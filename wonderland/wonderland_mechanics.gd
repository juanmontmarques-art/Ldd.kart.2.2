class_name WonderlandMechanics
extends RefCounted

# Os 14 mecanismos da Wonderland, todos determinísticos no tempo (relógio local), com animação, colisão (AnimatableBody3D),
# gatilhos (Area/proximidade) e integração com a IA (zonas dinâmicas e "bloqueios" que fazem os pilotos frearem).
#  1 portões/portcullis  2 pedregulhos rolantes  3 queda de rochas do teto  4 gêiseres lançadores
#  5 plataformas que desabam  6 pontes deslizantes (passagem fecha)  7 elevadores com barreira  8 rampas móveis
#  9 cristais-gatilho  10 atalho secreto (porta de cristal)  11 faixas de turbo  12 piso escorregadio
#  13 obstáculos que emergem  14 zona de baixa gravidade

static var blockers: Array = []      # [início, fim, fechado(bool)] para a IA
static var clock := 0.0

var world: Node3D
var track: TrackData
var layout: Dictionary
var road: WonderlandTrack
var terrain: WonderlandTerrain
var root: Node3D
var main_ref: Node = null
var items: Array = []                 # dicionários dos mecanismos (cada um com "tick": Callable)
var triggers := {}                    # nome -> segundos restantes
var rock_mat: ShaderMaterial
var racers: Array = []
var slick_ranges: Array = []
var lowgrav_ranges: Array = []
var boost_ranges: Array = []
var _prev_grip := {}


class Driver extends Node:
    var owner_ref: WonderlandMechanics
    func _physics_process(delta: float) -> void:
        owner_ref.tick(delta)


static func blocked_ahead(idx: int, look: int, count: int) -> bool:
    for b in blockers:
        if not b[2]:
            continue
        var ahead := posmod(int(b[0]) - idx, count)
        if ahead >= 0 and ahead <= look:
            return true
    return false


func gate_blocks(idx: int, ahead: int) -> bool:
    return WonderlandMechanics.blocked_ahead(idx, ahead, track.count)


func build(w: Node3D, tr: TrackData, lay: Dictionary, rd: WonderlandTrack, terr: WonderlandTerrain) -> void:
    world = w
    track = tr
    layout = lay
    road = rd
    terrain = terr
    blockers.clear()
    clock = 0.0
    root = Node3D.new()
    root.name = "Wonderland_Mechanics"
    world.add_child(root)
    rock_mat = WonderlandMaterials.rock(Color(0.34, 0.31, 0.29), Color(0.66, 0.6, 0.54), 0.2, 0.0, 0.5)
    var drv := Driver.new()
    drv.owner_ref = self
    drv.name = "Relogio"
    root.add_child(drv)
    var crystals := []
    for m in layout["mech"]:
        match m["t"]:
            "gate": _gate(m)
            "boulder": _boulder(m)
            "rockfall": _rockfall(m)
            "geyser": _geyser(m)
            "slider": _slider(m)
            "emerge": _emerge(m)
            "tiltramp": _tiltramp(m, false)
            "lifts_small": _tiltramp(m, true)
            "lift": _lift(m)
            "boost": _boost(m)
            "slick": _slick(m)
            "lowgrav": _lowgrav(m)
            "crystal": crystals.push_back(m)
    for m in layout["mech"]:
        if m["t"] == "collapse":
            _collapse(m)
    for cm in crystals:
        _crystal(cm)
    _secret_door()


func attach(main: Node) -> void:
    main_ref = main
    racers = main.racers


# ------------------------------------------------------------------ helpers
func _tbasis(i: int) -> Basis:
    var t := track.tans[i]
    var up := track.ups[i]
    return Basis.looking_at(t, up).orthonormalized()


func _abody(parent: Node3D) -> AnimatableBody3D:
    var b := AnimatableBody3D.new()
    b.sync_to_physics = true
    b.collision_layer = 1
    b.collision_mask = 0
    parent.add_child(b)
    return b


func _mesh(mb: MeshBuilder, mat: Material, parent: Node3D) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mb.to_mesh()
    mi.material_override = mat
    mi.visibility_range_end = 700.0
    parent.add_child(mi)
    return mi


func _box_shape(size: Vector3) -> BoxShape3D:
    var bs := BoxShape3D.new()
    bs.size = size
    return bs


func _col(parent: Node3D, shape: Shape3D, pos: Vector3 = Vector3.ZERO) -> CollisionShape3D:
    var cs := CollisionShape3D.new()
    cs.shape = shape
    cs.position = pos
    parent.add_child(cs)
    return cs


func _hash(n: int, salt: int) -> float:
    var x := sin(float(n) * 12.9898 + float(salt) * 78.233) * 43758.5453
    return x - floor(x)


func _racer_near(pos: Vector3, rad: float, vert: float) -> Racer:
    for r in racers:
        var d: Vector3 = r.body.global_position - pos
        if Vector2(d.x, d.z).length() < rad and absf(d.y) < vert:
            return r
    return null


func _glow_ball(pos: Vector3, col: Color, parent: Node3D, radius: float = 0.35) -> MeshInstance3D:
    var sm := SphereMesh.new()
    sm.radius = radius
    sm.height = radius * 2.0
    sm.radial_segments = 8
    sm.rings = 4
    var mi := MeshInstance3D.new()
    mi.mesh = sm
    mi.material_override = WonderlandMaterials.glow(col, 3.0)
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


func _hurt(r: Racer, dur: float = 1.3) -> void:
    if r.body.immunity > 0.0 or r.body.spin_time > 0.0:
        return
    r.body.spin(dur)


func _cave_up(i: int) -> float:
    return maxf(terrain.cave_up[i], 12.0) if terrain.cave_up.size() > i else 16.0


