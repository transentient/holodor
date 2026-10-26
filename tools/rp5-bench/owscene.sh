#!/bin/sh
# owscene.sh <tag> [launch options]: Outer Wilds in-scene benchmark. Waits for focus, resumes, wakes, measures 30 s, quits.
T=$1; shift; O="$*"; R=deck@192.168.1.68; D=$(dirname "$0"); P="sh $HOME/rp5-vs-hang/bin/rp5pad.sh"
ssh $R "python3 /var/tmp/spk/steamjs.py 'SteamClient.Apps.SetAppLaunchOptions(753640, \"$O\")' >/dev/null"
sh $D/gb.sh launch 753640
for i in $(seq 1 60); do sleep 5; ssh $R 'DISPLAY=:0 xprop -root' 2>/dev/null | grep -q "GAMESCOPE_FOCUSED_APP(CARDINAL) = 753640" && break; done
# menu is up when the game presents ~30 fps steadily; give it 40 s after focus
sleep 90; $P South >/dev/null 2>&1; sleep 55; $P West >/dev/null 2>&1; sleep 3; $P West >/dev/null 2>&1; sleep 25
sh $D/gb.sh shot ow_$T >/dev/null
echo "== $T [$O]"; sh $D/gb.sh frames ow_$T 30 | head -1 | cut -c1-120; ssh $R 'sh /var/tmp/spk/thr.sh OuterWilds 5 | tail -1'
sh $D/gb.sh quit 753640; sleep 10
