class_name WonderlandCinematic
extends RefCounted

# Abertura cinematográfica (pula com qualquer tecla/toque): panorama da montanha, voo pelos setores (cume, queda livre,
# abismo, caverna, labirinto de cristais, inferno), depois a câmera de largada. A câmera normal de corrida segue funcionando
# (esta só assume durante a introdução) + efeito de velocidade e transições.

var world: Node3D
var main: Node
var track: TrackData
var layout: Dictionary
var active := false
var started := false
var t := 0.0
var keys: Array = []
var total := 0.0
var bars_top: ColorRect
var bars_bot: ColorRect
var title: Label
var hint: Label
var speed_fx: ColorRect
var fx_mat: ShaderMaterial
var layer: CanvasLayer
var shown_sector := 0

const SPEED_SHADER := "shader_type canvas_item;
uniform float amount = 0.0;
void fragment(){
    vec2 uv = UV - 0.5;
    float r = length(uv);
    float a = atan(uv.y, uv.x);
    float streak = smoothstep(0.55, 1.0, fract(sin(floor(a * 60.0) * 91.7) * 437.5 + TIME * 0.0));
    float m = smoothstep(0.25, 0.7, r) * streak * amount;
    COLOR = vec4(1.0, 1.0, 1.0, m * 0.35);
}
"


func setup(w: Node3D, m: Node, tr: TrackData, lay: Dictionary) -> void:
    world = w
    main = m
    track = tr
    layout = lay
    active = true
    layer = CanvasLayer.new()
    layer.layer = 15
    main.add_child(layer)
    bars_top = ColorRect.new()
    bars_top.color = Color(0, 0, 0, 1)
    bars_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    bars_top.custom_minimum_size = Vector2(0, 80)
    bars_top.size = Vector2(1280, 80)
    bars_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(bars_top)
    bars_bot = ColorRect.new()
    bars_bot.color = Color(0, 0, 0, 1)
    bars_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bars_bot.custom_minimum_size = Vector2(0, 80)
    bars_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(bars_bot)
    title = Label.new()
    title.add_theme_font_size_override("font_size", 64)
    title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
    title.add_theme_constant_override("outline_size", 14)
    title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    title.position = Vector2(-450, -230)
    title.custom_minimum_size = Vector2(900, 80)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.modulate.a = 0.0
    layer.add_child(title)
    hint = Label.new()
    hint.text = "toque / tecla para pular"
    hint.add_theme_font_size_override("font_size", 20)
    hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    hint.position = Vector2(-300, -50)
    hint.modulate = Color(1, 1, 1, 0.7)
    layer.add_child(hint)
    var sh := Shader.new()
    sh.code = SPEED_SHADER
    fx_mat = ShaderMaterial.new()
    fx_mat.shader = sh
    speed_fx = ColorRect.new()
    speed_fx.material = fx_mat
    speed_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
    speed_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(speed_fx)
    # roteiro: [tempo, tipo, dados...]  't' = relativo à pista (idx, altura, lateral, olhar à frente); 'w' = absoluto
    var p0 := track.pts[0]
    var tn := track.tans[0]
    keys = [
        {"t": 0.0, "k": "w", "pos": p0 + Vector3(-420, 260, -520), "look": p0 + Vector3(300, -40, 40), "title": "WONDERLAND"},
        {"t": 4.0, "k": "w", "pos": p0 + Vector3(-110, 70, -170), "look": p0 + Vector3(380, -10, 40), "title": ""},
        {"t": 4.1, "k": "t", "idx": 40, "h": 14.0, "off": -4.0, "ahead": 70.0, "title": "1 · THE EDGE"},
        {"t": 8.5, "k": "t", "idx": 420, "h": 12.0, "off": 6.0, "ahead": 80.0, "title": ""},
        {"t": 12.0, "k": "t", "idx": 840, "h": 16.0, "off": 0.0, "ahead": 90.0, "title": "2 · FREEFALL"},
        {"t": 14.5, "k": "t", "idx": 1140, "h": 55.0, "off": 12.0, "ahead": 70.0, "title": "3 · THE ABYSS"},
        {"t": 18.0, "k": "t", "idx": 1560, "h": 30.0, "off": 5.0, "ahead": 80.0, "title": ""},
        {"t": 18.5, "k": "t", "idx": 1710, "h": 9.0, "off": 0.0, "ahead": 60.0, "title": "4 · UNDERWORLD"},
        {"t": 22.0, "k": "t", "idx": 2150, "h": 10.0, "off": -4.0, "ahead": 60.0, "title": ""},
        {"t": 22.4, "k": "t", "idx": 2290, "h": 7.0, "off": 0.0, "ahead": 50.0, "title": "5 · CRYSTAL LABYRINTH"},
        {"t": 25.0, "k": "t", "idx": 2640, "h": 7.0, "off": 0.0, "ahead": 50.0, "title": ""},
        {"t": 25.4, "k": "t", "idx": 2760, "h": 14.0, "off": 0.0, "ahead": 70.0, "title": "6 · THE INFERNO"},
        {"t": 28.0, "k": "t", "idx": 3100, "h": 14.0, "off": 0.0, "ahead": 70.0, "title": "7 · GRAVITY BREAK · 8 · THE ASCENT"},
    ]
    total = 28.0


