class_name LibraryVisits
extends Node
## Besucher der Bücherei (seit Etappe 7, Kind von StreetLife: life.library). Ein Passant, der auf dem Gehweg an der Treppe
## vorbeikommt, fragt hier (über einen Schritt "call"), ob er hereinkommt (Lending.want_visitor). Dann: die Treppe hinauf,
## durch die Ladentür (LibraryDoorLink), an ein bis drei Regalen stöbern und Bücher herausnehmen (am liebsten sein
## Lieblings-Genre), manchmal auf einem freien Sitzplatz lesen, an der Theke anstellen (einmal „Pling“, Ausweis
## hochhalten) und warten, bis die Spielfigur hinter der Theke mit E stempelt – dann ist ausgeliehen (Lending.lend), und er
## geht wieder auf die Straße und seinen Weg weiter. Findet er nichts, geht er freundlich wieder.
##
## Alle Wege im Laden plant ein Raster (AStarGrid2D) um Möbel und Wände herum; es wird neu vermessen, sobald sich die
## Einrichtung ändert (Room.layout_changed). Das Hinterzimmer gehört nicht dazu – Besucher gehen nie hinein.
## Alle Schritte im Laden werden erst geplant, wenn der Besucher wirklich dort ist (Schritt "call").

## Gruppe aller Besucher, solange sie in der Bücherei sind (das Bett prüft sie: mit Besuchern schläft man nicht)
const VISITOR_GROUP := &"library_visitors"
## Gruppe dieses Knotens (Lending fragt beim Speichern nach Büchern, die Besucher gerade in der Hand haben)
const GROUP := &"library_visits"
## Halbe Breite der Wege im Laden (m): eng, damit niemand Möbel streift
const PATH_HALF_WIDTH := 0.1
## Halbe Breite der Wege auf dem Gehweg (zur Treppe und zurück): dort weicht man anderen aus
const STREET_HALF_WIDTH := 0.5
## Abstand der Wartenden in der Schlange (m)
const QUEUE_GAP := 0.75

var life: StreetLife
var room: Room
var door: Door
var door_link: LibraryDoorLink
## Wartende an der Theke (der Erste steht vorn)
var queue: Array[Passerby] = []

var _grid: AStarGrid2D
var _grid_origin := Vector2.ZERO
var _grid_dirty := true
var _floor := 0.0
var _rng := RandomNumberGenerator.new()
var _stamp_interactable: Interactable
var _counter: Node3D
## Prüfwerkzeug: Ausgaben in die Konsole
static var debug := false
## Prüfwerkzeug: an der Theke selbst stempeln (ohne Spielfigur)
var auto_stamp := false
## Wer an der Theke gerade gestempelt wurde (bis er losgeht)
var _stamped: Dictionary = {}
## Was ein Besucher gerade trägt / will: walker → {books, genre, new}
var _visit: Dictionary = {}


func setup(street_life: StreetLife, seed_value: int = -1) -> void:
	life = street_life
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	room = Lending.find_room()
	if room == null:
		return
	for node: Node in room.find_children("*", "Door", true, false):
		door = node as Door
		break
	if door:
		door_link = LibraryDoorLink.new(door)
		door_link.name = "LibraryDoorLink"
		add_child(door_link)
	room.layout_changed.connect(func() -> void: _grid_dirty = true)
	add_to_group(GROUP)
	_floor = life.to_local(room.global_position).y


func is_ready() -> bool:
	return room != null and door_link != null


func step(delta: float) -> void:
	if door_link:
		door_link.step(delta)
	_update_counter()


# --- Vom Gehweg herein ---

