# cycle Y teardown: functional check, then the nosleep rule back on (installed state until bsp-sm8250 drops it)
sh /var/tmp/rp5-power/teardown-normal-check.sh
echo "adsp: $(tr "\n" " " < /sys/kernel/debug/qcom_stats/adsp)"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo on > $s/power/control; done; echo "nosleep rule restored"
