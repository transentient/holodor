import wave,struct,math,sys
for f in sys.argv[1:]:
    w=wave.open(f); n=w.getnframes(); d=struct.unpack("<%dh"%(2*n),w.readframes(n)); r=48000
    def g(x,fr):
        k=2*math.cos(2*math.pi*fr/r); a=b=0
        for v in x: a,b=v+k*a-b,a
        return math.sqrt(max(a*a+b*b-k*a*b,0))/len(x)*2
    L=d[0::2]; R=d[1::2]
    print(f.split("/")[-1], "game-left tone: FL %.0f FR %.0f | game-right tone: FL %.0f FR %.0f"%(g(L,440),g(R,440),g(L,880),g(R,880)), "=> SWAPPED" if g(R,440)>g(L,440) else "=> correct")
