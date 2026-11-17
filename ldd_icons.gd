class_name LddIcons
extends RefCounted

# Ícones vetoriais desenhados por código (sem imagens). Todos cabem num quadrado de
# lado "sz" centrado em "c". "t" é o tempo (para animar bandeira/engrenagem).

const INK := Color(0.04, 0.07, 0.20)


static func draw_icon(ci: CanvasItem, id: String, c: Vector2, sz: float, t: float, active: bool) -> void:
    match id:
        "flag":
            _flag(ci, c, sz, t)
        "trophy":
            _trophy(ci, c, sz)
        "helmet":
            _helmet(ci, c, sz)
        "palette":
            _palette(ci, c, sz)
        "gear":
            _gear(ci, c, sz, t if active else 0.0)
        "door":
            _door(ci, c, sz)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float) -> void:
    ci.draw_colored_polygon(pts, fill)
    var closed := pts.duplicate()
    closed.append(pts[0])
    ci.draw_polyline(closed, INK, w, true)


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 24, a0: float = 0.0, a1: float = TAU) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in n + 1:
        var a := lerpf(a0, a1, float(i) / float(n))
        out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
    return out


static func _flag(ci: CanvasItem, c: Vector2, sz: float, t: float) -> void:
    var w := maxf(2.0, sz * 0.06)
    var px := c.x - sz * 0.36
    ci.draw_line(Vector2(px, c.y - sz * 0.46), Vector2(px - sz * 0.10, c.y + sz * 0.5), INK, w * 2.6, true)
    ci.draw_line(Vector2(px, c.y - sz * 0.46), Vector2(px - sz * 0.10, c.y + sz * 0.5), Color(0.85, 0.88, 0.95), w * 1.2, true)
    var cols := 4
    var rows := 3
    var q := sz * 0.20
    var x0 := px + w
    var y0 := c.y - sz * 0.44
    for r in rows:
        for k in cols:
            var wave0 := sin(t * 5.0 + float(k) * 0.9) * sz * 0.035
            var wave1 := sin(t * 5.0 + float(k + 1) * 0.9) * sz * 0.035
            var a := Vector2(x0 + float(k) * q, y0 + float(r) * q + wave0 + float(k) * sz * 0.015)
            var b := Vector2(x0 + float(k + 1) * q, y0 + float(r) * q + wave1 + float(k + 1) * sz * 0.015)
            var d := Vector2(a.x, a.y + q)
            var e := Vector2(b.x, b.y + q)
            var col := Color.WHITE if (r + k) % 2 == 0 else Color(0.08, 0.09, 0.14)
            ci.draw_colored_polygon(PackedVector2Array([a, b, e, d]), col)
    var tl := Vector2(x0, y0)
    var tr := Vector2(x0 + float(cols) * q, y0 + sin(t * 5.0 + float(cols) * 0.9) * sz * 0.035 + float(cols) * sz * 0.015)
    var bl := Vector2(x0, y0 + float(rows) * q)
    var br := Vector2(tr.x, tr.y + float(rows) * q)
    ci.draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), INK, w, true)


