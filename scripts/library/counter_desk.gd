class_name CounterDesk
extends Node3D
## Theken-Ansicht (seit Etappe 8; seit dem Nachtest von Etappe 8 neu aufgeteilt, Wünsche der Entwicklerin). E „Bedienen“ hinter
## der Theke, wenn ein Gast wartet: Die Kamera rückt weich heran – mittig hinter der Theke, gerade nach vorn, der untere Bildrand
## liegt an der Thekenkante (_view_transform). Die Maus ist frei, alles geht mit Klicks, jeder Handgriff mit Geräusch und Bewegung.
## Aufteilung der Theke aus Sicht der Spielfigur (rechts = -X im Raum der Theke):
##   rechts  Tablet auf dem Ständer, links daneben der Kartenleser (ShopTablet, verschiebbares Möbel – Standardplatz in der Szene)
##           Korb des Gasts (LibraryVisits stellt ihn auf BASKET), davor seine Bücher als Stapel (BOOKS)
##   Mitte   Scanner, um 90° gedreht (SCANNER, Modell in counter.tscn)
##   links   offene Papiertüte (BAG), daneben ein Stapel gefalteter Tüten (counter.tscn)
## Ablauf:
##   1. Ausweis anklicken: er gleitet in den Kartenleser (Schaben, Piep), das Tablet zeigt „Bücherei-Ausleihe“ mit Name und
##      Stempelkarte, der neue Stempel ploppt auf (volle Karte: Lesezeichen und mehr Zeit); dann hüpft der Ausweis in die Tüte
##   2. Bücher anklicken (immer das oberste): von rechts nach links über den Scanner (Piep), dann in die Tüte
##   3. Tüte anklicken: sie rutscht dem Gast hinüber (er trägt sie hinaus), der Korb gleitet unten rechts aus dem Bild –
##      hinter die Theke – und es macht „Kaching“
## Danach rückt der nächste Gast nach oder die Ansicht endet. Esc verlässt sie vorher (der Gast wartet, Erledigtes bleibt).
## Hängt an der Theke (Lagen im Raum der Theke, Platte bei Counter.TOP_HEIGHT; Spielfigur -Z, Gäste +Z).

enum Step { CARD, READING, SCAN, BAG, DONE }

const CARD_SCENE := "res://scenes/street_life/props/library_card.tscn"
const BAG_MODEL := "res://assets/models/characters/props/library_bag_empty.glb"
## Lagen auf der Platte (y = 0 ist die Oberkante der Platte)
const SCANNER := Vector3(0.1, 0.0, -0.04)
const BAG := Vector3(0.36, 0.0, -0.03)
const BASKET := Vector3(-0.3, 0.0, 0.2)
const BOOKS := Vector3(-0.12, 0.0, -0.06)
const CARD_START := Vector3(-0.42, 0.0, 0.06)
## Griffpunkt der Tüte über ihrer Unterkante (build_storybook_bags.py: HANG + LIB_HEIGHT) und Innenmaße (quer zur Spielfigur, tief)
const BAG_DROP := 0.335
const BAG_INSIDE := Vector2(0.255, 0.175)
## Wohin der Korb am Ende gleitet (unten rechts aus dem Bild, hinter die Theke) und wohin die Tüte zum Gast rutscht
const BASKET_OUT := Vector3(-0.75, -0.5, -0.7)
const BAG_TO_GUEST := Vector3(0.3, 0.0, 0.46)
## Vordere Thekenkante auf der Seite der Spielfigur (z) – dort liegt der untere Bildrand
const NEAR_EDGE := -0.32

var visits: LibraryVisits
var counter: Node3D
var tablet: ShopTablet
var walker: Passerby
var is_open := false

var _camera: Camera3D
var _player: Node3D
var _player_camera: Camera3D
var _step := Step.CARD
## kleine Anleitung oben links (bei den ersten Bedienungen, Tutorial.desk_help_wanted)
var _steps_note: DeskSteps
var _busy := false
var _card: Node3D
var _bag: Node3D
var _books: Array[Dictionary] = []   # {node, book, scanned}
var _hover: Node3D
var _progress := {}                  # Gast → {"read": bool, "bonus": bool, "scanned": Array[Book]}
var _tween: Tween
var _moving := false                 # Kamera fährt gerade (dann nicht nachführen)
var _preview := false                # Prüfwerkzeug: ohne Gast (debug_preview)
var _preview_books: Array[Book] = []


