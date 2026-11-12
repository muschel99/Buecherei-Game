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
		"bench_chat":
			# Zwei auf der Bank im Gespräch (seit 6j): misst, wie weit sich der Kopf gegenüber der Brust dreht
			var other := ChibiPasserbyModel.new()
			add_child(other)
			var rng2 := RandomNumberGenerator.new(); rng2.seed = 11
			other.randomize_look(rng2)
			await get_tree().process_frame
			await get_tree().process_frame
			other.position = Vector3(-0.62, 0.0, 0.0)
			for f: ChibiPasserbyModel in [m, other]:
				f.sit_height = 0.25
				f._player_rest_until = 1e9
				f.relaxed_sit = true
			# Die fertige Haltung (mit Kopfdrehung) gibt es nur im Signal skeleton_updated
			for f: ChibiPasserbyModel in [m, other]:
				var sk: Skeleton3D = f._skeleton
				sk.skeleton_updated.connect(func() -> void:
					var hz := sk.get_bone_global_pose(sk.find_bone("Head")).basis.z
					var cz := sk.get_bone_global_pose(sk.find_bone("Hips")).basis.z
					f.set_meta("yaw", rad_to_deg(Vector2(cz.x, cz.z).angle_to(Vector2(hz.x, hz.z)))))
			m.set_chat_partner(other)
			other.set_chat_partner(m)
			m.set_talking(true)
			var worst := 0.0
			for i in 600:
				m.animate(&"sit", 0.0, 1.0 / 30.0)
				other.animate(&"sit", 0.0, 1.0 / 30.0)
				if i == 300:
					m.set_talking(false); other.set_talking(true)
				await get_tree().process_frame
				for f: ChibiPasserbyModel in [m, other]:
					var a: float = f.get_meta("yaw", 0.0)
					worst = maxf(worst, absf(a))
					if i % 60 == 0:
						print("t=%d kopf-gegen-huefte=%.0f blick=%.0f clip=%s" % [i, a, f._head_yaw, f._player.current_animation])
				if i % 100 == 50:
					cam.look_at_from_position(Vector3(-0.31, 1.0, 2.6), Vector3(-0.31, 0.6, 0), Vector3.UP)
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "bench_chat_%d.png" % i))
			print("groesste Kopfdrehung gegen Hüfte: %.0f Grad" % worst)
		"grid":
			# Alle sechs Grundfiguren in drei Körperformen und mehreren Haltungen (seit 6j: Netzfehler suchen)
			m.queue_free()
			var cam2: Camera3D = get_node("Cam")
			var figs: Array[ChibiPasserbyModel] = []
			for i in 6:
				var f := ChibiPasserbyModel.new()
				add_child(f)
				var r := RandomNumberGenerator.new(); r.seed = 20 + i
				f.randomize_look(r)
				f.figure = i as ChibiCharacter.Figure
				f.skin_color = f.skin_color
				f.top = ChibiCharacter.Top.TSHIRT if i % 2 == 0 else ChibiCharacter.Top.SWEATER
				f.bottom = ChibiCharacter.Bottom.SKIRT if i == 1 or i == 2 else ChibiCharacter.Bottom.TROUSERS
				f.hair = [ChibiCharacter.Hair.BOB, ChibiCharacter.Hair.BUN, ChibiCharacter.Hair.PIGTAILS, ChibiCharacter.Hair.SHORT, ChibiCharacter.Hair.SHORT, ChibiCharacter.Hair.BUN][i]
				f.give_bag(false)
				f.position = Vector3((i % 3) * 0.8, 0.0, 0.0 if i < 3 else 50.0)
				figs.append(f)
			await get_tree().process_frame
			await get_tree().process_frame
			var only := String(mode[1]) if mode.size() > 1 else ""
			for shape: float in [-0.9, 0.0, 1.0]:
				for f in figs:
					f.body_shape = shape
				for pose: Array in [[&"walk", 0.35, false], [&"sit_idle", 1.0, true], [&"talk", 1.2, false], [&"pet_reach", 1.6, false], [&"wave", 1.2, false]]:
					if only != "" and only != String(pose[0]):
						continue
					for f in figs:
						f.sit_height = 0.25
						f._player.play(pose[0], 0.0); f._player.seek(pose[1], true); f._player.speed_scale = 0.0
						f.set_skirt_sit(1.0 if pose[2] else 0.0)
					for group in 2:
						var c := Vector3(0.8, 0.6, 50.0 * group)
						for view: Array in [["vorn", Vector3(0.0, 0.25, 1.0)], ["hinten", Vector3(0.2, 0.3, -1.0)], ["seite", Vector3(1.0, 0.2, 0.15)]]:
							cam2.look_at_from_position(c + (view[1] as Vector3).normalized() * 3.1, c, Vector3.UP)
							for k in 3:
								await get_tree().process_frame
							await RenderingServer.frame_post_draw
							var file := "grid_%s_%s_%s_%s.png" % [pose[0], "duenn" if shape < 0.0 else ("mittel" if shape == 0.0 else "dick"), "f" if group == 0 else "m", view[0]]
							get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
			print("Raster fertig")
		"close":
			# Nahaufnahme einer Figur: close <figur 0-5> <form> <clip> <zeit> <höhe> <abstand> [top] [bottom]
			var fi := int(mode[1]); var shape := float(mode[2])
			m.figure = fi as ChibiCharacter.Figure
			m.body_shape = shape
			m.skin_color = m.skin_color
			if mode.size() > 7:
				m.top = int(mode[7]) as ChibiCharacter.Top
			if mode.size() > 8:
				m.bottom = int(mode[8]) as ChibiCharacter.Bottom
			m.give_bag(false)
			m.sit_height = 0.25
			await get_tree().process_frame
			await get_tree().process_frame
			m._player.play(StringName(mode[3]), 0.0); m._player.seek(float(mode[4]), true); m._player.speed_scale = 0.0
			m.set_skirt_sit(1.0 if String(mode[3]).begins_with("sit") else 0.0)
			var cc: Camera3D = get_node("Cam")
			var c := Vector3(0, float(mode[5]), 0)
			for view: Array in [["vorn", Vector3(0.0, 0.15, 1.0)], ["hinten", Vector3(0.0, 0.2, -1.0)], ["links", Vector3(1.0, 0.15, 0.2)], ["rechts", Vector3(-1.0, 0.15, 0.2)], ["unten", Vector3(0.3, -0.5, 1.0)]]:
				cc.look_at_from_position(c + (view[1] as Vector3).normalized() * float(mode[6]), c, Vector3.UP)
				for k in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "close_%d_%s_%s_%s.png" % [fi, mode[3], mode[5], view[0]]))
		"animal":
			# Tier in allen Bewegungen: animal <cat|cat_adult|bird|pigeon> [bewegung,…] [aussehen]
			m.queue_free()
			var scene := load("res://scenes/animals/%s.tscn" % mode[1]) as PackedScene
			var a := scene.instantiate() as StreetAnimal
			add_child(a)
			await get_tree().process_frame
			a.visible = true
			a.set_process(false)
			a.set_physics_process(false)
			var looks: Array = GameConfig.cat_looks
			if String(mode[1]).begins_with("cat") and a.has_method("apply_look"):
				var li := int(mode[3]) if mode.size() > 3 else (3 if mode[1] == "cat_adult" else 0)
				var look: Dictionary = looks[li]
				var fur := "Katze Fell groß" if mode[1] == "cat_adult" else "Katze Fell"
				a.apply_look("probe", {fur: look.fur},
					{fur: {"tabby": float(look.get("tabby", 0.0)), "tabby_color": look.get("tabby_color", Color.WHITE),
						"second_color": look.fur2, "third_color": look.get("back", look.fur), "mask_from": float(look.get("patches", 0.55)),
						"mask_soft": 0.3, "eye_color": look.eye}})
			var list: Array = Array(a.anim.get_animation_list())
			if mode.size() > 2 and String(mode[2]) != "all":
				list = Array(String(mode[2]).split(","))
			var ca: Camera3D = get_node("Cam")
			var size := 0.42 if String(mode[1]).begins_with("cat") else 0.22
			for an: String in list:
				if an == "RESET" or not a.anim.has_animation(an):
					continue
				var length := a.anim.get_animation(an).length
				for part: float in [0.25, 0.7]:
					a.anim.play(an, 0.0); a.anim.seek(length * part, true); a.anim.speed_scale = 0.0
					var k := 0
					for dir: Vector3 in [Vector3(1, 0.35, 0.6), Vector3(-0.2, 0.3, 1.0)]:
						var c := Vector3(0, size * 0.22, 0)
						ca.look_at_from_position(c + dir.normalized() * size * 1.5, c, Vector3.UP)
						for q in 3:
							await get_tree().process_frame
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s_%d_%d.png" % [mode[1], an, int(part * 100), k]))
						k += 1
			print("Tier fertig: ", list)
		"pet":
			# Streicheln mit Hand auf dem Kopf: pet <figur 0-5> <cat|cat_adult> <pet_reach|pet_cat> <zeit> [aus = ohne Ausgleich]
			m.figure = int(mode[1]) as ChibiCharacter.Figure
			m.give_bag(false)
			var cs := load("res://scenes/animals/%s.tscn" % mode[2]) as PackedScene
			var cat := cs.instantiate() as StreetAnimal
			add_child(cat)
			cat.set_process(false)
			cat.set_physics_process(false)
			cat.scale = Vector3.ONE * (1.36 if mode[2] == "cat_adult" else 1.0)
			await get_tree().process_frame
			await get_tree().process_frame
			var clip := StringName(mode[3])
			cat.anim.play(&"sit" if clip == &"pet_reach" else &"lie"); cat.anim.seek(0.6, true); cat.anim.speed_scale = 0.0
			# Katze vor der rechten Hand (wie Passerby.pet_hand)
			var hand: Vector2 = m.pet_hand(clip == &"pet_cat")
			cat.position = Vector3(hand.x, 0.0, hand.y + (0.06 if clip == &"pet_cat" else 0.03))
			cat.rotation.y = PI * 0.5
			m.play_clip(clip)
			if mode.size() <= 5:
				m.set_pet_target(cat)
			var tt := float(mode[4])
			for i in int(tt * 30.0):
				m.animate(&"idle", 0.0, 1.0 / 30.0)
				await get_tree().process_frame
			print("Clip: ", m._player.current_animation, " shot=", m._shot, " upper=", m._upper, " pet=", m._gesture_modifier.pet_weight, " katze sichtbar=", cat.visible)
			cat.visible = true
			m._player.speed_scale = 0.0
			var cp: Camera3D = get_node("Cam")
			var c := cat.position + Vector3(0, 0.35, 0)
			for view: Array in [["seite", Vector3(0.1, 0.25, 1.0)], ["vorn", Vector3(-1.0, 0.3, 0.3)]]:
				cp.look_at_from_position(c + (view[1] as Vector3).normalized() * 1.5, c, Vector3.UP)
				for k in 3:
					m.animate(&"idle", 0.0, 0.0001)
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "pet_%s_%s_%s_%s%s.png" % [mode[1], mode[2], mode[3], view[0], "_aus" if mode.size() > 5 else ""]))
		"bagsit":
			# Taschenträger setzt sich: Tasche wandert auf den Boden neben die Füße (seit 6j)
			m.give_bag(true)
			m.sit_height = 0.25
			await get_tree().process_frame
			var cb: Camera3D = get_node("Cam")
			for step: Array in [["steht", &"idle", 1.0], ["sitzt", &"sit", 2.5], ["auf", &"idle", 2.0]]:
				for i in int(float(step[2]) * 30.0):
					m.animate(step[1], 0.0, 1.0 / 30.0)
					await get_tree().process_frame
				for view: Array in [["vorn", Vector3(-0.3, 0.3, 1.0)], ["seite", Vector3(-1.0, 0.25, 0.2)]]:
					var c := Vector3(-0.1, 0.45, 0.1)
					cb.look_at_from_position(c + (view[1] as Vector3).normalized() * 2.2, c, Vector3.UP)
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "bagsit_%s_%s.png" % [step[0], view[0]]))
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
