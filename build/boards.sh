#!/usr/bin/env bash
# The EA boards openHC defines, one per line: every board/ea/<b>/<b>_defconfig
# except the family base.
set -euo pipefail
OPENHC_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)/openHC}"
for d in "$OPENHC_DIR"/board/ea/*/; do
    b=$(basename "$d")
    [ "$b" != common ] && [ -f "$d/${b}_defconfig" ] && echo "$b"
done
