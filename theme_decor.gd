class_name ThemeDecor
extends RefCounted

# Cenário temático de cada mapa: conjuntos de árvores, marcos (pirâmides, igloos, vulcão...),
# balões, aurora, fumaça e o clima (neve / brasas) preso à câmera.
# Tudo é montado em código com MeshBuilder; instâncias repetidas usam MultiMesh.

var _w: WorldBuilder
var _rng := RandomNumberGenerator.new()


# ----------------------------------------------------------------- árvores
static func tree_set(theme: MapTheme) -> Dictionary:
    var meshes: Array[ArrayMesh] = []
    var d := {"tree_line": 60.0, "high_h": 14.0, "high_chance": 0.25}
    match theme.style:
        "desert":
            meshes.append(_saguaro(5.4, 0.46, true))
            meshes.append(_saguaro(3.6, 0.40, false))
            meshes.append(_palm())
            meshes.append(_barrel_cactus())
            meshes.append(_dry_bush())
            d["low"] = [0, 1, 3, 3, 4, 4, 2]
            d["high"] = []
            d["tree_line"] = 40.0
        "ice":
            meshes.append(_snow_pine(1.0, Color(0.10, 0.38, 0.30)))
            meshes.append(_snow_pine(1.3, Color(0.14, 0.44, 0.34)))
            meshes.append(_snow_pine(0.7, Color(0.12, 0.40, 0.32)))
            meshes.append(_crystal_cluster(0.8))
            d["low"] = [0, 1, 2, 2]
            d["high"] = [3, 0]
            d["high_h"] = 22.0
            d["high_chance"] = 0.08
            d["tree_line"] = 55.0
        "lava":
            meshes.append(_dead_tree(5.0))
            meshes.append(_dead_tree(3.4))
            meshes.append(_obsidian_spikes(1.0))
            meshes.append(_obsidian_spikes(1.6))
            d["low"] = [0, 1, 2, 3]
            d["high"] = []
            d["tree_line"] = 90.0
        "lagoon":
            meshes.append(_palm())
            meshes.append(_palm())
            meshes.append(_broadleaf(Color(0.12, 0.60, 0.28)))
            meshes.append(_broadleaf(Color(0.30, 0.72, 0.26)))
            meshes.append(_dry_bush())
            d["low"] = [0, 1, 2, 3, 2, 3, 4]
            d["high"] = [2, 3]
        "alpine":
            meshes.append(_snow_pine(1.1, Color(0.10, 0.36, 0.26)))
            meshes.append(_snow_pine(1.5, Color(0.12, 0.40, 0.28)))
            meshes.append(_snow_pine(0.8, Color(0.14, 0.42, 0.30)))
            d["low"] = [0, 1, 2]
            d["high"] = [2]
            d["high_h"] = 40.0
            d["high_chance"] = 0.10
            d["tree_line"] = 75.0
        "jungle":
            meshes.append(_jungle_tree(1.0))
            meshes.append(_jungle_tree(1.4))
            meshes.append(_jungle_tree(0.8))
            meshes.append(_fern())
            meshes.append(_fern())
            d["low"] = [0, 1, 2, 3, 4, 0, 1]
            d["high"] = [0, 2]
            d["high_chance"] = 0.4
            d["tree_line"] = 90.0
        _:
            var greens: Array[Color] = [Color(0.20, 0.64, 0.22), Color(0.34, 0.76, 0.26), Color(0.14, 0.56, 0.32)]
            for g in greens:
                var mb := MeshBuilder.new()
                mb.cylinder(Vector3.ZERO, 0.40, 0.30, 2.6, 7, Color(0.48, 0.30, 0.15))
                mb.sphere(Vector3(0.0, 3.9, 0.0), Vector3(2.0, 1.8, 2.0), 4, 7, g)
                mb.sphere(Vector3(0.9, 5.2, 0.3), Vector3(1.3, 1.2, 1.3), 4, 7, g.lightened(0.14))
                meshes.append(mb.to_mesh())
            var pines: Array[Color] = [Color(0.10, 0.45, 0.28), Color(0.16, 0.52, 0.30)]
            for g in pines:
                var mb := MeshBuilder.new()
                mb.cylinder(Vector3.ZERO, 0.38, 0.30, 2.0, 7, Color(0.42, 0.26, 0.14))
                mb.cone(Vector3(0.0, 1.4, 0.0), 2.3, 3.0, 8, g)
                mb.cone(Vector3(0.0, 3.2, 0.0), 1.8, 2.8, 8, g.lightened(0.06))
                mb.cone(Vector3(0.0, 4.9, 0.0), 1.2, 2.6, 8, g.lightened(0.12))
                meshes.append(mb.to_mesh())
            d["low"] = [0, 1, 2]
            d["high"] = [3, 4]
    d["meshes"] = meshes
    return d


