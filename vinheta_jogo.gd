extends Node3D

# Vinheta do jogo (3D): o seu kart chega derrapando ao pôr do sol, a câmera dá a volta
# e o título "KART LIVRE 3D" explode na tela. Toque/tecla pula (depois de 0,5 s).
# Usa o kart e o piloto que estão selecionados no save.

@export_file("*.tscn") var next_scene_path := "res://Menu.tscn"

const TOTAL := 7.4
const DRIVE_END := 2.1      # instante em que o kart para
const SLAM_AT := 2.15       # instante em que o título aparece

var t := 0.0
var kart: Node3D
var cam: Camera3D
var headlight: SpotLight3D
var dust: CPUParticles3D
var sounds: Dictionary = {}
var played: Dictionary = {}
var players: Array[AudioStreamPlayer] = []

var title_root: Control
var sub_label: Label
var hint_label: Label
var flash: ColorRect
var fade: ColorRect
var _leaving := false
var _skipped := false
var _shake := 0.0


func _ready() -> void:
    _build_world()
    _build_ui()
    sounds = Sfx.build_vinheta()
    for i in 3:
        var p := AudioStreamPlayer.new()
        add_child(p)
        players.append(p)
    _update(0.0)


# ------------------------------------------------------------------ mundo 3D
func _build_world() -> void:
    # Céu de pôr do sol
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Webcore.soften(Color(0.04, 0.07, 0.24), 0.65, 0.2)
    sky_mat.sky_horizon_color = Webcore.soften(Color(1.0, 0.52, 0.24), 0.55, 0.14)
    sky_mat.ground_horizon_color = Color(0.45, 0.22, 0.20)
    sky_mat.ground_bottom_color = Color(0.03, 0.04, 0.09)
    sky_mat.sun_angle_max = 28.0
    var sky := Sky.new()
    sky.sky_material = sky_mat
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.9
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Webcore.soften(Color(0.55, 0.30, 0.32), 0.55, 0.16)
    env.fog_density = 0.0045
    Webcore.grade(env, 0.76, 1.02)
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    # Sol baixo atrás das montanhas (a luz vem de -Z e bate de contraluz no kart)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-9.0, 180.0, 0.0)
    sun.light_color = Color(1.0, 0.62, 0.32)
    sun.light_energy = 1.7
    sun.shadow_enabled = true
    add_child(sun)
    # Luz de preenchimento azulada do lado da câmera
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-30.0, 20.0, 0.0)
    fill.light_color = Color(0.45, 0.65, 1.0)
    fill.light_energy = 0.55
    add_child(fill)

    # Chão e estrada
    var ground := MeshInstance3D.new()
    var gm := PlaneMesh.new()
    gm.size = Vector2(700.0, 500.0)
    ground.mesh = gm
    ground.material_override = _flat(Color(0.07, 0.12, 0.10), 0.95)
    ground.position = Vector3(-40.0, -0.25, 0.0)
    add_child(ground)

    var road := MeshInstance3D.new()
    var rm := BoxMesh.new()
    rm.size = Vector3(300.0, 0.2, 13.0)
    road.mesh = rm
    road.material_override = _flat(Color(0.11, 0.12, 0.15), 0.8)
    road.position = Vector3(-60.0, -0.1, 0.0)
    add_child(road)

    # Faixa central tracejada, bordas e zebras vermelho/branco
    var dash := BoxMesh.new()
    dash.size = Vector3(3.0, 0.02, 0.22)
    var dash_mat := _unshaded(Color(0.95, 0.95, 0.85))
    var x := -150.0
    while x < 60.0:
        var d := MeshInstance3D.new()
        d.mesh = dash
        d.material_override = dash_mat
        d.position = Vector3(x, 0.01, 0.0)
        add_child(d)
        x += 8.0
    var curb := BoxMesh.new()
    curb.size = Vector3(4.0, 0.14, 0.9)
    var curb_red := _flat(Color(0.85, 0.08, 0.08), 0.6)
    var curb_white := _flat(Color(0.95, 0.95, 0.95), 0.6)
    var idx := 0
    x = -150.0
    while x < 60.0:
        for zs in [-1.0, 1.0]:
            var c := MeshInstance3D.new()
            c.mesh = curb
            c.material_override = curb_red if idx % 2 == 0 else curb_white
            c.position = Vector3(x, 0.02, 6.9 * zs)
            add_child(c)
        idx += 1
        x += 4.0

    # Postes de luz ciano passando rápido
    var post := BoxMesh.new()
    post.size = Vector3(0.25, 5.0, 0.25)
    var lamp := BoxMesh.new()
    lamp.size = Vector3(0.9, 0.18, 0.5)
    var post_mat := _flat(Color(0.2, 0.22, 0.28), 0.5)
    var lamp_mat := _unshaded(Color(0.4, 0.85, 1.0))
    x = -140.0
    while x < 50.0:
        var p := MeshInstance3D.new()
        p.mesh = post
        p.material_override = post_mat
        p.position = Vector3(x, 2.5, -9.5)
        add_child(p)
        var l := MeshInstance3D.new()
        l.mesh = lamp
        l.material_override = lamp_mat
        l.position = Vector3(x, 5.0, -9.2)
        add_child(l)
        x += 14.0

    # Montanhas ao fundo
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    for i in 16:
        var m := MeshInstance3D.new()
        var cone := CylinderMesh.new()
        var h := rng.randf_range(35.0, 85.0)
        cone.top_radius = 0.0
        cone.bottom_radius = h * rng.randf_range(0.9, 1.5)
        cone.height = h
        cone.radial_segments = 7
        m.mesh = cone
        m.material_override = _flat(Color(0.10, 0.09, 0.18).lerp(Color(0.2, 0.12, 0.2), rng.randf()), 1.0)
        m.position = Vector3(-300.0 + float(i) * 40.0 + rng.randf_range(-12.0, 12.0), h * 0.5 - 0.3, rng.randf_range(-210.0, -150.0))
        add_child(m)

    # Kart do jogador (o escolhido no save) apontando para +X
    var ch := Catalog.character(SaveGame.selected_char())
    var kd := Catalog.kart(SaveGame.selected_kart())
    kart = Node3D.new()
    kart.name = "Kart"
    add_child(kart)
    kart.add_child(KartModel.build(kd["color"], ch["color"], String(ch["style"]), String(kd["id"])))
    kart.rotation.y = -PI * 0.5
    kart.position = Vector3(-40.0, 0.0, 0.0)

    headlight = SpotLight3D.new()
    headlight.position = Vector3(0.0, 0.75, -1.1)
    headlight.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
    headlight.light_color = Color(1.0, 0.95, 0.8)
    headlight.light_energy = 0.0
    headlight.spot_range = 30.0
    headlight.spot_angle = 30.0
    kart.add_child(headlight)

    # Fumaça da derrapagem (parte de trás do kart = +Z local)
    dust = CPUParticles3D.new()
    dust.position = Vector3(0.0, 0.25, 1.0)
    dust.amount = 40
    dust.lifetime = 1.1
    dust.emitting = false
    dust.direction = Vector3(0.0, 0.4, 1.0)
    dust.spread = 50.0
    dust.initial_velocity_min = 2.0
    dust.initial_velocity_max = 5.0
    dust.gravity = Vector3(0.0, 0.6, 0.0)
    dust.scale_amount_min = 0.7
    dust.scale_amount_max = 1.6
    dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    dust.emission_sphere_radius = 0.35
    var puff := SphereMesh.new()
    puff.radius = 0.3
    puff.height = 0.6
    puff.radial_segments = 10
    puff.rings = 5
    var puff_mat := StandardMaterial3D.new()
    puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    puff_mat.vertex_color_use_as_albedo = true
    puff.material = puff_mat
    dust.mesh = puff
    var ramp := Gradient.new()
    ramp.colors = PackedColorArray([Color(0.85, 0.75, 0.70, 0.55), Color(0.5, 0.4, 0.45, 0.0)])
    ramp.offsets = PackedFloat32Array([0.0, 1.0])
    dust.color_ramp = ramp
    kart.add_child(dust)

    cam = Camera3D.new()
    cam.fov = 62.0
    cam.near = 0.1
    cam.far = 900.0
    add_child(cam)
    cam.current = true


