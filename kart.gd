class_name KartBody
extends RigidBody3D

# Kart com física "de esfera": uma esfera rígida rola de verdade sobre o terreno
# (gravidade, subidas, descidas, saltos, batidas em árvores/barreiras) e o
# modelo 3D do kart apenas segue a esfera, alinhado com a inclinação do chão.

signal boosted
signal hit
signal bumped

const RADIUS := 0.8

@export var max_speed := 31.0
@export var acceleration := 25.0
@export var brake_decel := 42.0
@export var reverse_speed := 9.0
@export var coast_drag := 5.0
@export var steer_rate := 2.05
@export var grip := 10.0
@export var gravity := 27.0
@export var nitro_speed_bonus := 10.0
@export var nitro_drain := 0.30    # consumo do tanque por segundo
@export var nitro_regen := 0.10    # recarga do tanque por segundo

var visual: Node3D
var flames: Array[MeshInstance3D] = []
var controls_enabled := false
var on_road := true

var yaw := 0.0
var steer := 0.0
var forward_speed := 0.0
var grounded := false
var air_time := 0.0
var ground_normal := Vector3.UP
var boost_time := 0.0
var nitro := 1.0
var nitro_active := false
var wall_contact := false

# Controle por IA (adversários) e itens
var ai_controlled := false
var ai_throttle := 0.0
var ai_brake := 0.0
var ai_steer := 0.0
var ai_nitro := false
var speed_factor := 1.0
var item := ""
var spin_time := 0.0
var spin_total := 1.0
var immunity := 0.0
var _prev_wall := false

# --- Extensões da Wonderland (valores neutros nos demais mapas) ---
var grip_mod := 1.0          # aderência lateral (gelo/óleo < 1)
var grav_mod := 1.0          # gravidade (zonas de baixa gravidade < 1)
var drag_over := 0.0         # freio extra quando passa muito do limite de velocidade (descidas extremas)
var mag_mode := false        # gravidade magnética: o kart "gruda" na pista, mesmo de cabeça para baixo
var mag_up := Vector3.UP
var mag_heading := Vector3(0.0, 0.0, -1.0)
var _mag_air := 0.0
var mag_target := Vector3.ZERO   # normal da pista no trecho atual (fornecida pelo Racer): guia a gravidade magnética no ar
var external_boost := 0.0    # aceleração contínua (faixas de turbo): segundos restantes

var _visual_up := Vector3.UP
var _kick := 0.0
var _teleport_pending := false
var _teleport_pos := Vector3.ZERO
var _teleport_yaw := 0.0


func _ready() -> void:
    _ensure_actions()
    collision_layer = 2
    collision_mask = 3   # chão/objetos (1) + outros karts (2)
    gravity_scale = 0.0
    mass = 1.0
    can_sleep = false
    continuous_cd = true
    contact_monitor = true
    max_contacts_reported = 6
    linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
    linear_damp = 0.0
    angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
    angular_damp = 0.0
    var mat := PhysicsMaterial.new()
    mat.friction = 0.0
    mat.bounce = 0.0
    physics_material_override = mat
    var col := CollisionShape3D.new()
    col.name = "EsferaDoKart"
    var shape := SphereShape3D.new()
    shape.radius = RADIUS
    col.shape = shape
    add_child(col)


func teleport(pos: Vector3, new_yaw: float) -> void:
    _teleport_pending = true
    _teleport_pos = pos
    _teleport_yaw = new_yaw


# Retorna true se o kart rodopiou (falha se estiver imune logo após outro golpe).
func spin(duration: float = 1.4) -> bool:
    if immunity > 0.0 or spin_time > 0.0:
        return false
    spin_time = duration
    spin_total = duration
    immunity = duration + 1.3
    hit.emit()
    return true


# Liga/desliga a gravidade magnética. Ao ligar, o rumo atual vira o vetor de direção no plano da pista.
func set_mag_mode(on: bool, up_hint: Vector3 = Vector3.UP) -> void:
    if on == mag_mode:
        return
    if on:
        mag_up = up_hint.normalized()
        var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
        mag_heading = (f - mag_up * f.dot(mag_up)).normalized()
        _mag_air = 0.0
    else:
        var h := mag_heading
        if Vector2(h.x, h.z).length() > 0.05:
            yaw = atan2(-h.x, -h.z)
    mag_mode = on


func heading_vec() -> Vector3:
    if mag_mode:
        return mag_heading
    return Vector3(-sin(yaw), 0.0, -cos(yaw))


