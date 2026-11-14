class_name CounterDesk
extends Node3D
## Theken-Ansicht (seit Etappe 8, Wunsch der Entwicklerin: Bedienen soll schön und „satisfying“ sein). E „Bedienen“ hinter
## der Theke, wenn ein Gast wartet: die Kamera rückt weich an die Theke, die Maus ist frei, und alles geht mit Klicks – jeder
## Handgriff mit eigenem Geräusch und kleiner Bewegung:
##   1. Ausweis anklicken: er gleitet in den Kartenleser (Schaben, Klick, Piep), am PC erscheinen Name und Stempelkarte, der
##      neue Stempel ploppt auf (volle Karte: Lesezeichen und mehr Zeit für den Gast)
##   2. Bücher einzeln anklicken: über den Scanner (Piep), dann auf den Stapel
##   3. Stapel anklicken: die Bücher rutschen dem Gast in den Korb – ausgeliehen
## Danach rückt der nächste Gast nach (die Ansicht bleibt) oder sie endet von selbst. Esc verlässt sie vorher (der Gast wartet
## weiter, Erledigtes bleibt erledigt). Hängt an der Theke (Lagen im Raum der Theke: Spielfigur -Z, Gäste +Z).

enum Step { CARD, READING, SCAN, PUSH, DONE }

const CARD_SCENE := "res://scenes/street_life/props/library_card.tscn"
const BOOK_ROW_START := Vector3(-0.27, 0.0, 0.02)
const BOOK_ROW_STEP := 0.085
const PILE := Vector3(-0.04, 0.0, -0.22)
const CARD_START := Vector3(0.28, 0.0, 0.17)
const BASKET := Vector3(0.0, 0.1, 0.15)

var visits: LibraryVisits
var counter: Node3D
var pc: CounterPc
var walker: Passerby
var is_open := false

var _camera: Camera3D
var _player: Node3D
var _player_camera: Camera3D
var _step := Step.CARD
var _busy := false
var _card: Node3D
var _books: Array[Dictionary] = []   # {node, book, scanned}
var _hover: Node3D
var _progress := {}                  # Gast → {"read": bool, "bonus": bool, "scanned": Array[Book]}
var _tween: Tween
var _preview := false                # Prüfwerkzeug: ohne Gast (debug_preview)
var _preview_books: Array[Book] = []


func setup(library_visits: LibraryVisits, counter_node: Node3D) -> void:
	visits = library_visits
	counter = counter_node
	pc = counter.find_child("CounterPc", true, false) as CounterPc
	_camera = Camera3D.new()
	_camera.name = "DeskCamera"
	_camera.fov = GameConfig.desk_camera_fov
	_camera.near = 0.02
	add_child(_camera)


# --- Öffnen und schließen ---

func open(guest: Passerby) -> void:
	if is_open or guest == null:
		return
	is_open = true
	walker = guest
	_player = visits.life.get_player()
	_player_camera = get_viewport().get_camera_3d()
	if _player:
		_player.set("movement_enabled", false)
		_player.set("interaction_enabled", false)
	MenuStack.open(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# weich heranrücken: von der Spielfigur-Kamera zur Theken-Ansicht
	_camera.global_transform = _player_camera.global_transform if _player_camera else _view_transform()
	_camera.fov = _player_camera.fov if _player_camera else GameConfig.desk_camera_fov
	_camera.make_current()
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "global_transform", _view_transform(), GameConfig.desk_camera_time)
	_tween.tween_property(_camera, "fov", GameConfig.desk_camera_fov, GameConfig.desk_camera_time)
	_begin_guest()


func close_from_escape() -> void:
	_close()


func restore_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close() -> void:
	if not is_open:
		return
	is_open = false
	MenuStack.close(self)
	_clear_props()
	if pc:
		pc.screen.show_idle()
	_kill_tween()
	var back := _player_camera
	if back and is_instance_valid(back):
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(_camera, "global_transform", back.global_transform, GameConfig.desk_camera_time * 0.8)
		_tween.tween_property(_camera, "fov", back.fov, GameConfig.desk_camera_time * 0.8)
		_tween.chain().tween_callback(func() -> void:
			back.make_current()
			_give_back_player())
	else:
		_give_back_player()
	walker = null