# ------------------------------------------------------------ 1. portões
func _gate(m: Dictionary) -> void:
    var a := int(m["a"])
    var p := track.pts[a]
    var hw := track.half_at(a)
    var up := track.ups[a]
    var bas := _tbasis(a)
    var ruin := int(m.get("ruin", 0)) == 1
    var holder := Node3D.new()
    holder.name = "Portao_%d" % a
    holder.transform = Transform3D(bas, p)
    root.add_child(holder)
    var height := 9.5
    var fb := MeshBuilder.new()
    for sgn: float in [-1.0, 1.0]:
        fb.box(Vector3(sgn * (hw + 2.0), 6.5, 0.0), Vector3(1.8, 6.5 if not ruin else 5.0, 1.8), Color(0.7, 0.65, 0.58))
        fb.box(Vector3(sgn * (hw + 2.0), 13.2, 0.0), Vector3(2.4, 0.7, 2.4), Color(0.8, 0.74, 0.64))
    fb.box(Vector3(0, 12.0, 0.0), Vector3(hw + 2.0, 1.1, 1.5), Color(0.62, 0.57, 0.5))
    var frame := _mesh(fb, rock_mat, holder)
    var fbody := StaticBody3D.new()
    fbody.collision_layer = 1
    holder.add_child(fbody)
    _col(fbody, fb.to_collision())
    # grade (porta)
    var db := MeshBuilder.new()
    var bars := int(hw)
    for k in range(-bars, bars + 1):
        db.box(Vector3(float(k) * (hw + 1.2) / float(maxi(bars, 1)), 0.0, 0.0), Vector3(0.22, height * 0.5, 0.22), Color(0.28, 0.27, 0.3))
    db.box(Vector3(0, -height * 0.5 + 0.3, 0), Vector3(hw + 1.4, 0.3, 0.3), Color(0.35, 0.33, 0.3))
    db.box(Vector3(0, 0.0, 0), Vector3(hw + 1.4, 0.3, 0.3), Color(0.35, 0.33, 0.3))
    var door := _abody(holder)
    _mesh(db, rock_mat, door)
    _col(door, _box_shape(Vector3((hw + 1.4) * 2.0, height, 0.7)))
    var lamp := _glow_ball(Vector3(0, 11.2, 1.8), Color(1, 0.1, 0.05), holder, 0.5)
    var entry := {"amt": 1.0, "blk": [a - 1, a + 1, false]}
    blockers.push_back(entry["blk"])
    var period: float = m["period"]
    var open_frac: float = m["open"]
    var phase: float = m["phase"]
    items.push_back({"tick": func(dt: float) -> void:
        var u := fmod(clock + phase, period)
        var t_open := open_frac * period
        var target := 1.0
        if u >= t_open - 0.5 and u < t_open:
            target = (t_open - u) / 0.5
        elif u >= t_open and u < period - 0.5:
            target = 0.0
        elif u >= period - 0.5:
            target = (u - (period - 0.5)) / 0.5
        # não esmaga: se alguém está sob a grade, ela não fecha
        if target < entry["amt"] and _racer_near(p, hw + 3.0, 8.0) != null:
            var rr := _racer_near(p, hw + 3.0, 8.0)
            var along: float = (rr.body.global_position - p).dot(track.tans[a])
            if absf(along) < 4.5:
                target = 1.0
        entry["amt"] = move_toward(entry["amt"], target, dt * 2.2)
        door.position = Vector3(0, height * 0.5 - 0.1 + entry["amt"] * (height + 0.4), 0.0)
        var closed: bool = entry["amt"] < 0.97 or (u >= t_open - 1.3 and u < period - 0.4)
        entry["blk"][2] = closed
        (lamp.material_override as StandardMaterial3D).albedo_color = Color(1, 0.12, 0.05) if closed else Color(0.2, 1.0, 0.3)
        (lamp.material_override as StandardMaterial3D).emission = (lamp.material_override as StandardMaterial3D).albedo_color
    })


# ------------------------------------------------------- 2. pedregulhos
func _boulder(m: Dictionary) -> void:
    var a := int(m["a"])
    var ln := int(m["len"])
    var period: float = m["period"]
    var phase: float = m["phase"]
    var rad := 2.4
    var holder := Node3D.new()
    holder.name = "Pedregulho_%d" % a
    root.add_child(holder)
    var body := _abody(holder)
    var mb := MeshBuilder.new()
    mb.sphere(Vector3.ZERO, Vector3(rad, rad * 0.96, rad), 7, 12, Color(0.5, 0.46, 0.42))
    _mesh(mb, WonderlandMaterials.rock(Color(0.3, 0.27, 0.25), Color(0.6, 0.55, 0.5), 0.3, 0.0, 0.3), body)
    var sh := SphereShape3D.new()
    sh.radius = rad
    _col(body, sh)
    body.position = Vector3(0, -5000, 0)
    var zone := Vector3(-1000, 0, 3.6)
    track.obstacle_zones.push_back(zone)
    var zi := track.obstacle_zones.size() - 1
    var speed := 21.0
    var run_t := float(ln) * TrackData.SPACING / speed
    var hit_cd := {}
    items.push_back({"tick": func(dt: float) -> void:
        var u := fmod(clock + phase, period)
        if u > run_t:
            body.position = Vector3(0, -5000, 0)
            track.obstacle_zones[zi] = Vector3(-1000, 0, 3.6)
            return
        var s := u / run_t
        var fi := float(a) + float(ln) * (1.0 - s)
        var i := clampi(int(fi), 0, track.count - 1)
        var hw := track.half_at(i)
        var lat := (hw * 0.42) * sin(u * 0.9 + phase)
        var pos := track.at(i, lat) + track.ups[i] * (rad - 0.1)
        body.global_position = pos
        body.rotation.x = -u * speed / rad
        track.obstacle_zones[zi] = Vector3(float(i), lat, 3.6)
        for r in racers:
            if r.body.global_position.distance_to(pos) < rad + 1.6:
                var key: String = r.display_name
                if not hit_cd.has(key) or clock - hit_cd[key] > 1.5:
                    hit_cd[key] = clock
                    _hurt(r, 1.4)
                    var push: Vector3 = (r.body.global_position - pos).normalized()
                    r.body.apply_central_impulse((push + Vector3.UP * 0.4) * 28.0 * r.body.mass)
    })


