#!/usr/bin/env python3
# pumptest.py <wav> : analyse a recording of the "probe + bursts" signal (steady 1 kHz probe, 220 Hz bursts
# 0.5 s on / 0.5 s off). Reports the probe's level while a burst is playing vs between bursts.
# A linear chain keeps the probe level the same; a compander/limiter moves it = audible pumping.
import sys, wave, math
w = wave.open(sys.argv[1]); ch = w.getnchannels(); sw = w.getsampwidth(); fs = w.getframerate(); d = w.readframes(w.getnframes()); w.close()
s = [int.from_bytes(d[i:i+sw], "little", signed=True) for i in range(0, len(d), sw)]; x = s[0::ch]; full = float(1 << (8 * sw - 1))
def goertzel(seg, f):
    k = 2 * math.cos(2 * math.pi * f / fs); s1 = s2 = 0.0
    for v in seg: s0 = v + k * s1 - s2; s2 = s1; s1 = s0
    p = s1 * s1 + s2 * s2 - k * s1 * s2
    return 20 * math.log10(max(math.sqrt(max(p, 0)) * 2 / len(seg) / math.sqrt(2), 1e-9) / full)
win = int(fs * 0.05); P = []; B = []
for i in range(0, len(x) - win, win):
    seg = x[i:i + win]; P.append(goertzel(seg, 1000)); B.append(goertzel(seg, 220))
pm = sorted(P)[len(P) // 2]; idx = [i for i, p in enumerate(P) if p > pm - 15]          # where the probe is playing
if not idx: sys.exit("no probe found")
i0, i1 = idx[0] + 3, idx[-1] - 3
bmax = max(B[i0:i1]); on = [P[i] for i in range(i0, i1) if B[i] > bmax - 6]; off = [P[i] for i in range(i0, i1) if B[i] < bmax - 25]
med = lambda v: sorted(v)[len(v) // 2] if v else float("nan")
allp = sorted(P[i0:i1])
print("probe 1 kHz: between bursts %.1f dBFS, during bursts %.1f dBFS -> burst changes probe by %+.1f dB | probe range overall %.1f dB (p5..p95) | burst level %.1f dBFS" %
      (med(off), med(on), med(on) - med(off), allp[int(len(allp) * .95)] - allp[int(len(allp) * .05)], bmax))
