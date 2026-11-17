class_name Minimap
extends Control

# Minimapa do circuito desenhado por código (canto superior direito).

var track: TrackData
var kart_pos := Vector3.ZERO
var kart_yaw := 0.0

var others := PackedVector3Array()
var other_colors := PackedColorArray()

var _line := PackedVector2Array()
var _branch_lines: Array[PackedVector2Array] = []
var _tunnel_lines: Array[PackedVector2Array] = []
var _bridge_lines: Array[PackedVector2Array] = []
var _scale := 1.0
var _offset := Vector2.ZERO
var _ready_map := false


func setup(t: TrackData) -> void:
    track = t
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var lo := Vector2(INF, INF)
    var hi := Vector2(-INF, -INF)
    for p in track.pts:
        lo.x = minf(lo.x, p.x)
        lo.y = minf(lo.y, p.z)
        hi.x = maxf(hi.x, p.x)
        hi.y = maxf(hi.y, p.z)
    var area := size - Vector2(24.0, 24.0)
    _scale = minf(area.x / (hi.x - lo.x), area.y / (hi.y - lo.y))
    var used := (hi - lo) * _scale
    _offset = Vector2(12.0, 12.0) + (area - used) * 0.5 - lo * _scale
    _line.clear()
    for i in range(0, track.count, 5):
        _line.push_back(_to_map(track.pts[i]))
    _line.push_back(_line[0])
    for tn in track.tunnels:
        var seg := PackedVector2Array()
        for i in range(tn.x, tn.y + 1, 2):
            seg.push_back(_to_map(track.pts[i % track.count]))
        _tunnel_lines.append(seg)
    for b in track.bridges:
        var seg2 := PackedVector2Array()
        for i in range(b.x, b.y + 1, 3):
            seg2.push_back(_to_map(track.pts[i % track.count]))
        _bridge_lines.append(seg2)
    for br in track.branches:
        var bp: PackedVector3Array = br["pts"]
        var seg3 := PackedVector2Array()
        for i in range(0, bp.size(), 3):
            seg3.push_back(_to_map(bp[i]))
        seg3.push_back(_to_map(bp[bp.size() - 1]))
        _branch_lines.append(seg3)
    _ready_map = true


func _to_map(p: Vector3) -> Vector2:
    return Vector2(p.x, p.z) * _scale + _offset


func update_kart(pos: Vector3, yaw: float, other_pos: PackedVector3Array, colors: PackedColorArray) -> void:
    kart_pos = pos
    kart_yaw = yaw
    others = other_pos
    other_colors = colors
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.08, 0.12, 0.62), true)
    if not _ready_map:
        return
    draw_polyline(_line, Color(0, 0, 0, 0.8), 9.0, true)
    draw_polyline(_line, Color(0.92, 0.94, 0.98), 5.0, true)
    for seg in _branch_lines:
        if seg.size() > 1:
            draw_polyline(seg, Color(0.10, 0.45, 0.25, 0.9), 6.0, true)
            draw_polyline(seg, Color(0.35, 1.0, 0.55), 3.0, true)
    for seg in _bridge_lines:
        if seg.size() > 1:
            draw_polyline(seg, Color(0.35, 0.80, 1.0), 5.0, true)
    for seg in _tunnel_lines:
        if seg.size() > 1:
            draw_polyline(seg, Color(0.55, 0.25, 0.85), 5.0, true)
    var s := _to_map(track.pts[0])
    draw_circle(s, 5.0, Color(1.0, 0.9, 0.2))
    for i in others.size():
        var o := _to_map(others[i])
        draw_circle(o, 6.0, Color(0, 0, 0, 0.9))
        draw_circle(o, 4.5, other_colors[i])
    var k := _to_map(kart_pos)
    draw_circle(k, 7.0, Color(1, 1, 1))
    draw_circle(k, 5.0, Color(0.9, 0.15, 0.12))
    var f := Vector2(-sin(kart_yaw), -cos(kart_yaw))
    draw_line(k, k + f * 12.0, Color(1, 1, 1), 2.5, true)