static func _trophy(ci: CanvasItem, c: Vector2, sz: float) -> void:
    var gold := Color(1.0, 0.82, 0.18)
    var dark := Color(0.82, 0.55, 0.05)
    var w := maxf(2.0, sz * 0.06)
    # alças
    for s in [-1.0, 1.0]:
        ci.draw_arc(c + Vector2(s * sz * 0.30, -sz * 0.18), sz * 0.15, -PI * 0.5 + (0.0 if s > 0.0 else PI * 0.0), PI * 0.5 if s > 0.0 else PI * 1.5, 14, INK, w * 3.2, true)
    for s in [-1.0, 1.0]:
        var a0 := -PI * 0.5 if s > 0.0 else PI * 0.5
        ci.draw_arc(c + Vector2(s * sz * 0.30, -sz * 0.18), sz * 0.15, a0, a0 + PI, 14, gold, w * 1.6, true)
    # base
    ci.draw_rect(Rect2(c.x - sz * 0.26, c.y + sz * 0.38, sz * 0.52, sz * 0.12), INK)
    ci.draw_rect(Rect2(c.x - sz * 0.23, c.y + sz * 0.395, sz * 0.46, sz * 0.09), dark)
    # haste
    ci.draw_rect(Rect2(c.x - sz * 0.07, c.y + sz * 0.22, sz * 0.14, sz * 0.17), INK)
    ci.draw_rect(Rect2(c.x - sz * 0.05, c.y + sz * 0.22, sz * 0.10, sz * 0.16), dark)
    # taça
    var cup := PackedVector2Array()
    cup.append(Vector2(c.x - sz * 0.32, c.y - sz * 0.42))
    cup.append(Vector2(c.x + sz * 0.32, c.y - sz * 0.42))
    var arc := _ellipse(Vector2(c.x, c.y - sz * 0.42), sz * 0.32, sz * 0.66, 18, 0.0, PI)
    for p in arc:
        cup.append(p)
    _poly(ci, cup, gold, w)
    ci.draw_line(Vector2(c.x - sz * 0.20, c.y - sz * 0.34), Vector2(c.x - sz * 0.16, c.y - sz * 0.08), Color(1, 1, 0.85, 0.85), w * 1.5, true)
    ci.draw_line(Vector2(c.x - sz * 0.32, c.y - sz * 0.42), Vector2(c.x + sz * 0.32, c.y - sz * 0.42), dark, w, true)


static func _helmet(ci: CanvasItem, c: Vector2, sz: float) -> void:
    var w := maxf(2.0, sz * 0.06)
    var hc := c + Vector2(0.0, -sz * 0.04)
    var shell := _ellipse(hc, sz * 0.44, sz * 0.42, 28, PI, TAU)
    # parte de baixo (queixo)
    shell.append(hc + Vector2(sz * 0.44, sz * 0.22))
    shell.append(hc + Vector2(sz * 0.28, sz * 0.44))
    shell.append(hc + Vector2(-sz * 0.28, sz * 0.44))
    shell.append(hc + Vector2(-sz * 0.44, sz * 0.22))
    _poly(ci, shell, Color(0.90, 0.12, 0.10), w)
    # brilho
    ci.draw_arc(hc, sz * 0.34, PI * 1.10, PI * 1.45, 10, Color(1, 1, 1, 0.65), w * 1.6, true)
    # viseira
    var vis := PackedVector2Array([
        hc + Vector2(-sz * 0.36, -sz * 0.06), hc + Vector2(sz * 0.36, -sz * 0.06),
        hc + Vector2(sz * 0.38, sz * 0.14), hc + Vector2(sz * 0.20, sz * 0.22),
        hc + Vector2(-sz * 0.20, sz * 0.22), hc + Vector2(-sz * 0.38, sz * 0.14)])
    _poly(ci, vis, Color(0.10, 0.18, 0.40), w)
    ci.draw_line(hc + Vector2(-sz * 0.26, -sz * 0.0), hc + Vector2(-sz * 0.06, -sz * 0.0), Color(0.55, 0.78, 1.0, 0.9), w * 1.4, true)
    # listra branca
    ci.draw_line(hc + Vector2(0.0, -sz * 0.42), hc + Vector2(0.0, -sz * 0.08), Color.WHITE, w * 2.2, true)
    # queixeira
    ci.draw_rect(Rect2(hc.x - sz * 0.22, hc.y + sz * 0.30, sz * 0.44, sz * 0.12), Color(0.25, 0.28, 0.35))


