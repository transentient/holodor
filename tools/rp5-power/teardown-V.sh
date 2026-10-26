# cycle V teardown: functional check after the forced sync_state, then reboot (restores audio DSP, wifi, and the unsynced state)
sh "$(dirname "$(readlink -f "$0")")/teardown-normal-check.sh" 2>/dev/null || sh /var/tmp/rp5-power/teardown-normal-check.sh
echo "display after resume: $(cat /sys/class/drm/card*-DSI-1/enabled 2>/dev/null | head -1); domains ON: $(awk '/^[a-z]/ && $2=="on" {printf "%s ", $1}' /sys/kernel/debug/pm_genpd/pm_genpd_summary)"
systemd-run --on-active=30 --unit=sleepcycle-V-reboot -q systemctl reboot && echo "reboot scheduled in 30 s"