static func _saguaro(h: float, r: float, arms: bool) -> ArrayMesh:
    var g := Color(0.30, 0.58, 0.28)
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3.ZERO, r, r * 0.9, h, 8, g)
    mb.sphere(Vector3(0.0, h, 0.0), Vector3(r * 0.9, r * 1.1, r * 0.9), 3, 8, g.lightened(0.05))
    if arms:
        mb.box(Vector3(0.75, h * 0.45, 0.0), Vector3(0.75, 0.22, 0.22), g)
        mb.cylinder(Vector3(1.5, h * 0.45 - 0.2, 0.0), 0.22, 0.2, h * 0.38, 7, g)
        mb.sphere(Vector3(1.5, h * 0.45 - 0.2 + h * 0.38, 0.0), Vector3(0.22, 0.28, 0.22), 3, 7, g.lightened(0.05))
        mb.box(Vector3(-0.6, h * 0.62, 0.0), Vector3(0.6, 0.2, 0.2), g)
        mb.cylinder(Vector3(-1.2, h * 0.62 - 0.2, 0.0), 0.2, 0.18, h * 0.26, 7, g)
    return mb.to_mesh()


static func _palm() -> ArrayMesh:
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3.ZERO, 0.34, 0.2, 6.4, 7, Color(0.55, 0.40, 0.24))
    var top := Vector3(0.0, 6.4, 0.0)
    for k in 7:
        var a := float(k) * TAU / 7.0
        var rot := Basis(Vector3.UP, a)
        var b := rot * Basis(Vector3(0.0, 0.0, 1.0), -0.38)
        mb.box(top + rot * Vector3(1.8, -0.3, 0.0), Vector3(2.0, 0.05, 0.34), Color(0.22, 0.60, 0.22).lightened(0.05 * float(k % 2)), b)
    mb.sphere(top + Vector3(0.0, -0.2, 0.0), Vector3(0.35, 0.3, 0.35), 3, 6, Color(0.45, 0.30, 0.15))
    return mb.to_mesh()


static func _barrel_cactus() -> ArrayMesh:
    var mb := MeshBuilder.new()
    mb.sphere(Vector3(0.0, 0.6, 0.0), Vector3(0.75, 0.65, 0.75), 4, 8, Color(0.32, 0.60, 0.30))
    mb.sphere(Vector3(0.0, 1.25, 0.0), Vector3(0.22, 0.14, 0.22), 3, 6, Color(0.95, 0.40, 0.55))
    return mb.to_mesh()


static func _broadleaf(g: Color) -> ArrayMesh:
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3.ZERO, 0.42, 0.30, 3.0, 7, Color(0.46, 0.30, 0.16))
    mb.sphere(Vector3(0.0, 4.4, 0.0), Vector3(2.4, 1.8, 2.4), 4, 7, g)
    mb.sphere(Vector3(1.3, 3.8, 0.4), Vector3(1.4, 1.1, 1.4), 4, 7, g.lightened(0.12))
    return mb.to_mesh()


static func _jungle_tree(s: float) -> ArrayMesh:
    var mb := MeshBuilder.new()
    var bark := Color(0.34, 0.22, 0.12)
    mb.cylinder(Vector3.ZERO, 0.6 * s, 0.38 * s, 7.0 * s, 7, bark)
    var g := Color(0.08, 0.46, 0.16)
    mb.sphere(Vector3(0.0, 8.0 * s, 0.0), Vector3(3.6, 1.7, 3.6) * s, 4, 8, g)
    mb.sphere(Vector3(1.8 * s, 7.2 * s, 0.6 * s), Vector3(2.4, 1.3, 2.4) * s, 4, 7, g.lightened(0.12))
    mb.sphere(Vector3(-1.6 * s, 7.4 * s, -0.8 * s), Vector3(2.2, 1.2, 2.2) * s, 4, 7, g.darkened(0.1))
    return mb.to_mesh()


static func _fern() -> ArrayMesh:
    var mb := MeshBuilder.new()
    for q in 5:
        var a := float(q) / 5.0 * TAU
        mb.cone(Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5), 0.35, 1.8, 4, Color(0.18, 0.62, 0.22).lightened(float(q) * 0.04))
    return mb.to_mesh()


static func _dry_bush() -> ArrayMesh:
    var mb := MeshBuilder.new()
    mb.sphere(Vector3(0.0, 0.4, 0.0), Vector3(0.9, 0.5, 0.8), 3, 6, Color(0.62, 0.50, 0.28))
    mb.sphere(Vector3(0.6, 0.3, 0.3), Vector3(0.5, 0.35, 0.5), 3, 6, Color(0.55, 0.44, 0.24))
    return mb.to_mesh()


