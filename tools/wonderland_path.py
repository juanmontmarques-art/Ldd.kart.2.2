"""WONDERLAND - gerador do traçado (parte 1: geometria).

O circuito é uma sequência de peças (retas e arcos, cada uma com sua inclinação) integradas em passos de 2,5 m.
A curvatura e a inclinação passam por filtros circulares (raios de curva e curvas verticais suaves).
O fechamento do circuito é resolvido numericamente (comprimento de duas retas) e a altura fecha pela
inclinação das peças de subida (Setor 8).

Convenção: plano matemático x (leste), y (norte). No Godot: x -> x, z = -y.
Ângulo positivo = curva para a ESQUERDA.
"""
import math
import numpy as np
from scipy.optimize import root

DS = 2.5          # passo de integração (m, horizontal)
K_WIN = 22.0      # janela de suavização da curvatura (m)
S_WIN = 34.0      # janela de suavização da inclinação (m)


def L(name, length, slope, sector, **kw):
    d = dict(kind='line', name=name, h=length, slope=slope, sector=sector)
    d.update(kw)
    return d


def A(name, ang, radius, slope, sector, **kw):
    d = dict(kind='arc', name=name, ang=ang, R=radius, h=abs(math.radians(ang)) * radius, slope=slope, sector=sector)
    d.update(kw)
    return d


def LIFT(name, length, rise, sector, **kw):
    d = dict(kind='lift', name=name, h=length, slope=0.0, rise=rise, sector=sector)
    d.update(kw)
    return d


def box_filter_circ(a, win_m):
    n = len(a)
    k = max(1, int(round(win_m / DS)))
    if k % 2 == 0:
        k += 1
    half = k // 2
    out = np.zeros(n)
    c = np.concatenate([a[-half:], a, a[:half]])
    cs = np.cumsum(np.insert(c, 0, 0.0))
    out = (cs[k:] - cs[:-k]) / k
    return out[:n]


def smooth(a, win_m, passes=2):
    for _ in range(passes):
        a = box_filter_circ(a, win_m)
    return a


def integrate(pieces, p_len, p_len2=None, closing=None):
    """Arrays por passo. O número de passos de cada peça é fixo (comprimento nominal 'h0'); o comprimento real
    (p_len) altera o tamanho do passo, então o resultado é contínuo nos parâmetros (necessário para o solver)."""
    plist = []
    for p in pieces:
        q = dict(p)
        q.setdefault('h0', q['h'])
        if q['kind'] in ('line', 'lift') and q['name'] in p_len:
            q['h'] = p_len[q['name']]
        plist.append(q)
    dang = []
    dh = []
    slope = []
    lift = []
    pid = []
    for idx, q in enumerate(plist):
        n = max(1, int(round(q['h0'] / DS)))
        q['n'] = n
        step = q['h'] / n
        if q['kind'] == 'arc':
            kv = math.copysign(1.0 / q['R'], q['ang'])
            ang_step = kv * step if False else math.radians(q['ang']) / n
        else:
            ang_step = 0.0
        dang += [ang_step] * n
        dh += [step] * n
        slope += [q['slope']] * n
        lift += [(q.get('rise', 0.0) / n if q['kind'] == 'lift' else 0.0)] * n
        pid += [idx] * n
    dang = np.array(dang)
    dh = np.array(dh)
    slope = np.array(slope)
    lift = np.array(lift)
    pid = np.array(pid)
    ks = smooth(dang, K_WIN)
    ss = smooth(slope, S_WIN)
    return plist, (ks, dh), ss, lift, pid


def trace(ksdh, ss, lift, theta0, y0, x0=0.0, z0=0.0):
    ks, dh = ksdh
    th = theta0 + np.concatenate([[0.0], np.cumsum(ks)])[:-1]
    th_mid = th + 0.5 * ks
    xs = x0 + np.concatenate([[0.0], np.cumsum(np.cos(th_mid) * dh)])
    zs = z0 + np.concatenate([[0.0], np.cumsum(np.sin(th_mid) * dh)])
    ys = y0 + np.concatenate([[0.0], np.cumsum(ss * dh + lift)])
    return xs, zs, ys, th


def solve_closure(pieces, adj_lines, climb_names, y0=0.0):
    """Ajusta o comprimento de 2 retas (adj_lines) para fechar x,z e a inclinação das peças 'climb'
    (fator c) para fechar a altura. O ângulo da última curva já deve fechar o rumo."""
    base = {p['name']: p['h'] for p in pieces}

    def residual(v):
        lens = dict(base)
        for nm, val in zip(adj_lines, v):
            lens[nm] = val
        plist, ks, ss, lift, pid = integrate(pieces, lens)
        xs, zs, ys, th = trace(ks, ss, lift, 0.0, y0)
        return [xs[-1] - xs[0], zs[-1] - zs[0]]

    sol = root(residual, [base[nm] for nm in adj_lines], method='hybr', tol=1e-9)
    lens = dict(base)
    for nm, val in zip(adj_lines, sol.x):
        lens[nm] = float(val)
    return lens, sol


def apply_heading_closure(pieces, closing_arc, total_turn_deg):
    s = 0.0
    for p in pieces:
        if p['kind'] == 'arc' and p['name'] != closing_arc:
            s += p['ang']
    for p in pieces:
        if p['name'] == closing_arc:
            p['ang'] = total_turn_deg - s
            p['h'] = abs(math.radians(p['ang'])) * p['R']
    return total_turn_deg - s


def solve_climb(pieces, climb_names, lens):
    """Fator c nas inclinações das peças de subida para fechar a altura total (lifts fixos)."""
    pc = [dict(p) for p in pieces]
    def dy(c):
        for p in pc:
            if p['name'] in climb_names:
                p['slope'] = c * p['slope0']
        plist, ks, ss, lift, pid = integrate(pc, lens)
        xs, zs, ys, th = trace(ks, ss, lift, 0.0, 0.0)
        return ys[-1] - ys[0]
    sol = root(lambda v: [dy(v[0])], [1.0], method='hybr', tol=1e-9)
    c = float(sol.x[0])
    for p in pieces:
        if p['name'] in climb_names:
            p['slope'] = c * p['slope0']
    return c
