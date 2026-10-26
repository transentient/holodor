echo 0 > /sys/kernel/tracing/events/clk/clk_prepare/enable; echo 0 > /sys/kernel/tracing/events/clk/clk_unprepare/enable
rfkill unblock bluetooth && echo "bluetooth unblocked (saved state stays on)"
systemd-run --on-active=30 --unit=sleepcycle-P-reboot -q systemctl reboot && echo "reboot scheduled in 30 s"