static func _snow_pine(s: float, green: Color) -> ArrayMesh:
    var snow := Color(0.96, 0.98, 1.0)
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3.ZERO, 0.38 * s, 0.30 * s, 2.0 * s, 7, Color(0.36, 0.24, 0.16))
    mb.cone(Vector3(0.0, 1.3 * s, 0.0), 2.4 * s, 3.0 * s, 8, green)
    mb.cone(Vector3(0.0, 2.2 * s, 0.0), 1.9 * s, 0.9 * s, 8, snow)
    mb.cone(Vector3(0.0, 3.1 * s, 0.0), 1.9 * s, 2.8 * s, 8, green.lightened(0.05))
    mb.cone(Vector3(0.0, 3.9 * s, 0.0), 1.4 * s, 0.8 * s, 8, snow)
    mb.cone(Vector3(0.0, 4.9 * s, 0.0), 1.3 * s, 2.6 * s, 8, green.lightened(0.10))
    mb.cone(Vector3(0.0, 5.9 * s, 0.0), 0.85 * s, 1.6 * s, 8, snow)
    return mb.to_mesh()


static func _crystal_cluster(s: float) -> ArrayMesh:
    var mb := MeshBuilder.new()
    var cols: Array[Color] = [Color(0.62, 0.90, 1.0), Color(0.45, 0.78, 0.98), Color(0.78, 0.95, 1.0), Color(0.40, 0.70, 0.96)]
    var offs: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1.1, 0, 0.4), Vector3(-0.9, 0, 0.7), Vector3(0.3, 0, -1.0)]
    var hs: Array[float] = [6.0, 3.8, 4.4, 3.0]
    for q in 4:
        mb.cone(offs[q] * s, 0.8 * s, hs[q] * s, 5, cols[q])
    return mb.to_mesh()


static func _dead_tree(h: float) -> ArrayMesh:
    var bark := Color(0.16, 0.12, 0.12)
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3.ZERO, 0.38, 0.14, h, 6, bark)
    mb.box(Vector3(0.7, h * 0.62, 0.0), Vector3(0.8, 0.09, 0.09), bark, Basis(Vector3(0, 0, 1), 0.5))
    mb.box(Vector3(-0.6, h * 0.78, 0.2), Vector3(0.7, 0.08, 0.08), bark, Basis(Vector3(0, 0, 1), -0.6))
    mb.box(Vector3(0.1, h * 0.5, -0.7), Vector3(0.07, 0.07, 0.7), bark, Basis(Vector3(1, 0, 0), 0.4))
    return mb.to_mesh()


static func _obsidian_spikes(s: float) -> ArrayMesh:
    var mb := MeshBuilder.new()
    mb.cone(Vector3(0.0, 0.0, 0.0), 1.1 * s, 5.0 * s, 5, Color(0.10, 0.08, 0.13))
    mb.cone(Vector3(1.2 * s, 0.0, 0.3 * s), 0.8 * s, 3.2 * s, 5, Color(0.16, 0.10, 0.16))
    mb.cone(Vector3(-0.9 * s, 0.0, 0.8 * s), 0.7 * s, 2.6 * s, 5, Color(0.12, 0.09, 0.14))
    mb.sphere(Vector3(0.0, 0.1, 0.0), Vector3(1.3 * s, 0.25 * s, 1.3 * s), 3, 7, Color(1.0, 0.40, 0.06))
    return mb.to_mesh()


# --------------------------------------------------------------- montagem
func build(world: WorldBuilder, theme: MapTheme) -> void:
    _w = world
    _rng.seed = 777 + theme.id.hash() % 1000
    match theme.style:
        "desert":
            _build_desert()
        "ice":
            _build_ice()
        "lava":
            _build_lava()
        "lagoon":
            _build_lagoon()
        "alpine":
            _build_alpine()
        "jungle":
            _build_jungle()
        _:
            pass


# Sorteia pontos fora da pista, em terreno firme, a uma certa distância do centro.
func _spots(step: int, start: int, off_min: float, off_max: float) -> Array[Vector3]:
    var out: Array[Vector3] = []
    var tr := _w.track
    var n := tr.count
    var i := start
    while i < n:
        var sg := 1.0 if _rng.randf() > 0.5 else -1.0
        var off := off_min + _rng.randf() * (off_max - off_min)
        var p := tr.pts[i] + tr.sides[i] * sg * off
        i += step
        if p.x < _w.min_x + 30.0 or p.x > _w.max_x - 30.0 or p.z < _w.min_z + 30.0 or p.z > _w.max_z - 30.0:
            continue
        if _w.road_dist_at(p.x, p.z) < off_min - 4.0:
            continue
        if _w._near_lake(p.x, p.z, 1.35):
            continue
        var ii := (i - step) % n
        if tr.in_cliff(ii):
            continue
        var h := _w.height_at(p.x, p.z)
        if h < tr.pts[ii].y - 10.0 or _w.slope_at(p.x, p.z) > 0.5:
            continue
        out.append(Vector3(p.x, h, p.z))
    return out


