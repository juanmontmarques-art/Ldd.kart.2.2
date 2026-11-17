class_name WonderlandProps
extends RefCounted

# Arquitetura e vegetação: pontes suspensas (torres, cabos, pendurais), pontes de pedra com pilares até o abismo,
# colunas ancestrais, floresta de coníferas na superfície, chegada monumental e largada.

var world: Node3D
var track: TrackData
var layout: Dictionary
var terrain: WonderlandTerrain
var road: WonderlandTrack
var root: Node3D
var rng := RandomNumberGenerator.new()
var stone_mat: ShaderMaterial


func build(w: Node3D, tr: TrackData, lay: Dictionary, terr: WonderlandTerrain, rd: WonderlandTrack) -> void:
    world = w
    track = tr
    layout = lay
    terrain = terr
    road = rd
    rng.seed = 424242
    root = Node3D.new()
    root.name = "Wonderland_Props"
    world.add_child(root)
    stone_mat = WonderlandMaterials.rock(Color(0.38, 0.35, 0.32), Color(0.72, 0.67, 0.6), 0.22, 0.0, 0.6)
    _bridges()
    _pillars()
    _forest()
    _spires()


func _add(mb: MeshBuilder, name_s: String, collide: bool = true) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mb.to_mesh()
    mi.material_override = stone_mat
    mi.name = name_s
    mi.visibility_range_end = 1400.0
    root.add_child(mi)
    if collide:
        var body := StaticBody3D.new()
        body.collision_layer = 1
        body.collision_mask = 0
        var cs := CollisionShape3D.new()
        cs.shape = mb.to_collision()
        body.add_child(cs)
        root.add_child(body)
    return mi


func _bridges() -> void:
    for br in track.bridges:
        var a := br.x
        var b := br.y
        var kind := br.z
        if kind == 0:
            _suspension(a, b)
        else:
            _stone_bridge(a, b)


func _suspension(a: int, b: int) -> void:
    var mb := MeshBuilder.new()
    var cable := Color(0.12, 0.1, 0.1)
    var wood := Color(0.55, 0.4, 0.25)
    var tower_h := 24.0
    var half := track.half_at((a + b) / 2) + 1.2
    for end_i in [a, b]:
        var p := track.pts[end_i]
        var s := track.sides[end_i]
        for sgn: float in [-1.0, 1.0]:
            var c := p + s * sgn * (half + 0.6)
            mb.box(c + Vector3(0, tower_h * 0.5, 0), Vector3(1.1, tower_h * 0.5, 1.1), Color(0.6, 0.57, 0.52))
            mb.box(c + Vector3(0, tower_h + 0.6, 0), Vector3(1.6, 0.6, 1.6), Color(0.45, 0.42, 0.4))
        # travessa superior
        mb.box(p + Vector3(0, tower_h * 0.92, 0), Vector3(half + 1.5, 0.5, 0.7), Color(0.6, 0.57, 0.52))
    # cabos (catenária simples) e pendurais
    var step := 4
    var i := a
    while i < b:
        var j := mini(i + step, b)
        var u0 := float(i - a) / float(b - a)
        var u1 := float(j - a) / float(b - a)
        for sgn: float in [-1.0, 1.0]:
            var p0 := track.pts[i] + track.sides[i] * sgn * (half + 0.6)
            var p1 := track.pts[j] + track.sides[j] * sgn * (half + 0.6)
            var h0 := lerpf(tower_h, 3.2, sin(PI * u0))
            var h1 := lerpf(tower_h, 3.2, sin(PI * u1))
            var q0 := p0 + Vector3(0, h0, 0)
            var q1 := p1 + Vector3(0, h1, 0)
            var d := q1 - q0
            var mid := (q0 + q1) * 0.5
            var bs := Basis.looking_at(d.normalized(), Vector3.UP)
            mb.box(mid, Vector3(0.12, 0.12, d.length() * 0.5), cable, bs)
            mb.box((p0 + q0) * 0.5, Vector3(0.05, h0 * 0.5, 0.05), cable)
        i += step
    # tábuas (cenário, sem colisão extra: a estrada já é sólida)
    var mi := _add(mb, "PonteSuspensa_%d" % a, false)
    # corrimão sólido: colisão simples nas laterais para dar sensação de ponte (somente trechos curtos)
    mi.set_meta("bridge", true)


