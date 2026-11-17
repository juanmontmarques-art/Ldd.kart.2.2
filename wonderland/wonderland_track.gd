class_name WonderlandTrack
extends RefCounted

# Estrada da Wonderland: malha varrida ao longo do traçado (com referencial rolado nos parafusos), larguras variáveis
# (pontes estreitas), lajes com PBR procedural, luzes de borda, meio-fio e casco de rocha por baixo. Gera colisão por trecho.

const CHUNK := 36
const SEC_TINT := [Color(), Color(0.46, 0.44, 0.42), Color(0.44, 0.40, 0.38), Color(0.36, 0.34, 0.40), Color(0.22, 0.27, 0.30), Color(0.27, 0.22, 0.34), Color(0.30, 0.20, 0.18), Color(0.20, 0.24, 0.32), Color(0.40, 0.38, 0.36)]
const SEC_EDGE := [Color(), Color(1.0, 0.75, 0.3), Color(1.0, 0.45, 0.25), Color(0.6, 0.45, 1.0), Color(0.1, 0.9, 0.8), Color(1.0, 0.3, 0.9), Color(1.0, 0.35, 0.05), Color(0.2, 1.0, 0.6), Color(1.0, 0.85, 0.5)]

var world: Node3D
var track: TrackData
var layout: Dictionary
var omit := PackedByteArray()
var sector_of := PackedByteArray()
var root: Node3D


func build(w: Node3D, tr: TrackData, lay: Dictionary) -> void:
    world = w
    track = tr
    layout = lay
    root = Node3D.new()
    root.name = "Wonderland_Track"
    world.add_child(root)
    _compute_flags()
    var n := track.count
    var i := 0
    while i < n:
        _chunk(i, mini(i + CHUNK, n))
        i += CHUNK


func _compute_flags() -> void:
    var n := track.count
    omit.resize(n)
    omit.fill(0)
    sector_of.resize(n)
    var secs: Array = layout["sectors"]
    for s in secs.size():
        var v: Vector2i = secs[s]
        for i in range(v.x, mini(v.y, n)):
            sector_of[i] = s + 1
    for g in track.gaps:
        for i in range(int(g.x), int(g.x) + int(g.y)):
            omit[posmod(i, n)] = 1
    for l in track.lifts:
        for i in range(int(l.x), int(l.x) + int(l.y)):
            omit[posmod(i, n)] = 1
    for c in track.collapses:
        for i in range(c.x, c.y + 1):
            omit[posmod(i, n)] = 1
    for m in layout["mech"]:
        if m["t"] == "slider":
            for i in range(int(m["a"]), int(m["b"]) + 1):
                omit[posmod(i, n)] = 1


func is_omitted(i: int) -> bool:
    return omit[posmod(i, track.count)] == 1


func _chunk(a: int, b: int) -> void:
    build_piece(a, b, null, false)


