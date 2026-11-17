class_name WorldBuilder
extends Node3D

# Constrói todo o cenário por código: céu, terreno com morros/montanhas/lago,
# pista com zebras e faixas, barreiras, rampas, pads de nitro, largada,
# arquibancada, árvores, rochas e nuvens. Tudo que o kart pode tocar tem colisão.

const CELL := 8.0
const WATER_LEVEL := 0.0
const CANYON_HEIGHT := 17.0
# O chão fica ABAIXO da pista (com uma valeta suave na beira). A malha do terreno tem células de 8 m e,
# em lombadas, vales e curvas inclinadas, uma célula grossa podia "furar" o asfalto e misturar chão com pista.
const ROAD_SINK := 1.25

var track: TrackData
var theme: MapTheme

var min_x := 0.0
var min_z := 0.0
var max_x := 0.0
var max_z := 0.0
var nx := 0
var nz := 0
var heights := PackedFloat32Array()
var road_dist := PackedFloat32Array()   # distância horizontal até o centro da pista
var _rd2 := PackedFloat32Array()
var _road_y := PackedFloat32Array()
var _road_idx := PackedFloat32Array()
var _far_d2 := PackedFloat32Array()
var _far_y := PackedFloat32Array()
var _canyon_w := PackedFloat32Array()
var _gap_w := PackedFloat32Array()
var _cliff_w := PackedFloat32Array()

var hill_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var canyon_ranges: Array[Vector2i] = []
var wall_side: Array[int] = []


func build(track_data: TrackData, map_theme: MapTheme) -> void:
    track = track_data
    theme = map_theme
    rng.seed = 20261113 + track.map_id.hash() % 1000
    canyon_ranges = track.canyons
    _setup_noise()
    _make_environment()
    await get_tree().process_frame
    _make_terrain()
    await get_tree().process_frame
    _make_road()
    await get_tree().process_frame
    _make_barriers()
    WorldExtras.new().build(self)
    _make_start_area()
    _make_boost_pads()
    _make_ramps()
    _make_obstacles()
    _make_gap_signs()
    _make_cliff_markers()
    await get_tree().process_frame
    _make_trees_and_rocks()
    await get_tree().process_frame
    _make_water_and_clouds()
    await get_tree().process_frame
    ThemeDecor.new().build(self, theme)


# ---------------------------------------------------------------- utilidades
func _setup_noise() -> void:
    hill_noise.seed = 11
    hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    hill_noise.frequency = 0.0042
    hill_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    hill_noise.fractal_octaves = 4
    detail_noise.seed = 23
    detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    detail_noise.frequency = 0.02
    detail_noise.fractal_octaves = 2
    forest_noise.seed = 5
    forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    forest_noise.frequency = 0.012


