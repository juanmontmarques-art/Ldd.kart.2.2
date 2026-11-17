extends Control

# Vinheta da empresa (Beberibe Studios).
# Linha do tempo: raios de luz -> emblema "BS" entra com impacto -> brilho
# metálico -> nome revelado -> linhas azuis -> STUDIOS -> slogan -> fade.
# Toque/clique/tecla pula a vinheta (depois de 0,6 s).

@export_file("*.tscn") var next_scene_path := "res://LddIntro.tscn"

const TOTAL := 5.9
const FADE_START := 5.2

# Camadas do logo: [arquivo, x, y, largura, altura] em coordenadas da imagem original.
const LOGO_ORIGIN := Vector2(119.0, 123.0)
const LOGO_SIZE := Vector2(1298.0, 762.0)
const LAYERS := {
    "emblema": ["res://assets/vinheta/emblema.png", Vector2(353, 123), Vector2(790, 485)],
    "nome": ["res://assets/vinheta/nome.png", Vector2(170, 637), Vector2(1201, 107)],
    "linha_esq": ["res://assets/vinheta/linha_esq.png", Vector2(119, 783), Vector2(258, 24)],
    "studios": ["res://assets/vinheta/studios.png", Vector2(415, 771), Vector2(709, 51)],
    "linha_dir": ["res://assets/vinheta/linha_dir.png", Vector2(1159, 783), Vector2(258, 24)],
    "slogan": ["res://assets/vinheta/slogan.png", Vector2(222, 857), Vector2(1094, 28)],
}

const SHADER_CODE := """
shader_type canvas_item;
uniform float reveal = 1.0;
uniform float dir = 1.0;
uniform float alpha = 1.0;
uniform float shine = -1.0;
uniform float shine_strength = 1.0;
uniform float glow = 0.0;
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float u = dir > 0.0 ? UV.x : 1.0 - UV.x;
    float m = clamp((reveal * 1.15 - u) / 0.15, 0.0, 1.0);
    float d = (UV.x + UV.y * 0.45) - shine;
    float band = exp(-d * d / 0.004);
    vec3 rgb = c.rgb + vec3(1.0) * band * shine_strength * 0.9 + vec3(0.2, 0.5, 1.0) * glow * c.a;
    COLOR = vec4(rgb, c.a * m * alpha);
}
"""

var t := 0.0
var scale_f := 1.0
var sprites := {}
var base_pos := {}
var mats := {}
var sounds := {}
var played := {}
var players: Array[AudioStreamPlayer] = []
var glow_sprite: Sprite2D
var group: Node2D
var flash: ColorRect
var hint: Label
var streaks: Array[Vector4] = []   # x = y(0..1), y = início(s), z = velocidade, w = comprimento
var _leaving := false
var _skipped := false


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    var bg := ColorRect.new()
    bg.color = Color(0.015, 0.025, 0.06)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    # Brilho azul radial ao fundo
    var grad := Gradient.new()
    grad.colors = PackedColorArray([Color(0.10, 0.38, 0.95, 0.60), Color(0.05, 0.15, 0.5, 0.0)])
    grad.offsets = PackedFloat32Array([0.0, 1.0])
    var gt := GradientTexture2D.new()
    gt.gradient = grad
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.5, 0.5)
    gt.fill_to = Vector2(1.0, 0.5)
    gt.width = 512
    gt.height = 512
    glow_sprite = Sprite2D.new()
    glow_sprite.texture = gt
    glow_sprite.modulate.a = 0.0
    add_child(glow_sprite)

    group = Node2D.new()
    add_child(group)
    var shader := Shader.new()
    shader.code = SHADER_CODE
    for key in LAYERS.keys():
        var info: Array = LAYERS[key]
        var spr := Sprite2D.new()
        spr.texture = load(info[0]) as Texture2D
        spr.centered = true
        var mat := ShaderMaterial.new()
        mat.shader = shader
        mat.set_shader_parameter("reveal", 0.0)
        mat.set_shader_parameter("alpha", 0.0)
        mat.set_shader_parameter("shine", -1.0)
        spr.material = mat
        group.add_child(spr)
        sprites[key] = spr
        mats[key] = mat
    mats["linha_dir"].set_shader_parameter("dir", -1.0)
    mats["linha_esq"].set_shader_parameter("dir", 1.0)

    flash = ColorRect.new()
    flash.color = Color(1, 1, 1, 0.0)
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(flash)

    hint = Label.new()
    hint.text = "Toque para pular"
    hint.add_theme_font_size_override("font_size", 18)
    hint.modulate = Color(1, 1, 1, 0.0)
    hint.anchor_left = 0.0
    hint.anchor_right = 1.0
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_top = -44.0
    hint.offset_bottom = -12.0
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hint)

    # Raios de luz
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    for i in 16:
        streaks.append(Vector4(rng.randf_range(0.08, 0.92), rng.randf_range(0.15, 0.75), rng.randf_range(1.6, 3.2), rng.randf_range(0.18, 0.5)))

    # Som sintetizado
    sounds = Sfx.build_intro()
    for i in 4:
        var p := AudioStreamPlayer.new()
        add_child(p)
        players.append(p)

    get_viewport().size_changed.connect(_layout)
    _layout()
    _update(0.0)


