#!/bin/sh
# ob.sh — Odin bench helper. install <appid>... | status | launch <appid> | quit <appid> | uninstall <appid> | press <Button> | key <Key> | shot <name> | frames <tag> <secs> | state
R=deck@192.168.1.32; D=/var/tmp/spk
js() { ssh $R "python3 $D/steamjs.py '$1'"; }
case $1 in
install) shift; for a in "$@"; do js "SteamClient.Installs.OpenInstallWizard([$a], 0)" >/dev/null; sleep 3; js "SteamClient.Installs.ContinueInstall()" >/dev/null; sleep 2; done;;
status) js 'JSON.stringify(collectionStore.allAppsCollection.allApps.filter(a=>a.app_type==1&&(a.per_client_data[0].installed||a.per_client_data[0].bytes_total)).map(a=>[a.display_name,a.per_client_data[0].installed,a.per_client_data[0].bytes_downloaded,a.per_client_data[0].bytes_total,a.size_on_disk]))' | python3 -c '
import json,sys; l=json.loads(json.load(sys.stdin))
for n,i,d,t,s in l: print(f"{n[:34]:34s} installed={i!s:5s} dl={ (d or 0)/1e9:6.2f}/{(t or 0)/1e9:6.2f} GB disk={(int(s) if s else 0)/1e9:6.2f} GB")';;
launch) js "SteamClient.Apps.RunGame(\"$2\", \"\", -1, 100)" >/dev/null
  # first launches stop at Steam's interstitials (Steam Input page, cloud, etc.): press A while Steam is waiting
  for i in 1 2 3 4 5 6 7 8; do sleep 5; ssh $R "grep -a 'AppID $2' ~/.local/share/Steam/logs/console_log.txt | tail -1" | grep -q "waiting for user response" || continue
    ssh $R "grep -a 'AppID $2' ~/.local/share/Steam/logs/console_log.txt | tail -1 | cut -c22-120"; RP5=192.168.1.32 sh /home/cliff/projects/holodor/tools/rp5-bench/rp5pad.sh South; done;;
quit) js "SteamClient.Apps.TerminateApp(\"$2\", false)" >/dev/null;;
uninstall) js "SteamClient.Apps.UninstallApps([$2], false)" >/dev/null;;
opts) js "SteamClient.Apps.SetAppLaunchOptions($2, \"$3\")" >/dev/null;;
press) ssh $R "systemd-run --quiet --wait --pipe --collect sh -c 'busctl --system --timeout=4 call org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/CompositeDevice0 org.shadowblip.Input.CompositeDevice SendButtonChord as 1 Gamepad:Button:$2'";;
key) ssh $R "systemd-run --quiet --wait --pipe --collect sh -c 'busctl --system --timeout=4 call org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/CompositeDevice0 org.shadowblip.Input.CompositeDevice SendButtonChord as 1 Keyboard:$2'";;
frames) ssh $R "cd $D && python3 gsframes.py $2.csv $3 >/dev/null 2>&1; python3 gsstats.py $2.csv; python3 vis.py $2.csv | tail -1";;
shot) RP5SHOT_DIR=$PWD sh /home/cliff/projects/holodor/tools/rp5-bench/rp5shot.sh $2 192.168.1.32 >/dev/null;;
waitfocus) for i in $(seq 1 $3); do f=$(ssh $R "DISPLAY=:0 xprop -root" 2>/dev/null | grep "GAMESCOPE_FOCUSED_APP(" | tr -dc 0-9); [ "$f" = "$2" ] && { echo "focused after $((i*5)) s"; exit 0; }; sleep 5; done; echo "NOT focused (last $f)"; exit 1;;
state) ssh $R 'DISPLAY=:0 xprop -root | grep "GAMESCOPE_FOCUSED_APP(\|FPS_LIMIT" | tr "\n" " "; echo; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1; cat /sys/class/devfreq/*gpu*/cur_freq 2>/dev/null; df -h / | tail -1';;
esac
# extra verbs
