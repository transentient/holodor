#!/usr/bin/env python3
# regsnap-diff.py <regs.txt> [<other regs.txt>] (2026-10-16): read regsnap.sh output.
# One file: per macro, cached registers whose hardware value differs from the cache (= a failed restore, or a value
# the hardware changes by itself). Two files: per macro, hardware values that differ between the two snapshots.
import sys


def load(path):
    out, name, block = {}, None, None
    for line in open(path):
        line = line.rstrip("\n")
        if line.startswith("== "):
            name = line.split()[1].split("-")[0]
            out[name] = {"state": line.split("runtime=")[-1], "cache": {}, "hw": {}}
        elif line in ("-- cache", "-- hw"):
            block = line[3:]
        elif name and block and ":" in line:
            reg, val = (s.strip() for s in line.split(":", 1))
            if val and set(val) != {"X"}:
                out[name][block][reg] = val
    return out


a = load(sys.argv[1])
for name, m in a.items():
    if not m["hw"]:
        print("%-18s runtime=%s, no hardware read (%d cached registers)" % (name, m["state"], len(m["cache"])))
        continue
    bad = [(r, v, m["hw"].get(r)) for r, v in m["cache"].items() if r in m["hw"] and m["hw"][r] != v]
    print("%-18s runtime=%s cached=%d hw=%d  cache!=hw: %d" % (name, m["state"], len(m["cache"]), len(m["hw"]), len(bad)))
    for r, c, h in bad[:25]:
        print("    %s cache=%s hw=%s" % (r, c, h))
if len(sys.argv) > 2:
    b = load(sys.argv[2])
    print("-- hardware %s vs %s" % (sys.argv[1], sys.argv[2]))
    for name in sorted(set(a) & set(b)):
        ha, hb = a[name]["hw"], b[name]["hw"]
        if not ha or not hb:
            print("%-18s skipped (no hardware read in one snapshot)" % name)
            continue
        diff = [(r, ha[r], hb[r]) for r in ha if r in hb and ha[r] != hb[r]]
        print("%-18s common=%d differ=%d" % (name, len(set(ha) & set(hb)), len(diff)))
        for r, x, y in diff[:40]:
            print("    %s %s -> %s" % (r, x, y))
