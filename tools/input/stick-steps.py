#!/usr/bin/env python3
# Record every change of the left stick's Y axis (EVIOCGABS polled at ~200 Hz) and summarize the
# step sizes: a 40-count MCU change threshold shows as steps clustered around 40; smooth reporting
# shows mostly 1-5. Also prints rest values at start and end.
import evdev, time, sys, collections
from evdev import ecodes as E
dev = next(d for d in map(evdev.InputDevice, evdev.list_devices()) if 'rsinput' in (d.phys or ''))
secs = int(sys.argv[1]) if len(sys.argv) > 1 else 15
ax = E.ABS_Y
t0 = time.time(); last = dev.absinfo(ax).value; start = last
steps = []; changes = 0; hist = collections.Counter(); mn = mx = last
while time.time() - t0 < secs:
    v = dev.absinfo(ax).value
    if v != last:
        d = abs(v - last); steps.append(d); hist[min(d, 200)] += 1; changes += 1; last = v
        mn = min(mn, v); mx = max(mx, v)
    time.sleep(0.005)
end = dev.absinfo(ax).value
print(f"LY rest at start {start}, at end {end}; min {mn} max {mx}; {changes} changes in {secs}s")
if steps:
    steps.sort(); n = len(steps)
    print(f"step size: median {steps[n//2]}, p10 {steps[n//10]}, p90 {steps[(9*n)//10]}, max {steps[-1]}")
    print("histogram (step -> count):", " ".join(f"{k}:{c}" for k, c in sorted(hist.items())[:40]))
