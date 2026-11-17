import sys, math, random
sys.path.insert(0,'/home/claude/tools')
from layoutlib import *
from specs import *
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt

def smooth_mask(path, flat_edges, window=100.0):
    L = path['L']; step = 5.0; n = int(L/step)
    raw = []
    for i in range(n):
        s = i*step
        m = 1.0
        for g in path['segs']:
            if s <= g['s1']:
                if g['kind']=='line' and g['i'] in flat_edges: m = 0.0
                break
        raw.append(m)
    k = int(window/step)
    sm = []
    for i in range(n):
        acc = 0.0
        for o in range(-k, k+1): acc += raw[(i+o) % n]
        sm.append(acc/(2*k+1))
    return lambda s: sm[int((s % L)/step) % n]

def build_map(name, verts, anchors_v, start_edge_frac, feats, flat_extra, lakes_n, peak, seed, amp=1.8, ctrl_spacing=40.0):
    p = build_path(verts)
    assert not p['problems'], p['problems']
    L = p['L']
    start_s = edge_station(p, 0, start_edge_frac)
    anchors = sorted([(corner_station(p, i), h) for i, h in enumerate(anchors_v)])
    flat_edges = set()
    for f in feats:
        if f[0] in ('gap','cliff','canyon'): flat_edges.add(f[1])
    mask = smooth_mask(p, flat_edges)
    und = lambda s: amp*math.sin(s/120.0+seed)*mask(s)
    cps = control_points(p, anchors, start_s, ctrl_spacing, und)
    pts, length, count, frac = resample(cps)
    sep, wi = min_separation(pts)
    grade = max_grade(pts)
    def idx_of(s):
        guess = int(round(((s-start_s) % L)/L*count))
        x, z = point_at(p, s)
        best = None; bd = 1e18
        for o in range(-14, 15):
            i = (guess+o) % count
            d = (pts[i][0]-x)**2+(pts[i][2]-z)**2
            if d < bd: bd = d; best = i
        return best
    # helper: edge segment
    seg_of = {g['i']: g for g in p['segs'] if g['kind']=='line'}
    out = dict(gaps=[], cliffs=[], canyons=[], pads=[], pad_lats=[], ramps=[], boxes=[], barrels=[], movers=[])
    taken = []   # (i0,i1) ranges occupied
    def free(i0, i1, margin=25):
        for a, b in taken:
            if i0-margin < b and i1+margin > a: return False
        return True
    warns = []
    for f in feats:
        kind, edge = f[0], f[1]
        g = seg_of[edge]
        if kind == 'gap':
            _, _, frac_, n, drop = f
            s = g['s0']+g['L']*frac_
            c = idx_of(s); i0 = c - n//2
            need_pre = (i0*SPACING) - 0
            # margins on straight
            if s - (n*SPACING/2+14) < g['s0']+40 or s + n*SPACING/2 + 40 > g['s1']:
                warns.append(f"{name} gap edge {edge} frac {frac_}: tight on straight ({g['L']:.0f} m)")
            out['gaps'].append((i0, n, drop)); taken.append((i0-8, i0+n+6))
            out['pads'].append(i0-16); out['pad_lats'].append(-3.0)
            out['pads'].append(i0-16); out['pad_lats'].append(3.0)
        elif kind in ('cliff','canyon'):
            _, _, f0, f1 = f
            i0 = idx_of(g['s0']+g['L']*f0); i1 = idx_of(g['s0']+g['L']*f1)
            out['cliffs' if kind=='cliff' else 'canyons'].append((i0, i1)); taken.append((i0, i1))
        elif kind == 'barrel':
            i = idx_of(g['s0']+g['L']*f[2]); out['barrels'].append(i); taken.append((i-6, i+34))
        elif kind == 'mover':
            i = idx_of(g['s0']+g['L']*f[2]); out['movers'].append(i); taken.append((i-6, i+6))
        elif kind == 'ramp':
            i = idx_of(g['s0']+g['L']*f[2]); out['ramps'].append(i); taken.append((i-6, i+6))
        elif kind == 'pad':
            i = idx_of(g['s0']+g['L']*f[2]); out['pads'].append(i); out['pad_lats'].append(f[3]); taken.append((i-3, i+3))
    # pads na saida dos hairpins
    for g in p['segs']:
        if g['kind']=='arc' and math.degrees(g['theta']) > 95:
            i = idx_of(g['s1']+45)
            if free(i-3, i+3, 10):
                out['pads'].append(i); out['pad_lats'].append(0.0); taken.append((i-3, i+3))
    # caixas de item a cada ~190 amostras, fora de abismos/penhascos
    i = 70
    while i < count-80:
        j = i
        ok = False
        for _ in range(12):
            if free(j-4, j+4, 14) and not any(a-20 < j < b+20 for a, b in out['cliffs']+out['canyons']):
                ok = True; break
            j += 12
        if ok: out['boxes'].append(j)
        i = max(j, i) + 170
    out['boxes'] = sorted(set(out['boxes']))
    # lagos automaticos (longe da pista e do pico)
    lakes = []
    xs = [q[0] for q in pts]; zs = [q[2] for q in pts]
    cand = []
    for x in range(int(min(xs))-60, int(max(xs))+60, 40):
        for z in range(int(min(zs))-60, int(max(zs))+60, 40):
            d = min(math.hypot(x-q[0], z-q[2]) for q in pts[::6])
            if peak: d2 = math.hypot(x-peak[0], z-peak[1]) - peak[2]
            else: d2 = 999
            cand.append((min(d, d2+260), x, z, d))
    cand.sort(reverse=True)
    for sc, x, z, d in (cand if not isinstance(lakes_n, list) else []):
        if len(lakes) >= lakes_n[0]: break
        if all(math.hypot(x-l[0], z-l[1]) > 420 for l in lakes) and d > lakes_n[2]:
            lakes.append((x, z, lakes_n[1], 0.0))
    if isinstance(lakes_n, list):
        lakes = [(x, z, rr, 0.0) for (x, z, rr) in lakes_n]
    out['lakes'] = lakes
    out['peak'] = peak
    out['pts'] = pts; out['cps'] = cps; out['count'] = count; out['length'] = length
    out['sep'] = sep; out['grade'] = grade; out['warns'] = warns; out['frac'] = frac
    out['path'] = p
    return out