## Schritt "call" an der Treppe: kommt dieser Passant herein? Dann die Schritte hinein (der Rest des Besuchs wird drinnen
## geplant); sonst nichts (er geht einfach weiter).
func offer_visit(walker: Passerby, rejoin: Vector2) -> Array:
	if not is_ready() or walker.companion != null or walker.carries_bag() or not Lending.want_visitor():
		return []
	Lending.visitor_entered(walker)
	_visit[walker] = {"books": [] as Array[Book], "genre": _pick_genre(), "new": Lending.roll_new_reader(), "rejoin": rejoin}
	walker.add_to_group(VISITOR_GROUP)
	walker.add_to_group(Door.KEEPOUT_GROUP)
	var p := _entrance_points()
	var actions: Array = []
	actions.append(_line([walker.pos, p.foot], 0.0, 0.0, STREET_HALF_WIDTH))
	actions.append(_line([p.foot, p.landing], 0.0, _floor))
	actions.append({"type": "door", "door": door_link, "from_pos": p.landing, "to_pos": p.inside, "middle": p.middle,
		"push": true, "floor": _floor, "fixed_path": true})
	actions.append(_call(_plan_inside))
	return actions


## Punkte vor der Tür: am Fuß der Treppe, oben auf dem Podest, Mitte der Tür, drinnen hinter dem Schwenkbereich.
func _entrance_points() -> Dictionary:
	var center := StreetLayout.door_center()
	var out := StreetLayout.door_outward()
	var middle := Vector2(center.x, center.z)
	var out2 := Vector2(out.x, out.z).normalized()
	var steps := GameConfig.entrance_podium_depth + GameConfig.entrance_step_count * GameConfig.entrance_step_depth
	var inside_world := room.to_global(Vector3(middle.x, 0.0, middle.y) - Vector3(out.x, 0.0, out.z) * (0.2 + Door.SWING_RADIUS + 0.25))
	var inside := _nearest_free(inside_world)
	return {"foot": middle + out2 * (steps + 0.15), "landing": middle + out2 * 0.42, "middle": middle,
		"inside": _to2(inside)}


## Ein gerader, fester Weg (Treppe: Boden steigt von floor_from auf floor_to).
func _line(points: Array, floor_from: float, floor_to: float, half_width: float = PATH_HALF_WIDTH) -> Dictionary:
	var route := _route(PackedVector2Array(points), half_width)
	if route == null:
		return _call(func(w: Passerby) -> Array:
			w.floor_y = floor_to
			return [])
	var action := {"type": "walk", "route": route, "to": route.length(), "fixed_path": true}
	if not is_equal_approx(floor_from, floor_to):
		action.floor_from = floor_from
		action.floor_to = floor_to
	return action


## Weg aus Punkten (fast gleiche Punkte fallen weg); null, wenn er zu kurz ist.
func _route(points: PackedVector2Array, half_width: float = PATH_HALF_WIDTH) -> StreetRoute:
	var clean := PackedVector2Array()
	for p in points:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.03:
			clean.append(p)
	if clean.size() < 2:
		return null
	return StreetRoute.from_points(clean, half_width)


func _call(callable: Callable) -> Dictionary:
	return {"type": "call", "callable": callable}


# --- Drinnen ---

## Drinnen angekommen: Regale, vielleicht lesen, Theke (oder ohne Buch wieder hinaus).
func _plan_inside(walker: Passerby) -> Array:
	var actions: Array = []
	var stops := _pick_shelves(walker)
	if debug:
		print("Bücherei: %s will %s, Regale %d" % [walker.name, (_visit.get(walker, {}) as Dictionary).get("genre", "?"), stops.size()])
	for shelf in stops:
		var spot := _shelf_spot(shelf)
		if debug:
			print("  Regal %s Bücher %d Platz %s" % [shelf.get_path(), shelf.get_books().size(), spot])
		if spot.is_empty():
			continue
		actions.append(_call(_go_to.bind(spot.pos)))
		actions.append({"type": "stand", "anim": &"browse", "face": spot.face,
			"time": _rng.randf_range(GameConfig.visitor_browse_time.x, GameConfig.visitor_browse_time.y)})
		actions.append(_call(_take_books.bind(shelf)))
	actions.append(_call(_after_browsing))
	return actions


