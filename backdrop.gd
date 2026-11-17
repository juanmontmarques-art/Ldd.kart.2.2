class_name Backdrop
extends Control

# Fundo animado dos menus em estilo webcore: degradê lilás→água, piso quadriculado em perspectiva
# rolando, janelinhas de sistema fantasmas à deriva, brilhos de estrela piscando e raios de velocidade suaves.
# Tudo em cores empoeiradas e movimento lento — confortável para ficar olhando.

var t := 0.0
var _streaks: Array[Vector4] = []   # x = y (0..1), y = fase, z = velocidade, w = comprimento (0..1)
var _sparks: Array[Vector4] = []    # x,y (0..1), z = tamanho, w = fase
var _wins: Array[Vector4] = []      # x,y (0..1), z = tamanho (fração da largura), w = fase
var _font: Font


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _font = ThemeDB.fallback_font
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    for i in 14:
        _streaks.append(Vector4(rng.randf_range(0.05, 0.60), rng.randf(), rng.randf_range(0.08, 0.26), rng.randf_range(0.08, 0.24)))
    for i in 30:
        _sparks.append(Vector4(rng.randf(), rng.randf_range(0.02, 0.62), rng.randf_range(5.0, 15.0), rng.randf() * TAU))
    for i in 4:
        _wins.append(Vector4(rng.randf_range(0.04, 0.80), rng.randf_range(0.06, 0.36), rng.randf_range(0.14, 0.22), rng.randf() * TAU))


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
    t += delta
    queue_redraw()


