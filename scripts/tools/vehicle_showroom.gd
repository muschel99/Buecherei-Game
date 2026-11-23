extends Node3D
## Fahrzeug-Ausstellung (Prüfwerkzeug seit „Modelle schöner“): alle Autos aus GameConfig.car_scenes und der Lieferwagen
## nebeneinander auf einer Fläche, mit Sonne und Himmel wie im Spiel. Bilder (xvfb):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 --audio-driver Dummy
##     res://scenes/tools/vehicle_showroom.tscn -- [front|side|back|close]   → screenshots/vehicles/<blick>.png

const OUT := "res://screenshots/vehicles/"
const GAP := 3.0

var _cars: Array[Node3D] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.52, 0.84)
	sky_mat.sky_horizon_color = Color(0.9, 0.86, 0.8)
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = GameConfig.light_sun_color
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, 36, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.62, 0.58, 0.54)
	ground.material_override = gmat
	add_child(ground)
	var scenes: Array[String] = []
	scenes.append_array(GameConfig.car_scenes)
	scenes.append(GameConfig.delivery_van_scene)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var x := -float(scenes.size() - 1) * GAP / 2.0
	for path in scenes:
		var car := (load(path) as PackedScene).instantiate() as Node3D
		add_child(car)
		car.position = Vector3(x, 0, 0)
		if car.has_method("set_active"):
			car.call("set_active", true)  # im Spiel blendet StreetLife die Wagen erst beim Losfahren ein
		if car.has_method("randomize_look"):
			car.call("randomize_look", rng, GameConfig.delivery_van_color if path == GameConfig.delivery_van_scene else Color(0.5, 0.62, 0.8))
		_cars.append(car)
		x += GAP
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	_shoot.call_deferred()


func _shoot() -> void:
	var args := OS.get_cmdline_user_args()
	var views := {"front": [Vector3(4, 3, 12), Vector3(0, 0.8, 0)], "side": [Vector3(0, 1.6, 13), Vector3(0, 0.8, 0)],
		"back": [Vector3(-5, 3, -11), Vector3(0, 0.8, 0)]}
	for name_: String in (args if not args.is_empty() else ["front", "side", "back"]):
		if name_ == "close":
			for i in _cars.size():
				var c := _cars[i].position
				await _shot(c + Vector3(3.2, 1.6, 4.2), c + Vector3(0, 0.75, 0), "close_%d" % i)
				await _shot(c + Vector3(-3.6, 1.2, -3.4), c + Vector3(0, 0.75, 0), "close_%d_back" % i)
			continue
		if views.has(name_):
			await _shot(views[name_][0], views[name_][1], name_)
	get_tree().quit()


func _shot(eye: Vector3, target: Vector3, name_: String) -> void:
	var cam := get_node("Cam") as Camera3D
	cam.look_at_from_position(eye, target, Vector3.UP)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name_ + ".png"))
	print("Bild: ", name_)
