extends Node
## Autoload "Sfx": crunchy procedurally generated sound effects, so the game
## has audio feedback before real sounds exist. To use a real sound instead,
## put it in _streams under the same name, e.g.
##   _streams["shotgun"] = preload("res://audio/shotgun.wav")

const RATE := 22050
const POOL_SIZE := 16

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_var: float = 0.08) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch * (1.0 + randf_range(-pitch_var, pitch_var)), 0.05)
	p.play()


func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.unit_size = 10.0
	p.max_distance = 90.0
	p.pitch_scale = pitch * (1.0 + randf_range(-0.08, 0.08))
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func _build() -> void:
	#                                   len   f0     f1    noise decay cutoff  wave
	_streams["revolver"] = _synth(0.30, 420.0, 70.0, 0.75, 13.0, 4200.0, "square")
	_streams["shotgun"] = _synth(0.50, 150.0, 40.0, 0.9, 7.5, 2600.0, "square")
	_streams["charge"] = _synth(0.55, 180.0, 900.0, 0.05, 0.8, 6000.0, "square")
	_streams["charge_shot"] = _synth(0.70, 900.0, 50.0, 0.6, 5.0, 6000.0, "saw")
	_streams["throw"] = _synth(0.18, 300.0, 650.0, 0.4, 12.0, 3000.0, "sine")
	_streams["explosion"] = _synth(1.0, 75.0, 22.0, 1.0, 4.0, 1300.0, "square")
	_streams["hit"] = _synth(0.08, 900.0, 600.0, 0.25, 30.0, 6000.0, "square")
	_streams["kill"] = _synth(0.28, 500.0, 1300.0, 0.2, 9.0, 7000.0, "square")
	_streams["hurt"] = _synth(0.30, 240.0, 80.0, 0.5, 9.0, 2400.0, "saw")
	_streams["parry"] = _synth(0.45, 1700.0, 2600.0, 0.15, 6.0, 9000.0, "square")
	_streams["punch"] = _synth(0.14, 170.0, 60.0, 0.6, 20.0, 1800.0, "sine")
	_streams["dash"] = _synth(0.24, 0.0, 0.0, 1.0, 10.0, 3200.0, "noise")
	_streams["jump"] = _synth(0.12, 220.0, 460.0, 0.1, 18.0, 4000.0, "square")
	_streams["land"] = _synth(0.12, 95.0, 50.0, 0.6, 25.0, 1200.0, "sine")
	_streams["slam"] = _synth(0.55, 85.0, 28.0, 0.9, 6.0, 1500.0, "square")
	_streams["grapple"] = _synth(0.20, 1300.0, 300.0, 0.3, 13.0, 5000.0, "saw")
	_streams["pickup"] = _synth(0.16, 700.0, 1500.0, 0.0, 13.0, 8000.0, "square")
	_streams["scrap"] = _synth(0.10, 1400.0, 1700.0, 0.0, 20.0, 8000.0, "square")
	_streams["enemy_shot"] = _synth(0.25, 520.0, 180.0, 0.3, 12.0, 3000.0, "saw")
	_streams["telegraph"] = _synth(0.30, 1050.0, 1050.0, 0.0, 4.0, 6000.0, "square")
	_streams["beep"] = _synth(0.07, 1500.0, 1500.0, 0.0, 10.0, 6000.0, "square")
	_streams["laser"] = _synth(0.55, 2100.0, 1400.0, 0.2, 5.0, 7000.0, "saw")
	_streams["spawn"] = _synth(0.45, 120.0, 900.0, 0.4, 5.0, 4000.0, "saw")
	_streams["rank_up"] = _synth(0.25, 880.0, 1760.0, 0.0, 9.0, 8000.0, "square")
	_streams["wave"] = _synth(0.80, 220.0, 110.0, 0.1, 2.5, 3000.0, "square")
	_streams["ui_move"] = _synth(0.05, 1200.0, 1200.0, 0.0, 30.0, 6000.0, "square")
	_streams["ui_select"] = _synth(0.12, 600.0, 1200.0, 0.0, 15.0, 6000.0, "square")
	_streams["slash"] = _synth(0.18, 0.0, 0.0, 1.0, 16.0, 6500.0, "noise")
	_streams["gatling"] = _synth(0.12, 320.0, 90.0, 0.8, 24.0, 3800.0, "square")
	_streams["zap"] = _synth(0.35, 2400.0, 500.0, 0.5, 8.0, 9000.0, "saw")


func _synth(length: float, f0: float, f1: float, noise: float, decay: float, cutoff: float, wave: String) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(wave + str(f0) + str(length))
	var w := TAU * cutoff / RATE
	var alpha := w / (1.0 + w)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / length)
		phase = fmod(phase + f / RATE, 1.0)
		var tone := 0.0
		match wave:
			"square":
				tone = 1.0 if phase < 0.5 else -1.0
			"saw":
				tone = phase * 2.0 - 1.0
			"sine":
				tone = sin(phase * TAU)
		var s := lerpf(tone, rng.randf_range(-1.0, 1.0), noise)
		lp += alpha * (s - lp)
		var env := exp(-t * decay) * minf(t * 400.0, 1.0)
		var v := roundf(lp * env * 0.7 * 40.0) / 40.0 # bit-crush for that console crunch
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
