class_name TrackData
extends RefCounted

# Traçado do circuito: curva suave (Catmull-Rom fechada) passando por pontos de
# controle (x, altura, z). A curva é reamostrada em pontos igualmente
# espaçados, usados para a pista, o terreno, a progressão de volta e o minimapa.

const ROAD_HALF_WIDTH := 8.0   # inclui as zebras laterais
const SPACING := 2.5

# Vector3(x, altura, z). Circuito grande (~3,8 km): reta de largada, subida da
# montanha em zigue-zague, desfiladeiro com salto sobre abismo, serpentina pelo
# meio do mapa, descida pelo lado oeste com segundo abismo.
var control_points: Array[Vector3] = [
    Vector3(-156.0, 4.1, 390.0), Vector3(39.0, 4.1, 397.8), Vector3(221.0, 5.4, 387.4),
    Vector3(383.5, 8.1, 348.4), Vector3(470.6, 12.2, 260.0), Vector3(491.4, 20.2, 156.0),
    Vector3(483.6, 29.7, 52.0), Vector3(435.5, 36.5, -32.5), Vector3(351.0, 39.2, -71.5),
    Vector3(292.5, 41.9, -130.0), Vector3(301.6, 48.6, -221.0), Vector3(344.5, 54.0, -305.5),
    Vector3(266.5, 51.3, -370.5), Vector3(143.0, 45.9, -383.5), Vector3(26.0, 41.9, -364.0),
    Vector3(-91.0, 37.8, -331.5), Vector3(-143.0, 33.8, -247.0), Vector3(-52.0, 31.1, -175.5),
    Vector3(65.0, 28.4, -143.0), Vector3(149.5, 25.7, -71.5), Vector3(104.0, 21.6, 13.0),
    Vector3(-13.0, 17.6, 52.0), Vector3(-130.0, 14.9, 13.0), Vector3(-221.0, 12.2, -78.0),
    Vector3(-325.0, 10.8, -149.5), Vector3(-429.0, 9.5, -195.0), Vector3(-470.6, 8.1, -78.0),
    Vector3(-470.6, 6.8, 39.0), Vector3(-455.0, 5.4, 143.0), Vector3(-416.0, 4.1, 247.0),
    Vector3(-344.5, 3.4, 322.4), Vector3(-253.5, 4.1, 370.5),
]

# Lagos / lava: x = x, y = z, z = raio, w = nível da água.
var lakes: Array[Vector4] = [Vector4(270.0, 160.0, 78.0, 0.0)]
# Picos (montanha/vulcão): x, z, raio, altura. "craters" = profundidade da cratera (mesmo índice).
var peaks: Array[Vector4] = []
var craters: Array[float] = []
# Trechos de penhasco: sem proteção e com terreno despencando ao lado da pista (x = início, y = fim).
var cliffs: Array[Vector2i] = []
# Deslocamento lateral de cada pad (opcional; mesmo tamanho de pad_spots).
var pad_lats: Array[float] = []

var map_id := "aventura"
var _layout: Dictionary = {}

# --- Recursos dos mapas v10 ---
# Túneis: x = início, y = fim (amostras), z = tipo (0 montanha, 1 cachoeira, 2 caverna).
var tunnels: Array[Vector3i] = []
# Pontes: x = início, y = fim, z = tipo (0 suspensa sobre o lago, 1 estreita entre penhascos).
var bridges: Array[Vector3i] = []
# Atalhos: cada um é um Dictionary {a, c, half, pts, tans, sides, count, tunnel(Vector2i), ramps(Array[int])}.
# "a"/"c" = amostras da pista principal onde o atalho sai e volta.
var branches: Array[Dictionary] = []
# Inclinação lateral (tangente do ângulo) de cada amostra; positivo = lado direito mais alto.
var banks := PackedFloat32Array()
var bank_gain := 0.0
var bank_max := 0.3
# Parafusos / paredes: Vector4(início, fim, ângulo inicial°, ângulo final°) — a pista rola de um lado para o outro.
var twists: Array[Vector4] = []

