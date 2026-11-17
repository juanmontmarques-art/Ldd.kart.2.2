class_name WonderlandMaterials
extends RefCounted

# Materiais procedurais da Wonderland (shaders GL Compatibility): rocha PBR com normal/roughness gerados por ruído
# triplanar, asfalto de pedra com faixas e luzes de borda, água, lava, nuvens, cristais e cachoeira.

const NOISE_LIB := """
float h31(vec3 p){ p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419)); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x){
    vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h31(i), h31(i + vec3(1,0,0)), f.x), mix(h31(i + vec3(0,1,0)), h31(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(h31(i + vec3(0,0,1)), h31(i + vec3(1,0,1)), f.x), mix(h31(i + vec3(0,1,1)), h31(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm3(vec3 p){ float a = 0.5; float s = 0.0; for (int k = 0; k < 4; k++){ s += a * vn(p); p = p * 2.03 + 11.7; a *= 0.5; } return s; }
"""

const ROCK := "shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint_a : source_color = vec3(0.30, 0.27, 0.25);
uniform vec3 tint_b : source_color = vec3(0.55, 0.50, 0.45);
uniform float scale = 0.11;
uniform float bump = 0.9;
uniform float rough = 0.92;
uniform float wet = 0.0;
uniform float vcol_mix = 0.55;
varying vec3 wp; varying vec3 wn;
" + NOISE_LIB + "
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
float hgt(vec3 p){ return fbm3(p * scale) * 0.75 + fbm3(p * scale * 5.3) * 0.25; }
void fragment(){
    float h = hgt(wp);
    float e = 0.12;
    vec3 g = vec3(hgt(wp + vec3(e,0,0)) - h, hgt(wp + vec3(0,e,0)) - h, hgt(wp + vec3(0,0,e)) - h) / e;
    vec3 nw = normalize(wn - g * bump * 0.35);
    NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
    float strat = 0.5 + 0.5 * sin(wp.y * 0.9 + fbm3(wp * 0.05) * 6.0);
    vec3 base = mix(tint_a, tint_b, clamp(h * 1.3 + strat * 0.25 - 0.2, 0.0, 1.0));
    ALBEDO = mix(base, COLOR.rgb * (0.55 + 0.8 * h), vcol_mix);
    ROUGHNESS = clamp(rough - wet * (0.6 * h) - 0.15 * (1.0 - h), 0.15, 1.0);
    SPECULAR = 0.3 + wet * 0.4;
}
"

const ROAD := "shader_type spatial;
uniform vec3 tint : source_color = vec3(0.26, 0.26, 0.30);
uniform vec3 stripe : source_color = vec3(0.95, 0.85, 0.30);
uniform vec3 edge_glow : source_color = vec3(0.1, 0.8, 1.0);
uniform float edge_energy = 1.4;
uniform float rough = 0.62;
uniform float tile = 6.0;
uniform float wet = 0.0;
uniform float ice = 0.0;
uniform float half_width = 8.0;
varying vec3 wp;
" + NOISE_LIB + "
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
    // UV.x = lateral em metros (-half..half), UV.y = distância ao longo da pista (m)
    float lat = UV.x;
    float along = UV.y;
    float h = fbm3(vec3(lat * 0.9, along * 0.9, 0.0));
    float h2 = vn(vec3(lat * 6.0, along * 6.0, 1.7));
    vec3 col = tint * (0.8 + 0.5 * h) * (0.9 + 0.2 * h2);
    // juntas das lajes de pedra
    vec2 cell = vec2(lat / (half_width * 0.5), along / tile);
    vec2 fc = fract(cell + vec2(0.0, 0.5 * floor(cell.x)));
    float joint = smoothstep(0.0, 0.03, fc.y) * smoothstep(0.0, 0.03, 1.0 - fc.y);
    float vjoint = smoothstep(0.0, 0.03, fract(cell.x)) * smoothstep(0.0, 0.03, 1.0 - fract(cell.x));
    col *= mix(0.55, 1.0, joint * vjoint);
    // faixa central tracejada e linhas de borda
    float dash = step(0.5, fract(along / 8.0));
    float center = (1.0 - smoothstep(0.12, 0.2, abs(lat))) * dash;
    float side = 1.0 - smoothstep(0.1, 0.22, abs(abs(lat) - (half_width - 1.15)));
    col = mix(col, stripe, clamp(center * 0.85 + side * 0.7, 0.0, 1.0));
    col = mix(col, vec3(0.55, 0.8, 0.95), ice);
    ALBEDO = col;
    ROUGHNESS = mix(rough - wet * 0.35 * h, 0.08, ice);
    METALLIC = ice * 0.2;
    SPECULAR = 0.4 + ice * 0.5;
    float rim = smoothstep(half_width - 0.75, half_width - 0.35, abs(lat));
    float pulse = 0.75 + 0.25 * sin(TIME * 2.0 - along * 0.25);
    EMISSION = edge_glow * rim * edge_energy * pulse;
    vec3 nn = vec3(fbm3(wp * 1.7) - 0.5, 0.0, fbm3(wp * 1.7 + 5.0) - 0.5) * 0.25;
    NORMAL = normalize(NORMAL + nn);
}
"

