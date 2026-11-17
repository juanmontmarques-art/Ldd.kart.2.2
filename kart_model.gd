class_name KartModel
extends RefCounted

# Karts e piloto 100% procedurais (malhas suaves feitas por KartMesh, nada de cilindro
# pronto). Seis modelos, um por kart do catálogo: classico, foguete, besouro, relampago,
# fantasma, ouro. Orientação (igual à corrida): frente em -Z, motor em +Z, chão em y = 0.
# O Node3D devolvido tem: "Chassis" (corpo), "Roda_FL/FR/RL/RR" (giram) e "Piloto".

const IDS: Array[String] = ["classico", "foguete", "besouro", "relampago", "fantasma", "ouro"]
const GROUND := 0.05   # o modelo antigo ficava 5 cm acima do chão; mantemos para a corrida

static var _cache := {}


# kart_color: pintura. driver_color: capacete/macacão. driver_style: "fin","pony","ears","antenna","".
static func build(kart_color: Color, driver_color: Color, driver_style: String = "", kart_id: String = "classico") -> Node3D:
    var id := kart_id if IDS.has(kart_id) else "classico"
    var root := Node3D.new()
    root.name = "KartVisual"
    var chassis := Node3D.new()
    chassis.name = "Chassis"
    chassis.position = Vector3(0.0, GROUND, 0.0)
    root.add_child(chassis)
    var spec := _spec(id)
    var mats := _materials(kart_color, spec)

    if not _cache.has("body_" + id):
        var kb := KartMesh.new()
        _body(kb, spec, id)
        _cache["body_" + id] = kb.commit()
    var res: Dictionary = _cache["body_" + id]
    var body := MeshInstance3D.new()
    body.name = "Corpo"
    body.mesh = res["mesh"]
    var keys: Array = res["keys"]
    for i in keys.size():
        body.set_surface_override_material(i, mats[keys[i]])
    chassis.add_child(body)

    # rodas
    var w: Dictionary = spec["wheels"]
    var wheel_defs: Array = [
        ["Roda_FL", -1.0, float(w["fx"]), float(w["fz"]), float(w["fR"]), float(w["fW"])],
        ["Roda_FR", 1.0, float(w["fx"]), float(w["fz"]), float(w["fR"]), float(w["fW"])],
        ["Roda_RL", -1.0, float(w["rx"]), float(w["rz"]), float(w["rR"]), float(w["rW"])],
        ["Roda_RR", 1.0, float(w["rx"]), float(w["rz"]), float(w["rR"]), float(w["rW"])],
    ]
    for d in wheel_defs:
        var side: float = d[1]
        var pivot := Node3D.new()
        pivot.name = d[0]
        pivot.position = Vector3(side * float(d[2]), float(d[4]), float(d[3]))
        chassis.add_child(pivot)
        var mi := MeshInstance3D.new()
        mi.mesh = _wheel_mesh(float(d[4]), float(d[5]), side, int(w["spokes"]))
        pivot.add_child(mi)

    chassis.add_child(_make_driver(driver_color, driver_style))
    return root


# ------------------------------------------------------------------ materiais
static func _mat(c: Color, rough: float, metal: float = 0.0, spec_amt: float = 0.35) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    m.metallic = metal
    m.metallic_specular = spec_amt
    return m