# Abismos: x = amostra inicial, y = nº de amostras sem pista, z = queda (m) do lado de lá.
var gaps: Array[Vector3] = []
# Trechos de desfiladeiro (paredes de rocha): x = início, y = fim (amostras).
var canyons: Array[Vector2i] = []
var pad_spots: Array[int] = []
var ramp_spots: Array[int] = []
var box_spots: Array[int] = []
var barrel_spots: Array[int] = []
var mover_spots: Array[int] = []
# Zonas ocupadas por obstáculos (para a IA desviar): x = amostra, y = lateral, z = raio.
var obstacle_zones: Array[Vector3] = []

# --- extensões da Wonderland (vazias nos demais mapas) ---
var rolls: Array[Vector4] = []       # (início, fim, ângulo0, ângulo1) em graus; + = lado direito mais alto
var mags: Array[Vector2i] = []       # zonas de gravidade magnética (estrada de cabeça para baixo)
var lifts: Array[Vector3] = []       # (início, contagem, subida) - plataformas elevatórias (sem asfalto)
var narrow: Array[Vector3] = []      # (início, fim, meia-largura)
var bank_tunnels := false
var roll_on := PackedByteArray()     # 1 = amostra usa o referencial rolado (rights/ups)
var rights := PackedVector3Array()
var ups := PackedVector3Array()
var half_w := PackedFloat32Array()
var mag_flag := PackedByteArray()
var unsafe := PackedByteArray()      # 1 = amostra onde não se deve reaparecer (cai/move/abismo)
var collapses: Array[Vector2i] = []
var lift_flag := PackedInt32Array()  # índice do elevador (-1 = nenhum)
var pts := PackedVector3Array()
var tans := PackedVector3Array()
var sides := PackedVector3Array()   # vetor horizontal apontando para a direita
var count := 0
var length := 0.0
var ctrl_index := PackedInt32Array()  # índice de amostra de cada ponto de controle


# Cria o traçado de um mapa ("aventura" é o original; os outros vêm de track_layouts.gd).
static func create(id: String) -> TrackData:
    var t := TrackData.new()
    t.map_id = "aventura" if id == Catalog.TRACK_ID else id
    if t.map_id != "aventura":
        t._layout = TrackLayouts.get_layout(id)
        if t._layout.is_empty():
            t._layout = TrackLayoutsExt.get_layout(id)
        if t._layout.is_empty() and id == "wonderland":
            t._layout = WonderlandLayout.get_layout()
        if not t._layout.is_empty():
            var flat: PackedFloat32Array = t._layout["points"]
            var list: Array[Vector3] = []
            for k in range(0, flat.size(), 3):
                list.append(Vector3(flat[k], flat[k + 1], flat[k + 2]))
            t.control_points = list
            t.lakes.clear()
        else:
            t.map_id = "aventura"
    return t


