extends Node3D
## Messwerkzeug (seit Testrunde 7b): Wie lange braucht das erste Bild der Fassaden-Vorschau (FacadePreview), wenn die gleiche
## Fassade im Spiel schon gezeichnet wird? Stellt die Bücherei-Fassade in die Hauptwelt (Kantenglättung wie im Spiel), wartet,
## bis sie gezeichnet ist, öffnet dann die Vorschau und misst das längste Bild danach.
##   xvfb-run -a godot --path . --audio-driver Dummy res://scenes/tools/facade_probe.tscn -- [msaa=old]
## msaa=old = Vorschau mit eigener Kantenglättung (MSAA 2x, wie vor Testrunde 7b), msaa=taa = nur TAA wie das Spiel – zum Vergleich.

var _args := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_args[arg.get_slice("=", 0)] = arg.get_slice("=", 1)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	add_child(env)
	var light := DirectionalLight3D.new()
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-40, 30, 0)
	add_child(light)
	var facade := LibraryFacade.new()
	facade.follow_design = false
	facade.build(FacadeDesign.get_draft())
	add_child(facade)
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(-8, 3, -8), Vector3(-2, 2, -2))
	_run.call_deferred()


func _run() -> void:
	var root := get_tree().root
	print("Hauptbild: MSAA %d, TAA %s, FXAA %s" % [root.msaa_3d, root.use_taa, root.screen_space_aa])
	for i in 60:
		await get_tree().process_frame
	var preview := FacadePreview.new()
	if _args.get("msaa", "") == "old":
		preview.msaa_3d = Viewport.MSAA_2X
		preview.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	elif _args.get("msaa", "") == "taa":
		preview.use_taa = root.use_taa
		preview.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	var dummy_room := Node3D.new()
	add_child(dummy_room)
	add_child(preview)
	var start := Time.get_ticks_msec()
	preview.prepare(dummy_room)
	preview.show_design(FacadeDesign.get_draft())
	var last := Time.get_ticks_usec()
	var longest := 0.0
	var total := 0.0
	for i in 30:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var frame := (now - last) / 1000.0
		last = now
		longest = maxf(longest, frame)
		total += frame
	var image := preview.get_texture().get_image()
	if image:  # ohne Bildschirm (headless) gibt es kein Bild
		image.save_png(ProjectSettings.globalize_path("res://screenshots/facade_probe.png"))
	print("VORSCHAU (%s): längstes Bild %.0f ms, 30 Bilder zusammen %.0f ms (Aufbau %d ms)" % [
		_args.get("msaa", "neu"), longest, total, Time.get_ticks_msec() - start])
	get_tree().quit()
