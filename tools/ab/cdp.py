#!/usr/bin/env python3
# cdp.py TAB_TITLE JS_EXPRESSION  - evaluate JS in a Steam CEF tab over the DevTools protocol
# (port 8080, enabled by pocknix-steam's .cef-enable-remote-debugging). Raw websocket client:
# the image has no websocket library. Prints the JSON result value (awaits promises).
import json, os, socket, struct, sys, urllib.request

title, expr = sys.argv[1], sys.argv[2]
tabs = json.load(urllib.request.urlopen("http://127.0.0.1:8080/json", timeout=3))
tab = next((t for t in tabs if t["title"] == title or t["title"].startswith(title)), None)
if not tab:
    sys.exit(f"no tab titled {title!r}: {[t['title'] for t in tabs]}")
path = tab["webSocketDebuggerUrl"].split("8080", 1)[1]
s = socket.create_connection(("127.0.0.1", 8080), timeout=15)
key = os.urandom(16).hex()[:22] + "=="
s.sendall(f"GET {path} HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n".encode())
buf = b""
while b"\r\n\r\n" not in buf:
    buf += s.recv(4096)
if b" 101 " not in buf.split(b"\r\n", 1)[0]:
    sys.exit("websocket handshake failed: " + buf.split(b"\r\n", 1)[0].decode())
rest = buf.split(b"\r\n\r\n", 1)[1]

def send(obj):
    data = json.dumps(obj).encode()
    mask = os.urandom(4)
    hdr = bytes([0x81])
    n = len(data)
    if n < 126: hdr += bytes([0x80 | n])
    elif n < 65536: hdr += bytes([0x80 | 126]) + struct.pack(">H", n)
    else: hdr += bytes([0x80 | 127]) + struct.pack(">Q", n)
    s.sendall(hdr + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

def recv_frame():
    global rest
    def need(n):
        global rest
        while len(rest) < n:
            chunk = s.recv(65536)
            if not chunk: raise EOFError
            rest += chunk
        out, rest = rest[:n], rest[n:]
        return out
    b0, b1 = need(2)
    n = b1 & 0x7F
    if n == 126: n = struct.unpack(">H", need(2))[0]
    elif n == 127: n = struct.unpack(">Q", need(8))[0]
    if b1 & 0x80: need(4)
    payload = need(n)
    return b0 & 0x0F, payload

send({"id": 1, "method": "Runtime.evaluate", "params": {"expression": expr, "awaitPromise": True, "returnByValue": True}})
while True:
    op, payload = recv_frame()
    if op != 1: continue
    msg = json.loads(payload)
    if msg.get("id") == 1:
        r = msg.get("result", {})
        if "exceptionDetails" in r:
            print("EXCEPTION:", json.dumps(r["exceptionDetails"].get("exception", {}).get("description", r["exceptionDetails"]))[:500])
        else:
            print(json.dumps(r.get("result", {}).get("value"))[:2000])
        break
