# VSCodium extensions that nixpkgs doesn't package, pinned as .vsix files
# straight from Open VSX (the marketplace VSCodium itself uses).
#
# Each entry in extensions.json is one extension. To add one, append an entry
# with any version and an empty hash, then run ./update to fill both in.
# ./update bumps every entry to its latest release, using the sha256 Open VSX
# publishes alongside each .vsix (no download needed).
{
  lib,
  vscode-utils,
  fetchurl,
}:

map (
  ext:
  vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      inherit (ext) publisher name version;
    };
    vsix = fetchurl {
      url = "https://open-vsx.org/api/${ext.publisher}/${ext.name}/${ext.version}/file/${ext.publisher}.${ext.name}-${ext.version}.vsix";
      inherit (ext) hash;
    };
  }
) (lib.importJSON ./extensions.json)
