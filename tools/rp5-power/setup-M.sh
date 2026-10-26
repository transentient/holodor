# cycle M: cycle L plus the PCIe root complex (wifi) and the USB glue driver unbound (reboot restores everything)
echo 1dfa000.crypto > /sys/bus/platform/drivers/qcrypto/unbind && echo "qcrypto unbound"
systemctl --user -M deck@.host stop wireplumber.service pipewire-pulse.service pipewire.service pipewire.socket pipewire-pulse.socket 2>/dev/null; echo "audio stack stopped"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
A=$(for r in /sys/class/remoteproc/remoteproc*; do [ "$(cat $r/name)" = adsp ] && echo $r; done); echo stop > $A/state; echo "adsp: $(cat $A/state)"
rfkill block bluetooth; sleep 3
echo "998000 (BT uart) after rfkill block: $(cat /sys/bus/platform/devices/998000.serial/power/runtime_status)"
if [ "$(cat /sys/bus/platform/devices/998000.serial/power/runtime_status)" != suspended ]; then echo serial1-0 > /sys/bus/serial/drivers/hci_uart_qca/unbind && echo "hci_uart_qca unbound from serial1-0"; fi
echo serial0-0 > /sys/bus/serial/drivers/retroid-pocket-gamepad/unbind && echo "gamepad serdev driver unbound"
P=$(ls /sys/bus/platform/drivers/qcom-pcie/ | grep -E '^[0-9a-f]+\.pcie$' | head -1); echo "$P" > /sys/bus/platform/drivers/qcom-pcie/unbind && echo "PCIe RC $P unbound"
U=$(ls /sys/bus/platform/drivers/dwc3-qcom-legacy/ | grep -E '^[0-9a-f]+\.usb$' | head -1); echo "$U" > /sys/bus/platform/drivers/dwc3-qcom-legacy/unbind && echo "USB glue $U unbound"
sleep 8
for d in 888000.serial 998000.serial; do printf "  %s=%s" $d "$(cat /sys/bus/platform/devices/$d/power/runtime_status)"; done; echo
echo "  pcie bound: $(ls /sys/bus/platform/drivers/qcom-pcie/ | grep -c pcie) usb bound: $(ls /sys/bus/platform/drivers/dwc3-qcom-legacy/ | grep -c usb)"
for c in bi_tcxo bi_tcxo_ao gcc_pcie_0_aux_clk gcc_pcie_phy_aux_clk gcc_usb30_prim_master_clk cam_cc_gdsc_clk; do printf "  %s=%s/%s" $c "$(cat /sys/kernel/debug/clk/$c/clk_prepare_count 2>/dev/null)" "$(cat /sys/kernel/debug/clk/$c/clk_enable_count 2>/dev/null)"; done; echo
grep -E "gdsc" /sys/kernel/debug/pm_genpd/pm_genpd_summary | awk '$2 ~ /^on/ {printf "  %s=%s", $1, $2} END {print ""}'
