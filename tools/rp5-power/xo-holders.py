#!/usr/bin/env python3
# xo-holders.py <clk-pre.txt> <trace.txt> [root=bi_tcxo] (2026-10-16): which clocks under <root> are still prepared at
# the suspend flush. clk-pre.txt = clk_summary at the pre-suspend edge (core prepare counts); trace.txt = clk:clk_prepare /
# clk:clk_unprepare (core 0<->1 transitions) + power:suspend_resume through the suspend. A core that was prepared at the
# edge and saw no 1->0 transition before "machine_suspend begin" (or was re-prepared) is still prepared at the flush.
import re, sys
pre, trace = sys.argv[1], sys.argv[2]
root = sys.argv[3] if len(sys.argv) > 3 else "bi_tcxo"
rows = []
for line in open(pre):
    m = re.match(r"^( *)(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)", line)
    if m and not line.lstrip().startswith(("clock", "enable")):
        rows.append([(len(m.group(1)) - 1) // 3, m.group(2), int(m.group(4)), []])
    elif rows and len(line.split()) == 2 and not line.lstrip().startswith("-"):
        rows[-1][3].append(line.split()[0])
sub, inside, rd = [], False, 0
for d, n, pr, cons in rows:
    if not inside and n == root:
        inside, rd = True, d; sub.append((0, n, pr, cons)); continue
    if inside:
        if d <= rd: break
        sub.append((d - rd, n, pr, cons))
state, t_ms = {}, None
ev = re.compile(r"\s(\d+\.\d+): (clk_prepare|clk_unprepare|suspend_resume): (\S+)")
for line in open(trace):
    m = ev.search(line)
    if not m: continue
    t, kind, arg = float(m.group(1)), m.group(2), m.group(3)
    if kind == "suspend_resume":
        if arg.startswith("machine_suspend") and "begin" in line and t_ms is None: t_ms = t
        continue
    if t_ms is not None: continue
    state[arg] = "prepared" if kind == "clk_prepare" else "unprepared"
print("machine_suspend begin at %s; %s subtree at the flush (prepared at the edge and not released):" % (t_ms, root))
for d, n, pr, cons in sub:
    if pr == 0 and state.get(n) != "prepared": continue
    s = state.get(n, "untouched")
    held = (s != "unprepared")
    c = [x for x in cons if x not in ("deviceless",)]
    print("%s%-40s edge_prepare=%-3d window=%-10s %s %s" % ("  " * d, n, pr, s, "HELD" if held else "released", " ".join(c)[:60]))
