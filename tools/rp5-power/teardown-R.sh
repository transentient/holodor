T=/sys/kernel/tracing; echo 0 > $T/events/kprobes/enable; echo nostacktrace > $T/trace_options; echo > $T/kprobe_events
echo 0 > $T/events/clk/clk_prepare/enable; echo 0 > $T/events/clk/clk_unprepare/enable
systemd-run --on-active=30 --unit=sleepcycle-R-reboot -q systemctl reboot && echo "reboot scheduled in 30 s"
