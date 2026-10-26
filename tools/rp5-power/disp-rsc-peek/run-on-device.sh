#!/bin/sh
# run-on-device.sh (2026-10-18): load disp_rsc_peek.ko on the RP5 and collect the display RSC dump. Run ON the device as
# root, display ACTIVE (screen on, not blanked): the module refuses to read while disp_cc_mdss_ahb_clk is off.
#   sh run-on-device.sh [wrapper=0|1]     ko expected at /var/tmp/rp5-power/disp_rsc_peek.ko
set -u
W=${1:-0}
echo "== $(date +%T) guards"
echo "-- mdss genpd:"; grep -E '^mdss_gdsc|^\s*/devices.*(display|mdss)' /sys/kernel/debug/pm_genpd/pm_genpd_summary | head -4
echo "-- dispcc clocks:"; grep -E 'disp_cc_mdss_ahb_clk|disp_cc_mdss_rscc|disp_cc_mdss_ahb_clk_src' /sys/kernel/debug/clk/clk_summary | awk '{print "   "$1, "en="$2, "prep="$3, "rate="$5}'
echo "-- panel:"; for c in /sys/class/drm/card*-DSI-1; do [ -e "$c" ] && echo "   $(basename $c) enabled=$(cat $c/enabled) dpms=$(cat $c/dpms)"; done
echo "-- iomem af2/af3:"; grep -i 'af2\|af3' /proc/iomem || echo "   (not mapped by the kernel: expected)"
echo "-- kernel.panic: $(sysctl -n kernel.panic) -> 15"; sysctl -q -w kernel.panic=15
echo "== $(date +%T) insmod wrapper=$W"
rmmod disp_rsc_peek 2>/dev/null
if insmod /var/tmp/rp5-power/disp_rsc_peek.ko wrapper=$W; then
  sleep 0.5
  echo "== dump (debugfs re-read; the insmod dump is in dmesg too):"; cat /sys/kernel/debug/disp_rsc_peek/dump
  echo "== dmesg tail:"; dmesg | tail -3
  echo "== cmd-db (for address -> name):"; cat /sys/kernel/debug/cmd-db > /var/tmp/rp5-power/cmd-db.txt && echo "   saved /var/tmp/rp5-power/cmd-db.txt ($(wc -l < /var/tmp/rp5-power/cmd-db.txt) lines)"
else
  echo "insmod FAILED: $?"; dmesg | tail -5
fi
echo "== $(date +%T) done (module left loaded: cat /sys/kernel/debug/disp_rsc_peek/dump re-reads; rmmod disp_rsc_peek to unload)"
