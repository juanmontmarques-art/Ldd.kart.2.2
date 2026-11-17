class_name LddButton
extends Button

# Botão arcade feito inteiramente de código (nada de imagem): degradê, brilho, contorno,
# inclinação "itálica", ícone vetorial, setas ◄ ► no foco e animação de entrada.
# Funciona com mouse, toque, teclado e controle (foco).

var title := ""
var icon_id := ""
var base := Color(1.0, 0.75, 0.10)
var reveal := 1.0            # 0..1, animação de entrada (deslizar da esquerda)
var show_arrows := true
var font_scale := 0.40
var text_color := Color.WHITE

var _hl := 0.0               # destaque suavizado (0..1)
var _press := 0.0
var _t := 0.0
var _font: FontVariation


func _init(p_title: String = "", p_icon: String = "", p_color: Color = Color(1.0, 0.75, 0.10)) -> void:
    title = p_title
    icon_id = p_icon
    base = Webcore.soften(p_color, 0.58, 0.12)
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    custom_minimum_size = Vector2(300.0, 56.0)
    var empty := StyleBoxEmpty.new()
    for n in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
        add_theme_stylebox_override(n, empty)
    _font = FontVariation.new()
    _font.base_font = ThemeDB.fallback_font
    _font.variation_embolden = 0.9
    _font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.20, 1.0), Vector2.ZERO)
    focus_entered.connect(func() -> void: Flow.ui("click"))
    mouse_entered.connect(func() -> void:
        if not disabled and reveal >= 0.99:
            grab_focus())
    resized.connect(func() -> void: pivot_offset = size * 0.5)


func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    _t += delta
    var active := (has_focus() or is_hovered()) and not disabled
    _hl = lerpf(_hl, 1.0 if active else 0.0, 1.0 - exp(-14.0 * delta))
    var pressed_now := button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
    _press = lerpf(_press, 1.0 if pressed_now else 0.0, 1.0 - exp(-24.0 * delta))
    scale = Vector2.ONE * (1.0 + 0.035 * _hl - 0.03 * _press)
    modulate.a = clampf(reveal * 1.6, 0.0, 1.0)
    queue_redraw()


func _round_rect(r: Rect2, rad: float, seg: int = 7) -> PackedVector2Array:
    var pts := PackedVector2Array()
    var cs: Array = [
        [Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
        [Vector2(r.end.x - rad, r.end.y - rad), 0.0],
        [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
        [Vector2(r.position.x + rad, r.position.y + rad), PI]]
    for corner in cs:
        var cc: Vector2 = corner[0]
        var a0: float = corner[1]
        for i in seg + 1:
            var a := a0 + (PI * 0.5) * float(i) / float(seg)
            pts.append(cc + Vector2(cos(a), sin(a)) * rad)
    return pts


func _grad(pts: PackedVector2Array, top: Color, bottom: Color, y0: float, y1: float) -> PackedColorArray:
    var cols := PackedColorArray()
    for p in pts:
        cols.append(top.lerp(bottom, clampf((p.y - y0) / maxf(y1 - y0, 1.0), 0.0, 1.0)))
    return cols


func _draw() -> void:
    var w := size.x
    var h := size.y
    var k := 0.10                      # inclinação
    var slide := (1.0 - _ease(reveal))
    var press_off := 3.0 * _press
    var margin := h * 0.34 if show_arrows else 4.0
    var body := Rect2(margin, 3.0, w - margin * 2.0, h - 9.0)
    var xoff := -slide * (w * 0.9)
    draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-k, 1.0), Vector2(k * h * 0.5 + xoff, press_off)))

    var rad := body.size.y * 0.30
    var pts := _round_rect(body, rad)
    var c_top := base.lightened(0.30 + 0.12 * _hl)
    var c_bot := base.darkened(0.18 - 0.08 * _hl)
    if disabled:
        c_top = Color(0.45, 0.47, 0.52)
        c_bot = Color(0.25, 0.27, 0.32)

    # sombra de baixo
    var sh := PackedVector2Array()
    for p in pts:
        sh.append(p + Vector2(0.0, 6.0))
    draw_colored_polygon(sh, Color(0.03, 0.02, 0.12, 0.40))
    # contorno escuro grosso
    var outline := pts.duplicate()
    outline.append(pts[0])
    draw_polyline(outline, Webcore.INK, 7.0, true)
    # preenchimento em degradê
    draw_polygon(pts, _grad(pts, c_top, c_bot, body.position.y, body.end.y))
    # brilho superior
    var gl := _round_rect(Rect2(body.position.x + 6.0, body.position.y + 4.0, body.size.x - 12.0, body.size.y * 0.42), rad * 0.7, 5)
    draw_colored_polygon(gl, Color(1, 1, 1, 0.20 + 0.10 * _hl))
    # filete claro por dentro
    var inner := _round_rect(body.grow(-3.5), rad * 0.8, 6)
    inner.append(inner[0])
    draw_polyline(inner, Color(1, 1, 1, 0.30 + 0.35 * _hl), 2.0, true)
    # borda de foco
    if _hl > 0.02:
        var outer := _round_rect(body.grow(3.0), rad * 1.1, 7)
        outer.append(outer[0])
        draw_polyline(outer, Color(1, 1, 1, 0.9 * _hl), 3.0, true)

    # ícone
    var icon_c := Vector2(body.position.x + body.size.y * 0.62, body.position.y + body.size.y * 0.5)
    if icon_id != "":
        LddIcons.draw_icon(self, icon_id, icon_c, body.size.y * 0.74, _t, _hl > 0.5)

    # texto
    var fs := int(body.size.y * font_scale * 1.1)
    var tx0 := body.position.x + body.size.y * 1.12
    var tw := body.end.x - tx0 - body.size.y * 0.25
    while fs > 12 and _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tw:
        fs -= 1
    var base_y := body.position.y + (body.size.y - _font.get_height(fs)) * 0.5 + _font.get_ascent(fs)
    var tcol := text_color if not disabled else Color(0.7, 0.72, 0.78)
    draw_string_outline(_font, Vector2(tx0, base_y + 2.0), title, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, 10, Webcore.INK)
    draw_string(_font, Vector2(tx0, base_y + 2.0), title, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, tcol)

    # setas laterais no foco
    draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(xoff, 0.0)))
    if show_arrows and _hl > 0.02:
        var bounce := sin(_t * 9.0) * h * 0.04
        var ah := h * 0.26
        var cy := h * 0.5 - 2.0
        var gold := Color(0.98, 0.90, 0.58, _hl)
        var ink := Color(0.30, 0.20, 0.35, _hl)
        var lx := margin * 0.5 + bounce
        var left := PackedVector2Array([Vector2(lx - ah * 0.6, cy), Vector2(lx + ah * 0.5, cy - ah), Vector2(lx + ah * 0.5, cy + ah)])
        draw_colored_polygon(left, gold)
        draw_polyline(PackedVector2Array([left[0], left[1], left[2], left[0]]), ink, 3.0, true)
        var rx := w - margin * 0.5 - bounce
        var right := PackedVector2Array([Vector2(rx + ah * 0.6, cy), Vector2(rx - ah * 0.5, cy - ah), Vector2(rx - ah * 0.5, cy + ah)])
        draw_colored_polygon(right, gold)
        draw_polyline(PackedVector2Array([right[0], right[1], right[2], right[0]]), ink, 3.0, true)
    draw_set_transform_matrix(Transform2D.IDENTITY)


func _ease(x: float) -> float:
    var c := clampf(x, 0.0, 1.0)
    return 1.0 - pow(1.0 - c, 3.0)
