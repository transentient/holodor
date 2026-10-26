#!/bin/sh
# hpq.sh <tag> <file> ["Ctl=val" ...]: set controls while the PCM is closed, play to the headphone sink, record the UCA202,
# print probe(1k)/burst(220) levels: steady (3.5 s) and mid-burst (4.1 s)
T=$1; F=$2; shift 2; S=${JACK_DIR:-/var/tmp/jack}
Q=""; for a in "$@"; do Q="$Q '$a'"; done
ssh deck@192.168.1.68 "sleep 5; sh /var/tmp/spk/hpset.sh $Q"
sudo arecord -q -D hw:CODEC,0 -f S16_LE -c 2 -r 48000 -d 9 $S/hp.$T.wav & R=$!
sleep 1.5
ssh deck@192.168.1.68 "timeout 6 pw-play --target alsa_output.platform-sound.HiFi__Headphones__sink /var/tmp/spk/$F"
wait $R; sudo chown cliff $S/hp.$T.wav
python3 $S/env.py $S/hp.$T.wav 1000 220 | awk -v t="$T" '$1=="3.5"{a=$0} $1=="4.1"{b=$0} END{print t" | steady:"a" | in burst:"b}' | tr -s ' '
