extends Node
## Einfaches Audio-System (seit Etappe 6d): Geräusche liegen als Dateien in Ordnern unter
## res://assets/audio/ – fehlt eine Datei, bleibt es einfach still (keine Fehlermeldung).
##
## Ordner und Kanal (Lautstärke getrennt in den Einstellungen):
##   music/      Musik            → Kanal „Music“
##   ambience/   Umgebung         → Kanal „Ambience“ (Vögel, Wind, Kamin, Stadt)
##   footsteps/, doors/, vehicles/, ui/, books/  → Kanal „Effects“
##   voices/     Stimmen          → Kanal „Voices“ (auch das Gemurmel aus sfx/murmur/)
##
## Namen ohne Endung angeben, z. B. Audio.play_at("doors/shop_bell", position). Gesucht wird
## <name>.ogg, .wav, .mp3 – und Abwandlungen <name>_1, <name>_2 … (dann zufällig eine davon, damit
## Schritte und Klingeln nicht immer gleich klingen). Alles Weitere: docs/ASSET_GUIDE.md („Eigene Geräusche“).

const ROOT := "res://assets/audio/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
## Kanäle (Busse) und welche Ordner dort hinein spielen
const BUSES := ["Music", "Ambience", "Effects", "Voices"]
const FOLDER_BUS := {"music": "Music", "ambience": "Ambience", "voices": "Voices", "sfx/murmur": "Voices"}

## name -> Array[AudioStream] (leer = gibt es nicht; wird nur einmal gesucht)
var _cache := {}


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


## Musik: alle Dateien in assets/audio/music/ nacheinander in zufälliger Reihenfolge (mit kurzer Pause).
func start_music() -> void:
	var tracks := []
	var dir := ROOT + "music/"
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			var name := file.trim_suffix(".import").trim_suffix(".remap")
			if name.get_extension().to_lower() in EXTENSIONS and not tracks.has(dir + name):
				tracks.append(dir + name)
	if tracks.is_empty():
		return
	tracks.shuffle()
	var player := AudioStreamPlayer.new()
	player.name = "Music"
	player.bus = "Music"
	add_child(player)
	var index := [0]
	var play_next := func() -> void:
		player.stream = load(tracks[index[0] % tracks.size()])
		index[0] += 1
		player.play()
	player.finished.connect(func() -> void:
		get_tree().create_timer(GameConfig.music_pause).timeout.connect(play_next))
	play_next.call()


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
	player.max_distance = max_distance
	owner_node.add_child(player)
	return player
