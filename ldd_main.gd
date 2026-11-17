class_name LddMain
extends Node3D

# LDD KART — sequência de introdução em 3D + menu principal (mesma cena 3D).
#   0–3 s   CENA 01  pista vazia (câmera parada, expectativa)
#   3–7 s   CENA 02  karts cruzam a pista, derrapam, fumaça, câmera vibra
#   7–9 s   CENA 03  explosão de fumaça cobre a tela, motores somem
#   9–12 s  CENA 04  fumaça se dispersa e a logo 3D é revelada
#   12–15 s CENA 05  logo vai para o canto, menu aparece, kart do jogador chega
# Toque/clique/tecla pula para o menu. Com play_intro = false (voltando da garagem)
# a cena já nasce no estado final do menu.

@export var play_intro := true

const T_MENU := 13.0          # início da transição para o menu
const T_END := 15.5
const FOV := 52.0
const LOGO_DIST := 5.0
const LOGO_ASPECT := 1523.0 / 869.0

const KARTS := [
    {"color": Color(0.90, 0.12, 0.10), "drv": Color(0.15, 0.45, 0.95), "style": "fin", "start": 3.00, "speed": 46.0, "lat": 4.0, "ph": 0.0},
    {"color": Color(0.15, 0.40, 0.95), "drv": Color(1.00, 0.80, 0.10), "style": "pony", "start": 3.30, "speed": 49.0, "lat": 6.0, "ph": 1.7},
    {"color": Color(1.00, 0.78, 0.10), "drv": Color(0.90, 0.20, 0.20), "style": "ears", "start": 3.65, "speed": 44.0, "lat": 2.2, "ph": 3.1},
    {"color": Color(0.20, 0.78, 0.30), "drv": Color(0.95, 0.95, 0.98), "style": "antenna", "start": 3.95, "speed": 50.0, "lat": 5.0, "ph": 4.4},
    {"color": Color(1.00, 0.50, 0.08), "drv": Color(0.20, 0.30, 0.80), "style": "", "start": 4.30, "speed": 47.0, "lat": 0.8, "ph": 2.4},
    {"color": Color(0.65, 0.25, 0.90), "drv": Color(1.00, 0.85, 0.20), "style": "fin", "start": 4.65, "speed": 48.0, "lat": 3.2, "ph": 5.5},
]

var t := 0.0
var world: LddWorld
var cam: Camera3D
var cam_base_pos := Vector3.ZERO
var cam_dir := Vector3.FORWARD
var cam_basis := Basis()
var kart_nodes: Array[Node3D] = []
var kart_engine: Array[AudioStreamPlayer3D] = []
var kart_skid: Array[AudioStreamPlayer3D] = []
var kart_smoke: Array[Array] = []
var skid_done: Array[bool] = []
var big_smoke: CPUParticles3D
var logo_root: Node3D
var logo_mats: Array[ShaderMaterial] = []
var menu_kart: Node3D
var menu_smoke: Array[CPUParticles3D] = []
var ui: LddMenuUI
var smoke_overlay: ColorRect
var smoke_mat: ShaderMaterial
var flash: ColorRect
var hint: Label
var sounds: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var played := {}
var _skipped := false
var _leaving := false
var _music_started := false
var _smoke_tex: Texture2D
var _kart_target := Vector3.ZERO
var _kart_yaw := 0.0

const LOGO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint = vec3(1.0);
uniform float shine = -1.0;
uniform float shine_strength = 0.0;
uniform float glow = 0.0;
uniform float alpha = 1.0;
void fragment() {
    vec4 c = texture(tex, UV);
    float d = (UV.x + UV.y * 0.35) - shine;
    float band = exp(-d * d / 0.0025);
    vec3 col = c.rgb * tint + vec3(1.0, 0.96, 0.85) * band * shine_strength * c.a + vec3(0.25, 0.5, 1.0) * glow * c.a;
    ALBEDO = col;
    ALPHA = c.a * alpha;
}
"""

const SMOKE_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float cover = 0.0;
uniform float time = 0.0;
void fragment() {
    vec2 uv = UV * vec2(1.8, 1.0);
    float n1 = texture(noise, uv * 0.8 + vec2(time * 0.06, -time * 0.035)).r;
    float n2 = texture(noise, uv * 2.2 - vec2(time * 0.10, time * 0.03)).r;
    float f = n1 * 0.65 + n2 * 0.35;
    float a = smoothstep(f - 0.14, f + 0.14, cover * 1.35 - 0.16);
    vec3 col = mix(vec3(0.58, 0.60, 0.68), vec3(0.93, 0.94, 0.97), clamp(f * 1.3 - 0.1 + cover * 0.2, 0.0, 1.0));
    COLOR = vec4(col, a * 0.98);
}
"""


