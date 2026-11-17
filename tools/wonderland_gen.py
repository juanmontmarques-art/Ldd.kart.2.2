"""WONDERLAND - gerador completo do layout (GDScript) + análise do traçado.

Uso: python3 tools/wonderland_gen.py   -> escreve wonderland/wonderland_layout.gd e relatórios/imagens em /home/claude/work
"""
import sys, math, json
sys.path.insert(0, '/home/claude/proj/tools')
import numpy as np
import wonderland_design as D
import wonderland_plot as P
from wonderland_path import DS
from wonderland_sample import resample_closed, SPACING

OUT = '/home/claude/proj/wonderland/wonderland_layout.gd'
CTRL_H = 14.0     # espaçamento dos pontos de controle (m horizontais)
LIFT_H = 3.0


def build_all():
    pieces, plist, lens, xs, zs, ys, th, pid, c, sol = P.build()
    n = len(xs) - 1
    # horizontal acumulado por passo
    dh = []
    for q in plist:
        dh += [q['h'] / q['n']] * q['n']
    h_at = np.concatenate([[0.0], np.cumsum(dh)])
    # início de cada peça em h
    pstart = {}
    acc = 0.0
    for q in plist:
        pstart[q['name']] = (acc, acc + q['h'])
        acc += q['h']
    total_h = acc
    # pontos de controle: amostrar o caminho (fechado, sem duplicar o último)
    hs = [0.0]
    h = 0.0
    lift_ranges = [pstart[q['name']] for q in plist if q['kind'] == 'lift']
    while True:
        step = CTRL_H
        for (a, b) in lift_ranges:
            if a - 28 <= h < b + 28:
                step = LIFT_H
        h += step
        if h >= total_h - 8.0:
            break
        hs.append(h)
    hs = np.array(hs)
    cx = np.interp(hs, h_at, xs)
    cz = np.interp(hs, h_at, zs)
    cy = np.interp(hs, h_at, ys)
    cps = np.stack([cx, cy, -cz], axis=1)       # Godot: (x, altura, z=-y)
    pts, hsamp, length, count, step = resample_closed(cps, hs)
    return dict(pieces=plist, pstart=pstart, total_h=total_h, cps=cps, hc=hs, pts=pts, hs=hsamp, length=length, count=count,
                step=step, lens=lens, climb=c)


W = build_all()
PTS = W['pts'].copy()
COUNT = W['count']
HS = W['hs']


def rng(name, f0=0.0, f1=1.0):
    a, b = W['pstart'][name]
    i0 = int(np.searchsorted(HS, a + (b - a) * f0))
    i1 = int(np.searchsorted(HS, a + (b - a) * f1))
    return i0, i1


def mid(name, f=0.5):
    return rng(name, f, f)[0]


def sector_range(sec):
    names = [q['name'] for q in W['pieces'] if q['sector'] == sec]
    return rng(names[0], 0.0, 0.0)[0], rng(names[-1], 1.0, 1.0)[0]


# ------------------------------------------------------------------ recursos
gaps = []        # (start, count, drop)
ramps = []
pads = []
pad_lats = []
boxes = []
barrels = []
movers = []
tunnels = []
bridges = []
narrow = []      # (start, end, half_width)
rolls = []       # (start, end, deg0, deg1)
mags = []        # (start, end)
lifts = []       # (start, count, rise)
collapses = []   # (start, end)
mech = []
chambers = []    # (start, end, half, up)
checkpoints = []
slick = []       # (start, end)
boosts = []      # (start, end)  faixa de aceleração contínua
pillars = []     # amostras com pilar de rocha até o fundo do abismo
profiles = []    # (start, end, id) perfis laterais de terreno: 0 livre, 1 plateau, 2 ledge, 3 chute, 4 chasm, 5 trench


def add_gap(name, f, n, drop):
    i = rng(name, f, f)[0]
    gaps.append((i, n, drop))
    ramps.append(i - 3)
    pads.extend([i - 5, i - 5]); pad_lats.extend([-3.0, 3.0])
    return i


