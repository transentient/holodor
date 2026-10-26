import os, sys, json, threading, time
from gi.repository import Gio, GLib
r, w = os.pipe()
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None); print("bus ok", flush=True)
fdl = Gio.UnixFDList.new(); idx = fdl.append(w)
buf = bytearray()
def reader():
    while True:
        b = os.read(r, 1 << 20)
        if not b: break
        buf.extend(b)
threading.Thread(target=reader, daemon=True).start()
loop = GLib.MainLoop(); out = {}
def done(src, res):
    try:
        v, _ = src.call_with_unix_fd_list_finish(res); out["meta"] = v.unpack()[0]
    except Exception as e:
        out["err"] = str(e)
    loop.quit()
opts = GLib.Variant("a{sv}", {"native-resolution": GLib.Variant("b", True)})
bus.call_with_unix_fd_list("org.kde.KWin", "/org/kde/KWin/ScreenShot2", "org.kde.KWin.ScreenShot2", sys.argv[2],
    GLib.Variant.new_tuple(opts, GLib.Variant("h", idx)), None, Gio.DBusCallFlags.NONE, 8000, fdl, None, done)
GLib.timeout_add_seconds(10, loop.quit); loop.run(); os.close(w); time.sleep(0.5)
print(out.get("err") or {k: v for k, v in out.get("meta", {}).items()}, len(buf), flush=True)
if buf: open(sys.argv[1], "wb").write(buf); json.dump({k: int(v) if isinstance(v,(int,float)) else str(v) for k, v in out.get("meta", {}).items()}, open(sys.argv[1] + ".json", "w"))
os._exit(0)
