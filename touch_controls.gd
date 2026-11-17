class_name TouchControls
extends Control

# Controles de toque estilo kart de console:
#  - Joystick analógico "flutuante" no lado esquerdo: aparece onde o dedo encosta,
#    move para qualquer direção. Horizontal = direção (com curva suave e zona
#    morta pequena), para cima = acelera, para baixo = freio/ré.
#  - Botões redondos grandes à direita: ACELERAR, FREIO, NITRO (e reiniciar posição).
# Cada dedo é rastreado por índice (multitoque real). O mouse vira toque pelo
# project.godot (emulate_touch_from_mouse), então o código é um só.

signal respawn_requested
signal item_requested
signal mute_toggled

const JOY_RADIUS := 92.0
const KNOB_RADIUS := 38.0
const STEER_DEADZONE := 0.07
const STEER_FULL_AT := 0.82
const STEER_CURVE := 1.35

var item_name := ""
var muted := false
var _joy_id := -999
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _buttons: Dictionary = {}   # índice do dedo -> nome do botão
var _applied: Dictionary = {}


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    _joy_origin = _default_joy_origin()
    get_viewport().size_changed.connect(_on_resized)


func _on_resized() -> void:
    if _joy_id == -999:
        _joy_origin = _default_joy_origin()
    queue_redraw()


func _view() -> Vector2:
    return get_viewport_rect().size


func _default_joy_origin() -> Vector2:
    var v := _view()
    return Vector2(JOY_RADIUS + 44.0, v.y - JOY_RADIUS - 44.0)


# --- Posição dos botões (ancorados no canto inferior direito) ---
func _accel_center() -> Vector2:
    var v := _view()
    return Vector2(v.x - 128.0, v.y - 128.0)


func _button_center(action: String) -> Vector2:
    var a := _accel_center()
    if action == "accelerate":
        return a
    if action == "brake":
        return a + Vector2(-172.0, 26.0)
    if action == "nitro":
        return a + Vector2(-100.0, -158.0)
    if action == "item":
        return a + Vector2(-252.0, -120.0)
    if action == "reset":
        return Vector2(_view().x - 262.0, 52.0)
    if action == "mute":
        return Vector2(_view().x - 322.0, 52.0)
    return Vector2.ZERO


func _button_radius(action: String) -> float:
    if action == "accelerate":
        return 86.0
    if action == "brake":
        return 56.0
    if action == "nitro":
        return 58.0
    if action == "item":
        return 52.0
    if action == "mute":
        return 24.0
    return 28.0


func _button_at(pos: Vector2) -> String:
    for action in ["accelerate", "nitro", "brake", "item", "reset", "mute"]:
        if pos.distance_to(_button_center(action)) <= _button_radius(action) + 14.0:
            return action
    return ""


# --- Entrada ---
func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _begin(touch.index, touch.position)
        else:
            _end(touch.index)
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        _move(drag.index, drag.position)


func _begin(id: int, pos: Vector2) -> void:
    var v := _view()
    var button := _button_at(pos)
    if button != "":
        if button == "reset":
            respawn_requested.emit()
        elif button == "item":
            item_requested.emit()
        elif button == "mute":
            mute_toggled.emit()
        else:
            _buttons[id] = button
    elif _joy_id == -999 and pos.x < v.x * 0.52 and pos.y > v.y * 0.18:
        _joy_id = id
        _joy_origin = Vector2(
            clampf(pos.x, JOY_RADIUS + 16.0, v.x * 0.5 - JOY_RADIUS * 0.4),
            clampf(pos.y, v.y * 0.40, v.y - JOY_RADIUS - 16.0))
        _update_joy(pos)
    _refresh()


func _move(id: int, pos: Vector2) -> void:
    if id == _joy_id:
        _update_joy(pos)
    elif _buttons.has(id):
        # Deslizar o dedo de um botão para outro troca a ação.
        var b := _button_at(pos)
        if b == "" or b == "reset" or b == "item" or b == "mute":
            _buttons.erase(id)
        else:
            _buttons[id] = b
    _refresh()


func _end(id: int) -> void:
    if id == _joy_id:
        _joy_id = -999
        _joy_vec = Vector2.ZERO
        _joy_origin = _default_joy_origin()
    _buttons.erase(id)
    _refresh()


func _update_joy(pos: Vector2) -> void:
    var d := (pos - _joy_origin) / JOY_RADIUS
    if d.length() > 1.0:
        d = d.normalized()
    _joy_vec = d


func _is_down(action: String) -> bool:
    for a in _buttons.values():
        if a == action:
            return true
    return false


