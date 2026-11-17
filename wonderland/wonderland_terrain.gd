class_name WonderlandTerrain
extends RefCounted

# Relevo da montanha (grade de alturas gerada por tools/wonderland_terrain.py): cume nevado, paredões, abismo,
# e a superfície da montanha SOBRE as cavernas. Dois LODs por bloco + colisão apenas perto da pista aberta.

const CHUNK_CELLS := 12
const BIN := "res://wonderland/data/terrain.bin"

var nx := 0
var nz := 0
var cell := 16.0
var min_x := 0.0
var min_z := 0.0
var h := PackedFloat32Array()
var cave_half := PackedFloat32Array()
var cave_up := PackedFloat32Array()
var track: TrackData
var root: Node3D
var near_open := {}
var hole := PackedByteArray()


func load_data() -> bool:
    var f := FileAccess.open(BIN, FileAccess.READ)
    if f == null:
        push_error("Wonderland: terrain.bin ausente")
        return false
    nx = f.get_32()
    nz = f.get_32()
    cell = f.get_float()
    min_x = f.get_float()
    min_z = f.get_float()
    var raw := f.get_buffer(nx * nz * 4)
    h = raw.to_float32_array()
    var cnt := f.get_32()
    cave_half = f.get_buffer(cnt * 4).to_float32_array()
    cave_up = f.get_buffer(cnt * 4).to_float32_array()
    return true


func height_at(x: float, z: float) -> float:
    var fx := (x - min_x) / cell
    var fz := (z - min_z) / cell
    var ix := clampi(int(floor(fx)), 0, nx - 2)
    var iz := clampi(int(floor(fz)), 0, nz - 2)
    var tx := clampf(fx - float(ix), 0.0, 1.0)
    var tz := clampf(fz - float(iz), 0.0, 1.0)
    return lerpf(lerpf(h[iz * nx + ix], h[iz * nx + ix + 1], tx), lerpf(h[(iz + 1) * nx + ix], h[(iz + 1) * nx + ix + 1], tx), tz)


func _color_at(y: float, slope: float, x: float, z: float) -> Color:
    var n := sin(x * 0.013) * cos(z * 0.017) * 0.5 + 0.5
    var rock := Color(0.42, 0.38, 0.35).lerp(Color(0.55, 0.5, 0.45), n)
    var grass := Color(0.20, 0.34, 0.16).lerp(Color(0.30, 0.40, 0.18), n)
    var snow := Color(0.92, 0.95, 1.0)
    var c := rock
    var gm := smoothstep(0.75, 0.35, slope) * smoothstep(260.0, 120.0, y)
    c = c.lerp(grass, gm)
    var sm := smoothstep(300.0, 360.0, y) * smoothstep(1.4, 0.5, slope)
    c = c.lerp(snow, sm)
    return c


func build(parent: Node3D, tr: TrackData) -> void:
    track = tr
    _make_holes()
    root = Node3D.new()
    root.name = "Wonderland_Terrain"
    parent.add_child(root)
    # chunks próximos de pista aberta recebem colisão
    var t0 := 1663
    var t1 := 4948
    for i in range(0, track.count, 3):
        if i >= t0 and i <= t1:
            continue
        var p := track.pts[i]
        var cx := int(floor((p.x - min_x) / cell / CHUNK_CELLS))
        var cz := int(floor((p.z - min_z) / cell / CHUNK_CELLS))
        for dz in range(-1, 2):
            for dx in range(-1, 2):
                near_open[Vector2i(cx + dx, cz + dz)] = true
    var ncx := int(ceil(float(nx - 1) / CHUNK_CELLS))
    var ncz := int(ceil(float(nz - 1) / CHUNK_CELLS))
    for cz in ncz:
        for cx in ncx:
            _chunk(cx, cz)