# ------------------------------------------------------- 3. queda de rochas
func _rockfall(m: Dictionary) -> void:
    var a := int(m["a"])
    var period: float = m["period"]
    var phase: float = m["phase"]
    var holder := Node3D.new()
    holder.name = "QuedaRochas_%d" % a
    root.add_child(holder)
    var mb := MeshBuilder.new()
    mb.sphere(Vector3.ZERO, Vector3(1.8, 1.5, 1.7), 5, 8, Color(0.5, 0.44, 0.4))
    var rock := _mesh(mb, WonderlandMaterials.rock(Color(0.3, 0.26, 0.24), Color(0.6, 0.5, 0.45), 0.3, 0.0, 0.3), holder)
    rock.visible = false
    var dm := MeshBuilder.new()
    dm.cylinder(Vector3.ZERO, 2.6, 2.6, 0.05, 16, Color(1, 0.15, 0.05))
    var disc := MeshInstance3D.new()
    disc.mesh = dm.to_mesh()
    disc.material_override = WonderlandMaterials.glow(Color(1.0, 0.2, 0.05), 1.6)
    disc.visible = false
    disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    holder.add_child(disc)
    var up_h := minf(_cave_up(a), 26.0)
    var hurt_cd := {}
    items.push_back({"tick": func(dt: float) -> void:
        var tt := clock + phase
        var n := int(floor(tt / period))
        var u := tt - float(n) * period
        var hw := track.half_at(a)
        var lat := (_hash(n, a) * 2.0 - 1.0) * (hw - 3.0)
        var ground := track.at(a, lat)
        var upv := track.ups[a]
        if u < 1.6:
            disc.visible = true
            disc.global_position = ground + upv * 0.08
            disc.scale = Vector3.ONE * (0.6 + u / 1.6 * 0.5)
            disc.visible = fmod(u, 0.3) < 0.2
            rock.visible = false
        elif u < 2.4:
            var f := (u - 1.6) / 0.8
            disc.visible = true
            disc.global_position = ground + upv * 0.08
            rock.visible = true
            rock.global_position = ground + upv * (1.4 + up_h * (1.0 - f * f))
            rock.rotation = Vector3(u * 4.0, u * 3.0, 0)
            if f > 0.55:
                for r in racers:
                    var d: Vector3 = r.body.global_position - rock.global_position
                    if d.length() < 3.4:
                        var key: String = r.display_name
                        if not hurt_cd.has(key) or clock - hurt_cd[key] > 1.2:
                            hurt_cd[key] = clock
                            _hurt(r, 1.2)
        elif u < 3.0:
            disc.visible = false
            rock.visible = true
            rock.global_position = ground + upv * (1.0 - (u - 2.4) * 1.4)
        else:
            disc.visible = false
            rock.visible = false
    })


# ------------------------------------------------------------ 4. gêiseres
func _geyser(m: Dictionary) -> void:
    var a := int(m["a"])
    var lat: float = m["lat"]
    var period: float = m["period"]
    var phase: float = m["phase"]
    var power: float = m["power"]
    var pos := track.at(a, lat)
    var holder := Node3D.new()
    holder.name = "Geiser_%d" % a
    holder.position = pos
    root.add_child(holder)
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3(0, 0.02, 0), 2.3, 2.1, 0.22, 14, Color(0.5, 0.45, 0.4))
    mb.cylinder(Vector3(0, 0.24, 0), 1.5, 1.5, 0.04, 14, Color(1.0, 0.45, 0.1))
    var base_mi := _mesh(mb, rock_mat, holder)
    var sm := CylinderMesh.new()
    sm.top_radius = 1.9
    sm.bottom_radius = 0.9
    sm.height = 14.0
    sm.radial_segments = 10
    sm.rings = 4
    var steam := MeshInstance3D.new()
    steam.mesh = sm
    var sm_mat := WonderlandMaterials.steam(Color(1.0, 0.85, 0.7))
    steam.material_override = sm_mat
    steam.position = Vector3(0, 7.0, 0)
    steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    holder.add_child(steam)
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.6, 0.25)
    light.omni_range = 16.0
    light.light_energy = 0.0
    light.position = Vector3(0, 1.0, 0)
    holder.add_child(light)
    var cd := {}
    items.push_back({"tick": func(dt: float) -> void:
        var u := fmod(clock + phase, period)
        var warn_start := period - 2.4
        var amt := 0.0
        if u >= warn_start and u < period - 1.0:
            amt = 0.25 + 0.15 * sin(u * 25.0)
        elif u >= period - 1.0 and u < period - 0.2:
            amt = 1.0
            for r in racers:
                var d: Vector3 = r.body.global_position - pos
                if Vector2(d.x, d.z).length() < 2.7 and d.y > -1.0 and d.y < 5.0:
                    var key: String = r.display_name
                    if not cd.has(key) or clock - cd[key] > 1.4:
                        cd[key] = clock
                        var v: Vector3 = r.body.linear_velocity
                        r.body.linear_velocity = Vector3(v.x, power, v.z)
        sm_mat.set_shader_parameter("amount", amt)
        steam.visible = amt > 0.01
        light.light_energy = amt * 2.2
    })


