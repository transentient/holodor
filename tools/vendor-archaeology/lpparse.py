import struct, sys
f = open(sys.argv[1],'rb').read()
geo = f[4096:8192]
magic, ssize = struct.unpack('<2I', geo[:8])
assert magic == 0x616c4467, hex(magic)
_,_,csum = geo[:4], geo[4:8], geo[8:40]
mms, slots, lbs = struct.unpack('<3I', geo[40:52])
print(f"geometry: metadata_max_size={mms} slots={slots} lbs={lbs}")
base = 4096*3  # reserved + geometry + backup geometry
hdr_off = base  # slot 0 primary
h = f[hdr_off:hdr_off+256]
hmagic, vmaj, vmin, hsize = struct.unpack('<IHHI', h[:12])
assert hmagic == 0x414C5030, hex(hmagic)
tables_size, = struct.unpack('<I', h[44:48])
def desc(off): return struct.unpack('<3I', h[off:off+12])  # offset, num, entry_size
p_off, p_num, p_sz = desc(80)
e_off, e_num, e_sz = desc(92)
tab = f[hdr_off+hsize : hdr_off+hsize+tables_size]
exts = []
for i in range(e_num):
    o = e_off + i*e_sz
    ns, tt, td, tsrc = struct.unpack('<QIQI', tab[o:o+24])
    exts.append((ns, tt, td, tsrc))
for i in range(p_num):
    o = p_off + i*p_sz
    name = tab[o:o+36].rstrip(b'\0').decode()
    attrs, fei, ne, gi = struct.unpack('<4I', tab[o+36:o+52])
    tot = sum(exts[fei+j][0] for j in range(ne))*512
    print(f"{name:24s} extents={ne} size={tot/1048576:.1f}MiB")
    for j in range(ne):
        ns, tt, td, tsrc = exts[fei+j]
        print(f"   extent: sectors={ns} type={tt} dst_sector={td} (bytes off={td*512}, len={ns*512})")
