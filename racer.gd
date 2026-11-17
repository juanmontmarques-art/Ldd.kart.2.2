class_name Racer
extends RefCounted

# Dados de um piloto (jogador ou adversário): kart, progresso na pista, voltas.

var body: KartBody
var visual: Node3D
var display_name := ""
var color := Color.WHITE
var is_player := false
var cur_idx := 0
var total_progress := 0
var last_good_idx := 0
var lap_count := 0
var finished := false
var finish_time := 0.0
var rank := 1
var ai: AiDriver
var engine3d: AudioStreamPlayer3D
var stuck_time := 0.0
var offtrack_time := 0.0
var fall_time := 0.0


var branch := -1            # atalho atual (-1 = pista principal)
var bidx := 0               # amostra dentro do atalho
var last_good_branch := -1
var last_good_bidx := 0


func ground_y(track: TrackData) -> float:
    if branch >= 0:
        var bp: PackedVector3Array = track.branches[branch]["pts"]
        return bp[bidx].y
    if track.lifts.size() > 0 or track.mags.size() > 0:
        var li := track.lift_index(cur_idx)
        if li >= 0:
            return track.pts[maxi(int(track.lifts[li].x) - 1, 0)].y - 2.0
        if track.is_mag(cur_idx):
            return track.pts[cur_idx].y - 45.0
    return track.pts[cur_idx].y


func _branch_virtual(track: TrackData, br: Dictionary, k: int) -> int:
    var m: int = br["count"]
    return int(br["a"]) + int(round(float(int(br["span"])) * float(k) / float(maxi(m - 1, 1))))


func _apply_virtual(track: TrackData, v: int) -> void:
    var new_idx := posmod(v, track.count)
    var diff := new_idx - cur_idx
    var half := track.count / 2
    if diff > half:
        diff -= track.count
    elif diff < -half:
        diff += track.count
    total_progress += diff
    cur_idx = new_idx


func update_progress(track: TrackData) -> float:
    var pos := body.global_position
    if branch >= 0:
        var br: Dictionary = track.branches[branch]
        var bp: PackedVector3Array = br["pts"]
        var m: int = br["count"]
        var bhalf: float = br["half"]
        bidx = track.nearest_open(bp, pos, bidx, 10)
        _apply_virtual(track, _branch_virtual(track, br, bidx))
        var bl := sqrt(pow(bp[bidx].x - pos.x, 2.0) + pow(bp[bidx].z - pos.z, 2.0))
        body.on_road = bl < bhalf + 0.8 and pos.y > bp[bidx].y - 3.0
        if body.on_road and body.grounded:
            last_good_idx = cur_idx
            last_good_branch = branch
            last_good_bidx = bidx
        # Altura: se o kart está fisicamente na pista principal (atalho passa por baixo/por cima), volta para ela.
        if absf(pos.y - bp[bidx].y) > 2.8 or bl > bhalf + 3.0:
            var mj := track.nearest(pos, cur_idx, 14)
            if absf(pos.y - track.pts[mj].y) < 2.8 and track.flat_distance(pos, mj) < track.half_at(mj) + 0.8:
                branch = -1
                cur_idx = mj
                return track.flat_distance(pos, mj)
        # Saída do atalho: chegou ao fim, ou voltou para a pista principal perto da bifurcação.
        if bidx >= m - 4:
            branch = -1
            cur_idx = posmod(int(br["c"]), track.count)
        elif bidx <= 3:
            var mi := track.nearest(pos, cur_idx, 14)
            if track.flat_distance(pos, mi) < bl:
                branch = -1
                cur_idx = mi
        return bl

    var new_idx := track.nearest(pos, cur_idx, 14)
    var diff := new_idx - cur_idx
    var half := track.count / 2
    if diff > half:
        diff -= track.count
    elif diff < -half:
        diff += track.count
    total_progress += diff
    cur_idx = new_idx
    var lateral := track.flat_distance(pos, cur_idx)
    var road_y := track.pts[cur_idx].y
    if track.mags.size() > 0:
        var mg := track.is_mag(cur_idx)
        if mg != body.mag_mode:
            body.set_mag_mode(mg, track.normal_at(cur_idx))
        body.mag_target = track.normal_at(cur_idx) if mg else Vector3.ZERO
        if mg:
            body.on_road = lateral < track.half_at(cur_idx) + 3.0
        else:
            body.on_road = lateral < track.half_at(cur_idx) + 0.8 and pos.y > road_y - 3.0
    else:
        body.on_road = lateral < track.half_at(cur_idx) + 0.8 and pos.y > road_y - 3.0
    if body.on_road and body.grounded:
        last_good_idx = cur_idx
        last_good_branch = -1
    # Entrada num atalho: o kart está mais perto do eixo do atalho do que da pista principal.
    for br in track.branches:
        var rel := posmod(cur_idx - int(br["a"]) + 25, track.count) - 25
        if rel < -25 or rel > 70:
            continue
        var bp2: PackedVector3Array = br["pts"]
        var bhalf2: float = br["half"]
        var best_k := -1
        var best_d := INF
        for k in range(0, mini(48, int(br["count"]))):
            var d := sqrt(pow(bp2[k].x - pos.x, 2.0) + pow(bp2[k].z - pos.z, 2.0))
            if d < best_d:
                best_d = d
                best_k = k
        if best_k >= 4 and best_d < lateral - 2.5 and best_d < bhalf2 + 1.0 and absf(pos.y - bp2[best_k].y) < 2.5:
            branch = int(br["id"])
            bidx = best_k
            break
    return lateral


# "back" = quantas amostras recuar (cair num abismo recua mais, para tomar embalo).
func respawn(track: TrackData, back_samples: int = 6) -> void:
    offtrack_time = 0.0
    stuck_time = 0.0
    fall_time = 0.0
    if branch >= 0 and last_good_branch == branch:
        var br: Dictionary = track.branches[branch]
        var bp: PackedVector3Array = br["pts"]
        var bt: PackedVector3Array = br["tans"]
        bidx = maxi(last_good_bidx - back_samples, 0)
        _apply_virtual(track, _branch_virtual(track, br, bidx))
        last_good_idx = cur_idx
        var tn := bt[bidx]
        body.teleport(bp[bidx] + Vector3(0.0, KartBody.RADIUS + 0.4, 0.0), atan2(-tn.x, -tn.z))
        return
    branch = -1
    last_good_idx = track.safe_index_before(posmod(last_good_idx - back_samples, track.count))
    var back := cur_idx - last_good_idx
    var half := track.count / 2
    if back > half:
        back -= track.count
    elif back < -half:
        back += track.count
    total_progress -= back
    cur_idx = last_good_idx
    var up_n := track.normal_at(cur_idx) if track.is_mag(cur_idx) else Vector3.UP
    if track.is_mag(cur_idx):
        body.set_mag_mode(true, up_n)
        body.mag_up = up_n
        var tn2 := track.tans[cur_idx]
        body.mag_heading = (tn2 - up_n * tn2.dot(up_n)).normalized()
    else:
        body.set_mag_mode(false)
    body.teleport(track.pts[cur_idx] + up_n * (KartBody.RADIUS + 0.4), track.yaw_at(cur_idx))
