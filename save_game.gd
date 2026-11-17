extends Node

# Sistema de salvamento (autoload "SaveGame").
# Guarda: moedas, personagens/karts desbloqueados, seleção atual, recordes
# (melhor tempo, melhor volta, top 5) e estatísticas. Tudo em JSON em user://.
#
# Segurança dos dados:
#  - escreve primeiro num arquivo temporário e só depois troca pelo definitivo;
#  - mantém uma cópia de segurança (.bak) usada se o arquivo principal corromper;
#  - saves antigos/incompletos são completados com valores padrão (migração);
#  - salva sozinho ao mudar algo (com pequeno atraso para juntar várias mudanças),
#    ao pausar o app (celular) e ao fechar o jogo.

signal coins_changed(total: int)
signal selection_changed
signal unlocked(kind: String, id: String)
signal fx_changed(enabled: bool)

const SAVE_PATH := "user://kartlivre_save.json"
const BACKUP_PATH := "user://kartlivre_save.bak"
const TEMP_PATH := "user://kartlivre_save.tmp"
const VERSION := 1
const TOP_SIZE := 5

# Prêmio em moedas por posição final (1º a 5º).
const PRIZE_BY_RANK: Array[int] = [120, 80, 55, 35, 20]
const BONUS_BEST_TIME := 50
const BONUS_BEST_LAP := 25

var data: Dictionary = {}
var _timer: Timer


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().set_auto_accept_quit(false)
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.wait_time = 1.2
    _timer.timeout.connect(save_game)
    add_child(_timer)
    load_game()
    AudioServer.set_bus_mute(0, bool(data["settings"]["muted"]))


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        save_game()
        if what == NOTIFICATION_WM_CLOSE_REQUEST:
            get_tree().quit()


# ----------------------------------------------------------------- arquivo
func _default_data() -> Dictionary:
    return {
        "version": VERSION,
        "coins": 0,
        "unlocked_chars": Catalog.free_character_ids(),
        "unlocked_karts": Catalog.free_kart_ids(),
        "selected_char": "rex",
        "selected_kart": "classico",
        "unlocked_maps": Catalog.free_map_ids(),
        "selected_map": Catalog.TRACK_ID,
        "stats": {"races": 0, "wins": 0, "podiums": 0, "coins_earned": 0, "coins_picked": 0},
        "records": {},
        "settings": {"muted": false, "fx": true},
    }


func load_game() -> void:
    var loaded: Variant = _read_json(SAVE_PATH)
    if loaded == null:
        loaded = _read_json(BACKUP_PATH)
        if loaded != null:
            push_warning("Save principal ausente/corrompido; usando a cópia de segurança.")
    data = _default_data()
    if loaded is Dictionary:
        _merge(loaded)
    _sanitize()


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return null
    var text := f.get_as_text()
    f.close()
    var parsed: Variant = JSON.parse_string(text)
    if parsed is Dictionary:
        return parsed
    return null


func save_game() -> void:
    if _timer != null:
        _timer.stop()
    var text := JSON.stringify(data, "\t")
    var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if f == null:
        push_warning("Não foi possível salvar o jogo (erro %d)." % FileAccess.get_open_error())
        return
    f.store_string(text)
    f.close()
    var dir := DirAccess.open("user://")
    if dir == null:
        return
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH):
            dir.remove(BACKUP_PATH.get_file())
        dir.copy(SAVE_PATH, BACKUP_PATH)
        dir.remove(SAVE_PATH.get_file())
    dir.rename(TEMP_PATH, SAVE_PATH)


# Pede para salvar logo (junta várias alterações seguidas numa gravação só).
func mark_dirty() -> void:
    if _timer != null and _timer.is_stopped():
        _timer.start()


func _merge(src: Dictionary) -> void:
    if src.has("coins"):
        data["coins"] = int(src["coins"])
    for key in ["unlocked_chars", "unlocked_karts", "unlocked_maps"]:
        if src.has(key) and src[key] is Array:
            var list: Array = data[key]
            for id in src[key]:
                if not list.has(String(id)):
                    list.append(String(id))
    for key in ["selected_char", "selected_kart", "selected_map"]:
        if src.has(key):
            data[key] = String(src[key])
    if src.has("stats") and src["stats"] is Dictionary:
        for k in data["stats"].keys():
            if src["stats"].has(k):
                data["stats"][k] = int(src["stats"][k])
    if src.has("records") and src["records"] is Dictionary:
        data["records"] = src["records"]
    if src.has("settings") and src["settings"] is Dictionary:
        if src["settings"].has("muted"):
            data["settings"]["muted"] = bool(src["settings"]["muted"])
        if src["settings"].has("fx"):
            data["settings"]["fx"] = bool(src["settings"]["fx"])


