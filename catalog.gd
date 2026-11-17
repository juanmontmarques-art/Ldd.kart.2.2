class_name Catalog
extends RefCounted

# Dados fixos do jogo: personagens (pilotos), karts e regras de desbloqueio.
# Para criar um novo personagem/kart basta acrescentar uma linha nas listas.
#
# TUDO LIBERADO: todos os itens usam {"type": "free"} (sem moedas/vitórias para destravar).
# "req" (como desbloquear):
#   {"type": "free"}              já vem liberado
#   {"type": "coins", "price": N} comprado com moedas na garagem
#   {"type": "wins", "n": N}      libera sozinho ao vencer N corridas
#   {"type": "races", "n": N}     libera sozinho ao terminar N corridas
#
# Multiplicadores ("mods"): 1.0 = igual ao kart padrão.
#   speed, accel, steer, grip, nitro_regen, nitro_drain (menor = nitro dura mais), coins

const TRACK_ID := "circuito_aventura"
const TRACK_NAME := "Circuito Aventura"

# Pistas. "req" funciona como nos personagens. "stats": extensão aproximada (km), quedas livres e
# grampos são mostrados na seleção de pista; dificuldade vai de 1 a 5.
const MAPS: Array = [
    {
        "id": "circuito_aventura", "name": "Circuito Aventura", "sub": "Campos, lago e cânions",
        "desc": "A pista clássica: curvas variadas, um lago e alguns saltos para começar.",
        "laps": 2, "difficulty": 2, "km": 3.8, "falls": 3, "color": Color(0.30, 0.78, 0.30),
        "req": {"type": "free"},
    },
    {
        "id": "deserto", "name": "Deserto das Pirâmides", "sub": "Dunas, ruínas e oásis",
        "desc": "Retas enormes cortadas por buracos. Calor, pirâmides e balões no céu.",
        "laps": 2, "difficulty": 3, "km": 5.0, "falls": 8, "color": Color(0.95, 0.75, 0.38),
        "req": {"type": "free"},
    },
    {
        "id": "gelo", "name": "Pico Gelado", "sub": "Gelo escorregadio e aurora",
        "desc": "O chão escorrega! Pontes quebradas e penhascos sem proteção.",
        "laps": 2, "difficulty": 4, "km": 5.4, "falls": 10, "color": Color(0.55, 0.82, 1.0),
        "req": {"type": "free"},
    },
    {
        "id": "vulcao", "name": "Vulcão", "sub": "Lava, brasas e abismos",
        "desc": "O mais longo e perigoso.",
        "laps": 2, "difficulty": 5, "km": 5.8, "falls": 12, "color": Color(1.0, 0.42, 0.10),
        "req": {"type": "free"},
    },
    {
        "id": "lagoa", "name": "Lagoa Esmeralda", "sub": "HARDCORE · serpentina, saltos e pontes",
        "desc": "9 km sem perdão: 6 hairpins em serpentina, rampas de 30%, 5 saltos (3 sobre a água), ponte suspensa, 3 túneis, parafusos e atalho pela caverna.",
        "laps": 1, "difficulty": 5, "km": 9.0, "falls": 5, "color": Color(0.10, 0.80, 0.72),
        "req": {"type": "free"},
    },
    {
        "id": "cume", "name": "Cume das Nuvens", "sub": "HARDCORE · altitude, espiral e penhascos",
        "desc": "8,5 km no topo do mundo: saltos de 40 m, 4 pontes estreitas entre penhascos, descida em espiral, 4 túneis, curvas de parede e parafusos.",
        "laps": 1, "difficulty": 5, "km": 8.4, "falls": 4, "color": Color(0.62, 0.74, 1.0),
        "req": {"type": "free"},
    },
    {
        "id": "selva", "name": "Selva das Cachoeiras", "sub": "HARDCORE · esses sem fim e cachoeiras",
        "desc": "8 km de S encadeados: 9 saltos entre plataformas, 2 cachoeiras, 3 cavernas, parafusos e atalho de curvas fechadas.",
        "laps": 1, "difficulty": 5, "km": 8.1, "falls": 9, "color": Color(0.20, 0.72, 0.30),
        "req": {"type": "free"},
    },
    {
        "id": "wonderland", "name": "Wonderland", "sub": "EXTREMA · 8 setores, queda livre, cavernas e gravidade zero",
        "desc": "13 km verticais: largada no topo da montanha, queda de até 45°, abismos, cavernas com lagos e cristais, labirinto, lava, parafusos de 360° de cabeça para baixo e a subida final.",
        "laps": 1, "difficulty": 5, "km": 13.0, "falls": 14, "color": Color(0.66, 0.40, 1.0),
        "req": {"type": "free"},
    },
]