# Instancia uma malha em várias posições (MultiMesh) e, opcionalmente, com colisão cilíndrica.
func _place(node_name: String, mesh: Mesh, spots: Array[Vector3], smin: float, smax: float, stretch: Vector2, coll_r: float, coll_h: float, sink: float = 0.2) -> void:
    if spots.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = spots.size()
    var body: StaticBody3D = null
    var shape: CylinderShape3D = null
    if coll_r > 0.0:
        body = StaticBody3D.new()
        body.name = "Col" + node_name
        body.collision_layer = 1
        body.collision_mask = 0
        _w.add_child(body)
        shape = CylinderShape3D.new()
        shape.radius = coll_r
        shape.height = coll_h
    for q in spots.size():
        var s := _rng.randf_range(smin, smax)
        var sy := s * _rng.randf_range(stretch.x, stretch.y)
        var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, sy, s))
        var p := spots[q] + Vector3(0.0, -sink, 0.0)
        mm.set_instance_transform(q, Transform3D(b, p))
        if body != null:
            var cs := CollisionShape3D.new()
            cs.shape = shape
            cs.scale = Vector3(s, sy, s)
            cs.position = p + Vector3(0.0, coll_h * 0.5 * sy, 0.0)
            body.add_child(cs)
    var inst := MultiMeshInstance3D.new()
    inst.name = node_name
    inst.multimesh = mm
    inst.material_override = _w._mat_vertex_color(0.9)
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    inst.visibility_range_end = 700.0
    _w.add_child(inst)


func _static_mesh(node_name: String, mesh: Mesh, pos: Vector3, unshaded: bool = false) -> MeshInstance3D:
    var mi := _w._add_mesh(mesh, _w._mat_vertex_color(0.9, unshaded))
    mi.name = node_name
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi


# ------------------------------------------------------------------ deserto
func _build_desert() -> void:
    var sand := Color(0.95, 0.80, 0.50)
    var sand_d := Color(0.82, 0.64, 0.38)

    # Pirâmides (degraus fingidos com cones empilhados) e obeliscos.
    var pb := MeshBuilder.new()
    pb.cone(Vector3(0.0, 0.0, 0.0), 1.0, 1.0, 4, sand)
    pb.cylinder(Vector3(0.0, 0.0, 0.0), 1.02, 1.0, 0.04, 4, sand_d)
    pb.box(Vector3(0.0, 0.07, 0.99), Vector3(0.09, 0.07, 0.03), Color(0.18, 0.12, 0.10))
    _place("Piramides", pb.to_mesh(), _spots(46, 12, 70.0, 150.0), 24.0, 46.0, Vector2(0.75, 0.95), 0.62, 1.0, 0.5)

    var ob := MeshBuilder.new()
    ob.cylinder(Vector3.ZERO, 1.3, 0.8, 13.0, 4, Color(0.88, 0.72, 0.46))
    ob.cone(Vector3(0.0, 13.0, 0.0), 0.8, 1.8, 4, Color(1.0, 0.82, 0.25))
    ob.box(Vector3(0.0, 0.3, 0.0), Vector3(1.9, 0.3, 1.9), sand_d)
    _place("Obeliscos", ob.to_mesh(), _spots(23, 5, 16.0, 30.0), 0.8, 1.3, Vector2(0.9, 1.2), 1.0, 13.0, 0.0)

    # Ruínas: arcos de pedra e colunas quebradas.
    var ab := MeshBuilder.new()
    ab.cylinder(Vector3(-3.2, 0.0, 0.0), 0.9, 0.8, 7.0, 8, sand_d)
    ab.cylinder(Vector3(3.2, 0.0, 0.0), 0.9, 0.8, 7.0, 8, sand_d)
    ab.box(Vector3(0.0, 7.4, 0.0), Vector3(4.6, 0.6, 1.0), sand)
    ab.box(Vector3(0.0, 8.3, 0.0), Vector3(1.4, 0.3, 0.8), Color(0.90, 0.30, 0.20))
    _place("Arcos", ab.to_mesh(), _spots(37, 9, 14.0, 24.0), 1.0, 1.5, Vector2(1.0, 1.1), 0.0, 0.0, 0.0)
    var cb := MeshBuilder.new()
    cb.cylinder(Vector3.ZERO, 0.8, 0.7, 4.5, 8, sand_d)
    cb.cylinder(Vector3(0.0, 4.5, 0.0), 0.7, 0.4, 0.8, 8, sand)
    cb.box(Vector3(2.2, 0.35, 0.8), Vector3(0.9, 0.35, 0.6), sand_d)
    _place("Colunas", cb.to_mesh(), _spots(15, 3, 14.0, 34.0), 0.8, 1.4, Vector2(0.5, 1.3), 0.8, 4.5, 0.1)

    # Mesas (mesetas) ao longe.
    var mbm := MeshBuilder.new()
    mbm.cylinder(Vector3.ZERO, 1.0, 0.82, 0.45, 9, Color(0.72, 0.36, 0.22))
    mbm.cylinder(Vector3(0.0, 0.45, 0.0), 0.82, 0.76, 0.3, 9, Color(0.88, 0.55, 0.32))
    mbm.cylinder(Vector3(0.0, 0.75, 0.0), 0.76, 0.84, 0.25, 9, Color(0.78, 0.42, 0.26))
    mbm.cylinder(Vector3(0.0, 1.0, 0.0), 0.84, 0.8, 0.08, 9, Color(0.93, 0.80, 0.50))
    _place("Mesas", mbm.to_mesh(), _spots(60, 20, 120.0, 220.0), 14.0, 30.0, Vector2(1.0, 1.9), 0.8, 1.08, 1.0)

    # Balões ao fundo.
    var bm := MeshBuilder.new()
    bm.sphere(Vector3(0.0, 0.0, 0.0), Vector3(5.2, 6.0, 5.2), 5, 10, Color(0.92, 0.22, 0.18))
    bm.sphere(Vector3(0.0, -0.4, 0.0), Vector3(5.3, 1.6, 5.3), 3, 10, Color(1.0, 0.86, 0.25))
    bm.sphere(Vector3(0.0, -3.4, 0.0), Vector3(3.2, 2.4, 3.2), 4, 9, Color(0.95, 0.40, 0.12))
    bm.box(Vector3(0.0, -9.0, 0.0), Vector3(0.9, 0.6, 0.9), Color(0.50, 0.32, 0.18))
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var fx: float = sx
            var fz: float = sz
            bm.box(Vector3(fx * 0.7, -6.2, fz * 0.7), Vector3(0.04, 2.2, 0.04), Color(0.25, 0.2, 0.15))
    var bmesh := bm.to_mesh()
    var bspots := _spots(90, 30, 60.0, 180.0)
    for q in bspots.size():
        var p := bspots[q]
        var mi := _static_mesh("Balao%d" % q, bmesh, Vector3(p.x, p.y + _rng.randf_range(55.0, 110.0), p.z))
        mi.scale = Vector3.ONE * _rng.randf_range(0.9, 1.6)
        mi.rotation.y = _rng.randf() * TAU

    # Oásis: palmeiras em volta de cada lago.
    var palm := _palm()
    var oasis: Array[Vector3] = []
    for lk in _w.track.lakes:
        for q in 12:
            var a := _rng.randf() * TAU
            var rr: float = lk.z * _rng.randf_range(1.0, 1.25)
            var x: float = lk.x + cos(a) * rr
            var z: float = lk.y + sin(a) * rr
            if _w.road_dist_at(x, z) < 14.0:
                continue
            oasis.append(Vector3(x, _w.height_at(x, z), z))
    _place("PalmeirasOasis", palm, oasis, 1.0, 1.5, Vector2(1.0, 1.2), 0.0, 0.0, 0.2)


