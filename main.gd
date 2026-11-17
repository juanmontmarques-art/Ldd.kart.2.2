extends Node3D

# Kart Livre 3D — Circuito Aventura v5
# Orquestra mundo, pilotos (jogador + adversários), itens, áudio, câmera,
# corrida (contagem, voltas, posições), interface e controles de toque.

enum RaceState { LOADING, COUNTDOWN, RACING, FINISHED }

const AI_COUNT := 4

var track: TrackData
var theme: MapTheme
var map_id := ""
var laps := 2
var world: WorldBuilder
var items: ItemManager
var audio: GameAudio
var camera: Camera3D
var minimap: Minimap
var tunnel_label: Label
var tunnel_dim: ColorRect
var _tunnel_fade := 0.0
var touch: TouchControls
var coins_mgr: CoinManager

# Seleção feita na garagem (vem do SaveGame)
var char_id := "rex"
var kart_id := "classico"
var char_data: Dictionary = {}
var kart_data: Dictionary = {}
var _coin_combo := 0
var _last_coin_time := -10.0

var racers: Array[Racer] = []
var sorted_racers: Array[Racer] = []
var player: Racer

var state := RaceState.LOADING
var countdown := 3.99
var last_count := 99
var race_time := 0.0
var final_time := 0.0
var lap_start := 0.0
var lap_times: Array[float] = []
var wrong_way_time := 0.0
var cam_yaw := 0.0
var _was_nitro := false
var _shown_item := "?"

var loading_label: Label
var pos_label: Label
var speed_label: Label
var lap_label: Label
var time_label: Label
var nitro_bar: ProgressBar
var center_label: Label
var warn_label: Label
var end_panel: Control
var end_label: Label
var reward_box: VBoxContainer
var pause_panel: Control
var coin_label: Label


func _ready() -> void:
    Flow.stop_music()
    char_id = SaveGame.selected_char()
    kart_id = SaveGame.selected_kart()
    char_data = Catalog.character(char_id)
    kart_data = Catalog.kart(kart_id)
    map_id = SaveGame.selected_map()
    var map_data := Catalog.map(map_id)
    laps = int(map_data["laps"])
    theme = MapTheme.get_theme(map_id)
    _make_ui()
    await get_tree().process_frame
    await get_tree().process_frame
    loading_label.text = "Montando: %s..." % String(map_data["name"])
    track = TrackData.create(map_id)
    track.build()
    world = WonderlandMain.new() if map_id == "wonderland" else WorldBuilder.new()
    world.name = "Mundo"
    add_child(world)
    await world.build(track, theme)
    if world.has_method("attach_race"):
        world.call("attach_race", self)

    loading_label.text = "Preparando sons..."
    await get_tree().process_frame
    audio = GameAudio.new()
    audio.name = "Audio"
    add_child(audio)
    audio.setup()
    await get_tree().process_frame
    audio.prepare_music()
    await get_tree().process_frame

    _make_racers()
    items = ItemManager.new()
    items.name = "Itens"
    add_child(items)
    items.setup(track, racers)
    items.picked.connect(_on_item_picked)
    items.used.connect(_on_item_used)
    _make_ai_drivers()
    coins_mgr = CoinManager.new()
    coins_mgr.name = "Moedas"
    add_child(coins_mgr)
    coins_mgr.setup(track, player, Catalog.mod(char_id, kart_id, "coins"))
    coins_mgr.collected.connect(_on_coin_collected)
    _make_camera()
    minimap.setup(track)

    player.body.boosted.connect(func() -> void: audio.sfx("whoosh", -4.0))
    player.body.hit.connect(func() -> void: audio.sfx("hit"))
    player.body.bumped.connect(func() -> void: audio.sfx("bump", -6.0))
    touch.item_requested.connect(_use_player_item)
    touch.mute_toggled.connect(_on_mute)
    touch.muted = SaveGame.is_muted()

    loading_label.visible = false
    audio.start_music()
    state = RaceState.COUNTDOWN


