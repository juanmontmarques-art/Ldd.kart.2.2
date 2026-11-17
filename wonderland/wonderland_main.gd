class_name WonderlandMain
extends WorldBuilder

# Mundo da pista WONDERLAND. Substitui o pipeline do WorldBuilder (terreno em grade) por: relevo baked, estrada varrida,
# cavernas de rocha, ambiente por setor, props, hazards, mecanismos, checkpoints e chegada.

var layout: Dictionary
var terrain: WonderlandTerrain
var env_mod: WonderlandEnvironment
var road: WonderlandTrack
var caves: WonderlandCaves
var props: WonderlandProps
var mech: WonderlandMechanics
var hazards: WonderlandHazards
var checks: WonderlandCheckpoints
var cinematic: WonderlandCinematic
var main_ref: Node = null
var sector_banner: Label
var last_sector := 0
var banner_time := 0.0
var build_ms := {}


func _stamp(tag: String, t0: int) -> void:
    build_ms[tag] = Time.get_ticks_msec() - t0


func build(track_data: TrackData, map_theme: MapTheme) -> void:
    track = track_data
    theme = map_theme
    layout = WonderlandLayout.get_layout()
    rng.seed = 20261116
    var t := Time.get_ticks_msec()
    terrain = WonderlandTerrain.new()
    terrain.load_data()
    env_mod = WonderlandEnvironment.new()
    env_mod.build(self, track, layout)
    await get_tree().process_frame
    terrain.build(self, track)
    _stamp("terreno", t)
    await get_tree().process_frame
    t = Time.get_ticks_msec()
    road = WonderlandTrack.new()
    road.build(self, track, layout)
    road.build_branches()
    _stamp("estrada", t)
    await get_tree().process_frame
    t = Time.get_ticks_msec()
    caves = WonderlandCaves.new()
    caves.road_mod = road
    caves.build(self, track, layout, terrain, road.sector_of)
    _stamp("cavernas", t)
    await get_tree().process_frame
    t = Time.get_ticks_msec()
    props = WonderlandProps.new()
    props.build(self, track, layout, terrain, road)
    _stamp("props", t)
    await get_tree().process_frame
    t = Time.get_ticks_msec()
    mech = WonderlandMechanics.new()
    mech.build(self, track, layout, road, terrain)
    checks = WonderlandCheckpoints.new()
    checks.build(self, track, layout)
    hazards = WonderlandHazards.new()
    hazards.checks = checks
    hazards.build(self, track, layout, road, terrain)
    _stamp("mecanismos", t)
    _make_finish_and_start()
    set_physics_process(true)


func height_at(x: float, z: float) -> float:
    return terrain.height_at(x, z) if terrain != null else 0.0


# Piso de referência: não há "chão" contínuo (abismo / cavernas); fora-da-pista usa a distância lateral e as quedas.
func floor_at(_p: Vector3) -> float:
    return -1.0e8


func road_dist_at(_x: float, _z: float) -> float:
    return 0.0


func gate_closed_near(idx: int, ahead: int) -> bool:
    return mech != null and mech.gate_blocks(idx, ahead)


func attach_race(main: Node) -> void:
    main_ref = main
    hazards.attach(main)
    mech.attach(main)
    checks.attach(main)
    cinematic = WonderlandCinematic.new()
    cinematic.setup(self, main, track, layout)
    var layer := CanvasLayer.new()
    layer.layer = 20
    main.add_child(layer)
    sector_banner = Label.new()
    sector_banner.add_theme_font_size_override("font_size", 46)
    sector_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    sector_banner.add_theme_constant_override("outline_size", 10)
    sector_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
    sector_banner.position = Vector2(-380, 120)
    sector_banner.custom_minimum_size = Vector2(760, 90)
    sector_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sector_banner.modulate.a = 0.0
    layer.add_child(sector_banner)


func camera_override(camera: Camera3D, delta: float) -> bool:
    if cinematic != null and cinematic.active:
        return cinematic.update(camera, delta)
    return false


func _input(event: InputEvent) -> void:
    if cinematic != null and cinematic.active and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
        cinematic.skip()


func _physics_process(delta: float) -> void:
    if main_ref == null or main_ref.player == null:
        return
    var p: Racer = main_ref.player
    cinematic.race_fx(absf(p.body.forward_speed) / 31.0 + (0.3 if p.body.boost_time > 0.0 else 0.0))
    env_mod.apply_index(p.cur_idx, delta)
    var sec := env_mod.sector_of(p.cur_idx)
    if sec != last_sector:
        last_sector = sec
        var names: Array = WonderlandLayout.SECTOR_NAMES
        sector_banner.text = "SETOR %d · %s" % [sec, names[sec]]
        banner_time = 3.2
    banner_time = maxf(banner_time - delta, 0.0)
    sector_banner.modulate.a = clampf(banner_time, 0.0, 1.0)


func _make_finish_and_start() -> void:
    props.build_start_finish()
