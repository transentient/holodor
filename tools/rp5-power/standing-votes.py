#!/usr/bin/env python3
# standing-votes.py <trace.txt> (2026-10-16): from an rpmh:rpmh_send_msg + power:suspend_resume trace of one suspend,
# print the LAST active-set value of every RPMh resource written before "machine_suspend begin" (= what stands at the
# cluster flush unless the sleep TCS overrides it), plus every sleep/wake write. Names from /sys/kernel/debug/cmd-db.
# BCM data (addr 0x5xxxx): commit bit 30, valid bit 29, vote_x (avg) bits 27:14, vote_y (peak) bits 13:0.
import re, sys
names = {}
for l in open("/sys/kernel/debug/cmd-db"):
    p = l.split()
    if p and p[0].startswith("0x") and p[0].endswith(":"):
        names[int(p[0][:-1], 16)] = p[1]
msg = re.compile(r"\s(\d+\.\d+): rpmh_send_msg: .*\[(active|sleep|wake)\].*addr: (0x[0-9a-f]+) data: (0x[0-9a-f]+)")
sus = re.compile(r"\s(\d+\.\d+): suspend_resume: machine_suspend\[\d+\] begin")
last, sw, t_ms = {}, [], None
for line in open(sys.argv[1]):
    m = sus.search(line)
    if m and t_ms is None:
        t_ms = float(m.group(1)); continue
    m = msg.search(line)
    if not m:
        continue
    t, kind, a, d = float(m.group(1)), m.group(2), int(m.group(3), 16), int(m.group(4), 16)
    if kind == "active" and (t_ms is None or t < t_ms):
        last[a] = (t, d)
    elif kind != "active":
        sw.append((t, kind, a, d))
def fmt(a, d):
    n = names.get(a & 0xfffff, "0x%05x" % a)
    if (a & 0xf0000) == 0x50000:
        return "%-8s x=%-5d y=%-5d %s%s" % (n, (d >> 14) & 0x3fff, d & 0x3fff, "C" if d >> 30 & 1 else "-", "V" if d >> 29 & 1 else "-")
    return "%-10s 0x%x" % (n, d)
print("machine_suspend begin at %s" % t_ms)
print("== last ACTIVE write per resource before machine_suspend (nonzero first):")
for a, (t, d) in sorted(last.items(), key=lambda kv: (kv[1][1] & 0x0fffffff == 0, kv[0])):
    print("  %.6f %s" % (t, fmt(a, d)))
print("== sleep/wake writes in the window:")
for t, k, a, d in sw:
    print("  %.6f %-5s %s" % (t, k, fmt(a, d)))