# ---- SETOR 1
s1a, s1b = sector_range(1)
profiles.append((s1a, rng('s1_lip', 0, 1)[1], 2))
profiles.append((s1a, rng('s1_plat', 0.0, 1.0)[1], 1))
bridges.append((*rng('s1_bridge1', 0.05, 0.95), 0)); narrow.append((*rng('s1_bridge1', 0.05, 0.95), 6.5))
bridges.append((*rng('s1_bridge2', 0.05, 0.95), 1)); narrow.append((*rng('s1_bridge2', 0.05, 0.95), 6.0))
pads += [mid('s1_plat', 0.35), mid('s1_plat', 0.35), mid('s1_lip', 0.6), mid('s1_lip', 0.6)]
pad_lats += [-3.0, 3.0, -3.0, 3.0]
ramps += [mid('s1_lip', 0.85)]
boxes += [mid('s1_plat', 0.6), mid('s1_bridge1', 0.0), mid('s1_a2', 0.5), mid('s1_bridge2', 0.0)]
barrels += [mid('s1_l3', 0.5)]
mech.append(dict(t='gate', a=mid('s1_l3', 0.2), period=7.0, open=0.7, phase=0.0, ruin=1))
mech.append(dict(t='gate', a=mid('s1_l3', 0.7), period=7.0, open=0.7, phase=3.5, ruin=1))
mech.append(dict(t='boulder', a=mid('s1_a4', 0.5), len=70, period=11.0, phase=2.0))
mech.append(dict(t='boost', a=rng('s1_plat', 0.15, 0.15)[0], b=rng('s1_plat', 0.28, 0.28)[0]))

# ---- SETOR 2
s2a, s2b = sector_range(2)
profiles.append((s2a, s2b, 3))
pads += [mid('s2_f1', 0.0), mid('s2_f1', 0.0)]
pad_lats += [-3.0, 3.0]
boxes += [mid('s2_p1', 0.5), mid('s2_p2', 0.5), mid('s2_p3', 0.5)]
slick.append(rng('s2_p2', 0.0, 1.0))
mech.append(dict(t='slick', a=rng('s2_p2', 0.0, 1.0)[0], b=rng('s2_p2', 0.0, 1.0)[1]))
mech.append(dict(t='boulder', a=mid('s2_p1', 0.9), len=55, period=9.0, phase=1.0))
mech.append(dict(t='emerge', a=mid('s2_p3', 0.35), period=6.0, phase=0.0))
g = add_gap('s2_f3', 0.45, 16, 12.0)
profiles.append((g - 30, g + 70, 3))
mech.append(dict(t='boost', a=mid('s2_f1', 0.1), b=mid('s2_f1', 0.9)))

# ---- SETOR 3
s3a, s3b = sector_range(3)
profiles.append((s3a, s3b + 4, 4))
bridges.append((*rng('s3_b1', 0.1, 0.9), 1)); narrow.append((*rng('s3_b1', 0.1, 0.9), 5.0))
bridges.append((*rng('s3_b2', 0.1, 0.9), 0)); narrow.append((*rng('s3_b2', 0.1, 0.9), 6.5))
bridges.append((*rng('s3_b3', 0.1, 0.9), 1)); narrow.append((*rng('s3_b3', 0.1, 0.9), 7.0))
g1 = add_gap('s3_j1', 0.5, 14, 9.0)
g2 = add_gap('s3_j2', 0.5, 16, 12.0)
b2a, b2b = rng('s3_b2', 0.25, 0.85)
collapses.append((b2a, b2b))
mech.append(dict(t='collapse', a=b2a, b=b2b, seg=6))
b3a, b3b = rng('s3_b3', 0.2, 0.6)
mech.append(dict(t='slider', a=b3a, b=b3b, period=9.0, open=0.62))
mech.append(dict(t='tiltramp', a=g1 - 12, period=8.0))
mech.append(dict(t='crystal', a=mid('s3_a1', 0.6), target='tiltramp'))
pillars += [mid('s3_a1', 0.5), mid('s3_a2', 0.5), mid('s3_a3', 0.5), mid('s3_a4', 0.5), g1 + 24, g2 + 26]
boxes += [mid('s3_b1', 0.2), mid('s3_a2', 0.4), mid('s3_b2', 0.2), mid('s3_a3', 0.5), mid('s3_b3', 0.85)]
mech.append(dict(t='boost', a=mid('s3_b1', 0.0), b=mid('s3_b1', 0.35)))
movers += [mid('s3_a2', 0.5)]

