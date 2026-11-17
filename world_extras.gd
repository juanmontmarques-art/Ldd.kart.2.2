class_name WorldExtras
extends RefCounted

# Estruturas dos mapas v10: túneis (montanha, cachoeira, caverna), pontes (suspensa e estreita),
# estradas dos atalhos e placas. Tudo montado com MeshBuilder; paredes/tetos/guarda-corpos têm colisão.

var w: WorldBuilder
var tr: TrackData
var th: MapTheme
var _lamps := MeshBuilder.new()
var _rng := RandomNumberGenerator.new()


func build(world: WorldBuilder) -> void:
    w = world
    tr = world.track
    th = world.theme
    _rng.seed = 4242 + tr.map_id.hash() % 1000
    for t in tr.tunnels:
        _tunnel(tr.pts, tr.sides, tr.tans, t.x, t.y, t.z, TrackData.ROAD_HALF_WIDTH, "tunel_%d" % t.x)
    for b in tr.bridges:
        if b.z == 0:
            _suspension_bridge(b)
        else:
            _stone_bridge(b)
    for br in tr.branches:
        _branch(br)
    if not _lamps.is_empty():
        var lm := w._add_mesh(_lamps.to_mesh(), w._mat_vertex_color(1.0, true))
        lm.name = "LuzesTunel"
        lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _beam(mb: MeshBuilder, a: Vector3, b: Vector3, t: float, col: Color) -> void:
    var d := b - a
    var l := d.length()
    if l < 0.01:
        return
    var dn := d / l
    var up := Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT
    mb.box((a + b) * 0.5, Vector3(t, t, l * 0.5), col, Basis.looking_at(dn, up))


# ------------------------------------------------------------------- túneis
func _tunnel_label(kind: int) -> String:
    match kind:
        1:
            return "CACHOEIRA"
        2:
            return "CAVERNA"
    return "TÚNEL"


func _ring(P: PackedVector3Array, S: PackedVector3Array, i: int, hw: float, H: float, rise: float) -> Array[Vector3]:
    var out: Array[Vector3] = []
    var base := P[i]
    var sd := S[i]
    out.append(base + sd * -hw + Vector3(0.0, -0.8, 0.0))
    out.append(base + sd * -hw + Vector3(0.0, H - rise, 0.0))
    for j in 5:
        var ph := float(j + 1) * PI / 6.0
        out.append(base + sd * (-hw * cos(ph)) + Vector3(0.0, H - rise + rise * sin(ph), 0.0))
    out.append(base + sd * hw + Vector3(0.0, H - rise, 0.0))
    out.append(base + sd * hw + Vector3(0.0, -0.8, 0.0))
    return out