func boost(duration: float = 1.3) -> void:
    boost_time = maxf(boost_time, duration)
    _kick += 4.0
    boosted.emit()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    var dt := state.step

    if _teleport_pending:
        _teleport_pending = false
        state.transform = Transform3D(Basis.IDENTITY, _teleport_pos)
        state.linear_velocity = Vector3.ZERO
        state.angular_velocity = Vector3.ZERO
        yaw = _teleport_yaw
        steer = 0.0
        forward_speed = 0.0
        boost_time = 0.0
        spin_time = 0.0
        _kick = 0.0
        return

    state.angular_velocity = Vector3.ZERO
    var v := state.linear_velocity
    var origin := state.transform.origin

    # --- Sensor de chão: um raio curto para baixo devolve a normal da superfície.
    var up := mag_up if mag_mode else Vector3.UP
    var normal := up
    grounded = false
    var space := state.get_space_state()
    var query := PhysicsRayQueryParameters3D.create(origin, origin - up * (RADIUS + 0.55), 1)
    var ray_hit := space.intersect_ray(query)
    if not ray_hit.is_empty():
        var hn: Vector3 = ray_hit["normal"]
        if hn.dot(up) > 0.45:
            grounded = true
            normal = hn.normalized()
    if grounded:
        air_time = 0.0
        ground_normal = normal
        if mag_mode:
            mag_up = mag_up.slerp(normal, 0.6).normalized()
            up = mag_up
            _mag_air = 0.0
    else:
        air_time += dt
        if mag_mode:
            _mag_air += dt
            if mag_target != Vector3.ZERO and _mag_air <= 1.6:
                mag_up = mag_up.slerp(mag_target, clampf(7.0 * dt, 0.0, 1.0)).normalized()
                up = mag_up
            elif _mag_air > 0.7:       # perdeu a pista: a gravidade magnética relaxa e o kart cai normalmente
                mag_up = mag_up.slerp(Vector3.UP, clampf(2.5 * dt, 0.0, 1.0)).normalized()
                up = mag_up

    # --- Contato lateral (barreiras, árvores, rochas).
    wall_contact = false
    for i in state.get_contact_count():
        var cn := state.get_contact_local_normal(i)
        if absf(cn.dot(up)) < 0.5:
            wall_contact = true

    if wall_contact and not _prev_wall and absf(forward_speed) > 8.0:
        bumped.emit()
    _prev_wall = wall_contact
    spin_time = maxf(0.0, spin_time - dt)
    immunity = maxf(0.0, immunity - dt)

    # --- Entradas (jogador = ações de teclado/toque; adversário = IA).
    var throttle := 0.0
    var brake := 0.0
    var steer_target := 0.0
    var want_nitro := false
    if controls_enabled and spin_time <= 0.0:
        if ai_controlled:
            throttle = clampf(ai_throttle, 0.0, 1.0)
            brake = clampf(ai_brake, 0.0, 1.0)
            steer_target = clampf(ai_steer, -1.0, 1.0)
            want_nitro = ai_nitro
        else:
            throttle = clampf(Input.get_action_strength("accelerate"), 0.0, 1.0)
            brake = clampf(Input.get_action_strength("brake"), 0.0, 1.0)
            steer_target = clampf(Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"), -1.0, 1.0)
            want_nitro = Input.is_action_pressed("nitro")

    # Direção suavizada: não "trava" nos extremos, responde ao analógico.
    var steer_rate_in := 9.0 if absf(steer_target) > absf(steer) else 14.0
    steer = move_toward(steer, steer_target, steer_rate_in * dt)

    # --- Nitro (tanque) e impulso de pads.
    nitro_active = want_nitro and nitro > 0.03
    if nitro_active:
        nitro = maxf(0.0, nitro - nitro_drain * dt)
        throttle = 1.0
    else:
        nitro = minf(1.0, nitro + nitro_regen * dt)
    boost_time = maxf(0.0, boost_time - dt)
    external_boost = maxf(0.0, external_boost - dt)
    var boosting := nitro_active or boost_time > 0.0 or external_boost > 0.0

    var cap := max_speed * speed_factor
    if not on_road:
        cap *= 0.62
    if boosting:
        cap += nitro_speed_bonus
    var acc := acceleration
    if boosting:
        acc *= 2.4
    if not on_road:
        acc *= 0.7

    var f_flat := Vector3(-sin(yaw), 0.0, -cos(yaw))
    if mag_mode:
        f_flat = (mag_heading - up * mag_heading.dot(up)).normalized()

    if grounded:
        var fwd := (f_flat - normal * f_flat.dot(normal)).normalized()
        var right := fwd.cross(normal).normalized()
        var fs := v.dot(fwd)
        var ls := v.dot(right)
        var fs0 := fs
        var ls0 := ls

        fs += _kick
        _kick = 0.0

        if brake > 0.05 and throttle > 0.05 and fs > 0.6:
            throttle = 0.0
        if throttle > 0.01:
            if fs < cap:
                fs = minf(cap, fs + acc * throttle * (1.0 - clampf(fs / cap, 0.0, 1.0) * 0.8) * dt)
        if fs > cap:
            fs = maxf(cap, fs - (14.0 + drag_over * (fs - cap)) * dt)
        if brake > 0.01:
            if fs > 0.6:
                fs = maxf(0.0, fs - brake_decel * brake * dt)
            else:
                fs = maxf(-reverse_speed, fs - acceleration * 0.6 * brake * dt)
        elif throttle <= 0.01:
            var drag := coast_drag * (2.5 if not on_road else 1.0)
            fs = move_toward(fs, 0.0, drag * dt)
        if spin_time > 0.0:
            fs = move_toward(fs, 0.0, 28.0 * dt)
        if not on_road and throttle > 0.01:
            fs = move_toward(fs, minf(fs, cap), 6.0 * dt)
        if wall_contact:
            fs *= (1.0 - 1.4 * dt)

        # Aderência lateral: escorrega um pouco em curvas fortes e em alta velocidade.
        var speed_ratio := clampf(absf(fs) / max_speed, 0.0, 1.0)
        var g := grip * grip_mod * (1.0 - 0.28 * absf(steer) * speed_ratio)
        ls *= exp(-g * dt)

        v += fwd * (fs - fs0) + right * (ls - ls0)

        # Mantém o kart colado em lombas suaves (mas deixa decolar nas rampas).
        var vn := v.dot(normal)
        if vn > 0.0 and vn < 4.5:
            v -= normal * vn

        # Esterçamento: precisa estar em movimento; inverte ao dar ré.
        var steer_speed := clampf(absf(fs) / 7.0, 0.0, 1.0)
        var high_speed := 1.0 - 0.30 * speed_ratio
        var dir := 1.0 if fs > -0.5 else -1.0
        var dyaw := steer * steer_rate * steer_speed * high_speed * dir * dt
        if mag_mode:
            mag_heading = f_flat.rotated(up, -dyaw).normalized()
        else:
            yaw -= dyaw
    else:
        # No ar: quase sem controle, só um leve ajuste de direção.
        if mag_mode:
            mag_heading = f_flat.rotated(up, -steer * steer_rate * 0.25 * dt).normalized()
        else:
            yaw -= steer * steer_rate * 0.25 * dt
        v *= (1.0 - 0.01 * dt)

    v -= up * (gravity * grav_mod * dt)
    v = v.limit_length(60.0)
    state.linear_velocity = v

    if mag_mode:
        mag_heading = (mag_heading - up * mag_heading.dot(up)).normalized()
        if Vector2(mag_heading.x, mag_heading.z).length() > 0.15:
            yaw = atan2(-mag_heading.x, -mag_heading.z)
        forward_speed = v.dot(mag_heading)
    else:
        forward_speed = v.dot(Vector3(-sin(yaw), 0.0, -cos(yaw)))


func _physics_process(delta: float) -> void:
    if visual == null:
        return
    var target_up := ground_normal if grounded else (mag_up if mag_mode else Vector3.UP)
    _visual_up = _visual_up.slerp(target_up, clampf(10.0 * delta, 0.0, 1.0)).normalized()

    var f := heading_vec()
    f = (f - _visual_up * f.dot(_visual_up)).normalized()
    var r := f.cross(_visual_up).normalized()
    var b := Basis(r, _visual_up, -f).orthonormalized()
    var speed_ratio := clampf(absf(forward_speed) / max_speed, 0.0, 1.0)
    b = b * Basis(Vector3(0.0, 0.0, 1.0), -steer * 0.09 * speed_ratio)
    if spin_time > 0.0:
        var prog := 1.0 - spin_time / maxf(spin_total, 0.1)
        b = Basis(_visual_up, prog * TAU * 2.0) * b
    visual.global_transform = Transform3D(b, global_position - _visual_up * RADIUS)

    var show_flames := nitro_active or boost_time > 0.0
    for fl in flames:
        fl.visible = show_flames


func _ensure_actions() -> void:
    _ensure_action("accelerate", [KEY_W, KEY_UP])
    _ensure_action("brake", [KEY_S, KEY_DOWN])
    _ensure_action("steer_left", [KEY_A, KEY_LEFT])
    _ensure_action("steer_right", [KEY_D, KEY_RIGHT])
    _ensure_action("nitro", [KEY_SHIFT, KEY_SPACE])


func _ensure_action(action_name: String, keys: Array) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    if InputMap.action_get_events(action_name).is_empty():
        for k in keys:
            var event := InputEventKey.new()
            event.physical_keycode = k as Key
            InputMap.action_add_event(action_name, event)