static func _palette(ci: CanvasItem, c: Vector2, sz: float) -> void:
    var w := maxf(2.0, sz * 0.06)
    var body := _ellipse(c, sz * 0.48, sz * 0.40, 32)
    _poly(ci, body, Color(0.95, 0.78, 0.50), w)
    var hole := _ellipse(c + Vector2(sz * 0.16, sz * 0.14), sz * 0.09, sz * 0.08, 14)
    _poly(ci, hole, Color(0.12, 0.16, 0.30), w * 0.8)
    var dots: Array = [
        [Vector2(-0.28, -0.04), Color(0.95, 0.15, 0.15)],
        [Vector2(-0.14, -0.24), Color(1.0, 0.85, 0.1)],
        [Vector2(0.10, -0.26), Color(0.2, 0.8, 0.3)],
        [Vector2(0.30, -0.08), Color(0.2, 0.5, 1.0)],
        [Vector2(-0.18, 0.18), Color(0.75, 0.3, 0.95)]]
    for d in dots:
        var p: Vector2 = c + (d[0] as Vector2) * sz
        ci.draw_circle(p, sz * 0.085, INK)
        ci.draw_circle(p, sz * 0.065, d[1])
    # pincel
    var a := c + Vector2(sz * 0.05, sz * 0.40)
    var b := c + Vector2(sz * 0.46, -sz * 0.40)
    ci.draw_line(a, b, INK, w * 3.4, true)
    ci.draw_line(a, b, Color(0.85, 0.55, 0.20), w * 1.8, true)
    ci.draw_line(b, b + (b - a).normalized() * sz * 0.14, INK, w * 3.4, true)
    ci.draw_line(b, b + (b - a).normalized() * sz * 0.12, Color(0.9, 0.15, 0.55), w * 1.8, true)


static func _gear(ci: CanvasItem, c: Vector2, sz: float, t: float) -> void:
    var w := maxf(2.0, sz * 0.06)
    var teeth := 8
    var pts := PackedVector2Array()
    for i in teeth:
        var a := TAU * float(i) / float(teeth) + t * 0.8
        var span := TAU / float(teeth)
        for step in [[-0.30, 0.34], [-0.20, 0.50], [0.20, 0.50], [0.30, 0.34]]:
            var aa := a + span * float(step[0])
            var rr := sz * float(step[1])
            pts.append(c + Vector2(cos(aa), sin(aa)) * rr)
    _poly(ci, pts, Color(0.80, 0.86, 0.95), w)
    ci.draw_circle(c, sz * 0.26, Color(0.62, 0.70, 0.84))
    ci.draw_circle(c, sz * 0.15, INK)
    ci.draw_arc(c, sz * 0.36, PI * 1.1 + t * 0.8, PI * 1.5 + t * 0.8, 10, Color(1, 1, 1, 0.7), w * 1.4, true)


static func _door(ci: CanvasItem, c: Vector2, sz: float) -> void:
    var w := maxf(2.0, sz * 0.06)
    var door := PackedVector2Array([
        c + Vector2(-sz * 0.40, -sz * 0.46), c + Vector2(sz * 0.12, -sz * 0.46),
        c + Vector2(sz * 0.12, sz * 0.46), c + Vector2(-sz * 0.40, sz * 0.46)])
    _poly(ci, door, Color(0.95, 0.60, 0.12), w)
    var inner := PackedVector2Array([
        c + Vector2(-sz * 0.32, -sz * 0.38), c + Vector2(sz * 0.04, -sz * 0.38),
        c + Vector2(sz * 0.04, sz * 0.38), c + Vector2(-sz * 0.32, sz * 0.38)])
    _poly(ci, inner, Color(0.78, 0.42, 0.06), w * 0.7)
    ci.draw_circle(c + Vector2(-sz * 0.02, sz * 0.02), sz * 0.04, Color(1, 0.9, 0.4))
    # seta saindo
    var arrow := PackedVector2Array([
        c + Vector2(sz * 0.06, -sz * 0.10), c + Vector2(sz * 0.26, -sz * 0.10), c + Vector2(sz * 0.26, -sz * 0.26),
        c + Vector2(sz * 0.50, 0.0),
        c + Vector2(sz * 0.26, sz * 0.26), c + Vector2(sz * 0.26, sz * 0.10), c + Vector2(sz * 0.06, sz * 0.10)])
    _poly(ci, arrow, Color(1.0, 0.86, 0.20), w)
