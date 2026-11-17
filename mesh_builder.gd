class_name MeshBuilder
extends RefCounted

# Utilitário para montar malhas com cor por vértice (estilo cartoon) sem
# depender de normais geradas automaticamente. A orientação de cada triângulo
# é corrigida automaticamente usando um vetor "hint" (direção da face visível),
# então não há risco de faces invertidas/invisíveis.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()


func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, hint: Vector3) -> void:
    var n := (c - a).cross(b - a)
    if n.length_squared() < 0.000001:
        return
    if n.dot(hint) < 0.0:
        var nf := -n.normalized()
        _push(a, c, b, nf, nf, nf, color)
    else:
        var nn := n.normalized()
        _push(a, b, c, nn, nn, nn, color)


func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, color: Color, hint: Vector3) -> void:
    var n := (c - a).cross(b - a)
    if n.length_squared() < 0.000001:
        return
    if n.dot(hint) < 0.0:
        _push(a, c, b, na, nc, nb, color)
    else:
        _push(a, b, c, na, nb, nc, color)


# Quadrilátero com cantos em ordem (a, b, c, d) ao redor do polígono.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, hint: Vector3) -> void:
    tri(a, b, c, color, hint)
    tri(a, c, d, color, hint)


func box(center: Vector3, half: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
    var ax := basis.x * half.x
    var ay := basis.y * half.y
    var az := basis.z * half.z
    var signs: Array[float] = [1.0, -1.0]
    for s in signs:
        _face(center, ax * s, ay, az, color)
        _face(center, ay * s, az, ax, color)
        _face(center, az * s, ax, ay, color)


func _face(center: Vector3, normal_axis: Vector3, u: Vector3, v: Vector3, color: Color) -> void:
    var fc := center + normal_axis
    quad(fc - u - v, fc + u - v, fc + u + v, fc - u + v, color, normal_axis)


# Cilindro/cone ao longo de +Y a partir de base_center.
func cylinder(base_center: Vector3, r_bottom: float, r_top: float, height: float, segs: int, color: Color, cap_top: bool = true) -> void:
    var top_center := base_center + Vector3(0.0, height, 0.0)
    for i in segs:
        var a0 := TAU * float(i) / float(segs)
        var a1 := TAU * float(i + 1) / float(segs)
        var d0 := Vector3(cos(a0), 0.0, sin(a0))
        var d1 := Vector3(cos(a1), 0.0, sin(a1))
        var b0 := base_center + d0 * r_bottom
        var b1 := base_center + d1 * r_bottom
        var t0 := top_center + d0 * r_top
        var t1 := top_center + d1 * r_top
        var hint := d0 + d1
        tri_smooth(b0, b1, t1, d0, d1, d1, color, hint)
        tri_smooth(b0, t1, t0, d0, d1, d0, color, hint)
        if cap_top and r_top > 0.001:
            tri(top_center, t0, t1, color, Vector3.UP)


func cone(base_center: Vector3, radius: float, height: float, segs: int, color: Color) -> void:
    cylinder(base_center, radius, 0.0, height, segs, color, false)


func sphere(center: Vector3, radii: Vector3, rings: int, segs: int, color: Color) -> void:
    for r in rings:
        var th0 := PI * float(r) / float(rings)
        var th1 := PI * float(r + 1) / float(rings)
        for s in segs:
            var ph0 := TAU * float(s) / float(segs)
            var ph1 := TAU * float(s + 1) / float(segs)
            var u00 := _unit(th0, ph0)
            var u01 := _unit(th0, ph1)
            var u11 := _unit(th1, ph1)
            var u10 := _unit(th1, ph0)
            var p00 := center + u00 * radii
            var p01 := center + u01 * radii
            var p11 := center + u11 * radii
            var p10 := center + u10 * radii
            var n00 := (u00 / radii).normalized()
            var n01 := (u01 / radii).normalized()
            var n11 := (u11 / radii).normalized()
            var n10 := (u10 / radii).normalized()
            var hint := u00 + u01 + u11 + u10
            tri_smooth(p00, p01, p11, n00, n01, n11, color, hint)
            tri_smooth(p00, p11, p10, n00, n11, n10, color, hint)


func _unit(th: float, ph: float) -> Vector3:
    return Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))


func _push(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, color_in: Color) -> void:
    # Visual webcore: todo cenário montado por aqui (árvores, barreiras, rampas...) perde um pouco de saturação.
    var color := Webcore.soften(color_in, 0.78, 0.04)
    var base := verts.size()
    verts.push_back(a)
    verts.push_back(b)
    verts.push_back(c)
    norms.push_back(na)
    norms.push_back(nb)
    norms.push_back(nc)
    cols.push_back(color)
    cols.push_back(color)
    cols.push_back(color)
    idx.push_back(base)
    idx.push_back(base + 1)
    idx.push_back(base + 2)


func is_empty() -> bool:
    return verts.size() == 0


func to_mesh() -> ArrayMesh:
    var mesh := ArrayMesh.new()
    if verts.size() == 0:
        return mesh
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_COLOR] = cols
    arrays[Mesh.ARRAY_INDEX] = idx
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


# Colisão em malha (trimesh) com as mesmas faces; colide dos dois lados.
func to_collision() -> ConcavePolygonShape3D:
    var shape := ConcavePolygonShape3D.new()
    shape.backface_collision = true
    shape.set_faces(verts)
    return shape
