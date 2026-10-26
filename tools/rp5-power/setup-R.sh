# cycle R (kernel 46): cycle Q's configuration but the audio DSP left running (clk_summary readable), PCIe link down,
# BT/gamepad/USB/display NORMAL; clk core transitions + consumer-level clk_prepare/clk_unprepare kprobes (dev, con, stack)
# traced through the suspend -> which direct consumers of bi_tcxo still hold it at the flush.
systemctl --user -M deck@.host stop wireplumber.service pipewire-pulse.service pipewire.service pipewire.socket pipewire-pulse.socket 2>/dev/null; echo "audio stack stopped (ADSP left running)"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
sleep 15
echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove && echo "wifi endpoint removed"
setpci -s 00:00.0 CAP_EXP+10.w=0010:0010 && echo "root port Link Disable set"
T=/sys/kernel/tracing
echo "p:cp clk_prepare c=+0(+0(+0(%x0))):string d=+0(+16(%x0)):string n=+0(+24(%x0)):string" >> $T/kprobe_events
echo "p:cu clk_unprepare c=+0(+0(+0(%x0))):string d=+0(+16(%x0)):string n=+0(+24(%x0)):string" >> $T/kprobe_events
echo 1 > $T/events/kprobes/enable; echo stacktrace > $T/trace_options
echo 1 > $T/events/clk/clk_prepare/enable; echo 1 > $T/events/clk/clk_unprepare/enable
echo "kprobes + clk core events on; bi_tcxo prepare=$(cat /sys/kernel/debug/clk/bi_tcxo/clk_prepare_count)"
for d in a6f8800.usb a600000.usb 88e3000.phy 88e8000.phy; do printf "  %s=%s" $d "$(cat /sys/bus/platform/devices/$d/power/runtime_status 2>/dev/null)"; done; echo
