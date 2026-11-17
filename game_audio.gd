class_name GameAudio
extends Node

# Reprodutor de sons: efeitos (pool), motor do jogador e música de fundo.

var streams := {}
var engine_stream: AudioStreamWAV
var music_stream: AudioStreamWAV
var pool: Array[AudioStreamPlayer] = []
var engine_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var muted := false


func setup() -> void:
    streams = Sfx.build_sfx()
    engine_stream = Sfx.engine()
    for i in 8:
        var p := AudioStreamPlayer.new()
        add_child(p)
        pool.append(p)
    engine_player = AudioStreamPlayer.new()
    engine_player.stream = engine_stream
    engine_player.volume_db = -12.0
    add_child(engine_player)
    music_player = AudioStreamPlayer.new()
    music_player.volume_db = -13.0
    add_child(music_player)


func prepare_music() -> void:
    music_stream = Sfx.music()


func start_music() -> void:
    if music_stream != null:
        music_player.stream = music_stream
        music_player.play()


func sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
    if not streams.has(sound_name):
        return
    var chosen: AudioStreamPlayer = pool[0]
    for p in pool:
        if not p.playing:
            chosen = p
            break
    chosen.stream = streams[sound_name]
    chosen.volume_db = volume_db
    chosen.pitch_scale = pitch
    chosen.play()


func set_engine(speed_ratio: float, boosting: bool, active: bool) -> void:
    if engine_player == null:
        return
    if not active:
        if engine_player.playing:
            engine_player.stop()
        return
    if not engine_player.playing:
        engine_player.play()
    engine_player.pitch_scale = 0.75 + speed_ratio * 1.7 + (0.25 if boosting else 0.0)


func toggle_mute() -> bool:
    muted = not muted
    AudioServer.set_bus_mute(0, muted)
    return muted