static func _emit(c: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    m.roughness = 0.3
    return m


static func _materials(kart_color: Color, spec: Dictionary) -> Dictionary:
    var m := {}
    var gold := bool(spec.get("metal_paint", false))
    m["paint"] = _mat(kart_color, 0.30 if gold else 0.40, 0.55 if gold else 0.0, 0.6 if gold else 0.35)
    m["paint2"] = _mat(spec["paint2"] as Color, 0.45, 0.0, 0.2)
    m["dark"] = _mat(Color(0.09, 0.10, 0.13), 0.55)
    m["seat"] = _mat(Color(0.14, 0.15, 0.20), 0.8)
    m["chrome"] = _mat(Color(0.88, 0.90, 0.96), 0.22, 0.7, 0.5)
    m["tire"] = _mat(Color(0.06, 0.06, 0.07), 0.9, 0.0, 0.1)
    m["rim"] = _mat(Color(0.86, 0.88, 0.94), 0.32, 0.45, 0.5)
    m["rimdark"] = _mat(Color(0.16, 0.17, 0.22), 0.5)
    m["light_f"] = _emit(Color(1.0, 0.95, 0.75), 2.2)
    m["light_r"] = _emit(Color(1.0, 0.12, 0.10), 1.8)
    m["glow"] = _emit(spec.get("glow", Color(0.2, 0.9, 1.0)) as Color, 2.5)
    var glass := _mat(Color(0.45, 0.75, 1.0, 0.38), 0.1, 0.0, 0.8)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m["glass"] = glass
    # piloto
    m["suit"] = _mat(Color(0.2, 0.2, 0.25), 0.7)
    m["helmet"] = _mat(Color(0.5, 0.5, 0.5), 0.3, 0.0, 0.5)
    m["visor"] = _mat(Color(0.04, 0.07, 0.14), 0.12, 0.3, 0.8)
    m["white"] = _mat(Color(0.96, 0.97, 1.0), 0.5)
    m["glove"] = _mat(Color(0.12, 0.12, 0.15), 0.7)
    m["yellow"] = _mat(Color(1.0, 0.85, 0.2), 0.3)
    return m


# ------------------------------------------------------------------ modelos
# Seções: [z, meia-largura, y_baixo, y_alto, expoente_topo, expoente_base]
# expoente 2 = elipse, 3 = cantos bem arredondados, 4+ = mais "caixa".
static func _spec(id: String) -> Dictionary:
    match id:
        "foguete":
            return {
                "paint2": Color(0.95, 0.96, 1.0),
                "front": [[-1.28, 0.26, 0.26, 0.46, 2.6, 3.5], [-0.98, 0.36, 0.22, 0.58, 2.8, 3.5], [-0.66, 0.44, 0.20, 0.74, 3, 4], [-0.40, 0.46, 0.22, 0.82, 3, 4]],
                "front_caps": [0.70, 0.10],
                "rear": [[0.64, 0.42, 0.26, 0.72, 3, 4], [0.95, 0.36, 0.28, 0.70, 3, 4], [1.20, 0.26, 0.32, 0.62, 3, 4]],
                "rear_caps": [0.10, 0.30],
                "pods": [[-0.46, 0.11, 0.26, 0.46, 2.4, 3], [-0.05, 0.15, 0.24, 0.52, 2.4, 3], [0.30, 0.12, 0.26, 0.48, 2.4, 3]],
                "pod_x": 0.58, "pod_caps": [0.30, 0.16], "pod_paint": "paint2",
                "floor": [[-0.90, 0.44, 0.14, 0.26, 4, 6], [0.95, 0.44, 0.14, 0.26, 4, 6]],
                "stripe": 0.10, "wing": "fins", "exhaust": "big", "lights": "slim", "fenders": false,
                "wheels": {"fR": 0.34, "fW": 0.24, "fx": 0.62, "fz": -0.86, "rR": 0.42, "rW": 0.38, "rx": 0.70, "rz": 0.80, "spokes": 6},
            }
        "besouro":
            return {
                "paint2": Color(1.0, 0.92, 0.55),
                "front": [[-0.98, 0.40, 0.26, 0.58, 2.4, 3], [-0.76, 0.50, 0.22, 0.76, 2.4, 3], [-0.52, 0.54, 0.22, 0.88, 2.4, 3.2], [-0.38, 0.50, 0.24, 0.88, 2.4, 3.2]],
                "front_caps": [0.22, 0.12],
                "rear": [[0.60, 0.50, 0.24, 0.82, 2.3, 3], [0.88, 0.56, 0.24, 0.98, 2.2, 3], [1.10, 0.50, 0.26, 0.92, 2.3, 3]],
                "rear_caps": [0.12, 0.20],
                "pods": [[-0.30, 0.14, 0.28, 0.50, 2.4, 3], [0.05, 0.17, 0.26, 0.56, 2.4, 3], [0.28, 0.14, 0.28, 0.52, 2.4, 3]],
                "pod_x": 0.56, "pod_caps": [0.20, 0.16], "pod_paint": "paint",
                "floor": [[-0.90, 0.48, 0.14, 0.26, 4, 6], [0.95, 0.48, 0.14, 0.26, 4, 6]],
                "stripe": 0.0, "wing": "none", "exhaust": "small", "lights": "round", "fenders": false,
                "wheels": {"fR": 0.36, "fW": 0.28, "fx": 0.68, "fz": -0.80, "rR": 0.42, "rW": 0.40, "rx": 0.74, "rz": 0.78, "spokes": 5},
            }
        "relampago":
            return {
                "paint2": Color(0.10, 0.11, 0.14),
                "front": [[-1.10, 0.40, 0.18, 0.34, 3.5, 5], [-0.80, 0.50, 0.18, 0.50, 3.2, 5], [-0.55, 0.52, 0.18, 0.66, 3, 5], [-0.40, 0.50, 0.20, 0.74, 3, 5]],
                "front_caps": [0.22, 0.10],
                "rear": [[0.62, 0.42, 0.24, 0.66, 3, 5], [0.95, 0.40, 0.24, 0.64, 3, 5], [1.12, 0.36, 0.26, 0.60, 3, 5]],
                "rear_caps": [0.10, 0.16],
                "pods": [[-0.50, 0.12, 0.20, 0.40, 2.6, 4], [-0.05, 0.16, 0.18, 0.46, 2.6, 4], [0.30, 0.14, 0.20, 0.42, 2.6, 4]],
                "pod_x": 0.60, "pod_caps": [0.30, 0.16], "pod_paint": "paint2",
                "floor": [[-1.05, 0.52, 0.10, 0.20, 5, 8], [0.95, 0.52, 0.10, 0.20, 5, 8]],
                "stripe": 0.12, "wing": "high", "exhaust": "twin", "lights": "slim", "fenders": false, "splitter": true,
                "wheels": {"fR": 0.34, "fW": 0.30, "fx": 0.70, "fz": -0.86, "rR": 0.42, "rW": 0.46, "rx": 0.76, "rz": 0.82, "spokes": 7},
            }
        "fantasma":
            return {
                "paint2": Color(0.13, 0.12, 0.18),
                "glow": Color(0.35, 0.95, 1.0),
                "front": [[-1.12, 0.32, 0.20, 0.40, 3, 4], [-0.82, 0.44, 0.18, 0.58, 2.8, 4], [-0.56, 0.50, 0.18, 0.74, 2.8, 4], [-0.40, 0.48, 0.20, 0.80, 2.8, 4]],
                "front_caps": [0.32, 0.10],
                "rear": [[0.62, 0.42, 0.24, 0.72, 2.8, 4], [0.92, 0.40, 0.24, 0.74, 2.8, 4], [1.14, 0.30, 0.26, 0.66, 2.8, 4]],
                "rear_caps": [0.10, 0.22],
                "pods": [[-0.52, 0.10, 0.22, 0.40, 2.4, 3], [-0.10, 0.15, 0.20, 0.48, 2.4, 3], [0.30, 0.12, 0.22, 0.44, 2.4, 3]],
                "pod_x": 0.58, "pod_caps": [0.34, 0.18], "pod_paint": "paint2",
                "floor": [[-0.95, 0.46, 0.14, 0.24, 4, 6], [0.95, 0.46, 0.14, 0.24, 4, 6]],
                "stripe": 0.08, "wing": "swept", "exhaust": "twin", "lights": "slim", "fenders": false, "glass": true, "underglow": true,
                "wheels": {"fR": 0.35, "fW": 0.26, "fx": 0.66, "fz": -0.84, "rR": 0.42, "rW": 0.38, "rx": 0.72, "rz": 0.80, "spokes": 0},
            }
        "ouro":
            return {
                "paint2": Color(0.96, 0.93, 0.80),
                "metal_paint": true,
                "front": [[-1.00, 0.40, 0.22, 0.56, 2.8, 3.5], [-0.76, 0.52, 0.20, 0.72, 2.8, 3.5], [-0.52, 0.56, 0.20, 0.86, 2.8, 3.5], [-0.38, 0.52, 0.22, 0.88, 2.8, 3.5]],
                "front_caps": [0.20, 0.12],
                "rear": [[0.60, 0.50, 0.24, 0.80, 2.8, 3.5], [0.90, 0.50, 0.24, 0.86, 2.8, 3.5], [1.10, 0.44, 0.26, 0.80, 2.8, 3.5]],
                "rear_caps": [0.12, 0.16],
                "pods": [[-0.34, 0.15, 0.26, 0.52, 2.5, 3], [0.02, 0.19, 0.24, 0.60, 2.5, 3], [0.28, 0.15, 0.26, 0.54, 2.5, 3]],
                "pod_x": 0.58, "pod_caps": [0.20, 0.16], "pod_paint": "paint",
                "floor": [[-0.92, 0.48, 0.14, 0.26, 4, 6], [0.95, 0.48, 0.14, 0.26, 4, 6]],
                "stripe": 0.10, "wing": "crown", "exhaust": "stacks", "lights": "round", "fenders": false, "bumper": true,
                "wheels": {"fR": 0.37, "fW": 0.30, "fx": 0.70, "fz": -0.80, "rR": 0.44, "rW": 0.44, "rx": 0.76, "rz": 0.80, "spokes": 8},
            }
        _:
            return {
                "paint2": Color(0.97, 0.97, 1.0),
                "front": [[-1.02, 0.34, 0.24, 0.50, 3, 4], [-0.78, 0.46, 0.20, 0.66, 3, 4], [-0.55, 0.52, 0.20, 0.78, 3, 4], [-0.40, 0.50, 0.22, 0.84, 3, 4]],
                "front_caps": [0.30, 0.10],
                "rear": [[0.62, 0.44, 0.26, 0.74, 3, 4], [0.92, 0.43, 0.26, 0.78, 3, 4], [1.10, 0.38, 0.28, 0.72, 3, 4]],
                "rear_caps": [0.10, 0.16],
                "pods": [[-0.40, 0.14, 0.26, 0.50, 2.6, 3], [-0.05, 0.19, 0.24, 0.56, 2.6, 3], [0.28, 0.15, 0.26, 0.52, 2.6, 3]],
                "pod_x": 0.58, "pod_caps": [0.22, 0.18], "pod_paint": "paint2",
                "floor": [[-0.95, 0.46, 0.14, 0.26, 4, 6], [0.95, 0.46, 0.14, 0.26, 4, 6]],
                "stripe": 0.10, "wing": "duck", "exhaust": "twin", "lights": "slim", "fenders": false,
                "wheels": {"fR": 0.36, "fW": 0.26, "fx": 0.66, "fz": -0.80, "rR": 0.42, "rW": 0.38, "rx": 0.72, "rz": 0.80, "spokes": 5},
            }


# ------------------------------------------------------------------ carroceria
static func _body(kb: KartMesh, sp: Dictionary, id: String) -> void:
    var fc: Array = sp["front_caps"]
    var rc: Array = sp["rear_caps"]
    kb.loft("paint", sp["front"], float(fc[0]), float(fc[1]))
    kb.loft("paint", sp["rear"], float(rc[0]), float(rc[1]))
    kb.loft("dark", sp["floor"], 0.15, 0.15)
    var pc: Array = sp["pod_caps"]
    var pod_key := String(sp["pod_paint"])
    for s in [-1.0, 1.0]:
        kb.loft(pod_key, sp["pods"], float(pc[0]), float(pc[1]), Transform3D(Basis(), Vector3(float(sp["pod_x"]) * s, 0.0, 0.0)))

    # faixa central no capô e na traseira (acompanha a superfície)
    var st := float(sp["stripe"])
    if st > 0.0:
        for part in ["front", "rear"]:
            var secs: Array = []
            for s in (sp[part] as Array):
                secs.append([s[0], st, float(s[3]) + 0.014, float(s[3]) + 0.034, 4.0, 4.0])
            kb.loft("paint2", secs, 0.0, 0.0, Transform3D.IDENTITY, 24)

    _cockpit(kb)
    _wings(kb, sp, id)
    _exhausts(kb, sp)
    _lights(kb, sp)
    if bool(sp["fenders"]):
        var w: Dictionary = sp["wheels"]
        for s in [-1.0, 1.0]:
            for pr in [["f", "fx", "fz", "fR", "fW"], ["r", "rx", "rz", "rR", "rW"]]:
                var wx := float(w[pr[1]])
                var wz := float(w[pr[2]])
                var wr := float(w[pr[3]])
                var ww := float(w[pr[4]])
                kb.ellipsoid("paint", Vector3(s * wx, wr * 2.0 + 0.02, wz), Vector3(ww * 0.5 + 0.06, 0.10, wr * 1.05))
    if bool(sp.get("splitter", false)):
        kb.loft("dark", [[-1.28, 0.55, 0.08, 0.14, 5, 6], [-0.85, 0.62, 0.08, 0.15, 5, 6]], 0.12, 0.05)
    if bool(sp.get("bumper", false)):
        var path: Array = []
        for k in 15:
            var t := float(k) / 14.0
            var a := lerpf(-1.15, 1.15, t)
            path.append(Vector3(0.62 * sin(a), 0.38, -1.12 + 0.20 * (1.0 - cos(a))))
        var rad: Array = []
        for k in 15:
            rad.append(0.045)
        kb.tube("chrome", path, rad, 12)
        kb.ellipsoid("chrome", Vector3(0.0, 0.92, -0.58), Vector3(0.06, 0.06, 0.07))
    if bool(sp.get("glass", false)):
        kb.loft("glass", [[-0.40, 0.40, 0.80, 0.84, 3, 3], [-0.28, 0.38, 0.86, 1.02, 3, 3], [-0.16, 0.34, 1.02, 1.08, 3, 3]], 0.02, 0.02, Transform3D.IDENTITY, 24)
    if bool(sp.get("underglow", false)):
        kb.loft("glow", [[-0.80, 0.40, 0.09, 0.12, 4, 4], [0.85, 0.40, 0.09, 0.12, 4, 4]], 0.12, 0.12)


static func _cockpit(kb: KartMesh) -> void:
    # assento
    kb.loft("seat", [[-0.02, 0.27, 0.36, 0.54, 3, 4], [0.30, 0.28, 0.34, 0.54, 3, 4], [0.50, 0.27, 0.36, 0.56, 3, 4]], 0.08, 0.04)
    kb.loft("seat", [[0.46, 0.27, 0.50, 1.12, 3, 3], [0.60, 0.26, 0.50, 1.16, 3, 3]], 0.06, 0.07)
    # coluna e volante
    var d := Vector3(0.0, 0.20, 0.17).normalized()
    var c := Vector3(0.0, 0.98, -0.36)
    kb.tube("dark", [Vector3(0.0, 0.76, -0.56), c - d * 0.02], [0.030, 0.028], 10)
    var circle: Array = []
    var rr: Array = []
    for k in 28:
        var a := TAU * float(k) / 28.0
        circle.append(Vector3(0.17 * cos(a), 0.17 * sin(a), 0.0))
        rr.append(0.026)
    var wxf := Transform3D(Basis.looking_at(-d, Vector3.UP), c)
    kb.tube("dark", circle, rr, 12, true, wxf)
    for ang in [PI * 0.5, PI * 1.15, PI * 1.85]:
        kb.tube("dark", [Vector3.ZERO, Vector3(0.15 * cos(ang), 0.15 * sin(ang), 0.0)], [0.022, 0.018], 8, false, wxf)
    kb.ellipsoid("white", Vector3.ZERO, Vector3(0.05, 0.05, 0.035), wxf)


# Placa horizontal (asa): envergadura ao longo de X, corda ao longo de Z.
static func _plate(kb: KartMesh, key: String, half_span: float, half_chord: float, half_t: float, pos: Vector3, yaw: float = 0.0) -> void:
    kb.loft(key, [[-half_span, half_chord, -half_t, half_t, 3, 3], [half_span, half_chord, -half_t, half_t, 3, 3]], 0.04, 0.04, Transform3D(Basis(Vector3.UP, PI * 0.5 + yaw), pos))


# Placa vertical (aleta/lateral): comprimento ao longo de Z, altura de y0 a y1.
static func _vplate(kb: KartMesh, key: String, x: float, z0: float, z1: float, y0: float, y1: float, t: float, y1_end: float = -1.0) -> void:
    var ye := y1 if y1_end < 0.0 else y1_end
    kb.loft(key, [[z0, t, y0, y1, 3, 3], [(z0 + z1) * 0.5, t, y0, (y1 + ye) * 0.5, 3, 3], [z1, t, y0, ye, 3, 3]], 0.04, 0.04, Transform3D(Basis(), Vector3(x, 0.0, 0.0)))


static func _wings(kb: KartMesh, sp: Dictionary, id: String) -> void:
    match String(sp["wing"]):
        "duck":
            _plate(kb, "paint2", 0.46, 0.12, 0.022, Vector3(0.0, 0.93, 1.14))
            for s in [-1.0, 1.0]:
                _vplate(kb, "paint2", 0.46 * s, 1.04, 1.24, 0.84, 1.04, 0.014)
        "high":
            _plate(kb, "paint2", 0.66, 0.15, 0.024, Vector3(0.0, 1.20, 1.14))
            _plate(kb, "paint2", 0.66, 0.09, 0.020, Vector3(0.0, 1.27, 1.02))
            for s in [-1.0, 1.0]:
                _vplate(kb, "paint2", 0.68 * s, 0.92, 1.26, 0.90, 1.32, 0.016, 1.38)
                _vplate(kb, "dark", 0.22 * s, 1.08, 1.16, 0.62, 1.20, 0.03)
        "fins":
            for s in [-1.0, 1.0]:
                kb.loft("paint2", [[0.66, 0.022, 0.66, 0.90, 3, 3], [1.00, 0.022, 0.66, 1.18, 3, 3], [1.26, 0.022, 0.66, 1.38, 3, 3]], 0.0, 0.12, Transform3D(Basis(Vector3.BACK, -0.16 * s), Vector3(0.30 * s, 0.0, 0.0)))
            _plate(kb, "paint2", 0.40, 0.16, 0.018, Vector3(0.0, 0.84, 1.10))
        "swept":
            for s in [-1.0, 1.0]:
                _plate(kb, "paint2", 0.26, 0.11, 0.018, Vector3(0.44 * s, 0.98, 1.10), -0.30 * s)
                _vplate(kb, "dark", 0.22 * s, 1.0, 1.14, 0.62, 1.0, 0.03)
            _plate(kb, "glow", 0.30, 0.012, 0.012, Vector3(0.0, 0.92, 1.22))
        "crown":
            _plate(kb, "chrome", 0.50, 0.13, 0.026, Vector3(0.0, 0.96, 1.14))
            for sx in [-1.0, 1.0]:
                _vplate(kb, "chrome", 0.50 * sx, 1.02, 1.26, 0.82, 1.04, 0.016)
        _:
            pass


static func _exhausts(kb: KartMesh, sp: Dictionary) -> void:
    var t := String(sp["exhaust"])
    var prof: Array = [Vector2(0.0, 0.0), Vector2(0.0, 0.05), Vector2(0.22, 0.055), Vector2(0.36, 0.065), Vector2(0.44, 0.095), Vector2(0.47, 0.105), Vector2(0.45, 0.085), Vector2(0.36, 0.05), Vector2(0.34, 0.0)]
    var sc := 1.0
    var ys := 0.62
    match t:
        "big":
            sc = 1.45
        "small":
            sc = 0.8
            ys = 0.50
        "stacks":
            sc = 1.1
    for s in [-1.0, 1.0]:
        var xf := Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(0.22 * s, ys, 1.10))
        if t == "stacks":
            xf = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(sc, sc, sc)), Vector3(0.30 * s, 0.82, 1.08))
        kb.lathe("chrome", prof, xf, 18)


