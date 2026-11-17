class_name Sfx
extends RefCounted

# Gerador de sons e música por código (sem arquivos de áudio).
# Tudo é sintetizado em memória como AudioStreamWAV de 16 bits.

const RATE := 22050
const MUSIC_RATE := 8000


static func to_wav(data: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = rate
    w.stereo = false
    var bytes := PackedByteArray()
    bytes.resize(data.size() * 2)
    for i in data.size():
        bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 30000.0))
    w.data = bytes
    if loop:
        w.loop_mode = AudioStreamWAV.LOOP_FORWARD
        w.loop_begin = 0
        w.loop_end = data.size()
    return w


static func _env(t: float, dur: float, attack: float = 0.005) -> float:
    var a := minf(t / attack, 1.0)
    var d := maxf(1.0 - t / dur, 0.0)
    return a * d * d


static func tone(freq: float, dur: float, vol: float = 0.4, duty: float = 0.5) -> PackedFloat32Array:
    var n := int(dur * float(RATE))
    var out := PackedFloat32Array()
    out.resize(n)
    var ph := 0.0
    for i in n:
        var t := float(i) / float(RATE)
        ph = fposmod(ph + freq / float(RATE), 1.0)
        out[i] = (1.0 if ph < duty else -1.0) * vol * _env(t, dur)
    return out


static func sweep(f0: float, f1: float, dur: float, vol: float, noise_mix: float) -> PackedFloat32Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var n := int(dur * float(RATE))
    var out := PackedFloat32Array()
    out.resize(n)
    var ph := 0.0
    var lp := 0.0
    for i in n:
        var t := float(i) / float(RATE)
        var f := lerpf(f0, f1, t / dur)
        ph = fposmod(ph + f / float(RATE), 1.0)
        lp += 0.25 * (rng.randf_range(-1.0, 1.0) - lp)
        var s := sin(TAU * ph) * (1.0 - noise_mix) + lp * noise_mix * 2.5
        out[i] = s * vol * _env(t, dur, 0.03)
    return out


static func noise(dur: float, vol: float, smooth: float) -> PackedFloat32Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = 13
    var n := int(dur * float(RATE))
    var out := PackedFloat32Array()
    out.resize(n)
    var lp := 0.0
    for i in n:
        var t := float(i) / float(RATE)
        lp += smooth * (rng.randf_range(-1.0, 1.0) - lp)
        out[i] = lp * vol * _env(t, dur, 0.002) * 2.0
    return out


static func mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
    var n := maxi(a.size(), b.size())
    var out := PackedFloat32Array()
    out.resize(n)
    for i in n:
        var v := 0.0
        if i < a.size():
            v += a[i]
        if i < b.size():
            v += b[i]
        out[i] = v
    return out


static func arpeggio(freqs: Array, note_dur: float, vol: float, duty: float) -> PackedFloat32Array:
    var out := PackedFloat32Array()
    for f in freqs:
        out.append_array(tone(f, note_dur, vol, duty))
    return out


static func engine() -> AudioStreamWAV:
    # Onda periódica (200 amostras x 8 ciclos) para loop sem estalo.
    var period := 200
    var n := period * 8
    var out := PackedFloat32Array()
    out.resize(n)
    var prev := 0.0
    for pass_i in 2:
        for i in n:
            var ph := float(i % period) / float(period)
            var saw := 2.0 * ph - 1.0
            var sq := 1.0 if ph < 0.45 else -1.0
            var raw := 0.5 * saw + 0.3 * sq + 0.2 * sin(TAU * ph * 2.0)
            prev += 0.4 * (raw - prev)
            if pass_i == 1:
                out[i] = prev * 0.5
    return to_wav(out, RATE, true)


static func build_sfx() -> Dictionary:
    var d := {}
    d["beep"] = to_wav(tone(440.0, 0.28, 0.45), RATE)
    d["go"] = to_wav(tone(880.0, 0.55, 0.45), RATE)
    d["pickup"] = to_wav(arpeggio([784.0, 1047.0, 1319.0, 1568.0], 0.06, 0.32, 0.25), RATE)
    d["whoosh"] = to_wav(sweep(300.0, 1800.0, 0.7, 0.55, 0.8), RATE)
    d["use"] = to_wav(arpeggio([523.0, 784.0], 0.07, 0.3, 0.5), RATE)
    d["hit"] = to_wav(mix(noise(0.4, 0.7, 0.15), sweep(170.0, 40.0, 0.4, 0.7, 0.0)), RATE)
    d["bump"] = to_wav(mix(noise(0.14, 0.5, 0.2), sweep(130.0, 60.0, 0.14, 0.6, 0.0)), RATE)
    d["banana"] = to_wav(sweep(700.0, 300.0, 0.14, 0.5, 0.0), RATE)
    d["shell"] = to_wav(sweep(1300.0, 500.0, 0.35, 0.45, 0.3), RATE)
    d["lap"] = to_wav(arpeggio([659.0, 784.0, 988.0, 1319.0], 0.09, 0.35, 0.25), RATE)
    d["finish"] = to_wav(arpeggio([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0, 1568.0], 0.11, 0.35, 0.25), RATE)
    d["coin"] = to_wav(arpeggio([1319.0, 1760.0], 0.05, 0.28, 0.25), RATE)
    return d