# ------------------------------------------------------------------- pilotos
func _make_racers() -> void:
    var base := track.count - 8
    # Adversários: sorteia entre os outros personagens do catálogo.
    var pool: Array = Catalog.characters().duplicate()
    pool.shuffle()
    var rivals: Array[Dictionary] = []
    for c in pool:
        if c["id"] != char_id and rivals.size() < AI_COUNT:
            rivals.append(c)
    for s in AI_COUNT:
        var rv: Dictionary = rivals[s % rivals.size()]
        var rc: Color = rv["color"]
        var others: Array[String] = []
        for kid in KartModel.IDS:
            if kid != kart_id:
                others.append(kid)
        racers.append(_make_racer(s, base, String(rv["name"]), rc, rc.lightened(0.25), String(rv["style"]), false, others[s % others.size()]))
    var pc: Color = char_data["color"]
    player = _make_racer(AI_COUNT, base, "Você", kart_data["color"], pc, String(char_data["style"]), true, kart_id)
    racers.append(player)
    sorted_racers.assign(racers)


func _make_racer(slot: int, base: int, display: String, col: Color, driver_col: Color, style: String, is_player: bool, model_id: String = "classico") -> Racer:
    var r := Racer.new()
    r.display_name = display
    r.color = col
    r.is_player = is_player
    var row := slot / 2
    var lat := -3.2 if slot % 2 == 0 else 3.2
    var i := posmod(base - row * 3, track.count)
    r.cur_idx = i
    r.last_good_idx = i
    r.total_progress = i - track.count

    var body := KartBody.new()
    body.name = "Kart_" + display
    body.position = track.at(i, lat) + Vector3(0.0, KartBody.RADIUS + 0.3, 0.0)
    body.yaw = track.yaw_at(i)
    add_child(body)
    r.body = body
    r.visual = _make_visual(body, col, driver_col, style, model_id)
    if is_player:
        _apply_mods(body)
        cam_yaw = body.yaw
    else:
        var p := AudioStreamPlayer3D.new()
        p.stream = audio.engine_stream
        p.unit_size = 8.0
        p.max_distance = 110.0
        p.volume_db = -6.0
        body.add_child(p)
        p.play()
        r.engine3d = p
    return r


func _make_ai_drivers() -> void:
    var lanes: Array[float] = [-4.0, 4.0, -1.5, 1.5]
    var skills: Array[float] = [0.985, 0.97, 0.955, 0.94]
    var n := 0
    for r in racers:
        if r.is_player:
            continue
        r.ai = AiDriver.new()
        r.ai.setup(r, track, items, racers, lanes[n], skills[n])
        n += 1


func _make_visual(body: KartBody, kart_col: Color, driver_col: Color, style: String, model_id: String = "classico") -> Node3D:
    var visual := Node3D.new()
    visual.name = "ModeloVisual_" + body.name
    add_child(visual)
    body.visual = visual
    var model_root := KartModel.build(kart_col, driver_col, style, model_id)
    model_root.position = Vector3(0.0, -0.05, 0.0)
    visual.add_child(model_root)

    var flame_mesh := CylinderMesh.new()
    flame_mesh.top_radius = 0.0
    flame_mesh.bottom_radius = 0.16
    flame_mesh.height = 0.9
    var flame_mat := StandardMaterial3D.new()
    flame_mat.albedo_color = Color(1.0, 0.55, 0.1)
    flame_mat.emission_enabled = true
    flame_mat.emission = Color(1.0, 0.45, 0.05)
    flame_mat.emission_energy_multiplier = 2.5
    flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for sx in [-0.22, 0.22]:
        var fl := MeshInstance3D.new()
        fl.mesh = flame_mesh
        fl.material_override = flame_mat
        fl.rotation_degrees = Vector3(90.0, 0.0, 0.0)
        fl.position = Vector3(sx, 0.62, 1.7)
        fl.visible = false
        visual.add_child(fl)
        body.flames.append(fl)
    return visual


# Aplica os bônus do personagem + kart escolhidos (ver catalog.gd).
func _apply_mods(body: KartBody) -> void:
    body.max_speed *= Catalog.mod(char_id, kart_id, "speed")
    body.acceleration *= Catalog.mod(char_id, kart_id, "accel")
    body.steer_rate *= Catalog.mod(char_id, kart_id, "steer")
    body.grip *= Catalog.mod(char_id, kart_id, "grip") * theme.grip_mult
    body.nitro_regen *= Catalog.mod(char_id, kart_id, "nitro_regen")
    body.nitro_drain *= Catalog.mod(char_id, kart_id, "nitro_drain")


