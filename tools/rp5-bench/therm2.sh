#!/bin/sh
# therm2.sh <out> <secs>: every 10 s: hottest zone, skin, pcb, battery temp (C), fan pwm, cpu7/gpu MHz, cpu7/gpu throttle state, battery current (mA) + voltage (mV)
O=$1; N=$(( ${2:-600} / 10 )); i=0
z() { v=$(for d in /sys/class/thermal/thermal_zone*; do [ "$(cat $d/type)" = "$1" ] && cat $d/temp 2>/dev/null; done); echo "${v:-0}"; }
cd() { for d in /sys/class/thermal/cooling_device*; do [ "$(cat $d/type)" = "$1" ] && cat $d/cur_state; done; }
B=$(ls -d /sys/class/power_supply/*battery* /sys/class/power_supply/bq* 2>/dev/null | head -1)
echo "t hot skin pcb batt fan f7 fg thr7 thrg mA mV" > $O
while [ $i -lt $N ]; do
  echo "$((i*10)) $(( $(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)/1000 )) $(( $(z skin-msm-thermal)/1000 )) $(( $(z pm8150l-pcb-thermal)/1000 )) $(( $(cat $B/temp 2>/dev/null || echo 0)/10 )) $(cat /sys/class/hwmon/hwmon*/pwm1 2>/dev/null | head -1) $(( $(cat /sys/devices/system/cpu/cpufreq/policy7/scaling_cur_freq)/1000 )) $(( $(cat /sys/class/devfreq/3d00000.gpu/cur_freq)/1000000 )) $(cd cpufreq-cpu7) $(cd devfreq-3d00000.gpu) $(( $(cat $B/current_now 2>/dev/null || echo 0)/1000 )) $(( $(cat $B/voltage_now 2>/dev/null || echo 0)/1000 ))" >> $O
  i=$((i+1)); sleep 10
done
