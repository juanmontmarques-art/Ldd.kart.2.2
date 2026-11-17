class_name ItemManager
extends Node3D

# Caixas de item, bananas e cascos teleguiados.
#  - Turbo: impulso forte por ~2 s.
#  - Banana: cai atrás do kart; quem pisar rodopia.
#  - Casco: segue a pista, mira no piloto à frente e o faz rodopiar.
# Quanto pior a posição, melhores (mais ofensivos/turbo) os itens.

signal picked(racer: Racer)
signal used(racer: Racer, item_name: String)
signal victim_hit(racer: Racer)

var track: TrackData
var racers: Array[Racer] = []
var boxes: Array[Node3D] = []
var bananas: Array[Node3D] = []
var shells: Array[Node3D] = []


func setup(t: TrackData, list: Array[Racer]) -> void:
    track = t
    racers = list
    var spots: Array[int] = track.box_spots
    var lats: Array[float] = [-4.5, 0.0, 4.5]
    for s in spots:
        for l in lats:
            _make_box(s % track.count, l)


func _make_box(i: int, lat: float) -> void:
    var root := Node3D.new()
    root.name = "CaixaItem"
    root.position = track.at(i, lat) + Vector3(0.0, 1.5, 0.0)
    add_child(root)

    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.3, 1.3, 1.3)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.75, 0.1, 0.85)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.55, 0.1)
    mat.emission_energy_multiplier = 0.9
    var mi := MeshInstance3D.new()
    mi.name = "Caixa"
    mi.mesh = mesh
    mi.material_override = mat
    mi.rotation.x = 0.5
    root.add_child(mi)

    var lab := Label3D.new()
    lab.text = "?"
    lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    lab.font_size = 96
    lab.pixel_size = 0.012
    lab.outline_size = 18
    lab.modulate = Color(1, 1, 1)
    root.add_child(lab)

    var area := Area3D.new()
    area.collision_layer = 0
    area.collision_mask = 2
    var cs := CollisionShape3D.new()
    var sh := SphereShape3D.new()
    sh.radius = 1.6
    cs.shape = sh
    area.add_child(cs)
    area.body_entered.connect(_on_box_entered.bind(root))
    root.add_child(area)
    root.set_meta("cd", 0.0)
    boxes.append(root)


func _racer_of(body: Node) -> Racer:
    for r in racers:
        if r.body == body:
            return r
    return null


func _on_box_entered(body: Node3D, root: Node3D) -> void:
    if not (body is KartBody):
        return
    var cd: float = root.get_meta("cd", 0.0)
    if cd > 0.0:
        return
    var r := _racer_of(body)
    if r == null or r.body.item != "":
        return
    r.body.item = _roll(r)
    root.set_meta("cd", 6.0)
    root.visible = false
    picked.emit(r)


func _roll(r: Racer) -> String:
    var n := racers.size()
    var rk := float(r.rank - 1) / float(maxi(n - 1, 1))
    var w_turbo := 25.0 + 35.0 * rk
    var w_banana := 45.0 - 30.0 * rk
    var w_casco := 20.0 + 15.0 * rk
    var x := randf() * (w_turbo + w_banana + w_casco)
    if x < w_turbo:
        return "turbo"
    x -= w_turbo
    if x < w_banana:
        return "banana"
    return "casco"


func use_item(r: Racer) -> void:
    var it := r.body.item
    if it == "":
        return
    r.body.item = ""
    match it:
        "turbo":
            r.body.boost(2.2)
        "banana":
            _spawn_banana(r)
        "casco":
            _spawn_shell(r)
    used.emit(r, it)


func _spawn_banana(r: Racer) -> void:
    var k := r.body
    var fwd := Vector3(-sin(k.yaw), 0.0, -cos(k.yaw))
    var pos := k.global_position - fwd * 3.4 - Vector3(0.0, KartBody.RADIUS - 0.35, 0.0)
    var root := Node3D.new()
    root.name = "Banana"
    root.position = pos
    add_child(root)
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.22
    mesh.height = 1.15
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.88, 0.12)
    mat.roughness = 0.5
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    mi.position = Vector3(0.0, 0.3, 0.0)
    root.add_child(mi)
    var area := Area3D.new()
    area.collision_layer = 0
    area.collision_mask = 2
    var cs := CollisionShape3D.new()
    var sh := SphereShape3D.new()
    sh.radius = 1.2
    cs.shape = sh
    cs.position = Vector3(0.0, 0.6, 0.0)
    area.add_child(cs)
    area.body_entered.connect(_on_banana.bind(root, r))
    root.add_child(area)
    root.set_meta("age", 0.0)
    bananas.append(root)