func _tunnel(P: PackedVector3Array, S: PackedVector3Array, T: PackedVector3Array, i0: int, i1: int, kind: int, half: float, tag: String) -> void:
    var hw := half + 1.7
    var H := 8.4 if half > 6.5 else 7.2
    var rise := 2.4
    var rock := th.rock_color
    var inner_base := rock.darkened(0.55)
    if kind == 1:
        inner_base = Color(0.20, 0.34, 0.30)
    elif kind == 2:
        inner_base = Color(0.20, 0.17, 0.20)
    var sh := MeshBuilder.new()      # interior (visual)
    var cb := MeshBuilder.new()      # colisão
    var i := i0
    while i < i1:
        var j := mini(i + 2, i1)
        var ra := _ring(P, S, i, hw, H, rise)
        var rb := _ring(P, S, j, hw, H, rise)
        var center := P[i] + Vector3(0.0, 2.5, 0.0)
        for k in 8:
            var qc := (ra[k] + ra[k + 1] + rb[k] + rb[k + 1]) * 0.25
            var hint := center - qc
            var shade := 1.0 + (0.12 if (i / 2) % 2 == 0 else -0.05)
            var col := inner_base.lightened(0.06 * float(k % 3)) * shade
            col.a = 1.0
            sh.quad(ra[k], ra[k + 1], rb[k + 1], rb[k], col, hint)
            cb.quad(ra[k], ra[k + 1], rb[k + 1], rb[k], Color.WHITE, hint)
        if kind != 2 and i % 8 == 0:
            for sg in [-1.0, 1.0]:
                var sf: float = sg
                var lp := P[i] + S[i] * sf * 3.2 + Vector3(0.0, H - 0.15, 0.0)
                _lamps.box(lp, Vector3(0.45, 0.07, 1.0), Color(1.0, 0.92, 0.62), Basis.looking_at(T[i], Vector3.UP))
        elif kind == 2 and i % 10 == 0:
            var gc := Color(0.35, 0.95, 0.85) if (i / 10) % 2 == 0 else Color(0.85, 0.45, 1.0)
            var side := -1.0 if (i / 10) % 3 == 0 else 1.0
            _lamps.sphere(P[i] + S[i] * side * (hw - 0.5) + Vector3(0.0, 0.5, 0.0), Vector3(0.35, 0.4, 0.35), 3, 6, gc)
            _lamps.sphere(P[i] + S[i] * -side * (hw - 0.8) + Vector3(0.0, H - 1.3, 0.0), Vector3(0.25, 0.3, 0.25), 3, 6, gc.lightened(0.2))
        i += 2
    var shell := w._add_mesh(sh.to_mesh(), w._mat_vertex_color(1.0, true))
    shell.name = "Interior_" + tag
    shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var body := w._add_static(cb.to_collision(), w)
    body.name = "ColisaoTunel_" + tag

    _hill(P, S, T, i0, i1, kind, half, hw, H, rise, tag)

    # Placa na entrada.
    var lab := Label3D.new()
    lab.text = _tunnel_label(kind)
    lab.font_size = 150
    lab.pixel_size = 0.012
    lab.outline_size = 28
    lab.modulate = Color(1.0, 0.92, 0.25)
    lab.outline_modulate = Color(0.05, 0.05, 0.08)
    lab.transform = Transform3D(Basis.looking_at(T[i0], Vector3.UP), P[i0] + Vector3(0.0, H + 2.8, 0.0) - T[i0] * 0.6)
    w.add_child(lab)
    var lab2 := Label3D.new()
    lab2.text = "SAÍDA"
    lab2.font_size = 110
    lab2.pixel_size = 0.01
    lab2.outline_size = 22
    lab2.modulate = Color(0.55, 1.0, 0.65)
    lab2.outline_modulate = Color(0.05, 0.05, 0.08)
    lab2.transform = Transform3D(Basis.looking_at(T[i1], Vector3.UP), P[i1] + Vector3(0.0, H + 2.2, 0.0) + T[i1] * 0.6)
    w.add_child(lab2)


