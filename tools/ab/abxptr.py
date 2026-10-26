#!/usr/bin/env python3
# abxptr.py [:0|:1] -> "root WxH pointer X Y" via XQueryPointer (ctypes, no python-xlib needed)
import ctypes, sys, os
d=sys.argv[1] if len(sys.argv)>1 else os.environ.get('DISPLAY',':1')
X=ctypes.CDLL('libX11.so.6'); X.XOpenDisplay.restype=ctypes.c_void_p; X.XDefaultRootWindow.restype=ctypes.c_ulong
dpy=X.XOpenDisplay(d.encode()); 
if not dpy: print(d,'open failed'); sys.exit(1)
root=X.XDefaultRootWindow(ctypes.c_void_p(dpy))
class Attr(ctypes.Structure): _fields_=[('x',ctypes.c_int),('y',ctypes.c_int),('width',ctypes.c_int),('height',ctypes.c_int),('pad',ctypes.c_byte*200)]
a=Attr(); X.XGetWindowAttributes(ctypes.c_void_p(dpy),ctypes.c_ulong(root),ctypes.byref(a))
r=ctypes.c_ulong(); c=ctypes.c_ulong(); rx=ctypes.c_int(); ry=ctypes.c_int(); wx=ctypes.c_int(); wy=ctypes.c_int(); m=ctypes.c_uint()
ok=X.XQueryPointer(ctypes.c_void_p(dpy),ctypes.c_ulong(root),ctypes.byref(r),ctypes.byref(c),ctypes.byref(rx),ctypes.byref(ry),ctypes.byref(wx),ctypes.byref(wy),ctypes.byref(m))
print(d,'root',a.width,'x',a.height,'pointer',rx.value,ry.value,'child',hex(c.value))
