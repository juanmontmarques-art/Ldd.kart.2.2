"""Replica de TrackData.build() (Catmull-Rom fechado + reamostragem a 2,5 m) para o traçado da Wonderland."""
import math
import numpy as np

SPACING = 2.5
PER = 40


def catmull(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


def resample_closed(cps, hc):
    """cps: (n,3) pontos de controle (x, y_altura, z). hc: (n,) h acumulado do caminho em cada ponto (para mapear amostra->h)."""
    n = len(cps)
    ts = np.arange(PER) / PER
    dense = []
    hd = []
    for i in range(n):
        p0, p1, p2, p3 = cps[(i - 1) % n], cps[i], cps[(i + 1) % n], cps[(i + 2) % n]
        seg = (0.5 * ((2.0 * p1)[None, :] + (-p0 + p2)[None, :] * ts[:, None] + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3)[None, :] * (ts ** 2)[:, None] + (-p0 + 3.0 * p1 - 3.0 * p2 + p3)[None, :] * (ts ** 3)[:, None]))
        dense.append(seg)
        h_next = hc[i + 1] if i + 1 < n else hc[0] + (hc[-1] - hc[0]) + (hc[1] - hc[0])
        hd.append(hc[i] + ts * (h_next - hc[i]))
    dense = np.concatenate(dense + [cps[0][None, :]], axis=0)
    hd = np.concatenate(hd + [[hd[0][0] + 0.0]])
    seglen = np.linalg.norm(np.diff(dense, axis=0), axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seglen)])
    length = cum[-1]
    count = int(round(length / SPACING))
    step = length / count
    d = np.arange(count) * step
    j = np.searchsorted(cum, d, side='right') - 1
    j = np.clip(j, 0, len(dense) - 2)
    f = (d - cum[j]) / np.maximum(cum[j + 1] - cum[j], 1e-4)
    pts = dense[j] + (dense[j + 1] - dense[j]) * f[:, None]
    hs = hd[j] + (hd[j + 1] - hd[j]) * f
    return pts, hs, length, count, step
