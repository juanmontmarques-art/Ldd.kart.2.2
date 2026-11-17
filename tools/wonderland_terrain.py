"""Gera o relevo da Wonderland (grade de alturas) + parâmetros de caverna por amostra -> wonderland/data/terrain.bin
Executar depois de exportar as amostras do Godot (tools/dump via Godot) em /home/claude/work/wl_godot_pts.bin."""
import numpy as np, struct, re, sys
from scipy.ndimage import zoom, gaussian_filter, uniform_filter1d
CELL = 16.0
raw = open('/home/claude/work/wl_godot_pts.bin', 'rb').read()
n = struct.unpack('<I', raw[:4])[0]
a = np.frombuffer(raw[4:], dtype='<f4').reshape(n, 7)
P = a[:, :3].astype(np.float64); UPS = a[:, 3:6]; HALF = a[:, 6]
lay = open('/home/claude/proj/wonderland/wonderland_layout.gd').read()
def vec_list(key, cls, k):
    m = re.search(r'"%s": \[(.*?)\],\n' % key, lay, re.S)
    body = m.group(1)
    return [tuple(float(x) for x in g.split(',')) for g in re.findall(cls + r'\(([^)]*)\)', body)]
chambers = vec_list('chambers', 'Vector4', 4)
profiles = vec_list('profiles', 'Vector3i', 3)
tun = vec_list('tunnels', 'Vector3i', 3)[0]
t0, t1 = int(tun[0]), int(tun[1])
# ---- parâmetros de caverna por amostra
chalf = np.zeros(n); cup = np.zeros(n)
for i in range(t0, t1 + 1):
    chalf[i] = 24; cup[i] = 20
for (s, e, h, u) in chambers:
    for i in range(int(s), int(e) + 1):
        if t0 <= i <= t1 and h + u > chalf[i] + cup[i] - 0 and (h > chalf[i] or True):
            chalf[i] = h; cup[i] = u
# S8 chambers (lifts) sobrepõem: já tratados acima (últimos vencem)
chalf = uniform_filter1d(chalf, 25, mode='wrap'); cup = uniform_filter1d(cup, 25, mode='wrap')
# na boca: afunila
for i in range(n):
    if i < t0 or i > t1:
        chalf[i] = 0; cup[i] = 0
# ---- grade
lo = P[:, [0, 2]].min(0) - 420; hi = P[:, [0, 2]].max(0) + 420
minx = np.floor(lo[0] / CELL) * CELL; minz = np.floor(lo[1] / CELL) * CELL
nx = int((hi[0] - minx) / CELL) + 1; nz = int((hi[1] - minz) / CELL) + 1
gx, gz = np.meshgrid(minx + np.arange(nx) * CELL, minz + np.arange(nz) * CELL)
gx = gx.ravel(); gz = gz.ravel()
prof = np.zeros(n, dtype=int)
for (s, e, pid) in profiles:
    prof[int(s):int(e) + 1] = int(pid)
def smoothstep(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)
H = np.full(gx.shape, -999.0)
cover = np.full(gx.shape, -999.0)
step = 2
cave_ids = [i for i in range(0, n, step) if t0 <= i <= t1]
open_ids = [i for i in range(0, n, step) if not (t0 <= i <= t1)]
for i in cave_ids:
    d = np.hypot(gx - P[i, 0], gz - P[i, 2])
    y = P[i, 1]
    dist_end = min(i - t0, t1 - i)
    cov = 4.0 + 46.0 * smoothstep(dist_end / 110.0)
    h = chalf[i]
    val = y + cup[i] + cov - 0.62 * np.maximum(0, d - h * 1.05)
    val = np.where(d < h * 1.05 + 260, val, -999.0)
    cover = np.maximum(cover, val)