# Morro por cima do túnel: perfil meio-elíptico extrudado ao longo da pista, com faces de entrada/saída.
func _hill(P: PackedVector3Array, S: PackedVector3Array, T: PackedVector3Array, i0: int, i1: int, kind: int, half: float, hw: float, H: float, rise: float, tag: String) -> void:
    var wide := 36.0 if half > 6.5 else 26.0
    var top_base := 27.0 if kind == 0 else (21.0 if kind == 1 else 19.0)
    if half > 6.5 and kind == 0 and th.style == "alpine":
        top_base = 34.0
        wide = 44.0
    var rock := th.rock_color
    var grass := th.ground_a
    if kind == 2:
        grass = rock.lightened(0.1)
    var mb := MeshBuilder.new()
    var cb := MeshBuilder.new()
    var segs := 8
    var rings: Array = []
    var idxs: Array[int] = []
    var i := i0
    while true:
        idxs.append(i)
        if i >= i1:
            break
        i = mini(i + 3, i1)
    for q in idxs.size():
        var ii := idxs[q]
        var u := float(q)
        var wd := wide + 5.0 * sin(u * 0.8 + 0.5)
        var top := top_base * (0.9 + 0.22 * sin(u * 0.5 + 1.3))
        # Pontas do morro um pouco mais baixas, mas as faces de entrada continuam altas.
        var ring: Array[Vector3] = []
        for k in segs + 1:
            var ph := float(k) * PI / float(segs)
            var bump := 1.0 + 0.07 * sin(float(k) * 2.3 + u * 1.7)
            var lat := -wd * cos(ph)
            var y := P[ii].y - 2.5 + top * sin(ph) * bump
            ring.append(P[ii] + S[ii] * lat + Vector3(0.0, y - P[ii].y, 0.0))
        rings.append(ring)
    # Corpo
    for q in range(rings.size() - 1):
        var ra: Array = rings[q]
        var rb: Array = rings[q + 1]
        var axis := P[idxs[q]] + Vector3(0.0, -4.0, 0.0)
        for k in segs:
            var a: Vector3 = ra[k]
            var b: Vector3 = ra[k + 1]
            var c: Vector3 = rb[k + 1]
            var d: Vector3 = rb[k]
            var mid := (a + b + c + d) * 0.25
            var sin_ph := sin((float(k) + 0.5) * PI / float(segs))
            var tcol := smoothstep(0.30, 0.62, sin_ph)
            var col := rock.lerp(grass, tcol).lightened(0.04 * float((q + k) % 2))
            mb.quad(a, b, c, d, col, mid - axis)
            cb.quad(a, b, c, d, Color.WHITE, mid - axis)
        # Saias laterais (escondem o vão até o terreno)
        for sk in [0, segs]:
            var p0: Vector3 = ra[sk]
            var p1: Vector3 = rb[sk]
            var hint := (p0 - P[idxs[q]]).normalized()
            mb.quad(p0, p1, p1 + Vector3(0.0, -34.0, 0.0), p0 + Vector3(0.0, -34.0, 0.0), rock.darkened(0.2), hint)
    # Faces de entrada e saída (com a abertura do túnel)
    for face in 2:
        var ii := i0 if face == 0 else i1
        var ring: Array = rings[0] if face == 0 else rings[rings.size() - 1]
        var inner := _ring(P, S, ii, hw + 0.15, H + 0.15, rise)
        var out_dir := -T[ii] if face == 0 else T[ii]
        # O anel interno tem 9 pontos (parede esquerda, arco, parede direita); o externo também.
        for k in segs:
            var a: Vector3 = ring[k]
            var b: Vector3 = ring[k + 1]
            var c: Vector3 = inner[k + 1]
            var d: Vector3 = inner[k]
            var col := rock.darkened(0.12 + 0.1 * float(k % 2))
            mb.quad(a, b, c, d, col, out_dir)
            cb.quad(a, b, c, d, Color.WHITE, out_dir)
    var mi := w._add_mesh(mb.to_mesh(), w._mat_vertex_color(0.95))
    mi.name = "Morro_" + tag
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var body := w._add_static(cb.to_collision(), w)
    body.name = "ColisaoMorro_" + tag

    if kind == 1:
        _waterfall_curtain(P, S, T, i0, hw, H, top_base)


