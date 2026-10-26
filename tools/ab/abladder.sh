#!/bin/bash
# abladder.sh — run one Cyberpunk config through the built-in benchmark N times, hands-free.
# Usage (root): abladder.sh LABEL WIDTHxHEIGHT SCALING FSRQ FSRIDX LSFG RUNS
#   e.g. abladder.sh Q1080 1920x1080 FSR3 Quality 2 off 3 [GSCAP]
#        abladder.sh N720  1280x720  Off  Auto    0 off 2
# Writes UserSettings.json + /etc/pocknix/game-tweaks.json, relaunches the game, verifies the
# Graphics tab by screenshot, runs the bench RUNS times, screenshots each results screen
# (/tmp/ab-LABEL-N-res.png), samples presented fps (absample) into /var/lib/pocknix/ab/LABEL-N.csv.
set -u
L=$1; RES=$2; SCALING=$3; FSRQ=$4; FSRIDX=$5; LSFG=$6; RUNS=${7:-3}; GSCAP=${8:-none}
# GSCAP = gamescope debug_set_fps_limit for the whole config (live, no modeset); reset to 120 after.
W=${RES%x*}; SCALE=$(awk -v w="$W" 'BEGIN{printf "%.4f", 1920/w}')
# 720p X-root coords from tools/ab/README (window 1280 wide, scale 1.5) -> rescale for this window
xy() { awk -v x="$1" -v y="$2" -v s="$SCALE" 'BEGIN{printf "%d %d", x*1.5/s, y*1.5/s}'; }
SETTINGS_XY=$(xy 160 400); RESULTS_SETTINGS_XY=$(xy 270 591)
US="/home/deck/.local/share/Steam/steamapps/compatdata/1091500/pfx/drive_c/users/steamuser/AppData/Local/CD Projekt Red/Cyberpunk 2077/UserSettings.json"
log() { echo "$(date +%H:%M:%S) [$L] $*"; }

# 1. quit any running game (by pid, never pkill -f)
pids=$(pgrep -f "Cyberpunk2077[.]exe" || true)
if [ -n "$pids" ]; then log "killing game pids $pids"; kill $pids 2>/dev/null; sleep 8; kill -9 $pids 2>/dev/null; sleep 4; fi
while pgrep -f "Cyberpunk2077[.]exe" >/dev/null; do sleep 2; done
# give Steam time to register the exit; a run URL sent too early races its custom-arguments dialog
[ -n "$pids" ] && sleep 15

# 2. settings file
python3 - "$US" "$RES" "$SCALING" "$FSRQ" "$FSRIDX" <<'PY'
import json,sys
p,res,sc,q,qi=sys.argv[1:]; d=json.load(open(p))
def walk(o):
    if isinstance(o,dict):
        n=o.get("name")
        if n=="Resolution": o["value"]=res
        elif n=="ResolutionScaling": o["value"]=sc; o["index"]={"Off":1,"FSR3":2}.get(sc,o.get("index"))
        elif n=="FSR3": o["value"]=q; o["index"]=int(qi)
        elif n in("FSR3_FrameGeneration",): o["value"]=False
        elif n=="FrameGeneration": o["value"]="Off"; o["index"]=0
        elif n=="DynamicResolutionScaling": o["value"]=False
        for v in o.values(): walk(v)
    elif isinstance(o,list):
        for v in o: walk(v)
walk(d); json.dump(d,open(p,"w"),indent=2)
print("settings:",res,sc,q,qi)
PY
chown deck:deck "$US"

# 3. lsfg per-game block
python3 - "$LSFG" <<'PY'
import json,sys
p="/etc/pocknix/game-tweaks.json"; d=json.load(open(p)); on=sys.argv[1]!="off"
g=d.setdefault("games",{})
g["1091500"]={"enabled":True,"fexFlags":{},"fexProfile":"default","lsfg":{"enabled":on,"multiplier":"2"},"name":"Cyberpunk 2077"}
json.dump(d,open(p,"w"),indent=2); print("lsfg:", "on x2" if on else "off")
PY

# 4. launch, skip REDlauncher, Steam args dialog, warm-up, title -> main menu -> Settings -> Graphics
su deck -c 'echo "steam://run/1091500//--launcher-skip/" > ~/.steam/steam.pipe'
sleep 10; abkey.py enter >/dev/null 2>&1; sleep 10; pgrep -f "Cyberpunk2077[.]exe" >/dev/null || abkey.py enter >/dev/null 2>&1
log "launched; waiting for process"
for i in $(seq 1 60); do
  pid=$(pgrep -f "Cyberpunk2077[.]exe" | head -1); [ -n "$pid" ] && break
  # REDlauncher showing = --launcher-skip did not take (Steam's custom-arguments dialog missed);
  # it cannot be driven by virtual input, so fail fast instead of benchmarking a launcher.
  rl=$(pgrep -f "REDlauncher[.]exe" | head -1)
  if [ -n "$rl" ] && [ $i -gt 12 ]; then log "FAIL: REDlauncher up (pid $rl), launcher-skip missed; killing it"; kill $rl; exit 2; fi
  sleep 2
done
[ -z "${pid:-}" ] && { log "FAIL: game never started"; exit 1; }
log "pid $pid start $(ps -o lstart= -p $pid); env lsfg: $(tr '\0' '\n' </proc/$pid/environ | grep -o 'DISABLE_LSFGVK=1\|LSFGVK_ENV=1' | head -1)"
sleep 130
abkey.py space >/dev/null 2>&1; sleep 4
abmouse.py $SETTINGS_XY click >/dev/null 2>&1; sleep 3
abkey.py 3 3 3 >/dev/null 2>&1; sleep 3
su deck -c "XDG_RUNTIME_DIR=/run/user/1001 abshot.sh $L-graphics" >/dev/null 2>&1
log "graphics tab screenshot /tmp/ab-$L-graphics.png"

# 5. benchmark runs (optional composite-cadence cap first)
if [ "$GSCAP" != none ]; then su deck -c "XDG_RUNTIME_DIR=/run/user/1001 gamescopectl debug_set_fps_limit $GSCAP" >/dev/null 2>&1; log "gamescope fps limit set to $GSCAP"; sleep 2; fi
for n in $(seq 1 $RUNS); do
  [ $n -gt 1 ] && { abmouse.py $RESULTS_SETTINGS_XY click >/dev/null 2>&1; sleep 3; }
  systemd-run --quiet --unit=absample-$L-$n-$(date +%s) --collect absample.sh $L-$n 125
  sleep 1; abkey.py b sleep:1.5 enter >/dev/null 2>&1; log "run $n started"
  sleep 116
  su deck -c "XDG_RUNTIME_DIR=/run/user/1001 abshot.sh $L-$n-res" >/dev/null 2>&1
  log "run $n done -> /tmp/ab-$L-$n-res.png $(stat -c %s /tmp/ab-$L-$n-res.png 2>/dev/null)"
done
[ "$GSCAP" != none ] && su deck -c "XDG_RUNTIME_DIR=/run/user/1001 gamescopectl debug_set_fps_limit 120" >/dev/null 2>&1
log "config complete; gpu faults: $(dmesg | grep -ci 'gpu fault' || true)"