func _flat(col: Color, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.roughness = rough
    return m


func _unshaded(col: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


# ------------------------------------------------------------------ interface
func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    title_root = Control.new()
    title_root.size = Vector2(1000.0, 160.0)
    title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_root.modulate.a = 0.0
    layer.add_child(title_root)
    var hb := HBoxContainer.new()
    hb.alignment = BoxContainer.ALIGNMENT_CENTER
    hb.add_theme_constant_override("separation", 28)
    hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_root.add_child(hb)
    hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var l1 := UIKit.label("KART LIVRE", 118, Color(1, 1, 1))
    l1.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.75))
    l1.add_theme_constant_override("outline_size", 26)
    hb.add_child(l1)
    var l2 := UIKit.label("3D", 150, UIKit.C_GOLD)
    l2.add_theme_color_override("font_outline_color", Color(0.55, 0.20, 0.02))
    l2.add_theme_constant_override("outline_size", 26)
    hb.add_child(l2)

    sub_label = UIKit.label("CIRCUITO AVENTURA", 38, Color(0.75, 0.88, 1.0))
    sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub_label.size = Vector2(1000.0, 50.0)
    sub_label.modulate.a = 0.0
    layer.add_child(sub_label)

    hint_label = UIKit.label("Toque para continuar", 22, Color(1, 1, 1))
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.size = Vector2(600.0, 32.0)
    hint_label.modulate.a = 0.0
    layer.add_child(hint_label)

    flash = ColorRect.new()
    flash.color = Color(1, 1, 1, 0)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(flash)
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    fade = ColorRect.new()
    fade.color = Color(0, 0, 0, 0)
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(fade)
    fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ------------------------------------------------------------------- animação
