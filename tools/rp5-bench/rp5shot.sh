#!/bin/sh
# rp5shot.sh <name> [host] : gamescope screenshot of the RP5's game-mode screen -> <dir>/<name>.png (960 px wide)
D=${RP5SHOT_DIR:-/tmp}; H=${2:-192.168.1.68}; R=deck@${H#*@}
ssh -o BatchMode=yes -o ConnectTimeout=6 $R 'rm -f /tmp/gamescope.png; xprop -display :0 -root -f GAMESCOPECTRL_DEBUG_REQUEST_SCREENSHOT 32c -set GAMESCOPECTRL_DEBUG_REQUEST_SCREENSHOT 1; for i in 1 2 3 4 5 6; do [ -s /tmp/gamescope.png ] && break; sleep 0.5; done; sleep 0.8' && scp -o BatchMode=yes -q $R:/tmp/gamescope.png "$D/$1.full.png" && ffmpeg -hide_banner -loglevel error -y -i "$D/$1.full.png" -vf "scale=960:-1" "$D/$1.png" && rm -f "$D/$1.full.png" && echo "$D/$1.png"
