extends Node3D

# Vitrine de teste: mostra os 6 karts lado a lado (gira). Útil para ver os modelos.
var pivots: Array[Node3D] = []
var t := 0.0

func _ready() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.55, 0.72, 0.95)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.8, 0.85, 0.95)
    env.ambient_light_energy = 0.7
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
    sun.light_energy = 1.0
    sun.shadow_enabled = true
    add_child(sun)
    var floor := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(40, 20)
    floor.mesh = pm
    var fm := StandardMaterial3D.new()
    fm.albedo_color = Color(0.35, 0.37, 0.42)
    floor.material_override = fm
    add_child(floor)
    var cols: Array[Color] = [Color(0.9, 0.15, 0.12), Color(0.15, 0.5, 1.0), Color(0.18, 0.78, 0.38), Color(1.0, 0.85, 0.1), Color(0.62, 0.3, 0.95), Color(1.0, 0.72, 0.12)]
    var styles: Array[String] = ["fin", "pony", "ears", "antenna", "fin", "pony"]
    for i in 6:
        var p := Node3D.new()
        p.position = Vector3((float(i % 3) - 1.0) * -4.0, 0.0, (float(i / 3) - 0.5) * 4.2)
        add_child(p)
        p.add_child(KartModel.build(cols[i], Color(0.15, 0.45, 0.95), styles[i], KartModel.IDS[i]))
        pivots.append(p)
    var cam := Camera3D.new()
    cam.fov = 40.0
    add_child(cam)
    cam.look_at_from_position(Vector3(0.0, 4.2, -8.2), Vector3(0.0, 0.5, 0.0), Vector3.UP)

func _process(delta: float) -> void:
    t += delta
    for i in pivots.size():
        pivots[i].rotation.y = 0.55 + float(OS.get_environment("KROT").to_float())