func _mat_vertex_color(roughness: float = 0.95, unshaded: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.vertex_color_is_srgb = true
    m.roughness = roughness
    m.metallic_specular = 0.15
    if unshaded:
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


func _mat_color(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m


func _add_mesh(mesh: Mesh, material: Material, parent: Node = null) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = material
    if parent == null:
        add_child(mi)
    else:
        parent.add_child(mi)
    return mi


func _add_static(shape: Shape3D, parent: Node, xform: Transform3D = Transform3D.IDENTITY) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    body.transform = xform
    var cs := CollisionShape3D.new()
    cs.shape = shape
    body.add_child(cs)
    parent.add_child(body)
    return body


func height_at(x: float, z: float) -> float:
    var fx := (x - min_x) / CELL
    var fz := (z - min_z) / CELL
    var ix := clampi(int(floor(fx)), 0, nx - 2)
    var iz := clampi(int(floor(fz)), 0, nz - 2)
    var tx := clampf(fx - float(ix), 0.0, 1.0)
    var tz := clampf(fz - float(iz), 0.0, 1.0)
    var h00 := heights[iz * nx + ix]
    var h10 := heights[iz * nx + ix + 1]
    var h01 := heights[(iz + 1) * nx + ix]
    var h11 := heights[(iz + 1) * nx + ix + 1]
    return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


# Piso de referência para câmera / fora-de-pista (mapas em camadas, como o Wonderland, sobrescrevem).
func floor_at(p: Vector3) -> float:
    return height_at(p.x, p.z)


func road_dist_at(x: float, z: float) -> float:
    var ix := clampi(int(round((x - min_x) / CELL)), 0, nx - 1)
    var iz := clampi(int(round((z - min_z) / CELL)), 0, nz - 1)
    return road_dist[iz * nx + ix]


func slope_at(x: float, z: float) -> float:
    var dx := height_at(x + 2.0, z) - height_at(x - 2.0, z)
    var dz := height_at(x, z + 2.0) - height_at(x, z - 2.0)
    return sqrt(dx * dx + dz * dz) / 4.0


func _basis_along(i: int) -> Basis:
    # -Z do objeto aponta no sentido da pista (inclui a inclinação da subida).
    return Basis.looking_at(track.tans[i], Vector3.UP)


# ------------------------------------------------------------------ ambiente
func _make_environment() -> void:
    var env := WorldEnvironment.new()
    env.name = "Ambiente"
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sm := ProceduralSkyMaterial.new()
    sm.sky_top_color = theme.sky_top
    sm.sky_horizon_color = theme.sky_horizon
    sm.ground_horizon_color = theme.ground_horizon
    sm.ground_bottom_color = theme.ground_bottom
    sm.sun_angle_max = 28.0
    sky.sky_material = sm
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = theme.ambient_color
    e.ambient_light_energy = theme.ambient_energy
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.tonemap_exposure = theme.exposure
    e.adjustment_enabled = true
    e.adjustment_saturation = theme.saturation
    e.adjustment_contrast = theme.contrast
    e.fog_enabled = true
    e.fog_light_color = theme.fog_color
    e.fog_density = theme.fog_density
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.name = "Sol"
    sun.rotation_degrees = theme.sun_rotation
    sun.light_color = theme.sun_color
    sun.light_energy = theme.sun_energy
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 110.0
    add_child(sun)


# ------------------------------------------------------------------- terreno
func _canyon_mask(idx: float) -> float:
    var m := 0.0
    for r in canyon_ranges:
        var a := float(r.x)
        var b := float(r.y)
        m = maxf(m, smoothstep(a, a + 30.0, idx) * (1.0 - smoothstep(b - 30.0, b, idx)))
    return m


func _gap_mask(idx: float) -> float:
    var m := 0.0
    for g in track.gaps:
        var a := g.x
        var b := g.x + g.y
        m = maxf(m, smoothstep(a - 1.5, a + 0.5, idx) * (1.0 - smoothstep(b - 0.5, b + 1.5, idx)))
    return m


func _cliff_mask(idx: float) -> float:
    var m := 0.0
    for r in track.cliffs:
        var a := float(r.x)
        var b := float(r.y)
        m = maxf(m, smoothstep(a, a + 12.0, idx) * (1.0 - smoothstep(b - 12.0, b, idx)))
    return m


func _bridge_mask(idx: float) -> float:
    var m := 0.0
    for r in track.bridges:
        var a := float(r.x)
        var b := float(r.y)
        m = maxf(m, smoothstep(a - 6.0, a + 6.0, idx) * (1.0 - smoothstep(b - 6.0, b + 6.0, idx)))
    return m


# Há um morro de túnel (ou caverna) por cima deste ponto do mapa?
func tunnel_hill_at(x: float, z: float, margin: float = 70.0) -> bool:
    var ix := clampi(int(round((x - min_x) / CELL)), 0, nx - 1)
    var iz := clampi(int(round((z - min_z) / CELL)), 0, nz - 1)
    var k := iz * nx + ix
    if road_dist[k] > margin:
        return false
    var idx := _road_idx[k]
    if idx >= 0.0:
        return track.tunnel_kind(int(idx)) >= 0
    var bid := int(floor(-idx / 10000.0)) - 1
    var local := int(-idx - float(bid + 1) * 10000.0)
    if bid < 0 or bid >= track.branches.size():
        return false
    var tun: Vector2i = track.branches[bid]["tunnel"]
    return tun.x >= 0 and local >= tun.x and local <= tun.y


# Montanhas / vulcão: soma ao relevo livre (a pista continua com a própria altura).
func _peak_bump(x: float, z: float) -> float:
    var total := 0.0
    for q in track.peaks.size():
        var pk: Vector4 = track.peaks[q]
        var d := Vector2(x, z).distance_to(Vector2(pk.x, pk.y))
        if d >= pk.z:
            continue
        var t := 1.0 - d / pk.z
        var h := pk.w * pow(t, 1.35)
        var crater := track.craters[q] if q < track.craters.size() else 0.0
        if crater > 0.0:
            h -= crater * (1.0 - smoothstep(0.0, pk.z * 0.16, d))
        total += h
    return total


func _near_lake(x: float, z: float, factor: float = 1.15) -> bool:
    for lk in track.lakes:
        if Vector2(x, z).distance_to(Vector2(lk.x, lk.y)) < lk.z * factor:
            return true
    return false


func _make_terrain() -> void:
    var lo := Vector2(INF, INF)
    var hi := Vector2(-INF, -INF)
    for p in track.pts:
        lo.x = minf(lo.x, p.x)
        lo.y = minf(lo.y, p.z)
        hi.x = maxf(hi.x, p.x)
        hi.y = maxf(hi.y, p.z)
    var margin := 210.0 if track.map_id == "aventura" else 190.0
    min_x = floorf((lo.x - margin) / CELL) * CELL
    min_z = floorf((lo.y - margin) / CELL) * CELL
    nx = int((hi.x + margin - min_x) / CELL) + 1
    nz = int((hi.y + margin - min_z) / CELL) + 1
    max_x = min_x + float(nx - 1) * CELL
    max_z = min_z + float(nz - 1) * CELL
    var total := nx * nz

    heights.resize(total)
    road_dist.resize(total)
    _rd2.resize(total)
    _road_y.resize(total)
    _road_idx.resize(total)
    _far_d2.resize(total)
    _far_y.resize(total)
    _canyon_w.resize(total)
    _gap_w.resize(total)
    _cliff_w.resize(total)
    _rd2.fill(1.0e12)
    _far_d2.fill(1.0e12)
    _road_y.fill(0.0)
    _road_idx.fill(0.0)
    _far_y.fill(0.0)
    _canyon_w.fill(0.0)
    _gap_w.fill(0.0)
    _cliff_w.fill(0.0)

    # Passo A: para cada segmento da pista, atualiza os vértices vizinhos
    # (distância exata ao eixo, altura e posição ao longo da pista).
    var ra := 46.0
    var n := track.count
    for i in n:
        var a := track.pts[i]
        var b := track.pts[(i + 1) % n]
        var ix0 := maxi(0, int(floor((minf(a.x, b.x) - ra - min_x) / CELL)))
        var ix1 := mini(nx - 1, int(ceil((maxf(a.x, b.x) + ra - min_x) / CELL)))
        var iz0 := maxi(0, int(floor((minf(a.z, b.z) - ra - min_z) / CELL)))
        var iz1 := mini(nz - 1, int(ceil((maxf(a.z, b.z) + ra - min_z) / CELL)))
        var abx := b.x - a.x
        var abz := b.z - a.z
        var ab2 := maxf(abx * abx + abz * abz, 0.0001)
        for iz in range(iz0, iz1 + 1):
            var pz := min_z + float(iz) * CELL
            for ix in range(ix0, ix1 + 1):
                var px := min_x + float(ix) * CELL
                var t := clampf(((px - a.x) * abx + (pz - a.z) * abz) / ab2, 0.0, 1.0)
                var dx := px - (a.x + abx * t)
                var dz := pz - (a.z + abz * t)
                var d2 := dx * dx + dz * dz
                var k := iz * nx + ix
                if d2 < _rd2[k]:
                    _rd2[k] = d2
                    var lat := dx * track.sides[i].x + dz * track.sides[i].z
                    var bank := lerpf(track.banks[i], track.banks[(i + 1) % n], t)
                    _road_y[k] = lerpf(a.y, b.y, t) + clampf(lat, -8.5, 8.5) * bank
                    _road_idx[k] = float(i) + t

    # Atalhos entram no mesmo mapa de distâncias (índice negativo = atalho).
    for br in track.branches:
        var bp: PackedVector3Array = br["pts"]
        var m: int = br["count"]
        var tag := -(float(int(br["id"]) + 1) * 10000.0)
        for i in range(m - 1):
            var a := bp[i]
            var b := bp[i + 1]
            var ix0 := maxi(0, int(floor((minf(a.x, b.x) - ra - min_x) / CELL)))
            var ix1 := mini(nx - 1, int(ceil((maxf(a.x, b.x) + ra - min_x) / CELL)))
            var iz0 := maxi(0, int(floor((minf(a.z, b.z) - ra - min_z) / CELL)))
            var iz1 := mini(nz - 1, int(ceil((maxf(a.z, b.z) + ra - min_z) / CELL)))
            var abx := b.x - a.x
            var abz := b.z - a.z
            var ab2 := maxf(abx * abx + abz * abz, 0.0001)
            for iz in range(iz0, iz1 + 1):
                var pz := min_z + float(iz) * CELL
                for ix in range(ix0, ix1 + 1):
                    var px := min_x + float(ix) * CELL
                    var t := clampf(((px - a.x) * abx + (pz - a.z) * abz) / ab2, 0.0, 1.0)
                    var dx := px - (a.x + abx * t)
                    var dz := pz - (a.z + abz * t)
                    var d2 := dx * dx + dz * dz
                    var k := iz * nx + ix
                    if d2 < _rd2[k] - 0.5:
                        _rd2[k] = d2
                        _road_y[k] = lerpf(a.y, b.y, t)
                        _road_idx[k] = tag - (float(i) + t)

    # Passo B: influência distante da altura da pista (morros acompanham a subida).
    var rb := 135.0
    for i in range(0, n, 6):
        var a := track.pts[i]
        var ix0 := maxi(0, int(floor((a.x - rb - min_x) / CELL)))
        var ix1 := mini(nx - 1, int(ceil((a.x + rb - min_x) / CELL)))
        var iz0 := maxi(0, int(floor((a.z - rb - min_z) / CELL)))
        var iz1 := mini(nz - 1, int(ceil((a.z + rb - min_z) / CELL)))
        for iz in range(iz0, iz1 + 1):
            var pz := min_z + float(iz) * CELL
            for ix in range(ix0, ix1 + 1):
                var px := min_x + float(ix) * CELL
                var d2 := (px - a.x) * (px - a.x) + (pz - a.z) * (pz - a.z)
                var k := iz * nx + ix
                if d2 < _far_d2[k]:
                    _far_d2[k] = d2
                    _far_y[k] = a.y

    # Alturas finais.
    var lake_floor := WATER_LEVEL - 7.0
    for iz in nz:
        var z := min_z + float(iz) * CELL
        for ix in nx:
            var x := min_x + float(ix) * CELL
            var k := iz * nx + ix
            var d := sqrt(_rd2[k])
            road_dist[k] = d
            var fd := sqrt(_far_d2[k])
            var n1 := hill_noise.get_noise_2d(x, z)
            var n2 := detail_noise.get_noise_2d(x, z)
            var near_amp := lerpf(0.28, 1.0, smoothstep(30.0, 110.0, fd))
            var hills := 0.0
            if theme.dunes:
                var dn := absf(hill_noise.get_noise_2d(x * 1.6, z * 1.6))
                hills = ((1.0 - dn) * (1.0 - dn) * theme.hill_amp * 1.6 + theme.hill_base + n2 * 1.6) * near_amp
            else:
                hills = (n1 * theme.hill_amp + theme.hill_base + n2 * 2.5) * near_amp
            var infl := 1.0 - smoothstep(25.0, 135.0, fd)
            var free_h := hills + _far_y[k] * infl
            var edge := minf(minf(x - min_x, max_x - x), minf(z - min_z, max_z - z))
            var mt := smoothstep(0.0, 1.0, clampf(1.0 - edge / 115.0, 0.0, 1.0))
            var ridge := 0.5 + 0.5 * detail_noise.get_noise_2d(x * 2.2 + 300.0, z * 2.2)
            free_h += mt * (theme.edge_height + theme.edge_ridge * ridge)
            free_h += _peak_bump(x, z)

            var blend := smoothstep(9.2, 42.0, d)
            # Sob a pista (e um pouco além da borda) o chão afunda; depois sobe suavemente até o nível normal.
            var sink := ROAD_SINK * (1.0 - smoothstep(8.6, 16.0, d))
            var h := lerpf(_road_y[k] - 0.15 - sink, free_h, blend)

            if d < 58.0:
                var cm := _canyon_mask(_road_idx[k])
                if cm > 0.0:
                    # As paredes só começam depois de ~18 m do eixo: com células de 8 m, uma parede mais perto
                    # "cortava" a pista na interpolação da malha (chão entrando no asfalto).
                    var w := smoothstep(18.5, 27.0, d) * (1.0 - smoothstep(38.0, 54.0, d))
                    h += CANYON_HEIGHT * w * cm
                    _canyon_w[k] = w * cm

            # Penhasco: o terreno despenca ao lado da pista (sem proteção!).
            if d < 125.0 and not track.cliffs.is_empty():
                var clm := _cliff_mask(_road_idx[k])
                if clm > 0.0:
                    var cw := smoothstep(9.4, 12.5, d) * (1.0 - smoothstep(60.0, 125.0, d)) * clm
                    h = lerpf(h, minf(h, _road_y[k] - 46.0), cw)
                    _cliff_w[k] = cw

            # Ponte: o terreno some de baixo do tabuleiro (lagoa, abismo).
            if d < 125.0 and not track.bridges.is_empty() and _road_idx[k] >= 0.0:
                var brm := _bridge_mask(_road_idx[k])
                if brm > 0.0:
                    var brw := (1.0 - smoothstep(60.0, 125.0, d)) * brm
                    h = lerpf(h, minf(h, _road_y[k] - 46.0), brw)
                    _cliff_w[k] = maxf(_cliff_w[k], smoothstep(9.0, 12.5, d) * brw)

            if d < 30.0 and not track.gaps.is_empty():
                var gm := _gap_mask(_road_idx[k]) * (1.0 - smoothstep(9.5, 15.0, d))
                if gm > 0.0:
                    h = lerpf(h, _road_y[k] - 22.0, gm)
                    _gap_w[k] = gm

            var bw := 0.0
            var lake_level := WATER_LEVEL
            for lk in track.lakes:
                var ld := Vector2(x, z).distance_to(Vector2(lk.x, lk.y))
                var lw := 1.0 - smoothstep(lk.z * 0.436, lk.z, ld)
                if lw > bw:
                    bw = lw
                    lake_level = lk.w
            h = lerpf(h, lake_level - 7.0, bw * blend)
            heights[k] = h

    # Normais, cores e malha.
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    var indices := PackedInt32Array()
    verts.resize(total)
    norms.resize(total)
    cols.resize(total)
    for iz in nz:
        var z := min_z + float(iz) * CELL
        for ix in nx:
            var x := min_x + float(ix) * CELL
            var k := iz * nx + ix
            var hl := heights[iz * nx + maxi(ix - 1, 0)]
            var hr := heights[iz * nx + mini(ix + 1, nx - 1)]
            var hd := heights[maxi(iz - 1, 0) * nx + ix]
            var hu := heights[mini(iz + 1, nz - 1) * nx + ix]
            var nrm := Vector3((hl - hr) / (2.0 * CELL), 1.0, (hd - hu) / (2.0 * CELL)).normalized()
            verts[k] = Vector3(x, heights[k], z)
            norms[k] = nrm
            cols[k] = _terrain_color(x, z, heights[k], nrm.y, road_dist[k], _canyon_w[k], _gap_w[k], _cliff_w[k])

    for iz in range(nz - 1):
        for ix in range(nx - 1):
            var v00 := iz * nx + ix
            var v10 := v00 + 1
            var v01 := v00 + nx
            var v11 := v01 + 1
            if (ix + iz) % 2 == 0:
                indices.append_array(PackedInt32Array([v00, v10, v01, v10, v11, v01]))
            else:
                indices.append_array(PackedInt32Array([v00, v10, v11, v00, v11, v01]))

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_COLOR] = cols
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    var mi := _add_mesh(mesh, _mat_vertex_color(1.0))
    mi.name = "Terreno"
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var shape := mesh.create_trimesh_shape()
    shape.backface_collision = true
    var body := _add_static(shape, self)
    body.name = "ColisaoTerreno"


func _terrain_color(x: float, z: float, h: float, ny: float, d: float, canyon_w: float, gap_w: float, cliff_w: float) -> Color:
    var stripe := 1.0 if (int(floor(x / 14.0)) + int(floor(z / 14.0))) % 2 == 0 else 0.0
    var gv := 0.5 + 0.5 * forest_noise.get_noise_2d(x * 1.7, z * 1.7)
    var col := theme.ground_a.lerp(theme.ground_b, clampf(gv * 0.65 + stripe * theme.stripe_amount, 0.0, 1.0))
    if theme.style == "ice":
        # Placas de gelo azulado no meio da neve
        var ice := smoothstep(0.05, 0.45, forest_noise.get_noise_2d(x * 0.9 + 70.0, z * 0.9))
        col = col.lerp(Color(0.66, 0.85, 0.98), ice * 0.7)
    elif theme.style == "desert":
        # Ondulações das dunas
        var ripple := 0.5 + 0.5 * sin((x * 0.6 + z * 0.35) * 0.22 + gv * 5.0)
        col = col.lerp(Color(0.80, 0.60, 0.34), ripple * 0.22)
    elif theme.style == "jungle":
        var moss := smoothstep(-0.1, 0.5, forest_noise.get_noise_2d(x * 0.6 + 30.0, z * 0.6))
        col = col.lerp(Color(0.06, 0.36, 0.14), moss * 0.45)
    elif theme.style == "alpine":
        var meadow := smoothstep(0.1, 0.6, forest_noise.get_noise_2d(x * 0.5, z * 0.5 + 11.0))
        col = col.lerp(Color(0.62, 0.70, 0.46), meadow * 0.35)
        col = col.lerp(theme.rock_color, smoothstep(30.0, 55.0, h) * 0.5)
    # Beira do lago (areia, margem verde, obsidiana...)
    for lk in track.lakes:
        if Vector2(x, z).distance_to(Vector2(lk.x, lk.y)) < lk.z * 1.4:
            col = col.lerp(theme.shore_color, smoothstep(lk.w + 1.1, lk.w + 0.1, h))
    # Encostas rochosas
    col = col.lerp(theme.rock_color, smoothstep(0.86, 0.68, ny))
    # Neve / cinzas nos picos
    col = col.lerp(theme.peak_color, smoothstep(theme.peak_from, theme.peak_to, h) * smoothstep(0.55, 0.85, ny))
    if theme.style == "lava":
        # Veios de lava incandescente no chão
        var vein := absf(detail_noise.get_noise_2d(x * 1.3 + 90.0, z * 1.3))
        if vein < 0.05 and ny > 0.55 and d > 15.0:
            col = col.lerp(Color(1.0, 0.46, 0.08), smoothstep(0.05, 0.0, vein) * 0.95)
    # Arenito / gelo azul do desfiladeiro, com camadas
    if canyon_w > 0.01:
        var strata := 0.5 + 0.5 * sin(h * 2.3)
        var sand := theme.canyon_a.lerp(theme.canyon_b, strata * 0.6)
        col = col.lerp(sand, clampf(canyon_w * 1.6, 0.0, 1.0))
    # Parede do penhasco
    if cliff_w > 0.01:
        var layer := 0.5 + 0.5 * sin(h * 1.7)
        var wall := theme.rock_color.darkened(0.15).lerp(theme.canyon_b, layer * 0.4)
        col = col.lerp(wall, clampf(cliff_w * 1.8, 0.0, 1.0))
    # Fundo escuro do abismo (lava brilhante no vulcão)
    if gap_w > 0.01:
        col = col.lerp(theme.gap_color, clampf(gap_w * 1.5, 0.0, 1.0))
    # Beira da pista levemente mais clara
    if d < 12.0:
        col = col.lerp(theme.trim_color, smoothstep(12.0, 9.0, d) * 0.45)
    return col


# --------------------------------------------------------------------- pista
func _road_strip_color(i: int, k: int) -> Color:
    var asphalt := theme.asphalt_a
    if (i / 6) % 2 == 1:
        asphalt = theme.asphalt_b
    if k == 0 or k == 6:
        return theme.curb_a if (i / 2) % 2 == 0 else theme.curb_b
    if k == 1 or k == 5:
        return theme.line_color
    if k == 3:
        return theme.line_color if (i % 8) < 4 else asphalt
    return asphalt


func _make_road() -> void:
    var mb := MeshBuilder.new()
    var cb := MeshBuilder.new()
    var n := track.count
    var lat: Array[float] = [-8.0, -6.9, -6.5, -0.15, 0.15, 6.5, 6.9, 8.0]
    var skirt := Color(0.55, 0.55, 0.58)
    for i in n:
        var j := (i + 1) % n
        var s0 := track.sides[i]
        var s1 := track.sides[j]
        if track.in_gap(i):
            continue
        # Bordas verticais nas pontas do abismo (fim da pista e retomada)
        var lip_down := Vector3(0.0, -2.5, 0.0)
        if track.in_gap(j):
            mb.quad(track.at(j, -8.0), track.at(j, 8.0), track.at(j, 8.0) + lip_down, track.at(j, -8.0) + lip_down, skirt, track.tans[i])
        if track.in_gap(posmod(i - 1, n)):
            mb.quad(track.at(i, -8.0), track.at(i, 8.0), track.at(i, 8.0) + lip_down, track.at(i, -8.0) + lip_down, skirt, -track.tans[i])
        var dark := 0.58 if track.tunnel_kind(i) >= 0 else 1.0
        for k in 7:
            var c := _road_strip_color(i, k)
            if dark < 1.0:
                c = c.darkened(1.0 - dark)
            var la := lat[k]
            var lb := lat[k + 1]
            mb.quad(track.at(i, la), track.at(i, lb), track.at(j, lb), track.at(j, la), c, Vector3.UP)
        # Laterais (fecham o vão entre pista e terreno)
        var down := Vector3(0.0, -1.6, 0.0)   # saia mais alta: esconde a valeta e fecha o vão sob a pista
        mb.quad(track.at(i, -8.0), track.at(j, -8.0), track.at(j, -8.0) + down, track.at(i, -8.0) + down, skirt, -s0)
        mb.quad(track.at(i, 8.0), track.at(j, 8.0), track.at(j, 8.0) + down, track.at(i, 8.0) + down, skirt, s0)
        # Colisão: faixa contínua e lisa (evita "degraus" entre peças)
        cb.quad(track.at(i, -8.4), track.at(i, 8.4), track.at(j, 8.4), track.at(j, -8.4), Color.WHITE, Vector3.UP)

    var road := _add_mesh(mb.to_mesh(), _mat_vertex_color(0.95))
    road.name = "Pista"
    road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var body := _add_static(cb.to_collision(), self)
    body.name = "ColisaoPista"


func _make_barriers() -> void:
    var n := track.count
    var span := 8
    var raw: Array[int] = []
    raw.resize(n)
    raw.fill(0)
    var tight: Array[bool] = []
    tight.resize(n)
    tight.fill(false)
    for i in n:
        var j := (i + span) % n
        var cy := track.tans[i].x * track.tans[j].z - track.tans[i].z * track.tans[j].x
        var ang := asin(clampf(absf(cy), 0.0, 1.0))
        if ang > 0.30:
            raw[i] = -1 if cy > 0.0 else 1   # parede no lado de fora da curva
            if ang > 0.50:
                tight[i] = true
    wall_side.resize(n)
    wall_side.fill(0)
    for i in n:
        if track.in_gap(i) or track.in_gap(posmod(i + 10, n)) or track.in_gap(posmod(i - 10, n)) or track.in_cliff(i) or track.in_cliff(posmod(i + 10, n)) or track.in_cliff(posmod(i - 10, n)) or track.tunnel_kind(i) >= 0 or track.bridge_kind(i) >= 0:
            raw[i] = 0
            tight[i] = false
    for i in n:
        if raw[i] != 0:
            for o in range(-6, span + 7):
                var kk := posmod(i + o, n)
                if wall_side[kk] == 0:
                    wall_side[kk] = raw[i]

    var mb := MeshBuilder.new()
    var inner := 9.05
    var outer := 9.55
    var low := Vector3(0.0, -0.45, 0.0)
    var high := Vector3(0.0, 1.15, 0.0)
    for i in n:
        var s := wall_side[i]
        var j := (i + 1) % n
        if s == 0 or wall_side[j] != s:
            continue
        var sf := float(s)
        var s0 := track.sides[i]
        var c := theme.barrier_a if (i / 2) % 2 == 0 else theme.barrier_b
        var ib0 := track.at(i, sf * inner)
        var ib1 := track.at(j, sf * inner)
        var ob0 := track.at(i, sf * outer)
        var ob1 := track.at(j, sf * outer)
        mb.quad(ib0 + low, ib1 + low, ib1 + high, ib0 + high, c, -s0 * sf)
        mb.quad(ob0 + low, ob1 + low, ob1 + high, ob0 + high, c, s0 * sf)
        mb.quad(ib0 + high, ib1 + high, ob1 + high, ob0 + high, c.lightened(0.15), Vector3.UP)
    if not mb.is_empty():
        var walls := _add_mesh(mb.to_mesh(), _mat_vertex_color(0.7))
        walls.name = "Barreiras"
        var body := _add_static(mb.to_collision(), self)
        body.name = "ColisaoBarreiras"

    # Placas de curva (chevrons) nos trechos mais fechados.
    var sign_mesh := BoxMesh.new()
    sign_mesh.size = Vector3(3.4, 1.7, 0.12)
    var sign_mat := _mat_color(theme.sign_color, 0.6)
    var post_mesh := BoxMesh.new()
    post_mesh.size = Vector3(0.18, 3.0, 0.18)
    var post_mat := _mat_color(Color(0.35, 0.37, 0.42), 0.8)
    for i in range(0, n, 7):
        if not tight[i] or wall_side[i] == 0:
            continue
        var s := wall_side[i]
        var sf := float(s)
        var jj := (i + span) % n
        var cy := track.tans[i].x * track.tans[jj].z - track.tans[i].z * track.tans[jj].x
        var base := track.at(i, sf * 9.8)
        var outward := track.sides[i] * sf
        var b := Basis.looking_at(outward, Vector3.UP)
        var holder := Node3D.new()
        holder.transform = Transform3D(b, base + Vector3(0.0, 2.9, 0.0))
        add_child(holder)
        var panel := MeshInstance3D.new()
        panel.mesh = sign_mesh
        panel.material_override = sign_mat
        holder.add_child(panel)
        var post := MeshInstance3D.new()
        post.mesh = post_mesh
        post.material_override = post_mat
        post.position = Vector3(0.0, -2.0, 0.0)
        holder.add_child(post)
        var lab := Label3D.new()
        lab.text = ">>>" if cy > 0.0 else "<<<"
        lab.font_size = 110
        lab.pixel_size = 0.0085
        lab.modulate = Color(0.08, 0.08, 0.10)
        lab.outline_size = 0
        lab.position = Vector3(0.0, 0.0, 0.08)
        holder.add_child(lab)


# --------------------------------------------------------- largada/arquibancada
func _make_start_area() -> void:
    var i0 := 0
    var origin := track.pts[i0]
    var b := _basis_along(i0)
    var root := Node3D.new()
    root.name = "Largada"
    root.transform = Transform3D(b, origin)
    add_child(root)

    # Linha quadriculada no asfalto
    var cb := MeshBuilder.new()
    var cols := 14
    var cw := 13.0 / float(cols)
    for r in 2:
        for c in cols:
            var col := Color(0.96, 0.96, 0.94) if (r + c) % 2 == 0 else Color(0.08, 0.08, 0.10)
            var x0 := -6.5 + float(c) * cw
            var z0 := -0.7 + float(r) * 0.7
            cb.quad(Vector3(x0, 0.05, z0), Vector3(x0 + cw, 0.05, z0), Vector3(x0 + cw, 0.05, z0 + 0.7), Vector3(x0, 0.05, z0 + 0.7), col, Vector3.UP)
    _add_mesh(cb.to_mesh(), _mat_vertex_color(0.8), root).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    # Pórtico
    var gb := MeshBuilder.new()
    var post_col := Color(0.15, 0.20, 0.45)
    gb.box(Vector3(-9.8, 4.2, 0.0), Vector3(0.45, 4.2, 0.45), post_col)
    gb.box(Vector3(9.8, 4.2, 0.0), Vector3(0.45, 4.2, 0.45), post_col)
    gb.box(Vector3(0.0, 8.0, 0.0), Vector3(10.4, 0.9, 0.5), Color(0.12, 0.16, 0.38))
    var ncheck := 26
    var cwid := 20.0 / float(ncheck)
    for r in 2:
        for c in ncheck:
            var cc := Color(0.97, 0.97, 0.95) if (r + c) % 2 == 0 else Color(0.08, 0.08, 0.10)
            var xa := -10.0 + float(c) * cwid
            var ya := 7.25 + float(r) * 0.75
            gb.quad(Vector3(xa, ya, 0.53), Vector3(xa + cwid, ya, 0.53), Vector3(xa + cwid, ya + 0.75, 0.53), Vector3(xa, ya + 0.75, 0.53), cc, Vector3(0, 0, 1))
            gb.quad(Vector3(xa, ya, -0.53), Vector3(xa + cwid, ya, -0.53), Vector3(xa + cwid, ya + 0.75, -0.53), Vector3(xa, ya + 0.75, -0.53), cc, Vector3(0, 0, -1))
    _add_mesh(gb.to_mesh(), _mat_vertex_color(0.7), root)
    var lab := Label3D.new()
    lab.text = "LARGADA"
    lab.font_size = 120
    lab.pixel_size = 0.0075
    lab.outline_size = 24
    lab.modulate = Color(1.0, 0.9, 0.2)
    lab.position = Vector3(0.0, 10.4, 0.6)
    root.add_child(lab)
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3(0.9, 8.4, 0.9)
    _add_static(box_shape, root, Transform3D(Basis.IDENTITY, Vector3(-9.8, 4.2, 0.0)))
    _add_static(box_shape, root, Transform3D(Basis.IDENTITY, Vector3(9.8, 4.2, 0.0)))

    # Arquibancada do lado esquerdo
    var sb := MeshBuilder.new()
    var tier_colors: Array[Color] = [Color(0.90, 0.25, 0.22), Color(0.98, 0.78, 0.18), Color(0.22, 0.52, 0.92), Color(0.95, 0.95, 0.95)]
    var stand := Node3D.new()
    stand.name = "Arquibancada"
    stand.transform = Transform3D(Basis.looking_at(track.tans[i0], Vector3.UP), origin + track.sides[i0] * -22.0 + Vector3(0.0, 0.0, 0.0))
    add_child(stand)
    for t in 4:
        var hgt := 1.7 + float(t) * 1.7
        var center := Vector3(-float(t) * 2.8, (hgt - 4.0) * 0.5, -6.0)
        sb.box(center, Vector3(1.4, (hgt + 4.0) * 0.5, 12.0), tier_colors[t])
        var shp := BoxShape3D.new()
        shp.size = Vector3(2.8, hgt + 4.0, 24.0)
        _add_static(shp, stand, Transform3D(Basis.IDENTITY, center))
    _add_mesh(sb.to_mesh(), _mat_vertex_color(0.8), stand)


# ----------------------------------------------------------- pads de nitro
func _make_boost_pads() -> void:
    var spots: Array[int] = track.pad_spots
    var offsets: Array[float] = [-2.5, 2.5, 0.0, -2.5, 2.5, 0.0, 2.5]
    for q in spots.size():
        var i := spots[q] % track.count
        var plat: float = offsets[q % offsets.size()]
        if track.pad_lats.size() == spots.size():
            plat = track.pad_lats[q]
        var pos := track.at(i, plat)
        var root := Node3D.new()
        root.name = "PadNitro"
        root.transform = Transform3D(_basis_along(i), pos)
        add_child(root)

        var mb := MeshBuilder.new()
        mb.quad(Vector3(-3.0, 0.07, 4.2), Vector3(3.0, 0.07, 4.2), Vector3(3.0, 0.07, -4.2), Vector3(-3.0, 0.07, -4.2), Color(0.08, 0.62, 0.98), Vector3.UP)
        var yellow := Color(1.0, 0.93, 0.25)
        for c in 3:
            var zc := 2.3 - float(c) * 2.3
            for sx in [-1.0, 1.0]:
                var sgn: float = sx
                mb.quad(
                    Vector3(sgn * 2.4, 0.09, zc + 0.5), Vector3(0.0, 0.09, zc - 0.9),
                    Vector3(0.0, 0.09, zc - 0.2), Vector3(sgn * 2.4, 0.09, zc + 1.2),
                    yellow, Vector3.UP)
        var mi := _add_mesh(mb.to_mesh(), _mat_vertex_color(0.5, true), root)
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

        var area := Area3D.new()
        area.collision_layer = 0
        area.collision_mask = 2
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(6.0, 3.0, 8.4)
        cs.shape = bs
        cs.position = Vector3(0.0, 1.3, 0.0)
        area.add_child(cs)
        area.body_entered.connect(_on_boost_pad)
        root.add_child(area)


func _on_boost_pad(body: Node3D) -> void:
    if body.has_method("boost"):
        body.call("boost", 1.4)


# ------------------------------------------------------------------- rampas
func _make_ramps() -> void:
    for sp in track.ramp_spots:
        _make_ramp(sp % track.count, 4.8, 4.6, 1.9)
    # Rampa de lançamento antes de cada abismo (largura total da pista).
    for g in track.gaps:
        _make_ramp(int(g.x) - 2, 7.4, 4.6, 2.1)


func _make_ramp(i: int, w: float, l: float, hh: float) -> void:
    make_ramp_at(_basis_along(i), track.pts[i], w, l, hh)


# Rampa em qualquer lugar (usada também pelos atalhos).
func make_ramp_at(basis: Basis, pos: Vector3, w: float, l: float, hh: float) -> void:
    var root := Node3D.new()
    root.name = "Rampa"
    root.transform = Transform3D(basis, pos + Vector3(0.0, -0.02, 0.0))
    add_child(root)
    var p0 := Vector3(-w, 0.0, l)
    var p1 := Vector3(w, 0.0, l)
    var p2 := Vector3(w, 0.0, -l)
    var p3 := Vector3(-w, 0.0, -l)
    var p4 := Vector3(w, hh, -l)
    var p5 := Vector3(-w, hh, -l)
    var mb := MeshBuilder.new()
    var stripes := 8
    for s in stripes:
        var xa := -w + 2.0 * w * float(s) / float(stripes)
        var xb := -w + 2.0 * w * float(s + 1) / float(stripes)
        var c := Color(1.0, 0.55, 0.12) if s % 2 == 0 else Color(1.0, 0.90, 0.25)
        mb.quad(Vector3(xa, 0.0, l), Vector3(xb, 0.0, l), Vector3(xb, hh, -l), Vector3(xa, hh, -l), c, Vector3(0.0, 2.0 * l, hh))
    var side_c := Color(0.30, 0.32, 0.40)
    mb.tri(p0, p3, p5, side_c, Vector3(-1, 0, 0))
    mb.tri(p1, p2, p4, side_c, Vector3(1, 0, 0))
    mb.quad(p3, p2, p4, p5, side_c, Vector3(0, 0, -1))
    _add_mesh(mb.to_mesh(), _mat_vertex_color(0.7), root)
    var shape := ConvexPolygonShape3D.new()
    shape.points = PackedVector3Array([p0, p1, p2, p3, p4, p5])
    _add_static(shape, root)


# ---------------------------------------------------------------- obstáculos
func _make_obstacles() -> void:
    # Barris em chicanes (aglomerados alternando de lado).
    var mb := MeshBuilder.new()
    var body := StaticBody3D.new()
    body.name = "ColisaoBarris"
    body.collision_layer = 1
    body.collision_mask = 0
    add_child(body)
    var shape := CylinderShape3D.new()
    shape.radius = 0.62
    shape.height = 1.3
    var n := track.count
    for sp in track.barrel_spots:
        for q in 3:
            var i := (sp + q * 14) % n
            var lat := -3.5 if q % 2 == 0 else 3.5
            for bx in [-0.75, 0.75]:
                for bz in [-0.75, 0.75]:
                    var bxf: float = bx
                    var bzf: float = bz
                    var p := track.at(i, lat + bxf) + Vector3(track.tans[i].x, 0.0, track.tans[i].z).normalized() * bzf
                    var col1 := theme.barrel_a
                    mb.cylinder(p, 0.55, 0.55, 1.2, 8, col1)
                    mb.cylinder(p + Vector3(0.0, 0.35, 0.0), 0.56, 0.56, 0.18, 8, theme.barrel_b, false)
                    var cs := CollisionShape3D.new()
                    cs.shape = shape
                    cs.position = p + Vector3(0.0, 0.65, 0.0)
                    body.add_child(cs)
    if not mb.is_empty():
        _add_mesh(mb.to_mesh(), _mat_vertex_color(0.6))

    # Barreiras deslizantes: cobrem metade da pista e vão e vêm (use o outro lado!).
    for q in track.mover_spots.size():
        var i := track.mover_spots[q] % n
        var lat := -3.5 if q % 2 == 0 else 3.5
        var mover := MovingObstacle.new()
        mover.name = "BarreiraMovel"
        var xf_basis := _basis_along(i)
        mover.position = track.at(i, lat) + Vector3(0.0, 0.7, 0.0)
        mover.basis = xf_basis
        mover.axis = track.sides[i]
        mover.amplitude = 2.6
        mover.speed = 1.5
        mover.phase = float(q) * 1.3
        var mmb := MeshBuilder.new()
        for seg in 5:
            var cc := theme.mover_a if seg % 2 == 0 else theme.mover_b
            mmb.box(Vector3(-2.0 + float(seg), 0.0, 0.0), Vector3(0.5, 0.7, 0.45), cc)
        var mi := MeshInstance3D.new()
        mi.mesh = mmb.to_mesh()
        mi.material_override = _mat_vertex_color(0.6)
        mover.add_child(mi)
        var mcs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(5.0, 1.4, 0.9)
        mcs.shape = bs
        mover.add_child(mcs)
        add_child(mover)


# Placas de aviso antes de cada abismo.
func _make_gap_signs() -> void:
    var sign_mesh := BoxMesh.new()
    sign_mesh.size = Vector3(4.2, 2.0, 0.14)
    var sign_mat := _mat_color(Color(1.0, 0.25, 0.15), 0.6)
    for g in track.gaps:
        for off in [40, 16]:
            var off_i: int = off
            var i := int(g.x) - off_i
            for sg in [-1.0, 1.0]:
                var sgf: float = sg
                var base := track.pts[i] + track.sides[i] * sgf * 10.5
                var holder := Node3D.new()
                holder.transform = Transform3D(Basis.looking_at(track.sides[i] * sgf, Vector3.UP), base + Vector3(0.0, 2.6, 0.0))
                add_child(holder)
                var panel := MeshInstance3D.new()
                panel.mesh = sign_mesh
                panel.material_override = sign_mat
                holder.add_child(panel)
                var lab := Label3D.new()
                lab.text = "SALTO!" if off_i == 40 else "!!!"
                lab.font_size = 100
                lab.pixel_size = 0.0085
                lab.modulate = Color(1, 1, 1)
                lab.outline_size = 12
                lab.position = Vector3(0.0, 0.0, 0.09)
                holder.add_child(lab)


# Balizas refletivas nos trechos de penhasco (não há proteção, então o piloto precisa ver a borda).
func _make_cliff_markers() -> void:
    if track.cliffs.is_empty():
        return
    var mb := MeshBuilder.new()
    var n := track.count
    for r in track.cliffs:
        for i in range(r.x, r.y, 3):
            var ii := i % n
            for sg in [-1.0, 1.0]:
                var sgf: float = sg
                var base := track.at(ii, sgf * 9.3)
                var c := theme.sign_color if (i / 3) % 2 == 0 else Color(1, 1, 1)
                mb.box(base + Vector3(0.0, 0.45, 0.0), Vector3(0.09, 0.45, 0.09), c)
                mb.box(base + Vector3(0.0, 0.95, 0.0), Vector3(0.13, 0.08, 0.13), Color(1.0, 0.22, 0.10))
    var mi := _add_mesh(mb.to_mesh(), _mat_vertex_color(0.6, true))
    mi.name = "Balizas"
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ----------------------------------------------------- árvores, pedras, extras
func _make_trees_and_rocks() -> void:
    var tset: Dictionary = ThemeDecor.tree_set(theme)
    var tree_meshes: Array = tset["meshes"]

    var groups: Dictionary = {}
    var collider_body := StaticBody3D.new()
    collider_body.name = "ColisaoArvores"
    collider_body.collision_layer = 1
    collider_body.collision_mask = 0
    add_child(collider_body)
    var trunk_shape := CylinderShape3D.new()
    trunk_shape.radius = 0.5
    trunk_shape.height = 3.2
    var placed := 0

    # Árvores acompanhando as margens da pista (guiam o olhar nas curvas).
    var n := track.count
    for i in range(0, n, theme.border_step):
        for s in [-1.0, 1.0]:
            var sg: float = s
            var off := 12.5 + rng.randf() * 9.0
            var p := track.pts[i] + track.sides[i] * sg * off
            if _try_add_tree(p.x, p.z, groups, tset, collider_body, trunk_shape):
                placed += 1

    # Florestas espalhadas pelo mapa.
    for attempt in theme.tree_count * 5:
        if placed >= theme.tree_count:
            break
        var x := rng.randf_range(min_x + 24.0, max_x - 24.0)
        var z := rng.randf_range(min_z + 24.0, max_z - 24.0)
        if forest_noise.get_noise_2d(x, z) < -0.05 and road_dist_at(x, z) > 30.0:
            continue
        if _try_add_tree(x, z, groups, tset, collider_body, trunk_shape):
            placed += 1

    for key in groups.keys():
        var k: Vector3i = key
        var list: Array = groups[key]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = tree_meshes[k.x]
        mm.instance_count = list.size()
        for q in list.size():
            mm.set_instance_transform(q, list[q])
        var inst := MultiMeshInstance3D.new()
        inst.multimesh = mm
        inst.material_override = _mat_vertex_color(0.9)
        inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        inst.visibility_range_end = 420.0
        add_child(inst)

    # Pedras (com colisão).
    var rmb := MeshBuilder.new()
    rmb.sphere(Vector3.ZERO, Vector3(1.0, 0.7, 0.9), 4, 6, theme.rock_color.lightened(0.12))
    var rock_mesh := rmb.to_mesh()
    var rock_xforms: Array[Transform3D] = []
    var rock_body := StaticBody3D.new()
    rock_body.name = "ColisaoPedras"
    rock_body.collision_layer = 1
    rock_body.collision_mask = 0
    add_child(rock_body)
    for i in range(3, n, 9):
        var sg := 1.0 if rng.randf() > 0.5 else -1.0
        var off := 11.0 + rng.randf() * 18.0
        var p := track.pts[i] + track.sides[i] * sg * off
        if _near_lake(p.x, p.z, 1.0) or tunnel_hill_at(p.x, p.z, 75.0):
            continue
        var h := height_at(p.x, p.z)
        if track.in_cliff(i) or h < p.y - 12.0:
            continue
        var sc := 0.9 + rng.randf() * 1.6
        var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(p.x, h + 0.25 * sc, p.z))
        rock_xforms.append(xf)
        var ss := SphereShape3D.new()
        ss.radius = 0.85 * sc
        var cs := CollisionShape3D.new()
        cs.shape = ss
        cs.position = xf.origin
        rock_body.add_child(cs)
    if rock_xforms.size() > 0:
        var rmm := MultiMesh.new()
        rmm.transform_format = MultiMesh.TRANSFORM_3D
        rmm.mesh = rock_mesh
        rmm.instance_count = rock_xforms.size()
        for q in rock_xforms.size():
            rmm.set_instance_transform(q, rock_xforms[q])
        var rinst := MultiMeshInstance3D.new()
        rinst.multimesh = rmm
        rinst.material_override = _mat_vertex_color(0.9)
        add_child(rinst)


