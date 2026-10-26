#!/usr/bin/env python3
# Poll the rsinput gamepad's stick axes via EVIOCGABS (works even while InputPlumber holds the grab).
import evdev, time, sys
from evdev import ecodes as E
dev = next(d for d in map(evdev.InputDevice, evdev.list_devices()) if 'rsinput' in (d.phys or ''))
axes = {'LX': E.ABS_X, 'LY': E.ABS_Y, 'RX': E.ABS_RX, 'RY': E.ABS_RY}
secs = int(sys.argv[1]) if len(sys.argv) > 1 else 20
print(f"device {dev.path} {dev.name}; ranges:", {k: (dev.absinfo(v).min, dev.absinfo(v).max) for k, v in axes.items()}, flush=True)
t0 = time.time(); last_print = t0
mn = {k: 9999 for k in axes}; mx = {k: -9999 for k in axes}; cur = {}
while time.time() - t0 < secs:
    for k, v in axes.items():
        val = dev.absinfo(v).value; cur[k] = val
        mn[k] = min(mn[k], val); mx[k] = max(mx[k], val)
    if time.time() - last_print >= 1.0:
        print(f"t={time.time()-t0:4.1f}s  " + "  ".join(f"{k}:{cur[k]:5d} [{mn[k]:5d}..{mx[k]:5d}]" for k in axes), flush=True)
        last_print = time.time(); mn = {k: 9999 for k in axes}; mx = {k: -9999 for k in axes}
    time.sleep(0.02)
