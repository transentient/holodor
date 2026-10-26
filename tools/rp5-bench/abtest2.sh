#!/bin/sh
# abtest2.sh <seconds-per-step> <cond> ... : scheduler conditions. Run as root. Leaves lavd in performance mode.
D=$1; shift; pid=$(ps -eo pid,comm | awk "\$2~/VampireSurv/{print \$1}" | head -1)
pin() { taskset -a -p $1 $pid >/dev/null 2>&1; }
lavd() { systemctl stop pocknix-lavd; [ "$1" = off ] && return; echo $1 > /var/lib/pocknix/lavd-mode; systemctl start pocknix-lavd; }
cur=performance; i=0
for c in "$@"; do
  i=$((i+1)); pin ff; want=performance
  case $c in base) ;; pinbig) pin f0 ;; eevdf) want=off ;; autopilot) want=autopilot ;; eevdfpin) want=off; pin f0 ;; autopin) want=autopilot; pin f0 ;; esac
  [ "$want" != "$cur" ] && { lavd $want; cur=$want; }
  sleep 4
  python3 /tmp/gsframes.py /tmp/sc_${i}_$c.csv $D >/dev/null
  echo "$i $c [sched: $(cat /sys/kernel/sched_ext/state)]: $(python3 /tmp/gsstats.py /tmp/sc_${i}_$c.csv)"
done
pin ff; [ "$cur" != performance ] && lavd performance
echo "restored: lavd $(cat /var/lib/pocknix/lavd-mode), sched_ext $(cat /sys/kernel/sched_ext/state)"
