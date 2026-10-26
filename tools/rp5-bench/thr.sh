#!/bin/sh
# thr.sh <comm-regex> [secs]: per-thread CPU % of the matching process over <secs>, top 8, plus GPU busy and clocks
P=$(ps -eo pid,comm | awk -v r="$1" '$2~r{print $1; exit}'); S=${2:-5}
a=$(mktemp); for t in /proc/$P/task/*; do echo "$(basename $t)|$(cat $t/comm)|$(awk '{print $14+$15}' $t/stat)"; done > $a
g1=$(cat /proc/$P/fdinfo/* 2>/dev/null | awk '/drm-engine-gpu/{s+=$2} END{print s+0}')
sleep $S
g2=$(cat /proc/$P/fdinfo/* 2>/dev/null | awk '/drm-engine-gpu/{s+=$2} END{print s+0}')
for t in /proc/$P/task/*; do id=$(basename $t); n=$(awk '{print $14+$15}' $t/stat); o=$(awk -F'|' -v i=$id '$1==i{print $3}' $a); echo "$(( (n - ${o:-0}) * 100 / (S*100) ))% $(cat $t/comm)"; done | sort -rn | head -8 | tr '\n' ';'; echo
echo "gpu busy $(( (g2-g1)/(S*10000000) ))%  gpu $(( $(cat /sys/class/devfreq/3d00000.gpu/cur_freq)/1000000 )) MHz  cpu4 $(( $(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq)/1000 ))  cpu7 $(( $(cat /sys/devices/system/cpu/cpufreq/policy7/scaling_cur_freq)/1000 ))  affinity $(taskset -cp $P | awk '{print $NF}')"