func _on_banana(body: Node3D, banana: Node3D, who: Racer) -> void:
    if not (body is KartBody):
        return
    if not is_instance_valid(banana) or banana.is_queued_for_deletion():
        return
    var age: float = banana.get_meta("age", 0.0)
    if body == who.body and age < 0.8:
        return
    var victim := _racer_of(body)
    if victim == null:
        return
    if victim.body.spin(1.5):
        victim_hit.emit(victim)
        banana.queue_free()


func _spawn_shell(r: Racer) -> void:
    var target: Racer = null
    var best := 1 << 30
    for o in racers:
        if o == r:
            continue
        var gap := o.total_progress - r.total_progress
        if gap > 0 and gap < best:
            best = gap
            target = o
    var root := Node3D.new()
    root.name = "Casco"
    add_child(root)
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.9, 0.12, 0.1)
    mat.emission_enabled = true
    mat.emission = Color(0.9, 0.1, 0.1)
    mat.emission_energy_multiplier = 0.6
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    root.add_child(mi)
    var stripe := MeshInstance3D.new()
    var smesh := CylinderMesh.new()
    smesh.top_radius = 0.52
    smesh.bottom_radius = 0.52
    smesh.height = 0.16
    var smat := StandardMaterial3D.new()
    smat.albedo_color = Color(1, 1, 1)
    stripe.mesh = smesh
    stripe.material_override = smat
    root.add_child(stripe)
    var center := track.pts[r.cur_idx]
    var lat0 := (r.body.global_position - center).dot(track.sides[r.cur_idx])
    root.set_meta("idx", float(r.cur_idx + 3))
    root.set_meta("lat", lat0)
    root.set_meta("target", target)
    root.set_meta("owner_racer", r)
    root.set_meta("life", 7.0)
    root.global_position = r.body.global_position + Vector3(0.0, 0.3, 0.0)
    shells.append(root)


func _process(delta: float) -> void:
    for b in boxes:
        var cd: float = b.get_meta("cd", 0.0)
        if cd > 0.0:
            cd -= delta
            b.set_meta("cd", cd)
            if cd <= 0.0:
                b.visible = true
        else:
            var mi: Node3D = b.get_node("Caixa")
            mi.rotation.y += delta * 1.6
    for i in range(bananas.size() - 1, -1, -1):
        var ban := bananas[i]
        if not is_instance_valid(ban) or ban.is_queued_for_deletion():
            bananas.remove_at(i)
            continue
        var age: float = ban.get_meta("age", 0.0) + delta
        ban.set_meta("age", age)
        if age > 45.0:
            ban.queue_free()
            bananas.remove_at(i)
    _update_shells(delta)


func _update_shells(delta: float) -> void:
    for i in range(shells.size() - 1, -1, -1):
        var s := shells[i]
        if not is_instance_valid(s) or s.is_queued_for_deletion():
            shells.remove_at(i)
            continue
        var life: float = s.get_meta("life", 0.0) - delta
        s.set_meta("life", life)
        var idx: float = s.get_meta("idx", 0.0) + 60.0 / TrackData.SPACING * delta
        idx = fposmod(idx, float(track.count))
        s.set_meta("idx", idx)
        var i0 := int(floor(idx)) % track.count
        var i1 := (i0 + 1) % track.count
        var center := track.pts[i0].lerp(track.pts[i1], idx - floor(idx))
        var side := track.sides[i0]
        var lat: float = s.get_meta("lat", 0.0)
        var tgt: Racer = s.get_meta("target", null)
        if tgt != null:
            var want := clampf((tgt.body.global_position - center).dot(side), -6.5, 6.5)
            lat = move_toward(lat, want, 9.0 * delta)
            s.set_meta("lat", lat)
        s.global_position = center + side * lat + Vector3(0.0, 0.9, 0.0)
        s.rotation.y += delta * 8.0
        var who: Racer = s.get_meta("owner_racer", null)
        var consumed := false
        for r in racers:
            if r == who:
                continue
            if r.body.global_position.distance_to(s.global_position) < 2.3:
                if r.body.spin(1.7):
                    victim_hit.emit(r)
                    consumed = true
                    break
        if life <= 0.0 or consumed:
            s.queue_free()
            shells.remove_at(i)