func _make_camera() -> void:
    camera = Camera3D.new()
    camera.name = "CameraSeguidora"
    camera.near = 0.3
    camera.far = 2400.0
    camera.fov = 68.0
    add_child(camera)
    camera.current = true
    ThemeDecor.attach_weather(camera, theme)
    var back := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
    camera.global_position = player.body.global_position + back * 7.5 + Vector3(0.0, 3.4, 0.0)
    camera.look_at(player.body.global_position + Vector3(0.0, 1.0, 0.0))


# ------------------------------------------------------------------------ UI
func _make_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)

    var panel := PanelContainer.new()
    panel.position = Vector2(18.0, 16.0)
    panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.09, 0.22, 0.72)))
    layer.add_child(panel)
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 2)
    panel.add_child(vbox)
    pos_label = _hud_label(vbox, "POSIÇÃO 5/5", 30)
    lap_label = _hud_label(vbox, "VOLTA 1/%d" % laps, 22)
    time_label = _hud_label(vbox, "TEMPO 0:00.00", 20)
    speed_label = _hud_label(vbox, "0 km/h", 22)
    nitro_bar = ProgressBar.new()
    nitro_bar.custom_minimum_size = Vector2(200.0, 14.0)
    nitro_bar.min_value = 0.0
    nitro_bar.max_value = 1.0
    nitro_bar.value = 1.0
    nitro_bar.show_percentage = false
    nitro_bar.add_theme_stylebox_override("background", _panel_style(Color(0.04, 0.03, 0.12, 0.60), 7))
    nitro_bar.add_theme_stylebox_override("fill", _panel_style(Webcore.AQUA, 7))
    vbox.add_child(nitro_bar)
    _hud_label(vbox, "NITRO", 13)
    coin_label = _hud_label(vbox, "MOEDAS 0", 20)
    coin_label.add_theme_color_override("font_color", UIKit.C_GOLD)

    center_label = Label.new()
    center_label.anchor_left = 0.5
    center_label.anchor_right = 0.5
    center_label.offset_left = -200.0
    center_label.offset_right = 200.0
    center_label.offset_top = 90.0
    center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center_label.add_theme_font_size_override("font_size", 120)
    center_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.58))
    center_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
    center_label.add_theme_constant_override("outline_size", 14)
    layer.add_child(center_label)

    warn_label = Label.new()
    warn_label.text = "SENTIDO ERRADO!"
    warn_label.anchor_left = 0.5
    warn_label.anchor_right = 0.5
    warn_label.offset_left = -200.0
    warn_label.offset_right = 200.0
    warn_label.offset_top = 260.0
    warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    warn_label.add_theme_font_size_override("font_size", 34)
    warn_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.52))
    warn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    warn_label.add_theme_constant_override("outline_size", 8)
    warn_label.visible = false
    layer.add_child(warn_label)

    tunnel_dim = ColorRect.new()
    tunnel_dim.color = Color(0.0, 0.0, 0.04, 0.0)
    tunnel_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tunnel_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(tunnel_dim)
    tunnel_label = Label.new()
    tunnel_label.anchor_left = 0.5
    tunnel_label.anchor_right = 0.5
    tunnel_label.offset_left = -220.0
    tunnel_label.offset_right = 220.0
    tunnel_label.offset_top = 14.0
    tunnel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tunnel_label.add_theme_font_size_override("font_size", 30)
    tunnel_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.60))
    tunnel_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    tunnel_label.add_theme_constant_override("outline_size", 8)
    tunnel_label.visible = false
    layer.add_child(tunnel_label)

    minimap = Minimap.new()
    minimap.anchor_left = 1.0
    minimap.anchor_right = 1.0
    minimap.offset_left = -196.0
    minimap.offset_right = -16.0
    minimap.offset_top = 16.0
    minimap.offset_bottom = 176.0
    minimap.size = Vector2(180.0, 160.0)
    layer.add_child(minimap)

    touch = TouchControls.new()
    touch.name = "Controles"
    touch.respawn_requested.connect(_respawn)
    layer.add_child(touch)
    touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _make_end_panel(layer)
    _make_pause_ui(layer)

    loading_label = Label.new()
    loading_label.text = "Carregando circuito..."
    loading_label.add_theme_font_size_override("font_size", 36)
    loading_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    loading_label.add_theme_constant_override("outline_size", 8)
    layer.add_child(loading_label)
    loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _make_end_panel(layer: CanvasLayer) -> void:
    var wrap := CenterContainer.new()
    wrap.visible = false
    layer.add_child(wrap)
    wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    end_panel = wrap
    var panel := UIKit.panel(Color(0.13, 0.12, 0.28, 0.95), 20)
    wrap.add_child(panel)
    var ev := VBoxContainer.new()
    ev.add_theme_constant_override("separation", 8)
    panel.add_child(ev)
    end_label = UIKit.label("", 24, UIKit.C_TEXT)
    ev.add_child(end_label)
    reward_box = VBoxContainer.new()
    reward_box.add_theme_constant_override("separation", 2)
    ev.add_child(reward_box)
    var again := UIKit.button("JOGAR DE NOVO", 26, Vector2(380.0, 62.0), UIKit.C_OK)
    again.pressed.connect(func() -> void:
        get_tree().paused = false
        get_tree().reload_current_scene())
    ev.add_child(again)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    ev.add_child(row)
    var garage := UIKit.button("GARAGEM", 20, Vector2(185.0, 52.0), UIKit.C_ACCENT)
    garage.pressed.connect(func() -> void: Flow.go(Flow.SCENE_GARAGEM))
    row.add_child(garage)
    var menu := UIKit.button("MENU", 20, Vector2(185.0, 52.0), UIKit.C_DIM)
    menu.pressed.connect(func() -> void: Flow.go(Flow.SCENE_MENU))
    row.add_child(menu)


