class_name LddWorld
extends Node3D

# Cenário 3D do LDD KART — Lagoa de Dentro: pista de kart, zebras, barreiras, pórtico,
# arquibancadas, palmeiras, igrejinha, lagoa com veleiro, colinas e nuvens.
# Tudo gerado por código (sem arquivos). A pista é uma curva medida em metros (path_*).

const ROAD_W := 16.0
const PATH_LEN := 215
const CAM_D := 150.0

var pts := PackedVector3Array()
var fwds := PackedVector3Array()
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var sun: DirectionalLight3D
var sway: Array[Node3D] = []
var clouds: Array[Node3D] = []
var boat: Node3D
var _vc: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _mats := {}


func build() -> void:
    name = "LddWorld"
    _rng.seed = 4242
    _make_path()
    var side := path_right(CAM_D)
    cam_pos = path_pos(CAM_D) + side * 10.2 + Vector3(0.0, 0.85, 0.0)
    cam_look = path_pos(CAM_D - 45.0) - side * 4.0 + Vector3(0.0, 2.4, 0.0)

    _vc = StandardMaterial3D.new()
    _vc.vertex_color_use_as_albedo = true
    _vc.cull_mode = BaseMaterial3D.CULL_DISABLED
    _vc.roughness = 0.9
    _vc.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON

    _environment()
    _ground()
    _road()
    _barriers()
    _gantry(112.0)
    _grandstands()
    _props()
    _palms()
    _far_scenery()
    _bunting()
    _bushes()
    _sign()
    _clouds()


# --------------------------------------------------------------------- pista
func _make_path() -> void:
    var pos := Vector3.ZERO
    var th := 1.40
    for i in PATH_LEN:
        var d := float(i)
        var k := 0.0
        if d > 25.0 and d < 95.0:
            k = 1.75 / 70.0
        th += k
        var f := Vector3(sin(th), 0.0, -cos(th))
        pts.append(pos)
        fwds.append(f)
        pos += f


func path_pos(d: float) -> Vector3:
    var dd := clampf(d, 0.0, float(PATH_LEN - 2))
    var i := int(dd)
    return pts[i].lerp(pts[i + 1], dd - float(i))


func path_fwd(d: float) -> Vector3:
    var dd := clampf(d, 0.0, float(PATH_LEN - 2))
    var i := int(dd)
    return fwds[i].lerp(fwds[i + 1], dd - float(i)).normalized()


func path_right(d: float) -> Vector3:
    return path_fwd(d).cross(Vector3.UP).normalized()


func dist_to_path(p: Vector3) -> float:
    var best := 1e9
    for i in range(0, PATH_LEN, 2):
        var q := pts[i]
        best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
    return best


# ------------------------------------------------------------------- helpers
func _mat(c: Color, rough: float = 0.8, toon: bool = true) -> StandardMaterial3D:
    var key := "%s_%s_%s" % [c.to_html(), rough, toon]
    if _mats.has(key):
        return _mats[key] as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    if toon:
        m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
        m.specular_mode = BaseMaterial3D.SPECULAR_TOON
    _mats[key] = m
    return m