SPEC = {}
# ---------------- DESERTO ----------------
SPEC['deserto'] = dict(verts=DESERTO,
    anchors=[6,8,14,22,26,30,34,38,38,38,38,30,22,18,12,8],
    start=0.12,
    feats=[('gap',0,0.62,8,3.0), ('barrel',1,0.35), ('gap',1,0.72,7,2.0),
           ('cliff',6,0.12,0.92),
           ('gap',7,0.30,6,1.5), ('gap',7,0.72,7,2.5),
           ('cliff',9,0.06,0.94),
           ('gap',10,0.60,9,5.0), ('ramp',10,0.25),
           ('canyon',11,0.0,1.0), ('gap',11,0.60,7,2.0), ('mover',11,0.25),
           ('cliff',12,0.10,0.90),
           ('gap',13,0.55,6,2.0), ('mover',14,0.5), ('ramp',4,0.5), ('barrel',5,0.4)],
    lakes=(1,75,280), peak=None, seed=0.0)
# ---------------- GELO ----------------
SPEC['gelo'] = dict(verts=GELO,
    anchors=[6,8,18,34,50,64,80,92,92,88,82,74,66,56,46,36,22,10],
    start=0.14,
    feats=[('gap',0,0.80,7,3.0),
           ('cliff',3,0.10,0.90), ('gap',4,0.50,6,2.0), ('cliff',6,0.10,0.90),
           ('gap',7,0.35,6,2.0), ('gap',7,0.75,6,3.0), ('gap',8,0.5,7,4.0),
           ('gap',10,0.5,8,3.0), ('cliff',11,0.1,0.9), ('gap',12,0.5,7,2.0), ('cliff',13,0.1,0.9),
           ('gap',14,0.5,8,4.0), ('canyon',15,0.0,1.0), ('barrel',16,0.5), ('mover',17,0.5),
           ('ramp',1,0.5), ('ramp',2,0.5)],
    lakes=(1,90,280), peak=(150,-150,260,150,0), seed=1.3)