# Entradas das cavernas: a face da montanha invade o volume do túnel. Remove os quadrados do relevo que estão dentro da boca
# (acima do nível da pista), abrindo a passagem; o túnel/portal fecha o resto.
func _make_holes() -> void:
    hole.resize(nx * nz)
    hole.fill(0)
    var t0 := 1663
    var t1 := 4948
    var zones := [Vector2i(t0 - 10, t0 + 16), Vector2i(t1 - 16, t1 + 10)]
    for z in zones:
        var i: int = z.x
        while i <= z.y:
            var p := track.pts[i]
            var half := maxf(cave_half[clampi(i, t0, t1)], 18.0) * 1.12 + 9.0
            var cx := int(round((p.x - min_x) / cell))
            var cz := int(round((p.z - min_z) / cell))
            var r := int(ceil(half / cell)) + 1
            for dz in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    var ix := cx + dx
                    var iz := cz + dz
                    if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
                        continue
                    var wx := min_x + float(ix) * cell
                    var wz := min_z + float(iz) * cell
                    if Vector2(wx - p.x, wz - p.z).length() < half and h[iz * nx + ix] > p.y - 2.0:
                        hole[iz * nx + ix] = 1
            i += 2


func _is_hole(ix: int, iz: int) -> bool:
    return ix >= 0 and iz >= 0 and ix < nx and iz < nz and hole[iz * nx + ix] == 1


func _vert(ix: int, iz: int, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray) -> void:
    ix = clampi(ix, 0, nx - 1)
    iz = clampi(iz, 0, nz - 1)
    var x := min_x + float(ix) * cell
    var z := min_z + float(iz) * cell
    var y := h[iz * nx + ix]
    var hx := h[iz * nx + mini(ix + 1, nx - 1)] - h[iz * nx + maxi(ix - 1, 0)]
    var hz := h[mini(iz + 1, nz - 1) * nx + ix] - h[maxi(iz - 1, 0) * nx + ix]
    var nrm := Vector3(-hx, 2.0 * cell, -hz).normalized()
    var slope := sqrt(hx * hx + hz * hz) / (2.0 * cell)
    verts.push_back(Vector3(x, y, z))
    norms.push_back(nrm)
    cols.push_back(_color_at(y, slope, x, z))


var _last_faces := PackedVector3Array()


func _mesh(cx: int, cz: int, stride: int) -> ArrayMesh:
    var x0 := cx * CHUNK_CELLS
    var z0 := cz * CHUNK_CELLS
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    var idx := PackedInt32Array()
    var m := CHUNK_CELLS / stride
    for k in m + 1:
        for l in m + 1:
            _vert(x0 + l * stride, z0 + k * stride, verts, norms, cols)
    for k in m:
        for l in m:
            if stride == 1:
                var gx := x0 + l
                var gz := z0 + k
                if _is_hole(gx, gz) or _is_hole(gx + 1, gz) or _is_hole(gx, gz + 1) or _is_hole(gx + 1, gz + 1):
                    continue
            var a := k * (m + 1) + l
            idx.append_array([a, a + 1, a + m + 2, a, a + m + 2, a + m + 1])
    _last_faces = PackedVector3Array()
    for q in idx:
        _last_faces.push_back(verts[q])
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = verts
    arr[Mesh.ARRAY_NORMAL] = norms
    arr[Mesh.ARRAY_COLOR] = cols
    arr[Mesh.ARRAY_INDEX] = idx
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    return am


func _chunk(cx: int, cz: int) -> void:
    if cx * CHUNK_CELLS >= nx - 1 or cz * CHUNK_CELLS >= nz - 1:
        return
    var mat := WonderlandMaterials.rock(Color(0.5, 0.5, 0.5), Color(0.8, 0.8, 0.8), 0.045, 0.0, 0.85)
    var near := MeshInstance3D.new()
    near.mesh = _mesh(cx, cz, 1)
    var faces0 := _last_faces
    near.material_override = mat
    near.visibility_range_end = 900.0
    near.visibility_range_end_margin = 60.0
    near.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    root.add_child(near)
    var far := MeshInstance3D.new()
    far.mesh = _mesh(cx, cz, 3)
    far.material_override = mat
    far.visibility_range_begin = 840.0
    far.visibility_range_begin_margin = 60.0
    far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    root.add_child(far)
    if near_open.has(Vector2i(cx, cz)):
        var body := StaticBody3D.new()
        body.collision_layer = 1
        body.collision_mask = 0
        var shape := ConcavePolygonShape3D.new()
        shape.set_faces(faces0)
        shape.backface_collision = true
        var cs := CollisionShape3D.new()
        cs.shape = shape
        body.add_child(cs)
        root.add_child(body)
