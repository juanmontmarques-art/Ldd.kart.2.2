class_name WonderlandCheckpoints
extends RefCounted

# Checkpoints visuais (arcos de runas) + registro por piloto. Quem cai na lava volta ao último checkpoint
# (os demais acidentes voltam ao último ponto seguro da pista, via Racer.respawn).

var world: Node3D
var track: TrackData
var layout: Dictionary
var main_ref: Node = null
var list: Array = []
var passed := {}
var root: Node3D
var label: Label
var label_time := 0.0


func build(w: Node3D, tr: TrackData, lay: Dictionary) -> void:
    world = w
    track = tr
    layout = lay
    list = lay["checkpoints"]
    root = Node3D.new()
    root.name = "Wonderland_Checkpoints"
    world.add_child(root)
    for q in list.size():
        _arch(int(list[q]), q)
    var d := CheckDriver.new()
    d.owner_ref = self
    root.add_child(d)


class CheckDriver extends Node:
    var owner_ref: WonderlandCheckpoints
    func _physics_process(delta: float) -> void:
        owner_ref.tick(delta)


func _arch(i: int, q: int) -> void:
    var p := track.pts[i]
    var hw := track.half_at(i)
    var bas := Basis.looking_at(track.tans[i], track.ups[i])
    var mb := MeshBuilder.new()
    var col := Color(0.3, 0.9, 1.0)
    for sgn: float in [-1.0, 1.0]:
        mb.box(Vector3(sgn * (hw + 0.7), 3.2, 0), Vector3(0.28, 3.2, 0.28), col)
    mb.box(Vector3(0, 6.5, 0), Vector3(hw + 1.0, 0.28, 0.28), col)
    var mi := MeshInstance3D.new()
    mi.mesh = mb.to_mesh()
    mi.material_override = WonderlandMaterials.glow(col, 2.2)
    mi.transform = Transform3D(bas, p)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.visibility_range_end = 500.0
    mi.name = "Checkpoint_%d" % (q + 1)
    root.add_child(mi)


func attach(main: Node) -> void:
    main_ref = main
    var layer := CanvasLayer.new()
    layer.layer = 21
    main.add_child(layer)
    label = Label.new()
    label.add_theme_font_size_override("font_size", 34)
    label.add_theme_color_override("font_color", Color(0.5, 1.0, 1.0))
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    label.add_theme_constant_override("outline_size", 8)
    label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    label.position = Vector2(-300, 210)
    label.custom_minimum_size = Vector2(600, 50)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.modulate.a = 0.0
    layer.add_child(label)


func last_checkpoint(r: Racer) -> int:
    return int(passed.get(r.display_name, -1))


func tick(delta: float) -> void:
    if main_ref == null:
        return
    for r in main_ref.racers:
        var best := -1
        var bi := -1
        for q in list.size():
            var c: int = list[q]
            var rel := posmod(r.cur_idx - c + track.count / 2, track.count) - track.count / 2
            if rel >= 0 and rel < 400 and r.branch < 0 or (rel >= 0 and rel < 400 and r.branch >= 0):
                if best < 0 or rel < posmod(r.cur_idx - best + track.count / 2, track.count) - track.count / 2:
                    best = c
                    bi = q
        if best >= 0:
            var prev := int(passed.get(r.display_name, -1))
            if prev != best and (prev < 0 or posmod(best - prev + track.count / 2, track.count) - track.count / 2 > 0):
                passed[r.display_name] = best
                if r.is_player:
                    label.text = "CHECKPOINT %d / %d" % [bi + 1, list.size()]
                    label_time = 2.0
    label_time = maxf(label_time - delta, 0.0)
    if label != null:
        label.modulate.a = clampf(label_time, 0.0, 1.0)