# ---------------- VULCAO ----------------
SPEC['vulcao'] = dict(verts=VULCAO,
    anchors=[8,10,18,28,34,42,50,58,62,66,60,52,46,36,24,14],
    start=0.10,
    feats=[('gap',0,0.55,7,3.0), ('gap',0,0.82,8,4.0),
           ('cliff',1,0.10,0.90), ('gap',5,0.5,8,3.0), ('cliff',6,0.10,0.90),
           ('gap',7,0.5,7,2.0), ('gap',8,0.5,6,3.0), ('cliff',9,0.10,0.90),
           ('gap',10,0.45,9,6.0), ('canyon',13,0.0,1.0), ('gap',13,0.5,7,3.0),
           ('cliff',14,0.1,0.9), ('barrel',2,0.5), ('mover',4,0.5), ('ramp',12,0.5), ('mover',15,0.5)],
    lakes=[(330,-250,90),(-330,250,90),(230,330,70)], peak=(0,0,340,160,55), seed=2.1)

if __name__ == '__main__':
    results = {}
    fig, axs = plt.subplots(1,3, figsize=(27,9))
    for ax, (name, sp) in zip(axs, SPEC.items()):
        r = build_map(name, sp['verts'], sp['anchors'], sp['start'], sp['feats'], None, sp['lakes'], sp['peak'], sp['seed'])
        results[name] = r
        print(f"== {name}: L={r['length']:.0f} m, count={r['count']}, frac={r['frac']:.3f}, minsep={r['sep']:.0f}, max grade={r['grade']*100:.1f}%")
        print('   gaps', r['gaps']); print('   cliffs', r['cliffs'], 'canyons', r['canyons'])
        print('   pads', len(r['pads']), 'boxes', len(r['boxes']), 'ramps', r['ramps'], 'barrels', r['barrels'], 'movers', r['movers'])
        print('   lakes', r['lakes'], 'peak', r['peak'])
        for w in r['warns']: print('   WARN', w)
        pts = r['pts']
        ax.plot([q[0] for q in pts]+[pts[0][0]],[q[2] for q in pts]+[pts[0][2]],'-',color='#888',lw=1)
        for (i0,n,d) in r['gaps']:
            ax.plot([pts[i][0] for i in range(i0,i0+n+1)],[pts[i][2] for i in range(i0,i0+n+1)],'-',color='red',lw=5)
        for (a,b) in r['cliffs']:
            ax.plot([pts[i][0] for i in range(a,b)],[pts[i][2] for i in range(a,b)],'-',color='orange',lw=3)
        for (a,b) in r['canyons']:
            ax.plot([pts[i][0] for i in range(a,b)],[pts[i][2] for i in range(a,b)],'-',color='brown',lw=3)
        for i in r['pads']: ax.plot(pts[i][0],pts[i][2],'b^',ms=4)
        for i in r['boxes']: ax.plot(pts[i][0],pts[i][2],'ys',ms=4)
        for (x,z,rad,lv) in r['lakes']: ax.add_patch(plt.Circle((x,z),rad,color='c',alpha=.5))
        if r['peak']: ax.add_patch(plt.Circle((r['peak'][0],r['peak'][1]),r['peak'][2],color='g',alpha=.25))
        ax.plot(pts[0][0],pts[0][2],'ko',ms=8)
        ax.set_aspect('equal'); ax.invert_yaxis(); ax.set_title(name); ax.grid(True,alpha=.3)
    plt.tight_layout(); plt.savefig('/home/claude/tools/layouts.png', dpi=50)