func _make_pause_ui(layer: CanvasLayer) -> void:
    var pause_btn := Button.new()
    pause_btn.text = "II"
    pause_btn.focus_mode = Control.FOCUS_NONE
    pause_btn.custom_minimum_size = Vector2(60.0, 52.0)
    pause_btn.add_theme_font_size_override("font_size", 24)
    pause_btn.anchor_left = 0.5
    pause_btn.anchor_right = 0.5
    pause_btn.offset_left = -30.0
    pause_btn.offset_right = 30.0
    pause_btn.offset_top = 12.0
    pause_btn.pressed.connect(_toggle_pause)
    layer.add_child(pause_btn)

    pause_panel = Control.new()
    pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
    pause_panel.visible = false
    layer.add_child(pause_panel)
    pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.62)
    pause_panel.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    pause_panel.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := UIKit.panel()
    center.add_child(panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    panel.add_child(v)
    var head := UIKit.label("PAUSADO", 40, UIKit.C_GOLD)
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(head)
    var resume := UIKit.button("CONTINUAR", 28, Vector2(340.0, 64.0), UIKit.C_OK)
    resume.pressed.connect(_toggle_pause)
    v.add_child(resume)
    var restart := UIKit.button("REINICIAR", 24, Vector2(340.0, 56.0), UIKit.C_ACCENT)
    restart.pressed.connect(func() -> void:
        get_tree().paused = false
        get_tree().reload_current_scene())
    v.add_child(restart)
    var garage := UIKit.button("GARAGEM", 24, Vector2(340.0, 56.0), UIKit.C_ACCENT)
    garage.pressed.connect(func() -> void: Flow.go(Flow.SCENE_GARAGEM))
    v.add_child(garage)
    var menu := UIKit.button("MENU PRINCIPAL", 24, Vector2(340.0, 56.0), UIKit.C_DIM)
    menu.pressed.connect(func() -> void: Flow.go(Flow.SCENE_MENU))
    v.add_child(menu)

    # Esc (teclado) também pausa/continua, mesmo com o jogo pausado.
    var watcher := PauseWatcher.new()
    watcher.toggle.connect(_toggle_pause)
    add_child(watcher)


func _toggle_pause() -> void:
    if player == null or state == RaceState.LOADING or end_panel.visible:
        return
    var now_paused := not get_tree().paused
    get_tree().paused = now_paused
    pause_panel.visible = now_paused


func _on_coin_collected(total: int) -> void:
    coin_label.text = "MOEDAS %d" % total
    var now := float(Time.get_ticks_msec()) / 1000.0
    if now - _last_coin_time > 1.5:
        _coin_combo = 0
    _coin_combo += 1
    _last_coin_time = now
    audio.sfx("coin", -7.0, 1.0 + minf(float(_coin_combo), 8.0) * 0.06)


# Escuta a tecla Esc mesmo com a árvore pausada.
class PauseWatcher extends Node:
    signal toggle

    func _init() -> void:
        process_mode = Node.PROCESS_MODE_ALWAYS

    func _unhandled_input(event: InputEvent) -> void:
        if event.is_action_pressed("ui_cancel"):
            toggle.emit()
            get_viewport().set_input_as_handled()


func _hud_label(parent: Control, text: String, font_size: int) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
    l.add_theme_constant_override("outline_size", 5)
    parent.add_child(l)
    return l


func _panel_style(color: Color, radius: int = 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.corner_radius_top_left = radius
    s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius
    s.corner_radius_bottom_right = radius
    s.content_margin_left = 14.0
    s.content_margin_right = 14.0
    s.content_margin_top = 8.0
    s.content_margin_bottom = 8.0
    return s


# ------------------------------------------------------------- eventos/itens
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            _respawn()
        elif event.keycode == KEY_E or event.keycode == KEY_Q:
            _use_player_item()
        elif event.keycode == KEY_M:
            _on_mute()


func _use_player_item() -> void:
    if player == null or state != RaceState.RACING or player.finished:
        return
    items.use_item(player)


func _on_item_picked(r: Racer) -> void:
    if r.is_player:
        audio.sfx("pickup")


func _on_item_used(r: Racer, item_name: String) -> void:
    if not r.is_player:
        return
    match item_name:
        "turbo":
            audio.sfx("use")
        "banana":
            audio.sfx("banana")
        "casco":
            audio.sfx("shell")


func _on_mute() -> void:
    SaveGame.set_muted(not SaveGame.is_muted())
    touch.muted = SaveGame.is_muted()
    touch.queue_redraw()


func _respawn() -> void:
    if player == null or state == RaceState.LOADING:
        return
    player.respawn(track)


# ------------------------------------------------------------------- corrida
func _rank_less(a: Racer, b: Racer) -> bool:
    if a.finished != b.finished:
        return a.finished
    if a.finished:
        return a.finish_time < b.finish_time
    return a.total_progress > b.total_progress


func _physics_process(delta: float) -> void:
    if player == null or camera == null:
        return

    var racing := state == RaceState.RACING or state == RaceState.FINISHED

    # Progresso, posição e proteção contra travamentos
    for r in racers:
        var lateral := r.update_progress(track)
        if lateral > 75.0 or r.body.global_position.y < world.floor_at(r.body.global_position) - 12.0:
            r.offtrack_time += delta
            if r.offtrack_time > 2.5:
                r.respawn(track)
        else:
            r.offtrack_time = 0.0
        # Caiu num abismo: volta alguns metros antes do salto, com espaço para pegar embalo.
        if r.body.global_position.y < r.ground_y(track) - 6.0:
            r.fall_time += delta
            if r.fall_time > 0.7:
                r.respawn(track, 40)
        else:
            r.fall_time = 0.0
        if racing and not r.is_player and not r.finished and absf(r.body.forward_speed) < 2.0:
            r.stuck_time += delta
            if r.stuck_time > 3.0:
                r.respawn(track)
        else:
            r.stuck_time = 0.0

    sorted_racers.sort_custom(_rank_less)
    for i in sorted_racers.size():
        sorted_racers[i].rank = i + 1

    # IA com "elástico": adversários distantes ajustam o ritmo ao do jogador.
    for r in racers:
        if r.ai == null:
            continue
        var gap := player.total_progress - r.total_progress
        r.body.speed_factor = r.ai.skill * clampf(1.0 + float(gap) * 0.0007, 0.88, 1.09)
        r.ai.update(delta, racing)

    # Indicação de trecho subterrâneo (túnel, caverna, cachoeira).
    var tk := track.tunnel_at(player.cur_idx, player.branch, player.bidx)
    _tunnel_fade = move_toward(_tunnel_fade, 1.0 if tk >= 0 else 0.0, delta * 3.0)
    tunnel_dim.color.a = 0.20 * _tunnel_fade
    tunnel_label.visible = tk >= 0
    if tk >= 0:
        tunnel_label.text = ["TÚNEL", "CACHOEIRA", "CAVERNA"][clampi(tk, 0, 2)]

    # Sentido errado (jogador)
    var kart := player.body
    var ref_tan := track.tans[player.cur_idx]
    if player.branch >= 0:
        var bt: PackedVector3Array = track.branches[player.branch]["tans"]
        ref_tan = bt[player.bidx]
    var along := Vector3(kart.linear_velocity.x, 0.0, kart.linear_velocity.z).dot(ref_tan)
    if state == RaceState.RACING and along < -3.0:
        wrong_way_time += delta
    else:
        wrong_way_time = 0.0
    warn_label.visible = wrong_way_time > 1.2

    match state:
        RaceState.COUNTDOWN:
            countdown -= delta
            for r in racers:
                r.body.controls_enabled = false
            if countdown > 0.0:
                var shown := maxi(1, int(ceil(countdown)))
                center_label.text = str(shown)
                if shown != last_count:
                    last_count = shown
                    audio.sfx("beep")
            else:
                center_label.text = "VAI!"
                audio.sfx("go")
                state = RaceState.RACING
                for r in racers:
                    r.body.controls_enabled = true
                race_time = 0.0
                lap_start = 0.0
        RaceState.RACING, RaceState.FINISHED:
            race_time += delta
            if race_time > 1.0 and center_label.text == "VAI!":
                center_label.text = ""
            _check_laps()
        _:
            pass

    _update_camera(delta)
    var pos_list := PackedVector3Array()
    var col_list := PackedColorArray()
    for r in racers:
        if not r.is_player:
            pos_list.append(r.body.global_position)
            col_list.append(r.color)
    minimap.update_kart(kart.global_position, kart.yaw, pos_list, col_list)


func _check_laps() -> void:
    for r in racers:
        if r.finished:
            continue
        var completed := int(floor(float(r.total_progress) / float(track.count)))
        if completed > r.lap_count:
            r.lap_count = completed
            if r.is_player:
                lap_times.append(race_time - lap_start)
                lap_start = race_time
                if completed < laps:
                    audio.sfx("lap")
                    coins_mgr.respawn_all()
            if completed >= laps:
                r.finished = true
                r.finish_time = race_time
                r.body.controls_enabled = false
                if r.is_player:
                    _finish_player()


func _finish_player() -> void:
    state = RaceState.FINISHED
    final_time = race_time
    audio.sfx("finish")
    center_label.text = ""

    var best := lap_times[0]
    for lt in lap_times:
        best = minf(best, lt)
    var rank := 1
    for r in racers:
        if r != player and r.finished and r.finish_time <= final_time:
            rank += 1

    # Grava a corrida: moedas de prêmio, recordes, desbloqueios.
    var summary := SaveGame.register_race({
        "time": final_time, "best_lap": best, "rank": rank,
        "char": char_id, "kart": kart_id, "track": map_id,
    })
    summary["coins_picked"] = coins_mgr.total_in_race
    Flow.last_summary = summary

    var txt := "CHEGADA!  %dº lugar\n\nTEMPO TOTAL  %s\n" % [rank, _fmt(final_time)]
    for i in lap_times.size():
        txt += "Volta %d   %s\n" % [i + 1, _fmt(lap_times[i])]
    txt += "Melhor volta  %s" % _fmt(best)
    end_label.text = txt

    for c in reward_box.get_children():
        c.queue_free()
    _reward_line("Prêmio do %dº lugar   +%d" % [rank, int(summary["prize"] )], UIKit.C_GOLD)
    if int(summary["bonus_time"]) > 0:
        _reward_line("NOVO RECORDE DE TEMPO!   +%d" % int(summary["bonus_time"]), UIKit.C_OK)
    if int(summary["bonus_lap"]) > 0:
        _reward_line("NOVO RECORDE DE VOLTA!   +%d" % int(summary["bonus_lap"]), UIKit.C_OK)
    if int(summary["leaderboard_pos"]) > 0:
        _reward_line("Entrou no Top 5 dos recordes (%dº)" % int(summary["leaderboard_pos"]), UIKit.C_ACCENT)
    if coins_mgr.total_in_race > 0:
        _reward_line("Moedas da pista   +%d" % coins_mgr.total_in_race, UIKit.C_GOLD)
    for nm in summary["unlocked_names"]:
        _reward_line("DESBLOQUEADO:  %s" % String(nm), UIKit.C_OK)
    _reward_line("Saldo: %d moedas" % SaveGame.coins(), UIKit.C_TEXT)
    if not (summary["unlocked_names"] as Array).is_empty():
        audio.sfx("lap")
    end_panel.visible = true


func _reward_line(text: String, color: Color) -> void:
    reward_box.add_child(UIKit.label(text, 22, color, false))


func _fmt(t: float) -> String:
    return "%d:%05.2f" % [int(floor(t / 60.0)), fmod(t, 60.0)]


func _process(_delta: float) -> void:
    if player == null:
        return
    var kart := player.body
    speed_label.text = "%d km/h" % int(absf(kart.forward_speed) * 3.6)
    nitro_bar.value = kart.nitro
    pos_label.text = "POSIÇÃO %d/%d" % [player.rank, racers.size()]
    var shown_lap := clampi(int(floor(float(maxi(player.total_progress, 0)) / float(track.count))) + 1, 1, laps)
    lap_label.text = "VOLTA %d/%d" % [shown_lap, laps]
    time_label.text = "TEMPO " + _fmt(final_time if state == RaceState.FINISHED else race_time)

    if kart.item != _shown_item:
        _shown_item = kart.item
        touch.item_name = kart.item
        touch.queue_redraw()

    # Sons do motor
    var ratio := clampf(absf(kart.forward_speed) / 31.0, 0.0, 1.3)
    var boosting := kart.nitro_active or kart.boost_time > 0.0
    audio.set_engine(ratio, boosting, state != RaceState.LOADING)
    if kart.nitro_active and not _was_nitro:
        audio.sfx("whoosh", -4.0)
    _was_nitro = kart.nitro_active

    # Adversários: motor 3D e corte de modelos distantes (economiza GPU)
    for r in racers:
        if r.is_player:
            continue
        if r.engine3d != null:
            r.engine3d.pitch_scale = 0.75 + clampf(absf(r.body.forward_speed) / 31.0, 0.0, 1.3) * 1.7
        r.visual.visible = r.body.global_position.distance_to(camera.global_position) < 170.0


func _update_camera(delta: float) -> void:
    var kart := player.body
    if world.has_method("camera_override") and world.call("camera_override", camera, delta):
        return
    if kart.mag_mode:
        _update_camera_mag(delta)
        return
    cam_yaw = lerp_angle(cam_yaw, kart.yaw, 1.0 - exp(-4.5 * delta))
    var speed_ratio := clampf(absf(kart.forward_speed) / 31.0, 0.0, 1.3)
    var boosting := kart.nitro_active or kart.boost_time > 0.0
    var dist := 7.2 + speed_ratio * 1.3 + (1.2 if boosting else 0.0)
    var height := 3.2 + speed_ratio * 0.4
    var back := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
    var kp := kart.global_position
    var target := kp + back * dist + Vector3(0.0, height, 0.0)
    var ground := world.floor_at(target)
    target.y = maxf(target.y, ground + 1.6)
    target = _camera_clip(kp + Vector3(0.0, 1.2, 0.0), target)
    camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-12.0 * delta))
    var look := kp - back * 4.0 + Vector3(0.0, 1.1, 0.0)
    if camera.global_position.distance_to(look) > 0.5:
        camera.look_at(look, Vector3.UP)
    var fov_target := 68.0 + speed_ratio * 6.0 + (9.0 if boosting else 0.0)
    camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-5.0 * delta))


