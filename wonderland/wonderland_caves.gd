class_name WonderlandCaves
extends RefCounted

# Cavernas de verdade: casco de rocha varrido ao longo do traçado (anéis com ruído, normais para dentro), com colisão,
# estalactites/estalagmites e cristais em MultiMesh, luzes de cristal com fade por distância, rios/lagos/lava e cachoeiras.
# A superfície da montanha (WonderlandTerrain) fica acima, com ≥ 4 m de cobertura (cresce até 50 m).

const RING := 20
const CH := 24            # anéis por bloco de malha
const STEP := 2           # amostras por anel (5 m)

var world: Node3D
var track: TrackData
var terrain: WonderlandTerrain
var layout: Dictionary
var root: Node3D
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var t0 := 1663
var t1 := 4948
var ring_pos := []          # por anel: PackedVector3Array(RING)
var ring_idx := PackedInt32Array()
var sector_of: PackedByteArray
var light_count := 0
var floor_depth := PackedFloat32Array()
var road_mod: WonderlandTrack = null


func build(w: Node3D, tr: TrackData, lay: Dictionary, terr: WonderlandTerrain, sec: PackedByteArray) -> void:
    world = w
    track = tr
    layout = lay
    terrain = terr
    sector_of = sec
    rng.seed = 77123
    noise.seed = 3
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.035
    noise.fractal_octaves = 3
    noise2.seed = 8
    noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise2.frequency = 0.14
    var tn: Vector3i = layout["tunnels"][0]
    t0 = tn.x
    t1 = tn.y
    root = Node3D.new()
    root.name = "Wonderland_Caves"
    world.add_child(root)
    _rings()
    var k := 0
    while k < ring_idx.size() - 1:
        _shell_chunk(k, mini(k + CH, ring_idx.size() - 1))
        k += CH
    _branch_tunnels()
    _decor()
    _liquids()
    _portals()


func floor_for(i: int) -> float:
    var sec := int(sector_of[i])
    var hw := terrain.cave_half[i]
    if sec == 6:
        return 15.0
    if sec == 4 and hw >= 36.0:
        return 15.0
    return 5.0 if hw < 30.0 else 9.0


func _rings() -> void:
    var i := t0
    while i <= t1:
        ring_idx.push_back(i)
        i += STEP
    for r in ring_idx.size():
        var s := ring_idx[r]
        var pr := PackedVector3Array()
        pr.resize(RING)
        var hw := maxf(terrain.cave_half[s], 12.0)
        var hu := maxf(terrain.cave_up[s], 10.0)
        var fd := floor_for(s)
        var mag := track.is_mag(s)
        var rt := track.rights[s]
        var up := track.ups[s]
        var c := track.pts[s]
        floor_depth.push_back(fd)
        for k in RING:
            var ph := TAU * float(k) / float(RING)
            var cx := cos(ph)
            var sy := sin(ph)
            var ax := hw * cx
            var ay := 0.0
            if mag:
                var rad := maxf(hw, hu) * 0.92
                ax = rad * cx
                ay = rad * sy
            else:
                ay = hu * sy if sy > 0.0 else fd * sy
            var base := c + rt * ax + up * ay
            var nz := noise.get_noise_3dv(base) * 0.22 + noise2.get_noise_3dv(base) * 0.07
            var off := Vector3(ax, 0.0, 0.0) * 0.0
            var rr := 1.0 + nz
            # a borda do chão fica reta perto da pista: mantém espaço mínimo de 1.6 m abaixo do asfalto
            var p := c + rt * (ax * rr) + up * (ay * rr)
            if not mag and sy < 0.0:
                var lat := absf(ax * rr)
                if lat < track.half_at(s) + 2.0:
                    p = c + rt * (ax * rr) + up * minf(ay * rr, -fd * 0.85)
            pr[k] = p
        ring_pos.push_back(pr)


