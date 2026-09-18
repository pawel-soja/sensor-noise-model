# Charakterystyka sensora kamery

[🇬🇧 English](README.md) | 🇵🇱 Polski

Wyznaczanie modelu szumu sensora (bias, cgain, read noise, dark current) z serii
klatek dark o różnych ISO/gain i czasach ekspozycji.
Metoda: https://www.brisk.org.uk/photog/d3readn.html

## Układ katalogów

```
frames/<kamera>/<typ>/        <typ> = dark | flat (w przyszłości light)
frames/<kamera>/<typ>/*.fits  kamery astro zapisują tu FITS bezpośrednio (mogą być podkatalogi)
frames/<kamera>/<typ>/raw/    DSLR: pliki RAW (NEF itp.), mogą być w podkatalogach
frames/<kamera>/<typ>/fits/   DSLR: FITS wygenerowane przez raw2fits.sh
stats/<kamera>_<typ>.csv      statystyki z frames2stats.py
plots/<kamera>_*.png          wykresy zapisywane automatycznie przez sensor_plot
```

Nazwa `<kamera>` jest kluczem w całym potoku: katalog klatek, plik CSV,
`analysis.name` i `case` w `sensor_models.m`. Model szumu poniżej wyznaczany jest z `dark`;
klatki `flat` są na razie tylko zbierane (photon transfer z prawdziwym światłem, np. dla kamer
z black-level clamp jak Z6 II).

## Potok

```
frames/<kamera>/dark/raw/**/*.nef  (DSLR)
  │  ./gphoto2_take_darks.sh          zdjęcia przez USB (opcjonalnie)
  │  ./raw2fits.sh <kamera> dark       RAW → FITS (Siril)
  ▼
frames/<kamera>/dark/**/*.fit[s]   (pary klatek dla każdego ISO × ekspozycja)
  │  ./frames2stats.py <kamera> dark
  ▼
stats/<kamera>_dark.csv            ISO; shutter [s]; average [DN]; sigma [DN]
  │  sensor_characterize('<kamera>')
  │    ├─ sensor_fit          dopasowania liniowe → struktura analysis
  │    ├─ sensor_plot         wykresy (fig 1: dane wejściowe, fig 2: model) → plots/<kamera>_{input,model}.png
  │    └─ sensor_print_model  drukuje gotowy kod struktury `camera`
  ▼
sensor_models.m                    wklej wydrukowaną strukturę jako nowy `case`
```

## Krok po kroku – nowa kamera

1. Zrób pary klatek dark dla każdej kombinacji ISO/gain × czas ekspozycji
   (min. 2 klatki na kombinację, kilka czasów od bardzo krótkiego do długiego).
   DSLR przez USB: ustaw `ISOS`/`TIMES` w `gphoto2_take_darks.sh` i odpal `./gphoto2_take_darks.sh`
   – zapisze `frames/<kamera>/dark/raw/dark_iso<ISO>_<czas>_<n>.nef`, np. `dark_iso800_0-01s_2.nef`
   (czas w sekundach, kropka zamieniona na `-`; nazwa kamery z `gphoto2 --auto-detect`).
2. Kamera astro: wrzuć FITS do `frames/<kamera>/dark/` (mogą być w podkatalogach – skrypt szuka rekurencyjnie).
   DSLR: RAW do `frames/<kamera>/dark/raw/` i skonwertuj:
   ```sh
   ./raw2fits.sh <kamera> dark            # → frames/<kamera>/dark/fits/
   ```
3. Policz statystyki:
   ```sh
   ./frames2stats.py <kamera> dark        # → stats/<kamera>_dark.csv
   ```
   Gain czytany jest z nagłówka `ISOSPEED` (DSLR) lub `GAIN` (kamery astro).
   Domyślnie liczona jest cała klatka bez żadnej selekcji pikseli; opcje `--win`/`--clip` tylko
   dla problematycznych danych (patrz opis skryptu).
4. W Octave:
   ```octave
   sensor_characterize('<kamera>')
   ```
5. Skopiuj wydruk z konsoli do `sensor_models.m` jako nowy `case`.

## Model szumu i wzory

Wartość piksela klatki dark $S$ [DN] przy czasie ekspozycji $t$ [s]:

$$S = b + g (D t + n),$$

