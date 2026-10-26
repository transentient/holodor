#!/usr/bin/env bash
# boot-journal-summary.sh [deck@ip] [boot offset, default -1]
# Pulls one boot's journal off the device (as root, monotonic timestamps) into the scratch dir
# and prints the lines that matter for the docked-sleep questions: did wifi come up, when did it
# suspend/resume and why, every power-key line, USB host / Type-C on the wake, charger input
# limit (kernel 16), and whether the boot ended in an orderly shutdown.
set -u
host="${1:-deck@192.168.1.68}"; boot="${2:--1}"
out="${OUT:-/tmp/rp5-journal-b${boot}.log}"
ssh -o ConnectTimeout=8 "$host" "systemd-run --quiet --wait --pipe --collect journalctl -b $boot -o short-monotonic --no-pager" > "$out" || { echo "journal pull failed"; exit 1; }
echo "== $(wc -l < "$out") lines -> $out"
echo "== boot identity"; grep -m2 -E 'Linux version|systemd\[1\]: .*running in system mode' "$out" | cut -c1-160
echo "== wifi / NetworkManager"; grep -E 'NetworkManager.*(manager: NetworkManager state|device \(wl|CONNECTED_|connectivity|limited)|wifi-heal|wlan[01]: (link|authenticated|associated|deauth)' "$out" | cut -c1-170 | head -40
echo "== suspend / resume / wakeup"; grep -E 'will suspend|PM: suspend (entry|exit)|Suspending system|suspend_enter|wakeup_source|Wakeup from|irq [0-9]+ .*wake|pocknix-wake-grace|resume detected' "$out" | cut -c1-160 | head -40
echo "== power key (logind + powerd)"; grep -E 'Power key|KEY_POWER|pocknix-powerd' "$out" | cut -c1-170 | head -40
echo "== USB host / Type-C around the wake"; grep -E 'xhci|HS-PHY|Host System Error|dwc3|tcpm|typec|DP-1|usb usb[0-9]|USB disconnect|new (high|SuperSpeed)' "$out" | cut -c1-160 | tail -40
echo "== charger (kernel 16 lines)"; grep -E 'input current limit|Apsd|pm8150b.*charger' "$out" | cut -c1-140 | head -12
echo "== orderly shutdown lines: $(grep -c -E 'Shutting down|System Power Off|Reached target.*Reboot|Powering off|Rebooting' "$out")"
echo "== last 25 lines (de-spammed)"; grep -v -E 'Apsd not ready|gboolean|pocknix-telemetryd' "$out" | tail -25 | cut -c1-170
