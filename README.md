# Camera sensor characterization

🇬🇧 English | [🇵🇱 Polski](README.pl.md)

Derives a sensor noise model (bias, egain, read noise, dark current) from series of
dark frames taken at different ISO/gain settings and exposure times.
Method: https://www.brisk.org.uk/photog/d3readn.html

## Directory layout

```
frames/<camera>/          dark frames in FITS (astro cameras write here directly)
frames/<camera>/raw/      DSLR: RAW files (NEF etc.), subdirectories allowed
frames/<camera>/fits/     DSLR: FITS produced by raw2fits.sh
stats/<camera>.csv        statistics from frames2stats.py
plots/<camera>_*.png      plots saved automatically by sensor_plot
```

`<camera>` is the key throughout the pipeline: frames directory, CSV file,
`analysis.name` and the `case` in `sensor_models.m`.

## Pipeline

```
frames/<camera>/raw/**/*.nef  (DSLR)
  │  ./gphoto2_take.sh          capture over USB (optional)
  │  ./raw2fits.sh <camera>     RAW → FITS (Siril)
  ▼
frames/<camera>/**/*.fit[s]   (frame pairs for every ISO × exposure)
  │  ./frames2stats.py <camera>
  ▼
stats/<camera>.csv            ISO; shutter [s]; average [DN]; sigma [DN]
  │  sensor_characterize('<camera>')
  │    ├─ sensor_fit          linear fits → analysis struct
  │    ├─ sensor_plot         plots (fig 1: input data, fig 2: model) → plots/<camera>_{input,model}.png
  │    └─ sensor_print_model  prints ready-to-paste `camera` struct
  ▼
sensor_models.m               paste the printed struct as a new `case`
```

## Step by step – new camera

1. Take pairs of dark frames for every ISO/gain × exposure time combination
   (at least 2 frames per combination, several exposures from very short to long).
   DSLR over USB: set `ISOS`/`TIMES` in `gphoto2_take.sh` and run `./gphoto2_take.sh`
   – it writes `frames/<camera>/raw/dark_iso<ISO>_<time>_<n>.nef`, e.g. `dark_iso800_0-01s_2.nef`
   (time in seconds with the dot replaced by `-`; camera name from `gphoto2 --auto-detect`).
2. Astro camera: put the FITS files in `frames/<camera>/` (subdirectories allowed – the script searches recursively).
   DSLR: put RAW files in `frames/<camera>/raw/` and convert:
   ```sh
   ./raw2fits.sh <camera>            # → frames/<camera>/fits/
   ```
3. Compute statistics:
   ```sh
   ./frames2stats.py <camera>        # → stats/<camera>.csv
   ```
   Gain is read from the `ISOSPEED` (DSLR) or `GAIN` (astro camera) header keyword.
   By default the whole frame is used with no pixel selection; `--win`/`--clip` are only for
   problematic data (see script description).
4. In Octave:
   ```octave
   sensor_characterize('<camera>')
   ```
5. Copy the console output into `sensor_models.m` as a new `case`.

## Scripts

### gphoto2_take.sh
Detects the single connected camera (`gphoto2 --auto-detect`), switches to RAW and for every
`ISOS` × `TIMES` combination takes `FRAMES` (default 2) frames into `frames/<camera>/raw/`.
`TIMES` values use the format reported by `gphoto2 --get-config capturesettings/shutterspeed`.

### raw2fits.sh <camera>
Finds every directory with RAW files under `frames/<camera>/raw/` and converts them with Siril
(no debayer, 32 bit) into `frames/<camera>/fits/<dir>_NNNNN.fit`. `ISOSPEED`/`EXPTIME` headers are preserved.
The `fits/` directory is wiped before conversion.

### build_images.sh
Regenerates every PNG in `plots/`: `sensor_characterize` for each `stats/*.csv` plus the extra
figures listed in `EXTRA` (`sensor_plot_iso_limit` for the D5100, `sensor_validate`).
Run it after changing the Octave scripts. Figure windows pop up briefly (qt renders the PNG 1:1
with the screen); without `DISPLAY` it falls back to gnuplot (fonts less faithful).

### frames2stats.py [--win N] [--clip S] <camera>
Groups FITS files from `frames/<camera>/` by (ISO, EXPTIME), takes the first two frames of each group and computes
`average` = mean, `sigma` = std(frame1 − frame2)/√2 over the whole frame.
Writes `stats/<camera>.csv` (`;`-separated).

By default no pixels are rejected – camera noise has heavy tails (RTS pixels etc.) and that is
real noise the model should describe. Options for faulty data only:
- `--win N` – use only the central N×N px (e.g. edge gradient / amp glow as in the D5100 with hacked firmware),
- `--clip S` – ignore pixels further than S robust sigmas (MAD) from the median in either frame
  (corrupt blocks of value 4128 in D5100 NEFs, see `frames/Nikon_D5100/CORRUPTED.txt`).
  Note: on heavy-tailed noise it biases sigma low (Z6 II: 0.5–5 %, up to 13 % at ISO 6400 / 1/100 s).

Parameters used: `Nikon_D5100` – `--win 4096 --clip 8`; `Nikon_Z6_2`, `ASI2600MM_5deg` – defaults.

### analysis = sensor_characterize(name, min_setting = [])
Main entry point. Loads `stats/<name>.csv` → `sensor_fit` → `sensor_plot` → `sensor_print_model`.
Returns the `analysis` struct (e.g. for `sensor_plot_iso_limit`).

