# VSCodium's browser server ("reh-web"): VS Code in a browser tab, built from
# VSCodium rather than Microsoft's VS Code. Unlike code-server, it doesn't
# bundle the GitHub Copilot extension, and like desktop VSCodium it installs
# extensions from Open VSX.
#
# Not in nixpkgs, so this repackages the prebuilt release tarball VSCodium
# publishes with every release (vscodium-reh-web-linux-x64-<version>.tar.gz).
# The pin lives in source.json; ./update.sh rewrites it:
#
#   nix/pkgs/codium-server/update.sh              # latest stable release
#   nix/pkgs/codium-server/update.sh 1.135.06055  # a specific release
#
# The tarball carries its own node binary plus native node modules (pty,
# sqlite, file watcher, ...) built for that exact node, so the bundled node is
# kept and autoPatchelf points everything at nixpkgs' glibc/libstdc++ rather
# than relying on nix-ld.
#
# Webviews (Markdown preview, extension panels) load their host page from
# Microsoft's vscode-cdn.net, as in upstream VS Code for the web: the server
# sets no local webview endpoint, so the browser falls back to the template
# in product.json. They need internet access from the browser to work.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  krb5,
  e2fsprogs,
}:

let
  source = lib.importJSON ./source.json;
in
stdenv.mkDerivation {
  pname = "codium-server";
  inherit (source) version;

  src = fetchurl {
    url = "https://github.com/VSCodium/vscodium/releases/download/${source.version}/vscodium-reh-web-linux-x64-${source.version}.tar.gz";
    inherit (source) hash;
  };

  # The tarball's contents sit at its root, not in a top-level directory.
  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  # The kerberos module (proxy authentication) dlopens libgssapi_krb5,
  # libkrb5 and libcom_err.so.2 (e2fsprogs' soname; krb5 ships .so.3) rather
  # than linking them, so autoPatchelf can't see the dependencies. dlopen
  # searches the calling library's runpath, so they have to land on
  # kerberos.node itself (runtimeDependencies only reaches executables).
  appendRunpaths = [
    "${lib.getLib krb5}/lib"
    "${lib.getLib e2fsprogs}/lib"
  ];

  installPhase = ''
    runHook preInstall

    # Binaries for other architectures; only x86_64 is packaged.
    rm -r node_modules/@vscode/ripgrep-universal/bin/linux-{arm,arm64,ia32,ppc64,riscv64,s390x}
    rm -r node_modules/@microsoft/mxc-sdk/bin/arm64

    # Native broker for Microsoft-account sign-in. It links webkitgtk, GTK and
    # libsecret, which a headless server has no use for; without it the
    # extension falls back to signing in through the browser.
    rm extensions/microsoft-authentication/dist/{msal-node-runtime.node,libmsalruntime.so}

    mkdir -p $out/lib $out/bin
    cp -r . $out/lib/codium-server
    # bin/codium-server finds its root through readlink -f, so a symlink works.
    ln -s $out/lib/codium-server/bin/codium-server $out/bin/codium-server

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "VSCodium web server: VS Code without Microsoft's proprietary bits, in the browser";
    homepage = "https://github.com/VSCodium/vscodium";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "codium-server";
  };
}
