#!/bin/sh
# abtest.sh <seconds-per-step> <cond> [<cond> ...] : apply a condition, log frames, restore. Run as root.
D=$1; shift; pid=$(ps -eo pid,comm | awk "\$2~/VampireSurv/{print \$1}" | head -1)
gov() { for p in /sys/devices/system/cpu/cpufreq/policy*; do echo $1 > $p/scaling_governor; done; }
pin() { taskset -a -p $1 $pid >/dev/null 2>&1; }
i=0
for c in "$@"; do
  i=$((i+1)); gov schedutil; pin ff
  case $c in base) ;; govperf) gov performance ;; pinbig) pin f0 ;; both) gov performance; pin f0 ;; pinprime3) pin e0 ;; esac
  sleep 3
  python3 /tmp/gsframes.py /tmp/ab_${i}_$c.csv $D >/dev/null
  echo "$i $c: $(python3 /tmp/gsstats.py /tmp/ab_${i}_$c.csv)"
done
gov schedutil; pin ff
