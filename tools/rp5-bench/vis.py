import sys, csv, collections
for f in sys.argv[1:]:
    rows = list(csv.DictReader(open(f)))
    for col in ("app_ms", "visible_ms"):
        v = [float(r[col]) for r in rows if r[col]]
        if not v: print(f, col, "none"); continue
        s = sorted(v); n = len(s); q = lambda p: s[min(n-1, int(n*p))]
        b = collections.Counter(min(8, round(x / 8.333)) for x in v)   # in refresh periods of 120 Hz
        print(f"{f.split(chr(47))[-1]:12s} {col:10s} n={n} mean={sum(v)/n:.2f} p50={q(.5):.2f} p95={q(.95):.2f} p99={q(.99):.2f} | frames by length in 8.3 ms refreshes:", " ".join(f"{k}x:{100*b[k]//n}%" for k in sorted(b)))
