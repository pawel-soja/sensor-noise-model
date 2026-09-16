#!/bin/bash

rm -rf all
mkdir all

OUT=$PWD/all
SRC=$PWD

cat << EOF > run.ssf

requires 0.99.4
set32bits

cd "$SRC/ISO 100"
convert iso100 -out=$OUT

cd "$SRC/ISO 125"
convert iso125 -out=$OUT

cd "$SRC/ISO 160"
convert iso160 -out=$OUT

cd "$SRC/ISO 200"
convert iso200 -out=$OUT

cd "$SRC/ISO 250"
convert iso250 -out=$OUT

cd "$SRC/ISO 320"
convert iso320 -out=$OUT

cd "$SRC/ISO 400"
convert iso400 -out=$OUT

cd "$SRC/ISO 500"
convert iso500 -out=$OUT

cd "$SRC/ISO 640"
convert iso640 -out=$OUT

cd "$SRC/ISO 800"
convert iso800 -out=$OUT

cd "$SRC/ISO 1000"
convert iso1000 -out=$OUT

cd "$SRC/ISO 1250"
convert iso1250 -out=$OUT

cd "$SRC/ISO 1600"
convert iso1600 -out=$OUT

cd "$SRC/ISO 2000"
convert iso2000 -out=$OUT

cd "$SRC/ISO 2500"
convert iso2500 -out=$OUT

cd "$SRC/ISO 3200"
convert iso3200 -out=$OUT

cd "$SRC/ISO 4000"
convert iso4000 -out=$OUT

cd "$SRC/ISO 5000"
convert iso5000 -out=$OUT

cd "$SRC/ISO 6400"
convert iso6400 -out=$OUT

EOF
siril -d /tmp -s $PWD/run.ssf
