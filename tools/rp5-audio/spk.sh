#!/bin/sh
# spk.sh <label> <file-on-rp5> : play a file on the RP5 speakers and record it with the USB mic on fusor.
S=${SPK_DIR:-/tmp}; (ssh deck@${RP5:-192.168.1.68} "export XDG_RUNTIME_DIR=/run/user/\$(id -u); sleep 1; pw-play $2" &)
sudo arecord -q -D hw:1,0 -f S24_3LE -c 2 -r 48000 -d ${3:-13} $S/$1.wav 2>/dev/null; sudo chown $(id -u) $S/$1.wav; sleep 1