# Monta um trecho de estrada (superfície + casco + colisão). 'body' != null: tudo vira filho dele (peças móveis);
# 'force' ignora as omissões (peças de pontes que caem / plataformas deslizantes).
func build_piece(a: int, b: int, body_in: CollisionObject3D, force: bool) -> void:
    var n := track.count
    var sec := int(sector_of[a])
    var sv := PackedVector3Array()
    var su := PackedVector2Array()
    var sn := PackedVector3Array()
    var si := PackedInt32Array()
    var rv := PackedVector3Array()
    var rn := PackedVector3Array()
    var rc := PackedColorArray()
    var ri := PackedInt32Array()
    var cols := [-1.0, -0.5, 0.0, 0.5, 1.0]
    var thick := 1.6
    var any := false
    for i in range(a, b):
        var j := (i + 1) % n
        if not force and (omit[i] == 1 or omit[j] == 1):
            continue
        any = true
        var hi := track.half_at(i)
        var hj := track.half_at(j)
        var ui := track.ups[i]
        var uj := track.ups[j]
        var di := float(i) * TrackData.SPACING
        var dj := di + TrackData.SPACING
        var base := sv.size()
        for k in cols.size():
            var li: float = cols[k] * hi
            sv.push_back(track.at(i, li) + ui * 0.02)
            su.push_back(Vector2(li, di))
            sn.push_back(ui)
        for k in cols.size():
            var lj: float = cols[k] * hj
            sv.push_back(track.at(j, lj) + uj * 0.02)
            su.push_back(Vector2(lj, dj))
            sn.push_back(uj)
        var cn := cols.size()
        for k in cn - 1:
            var p0 := base + k
            var p1 := base + k + 1
            var p2 := base + cn + k + 1
            var p3 := base + cn + k
            si.append_array([p0, p1, p2, p0, p2, p3])
            # (ordem anti-horária vista de cima: i->j é "frente", k aumenta para a direita)
        # casco de rocha: laterais, meio-fio e fundo
        var l_i := track.at(i, -hi)
        var r_i := track.at(i, hi)
        var l_j := track.at(j, -hj)
        var r_j := track.at(j, hj)
        var dwn_i := -ui * thick
        var dwn_j := -uj * thick
        var ks := track.rights[i] * 0.0
        var cb := rv.size()
        # lado esquerdo (normal para fora)
        _quad(rv, rn, rc, ri, l_i + ui * 0.02, l_j + uj * 0.02, l_j + dwn_j, l_i + dwn_i, -track.rights[i])
        _quad(rv, rn, rc, ri, r_j + uj * 0.02, r_i + ui * 0.02, r_i + dwn_i, r_j + dwn_j, track.rights[i])
        # fundo
        _quad(rv, rn, rc, ri, l_i + dwn_i, l_j + dwn_j, r_j + dwn_j, r_i + dwn_i, -ui)
        # meio-fio (0.45 m, 0.5 m de largura)
        var kh := 0.45
        var kw := 0.5
        var kl_i := l_i - track.rights[i] * kw
        var kl_j := l_j - track.rights[j] * kw
        var kr_i := r_i + track.rights[i] * kw
        var kr_j := r_j + track.rights[j] * kw
        _quad(rv, rn, rc, ri, kl_i + ui * kh, kl_j + uj * kh, l_j + uj * kh, l_i + ui * kh, ui)
        _quad(rv, rn, rc, ri, l_i + ui * 0.02, l_j + uj * 0.02, l_j + uj * kh, l_i + ui * kh, track.rights[i])
        _quad(rv, rn, rc, ri, kl_i + ui * kh, kl_i + dwn_i * 0.4, kl_j + dwn_j * 0.4, kl_j + uj * kh, -track.rights[i])
        _quad(rv, rn, rc, ri, r_i + ui * kh, r_j + uj * kh, kr_j + uj * kh, kr_i + ui * kh, ui)
        _quad(rv, rn, rc, ri, r_j + uj * 0.02, r_i + ui * 0.02, r_i + ui * kh, r_j + uj * kh, -track.rights[i])
        _quad(rv, rn, rc, ri, kr_j + uj * kh, kr_i + ui * kh, kr_i + dwn_i * 0.4, kr_j + dwn_j * 0.4, track.rights[i])
    if not any:
        return
    var tint: Color = SEC_TINT[maxi(sec, 1)]
    var edge: Color = SEC_EDGE[maxi(sec, 1)]
    var half := 8.0
    var mi := MeshInstance3D.new()
    var am := ArrayMesh.new()
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = sv
    arr[Mesh.ARRAY_NORMAL] = sn
    arr[Mesh.ARRAY_TEX_UV] = su
    arr[Mesh.ARRAY_INDEX] = _flip_if_needed(sv, si, sn)
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var wet := 0.5 if sec == 4 or sec == 5 else (0.15 if sec == 3 else 0.0)
    mi.mesh = am
    mi.material_override = WonderlandMaterials.road(tint, edge, half, wet)
    mi.visibility_range_end = 1500.0
    (body_in if body_in != null else root).add_child(mi)
    # casco
    var ri2 := _flip_if_needed_n(rv, ri, rn)
    var am2 := ArrayMesh.new()
    var arr2 := []
    arr2.resize(Mesh.ARRAY_MAX)
    arr2[Mesh.ARRAY_VERTEX] = rv
    arr2[Mesh.ARRAY_NORMAL] = rn
    arr2[Mesh.ARRAY_COLOR] = rc
    arr2[Mesh.ARRAY_INDEX] = ri2
    am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
    var mi2 := MeshInstance3D.new()
    mi2.mesh = am2
    mi2.material_override = WonderlandMaterials.rock(tint * 0.8, tint * 1.5, 0.2, 0.0, 0.0)
    mi2.visibility_range_end = 1200.0
    (body_in if body_in != null else root).add_child(mi2)
    # colisão: superfície + casco (um corpo por trecho)
    var cv := PackedVector3Array()
    for t in range(0, si.size(), 3):
        var tri := PackedInt32Array()
        tri = _tri_up(sv, arr[Mesh.ARRAY_INDEX], t)
        for q in tri:
            cv.push_back(sv[q])
    var body: CollisionObject3D = body_in
    if body == null:
        body = StaticBody3D.new()
        body.name = "Pista_%d" % a
        body.collision_layer = 1
        body.collision_mask = 0
    var shape := ConcavePolygonShape3D.new()
    var faces := PackedVector3Array()
    faces.append_array(cv)
    var ridx: PackedInt32Array = ri2
    for q in ridx:
        faces.push_back(rv[q])
    shape.backface_collision = true
    shape.set_faces(faces)
    var cs := CollisionShape3D.new()
    cs.shape = shape
    body.add_child(cs)
    if body_in == null:
        root.add_child(body)