func _shell_chunk(a: int, b: int) -> void:
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    var idx := PackedInt32Array()
    var m := b - a + 1
    for r in range(a, b + 1):
        var s := ring_idx[r]
        var sec := int(sector_of[s])
        var base_col := Color(0.55, 0.55, 0.55)
        match sec:
            4: base_col = Color(0.5, 0.7, 0.72)
            5: base_col = Color(0.7, 0.55, 0.85)
            6: base_col = Color(0.95, 0.55, 0.45)
            7: base_col = Color(0.55, 0.65, 0.9)
            8: base_col = Color(0.85, 0.75, 0.65)
        var pr: PackedVector3Array = ring_pos[r]
        for k in RING:
            verts.push_back(pr[k])
            var prev: Vector3 = ring_pos[maxi(r - 1, 0)][k]
            var nxt: Vector3 = ring_pos[mini(r + 1, ring_pos.size() - 1)][k]
            var pk: Vector3 = pr[(k + 1) % RING]
            var pj: Vector3 = pr[(k + RING - 1) % RING]
            var nrm := (nxt - prev).cross(pk - pj).normalized()
            # aponta para dentro (para o eixo da pista)
            var inward := (track.pts[s] - pr[k])
            if nrm.dot(inward) < 0.0:
                nrm = -nrm
            norms.push_back(nrm)
            cols.push_back(base_col)
    for r in m - 1:
        for k in RING:
            var k2 := (k + 1) % RING
            var p00 := r * RING + k
            var p01 := r * RING + k2
            var p10 := (r + 1) * RING + k
            var p11 := (r + 1) * RING + k2
            idx.append_array([p00, p01, p11, p00, p11, p10])
    # sentido dos triângulos: normais para dentro
    var fixed := PackedInt32Array()
    fixed.resize(idx.size())
    for t in range(0, idx.size(), 3):
        var fn := (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])
        if fn.dot(norms[idx[t]]) > 0.0:
            fixed[t] = idx[t]
            fixed[t + 1] = idx[t + 2]
            fixed[t + 2] = idx[t + 1]
        else:
            fixed[t] = idx[t]
            fixed[t + 1] = idx[t + 1]
            fixed[t + 2] = idx[t + 2]
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = verts
    arr[Mesh.ARRAY_NORMAL] = norms
    arr[Mesh.ARRAY_COLOR] = cols
    arr[Mesh.ARRAY_INDEX] = fixed
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var sec0 := int(sector_of[ring_idx[a]])
    var wet := 0.7 if sec0 == 4 else 0.2
    var mi := MeshInstance3D.new()
    mi.mesh = am
    mi.material_override = WonderlandMaterials.rock(Color(0.22, 0.21, 0.22), Color(0.5, 0.46, 0.44), 0.09, wet, 0.7)
    mi.visibility_range_end = 750.0
    mi.visibility_range_end_margin = 50.0
    mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    mi.set_meta("cave_chunk", true)
    root.add_child(mi)
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    var shape := ConcavePolygonShape3D.new()
    shape.backface_collision = true
    var faces := PackedVector3Array()
    for q in fixed:
        faces.push_back(verts[q])
    shape.set_faces(faces)
    var cs := CollisionShape3D.new()
    cs.shape = shape
    body.add_child(cs)
    root.add_child(body)
    # oclusão: cada bloco de caverna é opaco; os blocos vizinhos escondem o resto (visibility range já poda)


# ----------------------------------------------------------------- decoração
func _cone_mesh(r: float, hgt: float, segs: int) -> ArrayMesh:
    var mb := MeshBuilder.new()
    mb.cone(Vector3.ZERO, r, hgt, segs, Color(1, 1, 1))
    return mb.to_mesh()


func _crystal_mesh() -> ArrayMesh:
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3.ZERO, 0.38, 0.32, 2.2, 6, Color(1, 1, 1), false)
    mb.cone(Vector3(0.0, 2.2, 0.0), 0.32, 1.3, 6, Color(1, 1, 1))
    return mb.to_mesh()


