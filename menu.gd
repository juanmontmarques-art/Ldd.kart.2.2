extends Control

# Menu principal: JOGAR (vai para a garagem: personagem -> kart -> corrida),
# CORRIDA RÁPIDA (usa a seleção salva), RECORDES, OPÇÕES e SAIR.
# Mostra o kart + piloto selecionados em 3D e o saldo de moedas.

var _preview: KartPreview
var _caption: Label
var _stats_label: Label
var _overlay: Control
var _first_button: Button
var _mute_button: Button
var _reset_button: Button
var _reset_armed := false


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    Flow.start_menu_music()
    add_child(Backdrop.new())
    _build_preview()
    _build_left_column()
    _build_top_right()
    _refresh_preview()
    if _first_button != null:
        _first_button.grab_focus()


# -------------------------------------------------------------------- layout
func _anchor_rect(c: Control, l: float, t: float, r: float, b: float) -> void:
    c.anchor_left = l
    c.anchor_top = t
    c.anchor_right = r
    c.anchor_bottom = b
    c.offset_left = 0.0
    c.offset_top = 0.0
    c.offset_right = 0.0
    c.offset_bottom = 0.0


func _build_preview() -> void:
    var holder := Control.new()
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(holder)
    _anchor_rect(holder, 0.42, 0.04, 1.0, 0.84)
    _preview = KartPreview.new()
    _preview.mode = "spin"
    holder.add_child(_preview)
    _preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _preview.set_focus(0.0)

    _caption = UIKit.label("", 28, UIKit.C_TEXT)
    _caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_caption)
    _anchor_rect(_caption, 0.42, 0.84, 1.0, 0.92)

    _stats_label = UIKit.label("", 18, UIKit.C_DIM, false)
    _stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_stats_label)
    _anchor_rect(_stats_label, 0.42, 0.92, 1.0, 0.985)
    _stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _build_left_column() -> void:
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 14)
    add_child(col)
    col.position = Vector2(64.0, 40.0)

    var t1 := UIKit.label("KART LIVRE", 66, Color(1, 1, 1))
    t1.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.75))
    t1.add_theme_constant_override("outline_size", 14)
    col.add_child(t1)
    var t2 := UIKit.label("3D", 84, UIKit.C_GOLD)
    t2.add_theme_color_override("font_outline_color", Color(0.55, 0.20, 0.02))
    t2.add_theme_constant_override("outline_size", 14)
    col.add_child(t2)
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0.0, 6.0)
    col.add_child(gap)

    var play := UIKit.button("JOGAR", 34, Vector2(360.0, 76.0), UIKit.C_OK)
    play.pressed.connect(_on_play)
    col.add_child(play)
    _first_button = play

    var quick := UIKit.button("CORRIDA RÁPIDA", 26, Vector2(360.0, 62.0), UIKit.C_ACCENT)
    quick.pressed.connect(_on_quick)
    col.add_child(quick)

    var garage := UIKit.button("GARAGEM", 26, Vector2(360.0, 62.0), UIKit.C_ACCENT)
    garage.pressed.connect(_on_play)
    col.add_child(garage)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    col.add_child(row)
    var rec := UIKit.button("RECORDES", 22, Vector2(174.0, 56.0), UIKit.C_GOLD)
    rec.pressed.connect(_show_records)
    row.add_child(rec)
    var opt := UIKit.button("OPÇÕES", 22, Vector2(174.0, 56.0), UIKit.C_DIM)
    opt.pressed.connect(_show_options)
    row.add_child(opt)

    if not OS.has_feature("web"):
        var quit := UIKit.button("SAIR", 22, Vector2(360.0, 50.0), UIKit.C_BAD)
        quit.pressed.connect(func() -> void: Flow.quit_game())
        col.add_child(quit)


func _build_top_right() -> void:
    var badge := CoinBadge.new()
    add_child(badge)
    badge.anchor_left = 1.0
    badge.anchor_right = 1.0
    badge.offset_right = -22.0
    badge.offset_top = 18.0
    badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _refresh_preview() -> void:
    var ch := Catalog.character(SaveGame.selected_char())
    var kd := Catalog.kart(SaveGame.selected_kart())
    _preview.setup(kd["color"], ch["color"], String(ch["style"]), String(kd["id"]))
    _caption.text = "%s  ·  %s" % [ch["name"], kd["name"]]
    var st := SaveGame.stats()
    _stats_label.text = "Corridas %d   Vitórias %d   Pódios %d" % [int(st["races"]), int(st["wins"]), int(st["podiums"])]


# ------------------------------------------------------------------- ações
func _on_play() -> void:
    Flow.ui("start")
    Flow.go(Flow.SCENE_GARAGEM)


func _on_quick() -> void:
    Flow.ui("start")
    Flow.stop_music()
    Flow.go(Flow.SCENE_RACE)


