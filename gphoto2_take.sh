#!/bin/bash
# Capture dark frame pairs for every ISO x shutter combination via gphoto2.
# Output: frames/<camera>/raw/dark_iso<ISO>_<shutter>_<n>.nef
# Existing files are skipped, so the script can be re-run to resume or extend a series.
set -euo pipefail

# Shutter values as reported by: gphoto2 --get-config capturesettings/shutterspeed
# Low ISO: dark current is only ~0.015 DN/s at ISO 100 (Z6 II); the photon-transfer slope needs
# a clear dark signal, so low ISO needs minutes of exposure (or gets excluded by sensor_fit).
# 60 s and longer require "Extended shutter speeds (M)" enabled in the camera (Z6 II: d6).
# High ISO: noise grows fast, a few points are enough.
ISOS_LOW=(100 200 400 640 800 1600)
TIMES_LOW=("0,0010s" "0,1000s" "1,0000s" "4,0000s" "8,0000s" "15,0000s" "30,0000s" "60,0000s" "120,0000s" "300,0000s")
ISOS_HIGH=(3200 6400 12800 25600)
TIMES_HIGH=("0,0010s" "1,0000s" "4,0000s" "15,0000s")
FRAMES=2                                 # frames2stats.py needs 2 per combination
SLEEP=1                                  # pause between frames [s]

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

# Build the list of missing frames: "iso;shutter;filename"
PLAN=()
add_plan() {
  local iso t label n fname
  local -n isos=$1 times=$2
  for iso in "${isos[@]}"; do
    for t in "${times[@]}"; do
      label=$(tr , . <<< "${t%s}" | awk '{printf "%gs", $1}' | tr . -)   # "0,0100s" -> "0-01s"
      for ((n = 1; n <= FRAMES; n++)); do
        fname="$OUT/dark_iso${iso}_${label}_${n}.nef"
        [[ -e $fname ]] || PLAN+=("$iso;$t;$fname")
      done
    done
  done
}
add_plan ISOS_LOW TIMES_LOW
add_plan ISOS_HIGH TIMES_HIGH

if (( ${#PLAN[@]} == 0 )); then
  echo "Camera: $CAMERA ($PORT) -> $OUT: all frames already exist, nothing to do."
  exit 0
fi

# exposure + pause per frame (excludes download time)
TOTAL=$(printf '%s\n' "${PLAN[@]}" | cut -d';' -f2 | tr -d s | tr , . | awk -v p="$SLEEP" '{ s += $1 + p } END { printf "%d", s }')
printf 'Camera: %s (%s) -> %s\nFrames to capture: %d, estimated time: %dm %02ds\n' \
       "$CAMERA" "$PORT" "$OUT" "${#PLAN[@]}" $(( TOTAL / 60 )) $(( TOTAL % 60 ))
read -rp 'Continue? [y/N] ' answer
[[ $answer == [yY] ]] || exit 0

mkdir -p "$OUT"
gphoto2 --port "$PORT" --set-config capturesettings/imagequality="NEF (Raw)"

cur_iso=; cur_t=
for item in "${PLAN[@]}"; do
  IFS=';' read -r iso t fname <<< "$item"
  if [[ $iso != "$cur_iso" ]]; then
    gphoto2 --port "$PORT" --set-config imgsettings/iso="$iso"; cur_iso=$iso
  fi
  if [[ $t != "$cur_t" ]]; then
    gphoto2 --port "$PORT" --set-config capturesettings/shutterspeed="$t"; cur_t=$t
  fi
  echo "Capturing ISO=$iso shutter=$t -> $fname"
  gphoto2 --port "$PORT" --capture-image-and-download --force-overwrite --filename "$fname"
  sleep "$SLEEP"
done