func _give_back_player() -> void:
	if _player and is_instance_valid(_player):
		_player.set("movement_enabled", true)
		_player.set("interaction_enabled", true)
	MenuStack.restore_mouse_mode()


func _view_transform() -> Transform3D:
	var top := Vector3(0.0, Counter.TOP_HEIGHT, 0.0)
	var eye := counter.global_transform * (GameConfig.desk_camera_eye + top)
	var target := counter.global_transform * (GameConfig.desk_camera_target + top)
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


# --- Ablauf je Gast ---

func _begin_guest() -> void:
	_clear_props()
	_busy = false
	var progress: Dictionary = _progress.get(walker, {"read": false, "bonus": false, "scanned": [] as Array[Book]})
	_progress[walker] = progress
	if walker:
		visits.hand_over_card(walker)
	var books := _preview_books if _preview else visits.visit_books(walker)
	var info := Lending.reader_info(visits.visit_card(walker) if walker else "")
	if progress.read:
		pc.screen.show_card(str(info.get("name", "")), int(info.get("stamps", 0)), bool(progress.bonus))
		pc.screen.pop = 1.0
	else:
		_card = _spawn_card()
	# Bücher aus dem Korb nebeneinander auf die Theke (schon gescannte liegen auf dem Stapel)
	var scanned: Array = progress.scanned
	var i := 0
	for book: Book in books:
		var node := _spawn_book(book)
		var is_scanned := scanned.has(book)
		_books.append({"node": node, "book": book, "scanned": is_scanned})
		if is_scanned:
			node.transform = _pile_transform(book, _scanned_count() - 1)
		else:
			node.transform = _row_transform(book, i)
			i += 1
	visits.show_basket_empty(true)
	if not progress.read:
		_step = Step.CARD
	elif _scanned_count() < _books.size():
		_step = Step.SCAN
		_show_scan()
	else:
		_step = Step.PUSH
		_show_scan()


func _process(_delta: float) -> void:
	if not is_open:
		return
	if not _preview and (walker == null or not is_instance_valid(walker)):
		_close()
		return
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _hover and not _busy:
			_click(_hover)


func _click(target: Node3D) -> void:
	match _step:
		Step.CARD:
			if target == _card:
				_read_card()
		Step.SCAN:
			for entry in _books:
				if entry.node == target and not entry.scanned:
					_scan_book(entry)
					return
		Step.PUSH:
			_push_books()


## 1. Ausweis in den Kartenleser: gleitet hinüber, stellt sich auf und rutscht in den Schlitz; dann Stempel am PC.
func _read_card() -> void:
	_busy = true
	_step = Step.READING
	var slot := pc.reader_slot_global() if pc else counter.global_transform * Vector3(0.4, Counter.TOP_HEIGHT, -0.2)
	var upright := counter.global_transform.basis.orthonormalized()  # Ausweis aufrecht, längs des Schlitzes
	Audio.play_at("ui/card_insert", slot, -4.0, Audio.vary(0.04))
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_card, "global_transform", Transform3D(upright, slot + Vector3.UP * 0.075), GameConfig.desk_card_time)
	_tween.tween_property(_card, "global_position", slot + Vector3.UP * 0.035, 0.18)
	_tween.tween_callback(func() -> void:
		Audio.play_at("ui/card_beep", slot, -8.0)
		var id := visits.visit_card(walker) if walker else ""
		var bonus := Lending.add_stamp(id)
		var progress: Dictionary = _progress[walker]
		progress.read = true
		progress.bonus = bonus
		var info := Lending.reader_info(id)
		pc.screen.show_card(str(info.get("name", "Hattie Bramwell" if _preview else "")), int(info.get("stamps", 3 if _preview else 0)), bonus)
		if bonus:
			Audio.play("ui/kaching", -16.0, 1.3))
	_tween.tween_interval(0.85)
	_tween.tween_callback(func() -> void:
		_busy = false
		_step = Step.SCAN if _scanned_count() < _books.size() else Step.PUSH
		_show_scan())