gdzie $b$ – bias [DN], $g$ – cgain [DN/e-], $D$ – prąd ciemny [e-/s/pix], $n$ – szum [e-].
`cgain` to *conversion gain* w DN na elektron – odwrotność słowa kluczowego FITS `EGAIN` /
camera gain $K$ u Janesicka [e-/ADU].
Sygnał darka $D t$ ma rozkład Poissona (wariancja = średnia w e-), read noise $\sigma_r$ [DN] nie zależy od $t$.

### Statystyki wejściowe (`frames2stats.py`)

Dla każdej pary klatek $F_1$, $F_2$ o tym samym (ISO, $t$):

$$\overline{S} = \mathrm{mean}(F_1), \qquad
\sigma = \frac{\mathrm{std}(F_1 - F_2)}{\sqrt{2}}$$

Odjęcie dwóch klatek usuwa fixed pattern (gorące piksele, struktura biasu); różnica ma dwa razy
większą wariancję czasową, stąd $\sqrt 2$.

### Dopasowania dla każdego ISO/gain (`sensor_fit`)

Wszystkie dopasowania to zwykła metoda najmniejszych kwadratów (`polyfit(..., 1)`) po serii czasów
jednego ISO.

1. **Średnia vs czas** – bias i dark rate:

$$\overline{S}(t) = \underbrace{g D}_{\text{dark rate}} \cdot t + \underbrace{b}_{\text{bias}}$$

2. **Photon transfer** – wariancja vs średnia po odjęciu biasu. Sygnał darka w e- jest Poissonowski,
   więc $\mathrm{var}[\text{e-}] = D t$, a po przeskalowaniu przez $g$:

$$\sigma^2 = g^2 D t + \sigma_r^2 = \underbrace{g}_{\text{cgain}} \cdot (\overline{S} - b) + \underbrace{\sigma_r^2}_{\text{read noise}^2}$$

   czyli nachylenie $\sigma^2$ względem $(\overline{S} - b)$ to cgain [DN/e-], a przecięcie to
   read noise² [DN²]; $\sigma_r = \sqrt{\text{przecięcie}}$ [DN].

3. **Prąd ciemny** – z obu nachyleń, uśredniony po wszystkich ISO (nie zależy od wzmocnienia):

$$D = \left\langle \frac{\text{dark rate}}{g} \right\rangle_{\text{ISO}} \quad [\text{e-/s/pix}]$$

4. **Istotność nachylenia** (automatyczne `min_setting`): dla $n$ punktów dopasowania photon transfer
   z resztami $r_i$,

$$t = \frac{g}{\mathrm{se}(g)}, \qquad
\mathrm{se}(g) = \sqrt{\frac{\sum r_i^2 / (n-2)}{\sum (x_i - \bar x)^2}}, \quad x_i = \overline{S}_i - b$$

   Ustawienia poniżej najniższego ISO, od którego wszystkie wyższe mają $t \ge 10$, są odrzucane.

### Dopasowania między ISO/gain

- `iso2cgain`: $g(\text{ISO}) = a \cdot \text{ISO} + c$; dla kamer astro gain $G$ w 0.1 dB jest najpierw
  przeliczany na skalę liniową $\text{ISO} = 100 \cdot 10^{G/200}$. Oba modele są próbowane na
  znormalizowanym $x$; wygrywa ten z mniejszą normą reszt (`has_iso` = liniowy).
- `cgain2read_noise`: $\sigma_r(g) = a g + c$ [DN].
- `cgain2iso`: odwrotność `iso2cgain`.

### Wielkości pochodne

- Read noise w elektronach: $\sigma_r[\text{e-}] = \sigma_r[\text{DN}] / g$.
- Pełna skala / clipping w e-: $2^{\text{bity}} / g$.
- `sensor_compare`: dla strumienia nieba $\Phi$ [e-/s/px], długości klatki $t$ i akceptowanego udziału
  read noise $p$ (domyślnie 0.1),

$$\text{var/s} = \Phi + D + \frac{\sigma_r[\text{e-}]^2}{t}, \qquad
t_{\min} = \frac{\sigma_r[\text{e-}]^2}{p (\Phi + D)}$$

  Względny czas integracji do tego samego SNR to stosunek var/s między kamerami.