func build() -> void:
    var n := control_points.size()
    var per := 40
    var dense := PackedVector3Array()
    for i in n:
        var p0 := control_points[(i - 1 + n) % n]
        var p1 := control_points[i]
        var p2 := control_points[(i + 1) % n]
        var p3 := control_points[(i + 2) % n]
        for k in per:
            dense.push_back(_catmull(p0, p1, p2, p3, float(k) / float(per)))
    dense.push_back(dense[0])

    var cum := PackedFloat32Array()
    cum.resize(dense.size())
    cum[0] = 0.0
    for i in range(1, dense.size()):
        cum[i] = cum[i - 1] + dense[i].distance_to(dense[i - 1])
    length = cum[dense.size() - 1]
    count = int(round(length / SPACING))
    var step := length / float(count)

    pts.resize(count)
    var j := 0
    for i in count:
        var d := float(i) * step
        while cum[j + 1] < d:
            j += 1
        var seg := maxf(cum[j + 1] - cum[j], 0.0001)
        pts[i] = dense[j].lerp(dense[j + 1], (d - cum[j]) / seg)

    ctrl_index.resize(n)
    for k in n:
        ctrl_index[k] = int(round(cum[k * per] / step)) % count

    # Pontos de interesse
    if _layout.is_empty():
        # Mapa original (relativos aos pontos de controle, robustos a pequenas variações)
        var c := ctrl_index
        gaps.append(Vector3(c[14] - 16, 6, 3.5))
        gaps.append(Vector3(c[27] + 20, 6, 3.0))
        canyons.append(Vector2i(c[12] + 28, c[15] + 17))
        canyons.append(Vector2i(c[27] - 25, c[27] + 65))
        pad_spots = [70, 320, c[14] - 46, 800, 1080, c[27] - 10, 1440]
        ramp_spots = [150, 880, 1140]
        box_spots = [110, 300, 600, 735, 1000, 1200, 1350]
        barrel_spots = [365, 840, 1030, 1385]
        mover_spots = [695, 975, 1165, 1425]
    else:
        gaps.assign(_layout["gaps"])
        cliffs.assign(_layout["cliffs"])
        canyons.assign(_layout["canyons"])
        pad_spots.assign(_layout["pads"])
        pad_lats.assign(_layout["pad_lats"])
        ramp_spots.assign(_layout["ramps"])
        box_spots.assign(_layout["boxes"])
        barrel_spots.assign(_layout["barrels"])
        mover_spots.assign(_layout["movers"])
        lakes.assign(_layout["lakes"])
        peaks.assign(_layout["peaks"])
        craters.assign(_layout["craters"])
        tunnels.assign(_layout.get("tunnels", []))
        bridges.assign(_layout.get("bridges", []))
        bank_gain = float(_layout.get("bank_gain", 0.0))
        bank_max = float(_layout.get("bank_max", 0.3))
        twists.assign(_layout.get("twists", []))
        rolls.assign(_layout.get("rolls", []))
        mags.assign(_layout.get("mags", []))
        lifts.assign(_layout.get("lifts", []))
        narrow.assign(_layout.get("narrow", []))
        collapses.assign(_layout.get("collapses", []))
        bank_tunnels = bool(_layout.get("bank_tunnels", false))
    for sp in barrel_spots:
        obstacle_zones.append(Vector3(sp, -3.5, 3.0))
        obstacle_zones.append(Vector3(sp + 14, 3.5, 3.0))
        obstacle_zones.append(Vector3(sp + 28, -3.5, 3.0))
    for q in mover_spots.size():
        var mlat := -3.5 if q % 2 == 0 else 3.5
        obstacle_zones.append(Vector3(mover_spots[q], mlat, 6.0))

    tans.resize(count)
    sides.resize(count)
    for i in count:
        var t := (pts[(i + 1) % count] - pts[(i - 1 + count) % count]).normalized()
        tans[i] = t
        var flat := Vector3(t.x, 0.0, t.z).normalized()
        sides[i] = flat.cross(Vector3.UP).normalized()

    # Queda do outro lado de cada abismo (aplicada depois das tangentes, que
    # continuam "limpas"). A diferença some suavemente nas próximas amostras.
    for g in gaps:
        var after := int(g.x) + int(g.y)
        for i in range(after, count):
            var k := float(i - after) / 110.0
            var p := pts[i]
            p.y -= g.z * (1.0 - smoothstep(0.0, 1.0, k))
            pts[i] = p

    _compute_banks()
    _compute_frames()
    if not _layout.is_empty():
        for bd in _layout.get("branches", []):
            _build_branch(bd)


