class_name WonderlandEnvironment
extends RefCounted

# Céu, névoa, luz e pós-processamento por setor (interpolados suavemente ao longo da pista), mar de nuvens e sol.
# Efeitos que só existem no Forward+ (névoa volumétrica, SSAO, SSIL) são ligados só se o renderizador suportar.

# sky_top, sky_horizon, ambient, amb_energy, fog, fog_density, sun_energy, exposure, saturation, glow
const P := {
    1: [Color(0.18, 0.38, 0.78), Color(1.0, 0.72, 0.5), Color(0.75, 0.8, 0.95), 0.85, Color(0.78, 0.82, 0.92), 0.0007, 1.35, 1.0, 1.15, 0.35],
    2: [Color(0.22, 0.36, 0.7), Color(0.95, 0.65, 0.5), Color(0.7, 0.75, 0.9), 0.8, Color(0.74, 0.78, 0.9), 0.0016, 1.2, 1.0, 1.1, 0.35],
    3: [Color(0.08, 0.1, 0.3), Color(0.55, 0.35, 0.6), Color(0.45, 0.4, 0.7), 0.6, Color(0.32, 0.3, 0.55), 0.0030, 0.6, 1.0, 1.1, 0.5],
    4: [Color(0.02, 0.06, 0.1), Color(0.05, 0.2, 0.25), Color(0.2, 0.55, 0.6), 0.35, Color(0.03, 0.12, 0.15), 0.0032, 0.0, 1.1, 1.2, 0.8],
    5: [Color(0.05, 0.02, 0.1), Color(0.2, 0.08, 0.3), Color(0.6, 0.35, 0.9), 0.4, Color(0.09, 0.04, 0.16), 0.0036, 0.0, 1.1, 1.25, 0.9],
    6: [Color(0.12, 0.02, 0.0), Color(0.5, 0.12, 0.03), Color(0.95, 0.35, 0.15), 0.4, Color(0.22, 0.05, 0.01), 0.0034, 0.0, 1.1, 1.2, 0.9],
    7: [Color(0.02, 0.04, 0.12), Color(0.1, 0.2, 0.4), Color(0.45, 0.7, 1.0), 0.4, Color(0.04, 0.08, 0.2), 0.0030, 0.0, 1.1, 1.15, 0.9],
    8: [Color(0.1, 0.1, 0.2), Color(0.8, 0.5, 0.3), Color(0.9, 0.7, 0.5), 0.6, Color(0.45, 0.3, 0.25), 0.0045, 0.6, 1.05, 1.1, 0.6],
}

var world: Node3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var sectors: Array = []
var track: TrackData
var clouds: MeshInstance3D
var cave_start := 1663
var cave_end := 4948
var cur := {}


func build(w: Node3D, tr: TrackData, lay: Dictionary) -> void:
    world = w
    track = tr
    sectors = lay["sectors"]
    var we := WorldEnvironment.new()
    we.name = "Wonderland_Environment"
    env = Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sun_angle_max = 30.0
    sky_mat.sky_curve = 0.18
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.08
    env.fog_enabled = true
    env.fog_sky_affect = 0.8
    env.fog_aerial_perspective = 0.0
    env.glow_enabled = true
    env.glow_intensity = 0.8
    env.glow_strength = 1.1
    env.glow_bloom = 0.1
    env.glow_hdr_threshold = 1.0
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
    if str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")) == "forward_plus":
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = 0.004
        env.volumetric_fog_albedo = Color(0.7, 0.75, 0.9)
        env.ssao_enabled = true
        env.ssil_enabled = false
    we.environment = env
    world.add_child(we)
    sun = DirectionalLight3D.new()
    sun.name = "Sol"
    sun.rotation_degrees = Vector3(-32, -50, 0)
    sun.light_color = Color(1.0, 0.88, 0.72)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 140.0
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if false else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    world.add_child(sun)
    _clouds()
    apply_index(0)


func _clouds() -> void:
    var mb := PlaneMesh.new()
    mb.size = Vector2(9000, 9000)
    mb.subdivide_width = 1
    mb.subdivide_depth = 1
    clouds = MeshInstance3D.new()
    clouds.name = "MarDeNuvens"
    clouds.mesh = mb
    clouds.material_override = WonderlandMaterials.cloud()
    clouds.position = Vector3(1200, 120.0, 1100)
    clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    clouds.extra_cull_margin = 4000.0
    world.add_child(clouds)
    var c2 := MeshInstance3D.new()
    c2.mesh = mb
    c2.material_override = WonderlandMaterials.cloud(Color(1.0, 0.85, 0.75), Color(0.7, 0.62, 0.8))
    c2.position = Vector3(1200, 330.0, 1100)
    c2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    c2.extra_cull_margin = 4000.0
    world.add_child(c2)


func sector_of(idx: int) -> int:
    for s in sectors.size():
        var v: Vector2i = sectors[s]
        if idx >= v.x and idx < v.y:
            return s + 1
    return 8


func _preset_at(idx: int) -> Array:
    var s := sector_of(idx)
    var v: Vector2i = sectors[s - 1]
    var blend := 70.0
    var out: Array = (P[s] as Array).duplicate()
    # mistura com o setor vizinho perto das fronteiras
    var to_end := float(v.y - idx)
    var from_start := float(idx - v.x)
    var other := -1
    var t := 0.0
    if to_end < blend and s < 8:
        other = s + 1
        t = 0.5 * (1.0 - to_end / blend)
    elif from_start < blend and s > 1:
        other = s - 1
        t = 0.5 * (1.0 - from_start / blend)
    if other > 0:
        var o: Array = P[other]
        for k in out.size():
            if out[k] is Color:
                out[k] = (out[k] as Color).lerp(o[k], t)
            else:
                out[k] = lerpf(float(out[k]), float(o[k]), t)
    return out


func apply_index(idx: int, delta: float = 1.0, y: float = 0.0) -> void:
    var pr := _preset_at(idx)
    var k := 1.0 - exp(-2.2 * delta) if delta < 1.0 else 1.0
    if cur.is_empty():
        k = 1.0
    cur = {}
    sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(pr[0], k)
    sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(pr[1], k)
    sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
    sky_mat.ground_bottom_color = sky_mat.sky_top_color * 0.5
    env.ambient_light_color = env.ambient_light_color.lerp(pr[2], k)
    env.ambient_light_energy = lerpf(env.ambient_light_energy, pr[3], k)
    env.fog_light_color = env.fog_light_color.lerp(pr[4], k)
    env.fog_density = lerpf(env.fog_density, pr[5], k)
    sun.light_energy = lerpf(sun.light_energy, pr[6], k)
    sun.visible = sun.light_energy > 0.02
    env.tonemap_exposure = lerpf(env.tonemap_exposure, pr[7], k)
    env.adjustment_saturation = lerpf(env.adjustment_saturation, pr[8], k)
    env.glow_intensity = lerpf(env.glow_intensity, pr[9], k)
    cur["x"] = 1
