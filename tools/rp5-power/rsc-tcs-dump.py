#!/usr/bin/env python3
# rsc-tcs-dump.py (2026-10-16): dump the APPS RSC's TCS command slots (active / sleep / wake / control) straight from the
# registers via /dev/mem, read-only, with resource names from /sys/kernel/debug/cmd-db. The SLEEP TCS is the set of
# RPMh votes the AOSS applies when the CPU cluster powers down in s2idle: what is NOT in it keeps its active vote.
# Run as root on the device. Layout: rpmh-rsc.c ver-2.7 offsets (RSC_DRV_ID major 2 on sm8250); drv-id + tcs-offset
# + tcs-config from the live DT. Found on the RP5: one entry (MM0) -> the CPU DDR bandwidth votes stood through sleep.
import mmap, struct, os, sys
rsc = "/proc/device-tree/soc@0/rsc@18200000"
raw = open(rsc + "/reg", "rb").read()
regs = [struct.unpack(">QQ", raw[i:i+16]) for i in range(0, len(raw), 16)]
drv = int.from_bytes(open(rsc + "/qcom,drv-id", "rb").read(), "big")
tcs_off = int.from_bytes(open(rsc + "/qcom,tcs-offset", "rb").read(), "big")
cfg = open(rsc + "/qcom,tcs-config", "rb").read()
types = [struct.unpack(">II", cfg[i:i+8]) for i in range(0, len(cfg), 8)]   # (type, count) in DT order = TCS id order
# include/dt-bindings/soc/qcom,rpmh-rsc.h: SLEEP_TCS 0, WAKE_TCS 1, ACTIVE_TCS 2, CONTROL_TCS 3 (the first version of this
# tool had these swapped and labelled the WAKE TCS as SLEEP, 2026-10-16)
kind = {0: "SLEEP", 1: "WAKE", 2: "ACTIVE", 3: "CONTROL"}
layout = []
for t, n in types:
    layout += [kind[t]] * n
base, size = regs[drv]
fd = os.open("/dev/mem", os.O_RDONLY | os.O_SYNC)
m = mmap.mmap(fd, size, mmap.MAP_SHARED, mmap.PROT_READ, offset=base)
r32 = lambda o: struct.unpack("<I", m[o:o+4])[0]
ver = r32(0)
major = (ver >> 16) & 0xff
if major >= 3:
    TCS, CMD, EN, ADDR, DATA = 672, 24, 0x2C, 0x40, 0x44   # ver 3.0 table (check rpmh-rsc.c before trusting)
else:
    TCS, CMD, EN, ADDR, DATA = 672, 20, 0x1C, 0x34, 0x38   # ver 2.7 table
names = {}
for l in open("/sys/kernel/debug/cmd-db"):
    p = l.split()
    if p and p[0].startswith("0x") and p[0].endswith(":"):
        names[int(p[0][:-1], 16)] = p[1]
print("drv-%d base=0x%x RSC v%d.%d tcs-offset=0x%x layout=%s" % (drv, base, major, (ver >> 8) & 0xff, tcs_off, "/".join("%s:%d" % (kind[t], n) for t, n in types)))
only = sys.argv[1].upper() if len(sys.argv) > 1 else None
for t, k in enumerate(layout):
    if only and k != only:
        continue
    tb = tcs_off + TCS * t
    en = r32(tb + EN)
    slots = []
    for j in range(16):
        if en & (1 << j):
            a = r32(tb + CMD * j + ADDR); d = r32(tb + CMD * j + DATA)
            slots.append("%s=0x%x" % (names.get(a & 0xfffff, "0x%05x" % a), d))
    print("TCS%d %-7s enable=0x%04x: %s" % (t, k, en, " ".join(slots) if slots else "-"))