## Nach dem Stöbern: mit Büchern lesen (manchmal) und zur Theke, sonst freundlich gehen.
func _after_browsing(walker: Passerby) -> Array:
	var visit: Dictionary = _visit.get(walker, {})
	var books: Array = visit.get("books", [])
	if books.is_empty():
		Lending.nothing_found()
		if walker._model and walker._model.has_method("trigger_face"):
			walker._model.call("trigger_face", &"window_wonder")
		return _leave_actions(walker)
	walker.set_prop(&"book")
	var actions: Array = []
	if _rng.randf() < GameConfig.visitor_read_chance:
		var seat := _free_seat(walker)
		if debug:
			print("  %s setzt sich: %s" % [walker.name, seat.get_path() if seat else "kein Platz"])
		if seat:
			seat.occupant = walker
			var face3 := seat.global_basis.z
			var face := Vector2(face3.x, face3.z).normalized()
			var spot := _to2(seat.global_position)
			actions.append(_call(_go_to.bind(seat.global_position + face3 * 0.5)))
			actions.append({"type": "sit", "seat": seat, "spot": spot, "face": face, "floor": _floor,
				"height": seat.global_position.y - room.global_position.y,
				"time": _rng.randf_range(GameConfig.visitor_read_time.x, GameConfig.visitor_read_time.y)})
			actions.append(_call(func(w: Passerby) -> Array:
				if is_instance_valid(seat) and seat.occupant == w:
					seat.occupant = null
				return []))
	actions.append(_call(_queue_step))
	return actions


## An der Theke anstellen: bis vorn aufrücken, dann Ausweis zeigen und warten, bis gestempelt ist.
func _queue_step(walker: Passerby) -> Array:
	if _counter_node() == null:
		return _leave_actions(walker)  # keine Theke (sollte nie sein): Bücher bleiben bei ihm … und kommen nie wieder
	if not queue.has(walker):
		queue.append(walker)
	var index := queue.find(walker)
	var target := _queue_spot(index)
	if _to2(target).distance_to(walker.pos) > 0.12:
		return [_call(_go_to.bind(target)), _call(_queue_step)]
	if index > 0:
		return [{"type": "wait", "face": _counter_face(), "until": func(w: Passerby) -> bool: return queue.find(w) < index},
			_call(_queue_step)]
	# vorn an der Theke
	Audio.play_at("ui/counter_bell", _counter_node().global_transform * Vector3(-0.3, 1.0, 0.25), GameConfig.counter_bell_volume_db,
		Audio.vary(0.03))
	walker.set_prop(&"card")
	return [{"type": "wait", "face": _counter_face(), "until": func(w: Passerby) -> bool: return _stamped.has(w),
		"every": _hold_card}, _call(_after_stamp)]


func _hold_card(walker: Passerby, _delta: float) -> void:
	if walker._model and walker._model.has_method("show_hand_at"):
		walker._model.call("show_hand_at", _card_point())


## Gestempelt: ausgeliehen, Ausweis weg, Buch in der Hand, hinaus.
func _after_stamp(walker: Passerby) -> Array:
	_stamped.erase(walker)
	queue.erase(walker)
	if walker._model and walker._model.has_method("show_hand_at"):
		walker._model.call("show_hand_at", null)
	walker.set_prop(&"book")
	if walker._model and walker._model.has_method("trigger_face"):
		walker._model.call("trigger_face", &"buy")
	return _leave_actions(walker)


## Zur Tür und hinaus, die Treppe hinunter und zurück auf den Gehweg (dort geht der alte Weg weiter).
func _leave_actions(walker: Passerby) -> Array:
	var p := _entrance_points()
	var rejoin: Vector2 = (_visit.get(walker, {}) as Dictionary).get("rejoin", p.foot)
	return [
		_call(_go_to.bind(Vector3(p.inside.x, 0.0, p.inside.y))),
		{"type": "door", "door": door_link, "from_pos": p.inside, "to_pos": p.landing, "middle": p.middle, "push": false,
			"floor": _floor, "fixed_path": true},
		_line([p.landing, p.foot], _floor, 0.0),
		_call(_left_library),
		_line([p.foot, rejoin], 0.0, 0.0, STREET_HALF_WIDTH),
	]


