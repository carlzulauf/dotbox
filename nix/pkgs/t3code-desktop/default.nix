# T3 Code (https://t3.codes) desktop app, run from the upstream AppImage.
#
# nixpkgs and llm-agents both build T3 Code from source against nixpkgs'
# Electron, so they trail upstream's releases. This runs the official
# AppImage instead, in the same FHS sandbox `appimage-run` uses.
#
# Its version and hash are pinned by nvfetcher (../nvfetcher.toml); bump with
# `nix run nixpkgs#nvfetcher` in nix/pkgs.
#
# The desktop app starts its own backend on ~/.t3/userdata, so don't run it
# on a host that also runs a T3 Code server on the same home directory.
#
# It also writes a `t3` CLI shim to ~/.t3/bin/t3, but that execs the
# AppImage's Electron straight from the store, outside the FHS sandbox, so it
# fails on NixOS (missing libglib). Only `t3` itself and the app's
# "install as service" use it; the desktop app doesn't need it.
{
  lib,
  appimageTools,
  callPackage,
  makeWrapper,
}:

let
  inherit ((callPackage ../_sources/generated.nix { }).t3code-desktop) pname version src;

  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  # The built-in updater would replace the AppImage in place; Nix owns that.
  # The app also writes a t3code:// URL handler into
  # ~/.local/share/applications that execs the launcher path, which defaults
  # to a store path that goes away after an upgrade and gc; point it at the
  # name on PATH instead.
  extraInstallCommands = ''
    wrapProgram $out/bin/${pname} \
      --set T3CODE_DISABLE_AUTO_UPDATE 1 \
      --set T3CODE_DESKTOP_LAUNCHER_PATH ${pname}

    install -Dm644 ${contents}/t3code.desktop $out/share/applications/t3code.desktop
    substituteInPlace $out/share/applications/t3code.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${contents}/usr/share/icons $out/share/
  '';

  meta = {
    description = "Desktop control surface for coding agents (upstream AppImage)";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
