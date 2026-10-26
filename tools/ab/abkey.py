#!/usr/bin/env python3
# abkey.py KEY [KEY...]  — tap keys via a uinput keyboard (gamescope -> Xwayland -> game). Run as root.
# KEY names: enter down up left right esc tab space f1..f12 a-z, or 'sleep:N' (seconds), 'hold:KEY:MS'
import sys, time
from evdev import UInput, ecodes as e
names={'enter':e.KEY_ENTER,'down':e.KEY_DOWN,'up':e.KEY_UP,'left':e.KEY_LEFT,'right':e.KEY_RIGHT,'esc':e.KEY_ESC,
       'tab':e.KEY_TAB,'space':e.KEY_SPACE,'bksp':e.KEY_BACKSPACE,'pgdn':e.KEY_PAGEDOWN,'pgup':e.KEY_PAGEUP,
       'meta':e.KEY_LEFTMETA,'alt':e.KEY_LEFTALT,'ctrl':e.KEY_LEFTCTRL,'shift':e.KEY_LEFTSHIFT}
for i in range(1,13): names['f%d'%i]=getattr(e,'KEY_F%d'%i)
for c in 'abcdefghijklmnopqrstuvwxyz0123456789': names[c]=getattr(e,'KEY_'+c.upper())
ui=UInput({e.EV_KEY:list(set(names.values()))}, name='holodor-ab-kbd'); time.sleep(1.2)
def tap(k,ms=80): ui.write(e.EV_KEY,k,1); ui.syn(); time.sleep(ms/1000); ui.write(e.EV_KEY,k,0); ui.syn()
for a in sys.argv[1:]:
    if a.startswith('sleep:'): time.sleep(float(a[6:])); continue
    if a.startswith('hold:'): _,k,ms=a.split(':'); tap(names[k],int(ms)); time.sleep(0.4); continue
    if '+' in a:  # chord e.g. meta+f
        ks=[names[x] for x in a.split('+')]
        for k in ks: ui.write(e.EV_KEY,k,1); ui.syn(); time.sleep(0.05)
        for k in reversed(ks): ui.write(e.EV_KEY,k,0); ui.syn(); time.sleep(0.05)
        time.sleep(0.5); continue
    tap(names[a]); time.sleep(0.5)
ui.close()