func _p(a: float, b: float) -> float:
    return clampf((t - a) / (b - a), 0.0, 1.0)


func _ease_out(x: float) -> float:
    return 1.0 - pow(1.0 - x, 3.0)


func _ease_in_out(x: float) -> float:
    return x * x * (3.0 - 2.0 * x)


func _play(sound_name: String, at: float, volume_db: float = 0.0) -> void:
    if _skipped or played.has(sound_name) or t < at:
        return
    played[sound_name] = true
    for p in players:
        if not p.playing:
            p.stream = sounds[sound_name]
            p.volume_db = volume_db
            p.play()
            return


func _process(delta: float) -> void:
    t += delta
    _update(delta)
    if t >= TOTAL and not _leaving:
        _go_next()


func _update(delta: float) -> void:
    _play("rev", 0.05, -6.0)
    _play("whoosh", 0.7, -8.0)
    _play("skid", 1.45, -9.0)
    _play("slam", SLAM_AT, -2.0)
    _play("fanfare", SLAM_AT + 0.45, -8.0)

    # Kart chega freando (ease-out) e derrapa no final
    var k := _p(0.0, DRIVE_END)
    kart.position.x = lerpf(-40.0, 0.0, _ease_out(k))
    var drift := sin(_p(0.5, DRIVE_END) * PI) * 0.5
    kart.rotation.y = -PI * 0.5 - drift - 0.10 * _ease_in_out(_p(DRIVE_END, DRIVE_END + 1.0))
    kart.rotation.z = drift * 0.12
    kart.position.y = 0.0 if t < DRIVE_END else 0.006 * sin(t * 70.0)
    dust.emitting = t > 0.9 and t < DRIVE_END + 0.5
    headlight.light_energy = 5.0 * _ease_out(_p(1.6, 2.6))

    # Câmera orbita ao redor do kart e termina de frente para ele
    var p := _ease_in_out(clampf(t / (TOTAL - 0.6), 0.0, 1.0))
    var ang := lerpf(0.30, 1.30, p)
    var radius := lerpf(9.5, 6.4, p)
    var height := lerpf(1.0, 1.7, p)
    var center := kart.position + Vector3(0.0, 0.85, 0.0)
    var pos := center + Vector3(sin(ang) * radius, height - 0.85, cos(ang) * radius)
    _shake = maxf(0.0, _shake - delta * 2.2)
    if t >= SLAM_AT and not played.has("shaken"):
        played["shaken"] = true
        _shake = 1.0
    pos += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.12
    cam.position = pos
    cam.look_at(center, Vector3.UP)
    cam.fov = lerpf(62.0, 44.0, _ease_out(_p(0.0, 3.0)))

    # Título
    var vp := get_viewport().get_visible_rect().size
    var s_in := _p(SLAM_AT, SLAM_AT + 0.4)
    var overshoot := 1.0 + 1.6 * pow(1.0 - s_in, 2.0)
    var title_scale := overshoot if t >= SLAM_AT else 3.0
    title_root.scale = Vector2(title_scale, title_scale)
    title_root.pivot_offset = title_root.size * 0.5
    title_root.position = Vector2(vp.x * 0.5 - title_root.size.x * 0.5, vp.y * 0.07)
    title_root.modulate.a = clampf(s_in * 2.0, 0.0, 1.0) * (1.0 - _p(TOTAL - 0.5, TOTAL))

    sub_label.position = Vector2(vp.x * 0.5 - sub_label.size.x * 0.5, vp.y * 0.07 + 175.0 - 12.0 * (1.0 - _ease_out(_p(SLAM_AT + 0.5, SLAM_AT + 1.1))))
    sub_label.modulate.a = _p(SLAM_AT + 0.5, SLAM_AT + 1.1) * (1.0 - _p(TOTAL - 0.5, TOTAL))

    hint_label.position = Vector2(vp.x * 0.5 - hint_label.size.x * 0.5, vp.y - 56.0)
    hint_label.modulate.a = _p(3.6, 4.2) * (0.35 + 0.35 * sin(t * 4.0)) * (1.0 - _p(TOTAL - 0.5, TOTAL))

    var f := 0.0
    if t >= SLAM_AT:
        f = 0.8 * exp(-(t - SLAM_AT) * 9.0)
    flash.color.a = f
    fade.color.a = _p(TOTAL - 0.45, TOTAL)


func _input(event: InputEvent) -> void:
    if _leaving or t < 0.5:
        return
    var pressed := false
    if event is InputEventKey:
        pressed = event.pressed and not event.echo
    elif event is InputEventScreenTouch:
        pressed = event.pressed
    elif event is InputEventMouseButton:
        pressed = event.pressed
    if pressed:
        _skipped = true
        for p in players:
            p.stop()
        _go_next()


func _go_next() -> void:
    _leaving = true
    Flow.go(next_scene_path, 0.3)
