import struct, sys, os
f = open(sys.argv[1],'rb').read()
assert f[:8] == b'VNDRBOOT'
ver, pgsz = struct.unpack('<2I', f[8:16])
# v3/v4 header: ver, page_size, kernel_addr, ramdisk_addr, vendor_ramdisk_size, cmdline(2048), tags_addr, name(16), header_size, dtb_size, dtb_addr(u64)
o = 16
kaddr, raddr, rdsz = struct.unpack('<3I', f[o:o+12]); o += 12
cmdline = f[o:o+2048].rstrip(b'\0'); o += 2048
tags, = struct.unpack('<I', f[o:o+4]); o += 4
name = f[o:o+16].rstrip(b'\0'); o += 16
hsz, dtbsz = struct.unpack('<2I', f[o:o+8]); o += 8
dtbaddr, = struct.unpack('<Q', f[o:o+8]); o += 8
print(f"ver={ver} pgsz={pgsz} rdsz={rdsz} hsz={hsz} dtbsz={dtbsz} name={name}")
print("cmdline:", cmdline.decode(errors='replace')[:300])
def align(x): return (x + pgsz - 1)//pgsz*pgsz
# layout: header (aligned), vendor ramdisk (aligned), dtb
off = align(hsz)
off += align(rdsz)
dtb = f[off:off+dtbsz]
open(sys.argv[2],'wb').write(dtb)
print("dtb magic:", dtb[:4].hex())
