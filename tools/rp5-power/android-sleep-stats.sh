#!/bin/bash
# android-sleep-stats.sh (2026-10-17): the RP5's OWN Android as the AOSS control. Run on fusor with the RP5 booted into
# Android and plugged into fusor over USB (adb as the shell user, no root needed: these are 0444 sysfs files).
# Procedure (Cliff): boot Android, screen off, UNPLUGGED, leave it 15+ min (or overnight: note battery % at screen-off
# and at pickup); then plug into fusor and run this. Counts are since boot, so the unplugged window is what shows up.
# What it answers: does this device's firmware ever reach aosd/cxsd/ddr low-power with the vendor kernel? Android boots
# with lpm_levels.sleep_disabled=1 on the cmdline (android-evidence-20261012/dmesg.txt); init normally clears it.
set -u
adb wait-for-device >/dev/null 2>&1 || { echo "no adb device"; exit 1; }
echo "== $(date -u +%FT%TZ) $(adb shell getprop ro.build.fingerprint 2>/dev/null)"
echo "== uptime: $(adb shell cat /proc/uptime)"
echo "== lpm sleep_disabled: $(adb shell cat /sys/module/lpm_levels/parameters/sleep_disabled 2>&1)"
echo "== battery: $(adb shell cat /sys/class/power_supply/battery/capacity 2>&1) % $(adb shell cat /sys/class/power_supply/battery/status 2>&1)"
echo "== /sys/power/rpmh_stats/master_stats (APSS = the AOP's view of the CPU subsystem's sleeps):"
adb shell cat /sys/power/rpmh_stats/master_stats 2>&1 | head -60
echo "== /sys/power/system_sleep/stats (aosd/cxsd/ddr; on the RP5's kona kernel this is ONE FILE, read 2026-10-18):"
adb shell 'if [ -d /sys/power/system_sleep/stats ]; then for d in /sys/power/system_sleep/stats/*; do echo "$d: count=$(cat $d/count 2>/dev/null) last_entered=$(cat $d/last_entered_at 2>/dev/null) accumulated=$(cat $d/accumulated_duration 2>/dev/null)"; done; else cat /sys/power/system_sleep/stats; fi' 2>&1 | head -24
echo "== batterystats (discharge since unplug; 5047 mAh pack):"
adb shell dumpsys batterystats 2>/dev/null | grep -E "^\s*(Time on battery|Time on battery screen off|Discharge:|Screen off discharge|Screen on:)" | head -6
echo "== other candidates:"
for p in /sys/power/system_sleep /sys/power/rpmh_stats /sys/kernel/debug/qcom_stats /d/rpmh_stats /d/system_sleep_stats; do echo "$p: $(adb shell ls $p 2>&1 | tr '\n' ' ' | cut -c1-200)"; done
echo "== suspend stats: $(adb shell cat /sys/kernel/debug/suspend_stats 2>&1 | head -5 | tr '\n' ' ')"
echo "== wakeup_sources active (needs root, may fail): $(adb shell 'cat /sys/kernel/debug/wakeup_sources' 2>&1 | head -2 | tr '\n' ' ')"