func _sector_name(idx: int) -> String:
    return ""


func skip() -> void:
    if active:
        t = maxf(t, total - 1.2)


func _eval(time: float) -> Array:
    var k0: Dictionary = keys[0]
    var k1: Dictionary = keys[0]
    for q in keys.size():
        if keys[q]["t"] <= time:
            k0 = keys[q]
            k1 = keys[mini(q + 1, keys.size() - 1)]
    var span := maxf(float(k1["t"]) - float(k0["t"]), 0.001)
    var u := clampf((time - float(k0["t"])) / span, 0.0, 1.0)
    if k0 == k1:
        u = 1.0
    var s := u * u * (3.0 - 2.0 * u) if k0["k"] != k1["k"] or k0["k"] == "w" else u
    var pa := _abs(k0, 0.0)
    var pb := _abs(k1, 0.0)
    if k0["k"] == "t" and k1["k"] == "t":
        var idx := lerpf(float(k0["idx"]), float(k1["idx"]), u)
        var h := lerpf(float(k0["h"]), float(k1["h"]), s)
        var off := lerpf(float(k0["off"]), float(k1["off"]), s)
        var ah := lerpf(float(k0["ahead"]), float(k1["ahead"]), s)
        return _track_pose(idx, h, off, ah)
    var pos := (pa[0] as Vector3).lerp(pb[0], s)
    var look := (pa[1] as Vector3).lerp(pb[1], s)
    return [pos, look, int(k0.get("idx", 0))]


func _abs(k: Dictionary, _unused: float) -> Array:
    if k["k"] == "w":
        return [k["pos"], k["look"], 0]
    return _track_pose(float(k["idx"]), float(k["h"]), float(k["off"]), float(k["ahead"]))


func _track_pose(idx: float, h: float, off: float, ahead: float) -> Array:
    var n := track.count
    var i := clampi(int(idx), 0, n - 1)
    var j := (i + int(ahead / TrackData.SPACING)) % n
    var u: Vector3 = track.ups[i]
    var pos := track.pts[i] + u * h + track.sides[i] * off - track.tans[i] * 6.0
    var look := track.pts[j] + track.ups[j] * 2.0
    return [pos, look, i]


func update(camera: Camera3D, delta: float) -> bool:
    if not started:
        started = true
        active = true
        t = 0.0
        # congela a contagem regressiva até o fim da introdução
        main.state = 0
    t += delta
    if t >= total:
        active = false
        main.state = 1
        main.countdown = 3.99
        bars_top.visible = false
        bars_bot.visible = false
        title.visible = false
        hint.visible = false
        speed_fx.visible = false
        return false
    var pose := _eval(t)
    var target_pos: Vector3 = pose[0]
    var look: Vector3 = pose[1]
    camera.global_position = camera.global_position.lerp(target_pos, 1.0 - exp(-10.0 * delta)) if t > 0.3 else target_pos
    camera.look_at(look, Vector3.UP)
    camera.fov = 70.0 + 10.0 * sin(t * 0.4)
    # transição final: barras recuam e a câmera volta ao kart
    var end_f := clampf((t - (total - 1.2)) / 1.2, 0.0, 1.0)
    if end_f > 0.0:
        var kp: Vector3 = main.player.body.global_position
        var back := Vector3(sin(main.cam_yaw), 0.0, cos(main.cam_yaw))
        var want := kp + back * 7.4 + Vector3(0, 3.3, 0)
        camera.global_position = camera.global_position.lerp(want, end_f)
        camera.look_at(kp.lerp(camera.global_position, 0.0) + Vector3(0, 1.1, 0), Vector3.UP)
    var bar_h := lerpf(80.0, 0.0, end_f)
    bars_top.size.y = bar_h
    bars_bot.custom_minimum_size.y = bar_h
    bars_bot.size.y = bar_h
    bars_bot.position.y = bars_bot.get_viewport_rect().size.y - bar_h
    # título do setor com fade
    var cur_title := ""
    var tt := 0.0
    for q in keys.size():
        if keys[q]["t"] <= t and String(keys[q]["title"]) != "":
            cur_title = String(keys[q]["title"])
            tt = t - float(keys[q]["t"])
    title.text = cur_title
    title.modulate.a = clampf(minf(tt, 2.6 - tt), 0.0, 1.0)
    fx_mat.set_shader_parameter("amount", 0.6 if t > 4.0 and t < total - 2.0 else 0.0)
    # névoa/luz do setor correspondente
    world.env_mod.apply_index(int(pose[2]), delta)
    main.center_label.text = ""
    return true


func race_fx(ratio: float) -> void:
    if active:
        return
    speed_fx.visible = true
    fx_mat.set_shader_parameter("amount", clampf((ratio - 0.85) * 2.0, 0.0, 1.0))
