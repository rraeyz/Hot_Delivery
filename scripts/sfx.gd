class_name Sfx
extends Node
## Plays the synthesized sounds in assets/audio. Engine + music loop.

const NAMES := ["horn", "pickup", "cash", "crash", "fall", "splash", "splat", "thud", "bump",
	"throw", "cheer", "bark", "coo", "wind", "whistle", "click"]

var streams := {}
var pool: Array = []
var engine_player: AudioStreamPlayer
var music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	engine_player = AudioStreamPlayer.new()
	engine_player.stream = _looped(load("res://assets/audio/engine.wav"))
	engine_player.volume_db = -14.0
	add_child(engine_player)
	music_player = AudioStreamPlayer.new()
	music_player.stream = _looped(load("res://assets/audio/music.wav"))
	add_child(music_player)


func _looped(s: AudioStreamWAV) -> AudioStreamWAV:
	var c: AudioStreamWAV = s.duplicate()
	c.loop_mode = AudioStreamWAV.LOOP_FORWARD
	c.loop_begin = 0
	c.loop_end = int(c.data.size() / 2.0)
	return c


func play(n: String, pitch_jitter := 0.08) -> void:
	if not streams.has(n):
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[n]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func engine(speed: float, throttle: float) -> void:
	if not engine_player.playing:
		engine_player.play()
	engine_player.pitch_scale = 0.7 + absf(speed) * 0.07 + maxf(0.0, throttle) * 0.15
	engine_player.volume_db = -16.0 + minf(6.0, absf(speed) * 0.4)


func music(on: bool) -> void:
	music_player.volume_db = linear_to_db(maxf(0.001, Game.settings.music)) - 8.0
	if on and not music_player.playing:
		music_player.play()
	elif not on:
		music_player.stop()
		engine_player.stop()
