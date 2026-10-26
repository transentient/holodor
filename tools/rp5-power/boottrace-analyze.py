#!/usr/bin/env python3
# boottrace-analyze.py <boottrace-clk.txt> [clock-substring ...] (2026-10-16): net clk_prepare - clk_unprepare per
# (clock, consumer dev_id, con_id) from the boot kprobe trace; for every unbalanced key whose clock matches a filter, the
# distinct call stacks of its prepares (top frames). Answers "who holds this clock" with the call site that took it.
import re, sys
from collections import defaultdict
ev = re.compile(r':\s(c[pu]):\s\([^)]*\)\sc="?([^"]*)"?\sd="?([^"]*)"?\sn="?([^"]*)"?')
events, cur = [], None
for line in open(sys.argv[1], errors="replace"):
    m = ev.search(line)
    if m:
        cur = [m.group(1), m.group(2), m.group(3), m.group(4), []]
        events.append(cur); continue
    if cur is not None and line.lstrip().startswith("=>"):
        f = line.strip()[3:].split("+")[0]
        if f not in ("clk_prepare", "clk_unprepare", "kprobe_dispatcher", "kprobe_breakpoint_handler", "call_break_hook",
                     "brk_handler", "do_debug_exception", "el1_dbg", "el1h_64_sync_handler", "el1h_64_sync") and len(cur[4]) < 9:
            cur[4].append(f)
filters = sys.argv[2:]
net, stacks = defaultdict(int), defaultdict(lambda: defaultdict(int))
for kind, c, d, n, st in events:
    k = (c, d, n)
    net[k] += 1 if kind == "cp" else -1
    if kind == "cp":
        stacks[k][" < ".join(st[:6])] += 1
print("events: %d" % len(events))
for k in sorted(net, key=lambda k: (k[0], k[1], k[2])):
    if net[k] <= 0 or (filters and not any(f in k[0] for f in filters)):
        continue
    print("%-34s dev=%-26s con=%-16s net=+%d" % (k[0][:34], k[1][:26], k[2][:16], net[k]))
    for s, cnt in sorted(stacks[k].items(), key=lambda kv: -kv[1])[:4]:
        print("      %3dx %s" % (cnt, s[:150]))