# --------------------------------------------------------------------- gelo
func _build_ice() -> void:
    # Igloos.
    var ib := MeshBuilder.new()
    ib.sphere(Vector3(0.0, 0.0, 0.0), Vector3(3.2, 2.6, 3.2), 5, 10, Color(0.94, 0.97, 1.0))
    ib.box(Vector3(0.0, 0.7, 3.0), Vector3(1.0, 0.8, 1.3), Color(0.88, 0.94, 1.0))
    ib.box(Vector3(0.0, 0.55, 4.25), Vector3(0.65, 0.6, 0.06), Color(0.10, 0.16, 0.30))
    _place("Igloos", ib.to_mesh(), _spots(64, 11, 20.0, 40.0), 1.0, 1.5, Vector2(1.0, 1.0), 3.0, 3.0, 0.4)

    # Bonecos de neve.
    var sb := MeshBuilder.new()
    var white := Color(0.97, 0.98, 1.0)
    sb.sphere(Vector3(0.0, 0.9, 0.0), Vector3(1.1, 0.95, 1.1), 4, 8, white)
    sb.sphere(Vector3(0.0, 2.3, 0.0), Vector3(0.8, 0.7, 0.8), 4, 8, white)
    sb.sphere(Vector3(0.0, 3.3, 0.0), Vector3(0.58, 0.55, 0.58), 4, 8, white)
    sb.box(Vector3(0.0, 3.3, 0.62), Vector3(0.07, 0.07, 0.32), Color(1.0, 0.50, 0.10))
    sb.box(Vector3(-0.2, 3.5, 0.5), Vector3(0.06, 0.06, 0.04), Color(0.05, 0.05, 0.07))
    sb.box(Vector3(0.2, 3.5, 0.5), Vector3(0.06, 0.06, 0.04), Color(0.05, 0.05, 0.07))
    sb.cylinder(Vector3(0.0, 3.8, 0.0), 0.5, 0.42, 0.7, 8, Color(0.10, 0.10, 0.14))
    sb.box(Vector3(0.0, 2.7, 0.0), Vector3(0.9, 0.08, 0.9), Color(0.90, 0.15, 0.15))
    _place("Bonecos", sb.to_mesh(), _spots(41, 4, 13.0, 22.0), 1.0, 1.5, Vector2(1.0, 1.0), 1.0, 3.5, 0.1)

    # Pinguins em grupos.
    var pg := MeshBuilder.new()
    var offs: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1.4, 0, 0.7), Vector3(-1.2, 0, 1.0), Vector3(0.4, 0, -1.3)]
    for o in offs:
        pg.sphere(o + Vector3(0.0, 0.7, 0.0), Vector3(0.42, 0.7, 0.36), 4, 8, Color(0.08, 0.09, 0.14))
        pg.sphere(o + Vector3(0.0, 0.62, 0.14), Vector3(0.3, 0.52, 0.22), 4, 8, Color(0.96, 0.97, 1.0))
        pg.sphere(o + Vector3(0.0, 1.5, 0.0), Vector3(0.28, 0.26, 0.28), 4, 8, Color(0.08, 0.09, 0.14))
        pg.box(o + Vector3(0.0, 1.45, 0.3), Vector3(0.1, 0.05, 0.12), Color(1.0, 0.55, 0.10))
        pg.box(o + Vector3(0.0, 0.04, 0.12), Vector3(0.28, 0.04, 0.22), Color(1.0, 0.55, 0.10))
    _place("Pinguins", pg.to_mesh(), _spots(33, 7, 12.0, 20.0), 1.0, 1.4, Vector2(1.0, 1.0), 2.0, 2.0, 0.0)

    # Cristais de gelo gigantes ao longe.
    _place("Cristais", _crystal_cluster(3.0), _spots(50, 15, 40.0, 110.0), 1.0, 2.2, Vector2(0.9, 1.5), 4.0, 14.0, 0.5)

    # Aurora boreal: cortinas translúcidas no céu.
    _make_aurora()

    # Lagos congelados: rachaduras escuras sobre o gelo.
    for lk in _w.track.lakes:
        var mb := MeshBuilder.new()
        for q in 7:
            var a := _rng.randf() * TAU
            var l: float = lk.z * _rng.randf_range(0.6, 1.3)
            var c := Vector3(cos(a), 0.0, sin(a))
            var side := Vector3(-c.z, 0.0, c.x)
            var from := c * lk.z * 0.15
            var to := c * l
            mb.quad(from - side * 0.12, from + side * 0.12, to + side * 0.04, to - side * 0.04, Color(0.50, 0.70, 0.90), Vector3.UP)
        _static_mesh("Rachaduras", mb.to_mesh(), Vector3(lk.x, lk.w + 0.08, lk.y))