## 2. Ein Buch über den Scanner: kleiner Bogen hinüber, Piep, dann auf den Stapel.
func _scan_book(entry: Dictionary) -> void:
	_busy = true
	var node: Node3D = entry.node
	var book: Book = entry.book
	var scanner := pc.scanner_global() if pc else counter.global_transform * Vector3(0.2, Counter.TOP_HEIGHT, -0.15)
	var over := Transform3D(node.global_transform.basis, scanner + Vector3.UP * (book.data.size.x / 2.0 + 0.012))
	# erst nach oben abheben (über die anderen Bücher), dann hinüber und auf den Scanner
	var lifted := node.global_position + Vector3.UP * (0.07 + 0.03 * _books.size())
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(node, "global_position", lifted, GameConfig.desk_book_time * 0.35)
	_tween.tween_property(node, "global_transform", over.translated(Vector3.UP * 0.05), GameConfig.desk_book_time * 0.6)
	_tween.tween_property(node, "global_transform", over, GameConfig.desk_book_time * 0.4)
	_tween.tween_callback(func() -> void:
		Audio.play_at("ui/scan", scanner, -6.0, Audio.vary(0.02))
		entry.scanned = true
		(_progress[walker].scanned as Array).append(book)
		_show_scan())
	_tween.tween_interval(0.12)
	var pile := counter.global_transform * _pile_transform(book, _scanned_count())
	_tween.tween_property(node, "global_transform", pile, GameConfig.desk_book_time * 0.7)
	_tween.tween_callback(func() -> void:
		Audio.play_at("books/place", pile.origin, -10.0, Audio.vary(0.08))
		_busy = false
		if _scanned_count() >= _books.size():
			_step = Step.PUSH)


## 3. Alles dem Gast zuschieben: Bücher (und Ausweis) rutschen in den Korb – ausgeliehen.
func _push_books() -> void:
	_busy = true
	_step = Step.DONE
	var target := counter.global_transform * (BASKET + Vector3(0.0, Counter.TOP_HEIGHT, 0.0))
	Audio.play_at("ui/slide", target, -4.0, Audio.vary(0.05))
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for entry in _books:
		var node: Node3D = entry.node
		_tween.tween_property(node, "global_position", target, GameConfig.desk_push_time)
		_tween.tween_property(node, "scale", Vector3.ONE * 0.6, GameConfig.desk_push_time)
	if _card:
		_tween.tween_property(_card, "global_position", target, GameConfig.desk_push_time)
	_tween.chain().tween_callback(func() -> void:
		_clear_props()
		visits.show_basket_empty(false)
		var bonus := bool((_progress.get(walker, {}) as Dictionary).get("bonus", false))
		_progress.erase(walker)
		if walker:
			visits.complete_checkout(walker, bonus)
		pc.screen.show_done())
	_tween.chain().tween_interval(1.1)
	_tween.chain().tween_callback(_next_guest)


## Nächster Gast: wartet schon jemand vorn an der Theke, geht es gleich weiter – sonst endet die Ansicht.
func _next_guest() -> void:
	_busy = false
	if _preview:
		return
	var next := visits.waiting_guest()
	if next and is_open:
		walker = next
		_begin_guest()
	else:
		_close()


func _show_scan() -> void:
	var titles: Array[String] = []
	for entry in _books:
		if entry.scanned:
			titles.append((entry.book as Book).data.title)
	pc.screen.show_scan(titles, _books.size())


func _scanned_count() -> int:
	var n := 0
	for entry in _books:
		if entry.scanned:
			n += 1
	return n


# --- Hervorheben unter der Maus ---

func _clickables() -> Array[Node3D]:
	var result: Array[Node3D] = []
	match _step:
		Step.CARD:
			if _card:
				result.append(_card)
		Step.SCAN:
			for entry in _books:
				if not entry.scanned:
					result.append(entry.node)
		Step.PUSH:
			for entry in _books:
				result.append(entry.node)
	return result


