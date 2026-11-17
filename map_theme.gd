class_name MapTheme
extends RefCounted

# Aparência e "personalidade" de cada mapa: céu, luz, névoa, cores do terreno, da pista,
# das barreiras, água/lava, clima e física (ex.: gelo escorrega).
# O WorldBuilder lê estes valores; o ThemeDecor usa "style" para montar o cenário de cada tema.

var id := "aventura"
var style := "grass"          # grass | desert | ice | lava | lagoon | alpine | jungle

# Céu, luz e névoa
var sky_top := Color(0.20, 0.50, 0.95)
var sky_horizon := Color(0.74, 0.88, 1.0)
var ground_horizon := Color(0.74, 0.88, 1.0)
var ground_bottom := Color(0.55, 0.72, 0.60)
var sun_color := Color(1.0, 0.95, 0.84)
var sun_energy := 1.15
var sun_rotation := Vector3(-52.0, -35.0, 0.0)
var ambient_color := Color(0.80, 0.88, 1.0)
var ambient_energy := 0.8
var fog_color := Color(0.75, 0.88, 1.0)
var fog_density := 0.0007
var saturation := 1.22
var contrast := 1.04
var exposure := 1.0

# Terreno
var ground_a := Color(0.34, 0.74, 0.24)
var ground_b := Color(0.55, 0.88, 0.30)
var shore_color := Color(0.94, 0.85, 0.52)
var rock_color := Color(0.60, 0.57, 0.55)
var peak_color := Color(0.96, 0.98, 1.0)
var peak_from := 44.0
var peak_to := 54.0
var canyon_a := Color(0.90, 0.58, 0.32)
var canyon_b := Color(0.74, 0.40, 0.24)
var gap_color := Color(0.30, 0.22, 0.26)
var trim_color := Color(0.60, 0.90, 0.36)    # beira da pista
var stripe_amount := 0.16
var hill_amp := 13.0
var hill_base := 4.0
var edge_height := 38.0
var edge_ridge := 30.0
var dunes := false
var tree_count := 1500
var border_step := 4          # a cada N amostras há árvores/enfeites na margem da pista

# Pista e proteções
var asphalt_a := Color(0.24, 0.26, 0.31)
var asphalt_b := Color(0.27, 0.29, 0.34)
var line_color := Color(0.95, 0.95, 0.92)
var curb_a := Color(0.92, 0.18, 0.14)
var curb_b := Color(0.98, 0.98, 0.96)
var barrier_a := Color(0.92, 0.18, 0.14)
var barrier_b := Color(0.98, 0.98, 0.96)
var sign_color := Color(1.0, 0.82, 0.12)
var barrel_a := Color(0.95, 0.45, 0.10)
var barrel_b := Color(0.97, 0.97, 0.95)
var mover_a := Color(0.92, 0.18, 0.14)
var mover_b := Color(0.98, 0.98, 0.95)

# Água / gelo / lava
var water_color := Color(0.22, 0.70, 0.98, 0.78)
var water_roughness := 0.12
var water_opaque := false
var water_emission := Color(0, 0, 0)
var water_emission_energy := 0.0

# Nuvens / fumaça
var cloud_color := Color(1, 1, 1)
var cloud_count := 16

# Física e clima
var grip_mult := 1.0
var weather := ""             # "" | snow | embers


static func get_theme(map_id: String) -> MapTheme:
    var t := MapTheme.new()
    t.id = map_id
    match map_id:
        "deserto":
            _desert(t)
        "gelo":
            _ice(t)
        "vulcao":
            _lava(t)
        "lagoa":
            _lagoon(t)
        "cume":
            _alpine(t)
        "selva":
            _jungle(t)
        "wonderland":
            _wonderland(t)
            return t      # Wonderland tem direção de arte própria: não passa pelo filtro Webcore
    _webcore(t)
    return t


