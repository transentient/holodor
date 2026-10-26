#!/usr/bin/env python3
# gsminutes.py <frames.csv> [samples.log] : per-minute frame pacing (+ sampler columns if given)
import sys, csv, re
rows = [(float(r["t_s"]), float(r["app_ms"])) for r in csv.DictReader(open(sys.argv[1])) if r["app_ms"]]
t0 = rows[0][0]; mins = {}
for t, a in rows: mins.setdefault(int((t - t0) // 60), []).append(a)
print("min   fps  p50ms  p95ms  p99ms  maxms  >33ms  >50ms")
for m in sorted(mins):
    s = sorted(mins[m]); n = len(s); q = lambda p: s[min(n - 1, int(n * p))]
    print(f"{m:3d} {1000*n/sum(s):5.1f} {q(.5):6.1f} {q(.95):6.1f} {q(.99):6.1f} {s[-1]:6.0f} {sum(1 for x in s if x > 33.4):6d} {sum(1 for x in s if x > 50):6d}")