# terreno aberto: cada célula usa a amostra de estrada MAIS PRÓXIMA (evita que o paredão de um trecho vizinho cubra a pista)
ox = P[open_ids, 0]; oz = P[open_ids, 2]; oy = P[open_ids, 1]
oprof = prof[open_ids]; ohw = np.maximum(HALF[open_ids], 6.0)
best_d = np.full(gx.shape, 1e9); best_k = np.zeros(gx.shape, dtype=int)
for c0 in range(0, len(open_ids), 200):
    dd = np.hypot(gx[:, None] - ox[None, c0:c0 + 200], gz[:, None] - oz[None, c0:c0 + 200])
    kk = dd.argmin(1); dm = dd[np.arange(len(gx)), kk]
    m = dm < best_d
    best_d[m] = dm[m]; best_k[m] = kk[m] + c0
d = best_d; y = oy[best_k]; pid = oprof[best_k]; hw = ohw[best_k]
val = y - 2.0 - np.maximum(0, d - 12) * 1.2
v1 = y - 1.6 - np.maximum(0, d - 48) * 0.9
v2 = y - 2.0 - np.maximum(0, d - (hw + 3)) * 1.7
w3 = hw + 5
v3 = y - 2.0 + np.clip((d - w3) * 1.5, 0, 34) - np.maximum(0, d - (w3 + 30)) * 1.1
w4 = hw + 16
v4 = np.where(d < w4, y - 175.0 + d * 0.0, y - 120.0 + np.clip((d - w4) * 2.0, 0, 130) - np.maximum(0, d - (w4 + 65)) * 1.3)
val = np.where(pid == 1, v1, val); val = np.where(pid == 2, v2, val); val = np.where(pid == 3, v3, val); val = np.where(pid == 4, v4, val)
val = np.where(d < 340, val, -999.0)
H = np.maximum(H, val)
H = np.maximum(H, cover)
# piso de vale distante + ruído
def noise(shape, scale, seed):
    r = np.random.RandomState(seed).rand(int(shape[0] / scale) + 3, int(shape[1] / scale) + 3)
    z = zoom(r, scale, order=3)[:shape[0], :shape[1]]
    return z
Hg = H.reshape(nz, nx)
valley = -230.0 + 70 * noise((nz, nx), 14, 3)
ridged = 1 - np.abs(2 * noise((nz, nx), 6, 5) - 1)
amp = np.clip((Hg - valley) / 200.0, 0.15, 1.0)
Hg = np.maximum(Hg, valley)
Hg = Hg + (ridged - 0.5) * 22.0 * amp + (noise((nz, nx), 3, 9) - 0.5) * 7.0 * amp
Hg = gaussian_filter(Hg, 0.7)
# arestas das ruas: o chão fica ao menos 2.2 m abaixo da pista nas amostras abertas (não pode cobrir o asfalto)
flat = Hg.ravel()
for i in range(0, n):
    if t0 <= i <= t1: continue
    ix = np.clip(np.round((P[i, 0] - minx) / CELL).astype(int), 0, nx - 1); iz = np.clip(np.round((P[i, 2] - minz) / CELL).astype(int), 0, nz - 1)
    for dz in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            jx = np.clip(ix + dx, 0, nx - 1); jz = np.clip(iz + dz, 0, nz - 1)
            if abs(dx) + abs(dz) < 4:
                lim = P[i, 1] - 2.5
                k = jz * nx + jx
                dd = np.hypot(minx + jx * CELL - P[i, 0], minz + jz * CELL - P[i, 2])
                if dd < 22 and flat[k] > lim:
                    flat[k] = lim
Hg = flat.reshape(nz, nx)
with open('/home/claude/proj/wonderland/data/terrain.bin', 'wb') as f:
    f.write(struct.pack('<ii', nx, nz)); f.write(struct.pack('<fff', CELL, minx, minz))
    f.write(Hg.astype('<f4').tobytes())
    f.write(struct.pack('<i', n)); f.write(chalf.astype('<f4').tobytes()); f.write(cup.astype('<f4').tobytes())
print('grid', nx, nz, 'H range', Hg.min(), Hg.max(), 'tunnel', t0, t1)