# Garante valores válidos (ids que existem, números não negativos, seleção liberada).
func _sanitize() -> void:
    data["coins"] = maxi(int(data["coins"]), 0)
    var chars: Array = []
    for id in data["unlocked_chars"]:
        if Catalog.has_character(String(id)) and not chars.has(String(id)):
            chars.append(String(id))
    data["unlocked_chars"] = chars
    var karts: Array = []
    for id in data["unlocked_karts"]:
        if Catalog.has_kart(String(id)) and not karts.has(String(id)):
            karts.append(String(id))
    data["unlocked_karts"] = karts
    var maps: Array = []
    for id in data["unlocked_maps"]:
        if Catalog.has_map(String(id)) and not maps.has(String(id)):
            maps.append(String(id))
    if not maps.has(Catalog.TRACK_ID):
        maps.append(Catalog.TRACK_ID)
    data["unlocked_maps"] = maps
    if not maps.has(data["selected_map"]):
        data["selected_map"] = Catalog.TRACK_ID
    if not chars.has(data["selected_char"]):
        data["selected_char"] = chars[0] if not chars.is_empty() else "rex"
    if not karts.has(data["selected_kart"]):
        data["selected_kart"] = karts[0] if not karts.is_empty() else "classico"
    for k in data["stats"].keys():
        data["stats"][k] = maxi(int(data["stats"][k]), 0)
    var rec: Dictionary = data["records"]
    for track_id in rec.keys():
        var r: Dictionary = rec[track_id]
        r["best_time"] = float(r.get("best_time", 0.0))
        r["best_lap"] = float(r.get("best_lap", 0.0))
        var top: Array = []
        if r.get("top") is Array:
            for e in r["top"]:
                if e is Dictionary and e.has("time"):
                    top.append(e)
        r["top"] = top
        rec[track_id] = r


func reset_all() -> void:
    data = _default_data()
    AudioServer.set_bus_mute(0, false)
    save_game()
    coins_changed.emit(0)
    selection_changed.emit()


# ------------------------------------------------------------------ moedas
func coins() -> int:
    return int(data["coins"])


func add_coins(amount: int, picked_on_track: bool = false) -> void:
    if amount <= 0:
        return
    data["coins"] = coins() + amount
    data["stats"]["coins_earned"] = int(data["stats"]["coins_earned"]) + amount
    if picked_on_track:
        data["stats"]["coins_picked"] = int(data["stats"]["coins_picked"]) + amount
    coins_changed.emit(coins())
    mark_dirty()


func spend_coins(amount: int) -> bool:
    if amount < 0 or coins() < amount:
        return false
    data["coins"] = coins() - amount
    coins_changed.emit(coins())
    mark_dirty()
    return true


# ------------------------------------------------------------ desbloqueios
func is_char_unlocked(id: String) -> bool:
    return (data["unlocked_chars"] as Array).has(id)


func is_kart_unlocked(id: String) -> bool:
    return (data["unlocked_karts"] as Array).has(id)


# Compra com moedas. Retorna true se deu certo.
func buy_character(id: String) -> bool:
    return _buy("unlocked_chars", "character", Catalog.character(id))


func buy_kart(id: String) -> bool:
    return _buy("unlocked_karts", "kart", Catalog.kart(id))


func is_map_unlocked(id: String) -> bool:
    return (data["unlocked_maps"] as Array).has(id)


func buy_map(id: String) -> bool:
    return _buy("unlocked_maps", "map", Catalog.map(id))


func selected_map() -> String:
    return String(data["selected_map"])


func select_map(id: String) -> void:
    if is_map_unlocked(id):
        data["selected_map"] = id
        selection_changed.emit()
        mark_dirty()


# Opção de teste: libera tudo (personagens, karts e pistas).
func unlock_everything() -> void:
    for pair in [["unlocked_chars", Catalog.characters()], ["unlocked_karts", Catalog.karts()], ["unlocked_maps", Catalog.maps()]]:
        var list: Array = data[pair[0]]
        for item in pair[1]:
            if not list.has(item["id"]):
                list.append(item["id"])
    selection_changed.emit()
    save_game()


func _buy(list_key: String, kind: String, item: Dictionary) -> bool:
    var id: String = item["id"]
    var list: Array = data[list_key]
    if list.has(id):
        return true
    var req: Dictionary = item["req"]
    if req["type"] != "coins":
        return false
    if not spend_coins(int(req["price"])):
        return false
    list.append(id)
    unlocked.emit(kind, id)
    save_game()
    return true


# Libera por conquistas (vitórias / corridas). Retorna os nomes liberados agora.
func _check_auto_unlocks() -> Array[String]:
    var names: Array[String] = []
    var st: Dictionary = data["stats"]
    for entry in [["unlocked_chars", "character", Catalog.characters()], ["unlocked_karts", "kart", Catalog.karts()], ["unlocked_maps", "map", Catalog.maps()]]:
        var list: Array = data[entry[0]]
        for item in entry[2]:
            var id: String = item["id"]
            if list.has(id):
                continue
            var req: Dictionary = item["req"]
            var ok := false
            if req["type"] == "wins":
                ok = int(st["wins"]) >= int(req["n"])
            elif req["type"] == "races":
                ok = int(st["races"]) >= int(req["n"])
            if ok:
                list.append(id)
                names.append(String(item["name"]))
                unlocked.emit(String(entry[1]), id)
    return names


