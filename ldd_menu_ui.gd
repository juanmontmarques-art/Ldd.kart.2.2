class_name LddMenuUI
extends Control

# Interface do menu principal do LDD KART: tudo é Control do Godot (botões reais,
# foco por teclado/controle, toque). A cena 3D fica atrás.
# Ordem: JOGAR, SELEÇÃO DE KARTS, PERSONALIZAÇÃO, CAMPEONATO, CONFIGURAÇÕES, SAIR.

signal action(id: String)

var buttons: Array[LddButton] = []
var banner: Control
var footer: Control
var column: VBoxContainer
var _overlay: Control
var _reset_armed := false
var _reset_button: LddButton
var _mute_button: LddButton
var _fx_button: LddButton
var _banner_reveal := 0.0
var _footer_reveal := 0.0
var _first_focus_done := false

const ITEMS := [
    {"id": "play", "text": "JOGAR", "icon": "flag", "color": Color(1.00, 0.72, 0.08)},
    {"id": "karts", "text": "SELEÇÃO DE KARTS", "icon": "helmet", "color": Color(0.90, 0.14, 0.12)},
    {"id": "custom", "text": "PERSONALIZAÇÃO", "icon": "palette", "color": Color(0.18, 0.70, 0.22)},
    {"id": "champ", "text": "CAMPEONATO", "icon": "trophy", "color": Color(0.14, 0.42, 0.95)},
    {"id": "config", "text": "CONFIGURAÇÕES", "icon": "gear", "color": Color(0.38, 0.50, 0.70)},
    {"id": "quit", "text": "SAIR", "icon": "door", "color": Color(0.78, 0.10, 0.12)},
]


