class_name CoinBadge
extends PanelContainer

# Contador de moedas (ícone + valor). Acompanha o SaveGame sozinho e anima a contagem.

var _label: Label
var _shown := 0.0
var _tween: Tween


class CoinIcon extends Control:
    func _init() -> void:
        custom_minimum_size = Vector2(34.0, 34.0)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var c := size * 0.5
        var r := minf(size.x, size.y) * 0.5 - 1.0
        draw_circle(c, r, Color(0.78, 0.50, 0.05))
        draw_circle(c, r - 2.5, Color(1.0, 0.82, 0.20))
        draw_arc(c, r - 7.0, 0.0, TAU, 24, Color(0.85, 0.56, 0.08), 2.5, true)
        draw_arc(c, r - 3.5, PI * 1.05, PI * 1.6, 10, Color(1.0, 0.97, 0.7, 0.9), 2.5, true)


func _ready() -> void:
    add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.07, 0.13, 0.85), 22, Color(1.0, 0.82, 0.20, 0.7), 2, 12.0, 4.0))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    add_child(row)
    var icon := CoinIcon.new()
    row.add_child(icon)
    _label = UIKit.label("0", 26, UIKit.C_GOLD)
    row.add_child(_label)
    _shown = float(SaveGame.coins())
    _refresh()
    SaveGame.coins_changed.connect(_on_coins_changed)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_coins_changed(total: int) -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _tween = create_tween()
    _tween.tween_method(_set_shown, _shown, float(total), 0.5)


func _set_shown(v: float) -> void:
    _shown = v
    _refresh()


func _refresh() -> void:
    _label.text = str(int(round(_shown)))