func _draw() -> void:
    var s := size
    var horizon := s.y * 0.58

    # Céu: lilás-noite no alto, pêssego-lavanda no horizonte
    var top := Color(0.20, 0.19, 0.42)
    var mid := Color(0.46, 0.44, 0.72)
    var low := Color(0.74, 0.68, 0.86)
    draw_polygon(
        PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, horizon * 0.55), Vector2(0, horizon * 0.55)]),
        PackedColorArray([top, top, mid, mid]))
    draw_polygon(
        PackedVector2Array([Vector2(0, horizon * 0.55), Vector2(s.x, horizon * 0.55), Vector2(s.x, horizon), Vector2(0, horizon)]),
        PackedColorArray([mid, mid, low, low]))

    # Sol/orbe suave
    var pulse := 0.5 + 0.5 * sin(t * 0.5)
    var orb := Vector2(s.x * 0.76, horizon * 0.72)
    draw_circle(orb, s.y * (0.30 + 0.015 * pulse), Color(0.96, 0.78, 0.88, 0.10))
    draw_circle(orb, s.y * 0.20, Color(0.98, 0.84, 0.90, 0.16))
    draw_circle(orb, s.y * 0.11, Color(1.0, 0.93, 0.90, 0.30))

    # Janelinhas fantasmas à deriva
    for w in _wins:
        var ww := w.z * s.x
        var wh := ww * 0.68
        var x := w.x * s.x + sin(t * 0.25 + w.w) * s.x * 0.02
        var y := w.y * s.y + cos(t * 0.21 + w.w) * s.y * 0.02
        _ghost_window(Rect2(x, y, ww, wh), 0.20)

    # Raios de velocidade (suaves)
    for st in _streaks:
        var x01 := fposmod(st.y + t * st.z, 1.5) - 0.25
        var len_px := st.w * s.x
        var x := x01 * s.x
        var y := st.x * s.y
        var fade := sin(clampf((x01 + 0.25) / 1.5, 0.0, 1.0) * PI) * 0.22
        draw_line(Vector2(x, y), Vector2(x + len_px, y), Color(0.84, 0.82, 1.0, fade), 2.0, true)
        draw_line(Vector2(x + len_px * 0.55, y), Vector2(x + len_px, y), Color(1, 1, 1, fade), 2.0, true)

    # Piso quadriculado em perspectiva (rola em direção ao jogador)
    var floor_top := Color(0.62, 0.58, 0.86)
    var floor_bot := Color(0.34, 0.32, 0.62)
    draw_polygon(
        PackedVector2Array([Vector2(0, horizon), Vector2(s.x, horizon), Vector2(s.x, s.y), Vector2(0, s.y)]),
        PackedColorArray([floor_top, floor_top, floor_bot, floor_bot]))
    var vp := Vector2(s.x * 0.5, horizon)
    var rows := 11
    var cols := 18
    var scroll := fposmod(t * 0.35, 2.0)
    var depth_h := s.y - horizon
    for r in rows:
        var za := (float(r) - scroll) / float(rows)
        var zb := (float(r) + 1.0 - scroll) / float(rows)
        # perspectiva: y cresce com o quadrado (mais perto = linhas mais espaçadas)
        var ya := horizon + depth_h * pow(clampf(za, 0.0, 1.0), 2.0)
        var yb := horizon + depth_h * pow(clampf(zb, 0.0, 1.0), 2.0)
        if yb <= ya + 0.5:
            continue
        var ka := ya - horizon
        var kb := yb - horizon
        for c in cols:
            if (c + r) % 2 != 0:
                continue
            var xa0 := (float(c) / float(cols) - 0.5) * s.x * 2.6
            var xa1 := (float(c + 1) / float(cols) - 0.5) * s.x * 2.6
            var fa := ka / depth_h
            var fb := kb / depth_h
            var p0 := Vector2(vp.x + xa0 * fa, ya)
            var p1 := Vector2(vp.x + xa1 * fa, ya)
            var p2 := Vector2(vp.x + xa1 * fb, yb)
            var p3 := Vector2(vp.x + xa0 * fb, yb)
            draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), Color(1, 1, 1, 0.10 + 0.08 * fb))
    # linha do horizonte
    draw_line(Vector2(0, horizon), Vector2(s.x, horizon), Color(1, 1, 1, 0.35), 2.0)

    # Brilhos de estrela piscando
    for sp in _sparks:
        var tw := 0.5 + 0.5 * sin(t * 1.6 + sp.w)
        var a := 0.18 + 0.50 * tw
        var pos := Vector2(sp.x * s.x, sp.y * s.y + sin(t * 0.3 + sp.w) * 6.0)
        Webcore.draw_sparkle(self, pos, sp.z * (0.7 + 0.5 * tw), Color(1.0, 0.97, 1.0, a))

    # Faixa quadriculada embaixo (identidade do jogo), em tom suave
    var cell := 22.0
    var band_y := s.y - cell * 2.0
    var off := fposmod(t * 40.0, cell * 2.0)
    var ncols := int(s.x / cell) + 4
    for row in 2:
        for c in ncols:
            if (c + row) % 2 == 0:
                var rx := float(c) * cell - off
                draw_rect(Rect2(rx, band_y + float(row) * cell, cell, cell), Color(1, 1, 1, 0.12))


func _ghost_window(r: Rect2, a: float) -> void:
    var bar_h := maxf(r.size.y * 0.16, 12.0)
    draw_rect(r, Color(0.86, 0.86, 0.98, a * 0.55))
    draw_rect(Rect2(r.position, Vector2(r.size.x, bar_h)), Color(0.74, 0.70, 0.96, a * 1.3))
    draw_rect(r, Color(1, 1, 1, a * 1.4), false, 1.5)
    for q in 3:
        draw_rect(Rect2(r.end.x - 12.0 - float(q) * 11.0, r.position.y + 3.0, 8.0, bar_h - 6.0), Color(1, 1, 1, a * 1.6))
    # "conteúdo": barrinhas
    var y := r.position.y + bar_h + 8.0
    for q in 3:
        draw_rect(Rect2(r.position.x + 8.0, y + float(q) * 10.0, r.size.x * (0.7 - 0.15 * float(q)), 4.0), Color(1, 1, 1, a * 0.9))
