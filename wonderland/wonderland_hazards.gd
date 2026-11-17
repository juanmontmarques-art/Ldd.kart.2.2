class_name WonderlandHazards
extends RefCounted

# Hazards: lava (visual + dano real: queda na lava = volta ao último checkpoint), abismos com rampa de lançamento,
# elementos herdados do jogo base (nitro, rampas, barris, barreiras móveis, placas) ajustados à Wonderland.

var world: Node3D
var track: TrackData
var layout: Dictionary
var road: WonderlandTrack
var terrain: WonderlandTerrain
var main_ref: Node = null
var lava_ranges: Array = []
var burn_cd := {}
var checks: WonderlandCheckpoints = null


func build(w: Node3D, tr: TrackData, lay: Dictionary, rd: WonderlandTrack, terr: WonderlandTerrain) -> void:
    world = w
    track = tr
    layout = lay
    road = rd
    terrain = terr
    var secs: Array = layout["sectors"]
    var s6: Vector2i = secs[5]
    lava_ranges.push_back([s6.x, s6.y])
    # recursos do mundo base, reaproveitados (usam apenas TrackData): pads de nitro, rampas de salto, barris, barreiras móveis
    world._make_boost_pads()
    world._make_ramps()
    world._make_obstacles()
    world._make_gap_signs()
    var hd := HazardDriver.new()
    hd.name = "Wonderland_Hazards"
    hd.owner_ref = self
    world.add_child(hd)


class HazardDriver extends Node:
    var owner_ref: WonderlandHazards
    func _physics_process(delta: float) -> void:
        owner_ref.tick(delta)


var under_t := {}


func attach(main: Node) -> void:
    main_ref = main


func tick(_delta: float) -> void:
    if main_ref == null:
        return
    for r in main_ref.racers:
        var idx: int = r.cur_idx
        if r.branch >= 0 and r.last_good_branch != r.branch:
            pass
        # Atravessou o tabuleiro (aterrissagem rápida): fica preso por baixo da pista -> volta ao checkpoint.
        var kname: String = r.display_name
        var below := false
        if r.branch < 0 and track.lift_index(idx) < 0:
            var gp: Vector3 = r.body.global_position
            var dn := (gp - track.pts[idx]).dot(track.ups[idx])
            below = dn < -2.0 and dn > -12.0 and track.flat_distance(gp, idx) < track.half_at(idx) + 0.5
        if below:
            under_t[kname] = float(under_t.get(kname, 0.0)) + _delta
            if under_t[kname] > 1.2:
                under_t[kname] = 0.0
                _burn(r)
        else:
            under_t[kname] = 0.0
        for lr in lava_ranges:
            if idx >= lr[0] and idx <= lr[1]:
                var py: float = r.body.global_position.y
                var ry: float = track.pts[idx].y
                if r.branch >= 0:
                    var bp: PackedVector3Array = track.branches[r.branch]["pts"]
                    ry = bp[r.bidx].y
                if py < ry - 3.4 and r.body.global_position.y > ry - 14.0 and track.lift_index(idx) < 0:
                    _burn(r)


func _burn(r: Racer) -> void:
    var key := r.display_name
    if burn_cd.has(key) and Time.get_ticks_msec() - burn_cd[key] < 1500:
        return
    burn_cd[key] = Time.get_ticks_msec()
    var cp := -1
    if checks != null:
        cp = checks.last_checkpoint(r)
    if cp >= 0 and posmod(r.cur_idx - cp, track.count) < 260:
        r.last_good_idx = cp
        r.respawn(track, 0)
    else:
        r.respawn(track, 18)
    if r.is_player and main_ref != null and main_ref.has_method("_reward_line"):
        main_ref.call("_reward_line", "De volta ao checkpoint", Color(1.0, 0.45, 0.15))
