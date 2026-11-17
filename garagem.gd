extends Control

# Garagem: passo 1 = PILOTO, passo 2 = KART, passo 3 = PISTA, depois CORRIDA.
# Itens bloqueados podem ser comprados com moedas (ou mostram a conquista necessária).
# A seleção é gravada no SaveGame, então o menu e a corrida usam o que foi escolhido aqui.

enum Step { CHARACTER, KART, MAP }

var step: Step = Step.CHARACTER
var _char_id := ""    # piloto que está sendo visto (pode estar bloqueado)
var _kart_id := ""    # kart que está sendo visto (pode estar bloqueado)
var _map_id := ""     # pista que está sendo vista (pode estar bloqueada)
var _map_preview: MapPreview
var _bar_titles: Array[Label] = []

var _preview: KartPreview
var _back_button: Button
var _step_labels: Array[Label] = []
var _name_label: Label
var _title_label: Label
var _desc_label: Label
var _perk_label: Label
var _req_label: Label
var _action_button: Button
var _bars: Array[ProgressBar] = []
var _card_row: HBoxContainer
var _cards: Dictionary = {}      # id -> Button
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    Flow.start_menu_music()
    add_child(Backdrop.new())
    _char_id = SaveGame.selected_char()
    _kart_id = SaveGame.selected_kart()
    _map_id = SaveGame.selected_map()
    _build_ui()
    SaveGame.coins_changed.connect(func(_total: int) -> void: _refresh())
    var first := Step.KART if Flow.garage_step == 1 else Step.CHARACTER
    Flow.garage_step = 0
    _set_step(first)
    _action_button.grab_focus()


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


func _build_ui() -> void:
    # Barra superior: voltar | passos | moedas
    _back_button = UIKit.button("‹  MENU", 22, Vector2(170.0, 52.0), UIKit.C_DIM)
    _back_button.pressed.connect(_on_back)
    add_child(_back_button)
    _back_button.position = Vector2(22.0, 16.0)

    var steps := HBoxContainer.new()
    steps.add_theme_constant_override("separation", 10)
    steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(steps)
    steps.anchor_left = 0.5
    steps.anchor_right = 0.5
    steps.offset_top = 20.0
    steps.grow_horizontal = Control.GROW_DIRECTION_BOTH
    for txt in ["1  PILOTO", "2  KART", "3  PISTA", "4  CORRIDA"]:
        var l := UIKit.label(txt, 22, UIKit.C_DIM, false)
        l.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0.35), 16, Color(0, 0, 0, 0), 0, 16.0, 6.0))
        steps.add_child(l)
        _step_labels.append(l)

    var badge := CoinBadge.new()
    add_child(badge)
    badge.anchor_left = 1.0
    badge.anchor_right = 1.0
    badge.offset_right = -22.0
    badge.offset_top = 18.0
    badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN

    # Vitrine 3D
    var holder := Control.new()
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(holder)
    _anchor_rect(holder, 0.01, 0.11, 0.52, 0.71)
    _preview = KartPreview.new()
    holder.add_child(_preview)
    _preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _map_preview = MapPreview.new()
    _map_preview.visible = false
    holder.add_child(_map_preview)
    _map_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # Painel de informações
    var info := UIKit.panel()
    add_child(info)
    _anchor_rect(info, 0.53, 0.11, 0.985, 0.71)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    info.add_child(v)

    _name_label = UIKit.label("", 42, UIKit.C_TEXT)
    v.add_child(_name_label)
    _title_label = UIKit.label("", 20, UIKit.C_GOLD, false)
    v.add_child(_title_label)
    _desc_label = UIKit.label("", 17, UIKit.C_DIM, false)
    _desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _desc_label.custom_minimum_size = Vector2(360.0, 46.0)
    v.add_child(_desc_label)
    _perk_label = UIKit.label("", 18, UIKit.C_OK, false)
    v.add_child(_perk_label)

    var bars_box := VBoxContainer.new()
    bars_box.add_theme_constant_override("separation", 4)
    v.add_child(bars_box)
    for title in ["Velocidade", "Aceleração", "Controle", "Nitro"]:
        _bars.append(UIKit.stat_row(bars_box, title, 230.0))
        var row_node: Node = bars_box.get_child(bars_box.get_child_count() - 1)
        _bar_titles.append(row_node.get_child(0) as Label)

    _req_label = UIKit.label("", 20, UIKit.C_TEXT, false)
    v.add_child(_req_label)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(spacer)

    _action_button = UIKit.button("ESCOLHER", 30, Vector2(0.0, 68.0), UIKit.C_OK)
    _action_button.pressed.connect(_on_action)
    v.add_child(_action_button)

    # Cartas (rolagem horizontal se não couber)
    var scroll := ScrollContainer.new()
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(scroll)
    _anchor_rect(scroll, 0.015, 0.725, 0.985, 0.985)
    _card_row = HBoxContainer.new()
    _card_row.add_theme_constant_override("separation", 12)
    _card_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_card_row)

    _toast_label = UIKit.label("", 30, UIKit.C_GOLD)
    _toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast_label.modulate.a = 0.0
    add_child(_toast_label)
    _anchor_rect(_toast_label, 0.0, 0.62, 0.52, 0.70)


