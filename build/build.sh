#!/usr/bin/env bash
# Build an openHC EA image with the Home Assistant layer on top.
#
# openHC's own build/build.sh does all the composition (common + ea/common +
# features + board). This only hands it our layer through its downstream hook:
#   OHC_EXTRA_DEFCONFIG  board/ha_defconfig, appended last
#   OHC_EXTRA_EXTERNAL   board/, our BR2_EXTERNAL tree (OHCHA)
#
# BOARD is any openHC EA board (openHC/board/ea/<board>). Any other env openHC's
# build.sh reads (OHC_EA_SDK, OHC_VERSION, BR2_CCACHE_DIR, ...) passes through.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OPENHC_DIR="${OPENHC_DIR:-$REPO/openHC}"
BOARD="${BOARD:-ea3-v2}"

[ -f "$OPENHC_DIR/build/build.sh" ] || {
    echo "no openHC checkout at $OPENHC_DIR — run: git submodule update --init --recursive" >&2
    exit 1
}
[ "$BOARD" != common ] && [ -f "$OPENHC_DIR/board/ea/$BOARD/${BOARD}_defconfig" ] || {
    echo "BOARD must be an openHC EA board (got '$BOARD'); have:" >&2
    "$REPO/build/boards.sh" "$OPENHC_DIR" | sed 's/^/  /' >&2
    exit 1
}

export BOARD
export OHC_EXTRA_DEFCONFIG="$REPO/board/ha_defconfig"
export OHC_EXTRA_EXTERNAL="$REPO/board"
export BR2_OUTPUT_DIR="${BR2_OUTPUT_DIR:-$REPO/output/build/$BOARD}"
export BR2_DL_DIR="${BR2_DL_DIR:-$REPO/dl}"
exec bash "$OPENHC_DIR/build/build.sh" "$@"