func _ready() -> void:
    if not play_intro:
        t = T_END + 2.0
        _skipped = true
    _smoke_tex = _make_smoke_texture()
    world = LddWorld.new()
    add_child(world)
    world.build()

    cam = Camera3D.new()
    cam.fov = FOV
    cam.near = 0.05
    cam.far = 1500.0
    cam.keep_aspect = Camera3D.KEEP_HEIGHT
    add_child(cam)
    cam.look_at_from_position(world.cam_pos, world.cam_look, Vector3.UP)
    cam_base_pos = cam.position
    cam_basis = cam.basis
    cam_dir = -cam.basis.z
    cam.current = true

    # luz de preenchimento (vem da câmera) para os karts não ficarem no escuro
    var fill := DirectionalLight3D.new()
    fill.light_energy = 0.55
    fill.light_color = Color(1.0, 0.97, 0.92)
    fill.shadow_enabled = false
    add_child(fill)
    fill.basis = Basis.looking_at(cam_dir + Vector3(0.15, -0.45, 0.0), Vector3.UP)

    _build_karts()
    _build_big_smoke()
    _build_logo()
    _build_menu_kart()
    _build_ui()
    _build_audio()
    get_viewport().size_changed.connect(_layout)
    _layout()
    _update(0.0, 0.0)


# -------------------------------------------------------------- construção
func _make_smoke_texture() -> Texture2D:
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
    var gt := GradientTexture2D.new()
    gt.gradient = g
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.5, 0.5)
    gt.fill_to = Vector2(1.0, 0.5)
    gt.width = 128
    gt.height = 128
    return gt


func _smoke_material() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.vertex_color_use_as_albedo = true
    m.albedo_texture = _smoke_tex
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.billboard_keep_scale = true
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.disable_receive_shadows = true
    return m


