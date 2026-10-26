#!/usr/bin/env python3
# abxtree.py [:0] -> top-level X windows (bottom->top stacking): id, geometry, mapped, name
import ctypes, sys, os
d=sys.argv[1] if len(sys.argv)>1 else ':0'
X=ctypes.CDLL('libX11.so.6'); X.XOpenDisplay.restype=ctypes.c_void_p; X.XDefaultRootWindow.restype=ctypes.c_ulong
dpy=X.XOpenDisplay(d.encode()); root=X.XDefaultRootWindow(ctypes.c_void_p(dpy))
r=ctypes.c_ulong(); p=ctypes.c_ulong(); ch=ctypes.POINTER(ctypes.c_ulong)(); n=ctypes.c_uint()
X.XQueryTree(ctypes.c_void_p(dpy),ctypes.c_ulong(root),ctypes.byref(r),ctypes.byref(p),ctypes.byref(ch),ctypes.byref(n))
class Attr(ctypes.Structure): _fields_=[('x',ctypes.c_int),('y',ctypes.c_int),('width',ctypes.c_int),('height',ctypes.c_int),('border',ctypes.c_int),('depth',ctypes.c_int),('visual',ctypes.c_void_p),('root',ctypes.c_ulong),('cls',ctypes.c_int),('bg',ctypes.c_int),('bs',ctypes.c_int),('bp',ctypes.c_ulong),('pad',ctypes.c_byte*400)]
X.XFetchName.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(ctypes.c_char_p)]
for i in range(n.value):
    w=ch[i]; a=Attr(); X.XGetWindowAttributes(ctypes.c_void_p(dpy),ctypes.c_ulong(w),ctypes.byref(a))
    # map_state is at a fixed offset; simpler: use XGetWindowAttributes's map_state via struct layout is fragile -> use XGetWindowProperty for WM_NAME only
    nm=ctypes.c_char_p(); X.XFetchName(ctypes.c_void_p(dpy),ctypes.c_ulong(w),ctypes.byref(nm))
    name=nm.value.decode(errors='replace') if nm.value else ''
    if a.width>50 and a.height>50: print(hex(w),'%dx%d+%d+%d'%(a.width,a.height,a.x,a.y),repr(name))