# --------------------------------------------------- 5. plataformas que caem
func _collapse(m: Dictionary) -> void:
    var a := int(m["a"])
    var b := int(m["b"])
    var seg := int(m["seg"])
    var total := b - a + 1
    var per := int(ceil(float(total) / float(seg)))
    for k in seg:
        var s0 := a + k * per
        var s1 := mini(a + (k + 1) * per - 1, b)
        if s0 > b:
            break
        var body := _abody(root)
        body.name = "PlataformaFrágil_%d_%d" % [a, k]
        road.build_piece(s0 - 1 if k == 0 else s0 - 1, s1 + 1, body, true)
        var st := {"state": 0, "t": 0.0, "off": 0.0}
        var mid := (s0 + s1) / 2
        items.push_back({"tick": func(dt: float) -> void:
            match int(st["state"]):
                0:
                    for r in racers:
                        if r.cur_idx >= s0 - 1 and r.cur_idx <= s1 + 1 and r.body.grounded and absf(r.body.global_position.y - track.pts[r.cur_idx].y) < 3.0 and r.branch < 0:
                            st["state"] = 1
                            st["t"] = 0.0
                            break
                    body.position = Vector3.ZERO
                1:
                    st["t"] += dt
                    body.position = Vector3(0.0, sin(st["t"] * 60.0) * 0.07, 0.0)
                    # só cai quando ninguém está em cima (quem passa rápido atravessa); quem para sobre ela cai após 2.6 s
                    var occupied := false
                    for r in racers:
                        if r.cur_idx >= s0 - 1 and r.cur_idx <= s1 + 1 and r.branch < 0 and absf(r.body.global_position.y - track.pts[r.cur_idx].y) < 4.0:
                            occupied = true
                            break
                    if (st["t"] > 0.9 and not occupied) or st["t"] > 2.6:
                        st["state"] = 2
                        st["t"] = 0.0
                2:
                    st["t"] += dt
                    st["off"] = -0.5 * 22.0 * st["t"] * st["t"]
                    body.position = Vector3(0.0, st["off"], 0.0)
                    if st["t"] > 2.4:
                        st["state"] = 3
                        st["t"] = 0.0
                3:
                    st["t"] += dt
                    body.position = Vector3(0.0, -140.0, 0.0)
                    if st["t"] > 3.0:
                        st["state"] = 4
                        st["t"] = 0.0
                4:
                    st["t"] += dt
                    body.position = Vector3(0.0, -30.0 * (1.0 - clampf(st["t"] / 2.0, 0.0, 1.0)), 0.0)
                    if st["t"] >= 2.0:
                        st["state"] = 0
        })


# ------------------------------------------------- 6. ponte deslizante
func _slider(m: Dictionary) -> void:
    var a := int(m["a"])
    var b := int(m["b"])
    var period: float = m["period"]
    var open_frac: float = m["open"]
    var body := _abody(root)
    body.name = "PonteDeslizante_%d" % a
    road.build_piece(a - 1, b + 1, body, true)
    var mid := (a + b) / 2
    var side := track.sides[mid]
    var hw := track.half_at(mid)
    var shift := hw * 2.0 + 14.0
    var blk := [a - 1, b + 1, false]
    blockers.push_back(blk)
    var st := {"amt": 1.0}
    var l1 := _glow_ball(track.at(a - 2, -hw - 1.0) + track.ups[a] * 3.0, Color(0.2, 1, 0.3), root, 0.45)
    var l2 := _glow_ball(track.at(b + 2, hw + 1.0) + track.ups[b] * 3.0, Color(0.2, 1, 0.3), root, 0.45)
    var lava_force := "lavabridge" if a > 2900 and a < 3100 else ""
    items.push_back({"tick": func(dt: float) -> void:
        var u := fmod(clock + float(a) * 0.37, period)
        var present := u < open_frac * period
        if lava_force != "" and triggers.get(lava_force, 0.0) > 0.0:
            present = true
        # alguém na ponte: ela não sai
        for r in racers:
            if r.cur_idx >= a - 1 and r.cur_idx <= b + 1 and r.body.global_position.y > track.pts[r.cur_idx].y - 2.0 and r.body.grounded:
                present = true
        var soon_gone := u > open_frac * period - 1.2 and u < open_frac * period
        st["amt"] = move_toward(st["amt"], 1.0 if present else 0.0, dt / 0.9)
        body.position = side * shift * (1.0 - st["amt"])
        blk[2] = st["amt"] < 0.97 or soon_gone
        var c := Color(0.2, 1, 0.3) if (st["amt"] > 0.97 and not soon_gone) else Color(1, 0.15, 0.05)
        for lb in [l1, l2]:
            (lb.material_override as StandardMaterial3D).albedo_color = c
            (lb.material_override as StandardMaterial3D).emission = c
    })


