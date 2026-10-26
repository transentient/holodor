#!/bin/sh
# boottrace-collect.sh (2026-10-16): save the boot clock trace, switch the probes off, restore the command line + boot image.
T=/sys/kernel/tracing; O=/var/tmp/boottrace-clk.txt
echo 0 > $T/tracing_on; cp $T/trace "$O"; echo "saved $(grep -c ': c[pu]: ' "$O") events to $O (uptime $(cut -d. -f1 /proc/uptime)s)"
echo 0 > $T/events/kprobes/enable 2>/dev/null; echo nostacktrace > $T/trace_options; echo > $T/kprobe_events; echo 1 > $T/tracing_on
if [ -f /var/tmp/kernel-cmdline.orig ]; then cp /var/tmp/kernel-cmdline.orig /usr/lib/pocknix/kernel-cmdline && pocknix-build-bootimg | tail -1; echo "cmdline restored: $(wc -c < /usr/lib/pocknix/kernel-cmdline) bytes"; fi
