#!/usr/bin/env python3
# steamjs.py [--target NAME] '<javascript expression>' : evaluate JS inside Steam's UI over its CEF
# remote-debugging port (127.0.0.1:8080, enabled on Holodor because Decky needs it). Run ON the device.
# Default target: SharedJSContext (where SteamClient.* lives). Prints the JSON result.
# Minimal websocket client (no third-party modules).
import base64, json, os, socket, struct, sys, urllib.request
target = "SharedJSContext"; args = sys.argv[1:]
if args and args[0] == "--target": target = args[1]; args = args[2:]
expr = args[0]
tabs = json.load(urllib.request.urlopen("http://127.0.0.1:8080/json", timeout=5))
ws = next(t["webSocketDebuggerUrl"] for t in tabs if t.get("title", "").startswith(target))
path = ws.split("8080", 1)[1]
s = socket.create_connection(("127.0.0.1", 8080), timeout=15)
key = base64.b64encode(os.urandom(16)).decode()
s.sendall((f"GET {path} HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
           f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
buf = b""
while b"\r\n\r\n" not in buf: buf += s.recv(4096)
buf = buf.split(b"\r\n\r\n", 1)[1]
def send(obj):
    p = json.dumps(obj).encode(); mask = os.urandom(4)
    hdr = bytes([0x81]) + (bytes([0x80 | len(p)]) if len(p) < 126 else bytes([0x80 | 126]) + struct.pack(">H", len(p)) if len(p) < 65536 else bytes([0x80 | 127]) + struct.pack(">Q", len(p)))
    s.sendall(hdr + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(p)))
def need(n):
    global buf
    while len(buf) < n:
        d = s.recv(65536)
        if not d: raise EOFError
        buf += d
    r, buf = buf[:n], buf[n:]; return r
def recv():
    msg = b""
    while True:
        b0, b1 = need(2); ln = b1 & 0x7f
        if ln == 126: ln = struct.unpack(">H", need(2))[0]
        elif ln == 127: ln = struct.unpack(">Q", need(8))[0]
        data = need(ln)
        if b0 & 0x0f in (0, 1, 2): msg += data
        if b0 & 0x80 and b0 & 0x0f in (0, 1, 2): return json.loads(msg)
send({"id": 1, "method": "Runtime.evaluate", "params": {"expression": expr, "awaitPromise": True, "returnByValue": True}})
while True:
    m = recv()
    if m.get("id") == 1:
        r = m.get("result", {})
        if "exceptionDetails" in r: print("JS ERROR:", r["exceptionDetails"].get("exception", {}).get("description", r["exceptionDetails"])); sys.exit(1)
        print(json.dumps(r.get("result", {}).get("value"), indent=1)); break
