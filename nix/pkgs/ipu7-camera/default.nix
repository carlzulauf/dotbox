# Intel Vision Driver (intel_cvs), out-of-tree.
#
# The CVS coprocessor (ACPI INTC10DE) owns the camera sensor at boot and has
# to hand it over before the in-tree ov02c10 driver can talk to it.  There is
# no mainline driver for it yet -- see intel/vision-drivers#36 -- so it gets
# built from Intel's GitHub repo.
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
}:

stdenv.mkDerivation {
  pname = "intel-vision-drivers";
  version = "0-unstable-2026-05-07";

  src = fetchFromGitHub {
    owner = "intel";
    repo = "vision-drivers";
    rev = "845d6f8bdf66ff1f455901da9de5e00a53a83dce";
    hash = "sha256-i/qZN8GXyqaE6n6pRtxQLdmGhmPDjoArzVvflDmwuSs=";
  };

  patches = [
    ./sensor-owner.patch
    ./csi-subdev.patch
  ];

  # Shipped as a plain source file rather than a patch hunk so it stays
  # readable and reviewable; csi-subdev.patch only adds the hooks for it.
  postPatch = ''
    cp ${./intel_cvs_csi.c} drivers/misc/icvs/intel_cvs_csi.c
  '';

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  enableParallelBuilding = true;

  # The Makefile hardcodes an INSTALL_MOD_DIR install into the running
  # system's /lib/modules; redirect it at $out instead.
  preInstall = ''
    sed -i -e "s,INSTALL_MOD_DIR=,INSTALL_MOD_PATH=$out INSTALL_MOD_DIR=," Makefile
  '';

  installTargets = [ "modules_install" ];

  meta = {
    description = "Intel Vision Driver (intel_cvs), required for IPU7 cameras on Lunar Lake";
    homepage = "https://github.com/intel/vision-drivers";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    broken = kernel.kernelOlder "6.7";
  };
}