# ------------------------------------------- 13. obstáculos que emergem
func _emerge(m: Dictionary) -> void:
    var a := int(m["a"])
    var period: float = m["period"]
    var phase: float = m["phase"]
    var hw := track.half_at(a)
    var wid := hw * 0.55
    var body := _abody(root)
    body.name = "Emergente_%d" % a
    var mb := MeshBuilder.new()
    mb.box(Vector3(0, 1.6, 0), Vector3(wid, 1.7, 0.9), Color(0.4, 0.36, 0.34))
    for k in 5:
        mb.cone(Vector3(-wid + 0.8 + float(k) * (wid * 2.0 - 1.6) / 4.0, 3.3, 0), 0.7, 1.6, 6, Color(0.55, 0.3, 0.2))
    _mesh(mb, rock_mat, body)
    _col(body, _box_shape(Vector3(wid * 2.0, 3.4, 1.8)), Vector3(0, 1.7, 0))
    var warn := MeshBuilder.new()
    warn.box(Vector3.ZERO, Vector3(wid, 0.02, 1.2), Color(1, 0.5, 0.1))
    var wmi := MeshInstance3D.new()
    wmi.mesh = warn.to_mesh()
    wmi.material_override = WonderlandMaterials.glow(Color(1, 0.45, 0.1), 1.5)
    wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(wmi)
    track.obstacle_zones.push_back(Vector3(-1000, 0, wid + 0.5))
    var zi := track.obstacle_zones.size() - 1
    items.push_back({"tick": func(dt: float) -> void:
        var tt := clock + phase
        var n := int(floor(tt / period))
        var u := tt - float(n) * period
        var side := -1.0 if n % 2 == 0 else 1.0
        var lat := side * (hw - wid - 0.5) * 0.7
        var base := track.at(a, lat)
        var bas := _tbasis(a)
        var t_up := period * 0.30
        var t_dn := period * 0.80
        var h := -4.2
        if u >= t_up and u < t_up + 0.35:
            h = lerpf(-4.2, 0.0, (u - t_up) / 0.35)
        elif u >= t_up + 0.35 and u < t_dn:
            h = 0.0
        elif u >= t_dn and u < t_dn + 0.45:
            h = lerpf(0.0, -4.2, (u - t_dn) / 0.45)
        var shake := 0.0
        if u >= t_up - 1.0 and u < t_up:
            shake = sin(u * 70.0) * 0.1
        body.global_transform = Transform3D(bas, base + track.ups[a] * (h + shake))
        wmi.global_transform = Transform3D(bas, base + track.ups[a] * 0.07)
        wmi.visible = (u >= t_up - 1.0 and u < t_dn + 0.4) and fmod(u, 0.3) < 0.22
        track.obstacle_zones[zi] = Vector3(float(a), lat, wid + 0.5) if (u >= t_up - 1.0 and u < t_dn + 0.4) else Vector3(-1000, 0, wid + 0.5)
    })


# ------------------------------------------------- 8. rampas móveis
func _tiltramp(m: Dictionary, periodic: bool) -> void:
    var a := int(m["a"])
    var hw := track.half_at(a)
    var period: float = m.get("period", 6.0)
    var key := "tiltramp"
    var bas := _tbasis(a)
    var pivot := track.pts[a]
    var holder := _abody(root)
    holder.name = "RampaMovel_%d" % a
    var len := 13.0
    var mb := MeshBuilder.new()
    mb.box(Vector3(0, -0.18, -len * 0.5), Vector3(hw * 0.85, 0.25, len * 0.5), Color(0.9, 0.55, 0.15))
    for k in 6:
        mb.box(Vector3(0, 0.08, -1.0 - float(k) * 2.0), Vector3(hw * 0.85, 0.03, 0.4), Color(1.0, 0.95, 0.3))
    for sgn: float in [-1.0, 1.0]:
        mb.box(Vector3(sgn * hw * 0.85, 0.3, -len * 0.5), Vector3(0.2, 0.3, len * 0.5), Color(0.3, 0.3, 0.35))
    _mesh(mb, WonderlandMaterials.rock(Color(0.5, 0.3, 0.1), Color(0.95, 0.6, 0.2), 0.3, 0.0, 0.7), holder)
    _col(holder, _box_shape(Vector3(hw * 1.7, 0.5, len)), Vector3(0, -0.18, -len * 0.5))
    var st := {"ang": 0.0}
    items.push_back({"tick": func(dt: float) -> void:
        var want := 0.0
        if periodic:
            want = 0.38 if fmod(clock, period) < period * 0.5 else 0.0
        elif triggers.get(key, 0.0) > 0.0:
            want = 0.38
        st["ang"] = move_toward(st["ang"], want, dt * 0.5)
        var tb := bas.rotated(bas.x.normalized(), st["ang"]).orthonormalized()
        holder.global_transform = Transform3D(tb, pivot + track.ups[a] * 0.1)
    })