# Inclinação lateral automática: nas curvas a pista "deita" para dentro (o lado interno fica mais baixo).
func _compute_banks() -> void:
    banks.resize(count)
    banks.fill(0.0)
    if bank_gain <= 0.0:
        return
    var w := 6
    const WIN := 12            # janela de suavização da inclinação (amostras para cada lado)
    var raw := PackedFloat32Array()
    raw.resize(count)
    for i in count:
        var t1 := tans[posmod(i - w, count)]
        var t2 := tans[(i + w) % count]
        var f := maxf(Vector2(t1.x, t1.z).length() * Vector2(t2.x, t2.z).length(), 0.01)
        var cr := (t1.x * t2.z - t1.z * t2.x) / f       # > 0 = curva para a direita
        var kappa := asin(clampf(cr, -1.0, 1.0)) / (2.0 * float(w) * SPACING)
        raw[i] = -clampf(kappa * bank_gain, -bank_max, bank_max)
    # Zonas sem inclinação: abismos, pontes suspensas, túneis, rampas.
    var dist := PackedInt32Array()
    dist.resize(count)
    dist.fill(9999)
    var marks: Array[Vector2i] = []
    for g in gaps:
        marks.append(Vector2i(int(g.x) - 12, int(g.x) + int(g.y) + 16))
    for b in bridges:
        marks.append(Vector2i(b.x - 8, b.y + 8))
    if not bank_tunnels:
        for t in tunnels:
            marks.append(Vector2i(t.x - 4, t.y + 4))
    for l in lifts:
        marks.append(Vector2i(int(l.x) - 10, int(l.x) + int(l.y) + 10))
    for r in ramp_spots:
        marks.append(Vector2i(r - 6, r + 8))
    for m in marks:
        for i in range(m.x, m.y + 1):
            dist[posmod(i, count)] = 0
    for pass_i in 2:
        for i in count:
            dist[i] = mini(dist[i], dist[posmod(i - 1, count)] + 1)
        for i in range(count - 1, -1, -1):
            dist[i] = mini(dist[i], dist[(i + 1) % count] + 1)
    for i in count:
        var acc := 0.0
        for o in range(-WIN, WIN + 1):
            acc += raw[posmod(i + o, count)]
        banks[i] = acc / float(2 * WIN + 1) * smoothstep(0.0, 28.0, float(dist[i]))
    # Parafusos: o ângulo vai de a0 a a1 (suavizado) e se mistura com a inclinação automática nas pontas.
    for tw in twists:
        var i0 := int(tw.x)
        var i1 := int(tw.y)
        var span := maxf(float(i1 - i0), 1.0)
        for i in range(i0, i1 + 1):
            var u := float(i - i0) / span
            var ang := lerpf(tw.z, tw.w, smoothstep(0.0, 1.0, u))
            var wgt := smoothstep(0.0, 34.0, float(mini(i - i0, i1 - i)))
            var ii := posmod(i, count)
            banks[ii] = lerpf(banks[ii], tan(deg_to_rad(ang)), wgt)


