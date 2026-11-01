extends Node
## Einfaches Audio-System (seit Etappe 6d): Geräusche liegen als Dateien in Ordnern unter
## res://assets/audio/ – fehlt eine Datei, bleibt es einfach still (keine Fehlermeldung).
##
## Ordner und Kanal (Lautstärke getrennt in den Einstellungen):
##   music/      Musik            → Kanal „Music“
##   ambience/   Umgebung         → Kanal „Ambience“ (Vögel, Wind, Kamin, Stadt)
##   footsteps/, doors/, vehicles/, ui/, books/, computer/  → Kanal „Effects“
##   voices/     Stimmen          → Kanal „Voices“ (kurze Laute der Passanten: Lachen, „hm“, „oh“)
##
## Namen ohne Endung angeben, z. B. Audio.play_at("doors/shop_bell", position). Gesucht wird
## <name>.ogg, .wav, .mp3 – und Abwandlungen <name>_1, <name>_2 … (dann zufällig eine davon, damit
## Schritte und Klingeln nicht immer gleich klingen). Alles Weitere: docs/ASSET_GUIDE.md („Eigene Geräusche“).

const ROOT := "res://assets/audio/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
## Kanäle (Busse) und welche Ordner dort hinein spielen
const BUSES := ["Music", "Ambience", "Effects", "Voices"]
const FOLDER_BUS := {"music": "Music", "ambience": "Ambience", "voices": "Voices"}

## name -> Array[AudioStream] (leer = gibt es nicht; wird nur einmal gesucht)
var _cache := {}
## Musik: zwei Player zum Überblenden, Stücke der aktuellen Stimmung (seit Etappe 6f)
var _music_players: Array[AudioStreamPlayer] = []
var _music_active := 0
var _music_tracks: Array = []
var _music_index := 0
var _music_mood := "day"
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	apply_volumes()
	Settings.setting_changed.connect(func(key: String, _value: Variant) -> void:
		if key.begins_with("audio/"):
			apply_volumes())


## Lautstärken aus den Einstellungen (0–100 %) auf die Kanäle.
func apply_volumes() -> void:
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var percent := float(Settings.get_value("audio/%s_volume" % bus.to_lower()))
		AudioServer.set_bus_mute(index, percent <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(percent, 0.1) / 100.0))


## Kanal für einen Namen („doors/shop_bell“ → Effects).
func bus_for(sound_name: String) -> String:
	for folder in FOLDER_BUS:
		if sound_name.begins_with(folder + "/"):
			return FOLDER_BUS[folder]
	return "Effects"


## Alle Dateien zu einem Namen (Abwandlungen mitgezählt); leer, wenn es keine gibt.
func streams(sound_name: String) -> Array:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var found := []
	var base := ROOT + sound_name
	for ext in EXTENSIONS:
		if ResourceLoader.exists(base + "." + ext):
			found.append(load(base + "." + ext))
	var k := 1
	while k < 100:
		var any := false
		for ext in EXTENSIONS:
			if ResourceLoader.exists("%s_%d.%s" % [base, k, ext]):
				found.append(load("%s_%d.%s" % [base, k, ext]))
				any = true
		if not any:
			break
		k += 1
	_cache[sound_name] = found
	return found


## Eine Datei (bei Abwandlungen eine zufällige) oder null.
func stream(sound_name: String) -> AudioStream:
	var all := streams(sound_name)
	return all[randi() % all.size()] if not all.is_empty() else null


func has_sound(sound_name: String) -> bool:
	return not streams(sound_name).is_empty()


## Kurzes Geräusch ohne Ort (Oberfläche, Tablet, Bücher in der Hand).
func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(sound_name)
	if s == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = s
	player.bus = bus_for(sound_name)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Kurzes Geräusch an einem Ort in der Welt (Türklingel, Schritte, Hupe).
