extends Node
## Prüfbilder eines Gesprächs (seit Etappe 8): sucht den nächsten Passanten, stellt die Spielfigur vor ihn, beginnt ein
## Gespräch (mit Frage) und fotografiert Sprechblase und Antworten nach screenshots/talk_probe/.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 --audio-driver Dummy res://scenes/tools/talk_probe.tscn

const OUT := "res://screenshots/talk_probe/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	for i in 40:
		await get_tree().process_frame
	var player := main.get_node("Player") as Node3D
	var life := main.get_node("Outside/StreetLife") as StreetLife
	var best: Passerby = null
	for _try in 200:
		for node in life.find_children("*", "Passerby", true, false):
			var p := node as Passerby
			if p and p.can_talk() and p.get_action_type() == "walk":
				best = p
				break
		if best:
			break
		await get_tree().process_frame
	if best == null:
		push_error("Kein Passant zum Reden gefunden")
		get_tree().quit()
		return
	# Spielfigur vor den Passanten stellen
	var front := best.global_position + best.global_basis.z * 1.4
	player.global_position = Vector3(front.x, best.global_position.y, front.z)
	if "wunsch" in OS.get_cmdline_user_args():
		# Gedankenblase eines Gasts mit Wunsch (seit Etappe 8): erst „?“, dann das Genre-Zeichen
		var lib := life.library
		lib._visit[best] = {"books": [] as Array[Book], "wish": {"genre": "crime", "state": "open"}, "style": "stoebert"}
		best.in_library = true
		Conversation.begin(best, player, [{"text": "…"}])
		await _wait(1.5)
		await _shot("w1_frage")
		(lib._visit[best].wish as Dictionary).state = "accepted"
		await _wait(1.0)
		await _shot("w2_zeichen")
		get_tree().quit()
		return
	var steps := Conversation.default_steps(RandomNumberGenerator.new())
	var question := TalkLines.pick("frage", 12.0, RandomNumberGenerator.new())
	steps.insert(steps.size() - 1, {"text": question.text, "answers": question.answers})
	var talk := Conversation.begin(best, player, steps)
	if talk == null:
		push_error("Gespräch kam nicht zustande")
		get_tree().quit()
		return
	await _wait(0.6)
	await _shot("1_tippt")
	await _wait(2.5)
	await _shot("2_satz")
	# bis zur Frage weiterklicken
	for i in steps.size():
		if talk.get("_waiting_answer"):
			break
		_advance()
		await _wait(0.2)
		_advance()
		await _wait(0.3)
	await _wait(0.8)
	await _shot("3_frage")
	get_tree().quit()


func _advance() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("Bild: ", name)
