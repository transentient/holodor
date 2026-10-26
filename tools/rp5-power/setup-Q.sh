# cycle Q (kernel 46): BT, gamepad, USB, crypto, display in their NORMAL state (the k45/k46 patches handle them);
# only the two unsolved subsystems are taken down: the audio DSP (stopped) and the wifi PCIe link (Link Disable).
systemctl --user -M deck@.host stop wireplumber.service pipewire-pulse.service pipewire.service pipewire.socket pipewire-pulse.socket 2>/dev/null; echo "audio stack stopped"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
sleep 15
A=$(for r in /sys/class/remoteproc/remoteproc*; do [ "$(cat $r/name)" = adsp ] && echo $r; done); echo stop > $A/state; echo "adsp: $(cat $A/state)"
echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove && echo "wifi endpoint removed"
setpci -s 00:00.0 CAP_EXP+10.w=0010:0010 && echo "root port Link Disable set"
sleep 3
for d in 888000.serial 998000.serial a6f8800.usb 1dfa000.crypto ae94400.phy; do printf "  %s=%s" $d "$(cat /sys/bus/platform/devices/$d/power/runtime_status)"; done; echo
echo "  bi_tcxo=$(cat /sys/kernel/debug/clk/bi_tcxo/clk_prepare_count) disp_cc_mdss_ahb_clk=$(cat /sys/kernel/debug/clk/disp_cc_mdss_ahb_clk/clk_prepare_count) (screen on now; the display releases at suspend)"