func _unlit(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.rotation = rot
    mi.scale = scl
    parent.add_child(mi)
    return mi


func _box(size: Vector3) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = size
    return b


func _sphere(r: float, seg: int = 16) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = seg
    s.rings = maxi(seg / 2, 6)
    return s


func _cyl(rt: float, rb: float, h: float, seg: int = 14) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = rt
    c.bottom_radius = rb
    c.height = h
    c.radial_segments = seg
    return c


func _quad_vc(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
    st.set_normal(Vector3.UP)
    st.set_color(col)
    st.add_vertex(a)
    st.set_color(col)
    st.add_vertex(b)
    st.set_color(col)
    st.add_vertex(c)
    st.set_color(col)
    st.add_vertex(a)
    st.set_color(col)
    st.add_vertex(c)
    st.set_color(col)
    st.add_vertex(d)


# Faixa ao longo da pista entre dois deslocamentos laterais, alternando duas cores.
func _strip(off0: float, off1: float, y: float, d0: float, d1: float, seg: float, ca: Color, cb: Color, uv_fn: Callable = Callable()) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var idx := 0
    var d := d0
    while d < d1 - 0.001:
        var e := minf(d + seg, d1)
        var r0 := path_right(d)
        var r1 := path_right(e)
        var a := path_pos(d) + r0 * off0 + Vector3(0.0, y, 0.0)
        var b := path_pos(e) + r1 * off0 + Vector3(0.0, y, 0.0)
        var c := path_pos(e) + r1 * off1 + Vector3(0.0, y, 0.0)
        var dd := path_pos(d) + r0 * off1 + Vector3(0.0, y, 0.0)
        _quad_vc(st, a, b, c, dd, ca if idx % 2 == 0 else cb)
        idx += 1
        d = e
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = _vc
    add_child(mi)


func _multi(mesh: Mesh, mat: Material, xforms: Array[Transform3D], cols: Array[Color] = []) -> void:
    if xforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var use_c := cols.size() == xforms.size()
    mm.use_colors = use_c
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in xforms.size():
        mm.set_instance_transform(i, xforms[i])
        if use_c:
            mm.set_instance_color(i, cols[i])
    var mi := MultiMeshInstance3D.new()
    mi.multimesh = mm
    mi.material_override = mat
    add_child(mi)


func _basis_along(fwd: Vector3) -> Basis:
    return Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP).normalized())


# ------------------------------------------------------------------- ambiente
func _environment() -> void:
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Webcore.soften(Color(0.12, 0.42, 0.95), 0.55, 0.2)
    sky_mat.sky_horizon_color = Webcore.soften(Color(0.72, 0.90, 1.0), 0.55, 0.2)
    sky_mat.ground_horizon_color = Webcore.soften(Color(0.72, 0.90, 1.0), 0.55, 0.2)
    sky_mat.ground_bottom_color = Webcore.soften(Color(0.45, 0.70, 0.40), 0.55, 0.2)
    sky_mat.sun_angle_max = 18.0
    var sky := Sky.new()
    sky.sky_material = sky_mat
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    env.fog_enabled = true
    env.fog_light_color = Webcore.soften(Color(0.72, 0.88, 1.0), 0.55, 0.2)
    env.fog_density = 0.0016
    env.glow_enabled = true
    env.glow_intensity = 0.38
    env.glow_bloom = 0.05
    Webcore.grade(env, 0.74, 1.02)
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42.0, 128.0, 0.0)
    sun.light_energy = 0.95
    sun.light_color = Color(1.0, 0.96, 0.88)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 130.0
    sun.shadow_bias = 0.05
    add_child(sun)


func _ground() -> void:
    var plane := PlaneMesh.new()
    plane.size = Vector2(1400.0, 1400.0)
    var m := _mat(Color(0.30, 0.62, 0.20), 1.0)
    var mi := _add(self, plane, m, Vector3(0.0, 0.0, 0.0))
    mi.position = path_pos(CAM_D - 60.0)
    mi.position.y = 0.0
    # faixa de grama mais clara ao redor da pista (cortada)
    _strip(-ROAD_W * 0.5 - 7.0, ROAD_W * 0.5 + 7.0, 0.015, 0.0, float(PATH_LEN - 3), 6.0, Color(0.34, 0.66, 0.22), Color(0.30, 0.61, 0.20))


