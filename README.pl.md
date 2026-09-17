# Charakterystyka sensora kamery

[🇬🇧 English](README.md) | 🇵🇱 Polski

Wyznaczanie modelu szumu sensora (bias, egain, read noise, dark current) z serii
klatek dark o różnych ISO/gain i czasach ekspozycji.
Metoda: https://www.brisk.org.uk/photog/d3readn.html

## Układ katalogów

```
frames/<kamera>/          klatki dark w FITS (kamery astro zapisują tu bezpośrednio)
frames/<kamera>/raw/      DSLR: pliki RAW (NEF itp.), mogą być w podkatalogach
frames/<kamera>/fits/     DSLR: FITS wygenerowane przez raw2fits.sh
stats/<kamera>.csv        statystyki z frames2stats.py
plots/<kamera>_*.png      wykresy zapisywane automatycznie przez sensor_plot
```

Nazwa `<kamera>` jest kluczem w całym potoku: katalog klatek, plik CSV,
`analysis.name` i `case` w `sensor_models.m`.

## Potok

```
frames/<kamera>/raw/**/*.nef  (DSLR)
  │  ./gphoto2_take.sh          zdjęcia przez USB (opcjonalnie)
  │  ./raw2fits.sh <kamera>     RAW → FITS (Siril)
  ▼
frames/<kamera>/**/*.fit[s]   (pary klatek dla każdego ISO × ekspozycja)
  │  ./frames2stats.py <kamera>
  ▼
stats/<kamera>.csv            ISO; shutter [s]; average [DN]; sigma [DN]
  │  sensor_characterize('<kamera>')
  │    ├─ sensor_fit          dopasowania liniowe → struktura analysis
  │    ├─ sensor_plot         wykresy (fig 1: dane wejściowe, fig 2: model) → plots/<kamera>_{input,model}.png
  │    └─ sensor_print_model  drukuje gotowy kod struktury `camera`
  ▼
sensor_models.m               wklej wydrukowaną strukturę jako nowy `case`
```

## Krok po kroku – nowa kamera

1. Zrób pary klatek dark dla każdej kombinacji ISO/gain × czas ekspozycji
   (min. 2 klatki na kombinację, kilka czasów od bardzo krótkiego do długiego).
   DSLR przez USB: ustaw `ISOS`/`TIMES` w `gphoto2_take.sh` i odpal `./gphoto2_take.sh`
   – zapisze `frames/<kamera>/raw/dark_iso<ISO>_<czas>_<n>.nef`, np. `dark_iso800_0-01s_2.nef`
   (czas w sekundach, kropka zamieniona na `-`; nazwa kamery z `gphoto2 --auto-detect`).
2. Kamera astro: wrzuć FITS do `frames/<kamera>/` (mogą być w podkatalogach – skrypt szuka rekurencyjnie).
   DSLR: RAW do `frames/<kamera>/raw/` i skonwertuj:
   ```sh
   ./raw2fits.sh <kamera>            # → frames/<kamera>/fits/
   ```
3. Policz statystyki:
   ```sh
   ./frames2stats.py <kamera>        # → stats/<kamera>.csv
   ```
   Gain czytany jest z nagłówka `ISOSPEED` (DSLR) lub `GAIN` (kamery astro).
   Domyślnie liczona jest cała klatka bez żadnej selekcji pikseli; opcje `--win`/`--clip` tylko
   dla problematycznych danych (patrz opis skryptu).
4. W Octave:
   ```octave
   sensor_characterize('<kamera>')
   ```
5. Skopiuj wydruk z konsoli do `sensor_models.m` jako nowy `case`.

## Skrypty

### gphoto2_take.sh
Wykrywa jedyną podłączoną kamerę (`gphoto2 --auto-detect`), ustawia RAW i dla każdej kombinacji
`ISOS` × `TIMES` robi `FRAMES` (domyślnie 2) klatek do `frames/<kamera>/raw/`.
Wartości `TIMES` w formacie zgłaszanym przez `gphoto2 --get-config capturesettings/shutterspeed`.

### raw2fits.sh <kamera>
Znajduje wszystkie katalogi z RAW pod `frames/<kamera>/raw/` i konwertuje je Sirilem (bez debayeru,
32 bit) do `frames/<kamera>/fits/<katalog>_NNNNN.fit`. Nagłówki `ISOSPEED`/`EXPTIME` są zachowane.
Katalog `fits/` jest czyszczony przed konwersją.

