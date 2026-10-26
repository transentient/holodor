#!/bin/sh
# odintap.sh SX SY [SX SY ...] : tap the Odin's desktop at screenshot coordinates (960x540 space).
# Mapping measured 2026-10-02: the virtual touchscreen gets the panel rotation, dev_x = 1 - sy, dev_y = sx.
a=""; while [ $# -ge 2 ]; do a="$a $(( (540 - $2) * 9999 / 540 )) $(( $1 * 9999 / 960 ))"; shift 2; done
timeout 60 ssh -o ConnectTimeout=6 deck@192.168.1.32 "systemd-run --quiet --wait --pipe --collect python3 /tmp/vtap.py $a 2>&1 | tail -3"
