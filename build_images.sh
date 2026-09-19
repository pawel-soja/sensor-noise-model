#!/bin/bash
# Regenerate every PNG in plots/: model plots for each stats/*_dark.csv, plus the extra figures below.
set -euo pipefail
cd "$(dirname "$0")"

# Figures that are not a plain sensor_characterize(<camera>)
EXTRA=(
  "sensor_plot_iso_limit(sensor_characterize('Nikon_D5100'), 1600);"
  "sensor_validate('Nikon_D5100');"
  "sensor_plot_sub_length({'ASI2600MM_5deg', {'Nikon_D5100', 1600}, {'Nikon_Z6_2', 800}}, [0.03 0.3]);"
)

cmd=""
for csv in stats/*_dark.csv; do
  camera=$(basename "$csv" _dark.csv)
  cmd+="sensor_characterize('$camera'); "
done
for e in "${EXTRA[@]}"; do
  cmd+="$e "
done

# qt renders PNGs exactly like the on-screen window (figures pop up briefly); without a display
# fall back to gnuplot (fonts less faithful).
if [[ -n ${DISPLAY:-} ]]; then
  setup="graphics_toolkit qt;"
else
  setup="graphics_toolkit gnuplot;"
fi

octave --no-gui --quiet --eval "$setup $cmd" 2>&1 | grep -E '^(saved|error)' || {
  echo "octave failed" >&2
  exit 1
}
