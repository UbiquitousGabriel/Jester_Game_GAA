extends Node
## Autoload. Music with crossfades and pooled sound effects on their own buses.
## Sounds live in assets/audio (synthesised by tools/audio/synth.py). A name
## with no file is silent, so code can reference sounds before they exist.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 20
## Same sound no more often than this (seconds), so hit storms stay readable.
const REPEAT_GAP := 0.035

var _streams: Dictionary[StringName, AudioStream] = {}
var _missing: Dictionary[StringName, bool] = {}
var _last_played: Dictionary[StringName, int] = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: Array[AudioStreamPlayer] = []
var _music_index: int = 0
var _track: StringName = &""
var _ambience: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	_ensure_bus(&"Ambience")
	for i: int in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	for i: int in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Ambience"
	add_child(_ambience)


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


## 0..1 linear volume for "Master", "Music", "SFX" or "Ambience".
func set_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func sfx(sound: StringName, pitch_variance: float = 0.06, volume_db: float = 0.0) -> void:
	var stream := _stream(SFX_DIR, sound)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_played.get(sound, -100000) < int(REPEAT_GAP * 1000.0):
		return
	_last_played[sound] = now
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


## Crossfade to a music track ("" or &"" fades to silence).
func music(track: StringName, fade: float = 1.2) -> void:
	if track == _track:
		return
	_track = track
	var old := _music[_music_index]
	_music_index = 1 - _music_index
	var new := _music[_music_index]
	var tween := create_tween().set_parallel()
	tween.tween_property(old, "volume_db", -80.0, fade)
	tween.chain().tween_callback(old.stop)
	var stream := _stream(MUSIC_DIR, track) if track != &"" else null
	if stream == null:
		return
	new.stream = stream
	new.volume_db = -40.0
	new.play()
	create_tween().tween_property(new, "volume_db", 0.0, fade)


func current_track() -> StringName:
	return _track


## Looping background bed (wind, gears, rain).
func ambience(track: StringName) -> void:
	var stream := _stream(MUSIC_DIR, track) if track != &"" else null
	if stream == _ambience.stream and _ambience.playing:
		return
	_ambience.stop()
	_ambience.stream = stream
	if stream != null:
		_ambience.volume_db = -6.0
		_ambience.play()


func _stream(dir: String, sound: StringName) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	if _missing.has(sound):
		return null
	var path := dir + String(sound) + ".ogg"
	if not ResourceLoader.exists(path):
		_missing[sound] = true
		return null
	var stream := load(path) as AudioStream
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null and dir == MUSIC_DIR:
		ogg.loop = true
	_streams[sound] = stream
	return stream