func _tri_up(_sv: PackedVector3Array, idx: PackedInt32Array, t: int) -> PackedInt32Array:
    return PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]])


func _quad(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array, a: Vector3, b: Vector3, cc: Vector3, d: Vector3, nrm: Vector3) -> void:
    var base := v.size()
    var col := Color(0.8, 0.8, 0.8, 1.0)
    for p in [a, b, cc, d]:
        v.push_back(p)
        n.push_back(nrm)
        c.push_back(col)
    idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


# Garante que cada triângulo aponte para o lado da normal declarada (Godot usa sentido horário como frente).
func _flip_if_needed(v: PackedVector3Array, idx: PackedInt32Array, n: PackedVector3Array) -> PackedInt32Array:
    var out := PackedInt32Array()
    out.resize(idx.size())
    for t in range(0, idx.size(), 3):
        var a := v[idx[t]]
        var b := v[idx[t + 1]]
        var c := v[idx[t + 2]]
        var fn := (b - a).cross(c - a)
        var want := n[idx[t]]
        if fn.dot(want) > 0.0:
            # anti-horário em relação à normal -> inverte para horário (frente no Godot)
            out[t] = idx[t]
            out[t + 1] = idx[t + 2]
            out[t + 2] = idx[t + 1]
        else:
            out[t] = idx[t]
            out[t + 1] = idx[t + 1]
            out[t + 2] = idx[t + 2]
    return out


func _flip_if_needed_n(v: PackedVector3Array, idx: PackedInt32Array, n: PackedVector3Array) -> PackedInt32Array:
    return _flip_if_needed(v, idx, n)


# ------------------------------------------------------------- atalhos (ramais)
func build_branches() -> void:
    for br in track.branches:
        _branch_road(br)


# Trecho do ramal que já está livre da pista principal (largura somada + folga): só ali o ramal ganha malha própria.
func branch_clear_range(br: Dictionary) -> Vector2i:
    var bp: PackedVector3Array = br["pts"]
    var m: int = br["count"]
    var half_b: float = br["half"]
    var a := int(br["a"])
    var c := int(br["c"])
    var k0 := 0
    var k1 := m - 1
    for k in m:
        var dmin := 1e9
        for q in range(a - 4, a + 90):
            var pm := track.pts[posmod(q, track.count)]
            dmin = minf(dmin, Vector2(bp[k].x - pm.x, bp[k].z - pm.z).length())
        if dmin > track.half_at(a) + half_b + 2.5:
            k0 = k
            break
    for k in range(m - 1, -1, -1):
        var dmin2 := 1e9
        for q in range(c - 90, c + 4):
            var pm2 := track.pts[posmod(q, track.count)]
            dmin2 = minf(dmin2, Vector2(bp[k].x - pm2.x, bp[k].z - pm2.z).length())
        if dmin2 > track.half_at(c) + half_b + 2.5:
            k1 = k
            break
    return Vector2i(k0, k1)