# ------------------------------------------------------------------ overlays
func _open_overlay(title: String) -> VBoxContainer:
    _close_overlay()
    _overlay = Control.new()
    add_child(_overlay)
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.62)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.gui_input.connect(func(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.pressed:
            _close_overlay())
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := UIKit.panel()
    center.add_child(panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    panel.add_child(v)
    var head := UIKit.label(title, 38, UIKit.C_GOLD)
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(head)
    return v


func _add_close_button(v: VBoxContainer) -> void:
    var b := UIKit.button("VOLTAR", 24, Vector2(240.0, 56.0), UIKit.C_ACCENT)
    b.pressed.connect(func() -> void:
        Flow.ui("back")
        _close_overlay())
    b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    v.add_child(b)
    b.grab_focus()


func _close_overlay() -> void:
    if _overlay != null:
        _overlay.queue_free()
        _overlay = null
    _reset_armed = false
    if _first_button != null and is_inside_tree():
        _first_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and _overlay != null:
        Flow.ui("back")
        _close_overlay()
        get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ recordes
func _show_records() -> void:
    Flow.ui("click")
    var v := _open_overlay("RECORDES")
    var map_id := SaveGame.selected_map()
    var rec := SaveGame.track_records(map_id)
    var track_l := UIKit.label(String(Catalog.map(map_id)["name"]), 24, UIKit.C_DIM, false)
    track_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(track_l)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 40)
    grid.add_theme_constant_override("v_separation", 6)
    v.add_child(grid)
    for mp in Catalog.maps():
        var mr := SaveGame.track_records(String(mp["id"]))
        _grid_row(grid, String(mp["name"]), UIKit.fmt_time(float(mr["best_time"])) + "  /  " + UIKit.fmt_time(float(mr["best_lap"])), UIKit.C_GOLD if SaveGame.is_map_unlocked(String(mp["id"])) else UIKit.C_DIM)
    _grid_row(grid, "(tempo total / melhor volta)", "", UIKit.C_DIM)
    var st := SaveGame.stats()
    _grid_row(grid, "Corridas / Vitórias / Pódios", "%d / %d / %d" % [int(st["races"]), int(st["wins"]), int(st["podiums"])], UIKit.C_TEXT)
    _grid_row(grid, "Moedas ganhas (total)", str(int(st["coins_earned"])), UIKit.C_TEXT)
    _grid_row(grid, "Moedas coletadas na pista", str(int(st["coins_picked"])), UIKit.C_TEXT)

    var top_head := UIKit.label("TOP 5 TEMPOS  ·  " + String(Catalog.map(map_id)["name"]), 22, UIKit.C_ACCENT, false)
    v.add_child(top_head)
    var top: Array = rec["top"]
    if top.is_empty():
        v.add_child(UIKit.label("Ainda sem corridas. Vá para a pista!", 20, UIKit.C_DIM, false))
    for i in top.size():
        var e: Dictionary = top[i]
        var who := "%s · %s" % [Catalog.character(String(e.get("char", "rex")))["name"], Catalog.kart(String(e.get("kart", "classico")))["name"]]
        var line := "%dº   %s    %s    %s" % [i + 1, UIKit.fmt_time(float(e["time"])), who, _fmt_date(String(e.get("date", "")))]
        v.add_child(UIKit.label(line, 20, UIKit.C_TEXT, false))
    _add_close_button(v)


func _grid_row(grid: GridContainer, key: String, value: String, color: Color) -> void:
    grid.add_child(UIKit.label(key, 22, UIKit.C_DIM, false))
    var l := UIKit.label(value, 24, color, false)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    grid.add_child(l)


func _fmt_date(iso: String) -> String:
    var parts := iso.split("-")
    if parts.size() != 3:
        return ""
    return "%s/%s/%s" % [parts[2], parts[1], parts[0]]


# -------------------------------------------------------------------- opções
func _show_options() -> void:
    Flow.ui("click")
    var v := _open_overlay("OPÇÕES")
    v.custom_minimum_size = Vector2(460.0, 0.0)
    _mute_button = UIKit.button("", 24, Vector2(380.0, 60.0), UIKit.C_ACCENT)
    _mute_button.pressed.connect(_toggle_mute)
    v.add_child(_mute_button)
    _update_mute_text()

    _reset_button = UIKit.button("APAGAR PROGRESSO", 22, Vector2(380.0, 56.0), UIKit.C_BAD)
    _reset_button.pressed.connect(_on_reset)
    v.add_child(_reset_button)
    v.add_child(UIKit.label("Apaga moedas, desbloqueios e recordes.", 16, UIKit.C_DIM, false))
    var unlock_btn := UIKit.button("LIBERAR TUDO (TESTE)", 20, Vector2(380.0, 50.0), UIKit.C_GOLD)
    unlock_btn.pressed.connect(func() -> void:
        Flow.ui("unlock")
        SaveGame.unlock_everything()
        _refresh_preview()
        unlock_btn.text = "TUDO LIBERADO!")
    v.add_child(unlock_btn)
    _add_close_button(v)


func _toggle_mute() -> void:
    Flow.ui("click")
    SaveGame.set_muted(not SaveGame.is_muted())
    _update_mute_text()


func _update_mute_text() -> void:
    if _mute_button != null:
        _mute_button.text = "SOM: DESLIGADO" if SaveGame.is_muted() else "SOM: LIGADO"


func _on_reset() -> void:
    if not _reset_armed:
        _reset_armed = true
        _reset_button.text = "TOQUE DE NOVO PARA CONFIRMAR"
        get_tree().create_timer(3.0).timeout.connect(func() -> void:
            if _reset_armed and is_instance_valid(_reset_button):
                _reset_armed = false
                _reset_button.text = "APAGAR PROGRESSO")
        return
    _reset_armed = false
    SaveGame.reset_all()
    _refresh_preview()
    _close_overlay()
