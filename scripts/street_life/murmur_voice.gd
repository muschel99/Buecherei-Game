class_name MurmurVoice
extends AudioStreamPlayer3D
## Freundliches Gemurmel einer plaudernden Figur (seit Etappe 6c) – wie bei Animal Crossing: kurze,
## unverständliche Silben in kleinen „Sätzen“, jede Figur mit eigener Tonhöhe. Silben: alle Dateien in
## assets/audio/sfx/murmur/ (.wav/.ogg; selbst erzeugt von tools/make_chat_assets.py – eigene Geräusche
## einfach dazulegen oder austauschen). Lautstärke und Hörweite: GameConfig (murmur_*).

const FOLDER := "res://assets/audio/sfx/murmur/"

static var _syllables: Array[AudioStream] = []

## Tonhöhe dieser Figur (1 = wie aufgenommen)
var voice_pitch := 1.0
var _talk_left := 0.0
var _next := 0.0
var _in_sentence := 0


func _init() -> void:
	unit_size = 2.0
	max_distance = GameConfig.murmur_distance
	volume_db = GameConfig.murmur_volume_db
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice_pitch = randf_range(GameConfig.murmur_pitch_range.x, GameConfig.murmur_pitch_range.y)


## Alle Silben aus dem Ordner (einmal geladen).
static func syllables() -> Array[AudioStream]:
	if _syllables.is_empty():
		var seen := {}
		for file in DirAccess.get_files_at(FOLDER):
			var name := file.trim_suffix(".import").trim_suffix(".remap")
			if name.get_extension().to_lower() in ["wav", "ogg", "mp3"] and not seen.has(name):
				seen[name] = true
				var stream := load(FOLDER + name) as AudioStream
				if stream:
					_syllables.append(stream)
	return _syllables


## So lange (Sekunden) murmeln.
func talk(seconds: float) -> void:
	if not GameConfig.murmur_enabled:
		return
	_talk_left = seconds
	_next = 0.0
	_in_sentence = randi_range(3, 7)


func stop_talking() -> void:
	_talk_left = 0.0


func _process(delta: float) -> void:
	if _talk_left <= 0.0:
		return
	_talk_left -= delta
	_next -= delta
	if _next > 0.0:
		return
	var all := syllables()
	if all.is_empty():
		_talk_left = 0.0
		return
	stream = all[randi() % all.size()]
	pitch_scale = voice_pitch * randf_range(0.92, 1.1)
	play()
	_in_sentence -= 1
	if _in_sentence <= 0:
		# kleine Pause zwischen den „Sätzen“
		_in_sentence = randi_range(3, 7)
		_next = randf_range(0.35, 0.7)
	else:
		_next = randf_range(0.1, 0.16)