func _stone_bridge(a: int, b: int) -> void:
    var mb := MeshBuilder.new()
    var i := a
    while i <= b:
        var p := track.pts[i]
        var gy := maxf(terrain.height_at(p.x, p.z), p.y - 230.0)
        var hgt := p.y - 1.7 - gy
        if hgt > 3.0:
            mb.box(Vector3(p.x, gy + hgt * 0.5, p.z), Vector3(3.2, hgt * 0.5, 3.2), Color(0.55, 0.5, 0.45))
            mb.box(Vector3(p.x, p.y - 2.6, p.z), Vector3(5.5, 1.1, 5.5), Color(0.62, 0.57, 0.5))
        # balaustres decorativos nas bordas
        var s := track.sides[i]
        var hw := track.half_at(i)
        for sgn: float in [-1.0, 1.0]:
            var q := track.at(i, sgn * (hw + 0.2))
            mb.box(q + Vector3(0, 0.9, 0), Vector3(0.28, 0.9, 0.28), Color(0.7, 0.65, 0.58))
        i += 14
    _add(mb, "PonteDePedra_%d" % a, false)
    # corrimão lateral baixo (muretas de pedra contínuas com colisão leve, 1.1 m)
    var rails := MeshBuilder.new()
    var j := a
    while j < b - 1:
        var k := j + 2
        for sgn: float in [-1.0, 1.0]:
            var q0 := track.at(j, sgn * (track.half_at(j) + 0.3))
            var q1 := track.at(k, sgn * (track.half_at(k) + 0.3))
            var d := q1 - q0
            var bs := Basis.looking_at(d.normalized(), Vector3.UP)
            rails.box((q0 + q1) * 0.5 + Vector3(0, 0.55, 0), Vector3(0.22, 0.55, d.length() * 0.5), Color(0.66, 0.61, 0.55), bs)
        j += 2
    _add(rails, "Muretas_%d" % a, true)


func _pillars() -> void:
    var mb := MeshBuilder.new()
    for q in layout["pillars"].size():
        var s: int = layout["pillars"][q]
        var p := track.pts[s]
        var side := track.sides[s]
        var sgn := 1.0 if q % 2 == 0 else -1.0
        var c := p + side * sgn * 26.0
        var gy := maxf(terrain.height_at(c.x, c.z), p.y - 240.0)
        var top := p.y + 28.0 + float(q % 3) * 8.0
        mb.cylinder(Vector3(c.x, gy, c.z), 5.2, 4.2, top - gy, 10, Color(0.66, 0.6, 0.54))
        for r in range(0, int((top - gy) / 14.0)):
            mb.cylinder(Vector3(c.x, gy + float(r) * 14.0, c.z), 5.8, 5.8, 1.2, 10, Color(0.5, 0.46, 0.42))
        mb.box(Vector3(c.x, top + 1.0, c.z), Vector3(6.4, 1.0, 6.4), Color(0.72, 0.67, 0.6))
    if not mb.is_empty():
        _add(mb, "ColunasAncestrais", true)


func _spires() -> void:
    # agulhas de rocha monumentais no abismo (visuais, com colisão para o kart não atravessar se tocar)
    var secs: Array = layout["sectors"]
    var s3: Vector2i = secs[2]
    var mb := MeshBuilder.new()
    var i := s3.x + 20
    while i < s3.y - 20:
        var p := track.pts[i]
        var side := track.sides[i]
        for sgn: float in [-1.0, 1.0]:
            var d := rng.randf_range(48.0, 75.0)
            var c := p + side * sgn * d
            var gy := maxf(terrain.height_at(c.x, c.z), p.y - 200.0)
            var hgt := p.y + rng.randf_range(20.0, 90.0) - gy
            mb.cone(Vector3(c.x, gy, c.z), rng.randf_range(9.0, 16.0), hgt, 9, Color(0.5, 0.46, 0.44))
        i += rng.randi_range(22, 40)
    if not mb.is_empty():
        _add(mb, "AgulhasDeRocha", false)


