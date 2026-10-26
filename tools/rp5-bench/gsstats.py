#!/usr/bin/env python3
# gsstats.py <frames.csv> : frame-pacing summary of a gsframes.py log (app frames only)
import sys, csv
app = [float(r["app_ms"]) for r in csv.DictReader(open(sys.argv[1])) if r["app_ms"]]
if not app: sys.exit("no app frames")
s = sorted(app); n = len(s); q = lambda p: s[min(n - 1, int(n * p))]
med = q(.5); mean = sum(app) / n
late = sum(1 for x in app if x > 1.5 * med); hitch = sum(1 for x in app if x > 3 * med)
jit = sum(abs(a - b) for a, b in zip(app, app[1:])) / max(1, n - 1)
print(f"frames={n} fps={1000/mean:.1f} ms: mean={mean:.2f} p50={med:.2f} p95={q(.95):.2f} p99={q(.99):.2f} max={s[-1]:.1f} | "
      f">1.5x median: {100*late/n:.2f}%  >3x median: {hitch} | frame-to-frame jitter {jit:.2f} ms")
