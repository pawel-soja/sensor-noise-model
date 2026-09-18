#!/bin/bash
# Capture flat frame pairs for every ISO x shutter combination via gphoto2, for photon transfer
# with real light: evenly lit flat panel (or twilight sky) in front of the lens, focus irrelevant.
# Output: frames/<camera>/flat/raw/flat_iso<ISO>_<shutter>_<n>.nef
# Existing files are skipped, so the script can be re-run to resume or extend a series.
set -euo pipefail
cd "$(dirname "$0")"

# Shutter values as reported by: gphoto2 --get-config capturesettings/shutterspeed
# The series should span from a few % to ~70 % of full scale at every ISO without clipping:
# take a test frame at the longest time of each group first and adjust panel brightness /
# aperture. Doubling ISO doubles the signal, so the high-ISO group uses 8x shorter times.
ISOS_LOW=(100 200 400 800)
TIMES_LOW=("0,0005s" "0,0010s" "0,0020s" "0,0040s" "0,0080s" "0,0167s" "0,0333s" "0,0667s")
ISOS_HIGH=(1600 3200 6400 12800 25600)
TIMES_HIGH=("0,0001s" "0,0003s" "0,0005s" "0,0010s" "0,0020s" "0,0040s" "0,0080s")
TYPE=flat
FRAMES=2                                 # frames2stats.py needs 2 per combination
SLEEP=1                                  # pause between frames [s]

source ./gphoto2_capture.sh
capture_init
add_plan ISOS_LOW TIMES_LOW
add_plan ISOS_HIGH TIMES_HIGH
capture_run "Point the camera at the evenly lit flat panel; keep the light constant during the run."
