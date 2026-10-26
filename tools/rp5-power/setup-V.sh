# cycle V (kernel 47, 2026-10-16): cycle S2's configuration (audio DSP stopped, wifi PCIe link down, everything else
# NORMAL) PLUS a forced sync_state for the clock controllers still waiting for one. gcc + gpucc wait on 3d6a000.gmu,
# which never binds a driver (the msm driver uses it as a component); fw_devlink is in strict mode, so their
# sync_state never runs, and genpd keeps every power domain that was ON at boot ON until its provider's sync_state
# (drivers/pmdomain/core.c: genpd->stay_on, cleared only in of_genpd_sync_state). Upstream: "drm/msm: Attach a driver
# to the GMU" (Qualcomm, RFT 2026-05-12). Writing 1 to state_synced runs the sync_state once (drivers/base/dd.c).
G=/sys/kernel/debug/pm_genpd/pm_genpd_summary; V=/var/tmp/sleepcycle
on() { awk '/^[a-z]/ && $2=="on" {printf "%s ", $1}' $G; }
cp $G $V/V-genpd-before.txt
echo "domains ON before: $(on)"
echo "unsynced suppliers: $(for f in /sys/bus/platform/devices/*/state_synced; do [ "$(cat $f)" = 0 ] && printf '%s ' "$(basename "$(dirname "$f")")"; done)"
dmesg | grep -E 'sync_state\(\) pending' | sed 's/^\[[^]]*\] /  /' | sort -u | head -12
for d in 100000.clock-controller 3d90000.clock-controller; do
  f=/sys/bus/platform/devices/$d/state_synced
  [ -e $f ] && [ "$(cat $f)" = 0 ] && printf 1 > $f && echo "forced sync_state: $d -> $(cat $f)"   # exactly "1": state_synced_store strcmp()s, a newline is EINVAL
done
sleep 3
cp $G $V/V-genpd-after.txt
echo "domains ON after:  $(on)"
echo "display: $(cat /sys/class/drm/card*-DSI-1/enabled 2>/dev/null | head -1) $(cat /sys/class/drm/card*-DSI-1/dpms 2>/dev/null | head -1); usb: $(cat /sys/bus/platform/devices/a600000.usb/power/runtime_status 2>/dev/null); gpu: $(cat /sys/bus/platform/devices/3d00000.gpu/power/runtime_status 2>/dev/null)"
dmesg | tail -15 | grep -iE 'smmu|fault|gdsc|timeout|error|fail' | tail -5
# S2's configuration
systemctl --user -M deck@.host stop wireplumber.service pipewire-pulse.service pipewire.service pipewire.socket pipewire-pulse.socket 2>/dev/null; echo "audio stack stopped"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
sleep 15
A=$(for r in /sys/class/remoteproc/remoteproc*; do [ "$(cat $r/name)" = adsp ] && echo $r; done); echo stop > $A/state; echo "adsp: $(cat $A/state)"
echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove && echo "wifi endpoint removed"
setpci -s 00:00.0 CAP_EXP+10.w=0010:0010 && echo "root port Link Disable set"
sleep 3
