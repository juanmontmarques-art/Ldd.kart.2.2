class_name AiDriver
extends RefCounted

# Piloto automático: mira num ponto à frente na pista, freia antes de curvas
# fechadas, usa nitro nas retas e usa os itens que pega.

var racer: Racer
var track: TrackData
var items: ItemManager
var racers: Array[Racer] = []
var lane := 0.0
var skill := 0.96
var item_wait := 2.0
var _phase := 0.0


func setup(r: Racer, t: TrackData, im: ItemManager, all: Array[Racer], lane_offset: float, skill_value: float) -> void:
    racer = r
    track = t
    items = im
    racers = all
    lane = lane_offset
    skill = skill_value
    _phase = randf() * TAU
    racer.body.ai_controlled = true


func update(delta: float, racing: bool) -> void:
    var kart := racer.body
    if not racing or racer.finished:
        kart.ai_throttle = 0.0
        kart.ai_brake = 0.3 if racer.finished else 0.0
        kart.ai_steer = 0.0
        kart.ai_nitro = false
        return

    _phase += delta * 0.6
    var n := track.count
    var speed := absf(kart.forward_speed)
    var look := clampi(int(6.0 + speed * 0.5), 7, 22)
    var ti := (racer.cur_idx + look) % n
    var lat := _avoid(lane + sin(_phase) * 1.2)
    var hw_ahead := track.half_at(ti)
    var hw_here := track.half_at(racer.cur_idx)
    var hw := minf(hw_ahead, hw_here)
    if hw < 7.0:
        lat = clampf(lat, -hw + 2.4, hw - 2.4)
    var target := track.at(ti, lat)
    var to := target - kart.global_position
    var desired := atan2(-to.x, -to.z)
    var diff := wrapf(desired - kart.yaw, -PI, PI)
    if kart.mag_mode:
        # Gravidade magnética: o ângulo de esterço é medido em torno da normal da pista (vale de cabeça para baixo).
        var upv := kart.mag_up
        var tp := to - upv * to.dot(upv)
        if tp.length() > 0.01:
            diff = kart.mag_heading.signed_angle_to(tp.normalized(), upv)
    kart.ai_steer = clampf(-diff * 2.4, -1.0, 1.0)

    # Curva à frente -> velocidade-alvo menor.
    var far := (racer.cur_idx + 20) % n
    var t0 := track.tans[racer.cur_idx]
    var t1 := track.tans[far]
    var cross_y := t0.x * t1.z - t0.z * t1.x
    var dot := t0.x * t1.x + t0.z * t1.z
    var ang := absf(atan2(cross_y, dot))
    var target_speed := kart.max_speed * kart.speed_factor * lerpf(1.0, 0.5, clampf(ang / 1.0, 0.0, 1.0))
    if track.map_id == "wonderland" and racer.body.mag_mode:
        target_speed = minf(target_speed, 14.0)
    if track.map_id == "wonderland" and racer.branch < 0 and WonderlandMechanics.blocked_ahead(racer.cur_idx, clampi(int(speed * 0.5) + 6, 8, 24), n):
        target_speed = 2.0   # portão/ponte/elevador fechado à frente: espera
    if speed > target_speed + 2.0:
        kart.ai_throttle = 0.0
        kart.ai_brake = clampf((speed - target_speed) / 12.0, 0.0, 0.8)
    else:
        kart.ai_throttle = 1.0 if absf(diff) < 0.9 else 0.5
        kart.ai_brake = 0.0
    kart.ai_nitro = ang < 0.1 and kart.nitro > 0.3 and speed > 12.0 and absf(diff) < 0.1

    # Itens
    if kart.item != "":
        item_wait -= delta
        if item_wait <= 0.0:
            var use := false
            match kart.item:
                "turbo":
                    use = true
                "banana":
                    use = _someone_behind(40)
                "casco":
                    use = _someone_ahead(120)
            if use or item_wait < -5.0:
                items.use_item(racer)
                item_wait = randf_range(1.5, 3.5)
    else:
        item_wait = maxf(item_wait, 1.0)


func _someone_behind(max_samples: int) -> bool:
    for r in racers:
        if r == racer:
            continue
        var gap := racer.total_progress - r.total_progress
        if gap > 0 and gap < max_samples:
            return true
    return false


func _someone_ahead(max_samples: int) -> bool:
    for r in racers:
        if r == racer:
            continue
        var gap := r.total_progress - racer.total_progress
        if gap > 0 and gap < max_samples:
            return true
    return false


# Desvia de aglomerados de barris e barreiras móveis logo à frente.
func _avoid(lat_in: float) -> float:
    var lat := lat_in
    for z in track.obstacle_zones:
        var ahead := int(z.x) - racer.cur_idx
        if ahead < -2:
            ahead += track.count
        if ahead < 0 or ahead > 32:
            continue
        if absf(lat - z.y) < z.z + 2.2:
            var dir := 1.0 if lat >= z.y else -1.0
            lat = clampf(z.y + dir * (z.z + 2.6), -6.0, 6.0)
    return lat
