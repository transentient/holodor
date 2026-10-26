#!/usr/bin/env python3
# loud.py <wav> : rms of the loudest 3 s of a recording (dBFS), and its crest factor
import sys, wave, math
w = wave.open(sys.argv[1]); fs = w.getframerate(); sw = w.getsampwidth(); ch = w.getnchannels(); d = w.readframes(w.getnframes()); w.close()
s = [int.from_bytes(d[i:i+sw], "little", signed=True) for i in range(0, len(d), sw)]; x = s[0::ch]; full = float(1 << (8 * sw - 1))
hop = fs // 10; e = [sum(v * v for v in x[i:i + hop]) for i in range(0, len(x) - hop, hop)]
best = max(range(len(e) - 30), key=lambda i: sum(e[i:i + 30])); seg = x[best * hop:(best + 30) * hop]
r = math.sqrt(sum(v * v for v in seg) / len(seg)); pk = max(abs(v) for v in seg)
print("%.1f dBFS rms (crest %.1f dB)" % (20 * math.log10(r / full), 20 * math.log10(pk / r)))