# ---- SETOR 4
s4a, s4b = sector_range(4)
tunnels.append((s4a - 1, s4b, 2))
profiles.append((s4a, s4b, 0))
bridges.append((*rng('s4_riv1', 0.08, 0.92), 1)); narrow.append((*rng('s4_riv1', 0.08, 0.92), 8.0))
bridges.append((*rng('s4_fall', 0.1, 0.9), 1)); narrow.append((*rng('s4_fall', 0.1, 0.9), 7.0))
chambers.append((*rng('s4_riv1', 0.0, 1.0), 38, 38))
chambers.append((*rng('s4_lake', 0.0, 1.0), 55, 46))
chambers.append((*rng('s4_a3', 0.0, 1.0), 46, 42))
chambers.append((*rng('s4_fall', 0.0, 1.0), 50, 52))
slick.append(rng('s4_lake', 0.3, 0.75))
mech.append(dict(t='slick', a=rng('s4_lake', 0.3, 0.75)[0], b=rng('s4_lake', 0.3, 0.75)[1]))
for f in (0.25, 0.55, 0.8):
    mech.append(dict(t='geyser', a=mid('s4_lake', f), lat=(-4.5 if f != 0.55 else 4.5), period=7.0, phase=f * 9, power=17.0))
for f in (0.3, 0.7):
    mech.append(dict(t='rockfall', a=mid('s4_a2', f), period=5.0, phase=f * 7))
boxes += [mid('s4_in', 0.5), mid('s4_riv1', 0.3), mid('s4_riv1', 0.8), mid('s4_lake', 0.3), mid('s4_fall', 0.4)]
pads += [mid('s4_in', 0.7), mid('s4_in', 0.7), mid('s4_lake', 0.9), mid('s4_lake', 0.9)]
pad_lats += [-3.0, 3.0, -3.0, 3.0]
barrels += [mid('s4_a1', 0.6)]
mech.append(dict(t='crystal', a=mid('s4_a3', 0.5), target='boostgate'))

# ---- SETOR 5
s5a, s5b = sector_range(5)
profiles.append((s5a, s5b, 0))
chambers.append((s5a, s5b, 17, 15))
rolls_tw = []
for nm, a0, a1 in (('s5_a2', -26, 26), ('s5_a3', 26, -26), ('s5_a4', -28, 28), ('s5_a5', 28, -26)):
    r = rng(nm, 0.0, 1.0)
    a0 = 12.0 if a0 > 0 else -12.0
    a1 = 12.0 if a1 > 0 else -12.0
    e = 10
    rolls_tw.append((r[0], r[0] + e, 0.0, a0))
    rolls_tw.append((r[0] + e, r[1] - e, a0, a1))
    rolls_tw.append((r[1] - e, r[1], a1, 0.0))
mech.append(dict(t='gate', a=mid('s5_l1', 0.5), period=6.0, open=0.65, phase=0.0, ruin=0))
mech.append(dict(t='gate', a=mid('s5_l3', 0.5), period=6.0, open=0.65, phase=3.0, ruin=0))
mech.append(dict(t='gate', a=mid('s5_l5', 0.5), period=6.0, open=0.65, phase=1.5, ruin=0))
mech.append(dict(t='crystal', a=mid('s5_a4', 0.5), target='secretgate'))
mech.append(dict(t='emerge', a=mid('s5_l6', 0.5), period=5.0, phase=2.0))
boxes += [mid('s5_a1', 0.5), mid('s5_a3', 0.5), mid('s5_l4', 0.5), mid('s5_a5', 0.5), mid('s5_l6', 0.2)]
pads += [mid('s5_l2', 0.5), mid('s5_l2', 0.5), mid('s5_l6', 0.8), mid('s5_l6', 0.8)]
pad_lats += [-3.0, 3.0, -3.0, 3.0]
slick.append(rng('s5_l4', 0.0, 1.0))
mech.append(dict(t='slick', a=rng('s5_l4', 0.0, 1.0)[0], b=rng('s5_l4', 0.0, 1.0)[1]))

# ---- SETOR 6
s6a, s6b = sector_range(6)
profiles.append((s6a, s6b, 0))
chambers.append((s6a, s6b, 50, 55))
bridges.append((*rng('s6_bridge', 0.06, 0.94), 3)); narrow.append((*rng('s6_bridge', 0.06, 0.94), 6.5))
c6a, c6b = rng('s6_bridge', 0.45, 0.9)
collapses.append((c6a, c6b))
mech.append(dict(t='collapse', a=c6a, b=c6b, seg=5))
mech.append(dict(t='slick', a=rng('s6_l2', 0.1, 0.9)[0], b=rng('s6_l2', 0.1, 0.9)[1]))
slick.append(rng('s6_l2', 0.1, 0.9))
for f in (0.2, 0.5, 0.8):
    mech.append(dict(t='geyser', a=mid('s6_l2', f), lat=(4.0 if f != 0.5 else -4.0), period=6.0, phase=f * 8, power=18.0))