# --------------------------------------------------------------------- passos
func _items() -> Array:
    if step == Step.MAP:
        return Catalog.maps()
    return Catalog.characters() if step == Step.CHARACTER else Catalog.karts()


func _viewed_id() -> String:
    if step == Step.MAP:
        return _map_id
    return _char_id if step == Step.CHARACTER else _kart_id


func _is_unlocked(id: String) -> bool:
    if step == Step.MAP:
        return SaveGame.is_map_unlocked(id)
    return SaveGame.is_char_unlocked(id) if step == Step.CHARACTER else SaveGame.is_kart_unlocked(id)


func _set_step(s: Step) -> void:
    step = s
    _back_button.text = "‹  MENU" if s == Step.CHARACTER else ("‹  PILOTO" if s == Step.KART else "‹  KART")
    _preview.mode = "swing" if s == Step.CHARACTER else "spin"
    _preview.set_focus(1.0 if s == Step.CHARACTER else 0.0)
    _preview.visible = s != Step.MAP
    _map_preview.visible = s == Step.MAP
    for i in _step_labels.size():
        var active := (i == int(s))
        var done := i < int(s)
        var col := UIKit.C_GOLD if active else (UIKit.C_OK if done else UIKit.C_DIM)
        _step_labels[i].add_theme_color_override("font_color", col)
    _rebuild_cards()
    _refresh()


func _rebuild_cards() -> void:
    for c in _card_row.get_children():
        c.queue_free()
    _cards.clear()
    for item in _items():
        var id: String = item["id"]
        var b := _make_card(item)
        b.pressed.connect(_on_card.bind(id))
        _card_row.add_child(b)
        _cards[id] = b


func _make_card(item: Dictionary) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(172.0, 150.0)
    b.focus_mode = Control.FOCUS_ALL
    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 4)
    v.name = "Caixa"
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(v)
    v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var sw := Panel.new()
    sw.name = "Amostra"
    sw.custom_minimum_size = Vector2(56.0, 56.0)
    sw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(sw)

    var nl := UIKit.label(String(item["name"]), 22, UIKit.C_TEXT, false)
    nl.name = "Nome"
    nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if item.has("sub"):
        nl.add_theme_font_size_override("font_size", 17)
        nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        nl.custom_minimum_size = Vector2(158.0, 44.0)
    v.add_child(nl)
    var sl := UIKit.label("", 16, UIKit.C_DIM, false)
    sl.name = "Estado"
    sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(sl)
    return b


# Atualiza cor/borda/estado de todas as cartas.
func _refresh_cards() -> void:
    var selected := SaveGame.selected_char() if step == Step.CHARACTER else (SaveGame.selected_map() if step == Step.MAP else SaveGame.selected_kart())
    for item in _items():
        var id: String = item["id"]
        var b: Button = _cards[id]
        var unlocked := _is_unlocked(id)
        var viewed := id == _viewed_id()
        var border := UIKit.C_GOLD if viewed else Color(0.22, 0.45, 0.8, 0.6)
        var bg := Color(0.06, 0.12, 0.22, 0.95) if unlocked else Color(0.05, 0.07, 0.11, 0.95)
        var bw := 4 if viewed else 2
        b.add_theme_stylebox_override("normal", UIKit.box(bg, 16, border, bw))
        b.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.12), 16, border.lightened(0.2), bw))
        b.add_theme_stylebox_override("pressed", UIKit.box(bg.lightened(0.2), 16, Color(1, 1, 1), bw))
        b.add_theme_stylebox_override("focus", UIKit.box(Color(0, 0, 0, 0), 16, Color(1, 1, 1, 0.9), 3))

        var sw: Panel = b.get_node("Caixa/Amostra") as Panel
        var col: Color = item["color"]
        if sw != null:
            sw.add_theme_stylebox_override("panel", UIKit.box(col if unlocked else col.darkened(0.65), 28))
        var status: Label = _find_label(b, "Estado")
        var name_l: Label = _find_label(b, "Nome")
        if name_l != null:
            name_l.add_theme_color_override("font_color", UIKit.C_TEXT if unlocked else UIKit.C_DIM)
        if status == null:
            continue
        var req: Dictionary = item["req"]
        if unlocked:
            if id == selected:
                status.text = "EM USO"
                status.add_theme_color_override("font_color", UIKit.C_GOLD)
            else:
                status.text = "Liberado"
                status.add_theme_color_override("font_color", UIKit.C_OK)
        elif req["type"] == "coins":
            status.text = "%d moedas" % int(req["price"])
            status.add_theme_color_override("font_color", UIKit.C_GOLD if SaveGame.coins() >= int(req["price"]) else UIKit.C_DIM)
        else:
            status.text = Catalog.req_text(req)
            status.add_theme_color_override("font_color", UIKit.C_DIM)