class Banner extends Control:
    var reveal := 0.0
    var text := "MENU PRINCIPAL"
    var bottom := false
    var font: FontVariation

    func _init() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        font = FontVariation.new()
        font.base_font = ThemeDB.fallback_font
        font.variation_embolden = 0.9
        font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.20, 1.0), Vector2.ZERO)

    func _draw() -> void:
        var w := size.x
        var h := size.y
        var e := 1.0 - pow(1.0 - clampf(reveal, 0.0, 1.0), 3.0)
        var xo := -(1.0 - e) * w
        var yo := (1.0 - e) * h if bottom else 0.0
        draw_set_transform(Vector2(xo, yo), 0.0, Vector2.ONE)
        var cell := h * (0.5 if not bottom else 0.5)
        if bottom:
            draw_rect(Rect2(0, 0, w, h), Color(0.24, 0.22, 0.52))
            draw_rect(Rect2(0, 0, w, 3), Webcore.LILAC)
        else:
            var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - h * 0.5, h), Vector2(0, h)])
            draw_colored_polygon(pts, Color(0.24, 0.22, 0.52, 0.94))
            draw_line(Vector2(h * 1.4, h * 0.90), Vector2(w - h * 0.6, h * 0.62), Webcore.BUTTER, 4.0, true)
        # quadriculado
        var cols := 4 if not bottom else 3
        var rows := 2
        var cw := cell
        for r in rows:
            for c in cols:
                var col := Color.WHITE if (r + c) % 2 == 0 else Webcore.INK
                draw_rect(Rect2(float(c) * cw, float(r) * cw, cw, cw), col)
        var fs := int(h * (0.42 if not bottom else 0.50))
        var x0 := float(cols) * cw + h * 0.35
        var by := (h - font.get_height(fs)) * 0.5 + font.get_ascent(fs) - (h * 0.06 if not bottom else 0.0)
        draw_string_outline(font, Vector2(x0, by), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Webcore.INK)
        draw_string(font, Vector2(x0, by), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    banner = Banner.new()
    add_child(banner)
    banner.anchor_left = 0.0
    banner.anchor_right = 0.40
    banner.anchor_top = 0.035
    banner.anchor_bottom = 0.135

    column = VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(column)
    column.anchor_left = 0.015
    column.anchor_right = 0.425
    column.anchor_top = 0.185
    column.anchor_bottom = 0.925

    for it in ITEMS:
        if String(it["id"]) == "quit" and OS.has_feature("web"):
            continue
        var b := LddButton.new(String(it["text"]), String(it["icon"]), it["color"] as Color)
        b.size_flags_vertical = Control.SIZE_EXPAND_FILL
        b.reveal = 0.0
        var id := String(it["id"])
        b.pressed.connect(func() -> void: _on_pressed(id))
        column.add_child(b)
        buttons.append(b)
    # navegação circular com setas/controle
    for i in buttons.size():
        buttons[i].focus_neighbor_top = buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
        buttons[i].focus_neighbor_bottom = buttons[(i + 1) % buttons.size()].get_path()

    footer = Banner.new()
    (footer as Banner).bottom = true
    (footer as Banner).text = "LAGOA DE DENTRO KART"
    add_child(footer)
    footer.anchor_left = 0.0
    footer.anchor_right = 1.0
    footer.anchor_top = 0.945
    footer.anchor_bottom = 1.0

    var badge := CoinBadge.new()
    footer.add_child(badge)
    badge.anchor_left = 1.0
    badge.anchor_right = 1.0
    badge.anchor_top = 0.5
    badge.anchor_bottom = 0.5
    badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    badge.grow_vertical = Control.GROW_DIRECTION_BOTH
    badge.offset_right = -18.0
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

    _set_interactive(false)


# s = segundos desde o início da animação do menu.
func set_time(s: float) -> void:
    (banner as Banner).reveal = (s - 0.15) / 0.5
    (footer as Banner).reveal = (s - 0.25) / 0.5
    banner.queue_redraw()
    footer.queue_redraw()
    for i in buttons.size():
        buttons[i].reveal = clampf((s - 0.35 - 0.11 * float(i)) / 0.5, 0.0, 1.0)
    var ready_now := s >= 0.35 + 0.11 * float(buttons.size()) + 0.5
    _set_interactive(ready_now)
    if ready_now and not _first_focus_done and _overlay == null:
        _first_focus_done = true
        if not buttons.is_empty():
            buttons[0].grab_focus()


func _set_interactive(on: bool) -> void:
    for b in buttons:
        b.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
        b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


# ------------------------------------------------------------------- ações
func _on_pressed(id: String) -> void:
    match id:
        "play":
            Flow.ui("start")
            action.emit("play")
        "karts":
            Flow.ui("start")
            action.emit("karts")
        "custom":
            Flow.ui("start")
            action.emit("custom")
        "champ":
            Flow.ui("click")
            _show_champ()
        "config":
            Flow.ui("click")
            _show_config()
        "quit":
            Flow.ui("click")
            _show_quit()


func _open_overlay(title: String) -> VBoxContainer:
    _close_overlay(false)
    _overlay = Control.new()
    add_child(_overlay)
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = Color(0.05, 0.04, 0.16, 0.68)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := UIKit.panel(Color(0.15, 0.14, 0.32, 0.97), 22)
    center.add_child(panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    v.custom_minimum_size = Vector2(520.0, 0.0)
    panel.add_child(v)
    var head := UIKit.label(title, 40, UIKit.C_GOLD)
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(head)
    _set_interactive(false)
    return v


func _close_overlay(refocus: bool = true) -> void:
    if _overlay != null:
        _overlay.queue_free()
        _overlay = null
    _reset_armed = false
    if refocus:
        _set_interactive(true)
        if not buttons.is_empty():
            buttons[0].grab_focus()


func _small_button(v: VBoxContainer, text: String, icon: String, color: Color, cb: Callable) -> LddButton:
    var b := LddButton.new(text, icon, color)
    b.custom_minimum_size = Vector2(420.0, 64.0)
    b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    b.show_arrows = false
    b.pressed.connect(cb)
    v.add_child(b)
    return b


func _back_button(v: VBoxContainer, text: String = "VOLTAR") -> void:
    var b := _small_button(v, text, "", Color(0.38, 0.50, 0.70), func() -> void:
        Flow.ui("back")
        _close_overlay())
    b.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and _overlay != null:
        Flow.ui("back")
        _close_overlay()
        get_viewport().set_input_as_handled()


func _show_champ() -> void:
    var v := _open_overlay("CAMPEONATO")
    var msg := UIKit.label("O modo campeonato chega em breve!", 24, UIKit.C_TEXT, false)
    msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(msg)
    var rec := SaveGame.track_records()
    var st := SaveGame.stats()
    var info := UIKit.label("Melhor tempo  %s\nMelhor volta  %s\nCorridas %d   Vitórias %d   Pódios %d" % [
        UIKit.fmt_time(float(rec["best_time"])), UIKit.fmt_time(float(rec["best_lap"])),
        int(st["races"]), int(st["wins"]), int(st["podiums"])], 20, UIKit.C_DIM, false)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(info)
    _small_button(v, "CORRIDA RÁPIDA", "flag", Color(1.00, 0.72, 0.08), func() -> void:
        Flow.ui("start")
        action.emit("quick"))
    _back_button(v)


func _show_config() -> void:
    var v := _open_overlay("CONFIGURAÇÕES")
    _mute_button = _small_button(v, "", "gear", Color(0.14, 0.42, 0.95), func() -> void:
        Flow.ui("click")
        SaveGame.set_muted(not SaveGame.is_muted())
        _update_mute())
    _update_mute()
    _fx_button = _small_button(v, "", "gear", Color(0.52, 0.62, 0.80), func() -> void:
        Flow.ui("click")
        SaveGame.set_fx(not SaveGame.is_fx())
        _update_fx())
    _update_fx()
    _reset_button = _small_button(v, "APAGAR PROGRESSO", "", Color(0.78, 0.10, 0.12), _on_reset)
    v.add_child(UIKit.label("Apaga moedas, desbloqueios e recordes.", 16, UIKit.C_DIM, false))
    _back_button(v)
    _mute_button.grab_focus()


func _update_fx() -> void:
    if _fx_button != null:
        _fx_button.title = "EFEITO RETRÔ: LIGADO" if SaveGame.is_fx() else "EFEITO RETRÔ: DESLIGADO"


func _update_mute() -> void:
    if _mute_button != null:
        _mute_button.title = "SOM: DESLIGADO" if SaveGame.is_muted() else "SOM: LIGADO"


func _on_reset() -> void:
    if not _reset_armed:
        _reset_armed = true
        _reset_button.title = "TOQUE DE NOVO PARA CONFIRMAR"
        get_tree().create_timer(3.0).timeout.connect(func() -> void:
            if _reset_armed and is_instance_valid(_reset_button):
                _reset_armed = false
                _reset_button.title = "APAGAR PROGRESSO")
        return
    _reset_armed = false
    SaveGame.reset_all()
    action.emit("refresh")
    _close_overlay()


func _show_quit() -> void:
    var v := _open_overlay("SAIR DO JOGO?")
    _small_button(v, "SIM, SAIR", "door", Color(0.78, 0.10, 0.12), func() -> void: Flow.quit_game())
    var stay := _small_button(v, "CONTINUAR JOGANDO", "flag", Color(0.18, 0.70, 0.22), func() -> void:
        Flow.ui("back")
        _close_overlay())
    stay.grab_focus()