# WONDERLAND: fantasia sombria, crepúsculo cinematográfico, rochas frias, cristais e lava.
static func _wonderland(t: MapTheme) -> void:
    t.style = "wonderland"
    t.sky_top = Color(0.10, 0.12, 0.30)
    t.sky_horizon = Color(0.96, 0.58, 0.46)
    t.ground_horizon = Color(0.42, 0.30, 0.46)
    t.ground_bottom = Color(0.10, 0.08, 0.16)
    t.sun_color = Color(1.0, 0.72, 0.52)
    t.sun_energy = 1.55
    t.sun_rotation = Vector3(-24.0, -58.0, 0.0)
    t.ambient_color = Color(0.46, 0.50, 0.78)
    t.ambient_energy = 0.9
    t.fog_color = Color(0.52, 0.42, 0.62)
    t.fog_density = 0.0011
    t.saturation = 1.12
    t.contrast = 1.08
    t.exposure = 0.95
    t.ground_a = Color(0.20, 0.32, 0.26)
    t.ground_b = Color(0.30, 0.42, 0.30)
    t.rock_color = Color(0.36, 0.33, 0.38)
    t.gap_color = Color(0.05, 0.04, 0.09)
    t.trim_color = Color(0.55, 0.40, 0.90)
    t.asphalt_a = Color(0.20, 0.20, 0.25)
    t.asphalt_b = Color(0.23, 0.23, 0.29)
    t.line_color = Color(0.85, 0.82, 1.0)
    t.curb_a = Color(0.60, 0.32, 1.0)
    t.curb_b = Color(0.95, 0.90, 1.0)
    t.sign_color = Color(1.0, 0.80, 0.30)
    t.water_color = Color(0.06, 0.34, 0.48, 0.82)
    t.cloud_color = Color(0.95, 0.80, 0.82)
    t.cloud_count = 0
    t.tree_count = 0
    t.border_step = 9999