for nm, f in (('s6_in', 0.5), ('s6_a2', 0.5), ('s6_l3', 0.3), ('s6_l3', 0.7)):
    mech.append(dict(t='rockfall', a=mid(nm, f), period=4.5, phase=f * 6))
mech.append(dict(t='boulder', a=mid('s6_l2', 0.9), len=60, period=10.0, phase=4.0))
gl = add_gap('s6_l3', 0.5, 12, 6.0)
mech.append(dict(t='slider', a=mid('s6_a2', 0.2), b=mid('s6_a2', 0.2) + 5, period=8.0, open=0.6))
boxes += [mid('s6_in', 0.2), mid('s6_bridge', 0.1), mid('s6_a2', 0.5), mid('s6_l2', 0.5), mid('s6_l3', 0.9)]
barrels += [mid('s6_a3', 0.5)]
mech.append(dict(t='crystal', a=mid('s6_a1', 0.5), target='lavabridge'))
mech.append(dict(t='lifts_small', a=mid('s6_a3', 0.2)))

# ---- SETOR 7
s7a, s7b = sector_range(7)
profiles.append((s7a, s7b, 0))
chambers.append((s7a, s7b, 40, 38))
chambers.append((*rng('s7_h1', 0.0, 1.0), 38, 34))
sc = rng('s7_screw', 0.0, 1.0)
rolls.append((sc[0] + 10, sc[1] - 6, 0.0, 360.0))
mags.append((sc[0] - 4, sc[1] + 4))
hl = rng('s7_h1', 0.0, 1.0)
rolls.append((hl[0], hl[0] + 36, 0.0, 58.0))
rolls.append((hl[0] + 36, hl[1] - 36, 58.0, 58.0))
rolls.append((hl[1] - 36, hl[1], 58.0, 0.0))
mags.append((hl[0] - 4, hl[1] + 4))
iv = rng('s7_inv', 0.0, 1.0)
n_iv = iv[1] - iv[0]
rolls.append((iv[0] + 4, iv[0] + 40, 0.0, 180.0))
rolls.append((iv[0] + 40, iv[1] - 40, 180.0, 180.0))
rolls.append((iv[1] - 40, iv[1] - 4, 180.0, 360.0))
mags.append((iv[0] - 4, iv[1] + 4))
add_gap_after = None
boxes += [mid('s7_in', 0.5), mid('s7_screw', 0.5), mid('s7_h1', 0.25), mid('s7_h1', 0.75), mid('s7_inv', 0.5), mid('s7_l2', 0.5)]
pads += [mid('s7_in', 0.8), mid('s7_in', 0.8), mid('s7_inv', 0.0), mid('s7_inv', 0.0)]
pad_lats += [-3.0, 3.0, -3.0, 3.0]
mech.append(dict(t='emerge', a=mid('s7_l2', 0.4), period=5.0, phase=0.0))
mech.append(dict(t='emerge', a=mid('s7_l2', 0.75), period=5.0, phase=2.5))
mech.append(dict(t='lowgrav', a=rng('s7_a2', 0.0, 1.0)[0], b=rng('s7_a2', 0.0, 1.0)[1], scale=0.45))
narrow.append((*rng('s7_screw', 0.0, 1.0), 7.5))
narrow.append((*rng('s7_inv', 0.0, 1.0), 7.5))
mech.append(dict(t='boost', a=mid('s7_inv', 0.55), b=mid('s7_inv', 0.85)))

# ---- SETOR 8
s8a, s8b = sector_range(8)
ex = rng('s8_l1', 0.0, 1.0)[1]            # fim da subida (nível do platô)
tun_end = ex - 52
tunnels.append((s7a - 1 if False else s5a, tun_end, 2))   # substituído abaixo (S4..S8 contíguos)
tunnels = [(s4a - 1, tun_end, 2)]
profiles.append((s8a, tun_end, 0))
profiles.append((tun_end - 30, s8b, 5))
profiles.append((rng('s8_turn', 0.0, 1.0)[0], s8b, 1))
chambers.append((s8a, tun_end, 19, 17))
for nm in ('s8_lift1', 's8_lift2'):
    a, b = rng(nm, 0.0, 1.0)
    rise = [q for q in W['pieces'] if q['name'] == nm][0]['rise']
    lifts.append((a, b - a, rise))
    mech.append(dict(t='lift', a=a, count=b - a, rise=rise, period=11.0))
    chambers.append((a - 14, b + 14, 20, rise + 14))