func _refresh() -> void:
    # Direção analógica: zona morta pequena + curva (mais precisão perto do centro).
    var x := _joy_vec.x
    var mag := clampf((absf(x) - STEER_DEADZONE) / (STEER_FULL_AT - STEER_DEADZONE), 0.0, 1.0)
    var steer_val := signf(x) * pow(mag, STEER_CURVE)

    var up := -_joy_vec.y
    var down := _joy_vec.y
    var joy_throttle := 0.0
    if up > 0.35:
        joy_throttle = clampf((up - 0.35) / 0.4, 0.0, 1.0)
    var joy_brake := 0.0
    if down > 0.62 and down > absf(x) * 1.2:
        joy_brake = clampf((down - 0.62) / 0.3, 0.0, 1.0)

    _set_action("steer_left", maxf(-steer_val, 0.0))
    _set_action("steer_right", maxf(steer_val, 0.0))
    _set_action("accelerate", maxf(1.0 if _is_down("accelerate") else 0.0, joy_throttle))
    _set_action("brake", maxf(1.0 if _is_down("brake") else 0.0, joy_brake))
    _set_action("nitro", 1.0 if _is_down("nitro") else 0.0)
    queue_redraw()


func _set_action(action: String, strength: float) -> void:
    if not InputMap.has_action(action):
        return
    if strength > 0.001:
        Input.action_press(action, clampf(strength, 0.0, 1.0))
        _applied[action] = true
    elif _applied.has(action):
        Input.action_release(action)
        _applied.erase(action)


# --- Desenho ---
func _draw() -> void:
    _draw_joystick()
    _draw_round_button("accelerate", Color(0.16, 0.74, 0.30), "ACELERAR")
    _draw_round_button("brake", Color(0.90, 0.24, 0.20), "FREIO")
    _draw_round_button("nitro", Color(0.16, 0.55, 0.95), "NITRO")
    _draw_reset_button()
    _draw_item_button()
    _draw_mute_button()


func _draw_joystick() -> void:
    var active := _joy_id != -999
    var alpha := 1.0 if active else 0.6
    var c := _joy_origin
    draw_circle(c + Vector2(0.0, 5.0), JOY_RADIUS, Color(0, 0, 0, 0.22 * alpha))
    draw_circle(c, JOY_RADIUS, Color(0.05, 0.10, 0.16, 0.36 * alpha))
    draw_arc(c, JOY_RADIUS, 0.0, TAU, 72, Color(1, 1, 1, 0.75 * alpha), 4.0, true)
    draw_arc(c, JOY_RADIUS * 0.5, 0.0, TAU, 48, Color(1, 1, 1, 0.20 * alpha), 2.0, true)
    # Setinhas indicando que o joystick vai para todas as direções.
    var tri := Color(1, 1, 1, 0.5 * alpha)
    var r := JOY_RADIUS - 16.0
    draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(-9, -r + 14), c + Vector2(9, -r + 14)]), tri)
    draw_colored_polygon(PackedVector2Array([c + Vector2(0, r), c + Vector2(-9, r - 14), c + Vector2(9, r - 14)]), tri)
    draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r + 14, -9), c + Vector2(-r + 14, 9)]), tri)
    draw_colored_polygon(PackedVector2Array([c + Vector2(r, 0), c + Vector2(r - 14, -9), c + Vector2(r - 14, 9)]), tri)
    var k := c + _joy_vec * JOY_RADIUS
    draw_circle(k + Vector2(0.0, 4.0), KNOB_RADIUS, Color(0, 0, 0, 0.3 * alpha))
    draw_circle(k, KNOB_RADIUS, Color(Webcore.AQUA.r, Webcore.AQUA.g, Webcore.AQUA.b, 0.95 * alpha))
    draw_arc(k, KNOB_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.95 * alpha), 4.0, true)
    draw_circle(k + Vector2(-10, -12), 9.0, Color(1, 1, 1, 0.40 * alpha))


func _draw_round_button(action: String, base: Color, label: String) -> void:
    var pressed := _is_down(action)
    var c := _button_center(action)
    var r := _button_radius(action) * (0.94 if pressed else 1.0)
    var soft := Webcore.soften(base, 0.62, 0.10)
    var fill := soft.lightened(0.22) if pressed else soft
    draw_circle(c + Vector2(0.0, 7.0), r, Color(0, 0, 0, 0.30))
    draw_circle(c, r, Color(fill.r, fill.g, fill.b, 0.90))
    draw_circle(c, r * 0.82, Color(fill.darkened(0.12).r, fill.darkened(0.12).g, fill.darkened(0.12).b, 0.55))
    draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.95), 5.0, true)
    draw_arc(c, r * 0.80, PI * 1.05, PI * 1.65, 24, Color(1, 1, 1, 0.45), 4.0, true)
    var white := Color(1, 1, 1, 0.98)
    if action == "accelerate":
        var w := r * 0.30
        for off in [-0.05, 0.22]:
            var y: float = c.y + r * off
            draw_polyline(PackedVector2Array([Vector2(c.x - w, y + w * 0.5), Vector2(c.x, y - w * 0.5), Vector2(c.x + w, y + w * 0.5)]), white, 9.0, true)
    elif action == "nitro":
        var s := r / 58.0
        var bolt := PackedVector2Array([
            c + Vector2(-5, -30) * s, c + Vector2(15, -30) * s, c + Vector2(4, -8) * s,
            c + Vector2(17, -8) * s, c + Vector2(-9, 30) * s, c + Vector2(-2, 3) * s,
            c + Vector2(-15, 3) * s])
        draw_colored_polygon(bolt, Color(1.0, 0.92, 0.25))
    elif action == "brake":
        var bw := r * 0.46
        draw_rect(Rect2(c.x - bw * 0.5, c.y - bw * 0.95, bw, bw), white, true)
    var font := ThemeDB.fallback_font
    var fs := 22 if action == "accelerate" else 17
    var ty := c.y + r * (0.66 if action == "accelerate" else 0.74)
    if action == "brake":
        ty = c.y + r * 0.72
    draw_string_outline(font, Vector2(c.x - r, ty), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 6, Color(0, 0, 0, 0.55))
    draw_string(font, Vector2(c.x - r, ty), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, white)