func _left_library(walker: Passerby) -> Array:
	walker.remove_from_group(VISITOR_GROUP)
	walker.remove_from_group(Door.KEEPOUT_GROUP)
	walker.set_prop(&"")
	queue.erase(walker)
	_visit.erase(walker)
	Lending.visitor_left(walker)
	return []


## Weg im Laden von hier bis zu einem Punkt (Welt; Höhe egal).
func _go_to(walker: Passerby, target: Vector3) -> Array:
	var route := _route(find_path(walker.pos, _to2(target)))
	if route == null:
		return []
	return [{"type": "walk", "route": route, "to": route.length(), "fixed_path": true}]


# --- Bücher ---

func _pick_genre() -> String:
	var genres: Array[String] = []
	for genre: GenreData in Catalog.get_all_genres():
		if BookStock.is_genre_unlocked(genre.id):
			genres.append(genre.id)
	return genres[_rng.randi() % genres.size()] if not genres.is_empty() else ""


## Regale zum Stöbern: erst die mit dem Lieblings-Genre, dann andere mit Büchern.
func _pick_shelves(walker: Passerby) -> Array[BookShelf]:
	var genre := String((_visit.get(walker, {}) as Dictionary).get("genre", ""))
	var with_genre: Array[BookShelf] = []
	var others: Array[BookShelf] = []
	for node in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
		var shelf := node as BookShelf
		if shelf == null or not room.is_ancestor_of(shelf) or shelf.get_books().is_empty():
			continue
		if _in_back_room(shelf.global_position):
			continue
		if shelf.count_books(genre) > 0:
			with_genre.append(shelf)
		else:
			others.append(shelf)
	with_genre.shuffle()
	others.shuffle()
	var all := with_genre + others
	var count := mini(all.size(), _rng.randi_range(GameConfig.visitor_shelf_stops.x, GameConfig.visitor_shelf_stops.y))
	return all.slice(0, count)


## Am Regal: passende Bücher herausnehmen (Lieblings-Genre; sonst manchmal etwas anderes).
func _take_books(walker: Passerby, shelf: BookShelf) -> Array:
	var visit: Dictionary = _visit.get(walker, {})
	if visit.is_empty() or not is_instance_valid(shelf):
		return []
	if not visit.has("want"):
		visit.want = _rng.randi_range(GameConfig.visitor_books.x, GameConfig.visitor_books.y)
		visit.other_ok = _rng.randf() < GameConfig.visitor_other_genre_chance
	var held: Array[Book] = visit.books
	var missing := int(visit.want) - held.size()
	if missing <= 0:
		return []
	var choice: Array[Book] = []
	var candidates := shelf.get_books().duplicate()
	candidates.shuffle()
	for book: Book in candidates:
		if choice.size() < missing and book.genre_id == String(visit.genre):
			choice.append(book)
	if choice.is_empty() and bool(visit.other_ok):
		for book: Book in candidates:
			if choice.size() < mini(missing, 1):
				choice.append(book)
	if choice.is_empty():
		return []
	shelf.remove_books(choice, true)
	held.append_array(choice)
	Audio.play_at("books/take", shelf.global_position + Vector3.UP, -4.0, Audio.vary(0.08))
	return []


# --- Theke ---

func _counter_node() -> Node3D:
	if _counter == null or not is_instance_valid(_counter):
		_counter = get_tree().get_first_node_in_group(&"counters") as Node3D
		if _counter and _stamp_interactable == null:
			_add_stamp_interactable()
	return _counter


## Platz in der Schlange: vorn vor der Theke (Kundenseite = +Z der Theke, links von der Kasse), dahinter in einer Reihe.
func _queue_spot(index: int) -> Vector3:
	var counter := _counter_node()
	var front := counter.global_transform * Vector3(-0.35, 0.0, 0.325 + 0.3)
	var back := counter.global_basis.z.normalized()
	return _nearest_free(front + back * QUEUE_GAP * index)


func _counter_face() -> Vector2:
	var z := -_counter_node().global_basis.z
	return Vector2(z.x, z.z).normalized()


## Wo der Ausweis über der Theke gezeigt wird (Welt).
func _card_point() -> Vector3:
	return _counter_node().global_transform * Vector3(-0.35, 1.0 + GameConfig.counter_card_height, 0.38)


