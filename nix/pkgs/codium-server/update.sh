#!/usr/bin/env bash
# Pin codium-server to a VSCodium release by rewriting source.json.
#
#   nix/pkgs/codium-server/update.sh              # latest stable release
#   nix/pkgs/codium-server/update.sh 1.135.06055  # a specific release
#
# Takes the hash from the .sha256 file VSCodium publishes next to each
# tarball, so nothing big is downloaded here; fetchurl still verifies the
# tarball against it at build time.
set -euo pipefail

repo="VSCodium/vscodium"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
json="$dir/source.json"

for tool in curl jq nix; do
  command -v "$tool" >/dev/null || { echo "update.sh: needs $tool" >&2; exit 1; }
done

if [[ $# -gt 0 ]]; then
  version="$1"
else
  # /releases/latest skips pre-releases.
  version="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)"
fi

url="https://github.com/$repo/releases/download/$version/vscodium-reh-web-linux-x64-$version.tar.gz"
hex="$(curl -fsSL "$url.sha256" | cut -d' ' -f1)"
hash="$(nix hash convert --hash-algo sha256 --to sri "$hex")"

old="$(jq -r .version "$json" 2>/dev/null || echo none)"
jq -n --arg version "$version" --arg hash "$hash" \
  '{ version: $version, hash: $hash }' > "$json"

if [[ "$old" == "$version" ]]; then
  echo "codium-server: already at $version"
else
  echo "codium-server: $old -> $version"
fi
