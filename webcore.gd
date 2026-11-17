class_name Webcore
extends RefCounted

# Identidade visual "webcore" (internet antiga / Y2K / sonho de CRT) do jogo todo.
# Regras: cores empoeiradas e pastel, névoa lilás-azulada, bordas de "janela de sistema",
# estrelinhas e xadrez. Nada de efeito forte: a leitura da pista vem sempre em primeiro lugar.

const SAT := 0.60                          # quanto da saturação original sobra nas cores de cenário
const ENV_SATURATION := 0.74               # ajuste final de saturação da tela 3D (Environment)
const HAZE := Color(0.72, 0.74, 0.92)      # lilás-azulado usado para "empoeirar" as cores

# Paleta de interface
const INK := Color(0.09, 0.08, 0.20)       # contorno / texto escuro
const NIGHT := Color(0.12, 0.11, 0.26)     # fundo de painéis
const NIGHT_TOP := Color(0.20, 0.19, 0.40)
const LILAC := Color(0.70, 0.64, 0.92)
const AQUA := Color(0.52, 0.84, 0.86)
const PINK := Color(0.93, 0.62, 0.78)
const BUTTER := Color(0.96, 0.88, 0.60)
const MINT := Color(0.64, 0.88, 0.72)
const SILVER := Color(0.82, 0.84, 0.92)
const WIN_FACE := Color(0.78, 0.80, 0.90)  # "cinza Windows" tingido de lilás
const WIN_LIGHT := Color(0.97, 0.97, 1.0)
const WIN_DARK := Color(0.38, 0.38, 0.55)


# Reduz a saturação e puxa a cor um pouco para a névoa lilás. Mantém a luminosidade.
static func soften(c: Color, sat: float = SAT, tint: float = 0.10) -> Color:
    var g := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
    var out := Color(g, g, g, c.a).lerp(c, sat)
    var haze := Color(HAZE.r * (0.35 + g * 0.9), HAZE.g * (0.35 + g * 0.9), HAZE.b * (0.35 + g * 0.9), c.a)
    out = out.lerp(haze, tint)
    out.r = clampf(out.r, 0.0, 1.0)
    out.g = clampf(out.g, 0.0, 1.0)
    out.b = clampf(out.b, 0.0, 1.0)
    return out


# Gradação de cor padrão das telas 3D: menos saturado, contraste calmo.
static func grade(env: Environment, sat: float = ENV_SATURATION - 0.04, contrast: float = 1.02) -> void:
    env.adjustment_enabled = true
    env.adjustment_saturation = sat
    env.adjustment_contrast = contrast


# Estrela de quatro pontas (brilho) como polígono — não depende de fonte/emoji.
static func star_points(center: Vector2, radius: float, squash: float = 0.28) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in 8:
        var a := -PI * 0.5 + float(i) * PI * 0.25
        var r := radius if i % 2 == 0 else radius * squash
        pts.append(center + Vector2(cos(a), sin(a)) * r)
    return pts


# Desenha uma estrelinha de brilho dentro de qualquer Control em _draw().
static func draw_sparkle(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
    ci.draw_colored_polygon(star_points(center, radius), color)


# Moldura de "janela de sistema" (barra de título em degradê + bordas chanfradas).
# Retorna o Rect2 interno (conteúdo).
static func draw_window(ci: CanvasItem, r: Rect2, title: String, font: Font, accent: Color = LILAC, body: Color = NIGHT) -> Rect2:
    var bar_h := clampf(r.size.y * 0.12, 22.0, 34.0)
    ci.draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.28))
    ci.draw_rect(r, WIN_FACE)
    ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), WIN_LIGHT)
    ci.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), WIN_LIGHT)
    ci.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), WIN_DARK)
    ci.draw_rect(Rect2(r.end.x - 2, r.position.y, 2, r.size.y), WIN_DARK)
    var bar := Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, bar_h))
    var c0 := accent.darkened(0.30)
    var c1 := accent.lightened(0.10)
    ci.draw_polygon(
        PackedVector2Array([bar.position, Vector2(bar.end.x, bar.position.y), bar.end, Vector2(bar.position.x, bar.end.y)]),
        PackedColorArray([c0, c1, c1, c0]))
    var fs := int(bar_h * 0.58)
    ci.draw_string(font, Vector2(bar.position.x + 8, bar.position.y + bar_h * 0.70), title, HORIZONTAL_ALIGNMENT_LEFT, bar.size.x - 70, fs, INK)
    # três botõezinhos decorativos
    for q in 3:
        var bx := bar.end.x - 20.0 - float(q) * 19.0
        var b := Rect2(bx, bar.position.y + 3.0, 16.0, bar_h - 6.0)
        ci.draw_rect(b, WIN_FACE)
        ci.draw_rect(Rect2(b.position, Vector2(b.size.x, 1)), WIN_LIGHT)
        ci.draw_rect(Rect2(b.position.x, b.end.y - 1, b.size.x, 1), WIN_DARK)
    var inner := Rect2(r.position + Vector2(5, 8 + bar_h), Vector2(r.size.x - 10, r.size.y - 13 - bar_h))
    ci.draw_rect(inner, body)
    ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2)), WIN_DARK)
    ci.draw_rect(Rect2(inner.position, Vector2(2, inner.size.y)), WIN_DARK)
    return inner
