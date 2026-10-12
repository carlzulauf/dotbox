# Userspace driver for the Synaptics 06cb:00e7 match-on-chip fingerprint
# sensor (HP Envy x360 13-ay).  Upstream libfprint lists this ID under "known
# unsupported devices"; this is a from-scratch reverse-engineered libfprint
# TOD module plus the `fpdrv` CLI for diagnostics and on-chip template
# management.
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  libfprint-tod,
  gusb,
  glib,
  libusb1,
  openssl,
}:

stdenv.mkDerivation {
  pname = "synaptics-00e7-fpdrv";
  version = "0-unstable-2026-08-29";

  src = fetchFromGitHub {
    owner = "HansHoogerwerf";
    repo = "synaptics-00e7-fpdrv";
    rev = "53ec1fca4b73608f7f62cbd64dd9eb643041228f";
    hash = "sha256-WYLsoTDH0sK3GoySbbzvdl0YbPsMs5hdI4ImqW++8XY=";
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    libfprint-tod
    gusb
    glib
    libusb1
    openssl
  ];

  # libfprint-2-tod-1.pc only pulls in libfprint-2 (where fprint.h lives) via
  # Requires.private, which pkgconf on Debian honours for --cflags but
  # nixpkgs' pkg-config doesn't; name it explicitly.
  buildPhase = ''
    runHook preBuild
    make fpdrv
    make -C tod PKGS="libfprint-2 libfprint-2-tod-1 gusb glib-2.0 gobject-2.0 gio-2.0 libcrypto libusb-1.0"
    runHook postBuild
  '';

  # The Makefiles install into libfprint-tod's own drivers dir and reload the
  # running system's udev; neither works here, so install by hand.  The udev
  # rule is left out -- it grants a plugdev group NixOS doesn't have, and the
  # CLI is run as root anyway.
  installPhase = ''
    runHook preInstall
    install -Dm755 fpdrv $out/bin/fpdrv
    install -Dm644 tod/libfpdrv_00e7_tod.so $out/lib/libfprint-2/tod-1/libfpdrv_00e7_tod.so
    runHook postInstall
  '';

  passthru.driverPath = "/lib/libfprint-2/tod-1";

  meta = {
    description = "libfprint TOD driver for the Synaptics 06cb:00e7 fingerprint sensor";
    homepage = "https://github.com/HansHoogerwerf/synaptics-00e7-fpdrv";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "fpdrv";
  };
}