const CHARACTERS: Array = [
    {
        "id": "rex", "name": "Rex", "title": "O Equilibrado",
        "color": Color(0.15, 0.45, 0.95), "style": "fin",
        "desc": "Sem pontos fracos. Ótimo para aprender a pista.",
        "perk": "Sem bônus",
        "req": {"type": "free"},
        "mods": {},
    },
    {
        "id": "luna", "name": "Luna", "title": "Rainha do Nitro",
        "color": Color(1.0, 0.80, 0.10), "style": "pony",
        "desc": "O tanque de nitro dela enche muito mais rápido.",
        "perk": "Nitro recarrega +45%",
        "req": {"type": "free"},
        "mods": {"nitro_regen": 1.45},
    },
    {
        "id": "tico", "name": "Tico", "title": "Pé de Chumbo",
        "color": Color(0.20, 0.80, 0.35), "style": "ears",
        "desc": "Acelera forte e chega rápido à velocidade máxima.",
        "perk": "Aceleração +10%",
        "req": {"type": "free"},
        "mods": {"accel": 1.10},
    },
    {
        "id": "bia", "name": "Bia", "title": "Mestra das Curvas",
        "color": Color(0.72, 0.30, 0.92), "style": "antenna",
        "desc": "Pneus colados no chão e direção afiada.",
        "perk": "Controle +8% / Aderência +8%",
        "req": {"type": "free"},
        "mods": {"steer": 1.08, "grip": 1.08},
    },
    {
        "id": "zeca", "name": "Zeca", "title": "Caçador de Moedas",
        "color": Color(1.0, 0.45, 0.12), "style": "fin",
        "desc": "Onde ele passa, as moedas aparecem.",
        "perk": "Moedas +25%",
        "req": {"type": "free"},
        "mods": {"coins": 1.25},
    },
    {
        "id": "mel", "name": "Mel", "title": "A Veterana",
        "color": Color(0.95, 0.35, 0.60), "style": "pony",
        "desc": "Experiência vale ouro.",
        "perk": "Velocidade +3% / Nitro dura +15%",
        "req": {"type": "free"},
        "mods": {"speed": 1.03, "nitro_drain": 0.87},
    },
]

