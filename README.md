# Camera sensor characterization

🇬🇧 English | [🇵🇱 Polski](README.pl.md)

Derives a sensor noise model (bias, cgain, read noise, dark current) from series of
dark frames taken at different ISO/gain settings and exposure times.
Method: https://www.brisk.org.uk/photog/d3readn.html

## Directory layout

```
frames/<camera>/<type>/        <type> = dark | flat (light in the future)
frames/<camera>/<type>/*.fits  astro cameras write FITS here directly (subdirectories allowed)
frames/<camera>/<type>/raw/    DSLR: RAW files (NEF etc.), subdirectories allowed
frames/<camera>/<type>/fits/   DSLR: FITS produced by raw2fits.sh
stats/<camera>_<type>.csv      statistics from frames2stats.py
plots/<camera>_*.png           plots saved automatically by sensor_plot
```

`<camera>` is the key throughout the pipeline: frames directory, CSV file,
`analysis.name` and the `case` in `sensor_models.m`. `dark` is required; `flat` is optional and,
when present, takes over the conversion gain (see [Darks + flats](#darks--flats-sensor_merge)).

## Pipeline

```
frames/<camera>/dark/raw/**/*.nef            frames/<camera>/flat/raw/**/*.nef   (DSLR)
  │  ./gphoto2_take_darks.sh                    │  ./gphoto2_take_flats.sh        capture over USB (optional)
  │  ./raw2fits.sh <camera> dark                │  ./raw2fits.sh <camera> flat    RAW → FITS (Siril)
  ▼                                             ▼
frames/<camera>/dark/**/*.fit[s]             frames/<camera>/flat/**/*.fit[s]    (frame pairs, ISO × exposure)
  │  ./frames2stats.py <camera> dark            │  ./frames2stats.py <camera> flat
  ▼                                             ▼
stats/<camera>_dark.csv                      stats/<camera>_flat.csv  (optional)   ISO; shutter; average; sigma
  │  sensor_characterize('<camera>')
  │    ├─ sensor_fit          linear fits of darks (and flats)
  │    ├─ sensor_merge        with flats: cgain from flats, RN + dark current from darks
  │    ├─ sensor_plot         plots → plots/<camera>_{input,model,flat_input}.png
  │    └─ sensor_print_model  prints ready-to-paste `camera` struct
  ▼
sensor_models.m                              paste the printed struct as a new `case`
```

## Step by step – new camera

1. Take pairs of dark frames for every ISO/gain × exposure time combination
   (at least 2 frames per combination, several exposures from very short to long).
   DSLR over USB: set `ISOS`/`TIMES` in `gphoto2_take_darks.sh` and run `./gphoto2_take_darks.sh`
   – it writes `frames/<camera>/dark/raw/dark_iso<ISO>_<time>_<n>.nef`, e.g. `dark_iso800_0-01s_2.nef`
   (time in seconds with the dot replaced by `-`; camera name from `gphoto2 --auto-detect`).
2. Astro camera: put the FITS files in `frames/<camera>/dark/` (subdirectories allowed – the script searches recursively).
   DSLR: put RAW files in `frames/<camera>/dark/raw/` and convert:
   ```sh
   ./raw2fits.sh <camera> dark            # → frames/<camera>/dark/fits/
   ```
3. Compute statistics:
   ```sh
   ./frames2stats.py <camera> dark        # → stats/<camera>_dark.csv
   ```
   Gain is read from the `ISOSPEED` (DSLR) or `GAIN` (astro camera) header keyword.
   By default the whole frame is used with no pixel selection; `--win`/`--clip` are only for
   problematic data (see script description).
4. Optional – flats (recommended for DSLRs, required for cameras with a black-level clamp such as
   the Z6 II): `./gphoto2_take_flats.sh`, then the same `raw2fits.sh` / `frames2stats.py` with `flat`.
   If `stats/<camera>_flat.csv` exists, `sensor_characterize` uses it automatically.
5. In Octave:
   ```octave
   sensor_characterize('<camera>')
   ```
6. Copy the console output into `sensor_models.m` as a new `case`.

## Noise model and formulas

A dark frame pixel value $S$ [DN] at exposure time $t$ [s] is

$$S = b + g (D t + n),$$

where $b$ – bias [DN], $g$ – cgain [DN/e-], $D$ – dark current [e-/s/pix], $n$ – noise [e-].
`cgain` is the *conversion gain* in DN per electron – the inverse of the FITS `EGAIN` keyword /
Janesick's camera gain $K$ [e-/ADU].
The dark signal $D t$ is Poisson (variance = mean in e-), read noise $\sigma_r$ [DN] is independent of $t$.

### Input statistics (`frames2stats.py`)

For every (ISO, $t$) pair of frames $F_1$, $F_2$:

$$\overline{S} = \frac{\mathrm{mean}(F_1) + \mathrm{mean}(F_2)}{2}, \qquad
\sigma = \frac{\mathrm{std}(F_1 - k F_2)}{\sqrt{2}}, \quad k = \frac{\mathrm{mean}(F_1)}{\mathrm{mean}(F_2)}$$

Subtracting two frames removes the fixed pattern (hot pixels, bias structure, PRNU, vignetting);
the difference has twice the temporal variance, hence $\sqrt 2$. The scale factor $k$ absorbs a
brightness drift of the light source between the two flats (Z6 II panel: up to 3 %), which with
vignetting would otherwise leave a pattern in the difference and inflate $\sigma$ (ISO 100 / +2 EV:
44 → 29 DN). For darks $k \approx 1$.

### Fits per ISO/gain (`sensor_fit`)

All fits are ordinary least squares (`polyfit(..., 1)`) over the exposure series of a single ISO.

1. **Mean vs exposure** – bias and dark rate:

$$\overline{S}(t) = \underbrace{g D}_{\text{dark rate}} \cdot t + \underbrace{b}_{\text{bias}}$$

2. **Photon transfer** – variance vs bias-corrected mean. Since the dark signal in e- is Poisson,
   $\mathrm{var}[\text{e-}] = D t$ and after scaling by $g$:

$$\sigma^2 = g^2 D t + \sigma_r^2 = \underbrace{g}_{\text{cgain}} \cdot (\overline{S} - b) + \underbrace{\sigma_r^2}_{\text{read noise}^2}$$

   so the slope of $\sigma^2$ against $(\overline{S} - b)$ is cgain [DN/e-] and the intercept is
   read noise² [DN²]; $\sigma_r = \sqrt{\text{intercept}}$ [DN].

3. **Dark current** – from the two slopes, averaged over all ISO (it does not depend on gain):

$$D = \left\langle \frac{\text{dark rate}}{g} \right\rangle_{\text{ISO}} \quad [\text{e-/s/pix}]$$

4. **Slope significance** (automatic `min_setting`): for $n$ points of the photon-transfer fit with
   residuals $r_i$,

$$t = \frac{g}{\mathrm{se}(g)}, \qquad
\mathrm{se}(g) = \sqrt{\frac{\sum r_i^2 / (n-2)}{\sum (x_i - \bar x)^2}}, \quad x_i = \overline{S}_i - b$$

   Settings below the lowest ISO from which all higher ones have $t \ge 10$ are dropped.

### Darks + flats (`sensor_merge`)

A flat is the same photon-transfer experiment with light instead of dark current: $S = b + g(\Phi t + n)$
with the source flux $\Phi$ [e-/s] constant and $t$ stepped (in A mode via exposure compensation). The
same `sensor_fit` applies, but the signal is 100× larger, so the slope $g$ is far better determined and
independent of how the camera treats the dark mean. When `stats/<camera>_flat.csv` exists the model is
assembled from both:

| quantity | source | why |
|---|---|---|
| $b$ bias | darks, `average(t)` intercept | the flat intercept is spoiled by shutter timing error at the fastest speeds (1/8000 exposes longer than nominal) |
| $g$ cgain | flats, photon-transfer slope with the dark $b$ | large signal; immune to a black-level clamp |
| $\sigma_r$ read noise | darks, photon-transfer intercept | in flats $\sigma_r^2 \ll g(\overline S - b)$, the intercept is poorly determined |
| $D$ dark current | darks, **variance** growth | the dark mean may be clamped, the variance is not |

$$\sigma^2_{\text{dark}}(t) = g^2 D\, t + \sigma_r^2 \quad\Rightarrow\quad
D = \left\langle \frac{d\sigma^2/dt}{g^2} \right\rangle_{\text{ISO}}$$

with $g$ per ISO from the flats (settings without a flat are interpolated in log-log, $g \propto$ ISO).
The automatic `min_setting` exclusion is off in this mode – the dark photon-transfer slope is no
longer used. Dark-only cameras keep the formulas above.

### Fits across ISO/gain

- `iso2cgain`: $g(\text{ISO}) = a \cdot \text{ISO} + c$; for astro cameras the 0.1 dB gain setting $G$ is first
  converted to a linear scale $\text{ISO} = 100 \cdot 10^{G/200}$. Both models are tried on normalised $x$;
  the one with the lower residual norm wins (`has_iso` = linear).
- `cgain2read_noise`: $\sigma_r(g) = a g + c$ [DN].
- `cgain2iso`: inverse of `iso2cgain`.

### Derived quantities

- Read noise in electrons: $\sigma_r[\text{e-}] = \sigma_r[\text{DN}] / g$.
- Full well / clipping in e-: $2^{\text{bits}} / g$.
- `sensor_compare`: for sky flux $\Phi$ [e-/s/px], sub length $t$ and accepted read-noise share $p$
  (default 0.1),

$$\text{var/s} = \Phi + D + \frac{\sigma_r[\text{e-}]^2}{t}, \qquad
t_{\min} = \frac{\sigma_r[\text{e-}]^2}{p (\Phi + D)}$$

  Relative integration time for equal SNR is the ratio of var/s between cameras.
- `sensor_plot_sub_length`: total integration time for a given SNR with subs of length $t$,
  relative to an ideal noiseless camera $T_{\text{ideal}}$ (no dark current, no read noise; a finite
  time, $\propto \Phi$):

$$\frac{T(t)}{T_{\text{ideal}}} = \frac{\text{var/s}(t)}{\Phi} = \frac{\Phi + D + \sigma_r[\text{e-}]^2 / t}{\Phi}$$

  For $t \to \infty$ each curve approaches its own limit $(\Phi + D)/\Phi$ – the cost of dark current
  alone; at $t = t_{\min}$ it is $(1 + p)$ times that limit.
- `sensor_simulate` (inverse): $\overline{S} = g \overline{P} + b$,
  $\sigma = \sqrt{g^2 \mathrm{var}(P) + \sigma_r(g)^2}$ with $P \sim \text{Poisson}(D t)$.

## Scripts

### gphoto2_take_darks.sh
Detects the single connected camera (`gphoto2 --auto-detect`), switches to RAW and for every
`ISOS` × `TIMES` combination takes `FRAMES` (default 2) frames into `frames/<camera>/dark/raw/`.
`TIMES` values use the format reported by `gphoto2 --get-config capturesettings/shutterspeed`.
Existing files are skipped, so a run can be resumed or extended.

### gphoto2_take_flats.sh
Same for flats (`frames/<camera>/flat/raw/flat_iso<ISO>_ev<EV>_<n>.nef`) with an evenly lit panel in
front of the lens. Photon transfer needs several signal levels per ISO, so instead of tuning shutter
times the camera is put in **A mode with auto ISO off** and the script steps exposure compensation
(`EVS`, default −4 … +2 EV ≈ 1 … 70 % of full scale) – the camera meters the panel to mid grey and adapts
the shutter to each ISO by itself. The real shutter time lands in EXIF → `EXPTIME`, which
`frames2stats.py` groups by; both frames of a pair must meter identically (keep the light constant).

Both scripts are thin config wrappers around `gphoto2_capture.sh` (camera detection, plan of missing
frames, confirmation with time estimate, capture loop). `EXPOSURE_KEY` selects the gphoto2 setting
varied within an ISO series: `capturesettings/shutterspeed` (default, darks) or
`capturesettings/exposurecompensation` (flats).

### raw2fits.sh <camera> <dark|flat>
Finds every directory with RAW files under `frames/<camera>/<type>/raw/` and converts them with Siril
(no debayer, 32 bit) into `frames/<camera>/<type>/fits/<dir>_NNNNN.fit`. `ISOSPEED`/`EXPTIME` headers are preserved.
The `fits/` directory is wiped before conversion.

### build_images.sh
Regenerates every PNG in `plots/`: `sensor_characterize` for each `stats/*_dark.csv` plus the extra
figures listed in `EXTRA` (`sensor_plot_iso_limit` for the D5100, `sensor_validate`, `sensor_plot_sub_length`).
Run it after changing the Octave scripts. Figure windows pop up briefly (qt renders the PNG 1:1
with the screen); without `DISPLAY` it falls back to gnuplot (fonts less faithful).

### frames2stats.py [--win N] [--clip S] <camera> <dark|flat>
Groups FITS files from `frames/<camera>/<type>/` by (ISO, EXPTIME), takes the first two frames of each group and computes
`average` = mean of both, `sigma` = std(frame1 − k·frame2)/√2 over the whole frame, where k equalises the
means (brightness drift of the panel between two flats; for darks k ≈ 1).
Writes `stats/<camera>_<type>.csv` (`;`-separated).

By default no pixels are rejected – camera noise has heavy tails (RTS pixels etc.) and that is
real noise the model should describe. Options for faulty data only:
- `--win N` – use only the central N×N px (e.g. edge gradient / amp glow as in the D5100 with hacked firmware),
- `--clip S` – ignore pixels further than S robust sigmas (MAD) from the median in either frame
  (corrupt blocks of value 4128 in D5100 NEFs, see `frames/Nikon_D5100/CORRUPTED.txt`).
  Note: on heavy-tailed noise it biases sigma low (Z6 II: 0.5–5 %, up to 13 % at ISO 6400 / 1/100 s).

Parameters used: `Nikon_D5100` – `--win 4096 --clip 8`; `Nikon_Z6_2`, `ASI2600MM_5deg` – defaults.

### analysis = sensor_characterize(name, min_setting = [])
Main entry point. Loads `stats/<name>_dark.csv` → `sensor_fit` → `sensor_plot` → `sensor_print_model`.
If `stats/<name>_flat.csv` exists it is fitted too (with the dark bias) and combined by `sensor_merge`;
`min_setting` then defaults to 0 (no exclusion – the dark photon-transfer slope is not used).
Returns the `analysis` struct (e.g. for `sensor_plot_iso_limit`).

### analysis = sensor_fit(data, min_setting = [], bias = [])
From the `[ISO shutter average sigma]` matrix computes, for every ISO (formulas in
[Noise model and formulas](#noise-model-and-formulas)):
- `bias` – intercept of the average(shutter) line, or taken from the optional `[setting bias]` table
- `dark_rate` [DN/s] – slope of the average(shutter) line (for flats: source flux × cgain)
- `sigma2_rate` [DN²/s] – slope of the sigma²(shutter) line (= dark current × cgain²)
- `cgain` [DN/e-] – slope of the sigma²(average − bias) line (photon transfer)
- `read_noise` [DN] – √ of that line's intercept
- `dark_current` [e-/s/pix] – `dark_rate / cgain`
- `iso2cgain`, `cgain2read_noise` – linear fits between ISO and the parameters;
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
Result: D5100 – everything from ISO 100; ASI2600 – from gain 150; Z6 II – from ISO 1600 (darks only).

### analysis = sensor_merge(dark, flat)
Combines two `sensor_fit` results on the dark's ISO grid: `cgain` from the flat (interpolated in
log-log for settings without a flat), `read_noise` and `bias` from the dark, `dark_current` from the
dark variance growth `sigma2_rate / cgain²` (per setting in `dark_current_per_setting`). The flat fit
is attached as `analysis.flat`, `analysis.source = 'flat'`. See [Darks + flats](#darks--flats-sensor_merge).

### sensor_plot(analysis)
Fig 1 – dark input data with fits. Fig 2 – cgain, read noise vs ISO, dark current, SNR vs ISO.
With flats also Fig 3 – flat input data (log-log), and the dark-current panel shows the variance-based
estimate. Lines coloured by log(ISO) (blue = lowest, red = highest) with a colorbar instead of a legend.
Saved to `plots/<name>_input.png`, `plots/<name>_model.png` and `plots/<name>_flat_input.png`.

### sensor_plot_iso_limit(analysis, iso_limit)
Conversion gain and read noise vs ISO (log axis) with the range above `iso_limit` highlighted, where analog
gain no longer increases – saved to `plots/<name>_iso_limit.png`. E.g. for the D5100:
```octave
sensor_plot_iso_limit(sensor_characterize('Nikon_D5100'), 1600)
```

### sensor_print_model(analysis)
Prints the `camera` struct as code to paste into `sensor_models.m`.

### camera = sensor_models(name)
Database of fitted models (`"ASI2600MM_5deg"`, `"Nikon_D5100"`, `"Nikon_Z6_2"`). Besides the linear
fits it holds the measured `cgain` and `read_noise` [DN] for every setting.

### data = sensor_simulate(camera, shutter)
Generates synthetic statistics from a model (inverse of `sensor_fit`).

### sensor_validate(name)
Round-trip test: `sensor_models` → `sensor_simulate` → `sensor_fit` → `sensor_plot`.
The result should reproduce the input model parameters.

### sensor_compare(cameras, sky = 0.3, t = 60, penalty = 0.1)
Comparison table of cameras from `sensor_models` for a given sky flux [e-/s/px] and sub length [s]
(same optics and QE). Per camera: ISO/gain (default: lowest read noise in e-, or forced with
`{name, setting}`), cgain, read noise [e-], dark current, `t_min` – sub length at which read noise²
is `penalty` of the sky+dark variance (i.e. costs `penalty` more total time), noise variance per second
of integration `sky + D + RN²/t` and the resulting relative integration time for equal SNR.
```octave
sensor_compare({'ASI2600MM_5deg', {'Nikon_D5100', 1600}}, 0.3, 60)
```
```
camera            setting   cgain  RN [e-]  D [e-/s]  t_min   var/s   time
ASI2600MM_5deg        250   43.54    0.62    0.0017   12.7   0.308  1.00x
Nikon_D5100          1600    5.30    2.27    0.4444   69.4   0.830  2.70x
```
Under a dark sky (0.3 e-/s) the D5100 needs ~2.7× the time of the ASI2600 – almost entirely due to
dark current; under a bright sky (5 e-/s) the difference drops to ~10 %.

### sensor_plot_sub_length(cameras, skies = [0.03 0.3], t = logspace(0, log10(60), 61), penalty = 0.1)
Total integration time for equal SNR vs sub length, relative to an ideal noiseless camera (see
[formulas](#derived-quantities)). Shows two costs at once: dark current (height of the dashed long-sub
limit) and read noise (curve rising above it for short subs). One panel per sky flux in `skies`, one
line per camera (`cameras` as in `sensor_compare`), circles mark `t_min` – the sub length where read
noise costs `penalty` more time than the dashed limit. Log Y axis. Saved to `plots/sub_length.png`.
```octave
sensor_plot_sub_length({'ASI2600MM_5deg', {'Nikon_D5100', 1600}, {'Nikon_Z6_2', 800}}, [0.03 0.3])
```

## Outside the pipeline

### snr_vs_iso(name)
Experiment: SNR as a function of ISO for a fixed total exposure time.

### counts2mag
Estimating stellar magnitude from ADU counts – notes from a Deneb measurement.

## Results

### Nikon D5100 – ISO above 1600 is digital only

From ISO 1600 upwards cgain (5.3 DN/e-) and read noise (12.1 DN = 2.3 e-) stop changing:
analog gain ends at 1600, higher ISO is purely digital scaling (flats confirm it through Hi1/Hi2 =
ISO 12800/25600: cgain 5.47 / 5.55). SNR does not improve, only highlight headroom and bit depth are
lost – for astrophotography there is no point going above ISO 1600.

![D5100 – analog gain limit](plots/Nikon_D5100_iso_limit.png)

**Flats vs darks.** The D5100 has no black-level clamp, so its dark photon transfer is usable, but the
flats still correct cgain by −10 % at ISO ≥ 800 (5.90 → 5.30 DN/e- at 1600; 200–400 agree within 2 %).
The flat values double per ISO stop almost exactly (2.02, 1.99, 1.95, 1.94) while the dark values
scatter ±15 %: in darks the signal at ISO 1600 is only ~20 DN over 15 s against 12 DN of read noise,
and the dark variance has an excess over Poisson (RTS / blinking pixels) that biases the slope high.
With the flat cgain the full well at ISO 100 is 47 ke- (darks: 42; published ~44) and the read noise
at ISO 1600 2.27 e- (darks: 2.04; published ~2.5).

**Dark current depends on how long the camera has been on.** Per-ISO dark current from the same data
ranges 0.13–0.79 e-/s, which is physically impossible – sorted by capture time it rises monotonically
within each session: 0.13 e-/s at a cold start, 0.47 after 25 min, 0.75 after an hour of continuous
shooting; series taken cold the next morning are back at 0.16–0.22. The model value 0.44 e-/s is a
session average. Dark current halves per ~6 °C, so without the sensor temperature (or at least the
time since power-on) it is only known to within a factor of a few – this also explains most of the
gap to the Z6 II (measured warm after a long series).

Full model:

![D5100 – model](plots/Nikon_D5100_model.png)
![D5100 – input data](plots/Nikon_D5100_input.png)
![D5100 – flat input data](plots/Nikon_D5100_flat_input.png)

### ZWO ASI2600MM (−5 °C)

![ASI2600MM – model](plots/ASI2600MM_5deg_model.png)
![ASI2600MM – input data](plots/ASI2600MM_5deg_input.png)

### Sub length vs total integration time

Short subs cost integration time because every frame adds its read noise; dark current costs time
regardless of sub length. Both relative to an ideal noiseless camera (same optics and QE):

- Dark sky / narrowband (0.03 e-/s/px): the D5100 at ISO 1600 needs 16× the time even with perfect
  subs (dark current 0.44 e-/s is 15× the sky), the ASI2600 1.06×. With 10 s subs the ASI2600 needs
  2.3×, the D5100 33×. Neither camera reaches its `t_min` below 60 s (120 s and 109 s).
- Typical dark sky (0.3 e-/s/px): the D5100 limit is 2.5×, the ASI2600 1.01×; the ASI2600 is within
  10 % of its limit from ~13 s subs, the D5100 from ~70 s. With 10 s subs: ASI2600 1.1×, D5100 4.2×.
- The Z6 II at ISO 800 has a read noise close to the ASI2600 (1.5 vs 0.6 e-), so its `t_min` is short
  (13–16 s) – but its uncooled dark current of 1.4 e-/s puts the long-sub limit at 5.8× (0.3 e-/s) and
  49× (0.03 e-/s): sub length cannot fix dark current, only cooling can. Caveat: both DSLRs were
  measured at unknown, session-dependent sensor temperatures (see D5100 above), and the comparison
  is per pixel – the Z6 II pixel has 1.55× the area of the D5100's and collects correspondingly more sky.

The 10 % read-noise share (`penalty`) is the usual rule of thumb: it costs 10 % of total time, or ~5 %
of SNR at equal time. 5 % is a stricter common choice, but it doubles `t_min` – under 0.03 e-/s that
means 4-minute subs for the ASI2600, where guiding, satellites and saturation start to cost more than
the read noise saved.

![Integration time vs sub length](plots/sub_length.png)

### Nikon Z6 II – black-level clamp, dual conversion gain

From darks alone the Z6 II cannot be characterised: `sensor_fit` drops ISO < 1600 (slope not
significant) and above that gives an impossible cgain of 70–1100 DN/e-. Cause: the camera applies a
black-level clamp – it subtracts the mean dark current measured on shielded reference pixels and adds a
constant 1008 DN. The dark mean therefore grows ~20× slower than its noise implies (ISO 25600: +42 DN
in 15 s, but 216 DN of noise ≈ 19 e- of charge) and photon transfer loses its X axis. The noise itself
is fine: uniform across the frame, variance ∝ time and ∝ cgain². The D5100 (old design, bias 128, no
clamp) does not have this problem.

![Z6 II – dark input data](plots/Nikon_Z6_2_input.png)

With flats (A mode, −4 … +2 EV, `frames2stats.py` with the brightness-drift correction) the photon
transfer is clean over 65–4000 DN at every ISO and the model follows from `sensor_merge`:

- cgain 0.20 DN/e- at ISO 100, doubling per stop up to 45 DN/e- at 25600 – pure analog gain, no
  digital-only range like the D5100. Full well 16383 / 0.20 ≈ 80 ke-.
- **Dual conversion gain at ISO 800**: read noise in DN drops from 6.4 (ISO 640) to 2.2 (ISO 800),
  in electrons from 7.4 e- (ISO 100) / 4.4 e- (640) to 1.5 e- (800) and ~1.3–1.4 e- above. For
  astrophotography ISO 800 is the sweet spot: lowest read noise with the most headroom.
- Dark current 1.4 e-/s/pix from the variance growth (0.6–2.1 across ISO), reproduced in a second
  session with electronic shutter (1.2–1.3) – 3× the D5100 session average and 800× the cooled
  ASI2600; under a dark sky it dominates the noise budget (`sensor_compare`: 5.7× the integration time
  of the ASI2600 at 0.3 e-/s). Measured after a long tethered series with a warm sensor; a mirrorless
  sensor is powered continuously, so the gap to the D5100 is mostly temperature (see above).

![Z6 II – flat input data](plots/Nikon_Z6_2_flat_input.png)
![Z6 II – model](plots/Nikon_Z6_2_model.png)
