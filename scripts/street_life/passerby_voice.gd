class_name PasserbyVoice
extends RefCounted
## Kurze Laute der Passanten (seit Etappe 6e, ersetzt das selbst erzeugte Gemurmel): keine Wörter, nur
## Lachen, Kichern, „hm“ und „oh“ – passend zum Anlass (Gesichtsausdruck aus FaceTriggers) und sparsam:
## je Figur höchstens alle passerby_voice_cooldown Sekunden, insgesamt nie zwei Laute kurz nacheinander.
## Dateien: assets/audio/voices/ (Audio-System, Lautstärke „Stimmen“); fehlt eine, bleibt es still.

## Anlass → [Wahrscheinlichkeit, Laut für Frauen, Laut für Männer] (leer = kein Laut)
const LINES := {
	&"chat_laugh": [0.7, ["voices/laugh_female", "voices/giggle_female"], ["voices/laugh_female_2"]],
	&"chat_listen": [0.25, ["voices/hmm_male"], ["voices/hmm_male"]],
	&"window_wonder": [0.6, ["voices/oh_female"], ["voices/hmm_male"]],
	&"watch": [0.3, ["voices/hmm_male"], ["voices/hmm_male"]],
}
## Tonhöhe je Stimme: Männer ein wenig tiefer (das Lachen ist eine Frauenstimme), Frauen beim „hm“ höher
const PITCH := {"female_hmm": 1.22, "male_laugh": 0.86}

static var _last_any := -100.0


## Spielt (vielleicht) einen Laut zum Anlass trigger an der Figur (Kopfhöhe head). female = Frauenstimme.
## last = Zeit des letzten Lauts dieser Figur (Sekunden); liefert die neue Zeit (oder last, wenn still).
static func speak(figure: Node3D, trigger: StringName, female: bool, head: float, last: float) -> float:
	if not LINES.has(trigger) or figure == null or not figure.is_visible_in_tree():
		return last
	var now := Time.get_ticks_msec() / 1000.0
	if now - last < GameConfig.passerby_voice_cooldown or now - _last_any < GameConfig.passerby_voice_gap:
		return last
	var line: Array = LINES[trigger]
	if randf() > float(line[0]) * GameConfig.passerby_voice_chance:
		return last
	var names: Array = line[1] if female else line[2]
	if names.is_empty():
		return last
	var sound: String = names[randi() % names.size()]
	var pitch := Audio.vary(0.05)
	if female and sound.contains("hmm"):
		pitch *= PITCH.female_hmm
	elif not female and sound.contains("laugh"):
		pitch *= PITCH.male_laugh
	var player := Audio.play_on(figure, sound, GameConfig.passerby_voice_volume_db, pitch, GameConfig.passerby_voice_distance,
		Vector3(0.0, head, 0.0))
	if player == null:
		return last
	_last_any = now
	return now