func _road() -> void:
    var hw := ROAD_W * 0.5
    _strip(-hw, hw, 0.03, 0.0, float(PATH_LEN - 3), 4.0, Color(0.20, 0.21, 0.26), Color(0.23, 0.24, 0.29))
    # linhas de borda
    _strip(-hw + 0.3, -hw + 0.6, 0.045, 0.0, float(PATH_LEN - 3), 1.0, Color(0.95, 0.95, 0.95), Color(0.95, 0.95, 0.95))
    _strip(hw - 0.6, hw - 0.3, 0.045, 0.0, float(PATH_LEN - 3), 1.0, Color(0.95, 0.95, 0.95), Color(0.95, 0.95, 0.95))
    # tracejado central
    var d := 3.0
    while d < float(PATH_LEN - 8):
        _strip(-0.15, 0.15, 0.045, d, d + 3.0, 3.0, Color(1.0, 0.85, 0.2), Color(1.0, 0.85, 0.2))
        d += 8.0
    # zebras vermelho/branco
    _strip(-hw - 1.4, -hw, 0.06, 0.0, float(PATH_LEN - 3), 3.0, Color(0.92, 0.12, 0.10), Color(0.97, 0.97, 0.97))
    _strip(hw, hw + 1.4, 0.06, 0.0, float(PATH_LEN - 3), 3.0, Color(0.92, 0.12, 0.10), Color(0.97, 0.97, 0.97))
    # linha de largada quadriculada
    for row in 2:
        var d0 := 112.0 + float(row)
        _strip(-hw, hw, 0.05, d0, d0 + 1.0, 1.0, Color.WHITE, Color.WHITE)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var cells := 16
    for row in 2:
        for c in cells:
            if (row + c) % 2 == 0:
                var o0 := -hw + ROAD_W * float(c) / float(cells)
                var o1 := -hw + ROAD_W * float(c + 1) / float(cells)
                var dd0 := 112.0 + float(row)
                var a := path_pos(dd0) + path_right(dd0) * o0 + Vector3(0, 0.055, 0)
                var b := path_pos(dd0 + 1.0) + path_right(dd0 + 1.0) * o0 + Vector3(0, 0.055, 0)
                var cc := path_pos(dd0 + 1.0) + path_right(dd0 + 1.0) * o1 + Vector3(0, 0.055, 0)
                var dq := path_pos(dd0) + path_right(dd0) * o1 + Vector3(0, 0.055, 0)
                _quad_vc(st, a, b, cc, dq, Color(0.05, 0.05, 0.07))
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = _vc
    add_child(mi)


func _barriers() -> void:
    var red: Array[Transform3D] = []
    var white: Array[Transform3D] = []
    var tires: Array[Transform3D] = []
    var off := ROAD_W * 0.5 + 3.4
    var d := 2.0
    var i := 0
    while d < float(PATH_LEN - 6):
        for s in [-1.0, 1.0]:
            if s > 0.0 and d > 136.0 and d < 168.0:
                continue   # espaço para a câmera
            var f := path_fwd(d)
            var p := path_pos(d) + path_right(d) * off * float(s) + Vector3(0.0, 0.5, 0.0)
            var tf := Transform3D(_basis_along(f), p)
            if i % 2 == 0:
                red.append(tf)
            else:
                white.append(tf)
        # pilhas de pneus na parte externa da curva
        if d > 28.0 and d < 94.0 and int(d) % 14 == 0:
            for k in 3:
                tires.append(Transform3D(Basis(), path_pos(d) + path_right(d) * (off + 1.6) + Vector3(0.0, 0.2 + 0.4 * float(k), 0.0)))
        d += 4.0
        i += 1
    var bm := _box(Vector3(3.9, 1.0, 0.7))
    _multi(bm, _mat(Color(0.92, 0.12, 0.10), 0.6), red)
    _multi(bm, _mat(Color(0.97, 0.97, 0.97), 0.6), white)
    _multi(_cyl(0.7, 0.7, 0.42, 14), _mat(Color(0.06, 0.06, 0.08), 0.7), tires)