func _mm(mesh: Mesh, mat: Material, xforms: Array, colors: Array, parent: Node3D, vis_end: float) -> void:
    if xforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = colors.size() == xforms.size()
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for q in xforms.size():
        mm.set_instance_transform(q, xforms[q])
        if mm.use_colors:
            mm.set_instance_color(q, colors[q])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = mat
    mmi.visibility_range_end = vis_end
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mmi)


func _basis_from_dir(dir: Vector3, spin: float) -> Basis:
    var up := dir.normalized()
    var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
    var x := ref.cross(up).normalized()
    var z := x.cross(up).normalized()
    return Basis(x, up, z).rotated(up, spin)


func _decor() -> void:
    var deco := Node3D.new()
    deco.name = "Decor"
    root.add_child(deco)
    var crystal_mesh := _crystal_mesh()
    var cmat := WonderlandMaterials.crystal(1.9)
    var rock_mat := WonderlandMaterials.rock(Color(0.25, 0.23, 0.22), Color(0.5, 0.46, 0.42), 0.12, 0.3, 0.6)
    var spike_mesh := _cone_mesh(0.9, 5.0, 7)
    var glow_mesh := SphereMesh.new()
    glow_mesh.radius = 0.28
    glow_mesh.height = 0.56
    glow_mesh.radial_segments = 6
    glow_mesh.rings = 3
    var glow_mat := StandardMaterial3D.new()
    glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow_mat.vertex_color_use_as_albedo = true
    var bucket := 0
    var start := 0
    while start < ring_idx.size():
        var end := mini(start + 40, ring_idx.size())
        var spk_x: Array = []
        var cry_x: Array = []
        var cry_c: Array = []
        var orb_x: Array = []
        var orb_c: Array = []
        for r in range(start, end):
            var s := ring_idx[r]
            var sec := int(sector_of[s])
            var pr: PackedVector3Array = ring_pos[r]
            var mag := track.is_mag(s)
            var dens := 2
            match sec:
                4: dens = 3
                5: dens = 2
                6: dens = 2
                7: dens = 1
                8: dens = 1
            for q in dens:
                var k := rng.randi() % RING
                var p := pr[k]
                var inward := (track.pts[s] - p).normalized()
                var ph := TAU * float(k) / float(RING)
                var top := sin(ph) > 0.35
                var bottom := sin(ph) < -0.35
                if top and not mag and rng.randf() < 0.8:
                    var sc := rng.randf_range(0.6, 2.2)
                    var bs := _basis_from_dir(Vector3.DOWN + inward * 0.1, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.6), sc))
                    spk_x.push_back(Transform3D(bs, p))
                elif bottom and not mag and rng.randf() < 0.5:
                    var sc2 := rng.randf_range(0.5, 1.6)
                    var bs2 := _basis_from_dir(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc2, sc2 * rng.randf_range(0.6, 1.3), sc2))
                    spk_x.push_back(Transform3D(bs2, p))
                var cc := Color(0.2, 0.9, 0.85)
                var chance := 0.5
                match sec:
                    4:
                        cc = Color(0.15, 0.95, 0.8) if rng.randf() < 0.7 else Color(0.2, 0.6, 1.0)
                        chance = 0.45
                    5:
                        var rr := rng.randf()
                        cc = Color(1.0, 0.25, 0.9) if rr < 0.4 else (Color(0.45, 0.35, 1.0) if rr < 0.75 else Color(0.2, 0.9, 1.0))
                        chance = 1.0
                    6:
                        cc = Color(1.0, 0.35, 0.1)
                        chance = 0.25
                    7:
                        cc = Color(0.4, 0.9, 1.0) if rng.randf() < 0.7 else Color(0.9, 0.95, 1.0)
                        chance = 0.5
                    8:
                        cc = Color(1.0, 0.8, 0.4)
                        chance = 0.3
                if rng.randf() < chance:
                    var cnt := rng.randi_range(1, 4) if sec == 5 else rng.randi_range(1, 3)
                    for z in cnt:
                        var dir := (inward + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.3, 0.7), rng.randf_range(-0.7, 0.7))).normalized()
                        var sc3 := rng.randf_range(0.8, 2.4) * (1.5 if sec == 5 else 1.0)
                        var bs3 := _basis_from_dir(dir, rng.randf() * TAU).scaled(Vector3(sc3, sc3, sc3))
                        cry_x.push_back(Transform3D(bs3, p + inward * 0.2))
                        cry_c.push_back(cc)
                if sec == 4 and rng.randf() < 0.9:
                    for z in 3:
                        orb_x.push_back(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.6, 1.6)), p + inward * rng.randf_range(2.0, 9.0) + Vector3(0, rng.randf_range(-3, 3), 0)))
                        orb_c.push_back(Color(0.2, 1.0, 0.8).lerp(Color(0.3, 0.6, 1.0), rng.randf()))
        _mm(spike_mesh, rock_mat, spk_x, [], deco, 420.0)
        _mm(crystal_mesh, cmat, cry_x, cry_c, deco, 480.0)
        _mm(glow_mesh, glow_mat, orb_x, orb_c, deco, 260.0)
        start = end
    # luzes de cristal / lava (poucas, com fade por distância)
    var lights := Node3D.new()
    lights.name = "Luzes"
    root.add_child(lights)
    var r2 := 0
    while r2 < ring_idx.size():
        var s2 := ring_idx[r2]
        var sec2 := int(sector_of[s2])
        var lc := Color(0.2, 0.9, 0.85)
        var en := 1.5
        var rg := 30.0
        match sec2:
            4: lc = Color(0.2, 0.9, 0.85)
            5:
                lc = Color(0.9, 0.35, 1.0) if (r2 / 7) % 2 == 0 else Color(0.35, 0.5, 1.0)
                en = 2.4
                rg = 24.0
            6:
                lc = Color(1.0, 0.45, 0.12)
                en = 2.6
                rg = 44.0
            7: lc = Color(0.4, 0.8, 1.0)
            8:
                lc = Color(1.0, 0.8, 0.5)
                en = 1.2
        var L := OmniLight3D.new()
        var up := track.ups[s2]
        var off := -up * (5.0 if sec2 == 6 else -3.0)
        L.position = track.pts[s2] + off + up * 4.0
        L.light_color = lc
        L.light_energy = en
        L.omni_range = rg
        L.omni_attenuation = 1.4
        L.shadow_enabled = false
        L.distance_fade_enabled = true
        L.distance_fade_begin = 90.0
        L.distance_fade_length = 30.0
        L.distance_fade_shadow = 0.0
        lights.add_child(L)
        light_count += 1
        r2 += 6 if sec2 == 5 else 8


