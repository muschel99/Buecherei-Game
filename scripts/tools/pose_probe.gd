extends Node3D
## Prüfbilder einzelner Haltungen der Chibi-Figuren (seit Etappe 6i): Animation an festen Zeitpunkten, Gesten (Fegen, Umarmen,
## Trinken) und Gegenstände in der Hand – viel schneller als Bilder der ganzen Straße.
## Start: xvfb-run -a -s "-screen 0 700x700x24" godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##   --resolution 700x700 --audio-driver Dummy res://scenes/tools/pose_probe.tscn -- <water|doors|sweep|hug|drink>
## Bilder: screenshots/poses/
const OUT := "res://screenshots/poses/"
var shots := []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_go.call_deferred()

func _pose(m, clip, t, cam_dir := Vector3(1, 0.25, 1), label := ""):
	m._player.play(clip, 0.0)
	m._player.seek(t, true)
	m._player.speed_scale = 0.0
	await _shot(m, cam_dir, label if label != "" else "%s_%.1f" % [clip, t])

func _shot(m, cam_dir, name_):
	var cam: Camera3D = get_node("Cam")
	var c := Vector3(0, 0.85, 0)
	cam.look_at_from_position(c + cam_dir.normalized() * 2.4, c, Vector3.UP)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name_ + ".png"))
	print("Bild: ", name_)

func _go():
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-50, 30, 0)
	var e := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.7, 0.8, 0.9); env.ambient_light_color = Color.WHITE; env.ambient_light_energy = 0.8; e.environment = env; add_child(e)
	var cam := Camera3D.new(); cam.name = "Cam"; cam.fov = 40.0; add_child(cam); cam.make_current()
	var m := ChibiPasserbyModel.new()
	add_child(m)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	m.randomize_look(rng)
	await get_tree().process_frame
	await get_tree().process_frame
	var mode := OS.get_cmdline_user_args()
	var which := String(mode[0]) if mode.size() > 0 else "water"
	match which:
		"water":
			m.set_prop(&"can")
			for t in [0.5, 1.5, 2.5, 3.5, 4.5]:
				await _pose(m, &"water", t)
			await _pose(m, &"water", 2.5, Vector3(-1, 0.2, 0.2), "water_side")
		"doors":
			for clip in [&"door_in", &"door_out"]:
				for t in [0.5, 1.0, 1.5, 2.0, 3.0]:
					await _pose(m, clip, t, Vector3(1, 0.2, 0.7))
		"sweep":
			m.set_prop(&"broom")
			m._chore = "sweep"
			m._gesture_modifier.body_scale = m._hip_height / 0.607
			m._gesture_modifier.gesture = ChibiGestureModifier.Gesture.SWEEP
			m._gesture_modifier.weight = 1.0
			m._gesture = ChibiGestureModifier.Gesture.SWEEP
			m._gesture_left = 100.0
			m._player.play(&"idle", 0.0); m._player.seek(1.0, true); m._player.speed_scale = 0.0
			for tt in [0.0, 0.6, 1.2]:
				m._gesture_time = tt
				m._gesture_modifier.time = tt
				m._update_chore(0.0)
				for d in [Vector3(1,0.3,1), Vector3(0.1,0.3,1), Vector3(-1,0.2,0.1)]:
					await _shot(m, d, "sweep_%.1f_%d" % [tt, int(d.x * 10)])
		"hug":
			var other := ChibiPasserbyModel.new()
			add_child(other)
			var rng2 := RandomNumberGenerator.new(); rng2.seed = 11
			other.randomize_look(rng2)
			await get_tree().process_frame
			await get_tree().process_frame
			other.position = Vector3(0.5, 0.0, 0.0)
			for fig: Array in [[m, 1.0], [other, -1.0]]:
				var f: ChibiPasserbyModel = fig[0]
				f._gesture_modifier.body_scale = f._hip_height / 0.607
				f._gesture_modifier.gesture = ChibiGestureModifier.Gesture.HUG
				f._gesture_modifier.weight = 1.0
				f._gesture_modifier.hug_side = fig[1]
				f._player.play(&"idle", 0.0); f._player.seek(1.0, true); f._player.speed_scale = 0.0
			await _shot(m, Vector3(0.2, 0.3, 1), "hug_front")
			await _shot(m, Vector3(-0.3, 0.6, -1), "hug_back")
		"drink":
			m.set_prop(&"mug")
			m._gesture_modifier.body_scale = m._hip_height / 0.607
			m._gesture_modifier.gesture = ChibiGestureModifier.Gesture.DRINK
			m._gesture_modifier.weight = 1.0
			m.sit_height = 0.25
			m._player.play(&"sit_idle", 0.0); m._player.seek(1.0, true); m._player.speed_scale = 0.0
			m._gesture_modifier.grip_right = 1.0
			m._gesture_modifier.sip = 1.0
			await _shot(m, Vector3(1, 0.3, 1), "drink_up")
			await _shot(m, Vector3(-1, 0.3, 0.2), "drink_side")
			m._gesture_modifier.sip = 0.0
			await _shot(m, Vector3(1, 0.3, 1), "drink_low")
	get_tree().quit()