func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var radius := GameConfig.desk_pick_radius * get_viewport().get_visible_rect().size.y / 900.0
	var best: Node3D = null
	var best_d := radius
	if not _busy:
		for node in _clickables():
			if _camera.is_position_behind(node.global_position):
				continue
			var d := _camera.unproject_position(node.global_position).distance_to(mouse)
			if d < best_d:
				best_d = d
				best = node
	# beim Stapel zählt jedes Buch – dann leuchten alle
	var group: Array[Node3D] = []
	if best and _step == Step.PUSH:
		group = _clickables()
	elif best:
		group = [best]
	for node in _all_props():
		var on := group.has(node)
		node.set_meta("hover", on)
		var lift: Vector3 = node.get_meta("lift", Vector3.ZERO)
		var want := Vector3.UP * (0.012 if on else 0.0)
		if not _busy and lift != want:
			node.global_position += want - lift
			node.set_meta("lift", want)
	if best != _hover:
		_hover = best
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if best else Input.CURSOR_ARROW)


func _all_props() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if _card:
		result.append(_card)
	for entry in _books:
		result.append(entry.node)
	return result


# --- Dinge auf der Theke ---

func _spawn_card() -> Node3D:
	var card := (load(CARD_SCENE) as PackedScene).instantiate() as Node3D
	counter.add_child(card)
	card.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.FORWARD, 0.25),
		CARD_START + Vector3(0.0, Counter.TOP_HEIGHT + 0.003, 0.0))
	return card


func _spawn_book(book: Book) -> Node3D:
	var node := MeshInstance3D.new()
	node.mesh = BookLook.get_mesh()
	node.material_override = BookLook.create_single_material(book.data)
	counter.add_child(node)
	return node


## Liegend als lockerer Fächer vor der Spielfigur (Cover oben): jedes Buch ein Stück weiter rechts und auf dem vorigen.
func _row_transform(book: Book, index: int) -> Transform3D:
	var size := book.data.size
	var below := 0.0
	var n := 0
	for entry in _books:
		if n >= index:
			break
		if not entry.scanned:
			below += (entry.book as Book).data.size.x
		n += 1
	var turn := PI / 2.0 + (index - 1) * 0.22
	var basis := (Basis(Vector3.UP, turn) * Basis(Vector3.FORWARD, PI / 2.0)).scaled_local(size)
	return Transform3D(basis, BOOK_ROW_START + Vector3(index * BOOK_ROW_STEP, Counter.TOP_HEIGHT + below + size.x / 2.0 + 0.002,
		-index * 0.03))


## Auf dem Stapel neben dem Scanner (übereinander, leicht verdreht).
func _pile_transform(book: Book, index: int) -> Transform3D:
	var size := book.data.size
	var height := 0.0
	var n := 0
	for entry in _books:
		if entry.scanned and n < index:
			height += (entry.book as Book).data.size.x
			n += 1
	var basis := (Basis(Vector3.UP, PI / 2.0 + 0.15 * sin(index * 2.3)) * Basis(Vector3.FORWARD, PI / 2.0)).scaled_local(size)
	return Transform3D(basis, PILE + Vector3(0.0, Counter.TOP_HEIGHT + height + size.x / 2.0 + 0.002, 0.0))


func _clear_props() -> void:
	for node in _all_props():
		if is_instance_valid(node):
			node.queue_free()
	_books.clear()
	_card = null
	_hover = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


# --- Ohne Ansicht (Prüfwerkzeug: auto_stamp) ---

## Bedient einen Gast ohne Ansicht und ohne Bewegungen (Stempel, Ausleihe).
func auto_serve(guest: Passerby) -> void:
	var bonus := Lending.add_stamp(visits.visit_card(guest))
	visits.complete_checkout(guest, bonus)


## Prüfwerkzeug (desk_probe): die Ansicht ohne Gast öffnen, mit diesen Büchern.
func debug_preview(books: Array[Book]) -> void:
	_preview = true
	_preview_books = books
	_progress[null] = {"read": false, "bonus": false, "scanned": [] as Array[Book]}
	walker = null
	is_open = false
	open_preview()


func open_preview() -> void:
	is_open = true
	_player = visits.life.get_player()
	_player_camera = get_viewport().get_camera_3d()
	_camera.global_transform = _view_transform()
	_camera.fov = GameConfig.desk_camera_fov
	_camera.make_current()
	_begin_guest()


## Prüfwerkzeug: das, was gerade angeklickt werden kann, anklicken.
func debug_click() -> void:
	var targets := _clickables()
	if not targets.is_empty() and not _busy:
		_click(targets[0])