func setup(library_visits: LibraryVisits, counter_node: Node3D) -> void:
	visits = library_visits
	counter = counter_node
	_camera = Camera3D.new()
	_camera.name = "DeskCamera"
	_camera.near = 0.02
	add_child(_camera)


## Das Tablet auf der Theke (verschiebbar – darum jedes Mal gesucht).
func _find_tablet() -> ShopTablet:
	var best: ShopTablet = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(ShopTablet.GROUP):
		var t := node as ShopTablet
		var d := t.global_position.distance_to(counter.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best if best_d < 2.0 else null


# --- Öffnen und schließen ---

func open(guest: Passerby) -> void:
	if is_open or guest == null:
		return
	is_open = true
	walker = guest
	tablet = _find_tablet()
	_player = visits.life.get_player()
	_player_camera = get_viewport().get_camera_3d()
	if _player:
		_player.set("movement_enabled", false)
		_player.set("interaction_enabled", false)
	MenuStack.open(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# weich heranrücken: von der Spielfigur-Kamera zur Theken-Ansicht
	_camera.global_transform = _player_camera.global_transform if _player_camera else _view_transform()
	_camera.fov = _player_camera.fov if _player_camera else _view_fov()
	_camera.make_current()
	_kill_tween()
	_moving = true
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "global_transform", _view_transform(), GameConfig.desk_camera_time)
	_tween.tween_property(_camera, "fov", _view_fov(), GameConfig.desk_camera_time)
	_tween.chain().tween_callback(func() -> void: _moving = false)
	if tablet:
		tablet.show_loan(true)
	Tutorial.report("desk_open")
	_show_steps_note()
	_begin_guest()


## Die kleine Anleitung „So bedienst du“ (bei den ersten Bedienungen).
func _show_steps_note() -> void:
	if Tutorial.desk_help_wanted() and _steps_note == null:
		_steps_note = DeskSteps.new()
		add_child(_steps_note)


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
	if _steps_note:
		_steps_note.queue_free()
		_steps_note = null
	if tablet and is_instance_valid(tablet):
		tablet.show_loan(false)
	_kill_tween()
	var back := _player_camera
	if back and is_instance_valid(back):
		_moving = true
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(_camera, "global_transform", back.global_transform, GameConfig.desk_camera_time * 0.8)
		_tween.tween_property(_camera, "fov", back.fov, GameConfig.desk_camera_time * 0.8)
		_tween.chain().tween_callback(func() -> void:
			_moving = false
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


## Sichtfeld (oben/unten) so, dass links und rechts GameConfig.desk_camera_hfov Grad zu sehen sind – bei jedem Bildformat.
func _view_fov() -> float:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var half_h := deg_to_rad(GameConfig.desk_camera_hfov) / 2.0
	return rad_to_deg(2.0 * atan(tan(half_h) / aspect))


## Mittig hinter der Theke, gerade nach vorn; so weit nach unten geneigt, dass der untere Bildrand genau an der Thekenkante liegt.
func _view_transform() -> Transform3D:
	var top := Counter.TOP_HEIGHT
	var eye_rel := GameConfig.desk_camera_eye
	var to_edge := atan2(eye_rel.y, NEAR_EDGE - eye_rel.z)  # wie weit unter der Waagerechten die Kante liegt
	var pitch := to_edge - deg_to_rad(_view_fov()) / 2.0
	var forward := Vector3(0.0, -sin(pitch), cos(pitch))
	var eye := Vector3(eye_rel.x, top + eye_rel.y, eye_rel.z)
	var local := Transform3D(Basis.looking_at(forward, Vector3.UP), eye)
	return counter.global_transform * local


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
	_bag = _spawn_bag()
	if progress.read:
		if tablet:
			tablet.screen.show_card(str(info.get("name", "")), int(info.get("stamps", 0)), bool(progress.bonus))
			tablet.screen.pop = 1.0
	else:
		_card = _spawn_card()
	# Bücher: schon gescannte stehen in der Tüte, die übrigen liegen als Stapel vor dem Korb (das oberste zuerst)
	var scanned: Array = progress.scanned
	var pile := 0
	for book: Book in books:
		var node := _spawn_book(book)
		var is_scanned := scanned.has(book)
		_books.append({"node": node, "book": book, "scanned": is_scanned})
		if is_scanned:
			_put_in_bag(node, book, scanned.find(book))
		else:
			node.transform = _pile_transform(book, pile)
			pile += 1
	visits.show_basket_empty(true)
	if not progress.read:
		_step = Step.CARD
	elif _scanned_count() < _books.size():
		_step = Step.SCAN
		_show_scan()
	else:
		_step = Step.BAG
		_show_scan()


func _process(_delta: float) -> void:
	if not is_open:
		return
	if not _preview and (walker == null or not is_instance_valid(walker)):
		_close()
		return
	if not _moving:
		_camera.global_transform = _view_transform()  # bleibt richtig, auch wenn sich die Fenstergröße ändert
		_camera.fov = _view_fov()
	_update_hover()
	if _steps_note:
		var index: int = {Step.CARD: 0, Step.READING: 1, Step.SCAN: 1, Step.BAG: 2, Step.DONE: 3}[_step]
		_steps_note.set_state(index, _scanned_count(), _books.size())


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
		Step.BAG:
			if target == _bag:
				_hand_over_bag()


## 1. Ausweis in den Kartenleser: gleitet hinüber, stellt sich auf und rutscht in den Schlitz; dann Stempel auf dem Tablet, und
## der Ausweis hüpft wieder heraus in die Tüte (der Gast bekommt ihn mit den Büchern zurück).
func _read_card() -> void:
	_busy = true
	_step = Step.READING
	Tutorial.report("card_read")
	var slot := tablet.reader_slot_global() if tablet else counter.global_transform * Vector3(-0.4, Counter.TOP_HEIGHT + 0.04, -0.1)
	var upright := (tablet.global_transform.basis if tablet else counter.global_transform.basis).orthonormalized()
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
		if tablet:
			tablet.screen.show_card(str(info.get("name", "Hattie Bramwell" if _preview else "")),
				int(info.get("stamps", 3 if _preview else 0)), bonus)
		if bonus:
			Audio.play("ui/kaching", -16.0, 1.3))
	_tween.tween_interval(0.9)
	# wieder heraus und in die Tüte
	var into_bag := _bag.global_transform * Vector3(0.0, -BAG_DROP + 0.1, 0.0)
	_tween.tween_property(_card, "global_position", slot + Vector3.UP * 0.1, 0.2)
	_tween.tween_property(_card, "global_position", into_bag + Vector3.UP * 0.18, GameConfig.desk_card_time)
	_tween.tween_property(_card, "global_position", into_bag, 0.2).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		Audio.play_at("books/place", into_bag, -14.0, 1.3)
		_card.visible = false
		_busy = false
		_step = Step.SCAN if _scanned_count() < _books.size() else Step.BAG
		_show_scan())


