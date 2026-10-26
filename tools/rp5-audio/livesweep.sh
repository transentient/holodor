#!/bin/sh
# livesweep.sh <label> <file-on-rp5> <step-seconds> "<amixer cset args for step 1>" "<step 2>" ...
# Plays the file on the RP5 and applies each mixer step WHILE it plays (idle writes are unreliable on the
# WSA path). Records with the USB mic; prints 1 kHz level + THD per step (middle of each step).
L=$1; F=$2; T=$3; shift 3; S=${SPK_DIR:-/tmp}; N=$#; cmds=""
for c in "$@"; do cmds="$cmds amixer -q -D hw:0 cset $c; sleep $T;"; done
(ssh deck@${RP5:-192.168.1.68} "export XDG_RUNTIME_DIR=/run/user/\$(id -u); sleep 1; pw-play $F & sleep 1.5; date +%s.%N > /tmp/sweep_t0; $cmds kill %1 2>/dev/null" &)
t_rec=$(date +%s.%N); D=$(python3 -c "print(int($N*$T+6))")
sudo arecord -q -D hw:1,0 -f S24_3LE -c 2 -r 48000 -d $D $S/$L.wav 2>/dev/null; sudo chown $(id -u) $S/$L.wav
t0=$(ssh deck@${RP5:-192.168.1.68} cat /tmp/sweep_t0)
python3 - "$S/$L.wav" "$t_rec" "$t0" "$T" "$@" <<'PY'
import sys, wave, math
path, t_rec, t0, T = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]); steps = sys.argv[5:]
w = wave.open(path); fs = w.getframerate(); d = w.readframes(w.getnframes()); w.close()
s = [int.from_bytes(d[i:i+3], "little", signed=True) for i in range(0, len(d), 3)]; x = s[0::2]
def g(seg, f):
    k = 2 * math.cos(2 * math.pi * f / fs); s1 = s2 = 0.0
    for v in seg: s0 = v + k * s1 - s2; s2 = s1; s1 = s0
    return 20 * math.log10(max(math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) * 2 / len(seg) / math.sqrt(2), 1e-9) / 8388608)
off = t0 - t_rec + 0.25                       # recording starts ~0.25 s after t_rec (arecord open)
for i, st in enumerate(steps):
    a = int((off + i * T + 0.45 * T) * fs); b = int((off + i * T + 0.95 * T) * fs); seg = x[a:b]
    if len(seg) < fs // 10: print("  %-46s (outside recording)" % st); continue
    l1 = g(seg, 1000); pk = 20 * math.log10(max(1, max(abs(v) for v in seg)) / 8388608)
    print("  %-46s f0 %6.1f dBFS  H2 %4.0f dBc  H3 %4.0f dBc  peak %5.1f" % (st, l1, g(seg, 2000) - l1, g(seg, 3000) - l1, pk))
PY