const KARTS: Array = [
    {
        "id": "classico", "name": "Clássico", "color": Color(0.90, 0.15, 0.12),
        "desc": "O kart de sempre. Equilibrado em tudo.",
        "req": {"type": "free"},
        "mods": {},
    },
    {
        "id": "foguete", "name": "Foguete", "color": Color(0.15, 0.50, 1.0),
        "desc": "Velocidade final alta, mas demora para acelerar.",
        "req": {"type": "free"},
        "mods": {"speed": 1.06, "accel": 0.94, "steer": 0.96},
    },
    {
        "id": "besouro", "name": "Besouro", "color": Color(0.18, 0.78, 0.38),
        "desc": "Ágil e estável nas curvas, um pouco mais lento nas retas.",
        "req": {"type": "free"},
        "mods": {"speed": 0.97, "steer": 1.10, "grip": 1.12},
    },
    {
        "id": "relampago", "name": "Relâmpago", "color": Color(1.0, 0.85, 0.10),
        "desc": "Arranca como ninguém e recarrega o nitro rápido.",
        "req": {"type": "free"},
        "mods": {"accel": 1.18, "nitro_regen": 1.25},
    },
    {
        "id": "fantasma", "name": "Fantasma", "color": Color(0.62, 0.30, 0.95),
        "desc": "Melhor em tudo, só um pouquinho. Para quem junta moedas.",
        "req": {"type": "free"},
        "mods": {"speed": 1.04, "accel": 1.06, "steer": 1.04, "grip": 1.04},
    },
    {
        "id": "ouro", "name": "Ouro Puro", "color": Color(1.0, 0.72, 0.12),
        "desc": "O kart dos campeões.",
        "req": {"type": "free"},
        "mods": {"speed": 1.07, "accel": 1.10, "steer": 1.05, "grip": 1.05, "nitro_regen": 1.25},
    },
]


static func maps() -> Array:
    return MAPS


static func map(id: String) -> Dictionary:
    for m in MAPS:
        if m["id"] == id:
            return m
    return MAPS[0]


static func has_map(id: String) -> bool:
    for m in MAPS:
        if m["id"] == id:
            return true
    return false


static func free_map_ids() -> Array[String]:
    var out: Array[String] = []
    for m in MAPS:
        var req: Dictionary = m["req"]
        if req["type"] == "free":
            out.append(m["id"])
    return out


static func characters() -> Array:
    return CHARACTERS


static func karts() -> Array:
    return KARTS


static func character(id: String) -> Dictionary:
    for c in CHARACTERS:
        if c["id"] == id:
            return c
    return CHARACTERS[0]


static func kart(id: String) -> Dictionary:
    for k in KARTS:
        if k["id"] == id:
            return k
    return KARTS[0]


static func has_character(id: String) -> bool:
    for c in CHARACTERS:
        if c["id"] == id:
            return true
    return false


static func has_kart(id: String) -> bool:
    for k in KARTS:
        if k["id"] == id:
            return true
    return false


static func free_character_ids() -> Array[String]:
    var out: Array[String] = []
    for c in CHARACTERS:
        var req: Dictionary = c["req"]
        if req["type"] == "free":
            out.append(c["id"])
    return out


static func free_kart_ids() -> Array[String]:
    var out: Array[String] = []
    for k in KARTS:
        var req: Dictionary = k["req"]
        if req["type"] == "free":
            out.append(k["id"])
    return out


# Texto curto explicando como desbloquear.
static func req_text(req: Dictionary) -> String:
    match String(req["type"]):
        "coins":
            return "%d moedas" % int(req["price"])
        "wins":
            return "Vença %d corridas" % int(req["n"])
        "races":
            return "Termine %d corridas" % int(req["n"])
    return "Liberado"


# Multiplicador final (personagem x kart) para uma chave de "mods".
static func mod(char_id: String, kart_id: String, key: String) -> float:
    var cm: Dictionary = character(char_id)["mods"]
    var km: Dictionary = kart(kart_id)["mods"]
    return float(cm.get(key, 1.0)) * float(km.get(key, 1.0))


# Barras de status (0..1) para a interface: velocidade, aceleração, controle, nitro.
static func stat_bars(char_id: String, kart_id: String) -> Array[float]:
    var speed := mod(char_id, kart_id, "speed")
    var accel := mod(char_id, kart_id, "accel")
    var control := (mod(char_id, kart_id, "steer") + mod(char_id, kart_id, "grip")) * 0.5
    var nitro := mod(char_id, kart_id, "nitro_regen") / mod(char_id, kart_id, "nitro_drain")
    var out: Array[float] = []
    for v in [speed, accel, control, nitro]:
        out.append(clampf(remap(float(v), 0.85, 1.35, 0.15, 1.0), 0.1, 1.0))
    return out
