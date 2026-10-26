# cycle P (kernel 45): who holds the RPMh XO (bi_tcxo) at the suspend flush. Everything down as in O except the audio DSP
# (left running so clk_summary stays readable at the edge); clk core prepare/unprepare transitions traced through suspend.
systemctl --user -M deck@.host stop wireplumber.service pipewire-pulse.service pipewire.service pipewire.socket pipewire-pulse.socket 2>/dev/null; echo "audio stack stopped (ADSP left running)"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
sleep 15
rfkill block bluetooth; sleep 3; echo "BT uart: $(cat /sys/bus/platform/devices/998000.serial/power/runtime_status)"
echo serial0-0 > /sys/bus/serial/drivers/retroid-pocket-gamepad/unbind && echo "gamepad serdev driver unbound"
U=$(ls /sys/bus/platform/drivers/dwc3-qcom-legacy/ | grep -E '^[0-9a-f]+\.usb$' | head -1); echo "$U" > /sys/bus/platform/drivers/dwc3-qcom-legacy/unbind && echo "USB glue $U unbound"
echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove && echo "wifi endpoint removed"
setpci -s 00:00.0 CAP_EXP+10.w=0010:0010 && echo "root port Link Disable set"
echo 1 > /sys/kernel/tracing/events/clk/clk_prepare/enable; echo 1 > /sys/kernel/tracing/events/clk/clk_unprepare/enable; echo "clk core transition events on"
echo "bi_tcxo prepare=$(cat /sys/kernel/debug/clk/bi_tcxo/clk_prepare_count)"
