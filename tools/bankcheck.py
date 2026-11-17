import sys, math
sys.path.insert(0,'/home/claude/tools')
import gen3, specs3
SP=2.5
def banks_for(r, gain, bmax, win=5, w=6, fade=16, twists=True):
    pts=r['pts']; n=len(pts)
    tans=[]
    for i in range(n):
        a=pts[(i-1)%n]; b=pts[(i+1)%n]
        dx=b[0]-a[0]; dz=b[2]-a[2]; l=math.hypot(dx,dz); tans.append((dx/l,dz/l))
    raw=[]
    for i in range(n):
        t1=tans[(i-w)%n]; t2=tans[(i+w)%n]
        cr=t1[0]*t2[1]-t1[1]*t2[0]
        k=math.asin(max(-1,min(1,cr)))/(2*w*SP)
        raw.append(-max(-bmax,min(bmax,k*gain)))
    dist=[9999]*n
    marks=[(i0-12,i0+ng+16) for i0,ng,_ in r['gaps']]+[(a-8,b+8) for a,b,_ in r['bridges']]+[(a-4,b+4) for a,b,_ in r['tunnels']]+[(x-6,x+8) for x in r['ramps']]
    for a,b in marks:
        for i in range(a,b+1): dist[i%n]=0
    for _ in range(2):
        for i in range(n): dist[i]=min(dist[i],dist[(i-1)%n]+1)
        for i in range(n-1,-1,-1): dist[i]=min(dist[i],dist[(i+1)%n]+1)
    def sm(t): t=max(0,min(1,t)); return t*t*(3-2*t)
    bk=[]
    for i in range(n):
        acc=sum(raw[(i+o)%n] for o in range(-win,win+1))/(2*win+1)
        bk.append(acc*sm(dist[i]/fade))
    if twists:
        for (i0,i1,a0,a1) in r['twists']:
            span=max(i1-i0,1)
            for i in range(i0,i1+1):
                u=(i-i0)/span; ang=a0+(a1-a0)*sm(u); wg=sm(min(i-i0,i1-i)/14)
                ii=i%n; bk[ii]=bk[ii]*(1-wg)+math.tan(math.radians(ang))*wg
    return bk
def analyze(name, r, gain, bmax, win, fade, twist=True, lats=(-8,0,8), v=31.0):
    bk=banks_for(r,gain,bmax,win,6,fade,twist); pts=r['pts']; n=len(pts)
    gaps=r['gaps']
    skip=set()
    for i0,ng,_ in gaps:
        for i in range(i0-4,i0+ng+6): skip.add(i%n)
    worst=(0,0,0); cnt=0; roll=0
    for lat in lats:
        ys=[pts[i][1]+lat*bk[i] for i in range(n)]
        for i in range(n):
            if i in skip: continue
            yy=(ys[(i+1)%n]-2*ys[i]+ys[(i-1)%n])/(SP*SP)
            a=v*v*yy
            if a<-0.7*27: cnt+=1
            if a<worst[0]: worst=(a,i,lat)
    for i in range(n):
        d=abs(bk[(i+1)%n]-bk[i])/SP
        roll=max(roll,d)
    print(f"{name} gain={gain} max={bmax} win={win}: peak convex accel {worst[0]:.0f} m/s2 (limit -19 launch) @i={worst[1]} lat={worst[2]}  samples>0.7g={cnt}  max d(bank)/ds={roll:.3f}/m  max |bank|={max(abs(b) for b in bk):.2f}")
if __name__=='__main__':
    for nm in ('lagoa','cume','selva'):
        r=gen3.build_map3(nm,specs3.SPEC3[nm]); sp=specs3.SPEC3[nm]
        analyze(nm,r,sp['bank_gain'],sp['bank_max'],5,16)
