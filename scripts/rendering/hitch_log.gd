class_name HitchLog
extends Node
## Ruckel-Protokoll (seit der Überarbeitung): Braucht ein Bild länger als GameConfig.hitch_log_threshold
## (Ruckler) oder viel länger (Hänger), schreibt das Spiel still eine Zeile nach `user://hitches.log`:
## wie lange, wo die Spielfigur war, ob die Grafikkarte gerade Shader vorbereiten musste (Pipelines), wie viel
## Zeit Scripts/Physik brauchten, wie viele Objekte neu entstanden sind – und was kurz vorher passiert ist
## (`HitchLog.note("Speichern 120 ms")` aus anderen Scripts).
## Fedora: ~/.local/share/godot/app_userdata/Cozy Bücherei/hitches.log – die Datei einfach an Claude geben.
## main.gd legt den Knoten an (GameConfig.hitch_log_enabled).

const PATH := "user://hitches.log"
## So viele Zeilen je Spielstart höchstens (die Datei soll klein bleiben).
const MAX_LINES := 300
## Die ersten Sekunden nach dem Start zählen nicht (da lädt noch alles).
const WARMUP := 8.0

## Letzte Ereignisse (Text + Zeitpunkt), die kurz vor einem Ruckler passiert sind.
static var _events: Array = []

var _last_usec := 0
var _since_start := 0.0
var _lines := 0
var _file: FileAccess
var _last_monitors := {}

const MONITORS := {
	"pipe_canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"pipe_mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"pipe_surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"pipe_draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"pipe_special": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
	"objects": Performance.OBJECT_COUNT,
	"nodes": Performance.OBJECT_NODE_COUNT,
}


## Merkt sich ein Ereignis (z. B. „Speichern 85 ms“) – steht beim nächsten Ruckler mit im Protokoll.
static func note(text: String) -> void:
	_events.append([Time.get_ticks_msec(), text])
	if _events.size() > 12:
		_events.pop_front()


## Misst, wie lange etwas dauert: `var t := HitchLog.begin()` … `HitchLog.end(t, "Atlas")` – notiert nur,
## wenn es länger als 15 ms war.
static func begin() -> int:
	return Time.get_ticks_usec()


static func end(start_usec: int, what: String) -> void:
	var ms := (Time.get_ticks_usec() - start_usec) / 1000.0
	if ms >= 15.0:
		note("%s %.0f ms" % [what, ms])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000  # vor allen anderen messen
	_last_usec = Time.get_ticks_usec()
	_read_monitors()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_usec) / 1000.0
	_last_usec = now
	_since_start += delta
	var changes := _read_monitors()
	if _since_start < WARMUP or _lines >= MAX_LINES:
		return
	if frame_ms < GameConfig.hitch_log_threshold * 1000.0:
		return
	if not get_window().has_focus():
		return  # Fenster im Hintergrund: Bilder kommen absichtlich langsamer
	_write(frame_ms, changes)


func _read_monitors() -> Dictionary:
	var changes := {}
	for key: String in MONITORS:
		var value := Performance.get_monitor(MONITORS[key])
		changes[key] = value - float(_last_monitors.get(key, value))
		_last_monitors[key] = value
	return changes


func _write(frame_ms: float, changes: Dictionary) -> void:
	if _file == null:
		_file = FileAccess.open(PATH, FileAccess.READ_WRITE if FileAccess.file_exists(PATH) else FileAccess.WRITE)
		if _file == null:
			return
		_file.seek_end()
		_file.store_line("")
		_file.store_line("=== Spielstart %s, Godot %s, %s ===" % [Time.get_datetime_string_from_system(),
			Engine.get_version_info().string, RenderingServer.get_video_adapter_name()])
	var kind := "HÄNGER" if frame_ms >= 500.0 else "Ruckler"
	var pipes := int(changes.pipe_canvas + changes.pipe_mesh + changes.pipe_surface + changes.pipe_draw
		+ changes.pipe_special)
	var parts: Array[String] = []
	parts.append("%s %.0f ms" % [kind, frame_ms])
	parts.append("Uhr %s" % _clock_text())
	parts.append("Ort %s" % _player_text())
	parts.append("Scripts %.0f ms, Physik %.0f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	if pipes > 0:
		parts.append("Shader vorbereitet: %d (Fläche %d, Mesh %d, Zeichnen %d, 2D %d, Spezial %d)" % [pipes,
			int(changes.pipe_surface), int(changes.pipe_mesh), int(changes.pipe_draw), int(changes.pipe_canvas),
			int(changes.pipe_special)])
	if int(changes.nodes) != 0 or absf(changes.objects) >= 50:
		parts.append("Knoten %+d, Objekte %+d" % [int(changes.nodes), int(changes.objects)])
	var recent: Array[String] = []
	var now_ms := Time.get_ticks_msec()
	for event: Array in _events:
		if now_ms - int(event[0]) <= int(frame_ms) + 400:
			recent.append(str(event[1]))
	if not recent.is_empty():
		parts.append("vorher: " + ", ".join(recent))
	_file.store_line(" | ".join(parts))
	_file.flush()
	_lines += 1


func _clock_text() -> String:
	var clock := get_node_or_null("/root/GameClock")
	if clock and clock.has_method("time_text"):
		return str(clock.call("time_text"))
	return "-"


func _player_text() -> String:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return "-"
	var p := player.global_position
	var where := "drinnen" if p.y > -0.25 else "draußen"
	return "%s (%.0f, %.0f)" % [where, p.x, p.z]


func _exit_tree() -> void:
	if _file:
		_file.close()