func _branch_road(br: Dictionary) -> void:
    var bp: PackedVector3Array = br["pts"]
    var bs: PackedVector3Array = br["sides"]
    var m: int = br["count"]
    var half: float = br["half"]
    var cols := [-1.0, -0.5, 0.0, 0.5, 1.0]
    var sv := PackedVector3Array()
    var su := PackedVector2Array()
    var sn := PackedVector3Array()
    var si := PackedInt32Array()
    var rv := PackedVector3Array()
    var rn := PackedVector3Array()
    var rc := PackedColorArray()
    var ri := PackedInt32Array()
    var kr := branch_clear_range(br)
    var kb := 0
    for i in range(0, m):
        for k in cols.size():
            var lat: float = cols[k] * half
            sv.push_back(bp[i] + bs[i] * lat + Vector3(0, 0.03, 0))
            su.push_back(Vector2(lat, float(i) * TrackData.SPACING))
            sn.push_back(Vector3.UP)
        if i > 0:
            var base := (i - 1 - kb) * cols.size()
            var cn := cols.size()
            for k in cn - 1:
                si.append_array([base + k, base + cn + k, base + cn + k + 1, base + k, base + cn + k + 1, base + k + 1])
    for i in range(kr.x, kr.y):
        var l0 := bp[i] - bs[i] * half
        var r0 := bp[i] + bs[i] * half
        var l1 := bp[i + 1] - bs[i + 1] * half
        var r1 := bp[i + 1] + bs[i + 1] * half
        var d := Vector3(0, -1.4, 0)
        _quad(rv, rn, rc, ri, l0, l1, l1 + d, l0 + d, -bs[i])
        _quad(rv, rn, rc, ri, r1, r0, r0 + d, r1 + d, bs[i])
        _quad(rv, rn, rc, ri, l0 + d, l1 + d, r1 + d, r0 + d, Vector3.DOWN)
        # meio-fio
        var kh := Vector3(0, 0.45, 0)
        _quad(rv, rn, rc, ri, l0 - bs[i] * 0.5 + kh, l1 - bs[i + 1] * 0.5 + kh, l1 + kh, l0 + kh, Vector3.UP)
        _quad(rv, rn, rc, ri, r1 + kh, r0 + kh, r0 + bs[i] * 0.5 + kh, r1 + bs[i + 1] * 0.5 + kh, Vector3.UP)
        _quad(rv, rn, rc, ri, l0 + Vector3(0, 0.03, 0), l1 + Vector3(0, 0.03, 0), l1 + kh, l0 + kh, bs[i])
        _quad(rv, rn, rc, ri, r1 + Vector3(0, 0.03, 0), r0 + Vector3(0, 0.03, 0), r0 + kh, r1 + kh, -bs[i])
    var sec := int(sector_of[int(br["a"]) % track.count])
    var fi := _flip_if_needed(sv, si, sn)
    var ri2 := _flip_if_needed(rv, ri, rn)
    var am := ArrayMesh.new()
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = sv
    arr[Mesh.ARRAY_NORMAL] = sn
    arr[Mesh.ARRAY_TEX_UV] = su
    arr[Mesh.ARRAY_INDEX] = fi
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var mi := MeshInstance3D.new()
    mi.mesh = am
    var tint: Color = SEC_TINT[maxi(sec, 1)] * 0.9
    var edge: Color = Color(1.0, 0.9, 0.2) if sec == 5 else Color(1.0, 0.55, 0.1)
    mi.material_override = WonderlandMaterials.road(tint, edge, half, 0.2)
    mi.name = "Atalho_%s" % str(br["id"])
    root.add_child(mi)
    var am2 := ArrayMesh.new()
    var arr2 := []
    arr2.resize(Mesh.ARRAY_MAX)
    arr2[Mesh.ARRAY_VERTEX] = rv
    arr2[Mesh.ARRAY_NORMAL] = rn
    arr2[Mesh.ARRAY_COLOR] = rc
    arr2[Mesh.ARRAY_INDEX] = ri2
    am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
    var mi2 := MeshInstance3D.new()
    mi2.mesh = am2
    mi2.material_override = WonderlandMaterials.rock(tint * 0.8, tint * 1.5, 0.2, 0.0, 0.0)
    root.add_child(mi2)
    var faces := PackedVector3Array()
    for q in fi:
        faces.push_back(sv[q])
    for q in ri2:
        faces.push_back(rv[q])
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    var shape := ConcavePolygonShape3D.new()
    shape.backface_collision = true
    shape.set_faces(faces)
    var cs := CollisionShape3D.new()
    cs.shape = shape
    body.add_child(cs)
    root.add_child(body)
