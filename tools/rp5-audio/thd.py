#!/usr/bin/env python3
# thd.py <wav> [f0=1000] : level of f0 and its 2nd/3rd harmonics over the middle of the tone (dBFS, dBc)
import sys, wave, math
w = wave.open(sys.argv[1]); ch = w.getnchannels(); sw = w.getsampwidth(); fs = w.getframerate(); d = w.readframes(w.getnframes()); w.close()
s = [int.from_bytes(d[i:i+sw], "little", signed=True) for i in range(0, len(d), sw)]; x = s[0::ch]; full = float(1 << (8 * sw - 1))
f0 = float(sys.argv[2]) if len(sys.argv) > 2 else 1000.0
def g(seg, f):
    k = 2 * math.cos(2 * math.pi * f / fs); s1 = s2 = 0.0
    for v in seg: s0 = v + k * s1 - s2; s2 = s1; s1 = s0
    return 20 * math.log10(max(math.sqrt(max(s1 * s1 + s2 * s2 - k * s1 * s2, 0)) * 2 / len(seg) / math.sqrt(2), 1e-9) / full)
win = int(fs * 0.1); lv = [g(x[i:i + win], f0) for i in range(0, len(x) - win, win)]
m = max(lv); idx = [i for i, v in enumerate(lv) if v > m - 6]
a, b = (idx[0] + 2) * win, (idx[-1] - 1) * win; seg = x[a:b]
if len(seg) < win: seg = x
l1, l2, l3 = g(seg, f0), g(seg, 2 * f0), g(seg, 3 * f0); pk = 20 * math.log10(max(1, max(abs(v) for v in seg)) / full)
print("f0 %.1f dBFS  H2 %.0f dBc  H3 %.0f dBc  mic peak %.1f dBFS" % (l1, l2 - l1, l3 - l1, pk))
