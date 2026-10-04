#!/bin/bash
# Fetch the AmneziaWG kernel module source and apply this repo's patch series.
# Shared by .github/workflows/build.yml (module-prepare) and ci/local-kmod.sh so
# CI and local builds compile identical sources.
#
# Usage: prepare-module.sh <module-version> <dest-dir> [repo-dir]
#
# Every patch must apply cleanly (no fuzz). A patch that no longer applies means
# upstream changed underneath it: fail here, loudly, rather than ship a module
# built without the fix.
set -euo pipefail

VERSION=${1:?module version required}
DEST=${2:?destination directory required}
REPO=${3:-$(cd "$(dirname "$0")/.." && pwd)}
PATCH_DIR="$REPO/patches/amneziawg-linux-kernel-module"
URL="https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/tags/v$VERSION.tar.gz"

tarball=$(mktemp)
trap 'rm -f "$tarball"' EXIT

curl -fsSL -o "$tarball" "$URL"
mkdir -p "$DEST"
tar -xf "$tarball" -C "$DEST" --strip-components=1

cd "$DEST"
sed -i 's/ --dirty//g' src/Makefile

shopt -s nullglob
patches=("$PATCH_DIR"/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
    echo "ERROR: no patches found in $PATCH_DIR" >&2
    exit 1
fi

for p in "${patches[@]}"; do
    echo "Applying $(basename "$p")"
    if ! patch -p1 --forward --fuzz=0 --no-backup-if-mismatch < "$p"; then
        echo "ERROR: $(basename "$p") does not apply to amneziawg-linux-kernel-module v$VERSION" >&2
        exit 1
    fi
done
