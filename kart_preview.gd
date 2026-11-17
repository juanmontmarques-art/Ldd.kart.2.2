class_name KartPreview
extends SubViewportContainer

# Vitrine 3D do kart + piloto (fundo transparente), usada no menu e na garagem.
#   mode "spin":  gira devagar 360°
#   mode "swing": balança de leve mostrando a frente (bom para ver o rosto/capacete)
# "locked" escurece o modelo (silhueta) para itens ainda bloqueados.

var vp: SubViewport
var cam: Camera3D
var pivot: Node3D
var model: Node3D
var mode := "spin"
var locked := false:
    set(value):
        locked = value
        modulate = Color(0.16, 0.18, 0.24, 1.0) if value else Color(1, 1, 1, 1)

var _t := 0.0
var _kart_color := Color(0.9, 0.15, 0.12)
var _driver_color := Color(0.15, 0.45, 0.95)
var _driver_style := ""
var _kart_id := "classico"
var _focus := 0.0          # 0 = kart inteiro, 1 = close no piloto
var _focus_target := 0.0
var _yaw_extra := 0.0      # giro dado pelo dedo/mouse
var _dragging := false


func _ready() -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_PASS
    vp = SubViewport.new()
    vp.transparent_bg = true
    vp.own_world_3d = true
    vp.msaa_3d = Viewport.MSAA_2X
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(vp)

    var env := Environment.new()
    env.background_mode = Environment.BG_CLEAR_COLOR
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.62, 0.70, 0.88)
    env.ambient_light_energy = 0.85
    Webcore.grade(env, 0.84, 1.0)
    var we := WorldEnvironment.new()
    we.environment = env
    vp.add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    vp.add_child(sun)
    var rim := DirectionalLight3D.new()
    rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
    rim.light_energy = 0.7
    rim.light_color = Color(0.5, 0.75, 1.0)
    vp.add_child(rim)

    # Plataforma com anel luminoso
    var disc := CylinderMesh.new()
    disc.top_radius = 2.0
    disc.bottom_radius = 2.0
    disc.height = 0.08
    disc.radial_segments = 48
    var dm := StandardMaterial3D.new()
    dm.albedo_color = Color(0.05, 0.09, 0.16)
    dm.metallic = 0.5
    dm.roughness = 0.35
    var disc_mi := MeshInstance3D.new()
    disc_mi.mesh = disc
    disc_mi.material_override = dm
    disc_mi.position = Vector3(0.0, -0.04, 0.0)
    vp.add_child(disc_mi)
    var ring := TorusMesh.new()
    ring.inner_radius = 1.93
    ring.outer_radius = 2.0
    ring.rings = 48
    ring.ring_segments = 8
    var rm := StandardMaterial3D.new()
    rm.albedo_color = Color(0.2, 0.7, 1.0)
    rm.emission_enabled = true
    rm.emission = Color(0.2, 0.65, 1.0)
    rm.emission_energy_multiplier = 2.0
    rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var ring_mi := MeshInstance3D.new()
    ring_mi.mesh = ring
    ring_mi.material_override = rm
    ring_mi.position = Vector3(0.0, 0.01, 0.0)
    vp.add_child(ring_mi)

    pivot = Node3D.new()
    vp.add_child(pivot)

    cam = Camera3D.new()
    cam.fov = 34.0
    cam.near = 0.1
    cam.far = 60.0
    vp.add_child(cam)
    _place_camera()
    call_deferred("_ensure_built")


# Só constrói o modelo padrão se ninguém chamou setup() (evita construir duas vezes).
func _ensure_built() -> void:
    if model == null:
        _rebuild()


# Troca as cores/estilo. Reconstrói o modelo.
func setup(kart_color: Color, driver_color: Color, driver_style: String, kart_id: String = "classico") -> void:
    if model != null and kart_color == _kart_color and driver_color == _driver_color and driver_style == _driver_style and kart_id == _kart_id:
        return
    _kart_id = kart_id
    _kart_color = kart_color
    _driver_color = driver_color
    _driver_style = driver_style
    if pivot != null:
        _rebuild()


# 0 = kart inteiro, 1 = close no piloto.
func set_focus(value: float) -> void:
    _focus_target = clampf(value, 0.0, 1.0)


func _rebuild() -> void:
    if model != null:
        pivot.remove_child(model)
        model.free()
    model = KartModel.build(_kart_color, _driver_color, _driver_style, _kart_id)
    pivot.add_child(model)


func _process(delta: float) -> void:
    if pivot == null:
        return
    _t += delta
    _focus = lerpf(_focus, _focus_target, 1.0 - exp(-6.0 * delta))
    _place_camera()
    var base := 2.5   # vista 3/4 da frente (a frente do kart é -Z)
    if _dragging:
        pass
    elif mode == "spin":
        _yaw_extra += delta * 0.55
    else:
        _yaw_extra = lerp_angle(_yaw_extra, sin(_t * 0.9) * 0.45, 1.0 - exp(-3.0 * delta))
    pivot.rotation.y = base + _yaw_extra
    # leve flutuação
    pivot.position.y = 0.02 * sin(_t * 1.6)


func _place_camera() -> void:
    var wide_pos := Vector3(0.0, 1.9, 6.2)
    var close_pos := Vector3(0.0, 1.55, 3.3)
    var wide_look := Vector3(0.0, 0.75, 0.0)
    var close_look := Vector3(0.0, 1.30, 0.1)
    cam.position = wide_pos.lerp(close_pos, _focus)
    cam.look_at_from_position(cam.position, wide_look.lerp(close_look, _focus), Vector3.UP)


# Arrastar com o dedo/mouse gira o kart.
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _dragging = event.pressed
    elif event is InputEventScreenTouch:
        _dragging = event.pressed
    elif event is InputEventMouseMotion and _dragging:
        _yaw_extra += event.relative.x * 0.012
    elif event is InputEventScreenDrag:
        _yaw_extra += event.relative.x * 0.012
