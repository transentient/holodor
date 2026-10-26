#!/bin/sh
# sleepcycle-edge.sh pre|post <outdir> (2026-10-16): called from the temporary sleep.d hooks that sleep-cycle.sh installs.
# Snapshots at the suspend edge: qcom_stats counts, the fuel gauge's monotonic SOC (pm8150b 0x4009, 0-255 = 0.39 %
# per step, the finest battery measure the driver exposes) and voltage, /proc/interrupts, and (pre) the interconnect / clock / regulator
# summaries = what every consumer holds at the moment our hooks have run and the kernel suspend begins.
P=$1; O=$2
for s in aosd cxsd ddr adsp cdsp slpi; do f=/sys/kernel/debug/qcom_stats/$s; [ -r "$f" ] && printf "%s=%s " "$s" "$(awk '/Count/{print $2}' "$f")"; done > "$O/qs-$P"
printf "msoc=%s volt=%s " "$(grep -E '^4009: ' /sys/kernel/debug/regmap/0-02/registers 2>/dev/null | cut -d' ' -f2)" "$(cat /sys/class/power_supply/battery/voltage_now 2>/dev/null)" >> "$O/qs-$P"
date -u +%T.%N >> "$O/qs-$P"
cp /proc/interrupts "$O/irq-$P.txt"
if [ "$P" = pre ]; then
  cp /sys/kernel/debug/interconnect/interconnect_summary "$O/icc-pre.txt" 2>/dev/null
  cp /sys/kernel/debug/clk/clk_summary "$O/clk-pre.txt" 2>/dev/null
  cp /sys/kernel/debug/regulator/regulator_summary "$O/reg-pre.txt" 2>/dev/null
fi
exit 0
