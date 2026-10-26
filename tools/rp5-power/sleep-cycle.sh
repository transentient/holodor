#!/bin/bash
# sleep-cycle.sh <label> [seconds=120] [setup.sh] [teardown.sh] (2026-10-16)
# One real s2idle suspend with ground-truth capture. Run ON the device as root, started with systemd-run (an ssh session can
# die across the suspend; a transient unit is frozen and thawed with everything else). Output: /var/tmp/sleepcycle/<label>/
# report.txt + raw captures, then a "done" marker. Captures: qcom_stats at the edges and the interconnect / clock / regulator
# summaries at the pre edge (temporary sleep.d pre/999 + post/000 hooks, removed at the end), the rpmh + suspend_resume
# trace over the cycle, the RSC TCS slots after resume, the standing votes at the flush. Holds the session's idle
# inhibitor except during the suspend itself. setup/teardown: optional shell snippets (e.g. an unbind and its bind).
set -u
L=$1; N=${2:-120}; SETUP=${3:-}; TEARDOWN=${4:-}
TOOLS=$(dirname "$(readlink -f "$0")")
O=/var/tmp/sleepcycle/$L; rm -rf "$O"; mkdir -p "$O"
D=/usr/lib/pocknix/sleep.d; T=/sys/kernel/tracing; R=$O/report.txt
log() { echo "$(date -u +%T) $*" >> "$R"; }
inhibit_on() { systemd-run --user -M deck@.host --unit="sleeptest-inhibit-$(date +%s%N)" -q systemd-inhibit --what=sleep:idle --who=sleeptest --why="sleep cycle $L" --mode=block sleep 3600; }
inhibit_off() { for u in $(systemctl --user -M deck@.host list-units --no-legend --plain "sleeptest-inhibit*" 2>/dev/null | awk '{print $1}'); do systemctl --user -M deck@.host stop "$u"; done; }
log "cycle $L: ${N}s, kernel $(pacman -Q linux-pocknix-sm8250 | cut -d' ' -f2), battery $(cat /sys/class/power_supply/*battery*/capacity | head -1)% $(cat /sys/class/power_supply/*battery*/status | head -1)"
printf '#!/bin/sh\n[ -r /run/sleepcycle-dir ] && sh %s/sleepcycle-edge.sh pre "$(cat /run/sleepcycle-dir)"\nexit 0\n' "$TOOLS" > "$D/pre/999-sleepcycle"
printf '#!/bin/sh\n[ -r /run/sleepcycle-dir ] && sh %s/sleepcycle-edge.sh post "$(cat /run/sleepcycle-dir)"\nexit 0\n' "$TOOLS" > "$D/post/000-sleepcycle"
chmod +x "$D/pre/999-sleepcycle" "$D/post/000-sleepcycle"; echo "$O" > /run/sleepcycle-dir
if [ -n "$SETUP" ]; then log "setup $SETUP:"; sh "$SETUP" >> "$R" 2>&1; fi
echo 0 > $T/tracing_on; echo > $T/trace; echo 32768 > $T/buffer_size_kb
echo 1 > $T/events/rpmh/rpmh_send_msg/enable; echo 1 > $T/events/power/suspend_resume/enable; echo 1 > $T/tracing_on
log "suspend now (rtcwake alarm in ${N}s)"
inhibit_off; sleep 1
rtcwake -m no -s "$N" >/dev/null 2>&1
systemctl suspend
i=0; while [ ! -s "$O/qs-post" ] && [ $i -lt $((N + 120)) ]; do sleep 1; i=$((i + 1)); done
sleep 5; inhibit_on
echo 0 > $T/tracing_on; cp $T/trace "$O/trace.txt"
echo 0 > $T/events/rpmh/rpmh_send_msg/enable; echo 0 > $T/events/power/suspend_resume/enable; echo 1 > $T/tracing_on
log "resumed: $(journalctl -k --no-pager -o short-iso --since "-$((N + 200)) s" | grep -E 'PM: suspend (entry|exit)' | cut -c12-19 | tr '\n' ' ')"
log "qcom_stats pre:  $(tr '\n' ' ' < "$O/qs-pre" 2>/dev/null)"
log "qcom_stats post: $(tr '\n' ' ' < "$O/qs-post" 2>/dev/null)"
python3 "$TOOLS/rsc-tcs-dump.py" > "$O/tcs.txt" 2>&1; grep -E "SLEEP|WAKE" "$O/tcs.txt" | grep -v ": -$" >> "$R"
python3 "$TOOLS/standing-votes.py" "$O/trace.txt" > "$O/standing.txt" 2>&1
if [ -n "$TEARDOWN" ]; then log "teardown $TEARDOWN:"; sh "$TEARDOWN" >> "$R" 2>&1; fi
rm -f "$D/pre/999-sleepcycle" "$D/post/000-sleepcycle" /run/sleepcycle-dir
log "battery $(cat /sys/class/power_supply/*battery*/capacity | head -1)%; hooks removed; inhibitor held"
touch "$O/done"
