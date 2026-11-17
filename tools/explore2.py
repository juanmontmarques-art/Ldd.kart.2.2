import sys; sys.path.insert(0,'.')
from layoutlib import *
from specs import *
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, axs = plt.subplots(1,3, figsize=(24,8))
for ax,(name,v) in zip(axs, [('deserto',DESERTO),('gelo',GELO),('vulcao',VULCAO)]):
    p = build_path(v)
    print(name, 'L=%.0f'%p['L'], p['problems'])
    cps = control_points(p, [(0,5.0)], 0.0)
    rp, length, count, frac = resample(cps)
    d, wi = min_separation(rp)
    print('  resample %.0f count %d frac %.3f minsep %.0f'%(length,count,frac,d), wi)
    ax.plot([a[0] for a in rp]+[rp[0][0]],[a[2] for a in rp]+[rp[0][2]],'-',lw=1.5)
    ax.plot([a[0] for a in v],[a[1] for a in v],'r.',ms=5)
    for i,a in enumerate(v): ax.annotate(str(i),(a[0],a[1]),fontsize=8)
    ax.set_aspect('equal'); ax.invert_yaxis(); ax.grid(True,alpha=.3); ax.set_title('%s %.1f km'%(name,p['L']/1000))
plt.tight_layout(); plt.savefig('explore2.png',dpi=55)
