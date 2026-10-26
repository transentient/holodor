#!/bin/sh
# runs ON the RP5: one line per second.
# v2 (2026-10-02): + the game's main-thread CPU %, whole-process CPU %, the core the main thread last
# ran on and that core's frequency, and the game's own GPU busy % (fdinfo drm-engine-gpu).
# v2.1: + shader_cpu = CPU % of the game's dxvk-shader* threads (shader-compile stutter shows up here).
# "Game" = the .exe process with the most CPU time (re-picked every 10 s).
st() { sed 's/.*) //' "$1" 2>/dev/null; }          # /proc/.../stat after the comm field
pick() { for d in /proc/[0-9]*; do case "$(tr '\0' ' ' < $d/cmdline 2>/dev/null)" in *.exe*) set -- $(st $d/stat); echo "$(( ${12} + ${13} )) ${d#/proc/}";; esac; done | sort -n | tail -1 | cut -d' ' -f2; }
gpu() { cat /proc/$1/fdinfo/* 2>/dev/null | awk '/drm-client-id/{id=$2} /drm-engine-gpu/{if(!(id in s)) s[id]=$2} END{t=0; for(i in s) t+=s[i]; printf "%.0f", t/1000000}'; }
shd() { cat /proc/$1/task/*/stat 2>/dev/null | awk '/\(dxvk-shader/{sub(/.*\) /,""); s+=$12+$13} END{print s+0}'; }
n=0; pid=""; pm=0; pp=0; pg=0; ps=0; pt=$(date +%s%N)
while :; do
  [ $(( n % 10 )) = 0 ] && pid=$(pick); n=$(( n + 1 ))
  ma=$(( $(awk '/MemAvailable/{print $2}' /proc/meminfo) / 1024 ))
  gf=$(cat /sys/class/devfreq/*gpu*/cur_freq 2>/dev/null | head -1)
  mt=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
  ld=$(cut -d' ' -f1 /proc/loadavg)
  now=$(date +%s%N); dt=$(( (now - pt) / 1000000 )); [ $dt -lt 1 ] && dt=1; pt=$now
  x=""
  if [ -n "$pid" ] && [ -r /proc/$pid/task/$pid/stat ]; then
    set -- $(st /proc/$pid/task/$pid/stat); m=$(( ${12} + ${13} )); core=${37}
    set -- $(st /proc/$pid/stat); p=$(( ${12} + ${13} )); g=$(gpu $pid); sc=$(shd $pid)
    cf=$(cat /sys/devices/system/cpu/cpu$core/cpufreq/scaling_cur_freq 2>/dev/null)
    x=" main_cpu=$(( (m - pm) * 1000 / dt )) proc_cpu=$(( (p - pp) * 1000 / dt )) main_core=$core core_kHz=$cf game_gpu=$(( (g - pg) * 100 / dt )) shader_cpu=$(( (sc - ps) * 1000 / dt ))"
    pm=$m; pp=$p; pg=$g; ps=$sc
  fi
  printf '%s mem_avail_MB=%s gpu_Hz=%s maxtemp=%s load=%s%s\n' "$(date +%T)" "$ma" "$gf" "$mt" "$ld" "$x"
  sleep 1
done
