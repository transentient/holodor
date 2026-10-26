# Input measurement tools (dev repo only)

Run on the device as root (`systemd-run --quiet --wait --pipe --collect python3 /tmp/<tool>`), python-evdev is on the image.

- stick-sample.py [secs]  one line per second: current value + range per stick axis (EVIOCGABS; works under InputPlumber grab)
- stick-steps.py [secs]   records every ABS_Y change; step-size histogram (40-count MCU threshold shows as 41-53; kernel-32 gives 9-13)
- deck-hid.py [secs]      reads the virtual Steam Deck hidraw (28DE): what Steam actually receives, int16 per stick axis

See HANDOFF 2026-09-28 and docs/stick-calibration-2026-09-27.md. Jack rig: ~/jack-measure on fusor.
