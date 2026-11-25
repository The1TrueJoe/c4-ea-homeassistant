#!/usr/bin/env bash
# Download the image bundle openHC's CI built for <board> at the openHC
# submodule's commit: build/openhc-bundle.sh <board> <out.zip>
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
BOARD=$1 OUT=$2
SHA=$(git -C "$REPO/openHC" rev-parse HEAD)
RUN=$(gh run list -R The1TrueJoe/openHC -w images -c "$SHA" -s success -L 1 --json databaseId --jq '.[0].databaseId')
[ -n "$RUN" ] || { echo "openHC has no successful images run for $SHA yet" >&2; exit 1; }
T=$(mktemp -d)
gh run download "$RUN" -R The1TrueJoe/openHC -n "openhc-$BOARD" -D "$T"
mkdir -p "$(dirname "$OUT")"
f=$(find "$T" -name '*.zip' | head -1)
if [ -n "$f" ]; then mv "$f" "$OUT"; else (cd "$T" && zip -q -r "$(realpath -m "$OUT")" .); fi
rm -rf "$T"
echo "openhc-$BOARD @ ${SHA:0:7} (run $RUN) -> $OUT"
