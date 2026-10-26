#!/usr/bin/env python3
# abpad.py ACTION [ACTION...] — virtual Xbox-360-style gamepad via uinput (root).
# ACTIONS: a b x y start select guide lb rb up down left right  (tap), 'hold:a:500' (ms),
#          'lt' 'rt' (trigger tap), 'ls:X:Y' / 'rs:X:Y' (stick to -1..1 for 300ms), 'sleep:N'
# The device stays alive for the whole argument list, then closes.
import sys, time
from evdev import UInput, ecodes as e, AbsInfo
btn={'a':e.BTN_SOUTH,'b':e.BTN_EAST,'x':e.BTN_NORTH,'y':e.BTN_WEST,'start':e.BTN_START,'select':e.BTN_SELECT,
     'guide':e.BTN_MODE,'lb':e.BTN_TL,'rb':e.BTN_TR,'l3':e.BTN_THUMBL,'r3':e.BTN_THUMBR}
ai=AbsInfo(0,-32768,32767,16,128,0); ti=AbsInfo(0,0,255,0,0,0); hi=AbsInfo(0,-1,1,0,0,0)
cap={e.EV_KEY:list(btn.values()), e.EV_ABS:[(e.ABS_X,ai),(e.ABS_Y,ai),(e.ABS_RX,ai),(e.ABS_RY,ai),(e.ABS_Z,ti),(e.ABS_RZ,ti),(e.ABS_HAT0X,hi),(e.ABS_HAT0Y,hi)]}
ui=UInput(cap,name='Microsoft X-Box 360 pad',vendor=0x045e,product=0x028e,version=0x110); time.sleep(1.5)
def tap(code,ms=90): ui.write(e.EV_KEY,code,1); ui.syn(); time.sleep(ms/1000); ui.write(e.EV_KEY,code,0); ui.syn()
def hat(x,y,ms=90): ui.write(e.EV_ABS,e.ABS_HAT0X,x); ui.write(e.EV_ABS,e.ABS_HAT0Y,y); ui.syn(); time.sleep(ms/1000); ui.write(e.EV_ABS,e.ABS_HAT0X,0); ui.write(e.EV_ABS,e.ABS_HAT0Y,0); ui.syn()
for a in sys.argv[1:]:
    if a.startswith('sleep:'): time.sleep(float(a[6:])); continue
    if a.startswith('hold:'): _,k,ms=a.split(':'); tap(btn[k],int(ms)); time.sleep(0.3); continue
    if a in btn: tap(btn[a]); time.sleep(0.45); continue
    if a=='up': hat(0,-1)
    elif a=='down': hat(0,1)
    elif a=='left': hat(-1,0)
    elif a=='right': hat(1,0)
    elif a in ('lt','rt'):
        c=e.ABS_Z if a=='lt' else e.ABS_RZ; ui.write(e.EV_ABS,c,255); ui.syn(); time.sleep(0.12); ui.write(e.EV_ABS,c,0); ui.syn()
    elif a.startswith('ls:') or a.startswith('rs:'):
        s,x,y=a.split(':'); cx,cy=(e.ABS_X,e.ABS_Y) if s=='ls' else (e.ABS_RX,e.ABS_RY)
        ui.write(e.EV_ABS,cx,int(float(x)*32767)); ui.write(e.EV_ABS,cy,int(float(y)*32767)); ui.syn(); time.sleep(0.3)
        ui.write(e.EV_ABS,cx,0); ui.write(e.EV_ABS,cy,0); ui.syn()
    time.sleep(0.45)
time.sleep(0.3); ui.close()