mech.append(dict(t='gate', a=mid('s8_in', 0.5), period=7.0, open=0.7, phase=0.0, ruin=0))
mech.append(dict(t='gate', a=mid('s8_l1', 0.35), period=7.0, open=0.7, phase=3.5, ruin=0))
for nm, f in (('s8_in', 0.3), ('s8_sp1', 0.5), ('s8_sp2', 0.3), ('s8_sp2', 0.75), ('s8_l1', 0.15)):
    mech.append(dict(t='rockfall', a=mid(nm, f), period=5.0, phase=f * 9))
mech.append(dict(t='boulder', a=mid('s8_l1', 0.6), len=80, period=11.0, phase=5.0))
g8 = add_gap('s8_l1', 0.78, 9, 4.0)
boxes += [mid('s8_in', 0.2), mid('s8_sp1', 0.3), mid('s8_sp1', 0.8), mid('s8_sp2', 0.3), mid('s8_sp2', 0.8), mid('s8_l1', 0.3), mid('s8_fin', 0.5)]
pads += [mid('s8_sp1', 0.9), mid('s8_sp1', 0.9), mid('s8_sp2', 0.9), mid('s8_sp2', 0.9), mid('s8_l1', 0.05), mid('s8_l1', 0.05), mid('s8_turn', 0.2), mid('s8_turn', 0.2)]
pad_lats += [-3.0, 3.0] * 4
mech.append(dict(t='boost', a=mid('s8_l1', 0.3), b=mid('s8_l1', 0.55)))
mech.append(dict(t='slick', a=rng('s8_sp2', 0.3, 0.6)[0], b=rng('s8_sp2', 0.3, 0.6)[1]))
slick.append(rng('s8_sp2', 0.3, 0.6))

# ---- ramps/pads auxiliares nos saltos obrigatórios
for gg in gaps:
    pass