func _build_lagoon() -> void:
    # Rochas cobertas de musgo e barcos à deriva nas lagoas.
    var rb := MeshBuilder.new()
    rb.sphere(Vector3(0.0, 0.5, 0.0), Vector3(1.6, 1.0, 1.3), 4, 7, Color(0.52, 0.52, 0.50))
    rb.sphere(Vector3(0.0, 1.0, 0.0), Vector3(1.2, 0.5, 1.0), 3, 6, Color(0.30, 0.64, 0.28))
    _place("RochasMusgo", rb.to_mesh(), _spots(17, 3, 11.0, 30.0), 0.9, 2.0, Vector2(0.8, 1.3), 1.2, 1.4, 0.2)
    for lk in _w.track.lakes:
        var bb := MeshBuilder.new()
        bb.box(Vector3(0.0, 0.3, 0.0), Vector3(1.2, 0.3, 3.0), Color(0.95, 0.95, 0.92))
        bb.box(Vector3(0.0, 0.62, 0.0), Vector3(1.0, 0.04, 2.8), Color(0.85, 0.30, 0.20))
        bb.box(Vector3(0.0, 2.6, 0.0), Vector3(0.06, 2.0, 0.06), Color(0.5, 0.4, 0.3))
        bb.quad(Vector3(0, 4.4, 0), Vector3(0, 4.4, -2.0), Vector3(0, 1.2, -2.0), Vector3(0, 1.2, 0), Color(1.0, 1.0, 0.95), Vector3.RIGHT)
        var a := _rng.randf() * TAU
        var pos := Vector3(lk.x + cos(a) * lk.z * 0.4, lk.w + 0.05, lk.y + sin(a) * lk.z * 0.4)
        var mi := _static_mesh("Barco", bb.to_mesh(), pos)
        mi.rotation.y = _rng.randf() * TAU