static func _lights(kb: KartMesh, sp: Dictionary) -> void:
    var t := String(sp["lights"])
    var f0: Array = (sp["front"] as Array)[0]
    var fc: Array = sp["front_caps"]
    var tip_z := float(f0[0]) - float(fc[0])
    var ym := (float(f0[2]) + float(f0[3])) * 0.5
    var hw := float(f0[1])
    for s in [-1.0, 1.0]:
        match t:
            "round":
                var p := Vector3(0.40 * s, ym + 0.13, float(f0[0]) - float(fc[0]) * 0.55)
                kb.ellipsoid("chrome", p, Vector3(0.15, 0.15, 0.11))
                kb.ellipsoid("light_f", p + Vector3(0.0, 0.0, -0.05), Vector3(0.115, 0.115, 0.08))
            _:
                var p2 := Vector3(hw * 0.62 * 0.62 * s, ym + 0.03, float(f0[0]) - float(fc[0]) * 0.78)
                kb.ellipsoid("light_f", p2, Vector3(0.10, 0.04, 0.06))
        kb.ellipsoid("light_r", Vector3(0.24 * s, 0.56, 1.16), Vector3(0.08, 0.04, 0.05))


# ------------------------------------------------------------------ rodas
static func _wheel_mats() -> Dictionary:
    if not _cache.has("wheel_mats"):
        var m := {}
        m["tire"] = _mat(Color(0.06, 0.06, 0.07), 0.9, 0.0, 0.1)
        m["rim"] = _mat(Color(0.86, 0.88, 0.94), 0.32, 0.45, 0.5)
        m["rimdark"] = _mat(Color(0.16, 0.17, 0.22), 0.5)
        _cache["wheel_mats"] = m
    return _cache["wheel_mats"]