func _try_add_tree(x: float, z: float, groups: Dictionary, tset: Dictionary, collider_body: StaticBody3D, trunk_shape: CylinderShape3D) -> bool:
    if x < min_x + 20.0 or x > max_x - 20.0 or z < min_z + 20.0 or z > max_z - 20.0:
        return false
    var d := road_dist_at(x, z)
    if d < 12.0:
        return false
    if _near_lake(x, z) or tunnel_hill_at(x, z, 75.0):
        return false
    var h := height_at(x, z)
    if h > float(tset["tree_line"]):
        return false
    if slope_at(x, z) > 0.45:
        return false
    var low: Array = tset["low"]
    var high: Array = tset["high"]
    var variant: int = low[rng.randi_range(0, low.size() - 1)]
    if not high.is_empty() and (h > float(tset["high_h"]) or rng.randf() < float(tset["high_chance"])):
        variant = high[rng.randi_range(0, high.size() - 1)]
    var sc := 0.8 + rng.randf() * 0.7
    var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(x, h - 0.2, z))
    var key := Vector3i(variant, int(floor(x / 220.0)), int(floor(z / 220.0)))
    if not groups.has(key):
        groups[key] = []
    var list: Array = groups[key]
    list.append(xf)
    if d < 46.0:
        var cs := CollisionShape3D.new()
        cs.shape = trunk_shape
        cs.position = Vector3(x, h + 1.4, z)
        collider_body.add_child(cs)
    return true


