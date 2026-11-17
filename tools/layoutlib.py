import math, random

SPACING = 2.5
PER = 40

def norm(v):
    l = math.hypot(*v)
    return (v[0]/l, v[1]/l)

def build_path(verts):
    """verts: list of (x,z,R). Returns dict with segments, total length L, edge info."""
    n = len(verts)
    corners = []
    for i in range(n):
        p0 = verts[(i-1) % n]; p1 = verts[i]; p2 = verts[(i+1) % n]
        d1 = norm((p1[0]-p0[0], p1[1]-p0[1]))
        d2 = norm((p2[0]-p1[0], p2[1]-p1[1]))
        cr = d1[0]*d2[1]-d1[1]*d2[0]
        dot = d1[0]*d2[0]+d1[1]*d2[1]
        theta = math.atan2(abs(cr), dot)   # turn angle
        R = p1[2]
        t = R*math.tan(theta/2) if R > 0 else 0
        a = (p1[0]-d1[0]*t, p1[1]-d1[1]*t)
        b = (p1[0]+d2[0]*t, p1[1]+d2[1]*t)
        left = 1 if cr > 0 else -1  # in x/z plane sign
        # center is offset from a by normal*R toward the turn side
        nrm = (-d1[1]*left, d1[0]*left)
        c = (a[0]+nrm[0]*R, a[1]+nrm[1]*R)
        corners.append(dict(a=a, b=b, c=c, R=R, theta=theta, t=t, sign=left, d1=d1, d2=d2))
    segs = []
    s = 0.0
    problems = []
    for i in range(n):
        ci = corners[i]; cn = corners[(i+1) % n]
        A = ci['b']; B = cn['a']
        L = math.hypot(B[0]-A[0], B[1]-A[1])
        # direction must agree with edge direction
        e = (verts[(i+1)%n][0]-verts[i][0], verts[(i+1)%n][1]-verts[i][1])
        if (B[0]-A[0])*e[0]+(B[1]-A[1])*e[1] < 0:
            problems.append(f"edge {i}: corners overlap (tangents too long)")
        segs.append(dict(kind='line', i=i, A=A, B=B, s0=s, s1=s+L, L=L))
        s += L
        # arc of corner i+1
        arcL = cn['R']*cn['theta']
        segs.append(dict(kind='arc', i=(i+1) % n, c=cn['c'], R=cn['R'], a=cn['a'], b=cn['b'], sign=cn['sign'], s0=s, s1=s+arcL, L=arcL, theta=cn['theta']))
        s += arcL
    return dict(segs=segs, L=s, corners=corners, problems=problems, verts=verts)

def point_at(path, s):
    L = path['L']
    s = s % L
    for g in path['segs']:
        if s <= g['s1']:
            u = s - g['s0']
            if g['kind'] == 'line':
                f = u/g['L'] if g['L'] > 0 else 0
                return (g['A'][0]+(g['B'][0]-g['A'][0])*f, g['A'][1]+(g['B'][1]-g['A'][1])*f)
            else:
                c = g['c']; R = g['R']
                a0 = math.atan2(g['a'][1]-c[1], g['a'][0]-c[0])
                ang = a0 + g['sign']*(u/R)
                return (c[0]+R*math.cos(ang), c[1]+R*math.sin(ang))
    return path['segs'][-1]['B'] if path['segs'][-1]['kind']=='line' else path['segs'][-1]['b']

def edge_station(path, edge, frac):
    for g in path['segs']:
        if g['kind'] == 'line' and g['i'] == edge:
            return g['s0'] + g['L']*frac
    raise KeyError(edge)

def corner_station(path, corner):
    for g in path['segs']:
        if g['kind'] == 'arc' and g['i'] == corner:
            return g['s0'] + g['L']*0.5
    raise KeyError(corner)

def cosine_interp(anchors, s, L):
    """anchors: sorted list of (s,h), periodic over L."""
    n = len(anchors)
    s = s % L
    for i in range(n):
        s0, h0 = anchors[i]
        s1, h1 = anchors[(i+1) % n]
        if i == n-1:
            s1 += L
        ss = s if s >= s0 else s + L
        if s0 <= ss <= s1:
            t = (ss-s0)/(s1-s0) if s1 > s0 else 0
            t = 0.5-0.5*math.cos(math.pi*t)
            return h0+(h1-h0)*t
    return anchors[0][1]

def control_points(path, heights_anchors, start_s, spacing=40.0, undulate=None):
    L = path['L']
    N = int(round(L/spacing))
    step = L/N
    pts = []
    for j in range(N):
        s = start_s + j*step
        x, z = point_at(path, s)
        h = cosine_interp(heights_anchors, s, L)
        if undulate:
            h += undulate(s % L)
        pts.append((x, h, z))
    return pts

# ---- port of TrackData.build (resample) ----
def catmull(p0, p1, p2, p3, t):
    t2 = t*t; t3 = t2*t
    out = []
    for k in range(3):
        out.append(0.5*((2*p1[k])+(-p0[k]+p2[k])*t+(2*p0[k]-5*p1[k]+4*p2[k]-p3[k])*t2+(-p0[k]+3*p1[k]-3*p2[k]+p3[k])*t3))
    return tuple(out)

def resample(cps):
    n = len(cps)
    dense = []
    for i in range(n):
        p0 = cps[(i-1) % n]; p1 = cps[i]; p2 = cps[(i+1) % n]; p3 = cps[(i+2) % n]
        for k in range(PER):
            dense.append(catmull(p0, p1, p2, p3, k/PER))
    dense.append(dense[0])
    cum = [0.0]
    for i in range(1, len(dense)):
        a = dense[i]; b = dense[i-1]
        cum.append(cum[-1]+math.dist(a, b))
    length = cum[-1]
    count = int(round(length/SPACING))
    step = length/count
    pts = []
    j = 0
    for i in range(count):
        d = i*step
        while cum[j+1] < d:
            j += 1
        seg = max(cum[j+1]-cum[j], 1e-4)
        f = (d-cum[j])/seg
        a = dense[j]; b = dense[j+1]
        pts.append(tuple(a[k]+(b[k]-a[k])*f for k in range(3)))
    return pts, length, count, (length/SPACING) % 1.0

def nearest_idx(pts, x, z):
    best = 0; bd = 1e18
    for i, p in enumerate(pts):
        d = (p[0]-x)**2+(p[2]-z)**2
        if d < bd:
            bd = d; best = i
    return best

def min_separation(pts, min_gap_samples=180):
    n = len(pts)
    worst = 1e9; wi = (0, 0)
    for i in range(0, n, 2):
        for j in range(i+min_gap_samples, n, 2):
            if n-(j-i) < min_gap_samples:
                continue
            d = math.hypot(pts[i][0]-pts[j][0], pts[i][2]-pts[j][2])
            if d < worst:
                worst = d; wi = (i, j)
    return worst, wi

def max_grade(pts):
    g = 0
    for i in range(len(pts)):
        a = pts[i]; b = pts[(i+1) % len(pts)]
        d = math.hypot(a[0]-b[0], a[2]-b[2])
        g = max(g, abs(b[1]-a[1])/d)
    return g