### build_images.sh
Przegenerowuje wszystkie PNG w `plots/`: `sensor_characterize` dla każdego `stats/*.csv` plus
dodatkowe figury z listy `EXTRA` (`sensor_plot_iso_limit` dla D5100, `sensor_validate`).
Odpalaj po zmianach w skryptach Octave. Okna wykresów pojawiają się na chwilę (qt renderuje PNG
1:1 z ekranem); bez `DISPLAY` używa gnuplota (czcionki mniej wierne).

### frames2stats.py [--win N] [--clip S] <kamera>
Grupuje pliki FITS z `frames/<kamera>/` po (ISO, EXPTIME), dla każdej grupy bierze dwie pierwsze klatki i liczy
`average` = średnia, `sigma` = std(klatka1 − klatka2)/√2 z całej klatki.
Zapisuje `stats/<kamera>.csv` (rozdzielany `;`).

Domyślnie żadne piksele nie są odrzucane – szum kamery ma ciężkie ogony (piksele RTS itp.) i to jest
realny szum, który model ma opisywać. Opcje do użycia tylko przy wadliwych danych:
- `--win N` – tylko centralne N×N px (np. gradient/amp glow przy krawędziach jak w D5100 z podmienionym firmware),
- `--clip S` – pomija piksele odległe o > S robustnych sigm (MAD) od mediany w którejkolwiek klatce
  (uszkodzone bloki o wartości 4128 w NEF z D5100, patrz `frames/Nikon_D5100/CORRUPTED.txt`).
  Uwaga: na szumie z ciężkimi ogonami zaniża sigmę (Z6 II: 0.5–5 %, do 13 % przy ISO 6400 / 1/100 s).

Użyte parametry: `Nikon_D5100` – `--win 4096 --clip 8`; `Nikon_Z6_2`, `ASI2600MM_5deg` – domyślne.

### analysis = sensor_characterize(name, min_setting = [])
Główne wejście. Wczytuje `stats/<name>.csv` → `sensor_fit` → `sensor_plot` → `sensor_print_model`.
Zwraca strukturę `analysis` (np. do `sensor_plot_iso_limit`).

### analysis = sensor_fit(data, min_setting = [])
Z macierzy `[ISO shutter average sigma]` liczy dla każdego ISO:
- `bias` – przecięcie prostej average(shutter)
- `dark_rate` [DN/s] – nachylenie prostej average(shutter)
- `egain` [DN/e-] – nachylenie prostej sigma²(average − bias) (photon transfer)
- `read_noise` [DN] – √ przecięcia tej prostej
- `dark_current` [e-/s/pix] – `dark_rate / egain`
- `iso2egain`, `egain2read_noise` – dopasowania liniowe między ISO i parametrami;
  `has_iso` mówi, czy ISO skaluje się liniowo (DSLR) czy logarytmicznie (gain 0.1 dB, kamery astro)
- `setting` – wartości ISO/gain tak jak ustawione w kamerze (do etykiet)

Liczba czasów może być różna dla różnych ISO (brakujące pola są `NaN`).

**Minimalne ISO/gain.** Photon transfer wymaga, żeby sygnał darka wyraźnie rósł w serii. Przy niskim
ISO/gain w kamerach z małym prądem ciemnym (chłodzone astro, nowoczesne DSLR) przybywa < 1 e-,
a wariancja rośnie głównie przez gorące piksele – nachylenie jest przypadkowe. `sensor_fit` liczy
dla każdego ustawienia istotność nachylenia (nachylenie / jego błąd standardowy) i odrzuca wszystko
poniżej najniższego ustawienia, od którego w górę wszystkie mają t ≥ 10. Odrzucone ustawienia są
wypisywane (`analysis.excluded`, `analysis.min_setting`) i nie trafiają na wykresy ani do modelu.
W astrofoto niskie ISO/gain i tak się nie używa. `min_setting` wymusza próg ręcznie (0 = wszystko).
Efekt: D5100 – wszystko od ISO 100; ASI2600 – od gain 150; Z6 II – od ISO 1600.

### sensor_plot(analysis)
Fig 1 – dane wejściowe z dopasowaniami. Fig 2 – egain, read noise vs ISO, SNR vs ISO.
Linie kolorowane po log(ISO) (niebieski = najniższe, czerwony = najwyższe) z paskiem kolorów zamiast legendy.
Obie figury zapisywane do `plots/<name>_input.png` i `plots/<name>_model.png`.

### sensor_plot_iso_limit(analysis, iso_limit)
Egain i read noise vs ISO (oś log) z zaznaczonym zakresem powyżej `iso_limit`, gdzie wzmocnienie
analogowe już nie rośnie – zapis do `plots/<name>_iso_limit.png`. Np. dla D5100:
```octave
sensor_plot_iso_limit(sensor_characterize('Nikon_D5100'), 1600)
```

