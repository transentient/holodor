#!/usr/bin/env python3
# abmouse.py X Y [click|move|dblclick] [step]  — uinput relative mouse, small steps (default 4 px) so
# Windows/wine pointer acceleration stays 1:1. Homes to top-left first, then walks to (X,Y) in X-root
# coords, then closed-loop corrects against XQueryPointer on :1 (falls back silently if unavailable).
import sys, time, subprocess
from evdev import UInput, ecodes as e
x,y=int(sys.argv[1]),int(sys.argv[2]); act=sys.argv[3] if len(sys.argv)>3 else 'click'; step=int(sys.argv[4]) if len(sys.argv)>4 else 4
ui=UInput({e.EV_KEY:[e.BTN_LEFT,e.BTN_RIGHT],e.EV_REL:[e.REL_X,e.REL_Y,e.REL_WHEEL]}, name='holodor-ab-mouse'); time.sleep(1.0)
def mv(dx,dy,st):
    while dx or dy:
        sx=max(-st,min(st,dx)); sy=max(-st,min(st,dy))
        ui.write(e.EV_REL,e.REL_X,sx); ui.write(e.EV_REL,e.REL_Y,sy); ui.syn(); dx-=sx; dy-=sy; time.sleep(0.002)
def xptr():
    try:
        out=subprocess.run(['abxptr.py',':1'],capture_output=True,text=True,timeout=3).stdout.split()
        i=out.index('pointer'); return int(out[i+1]),int(out[i+2])
    except Exception: return None
mv(-2500,-2500,step); time.sleep(0.15); mv(x,y,step); time.sleep(0.15)
for _ in range(3):
    p=xptr()
    if not p or (p[0]==x and p[1]==y): break
    mv(x-p[0],y-p[1],step); time.sleep(0.1)
print('xptr:',xptr())
def click():
    ui.write(e.EV_KEY,e.BTN_LEFT,1); ui.syn(); time.sleep(0.07); ui.write(e.EV_KEY,e.BTN_LEFT,0); ui.syn()
if act=='click': click()
elif act=='dblclick': click(); time.sleep(0.12); click()
time.sleep(0.3); ui.close()
