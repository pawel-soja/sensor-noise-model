#!/bin/bash
# Convert DSLR RAW frames to FITS with Siril (keeps CFA data, ISOSPEED/EXPTIME headers).
#
# Usage: ./raw2fits.sh <camera> <type>          type: dark | flat
#   reads  frames/<camera>/<type>/raw/**/*.nef  (every directory containing RAW files)
#   writes frames/<camera>/<type>/fits/<dir>_NNNNN.fit
set -euo pipefail

RAW_EXT='nef|cr2|cr3|arw|dng'

if (( $# != 2 )); then
  echo "usage: $0 <camera> <dark|flat>" >&2
  exit 1
fi

SRC=$(realpath "frames/$1/$2/raw")
OUT=$(realpath "frames/$1/$2")/fits

# Siril keeps quotes in -out= literally, so the path must not contain spaces
if [[ "$OUT" == *" "* ]]; then
  echo "output path must not contain spaces: $OUT" >&2
  exit 1
fi

SCRIPT=$(mktemp --suffix=.ssf)
trap 'rm -f "$SCRIPT"' EXIT

mapfile -t DIRS < <(find "$SRC" -type f -regextype posix-extended -iregex ".*\.($RAW_EXT)$" -printf '%h\n' | sort -u)

if (( ${#DIRS[@]} == 0 )); then
  echo "no RAW files in $SRC" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"

{
  echo "requires 1.2.0"
  echo "set32bits"
  for dir in "${DIRS[@]}"; do
    prefix=$(basename "$dir" | tr -cd '[:alnum:]\n' | tr '[:upper:]' '[:lower:]')
    echo "cd \"$dir\""
    echo "convert $prefix -out=$OUT"
  done
} > "$SCRIPT"

siril-cli -d /tmp -s "$SCRIPT"

echo "written $(find "$OUT" -name '*.fit' | wc -l) FITS files to $OUT" >&2
