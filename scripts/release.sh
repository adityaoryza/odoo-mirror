#!/usr/bin/env bash
# Build the files of a release, in a local folder. It does not publish anything.
#
#   scripts/release.sh [OUT_DIR]        (default: ./dist)
#
# Produces, for the version in lib/globals.sh:
#   odoo-mirror-vX.Y.Z.tar.gz   the tool (bin, lib, sql, scripts, docs, examples, README, LICENSE...)
#   SHA256SUMS                  checksums of the archive and of install.sh
#   install.sh                  the one-line installer, to be attached to the release as well
set -euo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
OUT=${1:-$ROOT/dist}

VERSION=$(sed -n 's/^readonly VERSION="\(.*\)"$/\1/p' "$ROOT/lib/globals.sh")
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "release: cannot read VERSION from lib/globals.sh" >&2; exit 1; }
TAG="v$VERSION"
NAME="odoo-mirror-$TAG"

stage=$(mktemp -d "${TMPDIR:-/tmp}/odoo-mirror-release.XXXXXX")
trap 'rm -rf "${stage:?}"' EXIT
dir="$stage/$NAME"
mkdir -p "$dir/scripts"

for item in bin lib sql examples docs README.md LICENSE CHANGELOG.md SECURITY.md packages.apt requirements.txt; do
    [[ -e "$ROOT/$item" ]] || { echo "release: missing $item" >&2; exit 1; }
    cp -R "$ROOT/$item" "$dir/"
done
cp "$ROOT/scripts/install.sh" "$dir/scripts/install.sh"
printf '%s\n' "$VERSION" >"$dir/RELEASE"
find "$dir" -name '__pycache__' -prune -exec rm -rf {} +

mkdir -p "$OUT"
tar -C "$stage" -czf "$OUT/$NAME.tar.gz" --owner=0 --group=0 --numeric-owner --sort=name "$NAME"
cp "$ROOT/scripts/install.sh" "$OUT/install.sh"
(cd "$OUT" && sha256sum "$NAME.tar.gz" install.sh >SHA256SUMS)

echo "Release $TAG built in $OUT:"
for f in "$NAME.tar.gz" SHA256SUMS install.sh; do printf '  %8s  %s\n' "$(wc -c <"$OUT/$f")" "$OUT/$f"; done
cat <<MSG

Nothing was published. To publish it yourself:
  git tag $TAG && git push origin $TAG
  gh release create $TAG "$OUT/$NAME.tar.gz" "$OUT/SHA256SUMS" "$OUT/install.sh" --title "$TAG" --notes-file CHANGELOG.md
MSG
