#!/bin/bash
# dock-audio-test.sh <rp5-host> [label] : hands-free dock audio check. The RP5 plays a 1 kHz tone at a
# LOW level into the DisplayPort sink (profile HDMI); fusor records the dock's HDMI audio on the
# MacroSilicon capture dongle (ALSA card "Video") and reports level + dominant frequency.
# PASS = a 1 kHz tone well above the noise floor in the recording. Nothing plays on the RP5 speakers.
set -u
H=$1; L=${2:-dockaudio}; OUT=${OUT:-$HOME/dock-runs/audio/$L}; mkdir -p "$OUT"
SSH="ssh -o ConnectTimeout=5 -o BatchMode=yes deck@$H"
CARD=$(sed -n 's/^ *\([0-9]\+\) \[Video *\].*/\1/p' /proc/asound/cards | head -1)   # arecord -l shows nothing for a user without a seat; /proc/asound/cards always does
[ -n "$CARD" ] || { echo "no 'Video' capture card on fusor"; exit 1; }
echo "== RP5 audio state"; $SSH 'timeout 5 wpctl status 2>/dev/null | sed -n "/Audio/,/Video/p" | grep -E "Devices|Sinks|\*|HDMI|HiFi|DisplayPort|Speaker" | head -12; systemctl --user is-active pocknix-dp-audio-switch; journalctl --user -u pocknix-dp-audio-switch --no-pager -n 6 -o cat' | tee "$OUT/state.txt"
echo "== record 6 s on fusor card $CARD while the RP5 plays 4 s of 1 kHz at -20 dBFS to the DP sink"
( sudo timeout 8 arecord -D hw:$CARD,0 -f S16_LE -r 48000 -c 2 -d 6 "$OUT/dock.wav" >/dev/null 2>&1 ) &
sleep 1
$SSH 'timeout 8 pw-play --target alsa_output.platform-sound.HDMI__DisplayPort__sink --volume 0.1 <(python3 -c "
import struct,math,sys
sr=48000; n=sr*4; a=0.1
sys.stdout.buffer.write(b\"RIFF\"+struct.pack(\"<I\",36+n*4)+b\"WAVEfmt \"+struct.pack(\"<IHHIIHH\",16,1,2,sr,sr*4,4,16)+b\"data\"+struct.pack(\"<I\",n*4))
for i in range(n):
    v=int(32767*a*math.sin(2*math.pi*1000*i/sr)); sys.stdout.buffer.write(struct.pack(\"<hh\",v,v))
") 2>&1 | tail -2'
wait
python3 - "$OUT/dock.wav" <<'PY'
import sys,wave,struct,math
w=wave.open(sys.argv[1]); n=w.getnframes(); fr=w.getframerate(); d=w.readframes(n); w.close()
s=struct.unpack("<%dh"%(len(d)//2),d)[0::2]
if not s: print("capture: empty"); sys.exit(1)
rms=math.sqrt(sum(x*x for x in s)/len(s)); db=20*math.log10(rms/32768) if rms>0 else -120
# crude dominant-frequency estimate: zero crossings over the middle 2 s
mid=s[fr*2:fr*4]; zc=sum(1 for i in range(1,len(mid)) if (mid[i-1]<0)<=(mid[i]>=0) and (mid[i-1]<0)!=(mid[i]<0)); f=zc/2/2.0
print("capture: rms %.1f dBFS, ~%.0f Hz (zero crossings), %d frames" % (db, f, n))
print("RESULT:", "PASS" if db > -45 and 900 < f < 1100 else "FAIL")
PY