func _forest() -> void:
    var mb_trunk := MeshBuilder.new()
    mb_trunk.cylinder(Vector3.ZERO, 0.35, 0.25, 2.2, 5, Color(0.35, 0.22, 0.12))
    mb_trunk.cone(Vector3(0, 1.4, 0), 2.1, 4.2, 7, Color(0.13, 0.30, 0.16))
    mb_trunk.cone(Vector3(0, 3.4, 0), 1.6, 3.6, 7, Color(0.16, 0.36, 0.18))
    mb_trunk.cone(Vector3(0, 5.2, 0), 1.0, 3.0, 7, Color(0.2, 0.42, 0.2))
    var mesh := mb_trunk.to_mesh()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 0.9
    var xf: Array = []
    var tries := 0
    while xf.size() < 2600 and tries < 30000:
        tries += 1
        var x := rng.randf_range(terrain.min_x, terrain.min_x + float(terrain.nx - 1) * terrain.cell)
        var z := rng.randf_range(terrain.min_z, terrain.min_z + float(terrain.nz - 1) * terrain.cell)
        var y := terrain.height_at(x, z)
        if y < -60.0 or y > 235.0:
            continue
        var sl := (absf(terrain.height_at(x + 4.0, z) - y) + absf(terrain.height_at(x, z + 4.0) - y)) / 8.0
        if sl > 0.6:
            continue
        var sc := rng.randf_range(1.6, 3.8)
        xf.push_back(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.5), sc)), Vector3(x, y - 0.3, z)))
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xf.size()
    for q in xf.size():
        mm.set_instance_transform(q, xf[q])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = mat
    mmi.name = "Floresta"
    mmi.visibility_range_end = 900.0
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(mmi)


func build_start_finish() -> void:
    world._make_start_area()
    var mb := MeshBuilder.new()
    var p := track.pts[0]
    var t := track.tans[0]
    var s := track.sides[0]
    var bs := Basis.looking_at(Vector3(t.x, 0, t.z).normalized(), Vector3.UP)
    var holder := Node3D.new()
    holder.name = "ChegadaMonumental"
    holder.transform = Transform3D(bs, p)
    root.add_child(holder)
    var mb2 := MeshBuilder.new()
    for sgn: float in [-1.0, 1.0]:
        mb2.box(Vector3(sgn * 26.0, 14.0, -8.0), Vector3(3.0, 14.0, 3.0), Color(0.72, 0.66, 0.58))
        mb2.box(Vector3(sgn * 26.0, 29.0, -8.0), Vector3(4.2, 1.2, 4.2), Color(0.8, 0.74, 0.64))
        mb2.cone(Vector3(sgn * 26.0, 30.2, -8.0), 3.0, 8.0, 8, Color(0.85, 0.8, 0.7))
    mb2.box(Vector3(0, 30.0, -8.0), Vector3(26.0, 1.4, 2.4), Color(0.75, 0.69, 0.6))
    var mi := MeshInstance3D.new()
    mi.mesh = mb2.to_mesh()
    mi.material_override = stone_mat
    holder.add_child(mi)
    var body := StaticBody3D.new()
    body.collision_layer = 1
    var cs := CollisionShape3D.new()
    cs.shape = mb2.to_collision()
    body.add_child(cs)
    holder.add_child(body)
    var lab := Label3D.new()
    lab.text = "WONDERLAND"
    lab.font_size = 160
    lab.pixel_size = 0.016
    lab.modulate = Color(1.0, 0.85, 0.4)
    lab.outline_size = 24
    lab.position = Vector3(0, 30.0, -6.4)
    lab.rotation_degrees = Vector3(0, 180, 0)
    holder.add_child(lab)
    for sgn: float in [-1.0, 1.0]:
        var fl := OmniLight3D.new()
        fl.position = Vector3(sgn * 26.0, 36.0, -8.0)
        fl.light_color = Color(1.0, 0.6, 0.25)
        fl.light_energy = 3.0
        fl.omni_range = 40.0
        holder.add_child(fl)
