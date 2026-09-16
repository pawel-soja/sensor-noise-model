#!/usr/bin/python

# https://www.brisk.org.uk/photog/d3readn.html
#
# Usage: ./frames2stats.py <camera>
#   reads  frames/<camera>/**/*.fit[s]
#   writes stats/<camera>.csv  (ISO;shutter;average;sigma)

import os
import sys
import glob
import math
from astropy.io import fits
import numpy as np

GAIN_KEYS = ['ISOSPEED', 'GAIN']  # DSLR, astro camera
WIN = 1024 * 4                    # central crop size [px], clamped to frame size

def crop(array, boxSize = 2):
    s = min(boxSize, min(array.shape)) // 2
    h = array.shape[0] // 2
    w = array.shape[1] // 2

    return array[h - s : h + s, w - s : w + s]

def read_gain(header):
    for key in GAIN_KEYS:
        if key in header:
            return int(header[key])
    raise KeyError("none of %s found in FITS header" % GAIN_KEYS)

if len(sys.argv) != 2:
    sys.exit("usage: %s <camera>" % sys.argv[0])

camera = sys.argv[1]
frames_dir = os.path.join('frames', camera)
stats_file = os.path.join('stats', camera + '.csv')

files = glob.glob(os.path.join(frames_dir, '**', '*.fit'), recursive=True) + \
        glob.glob(os.path.join(frames_dir, '**', '*.fits'), recursive=True)
if not files:
    sys.exit("no FITS files in %s" % frames_dir)

group_isoexp = {}

for file in files:
    header = fits.getheader(file)

    exp = header['EXPTIME']
    iso = read_gain(header)

    group_isoexp.setdefault(iso, {}).setdefault(exp, []).append(file)

os.makedirs('stats', exist_ok=True)

with open(stats_file, 'w') as out:
    for iso in sorted(group_isoexp.keys()):
        group_exp = group_isoexp[iso]

        for exp in sorted(group_exp.keys()):
            file = sorted(group_exp[exp])
            if len(file) < 2:
                print("skip ISO %d EXP %g: need 2 frames, got %d" % (iso, exp, len(file)), file=sys.stderr)
                continue

            fit1 = fits.getdata(file[0]).astype(float)
            fit2 = fits.getdata(file[1]).astype(float)

            mean = (np.mean(crop(fit1, WIN)) + np.mean(crop(fit2, WIN))) / 2

            dsigma = np.std(crop(fit1 - fit2, WIN)) / math.sqrt(2)

            print("%s" % file[0], file=sys.stderr)
            out.write("%f;%f;%f;%f\n" % (iso, exp, mean, dsigma))

print("written %s" % stats_file, file=sys.stderr)