# ------------------------------------------------- água, lava e cachoeiras
func _ribbon(a: int, b: int, drop: float, wfrac: float, mat: Material, name_s: String) -> MeshInstance3D:
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var uvs := PackedVector2Array()
    var idx := PackedInt32Array()
    var i := a
    var k := 0
    while i <= b:
        var s := mini(i, track.count - 1)
        var w := maxf(terrain.cave_half[s], 14.0) * wfrac
        var c := track.pts[s] + Vector3(0.0, -drop, 0.0)
        var side := track.sides[s]
        verts.push_back(c - side * w)
        verts.push_back(c + side * w)
        norms.push_back(Vector3.UP)
        norms.push_back(Vector3.UP)
        uvs.push_back(Vector2(0, float(k)))
        uvs.push_back(Vector2(1, float(k)))
        if k > 0:
            var p := (k - 1) * 2
            idx.append_array([p, p + 2, p + 3, p, p + 3, p + 1])
        i += STEP
        k += 1
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = verts
    arr[Mesh.ARRAY_NORMAL] = norms
    arr[Mesh.ARRAY_TEX_UV] = uvs
    arr[Mesh.ARRAY_INDEX] = idx
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var mi := MeshInstance3D.new()
    mi.name = name_s
    mi.mesh = am
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.visibility_range_end = 900.0
    root.add_child(mi)
    return mi


