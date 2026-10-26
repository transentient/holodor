#!/usr/bin/env python3
# fmt-dump.py <dump.txt> <cmd-db.txt>: annotate the disp_rsc_peek dump's command addresses with cmd-db resource names
# (the same mapping rsc-tcs-dump.py uses for the APPS RSC). Data decoding: BCM votes bit30 valid, bit29 commit,
# bits28:14 x(avg), bits13:0 y(peak); ARC levels = the corner index; VRM = enable/mode/voltage.
import re, sys
names = {}
for l in open(sys.argv[2]):
    p = l.split()
    if p and p[0].startswith("0x") and p[0].endswith(":"):
        names[int(p[0][:-1], 16)] = p[1]
for l in open(sys.argv[1]):
    m = re.search(r"addr (0x[0-9a-f]+) data (0x[0-9a-f]+)", l)
    if m:
        a, d = int(m.group(1), 16), int(m.group(2), 16)
        n = names.get(a & 0xfffff, "?")
        extra = ""
        if d & (1 << 30):
            extra = " [BCM valid%s x=%d y=%d]" % (" commit" if d & (1 << 29) else "", (d >> 14) & 0x7fff, d & 0x3fff)
        l = l.rstrip() + "   <- %s%s" % (n, extra) + "\n"
    sys.stdout.write(l)
