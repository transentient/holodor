#!/bin/sh
# hpt.sh <tag> ["Ctl=val" ...]: full-scale 1 kHz (3 s) then 2 s digital silence; prints level, THD, and the noise floor
T=$1; shift; S=${JACK_DIR:-/var/tmp/jack}
Q=""; for a in "$@"; do Q="$Q '$a'"; done
ssh deck@192.168.1.68 "sleep 5; sh /var/tmp/spk/hpset.sh $Q"
sudo arecord -q -D hw:CODEC,0 -f S16_LE -c 2 -r 48000 -d 8 $S/hp.$T.wav & R=$!
sleep 1.5
ssh deck@192.168.1.68 "pw-play --target alsa_output.platform-sound.HiFi__Headphones__sink /var/tmp/spk/fs1k.wav"
wait $R; sudo chown cliff $S/hp.$T.wav
echo "$T: $(python3 $S/thd.py $S/hp.$T.wav 1000 2.6 3.6 | tr '\n' ' ')"
python3 - $S/hp.$T.wav <<'PY'
import sys,wave,struct,math
w=wave.open(sys.argv[1]); n=w.getnframes(); d=struct.unpack("<%dh"%(2*n),w.readframes(n)); fs=48000
for nm,a,b in (("floor while playing silence",5.6,6.3),("floor idle",0.2,1.0)):
    s=d[0::2][int(a*fs):int(b*fs)]; m=sum(s)/len(s); print("    %s: %.1f dBFS"%(nm,20*math.log10(max((sum((v-m)**2 for v in s)/len(s))**.5,0.01)/32768)))
PY