func _make_puff(parent: Node3D, pos: Vector3, amount: int, life: float, size_min: float, size_max: float, vel: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    var q := QuadMesh.new()
    q.size = Vector2(1.0, 1.0)
    q.material = _smoke_material()
    p.mesh = q
    p.amount = amount
    p.lifetime = life
    p.explosiveness = 0.0
    p.local_coords = false
    p.position = pos
    p.direction = Vector3(0.0, 1.0, 0.6)
    p.spread = 35.0
    p.gravity = Vector3(0.0, 0.5, 0.0)
    p.initial_velocity_min = vel * 0.5
    p.initial_velocity_max = vel
    p.scale_amount_min = size_min
    p.scale_amount_max = size_max
    var sc := Curve.new()
    sc.add_point(Vector2(0.0, 0.35))
    sc.add_point(Vector2(1.0, 1.4))
    p.scale_amount_curve = sc
    p.angle_min = -180.0
    p.angle_max = 180.0
    p.angular_velocity_min = -40.0
    p.angular_velocity_max = 40.0
    var cg := Gradient.new()
    cg.colors = PackedColorArray([Color(0.95, 0.95, 0.98, 0.0), Color(0.93, 0.94, 0.97, 0.75), Color(0.80, 0.82, 0.88, 0.0)])
    cg.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
    p.color_ramp = cg
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 0.25
    p.emitting = false
    parent.add_child(p)
    return p


func _build_karts() -> void:
    for i in KARTS.size():
        var k: Dictionary = KARTS[i]
        var n := KartModel.build(k["color"] as Color, k["drv"] as Color, String(k["style"]), KartModel.IDS[i % KartModel.IDS.size()])
        n.visible = false
        add_child(n)
        kart_nodes.append(n)
        var sm: Array = []
        for sx in [-0.65, 0.65]:
            sm.append(_make_puff(n, Vector3(sx, 0.25, 0.95), 26, 1.3, 0.9, 1.7, 1.4))
        kart_smoke.append(sm)
        var eng := AudioStreamPlayer3D.new()
        eng.stream = Sfx.engine()
        eng.unit_size = 9.0
        eng.max_distance = 400.0
        eng.volume_db = -6.0
        eng.pitch_scale = 0.9 + float(k["speed"]) * 0.004
        eng.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
        n.add_child(eng)
        kart_engine.append(eng)
        var sk := AudioStreamPlayer3D.new()
        sk.stream = Sfx.build_vinheta()["skid"]
        sk.unit_size = 9.0
        sk.max_distance = 300.0
        sk.volume_db = -3.0
        n.add_child(sk)
        kart_skid.append(sk)
        skid_done.append(false)


func _build_big_smoke() -> void:
    big_smoke = _make_puff(cam, Vector3(0.0, -1.5, -13.0), 110, 2.4, 9.0, 15.0, 1.2)
    big_smoke.local_coords = true
    big_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    big_smoke.emission_box_extents = Vector3(12.0, 3.0, 5.0)
    big_smoke.direction = Vector3(0.0, 0.3, -1.0)
    big_smoke.spread = 70.0
    big_smoke.gravity = Vector3.ZERO


func _build_logo() -> void:
    logo_root = Node3D.new()
    cam.add_child(logo_root)
    logo_root.position = Vector3(0.0, 0.0, -LOGO_DIST)
    var tex := load("res://assets/ldd/logo.png") as Texture2D
    var shader := Shader.new()
    shader.code = LOGO_SHADER
    var layers := 8
    # camadas de trás para frente: sombra, extrusão, frente
    for i in layers + 2:
        var mi := MeshInstance3D.new()
        var q := QuadMesh.new()
        q.size = Vector2(LOGO_ASPECT, 1.0)
        mi.mesh = q
        var m := ShaderMaterial.new()
        m.shader = shader
        m.set_shader_parameter("tex", tex)
        var z := 0.0
        if i == 0:
            z = -0.20
            m.set_shader_parameter("tint", Vector3(0.0, 0.0, 0.0))
            m.set_shader_parameter("alpha", 0.35)
            mi.position = Vector3(0.05, -0.06, z)
        elif i <= layers:
            z = -0.012 * float(layers - i + 1)
            var f := 0.10 + 0.04 * float(i) / float(layers)
            m.set_shader_parameter("tint", Vector3(f * 0.5, f * 0.8, f * 1.9))
            mi.position = Vector3(0.0, 0.0, z)
        else:
            mi.position = Vector3(0.0, 0.0, 0.0)
            m.set_shader_parameter("tint", Vector3(1.0, 1.0, 1.0))
        m.render_priority = i
        mi.material_override = m
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        logo_root.add_child(mi)
        logo_mats.append(m)
    logo_root.visible = false


func _build_menu_kart() -> void:
    var ch := Catalog.character(SaveGame.selected_char())
    var kd := Catalog.kart(SaveGame.selected_kart())
    menu_kart = KartModel.build(kd["color"] as Color, ch["color"] as Color, String(ch["style"]), String(kd["id"]))
    menu_kart.visible = false
    add_child(menu_kart)
    for sx in [-0.65, 0.65]:
        menu_smoke.append(_make_puff(menu_kart, Vector3(sx, 0.25, 0.95), 24, 1.2, 0.8, 1.5, 1.4))
    # sombra suave sob o kart
    var disc := CylinderMesh.new()
    disc.top_radius = 1.7
    disc.bottom_radius = 1.7
    disc.height = 0.01
    disc.radial_segments = 24
    var sm := StandardMaterial3D.new()
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.albedo_color = Color(0, 0, 0, 0.28)
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var shadow := MeshInstance3D.new()
    shadow.mesh = disc
    shadow.material_override = sm
    shadow.position = Vector3(0.0, 0.03, 0.2)
    shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    menu_kart.add_child(shadow)


func refresh_menu_kart() -> void:
    if menu_kart == null:
        return
    var vis := menu_kart.visible
    var pos := menu_kart.position
    var rot := menu_kart.rotation
    menu_kart.queue_free()
    _build_menu_kart()
    menu_kart.visible = vis
    menu_kart.position = pos
    menu_kart.rotation = rot


func _build_ui() -> void:
    var ui_layer := CanvasLayer.new()
    ui_layer.layer = 1
    add_child(ui_layer)
    ui = LddMenuUI.new()
    ui_layer.add_child(ui)
    ui.action.connect(_on_menu_action)
    ui.visible = false

    var smoke_layer := CanvasLayer.new()
    smoke_layer.layer = 2
    add_child(smoke_layer)
    smoke_overlay = ColorRect.new()
    smoke_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    smoke_layer.add_child(smoke_overlay)
    smoke_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shader := Shader.new()
    shader.code = SMOKE_SHADER
    smoke_mat = ShaderMaterial.new()
    smoke_mat.shader = shader
    var nz := FastNoiseLite.new()
    nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    nz.frequency = 0.012
    nz.fractal_octaves = 4
    var nt := NoiseTexture2D.new()
    nt.noise = nz
    nt.seamless = true
    nt.width = 512
    nt.height = 512
    smoke_mat.set_shader_parameter("noise", nt)
    smoke_overlay.material = smoke_mat

    var top_layer := CanvasLayer.new()
    top_layer.layer = 3
    add_child(top_layer)
    flash = ColorRect.new()
    flash.color = Color(1, 1, 1, 0.0)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_layer.add_child(flash)
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hint = Label.new()
    hint.text = "Toque para pular"
    hint.add_theme_font_size_override("font_size", 18)
    hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
    hint.add_theme_constant_override("outline_size", 5)
    hint.modulate = Color(1, 1, 1, 0.0)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_layer.add_child(hint)
    hint.anchor_left = 0.0
    hint.anchor_right = 1.0
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_top = -44.0
    hint.offset_bottom = -12.0
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_audio() -> void:
    sounds = Sfx.build_vinheta()
    sounds["boom"] = Sfx.to_wav(Sfx.mix(Sfx.noise(1.2, 0.9, 0.06), Sfx.sweep(120.0, 28.0, 1.1, 1.0, 0.0)), Sfx.RATE)
    sounds["smoke"] = Sfx.to_wav(Sfx.noise(2.2, 0.35, 0.05), Sfx.RATE)
    for i in 4:
        var p := AudioStreamPlayer.new()
        add_child(p)
        players.append(p)


func _play(sound_name: String, at: float, vol: float = 0.0) -> void:
    if _skipped or played.has(sound_name) or t < at:
        return
    played[sound_name] = true
    for p in players:
        if not p.playing:
            p.stream = sounds[sound_name]
            p.volume_db = vol
            p.play()
            return


# ------------------------------------------------------------------ layout
func _vis_size() -> Vector2:
    var vp := get_viewport().get_visible_rect().size
    var vh := 2.0 * LOGO_DIST * tan(deg_to_rad(FOV) * 0.5)
    return Vector2(vh * vp.x / maxf(vp.y, 1.0), vh)


func _layout() -> void:
    # posição-alvo do kart do menu: projeta um ponto da tela (parte baixa direita) no chão
    var vp := get_viewport().get_visible_rect().size
    var aspect := vp.x / maxf(vp.y, 1.0)
    var th := tan(deg_to_rad(FOV) * 0.5)
    var ndc := Vector2(0.50, -0.42)
    var local_dir := Vector3(ndc.x * th * aspect, ndc.y * th, -1.0).normalized()
    var final_pos := cam_base_pos + cam_dir * 0.25 * 12.0
    var dir_w := cam_basis * local_dir
    if dir_w.y < -0.01:
        var k := (0.0 - final_pos.y) / dir_w.y
        _kart_target = final_pos + dir_w * k
    else:
        _kart_target = final_pos + cam_dir * 9.0
        _kart_target.y = 0.0
    var to_cam := final_pos - _kart_target
    _kart_yaw = _yaw_for(to_cam) + 0.55
    hint.size = Vector2(vp.x, 32.0)


func _yaw_for(dir: Vector3) -> float:
    return atan2(-dir.x, -dir.z)


# --------------------------------------------------------------- linha do tempo
func _p(a: float, b: float) -> float:
    return clampf((t - a) / (b - a), 0.0, 1.0)


func _ease_out(x: float) -> float:
    return 1.0 - pow(1.0 - x, 3.0)


func _ease_io(x: float) -> float:
    return x * x * (3.0 - 2.0 * x)


func _back_out(x: float) -> float:
    var c1 := 1.70158
    var c3 := c1 + 1.0
    return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _process(delta: float) -> void:
    delta = minf(delta, 0.05)
    t += delta
    _update(t, delta)


func _update(time: float, delta: float) -> void:
    world.animate(time, delta)
    _update_camera(time)
    _update_karts(time)
    _update_smoke_and_logo(time)
    _update_menu(time)
    _update_sounds(time)
    hint.modulate.a = (_p(1.0, 1.6) * 0.5 * (1.0 - _p(11.8, 12.6))) if play_intro and not _skipped else 0.0


func _update_camera(time: float) -> void:
    var creep := 0.25 * minf(time, 12.0)
    var pos := cam_base_pos + cam_dir * creep
    var amp := 0.0
    if time > 3.0 and time < 9.0:
        var cp := cam_base_pos + cam_dir * creep
        for i in kart_nodes.size():
            if kart_nodes[i].visible:
                var dist := kart_nodes[i].global_position.distance_to(cp)
                amp += 0.045 * pow(clampf(1.0 - dist / 26.0, 0.0, 1.0), 2.0)
    if time > 7.0 and time < 9.5:
        amp += 0.012
    var sway_m := 0.0
    if time > T_MENU:
        sway_m = _p(T_MENU, T_MENU + 1.5)
    var e := Vector3(
        amp * sin(time * 53.0) + 0.004 * sway_m * sin(time * 0.5),
        amp * sin(time * 47.0 + 1.3) + 0.012 * sway_m * sin(time * 0.37),
        amp * 0.6 * sin(time * 61.0 + 2.1))
    cam.position = pos + Vector3(0.0, amp * 0.5 * sin(time * 71.0), 0.0)
    cam.basis = cam_basis * Basis.from_euler(e)


func _update_karts(time: float) -> void:
    for i in KARTS.size():
        var k: Dictionary = KARTS[i]
        var d := float(k["speed"]) * (time - float(k["start"]))
        var n := kart_nodes[i]
        var active := d >= 0.0 and d < 205.0 and time < 9.5
        n.visible = active
        for s in kart_smoke[i]:
            (s as CPUParticles3D).emitting = active and d > 20.0 and d < 190.0
        var eng := kart_engine[i]
        if active:
            if not eng.playing:
                eng.play()
            var fade := 1.0 - _p(7.0, 9.0)
            eng.volume_db = -6.0 + 28.0 * log(maxf(fade, 0.001)) / log(10.0) * 0.5
        elif eng.playing:
            eng.stop()
        if not active:
            continue
        var ph := float(k["ph"])
        var slip := sin(d * 0.07 + ph) * 0.40 + 0.18 * sin(d * 0.19 + ph * 2.0)
        var lat := float(k["lat"]) + sin(d * 0.045 + ph) * 1.8
        var fwd := world.path_fwd(d)
        var pos := world.path_pos(d) + world.path_right(d) * lat
        pos.y = 0.05 + 0.05 * absf(sin(d * 0.9 + ph))
        var look := fwd.rotated(Vector3.UP, slip)
        var b := Basis.looking_at(look, Vector3.UP)
        b = b * Basis(Vector3(0.0, 0.0, 1.0), -slip * 0.28)
        n.transform = Transform3D(b, pos)
        # derrapada sonora quando passa perto da câmera
        if not skid_done[i] and d > 128.0 and not _skipped:
            skid_done[i] = true
            kart_skid[i].play()


func _update_smoke_and_logo(time: float) -> void:
    # fumaça 3D grande
    big_smoke.emitting = time > 7.1 and time < 9.6
    # cobertura em tela (dissolve com ruído)
    var cover := 0.0
    if time < 8.9:
        cover = _ease_io(_p(7.2, 8.8))
    elif time < 9.0:
        cover = 1.0
    else:
        cover = 1.0 - _ease_io(_p(9.0, 11.3))
    smoke_mat.set_shader_parameter("cover", cover)
    smoke_mat.set_shader_parameter("time", time)

    # logo 3D
    var vis := _vis_size()
    var show_logo := time >= 8.9
    logo_root.visible = show_logo
    if not show_logo:
        return
    var pop := _back_out(_p(9.05, 9.85))
    var hold_in := _p(9.0, 13.0)     # aproximação lenta (CENA 04)
    var big_h := minf(vis.x * 0.66 / LOGO_ASPECT, vis.y * 0.64)
    var small_h := vis.x * 0.36 / LOGO_ASPECT
    var m := _ease_io(_p(T_MENU, T_MENU + 1.3))
    var h := lerpf(big_h * (1.0 + 0.07 * hold_in), small_h, m) * lerpf(0.55, 1.0, pop)
    var cx := lerpf(0.0, 0.285 * vis.x, m)
    var cy := lerpf(0.02 * vis.y, 0.285 * vis.y, m)
    logo_root.position = Vector3(cx, cy + 0.03 * sin(time * 1.6) * m, -LOGO_DIST)
    logo_root.scale = Vector3.ONE * h
    logo_root.rotation = Vector3(sin(time * 0.9) * 0.05, sin(time * 1.2) * 0.14, sin(time * 0.7) * 0.015)
    var a := _p(9.0, 9.25)
    var shine := lerpf(-0.5, 1.6, _p(10.0, 11.4))
    var shine2 := lerpf(-0.5, 1.6, _p(14.3, 15.2))
    var glow := 0.55 * exp(-maxf(time - 9.1, 0.0) * 2.2) if time >= 9.1 else 0.0
    for i in logo_mats.size():
        var lm := logo_mats[i]
        lm.set_shader_parameter("alpha", (0.35 if i == 0 else 1.0) * a)
        if i == logo_mats.size() - 1:
            lm.set_shader_parameter("shine", shine if time < 13.0 else shine2)
            lm.set_shader_parameter("shine_strength", 0.9)
            lm.set_shader_parameter("glow", glow)
    flash.color.a = 0.65 * exp(-(time - 9.1) * 8.0) if time >= 9.1 and time < 10.5 else 0.0


func _update_menu(time: float) -> void:
    var mt := time - T_MENU
    ui.visible = time >= T_MENU
    if ui.visible:
        ui.set_time(mt)
    if time >= T_MENU and not _music_started:
        _music_started = true
        Flow.start_menu_music()
    # kart do jogador chega derrapando
    var p := _p(T_MENU + 0.2, T_MENU + 1.5)
    menu_kart.visible = time >= T_MENU + 0.2
    var arriving := menu_kart.visible and p < 1.0
    for s in menu_smoke:
        s.emitting = arriving or (menu_kart.visible and time < T_MENU + 2.2)
    if menu_kart.visible:
        var right := cam_basis.x
        right.y = 0.0
        right = right.normalized()
        var e := _ease_out(p)
        var pos := _kart_target + right * lerpf(22.0, 0.0, e)
        var drive_yaw := _yaw_for(-right)
        var yaw := lerp_angle(drive_yaw, _kart_yaw, _ease_io(clampf((p - 0.45) / 0.55, 0.0, 1.0)))
        var slide := sin(p * PI) * 0.22 * (1.0 - p)
        var b := Basis(Vector3.UP, yaw + slide)
        var bob := 0.0
        if p >= 1.0:
            bob = 0.012 * sin(time * 2.4)
        menu_kart.transform = Transform3D(b * Basis(Vector3(0, 0, 1), slide * 0.4), pos + Vector3(0.0, bob, 0.0))


func _update_sounds(time: float) -> void:
    _play("rev", 1.3, -14.0)
    _play("smoke", 7.0, -8.0)
    _play("whoosh", 8.2, -6.0)
    _play("boom", 9.05, -2.0)
    _play("fanfare", 9.25, -8.0)
    if time >= T_MENU + 0.15 and not played.has("menu_whoosh") and not _skipped:
        played["menu_whoosh"] = true
        for pl in players:
            if not pl.playing:
                pl.stream = sounds["whoosh"]
                pl.volume_db = -9.0
                pl.play()
                break


# ------------------------------------------------------------------- entrada
func _input(event: InputEvent) -> void:
    if not play_intro or _skipped or _leaving or t < 0.6 or t >= T_MENU - 0.2:
        return
    var pressed := false
    if event is InputEventKey:
        pressed = event.pressed and not event.echo
    elif event is InputEventScreenTouch:
        pressed = event.pressed
    elif event is InputEventMouseButton:
        pressed = event.pressed
    if pressed:
        _skip()


func _skip() -> void:
    _skipped = true
    for p in players:
        p.stop()
    for i in kart_engine.size():
        kart_engine[i].stop()
        kart_skid[i].stop()
    t = T_MENU


func _on_menu_action(id: String) -> void:
    match id:
        "play", "custom":
            Flow.garage_step = 0
            Flow.go(Flow.SCENE_GARAGEM)
        "karts":
            Flow.garage_step = 1
            Flow.go(Flow.SCENE_GARAGEM)
        "quick":
            Flow.stop_music()
            Flow.go(Flow.SCENE_RACE)
        "refresh":
            refresh_menu_kart()
