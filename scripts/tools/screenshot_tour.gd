extends Node
## Testbilder aus festen Blickwinkeln (seit Etappe 4f) – für die Selbstkontrolle von Claude.
## Lädt die Hauptszene, stellt eine eigene Kamera nacheinander an die Blickpunkte aus
## ScreenshotViews und speichert je ein Bild. Danach beendet sich das Spiel von selbst.
##
## Starten (am einfachsten über tools/screenshots.sh, das auch den unsichtbaren Bildschirm
## startet):
##   godot --path . res://scenes/tools/screenshot_tour.tscn -- --set=street_end
## Angaben nach "--":
##   --set=<name>       Gruppe von Blickpunkten aus ScreenshotViews (Standard: overview)
##   --only=<a,b>       nur diese Blickpunkte der Gruppe
##   --cam=x,y,z:tx,ty,tz  zusätzlicher freier Blickpunkt (Kamera : Zielpunkt), Name "cam"
##   --out=<ordner>     Ordner für die Bilder (Standard: screenshots/ im Projekt)
##   --tag=<wort>       Zusatz im Dateinamen, z. B. "vorher" -> street_end-bound_road-vorher.png
##   --fov=<grad>       Bildwinkel (Standard: wie die Spielfigur)
##   --hud              Oberfläche (HUD) mit aufnehmen
##   --list             nur die Gruppen und Blickpunkte auflisten
## Die Spielfigur bleibt stehen, wo sie ist; gespeichert wird nichts.

const MAIN_SCENE := "res://scenes/main.tscn"
## So viele Bilder warten, bis alles aufgebaut ist (Atlas, Häuser, Schatten).
const WARMUP_FRAMES := 40
## So viele Bilder je Blickpunkt warten (Schatten und Kantenglättung beruhigen sich).
const SETTLE_FRAMES := 12

var _args := {}
var _camera: Camera3D


func _ready() -> void:
	_args = _parse_args()
	if _args.has("list"):
		for set_name in ScreenshotViews.all_sets():
			print("%s: %s" % [set_name, ", ".join(ScreenshotViews.get_set(set_name).keys())])
		get_tree().quit()
		return
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(main)
	_freeze_player(main)
	_camera = Camera3D.new()
	_camera.name = "TourCamera"
	_camera.fov = float(_args.get("fov", GameConfig.camera_fov))
	_camera.near = 0.03
	_camera.far = 400.0
	main.add_child(_camera)
	_camera.make_current()
	if not _args.has("hud"):
		_hide_interface(get_tree().root)
	_run.call_deferred()


func _run() -> void:
	await _wait_frames(WARMUP_FRAMES)
	var out_dir := String(_args.get("out", ProjectSettings.globalize_path("res://screenshots")))
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Godot soll die Bilder im Projekt nicht importieren
	if not FileAccess.file_exists(out_dir.path_join(".gdignore")):
		FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)
	var views := _collect_views()
	for view_name in views:
		var view: Dictionary = views[view_name]
		_camera.global_position = view.pos
		_camera.look_at(view.target, Vector3.UP)
		_camera.fov = float(view.get("fov", _camera.fov))
		await _wait_frames(SETTLE_FRAMES)
		var image := get_viewport().get_texture().get_image()
		var file := "%s-%s" % [_args.get("set", "free"), view_name]
		if _args.has("tag"):
			file += "-" + String(_args.tag)
		var path := out_dir.path_join(file + ".png")
		image.save_png(path)
		print("Bild gespeichert: ", path)
	get_tree().quit()


## Blickpunkte aus der gewählten Gruppe (+ freier Blickpunkt aus --cam).
func _collect_views() -> Dictionary:
	var views := {}
	if not _args.has("cam") or _args.has("set"):
		var all := ScreenshotViews.get_set(String(_args.get("set", "overview")))
		var only: PackedStringArray = String(_args.get("only", "")).split(",", false)
		for view_name in all:
			if only.is_empty() or view_name in only:
				views[view_name] = all[view_name]
	if _args.has("cam"):
		var parts := String(_args.cam).split(":")
		views["cam"] = {"pos": _vec(parts[0]), "target": _vec(parts[1])}
	return views


func _vec(text: String) -> Vector3:
	var n := text.split_floats(",")
	return Vector3(n[0], n[1], n[2])


## Spielfigur anhalten und ihre Kamera abgeben (sie bleibt sonst die aktive Kamera).
func _freeze_player(main: Node) -> void:
	var player := main.get_node_or_null("Player")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED


## Alle Oberflächen (HUD, Menüs) ausblenden – nur die Spielwelt soll aufs Bild.
func _hide_interface(root: Node) -> void:
	for child in root.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		else:
			_hide_interface(child)


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		var clean := arg.trim_prefix("--")
		var eq := clean.find("=")
		if eq == -1:
			result[clean] = true
		else:
			result[clean.substr(0, eq)] = clean.substr(eq + 1)
	return result