func _waterfall_curtain(P: PackedVector3Array, S: PackedVector3Array, T: PackedVector3Array, i0: int, hw: float, H: float, top: float) -> void:
    var wm := MeshBuilder.new()
    var base := P[i0] - T[i0] * 0.25
    var sd := S[i0]
    # Cortina d'água cobrindo a entrada (só visual: dá para atravessar).
    for q in 6:
        var f0 := -hw + 2.0 * hw * float(q) / 6.0
        var f1 := -hw + 2.0 * hw * float(q + 1) / 6.0
        var c := Color(0.80, 0.94, 1.0, 0.42 + 0.12 * float(q % 2))
        wm.quad(base + sd * f0 + Vector3(0.0, -0.3, 0.0), base + sd * f1 + Vector3(0.0, -0.3, 0.0), base + sd * f1 + Vector3(0.0, H + 0.6, 0.0), base + sd * f0 + Vector3(0.0, H + 0.6, 0.0), c, -T[i0])
        wm.quad(base + sd * f0 + Vector3(0.0, -0.3, 0.0), base + sd * f1 + Vector3(0.0, -0.3, 0.0), base + sd * f1 + Vector3(0.0, H + 0.6, 0.0), base + sd * f0 + Vector3(0.0, H + 0.6, 0.0), c, T[i0])
    # Cascata descendo pela face do morro, acima do arco.
    var face := P[i0] - T[i0] * 0.55
    for q in 4:
        var f0 := -5.0 + 10.0 * float(q) / 4.0
        var f1 := -5.0 + 10.0 * float(q + 1) / 4.0
        var c := Color(0.92, 0.98, 1.0, 0.62 - 0.1 * float(q % 2))
        wm.quad(face + sd * f0 + Vector3(0.0, H + 0.6, 0.0), face + sd * f1 + Vector3(0.0, H + 0.6, 0.0), face + sd * f1 + Vector3(0.0, top - 3.0, 0.0), face + sd * f0 + Vector3(0.0, top - 3.0, 0.0), c, -T[i0])
    # Espuma na base e névoa.
    wm.sphere(face + Vector3(0.0, 0.6, 0.0), Vector3(hw + 2.0, 1.0, 2.2), 3, 8, Color(1.0, 1.0, 1.0, 0.55))
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    var mi := w._add_mesh(wm.to_mesh(), m)
    mi.name = "Cachoeira"
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------- pontes
func _suspension_bridge(b: Vector3i) -> void:
    var i0 := b.x
    var i1 := b.y
    var len_s := i1 - i0
    var steel := Color(0.80, 0.80, 0.84)
    var tower_c := th.curb_a
    var deck := MeshBuilder.new()
    var rails := MeshBuilder.new()
    var rail_cb := MeshBuilder.new()
    var cab := MeshBuilder.new()
    var dark := Color(0.30, 0.32, 0.38)
    for i in range(i0, i1):
        var j := i + 1
        var down := Vector3(0.0, -1.3, 0.0)
        deck.quad(tr.at(i, -8.4) + down, tr.at(i, 8.4) + down, tr.at(j, 8.4) + down, tr.at(j, -8.4) + down, dark, Vector3.DOWN)
        deck.quad(tr.at(i, -8.4), tr.at(j, -8.4), tr.at(j, -8.4) + down, tr.at(i, -8.4) + down, steel, -tr.sides[i])
        deck.quad(tr.at(i, 8.4), tr.at(j, 8.4), tr.at(j, 8.4) + down, tr.at(i, 8.4) + down, steel, tr.sides[i])
        # Guarda-corpo (parede baixa com corrimão), com colisão.
        for sg in [-1.0, 1.0]:
            var sf: float = sg
            var lo0 := tr.at(i, sf * 8.55)
            var lo1 := tr.at(j, sf * 8.55)
            var hi := Vector3(0.0, 1.25, 0.0)
            var rc := th.barrier_a if (i / 3) % 2 == 0 else th.barrier_b
            rails.quad(lo0, lo1, lo1 + hi, lo0 + hi, rc, -tr.sides[i] * sf)
            rails.quad(lo0, lo1, lo1 + hi, lo0 + hi, rc, tr.sides[i] * sf)
            rails.quad(lo0 + hi, lo1 + hi, lo1 + hi + tr.sides[i] * sf * 0.3, lo0 + hi + tr.sides[i] * sf * 0.3, steel, Vector3.UP)
            rail_cb.quad(lo0 + Vector3(0.0, -0.5, 0.0), lo1 + Vector3(0.0, -0.5, 0.0), lo1 + hi, lo0 + hi, Color.WHITE, -tr.sides[i] * sf)
    # Torres e cabos
    var u1 := 0.2
    var u2 := 0.8
    var tower_h := 34.0
    for u in [u1, u2]:
        var ti: int = i0 + int(float(len_s) * float(u))
        var base := tr.pts[ti]
        var sd := tr.sides[ti]
        for sg in [-1.0, 1.0]:
            var sf2: float = sg
            _beam(cab, base + sd * sf2 * 10.0 + Vector3(0.0, -45.0, 0.0), base + sd * sf2 * 10.0 + Vector3(0.0, tower_h, 0.0), 1.1, tower_c)
        _beam(cab, base + sd * -10.0 + Vector3(0.0, 14.0, 0.0), base + sd * 10.0 + Vector3(0.0, 14.0, 0.0), 0.7, tower_c)
        _beam(cab, base + sd * -10.0 + Vector3(0.0, 27.0, 0.0), base + sd * 10.0 + Vector3(0.0, 27.0, 0.0), 0.7, tower_c)
        _beam(cab, base + sd * -10.0 + Vector3(0.0, tower_h, 0.0), base + sd * 10.0 + Vector3(0.0, tower_h, 0.0), 0.9, tower_c.darkened(0.2))
        # luzes de aviso
        for sg in [-1.0, 1.0]:
            var sf3: float = sg
            _lamps.sphere(base + sd * sf3 * 10.0 + Vector3(0.0, tower_h + 1.2, 0.0), Vector3(0.7, 0.7, 0.7), 3, 6, Color(1.0, 0.25, 0.2))
        # piers dentro d'água
        for sg in [-1.0, 1.0]:
            var sf4: float = sg
            cab.cylinder(base + sd * sf4 * 10.0 + Vector3(0.0, -46.0, 0.0), 3.4, 2.2, 45.0, 8, steel.darkened(0.15))
    # Cabos principais: parábola entre as torres, descendo até o tabuleiro nas pontas.
    var step := 5
    for sg in [-1.0, 1.0]:
        var sf5: float = sg
        var prev := Vector3.ZERO
        var have := false
        var q := 0
        while true:
            var ci: int = mini(i0 + q * step, i1)
            var u := float(ci - i0) / float(len_s)
            var hgt := 0.0
            if u < u1:
                var t := u / u1
                hgt = lerpf(1.2, tower_h, t * t)
            elif u > u2:
                var t2 := (1.0 - u) / (1.0 - u2)
                hgt = lerpf(1.2, tower_h, t2 * t2)
            else:
                var t3 := (u - 0.5) / (u2 - 0.5)
                hgt = lerpf(6.0, tower_h, t3 * t3)
            var pt := tr.pts[ci] + tr.sides[ci] * sf5 * 10.0 + Vector3(0.0, hgt, 0.0)
            if have:
                _beam(cab, prev, pt, 0.28, steel)
            if ci % 10 < step and hgt > 2.0:
                _beam(cab, tr.pts[ci] + tr.sides[ci] * sf5 * 10.0 + Vector3(0.0, 0.8, 0.0), pt, 0.09, steel.darkened(0.1))
            prev = pt
            have = true
            if ci >= i1:
                break
            q += 1
    var dm := w._add_mesh(deck.to_mesh(), w._mat_vertex_color(0.7))
    dm.name = "TabuleiroPonte"
    var rm := w._add_mesh(rails.to_mesh(), w._mat_vertex_color(0.7))
    rm.name = "GuardaCorpoPonte"
    var rb := w._add_static(rail_cb.to_collision(), w)
    rb.name = "ColisaoGuardaCorpo"
    var cm := w._add_mesh(cab.to_mesh(), w._mat_vertex_color(0.6))
    cm.name = "CabosPonte"
    cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var lab := Label3D.new()
    lab.text = "PONTE SUSPENSA"
    lab.font_size = 110
    lab.pixel_size = 0.01
    lab.outline_size = 22
    lab.modulate = Color(1.0, 0.92, 0.25)
    lab.outline_modulate = Color(0.05, 0.05, 0.08)
    lab.transform = Transform3D(Basis.looking_at(tr.tans[i0], Vector3.UP), tr.pts[i0] + Vector3(0.0, 9.0, 0.0) - tr.tans[i0] * 4.0)
    w.add_child(lab)


