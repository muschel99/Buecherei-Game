extends Node
## Prüfwerkzeug Hauptmenü (seit dem Wunsch nach Hauptmenü und Story): lädt die Hauptszene wie beim echten Start (mit Hauptmenü).
##   Bilder (xvfb):  xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 --audio-driver Dummy
##                   res://scenes/tools/title_probe.tscn -- shot      → screenshots/title_probe/menu.png, settings.png
##   Neues Spiel:    godot --headless --path . res://scenes/tools/title_probe.tscn -- new
##                   (Geld, Tag und Lager verändern, „Neues Spiel“ wählen, prüfen, ob alles wieder wie am Anfang ist)
##   Story:          … -- story  (dazu den Story-Anfang durchspielen: Spielfigur folgt der Maklerin, Gespräche klicken sich
##                   weiter; danach die To-do-Zettel über die echten Wege des Spiels abarbeiten)
##   To-do-Zettel:   xvfb wie oben, … -- todo   → screenshots/title_probe/todo.png, todo_tick.png

const OUT := "res://screenshots/title_probe/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var args := OS.get_cmdline_user_args()
	TitleScreen.show_on_start = true
	SaveManager.saving_enabled = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
	# dieser Knoten verschwindet mit dem Szenenwechsel – die Prüfung läuft in einem Knoten an der Wurzel weiter
	var runner := Runner.new()
	runner.mode = "shot"
	for mode in ["story", "new", "todo"]:
		if mode in args:
			runner.mode = mode
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var mode := "shot"

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		for i in 60:
			await get_tree().process_frame
		var title := get_tree().current_scene.get_node_or_null("TitleScreen")
		print("Hauptmenü da: ", title != null)
		if mode == "todo":
			title.call("_enter_game")
			Tutorial.start_new_game()
			Tutorial.finish_intro()
			Tutorial.report("tablet")
			for i in 120:
				await get_tree().process_frame
			await _shot("todo")
			Tutorial.report("shelf_ordered")
			for i in 40:
				await get_tree().process_frame
			await _shot("todo_tick")
			get_tree().quit()
			return
		if mode == "shot":
			await _shot("menu")
			title.call("_settings")
			for i in 90:
				await get_tree().process_frame
			await _shot("settings")
			get_tree().quit()
			return
		# Neues Spiel: erst etwas verändern, dann zurücksetzen lassen
		var start_money := Wallet.money
		var start_day := GameClock.day
		Wallet.earn(321, "Test")
		GameClock.day += 3
		Inventory.add_furniture("armchair_min", 2)
		print("vorher: Geld %d, Tag %d, Sessel %d" % [Wallet.money, GameClock.day, Inventory.get_count("armchair_min")])
		title.call("_start_new_game")
		for i in 160:
			await get_tree().process_frame
		var ok := Wallet.money == start_money and GameClock.day == start_day and Inventory.get_count("armchair_min") == 0
		print("nachher: Geld %d, Tag %d, Sessel %d, neues Spiel %s, Hauptmenü %s – %s" % [Wallet.money, GameClock.day,
			Inventory.get_count("armchair_min"), TitleScreen.new_game_started,
			get_tree().current_scene.get_node_or_null("TitleScreen") != null, "in Ordnung" if ok else "FEHLER"])
		if mode == "story":
			await _follow_story()
		get_tree().quit()

	## Story-Anfang durchspielen: die Spielfigur folgt der Maklerin (Spur von vor 1,5 s), Gespräche klicken sich weiter.
	func _follow_story() -> void:
		var story := get_tree().current_scene.get_node_or_null("StoryIntro")
		print("Story: Knoten da %s, intro_done %s" % [story != null, Tutorial.intro_done])
		if story == null:
			return
		Engine.time_scale = 3.0
		var trail: Array[Vector3] = []
		var talked := -1
		var time := 0.0
		var click := 0.0
		var finished_at := -1.0
		while time < 400.0:
			await get_tree().process_frame
			var delta := get_process_delta_time() * Engine.time_scale
			time += delta
			var player := get_tree().get_first_node_in_group(&"player") as Player
			var agent: Passerby = story.get("_agent") if is_instance_valid(story) else null
			if Conversation.current:
				click -= delta
				if click <= 0.0:
					click = 0.25
					if Conversation.current.get("_typing"):
						Conversation.current.call("_finish_line")
					elif not Conversation.current.get("_ending"):
						Conversation.current.call("_next")
				var index: int = story.get("_talk_index") if is_instance_valid(story) else -1
				if index != talked:
					talked = index
					print("  %.0f s: Gespräch an Station %s" % [time, StoryIntro.STATIONS[index] if index >= 0 else "?"])
				continue
			if agent and agent.active:
				trail.append(agent.global_position)
				var lag := int(1.5 / maxf(delta, 0.001))
				if trail.size() > lag and player:
					player.global_position = trail[trail.size() - lag] + Vector3.UP * 0.05
			if Tutorial.intro_done and finished_at < 0.0:
				finished_at = time
				print("  %.0f s: Schlüssel übergeben" % time)
			if finished_at >= 0.0 and (not is_instance_valid(story) or agent == null or not agent.active or not agent.scripted):
				print("  %.0f s: Maklerin ist gegangen" % time)
				break
		Engine.time_scale = 1.0
		print("Story: %s (intro_done %s, %.0f s)" % ["in Ordnung" if Tutorial.intro_done and finished_at >= 0.0 else "FEHLER",
			Tutorial.intro_done, time])
		await _todo_test()

	## To-do-Zettel: die Aufgaben über die echten Wege des Spiels erledigen und zusehen, wie die Zettel weiterwandern.
	func _todo_test() -> void:
		var lists := Tutorial.load_lists()
		var note := get_tree().current_scene.find_children("*", "TodoNote", true, false)
		print("To-do: Zettel im HUD %s, Zettel %d, jetzt „%s“ (Schild offen: %s)" % [not note.is_empty(), lists.size(),
			Tutorial.current_list().get("title", "–"), Lending.is_open])
		var room := Lending.find_room()
		var steps: Array[Callable] = [
			func() -> void:
				var tablet := get_tree().get_first_node_in_group("counter_tablet")
				tablet.call("open_tablet")
				await get_tree().create_timer(0.5).timeout
				tablet.call("close_from_escape"),
			func() -> void:
				get_tree().get_first_node_in_group("delivery_manager").call("place_order",
					[{"kind": "furniture", "id": "bookshelf_oak", "count": 1}]),
			func() -> void: Tutorial.report("unpack"),
			func() -> void:
				var build := get_tree().current_scene.get_node("BuildMode")
				Inventory.add_furniture("bookshelf_oak", 1)  # (wie nach dem Auspacken)
				build.call("set_active", true)
				build.call("select_furniture", Catalog.get_furniture("bookshelf_oak")),
			func() -> void:
				room.add_furniture(Catalog.get_furniture("bookshelf_oak"), room.global_transform * Transform3D(Basis.IDENTITY,
					Vector3(-0.5, 0.0, 3.5)), null),
			func() -> void: get_tree().current_scene.get_node("BuildMode").call("set_active", false),
			func() -> void:
				var crates := room.find_children("*", "GenreCrates", true, false)
				crates[0].call("_take", BookStock.get_unlocked_genres()[0].get_id()),
			func() -> void:
				for shelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
					if room.is_ancestor_of(shelf):
						shelf.call("put_carried"),  # wie Linksklick halten am Regal
			func() -> void: Lending.set_open(true),
			func() -> void:
				Tutorial.report("guest_waiting")  # (Glocke – braucht einen echten Gast)
				Tutorial.report("desk_open"),
			func() -> void: Tutorial.report("guest_served"),
			func() -> void: Tutorial.report("talked"),
			func() -> void: Tutorial.report("sat_down"),
			func() -> void: GameClock.woke_up.emit(),
		]
		var last_title := String(Tutorial.current_list().get("title", ""))
		for step in steps:
			await step.call()
			for i in 90:  # Prüfung alle 0,5 s, fertiger Zettel bleibt todo_next_delay hängen
				await get_tree().process_frame
			await get_tree().create_timer(GameConfig.todo_next_delay + 0.8).timeout
			var title := String(Tutorial.current_list().get("title", "–"))
			var done := Tutorial.events.keys()
			print("  erledigt: %s → Zettel „%s“" % [", ".join(PackedStringArray(done)), title])
			last_title = title
		var all_done := Tutorial.list_index >= lists.size()
		print("To-do: %s (Zettel %d von %d)" % ["in Ordnung" if all_done else "FEHLER", Tutorial.list_index, lists.size()])

	func _shot(name_: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name_ + ".png"))
		print("Bild: ", name_)