const WATER := "shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.02, 0.18, 0.28);
uniform vec3 shallow : source_color = vec3(0.1, 0.55, 0.6);
uniform vec3 glow : source_color = vec3(0.0, 0.9, 0.8);
uniform float glow_energy = 0.35;
uniform float flow = 0.35;
uniform vec2 dir = vec2(0.0, 1.0);
uniform float alpha = 0.82;
varying vec3 wp;
" + NOISE_LIB + "
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
    vec3 q = vec3(wp.x * 0.35 + dir.x * TIME * flow * 3.0, TIME * 0.25, wp.z * 0.35 + dir.y * TIME * flow * 3.0);
    float h = fbm3(q);
    float e = 0.08;
    vec3 n = normalize(vec3(fbm3(q + vec3(e,0,0)) - h, 0.12, fbm3(q + vec3(0,0,e)) - h));
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
    vec3 c = mix(deep, shallow, h);
    ALBEDO = c;
    ROUGHNESS = 0.06;
    METALLIC = 0.1;
    SPECULAR = 0.9;
    EMISSION = glow * glow_energy * (0.4 + h) + shallow * fres * 0.4;
    ALPHA = clamp(alpha + fres * 0.15, 0.0, 1.0);
}
"

const LAVA := "shader_type spatial;
render_mode cull_disabled;
uniform float speed = 0.12;
uniform vec2 dir = vec2(0.0, 1.0);
uniform float energy = 2.4;
varying vec3 wp;
" + NOISE_LIB + "
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
    vec3 q = vec3(wp.x * 0.07 + dir.x * TIME * speed, TIME * 0.05, wp.z * 0.07 + dir.y * TIME * speed);
    float a = fbm3(q);
    float b = fbm3(q * 2.7 + a * 2.0);
    float crust = smoothstep(0.42, 0.62, b);
    vec3 hot = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.85, 0.2), smoothstep(0.2, 0.0, b));
    vec3 dark = vec3(0.07, 0.03, 0.03);
    ALBEDO = mix(hot * 0.4, dark, crust);
    EMISSION = mix(hot * energy, vec3(0.25, 0.04, 0.0), crust);
    ROUGHNESS = 0.8;
}
"

const CLOUD := "shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
uniform vec3 col_a : source_color = vec3(1.0, 0.96, 0.92);
uniform vec3 col_b : source_color = vec3(0.62, 0.72, 0.9);
uniform float density = 1.0;
uniform float fade_dist = 900.0;
varying vec3 wp;
" + NOISE_LIB + "
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
    vec3 q = vec3(wp.x * 0.0035 + TIME * 0.01, wp.y * 0.01, wp.z * 0.0035);
    float n = fbm3(q) * 1.3 + 0.35 * fbm3(q * 5.0);
    float d = smoothstep(0.38, 0.8, n) * density;
    float dist = length(wp - CAMERA_POSITION_WORLD);
    ALBEDO = mix(col_b, col_a, smoothstep(0.4, 0.9, n));
    ALPHA = d * (1.0 - smoothstep(fade_dist * 0.7, fade_dist, dist)) * smoothstep(8.0, 60.0, abs(CAMERA_POSITION_WORLD.y - wp.y));
}
"

const CRYSTAL := "shader_type spatial;
render_mode cull_back;
uniform float energy = 1.8;
uniform float pulse_speed = 1.4;
varying vec3 wp;
" + NOISE_LIB + "
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
    float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
    float p = 0.75 + 0.25 * sin(TIME * pulse_speed + wp.x * 0.3 + wp.z * 0.2);
    float facets = 0.6 + 0.4 * vn(wp * 1.3);
    ALBEDO = COLOR.rgb * 0.55;
    ROUGHNESS = 0.08;
    METALLIC = 0.3;
    SPECULAR = 0.9;
    EMISSION = COLOR.rgb * energy * p * facets * (0.55 + fres);
}
"

const FALLS := "shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec3 col : source_color = vec3(0.6, 0.9, 1.0);
uniform float speed = 1.6;
varying vec3 wp;
" + NOISE_LIB + "
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
    float s = fbm3(vec3(wp.x * 0.9 + wp.z * 0.7, wp.y * 0.12 + TIME * speed, wp.z * 0.9));
    float streak = smoothstep(0.35, 0.8, s);
    float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
    ALBEDO = col * (0.35 + streak * 0.9);
    ALPHA = (0.25 + 0.6 * streak) * edge;
}
"

