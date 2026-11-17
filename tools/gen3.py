import sys, math
sys.path.insert(0, '/home/claude/tools')
from layoutlib import *
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt

def smooth_mask_edges(path, flat_edges, window=100.0):
    L = path['L']; step = 5.0; n = int(L/step)
    raw = []
    for i in range(n):
        s = i*step; m = 1.0
        for g in path['segs']:
            if s <= g['s1']:
                if g['kind'] == 'line' and g['i'] in flat_edges: m = 0.0
                break
        raw.append(m)
    k = int(window/step); sm = []
    for i in range(n):
        acc = 0.0
        for o in range(-k, k+1): acc += raw[(i+o) % n]
        sm.append(acc/(2*k+1))
    return lambda s: sm[int((s % L)/step) % n]

def apply_gap_drop(pts, gaps):
    pts = [list(p) for p in pts]
    n = len(pts)
    for (i0, ng, drop) in gaps:
        after = i0+ng
        for i in range(after, n):
            k = (i-after)/110.0
            t = min(max(k, 0), 1); sm = t*t*(3-2*t)
            pts[i][1] -= drop*(1-sm)
    return [tuple(p) for p in pts]

def catmull_open(ctrl, per=20):
    """ctrl includes phantom first/last. Returns dense polyline through ctrl[1..-2]."""
    dense = []
    for i in range(1, len(ctrl)-2):
        p0, p1, p2, p3 = ctrl[i-1], ctrl[i], ctrl[i+1], ctrl[i+2]
        for k in range(per):
            dense.append(catmull(p0, p1, p2, p3, k/per))
    dense.append(ctrl[-2])
    return dense

def resample_open(dense):
    cum = [0.0]
    for i in range(1, len(dense)): cum.append(cum[-1]+math.dist(dense[i], dense[i-1]))
    length = cum[-1]; cnt = max(2, int(round(length/SPACING))+1)
    step = length/(cnt-1)
    out = []; j = 0
    for i in range(cnt):
        d = i*step
        while j < len(cum)-2 and cum[j+1] < d: j += 1
        seg = max(cum[j+1]-cum[j], 1e-4); f = (d-cum[j])/seg
        a = dense[j]; b = dense[j+1]
        out.append(tuple(a[k]+(b[k]-a[k])*f for k in range(3)))
    return out, length