# ---- checkpoints (início de cada setor + pontos médios)
for sec in range(1, 9):
    a, b = sector_range(sec)
    checkpoints.append(a)
    if b - a > 500:
        checkpoints.append((a + b) // 2)
checkpoints = sorted(set(c for c in checkpoints if c > 0))

# ---- ramos (atalhos)
branches = []


def make_branch(a, c, half, lateral, dy_mid, tun=(8, 8), ramps_b=None, name=''):
    """ctrl: [a-1, a, ...pontos intermediários..., c, c+1] em coordenadas (x, altura, z)."""
    pa, pc = PTS[a], PTS[c % COUNT]
    k = 5
    ctrl = [PTS[(a - 6) % COUNT]]
    ctrl.append(pa)
    d = pc - pa
    dh = np.array([d[0], 0.0, d[2]])
    L = np.linalg.norm(dh)
    t = dh / L
    side = np.array([t[2] * -1.0, 0.0, t[0]]) * 0.0 + np.array([-t[2], 0.0, t[0]])
    for q in range(1, k + 1):
        u = q / (k + 1)
        p = pa + d * u
        off = lateral * math.sin(math.pi * u * 2.0)
        p = p + side * off
        p[1] = pa[1] + d[1] * u + dy_mid * math.sin(math.pi * u)
        ctrl.append(p)
    ctrl.append(pc)
    ctrl.append(PTS[(c + 6) % COUNT])
    branches.append(dict(a=a, c=c, half=half, tunnel=tun, ramps=ramps_b or [], ctrl=np.array(ctrl), name=name))


# S1: atalho secreto que corta o grampo s1_a2 -> s1_l3
a1 = rng('s1_a2', 0.18, 0.18)[0]
c1 = rng('s1_l3', 0.9, 0.9)[0]
make_branch(a1, c1, 6.0, 0.0, -6.0, tun=(-1, -1), name='s1_secret')
# S5: atalho de risco
a5 = rng('s5_a2', 0.1, 0.1)[0]
c5 = rng('s5_a4', 0.9, 0.9)[0]
make_branch(a5, c5, 5.5, 0.0, 0.0, tun=(6, 6), name='s5_risk')
# S6: atalho sobre a lava
a6 = rng('s6_in', 0.7, 0.7)[0]
c6 = rng('s6_a2', 0.5, 0.5)[0]
make_branch(a6, c6, 5.5, 0.0, -2.0, tun=(6, 6), name='s6_lava')

# ------------------------------------------------------------------ análise
tangent = np.gradient(PTS, axis=0, edge_order=1)
tn = np.roll(PTS, -1, axis=0) - np.roll(PTS, 1, axis=0)
hz = np.hypot(tn[:, 0], tn[:, 2])
pitch = np.degrees(np.arctan2(tn[:, 1], hz))
sec_of = np.zeros(COUNT, dtype=int)
for sec in range(1, 9):
    a, b = sector_range(sec)
    sec_of[a:b + 1] = sec


def analyse():
    rep = {}
    rep['count'] = COUNT
    rep['length_m'] = float(W['length'])
    rep['pitch_min'] = float(pitch.min())
    rep['pitch_max'] = float(pitch.max())
    rep['sector_pitch_min'] = {int(s): float(pitch[sec_of == s].min()) for s in range(1, 9)}
    rep['sector_pitch_max'] = {int(s): float(pitch[sec_of == s].max()) for s in range(1, 9)}
    # curvatura horizontal (raio mínimo)
    t = tn / np.maximum(np.linalg.norm(tn, axis=1, keepdims=True), 1e-6)
    a_=t[:-2][:, [0, 2]]; b_=t[2:][:, [0, 2]]
    ang = np.arctan2(a_[:,0]*b_[:,1]-a_[:,1]*b_[:,0], (a_*b_).sum(axis=1))
    rad = (2 * SPACING) / np.maximum(np.abs(ang), 1e-6)
    rep['min_radius'] = float(np.percentile(rad, 0.5))
    # separação entre trechos distantes
    under = sec_of >= 4
    hs_ = PTS
    bad = []
    stride = 2
    idxs = np.arange(0, COUNT, stride)
    P = PTS[idxs]
    D3 = np.linalg.norm(P[:, None, :] - P[None, :, :], axis=2)
    Dh = np.hypot(P[:, None, 0] - P[None, :, 0], P[:, None, 2] - P[None, :, 2])
    ii, jj = np.meshgrid(idxs, idxs, indexing='ij')
    gap_i = np.minimum(np.abs(ii - jj), COUNT - np.abs(ii - jj))
    far = gap_i > 60
    ua = under[idxs][:, None] & under[idxs][None, :]
    need = np.where(ua, 62.0, 36.0)
    viol = far & (D3 < need)
    # lifts e arredores: o poço do elevador não conta
    vi = np.argwhere(viol)
    pairs = {}
    for a, b in vi:
        if a < b:
            key = (int(sec_of[idxs[a]]), int(sec_of[idxs[b]]))
            pairs.setdefault(key, []).append((int(idxs[a]), int(idxs[b]), float(D3[a, b])))
    rep['violations'] = {str(k): (len(v), min(v, key=lambda z: z[2])) for k, v in pairs.items()}
    return rep


def fmt_vec3(v):
    return 'Vector3(%.1f, %.1f, %.1f)' % (v[0], v[1], v[2])


def emit():
    L = []
    L.append('class_name WonderlandLayout')
    L.append('extends RefCounted')
    L.append('')
    L.append('# GERADO por tools/wonderland_gen.py - NÃO editar à mão. Traçado, setores, mecanismos e recursos da pista WONDERLAND.')
    L.append('')
    L.append('const SECTOR_NAMES := ["", "THE EDGE", "FREEFALL", "THE ABYSS", "UNDERWORLD", "CRYSTAL LABYRINTH", "THE INFERNO", "GRAVITY BREAK", "THE ASCENT"]')
    L.append('const EXPECTED_COUNT := %d' % COUNT)
    L.append('')
    L.append('static func get_layout() -> Dictionary:')
    L.append('    var pts := PackedFloat32Array([')
    flat = W['cps'].reshape(-1)
    row = []
    for i in range(0, len(flat), 9):
        L.append('        ' + ', '.join('%.2f' % v for v in flat[i:i + 9]) + ',')
    L[-1] = L[-1].rstrip(',')
    L.append('    ])')
    L.append('    var branches: Array = []')
    for b in branches:
        c = b['ctrl'].reshape(-1)
        L.append('    branches.append({')
        L.append('        "a": %d, "c": %d, "half": %.1f, "tunnel": Vector2i(%d, %d), "ramps": [], "name": "%s",' % (b['a'], b['c'], b['half'], b['tunnel'][0], b['tunnel'][1], b['name']))
        L.append('        "ctrl": PackedFloat32Array([' + ', '.join('%.2f' % v for v in c) + ']),')
        L.append('    })')

    def vlist(items, f):
        return '[' + ', '.join(f(x) for x in items) + ']'
    L.append('    var mech: Array = []')
    for m in mech:
        parts = []
        for k, v in m.items():
            if isinstance(v, str):
                parts.append('"%s": "%s"' % (k, v))
            elif isinstance(v, float):
                parts.append('"%s": %.3f' % (k, v))
            else:
                parts.append('"%s": %s' % (k, v))
        L.append('    mech.append({' + ', '.join(parts) + '})')
    sec_starts = [sector_range(s) for s in range(1, 9)]
    L.append('    return {')
    L.append('        "points": pts,')
    L.append('        "gaps": ' + vlist(gaps, lambda g: 'Vector3(%d, %d, %.1f)' % g) + ',')
    L.append('        "cliffs": [],')
    L.append('        "canyons": [],')
    L.append('        "pads": ' + str([int(p) for p in pads]) + ',')
    L.append('        "pad_lats": ' + str([float(p) for p in pad_lats]) + ',')
    L.append('        "ramps": ' + str([int(r) for r in ramps]) + ',')
    L.append('        "boxes": ' + str([int(r) for r in boxes]) + ',')
    L.append('        "barrels": ' + str([int(r) for r in barrels]) + ',')
    L.append('        "movers": ' + str([int(r) for r in movers]) + ',')
    L.append('        "lakes": [],')
    L.append('        "peaks": [],')
    L.append('        "craters": [],')
    L.append('        "tunnels": ' + vlist(tunnels, lambda t: 'Vector3i(%d, %d, %d)' % t) + ',')
    L.append('        "bridges": ' + vlist(bridges, lambda t: 'Vector3i(%d, %d, %d)' % t) + ',')
    L.append('        "twists": [],')
    L.append('        "branches": branches,')
    L.append('        "bank_gain": 9.0,')
    L.append('        "bank_max": 0.27,')
    L.append('        "bank_tunnels": true,')
    L.append('        "rolls": ' + vlist(rolls + rolls_tw, lambda r: 'Vector4(%d, %d, %.1f, %.1f)' % r) + ',')
    L.append('        "mags": ' + vlist(mags, lambda r: 'Vector2i(%d, %d)' % r) + ',')
    L.append('        "lifts": ' + vlist(lifts, lambda r: 'Vector3(%d, %d, %.1f)' % r) + ',')
    L.append('        "narrow": ' + vlist(narrow, lambda r: 'Vector3(%d, %d, %.1f)' % r) + ',')
    L.append('        "collapses": ' + vlist(collapses, lambda r: 'Vector2i(%d, %d)' % r) + ',')
    L.append('        "chambers": ' + vlist(chambers, lambda r: 'Vector4(%d, %d, %.0f, %.0f)' % r) + ',')
    L.append('        "slick": ' + vlist(slick, lambda r: 'Vector2i(%d, %d)' % r) + ',')
    L.append('        "pillars": ' + str([int(p) for p in pillars]) + ',')
    L.append('        "profiles": ' + vlist(profiles, lambda r: 'Vector3i(%d, %d, %d)' % r) + ',')
    L.append('        "sectors": ' + vlist(sec_starts, lambda r: 'Vector2i(%d, %d)' % r) + ',')
    L.append('        "checkpoints": ' + str([int(c) for c in checkpoints]) + ',')
    L.append('        "mech": mech,')
    L.append('    }')
    return '\n'.join(L) + '\n'


if __name__ == '__main__':
    rep = analyse()
    print(json.dumps(rep, indent=1, default=str)[:3000])
    import os
    os.makedirs('/home/claude/proj/wonderland', exist_ok=True)
    open(OUT, 'w').write(emit())
    print('layout escrito', OUT, 'pontos de controle', len(W['cps']))
    np.save('/home/claude/work/wl_pts.npy', PTS)
    json.dump({'sec_of': sec_of.tolist()}, open('/home/claude/work/wl_sec.json', 'w'))