## 2. Das oberste Buch: abheben, flach von rechts nach links über den Scanner (Piep), hoch und aufrecht von oben in die Tüte.
func _scan_book(entry: Dictionary) -> void:
	_busy = true
	var node: Node3D = entry.node
	var book: Book = entry.book
	var size := book.data.size
	var flat := _flat_basis(book)
	var glide_y := Counter.TOP_HEIGHT + 0.03 + size.x / 2.0
	var from := counter.global_transform * Transform3D(flat, Vector3(SCANNER.x - 0.16, glide_y, SCANNER.z))
	var over := counter.global_transform * Transform3D(flat, Vector3(SCANNER.x, glide_y - 0.01, SCANNER.z))
	# nach dem Piep senkrecht hoch (seitlich stieße das Buch an die Tüte), dann von oben in die Tüte
	var up := counter.global_transform * Transform3D(flat, Vector3(SCANNER.x + 0.03, glide_y + 0.32, SCANNER.z))
	var index := _scanned_count()
	var slot := _bag_slot(book, index)
	var above_bag := Transform3D(slot.basis, slot.origin + Vector3.UP * (size.y * 0.5 + 0.12))
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(node, "global_position", node.global_position + Vector3.UP * 0.08, GameConfig.desk_book_time * 0.3)
	_tween.tween_property(node, "global_transform", from, GameConfig.desk_book_time * 0.6)
	# langsam über den Glasstreifen ziehen – in der Mitte piept es
	_tween.tween_property(node, "global_transform", over, GameConfig.desk_book_time * 0.45).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		Audio.play_at("ui/scan", over.origin, -6.0, Audio.vary(0.02))
		entry.scanned = true
		(_progress[walker].scanned as Array).append(book)
		_show_scan())
	_tween.tween_property(node, "global_transform", up, GameConfig.desk_book_time * 0.5)
	_tween.tween_property(node, "global_transform", above_bag, GameConfig.desk_book_time * 0.7)
	_tween.tween_property(node, "global_transform", slot, GameConfig.desk_book_time * 0.45).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		Audio.play_at("books/place", slot.origin, -10.0, Audio.vary(0.08))
		_put_in_bag(node, book, index)
		_busy = false
		if _scanned_count() >= _books.size():
			_step = Step.BAG
			Tutorial.report("books_scanned"))