## E-Bereich auf der Theke („Stempeln“, nur wenn jemand wartet und man hinter der Theke steht).
func _add_stamp_interactable() -> void:
	_stamp_interactable = Interactable.new()
	_stamp_interactable.name = "StampInteractable"
	_stamp_interactable.prompt_text = ""
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.3, 0.65)
	shape.shape = box
	_stamp_interactable.add_child(shape)
	_stamp_interactable.position = Vector3(0.0, 1.12, 0.02)
	_counter.add_child(_stamp_interactable)
	_stamp_interactable.interacted.connect(_on_stamp)


func _waiting_at_counter() -> Passerby:
	if queue.is_empty():
		return null
	var first := queue[0]
	if not is_instance_valid(first) or _stamped.has(first) or first.get_action_type() != "wait":
		return null
	return first


## Steht die Spielfigur hinter der Theke (Seite -Z, nicht weiter als counter_staff_reach)?
func player_behind_counter() -> bool:
	var player := life.get_player()
	var counter := _counter_node()
	if player == null or counter == null:
		return false
	var local := counter.global_transform.affine_inverse() * player.global_position
	return local.z < -0.2 and absf(local.x) < 1.4 and local.z > -GameConfig.counter_staff_reach


func _update_counter() -> void:
	if _counter_node() == null or _stamp_interactable == null:
		return
	var waiting := _waiting_at_counter()
	_stamp_interactable.prompt_text = "Stempeln" if waiting and player_behind_counter() else ""
	if auto_stamp and waiting and waiting.get_action().get("type") == "wait":
		_stamp(waiting)


func _on_stamp(_who: Node) -> void:
	var walker := _waiting_at_counter()
	if walker == null or not player_behind_counter():
		return
	_stamp(walker)


func _stamp(walker: Passerby) -> void:
	var visit: Dictionary = _visit.get(walker, {})
	var books: Array[Book] = []
	for book: Book in visit.get("books", []):
		books.append(book)
	var income := Lending.lend(books, bool(visit.get("new", false)))
	visit.lent = true
	Audio.play_at("ui/stamp", _card_point(), -2.0, Audio.vary(0.06))
	Audio.play("ui/kaching", -12.0)
	var text := "%d %s ausgeliehen" % [books.size(), "Buch" if books.size() == 1 else "Bücher"]
	if bool(visit.get("new", false)):
		text += ", neuer Leseausweis"
	Notice.post(self, "%s (+%s)" % [text, Wallet.format(income)])
	_stamped[walker] = true


# --- Sitzplätze ---

func _free_seat(walker: Passerby) -> SeatPoint:
	var seats: Array[SeatPoint] = []
	for node: Node in room.find_children("*", "Seating", true, false):
		var seating := node as Seating
		if seating == null:
			continue
		for seat in seating.get_free_seats():
			if not _in_back_room(seat.global_position):
				seats.append(seat)
	seats.shuffle()
	for seat in seats:
		# nur, wenn man davor stehen kann
		var front := seat.global_position + seat.global_basis.z * 0.5
		if _to2(_nearest_free(front)).distance_to(_to2(front)) < 0.35:
			return seat
	return null


func _in_back_room(point: Vector3) -> bool:
	var local := room.to_local(point)
	return BackRoom.back_area().grow(0.05).has_point(Vector2(local.x, local.z))


## Stelle vor einem Regal (Welt) und Blickrichtung dorthin (2D), oder leer.
func _shelf_spot(shelf: BookShelf) -> Dictionary:
	var item := FurnitureUtils.find_placed_furniture(shelf)
	var base := item if item else shelf as Node3D
	var forward := base.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var desired := base.global_position + forward * 0.75
	var spot := _nearest_free(desired)
	if spot.distance_to(desired) > 0.9:
		return {}
	var face := Vector2(-forward.x, -forward.z)
	return {"pos": spot, "face": face}


# --- Raster ---