# --------------------------------------------------------------- seleção
func selected_char() -> String:
    return String(data["selected_char"])


func selected_kart() -> String:
    return String(data["selected_kart"])


func select_character(id: String) -> void:
    if is_char_unlocked(id):
        data["selected_char"] = id
        selection_changed.emit()
        mark_dirty()


func select_kart(id: String) -> void:
    if is_kart_unlocked(id):
        data["selected_kart"] = id
        selection_changed.emit()
        mark_dirty()


# ----------------------------------------------------------------- recordes
func track_records(track_id: String = "") -> Dictionary:
    if track_id == "":
        track_id = selected_map()
    var rec: Dictionary = data["records"]
    if not rec.has(track_id):
        return {"best_time": 0.0, "best_lap": 0.0, "top": []}
    return rec[track_id]


func stats() -> Dictionary:
    return data["stats"]


# Registra uma corrida terminada.
# result: {time, best_lap, rank, coins_picked, char, kart, track}
# Retorna um resumo para a tela final:
#   {prize, bonus_time, bonus_lap, total, new_time_record, new_lap_record,
#    leaderboard_pos (0 = fora do top), unlocked_names}
func register_race(result: Dictionary) -> Dictionary:
    var track_id: String = String(result.get("track", selected_map()))
    var rank: int = int(result.get("rank", 5))
    var time: float = float(result.get("time", 0.0))
    var best_lap: float = float(result.get("best_lap", 0.0))
    var char_id: String = String(result.get("char", selected_char()))
    var kart_id: String = String(result.get("kart", selected_kart()))

    var stats_d: Dictionary = data["stats"]
    stats_d["races"] = int(stats_d["races"]) + 1
    if rank == 1:
        stats_d["wins"] = int(stats_d["wins"]) + 1
    if rank <= 3:
        stats_d["podiums"] = int(stats_d["podiums"]) + 1

    var rec: Dictionary = data["records"]
    if not rec.has(track_id):
        rec[track_id] = {"best_time": 0.0, "best_lap": 0.0, "top": []}
    var r: Dictionary = rec[track_id]

    var new_time := time > 0.0 and (float(r["best_time"]) <= 0.0 or time < float(r["best_time"]))
    var new_lap := best_lap > 0.0 and (float(r["best_lap"]) <= 0.0 or best_lap < float(r["best_lap"]))
    # Primeira corrida da pista não conta como "recorde batido" (não há o que bater).
    var had_record := float(r["best_time"]) > 0.0
    if new_time:
        r["best_time"] = time
    if new_lap:
        r["best_lap"] = best_lap

    var top: Array = r["top"]
    top.append({
        "time": time, "lap": best_lap, "rank": rank,
        "char": char_id, "kart": kart_id,
        "date": Time.get_date_string_from_system(),
    })
    top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
    var pos := 0
    for i in top.size():
        if is_equal_approx(float(top[i]["time"]), time) and String(top[i]["char"]) == char_id and String(top[i]["date"]) == Time.get_date_string_from_system():
            pos = i + 1
            break
    if top.size() > TOP_SIZE:
        top.resize(TOP_SIZE)
    if pos > TOP_SIZE:
        pos = 0
    r["top"] = top

    var coin_mult := Catalog.mod(char_id, kart_id, "coins")
    var prize := int(round(float(PRIZE_BY_RANK[clampi(rank - 1, 0, PRIZE_BY_RANK.size() - 1)]) * coin_mult))
    var bonus_time := BONUS_BEST_TIME if (new_time and had_record) else 0
    var bonus_lap := BONUS_BEST_LAP if (new_lap and had_record) else 0
    var total := prize + bonus_time + bonus_lap
    add_coins(total)

    var names := _check_auto_unlocks()
    save_game()
    return {
        "prize": prize, "bonus_time": bonus_time, "bonus_lap": bonus_lap, "total": total,
        "new_time_record": new_time and had_record, "new_lap_record": new_lap and had_record,
        "leaderboard_pos": pos, "unlocked_names": names,
    }


# --------------------------------------------------------------- opções
func set_muted(value: bool) -> void:
    data["settings"]["muted"] = value
    AudioServer.set_bus_mute(0, value)
    mark_dirty()


func is_muted() -> bool:
    return bool(data["settings"]["muted"])


# Efeito visual retrô (scanlines/vinheta) — ligado por padrão.
func is_fx() -> bool:
    return bool((data["settings"] as Dictionary).get("fx", true))


func set_fx(value: bool) -> void:
    data["settings"]["fx"] = value
    fx_changed.emit(value)
    mark_dirty()