# ------------------------------------------------------- 7. elevadores
func _lift(m: Dictionary) -> void:
    var a := int(m["a"])
    var cnt := int(m["count"])
    var period: float = m["period"]
    var hw := track.half_at(a - 1)
    var i0 := a - 1
    var i1 := a + cnt
    var t0 := track.tans[i0]
    var bas := Basis.looking_at(Vector3(t0.x, 0, t0.z).normalized(), Vector3.UP)
    var flat_t := Vector3(t0.x, 0, t0.z).normalized()
    var p_bot := track.pts[i0] + flat_t * 6.5
    var t1 := track.tans[i1]
    var flat_t1 := Vector3(t1.x, 0, t1.z).normalized()
    var p_top := track.pts[i1] - flat_t1 * 6.5
    var plat := _abody(root)
    plat.name = "Elevador_%d" % a
    var width := hw + 0.5
    var mb := MeshBuilder.new()
    mb.box(Vector3(0, -0.4, 0), Vector3(width, 0.4, 6.8), Color(0.35, 0.36, 0.42))
    mb.box(Vector3(0, -0.1, 0), Vector3(width - 0.4, 0.05, 6.4), Color(0.2, 0.9, 1.0))
    for sgn: float in [-1.0, 1.0]:
        mb.box(Vector3(sgn * (width + 0.15), 0.6, 0), Vector3(0.25, 0.9, 6.8), Color(0.5, 0.5, 0.56))
    _mesh(mb, rock_mat, plat)
    _col(plat, _box_shape(Vector3(width * 2.0, 0.8, 13.6)), Vector3(0, -0.4, 0))
    _col(plat, _box_shape(Vector3(0.5, 1.8, 13.6)), Vector3(-(width + 0.15), 0.6, 0))
    _col(plat, _box_shape(Vector3(0.5, 1.8, 13.6)), Vector3(width + 0.15, 0.6, 0))
    # parede frontal (abaixa no topo)
    var fw := _abody(root)
    var fmb := MeshBuilder.new()
    fmb.box(Vector3(0, 0.9, 0), Vector3(width, 0.9, 0.3), Color(1.0, 0.7, 0.1))
    _mesh(fmb, rock_mat, fw)
    _col(fw, _box_shape(Vector3(width * 2.0, 1.8, 0.6)), Vector3(0, 0.9, 0))
    # barreira inferior (fecha a entrada quando a plataforma não está embaixo)
    var barrier := _abody(root)
    var bmb := MeshBuilder.new()
    bmb.box(Vector3(0, 1.4, 0), Vector3(hw + 1.0, 1.4, 0.35), Color(1.0, 0.2, 0.1))
    for k in range(-3, 4):
        bmb.box(Vector3(float(k) * 2.2, 1.4, 0.0), Vector3(0.5, 1.4, 0.42), Color(1.0, 0.9, 0.2) if k % 2 == 0 else Color(0.1, 0.1, 0.1))
    _mesh(bmb, rock_mat, barrier)
    _col(barrier, _box_shape(Vector3((hw + 1.0) * 2.0, 2.8, 0.7)), Vector3(0, 1.4, 0))
    var bar_pos := track.pts[i0] + flat_t * 0.2
    var blk := [i0 - 1, i0 + 1, false]
    blockers.push_back(blk)
    var st := {"y": 0.0, "prev": p_bot, "bar": 1.0}
    var dist := p_bot.distance_to(p_top)
    var t_load := period * 0.28
    var t_up := period * 0.34
    var t_hold := period * 0.14
    plat.global_transform = Transform3D(bas, p_bot + Vector3(0, -0.05, 0))
    items.push_back({"tick": func(dt: float) -> void:
        var u := fmod(clock + float(a) * 0.1, period)
        var f := 0.0
        var at_bottom := true
        if u < t_load:
            f = 0.0
        elif u < t_load + t_up:
            f = smoothstep(0.0, 1.0, (u - t_load) / t_up)
            at_bottom = false
        elif u < t_load + t_up + t_hold:
            f = 1.0
            at_bottom = false
        else:
            f = 1.0 - smoothstep(0.0, 1.0, (u - t_load - t_up - t_hold) / (period - t_load - t_up - t_hold))
            at_bottom = f < 0.04
        var pos := p_bot.lerp(p_top, f) + Vector3(0, -0.05, 0)
        var delta_p: Vector3 = pos - st["prev"]
        # leva quem está em cima (o corpo rígido não herda bem o movimento da plataforma)
        for r in racers:
            var rel: Vector3 = r.body.global_position - st["prev"]
            var lx: float = rel.dot(bas.x)
            var lz: float = rel.dot(bas.z)
            if absf(lx) < width + 0.3 and absf(lz) < 7.0 and rel.y > -0.5 and rel.y < 3.2 and delta_p.length() > 0.0001:
                r.body.global_position += delta_p
                if absf(delta_p.y) > 0.0:
                    var v: Vector3 = r.body.linear_velocity
                    r.body.linear_velocity = Vector3(v.x, maxf(v.y, delta_p.y / maxf(dt, 0.001)), v.z)
        st["prev"] = pos
        plat.global_transform = Transform3D(bas, pos)
        var top_open := f > 0.97
        fw.global_transform = Transform3D(bas, pos + flat_t * 6.5 + Vector3(0, -1.9 if top_open else -0.3, 0))
        # barreira: abaixada (aberta) só com a plataforma embaixo e parada; sobe 1.2 s antes de partir
        var open_gate := at_bottom and u < t_load - 0.8
        st["bar"] = move_toward(st["bar"], 0.0 if open_gate else 1.0, dt * 2.0)
        barrier.global_transform = Transform3D(bas, bar_pos + Vector3(0, -2.9 + 2.9 * st["bar"], 0))
        blk[2] = st["bar"] > 0.4
    })


# --------------------------------------------------------- 11. turbo
func _boost(m: Dictionary) -> void:
    var a := int(m["a"])
    var b := int(m["b"])
    boost_ranges.push_back([a, b])
    var mat := WonderlandMaterials.boost_strip(Color(0.2, 0.9, 1.0))
    var sv := PackedVector3Array()
    var su := PackedVector2Array()
    var sn := PackedVector3Array()
    var si := PackedInt32Array()
    var k := 0
    for i in range(a, b + 1):
        var hw := minf(track.half_at(i) * 0.6, 4.2)
        for sgn: float in [-1.0, 1.0]:
            sv.push_back(track.at(i, sgn * hw) + track.ups[i] * 0.07)
            su.push_back(Vector2(sgn * hw * 1.9, float(k) * 2.5))
            sn.push_back(track.ups[i])
        if k > 0:
            var p := (k - 1) * 2
            si.append_array([p, p + 2, p + 3, p, p + 3, p + 1])
        k += 1
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = sv
    arr[Mesh.ARRAY_NORMAL] = sn
    arr[Mesh.ARRAY_TEX_UV] = su
    arr[Mesh.ARRAY_INDEX] = si
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var mi := MeshInstance3D.new()
    mi.mesh = am
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.name = "Turbo_%d" % a
    root.add_child(mi)