## 3. Die Tüte rutscht dem Gast hinüber (er trägt sie hinaus); der Korb gleitet unten rechts aus dem Bild hinter die Theke.
func _hand_over_bag() -> void:
	_busy = true
	_step = Step.DONE
	var to_guest := counter.global_transform * (BAG_TO_GUEST + Vector3(0.0, Counter.TOP_HEIGHT + BAG_DROP, 0.0))
	Audio.play_at("ui/slide", _bag.global_position, -4.0, Audio.vary(0.05))
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_bag, "global_position", to_guest, GameConfig.desk_push_time)
	_tween.tween_callback(func() -> void:
		var bonus := bool((_progress.get(walker, {}) as Dictionary).get("bonus", false))
		_progress.erase(walker)
		if is_instance_valid(_bag):
			_bag.queue_free()
		_bag = null
		for entry in _books:
			if is_instance_valid(entry.node):
				(entry.node as Node3D).queue_free()
		_books.clear()
		if walker:
			visits.complete_checkout(walker, bonus)  # Ausleihe, Kaching; der Gast nimmt die Tüte
		if tablet:
			tablet.screen.show_done())
	var basket := visits.counter_basket()
	if basket:
		var out := counter.global_transform * (BASKET_OUT + Vector3(0.0, Counter.TOP_HEIGHT, 0.0))
		_tween.tween_property(basket, "global_position", out, GameConfig.desk_basket_time).set_ease(Tween.EASE_IN)
		_tween.tween_callback(visits.clear_counter_basket)
	_tween.tween_interval(0.6)
	_tween.tween_callback(_next_guest)


## Nächster Gast: wartet schon jemand vorn an der Theke, geht es gleich weiter – sonst endet die Ansicht.
func _next_guest() -> void:
	_busy = false
	if _preview:
		return
	var next := visits.waiting_guest()
	if next and is_open:
		walker = next
		if tablet:
			tablet.screen.show_wait()
		_begin_guest()
	else:
		_close()


func _show_scan() -> void:
	if tablet == null:
		return
	var titles: Array[String] = []
	for entry in _books:
		if entry.scanned:
			titles.append((entry.book as Book).data.title)
	tablet.screen.show_scan(titles, _books.size())


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
			var top := _top_book()
			if top:
				result.append(top)
		Step.BAG:
			if _bag:
				result.append(_bag)
	return result


## Das oberste noch nicht gescannte Buch des Stapels.
func _top_book() -> Node3D:
	var best: Node3D = null
	for entry in _books:
		if not entry.scanned and (best == null or (entry.node as Node3D).position.y > best.position.y):
			best = entry.node
	return best


func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var radius := GameConfig.desk_pick_radius * get_viewport().get_visible_rect().size.y / 900.0
	var best: Node3D = null
	var best_d := radius * (1.6 if _step == Step.BAG else 1.0)
	if not _busy:
		for node in _clickables():
			var at := node.global_position
			if node == _bag:
				at -= Vector3.UP * (BAG_DROP - 0.13)  # Mitte der Tüte statt Griff
			if _camera.is_position_behind(at):
				continue
			var d := _camera.unproject_position(at).distance_to(mouse)
			if d < best_d:
				best_d = d
				best = node
	for node in _all_props():
		var on := node == best
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
	if _bag:
		result.append(_bag)
	for entry in _books:
		if not entry.scanned:
			result.append(entry.node)
	return result


# --- Dinge auf der Theke ---

