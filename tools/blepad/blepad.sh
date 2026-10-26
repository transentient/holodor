#!/bin/bash
# blepad.sh <command...> : send one command to the AtomS3U BLE gamepad over its USB serial port and print the reply.
#   blepad.sh status | press A | dpad right | stick L 0.5 0 | trig R 1 | hold B | release B
# Firmware: AtomS3U_BlePad/ (build + flash: see README.md). Port: /dev/ttyACM0 (group uucp; sudo until re-login).
PORT=${BLEPAD_PORT:-/dev/ttyACM0}
exec sudo /home/cliff/esp-venv/bin/python3 - "$PORT" "$*" <<'PY'
import sys, serial, time
port, cmd = sys.argv[1], sys.argv[2]
with serial.Serial(port, 115200, timeout=2) as s:
    s.reset_input_buffer(); s.write((cmd + "\n").encode()); s.flush()
    t0 = time.time()
    while time.time() - t0 < 2:
        line = s.readline().decode(errors="replace").strip()
        if line.startswith("ok") or line.startswith("err"):
            print(line); sys.exit(0 if line.startswith("ok") else 1)
print("err no-reply"); sys.exit(2)
PY
