#!/usr/bin/env python3
# Read the virtual Steam Deck controller's HID reports (what Steam receives) for N seconds and
# print the left/right stick int16 values seen at rest: min/max/last per axis.
import glob, os, struct, time, sys, select
secs = int(sys.argv[1]) if len(sys.argv) > 1 else 3
path = None
for h in glob.glob('/sys/class/hidraw/hidraw*'):
    u = open(h + '/device/uevent').read()
    if 'HID_ID=0003:000028DE' in u.upper() or '28DE' in u.upper():
        path = '/dev/' + os.path.basename(h); break
print("hidraw:", path, flush=True)
fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
t0 = time.time(); stats = {}
axes = {'LX': 48, 'LY': 50, 'RX': 52, 'RY': 54}   # Steam Deck input report v1 offsets (int16 LE)
n = 0
while time.time() - t0 < secs:
    r, _, _ = select.select([fd], [], [], 0.2)
    if not r: continue
    data = os.read(fd, 64)
    if len(data) < 56: continue
    n += 1
    for k, off in axes.items():
        v = struct.unpack_from('<h', data, off)[0]
        mn, mx = stats.get(k, (v, v)); stats[k] = (min(mn, v), max(mx, v))
        stats[k + '_last'] = v
print(f"{n} reports;", "  ".join(f"{k}: last {stats.get(k+'_last')} range {stats.get(k)}" for k in axes))
