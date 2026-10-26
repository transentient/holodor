# cycle Y (kernel 51, 2026-10-16): the intended shipping audio config = the WCD938x nosleep rule lifted (jack detection
# verified with the codec bus clock-stopped: insert + remove both woke the bus via the TX SoundWire wake irq), everything
# else NORMAL, undocked, jack unplugged. Waits until the LPASS core votes are released before the suspend.
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
i=0; while [ $i -lt 90 ]; do [ "$(cat /sys/kernel/debug/clk/LPASS_HW_MACRO/clk_prepare_count)" = 0 ] && break; sleep 1; i=$((i + 1)); done
echo "nosleep rule lifted; LPASS_HW_MACRO=$(cat /sys/kernel/debug/clk/LPASS_HW_MACRO/clk_prepare_count) after ${i}s; adsp sleeps=$(awk '/Count/{print $2}' /sys/kernel/debug/qcom_stats/adsp); jack=$(amixer -c0 cget iface=CARD,name='Headphone Jack' | grep -oE ': values=(on|off)' | cut -d= -f2); battery $(cat /sys/class/power_supply/battery/capacity)% $(cat /sys/class/power_supply/battery/voltage_now) uV"