### sensor_print_model(analysis)
Drukuje strukturę `camera` w formie kodu do wklejenia w `sensor_models.m`.

### camera = sensor_models(name)
Baza dopasowanych modeli (`"ASI2600MM_5deg"`, `"Nikon_D5100"`). Oprócz dopasowań
liniowych zawiera zmierzone `egain` i `read_noise` [DN] dla każdego ustawienia.

### data = sensor_simulate(camera, shutter)
Generuje syntetyczne statystyki z modelu (odwrotność `sensor_fit`).

### sensor_validate(name)
Test round-trip: `sensor_models` → `sensor_simulate` → `sensor_fit` → `sensor_plot`.
Wynik powinien odtworzyć parametry wejściowego modelu.

### sensor_compare(cameras, sky = 0.3, t = 60)
Tabela porównawcza kamer z `sensor_models` dla zadanego strumienia nieba [e-/s/px] i długości klatki [s]
(ta sama optyka i QE). Dla każdej kamery: ISO/gain (domyślnie z najniższym read noise w e-, albo
wymuszone przez `{nazwa, ustawienie}`), egain, read noise [e-], prąd ciemny, `t_min` – długość klatki,
od której read noise² to 10 % wariancji nieba+darka, wariancja na sekundę integracji
`sky + D + RN²/t` i wynikający z niej względny czas integracji do tego samego SNR.
```octave
sensor_compare({'ASI2600MM_5deg', {'Nikon_D5100', 1600}}, 0.3, 60)
```
```
camera            setting   egain  RN [e-]  D [e-/s]  t_min   var/s   time
ASI2600MM_5deg        250   43.54    0.62    0.0017   12.7   0.308  1.00x
Nikon_D5100          1600    5.90    2.04    0.4012   59.4   0.771  2.50x
```
Przy ciemnym niebie (0.3 e-/s) D5100 potrzebuje ~2.5× czasu ASI2600 – prawie wyłącznie przez prąd
ciemny; pod jasnym niebem (5 e-/s) różnica spada do ~9 %.

## Poza potokiem

### snr_vs_iso(name)
Eksperyment: SNR w funkcji ISO dla stałego całkowitego czasu ekspozycji.

### counts2mag
Szacowanie jasności gwiazdowej (mag) z zliczeń ADU – notatki z pomiaru Deneba.

## Wyniki

### Nikon D5100 – ISO powyżej 1600 to tylko cyfra

Od ISO 1600 w górę egain (5.9 DN/e-) i read noise (12.1 DN = 2.1 e-) przestają się zmieniać:
wzmocnienie analogowe kończy się na 1600, wyższe ISO to wyłącznie skalowanie cyfrowe.
SNR nie rośnie, traci się tylko zapas na światła i głębię bitową – w astrofoto nie ma sensu
wychodzić ponad ISO 1600.

![D5100 – granica wzmocnienia analogowego](plots/Nikon_D5100_iso_limit.png)

Pełny model:

![D5100 – model](plots/Nikon_D5100_model.png)
![D5100 – dane wejściowe](plots/Nikon_D5100_input.png)

### ZWO ASI2600MM (−5 °C)

![ASI2600MM – model](plots/ASI2600MM_5deg_model.png)
![ASI2600MM – dane wejściowe](plots/ASI2600MM_5deg_input.png)

### Nikon Z6 II

`sensor_fit` odrzuca ISO < 1600 (nachylenie photon transfer nieistotne), ale i powyżej wynik jest
fizycznie niemożliwy: egain 70–1100 DN/e- (oczekiwane ~5–40), czyli pełna skala 14 bit = 15 e-
przy ISO 25600 i read noise 0.05 e-. Przyczyna: aparat robi black-level clamp – odejmuje od klatki
średni prąd ciemny zmierzony na zasłoniętych pikselach referencyjnych i dodaje stałą 1008 DN.
Średnia darka rośnie więc ~20× wolniej niż wynikałoby z jego szumu (przy ISO 25600: +42 DN w 15 s,
a szum 216 DN ≈ 19 e- ładunku), a photon transfer traci oś X. Sam szum jest w porządku: rozkład
jednorodny po klatce, wariancja ∝ czas i ∝ egain², spójnie ~1.2 e-/s prądu ciemnego. D5100 (stara
architektura, bias 128, bez clampu) tego problemu nie ma. Z darków Z6 II wiarygodne są: bias, read
noise w DN (1.6 → 113 DN) i tempo wzrostu wariancji; do egain potrzebne są flaty. Model nie jest w bazie.

![Z6 II – dane wejściowe](plots/Nikon_Z6_2_input.png)