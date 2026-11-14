extends Node
## Prüfbilder der Theken-Ansicht (seit Etappe 8) ohne echten Gast: öffnet sie mit drei Büchern aus dem Lager, klickt
## Ausweis, Bücher und Stapel nacheinander an und fotografiert jeden Schritt nach screenshots/desk_probe/.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 --audio-driver Dummy res://scenes/tools/desk_probe.tscn

const OUT := "res://screenshots/desk_probe/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	for i in 30:
		await get_tree().process_frame
	var desk := main.find_child("CounterDesk", true, false) as CounterDesk
	if desk == null:
		push_error("Keine Theken-Ansicht gefunden")
		get_tree().quit()
		return
	var books: Array[Book] = []
	for genre in BookStock.get_unlocked_genres():
		for book in BookStock.get_stored_books(genre.get_id()):
			if books.size() < 3:
				books.append(book)
	desk.debug_preview(books)
	await _wait(1.0)
	await _shot("1_ansicht")
	desk.debug_click()
	await _settle(desk)
	await _shot("2_ausweis")
	desk.debug_click()
	await _wait(0.25)
	await _shot("3_scannen")
	await _settle(desk)
	for i in books.size() - 1:
		desk.debug_click()
		await _settle(desk)
	await _shot("4_gescannt")
	desk.debug_click()
	await _settle(desk)
	await _wait(0.5)
	await _shot("5_fertig")
	get_tree().quit()


## Warten, bis der Handgriff fertig ist (Bewegungen laufen in Echtzeit, die Bilder kommen ohne Grafikkarte langsam).
func _settle(desk: CounterDesk) -> void:
	await get_tree().process_frame
	while desk.get("_busy"):
		await get_tree().process_frame
	for i in 3:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("Bild: ", name)