# Câmera nas zonas de gravidade magnética (parafusos, pista invertida): segue o "cima" da pista.
func _update_camera_mag(delta: float) -> void:
    var kart := player.body
    var up: Vector3 = kart.mag_up
    var hd: Vector3 = kart.mag_heading
    var speed_ratio := clampf(absf(kart.forward_speed) / 31.0, 0.0, 1.3)
    var kp := kart.global_position
    var target := kp - hd * (7.6 + speed_ratio) + up * (3.4 + speed_ratio * 0.4)
    target = _camera_clip(kp + up * 1.2, target)
    camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-9.0 * delta))
    var look := kp + hd * 4.0 + up * 1.1
    var cu: Vector3 = camera.global_transform.basis.y.lerp(up, 1.0 - exp(-6.0 * delta)).normalized()
    if camera.global_position.distance_to(look) > 0.5:
        camera.look_at(look, cu)
    camera.fov = lerpf(camera.fov, 72.0 + speed_ratio * 6.0, 1.0 - exp(-5.0 * delta))
    cam_yaw = kart.yaw


# Em cavernas a câmera não atravessa a rocha: raio do kart até a câmera.
func _camera_clip(from: Vector3, to: Vector3) -> Vector3:
    if not world.has_method("camera_override") and track.map_id != "wonderland":
        return to
    var space := get_viewport().world_3d.direct_space_state
    var q := PhysicsRayQueryParameters3D.create(from, to, 1)
    var hit := space.intersect_ray(q)
    if hit.is_empty():
        return to
    return from + (hit["position"] - from) * 0.9
