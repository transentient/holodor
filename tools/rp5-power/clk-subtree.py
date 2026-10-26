#!/usr/bin/env python3
# clk-subtree.py <clk_summary file> <clock name> [--all] (2026-10-16): print the subtree of one clock from a saved
# /sys/kernel/debug/clk/clk_summary with enable/prepare counts and consumer handles. Default: only nodes with a nonzero
# prepare count (what keeps the root clock prepared, e.g. who holds the RPMh XO "bi_tcxo" on through suspend).
import re, sys
path, root = sys.argv[1], sys.argv[2]
show_all = "--all" in sys.argv
rows = []          # (depth, name, enable, prepare, [consumers])
for line in open(path):
    if not line.strip() or line.lstrip().startswith(("clock", "enable", "---")):
        continue
    m = re.match(r"^( *)(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(?:\s+(\S+)\s+(\S+))?", line)
    if m:
        depth = (len(m.group(1)) - 1) // 3
        rows.append([depth, m.group(2), int(m.group(3)), int(m.group(4)), []])
        if m.group(11):
            rows[-1][4].append(m.group(11) + ":" + m.group(12))
    elif rows:
        p = line.split()
        if len(p) == 2:
            rows[-1][4].append(p[0] + ":" + p[1])
out, inside, rdepth = [], False, 0
for d, n, en, pr, cons in rows:
    if not inside and n == root:
        inside, rdepth = True, d
        out.append((0, n, en, pr, cons)); continue
    if inside:
        if d <= rdepth:
            break
        out.append((d - rdepth, n, en, pr, cons))
for d, n, en, pr, cons in out:
    if show_all or pr > 0 or d == 0:
        c = [x for x in cons if not x.startswith("deviceless")]
        print("%s%-36s en=%-3d prep=%-3d %s" % ("  " * d, n, en, pr, " ".join(c)))