func _find_label(card: Button, node_name: String) -> Label:
    for child in card.get_children():
        for sub in child.get_children():
            if sub.name == node_name and sub is Label:
                return sub as Label
    return null


# ------------------------------------------------------------- atualização
func _refresh() -> void:
    if _cards.is_empty():
        return
    var id := _viewed_id()
    var item: Dictionary
    if step == Step.CHARACTER:
        item = Catalog.character(id)
    elif step == Step.KART:
        item = Catalog.kart(id)
    else:
        item = Catalog.map(id)
    var unlocked := _is_unlocked(id)
    var req: Dictionary = item["req"]

    # Combinação mostrada: item visto + o outro já selecionado
    var char_id := _char_id if step == Step.CHARACTER else SaveGame.selected_char()
    var kart_id := _kart_id if step == Step.KART else SaveGame.selected_kart()
    var ch := Catalog.character(char_id)
    var kd := Catalog.kart(kart_id)

    _preview.setup(kd["color"], ch["color"], String(ch["style"]), String(kd["id"]))
    _preview.locked = not unlocked and step != Step.MAP
    if step == Step.MAP:
        _map_preview.locked = not unlocked
        _map_preview.setup(id)

    _name_label.text = String(item["name"])
    if step == Step.CHARACTER:
        _title_label.text = String(item["title"])
        _perk_label.text = "Habilidade: " + String(item["perk"])
    elif step == Step.KART:
        _title_label.text = "Kart"
        _perk_label.text = _kart_perk_text(item)
    else:
        _title_label.text = String(item["sub"])
        _perk_label.text = "%d voltas  ·  Dificuldade %s" % [int(item["laps"]), "★".repeat(int(item["difficulty"])) + "☆".repeat(5 - int(item["difficulty"]))]
    _desc_label.text = String(item["desc"])

    var titles: Array[String] = ["Velocidade", "Aceleração", "Controle", "Nitro"]
    var bar_values: Array[float] = []
    if step == Step.MAP:
        titles = ["Extensão", "Quedas livres", "Curvas fechadas", "Altitude"]
        var inf := MapPreview.info(id)
        bar_values = [clampf(float(inf["km"]) / 6.0, 0.1, 1.0), clampf(float(inf["falls"]) / 14.0, 0.05, 1.0), clampf(float(inf["hairpins"]) / 14.0, 0.05, 1.0), clampf(float(inf["climb"]) / 140.0, 0.05, 1.0)]
        _perk_label.text += "  ·  %.1f km" % float(inf["km"])
        if int(inf["tunnels"]) > 0:
            _perk_label.text += "  ·  %d túneis" % int(inf["tunnels"])
        if int(inf["bridges"]) > 0:
            _perk_label.text += "  ·  %d pontes" % int(inf["bridges"])
        if int(inf["shortcuts"]) > 0:
            _perk_label.text += "  ·  atalho"
    else:
        bar_values = Catalog.stat_bars(char_id, kart_id)
    for i in _bars.size():
        _bars[i].value = bar_values[i]
        _bar_titles[i].text = titles[i]

    # Estado e botão de ação
    var accent := UIKit.C_OK
    if unlocked:
        _req_label.text = "DESBLOQUEADO"
        _req_label.add_theme_color_override("font_color", UIKit.C_OK)
        _action_button.text = "CORRER!" if step == Step.MAP else "ESCOLHER  ›"
        _action_button.disabled = false
    elif req["type"] == "coins":
        var price := int(req["price"])
        var have := SaveGame.coins()
        _req_label.text = "BLOQUEADO  ·  %d moedas" % price
        _req_label.add_theme_color_override("font_color", UIKit.C_GOLD)
        if have >= price:
            _action_button.text = "COMPRAR  (%d)" % price
            _action_button.disabled = false
            accent = UIKit.C_GOLD
        else:
            _action_button.text = "FALTAM %d MOEDAS" % (price - have)
            _action_button.disabled = true
    else:
        _req_label.text = "BLOQUEADO  ·  " + Catalog.req_text(req)
        _req_label.add_theme_color_override("font_color", UIKit.C_DIM)
        _action_button.text = "CONQUISTA NECESSÁRIA"
        _action_button.disabled = true
    _style_action(accent)
    _refresh_cards()