func _spawn_card() -> Node3D:
	var card := (load(CARD_SCENE) as PackedScene).instantiate() as Node3D
	counter.add_child(card)
	card.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.FORWARD, 0.25),
		CARD_START + Vector3(0.0, Counter.TOP_HEIGHT + 0.003, 0.0))
	return card


## Offene Papiertüte links; die breite Seite mit dem Herz-Etikett zur Spielfigur.
func _spawn_bag() -> Node3D:
	var model := load(BAG_MODEL) as PackedScene
	var bag: Node3D = model.instantiate() if model else Node3D.new()
	counter.add_child(bag)
	bag.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), BAG + Vector3(0.0, Counter.TOP_HEIGHT + BAG_DROP, 0.0))
	return bag


func _spawn_book(book: Book) -> Node3D:
	var node := MeshInstance3D.new()
	node.mesh = BookLook.get_mesh()
	node.material_override = BookLook.create_single_material(book.data)
	counter.add_child(node)
	return node


## Liegend (Cover oben, Rücken zur Spielfigur), lang quer zur Theke.
func _flat_basis(book: Book) -> Basis:
	return (Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.FORWARD, PI / 2.0)).scaled_local(book.data.size)


## Der Stapel vor dem Korb (übereinander, leicht verdreht) – das erste Buch unten.
func _pile_transform(book: Book, index: int) -> Transform3D:
	var size := book.data.size
	var height := 0.0
	var n := 0
	for entry in _books:
		if n >= index:
			break
		if not entry.scanned:
			height += (entry.book as Book).data.size.x
			n += 1
	var basis := (Basis(Vector3.UP, PI / 2.0 + 0.12 * sin(index * 2.3)) * Basis(Vector3.FORWARD, PI / 2.0)).scaled_local(size)
	return Transform3D(basis, BOOKS + Vector3(0.0, Counter.TOP_HEIGHT + height + size.x / 2.0 + 0.002, 0.0))


## Platz in der Tüte (Welt): aufrecht, Rücken nach oben links, nebeneinander von vorn nach hinten.
func _bag_slot(book: Book, index: int) -> Transform3D:
	var size := book.data.size
	var depth := 0.0
	var n := 0
	for entry in _books:
		if entry.scanned and n < index:
			depth += (entry.book as Book).data.size.x + 0.004
			n += 1
	var z := BAG.z - BAG_INSIDE.y / 2.0 + depth + size.x / 2.0
	z = minf(z, BAG.z + BAG_INSIDE.y / 2.0 - size.x / 2.0)
	var basis := (Basis(Vector3.UP, -PI / 2.0) * Basis(Vector3.FORWARD, 0.04 * (index % 2 * 2 - 1))).scaled_local(size)
	var local := Transform3D(basis, Vector3(BAG.x, Counter.TOP_HEIGHT + 0.008 + size.y / 2.0, z))
	return counter.global_transform * local


## Buch in die Tüte stellen (es wandert mit ihr).
func _put_in_bag(node: Node3D, book: Book, index: int) -> void:
	var slot := _bag_slot(book, index)
	if _bag and node.get_parent() != _bag:
		node.reparent(_bag)
	node.global_transform = slot
	node.set_meta("lift", Vector3.ZERO)


func _clear_props() -> void:
	for node in _all_props():
		if is_instance_valid(node):
			node.queue_free()
	for entry in _books:
		if is_instance_valid(entry.node):
			(entry.node as Node3D).queue_free()
	_books.clear()
	_card = null
	_bag = null
	_hover = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	_moving = false


# --- Ohne Ansicht (Prüfwerkzeug: auto_stamp) ---

## Bedient einen Gast ohne Ansicht und ohne Bewegungen (Stempel, Ausleihe).
func auto_serve(guest: Passerby) -> void:
	var bonus := Lending.add_stamp(visits.visit_card(guest))
	visits.complete_checkout(guest, bonus)
	visits.clear_counter_basket()


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
	tablet = _find_tablet()
	_player = visits.life.get_player()
	_player_camera = get_viewport().get_camera_3d()
	_camera.global_transform = _view_transform()
	_camera.fov = _view_fov()
	_camera.make_current()
	if tablet:
		tablet.show_loan(true)
	_show_steps_note()
	_begin_guest()


## Prüfwerkzeug: das, was gerade angeklickt werden kann, anklicken.
func debug_click() -> void:
	var targets := _clickables()
	if not targets.is_empty() and not _busy:
		_click(targets[0])
