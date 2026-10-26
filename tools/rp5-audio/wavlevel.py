#!/usr/bin/env python3
# wavlevel.py <wav> [tone_hz] : rms / peak in dBFS; with tone_hz also the level of that tone (Goertzel)
# and how much its level moves across 50 ms windows.
import sys, wave, struct, math
w = wave.open(sys.argv[1]); n = w.getnframes(); ch = w.getnchannels(); sw = w.getsampwidth(); fs = w.getframerate()
d = w.readframes(n); w.close()
if sw == 2: s = struct.unpack("<%dh" % (len(d) // 2), d); full = 32768.0
else: s = [int.from_bytes(d[i:i+3], "little", signed=True) for i in range(0, len(d), 3)]; full = 8388608.0
x = s[0::ch]
db = lambda v: 20 * math.log10(max(v, 1e-9) / full)
rms = math.sqrt(sum(v * v for v in x) / len(x)); print("rms %.1f dBFS  peak %.1f dBFS" % (db(rms), db(max(abs(v) for v in x))), end="")
if len(sys.argv) > 2:
    f = float(sys.argv[2]); win = int(fs * 0.05); lv = []
    for i in range(0, len(x) - win, win):
        k = 2 * math.cos(2 * math.pi * f / fs); s1 = s2 = 0.0
        for v in x[i:i + win]: s0 = v + k * s1 - s2; s2 = s1; s1 = s0
        p = s1 * s1 + s2 * s2 - k * s1 * s2; lv.append(db(math.sqrt(max(p, 0)) * 2 / win / math.sqrt(2)))
    lv = lv[4:-2]; ls = sorted(lv)
    print("  tone %.0f Hz: median %.1f dBFS, min %.1f, max %.1f, swing %.1f dB" % (f, ls[len(ls)//2], ls[0], ls[-1], ls[-1] - ls[0]), end="")
print()