# Visual webcore para todos os mapas: tira a saturação, tinge de névoa lilás e deixa a tela mais calma.
# (Aplicado em todas as cores do tema de uma vez, então os valores de cada mapa abaixo continuam editáveis.)
static func _webcore(t: MapTheme) -> void:
    var lava := t.style == "lava"
    for p in t.get_property_list():
        if int(p["type"]) != TYPE_COLOR or (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
            continue
        var nm: String = p["name"]
        var c: Color = t.get(nm)
        var sat := Webcore.SAT
        var tint := 0.10
        if nm.begins_with("sky_") or nm.begins_with("ground_horizon") or nm.begins_with("fog"):
            sat = 0.52
            tint = 0.20
        elif nm.begins_with("water_emission"):
            sat = 0.80 if lava else 0.55
            tint = 0.0
        elif nm == "gap_color" or nm == "water_color":
            sat = 0.78 if lava else Webcore.SAT
            tint = 0.04 if lava else 0.10
        elif lava:
            sat = 0.72
            tint = 0.06
        var out := Webcore.soften(c, sat, tint)
        # Chão e beira da pista mais escuros: evita o "branco estourado" e dá contraste com o céu.
        if nm == "ground_a" or nm == "ground_b" or nm == "trim_color" or nm == "shore_color":
            out = out.darkened(0.20 if t.style == "ice" else 0.30)
        t.set(nm, out)
    t.saturation = Webcore.ENV_SATURATION
    t.exposure = minf(t.exposure, 1.0) * 0.84
    t.contrast = minf(t.contrast, 1.03)
    t.sun_energy *= 0.94
    t.ambient_energy = maxf(t.ambient_energy, 0.82)   # sombras mais suaves = visão confortável


static func _desert(t: MapTheme) -> void:
    t.style = "desert"
    t.sky_top = Color(0.26, 0.54, 0.92)
    t.sky_horizon = Color(0.99, 0.88, 0.68)
    t.ground_horizon = Color(0.98, 0.85, 0.62)
    t.ground_bottom = Color(0.80, 0.62, 0.40)
    t.sun_color = Color(1.0, 0.92, 0.76)
    t.sun_energy = 1.35
    t.sun_rotation = Vector3(-46.0, -30.0, 0.0)
    t.ambient_color = Color(1.0, 0.92, 0.80)
    t.ambient_energy = 0.85
    t.fog_color = Color(0.96, 0.84, 0.64)
    t.fog_density = 0.0009
    t.saturation = 1.15
    t.contrast = 1.06
    t.ground_a = Color(0.90, 0.72, 0.42)
    t.ground_b = Color(0.98, 0.84, 0.54)
    t.shore_color = Color(0.46, 0.72, 0.30)
    t.rock_color = Color(0.68, 0.42, 0.28)
    t.peak_from = 9999.0
    t.peak_to = 10000.0
    t.canyon_a = Color(0.90, 0.52, 0.28)
    t.canyon_b = Color(0.62, 0.30, 0.20)
    t.gap_color = Color(0.34, 0.20, 0.14)
    t.trim_color = Color(0.95, 0.82, 0.52)
    t.stripe_amount = 0.10
    t.hill_amp = 8.0
    t.hill_base = 5.0
    t.edge_height = 30.0
    t.edge_ridge = 26.0
    t.dunes = true
    t.tree_count = 700
    t.border_step = 10
    t.asphalt_a = Color(0.37, 0.34, 0.33)
    t.asphalt_b = Color(0.40, 0.37, 0.36)
    t.line_color = Color(0.97, 0.93, 0.80)
    t.curb_a = Color(0.82, 0.28, 0.12)
    t.curb_b = Color(0.97, 0.90, 0.70)
    t.barrier_a = Color(0.80, 0.24, 0.12)
    t.barrier_b = Color(0.96, 0.88, 0.66)
    t.sign_color = Color(1.0, 0.72, 0.10)
    t.barrel_a = Color(0.72, 0.46, 0.22)
    t.barrel_b = Color(0.96, 0.86, 0.60)
    t.mover_a = Color(0.15, 0.62, 0.62)
    t.mover_b = Color(0.97, 0.80, 0.28)
    t.water_color = Color(0.12, 0.76, 0.82, 0.86)
    t.cloud_color = Color(1.0, 0.97, 0.92)
    t.cloud_count = 7


static func _ice(t: MapTheme) -> void:
    t.style = "ice"
    t.sky_top = Color(0.05, 0.10, 0.36)
    t.sky_horizon = Color(0.82, 0.84, 1.0)
    t.ground_horizon = Color(0.85, 0.90, 1.0)
    t.ground_bottom = Color(0.70, 0.80, 0.95)
    t.sun_color = Color(1.0, 0.84, 0.80)
    t.sun_energy = 1.05
    t.sun_rotation = Vector3(-20.0, -40.0, 0.0)
    t.ambient_color = Color(0.70, 0.80, 1.0)
    t.ambient_energy = 0.95
    t.fog_color = Color(0.78, 0.86, 0.98)
    t.fog_density = 0.0013
    t.saturation = 1.10
    t.contrast = 1.05
    t.exposure = 1.05
    t.ground_a = Color(0.90, 0.94, 1.0)
    t.ground_b = Color(0.78, 0.87, 0.98)
    t.shore_color = Color(0.72, 0.86, 0.96)
    t.rock_color = Color(0.40, 0.48, 0.60)
    t.peak_color = Color(1.0, 1.0, 1.0)
    t.peak_from = 30.0
    t.peak_to = 50.0
    t.canyon_a = Color(0.56, 0.80, 0.96)
    t.canyon_b = Color(0.34, 0.58, 0.86)
    t.gap_color = Color(0.05, 0.12, 0.32)
    t.trim_color = Color(0.82, 0.92, 1.0)
    t.stripe_amount = 0.05
    t.hill_amp = 12.0
    t.hill_base = 4.0
    t.edge_height = 46.0
    t.edge_ridge = 36.0
    t.tree_count = 1100
    t.border_step = 5
    t.asphalt_a = Color(0.50, 0.58, 0.70)
    t.asphalt_b = Color(0.54, 0.62, 0.74)
    t.line_color = Color(1.0, 1.0, 1.0)
    t.curb_a = Color(0.20, 0.55, 0.95)
    t.curb_b = Color(0.96, 0.98, 1.0)
    t.barrier_a = Color(0.50, 0.82, 1.0)
    t.barrier_b = Color(0.95, 0.98, 1.0)
    t.sign_color = Color(0.20, 0.70, 1.0)
    t.barrel_a = Color(0.62, 0.86, 1.0)
    t.barrel_b = Color(0.95, 0.98, 1.0)
    t.mover_a = Color(0.20, 0.55, 0.95)
    t.mover_b = Color(0.97, 0.98, 1.0)
    t.water_color = Color(0.68, 0.88, 0.98, 1.0)
    t.water_roughness = 0.05
    t.water_opaque = true
    t.cloud_color = Color(0.95, 0.95, 1.0)
    t.cloud_count = 10
    t.grip_mult = 0.62
    t.weather = "snow"


static func _lava(t: MapTheme) -> void:
    t.style = "lava"
    t.sky_top = Color(0.09, 0.03, 0.07)
    t.sky_horizon = Color(0.98, 0.38, 0.10)
    t.ground_horizon = Color(0.75, 0.22, 0.08)
    t.ground_bottom = Color(0.15, 0.05, 0.04)
    t.sun_color = Color(1.0, 0.45, 0.18)
    t.sun_energy = 1.2
    t.sun_rotation = Vector3(-24.0, -30.0, 0.0)
    t.ambient_color = Color(0.95, 0.50, 0.36)
    t.ambient_energy = 0.85
    t.fog_color = Color(0.50, 0.16, 0.08)
    t.fog_density = 0.0016
    t.saturation = 1.25
    t.contrast = 1.10
    t.exposure = 0.95
    t.ground_a = Color(0.20, 0.15, 0.15)
    t.ground_b = Color(0.30, 0.21, 0.18)
    t.shore_color = Color(0.10, 0.08, 0.09)
    t.rock_color = Color(0.34, 0.22, 0.20)
    t.peak_color = Color(0.46, 0.43, 0.43)
    t.peak_from = 52.0
    t.peak_to = 90.0
    t.canyon_a = Color(0.52, 0.20, 0.12)
    t.canyon_b = Color(0.28, 0.12, 0.10)
    t.gap_color = Color(1.0, 0.38, 0.05)
    t.trim_color = Color(0.30, 0.20, 0.18)
    t.stripe_amount = 0.0
    t.hill_amp = 15.0
    t.hill_base = 6.0
    t.edge_height = 50.0
    t.edge_ridge = 40.0
    t.tree_count = 450
    t.border_step = 9
    t.asphalt_a = Color(0.17, 0.17, 0.20)
    t.asphalt_b = Color(0.20, 0.20, 0.23)
    t.line_color = Color(1.0, 0.86, 0.42)
    t.curb_a = Color(0.96, 0.36, 0.08)
    t.curb_b = Color(0.12, 0.12, 0.14)
    t.barrier_a = Color(0.92, 0.32, 0.06)
    t.barrier_b = Color(0.14, 0.13, 0.15)
    t.sign_color = Color(1.0, 0.50, 0.05)
    t.barrel_a = Color(0.16, 0.14, 0.17)
    t.barrel_b = Color(1.0, 0.46, 0.06)
    t.mover_a = Color(0.20, 0.20, 0.24)
    t.mover_b = Color(1.0, 0.42, 0.06)
    t.water_color = Color(1.0, 0.42, 0.05, 1.0)
    t.water_roughness = 0.3
    t.water_opaque = true
    t.water_emission = Color(1.0, 0.34, 0.02)
    t.water_emission_energy = 2.4
    t.cloud_color = Color(0.30, 0.20, 0.20)
    t.cloud_count = 14
    t.weather = "embers"


static func _lagoon(t: MapTheme) -> void:
    t.style = "lagoon"
    t.sky_top = Color(0.12, 0.52, 0.98)
    t.sky_horizon = Color(0.80, 0.96, 1.0)
    t.ground_horizon = Color(0.78, 0.95, 0.98)
    t.ground_bottom = Color(0.30, 0.62, 0.62)
    t.sun_energy = 1.25
    t.fog_color = Color(0.74, 0.93, 0.98)
    t.fog_density = 0.0006
    t.ground_a = Color(0.20, 0.70, 0.34)
    t.ground_b = Color(0.42, 0.86, 0.38)
    t.shore_color = Color(0.96, 0.90, 0.64)
    t.rock_color = Color(0.58, 0.56, 0.52)
    t.peak_from = 9999.0
    t.peak_to = 10000.0
    t.canyon_a = Color(0.82, 0.62, 0.38)
    t.canyon_b = Color(0.58, 0.40, 0.26)
    t.gap_color = Color(0.06, 0.30, 0.38)
    t.trim_color = Color(0.70, 0.95, 0.50)
    t.hill_amp = 11.0
    t.edge_height = 34.0
    t.edge_ridge = 28.0
    t.tree_count = 1300
    t.border_step = 5
    t.asphalt_a = Color(0.30, 0.33, 0.38)
    t.asphalt_b = Color(0.33, 0.36, 0.41)
    t.curb_a = Color(0.05, 0.72, 0.78)
    t.curb_b = Color(0.98, 0.98, 0.96)
    t.barrier_a = Color(0.05, 0.72, 0.78)
    t.barrier_b = Color(0.98, 0.98, 0.96)
    t.sign_color = Color(1.0, 0.62, 0.12)
    t.water_color = Color(0.08, 0.78, 0.76, 0.80)
    t.water_roughness = 0.08
    t.cloud_count = 14


static func _alpine(t: MapTheme) -> void:
    t.style = "alpine"
    t.sky_top = Color(0.10, 0.34, 0.80)
    t.sky_horizon = Color(0.86, 0.92, 1.0)
    t.ground_horizon = Color(0.86, 0.92, 1.0)
    t.ground_bottom = Color(0.55, 0.62, 0.72)
    t.sun_color = Color(1.0, 0.96, 0.90)
    t.sun_energy = 1.3
    t.sun_rotation = Vector3(-36.0, -50.0, 0.0)
    t.ambient_color = Color(0.78, 0.86, 1.0)
    t.fog_color = Color(0.82, 0.89, 0.98)
    t.fog_density = 0.0011
    t.ground_a = Color(0.42, 0.56, 0.36)
    t.ground_b = Color(0.56, 0.66, 0.42)
    t.shore_color = Color(0.70, 0.74, 0.70)
    t.rock_color = Color(0.50, 0.50, 0.54)
    t.peak_color = Color(0.97, 0.98, 1.0)
    t.peak_from = 70.0
    t.peak_to = 100.0
    t.canyon_a = Color(0.62, 0.60, 0.62)
    t.canyon_b = Color(0.40, 0.40, 0.46)
    t.gap_color = Color(0.20, 0.24, 0.34)
    t.trim_color = Color(0.74, 0.78, 0.70)
    t.hill_amp = 16.0
    t.hill_base = 6.0
    t.edge_height = 60.0
    t.edge_ridge = 50.0
    t.tree_count = 700
    t.border_step = 8
    t.asphalt_a = Color(0.26, 0.27, 0.31)
    t.asphalt_b = Color(0.29, 0.30, 0.34)
    t.curb_a = Color(0.95, 0.55, 0.10)
    t.curb_b = Color(0.97, 0.97, 0.97)
    t.barrier_a = Color(0.95, 0.55, 0.10)
    t.barrier_b = Color(0.97, 0.97, 0.97)
    t.water_color = Color(0.30, 0.62, 0.86, 0.85)
    t.cloud_color = Color(1.0, 1.0, 1.0)
    t.cloud_count = 26


static func _jungle(t: MapTheme) -> void:
    t.style = "jungle"
    t.sky_top = Color(0.14, 0.46, 0.72)
    t.sky_horizon = Color(0.78, 0.92, 0.80)
    t.ground_horizon = Color(0.62, 0.80, 0.62)
    t.ground_bottom = Color(0.12, 0.30, 0.18)
    t.sun_color = Color(1.0, 0.96, 0.78)
    t.sun_energy = 1.1
    t.ambient_color = Color(0.70, 0.90, 0.78)
    t.ambient_energy = 0.9
    t.fog_color = Color(0.58, 0.78, 0.64)
    t.fog_density = 0.0017
    t.saturation = 1.30
    t.ground_a = Color(0.10, 0.50, 0.18)
    t.ground_b = Color(0.20, 0.64, 0.22)
    t.shore_color = Color(0.40, 0.34, 0.20)
    t.rock_color = Color(0.40, 0.38, 0.32)
    t.peak_from = 9999.0
    t.peak_to = 10000.0
    t.canyon_a = Color(0.50, 0.36, 0.22)
    t.canyon_b = Color(0.30, 0.22, 0.14)
    t.gap_color = Color(0.04, 0.16, 0.12)
    t.trim_color = Color(0.30, 0.70, 0.30)
    t.hill_amp = 14.0
    t.edge_height = 44.0
    t.edge_ridge = 36.0
    t.tree_count = 2000
    t.border_step = 3
    t.asphalt_a = Color(0.34, 0.28, 0.22)
    t.asphalt_b = Color(0.38, 0.31, 0.25)
    t.line_color = Color(0.96, 0.92, 0.70)
    t.curb_a = Color(0.90, 0.72, 0.14)
    t.curb_b = Color(0.20, 0.14, 0.08)
    t.barrier_a = Color(0.62, 0.40, 0.18)
    t.barrier_b = Color(0.86, 0.70, 0.40)
    t.sign_color = Color(1.0, 0.80, 0.10)
    t.water_color = Color(0.10, 0.56, 0.50, 0.86)
    t.cloud_color = Color(0.92, 0.98, 0.92)
    t.cloud_count = 12
