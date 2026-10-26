#!/bin/sh
# boottrace-arm.sh (2026-10-16): arm ONE boot with a kprobe trace of every clock consumer prepare/unprepare (clock name,
# consumer dev_id, con_id + stack), to name who holds a clock that nothing awake should hold. Backs up the package-owned
# command-line file; boottrace-collect.sh restores it. Run as root, then install a kernel or run pocknix-build-bootimg.
F=/usr/lib/pocknix/kernel-cmdline
[ -f /var/tmp/kernel-cmdline.orig ] || cp "$F" /var/tmp/kernel-cmdline.orig
# string args: the outermost +offs() is the string's ADDRESS (not dereferenced), hence one more level than the pointer chain;
# trace_event= is what expands the ring buffer to trace_buf_size at boot (a boot kprobe event alone keeps 1 page/CPU)
ADD='trace_buf_size=16M trace_options=stacktrace trace_event=power:suspend_resume kprobe_event=p:cp,clk_prepare,c=+0(+0(+0(%x0))):string,d=+0(+16(%x0)):string,n=+0(+24(%x0)):string;p:cu,clk_unprepare,c=+0(+0(+0(%x0))):string,d=+0(+16(%x0)):string,n=+0(+24(%x0)):string'
printf '%s %s' "$(cat /var/tmp/kernel-cmdline.orig)" "$ADD" > "$F"
echo "armed: cmdline $(wc -c < "$F") bytes (mkbootimg field 512)"
