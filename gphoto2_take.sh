#!/bin/bash
# Capture dark frame pairs for every ISO x shutter combination via gphoto2.
# Output: frames/<camera>/raw/dark_iso<ISO>_<shutter>_<n>.nef
set -euo pipefail

ISOS=(100 200 400 800 1600 6400 25600)
TIMES=("0,0100s" "1,0000s" "2,0000s" "4,0000s" "8,0000s")   # as reported by: gphoto2 --get-config capturesettings/shutterspeed
FRAMES=2                                 # frames2stats.py needs 2 per combination
SLEEP=1                                  # pause between frames [s]

# exposure + pause per frame, summed over all combinations (excludes download time)
TOTAL=$(printf '%s\n' "${TIMES[@]}" | tr , . | awk -v n="${#ISOS[@]}" -v f="$FRAMES" -v p="$SLEEP" \
        '{ s += ($1 + p) } END { printf "%d", n * f * s }')
printf 'Frames: %d, estimated time: %dm %02ds\n' $(( ${#ISOS[@]} * ${#TIMES[@]} * FRAMES )) $(( TOTAL / 60 )) $(( TOTAL % 60 ))
read -rp 'Continue? [y/N] ' answer
[[ $answer == [yY] ]] || exit 0

mapfile -t CAMERAS < <(gphoto2 --auto-detect | grep 'usb:')

if (( ${#CAMERAS[@]} != 1 )); then
  echo "Expected exactly one camera, found ${#CAMERAS[@]}:" >&2
  printf '  %s\n' "${CAMERAS[@]}" >&2
  exit 1
fi

PORT=$(awk '{print $NF}' <<< "${CAMERAS[0]}")
CAMERA=$(sed -E 's/[[:space:]]*usb:.*//' <<< "${CAMERAS[0]}")
CAMERA=${CAMERA// /_}
OUT="frames/$CAMERA/raw"

echo "Camera: $CAMERA ($PORT) -> $OUT"
mkdir -p "$OUT"

gphoto2 --port "$PORT" --set-config capturesettings/imagequality="NEF (Raw)"

for iso in "${ISOS[@]}"; do
  gphoto2 --port "$PORT" --set-config imgsettings/iso="$iso"
  for t in "${TIMES[@]}"; do
    gphoto2 --port "$PORT" --set-config capturesettings/shutterspeed="$t"
    label=$(tr , . <<< "${t%s}" | awk '{printf "%gs", $1}' | tr . -)   # "0,0100s" -> "0-01s"
    for ((n = 1; n <= FRAMES; n++)); do
      fname="$OUT/dark_iso${iso}_${label}_${n}.nef"
      echo "Capturing ISO=$iso shutter=$t frame=$n"
      gphoto2 --port "$PORT" --capture-image-and-download --filename "$fname"
      sleep "$SLEEP"
    done
  done
done
