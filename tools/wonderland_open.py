import sys
sys.path.insert(0, '/home/claude/proj/tools')
import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import wonderland_design as D
from wonderland_path import *
from wonderland_plot import COL
pieces = [dict(p) for p in D.PIECES]
apply_heading_closure(pieces, D.CLOSING_ARC, D.TOTAL_TURN)
lens = {p['name']: p['h'] for p in pieces}
lens['s8_adj1']=1.0; lens['s8_adj2']=1.0
# fixed climb factor 1
plist, ks, ss, lift, pid = integrate(pieces, lens)
xs, zs, ys, th = trace(ks, ss, lift, 0.0, D.Y0)
print('end', xs[-1], zs[-1], ys[-1], 'heading deg', np.degrees(th[-1]) % 360)
fig, ax = plt.subplots(1,1, figsize=(14,12))
n=len(xs)-1
for k in range(n):
    ax.plot(xs[k:k+2], zs[k:k+2], color=COL[plist[pid[k]]['sector']], lw=2)
for p_i,q in enumerate(plist):
    k=int(np.argmax(pid==p_i)); ax.text(xs[k], zs[k], q['name'], fontsize=7)
ax.set_aspect('equal'); ax.grid(alpha=.3)
plt.savefig('/home/claude/work/wl_open.png', dpi=60)