# Atalho: curva aberta (Catmull-Rom) ligando duas amostras da pista principal.
func _build_branch(bd: Dictionary) -> void:
    var flat: PackedFloat32Array = bd["ctrl"]
    var ctrl: Array[Vector3] = []
    for k in range(0, flat.size(), 3):
        ctrl.append(Vector3(flat[k], flat[k + 1], flat[k + 2]))
    var a := int(bd["a"])
    var c := int(bd["c"])
    ctrl[1] = pts[a]
    ctrl[ctrl.size() - 2] = pts[c]
    var dense := PackedVector3Array()
    for i in range(1, ctrl.size() - 2):
        for k in 20:
            dense.push_back(_catmull(ctrl[i - 1], ctrl[i], ctrl[i + 1], ctrl[i + 2], float(k) / 20.0))
    dense.push_back(ctrl[ctrl.size() - 2])
    var cum := PackedFloat32Array()
    cum.resize(dense.size())
    cum[0] = 0.0
    for i in range(1, dense.size()):
        cum[i] = cum[i - 1] + dense[i].distance_to(dense[i - 1])
    var total := cum[dense.size() - 1]
    var m := int(round(total / SPACING)) + 1
    var step := total / float(m - 1)
    var bp := PackedVector3Array()
    bp.resize(m)
    var j := 0
    for i in m:
        var d := float(i) * step
        while j < dense.size() - 2 and cum[j + 1] < d:
            j += 1
        var seg := maxf(cum[j + 1] - cum[j], 0.0001)
        bp[i] = dense[j].lerp(dense[j + 1], clampf((d - cum[j]) / seg, 0.0, 1.0))
    var bt := PackedVector3Array()
    var bs := PackedVector3Array()
    bt.resize(m)
    bs.resize(m)
    for i in m:
        var t := (bp[mini(i + 1, m - 1)] - bp[maxi(i - 1, 0)]).normalized()
        bt[i] = t
        bs[i] = Vector3(t.x, 0.0, t.z).normalized().cross(Vector3.UP).normalized()
    var tm: Vector2i = bd["tunnel"]
    var tun := Vector2i(-1, -1)
    if tm.x >= 0:
        tun = Vector2i(tm.x, m - 1 - tm.y)
    var ramps: Array[int] = []
    ramps.assign(bd["ramps"])
    branches.append({
        "id": branches.size(), "a": a, "c": c, "half": float(bd["half"]),
        "pts": bp, "tans": bt, "sides": bs, "count": m, "tunnel": tun, "ramps": ramps,
        "span": posmod(c - a, count),
    })


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
    var t2 := t * t
    var t3 := t2 * t
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


# Amostra mais próxima (distância horizontal) procurando perto de "hint".
func nearest(p: Vector3, hint: int, window: int) -> int:
    var best := hint
    var best_d := INF
    for o in range(-window, window + 1):
        var i := posmod(hint + o, count)
        var dx := pts[i].x - p.x
        var dz := pts[i].z - p.z
        var d := dx * dx + dz * dz
        if d < best_d:
            best_d = d
            best = i
    return best


# Amostra mais próxima numa curva aberta (atalho).
func nearest_open(arr: PackedVector3Array, p: Vector3, hint: int, window: int) -> int:
    var best := clampi(hint, 0, arr.size() - 1)
    var best_d := INF
    for o in range(-window, window + 1):
        var i := clampi(hint + o, 0, arr.size() - 1)
        var dx := arr[i].x - p.x
        var dz := arr[i].z - p.z
        var d := dx * dx + dz * dz
        if d < best_d:
            best_d = d
            best = i
    return best


# Está dentro de um túnel/caverna? (índice de progresso e atalho atual)
func tunnel_at(i: int, branch: int, bidx: int) -> int:
    if branch >= 0 and branch < branches.size():
        var tun: Vector2i = branches[branch]["tunnel"]
        if tun.x >= 0 and bidx >= tun.x and bidx <= tun.y:
            return 2
        return -1
    return tunnel_kind(i)


func flat_distance(p: Vector3, i: int) -> float:
    var dx := pts[i].x - p.x
    var dz := pts[i].z - p.z
    return sqrt(dx * dx + dz * dz)


func in_cliff(i: int) -> bool:
    for c in cliffs:
        if i >= c.x and i <= c.y:
            return true
    return false


# Tipo do túnel que cobre a amostra (-1 = nenhum).
func tunnel_kind(i: int) -> int:
    for t in tunnels:
        if i >= t.x and i <= t.y:
            return t.z
    return -1


func bridge_kind(i: int) -> int:
    for b in bridges:
        if i >= b.x and i <= b.y:
            return b.z
    return -1


# Ponto da pista a "lat" metros do centro, já considerando a inclinação lateral.
func at(i: int, lat: float) -> Vector3:
    if roll_on.size() > 0 and roll_on[i] == 1:
        return pts[i] + rights[i] * lat
    return pts[i] + sides[i] * lat + Vector3(0.0, lat * banks[i], 0.0)


# Normal da pista (aponta para "cima" do asfalto; para baixo nos trechos invertidos).
func normal_at(i: int) -> Vector3:
    if ups.size() > 0:
        return ups[i]
    return Vector3.UP


