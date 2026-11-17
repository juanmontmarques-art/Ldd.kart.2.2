extends CanvasLayer

# Fluxo entre telas (autoload "Flow").
#   Intro (empresa) -> LddIntro (3D, termina no menu) -> Menu -> Garagem (personagem + kart) -> Main (corrida)
# Faz a transição com fade preto, guarda o resultado da última corrida e toca
# a música/sons dos menus (que continuam tocando ao trocar de tela).

const SCENE_INTRO := "res://Intro.tscn"
const SCENE_VINHETA := "res://LddIntro.tscn"
const SCENE_MENU := "res://Menu.tscn"
const SCENE_GARAGEM := "res://Garagem.tscn"
const SCENE_RACE := "res://Main.tscn"

# Resumo da última corrida (preenchido pela corrida, lido pelo menu/recordes).
var last_summary: Dictionary = {}

# Passo inicial da garagem: 0 = piloto (personalização), 1 = seleção de karts.
var garage_step := 0

var _fade: ColorRect
var _busy := false
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _ui_sounds: Dictionary = {}
var _ui_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    _fade = ColorRect.new()
    _fade.color = Color(0.0, 0.0, 0.0, 0.0)
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_fade)
    _fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _ui_sounds = Sfx.build_ui()
    for i in 4:
        var p := AudioStreamPlayer.new()
        p.volume_db = -6.0
        add_child(p)
        _ui_players.append(p)

    _music = AudioStreamPlayer.new()
    _music.volume_db = -17.0
    add_child(_music)


# Troca de cena com fade. Ignora chamadas enquanto uma troca está em andamento.
func go(path: String, duration: float = 0.35) -> void:
    if _busy:
        return
    _busy = true
    _fade.mouse_filter = Control.MOUSE_FILTER_STOP
    var tw := create_tween()
    tw.tween_property(_fade, "color:a", 1.0, duration)
    await tw.finished
    get_tree().paused = false
    get_tree().change_scene_to_file(path)
    await get_tree().process_frame
    await get_tree().process_frame
    var tw2 := create_tween()
    tw2.tween_property(_fade, "color:a", 0.0, duration)
    await tw2.finished
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _busy = false


func is_busy() -> bool:
    return _busy


# Som curto de interface: click, select, back, deny, buy, unlock, start.
func ui(sound_name: String) -> void:
    if not _ui_sounds.has(sound_name):
        return
    var chosen: AudioStreamPlayer = _ui_players[0]
    for p in _ui_players:
        if not p.playing:
            chosen = p
            break
    chosen.stream = _ui_sounds[sound_name]
    chosen.play()


func start_menu_music() -> void:
    if _music.playing:
        return
    if _music_stream == null:
        _music_stream = Sfx.music()
    _music.stream = _music_stream
    _music.play()


func stop_music() -> void:
    _music.stop()


# Sai do jogo garantindo que o save foi gravado.
func quit_game() -> void:
    SaveGame.save_game()
    get_tree().quit()
