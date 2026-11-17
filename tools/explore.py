import math, sys
sys.path.insert(0,'.')
from layoutlib import *
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

MAPS = {}
# Deserto
MAPS['deserto'] = [
 (-380, 430, 110), (420, 430, 120), (690, 250, 90), (710, -70, 150), (520, -230, 60),
 (700, -430, 90), (420, -530, 110), (120, -420, 70), (-140, -570, 100), (-450, -450, 90),
 (-710, -230, 110), (-560, 20, 70), (-330, 50, 60), (-250, 250, 80),
]
# Gelo (alongado, zigue-zague no lado oeste)
MAPS['gelo'] = [
 (-120, 560, 100), (380, 560, 120), (470, 300, 130), (400, 0, 120), (470, -300, 120),
 (330, -600, 100), (60, -700, 90), (-200, -640, 70), (-80, -480, 45), (-330, -420, 55),
 (-120, -270, 45), (-380, -190, 55), (-140, -40, 45), (-390, 60, 55), (-160, 200, 45),
 (-420, 330, 80),
]
# Vulcao (anel em volta da cratera com idas e vindas)
MAPS['vulcao'] = [
 (-300, 640, 110), (260, 640, 110), (610, 430, 100), (700, 80, 120), (500, -90, 55),
 (690, -330, 90), (480, -600, 100), (130, -520, 55), (-120, -680, 100), (-480, -560, 90),
 (-690, -250, 110), (-520, -60, 50), (-700, 150, 80), (-560, 430, 100),
]
fig, axs = plt.subplots(1, 3, figsize=(21, 7))
for ax, (name, v) in zip(axs, MAPS.items()):
    p = build_path(v)
    print(name, 'L=%.0f' % p['L'], p['problems'])
    for c in p['corners']:
        pass
    pts = [point_at(p, s) for s in [i*5.0 for i in range(int(p['L']/5))]]
    ax.plot([a[0] for a in pts]+[pts[0][0]], [a[1] for a in pts]+[pts[0][1]], '-', lw=1.5)
    ax.plot([a[0] for a in v], [a[1] for a in v], 'r.', ms=4)
    ax.set_aspect('equal'); ax.invert_yaxis(); ax.set_title(name + ' %.1f km' % (p['L']/1000)); ax.grid(True, alpha=.3)
    cps = control_points(p, [(0, 5.0)], 0.0)
    rp, length, count, frac = resample(cps)
    print('  resample length %.0f count %d frac %.3f' % (length, count, frac))
    d, wi = min_separation(rp)
    print('  min separation %.0f at' % d, wi)
plt.tight_layout(); plt.savefig('explore.png', dpi=60)
