import wave,struct,math,sys
# audiochk.py <wav>: level statistics and dropout count of a jack recording (left channel, 10 ms windows)
w=wave.open(sys.argv[1]); n=w.getnframes(); d=struct.unpack("<%dh"%(2*n),w.readframes(n)); fs=48000; L=d[0::2]; R=d[1::2]
W=fs//100; db=[20*math.log10(max((sum(v*v for v in L[i:i+W])/W)**.5,0.3)/32768) for i in range(0,len(L)-W,W)]
s=sorted(db); print("jack audio: 10 ms rms median %.1f dBFS, p5 %.1f, p95 %.1f, max %.1f, peak sample L %d R %d"%(s[len(s)//2],s[len(s)//20],s[-len(s)//20],s[-1],max(abs(v) for v in L),max(abs(v) for v in R)))
gaps=0; run=0; prev=-99
for i,x in enumerate(db):
    if x<-80: run+=1
    else:
        if 1<=run<=30 and prev>-65 and x>-65: gaps+=1
        run=0; prev=x
print("abrupt silent gaps (10-300 ms, loud on both sides): %d"%gaps)
