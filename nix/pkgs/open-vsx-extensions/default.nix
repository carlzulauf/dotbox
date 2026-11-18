# VSCodium extensions that nixpkgs doesn't package, pinned as .vsix files
# straight from Open VSX (the marketplace VSCodium itself uses).
#
# Every nvfetcher source with a publisher (../nvfetcher.toml) is one. To add
# one, add an entry there like the others and run `nix run nixpkgs#nvfetcher`
# in nix/pkgs, which also bumps them all to their latest releases.
{
  lib,
  vscode-utils,
  callPackage,
  unzip,
}:

map (
  ext:
  vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      inherit (ext) publisher version;
      name = ext.extName;
    };
    vsix = ext.src;
    # nvfetcher names the download .zip, which the .vsix unpacker skips.
    nativeBuildInputs = [ unzip ];
  }
) (lib.filter (source: source ? publisher) (lib.attrValues (callPackage ../_sources/generated.nix { })))