func _draw_reset_button() -> void:
    var c := _button_center("reset")
    var r := _button_radius("reset")
    draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.28))
    draw_circle(c, r, Color(0.10, 0.16, 0.24, 0.78))
    draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 3.0, true)
    draw_arc(c, r * 0.5, PI * 0.25, PI * 1.85, 24, Color(1, 1, 1, 0.95), 4.0, true)
    var tip := c + Vector2(cos(PI * 0.25), sin(PI * 0.25)) * (r * 0.5)
    draw_colored_polygon(PackedVector2Array([tip + Vector2(-2, -9), tip + Vector2(11, 3), tip + Vector2(-9, 5)]), Color(1, 1, 1, 0.95))


func _draw_item_button() -> void:
    var c := _button_center("item")
    var r := _button_radius("item")
    var has := item_name != ""
    var base := Color(0.62, 0.32, 0.92) if has else Color(0.32, 0.28, 0.42)
    var white := Color(1, 1, 1, 0.96)
    draw_circle(c + Vector2(0.0, 6.0), r, Color(0, 0, 0, 0.30))
    draw_circle(c, r, Color(base.r, base.g, base.b, 0.88))
    draw_arc(c, r, 0.0, TAU, 56, white, 5.0, true)
    var label := "ITEM"
    if item_name == "turbo":
        draw_circle(c + Vector2(0.0, -8.0), r * 0.40, Color(0.92, 0.20, 0.20))
        draw_circle(c + Vector2(-10.0, -12.0), 6.0, white)
        draw_circle(c + Vector2(9.0, -8.0), 5.0, white)
        draw_circle(c + Vector2(0.0, -22.0), 4.0, white)
        draw_rect(Rect2(c.x - 8.0, c.y + 6.0, 16.0, 13.0), Color(0.98, 0.90, 0.70), true)
        label = "TURBO"
    elif item_name == "banana":
        draw_arc(c + Vector2(0.0, -8.0), r * 0.42, PI * 0.12, PI * 0.88, 24, Color(1.0, 0.88, 0.15), 12.0, true)
        label = "BANANA"
    elif item_name == "casco":
        draw_circle(c + Vector2(0.0, -6.0), r * 0.40, Color(0.90, 0.15, 0.12))
        draw_arc(c + Vector2(0.0, -6.0), r * 0.40, 0.0, TAU, 32, white, 4.0, true)
        draw_rect(Rect2(c.x - r * 0.40, c.y - 9.0, r * 0.80, 6.0), white, true)
        label = "CASCO"
    else:
        var qf := ThemeDB.fallback_font
        draw_string(qf, Vector2(c.x - r, c.y + 4.0), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 34, Color(1, 1, 1, 0.55))
    var font := ThemeDB.fallback_font
    var ty := c.y + r * 0.78
    draw_string_outline(font, Vector2(c.x - r, ty), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 14, 5, Color(0, 0, 0, 0.55))
    draw_string(font, Vector2(c.x - r, ty), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 14, white)


func _draw_mute_button() -> void:
    var c := _button_center("mute")
    var r := _button_radius("mute")
    var white := Color(1, 1, 1, 0.95)
    draw_circle(c + Vector2(0.0, 4.0), r, Color(0, 0, 0, 0.28))
    draw_circle(c, r, Color(0.10, 0.16, 0.24, 0.78))
    draw_arc(c, r, 0.0, TAU, 32, white, 3.0, true)
    draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -4), c + Vector2(-3, -4), c + Vector2(4, -10), c + Vector2(4, 10), c + Vector2(-3, 4), c + Vector2(-9, 4)]), white)
    if muted:
        draw_line(c + Vector2(-12, 12), c + Vector2(12, -12), Color(1.0, 0.3, 0.25), 4.0, true)
    else:
        draw_arc(c + Vector2(3, 0), 8.0, -0.9, 0.9, 12, white, 2.5, true)
        draw_arc(c + Vector2(3, 0), 13.0, -0.9, 0.9, 12, white, 2.5, true)


func _exit_tree() -> void:
    for action in _applied.keys():
        Input.action_release(action)
    _applied.clear()
