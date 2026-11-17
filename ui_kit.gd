class_name UIKit
extends RefCounted

# Peças de interface compartilhadas pelas telas (mesma cara em todo o jogo).

const C_PANEL := Color(0.11, 0.10, 0.24, 0.92)
const C_ACCENT := Webcore.LILAC
const C_GOLD := Color(0.97, 0.88, 0.55)
const C_TEXT := Color(0.95, 0.95, 1.0)
const C_DIM := Color(0.70, 0.70, 0.86)
const C_OK := Webcore.MINT
const C_BAD := Color(0.96, 0.54, 0.54)


static func box(color: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), border_w: int = 0, margin_x: float = 14.0, margin_y: float = 8.0) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.corner_radius_top_left = radius
    s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius
    s.corner_radius_bottom_right = radius
    s.border_width_left = border_w
    s.border_width_right = border_w
    s.border_width_top = border_w
    s.border_width_bottom = border_w
    s.border_color = border
    s.content_margin_left = margin_x
    s.content_margin_right = margin_x
    s.content_margin_top = margin_y
    s.content_margin_bottom = margin_y
    return s


# Caixa "janela de sistema": cantos quase retos, borda clara e sombra dura deslocada.
static func win_box(color: Color, border: Color, border_w: int = 3, margin_x: float = 14.0, margin_y: float = 8.0, shadow: int = 4) -> StyleBoxFlat:
    var s := box(color, 5, border, border_w, margin_x, margin_y)
    if shadow > 0:
        s.shadow_color = Color(0.03, 0.02, 0.10, 0.55)
        s.shadow_size = 1
        s.shadow_offset = Vector2(shadow, shadow)
    return s


static func label(text: String, font_size: int = 22, color: Color = C_TEXT, outline: bool = true) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    if outline:
        l.add_theme_color_override("font_outline_color", Color(Webcore.INK.r, Webcore.INK.g, Webcore.INK.b, 0.85))
        l.add_theme_constant_override("outline_size", maxi(3, font_size / 6))
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


static func panel(color: Color = C_PANEL, radius: int = 18) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", win_box(color, Webcore.LILAC.darkened(0.15), 3, 20.0, 16.0, 5))
    return p


# Botão grande, bom para toque. "accent" define a cor da borda/realce.
static func button(text: String, font_size: int = 26, min_size: Vector2 = Vector2(300, 64), accent: Color = C_ACCENT) -> Button:
    var acc := Webcore.soften(accent, 0.70, 0.10)
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.focus_mode = Control.FOCUS_ALL
    b.add_theme_font_size_override("font_size", font_size)
    b.add_theme_color_override("font_color", C_TEXT)
    b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
    b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
    b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.68))
    b.add_theme_stylebox_override("normal", win_box(acc.darkened(0.55), acc.lightened(0.10), 3, 18.0, 8.0, 4))
    b.add_theme_stylebox_override("hover", win_box(acc.darkened(0.40), acc.lightened(0.30), 3, 18.0, 8.0, 4))
    var pr := win_box(acc.darkened(0.25), Color(1, 1, 1), 3, 18.0, 8.0, 1)
    b.add_theme_stylebox_override("pressed", pr)
    b.add_theme_stylebox_override("disabled", win_box(Color(0.14, 0.13, 0.22, 0.9), Color(0.34, 0.33, 0.46), 3, 18.0, 8.0, 2))
    b.add_theme_stylebox_override("focus", win_box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), 3, 18.0, 8.0, 0))
    return b


# Linha "NOME [barra]" para status (velocidade etc.). Retorna a barra para atualizar o valor (0..1).
static func stat_row(parent: Control, title: String, width: float = 260.0) -> ProgressBar:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    var l := label(title, 18, C_DIM, false)
    l.custom_minimum_size = Vector2(118.0, 0.0)
    row.add_child(l)
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(width, 16.0)
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    bar.min_value = 0.0
    bar.max_value = 1.0
    bar.value = 0.5
    bar.show_percentage = false
    bar.add_theme_stylebox_override("background", box(Color(0.03, 0.02, 0.10, 0.60), 3, Webcore.WIN_DARK, 2, 0.0, 0.0))
    bar.add_theme_stylebox_override("fill", box(Webcore.AQUA, 2, Color(0, 0, 0, 0), 0, 0.0, 0.0))
    row.add_child(bar)
    return bar


static func fmt_time(t: float) -> String:
    if t <= 0.0:
        return "--:--.--"
    return "%d:%05.2f" % [int(floor(t / 60.0)), fmod(t, 60.0)]