func _gantry(d: float) -> void:
    var g := Node3D.new()
    add_child(g)
    g.position = path_pos(d)
    g.basis = _basis_along(path_fwd(d)) * Basis(Vector3.UP, -PI * 0.5)
    # (z local do portico aponta ao longo da pista, x atravessa)
    var hw := ROAD_W * 0.5 + 1.2
    for s in [-1.0, 1.0]:
        _add(g, _box(Vector3(1.2, 8.0, 1.2)), _mat(Color(0.12, 0.30, 0.85), 0.5), Vector3(hw * float(s), 4.0, 0.0))
        _add(g, _box(Vector3(1.5, 0.6, 1.5)), _mat(Color(0.95, 0.95, 0.95), 0.5), Vector3(hw * float(s), 0.3, 0.0))
    _add(g, _box(Vector3(hw * 2.0 + 2.4, 2.8, 1.4)), _mat(Color(0.95, 0.95, 0.98), 0.4), Vector3(0.0, 8.4, 0.0))
    _add(g, _box(Vector3(hw * 2.0 + 2.6, 0.5, 1.6)), _mat(Color(0.92, 0.12, 0.10), 0.4), Vector3(0.0, 9.95, 0.0))
    for k in 18:
        if k % 2 == 0:
            _add(g, _box(Vector3(1.2, 0.5, 1.5)), _mat(Color(0.05, 0.05, 0.07), 0.5), Vector3(-hw + 0.7 * float(k), 7.0, 0.0))
    for z in [-0.75, 0.75]:
        var lb := Label3D.new()
        lb.text = "LDD KART"
        lb.font_size = 220
        lb.pixel_size = 0.0155
        lb.modulate = Color(0.10, 0.28, 0.85)
        lb.outline_modulate = Color(0.02, 0.05, 0.25)
        lb.outline_size = 24
        lb.position = Vector3(0.0, 8.6, float(z))
        lb.rotation.y = 0.0 if z > 0.0 else PI
        lb.shaded = false
        g.add_child(lb)


func _grandstands() -> void:
    var seat_cols: Array[Color] = [Color(0.15, 0.40, 0.95), Color(0.97, 0.97, 0.97), Color(0.92, 0.18, 0.15), Color(1.0, 0.80, 0.15)]
    for spec in [[96.0, -1.0, 26.0, 0], [128.0, -1.0, 30.0, 1]]:
        var d: float = spec[0]
        var s: float = spec[1]
        var w: float = spec[2]
        var gs := Node3D.new()
        add_child(gs)
        var p := path_pos(d) + path_right(d) * (ROAD_W * 0.5 + 15.0) * s
        gs.position = p
        var to_track := (path_pos(d) - p)
        to_track.y = 0.0
        gs.basis = Basis.looking_at(-to_track.normalized(), Vector3.UP)   # +Z local aponta para a pista
        var rows := 6
        for r in rows:
            var y := 0.5 + float(r) * 0.95
            var z := -float(r) * 1.7
            _add(gs, _box(Vector3(w, y * 2.0, 1.7)), _mat(Color(0.80, 0.82, 0.88), 0.9), Vector3(0.0, y, z))
            var secs := 8
            for k in secs:
                var c := seat_cols[(k + r + int(spec[3])) % seat_cols.size()]
                _add(gs, _box(Vector3(w / float(secs) - 0.25, 0.35, 1.0)), _mat(c, 0.7), Vector3((float(k) + 0.5) * w / float(secs) - w * 0.5, y * 2.0 + 0.18, z + 0.25))
        # teto
        for sx in [-1.0, 1.0]:
            _add(gs, _cyl(0.18, 0.18, 8.2, 8), _mat(Color(0.9, 0.9, 0.95), 0.5), Vector3((w * 0.5 - 0.4) * float(sx), 4.1, -7.5))
        _add(gs, _box(Vector3(w + 1.0, 0.45, 5.0)), _mat(Color(0.92, 0.14, 0.12), 0.5), Vector3(0.0, 8.4, -6.8), Vector3(deg_to_rad(10.0), 0.0, 0.0))
        _add(gs, _box(Vector3(w + 1.0, 0.18, 5.0)), _mat(Color(1, 1, 1), 0.5), Vector3(0.0, 8.7, -6.8), Vector3(deg_to_rad(10.0), 0.0, 0.0), Vector3(1.0, 1.0, 0.25))