def build_map3(name, sp):
    p = build_path(sp['verts'])
    assert not p['problems'], (name, p['problems'])
    L = p['L']
    start_s = edge_station(p, 0, sp['start'])
    anchors = sorted([(corner_station(p, i), h) for i, h in enumerate(sp['anchors'])])
    flat_edges = set(f[1] for f in sp['feats'] if f[0] in ('gap', 'wgap', 'cliff', 'canyon', 'bridge'))
    mask = smooth_mask_edges(p, flat_edges)
    seed = sp.get('seed', 0.0); amp = sp.get('amp', 1.4)
    und = lambda s: amp*math.sin(s/120.0+seed)*mask(s)
    cps = control_points(p, anchors, start_s, sp.get('ctrl', 40.0), und)
    pts, length, count, frac = resample(cps)
    sep, wi = min_separation(pts)
    seg_of = {g['i']: g for g in p['segs'] if g['kind'] == 'line'}
    def idx_of(s):
        guess = int(round(((s-start_s) % L)/L*count))
        x, z = point_at(p, s)
        best = None; bd = 1e18
        for o in range(-16, 17):
            i = (guess+o) % count
            d = (pts[i][0]-x)**2+(pts[i][2]-z)**2
            if d < bd: bd = d; best = i
        return best
    out = dict(gaps=[], cliffs=[], canyons=[], pads=[], pad_lats=[], ramps=[], boxes=[], barrels=[], movers=[],
               tunnels=[], bridges=[], branches=[], lakes=[], falls=[], twists=[])
    taken = []
    def free(i0, i1, margin=25):
        for a, b in taken:
            if i0-margin < b and i1+margin > a: return False
        return True
    warns = []
    lakes = [tuple(l) for l in sp.get('lakes', [])]
    for f in sp['feats']:
        kind, edge = f[0], f[1]
        g = seg_of[edge]
        def frc(fr):
            if isinstance(fr, tuple):
                ax = 0 if fr[0] == 'x' else 1
                a0 = g['A'][ax]; b0 = g['B'][ax]
                return min(max((fr[1]-a0)/(b0-a0), 0.0), 1.0)
            return fr
        def at(fr): return idx_of(g['s0']+g['L']*frc(fr))
        if kind in ('gap', 'wgap'):
            _, _, fr, n, drop = f[:5]
            fr = frc(fr)
            c = at(fr); i0 = c-n//2
            if (fr*g['L']) < n*SPACING/2+55 or (1-fr)*g['L'] < n*SPACING/2+40:
                warns.append(f"{name}: {kind} edge {edge} fr {fr}: tight ({g['L']:.0f} m)")
            out['gaps'].append((i0, n, drop)); taken.append((i0-8, i0+n+6))
            out['pads'] += [i0-16, i0-16]; out['pad_lats'] += [-3.0, 3.0]
            out['ramps'].append(i0-3)
            if kind == 'wgap':
                x, _, z = pts[i0+n//2]
                lakes.append((x, z, f[5], ('gap', i0+n//2, -5.0)))
        elif kind in ('cliff', 'canyon'):
            _, _, f0, f1 = f
            i0 = at(f0); i1 = at(f1)
            out['cliffs' if kind == 'cliff' else 'canyons'].append((i0, i1)); taken.append((i0, i1))
        elif kind == 'tunnel':
            _, _, f0, f1, tk = f
            i0 = at(f0); i1 = at(f1)
            out['tunnels'].append((i0, i1, tk)); taken.append((i0-4, i1+4))
        elif kind == 'fall':
            i0 = at(f[2])
            out['tunnels'].append((i0, i0+14, 1)); taken.append((i0-4, i0+18))
        elif kind == 'bridge':
            _, _, f0, f1, bk = f[:5]
            i0 = at(f0); i1 = at(f1)
            out['bridges'].append((i0, i1, bk)); taken.append((i0-4, i1+4))
            if len(f) > 5:   # lagoa sob a ponte
                lx, lz, lr = f[5]
                mid = (i0+i1)//2
                lakes.append((lx, lz, lr, ('bridge', mid, -14.0)))
        elif kind == 'twist':
            _, _, f0, f1, a0, a1 = f
            i0 = at(f0); i1 = at(f1)
            out['twists'].append((i0, i1, a0, a1)); taken.append((i0-2, i1+2))
        elif kind == 'barrel':
            i = at(f[2]); out['barrels'].append(i); taken.append((i-6, i+34))
        elif kind == 'mover':
            i = at(f[2]); out['movers'].append(i); taken.append((i-6, i+6))
        elif kind == 'ramp':
            i = at(f[2]); out['ramps'].append(i); taken.append((i-6, i+6))
        elif kind == 'pad':
            i = at(f[2]); out['pads'].append(i); out['pad_lats'].append(f[3]); taken.append((i-3, i+3))
    for g in p['segs']:
        if g['kind'] == 'arc' and math.degrees(g['theta']) > 95:
            i = idx_of(g['s1']+45)
            if free(i-3, i+3, 10):
                out['pads'].append(i); out['pad_lats'].append(0.0); taken.append((i-3, i+3))
    i = 70
    bad = out['cliffs']+out['canyons']+[(a, b) for a, b, _ in out['tunnels']]+[(a, b) for a, b, _ in out['bridges']]
    while i < count-80:
        j = i; ok = False
        for _ in range(12):
            if free(j-4, j+4, 14) and not any(a-20 < j < b+20 for a, b in bad): ok = True; break
            j += 12
        if ok: out['boxes'].append(j)
        i = max(j, i)+170
    out['boxes'] = sorted(set(out['boxes']))
    final = apply_gap_drop(pts, out['gaps'])
    # lagos: nivel absoluto
    L2 = []
    for lk in lakes:
        x, z, r, lv = lk
        if isinstance(lv, tuple):
            _, ci, off = lv
            lv = final[ci][1]+off
        L2.append((x, z, r, lv))
    out['lakes'] = L2
    # atalhos
    for bd in sp.get('branches', []):
        ea, fa = bd['a']; ec, fc = bd['c']
        def frb(e, fr):
            gg = seg_of[e]
            if isinstance(fr, tuple):
                ax = 0 if fr[0] == 'x' else 1
                return min(max((fr[1]-gg['A'][ax])/(gg['B'][ax]-gg['A'][ax]), 0.0), 1.0)
            return fr
        a = idx_of(seg_of[ea]['s0']+seg_of[ea]['L']*frb(ea, fa)); c = idx_of(seg_of[ec]['s0']+seg_of[ec]['L']*frb(ec, fc))
        A = final[a]; C = final[c]
        tA = (final[(a+1) % count][0]-final[(a-1) % count][0], final[(a+1) % count][2]-final[(a-1) % count][2])
        tC = (final[(c+1) % count][0]-final[(c-1) % count][0], final[(c+1) % count][2]-final[(c-1) % count][2])
        nA = norm(tA); nC = norm(tC)
        mids = bd.get('mid')
        if mids is None:
            vx = C[0]-A[0]; vz = C[2]-A[2]; ln = math.hypot(vx, vz); px = -vz/ln; pz = vx/ln
            mids = [(A[0]+vx*u+px*v, A[2]+vz*u+pz*v, 0.0) for (u, v) in bd['rel']]
        chain = [(A[0], A[2])]+[(m[0], m[1]) for m in mids]+[(C[0], C[2])]
        cum = [0.0]
        for q in range(1, len(chain)): cum.append(cum[-1]+math.dist(chain[q], chain[q-1]))
        tot = cum[-1]
        ctrl = [(A[0]-nA[0]*35, A[1], A[2]-nA[1]*35), A]
        for q, m in enumerate(mids):
            y = A[1]+(C[1]-A[1])*cum[q+1]/tot + (m[2] if len(m) > 2 else 0.0)
            ctrl.append((m[0], y, m[1]))
        ctrl += [C, (C[0]+nC[0]*35, C[1], C[2]+nC[1]*35)]
        dense = catmull_open(ctrl)
        bpts, blen = resample_open(dense)
        out['branches'].append(dict(a=a, c=c, half=bd.get('half', 6.0), ctrl=ctrl, pts=bpts, length=blen,
                                    tunnel=bd.get('tunnel'), ramps=[int(f*len(bpts)) for f in bd.get('ramps', [])], main_len=((c-a) % count)*SPACING))
    out.update(pts=final, cps=cps, count=count, length=length, sep=sep, frac=frac, path=p,
               warns=warns, peaks=sp.get('peaks', []), craters=sp.get('craters', []),
               bank_gain=sp.get('bank_gain', 11.0), bank_max=sp.get('bank_max', 0.30))
    # distancia ramo x pista
    for b in out['branches']:
        worst = 1e9
        for q, bp in enumerate(b['pts']):
            if q < 30 or q > len(b['pts'])-30: continue
            for i in range(0, count, 2):
                d = math.hypot(bp[0]-final[i][0], bp[2]-final[i][2])
                worst = min(worst, d)
        b['min_main'] = worst
    return out

def max_grade_pts(pts, skip=()):
    g = 0; gi = 0
    for i in range(len(pts)):
        if any(a-4 <= i <= a+n+4 for a, n in skip): continue
        a = pts[i]; b = pts[(i+1) % len(pts)]
        d = math.hypot(a[0]-b[0], a[2]-b[2])
        if d > 0 and abs(b[1]-a[1])/d > g: g = abs(b[1]-a[1])/d; gi = i
    return g, gi

def plot(results, path='/home/claude/tools/layouts3.png'):
    fig, axs = plt.subplots(1, len(results), figsize=(9*len(results), 9))
    if len(results) == 1: axs = [axs]
    for ax, (name, r) in zip(axs, results.items()):
        pts = r['pts']
        ax.plot([q[0] for q in pts]+[pts[0][0]], [q[2] for q in pts]+[pts[0][2]], '-', color='#555', lw=1.5)
        for (i0, n, d) in r['gaps']: ax.plot([pts[i][0] for i in range(i0, i0+n+1)], [pts[i][2] for i in range(i0, i0+n+1)], '-', color='red', lw=5)
        for (a, b) in r['cliffs']: ax.plot([pts[i][0] for i in range(a, b)], [pts[i][2] for i in range(a, b)], '-', color='orange', lw=4)
        for (a, b, k) in r['tunnels']: ax.plot([pts[i % len(pts)][0] for i in range(a, b)], [pts[i % len(pts)][2] for i in range(a, b)], '-', color='purple', lw=6, alpha=.7)
        for (a, b, k) in r['bridges']: ax.plot([pts[i][0] for i in range(a, b)], [pts[i][2] for i in range(a, b)], '-', color='green', lw=6, alpha=.7)
        for b in r['branches']:
            ax.plot([q[0] for q in b['pts']], [q[2] for q in b['pts']], '-', color='magenta', lw=2)
        for (x, z, rad, lv) in r['lakes']: ax.add_patch(plt.Circle((x, z), rad, color='c', alpha=.4))
        for pk in r['peaks']: ax.add_patch(plt.Circle((pk[0], pk[1]), pk[2], color='g', alpha=.2))
        for i in r['pads']: ax.plot(pts[i][0], pts[i][2], 'b^', ms=3)
        for i in r['ramps']: ax.plot(pts[i][0], pts[i][2], 'k>', ms=5)
        ax.plot(pts[0][0], pts[0][2], 'ko', ms=9)
        for i in range(0, len(pts), 100): ax.text(pts[i][0], pts[i][2], str(i), fontsize=7, color='gray')
        ax.set_aspect('equal'); ax.invert_yaxis(); ax.grid(True, alpha=.3); ax.set_title(name)
    plt.tight_layout(); plt.savefig(path, dpi=60)

def report(name, r):
    g, gi = max_grade_pts(r['pts'], [(a, n) for a, n, d in r['gaps']])
    hs = [q[1] for q in r['pts']]
    print(f"== {name}: L={r['length']:.0f} m count={r['count']} frac={r['frac']:.3f} minsep={r['sep']:.0f} grade={g*100:.1f}% @ {gi} alt {min(hs):.0f}..{max(hs):.0f}")
    print('   gaps', r['gaps'], 'cliffs', r['cliffs'], 'canyons', r['canyons'])
    print('   tunnels', r['tunnels'], 'bridges', r['bridges'], 'lakes', [(round(a), round(b), c, round(d, 1)) for a, b, c, d in r['lakes']])
    for b in r['branches']:
        print(f"   branch a={b['a']} c={b['c']} len={b['length']:.0f} main={b['main_len']:.0f} min_dist_main={b['min_main']:.0f} n={len(b['pts'])}")
    for w in r['warns']: print('   WARN', w)
