#!/usr/bin/env bash
# The EA boards openHC defines, one per line: every
# board/ea/<family>/<board>/<board>_defconfig.
set -euo pipefail
OPENHC_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)/openHC}"
for f in "$OPENHC_DIR"/board/ea/*/*/*_defconfig; do
    b=$(basename "$(dirname "$f")")
    [ "$(basename "$f")" = "${b}_defconfig" ] && echo "$b"
done
