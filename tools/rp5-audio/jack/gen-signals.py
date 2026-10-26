#!/usr/bin/env python3
# gen-signals.py <outdir>: fs1k.wav = full-scale 1 kHz 3 s + 2 s digital silence (level + THD via thd.py);
# burst.wav = 1 kHz probe at -30 dBFS for 6 s with 220 Hz bursts at -1 dBFS from 4.0 s, 0.5 s on / 0.5 s off
# (ducking via env.py: probe level between vs during bursts). 48 kHz stereo S16.
import sys,wave,struct,math,os
fs=48000; out=sys.argv[1] if len(sys.argv)>1 else '.'
def w(path,frames):
    f=wave.open(path,'wb'); f.setnchannels(2); f.setsampwidth(2); f.setframerate(fs); f.writeframes(b''.join(struct.pack('<hh',v,v) for v in frames)); f.close()
w(os.path.join(out,'fs1k.wav'),[int(32767*math.sin(2*math.pi*1000*i/fs)) for i in range(3*fs)]+[0]*(2*fs))
fr=[]
for i in range(6*fs):
    t=i/fs; v=0.0316*math.sin(2*math.pi*1000*t)
    if t>=4.0 and int((t-4.0)*2)%2==0: v+=0.89*math.sin(2*math.pi*220*t)
    fr.append(int(max(-32767,min(32767,v*32767))))
w(os.path.join(out,'burst.wav'),fr); print("fs1k.wav + burst.wav written to", out)