# Sons da interface (menus).
static func build_ui() -> Dictionary:
    var d := {}
    d["click"] = to_wav(tone(880.0, 0.06, 0.30, 0.5), RATE)
    d["select"] = to_wav(arpeggio([660.0, 880.0], 0.05, 0.28, 0.25), RATE)
    d["back"] = to_wav(arpeggio([620.0, 440.0], 0.05, 0.28, 0.5), RATE)
    d["deny"] = to_wav(tone(160.0, 0.18, 0.40, 0.5), RATE)
    d["buy"] = to_wav(arpeggio([988.0, 1319.0, 1568.0, 1976.0], 0.06, 0.30, 0.25), RATE)
    d["unlock"] = to_wav(arpeggio([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.08, 0.32, 0.25), RATE)
    d["start"] = to_wav(sweep(200.0, 900.0, 0.35, 0.40, 0.3), RATE)
    return d


# Sons da vinheta do jogo (3D).
static func build_vinheta() -> Dictionary:
    var d := {}
    d["rev"] = to_wav(sweep(70.0, 520.0, 1.6, 0.50, 0.35), RATE)
    d["skid"] = to_wav(sweep(900.0, 420.0, 0.7, 0.35, 0.85), RATE)
    d["slam"] = to_wav(mix(noise(0.7, 0.8, 0.10), sweep(150.0, 35.0, 0.7, 0.95, 0.0)), RATE)
    d["fanfare"] = to_wav(arpeggio([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0], 0.10, 0.30, 0.25), RATE)
    d["whoosh"] = to_wav(sweep(250.0, 2200.0, 0.9, 0.40, 0.8), RATE)
    return d


static func build_intro() -> Dictionary:
    var d := {}
    d["swell"] = to_wav(sweep(70.0, 520.0, 0.65, 0.55, 0.45), RATE)
    d["hit"] = to_wav(mix(noise(0.8, 0.8, 0.08), sweep(130.0, 32.0, 0.8, 0.95, 0.0)), RATE)
    d["shine"] = to_wav(sweep(1500.0, 5200.0, 0.55, 0.22, 0.55), RATE)
    d["lines"] = to_wav(sweep(500.0, 1800.0, 0.4, 0.28, 0.1), RATE)
    d["tick"] = to_wav(tone(1320.0, 0.08, 0.25, 0.5), RATE)
    d["chime"] = to_wav(arpeggio([784.0, 1047.0, 1319.0, 1568.0], 0.16, 0.26, 0.5), RATE)
    return d


static func _mtof(m: int) -> float:
    return 440.0 * pow(2.0, float(m - 69) / 12.0)


static func _add_square(out: PackedFloat32Array, start: int, length: int, freq: float, vol: float, duty: float, gate: float) -> void:
    var last := mini(int(float(length) * gate), length)
    for i in last:
        var idx := start + i
        if idx >= out.size():
            break
        var ph := fposmod(float(i) * freq / float(MUSIC_RATE), 1.0)
        var env := 1.0 - float(i) / float(length) * 0.5
        out[idx] += (1.0 if ph < duty else -1.0) * vol * env


static func _add_kick(out: PackedFloat32Array, start: int, length: int) -> void:
    var ph := 0.0
    for i in length:
        var idx := start + i
        if idx >= out.size():
            break
        var k := float(i) / float(length)
        ph += lerpf(130.0, 45.0, k) / float(MUSIC_RATE)
        out[idx] += sin(TAU * ph) * 0.30 * (1.0 - k)


static func _add_hat(out: PackedFloat32Array, start: int, length: int, rng: RandomNumberGenerator) -> void:
    for i in length:
        var idx := start + i
        if idx >= out.size():
            break
        out[idx] += rng.randf_range(-1.0, 1.0) * 0.07 * (1.0 - float(i) / float(length))


static func music() -> AudioStreamWAV:
    var rng := RandomNumberGenerator.new()
    rng.seed = 99
    var beat := 0.375
    var bars := 8
    var step_n := int(beat * 0.5 * float(MUSIC_RATE))
    var steps := bars * 8
    var out := PackedFloat32Array()
    out.resize(steps * step_n)
    var prog_bass: Array = [48, 45, 41, 43]
    var prog_chord: Array = [[60, 64, 67], [57, 60, 64], [57, 60, 65], [59, 62, 67]]
    var pat_a: Array = [0, 1, 2, 1, 2, 1, 0, 1]
    var pat_b: Array = [2, 1, 0, 1, 2, 2, 1, 0]
    for s in steps:
        var bar := s / 8
        var chord_i := bar % 4
        var in_bar := s % 8
        var start := s * step_n
        var bm: int = prog_bass[chord_i] + (12 if in_bar % 2 == 1 else 0)
        _add_square(out, start, step_n, _mtof(bm), 0.15, 0.5, 0.85)
        var tones: Array = prog_chord[chord_i]
        var pat: Array = pat_a if bar < 4 else pat_b
        var lm: int = tones[pat[in_bar]] + (12 if bar >= 4 else 0)
        _add_square(out, start, step_n, _mtof(lm), 0.12, 0.25, 0.9)
        if in_bar % 2 == 0:
            _add_kick(out, start, int(0.14 * float(MUSIC_RATE)))
        else:
            _add_hat(out, start, int(0.04 * float(MUSIC_RATE)), rng)
    return to_wav(out, MUSIC_RATE, true)
