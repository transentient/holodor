#!/bin/sh
# lrrun.sh <tag>: launch the L/R test "game" through Steam, record the speaker chain input, print driver + links
T=$1; rm -f /var/tmp/spk/mon.$T.wav
timeout 24 pw-record --target alsa_output.platform-sound.HiFi__Speaker__sink -P stream.capture.sink=true --channels 2 --rate 48000 --format s16 /var/tmp/spk/mon.$T.wav >/dev/null 2>&1 &
sleep 1
python3 /var/tmp/spk/steamjs.py 'SteamClient.Apps.RunGame("3044080", "", -1, 100)' >/dev/null
for i in $(seq 1 80); do sleep 0.25; pw-link -l | grep -q "^Guess" && break; done
sleep 1.5
P=$(ps -eo pid,args | awk '/S:.common.Guess/ && !/awk/ {print $1; exit}')
echo "$T driver: $(cat /proc/$P/task/*/comm 2>/dev/null | grep -i 'pulse\|pipewire' | sort -u | tr '\n' ' ') links: $(pw-link -l | grep -A1 '^Guess' | tr -s ' \n' ' ')"
wait; sleep 6
