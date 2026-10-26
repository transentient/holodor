#!/bin/sh
# gb.sh launch <appid> | shot <name> | frames <tag> <secs> | quit <appid> | state
R=deck@192.168.1.68; D=/var/tmp/spk
case $1 in
launch) ssh $R "python3 $D/steamjs.py 'SteamClient.Apps.RunGame(\"$2\", \"\", -1, 100)' >/dev/null";;
quit) ssh $R "python3 $D/steamjs.py 'SteamClient.Apps.TerminateApp(\"$2\", false)' >/dev/null";;
shot) RP5SHOT_DIR=$PWD sh ~/rp5-vs-hang/bin/rp5shot.sh $2;;
frames) ssh $R "cd $D && python3 gsframes.py $2.csv $3 >/dev/null 2>&1; python3 gsstats.py $2.csv; python3 vis.py $2.csv | tail -1";;
state) ssh $R 'DISPLAY=:0 xprop -root | grep "GAMESCOPE_FOCUSED_APP(\|FPS_LIMIT\|RATE_FEEDBACK" | tr "\n" " "; echo; top -bn1 -w 150 | sed -n 1,4p; top -bn1 -w 150 | sed -n 8,14p | cut -c1-120; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1; cat /sys/class/devfreq/*gpu*/cur_freq 2>/dev/null; cat /sys/class/power_supply/*/capacity 2>/dev/null | head -1; free -m | sed -n 2p';;
esac
