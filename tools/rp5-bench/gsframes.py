#!/usr/bin/env python3
# gsframes.py <out.csv> <seconds> : log gamescope's per-frame timings on the device.
# gamescope sends one SysV message per presented app frame to its overlay (mangoapp); the x86 game
# cannot load our arm64 MangoHud layer, so this queue is the only frame-time source. A queue message
# goes to ONE reader, so mangoapp is paused (SIGSTOP) for the duration and resumed afterwards.
import ctypes, ctypes.util, os, signal, struct, subprocess, sys, time
out, secs = sys.argv[1], float(sys.argv[2])
libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
libc.msgrcv.restype = ctypes.c_ssize_t
libc.msgrcv.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_long, ctypes.c_int]
qid = None
for line in subprocess.run(["ipcs", "-q"], capture_output=True, text=True).stdout.splitlines():
    p = line.split()
    if len(p) >= 6 and p[0].startswith("0x"): qid = int(p[1])
if qid is None: sys.exit("no message queue (is gamescope running with --mangoapp?)")
pids = [int(p) for p in subprocess.run(["pidof", "mangoapp"], capture_output=True, text=True).stdout.split()]
for p in pids: os.kill(p, signal.SIGSTOP)
buf = ctypes.create_string_buffer(8192); IPC_NOWAIT = 0o4000; n = 0
try:
    while libc.msgrcv(qid, buf, 8184, 0, IPC_NOWAIT) >= 0: pass      # drop the backlog
    end = time.monotonic() + secs
    with open(out, "w") as f:
        f.write("t_s,app_ms,visible_ms,latency_ms,pid\n")
        while time.monotonic() < end:
            r = libc.msgrcv(qid, buf, 8184, 0, IPC_NOWAIT)
            if r < 0: time.sleep(0.002); continue
            ver, pid, app = struct.unpack_from("<IIQ", buf.raw, 8)
            vis, lat = struct.unpack_from("<QQ", buf.raw, 8 + 16 + 2)
            g = lambda v: "" if v >= 2**63 else f"{v/1e6:.3f}"
            f.write(f"{time.monotonic():.4f},{g(app)},{g(vis)},{g(lat)},{pid}\n"); n += 1
finally:
    for p in pids: os.kill(p, signal.SIGCONT)
print(f"{n} frames in {secs:.0f} s -> {out}")