func half_at(i: int) -> float:
    if half_w.size() > 0:
        return half_w[i]
    return ROAD_HALF_WIDTH


# Recuo seguro para o respawn: sai de trechos instáveis (elevadores, pontes que caem, deslizantes, saltos).
func safe_index_before(i: int) -> int:
    if unsafe.size() == 0:
        return i
    var k := i
    var guard := 0
    while unsafe[posmod(k, count)] == 1 and guard < 260:
        k -= 1
        guard += 1
    return posmod(k, count)


func is_mag(i: int) -> bool:
    return mag_flag.size() > 0 and mag_flag[i] == 1


func lift_index(i: int) -> int:
    if lift_flag.size() > 0:
        return lift_flag[i]
    return -1


# Referencial da pista em cada amostra: lateral (rights) e normal (ups), com rolagem total quando houver.
func _compute_frames() -> void:
    rights.resize(count)
    ups.resize(count)
    half_w.resize(count)
    half_w.fill(ROAD_HALF_WIDTH)
    roll_on.resize(count)
    roll_on.fill(0)
    mag_flag.resize(count)
    mag_flag.fill(0)
    lift_flag.resize(count)
    lift_flag.fill(-1)
    var roll_ang := PackedFloat32Array()
    roll_ang.resize(count)
    for i in count:
        roll_ang[i] = atan(banks[i])
    for nw in narrow:
        for i in range(int(nw.x), int(nw.y) + 1):
            var ii := posmod(i, count)
            half_w[ii] = minf(half_w[ii], nw.z)
    # suaviza as bordas das seções estreitas
    for pass_i in 2:
        for i in count:
            half_w[i] = minf(half_w[i], half_w[posmod(i - 1, count)] + 0.12)
        for i in range(count - 1, -1, -1):
            half_w[i] = minf(half_w[i], half_w[(i + 1) % count] + 0.12)
    unsafe.resize(count)
    unsafe.fill(0)
    for cz in collapses:
        for i in range(cz.x - 6, cz.y + 6):
            unsafe[posmod(i, count)] = 1
    for g in gaps:
        for i in range(int(g.x) - 3, int(g.x) + int(g.y) + 6):
            unsafe[posmod(i, count)] = 1
    for li in lifts.size():
        var l := lifts[li]
        for i in range(int(l.x) - 8, int(l.x) + int(l.y) + 8):
            unsafe[posmod(i, count)] = 1
        for i in range(int(l.x), int(l.x) + int(l.y)):
            lift_flag[posmod(i, count)] = li
    for r in rolls:
        var i0 := int(r.x)
        var i1 := int(r.y)
        var span := maxf(float(i1 - i0), 1.0)
        for i in range(i0, i1 + 1):
            var u := float(i - i0) / span
            var ang := lerpf(r.z, r.w, smoothstep(0.0, 1.0, u)) if absf(r.z - r.w) > 0.01 else r.z
            var ii := posmod(i, count)
            roll_ang[ii] = deg_to_rad(ang) if absf(r.z - r.w) > 0.01 or absf(r.z) > 0.01 else roll_ang[ii]
            roll_on[ii] = 1
    for m in mags:
        for i in range(m.x, m.y + 1):
            var ii := posmod(i, count)
            mag_flag[ii] = 1
            roll_on[ii] = 1
    # suaviza a rolagem nas amostras rolantes (evita degraus nas emendas)
    for i in count:
        var t := tans[i]
        var side := sides[i]
        var up0 := side.cross(t).normalized()
        var r := roll_ang[i]
        rights[i] = (side * cos(r) + up0 * sin(r)).normalized()
        ups[i] = (up0 * cos(r) - side * sin(r)).normalized()


func in_gap(i: int) -> bool:
    for g in gaps:
        if i >= int(g.x) and i < int(g.x) + int(g.y):
            return true
    return false


func yaw_at(i: int) -> float:
    var t := tans[i]
    return atan2(-t.x, -t.z)