static func _wheel_mesh(R: float, W: float, side: float, spokes: int) -> ArrayMesh:
    var key := "wheel_%s_%s_%s_%s" % [R, W, side, spokes]
    if _cache.has(key):
        return _cache[key]
    var kb := KartMesh.new()
    var half := W * 0.5
    var r_in := R * 0.62
    var cr := W * 0.34
    # pneu: perfil fechado, ombros arredondados, bandas de rodagem com sulcos
    var tp: Array = []
    tp.append(Vector2(-half * 0.80, r_in * 0.93))
    tp.append(Vector2(-half * 0.92, r_in))
    tp.append(Vector2(-half * 0.99, r_in + (R - r_in) * 0.40))
    for k in range(0, 5):
        var a := PI - (PI * 0.5) * float(k) / 4.0
        tp.append(Vector2(-half + cr + cr * cos(a), R - cr + cr * sin(a)))
    for k in range(1, 8):
        var u := float(k) / 8.0
        var x := lerpf(-half + cr, half - cr, u)
        var groove := 0.011 * exp(-pow((absf(x) - half * 0.30) / (half * 0.07), 2.0))
        tp.append(Vector2(x, R - 0.012 * pow(x / half, 2.0) - groove))
    for k in range(0, 5):
        var a := (PI * 0.5) - (PI * 0.5) * float(k) / 4.0
        tp.append(Vector2(half - cr + cr * cos(a), R - cr + cr * sin(a)))
    tp.append(Vector2(half * 0.99, r_in + (R - r_in) * 0.40))
    tp.append(Vector2(half * 0.92, r_in))
    tp.append(Vector2(half * 0.80, r_in * 0.93))
    kb.lathe("tire", tp, Transform3D.IDENTITY, 36, true)
    # aro
    var rr := r_in * 1.02
    var face := half * 0.82
    var rp: Array = [
        Vector2(face + 0.012, 0.0), Vector2(face + 0.014, rr * 0.10), Vector2(face - 0.02 * R, rr * 0.22),
        Vector2(face - 0.10 * R, rr * 0.45), Vector2(face - 0.14 * R, rr * 0.80), Vector2(face - 0.01, rr * 0.97),
        Vector2(face + 0.010, rr * 1.0), Vector2(face + 0.008, rr * 0.93), Vector2(face - 0.03 * R, rr * 0.86),
        Vector2(half * 0.2, rr * 0.90), Vector2(half * 0.2, 0.0)]
    if spokes > 0:
        kb.lathe("rimdark", rp, Transform3D.IDENTITY, 30)
        # cubo e raios
        kb.ellipsoid("rim", Vector3(0.0, 0.0, face - 0.01), Vector3(rr * 0.20, rr * 0.20, 0.04))
        for i in spokes:
            var ph := TAU * float(i) / float(spokes)
            var c := cos(ph)
            var s := sin(ph)
            var basis := Basis(Vector3(0, 0, 1), Vector3(-s, c, 0), Vector3(c, s, 0))
            var secs: Array = [
                [rr * 0.10, 0.014, -0.040, 0.040, 3, 3], [rr * 0.40, 0.016, -0.030, 0.030, 3, 3], [rr * 0.80, 0.018, -0.032, 0.032, 3, 3]]
            kb.loft("rim", secs, 0.03, 0.10 * rr, Transform3D(basis, Vector3(0.0, 0.0, face - 0.045 * R)), 8)
        kb.lathe("rim", [Vector2(face - 0.10 * R, rr * 0.80), Vector2(face - 0.01, rr * 0.98), Vector2(face + 0.012, rr * 1.0), Vector2(face + 0.004, rr * 0.94), Vector2(face - 0.04 * R, rr * 0.84)], Transform3D.IDENTITY, 30)
    else:
        kb.lathe("rim", rp, Transform3D.IDENTITY, 30)
        kb.lathe("rimdark", [Vector2(face + 0.016, rr * 0.45), Vector2(face + 0.020, rr * 0.70), Vector2(face + 0.010, rr * 0.74)], Transform3D.IDENTITY, 30)
    # eixo local Z -> eixo X do mundo, face para fora
    var xf := Transform3D(Basis(Vector3.UP, PI * 0.5 * side), Vector3.ZERO)
    var res := _retransform(kb, xf)
    var mesh: ArrayMesh = res["mesh"]
    var keys: Array = res["keys"]
    var wm := _wheel_mats()
    for i in keys.size():
        mesh.surface_set_material(i, wm[keys[i]])
    _cache[key] = mesh
    return mesh