## Weg von a nach b (Koordinaten unter StreetLife) um alles Feste herum, geglättet.
func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	_ensure_grid()
	var ca := _nearest_cell(_cell_of(a))
	var cb := _nearest_cell(_cell_of(b))
	if ca == Vector2i(-1, -1) or cb == Vector2i(-1, -1):
		return PackedVector2Array([a, b])
	var cells := _grid.get_id_path(ca, cb)
	if cells.is_empty():
		return PackedVector2Array([a, b])
	var points := PackedVector2Array([a])
	# Glätten: von jedem Punkt so weit wie möglich geradeaus (freie Sicht über das Raster)
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not _clear_line(cells[i], cells[j]):
			j -= 1
		if j < cells.size() - 1:
			points.append(_cell_center(cells[j]))
		i = j
	points.append(b)
	return points


func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	for k in steps + 1:
		var t := float(k) / maxf(steps, 1)
		var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if _grid.is_point_solid(c):
			return false
	return true


## Nächster freier Punkt (Welt) bei p im Laden.
func _nearest_free(p: Vector3) -> Vector3:
	_ensure_grid()
	var cell := _nearest_cell(_cell_of(_to2(p)))
	if cell == Vector2i(-1, -1):
		return p
	var c := _cell_center(cell)
	return life.to_global(Vector3(c.x, _floor, c.y))


func _ensure_grid() -> void:
	if _grid != null and not _grid_dirty:
		return
	_grid_dirty = false
	var area := room.build_area
	var step := GameConfig.visitor_grid_step
	var size := Vector2i(ceili(area.size.x / step), ceili(area.size.y / step))
	if _grid == null:
		_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, size)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	var origin_world := room.to_global(Vector3(area.position.x, 0.0, area.position.y))
	_grid_origin = _to2(origin_world)
	var space := room.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = GameConfig.visitor_clearance
	cylinder.height = 1.5
	query.shape = cylinder
	query.collision_mask = FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT
	for x in size.x:
		for y in size.y:
			var c := Vector2i(x, y)
			var center2 := _cell_center(c)
			var world := life.to_global(Vector3(center2.x, _floor + 0.15 + 0.75, center2.y))
			var solid := not room.is_inside_build_area(world)
			if not solid:
				query.transform = Transform3D(Basis.IDENTITY, world)
				for hit in space.intersect_shape(query, 6):
					if hit.collider and not door.is_leaf(hit.collider):
						solid = true
						break
			_grid.set_point_solid(c, solid)


func _cell_of(p: Vector2) -> Vector2i:
	var step := GameConfig.visitor_grid_step
	return Vector2i(floori((p.x - _grid_origin.x) / step), floori((p.y - _grid_origin.y) / step))


func _cell_center(c: Vector2i) -> Vector2:
	var step := GameConfig.visitor_grid_step
	return _grid_origin + (Vector2(c) + Vector2(0.5, 0.5)) * step


## Nächste freie Zelle (Suche in wachsenden Ringen), sonst (-1, -1).
func _nearest_cell(c: Vector2i) -> Vector2i:
	var region := _grid.region
	for r in 12:
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if region.has_point(n) and not _grid.is_point_solid(n):
					var d := Vector2(dx, dy).length()
					if d < best_d:
						best_d = d
						best = n
		if best != Vector2i(-1, -1):
			return best
	return Vector2i(-1, -1)


func _to2(world: Vector3) -> Vector2:
	var local := life.to_local(world)
	return Vector2(local.x, local.z)


## Bücher, die Besucher gerade in der Hand haben (noch nicht ausgeliehen) – beim Speichern kommen sie als Rückgabe mit.
func held_books() -> Array[Book]:
	var result: Array[Book] = []
	for walker: Variant in _visit:
		if (_visit[walker] as Dictionary).get("lent", false):
			continue  # schon ausgeliehen
		for book: Book in (_visit[walker] as Dictionary).get("books", []):
			result.append(book)
	return result


## Für das Prüfwerkzeug: Besucher gerade drinnen, wartend an der Theke.
func stats_text() -> String:
	return "drinnen %d, an der Theke %d" % [Lending.visitors_inside(), queue.size()]