func _build_alpine() -> void:
    # Rochas de alta montanha, bandeirolas e esporões de gelo.
    var rb := MeshBuilder.new()
    rb.sphere(Vector3(0.0, 0.8, 0.0), Vector3(2.0, 1.5, 1.8), 4, 7, Color(0.48, 0.48, 0.52))
    rb.sphere(Vector3(0.0, 1.8, 0.0), Vector3(1.2, 0.5, 1.1), 3, 6, Color(0.96, 0.97, 1.0))
    _place("RochasAlpinas", rb.to_mesh(), _spots(11, 2, 12.0, 40.0), 0.9, 2.4, Vector2(0.8, 1.5), 1.6, 2.0, 0.3)
    _place("Cristais", _crystal_cluster(2.0), _spots(60, 20, 40.0, 120.0), 1.0, 2.0, Vector2(0.9, 1.5), 3.0, 10.0, 0.5)


func _build_jungle() -> void:
    # Rochedos cobertos de musgo e cogumelos gigantes (ponto de cor).
    var rb := MeshBuilder.new()
    rb.sphere(Vector3(0.0, 0.7, 0.0), Vector3(1.8, 1.2, 1.5), 4, 7, Color(0.40, 0.40, 0.34))
    rb.sphere(Vector3(0.0, 1.3, 0.0), Vector3(1.4, 0.6, 1.2), 3, 6, Color(0.14, 0.50, 0.20))
    _place("RochasMusgo", rb.to_mesh(), _spots(9, 2, 10.0, 28.0), 0.9, 2.2, Vector2(0.8, 1.4), 1.4, 1.6, 0.2)
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3.ZERO, 0.30, 0.24, 1.6, 6, Color(0.96, 0.92, 0.82))
    mb.sphere(Vector3(0.0, 1.7, 0.0), Vector3(1.3, 0.6, 1.3), 4, 8, Color(0.92, 0.20, 0.22))
    mb.sphere(Vector3(0.5, 2.0, 0.2), Vector3(0.18, 0.1, 0.18), 3, 5, Color(1, 1, 1))
    mb.sphere(Vector3(-0.4, 2.0, -0.4), Vector3(0.18, 0.1, 0.18), 3, 5, Color(1, 1, 1))
    _place("Cogumelos", mb.to_mesh(), _spots(23, 5, 9.0, 22.0), 1.0, 2.2, Vector2(1.0, 1.0), 0.5, 1.6, 0.1)