func _style_action(accent: Color) -> void:
    _action_button.add_theme_stylebox_override("normal", UIKit.box(accent.darkened(0.55), 16, accent.darkened(0.1), 3, 18.0, 8.0))
    _action_button.add_theme_stylebox_override("hover", UIKit.box(accent.darkened(0.4), 16, accent.lightened(0.15), 3, 18.0, 8.0))
    _action_button.add_theme_stylebox_override("pressed", UIKit.box(accent.darkened(0.2), 16, Color(1, 1, 1), 3, 18.0, 8.0))


func _kart_perk_text(item: Dictionary) -> String:
    var mods: Dictionary = item["mods"]
    if mods.is_empty():
        return "Equilibrado em tudo"
    var parts: Array[String] = []
    var labels := {"speed": "Velocidade", "accel": "Aceleração", "steer": "Direção", "grip": "Aderência", "nitro_regen": "Nitro"}
    for key in labels.keys():
        if mods.has(key):
            var pct := int(round((float(mods[key]) - 1.0) * 100.0))
            if pct != 0:
                parts.append("%s %s%d%%" % [labels[key], "+" if pct > 0 else "", pct])
    return ", ".join(parts)


# -------------------------------------------------------------------- ações
func _on_card(id: String) -> void:
    Flow.ui("click")
    if step == Step.CHARACTER:
        _char_id = id
        SaveGame.select_character(id)   # só muda se estiver liberado
    elif step == Step.KART:
        _kart_id = id
        SaveGame.select_kart(id)
    else:
        _map_id = id
        SaveGame.select_map(id)
    _refresh()


func _on_action() -> void:
    var id := _viewed_id()
    if not _is_unlocked(id):
        var ok := false
        var nm := ""
        if step == Step.CHARACTER:
            ok = SaveGame.buy_character(id)
            nm = String(Catalog.character(id)["name"])
        elif step == Step.KART:
            ok = SaveGame.buy_kart(id)
            nm = String(Catalog.kart(id)["name"])
        else:
            ok = SaveGame.buy_map(id)
            nm = String(Catalog.map(id)["name"])
        if ok:
            Flow.ui("unlock")
            if step == Step.CHARACTER:
                SaveGame.select_character(id)
            elif step == Step.KART:
                SaveGame.select_kart(id)
            else:
                SaveGame.select_map(id)
            _show_toast("Desbloqueado: %s!" % nm)
            _refresh()
        else:
            Flow.ui("deny")
        return
    Flow.ui("select")
    if step == Step.CHARACTER:
        SaveGame.select_character(id)
        _set_step(Step.KART)
    elif step == Step.KART:
        SaveGame.select_kart(id)
        _set_step(Step.MAP)
    else:
        SaveGame.select_map(id)
        SaveGame.save_game()
        Flow.ui("start")
        Flow.stop_music()
        Flow.go(Flow.SCENE_RACE)


func _on_back() -> void:
    Flow.ui("back")
    if step == Step.MAP:
        _set_step(Step.KART)
    elif step == Step.KART:
        _set_step(Step.CHARACTER)
    else:
        Flow.go(Flow.SCENE_MENU)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _on_back()
        get_viewport().set_input_as_handled()


func _show_toast(text: String) -> void:
    _toast_label.text = text
    if _toast_tween != null and _toast_tween.is_valid():
        _toast_tween.kill()
    _toast_label.modulate.a = 1.0
    _toast_tween = create_tween()
    _toast_tween.tween_interval(1.2)
    _toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)