func _layout() -> void:
    var vp := get_viewport_rect().size
    scale_f = minf(vp.x * 0.74 / LOGO_SIZE.x, vp.y * 0.78 / LOGO_SIZE.y)
    var center := vp * 0.5
    var logo_center := LOGO_ORIGIN + LOGO_SIZE * 0.5
    for key in LAYERS.keys():
        var info: Array = LAYERS[key]
        var off: Vector2 = info[1]
        var sz: Vector2 = info[2]
        var p := center + ((off + sz * 0.5) - logo_center) * scale_f
        base_pos[key] = p
        sprites[key].position = p
        sprites[key].scale = Vector2(scale_f, scale_f)
    glow_sprite.position = center
    var gs := maxf(vp.x, vp.y) * 1.3 / 512.0
    glow_sprite.scale = Vector2(gs, gs)


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


func _p(a: float, b: float) -> float:
    return clampf((t - a) / (b - a), 0.0, 1.0)


func _ease_out(x: float) -> float:
    return 1.0 - pow(1.0 - x, 3.0)


func _process(delta: float) -> void:
    t += delta
    _update(t)
    if t >= TOTAL and not _leaving:
        _go_next()


func _update(time: float) -> void:
    # Sons
    _play("swell", 0.05, -4.0)
    _play("hit", 0.62, -2.0)
    _play("shine", 1.25, -8.0)
    _play("lines", 2.35, -9.0)
    _play("tick", 3.05, -12.0)
    _play("chime", 3.55, -10.0)

    # Brilho de fundo
    var glow_in := _ease_out(_p(0.1, 1.2))
    var pulse := 1.0 + 0.25 * exp(-maxf(t - 0.62, 0.0) * 3.0) * (1.0 if t >= 0.62 else 0.0)
    var fade_out := 1.0 - _p(FADE_START, TOTAL)
    glow_sprite.modulate.a = glow_in * 0.85 * pulse * fade_out

    # Emblema: entra com impacto
    var e := _ease_out(_p(0.62, 1.15))
    var em: Sprite2D = sprites["emblema"]
    var em_s := lerpf(1.30, 1.0, e) * scale_f
    em.scale = Vector2(em_s, em_s)
    mats["emblema"].set_shader_parameter("reveal", 1.0 if t >= 0.62 else 0.0)
    mats["emblema"].set_shader_parameter("alpha", _p(0.62, 0.85) * fade_out)
    mats["emblema"].set_shader_parameter("shine", lerpf(-0.4, 1.5, _p(1.25, 2.05)))
    mats["emblema"].set_shader_parameter("shine_strength", 1.0)
    mats["emblema"].set_shader_parameter("glow", 0.35 * exp(-maxf(t - 0.62, 0.0) * 2.0) if t >= 0.62 else 0.0)

    # Nome: revelado da esquerda para a direita, deslizando
    var nm := _ease_out(_p(1.75, 2.45))
    mats["nome"].set_shader_parameter("reveal", nm)
    mats["nome"].set_shader_parameter("alpha", _p(1.75, 1.95) * fade_out)
    mats["nome"].set_shader_parameter("shine", lerpf(-0.4, 1.5, _p(3.3, 4.1)))
    sprites["nome"].position = base_pos["nome"] + Vector2(lerpf(-60.0, 0.0, nm) * scale_f, 0.0)

    # Linhas azuis crescem do centro para fora; STUDIOS entra no meio
    var ln := _ease_out(_p(2.4, 2.95))
    mats["linha_esq"].set_shader_parameter("reveal", ln)
    mats["linha_esq"].set_shader_parameter("alpha", _p(2.4, 2.55) * fade_out)
    mats["linha_dir"].set_shader_parameter("reveal", ln)
    mats["linha_dir"].set_shader_parameter("alpha", _p(2.4, 2.55) * fade_out)
    var st := _ease_out(_p(2.6, 3.3))
    mats["studios"].set_shader_parameter("reveal", st)
    mats["studios"].set_shader_parameter("alpha", _p(2.6, 2.9) * fade_out)

    # Slogan
    var sg := _ease_out(_p(3.2, 3.9))
    mats["slogan"].set_shader_parameter("reveal", sg)
    mats["slogan"].set_shader_parameter("alpha", _p(3.2, 3.6) * fade_out)

    # Flash do impacto
    var f := 0.0
    if t >= 0.62:
        f = 0.75 * exp(-(t - 0.62) * 9.0)
    flash.color.a = f

    hint.modulate.a = _p(1.2, 1.8) * 0.45 * fade_out
    queue_redraw()


func _draw() -> void:
    var vp := get_viewport_rect().size
    for s in streaks:
        var start := s.y
        var local := t - start
        if local < 0.0 or local > 1.6:
            continue
        var len_px := s.w * vp.x
        var x := -len_px + local * s.z * vp.x
        var y := s.x * vp.y
        var a := sin(clampf(local / 1.6, 0.0, 1.0) * PI) * 0.55
        draw_line(Vector2(x, y), Vector2(x + len_px, y), Color(0.45, 0.72, 1.0, a), 2.0, true)
        draw_line(Vector2(x + len_px * 0.5, y), Vector2(x + len_px, y), Color(1, 1, 1, a), 2.0, true)


func _input(event: InputEvent) -> void:
    if _leaving or t < 0.6:
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
        t = maxf(t, FADE_START)


func _go_next() -> void:
    _leaving = true
    Flow.go(next_scene_path, 0.4)
