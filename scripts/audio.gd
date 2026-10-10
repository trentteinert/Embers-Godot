class_name Sfx
extends Node
## Sound effects and music. Call from anywhere:
##   Sfx.play("hit")                      # plain sound
##   Sfx.play("hit", enemy.global_position)  # quieter the further it is from the player
##   Sfx.music("meadow")                  # crossfades to a music loop
## Sounds live in assets/audio/sfx/*.wav, music in assets/audio/music/*.ogg
## (tools/make_audio.py regenerates them). Volumes are saved to user://settings.cfg.

const SFX_PATH := "res://assets/audio/sfx/%s.wav"
const MUSIC_PATH := "res://assets/audio/music/%s.ogg"
const SETTINGS_PATH := "user://settings.cfg"
const VOICES := 24
const FADE := 1.6

static var inst: Sfx

var listener: Node3D            # usually the player
var volumes := {"Master": 0.8, "Music": 0.6, "SFX": 0.8}

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_track := ""


static func play(sound: String, at := Vector3.INF, volume_db := 0.0, pitch_var := 0.08) -> void:
	if inst:
		inst._play(sound, at, volume_db, pitch_var)


static func music(track: String) -> void:
	if inst:
		inst._music(track)


func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
	_load_settings()


func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[path] = s
	return s


func _play(sound: String, at: Vector3, volume_db: float, pitch_var: float) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -1000)) < 35:
		return
	var s := _stream(SFX_PATH % sound)
	if s == null:
		return
	var vol := volume_db
	if at != Vector3.INF and listener:
		var d := Vector2(at.x - listener.global_position.x, at.z - listener.global_position.z).length()
		if d > 40.0:
			return
		vol -= clampf((d - 4.0) * 0.6, 0.0, 30.0)
	_last_play[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func _music(track: String) -> void:
	if track == _current_track:
		return
	_current_track = track
	var old := _music_a if _music_a.playing and _music_a.volume_db > -40.0 else _music_b
	var fresh := _music_b if old == _music_a else _music_a
	var tw := create_tween().set_parallel(true)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, FADE)
	if track == "":
		return
	var s := _stream(MUSIC_PATH % track)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	fresh.stream = s
	fresh.volume_db = -40.0
	fresh.play()
	tw.tween_property(fresh, "volume_db", 0.0, FADE)
	tw.chain().tween_callback(func() -> void:
		if old.volume_db <= -79.0:
			old.stop())


# ---------------------------------------------------------------- volume settings
func set_volume(bus_name: String, v: float) -> void:
	volumes[bus_name] = clampf(v, 0.0, 1.0)
	_apply()
	_save_settings()


func _apply() -> void:
	for k: String in volumes:
		var i := AudioServer.get_bus_index(k)
		if i >= 0:
			var v: float = volumes[k]
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(i, v <= 0.001)


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k: String in volumes:
			volumes[k] = float(cf.get_value("audio", k, volumes[k]))
	_apply()


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	for k: String in volumes:
		cf.set_value("audio", k, volumes[k])
	cf.save(SETTINGS_PATH)
