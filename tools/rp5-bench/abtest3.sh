#!/bin/sh
# abtest3.sh <secs> <cond>... : game already pinned to 4-7 by pocknix-game-affinity. Conditions on top of that.
D=$1; shift; pid=$(ps -eo pid,comm | awk "\$2~/VampireSurv/{print \$1}" | head -1)
gov() { for p in /sys/devices/system/cpu/cpufreq/policy*; do echo $1 > $p/scaling_governor; done; }
i=0
for c in "$@"; do
  i=$((i+1)); gov schedutil; taskset -a -c -p 4-7 $pid >/dev/null 2>&1
  case $c in pinned) ;; govperf) gov performance ;; mainprime) taskset -c -p 7 $pid >/dev/null ;; mainprime_gov) taskset -c -p 7 $pid >/dev/null; gov performance ;; esac
  sleep 3
  python3 /tmp/gsframes.py /tmp/c_${i}_$c.csv $D >/dev/null
  echo "$i $c: $(python3 /tmp/gsstats.py /tmp/c_${i}_$c.csv | sed -E "s/ms: mean=[0-9.]+ //; s/ \| >1.5x.*jitter/ | jitter/") | $(python3 /tmp/vis.py /tmp/c_${i}_$c.csv | grep visible | sed "s/.*refreshes: //")"
done
gov schedutil; taskset -a -c -p 4-7 $pid >/dev/null 2>&1
