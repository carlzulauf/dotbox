{ lib, stdenv, fetchFromGitHub, kernel, kernelModuleMakeFlags }:

stdenv.mkDerivation {
  pname = "vision-drivers";
  version = "unstable-2025-07-07";

  src = fetchFromGitHub {
    owner = "intel";
    repo = "vision-drivers";
    rev = "845d6f8bdf66ff1f455901da9de5e00a53a83dce";
    hash = "sha256-i/qZN8GXyqaE6n6pRtxQLdmGhmPDjoArzVvflDmwuSs=";
  };

  patches = [
    # Add delayed_release field to struct intel_cvs (header)
    ./patch-struct.patch
    # Add delayed sensor release + sensor_owner sysfs + probe/remove hooks
    ./patch-intel-cvs.patch
  ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  enableParallelBuilding = true;

  preInstall = ''
    sed -i -e "s,INSTALL_MOD_DIR=,INSTALL_MOD_PATH=$out INSTALL_MOD_DIR=," Makefile
  '';

  installTargets = [ "modules_install" ];

  meta = {
    homepage = "https://github.com/intel/vision-drivers";
    description = "Intel Vision Driver (intel_cvs) for IPU7 camera support on Lunar Lake";
    license = lib.licenses.gpl2Only;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    broken = kernel.kernelOlder "6.7";
  };
}
