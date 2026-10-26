# setup-NOMSM.sh (2026-10-18): cycle "S2 + no msm". Opus's S2 config (audio DSP stopped, wifi PCIe link down: the only
# config whose APPS sleep set reaches xo.lvl 0), then the GPU and the display subsystem UNBOUND so neither the GMU's RSC
# nor the display pipeline is live at the flush (CONFIG_DRM_MSM=y: unbind is the only way without a new boot image).
# Must run UNDOCKED on battery (VBUS keeps dwc3 active = XO held). teardown-Q reboots the device afterwards.
rmmod disp_rsc_peek 2>/dev/null
sh /var/tmp/rp5-power/setup-Q.sh
echo "-- stopping the game session (RP5: getty@tty1 autologin -> login deck -> bash -> pocknix-steam -> gamescope-wl; seatd is DRM master)"
systemctl stop getty@tty1.service && echo "   getty@tty1 stopped (no autologin respawn)"
for sid in $(loginctl list-sessions --no-legend 2>/dev/null | awk '$3=="deck" {print $1}'); do loginctl terminate-session "$sid" && echo "   session $sid terminated"; done
for i in 1 2 3 4 5 6 7 8; do fuser /dev/dri/renderD128 >/dev/null 2>&1 || break; sleep 1; done
if fuser /dev/dri/card0 >/dev/null 2>&1; then
  echo "   card0 still held by: $(fuser -v /dev/dri/card0 2>&1 | tail -n +2 | awk '{print $NF"("$2")"}' | tr '\n' ' ')"
  systemctl stop seatd.service && echo "   seatd stopped"; sleep 1
fi
echo "-- drm holders left: $(fuser /dev/dri/card0 /dev/dri/renderD128 2>/dev/null | wc -w)"
echo "-- unbinding mdss (the DRM master; takes dpu/dsi/gpu components down), then the gpu platform device"
if [ -e /sys/bus/platform/drivers/msm-mdss/ae00000.display-subsystem ]; then echo ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/unbind && echo "   mdss unbound"; else echo "   mdss already not bound"; fi
sleep 3
if [ -e /sys/bus/platform/drivers/adreno/3d00000.gpu ]; then echo 3d00000.gpu > /sys/bus/platform/drivers/adreno/unbind && echo "   gpu unbound"; else echo "   gpu already not bound"; fi
sleep 3
echo "-- after unbind: dri0 $( [ -e /dev/dri/card0 ] && echo still-present || echo gone ); mdss_gdsc/gpu genpd:"
grep -E '^(mdss_gdsc|gpu_cx_gdsc|gpu_gx_gdsc|gfx|mmcx|cx|mx)\b' /sys/kernel/debug/pm_genpd/pm_genpd_summary | awk '{printf "   %-14s %s\n", $1, $2}'
echo "   bi_tcxo=$(cat /sys/kernel/debug/clk/bi_tcxo/clk_prepare_count) disp_cc_mdss_ahb_clk=$(cat /sys/kernel/debug/clk/disp_cc_mdss_ahb_clk/clk_prepare_count) gpu_cc_cx_gmu_clk=$(cat /sys/kernel/debug/clk/gpu_cc_cx_gmu_clk/clk_prepare_count 2>/dev/null)"