# -------------------------------------------------- 12. piso escorregadio
func _slick(m: Dictionary) -> void:
    var a := int(m["a"])
    var b := int(m["b"])
    slick_ranges.push_back([a, b])
    var sv := PackedVector3Array()
    var su := PackedVector2Array()
    var sn := PackedVector3Array()
    var si := PackedInt32Array()
    var cols := [-1.0, 0.0, 1.0]
    var k := 0
    for i in range(a, b + 1):
        var hw := track.half_at(i)
        for c in cols:
            var lat: float = c * hw
            sv.push_back(track.at(i, lat) + track.ups[i] * 0.045)
            su.push_back(Vector2(lat, float(i) * 2.5))
            sn.push_back(track.ups[i])
        if k > 0:
            var base := (k - 1) * 3
            for q in 2:
                si.append_array([base + q, base + 3 + q, base + 4 + q, base + q, base + 4 + q, base + q + 1])
        k += 1
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = sv
    arr[Mesh.ARRAY_NORMAL] = sn
    arr[Mesh.ARRAY_TEX_UV] = su
    arr[Mesh.ARRAY_INDEX] = si
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var mi := MeshInstance3D.new()
    mi.mesh = am
    mi.material_override = WonderlandMaterials.road(Color(0.5, 0.75, 0.9), Color(0.5, 0.9, 1.0), 8.0, 0.0, 0.85)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.name = "Gelo_%d" % a
    root.add_child(mi)


# ---------------------------------------------------- 14. baixa gravidade
func _lowgrav(m: Dictionary) -> void:
    var a := int(m["a"])
    var b := int(m["b"])
    lowgrav_ranges.push_back([a, b, float(m["scale"])])
    var ps := CPUParticles3D.new()
    ps.position = track.pts[(a + b) / 2] + Vector3(0, 6, 0)
    ps.amount = 120
    ps.lifetime = 5.0
    ps.preprocess = 5.0
    ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    ps.emission_box_extents = Vector3(12, 8, float(b - a) * 1.25)
    ps.gravity = Vector3(0, 0.4, 0)
    ps.initial_velocity_min = 0.1
    ps.initial_velocity_max = 0.8
    var sm := SphereMesh.new()
    sm.radius = 0.12
    sm.height = 0.24
    sm.radial_segments = 4
    sm.rings = 2
    ps.mesh = sm
    ps.material_override = WonderlandMaterials.glow(Color(0.6, 0.9, 1.0), 3.0)
    ps.visibility_range_end = 200.0
    ps.transform.basis = _tbasis((a + b) / 2)
    root.add_child(ps)
    # anéis de luz marcam a zona
    var ring_mb := MeshBuilder.new()
    for q in 24:
        var ang := TAU * float(q) / 24.0
        ring_mb.box(Vector3(cos(ang) * 11.0, sin(ang) * 11.0, 0), Vector3(0.5, 0.5, 0.25), Color(0.5, 0.9, 1.0), Basis(Vector3(0, 0, 1), ang))
    for i in [a, (a + b) / 2, b]:
        var mi := MeshInstance3D.new()
        mi.mesh = ring_mb.to_mesh()
        mi.material_override = WonderlandMaterials.glow(Color(0.5, 0.9, 1.0), 2.5)
        mi.transform = Transform3D(_tbasis(i), track.pts[i] + track.ups[i] * 2.0)
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(mi)


# ----------------------------------------------- 9. cristais-gatilho
func _crystal(m: Dictionary) -> void:
    var target: String = m["target"]
    var a := int(m["a"])
    # o cristal do atalho secreto fica ANTES da bifurcação, para dar tempo de abrir a porta
    if target == "secretgate":
        a = 2342 - 50
    var hw := track.half_at(a)
    var side := 1.0 if (a / 7) % 2 == 0 else -1.0
    var pos := track.at(a, side * (hw - 2.8))
    var holder := Node3D.new()
    holder.name = "CristalGatilho_%s_%d" % [target, a]
    holder.position = pos
    root.add_child(holder)
    var mb := MeshBuilder.new()
    mb.cylinder(Vector3.ZERO, 0.8, 0.5, 3.4, 6, Color(1, 1, 1), false)
    mb.cone(Vector3(0, 3.4, 0), 0.5, 1.9, 6, Color(1, 1, 1))
    mb.cylinder(Vector3(1.0, 0, 0.4), 0.5, 0.3, 2.0, 6, Color(1, 1, 1), false)
    mb.cone(Vector3(1.0, 2.0, 0.4), 0.3, 1.2, 6, Color(1, 1, 1))
    var col := {"tiltramp": Color(1.0, 0.7, 0.1), "boostgate": Color(0.2, 0.9, 1.0), "secretgate": Color(1.0, 0.3, 0.9), "lavabridge": Color(1.0, 0.4, 0.1)}.get(target, Color(0.5, 1, 0.5)) as Color
    var mi := MeshInstance3D.new()
    var mesh := mb.to_mesh()
    mi.mesh = mesh
    var mat := WonderlandMaterials.crystal(2.6)
    mi.material_override = mat
    holder.add_child(mi)
    # cor via material duplicado com vertex color tingido
    var tinted := MeshBuilder.new()
    tinted.cylinder(Vector3.ZERO, 0.8, 0.5, 3.4, 6, col, false)
    tinted.cone(Vector3(0, 3.4, 0), 0.5, 1.9, 6, col)
    tinted.cylinder(Vector3(1.0, 0, 0.4), 0.5, 0.3, 2.0, 6, col, false)
    tinted.cone(Vector3(1.0, 2.0, 0.4), 0.3, 1.2, 6, col)
    mi.mesh = tinted.to_mesh()
    var light := OmniLight3D.new()
    light.light_color = col
    light.light_energy = 2.0
    light.omni_range = 18.0
    light.position = Vector3(0, 2.5, 0)
    light.distance_fade_enabled = true
    light.distance_fade_begin = 90.0
    light.distance_fade_length = 30.0
    holder.add_child(light)
    var area := Area3D.new()
    area.collision_layer = 0
    area.collision_mask = 2
    var cs := CollisionShape3D.new()
    var sh := SphereShape3D.new()
    sh.radius = 3.6
    cs.shape = sh
    cs.position = Vector3(0, 1.8, 0)
    area.add_child(cs)
    holder.add_child(area)
    var dur := 8.0
    if target == "secretgate":
        dur = 22.0
    elif target == "lavabridge":
        dur = 12.0
    elif target == "boostgate":
        dur = 10.0
    area.body_entered.connect(func(body: Node3D) -> void:
        if body.has_method("boost"):
            triggers[target] = dur
            light.light_energy = 6.0)
    items.push_back({"tick": func(dt: float) -> void:
        if triggers.get(target, 0.0) > 0.0:
            mi.scale = Vector3.ONE * (1.0 + 0.08 * sin(clock * 12.0))
        else:
            mi.scale = Vector3.ONE
            light.light_energy = move_toward(light.light_energy, 2.0, dt * 6.0)
    })
    if target == "boostgate":
        _boost_gate(a + 25)