func _stone_bridge(b: Vector3i) -> void:
    var i0 := b.x
    var i1 := b.y
    var stone := th.rock_color.lightened(0.18)
    var deck := MeshBuilder.new()
    var curb_cb := MeshBuilder.new()
    for i in range(i0, i1):
        var j := i + 1
        var down := Vector3(0.0, -1.8, 0.0)
        deck.quad(tr.at(i, -8.3) + down, tr.at(i, 8.3) + down, tr.at(j, 8.3) + down, tr.at(j, -8.3) + down, stone.darkened(0.25), Vector3.DOWN)
        deck.quad(tr.at(i, -8.3), tr.at(j, -8.3), tr.at(j, -8.3) + down, tr.at(i, -8.3) + down, stone, -tr.sides[i])
        deck.quad(tr.at(i, 8.3), tr.at(j, 8.3), tr.at(j, 8.3) + down, tr.at(i, 8.3) + down, stone, tr.sides[i])
        # Mureta baixa nas bordas (dá para cair se bater de lado com força).
        for sg in [-1.0, 1.0]:
            var sf: float = sg
            var lo0 := tr.at(i, sf * 8.5)
            var lo1 := tr.at(j, sf * 8.5)
            var hi := Vector3(0.0, 0.55, 0.0)
            var mc := stone.lightened(0.1) if (i / 2) % 2 == 0 else stone
            deck.quad(lo0, lo1, lo1 + hi, lo0 + hi, mc, -tr.sides[i] * sf)
            deck.quad(lo0, lo1, lo1 + hi, lo0 + hi, mc, tr.sides[i] * sf)
            deck.quad(lo0 + hi, lo1 + hi, lo1 + hi + tr.sides[i] * sf * 0.5, lo0 + hi + tr.sides[i] * sf * 0.5, stone.lightened(0.25), Vector3.UP)
            curb_cb.quad(lo0, lo1, lo1 + hi, lo0 + hi, Color.WHITE, -tr.sides[i] * sf)
    # Pilares e arcos descendo até o fundo do desfiladeiro.
    var i := i0 + 6
    while i < i1 - 2:
        var base := tr.pts[i]
        deck.cylinder(base + Vector3(0.0, -52.0, 0.0), 4.6, 3.0, 50.0, 8, stone.darkened(0.12))
        deck.box(base + Vector3(0.0, -2.4, 0.0), Vector3(9.0, 0.6, 2.6), stone.darkened(0.05), Basis.looking_at(tr.sides[i], Vector3.UP))
        i += 14
    var dm := w._add_mesh(deck.to_mesh(), w._mat_vertex_color(0.9))
    dm.name = "PonteEstreita"
    var body := w._add_static(curb_cb.to_collision(), w)
    body.name = "ColisaoMureta"
    var lab := Label3D.new()
    lab.text = "PONTE ESTREITA"
    lab.font_size = 110
    lab.pixel_size = 0.01
    lab.outline_size = 22
    lab.modulate = Color(1.0, 0.6, 0.2)
    lab.outline_modulate = Color(0.05, 0.05, 0.08)
    lab.transform = Transform3D(Basis.looking_at(tr.tans[i0], Vector3.UP), tr.pts[i0] + Vector3(0.0, 6.0, 0.0) - tr.tans[i0] * 3.0)
    w.add_child(lab)