const STEAM := "shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec3 col : source_color = vec3(1.0, 0.85, 0.7);
uniform float amount = 0.0;
varying vec3 wp;
" + NOISE_LIB + "
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
    float s = fbm3(vec3(wp.x * 0.6, wp.y * 0.25 - TIME * 3.0, wp.z * 0.6));
    ALBEDO = col;
    ALPHA = smoothstep(0.3, 0.8, s) * amount * (1.0 - UV.y);
}
"

const BOOST := "shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;
uniform vec3 col : source_color = vec3(0.1, 0.8, 1.0);
uniform float active_amt = 1.0;
void fragment(){
    float along = UV.y;
    float lat = UV.x / 8.0;
    float chev = abs(lat) * 1.4 - along * 0.18 + TIME * 2.2;
    float band = smoothstep(0.35, 0.5, fract(chev)) * (1.0 - smoothstep(0.5, 0.75, fract(chev)));
    float edge = 1.0 - smoothstep(0.8, 1.0, abs(lat));
    ALBEDO = col * (0.5 + band * 1.5);
    ALPHA = (0.28 + band * 0.7) * edge * active_amt;
}
"

static var _cache: Dictionary = {}


static func _sm(code: String) -> ShaderMaterial:
    var key := code.hash()
    var sh: Shader
    if _cache.has(key):
        sh = _cache[key]
    else:
        sh = Shader.new()
        sh.code = code
        _cache[key] = sh
    var m := ShaderMaterial.new()
    m.shader = sh
    return m


static func rock(tint_a: Color = Color(0.30, 0.27, 0.25), tint_b: Color = Color(0.55, 0.50, 0.45), scale: float = 0.11, wet: float = 0.0, vmix: float = 0.55) -> ShaderMaterial:
    var m := _sm(ROCK)
    m.set_shader_parameter("tint_a", Vector3(tint_a.r, tint_a.g, tint_a.b))
    m.set_shader_parameter("tint_b", Vector3(tint_b.r, tint_b.g, tint_b.b))
    m.set_shader_parameter("scale", scale)
    m.set_shader_parameter("wet", wet)
    m.set_shader_parameter("vcol_mix", vmix)
    return m


static func road(tint: Color, edge: Color, half_width: float = 8.0, wet: float = 0.0, ice: float = 0.0) -> ShaderMaterial:
    var m := _sm(ROAD)
    m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
    m.set_shader_parameter("edge_glow", Vector3(edge.r, edge.g, edge.b))
    m.set_shader_parameter("half_width", half_width)
    m.set_shader_parameter("wet", wet)
    m.set_shader_parameter("ice", ice)
    return m


static func water(deep: Color = Color(0.02, 0.18, 0.28), shallow: Color = Color(0.1, 0.55, 0.6), glow: Color = Color(0.0, 0.9, 0.8), glow_energy: float = 0.35, flow: float = 0.35, dir: Vector2 = Vector2(0, 1)) -> ShaderMaterial:
    var m := _sm(WATER)
    m.set_shader_parameter("deep", Vector3(deep.r, deep.g, deep.b))
    m.set_shader_parameter("shallow", Vector3(shallow.r, shallow.g, shallow.b))
    m.set_shader_parameter("glow", Vector3(glow.r, glow.g, glow.b))
    m.set_shader_parameter("glow_energy", glow_energy)
    m.set_shader_parameter("flow", flow)
    m.set_shader_parameter("dir", dir)
    return m


static func lava(dir: Vector2 = Vector2(0, 1), energy: float = 2.4) -> ShaderMaterial:
    var m := _sm(LAVA)
    m.set_shader_parameter("dir", dir)
    m.set_shader_parameter("energy", energy)
    return m


static func cloud(a: Color = Color(1.0, 0.96, 0.92), b: Color = Color(0.62, 0.72, 0.9)) -> ShaderMaterial:
    var m := _sm(CLOUD)
    m.set_shader_parameter("col_a", Vector3(a.r, a.g, a.b))
    m.set_shader_parameter("col_b", Vector3(b.r, b.g, b.b))
    return m


static func crystal(energy: float = 1.8) -> ShaderMaterial:
    var m := _sm(CRYSTAL)
    m.set_shader_parameter("energy", energy)
    return m


static func falls(col: Color = Color(0.6, 0.9, 1.0)) -> ShaderMaterial:
    var m := _sm(FALLS)
    m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
    return m


static func steam(col: Color = Color(1.0, 0.85, 0.7)) -> ShaderMaterial:
    var m := _sm(STEAM)
    m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
    return m


# Material simples emissivo (luzes de borda, placas, marcações).
static func glow(col: Color, energy: float = 2.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.emission_enabled = true
    m.emission = col
    m.emission_energy_multiplier = energy
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


static func boost_strip(col: Color = Color(0.1, 0.85, 1.0)) -> ShaderMaterial:
    var m := _sm(BOOST)
    m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
    return m