func _make_water_and_clouds() -> void:
    for lk in track.lakes:
        var plane := PlaneMesh.new()
        plane.size = Vector2(lk.z * 2.8, lk.z * 2.8)
        var wm := StandardMaterial3D.new()
        wm.albedo_color = theme.water_color
        if not theme.water_opaque:
            wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        wm.roughness = theme.water_roughness
        wm.metallic_specular = 0.9
        if theme.water_emission_energy > 0.0:
            wm.emission_enabled = true
            wm.emission = theme.water_emission
            wm.emission_energy_multiplier = theme.water_emission_energy
        var water := _add_mesh(plane, wm)
        water.name = "Lago"
        water.position = Vector3(lk.x, lk.w, lk.y)
        water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var cb := MeshBuilder.new()
    for i in theme.cloud_count:
        var cx := rng.randf_range(min_x, max_x)
        var cz := rng.randf_range(min_z, max_z)
        var cy := rng.randf_range(150.0, 230.0)
        for q in 4:
            var off := Vector3(rng.randf_range(-22.0, 22.0), rng.randf_range(-3.0, 4.0), rng.randf_range(-12.0, 12.0))
            var rad := Vector3(rng.randf_range(14.0, 24.0), rng.randf_range(6.0, 9.0), rng.randf_range(10.0, 16.0))
            cb.sphere(Vector3(cx, cy, cz) + off, rad, 4, 8, theme.cloud_color)
    var clouds := _add_mesh(cb.to_mesh(), _mat_vertex_color(1.0, true))
    clouds.name = "Nuvens"
    clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