func _props() -> void:
    var cones: Array[Transform3D] = []
    for d in [96.0, 100.0, 104.0, 124.0, 128.0, 132.0, 40.0, 60.0, 80.0]:
        for s in [-1.0, 1.0]:
            var dd: float = d + (3.0 if s > 0.0 else 0.0)
            if s > 0.0 and dd > 136.0 and dd < 168.0:
                continue
            cones.append(Transform3D(Basis(), path_pos(dd) + path_right(dd) * (ROAD_W * 0.5 + 1.0) * float(s) + Vector3(0.0, 0.45, 0.0)))
    _multi(_cyl(0.05, 0.36, 0.9, 10), _mat(Color(1.0, 0.45, 0.05), 0.5), cones)


func _palm(p: Vector3, h: float) -> void:
    var root := Node3D.new()
    root.position = p
    add_child(root)
    var lean := _rng.randf_range(-0.12, 0.12)
    var trunk := _add(root, _cyl(0.26, 0.42, h, 10), _mat(Color(0.62, 0.40, 0.20), 0.9), Vector3(0.0, h * 0.5, 0.0), Vector3(0.0, 0.0, lean))
    trunk.name = "Trunk"
    var crown := Node3D.new()
    crown.position = Vector3(-sin(lean) * h * 0.5 * 1.0, h, 0.0)
    root.add_child(crown)
    sway.append(crown)
    var greens: Array[Color] = [Color(0.12, 0.62, 0.16), Color(0.25, 0.78, 0.18)]
    var n := 8
    for i in n:
        var piv := Node3D.new()
        piv.rotation.y = TAU * float(i) / float(n) + _rng.randf_range(-0.15, 0.15)
        crown.add_child(piv)
        var fr := _add(piv, _sphere(1.0, 10), _mat(greens[i % 2], 0.8), Vector3(2.2, -0.35, 0.0), Vector3(0.0, 0.0, -0.45), Vector3(2.6, 0.12, 0.85))
        fr.name = "Frond"
    for k in 3:
        _add(crown, _sphere(0.28, 8), _mat(Color(0.35, 0.2, 0.08), 0.6), Vector3(0.35 * cos(float(k) * 2.1), -0.3, 0.35 * sin(float(k) * 2.1)))


func _palms() -> void:
    var placed := 0
    var d := 4.0
    while d < float(PATH_LEN - 10):
        for s in [-1.0, 1.0]:
            var lat := (ROAD_W * 0.5 + _rng.randf_range(9.0, 26.0)) * float(s)
            var p := path_pos(d + _rng.randf_range(-3.0, 3.0)) + path_right(d) * lat
            p.y = 0.0
            if dist_to_path(p) < ROAD_W * 0.5 + 8.0:
                continue
            if p.distance_to(Vector3(cam_pos.x, 0.0, cam_pos.z)) < 14.0:
                continue
            _palm(p, _rng.randf_range(8.0, 12.5))
            placed += 1
        d += _rng.randf_range(8.0, 12.0)
    # grupo extra no fundo, atrás da curva
    for i in 16:
        var q := path_pos(40.0) + Vector3(_rng.randf_range(-60.0, 60.0), 0.0, _rng.randf_range(-70.0, -20.0))
        if dist_to_path(q) > 22.0 and q.distance_to(Vector3(cam_pos.x, 0.0, cam_pos.z)) > 30.0:
            _palm(q, _rng.randf_range(9.0, 13.0))