func _boost_gate(a: int) -> void:
    # anel de turbo que só funciona enquanto o cristal está ativo
    var hw := track.half_at(a)
    var bas := _tbasis(a)
    var mb := MeshBuilder.new()
    for q in 28:
        var ang := TAU * float(q) / 28.0
        mb.box(Vector3(cos(ang) * 6.4, 5.5 + sin(ang) * 5.5, 0), Vector3(0.6, 0.6, 0.3), Color(0.2, 0.9, 1.0), Basis(Vector3(0, 0, 1), ang))
    var mi := MeshInstance3D.new()
    mi.mesh = mb.to_mesh()
    var gm := WonderlandMaterials.glow(Color(0.2, 0.9, 1.0), 3.0)
    mi.material_override = gm
    mi.transform = Transform3D(bas, track.pts[a])
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(mi)
    var cd := {}
    items.push_back({"tick": func(dt: float) -> void:
        var on: bool = triggers.get("boostgate", 0.0) > 0.0
        mi.visible = on or fmod(clock, 1.2) < 0.4
        gm.albedo_color = Color(0.2, 0.9, 1.0) if on else Color(0.3, 0.3, 0.35)
        gm.emission = gm.albedo_color
        if on:
            for r in racers:
                if absf(float(r.cur_idx - a)) < 2 and not cd.has(r.display_name):
                    cd[r.display_name] = clock
                    r.body.boost(1.6)
                elif cd.has(r.display_name) and clock - cd[r.display_name] > 4.0:
                    cd.erase(r.display_name)
    })


# ----------------------------------------------- 10. atalho secreto
func _secret_door() -> void:
    for br in track.branches:
        if str(br.get("a", 0)) != "2342":
            continue
        var bp: PackedVector3Array = br["pts"]
        var bt: PackedVector3Array = br["tans"]
        var k := road.branch_clear_range(br).x + 8
        var half: float = br["half"]
        var bas := Basis.looking_at(bt[k], Vector3.UP)
        var door := _abody(root)
        door.name = "PortaSecreta"
        var mb := MeshBuilder.new()
        mb.box(Vector3(0, 5.5, 0), Vector3(half + 3.0, 5.5, 0.9), Color(0.45, 0.4, 0.5))
        mb.box(Vector3(0, 5.5, 0.95), Vector3(1.2, 2.2, 0.2), Color(1, 0.3, 0.9))
        _mesh(mb, rock_mat, door)
        _col(door, _box_shape(Vector3((half + 3.0) * 2.0, 11.0, 1.8)), Vector3(0, 5.5, 0))
        var amt := {"v": 0.0}
        var blk := [int(br["a"]) + 14, int(br["a"]) + 15, true]
        items.push_back({"tick": func(dt: float) -> void:
            var want := 1.0 if triggers.get("secretgate", 0.0) > 0.0 else 0.0
            amt["v"] = move_toward(amt["v"], want, dt * 0.8)
            door.global_transform = Transform3D(bas, bp[k] + Vector3(0, amt["v"] * 11.5, 0))
        })
        break


# ------------------------------------------------------------- relógio
func tick(delta: float) -> void:
    clock += delta
    if main_ref != null:
        racers = main_ref.racers
    for key in triggers.keys():
        triggers[key] = maxf(0.0, triggers[key] - delta)
    for it in items:
        it["tick"].call(delta)
    _zones(delta)


func _zones(_delta: float) -> void:
    for r in racers:
        var kb: KartBody = r.body
        var idx: int = r.cur_idx
        var slick := false
        if r.branch < 0:
            for s in slick_ranges:
                if idx >= s[0] and idx <= s[1] and kb.grounded:
                    slick = true
        var key: String = r.display_name
        if slick:
            kb.grip_mod = 0.3
            _prev_grip[key] = true
        elif _prev_grip.get(key, false):
            kb.grip_mod = 1.0
            _prev_grip[key] = false
        var gscale := 1.0
        for s in lowgrav_ranges:
            if idx >= s[0] and idx <= s[1] and r.branch < 0:
                gscale = s[2]
        if gscale != 1.0 or kb.grav_mod != 1.0:
            kb.grav_mod = gscale
        if r.branch < 0:
            for s in boost_ranges:
                if idx >= s[0] and idx <= s[1]:
                    kb.external_boost = 0.25
