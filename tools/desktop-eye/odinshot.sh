#!/bin/sh
# odinshot.sh <name> : screenshot the Odin desktop (KWin ScreenShot2) -> scratchpad/<name>.png (960x540)
S=$(dirname "$0"); R=deck@192.168.1.32
timeout 40 ssh -o ConnectTimeout=6 $R 'export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus; timeout 25 python3 -u /tmp/kwinshot.py /tmp/s.raw CaptureActiveScreen >/dev/null 2>&1; ls /tmp/s.raw >/dev/null' || { echo "shot failed"; exit 1; }
scp -q $R:/tmp/s.raw "$S/$1.raw" && ffmpeg -hide_banner -loglevel error -y -f rawvideo -pix_fmt bgra -s 1920x1080 -i "$S/$1.raw" -vf scale=960:540 "$S/$1.png" && rm -f "$S/$1.raw" && echo "$S/$1.png"
