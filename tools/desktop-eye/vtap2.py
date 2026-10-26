#!/usr/bin/env python3
# vtap2.py X Y [X Y ...]: like vtap.py but a slower, longer tap (press 150 ms, 1 s between), for UIs that need hover-then-click
import sys, time
from evdev import UInput, AbsInfo, ecodes as e
cap = {e.EV_KEY: [e.BTN_TOUCH],
       e.EV_ABS: [(e.ABS_X, AbsInfo(0, 0, 9999, 0, 0, 40)), (e.ABS_Y, AbsInfo(0, 0, 9999, 0, 0, 40)),
                  (e.ABS_MT_SLOT, AbsInfo(0, 0, 0, 0, 0, 0)), (e.ABS_MT_TRACKING_ID, AbsInfo(0, 0, 65535, 0, 0, 0)),
                  (e.ABS_MT_POSITION_X, AbsInfo(0, 0, 9999, 0, 0, 40)), (e.ABS_MT_POSITION_Y, AbsInfo(0, 0, 9999, 0, 0, 40))]}
ui = UInput(cap, name="claude-virtual-touch", input_props=[e.INPUT_PROP_DIRECT]); time.sleep(2.5)
a = [int(v) for v in sys.argv[1:]]; tid = 100
for x, y in zip(a[0::2], a[1::2]):
    for press in (0, 1):
        tid += 1
        ui.write(e.EV_ABS, e.ABS_MT_SLOT, 0); ui.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, tid)
        ui.write(e.EV_ABS, e.ABS_MT_POSITION_X, x); ui.write(e.EV_ABS, e.ABS_MT_POSITION_Y, y)
        ui.write(e.EV_ABS, e.ABS_X, x); ui.write(e.EV_ABS, e.ABS_Y, y)
        ui.write(e.EV_KEY, e.BTN_TOUCH, 1); ui.syn(); time.sleep(0.15)
        ui.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, -1); ui.write(e.EV_KEY, e.BTN_TOUCH, 0); ui.syn(); time.sleep(0.5)
    time.sleep(0.5)
ui.close()
