#!/bin/bash
# Capture flat frame pairs for every ISO x exposure level via gphoto2, for photon transfer with
# real light: evenly lit flat panel (or twilight sky) in front of the lens, focus irrelevant.
#
# Camera: mode dial A (aperture priority), auto ISO OFF, fixed aperture. The camera meters the
# panel to mid grey and the script steps exposure compensation, so every ISO gets the same set
# of signal levels (~1 % .. ~70 % of full scale for -4 .. +2 EV) without tuning panel brightness
# or shutter times per ISO. The actual shutter time ends up in EXIF -> EXPTIME, which
# frames2stats.py groups by; both frames of a pair must meter identically (constant panel).
#
# Output: frames/<camera>/flat/raw/flat_iso<ISO>_ev<EV>_<n>.nef
# Existing files are skipped, so the script can be re-run to resume or extend a series.
set -euo pipefail
cd "$(dirname "$0")"

# EV values as reported by: gphoto2 --get-config capturesettings/exposurecompensation
ISOS=(100 200 400 800 1600 3200 6400 12800 25600)
EVS=("-4" "-3" "-2" "-1" "0" "1" "2")
TYPE=flat
EXPOSURE_KEY=capturesettings/exposurecompensation
FRAMES=2                                 # frames2stats.py needs 2 per combination
SLEEP=1                                  # pause between frames [s]

source ./gphoto2_capture.sh
capture_init
add_plan ISOS EVS
capture_run "Mode dial A, auto ISO off. Point the camera at the evenly lit flat panel; keep the light constant during the run."