func _liquids() -> void:
    var secs: Array = layout["sectors"]
    var s4: Vector2i = secs[3]
    var s6: Vector2i = secs[5]
    var s5: Vector2i = secs[4]
    # S4: rio/lago subterrâneo bioluminescente (0.9 da meia-largura)
    var water := WonderlandMaterials.water(Color(0.01, 0.12, 0.2), Color(0.05, 0.5, 0.55), Color(0.0, 1.0, 0.8), 0.55, 0.3)
    _ribbon(maxi(s4.x, t0 + 20), s4.y, 7.0, 0.92, water, "Rio_S4")
    # S5: filetes de água fina no chão dos túneis
    var water5 := WonderlandMaterials.water(Color(0.04, 0.05, 0.2), Color(0.2, 0.2, 0.6), Color(0.8, 0.3, 1.0), 0.18, 0.2)
    _ribbon(s5.x, s5.y, 3.8, 0.9, water5, "Agua_S5")
    # S6: rio e lago de lava
    var lava := WonderlandMaterials.lava(Vector2(0, 1), 2.6)
    _ribbon(s6.x, s6.y, 8.5, 0.96, lava, "Lava_S6")
    # S7: poças de energia não existem: nada
    # cachoeiras (S4): folhas verticais do teto ao lago em trechos amplos
    var falls_mat := WonderlandMaterials.falls(Color(0.5, 0.95, 1.0))
    var fi := s4.x + 120
    var made := 0
    while fi < s4.y - 40 and made < 6:
        var s := fi
        var side := track.sides[s]
        var sgn := 1.0 if made % 2 == 0 else -1.0
        var hw := terrain.cave_half[s]
        var top := track.pts[s] + Vector3(0, terrain.cave_up[s] - 2.0, 0) + side * sgn * hw * 0.82
        var bottom := track.pts[s] + Vector3(0, -7.0, 0) + side * sgn * hw * 0.86
        var tang := track.tans[s]
        var qm := MeshBuilder.new()
        qm.quad(bottom - tang * 5.0, bottom + tang * 5.0, top + tang * 5.0, top - tang * 5.0, Color.WHITE, -side * sgn)
        var fm := MeshInstance3D.new()
        fm.mesh = qm.to_mesh()
        fm.material_override = falls_mat
        fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        fm.name = "Cachoeira"
        root.add_child(fm)
        # respingo
        var sp := CPUParticles3D.new()
        sp.position = bottom + Vector3(0, 1.0, 0) - side * sgn * 2.0
        sp.amount = 40
        sp.lifetime = 1.6
        sp.direction = Vector3.UP
        sp.spread = 40.0
        sp.initial_velocity_min = 3.0
        sp.initial_velocity_max = 8.0
        sp.gravity = Vector3(0, -9, 0)
        sp.mesh = SphereMesh.new()
        (sp.mesh as SphereMesh).radius = 0.12
        (sp.mesh as SphereMesh).height = 0.24
        sp.material_override = WonderlandMaterials.glow(Color(0.7, 1.0, 1.0), 1.5)
        sp.visibility_range_end = 220.0
        root.add_child(sp)
        made += 1
        fi += 34 if made < 3 else 20
    # partículas ambientes: vaga-lumes (S4/S5) e brasas (S6)
    for sec in [4, 5, 6, 7]:
        var sv: Vector2i = secs[sec - 1]
        var j := sv.x + 20
        while j < sv.y - 10:
            var pe := CPUParticles3D.new()
            pe.position = track.pts[j] + track.ups[j] * 6.0
            pe.amount = 14
            pe.lifetime = 7.0
            pe.preprocess = 7.0
            pe.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
            pe.emission_box_extents = Vector3(10, 6, 14)
            pe.direction = Vector3.UP
            pe.spread = 180.0
            pe.initial_velocity_min = 0.2
            pe.initial_velocity_max = 1.4 if sec != 6 else 3.5
            pe.gravity = Vector3(0, 0.15 if sec != 6 else 1.2, 0)
            var sm := SphereMesh.new()
            sm.radius = 0.09
            sm.height = 0.18
            sm.radial_segments = 4
            sm.rings = 2
            pe.mesh = sm
            var col := Color(0.4, 1.0, 0.8)
            if sec == 5:
                col = Color(1.0, 0.5, 1.0)
            elif sec == 6:
                col = Color(1.0, 0.5, 0.1)
            elif sec == 7:
                col = Color(0.6, 0.9, 1.0)
            pe.material_override = WonderlandMaterials.glow(col, 3.0)
            pe.visibility_range_end = 120.0
            pe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            root.add_child(pe)
            j += 40