func _make_aurora() -> void:
    var cx := (_w.min_x + _w.max_x) * 0.5
    var cz := (_w.min_z + _w.max_z) * 0.5
    var rx := (_w.max_x - _w.min_x) * 0.5 + 200.0
    var rz := (_w.max_z - _w.min_z) * 0.5 + 200.0
    var mb := MeshBuilder.new()
    var segs := 56
    var palette: Array[Color] = [Color(0.2, 1.0, 0.6), Color(0.3, 0.9, 0.9), Color(0.6, 0.4, 1.0)]
    for band in 3:
        var phase := float(band) * 1.9
        var a0 := float(band) * 0.9 - 0.4
        for j in segs:
            var t0 := a0 + float(j) / float(segs) * 1.9
            var t1 := a0 + float(j + 1) / float(segs) * 1.9
            var y0 := 190.0 + sin(t0 * 5.0 + phase) * 22.0 + float(band) * 25.0
            var y1 := 190.0 + sin(t1 * 5.0 + phase) * 22.0 + float(band) * 25.0
            var p0 := Vector3(cx + cos(t0 * 2.2) * rx, 0.0, cz - absf(sin(t0 * 2.2)) * rz - 150.0)
            var p1 := Vector3(cx + cos(t1 * 2.2) * rx, 0.0, cz - absf(sin(t1 * 2.2)) * rz - 150.0)
            for l in 4:
                var f0 := float(l) / 4.0
                var f1 := float(l + 1) / 4.0
                var c := palette[band]
                c.a = 0.34 * (1.0 - f0)
                var h0 := 70.0 * f0
                var h1 := 70.0 * f1
                mb.quad(
                    Vector3(p0.x, y0 + h0, p0.z), Vector3(p1.x, y1 + h0, p1.z),
                    Vector3(p1.x, y1 + h1, p1.z), Vector3(p0.x, y0 + h1, p0.z), c, Vector3.UP)
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    var mi := _w._add_mesh(mb.to_mesh(), m)
    mi.name = "Aurora"
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------- vulcão
func _build_lava() -> void:
    # Rochas incandescentes (brilham no escuro) e esporões de obsidiana próximos à pista.
    var rb := MeshBuilder.new()
    rb.sphere(Vector3(0.0, 0.5, 0.0), Vector3(1.4, 0.9, 1.2), 4, 7, Color(0.22, 0.14, 0.13))
    rb.sphere(Vector3(0.0, 0.8, 0.0), Vector3(0.9, 0.5, 0.8), 3, 6, Color(1.0, 0.42, 0.08))
    rb.sphere(Vector3(1.3, 0.35, 0.5), Vector3(0.7, 0.5, 0.6), 3, 6, Color(0.30, 0.18, 0.15))
    _place("RochasBrasa", rb.to_mesh(), _spots(13, 2, 11.0, 26.0), 0.9, 1.9, Vector2(0.8, 1.3), 1.0, 1.2, 0.2)
    _place("Esporoes", _obsidian_spikes(2.2), _spots(34, 6, 24.0, 70.0), 1.0, 2.0, Vector2(0.9, 1.6), 1.6, 6.0, 0.3)

    # Cascatas de lava nos lagos: brilho de luz sobre cada lago.
    for lk in _w.track.lakes:
        var l := OmniLight3D.new()
        l.name = "LuzLava"
        l.light_color = Color(1.0, 0.42, 0.10)
        l.light_energy = 3.0
        l.omni_range = lk.z * 2.4
        l.shadow_enabled = false
        l.position = Vector3(lk.x, lk.w + 5.0, lk.y)
        _w.add_child(l)

    # Vulcão: cratera de lava no maior pico, com luz e coluna de fumaça.
    var tr := _w.track
    if tr.peaks.is_empty():
        return
    var best: Vector4 = tr.peaks[0]
    for pk in tr.peaks:
        if pk.w > best.w:
            best = pk
    var top_y := _w.height_at(best.x, best.y)
    var rad := clampf(best.z * 0.14, 8.0, 18.0)
    var disc := CylinderMesh.new()
    disc.top_radius = rad
    disc.bottom_radius = rad
    disc.height = 0.6
    disc.radial_segments = 24
    var lm := StandardMaterial3D.new()
    lm.albedo_color = Color(1.0, 0.45, 0.06)
    lm.emission_enabled = true
    lm.emission = Color(1.0, 0.34, 0.02)
    lm.emission_energy_multiplier = 2.8
    var cr := _w._add_mesh(disc, lm)
    cr.name = "CrateraLava"
    cr.position = Vector3(best.x, top_y + 0.4, best.y)
    cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var ring := MeshBuilder.new()
    for q in 14:
        var a := float(q) / 14.0 * TAU
        ring.sphere(Vector3(cos(a) * rad * 1.05, 0.9, sin(a) * rad * 1.05), Vector3(3.2, 2.4, 3.2), 3, 6, Color(0.20, 0.12, 0.11))
    _static_mesh("BordaCratera", ring.to_mesh(), Vector3(best.x, top_y, best.y))
    var vl := OmniLight3D.new()
    vl.name = "LuzVulcao"
    vl.light_color = Color(1.0, 0.40, 0.08)
    vl.light_energy = 6.0
    vl.omni_range = 220.0
    vl.position = Vector3(best.x, top_y + 18.0, best.y)
    _w.add_child(vl)

    var sm := MeshBuilder.new()
    for q in 16:
        var f := float(q) / 15.0
        var jitter := Vector3(_rng.randf_range(-6.0, 6.0) + f * 22.0, 0.0, _rng.randf_range(-6.0, 6.0))
        var r := 7.0 + f * 16.0
        var g := 0.26 - f * 0.10
        sm.sphere(jitter + Vector3(0.0, 14.0 + f * 160.0, 0.0), Vector3(r, r * 0.8, r), 4, 8, Color(g + 0.05, g, g))
    _static_mesh("FumacaVulcao", sm.to_mesh(), Vector3(best.x, top_y, best.y), true)


# -------------------------------------------------------------------- clima
# Partículas presas à câmera (neve ou brasas). Devolve o nó para o chamador ajustar se quiser.
static func attach_weather(cam: Node3D, theme: MapTheme) -> CPUParticles3D:
    if theme.weather == "":
        return null
    var p := CPUParticles3D.new()
    p.name = "Clima"
    p.local_coords = false
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    var quad := QuadMesh.new()
    p.direction = Vector3(0.0, -1.0, 0.0)
    p.spread = 12.0
    p.randomness = 1.0
    if theme.weather == "snow":
        p.amount = 420
        p.lifetime = 5.0
        p.emission_box_extents = Vector3(34.0, 1.0, 34.0)
        p.position = Vector3(0.0, 16.0, -8.0)
        p.gravity = Vector3(-1.2, -1.0, 0.0)
        p.initial_velocity_min = 2.0
        p.initial_velocity_max = 5.0
        quad.size = Vector2(0.16, 0.16)
        mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    else:
        p.amount = 200
        p.lifetime = 3.2
        p.emission_box_extents = Vector3(30.0, 1.0, 30.0)
        p.position = Vector3(0.0, -2.0, -6.0)
        p.direction = Vector3(0.0, 1.0, 0.0)
        p.gravity = Vector3(1.5, 3.0, 0.0)
        p.initial_velocity_min = 2.0
        p.initial_velocity_max = 6.0
        quad.size = Vector2(0.12, 0.12)
        mat.albedo_color = Color(1.0, 0.55, 0.15)
        mat.emission_enabled = true
        mat.emission = Color(1.0, 0.45, 0.08)
        mat.emission_energy_multiplier = 2.5
    quad.material = mat
    p.mesh = quad
    cam.add_child(p)
    return p
