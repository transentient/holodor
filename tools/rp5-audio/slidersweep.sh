#!/bin/sh
# slidersweep.sh <label> <file-on-rp5> <step-s> <v1> <v2> ... : step the RP5 speaker slider while a tone plays;
# prints the 1 kHz level per step and the change relative to the first step.
L=$1; F=$2; T=$3; shift 3; S=${SPK_DIR:-/tmp}; N=$#; cmds=""
for v in "$@"; do cmds="$cmds wpctl set-volume @DEFAULT_AUDIO_SINK@ $v; sleep $T;"; done
(ssh deck@${RP5:-192.168.1.68} "export XDG_RUNTIME_DIR=/run/user/\$(id -u); sleep 1; pw-play $F & sleep 1.5; date +%s.%N > /tmp/sweep_t0; $cmds kill %1 2>/dev/null" &)
t_rec=$(date +%s.%N); D=$(python3 -c "print(int($N*$T+6))")
sudo arecord -q -D hw:1,0 -f S24_3LE -c 2 -r 48000 -d $D $S/$L.wav 2>/dev/null; sudo chown $(id -u) $S/$L.wav
t0=$(ssh deck@${RP5:-192.168.1.68} cat /tmp/sweep_t0)
python3 - "$S/$L.wav" "$t_rec" "$t0" "$T" "$@" <<'PY'
import sys, wave, math
path, t_rec, t0, T = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]); steps = sys.argv[5:]
w = wave.open(path); fs = w.getframerate(); d = w.readframes(w.getnframes()); w.close()
s = [int.from_bytes(d[i:i+3], "little", signed=True) for i in range(0, len(d), 3)]; x = s[0::2]
def g(seg, f=1000.0):
    k = 2 * math.cos(2 * math.pi * f / fs); s1 = s2 = 0.0
    for v in seg: s0 = v + k * s1 - s2; s2 = s1; s1 = s0
    return 20 * math.log10(max(math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) * 2 / len(seg) / math.sqrt(2), 1e-9) / 8388608)
off = t0 - t_rec + 0.25; ref = None
for i, st in enumerate(steps):
    a = int((off + i * T + 0.5 * T) * fs); b = int((off + i * T + 0.95 * T) * fs); seg = x[a:b]
    if len(seg) < fs // 10: continue
    l = g(seg); ref = l if ref is None else ref
    print("  slider %5.0f %%   tone %6.1f dBFS   %+6.1f dB vs first" % (float(st) * 100, l, l - ref))
PY
