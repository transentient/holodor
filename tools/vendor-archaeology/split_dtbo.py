import struct, sys, os
f = open(sys.argv[1],'rb').read()
magic, total, hsz, esz, cnt, eoff, pgsz, ver = struct.unpack('>8I', f[:32])
assert magic == 0xd7b7ab1e
print(f"entries={cnt} total={total} ver={ver}")
outdir = sys.argv[2]; os.makedirs(outdir, exist_ok=True)
for i in range(cnt):
    off = eoff + i*esz
    dsz, doff, did, drev, c0,c1,c2,c3 = struct.unpack('>8I', f[off:off+32])
    blob = f[doff:doff+dsz]
    open(f"{outdir}/dtbo_{i:03d}.dtb",'wb').write(blob)
    print(f"{i:03d} size={dsz} id={did:#x} rev={drev:#x} custom={c0:#x},{c1:#x},{c2:#x},{c3:#x}")
