import sys
sys.path.insert(0, '/home/claude/proj/tools')
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.optimize import least_squares
import wonderland_design as D
from wonderland_path import *

COL = {1: '#e8c070', 2: '#ff6b4a', 3: '#a070ff', 4: '#40b0d0', 5: '#ff70d0', 6: '#ff9020', 7: '#70e070', 8: '#222222'}


def solve_all(pieces):
    names = [n for n in D.FREE if any(p['name'] == n for p in pieces)]
    base = {p['name']: p['h'] for p in pieces}
    x0 = np.array([base[n] for n in names])
    lo = np.array([D.FREE[n][0] for n in names])
    hi = np.array([D.FREE[n][1] for n in names])
    x0 = np.clip(x0, lo, hi)

    def lens_of(v):
        lens = dict(base)
        for n, val in zip(names, v):
            lens[n] = float(val)
        return lens

    def res(v):
        lens = lens_of(v)
        plist, ks, ss, lift, pid = integrate(pieces, lens)
        xs, zs, ys, th = trace(ks, ss, lift, 0.0, 0.0)
        reg = 0.02 * (v - x0)
        return np.concatenate([[xs[-1] - xs[0], zs[-1] - zs[0]], reg])

    sol = least_squares(res, x0, bounds=(lo, hi), xtol=1e-12, ftol=1e-12)
    return lens_of(sol.x), sol


def build(verbose=False):
    pieces = D.assemble()
    lens, sol = solve_all(pieces)
    for p in pieces:
        p['h'] = lens[p['name']]
    for p in pieces:
        if p['kind'] == 'arc':
            pass
    c = solve_climb(pieces, D.CLIMB, lens)
    plist, ks, ss, lift, pid = integrate(pieces, lens)
    xs, zs, ys, th = trace(ks, ss, lift, 0.0, D.Y0)
    return pieces, plist, lens, xs, zs, ys, th, pid, c, sol


if __name__ == '__main__':
    pieces, plist, lens, xs, zs, ys, th, pid, c, sol = build()
    print('climb factor', round(c, 3))
    print('end residual', round(xs[-1]-xs[0], 2), round(zs[-1]-zs[0], 2), round(ys[-1]-ys[0], 3), 'head', round(float(np.degrees(th[-1])) % 360, 2))
    n = len(xs) - 1
    print('horizontal length', n * DS, ' ymin', ys.min(), 'ymax', ys.max())
    for nm, v in lens.items():
        if nm in D.FREE:
            print('  %-12s %.0f (%s)' % (nm, v, D.FREE[nm]))
    fig, ax = plt.subplots(1, 2, figsize=(24, 11), gridspec_kw={'width_ratios': [1, 1]})
    for k in range(n):
        sec = plist[pid[k]]['sector']
        ax[0].plot(xs[k:k+2], zs[k:k+2], color=COL[sec], lw=2.2)
    for p_i, q in enumerate(plist):
        k = int(np.argmax(pid == p_i))
        ax[0].text(xs[k], zs[k], q['name'], fontsize=6)
    ax[0].set_aspect('equal'); ax[0].grid(alpha=0.3)
    s = np.arange(n + 1) * DS
    for k in range(n):
        sec = plist[pid[k]]['sector']
        ax[1].plot(s[k:k+2], ys[k:k+2], color=COL[sec], lw=2.2)
    ax[1].grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig('/home/claude/work/wl_plan.png', dpi=60)
    for sec in range(1, 9):
        m = np.array([plist[i]['sector'] == sec for i in pid])
        print('S%d  h=%.0f  y %.0f -> %.0f' % (sec, m.sum() * DS, ys[:-1][m][0], ys[:-1][m][-1]))
