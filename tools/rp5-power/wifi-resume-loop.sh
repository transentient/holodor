#!/bin/bash
# wifi-resume-loop.sh <label> [cycles=10] [seconds=60] (2026-10-16), run ON the RP5 as root, started with systemd-run
# (ssh dies across a suspend; a transient unit is frozen and thawed with everything else).
# Kernel 49 (Qualcomm's posted PCI: qcom D3cold v5): when the wifi endpoint is in D3hot at suspend, the root complex
# now sends PME_Turn_Off, takes the link to L2, powers itself off and drops the chip's WLAN power (pwrctrl), and
# rebuilds all of it on resume. This loop runs N real suspends with the SHIPPING sleep hooks (radio off/on, resume
# gateway check) and records after each resume: seconds until NM says connected, a gateway ping over the wifi netdev,
# new wifi-heal.log lines, ath11k/PCIe kernel errors, the PCIe link speed/width, Bluetooth powered, and the RSC sleep
# TCS xo.lvl entry (sleep 0x0 = the APPS side released XO for that suspend).
# Output: /var/tmp/wifiloop/<label>/report.txt, then a "done" marker.
set -u
L=$1; N=${2:-10}; S=${3:-60}
TOOLS=$(dirname "$(readlink -f "$0")")
O=/var/tmp/wifiloop/$L; rm -rf "$O"; mkdir -p "$O"; R=$O/report.txt
HL=/var/lib/pocknix/wifi-heal.log
log() { echo "$(date -u +%T) $*" >> "$R"; }
inhibit_on() { systemd-run --user -M deck@.host --unit="sleeptest-inhibit-$(date +%s%N)" -q systemd-inhibit --what=sleep:idle --who=sleeptest --why="wifi loop $L" --mode=block sleep 3600; }
inhibit_off() { for u in $(systemctl --user -M deck@.host list-units --no-legend --plain "sleeptest-inhibit*" 2>/dev/null | awk '{print $1}'); do systemctl --user -M deck@.host stop "$u"; done; }
wdev() { nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}'; }
wstate() { nmcli -t -f TYPE,STATE device status 2>/dev/null | awk -F: '$1=="wifi"{print $2; exit}'; }
EP=$(for d in /sys/bus/pci/drivers/ath1*k_pci/0000:*; do [ -e "$d" ] && basename "$d"; done | head -1)
GW=$(ip -4 route show default | awk '{print $3; exit}')
log "loop $L: $N x ${S}s, kernel $(pacman -Q linux-pocknix-sm8250 | cut -d' ' -f2), wifi $(wdev) $(wstate) ep=$EP wakeup=$(cat /sys/bus/pci/devices/$EP/power/wakeup 2>/dev/null) gw=$GW, battery $(cat /sys/class/power_supply/*battery*/capacity | head -1)%"
pass=0
for i in $(seq 1 "$N"); do
  since=$(date '+%Y-%m-%d %H:%M:%S'); h0=$(wc -l < "$HL" 2>/dev/null || echo 0)
  inhibit_off; sleep 1
  rtcwake -m no -s "$S" >/dev/null 2>&1
  systemctl suspend
  w=0; until journalctl -k --since "$since" --no-pager -o cat | grep -q 'PM: suspend exit'; do sleep 1; w=$((w + 1)); [ $w -gt $((S + 240)) ] && break; done
  inhibit_on
  c=-1; for k in $(seq 1 90); do [ "$(wstate)" = connected ] && { c=$k; break; }; sleep 1; done
  dev=$(wdev); gw=$(ip -4 route show default dev "$dev" 2>/dev/null | awk '{print $3; exit}')
  p=FAIL; [ -n "$gw" ] && ping -c 3 -W 2 -I "$dev" "$gw" >/dev/null 2>&1 && p=ok
  sleep 3   # let the resume gateway check (bsp-common 37) finish its own pings
  heal=$(tail -n +$((h0 + 1)) "$HL" 2>/dev/null | cut -c27- | tr '\n' '|' | cut -c1-200)
  kerr=$(journalctl -k --since "$since" --no-pager -o cat | grep -ciE 'ath11k.*(fail|err|timeout|crash|recover)|qcom-pcie.*(fail|err|timeout)|pcieport.*(error|fail)|link (down|failed)')
  susp=$(journalctl -k --since "$since" --no-pager -o cat | grep -cE 'PM: suspend entry')
  lnk="$(cat /sys/bus/pci/devices/$EP/current_link_speed 2>/dev/null | tr -d ' ')/x$(cat /sys/bus/pci/devices/$EP/current_link_width 2>/dev/null)"
  bt=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo OFF)   # btmgmt prints nothing from a unit (10-16)
  xo=$(python3 "$TOOLS/rsc-tcs-dump.py" 2>/dev/null | grep -E 'SLEEP' | grep -oE 'xo\.lvl[^ ]* *=? *0x[0-9a-f]+' | head -1)
  [ "$c" -gt 0 ] && [ "$p" = ok ] && [ "$bt" = on ] && pass=$((pass + 1))
  log "cycle $i/$N: suspends=$susp resumed after ${w}s, connected after ${c}s ($dev), gw ping $p, bt $bt, link $lnk, kernel errors $kerr, sleep-TCS ${xo:-no xo.lvl}, heal log: ${heal:-none}"
  journalctl -k --since "$since" --no-pager -o short-monotonic | grep -iE 'ath11k|qcom-pcie|pcie|pci 0000|wlan|PM: suspend' > "$O/kernel-$i.txt"
  sleep 5
done
log "result: $pass/$N cycles connected + gateway + bluetooth; battery $(cat /sys/class/power_supply/*battery*/capacity | head -1)%; inhibitor held"
touch "$O/done"
