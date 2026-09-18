# Shared gphoto2 capture logic, sourced by gphoto2_take_darks.sh / gphoto2_take_flats.sh.
# The wrapper sets TYPE (dark|flat), FRAMES, SLEEP and calls:
#   capture_init                 detect the camera -> PORT, CAMERA, OUT
#   add_plan ISOS TIMES          queue missing frames for every ISO x shutter (array names)
#   capture_run [message]        summary, confirmation, optional prompt, capture loop
# Output: frames/<camera>/<TYPE>/raw/<TYPE>_iso<ISO>_<shutter>_<n>.nef
# Existing files are skipped, so a run can be resumed or extended.

PLAN=()

capture_init() {
  local cameras
  mapfile -t cameras < <(gphoto2 --auto-detect | grep 'usb:')
  if (( ${#cameras[@]} != 1 )); then
    echo "Expected exactly one camera, found ${#cameras[@]}:" >&2
    printf '  %s\n' "${cameras[@]}" >&2
    exit 1
  fi
  PORT=$(awk '{print $NF}' <<< "${cameras[0]}")
  CAMERA=$(sed -E 's/[[:space:]]*usb:.*//' <<< "${cameras[0]}")
  CAMERA=${CAMERA// /_}
  OUT="frames/$CAMERA/$TYPE/raw"
}

# add_plan <isos array name> <times array name>; times as reported by
# gphoto2 --get-config capturesettings/shutterspeed, e.g. "0,0010s"
add_plan() {
  local iso t label n fname
  local -n isos=$1 times=$2
  for iso in "${isos[@]}"; do
    for t in "${times[@]}"; do
      label=$(tr , . <<< "${t%s}" | awk '{printf "%gs", $1}' | tr . -)   # "0,0100s" -> "0-01s"
      for ((n = 1; n <= FRAMES; n++)); do
        fname="$OUT/${TYPE}_iso${iso}_${label}_${n}.nef"
        [[ -e $fname ]] || PLAN+=("$iso;$t;$fname")
      done
    done
  done
}

capture_run() {
  local prompt=${1:-}
  if (( ${#PLAN[@]} == 0 )); then
    echo "Camera: $CAMERA ($PORT) -> $OUT: all frames already exist, nothing to do."
    exit 0
  fi

  # exposure + pause per frame (excludes download time)
  local total
  total=$(printf '%s\n' "${PLAN[@]}" | cut -d';' -f2 | tr -d s | tr , . | awk -v p="$SLEEP" '{ s += $1 + p } END { printf "%d", s }')
  printf 'Camera: %s (%s) -> %s\nFrames to capture: %d, estimated time: %dm %02ds\n' \
         "$CAMERA" "$PORT" "$OUT" "${#PLAN[@]}" $(( total / 60 )) $(( total % 60 ))
  [[ -n $prompt ]] && echo "$prompt"
  local answer
  read -rp 'Continue? [y/N] ' answer
  [[ $answer == [yY] ]] || exit 0

  mkdir -p "$OUT"
  gphoto2 --port "$PORT" --set-config capturesettings/imagequality="NEF (Raw)"

  local item iso t fname cur_iso= cur_t=
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
}
