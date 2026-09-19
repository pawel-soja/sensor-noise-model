# Shared gphoto2 capture logic, sourced by gphoto2_take_darks.sh / gphoto2_take_flats.sh.
# The wrapper sets TYPE (dark|flat), FRAMES, SLEEP, optionally EXPOSURE_KEY, and calls:
#   capture_init                 detect the camera -> PORT, CAMERA, OUT
#   add_plan ISOS VALUES         queue missing frames for every ISO x exposure value (array names)
#   capture_run [message]        summary, confirmation, optional prompt, capture loop
# EXPOSURE_KEY is the gphoto2 config varied within an ISO series:
#   capturesettings/shutterspeed          (default) manual mode, values like "0,0010s" -> label "0-001s"
#   capturesettings/exposurecompensation  A mode, values like "-2" -> label "ev-2"
# Output: frames/<camera>/<TYPE>/raw/<TYPE>_iso<ISO>_<label>_<n>.nef
# Existing files are skipped, so a run can be resumed or extended.

PLAN=()
: "${EXPOSURE_KEY:=capturesettings/shutterspeed}"

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

# add_plan <isos array name> <values array name>; values as reported by
# gphoto2 --get-config $EXPOSURE_KEY, e.g. "0,0010s" or "-2"
add_plan() {
  local iso t label n fname
  local -n isos=$1 values=$2
  for iso in "${isos[@]}"; do
    for t in "${values[@]}"; do
      if [[ $EXPOSURE_KEY == */shutterspeed ]]; then
        label=$(tr , . <<< "${t%s}" | awk '{printf "%gs", $1}' | tr . -)   # "0,0100s" -> "0-01s"
      else
        label=$(tr , . <<< "$t" | awk '{printf "ev%+g", $1}')               # "-2" -> "ev-2", "1" -> "ev+1"
      fi
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

  printf 'Camera: %s (%s) -> %s\nFrames to capture: %d' "$CAMERA" "$PORT" "$OUT" "${#PLAN[@]}"
  if [[ $EXPOSURE_KEY == */shutterspeed ]]; then
    # exposure + pause per frame (excludes download time)
    local total
    total=$(printf '%s\n' "${PLAN[@]}" | cut -d';' -f2 | tr -d s | tr , . | awk -v p="$SLEEP" '{ s += $1 + p } END { printf "%d", s }')
    printf ', estimated time: %dm %02ds\n' $(( total / 60 )) $(( total % 60 ))
  else
    printf ' (auto exposure, time unknown)\n'
  fi
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
      gphoto2 --port "$PORT" --set-config "$EXPOSURE_KEY=$t"; cur_t=$t
    fi
    echo "Capturing ISO=$iso ${EXPOSURE_KEY##*/}=$t -> $fname"
    gphoto2 --port "$PORT" --capture-image-and-download --force-overwrite --filename "$fname"
    sleep "$SLEEP"
  done
}
