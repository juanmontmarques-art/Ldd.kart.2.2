class_name KartMesh
extends RefCounted

# Gerador de malhas suaves por código (triângulos reais, sem primitivas do Godot).
# Toda peça é uma "grade" de pontos (linhas x colunas). As normais saem das diferenças
# entre pontos vizinhos, então o sombreamento é liso e contínuo. Cada triângulo tem a
# ordem corrigida para a face da frente ficar para fora (sem peças invisíveis).
#
#   loft     : corpo por seções (cada seção é uma superelipse: arredondada ou "quadradona")
#   lathe    : peça de revolução (pneus, aros, escapamentos, faróis)
#   tube     : tubo com raio variável seguindo um caminho (volante, arcos, canos)
#   ellipsoid: elipsoide liso (capacete, mãos, faróis)

var surf := {}   # chave de material -> {v, n, uv, i}


func _s(key: String) -> Dictionary:
    if not surf.has(key):
        surf[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
    return surf[key]


# rows: Array de PackedVector3Array (mesmo tamanho). wrap_u: cada linha fecha em anel.
# wrap_v: as linhas fecham entre si (tubo fechado). orient: 0 = automático (para fora do
# centro), 1 = manter, -1 = inverter (para peças abertas como asas).
func add_grid(key: String, rows: Array, wrap_u: bool, xf: Transform3D = Transform3D.IDENTITY, orient: int = 0, wrap_v: bool = false) -> void:
    var R := rows.size()
    if R < 2:
        return
    var M: int = (rows[0] as PackedVector3Array).size()
    var P: Array = rows
    var N: Array = []
    var degenerate: Array[bool] = []
    for r in R:
        var row: PackedVector3Array = P[r]
        var c := Vector3.ZERO
        for p in row:
            c += p
        c /= float(M)
        var spread := 0.0
        for p in row:
            spread = maxf(spread, p.distance_to(c))
        degenerate.append(spread < 1e-5)
    var center := Vector3.ZERO
    for r in R:
        for p in (P[r] as PackedVector3Array):
            center += p
    center /= float(R * M)
    var sum_out := 0.0
    for r in R:
        var nr := PackedVector3Array()
        nr.resize(M)
        var r0 := r - 1
        var r1 := r + 1
        if wrap_v:
            r0 = (r + R - 1) % R
            r1 = (r + 1) % R
        else:
            r0 = maxi(r - 1, 0)
            r1 = mini(r + 1, R - 1)
        for m in M:
            var m0 := m - 1
            var m1 := m + 1
            if wrap_u:
                m0 = (m + M - 1) % M
                m1 = (m + 1) % M
            else:
                m0 = maxi(m - 1, 0)
                m1 = mini(m + 1, M - 1)
            var du: Vector3 = (P[r] as PackedVector3Array)[m1] - (P[r] as PackedVector3Array)[m0]
            var dv: Vector3 = (P[r1] as PackedVector3Array)[m] - (P[r0] as PackedVector3Array)[m]
            var n := du.cross(dv)
            if degenerate[r] or n.length() < 1e-10:
                # polo: normal aponta do miolo da linha vizinha para o ponto
                var nb := r + 1 if r == 0 else r - 1
                var cc := Vector3.ZERO
                for p in (P[nb] as PackedVector3Array):
                    cc += p
                cc /= float(M)
                n = (P[r] as PackedVector3Array)[m] - cc
                if n.length() < 1e-10:
                    n = Vector3.UP
            nr[m] = n.normalized()
            sum_out += nr[m].dot((P[r] as PackedVector3Array)[m] - center)
        N.append(nr)
    var flip := 1.0
    if orient == 0:
        flip = 1.0 if sum_out >= 0.0 else -1.0
    else:
        flip = float(orient)
    var d := _s(key)
    var vs: PackedVector3Array = d["v"]
    var ns: PackedVector3Array = d["n"]
    var uvs: PackedVector2Array = d["uv"]
    var idx: PackedInt32Array = d["i"]
    var base := vs.size()
    var nb_xf := xf.basis.inverse().transposed()
    for r in R:
        for m in M:
            vs.append(xf * (P[r] as PackedVector3Array)[m])
            ns.append((nb_xf * ((N[r] as PackedVector3Array)[m] * flip)).normalized())
            uvs.append(Vector2(float(m) / float(M), float(r) / float(R)))
    var rmax := R if wrap_v else R - 1
    var mmax := M if wrap_u else M - 1
    for r in rmax:
        for m in mmax:
            var a := base + r * M + m
            var b := base + r * M + (m + 1) % M
            var c := base + ((r + 1) % R) * M + (m + 1) % M
            var dd := base + ((r + 1) % R) * M + m
            _tri(vs, ns, idx, a, b, c)
            _tri(vs, ns, idx, a, c, dd)
    d["v"] = vs
    d["n"] = ns
    d["uv"] = uvs
    d["i"] = idx


func _tri(vs: PackedVector3Array, ns: PackedVector3Array, idx: PackedInt32Array, a: int, b: int, c: int) -> void:
    var geo := (vs[b] - vs[a]).cross(vs[c] - vs[a])
    if geo.length_squared() < 1e-14:
        return
    # face da frente no Godot = sentido horário: normal geométrica oposta à normal "para fora"
    if geo.dot(ns[a] + ns[b] + ns[c]) > 0.0:
        idx.append(a)
        idx.append(c)
        idx.append(b)
    else:
        idx.append(a)
        idx.append(b)
        idx.append(c)


# Gera o ArrayMesh e devolve também a lista de chaves na ordem das superfícies.
func commit() -> Dictionary:
    var mesh := ArrayMesh.new()
    var keys: Array[String] = []
    for k in surf.keys():
        var d: Dictionary = surf[k]
        if (d["i"] as PackedInt32Array).is_empty():
            continue
        var arr := []
        arr.resize(Mesh.ARRAY_MAX)
        arr[Mesh.ARRAY_VERTEX] = d["v"]
        arr[Mesh.ARRAY_NORMAL] = d["n"]
        arr[Mesh.ARRAY_TEX_UV] = d["uv"]
        arr[Mesh.ARRAY_INDEX] = d["i"]
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
        keys.append(String(k))
    return {"mesh": mesh, "keys": keys}


# ---------------------------------------------------------------- formas
static func _spow(x: float, e: float) -> float:
    return signf(x) * pow(absf(x), e)


# Anel superelíptico no plano XY na altura z. n = 2 elipse, 3-4 caixa arredondada.
static func ring(z: float, hw: float, yb: float, yt: float, nt: float, nb: float, segs: int, cx: float = 0.0) -> PackedVector3Array:
    var out := PackedVector3Array()
    var yc := (yt + yb) * 0.5
    var hh := (yt - yb) * 0.5
    for k in segs:
        var a := TAU * float(k) / float(segs)
        var c := cos(a)
        var s := sin(a)
        var n := nt if s >= 0.0 else nb
        out.append(Vector3(cx + hw * _spow(c, 2.0 / n), yc + hh * _spow(s, 2.0 / n), z))
    return out


# secs: Array de [z, hw, yb, yt, nt, nb]. cap_f/cap_b: comprimento da cúpula que fecha a ponta.
func loft(key: String, secs: Array, cap_f: float, cap_b: float, xf: Transform3D = Transform3D.IDENTITY, segs: int = 28, orient: int = 1) -> void:
    var rows: Array = []
    var steps := 5
    if cap_f > 0.0:
        var s0: Array = secs[0]
        for j in range(steps, 0, -1):
            var th := PI * 0.5 * float(j) / float(steps)
            rows.append(_scaled_ring(s0, s0[0] - cap_f * sin(th), cos(th), segs))
    for s in secs:
        rows.append(ring(s[0], s[1], s[2], s[3], s[4], s[5], segs))
    if cap_b > 0.0:
        var s1: Array = secs[secs.size() - 1]
        for j in range(1, steps + 1):
            var th := PI * 0.5 * float(j) / float(steps)
            rows.append(_scaled_ring(s1, s1[0] + cap_b * sin(th), cos(th), segs))
    add_grid(key, rows, true, xf, orient)


static func _scaled_ring(s: Array, z: float, f: float, segs: int) -> PackedVector3Array:
    var yc: float = (float(s[2]) + float(s[3])) * 0.5
    var hh: float = (float(s[3]) - float(s[2])) * 0.5 * f
    return ring(z, float(s[1]) * f, yc - hh, yc + hh, float(s[4]), float(s[5]), segs)


# Elipsoide liso centrado em c com raios r.
func ellipsoid(key: String, c: Vector3, r: Vector3, xf: Transform3D = Transform3D.IDENTITY, segs: int = 14) -> void:
    var secs: Array = []
    var steps := 6
    for j in range(-steps + 1, steps):
        var th := PI * 0.5 * float(j) / float(steps)
        var f := cos(th)
        secs.append([c.z + r.z * sin(th), r.x * f, c.y - r.y * f, c.y + r.y * f, 2.0, 2.0])
    var rows: Array = []
    # polos
    rows.append(ring(c.z - r.z, 0.0, c.y, c.y, 2.0, 2.0, segs, c.x))
    for s in secs:
        rows.append(ring(s[0], s[1], s[2], s[3], s[4], s[5], segs, c.x))
    rows.append(ring(c.z + r.z, 0.0, c.y, c.y, 2.0, 2.0, segs, c.x))
    add_grid(key, rows, true, xf, 1)


# Revolução em torno do eixo Z local. profile: Array[Vector2] (axial z, raio).
func lathe(key: String, profile: Array, xf: Transform3D = Transform3D.IDENTITY, segs: int = 48, closed_profile: bool = false) -> void:
    var rows: Array = []
    for p in profile:
        var row := PackedVector3Array()
        var pv: Vector2 = p
        for k in segs:
            var a := TAU * float(k) / float(segs)
            row.append(Vector3(pv.y * cos(a), pv.y * sin(a), pv.x))
        rows.append(row)
    add_grid(key, rows, true, xf, 0, closed_profile)


# Tubo de raio variável seguindo o caminho (pontos). radii: um valor por ponto.
func tube(key: String, path: Array, radii: Array, sides: int = 10, closed: bool = false, xf: Transform3D = Transform3D.IDENTITY, orient: int = 1) -> void:
    var n := path.size()
    var rows: Array = []
    var prev_n := Vector3.ZERO
    for i in n:
        var p: Vector3 = path[i]
        var t: Vector3
        if closed:
            t = ((path[(i + 1) % n] as Vector3) - (path[(i + n - 1) % n] as Vector3)).normalized()
        else:
            t = ((path[mini(i + 1, n - 1)] as Vector3) - (path[maxi(i - 1, 0)] as Vector3)).normalized()
        var nn: Vector3
        if i == 0:
            nn = t.cross(Vector3.UP)
            if nn.length() < 0.2:
                nn = t.cross(Vector3.RIGHT)
            nn = nn.normalized()
        else:
            nn = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = nn
        var bb := t.cross(nn).normalized()
        var row := PackedVector3Array()
        for k in sides:
            var a := TAU * float(k) / float(sides)
            row.append(p + (nn * cos(a) + bb * sin(a)) * float(radii[i]))
        rows.append(row)
    if not closed:
        # tampas arredondadas simples (polo): linha degenerada nas pontas
        var first: PackedVector3Array = rows[0]
        var last: PackedVector3Array = rows[rows.size() - 1]
        var pole0 := PackedVector3Array()
        var pole1 := PackedVector3Array()
        for k in sides:
            pole0.append(path[0])
            pole1.append(path[n - 1])
        rows.push_front(pole0)
        rows.push_back(pole1)
    add_grid(key, rows, true, xf, orient, closed)