func play_at(sound_name: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(sound_name)
	if s == null or not is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = s
	player.bus = bus_for(sound_name)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	_spatial(player, GameConfig.audio_max_distance)
	get_tree().current_scene.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()


## Hintergrund-Geräusch ohne Ort in Schleife (z. B. ambience/outdoor: Vögel, ferne Stadt).
func start_ambience(sound_name: String) -> void:
	var s := stream(sound_name)
	if s == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = "Ambience"
	player.stream = _looped(s)
	player.bus = "Ambience"
	add_child(player)
	player.play()


## Musik (seit Etappe 6f nach Stimmung in Unterordnern von music/: day, night, rain, winter): alle Stücke des
## Ordners in zufälliger Reihenfolge, ohne Pause – das nächste Stück blendet weich über das Ende des alten
## (GameConfig.music_crossfade). Ein leerer Ordner nimmt „day“ bzw. die Dateien direkt in music/.
func start_music(mood: String = "day") -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		_music_players.append(player)
	set_music_mood(mood)


## Stimmung der Musik wechseln (später nach Tageszeit, Wetter und Jahreszeit): das laufende Stück blendet
## weich in ein Stück aus dem neuen Ordner über.
func set_music_mood(mood: String) -> void:
	_music_mood = mood
	_music_tracks = _music_files(mood)
	if _music_tracks.is_empty() and mood != "day":
		_music_tracks = _music_files("day")
	if _music_tracks.is_empty():
		_music_tracks = _music_files("")
	_music_tracks.shuffle()
	_music_index = 0
	if not _music_tracks.is_empty() and not _music_players.is_empty():
		_next_track()


func get_music_mood() -> String:
	return _music_mood


func _music_files(mood: String) -> Array:
	var tracks := []
	var dir := ROOT + "music/" + (mood + "/" if not mood.is_empty() else "")
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			var name := file.trim_suffix(".import").trim_suffix(".remap")
			if name.get_extension().to_lower() in EXTENSIONS and not tracks.has(dir + name):
				tracks.append(dir + name)
	return tracks


## Nächstes Stück auf dem freien Player einblenden, das laufende ausblenden.
func _next_track() -> void:
	if _music_players.is_empty() or _music_tracks.is_empty():
		return
	var old: AudioStreamPlayer = _music_players[_music_active]
	_music_active = 1 - _music_active
	var player: AudioStreamPlayer = _music_players[_music_active]
	var path: String = _music_tracks[_music_index % _music_tracks.size()]
	_music_index += 1
	if _music_index >= _music_tracks.size():
		# Runde zu Ende: neu mischen, aber nicht dasselbe Stück zweimal hintereinander
		_music_index = 0
		var last := path
		_music_tracks.shuffle()
		if _music_tracks.size() > 1 and _music_tracks[0] == last:
			_music_tracks.append(_music_tracks.pop_front())
	player.stream = load(path)
	player.volume_db = -40.0
	player.play()
	var fade := GameConfig.music_crossfade
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(player, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_music_tween.chain().tween_callback(old.stop)


func _process(_delta: float) -> void:
	# kurz vor dem Ende des laufenden Stücks das nächste überblenden (keine Pause)
	if _music_players.is_empty() or _music_tracks.is_empty():
		return
	var player: AudioStreamPlayer = _music_players[_music_active]
	if player.stream == null:
		return
	if not player.playing or player.get_playback_position() >= player.stream.get_length() - GameConfig.music_crossfade:
		_next_track()


func _looped(s: AudioStream) -> AudioStream:
	s = s.duplicate()
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		if (s as AudioStreamWAV).loop_end <= 0:
			(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	return s


## Kurzes Geräusch, das an einem Knoten hängt und mit ihm wandert (Fahrradklingel, Hupe, Stimme):
## räumlich, offset = Stelle relativ zum Knoten (z. B. Kopfhöhe). Liefert den Player (oder null).
func play_on(owner_node: Node3D, sound_name: String, volume_db: float = 0.0, pitch: float = 1.0,
		max_distance: float = 25.0, offset: Vector3 = Vector3.ZERO) -> AudioStreamPlayer3D:
	var s := stream(sound_name)
	if s == null or owner_node == null or not owner_node.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = s
	player.bus = bus_for(sound_name)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	_spatial(player, max_distance)
	player.position = offset
	owner_node.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Tonhöhe leicht zufällig (damit nichts gleichförmig klingt): 1 ± spread.
static func vary(spread: float = 0.06) -> float:
	return randf_range(1.0 - spread, 1.0 + spread)


## Dauerndes Geräusch an einem Knoten (Kaminknistern, Vögel im Baum): ein AudioStreamPlayer3D als
## Kind von owner, das in Schleife läuft. Liefert ihn (oder null, wenn es die Datei nicht gibt).
func loop_at(owner_node: Node3D, sound_name: String, volume_db: float = 0.0, max_distance: float = 12.0) -> AudioStreamPlayer3D:
	var s := stream(sound_name)
	if s == null:
		return null
	s = _looped(s)
	var player := AudioStreamPlayer3D.new()
	player.name = "Sound_" + sound_name.get_file()
	player.stream = s
	player.bus = bus_for(sound_name)
	player.volume_db = volume_db
	_spatial(player, max_distance)
	owner_node.add_child(player)
	return player


## Räumlich hören (seit Etappe 6f): leiser mit der Entfernung (unit_size = GameConfig.audio_unit_size statt
## Godots 10 m – sonst klang alles fast gleich laut und schien „von mir“ zu kommen), in der Ferne dumpfer,
## ab max_distance still.
func _spatial(player: AudioStreamPlayer3D, max_distance: float) -> void:
	player.unit_size = GameConfig.audio_unit_size
	player.max_distance = max_distance
	player.attenuation_filter_cutoff_hz = 6000.0
	player.attenuation_filter_db = -18.0
