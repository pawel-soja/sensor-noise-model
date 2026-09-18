#!/bin/bash
# Capture dark frame pairs for every ISO x shutter combination via gphoto2 (lens cap on).
# Output: frames/<camera>/dark/raw/dark_iso<ISO>_<shutter>_<n>.nef
# Existing files are skipped, so the script can be re-run to resume or extend a series.
set -euo pipefail
cd "$(dirname "$0")"

# Shutter values as reported by: gphoto2 --get-config capturesettings/shutterspeed
# Low ISO: dark current is only ~0.015 DN/s at ISO 100 (Z6 II); the photon-transfer slope needs
# a clear dark signal, so low ISO needs minutes of exposure (or gets excluded by sensor_fit).
# 60 s and longer require "Extended shutter speeds (M)" enabled in the camera (Z6 II: d6).
# High ISO: noise grows fast, a few points are enough.
ISOS_LOW=(100 200 400 640 800 1600)
TIMES_LOW=("0,0010s" "0,1000s" "1,0000s" "4,0000s" "8,0000s" "15,0000s" "30,0000s" "60,0000s")
ISOS_HIGH=(3200 6400 12800 25600)
TIMES_HIGH=("0,0010s" "1,0000s" "4,0000s" "15,0000s")
TYPE=dark
FRAMES=2                                 # frames2stats.py needs 2 per combination
SLEEP=1                                  # pause between frames [s]

source ./gphoto2_capture.sh
capture_init
add_plan ISOS_LOW TIMES_LOW
add_plan ISOS_HIGH TIMES_HIGH
capture_run "Put the lens cap on and cover the viewfinder."