# ----------------------------------------------------------------- portais
func _portal(i: int, flip: bool) -> void:
    var p := track.pts[i]
    var t := track.tans[i]
    var side := track.sides[i]
    var hw := terrain.cave_half[i]
    var hu := terrain.cave_up[i]
    var basis := Basis.looking_at(Vector3(t.x, 0, t.z).normalized(), Vector3.UP)
    var mb := MeshBuilder.new()
    var stone := Color(0.7, 0.66, 0.6)
    for sgn: float in [-1.0, 1.0]:
        mb.box(Vector3(hw * 0.95 * sgn, hu * 0.45, 0.0), Vector3(3.2, hu * 0.55, 3.0), stone)
        mb.box(Vector3(hw * 0.95 * sgn, hu + 3.5, 0.0), Vector3(4.2, 1.6, 3.6), stone * 0.9)
    mb.box(Vector3(0, hu + 5.5, 0), Vector3(hw * 0.95 + 4.0, 2.4, 3.4), stone * 0.95)
    var mi := MeshInstance3D.new()
    mi.mesh = mb.to_mesh()
    mi.material_override = WonderlandMaterials.rock(Color(0.4, 0.38, 0.35), Color(0.7, 0.66, 0.6), 0.25, 0.0, 0.5)
    mi.transform = Transform3D(basis, p)
    mi.name = "Portal"
    root.add_child(mi)
    # runas luminosas
    var rl := OmniLight3D.new()
    rl.position = p + Vector3(0, hu * 0.8, 0)
    rl.light_color = Color(1.0, 0.8, 0.5)
    rl.light_energy = 2.0
    rl.omni_range = 45.0
    rl.shadow_enabled = false
    root.add_child(rl)


func _portals() -> void:
    _portal(t0 + 6, false)
    _portal(t1 - 6, true)


