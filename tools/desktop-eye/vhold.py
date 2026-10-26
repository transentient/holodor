#!/usr/bin/env python3
# vhold.py KEY SECONDS: hold a keyboard key via a uinput keyboard (for "hold to confirm" prompts). KEY = evdev name, e.g. KEY_ENTER
import sys, time
from evdev import UInput, ecodes as e
key = getattr(e, sys.argv[1]); secs = float(sys.argv[2])
ui = UInput({e.EV_KEY: [key]}, name="claude-virtual-keyboard"); time.sleep(2.0)
ui.write(e.EV_KEY, key, 1); ui.syn(); time.sleep(secs); ui.write(e.EV_KEY, key, 0); ui.syn(); time.sleep(0.5); ui.close()
