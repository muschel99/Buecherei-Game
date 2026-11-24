extends Node
## Bedienen echter Gäste an der Theke (seit Etappe 8d, nach dem Fehler „das Spiel stoppt beim Bedienen“): öffnet die Bücherei,
## lässt Besucher kommen, wartet, bis einer vorn an der Theke steht, und bedient ihn mit echten Klicks (Ausweis, Bücher, Tüte),
## dann den nächsten – drei Gäste. Anders als desk_probe (Vorschau ohne Gast) laufen hier Korb, Ausleihe und Nachrücken mit.
## Ohne Bilder; Script-Fehler stehen in der Ausgabe (mit Godot 4.6.2 prüfen, siehe CLAUDE.md):
##   godot --headless --path . res://scenes/tools/serve_probe.tscn

var _main: Node


func _ready() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_run.call_deferred()


func _run() -> void:
	for i in 30:
		await get_tree().process_frame
	GameClock.load_save_data({"day": 1, "minute": 10.0 * 60.0})
	GameClock.running = false
	Lending.set_open(true)
	Lending.debug_add_visits(4)
	var room := Lending.find_room()
	for entry: Array in [["bookshelf_country", Vector3(2.7, 0, -1.0), -PI / 2.0], ["bookshelf_min_tall", Vector3(-2.75, 0, 1.6), PI / 2.0]]:
		var data := Catalog.get_furniture(String(entry[0]))
		if data and room:
			room.add_furniture(data, Transform3D(Basis(Vector3.UP, float(entry[2])), entry[1]), null)
	await get_tree().physics_frame
	for shelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
		(shelf as BookShelf).set_genre(BookShelf.MIXED)
		print("Regal gefüllt: %d Bücher" % (shelf as BookShelf).fill_from_storage())
	LibraryVisits.debug = true
	var desk := _main.find_child("CounterDesk", true, false) as CounterDesk
	var visits: LibraryVisits = desk.visits
	Engine.time_scale = 4.0
	var served := 0
	var waited := 0.0
	while served < 3 and waited < 400.0:
		await get_tree().create_timer(0.5, true, false, true).timeout
		waited += 0.5
		var guest := visits.waiting_guest()
		if guest == null or desk.is_open:
			continue
		print("Gast wartet an der Theke: ", guest.name, " nach ", waited, " s")
		Engine.time_scale = 1.0
		desk.open(guest)
		var clicks := 0
		var t := 0.0
		while desk.is_open and t < 60.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			if not desk.get("_busy"):
				var before := int(desk.get("_step"))
				desk.debug_click()
				if int(desk.get("_step")) != before or desk.get("_busy"):
					clicks += 1
					print("  Klick ", clicks, " Schritt ", before, " -> ", int(desk.get("_step")))
		print("Bedienung fertig: offen=", desk.is_open, " Klicks=", clicks)
		served += 1
		Engine.time_scale = 4.0
	print("Bedient: ", served)
	get_tree().quit()
