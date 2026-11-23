class_name QuestAudio
extends Node
var players: Array[AudioStreamPlayer] = []
var effects: AudioStreamPlayer
var active := 0
var music_volume := 0.55
var effects_volume := 0.65
var current_track := -1
var cache: Dictionary = {}
var fade: Tween

func _exit_tree() -> void:
    if fade: fade.kill()
    for player in players:
        player.stop()
        player.stream = null
    effects.stop()
    effects.stream = null
    cache.clear()

func _ready() -> void:
    for i in range(2):
        var player := AudioStreamPlayer.new()
        add_child(player)
        players.append(player)
    effects = AudioStreamPlayer.new()
    add_child(effects)

func set_volumes(music: float, sfx: float) -> void:
    music_volume = clampf(music, 0, 1)
    effects_volume = clampf(sfx, 0, 1)
    if fade and fade.is_running(): fade.kill()
    for i in range(2):
        players[i].volume_db = linear_to_db(music_volume * 0.28) if i == active else -80
        if i != active: players[i].stop()
    effects.volume_db = linear_to_db(effects_volume * 0.3)

func change_track(room: int) -> void:
    var track := 0 if room < 2 else (1 if room < 4 else (2 if room == 4 else (3 if room < 7 else 4)))
    if room == 8: track = 5
    if track == current_track: return
    current_track = track
    var next := 1 - active
    if not cache.has(track): cache[track] = _music(track)
    players[next].stream = cache[track]
    players[next].volume_db = -60
    players[next].play()
    if fade: fade.kill()
    fade = create_tween().set_parallel(true)
    fade.tween_property(players[active], "volume_db", -80.0, 0.65)
    fade.tween_property(players[next], "volume_db", linear_to_db(maxf(0.0001, music_volume * 0.28)), 0.65)
    var previous := active
    fade.chain().tween_callback(func(): players[previous].stop())
    active = next

func sfx(kind: String) -> void:
    var frequencies := {"step": 95.0, "key": 750.0, "door": 220.0, "success": 660.0, "error": 140.0, "reward": 880.0}
    var key := "fx_" + kind
    if not cache.has(key):
        var length := 1.2 if kind == "reward" else (0.07 if kind in ["step", "key"] else 0.24)
        var buffer := PackedByteArray()
        buffer.resize(int(22050 * length) * 2)
        var freq: float = frequencies.get(kind, 440.0)
        for i in range(buffer.size() / 2):
            var t := float(i) / 22050
            if kind == "reward": freq = [523.25, 659.25, 783.99, 1046.5][mini(3, int(t / 0.2))]
            var sample := sin(TAU * (freq + t * (600 if kind != "error" else -200)) * t) * exp(-t * 18) * 0.45
            if kind == "reward": sample = sin(TAU * freq * t) * exp(-fmod(t, 0.2) * 12) * 0.35 * minf(1, (length - t) * 10)
            buffer.encode_s16(i * 2, int(sample * 32767))
        var stream := AudioStreamWAV.new()
        stream.format = AudioStreamWAV.FORMAT_16_BITS
        stream.mix_rate = 22050
        stream.data = buffer
        cache[key] = stream
    effects.stream = cache[key]
    effects.play()

func _music(track: int) -> AudioStreamWAV:
    # Original arpeggios, bass and soft pulse percussion, generated locally once.
    var sequences := [
        [0, 4, 7, 11, 7, 4, 2, 7, 0, 4, 9, 7, 5, 4, 2, 7],
        [0, 7, 12, 7, 3, 10, 15, 10, 5, 12, 17, 12, 7, 14, 19, 14],
        [0, 3, 7, 10, 0, 3, 8, 10, -2, 2, 7, 10, -2, 2, 5, 9],
        [0, 7, 3, 10, 0, 12, 7, 15, 5, 12, 8, 15, 7, 14, 10, 17],
        [0, 12, 7, 15, 3, 15, 10, 19, 5, 17, 12, 20, 7, 19, 14, 22],
        [0, 4, 7, 12, 11, 7, 4, 7, 5, 9, 12, 17, 12, 9, 7, 12]]
    var step := 0.25 if track in [3, 4] else 0.34
    var length := step * 32
    var buffer := PackedByteArray()
    var count := int(length * 22050)
    buffer.resize(count * 2)
    for i in range(count):
        var t := float(i) / 22050
        var beat := int(t / step)
        var phase := fmod(t, step)
        var note: int = sequences[track][beat % 16]
        var freq := 220.0 * pow(2.0, float(note) / 12.0)
        var melody := (1.0 if sin(TAU * freq * t) > 0 else -1.0) * exp(-phase * 12) * 0.12
        var bass_note: int = [0, 3, 5, 7][int(beat / 8) % 4]
        var bass := sin(TAU * 55 * pow(2, float(bass_note) / 12) * t) * 0.17
        var kick := sin(TAU * 72 * phase) * exp(-phase * 40) * (0.16 if beat % 2 == 0 else 0.03)
        var pad := sin(TAU * freq * 0.5 * t) * 0.035
        var edge := minf(1, minf(t * 40, (length - t) * 40))
        buffer.encode_s16(i * 2, int((melody + bass + kick + pad) * edge * 32767))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = buffer
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = count
    return stream