# Aplica uma transformação a todas as superfícies já geradas (posição e normal).
static func _retransform(kb: KartMesh, xf: Transform3D) -> Dictionary:
    var nb := xf.basis.inverse().transposed()
    for k in kb.surf.keys():
        var d: Dictionary = kb.surf[k]
        var vs: PackedVector3Array = d["v"]
        var ns: PackedVector3Array = d["n"]
        for i in vs.size():
            vs[i] = xf * vs[i]
            ns[i] = (nb * ns[i]).normalized()
        d["v"] = vs
        d["n"] = ns
    return kb.commit()


# ------------------------------------------------------------------ piloto
static func _make_driver(col: Color, style: String) -> Node3D:
    var d := Node3D.new()
    d.name = "Piloto"
    var dkey := "driver_" + style
    if _cache.has(dkey):
        return _driver_instance(_cache[dkey], col)
    var kb := KartMesh.new()
    # tronco: loft ao longo de Z, girado para ficar em pé e inclinado para trás
    var torso_xf := Transform3D(Basis(Vector3.RIGHT, 0.20) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.60, 0.20))
    kb.loft("suit", [[0.02, 0.17, -0.12, 0.12, 2.4, 2.4], [0.22, 0.19, -0.13, 0.13, 2.4, 2.4], [0.44, 0.22, -0.13, 0.13, 2.4, 2.4], [0.58, 0.20, -0.11, 0.11, 2.4, 2.4]], 0.10, 0.08, torso_xf)
    kb.ellipsoid("white", Vector3(0.0, 0.95, 0.04), Vector3(0.08, 0.08, 0.035), Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3.ZERO))
    # pernas
    for s in [-1.0, 1.0]:
        kb.tube("suit", [Vector3(0.12 * s, 0.62, 0.24), Vector3(0.14 * s, 0.66, -0.05), Vector3(0.14 * s, 0.62, -0.38), Vector3(0.13 * s, 0.36, -0.62)], [0.085, 0.075, 0.065, 0.06], 12)
        kb.ellipsoid("glove", Vector3(0.13 * s, 0.30, -0.68), Vector3(0.075, 0.06, 0.12))
    # braços até o volante
    for s in [-1.0, 1.0]:
        var sh := Vector3(0.21 * s, 1.10, 0.30)
        var el := Vector3(0.30 * s, 0.98, 0.02)
        var hd := Vector3(0.17 * s, 0.98, -0.33)
        kb.tube("suit", [sh, sh.lerp(el, 0.5), el, el.lerp(hd, 0.5), hd], [0.062, 0.056, 0.050, 0.046, 0.044], 12)
        kb.ellipsoid("glove", hd, Vector3(0.058, 0.058, 0.062))
    # pescoço + capacete
    var hc := Vector3(0.0, 1.44, 0.30)
    kb.tube("white", [Vector3(0.0, 1.18, 0.33), Vector3(0.0, 1.30, 0.32)], [0.075, 0.07], 12)
    kb.ellipsoid("helmet", hc, Vector3(0.225, 0.215, 0.245))
    kb.ellipsoid("white", hc + Vector3(0.0, 0.0, 0.0), Vector3(0.034, 0.222, 0.252))
    kb.ellipsoid("visor", hc + Vector3(0.0, 0.015, -0.115), Vector3(0.178, 0.092, 0.13))
    kb.ellipsoid("helmet", hc + Vector3(0.0, -0.13, -0.10), Vector3(0.12, 0.07, 0.10))
    match style:
        "fin":
            kb.loft("helmet", [[-0.12, 0.016, 0.0, 0.07, 3, 3], [0.10, 0.016, 0.0, 0.17, 3, 3], [0.26, 0.016, 0.0, 0.06, 3, 3]], 0.04, 0.05, Transform3D(Basis(), hc + Vector3(0.0, 0.18, 0.0)))
        "pony":
            kb.ellipsoid("helmet", hc + Vector3(0.0, 0.06, 0.25), Vector3(0.075, 0.085, 0.085))
            kb.tube("helmet", [hc + Vector3(0.0, 0.05, 0.30), hc + Vector3(0.0, -0.06, 0.42), hc + Vector3(0.0, -0.22, 0.44)], [0.055, 0.05, 0.02], 10)
        "ears":
            kb.ellipsoid("helmet", hc + Vector3(-0.17, 0.17, 0.0), Vector3(0.07, 0.085, 0.045))
            kb.ellipsoid("helmet", hc + Vector3(0.17, 0.17, 0.0), Vector3(0.07, 0.085, 0.045))
        "antenna":
            kb.tube("white", [hc + Vector3(0.0, 0.20, 0.0), hc + Vector3(0.0, 0.34, 0.0)], [0.012, 0.010], 8)
            kb.ellipsoid("yellow", hc + Vector3(0.0, 0.38, 0.0), Vector3(0.045, 0.045, 0.045))
    _cache[dkey] = kb.commit()
    return _driver_instance(_cache[dkey], col)


static func _driver_instance(res: Dictionary, col: Color) -> Node3D:
    var d := Node3D.new()
    d.name = "Piloto"
    var mats := _materials(Color.WHITE, {"paint2": Color.WHITE})
    mats["suit"] = _mat(col.darkened(0.30), 0.65)
    mats["helmet"] = _mat(col, 0.28, 0.0, 0.55)
    var mi := MeshInstance3D.new()
    mi.name = "PilotoMalha"
    mi.mesh = res["mesh"]
    var keys: Array = res["keys"]
    for i in keys.size():
        mi.set_surface_override_material(i, mats[keys[i]])
    d.add_child(mi)
    return d
