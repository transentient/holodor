import sys, wave, math, struct
# env.py <wav> [f1 f2 ...]: per-100 ms level (dBFS) of each tone, left channel (and right for the first tone)
w=wave.open(sys.argv[1]); fs=w.getframerate(); n=w.getnframes(); d=struct.unpack("<%dh"%(2*n), w.readframes(n))
fr=[float(x) for x in sys.argv[2:]] or [1000.0]
def g(seg,f):
    k=2*math.cos(2*math.pi*f/fs); a=b=0.0
    for v in seg: a,b=v+k*a-b,a
    return 20*math.log10(max(math.sqrt(max(a*a+b*b-k*a*b,0))*2/len(seg)/math.sqrt(2),1e-3)/32768)
L=d[0::2]; R=d[1::2]; W=fs//10
for i in range(0,len(L)-W,W):
    print("%5.1f s  "%(i/fs)+"  ".join("%6.1f"%g(L[i:i+W],f) for f in fr)+"   R %6.1f"%g(R[i:i+W],fr[0]))