# Túneis dos atalhos (ramais) dentro da montanha: tubo menor com ruído, colisão e luzes próprias.
func _branch_tunnels() -> void:
    for br in track.branches:
        var tun: Vector2i = br["tunnel"]
        if tun.x < 0:
            continue
        var kr := road_mod.branch_clear_range(br)
        tun = Vector2i(maxi(tun.x, kr.x), mini(tun.y, kr.y))
        var bp: PackedVector3Array = br["pts"]
        # O tubo só existe onde o ramal está longe da pista principal (senão a parede invade o asfalto).
        var best_s := -1
        var best_e := -1
        var run_s := -1
        for kk in range(tun.x, tun.y + 2):
            var okk := false
            if kk <= tun.y:
                okk = true
                var lo := int(br["a"]) - 30
                var hi := int(br["c"]) + 30
                for mi2 in range(lo, hi, 2):
                    var mp := track.pts[posmod(mi2, track.count)]
                    if Vector2(mp.x - bp[kk].x, mp.z - bp[kk].z).length() < 24.0:
                        okk = false
                        break
            if okk and run_s < 0:
                run_s = kk
            elif not okk and run_s >= 0:
                if kk - 1 - run_s > best_e - best_s:
                    best_s = run_s
                    best_e = kk - 1
                run_s = -1
        if best_s < 0:
            continue
        tun = Vector2i(best_s, best_e)
        if tun.y - tun.x < 6:
            continue
        var bs: PackedVector3Array = br["sides"]
        var bt: PackedVector3Array = br["tans"]
        var half: float = br["half"]
        var rings := []
        var k := tun.x
        while k <= tun.y:
            var tdir := bt[k]
            var rt := bs[k]
            var up := rt.cross(tdir).normalized()
            if up.y < 0.0:
                up = -up
            var pr := PackedVector3Array()
            pr.resize(RING)
            for q in RING:
                var ph := TAU * float(q) / float(RING)
                var ax := (half + 4.5) * cos(ph)
                var ay := 11.0 * sin(ph) if sin(ph) > 0.0 else 3.0 * sin(ph)
                var base := bp[k] + rt * ax + up * ay
                var rr := 1.0 + noise.get_noise_3dv(base) * 0.2
                pr[q] = bp[k] + rt * ax * rr + up * ay * rr
            rings.push_back(pr)
            k += 2
        var verts := PackedVector3Array()
        var norms := PackedVector3Array()
        var cols := PackedColorArray()
        var idx := PackedInt32Array()
        for r in rings.size():
            var pr2: PackedVector3Array = rings[r]
            for q in RING:
                verts.push_back(pr2[q])
                var prev: Vector3 = rings[maxi(r - 1, 0)][q]
                var nxt: Vector3 = rings[mini(r + 1, rings.size() - 1)][q]
                var n := (nxt - prev).cross(pr2[(q + 1) % RING] - pr2[(q + RING - 1) % RING]).normalized()
                var ctr := bp[tun.x + r * 2]
                if n.dot(ctr - pr2[q]) < 0.0:
                    n = -n
                norms.push_back(n)
                cols.push_back(Color(0.6, 0.55, 0.6))
        for r in rings.size() - 1:
            for q in RING:
                var q2 := (q + 1) % RING
                idx.append_array([r * RING + q, r * RING + q2, (r + 1) * RING + q2, r * RING + q, (r + 1) * RING + q2, (r + 1) * RING + q])
        var fixed := PackedInt32Array()
        fixed.resize(idx.size())
        for t in range(0, idx.size(), 3):
            var fn := (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])
            if fn.dot(norms[idx[t]]) > 0.0:
                fixed[t] = idx[t]
                fixed[t + 1] = idx[t + 2]
                fixed[t + 2] = idx[t + 1]
            else:
                fixed[t] = idx[t]
                fixed[t + 1] = idx[t + 1]
                fixed[t + 2] = idx[t + 2]
        var arr := []
        arr.resize(Mesh.ARRAY_MAX)
        arr[Mesh.ARRAY_VERTEX] = verts
        arr[Mesh.ARRAY_NORMAL] = norms
        arr[Mesh.ARRAY_COLOR] = cols
        arr[Mesh.ARRAY_INDEX] = fixed
        var am := ArrayMesh.new()
        am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
        var mi := MeshInstance3D.new()
        mi.mesh = am
        mi.material_override = WonderlandMaterials.rock(Color(0.22, 0.2, 0.22), Color(0.5, 0.46, 0.44), 0.1, 0.2, 0.5)
        mi.name = "TunelAtalho_%s" % str(br["id"])
        root.add_child(mi)
        var faces := PackedVector3Array()
        for q in fixed:
            faces.push_back(verts[q])
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
        # cristais iluminando o ramal
        for j in range(tun.x, tun.y, 14):
            var L := OmniLight3D.new()
            L.position = bp[j] + Vector3(0, 5, 0)
            L.light_color = Color(1.0, 0.8, 0.3)
            L.light_energy = 1.6
            L.omni_range = 22.0
            L.distance_fade_enabled = true
            L.distance_fade_begin = 80.0
            L.distance_fade_length = 30.0
            root.add_child(L)