### analysis = sensor_fit(data, min_setting = [])
From the `[ISO shutter average sigma]` matrix computes, for every ISO:
- `bias` – intercept of the average(shutter) line
- `dark_rate` [DN/s] – slope of the average(shutter) line
- `egain` [DN/e-] – slope of the sigma²(average − bias) line (photon transfer)
- `read_noise` [DN] – √ of that line's intercept
- `dark_current` [e-/s/pix] – `dark_rate / egain`
- `iso2egain`, `egain2read_noise` – linear fits between ISO and the parameters;
  `has_iso` tells whether ISO scales linearly (DSLR) or logarithmically (0.1 dB gain, astro cameras)
- `setting` – ISO/gain values as set on the camera (for labels)

The number of exposures may differ between ISO settings (missing entries are `NaN`).

**Minimum ISO/gain.** Photon transfer needs the dark signal to grow clearly over the series. At low
ISO/gain on cameras with low dark current (cooled astro cameras, modern DSLRs) less than 1 e-
accumulates and the variance grows mostly through hot pixels – the slope is random. `sensor_fit`
computes the slope significance (slope / its standard error) for every setting and drops everything
below the lowest setting from which all higher ones have t ≥ 10. Dropped settings are reported
(`analysis.excluded`, `analysis.min_setting`) and appear neither in the plots nor in the model.
Low ISO/gain is not used in astrophotography anyway. `min_setting` forces the threshold (0 = keep all).
Result: D5100 – everything from ISO 100; ASI2600 – from gain 150; Z6 II – from ISO 1600.

### sensor_plot(analysis)
Fig 1 – input data with fits. Fig 2 – egain, read noise vs ISO, SNR vs ISO.
Lines coloured by log(ISO) (blue = lowest, red = highest) with a colorbar instead of a legend.
Both figures are saved to `plots/<name>_input.png` and `plots/<name>_model.png`.

### sensor_plot_iso_limit(analysis, iso_limit)
Egain and read noise vs ISO (log axis) with the range above `iso_limit` highlighted, where analog
gain no longer increases – saved to `plots/<name>_iso_limit.png`. E.g. for the D5100:
```octave
sensor_plot_iso_limit(sensor_characterize('Nikon_D5100'), 1600)
```

### sensor_print_model(analysis)
Prints the `camera` struct as code to paste into `sensor_models.m`.

### camera = sensor_models(name)
Database of fitted models (`"ASI2600MM_5deg"`, `"Nikon_D5100"`). Besides the linear
fits it holds the measured `egain` and `read_noise` [DN] for every setting.

### data = sensor_simulate(camera, shutter)
Generates synthetic statistics from a model (inverse of `sensor_fit`).

### sensor_validate(name)
Round-trip test: `sensor_models` → `sensor_simulate` → `sensor_fit` → `sensor_plot`.
The result should reproduce the input model parameters.

### sensor_compare(cameras, sky = 0.3, t = 60)
Comparison table of cameras from `sensor_models` for a given sky flux [e-/s/px] and sub length [s]
(same optics and QE). Per camera: ISO/gain (default: lowest read noise in e-, or forced with
`{name, setting}`), egain, read noise [e-], dark current, `t_min` – sub length at which read noise²
is 10 % of the sky+dark variance, noise variance per second of integration `sky + D + RN²/t` and the
resulting relative integration time for equal SNR.
```octave
sensor_compare({'ASI2600MM_5deg', {'Nikon_D5100', 1600}}, 0.3, 60)
```
```
camera            setting   egain  RN [e-]  D [e-/s]  t_min   var/s   time
ASI2600MM_5deg        250   43.54    0.62    0.0017   12.7   0.308  1.00x
Nikon_D5100          1600    5.90    2.04    0.4012   59.4   0.771  2.50x
```
Under a dark sky (0.3 e-/s) the D5100 needs ~2.5× the time of the ASI2600 – almost entirely due to
dark current; under a bright sky (5 e-/s) the difference drops to ~9 %.

## Outside the pipeline

### snr_vs_iso(name)
Experiment: SNR as a function of ISO for a fixed total exposure time.

### counts2mag
Estimating stellar magnitude from ADU counts – notes from a Deneb measurement.

## Results

### Nikon D5100 – ISO above 1600 is digital only

From ISO 1600 upwards egain (5.9 DN/e-) and read noise (12.1 DN = 2.1 e-) stop changing:
analog gain ends at 1600, higher ISO is purely digital scaling.
SNR does not improve, only highlight headroom and bit depth are lost – for astrophotography
there is no point going above ISO 1600.

![D5100 – analog gain limit](plots/Nikon_D5100_iso_limit.png)

Full model:

![D5100 – model](plots/Nikon_D5100_model.png)
![D5100 – input data](plots/Nikon_D5100_input.png)

### ZWO ASI2600MM (−5 °C)

![ASI2600MM – model](plots/ASI2600MM_5deg_model.png)
![ASI2600MM – input data](plots/ASI2600MM_5deg_input.png)

### Nikon Z6 II

`sensor_fit` drops ISO < 1600 (photon-transfer slope not significant), but even above that the result
is physically impossible: egain 70–1100 DN/e- (expected ~5–40), i.e. a 14-bit full scale of 15 e- at
ISO 25600 and a read noise of 0.05 e-. Cause: the camera applies a black-level clamp – it subtracts the
mean dark current measured on shielded reference pixels and adds a constant 1008 DN. The dark mean
therefore grows ~20× slower than its noise implies (ISO 25600: +42 DN in 15 s, but 216 DN of noise ≈
19 e- of charge), and photon transfer loses its X axis. The noise itself is fine: uniform across the
frame, variance ∝ time and ∝ egain², consistently ~1.2 e-/s of dark current. The D5100 (old design,
bias 128, no clamp) does not have this problem. From Z6 II darks the reliable quantities are bias, read
noise in DN (1.6 → 113 DN) and the variance growth rate; egain needs flats. The model is not in the database.

![Z6 II – input data](plots/Nikon_Z6_2_input.png)
