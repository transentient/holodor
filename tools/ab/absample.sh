#!/bin/bash
# absample.sh <label> <seconds> -> /var/lib/pocknix/ab/<label>.csv  (run as root)
# 1 Hz: presented fps (DPU crtc total_framecount delta), GPU clock, GPU busy% (fdinfo of the
# heaviest drm client), temp, battery W, big-core clock. Run alongside a benchmark.
label=$1; secs=${2:-120}; out=/var/lib/pocknix/ab; mkdir -p $out; f=$out/$label.csv
crtc=/sys/kernel/debug/dri/0/crtc-0/status
gpu=$(ls -d /sys/class/devfreq/*gpu* 2>/dev/null | head -1)
fc() { grep -o 'total_framecount:[0-9]*' $crtc | cut -d: -f2; }
gpubusy() { # sum drm-engine-gpu ns over all fdinfo of pids named GameThread/wine/Cyberpunk, delta per second
  local t=0; for p in $(pgrep -f 'Cyberpunk2077|GameThread' 2>/dev/null); do
    for fd in /proc/$p/fdinfo/*; do v=$(grep -m1 -s 'drm-engine-gpu' $fd | awk '{print $2}'); [ -n "$v" ] && t=$((t+v)); done; done; echo $t; }
echo "t,presented_fps,gpu_mhz,gpu_busy_pct,temp_c,batt_w,big_khz" > $f
f0=$(fc); g0=$(gpubusy); t0=$(date +%s)
for ((i=0;i<secs;i++)); do sleep 1
  f1=$(fc); g1=$(gpubusy); t1=$(date +%s); dt=$((t1-t0)); [ $dt -lt 1 ] && dt=1
  fps=$(( (f1-f0)/dt )); busy=$(( (g1-g0)/dt/10000000 )); [ $busy -gt 100 ] && busy=100
  temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1); temp=$((temp/1000))
  w=$(awk -v v=$(cat /sys/class/power_supply/battery/voltage_now) -v a=$(cat /sys/class/power_supply/battery/current_now) 'BEGIN{printf "%.1f", v*a/1e12}')
  big=$(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_cur_freq 2>/dev/null)
  echo "$(date +%H:%M:%S),$fps,$(( $(cat $gpu/cur_freq)/1000000 )),$busy,$temp,$w,$big" >> $f
  f0=$f1; g0=$g1; t0=$t1
done
echo "wrote $f ($(wc -l < $f) rows)"
