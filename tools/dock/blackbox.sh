#!/bin/bash
# blackbox.sh — 2-second flight recorder for the RP5 dock investigation. Runs ON the device as root:
#   systemd-run --unit=pocknix-blackbox --collect -p Nice=10 bash /home/deck/blackbox.sh
# One line per sample, fdatasync'ed, to /var/lib/pocknix/blackbox.log, so the last lines before a
# hard reset are on the card for the next boot. Everything is local sysfs/regmap (no ssh polling,
# which flooded logind on 2026-10-10). ~400 B/sample, rotated at 8 MB.
#
# Fields: t=epoch up=uptime | battery: cap status V uA temp health | usb psy: online type imax |
# typec: power_role data_role pd(partner) | DP-1 status/enabled | thermal: pm8150b die, pm8150 die,
# hottest cpu/gpu, skin | SMB5 (PM8150B, SPMI SID2, base 0x1000) raw regs:
#   chg1=0x1006 BATTERY_CHARGER_STATUS_1 (bits2:0 0 trickle 1 pre 2 fullon 3 taper 4 terminate 5 inhibit 6 disable 7 pause)
#   chg2=0x1007 STATUS_2 (bit7 input-limited, 6 vbat<rchg, 5 vbat>inhibit, 4 vbat>float, 2 sft-expired, 1 BAT_OV, 0 BAT_TERM_MISSING)
#   chgint=0x1010 charger INT_RT_STS  icl=0x1107 ICL_STATUS  aicl=0x1108 AICL_STATUS  pp=0x110B POWER_PATH_STATUS
#   apsd=0x1307 APSD_STATUS  apsdr=0x1308 APSD_RESULT  usbint=0x1310 USBIN INT_RT_STS (bit4 plugged)
#   tcsnk=0x1506 TYPE_C_SNK_STATUS  tcsrc=0x1508  tcsm=0x1509 TYPE_C_STATE_MACHINE  tcmisc=0x150B
#   iclmax=0x1106 ICL_MAX_STATUS (the limit the chip is applying, x50 mA)  cfg=0x1370 USBIN_CURRENT_LIMIT_CFG (what SW wrote)
#   ovr=0x1342 CMD_ICL_OVERRIDE (bit0 = USB 2.0/3.0 100/500/900 override, NOT high-current)  load=0x1365 USBIN_LOAD_CFG (bit4 SW ICL survives APSD)
#   iclopt=0x1366 USBIN_ICL_OPTIONS (bit0 high-current mode, bit1 USB51 500 mA, bit2 USB3)  opt1=0x1362 USBIN_OPTIONS_1 (bit3 APSD/BC1.2 on)
#   aiclopt=0x1380 USBIN_AICL_OPTIONS (bit7 suspend on collapse, 4 periodic rerun, 3 ADC, 2 AICL on)
#   allow=0x1344 USBIN_ADAPTER_ALLOW_OVERRIDE (bit3 continuous, 2 force 12 V, 1 force 9 V, 0 force 5 V; 0 = the
#     0x1360 windows), cont=0x1384 continuous AICL threshold (4.0-5.5 V in 100 mV, >= 5.6 V in 200 mV from 16).
#   usbint bit3 = USBIN_OV, pp bit6 = USBIN suspended (kernel 21 at 9 V: usbint=18 pp=d8 = input refused).
#   2026-10-11 docked boot: icl=0a aicl=0a (500 mA) with imax=2000000 = the drain; 0722 v3 (kernel 19) should show iclmax=28.
#   2026-10-14 docked wake: pd ack=01 with a DP Attention (hdr 238f) in the RX buffer = PD receive wedged since the resume, DP never retrained.
set -u
OUT=/var/lib/pocknix/blackbox.log
RM=/sys/kernel/debug/regmap/0-02/registers
B=/sys/class/power_supply/battery
INTERVAL=${INTERVAL:-2}
mkdir -p "$(dirname "$OUT")"
LEN=$(head -c 64 "$RM" 2>/dev/null | head -n1 | wc -c)
rd() { local l; l=$(dd if="$RM" bs="$LEN" skip="$1" count=1 2>/dev/null); [[ "${l%%:*}" == "$(printf '%0*x' $((LEN-5)) "$1")" ]] && echo "${l#*: }" || echo "??"; }
val() { cat "$1" 2>/dev/null || echo "-"; }
usbpsy=""
for u in /sys/class/power_supply/*/; do [ "$(val "$u/type")" = "USB" ] && usbpsy=$u; done
tz_by_type() { local z; for z in /sys/class/thermal/thermal_zone*; do [ "$(val "$z/type")" = "$1" ] && { echo "$z"; return; }; done; }
Z_B=$(tz_by_type pm8150b-thermal); Z_A=$(tz_by_type pm8150-thermal); Z_L=$(tz_by_type pm8150l-thermal)
hot() { local m=0 h t; for h in /sys/class/hwmon/hwmon*/; do case "$(val "$h/name")" in cpu*|gpuss*|ddr_thermal) t=$(val "$h/temp1_input"); [[ $t =~ ^[0-9]+$ ]] && [ "$t" -gt "$m" ] && m=$t;; esac; done; echo $((m/1000)); }
mC() { local v; v=$(val "$1/temp"); [[ $v =~ ^-?[0-9]+$ ]] && echo $((v/1000)) || echo "-"; }
echo "# blackbox start $(date '+%F %T') boot=$(cat /proc/sys/kernel/random/boot_id) interval=${INTERVAL}s usbpsy=${usbpsy:-none}" >> "$OUT"
while :; do
  line="t=$(date +%s) up=$(cut -d' ' -f1 /proc/uptime)"
  line+=" | bat cap=$(val $B/capacity) st=$(val $B/status) uV=$(val $B/voltage_now) uA=$(val $B/current_now) T=$(val $B/temp) h=$(val $B/health)"
  [ -n "$usbpsy" ] && line+=" | usb on=$(val $usbpsy/online) type=$(val $usbpsy/usb_type | sed -n 's/.*\[\([^]]*\)\].*/\1/p') imax=$(val $usbpsy/current_max) vmax=$(val $usbpsy/voltage_max)"
  line+=" | tc pr=$(val /sys/class/typec/port0/power_role | sed -n 's/.*\[\([^]]*\)\].*/\1/p') dr=$(val /sys/class/typec/port0/data_role | sed -n 's/.*\[\([^]]*\)\].*/\1/p') pd=$(val /sys/class/typec/port0-partner/supports_usb_power_delivery)"
  line+=" | dp=$(val /sys/class/drm/card0-DP-1/status)/$(val /sys/class/drm/card0-DP-1/enabled)"
  line+=" | T pm8150b=$(mC "$Z_B") pm8150=$(mC "$Z_A") pm8150l=$(mC "$Z_L") hot=$(hot)"
  if [ -r "$RM" ]; then
    line+=" | smb chg1=$(rd $((0x1006))) chg2=$(rd $((0x1007))) chgint=$(rd $((0x1010))) icl=$(rd $((0x1107))) aicl=$(rd $((0x1108))) pp=$(rd $((0x110B)))"
    line+=" apsd=$(rd $((0x1307))) apsdr=$(rd $((0x1308))) usbint=$(rd $((0x1310))) tcsnk=$(rd $((0x1506))) tcsrc=$(rd $((0x1508))) tcsm=$(rd $((0x1509))) tcmisc=$(rd $((0x150B)))"
    line+=" iclmax=$(rd $((0x1106))) cfg=$(rd $((0x1370))) ovr=$(rd $((0x1342))) load=$(rd $((0x1365))) iclopt=$(rd $((0x1366))) opt1=$(rd $((0x1362))) aiclopt=$(rd $((0x1380))) allow=$(rd $((0x1344))) cont=$(rd $((0x1384)))"
    # PD PHY (0x1700): pdack=0x174B RX_ACKNOWLEDGE (1 = the RX buffer is owned by software: tcpm has not read the last
    # message, every TX is refused with EBUSY), pdrx=0x174A RX_STATUS, pdsz=0x1742 RX_SIZE, pdhdr=0x1780/81 RX buffer header
    line+=" | pd ack=$(rd $((0x174B))) rx=$(rd $((0x174A))) sz=$(rd $((0x1742))) hdr=$(rd $((0x1781)))$(rd $((0x1780)))"
  fi
  echo "$line" >> "$OUT"; sync -d "$OUT" 2>/dev/null || sync
  if [ "$(stat -c %s "$OUT")" -gt 8388608 ]; then tail -n 20000 "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; fi
  sleep "$INTERVAL"
done
