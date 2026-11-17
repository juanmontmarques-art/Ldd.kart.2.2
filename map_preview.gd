class_name MapPreview
extends Control

# Prévia 2D de uma pista: traçado, saltos sobre abismos (vermelho), pads de turbo (amarelo)
# e a largada. Também calcula os números mostrados na seleção de pista.

static var _cache: Dictionary = {}

var map_id := ""
var locked := false
var _t := 0.0


static func get_track(id: String) -> TrackData:
    if not _cache.has(id):
        var t := TrackData.create(id)
        t.build()
        _cache[id] = t
    return _cache[id]


# {km, falls, hairpins, climb}
static func info(id: String) -> Dictionary:
    var t := get_track(id)
    var hair := 0
    var cool := 0
    var w := 12
    for i in t.count:
        cool -= 1
        var a := t.pts[(i + t.count - w) % t.count]
        var b := t.pts[i]
        var c := t.pts[(i + w) % t.count]
        var d1 := Vector2(b.x - a.x, b.z - a.z).normalized()
        var d2 := Vector2(c.x - b.x, c.z - b.z).normalized()
        if d1.dot(d2) < 0.35 and cool <= 0:
            hair += 1
            cool = 25
    var lo := 1000.0
    var hi := -1000.0
    for p in t.pts:
        lo = minf(lo, p.y)
        hi = maxf(hi, p.y)
    return {"km": t.length / 1000.0, "falls": t.gaps.size() + t.cliffs.size(), "hairpins": hair, "climb": hi - lo, "tunnels": t.tunnels.size(), "bridges": t.bridges.size(), "shortcuts": t.branches.size()}


func setup(id: String) -> void:
    map_id = id
    queue_redraw()


func _process(delta: float) -> void:
    _t += delta
    queue_redraw()


func _draw() -> void:
    var r := Rect2(Vector2.ZERO, size)
    draw_rect(r, Color(0.02, 0.05, 0.10, 0.55))
    if map_id == "":
        return
    var t := get_track(map_id)
    var lo := Vector2(1e9, 1e9)
    var hi := Vector2(-1e9, -1e9)
    for p in t.pts:
        lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
        hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
    var span := hi - lo
    var pad := 28.0
    var sc := minf((size.x - pad * 2.0) / maxf(span.x, 1.0), (size.y - pad * 2.0) / maxf(span.y, 1.0))
    var off := (size - span * sc) * 0.5 - lo * sc
    var line := PackedVector2Array()
    for i in range(0, t.count, 3):
        var p := t.pts[i]
        line.append(Vector2(p.x, p.z) * sc + off)
    line.append(line[0])
    var base := Color(0.35, 0.40, 0.50) if locked else Color(0.92, 0.95, 1.0)
    draw_polyline(line, Color(0, 0, 0, 0.6), 9.0, true)
    draw_polyline(line, base, 5.0, true)
    for g in t.gaps:
        var i0 := int(g.x)
        var i1 := mini(int(g.x) + int(g.y), t.count - 1)
        for k in range(i0, i1 + 1):
            var p := t.pts[k]
            draw_circle(Vector2(p.x, p.z) * sc + off, 4.0, Color(1.0, 0.25, 0.20))
    for cl in t.cliffs:
        for k in range(cl.x, mini(cl.y, t.count - 1), 4):
            var p := t.pts[k]
            draw_circle(Vector2(p.x, p.z) * sc + off, 3.0, Color(1.0, 0.55, 0.15))
    for tn in t.tunnels:
        var seg := PackedVector2Array()
        for k in range(tn.x, mini(tn.y, t.count - 1) + 1, 2):
            var p := t.pts[k]
            seg.append(Vector2(p.x, p.z) * sc + off)
        if seg.size() > 1:
            draw_polyline(seg, Color(0.62, 0.35, 0.95), 5.0, true)
    for br in t.bridges:
        var seg2 := PackedVector2Array()
        for k in range(br.x, mini(br.y, t.count - 1) + 1, 2):
            var p := t.pts[k]
            seg2.append(Vector2(p.x, p.z) * sc + off)
        if seg2.size() > 1:
            draw_polyline(seg2, Color(0.35, 0.85, 1.0), 5.0, true)
    for bd in t.branches:
        var bp: PackedVector3Array = bd["pts"]
        var seg3 := PackedVector2Array()
        for k in range(0, bp.size(), 2):
            seg3.append(Vector2(bp[k].x, bp[k].z) * sc + off)
        if seg3.size() > 1:
            draw_polyline(seg3, Color(0.35, 1.0, 0.55), 3.0, true)
    for s in t.pad_spots:
        var p := t.pts[s % t.count]
        draw_circle(Vector2(p.x, p.z) * sc + off, 3.5, Color(1.0, 0.88, 0.2))
    var sp := t.pts[0]
    var spos := Vector2(sp.x, sp.z) * sc + off
    draw_rect(Rect2(spos - Vector2(6, 6), Vector2(12, 12)), Color(1, 1, 1))
    # ponto "kart" percorrendo a pista
    var idx := int(_t * 60.0) % t.count
    var kp := t.pts[idx]
    draw_circle(Vector2(kp.x, kp.z) * sc + off, 6.0, UIKit.C_GOLD)
