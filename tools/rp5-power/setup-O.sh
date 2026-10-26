# cycle O (kernel 45): every known holder down, PCIe link disabled (unbind is forbidden); teardown reboots to restore
echo "crypto icc (k45 runtime PM): $(awk '/crypto/ && ($3+0>0 || $4+0>0)' /sys/kernel/debug/interconnect/interconnect_summary | wc -l) nonzero requests; runtime=$(cat /sys/bus/platform/devices/1dfa000.crypto/power/runtime_status)"
echo "bi_tcxo before: prepare=$(cat /sys/kernel/debug/clk/bi_tcxo/clk_prepare_count) cam_cc_xo_clk_src=$(cat /sys/kernel/debug/clk/cam_cc_xo_clk_src/clk_prepare_count 2>/dev/null) cam_cc_gdsc_clk registered=$( [ -d /sys/kernel/debug/clk/cam_cc_gdsc_clk ] && echo yes || echo no)"
systemctl --user -M deck@.host stop wireplumber.service pipewire-pulse.service pipewire.service pipewire.socket pipewire-pulse.socket 2>/dev/null; echo "audio stack stopped"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
sleep 15
A=$(for r in /sys/class/remoteproc/remoteproc*; do [ "$(cat $r/name)" = adsp ] && echo $r; done); echo stop > $A/state; echo "adsp: $(cat $A/state)"
rfkill block bluetooth; sleep 3; echo "BT uart: $(cat /sys/bus/platform/devices/998000.serial/power/runtime_status)"
echo serial0-0 > /sys/bus/serial/drivers/retroid-pocket-gamepad/unbind && echo "gamepad serdev driver unbound"
U=$(ls /sys/bus/platform/drivers/dwc3-qcom-legacy/ | grep -E '^[0-9a-f]+\.usb$' | head -1); echo "$U" > /sys/bus/platform/drivers/dwc3-qcom-legacy/unbind && echo "USB glue $U unbound"
echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove && echo "wifi endpoint removed"
setpci -s 00:00.0 CAP_EXP+10.w=0010:0010 && sleep 1
python3 - <<'PY'
import struct
c=open("/sys/bus/pci/devices/0000:00:00.0/config","rb").read(); p=c[0x34]
while p:
    if c[p]==0x10:
        ctl=struct.unpack("<H",c[p+0x10:p+0x12])[0]; sta=struct.unpack("<H",c[p+0x12:p+0x14])[0]
        print("  root port LNKCTL=0x%04x (LD=%d) LNKSTA=0x%04x (DLLLA=%d)" % (ctl, (ctl>>4)&1, sta, (sta>>13)&1))
    p=c[p+1]
PY
sleep 3
for d in 888000.serial 998000.serial; do printf "  %s=%s" $d "$(cat /sys/bus/platform/devices/$d/power/runtime_status)"; done; echo
echo "bi_tcxo now: prepare=$(cat /sys/kernel/debug/clk/bi_tcxo/clk_prepare_count) bi_tcxo_ao=$(cat /sys/kernel/debug/clk/bi_tcxo_ao/clk_prepare_count) pcie_aux=$(cat /sys/kernel/debug/clk/gcc_pcie_0_aux_clk/clk_prepare_count) pcie_phy_aux=$(cat /sys/kernel/debug/clk/gcc_pcie_phy_aux_clk/clk_prepare_count) refgen=$(cat /sys/kernel/debug/clk/gcc_pcie0_phy_refgen_clk/clk_prepare_count)"