- `sensor_plot_sub_length`: całkowity czas integracji do zadanego SNR przy klatkach o długości $t$,
  względem idealnej bezszumowej kamery $T_{\text{ideal}}$ (bez prądu ciemnego i read noise; to skończony
  czas, $\propto \Phi$):

$$\frac{T(t)}{T_{\text{ideal}}} = \frac{\text{var/s}(t)}{\Phi} = \frac{\Phi + D + \sigma_r[\text{e-}]^2 / t}{\Phi}$$

  Dla $t \to \infty$ każda krzywa dąży do własnej granicy $(\Phi + D)/\Phi$ – koszt samego prądu
  ciemnego; przy $t = t_{\min}$ jest $(1 + p)$ razy powyżej tej granicy.
- `sensor_simulate` (odwrotność): $\overline{S} = g \overline{P} + b$,
  $\sigma = \sqrt{g^2 \mathrm{var}(P) + \sigma_r(g)^2}$, gdzie $P \sim \text{Poisson}(D t)$.

## Skrypty

### gphoto2_take_darks.sh
Wykrywa jedyną podłączoną kamerę (`gphoto2 --auto-detect`), ustawia RAW i dla każdej kombinacji
`ISOS` × `TIMES` robi `FRAMES` (domyślnie 2) klatek do `frames/<kamera>/dark/raw/`.
Wartości `TIMES` w formacie zgłaszanym przez `gphoto2 --get-config capturesettings/shutterspeed`.
Istniejące pliki są pomijane, więc serię można wznowić lub rozszerzyć.

### gphoto2_take_flats.sh
To samo dla flatów (`frames/<kamera>/flat/raw/flat_iso<ISO>_<czas>_<n>.nef`) z równomiernie
oświetlonym panelem przed obiektywem. Seria czasów powinna pokrywać od kilku % do ~70 % pełnej skali
przy każdym ISO bez przepaleń – najpierw sprawdź najdłuższy czas z każdej grupy klatką testową i dobierz
jasność panelu albo przysłonę. Na razie tylko zbieranie; potok analizy używa darków.

Oba skrypty to cienkie nakładki konfiguracyjne na `gphoto2_capture.sh` (wykrycie kamery, plan
brakujących klatek, potwierdzenie z szacowanym czasem, pętla zdjęć).

### raw2fits.sh <kamera> <dark|flat>
Znajduje wszystkie katalogi z RAW pod `frames/<kamera>/<typ>/raw/` i konwertuje je Sirilem (bez debayeru,
32 bit) do `frames/<kamera>/<typ>/fits/<katalog>_NNNNN.fit`. Nagłówki `ISOSPEED`/`EXPTIME` są zachowane.
Katalog `fits/` jest czyszczony przed konwersją.

### build_images.sh
Przegenerowuje wszystkie PNG w `plots/`: `sensor_characterize` dla każdego `stats/*_dark.csv` plus
dodatkowe figury z listy `EXTRA` (`sensor_plot_iso_limit` dla D5100, `sensor_validate`, `sensor_plot_sub_length`).
Odpalaj po zmianach w skryptach Octave. Okna wykresów pojawiają się na chwilę (qt renderuje PNG
1:1 z ekranem); bez `DISPLAY` używa gnuplota (czcionki mniej wierne).

### frames2stats.py [--win N] [--clip S] <kamera> <dark|flat>
Grupuje pliki FITS z `frames/<kamera>/<typ>/` po (ISO, EXPTIME), dla każdej grupy bierze dwie pierwsze klatki i liczy
`average` = średnia, `sigma` = std(klatka1 − klatka2)/√2 z całej klatki.
Zapisuje `stats/<kamera>_<typ>.csv` (rozdzielany `;`).

Domyślnie żadne piksele nie są odrzucane – szum kamery ma ciężkie ogony (piksele RTS itp.) i to jest
realny szum, który model ma opisywać. Opcje do użycia tylko przy wadliwych danych:
- `--win N` – tylko centralne N×N px (np. gradient/amp glow przy krawędziach jak w D5100 z podmienionym firmware),
- `--clip S` – pomija piksele odległe o > S robustnych sigm (MAD) od mediany w którejkolwiek klatce
  (uszkodzone bloki o wartości 4128 w NEF z D5100, patrz `frames/Nikon_D5100/CORRUPTED.txt`).
  Uwaga: na szumie z ciężkimi ogonami zaniża sigmę (Z6 II: 0.5–5 %, do 13 % przy ISO 6400 / 1/100 s).