func _church(p: Vector3, yaw: float, s: float) -> void:
    var c := Node3D.new()
    add_child(c)
    c.position = p
    c.rotation.y = yaw
    c.scale = Vector3.ONE * s
    var white := _mat(Color(0.97, 0.96, 0.92), 0.8)
    var blue := _mat(Color(0.20, 0.38, 0.80), 0.6)
    var red := _mat(Color(0.78, 0.22, 0.14), 0.7)
    _add(c, _box(Vector3(14.0, 7.0, 20.0)), white, Vector3(0.0, 3.5, 0.0))
    _add(c, _box(Vector3(14.6, 0.5, 20.6)), blue, Vector3(0.0, 0.25, 0.0))
    _add(c, PrismMesh.new(), red, Vector3(0.0, 8.6, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(14.0, 3.4, 20.6))
    _add(c, _box(Vector3(6.0, 12.0, 6.0)), white, Vector3(-5.0, 6.0, 9.0))
    _add(c, _box(Vector3(6.5, 0.6, 6.5)), blue, Vector3(-5.0, 12.3, 9.0))
    _add(c, _sphere(3.0, 16), blue, Vector3(-5.0, 12.6, 9.0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
    _add(c, _box(Vector3(0.4, 2.4, 0.4)), _mat(Color(1.0, 0.85, 0.3)), Vector3(-5.0, 16.0, 9.0))
    _add(c, _box(Vector3(1.4, 0.4, 0.4)), _mat(Color(1.0, 0.85, 0.3)), Vector3(-5.0, 16.4, 9.0))
    _add(c, _box(Vector3(2.4, 3.4, 0.4)), _mat(Color(0.5, 0.28, 0.12)), Vector3(0.0, 1.7, 10.2))
    for x in [-4.0, 4.0]:
        _add(c, _box(Vector3(1.0, 2.2, 0.4)), blue, Vector3(x, 4.0, 10.2))


func _far_scenery() -> void:
    var cdir := (cam_look - cam_pos)
    cdir.y = 0.0
    cdir = cdir.normalized()
    var cright := cdir.cross(Vector3.UP).normalized()
    var base := cam_pos
    # lagoa
    var lag := _cyl(1.0, 1.0, 0.1, 48)
    var water := StandardMaterial3D.new()
    water.albedo_color = Color(0.10, 0.62, 0.95)
    water.roughness = 0.1
    water.metallic = 0.3
    water.emission_enabled = true
    water.emission = Color(0.05, 0.30, 0.55)
    water.emission_energy_multiplier = 0.6
    var lc := base + cdir * 250.0 + cright * 40.0
    _add(self, lag, _mat(Color(0.96, 0.86, 0.55), 0.95), Vector3(lc.x, 0.02, lc.z), Vector3.ZERO, Vector3(150.0, 1.0, 105.0))
    _add(self, lag, water, Vector3(lc.x, 0.08, lc.z), Vector3.ZERO, Vector3(138.0, 1.0, 95.0))
    # veleiro
    boat = Node3D.new()
    add_child(boat)
    boat.position = lc + cright * 10.0 - cdir * 20.0 + Vector3(0.0, 0.1, 0.0)
    boat.rotation.y = atan2(cdir.x, cdir.z) + 0.4
    _add(boat, _box(Vector3(5.0, 0.9, 1.7)), _mat(Color(0.95, 0.95, 0.98)), Vector3(0.0, 0.6, 0.0))
    _add(boat, _cyl(0.07, 0.07, 9.0, 6), _mat(Color(0.5, 0.35, 0.2)), Vector3(0.0, 5.0, 0.0))
    var sail := _add(boat, PrismMesh.new(), _mat(Color(1.0, 1.0, 1.0), 0.9), Vector3(0.0, 5.4, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(0.12, 7.0, 3.2))
    sail.rotation.y = 0.0
    # colinas ao fundo
    for i in 14:
        var ang := lerpf(-1.2, 1.2, float(i) / 13.0)
        var dir := cdir.rotated(Vector3.UP, ang)
        var pos := base + dir * _rng.randf_range(340.0, 420.0)
        var h := _rng.randf_range(35.0, 70.0)
        var col := Color(0.18, 0.55, 0.22).lerp(Color(0.28, 0.66, 0.30), _rng.randf())
        _add(self, _sphere(1.0, 20), _mat(col, 1.0), Vector3(pos.x, h * 0.15, pos.z), Vector3.ZERO, Vector3(_rng.randf_range(70.0, 110.0), h, _rng.randf_range(60.0, 90.0)))
        for k in 4:
            var hp := pos + Vector3(_rng.randf_range(-35.0, 35.0), 0.0, _rng.randf_range(-20.0, 20.0)) - dir * 25.0
            var hy := h * 0.15 + h * 0.55
            _add(self, _box(Vector3(5.0, 3.2, 4.0)), _mat(Color(0.98, 0.96, 0.92)), Vector3(hp.x, hy, hp.z))
            _add(self, PrismMesh.new(), _mat(Color(0.85, 0.28, 0.16)), Vector3(hp.x, hy + 2.8, hp.z), Vector3.ZERO, Vector3(5.6, 2.2, 4.6))
    # igrejinha na margem
    var cp := base + cdir * 150.0 - cright * 70.0
    cp.y = 0.0
    if dist_to_path(cp) > 40.0:
        _church(cp, atan2(-cdir.x, -cdir.z) + 0.5, 1.5)
    else:
        _church(base + cdir * 190.0 + cright * 110.0, atan2(-cdir.x, -cdir.z) - 0.4, 1.5)


func _bunting() -> void:
    var cols: Array[Color] = [Color(0.92, 0.18, 0.15), Color(1.0, 0.65, 0.1), Color(0.2, 0.55, 1.0), Color(0.2, 0.8, 0.3)]
    var s := -1.0
    var lat := (ROAD_W * 0.5 + 5.6) * s
    var d := 30.0
    var flag_mesh := PrismMesh.new()
    flag_mesh.size = Vector3(0.7, 0.9, 0.05)
    var xf: Array[Transform3D] = []
    var cs: Array[Color] = []
    var vc_m := StandardMaterial3D.new()
    vc_m.vertex_color_use_as_albedo = true
    vc_m.cull_mode = BaseMaterial3D.CULL_DISABLED
    vc_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    while d < 200.0:
        var a := path_pos(d) + path_right(d) * lat + Vector3(0.0, 5.0, 0.0)
        var b := path_pos(d + 24.0) + path_right(d + 24.0) * lat + Vector3(0.0, 5.0, 0.0)
        _add(self, _cyl(0.1, 0.12, 5.0, 6), _mat(Color(0.85, 0.85, 0.9)), a - Vector3(0, 2.5, 0))
        for i in 9:
            var f := (float(i) + 0.5) / 9.0
            var p := a.lerp(b, f)
            p.y -= sin(f * PI) * 1.1
            var fw := (b - a).normalized()
            xf.append(Transform3D(Basis(fw, Vector3.UP, fw.cross(Vector3.UP).normalized()) * Basis(Vector3(1, 0, 0), PI), p - Vector3(0, 0.35, 0)))
            cs.append(cols[i % cols.size()])
        d += 24.0
    _multi(flag_mesh, vc_m, xf, cs)


func _bushes() -> void:
    var cdir := cam_look - cam_pos
    cdir.y = 0.0
    cdir = cdir.normalized()
    var cleft := -cdir.cross(Vector3.UP).normalized()
    var greens: Array[Color] = [Color(0.14, 0.50, 0.16), Color(0.22, 0.62, 0.20), Color(0.10, 0.42, 0.18)]
    var flowers: Array[Color] = [Color(1.0, 0.35, 0.60), Color(1.0, 0.85, 0.15), Color(1.0, 1.0, 1.0), Color(0.75, 0.40, 1.0)]
    var tries := 0
    var placed := 0
    while placed < 38 and tries < 400:
        tries += 1
        var p := cam_pos + cdir * _rng.randf_range(5.0, 75.0) + cleft * _rng.randf_range(2.5, 40.0)
        p.y = 0.0
        if dist_to_path(p) < ROAD_W * 0.5 + 6.0:
            continue
        var r := _rng.randf_range(0.9, 1.9)
        for k in 3:
            var o := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * r
            _add(self, _sphere(1.0, 12), _mat(greens[k % 3], 0.9), p + o + Vector3(0.0, r * 0.55, 0.0), Vector3.ZERO, Vector3(r, r * 0.8, r))
        for k in 6:
            var fo := Vector3(_rng.randf_range(-1.6, 1.6), 0.0, _rng.randf_range(-1.6, 1.6)) * r
            _add(self, _sphere(0.16, 6), _mat(flowers[_rng.randi() % flowers.size()], 0.6), p + fo + Vector3(0.0, r * 0.9 + _rng.randf_range(0.0, 0.4), 0.0))
        placed += 1


func _sign() -> void:
    var d := 84.0
    var s := 1.0
    var p := path_pos(d) + path_right(d) * (ROAD_W * 0.5 + 8.0) * s
    var g := Node3D.new()
    add_child(g)
    g.position = p
    var to_track := path_pos(d) - p
    to_track.y = 0.0
    g.basis = Basis.looking_at(-to_track.normalized(), Vector3.UP)
    for x in [-4.8, 4.8]:
        _add(g, _box(Vector3(0.5, 5.5, 0.5)), _mat(Color(0.5, 0.32, 0.15)), Vector3(x, 2.75, 0.0))
    _add(g, _box(Vector3(11.0, 4.0, 0.5)), _mat(Color(0.12, 0.30, 0.78), 0.5), Vector3(0.0, 5.2, 0.0))
    _add(g, _box(Vector3(11.4, 4.4, 0.4)), _mat(Color(0.95, 0.95, 0.98), 0.5), Vector3(0.0, 5.2, -0.1))
    var lb := Label3D.new()
    lb.text = "LAGOA\nDE DENTRO"
    lb.font_size = 160
    lb.pixel_size = 0.016
    lb.modulate = Color.WHITE
    lb.outline_modulate = Color(0.02, 0.08, 0.30)
    lb.outline_size = 18
    lb.shaded = false
    lb.position = Vector3(0.0, 5.2, 0.3)
    g.add_child(lb)


func _clouds() -> void:
    for i in 16:
        var c := Node3D.new()
        add_child(c)
        c.position = cam_pos + Vector3(_rng.randf_range(-450.0, 450.0), _rng.randf_range(70.0, 140.0), _rng.randf_range(-500.0, 100.0))
        for k in 4:
            _add(c, _sphere(1.0, 12), _unlit(Color(1, 1, 1)), Vector3(float(k) * 9.0 - 14.0, _rng.randf_range(-1.0, 2.0), _rng.randf_range(-2.0, 2.0)), Vector3.ZERO, Vector3(_rng.randf_range(10.0, 16.0), _rng.randf_range(5.0, 8.0), _rng.randf_range(6.0, 9.0)))
        clouds.append(c)


# ------------------------------------------------------------------ animação
func animate(t: float, delta: float) -> void:
    for i in sway.size():
        var n := sway[i]
        n.rotation.z = sin(t * 1.3 + float(i) * 0.7) * 0.035
        n.rotation.x = cos(t * 1.1 + float(i)) * 0.025
    for c in clouds:
        c.position.x += delta * 1.6
    if boat != null:
        boat.position.y = 0.1 + sin(t * 1.2) * 0.06
        boat.rotation.z = sin(t * 0.9) * 0.03
