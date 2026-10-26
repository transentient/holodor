import sys, wave, math, struct
# thd.py <wav> <f0> <t0> <t1>: level of f0 and harmonics 2..5 (dB rel. fundamental), both channels; plus rms of everything
w=wave.open(sys.argv[1]); fs=w.getframerate(); n=w.getnframes(); d=struct.unpack("<%dh"%(2*n), w.readframes(n))
f0=float(sys.argv[2]); a=int(float(sys.argv[3])*fs); b=int(float(sys.argv[4])*fs)
def g(seg,f):
    N=len(seg); k=2*math.cos(2*math.pi*f/fs); s1=s2=0.0
    for i,v in enumerate(seg):
        v*=0.5-0.5*math.cos(2*math.pi*i/N); s0=v+k*s1-s2; s2=s1; s1=s0
    return 20*math.log10(max(math.sqrt(max(s1*s1+s2*s2-k*s1*s2,0))*4/N/math.sqrt(2),1e-3)/32768)
for ch,nm in ((0,"L"),(1,"R")):
    s=d[ch::2][a:b]; f=g(s,f0); h=[g(s,f0*m)-f for m in (2,3,4,5)]
    thd=10*math.log10(sum(10**(x/10) for x in h))
    print("%s f0 %.1f dBFS  H2..5 %s  THD %.1f dB (%.2f %%) peak %d"%(nm,f," ".join("%.0f"%x for x in h),thd,100*10**(thd/20),max(abs(v) for v in s)))