# ------------------------------------------------------------------ atalhos
func _branch(br: Dictionary) -> void:
    var P: PackedVector3Array = br["pts"]
    var S: PackedVector3Array = br["sides"]
    var T: PackedVector3Array = br["tans"]
    var m: int = br["count"]
    var half: float = br["half"]
    var tun: Vector2i = br["tunnel"]
    var lat: Array[float] = [-half, -half + 1.1, -half + 1.5, -0.15, 0.15, half - 1.5, half - 1.1, half]
    var mb := MeshBuilder.new()
    var cb := MeshBuilder.new()
    var wall := MeshBuilder.new()
    var wall_cb := MeshBuilder.new()
    var skirt := Color(0.55, 0.55, 0.58)
    var lift := Vector3(0.0, 0.04, 0.0)
    for i in range(m - 1):
        var j := i + 1
        var in_tun := tun.x >= 0 and i >= tun.x and i <= tun.y
        for k in 7:
            var c := w._road_strip_color(i, k)
            if in_tun:
                c = c.darkened(0.42)
            var pa := P[i] + S[i] * lat[k] + lift
            var pb := P[i] + S[i] * lat[k + 1] + lift
            var pc := P[j] + S[j] * lat[k + 1] + lift
            var pd := P[j] + S[j] * lat[k] + lift
            mb.quad(pa, pb, pc, pd, c, Vector3.UP)
        var down := Vector3(0.0, -1.6, 0.0)
        mb.quad(P[i] - S[i] * half + lift, P[j] - S[j] * half + lift, P[j] - S[j] * half + down, P[i] - S[i] * half + down, skirt, -S[i])
        mb.quad(P[i] + S[i] * half + lift, P[j] + S[j] * half + lift, P[j] + S[j] * half + down, P[i] + S[i] * half + down, skirt, S[i])
        cb.quad(P[i] - S[i] * (half + 0.4) + lift, P[i] + S[i] * (half + 0.4) + lift, P[j] + S[j] * (half + 0.4) + lift, P[j] - S[j] * (half + 0.4) + lift, Color.WHITE, Vector3.UP)
        # Muros dos dois lados (exceto nas entradas e dentro da caverna, onde as paredes já existem).
        if i > 7 and i < m - 9 and not in_tun:
            for sg in [-1.0, 1.0]:
                var sf: float = sg
                var o := half + 0.9
                var hi := Vector3(0.0, 1.2, 0.0)
                var c2 := th.barrier_a if (i / 2) % 2 == 0 else th.barrier_b
                var a0 := P[i] + S[i] * sf * o
                var a1 := P[j] + S[j] * sf * o
                wall.quad(a0, a1, a1 + hi, a0 + hi, c2, -S[i] * sf)
                wall.quad(a0, a1, a1 + hi, a0 + hi, c2, S[i] * sf)
                wall.quad(a0 + hi, a1 + hi, a1 + hi + S[i] * sf * 0.4, a0 + hi + S[i] * sf * 0.4, c2.lightened(0.2), Vector3.UP)
                wall_cb.quad(a0, a1, a1 + hi, a0 + hi, Color.WHITE, -S[i] * sf)
    var road := w._add_mesh(mb.to_mesh(), w._mat_vertex_color(0.95))
    road.name = "PistaAtalho%d" % int(br["id"])
    road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var body := w._add_static(cb.to_collision(), w)
    body.name = "ColisaoAtalho%d" % int(br["id"])
    if not wall.is_empty():
        var wm := w._add_mesh(wall.to_mesh(), w._mat_vertex_color(0.7))
        wm.name = "MurosAtalho%d" % int(br["id"])
        var wb := w._add_static(wall_cb.to_collision(), w)
        wb.name = "ColisaoMurosAtalho%d" % int(br["id"])
    # Rampas do atalho.
    for r in br["ramps"]:
        var ri: int = clampi(int(r), 6, m - 8)
        w.make_ramp_at(Basis.looking_at(T[ri], Vector3.UP), P[ri], half - 1.0, 4.4, 1.8)
    # Túnel (caverna) do atalho.
    if tun.x >= 0 and tun.y > tun.x + 6:
        _tunnel(P, S, T, tun.x, tun.y, 2, half, "caverna_%d" % int(br["id"]))
    _fork_sign(br)


