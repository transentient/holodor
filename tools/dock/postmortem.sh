#!/bin/bash
# postmortem.sh — first thing to run after an RP5 mystery reset, from fusor:
#   tools/dock/postmortem.sh [deck@192.168.1.68]
# 1. deploys pon-reason.sh + blackbox.sh to the device, 2. reads + decodes the PMIC's last
# power-off reason (root, regmap debugfs), 3. shows the previous boot's journal tail (de-spammed),
# the 60 s telemetry CSV tail and the blackbox tail, 4. (re)starts the blackbox recorder.
set -u
H=${1:-deck@192.168.1.68}
D=$(cd "$(dirname "$0")" && pwd)
SSH="ssh -o ConnectTimeout=8 -o BatchMode=yes"
echo "== deploy"; scp -q "$D/pon-reason.sh" "$D/blackbox.sh" "$H:/home/deck/" || exit 1
echo "== PMIC power-on / power-off reasons (last off = the death if nothing powered it off since)"
$SSH "$H" 'systemd-run --wait --pipe --collect -q bash /home/deck/pon-reason.sh'
echo "== previous boot: last 30 journal lines (upower/apsd/session spam removed)"
$SSH "$H" 'journalctl -b -1 -o short-monotonic --no-pager 2>/dev/null | grep -vE "invalid gboolean|Apsd not ready|pam_unix|session-[0-9]+\.scope|New session|Removed session|logged (in|out)|sshd\[" | tail -30 | cut -c1-200'
echo "== previous boot: boot id + how it ended"
$SSH "$H" 'journalctl --list-boots --no-pager 2>/dev/null | tail -3; journalctl -b -1 --no-pager 2>/dev/null | grep -cE "Shutting down|Reached target.*(Shutdown|Power-Off|Reboot)" | sed "s/^/orderly-shutdown lines: /"'
echo "== telemetry.csv tail (60 s samples: epoch,capacity,status,uV,uA,W,temp_max,...)"
$SSH "$H" 'tail -12 /var/lib/pocknix/telemetry.csv 2>/dev/null | while IFS=, read e rest; do echo "$(date -d @$e +%T 2>/dev/null) $rest"; done'
echo "== blackbox tail"
$SSH "$H" 'tail -6 /var/lib/pocknix/blackbox.log 2>/dev/null | cut -c1-400'
echo "== start the blackbox recorder for this boot"
$SSH "$H" 'systemctl is-active pocknix-blackbox.service >/dev/null 2>&1 && echo "already running" || systemd-run --unit=pocknix-blackbox --collect -p Nice=10 bash /home/deck/blackbox.sh'
