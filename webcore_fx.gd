extends CanvasLayer

# Camada de acabamento "webcore" por cima de TODO o jogo (autoload "WebFX").
# Bem sutil para não cansar a vista: linhas de varredura de CRT quase invisíveis, vinheta lilás
# nos cantos e uma faixa de interferência lentíssima. Dá para desligar em CONFIGURAÇÕES.

const SHADER := """
shader_type canvas_item;
render_mode blend_mix;

uniform float scan_alpha = 0.050;
uniform float vig_alpha = 0.30;
uniform float band_alpha = 0.022;
uniform vec3 ink = vec3(0.06, 0.05, 0.16);
uniform vec3 haze = vec3(0.62, 0.60, 0.95);
uniform float t = 0.0;

void fragment() {
    vec2 uv = UV;
    // linhas de varredura (3 px de período, sempre nítidas)
    float line = step(1.5, mod(FRAGCOORD.y, 3.0));
    float sa = scan_alpha * (1.0 - line);
    // vinheta: só começa depois de ~60% do raio, não escurece o centro
    vec2 d = (uv - 0.5) * vec2(1.0, 0.85);
    float r = length(d) * 1.6;
    float v = smoothstep(0.62, 1.25, r);
    float va = vig_alpha * v;
    // faixa de interferência bem lenta
    float band = smoothstep(0.0, 0.5, 0.5 - abs(fract(uv.y * 0.6 - t * 0.035) - 0.5));
    vec3 band_col = haze;
    float ba = band_alpha * band;
    float a = 1.0 - (1.0 - sa) * (1.0 - va) * (1.0 - ba);
    vec3 rgb = (ink * (sa + va) + band_col * ba) / max(sa + va + ba, 0.0001);
    COLOR = vec4(rgb, a);
}
"""

var enabled := true:
    set(value):
        enabled = value
        if _rect != null:
            _rect.visible = value

var _rect: ColorRect
var _mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
    layer = 90                       # abaixo do fade do Flow (100), acima de tudo o resto
    process_mode = Node.PROCESS_MODE_ALWAYS
    _rect = ColorRect.new()
    _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rect.color = Color.WHITE
    var sh := Shader.new()
    sh.code = SHADER
    _mat = ShaderMaterial.new()
    _mat.shader = sh
    _rect.material = _mat
    add_child(_rect)
    _rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    enabled = SaveGame.is_fx()
    SaveGame.fx_changed.connect(func(v: bool) -> void: enabled = v)


func _process(delta: float) -> void:
    if not enabled:
        return
    _t += delta
    _mat.set_shader_parameter("t", _t)
