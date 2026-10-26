# setup-NOMSM2.sh (2026-10-18): cycle "S2 + msm absent by DT". Boot with gpu@3d00000, gmu@3d6a000 and
# display-subsystem@ae00000 status=disabled (tools/rp5-power/swap-dtbs.sh apply with /var/tmp/dtb-exp/*.dtb), so neither
# the GMU nor the display pipeline ever started. The runtime unbind variant (setup-NOMSM.sh) hangs the device: do not use it.
# Then Opus's S2 config (audio DSP stopped, wifi PCIe link down) and the autologin session stopped. UNDOCKED on battery.
echo "-- msm absent? dri: $(ls /dev/dri 2>/dev/null | tr '\n' ' ' | sed 's/^$/none/'); gpu bound: $( [ -e /sys/bus/platform/drivers/adreno/3d00000.gpu ] && echo YES || echo no ); mdss bound: $( [ -e /sys/bus/platform/drivers/msm-mdss/ae00000.display-subsystem ] && echo YES || echo no )"
echo "-- genpd: $(grep -E '^(mdss_gdsc|gpu_cx_gdsc|gpu_gx_gdsc|gfx|mmcx|cx)\b' /sys/kernel/debug/pm_genpd/pm_genpd_summary | awk '{printf "%s=%s ", $1, $2}')"
systemctl stop getty@tty1.service && echo "-- getty@tty1 stopped"
for sid in $(loginctl list-sessions --no-legend 2>/dev/null | awk '$3=="deck" {print $1}'); do loginctl terminate-session "$sid" && echo "-- session $sid terminated"; done
sleep 2
sh /var/tmp/rp5-power/setup-Q.sh
