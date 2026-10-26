#!/usr/bin/env python3
# frameloop.py [N] [seconds] : a frame-paced single-thread load (like an emulated game's main thread)
# plus two lighter helper processes. Fixed work per 16.67 ms frame; reports how long the work took
# and which cores it ran on. Compares scheduler/governor behaviour, not absolute game speed.
import os, sys, time, multiprocessing as mp
def work(n):
    x = 0
    for i in range(n):
        x = (x * 1103515245 + i) & 0xffffffff
    return x
def helper(n, period, stop):
    while time.monotonic() < stop:
        t = time.monotonic(); work(n); d = period - (time.monotonic() - t)
        if d > 0: time.sleep(d)
def calibrate():
    best = min((lambda t0: (work(20000), time.perf_counter() - t0)[1])(time.perf_counter()) for _ in range(30))
    return int(20000 * 0.009 / best)
N = int(sys.argv[1]) if len(sys.argv) > 1 and int(sys.argv[1]) > 0 else calibrate()
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 25
stop = time.monotonic() + secs + 1
for _ in range(2): mp.Process(target=helper, args=(N // 3, 1 / 60, stop), daemon=True).start()
frame = 1 / 60; times = []; cores = {}; nxt = time.monotonic() + 1
time.sleep(1)
while time.monotonic() < stop:
    t = time.perf_counter(); work(N); d = time.perf_counter() - t
    times.append(d * 1000); c = int(open('/proc/self/stat').read().rsplit(') ', 1)[1].split()[36]); cores[c] = cores.get(c, 0) + 1
    nxt += frame; s = nxt - time.monotonic()
    if s > 0: time.sleep(s)
    else: nxt = time.monotonic()
times.sort(); n = len(times); q = lambda p: times[min(n - 1, int(n * p))]
big = sum(v for k, v in cores.items() if k >= 4); prime = cores.get(7, 0)
print(f"N={N} frames={n} work_ms mean={sum(times)/n:.2f} p50={q(.5):.2f} p95={q(.95):.2f} p99={q(.99):.2f} max={times[-1]:.2f} "
      f"late={sum(1 for x in times if x > 16.67)} fps={n/secs:.1f} prime={100*prime//n}% big={100*(big-prime)//n}% little={100*(n-big)//n}%")
