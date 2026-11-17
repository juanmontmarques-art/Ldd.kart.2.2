class_name CoinManager
extends Node3D

# Moedas espalhadas pela pista (grupos de 5 em linha). Só o jogador coleta.
# As moedas reaparecem a cada volta. Cada moeda coletada vai direto para o SaveGame
# (então nada se perde se você sair da corrida no meio).

signal collected(total_in_race: int)

const GROUP_EVERY := 70      # amostras entre grupos (~175 m)
const GROUP_SIZE := 5
const GROUP_SPACING := 4     # amostras entre moedas do grupo (10 m)
const PICK_RADIUS := 2.4

var track: TrackData
var player: Racer
var multiplier := 1.0
var total_in_race := 0

var _coins: Array[Node3D] = []
var _hidden: Array[bool] = []
var _carry := 0.0
var _t := 0.0


func setup(t: TrackData, p: Racer, mult: float) -> void:
    track = t
    player = p
    multiplier = mult
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.5
    mesh.bottom_radius = 0.5
    mesh.height = 0.10
    mesh.radial_segments = 20
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.80, 0.15)
    mat.metallic = 0.7
    mat.roughness = 0.3
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.65, 0.05)
    mat.emission_energy_multiplier = 0.8

    var blocked: Array[int] = []
    blocked.append_array(track.pad_spots)
    blocked.append_array(track.ramp_spots)
    blocked.append_array(track.barrel_spots)
    blocked.append_array(track.mover_spots)

    var start := 40
    var i := start
    var lane_toggle := 0
    while i < track.count - GROUP_EVERY:
        var lat: float = [-3.0, 0.0, 3.0][lane_toggle % 3]
        lane_toggle += 1
        for k in GROUP_SIZE:
            var idx := i + k * GROUP_SPACING
            if _near_problem(idx, blocked):
                continue
            _make_coin(mesh, mat, idx, lat)
        i += GROUP_EVERY


func _near_problem(idx: int, blocked: Array[int]) -> bool:
    for g in track.gaps:
        if idx > int(g.x) - 14 and idx < int(g.x) + int(g.y) + 14:
            return true
    for b in blocked:
        if absi(idx - b) < 10:
            return true
    return false


func _make_coin(mesh: Mesh, mat: Material, idx: int, lat: float) -> void:
    var root := Node3D.new()
    root.name = "Moeda"
    root.position = track.at(idx, lat) + Vector3(0.0, 1.25, 0.0)
    root.rotation.y = float(idx) * 0.7
    add_child(root)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)   # disco em pé
    root.add_child(mi)
    _coins.append(root)
    _hidden.append(false)


func _process(delta: float) -> void:
    _t += delta
    for i in _coins.size():
        if _hidden[i]:
            continue
        var c := _coins[i]
        c.rotation.y += delta * 3.2


func _physics_process(_delta: float) -> void:
    if player == null:
        return
    var pp := player.body.global_position
    var r2 := PICK_RADIUS * PICK_RADIUS
    for i in _coins.size():
        if _hidden[i]:
            continue
        if _coins[i].global_position.distance_squared_to(pp) <= r2:
            _pick(i)


func _pick(i: int) -> void:
    _hidden[i] = true
    _coins[i].visible = false
    _carry += multiplier
    var whole := int(floor(_carry))
    _carry -= float(whole)
    if whole > 0:
        SaveGame.add_coins(whole, true)
        total_in_race += whole
    collected.emit(total_in_race)


# Chame ao completar uma volta: as moedas voltam para a pista.
func respawn_all() -> void:
    for i in _coins.size():
        _hidden[i] = false
        _coins[i].visible = true
