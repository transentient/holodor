# cycle L: every userspace-removable suspect down at once (reversible; teardown reboots to restore audio/BT/controls)
echo 1dfa000.crypto > /sys/bus/platform/drivers/qcrypto/unbind && echo "qcrypto unbound"
systemctl --user -M deck@.host stop wireplumber.service pipewire-pulse.service pipewire.service pipewire.socket pipewire-pulse.socket 2>/dev/null; echo "audio stack stopped"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
A=$(for r in /sys/class/remoteproc/remoteproc*; do [ "$(cat $r/name)" = adsp ] && echo $r; done); echo stop > $A/state; echo "adsp: $(cat $A/state)"
rfkill block bluetooth; sleep 3
echo "998000 (BT uart) after rfkill block: $(cat /sys/bus/platform/devices/998000.serial/power/runtime_status)"
if [ "$(cat /sys/bus/platform/devices/998000.serial/power/runtime_status)" != suspended ]; then echo serial1-0 > /sys/bus/serial/drivers/hci_uart_qca/unbind && echo "hci_uart_qca unbound from serial1-0"; fi
echo serial0-0 > /sys/bus/serial/drivers/retroid-pocket-gamepad/unbind && echo "gamepad serdev driver unbound"
sleep 8
for d in 888000.serial 998000.serial 3200000.rxmacro 3220000.txmacro; do printf "  %s=%s" $d "$(cat /sys/bus/platform/devices/$d/power/runtime_status)"; done; echo
echo "  icc requests left: crypto=$(grep -c crypto /sys/kernel/debug/interconnect/interconnect_summary) serial=$(grep -cE '(888|998)000.serial' /sys/kernel/debug/interconnect/interconnect_summary) usb=$(grep -c 'a6f8800.usb' /sys/kernel/debug/interconnect/interconnect_summary)"
awk '/^ *(icc|interconnect)/{next} /^[^ ]/{n=$1; next} /serial|crypto/ && ($3+0>0 || $4+0>0) {print "   ", n, $1, $3, $4}' /sys/kernel/debug/interconnect/interconnect_summary | head -6
grep -E "^ *(LPASS_HW_MACRO|LPASS_HW_DCODEC|LPASS_CLK_ID_TX_CORE_MCLK|LPASS_CLK_ID_TX_CORE_NPL_MCLK|bi_tcxo|bi_tcxo_ao) " /sys/kernel/debug/clk/clk_summary | awk '{printf "  %s=%s", $1, $2} END {print ""}'