Użyte parametry: `Nikon_D5100` – `--win 4096 --clip 8`; `Nikon_Z6_2`, `ASI2600MM_5deg` – domyślne.

### analysis = sensor_characterize(name, min_setting = [])
Główne wejście. Wczytuje `stats/<name>_dark.csv` → `sensor_fit` → `sensor_plot` → `sensor_print_model`.
Zwraca strukturę `analysis` (np. do `sensor_plot_iso_limit`).

### analysis = sensor_fit(data, min_setting = [])
Z macierzy `[ISO shutter average sigma]` liczy dla każdego ISO (wzory w
[Model szumu i wzory](#model-szumu-i-wzory)):
- `bias` – przecięcie prostej average(shutter)
- `dark_rate` [DN/s] – nachylenie prostej average(shutter)
- `cgain` [DN/e-] – nachylenie prostej sigma²(average − bias) (photon transfer)
- `read_noise` [DN] – √ przecięcia tej prostej
- `dark_current` [e-/s/pix] – `dark_rate / cgain`
- `iso2cgain`, `cgain2read_noise` – dopasowania liniowe między ISO i parametrami;
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
Fig 1 – dane wejściowe z dopasowaniami. Fig 2 – cgain, read noise vs ISO, SNR vs ISO.
Linie kolorowane po log(ISO) (niebieski = najniższe, czerwony = najwyższe) z paskiem kolorów zamiast legendy.
Obie figury zapisywane do `plots/<name>_input.png` i `plots/<name>_model.png`.

### sensor_plot_iso_limit(analysis, iso_limit)
Conversion gain i read noise vs ISO (oś log) z zaznaczonym zakresem powyżej `iso_limit`, gdzie wzmocnienie
analogowe już nie rośnie – zapis do `plots/<name>_iso_limit.png`. Np. dla D5100:
```octave
sensor_plot_iso_limit(sensor_characterize('Nikon_D5100'), 1600)
```

### sensor_print_model(analysis)
Drukuje strukturę `camera` w formie kodu do wklejenia w `sensor_models.m`.

### camera = sensor_models(name)
Baza dopasowanych modeli (`"ASI2600MM_5deg"`, `"Nikon_D5100"`). Oprócz dopasowań
liniowych zawiera zmierzone `cgain` i `read_noise` [DN] dla każdego ustawienia.

### data = sensor_simulate(camera, shutter)
Generuje syntetyczne statystyki z modelu (odwrotność `sensor_fit`).

### sensor_validate(name)
Test round-trip: `sensor_models` → `sensor_simulate` → `sensor_fit` → `sensor_plot`.
Wynik powinien odtworzyć parametry wejściowego modelu.

### sensor_compare(cameras, sky = 0.3, t = 60, penalty = 0.1)
Tabela porównawcza kamer z `sensor_models` dla zadanego strumienia nieba [e-/s/px] i długości klatki [s]
(ta sama optyka i QE). Dla każdej kamery: ISO/gain (domyślnie z najniższym read noise w e-, albo
wymuszone przez `{nazwa, ustawienie}`), cgain, read noise [e-], prąd ciemny, `t_min` – długość klatki,
od której read noise² to `penalty` wariancji nieba+darka (czyli kosztuje `penalty` więcej czasu),
wariancja na sekundę integracji `sky + D + RN²/t` i wynikający z niej względny czas integracji do tego
samego SNR.
```octave
sensor_compare({'ASI2600MM_5deg', {'Nikon_D5100', 1600}}, 0.3, 60)
```
```
camera            setting   cgain  RN [e-]  D [e-/s]  t_min   var/s   time
ASI2600MM_5deg        250   43.54    0.62    0.0017   12.7   0.308  1.00x
Nikon_D5100          1600    5.90    2.04    0.4012   59.4   0.771  2.50x
```
Przy ciemnym niebie (0.3 e-/s) D5100 potrzebuje ~2.5× czasu ASI2600 – prawie wyłącznie przez prąd
ciemny; pod jasnym niebem (5 e-/s) różnica spada do ~9 %.

### sensor_plot_sub_length(cameras, skies = [0.03 0.3], t = logspace(0, log10(60), 61), penalty = 0.1)
Całkowity czas integracji do tego samego SNR w funkcji długości klatki, względem idealnej bezszumowej
kamery (patrz [wzory](#wielkości-pochodne)). Pokazuje dwa koszty naraz: prąd ciemny (wysokość kreskowanej
granicy długich klatek) i read noise (krzywa ponad nią przy krótkich klatkach). Jeden panel na strumień
nieba z `skies`, jedna linia na kamerę (`cameras` jak w `sensor_compare`), kółka oznaczają `t_min` –
długość klatki, przy której read noise kosztuje `penalty` więcej czasu niż kreskowana granica.
Oś Y logarytmiczna. Zapis do `plots/sub_length.png`.
```octave
sensor_plot_sub_length({'ASI2600MM_5deg', {'Nikon_D5100', 1600}}, [0.03 0.3])
```

## Poza potokiem

### snr_vs_iso(name)
Eksperyment: SNR w funkcji ISO dla stałego całkowitego czasu ekspozycji.

### counts2mag
Szacowanie jasności gwiazdowej (mag) z zliczeń ADU – notatki z pomiaru Deneba.

## Wyniki

### Nikon D5100 – ISO powyżej 1600 to tylko cyfra

Od ISO 1600 w górę cgain (5.9 DN/e-) i read noise (12.1 DN = 2.1 e-) przestają się zmieniać:
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

### Długość klatki a całkowity czas integracji

Krótkie klatki kosztują czas integracji, bo każda dokłada swój read noise; prąd ciemny kosztuje czas
niezależnie od długości klatki. Oba efekty względem idealnej bezszumowej kamery (ta sama optyka i QE):

- Ciemne niebo / wąskopasmowo (0.03 e-/s/px): D5100 przy ISO 1600 potrzebuje 14× więcej czasu nawet
  przy idealnych klatkach (prąd ciemny 0.40 e-/s to 13× niebo), ASI2600 1.06×. Przy klatkach 10 s
  ASI2600 potrzebuje 2.3×, D5100 28×. Żadna kamera nie osiąga `t_min` poniżej 60 s (120 s i 97 s).
- Typowe ciemne niebo (0.3 e-/s/px): granica D5100 to 2.3×, ASI2600 1.01×; ASI2600 jest w granicach
  10 % od swojej granicy od ~13 s, D5100 od ~60 s. Przy klatkach 10 s: ASI2600 1.1×, D5100 3.7×.

10 % udziału read noise (`penalty`) to typowa reguła kciuka: kosztuje 10 % czasu całkowitego albo ~5 %
SNR przy tym samym czasie. 5 % to częsty ostrzejszy wybór, ale podwaja `t_min` – przy 0.03 e-/s to
4-minutowe klatki dla ASI2600, gdzie prowadzenie, satelity i saturacja zaczynają kosztować więcej niż
zaoszczędzony read noise.

![Czas integracji vs długość klatki](plots/sub_length.png)

### Nikon Z6 II

`sensor_fit` odrzuca ISO < 1600 (nachylenie photon transfer nieistotne), ale i powyżej wynik jest
fizycznie niemożliwy: cgain 70–1100 DN/e- (oczekiwane ~5–40), czyli pełna skala 14 bit = 15 e-
przy ISO 25600 i read noise 0.05 e-. Przyczyna: aparat robi black-level clamp – odejmuje od klatki
średni prąd ciemny zmierzony na zasłoniętych pikselach referencyjnych i dodaje stałą 1008 DN.
Średnia darka rośnie więc ~20× wolniej niż wynikałoby z jego szumu (przy ISO 25600: +42 DN w 15 s,
a szum 216 DN ≈ 19 e- ładunku), a photon transfer traci oś X. Sam szum jest w porządku: rozkład
jednorodny po klatce, wariancja ∝ czas i ∝ cgain², spójnie ~1.2 e-/s prądu ciemnego. D5100 (stara
architektura, bias 128, bez clampu) tego problemu nie ma. Z darków Z6 II wiarygodne są: bias, read
noise w DN (1.6 → 113 DN) i tempo wzrostu wariancji; do cgain potrzebne są flaty. Model nie jest w bazie.

![Z6 II – dane wejściowe](plots/Nikon_Z6_2_input.png)