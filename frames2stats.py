#!/usr/bin/python

# https://www.brisk.org.uk/photog/d3readn.html
#
# Usage: ./frames2stats.py [--win N] [--clip S] <camera> <type>
#   type: dark | flat
#   reads  frames/<camera>/<type>/**/*.fit[s]
#   writes stats/<camera>_<type>.csv  (ISO;shutter;average;sigma)
#
#   --win N   use only the central N x N px (default: whole frame)
#   --clip S  ignore pixels further than S robust sigmas (MAD) from the median in either
#             frame - only for corrupt data (e.g. D5100 blocks of value 4128), it biases
#             sigma low on heavy-tailed noise (default: off)

import os
import sys
import glob
import math
import argparse
from astropy.io import fits
from astropy.stats import sigma_clip
import numpy as np

GAIN_KEYS = ['ISOSPEED', 'GAIN']  # DSLR, astro camera

def crop(array, boxSize):
    if not boxSize:
        return array
    s = min(boxSize, min(array.shape)) // 2
    h = array.shape[0] // 2
    w = array.shape[1] // 2

    return array[h - s : h + s, w - s : w + s]

def read_gain(header):
    for key in GAIN_KEYS:
        if key in header:
            return int(header[key])
    raise KeyError("none of %s found in FITS header" % GAIN_KEYS)

ap = argparse.ArgumentParser()
ap.add_argument('camera')
ap.add_argument('type', choices=['dark', 'flat'])
ap.add_argument('--win', type=int, default=0, metavar='N', help='central crop size [px], 0 = whole frame')
ap.add_argument('--clip', type=float, default=0, metavar='S', help='reject pixels beyond S robust sigmas, 0 = off')
args = ap.parse_args()

camera = args.camera
frames_dir = os.path.join('frames', camera, args.type)
stats_file = os.path.join('stats', camera + '_' + args.type + '.csv')

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

            fit1 = crop(fits.getdata(file[0]).astype(float), args.win)
            fit2 = crop(fits.getdata(file[1]).astype(float), args.win)

            if args.clip:
                bad = sigma_clip(fit1, sigma=args.clip, stdfunc='mad_std', maxiters=5).mask | \
                      sigma_clip(fit2, sigma=args.clip, stdfunc='mad_std', maxiters=5).mask
                info = "  masked %d px (%.3f%%)" % (bad.sum(), 100.0 * bad.sum() / bad.size)
            else:
                bad = np.zeros(fit1.shape, dtype=bool)
                info = ""
            good = ~bad

            mean = (np.mean(fit1[good]) + np.mean(fit2[good])) / 2

            # Flats: the light source may drift between the two frames (Z6 II panel: up to 3 %);
            # with vignetting that leaves a pattern in the difference and inflates sigma.
            # Scaling frame 2 to the same mean removes it (residual ~ bias / (bias + signal) of
            # the drift); for darks the factor is ~1 and nothing changes.
            scale = np.mean(fit1[good]) / np.mean(fit2[good])
            dsigma = np.std((fit1 - scale * fit2)[good]) / math.sqrt(2)

            print("%s%s" % (file[0], info), file=sys.stderr)
            out.write("%f;%f;%f;%f\n" % (iso, exp, mean, dsigma))

print("written %s" % stats_file, file=sys.stderr)