# Placa "ATALHO" ao lado da pista principal, no ponto onde o atalho se separa.
func _fork_sign(br: Dictionary) -> void:
    var a: int = br["a"]
    var P: PackedVector3Array = br["pts"]
    var probe: Vector3 = P[mini(14, int(br["count"]) - 1)]
    var side := 1.0 if (probe - tr.pts[a]).dot(tr.sides[a]) > 0.0 else -1.0
    var base := tr.at(posmod(a - 10, tr.count), side * 11.5)
    var holder := Node3D.new()
    holder.name = "PlacaAtalho"
    holder.transform = Transform3D(Basis.looking_at(tr.tans[a], Vector3.UP), base + Vector3(0.0, 2.6, 0.0))
    w.add_child(holder)
    var panel_mesh := BoxMesh.new()
    panel_mesh.size = Vector3(5.4, 1.9, 0.14)
    var panel := MeshInstance3D.new()
    panel.mesh = panel_mesh
    panel.material_override = w._mat_color(Color(0.10, 0.55, 0.28), 0.6)
    holder.add_child(panel)
    var post_mesh := BoxMesh.new()
    post_mesh.size = Vector3(0.2, 3.2, 0.2)
    var post := MeshInstance3D.new()
    post.mesh = post_mesh
    post.material_override = w._mat_color(Color(0.35, 0.37, 0.42), 0.8)
    post.position = Vector3(0.0, -2.0, 0.0)
    holder.add_child(post)
    var lab := Label3D.new()
    lab.text = "ATALHO »" if side > 0.0 else "« ATALHO"
    lab.font_size = 120
    lab.pixel_size = 0.0085
    lab.modulate = Color(1, 1, 1)
    lab.outline_size = 14
    lab.outline_modulate = Color(0.02, 0.2, 0.1)
    lab.position = Vector3(0.0, 0.0, 0.09)
    holder.add_child(lab)
