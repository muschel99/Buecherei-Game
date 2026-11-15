class_name LibraryVisits
extends Node
## Besucher der Bücherei (seit Etappe 7, Kind von StreetLife: life.library). Ein Passant, der auf dem Gehweg an der Treppe
## vorbeikommt, fragt hier (über einen Schritt "call"), ob er hereinkommt (Lending.want_visitor). Dann: die Treppe hinauf,
## durch die Ladentür (LibraryDoorLink), an ein bis drei Regalen stöbern und Bücher herausnehmen (am liebsten sein
## Lieblings-Genre), manchmal auf einem freien Sitzplatz lesen, an der Theke anstellen (einmal „Pling“, Ausweis
## hochhalten) und warten, bis die Spielfigur hinter der Theke bedient – dann ist ausgeliehen (Lending.lend), und er
## geht wieder auf die Straße und seinen Weg weiter. Findet er nichts, geht er freundlich wieder.
## Besucher tragen drinnen einen Korb (seit dem Nachtest von Etappe 8 ohne Stapel: er ist da, sobald sie hereinkommen), legen die
## Bücher hinein und stellen ihn an der Theke ab (rechts, CounterDesk.BASKET). Man bedient in der Theken-Ansicht (CounterDesk, E
## „Bedienen“): Ausweis in den Kartenleser (Stempel auf dem Tablet), Bücher über den Scanner in die Papiertüte, Tüte zum Gast;
## der Korb gleitet hinter die Theke. Der Gast trägt die Bücherei-Tüte hinaus (LIBRARY_BAG). Wer nichts findet, lässt den Korb an
## der Tür zurück.
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
## Theke: Wer gerade dran ist und wie weit (0 = Ausweis hochhalten, 1 = Ausweis liegt da, 2 = gestempelt, 3 = fertig)
var _checkout: Dictionary = {}
## Dinge auf der Theke beim Ausleihen (Korb, Ausweis, Stempel) und der Korbstapel an der Wand
var _stamp_shape: CollisionShape3D
var _counter_basket: Node3D
var _desk: CounterDesk
## Tüte, mit der Gäste nach der Ausleihe hinausgehen (seit dem Nachtest von Etappe 8, build_storybook_bags.py)
const LIBRARY_BAG := "res://assets/models/characters/props/library_bag.glb"
const BASKET_MODELS := ["res://assets/models/characters/props/library_basket_0.glb",
	"res://assets/models/characters/props/library_basket_1.glb", "res://assets/models/characters/props/library_basket_2.glb",
	"res://assets/models/characters/props/library_basket_3.glb"]
## Abstand Griff – Boden des Korbs (m, wie im Blender-Script: Hängen + Höhe)
const BASKET_DROP := 0.2
## Plätze vor Regalen, die Besucher gerade belegen (walker → Welt-Punkt)
var _shelf_spots: Dictionary = {}
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
	_update_wish_bubbles(delta)


# --- Vom Gehweg herein ---

## Schritt "call" an der Treppe: kommt dieser Passant herein? Dann die Schritte hinein (der Rest des Besuchs wird drinnen
## geplant); sonst nichts (er geht einfach weiter).
func offer_visit(walker: Passerby, rejoin: Vector2) -> Array:
	if not is_ready() or walker.companion != null or walker.chat != null or walker.carries_bag() or walker.talking:
		return []
	var regular := Regulars.find(walker.regular_id)
	if regular.is_empty() and not Lending.want_visitor():
		return []
	if not regular.is_empty() and (not Lending.accepts_visitors() or visitors_full()):
		return []
	Lending.visitor_entered(walker)
	if regular.is_empty():
		# bekannter Gast (beim Losgehen ausgewählt, sieht aus wie damals) oder ein neuer Ausweis mit passendem Namen und dem
		# Aussehen dieser Figur (seit dem Nachtest von Etappe 8 – vorher bekam eine fremde Figur einen alten Ausweis)
		var is_new := walker.reader_id.is_empty() or not Lending.readers.has(walker.reader_id)
		var card: String = Lending.new_reader("", walker.look_seed, 1 if walker.is_female() else 0) if is_new else walker.reader_id
		_visit[walker] = {"books": [] as Array[Book], "genre": _pick_genre(), "new": is_new, "rejoin": rejoin,
			"card": card, "style": _pick_style()}
		walker.reader_id = card
	else:
		# Stammgast (seit Etappe 8): eigener Ausweis, Lieblingsgenre, Art des Besuchs; Freunde bringen manchmal jemanden mit
		var created := Lending.ensure_reader(regular.id, regular.name)
		var genre := String(regular.genre) if BookStock.is_genre_unlocked(String(regular.genre)) else _pick_genre()
		_visit[walker] = {"books": [] as Array[Book], "genre": genre, "new": created, "rejoin": rejoin, "card": regular.id,
			"style": regular.style}
		var info: Dictionary = Lending.readers[regular.id]
		info.last_day = GameClock.day
		if Lending.friendship(regular.id) >= GameConfig.friend_bring_level and _rng.randf() < GameConfig.friend_bring_chance:
			Lending.add_visit_ticket()
	# Prüfwerkzeug: passt der Name auf dem Ausweis zur Figur? Sieht ein bekannter Gast aus wie beim ersten Mal?
	var card_info := Lending.reader_info(String(_visit[walker].card))
	var gender: int = PersonNames.gender_of(str(card_info.get("name", ""))) if regular.is_empty() else int(regular.female)
	_note("name_ok" if gender < 0 or (gender == 1) == walker.is_female() else "name_wrong")
	if regular.is_empty() and not bool(_visit[walker].new):
		_note("known_again")
	if String(_visit[walker].style) == "zurueck" and Lending.loans.is_empty():
		_visit[walker].style = "zielstrebig"  # nichts zum Zurückbringen da
	_note("styles", String(_visit[walker].style))
	if not regular.is_empty():
		_note("regular")
	# Manche haben einen Wunsch (seit Etappe 8): immer ein Genre; Gedankenblase mit Fragezeichen über dem Kopf
	if _rng.randf() < GameConfig.wish_chance and String(_visit[walker].style) != "zurueck":
		var genres := BookStock.get_unlocked_genres()
		if not genres.is_empty():
			_visit[walker].wish = {"genre": genres[_rng.randi() % genres.size()].get_id(), "state": "open"}
			_note("wish")
	walker.add_to_group(VISITOR_GROUP)
	walker.add_to_group(Door.KEEPOUT_GROUP)
	walker.in_library = true
	_visit[walker].speed = walker.speed_pref
	walker.speed_pref = clampf(walker.speed_pref, GameConfig.visitor_speed_range.x, GameConfig.visitor_speed_range.y)
	var p := _entrance_points()
	var actions: Array = []
	actions.append(_line([walker.pos, p.foot], 0.0, 0.0, STREET_HALF_WIDTH))
	actions.append(_line([p.foot, p.landing], 0.0, _floor))
	actions.append({"type": "door", "door": door_link, "from_pos": p.landing, "to_pos": p.inside, "middle": p.middle,
		"push": true, "floor": _floor, "fixed_path": true})
	actions.append(_call(_plan_inside))
	return actions


# --- Für die Geschichte (Maklerin, StoryIntro) ---

## Punkte vor der Tür (siehe _entrance_points).
func entrance_points() -> Dictionary:
	return _entrance_points()


## Von pos die Treppe hinauf und durch die Tür hinein.
func enter_actions(from: Vector2) -> Array:
	var p := _entrance_points()
	return [_line([from, p.foot], 0.0, 0.0, STREET_HALF_WIDTH), _line([p.foot, p.landing], 0.0, _floor),
		{"type": "door", "door": door_link, "from_pos": p.landing, "to_pos": p.inside, "middle": p.middle, "push": true,
			"floor": _floor, "fixed_path": true}]


## Im Laden zu einem Punkt (Welt) gehen – um alle Möbel herum.
func go_to_actions(target: Vector3) -> Array:
	return [_call(_go_to.bind(target))]


## Zur Tür, hinaus und die Treppe hinunter bis auf den Gehweg (dort geht es mit StreetLife.exit_actions weiter).
func exit_house_actions() -> Array:
	var p := _entrance_points()
	return [_call(_go_to.bind(Vector3(p.inside.x, 0.0, p.inside.y))),
		{"type": "door", "door": door_link, "from_pos": p.inside, "to_pos": p.landing, "middle": p.middle, "push": false,
			"floor": _floor, "fixed_path": true},
		_line([p.landing, p.foot], _floor, 0.0)]


## Höhe des Ladenbodens (unter StreetLife).
func shop_floor() -> float:
	return _floor


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
	if _style(walker) == "zurueck":
		return _return_actions(walker)
	var actions: Array = _basket_actions(true)
	var stops := _pick_shelves(walker)
	if debug:
		print("Bücherei: %s will %s, Regale %d" % [walker.name, (_visit.get(walker, {}) as Dictionary).get("genre", "?"), stops.size()])
	for shelf in stops:
		actions.append(_call(_visit_shelf.bind(shelf)))
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
	var actions: Array = []
	var read_chance := 1.0 if _style(walker) == "liest" else (0.0 if _style(walker) == "zielstrebig" else GameConfig.visitor_read_chance)
	if _rng.randf() < read_chance:
		var seat := _free_seat(walker)
		if debug:
			print("  %s setzt sich: %s" % [walker.name, seat.get_path() if seat else "kein Platz"])
		if seat:
			seat.occupant = walker
			var face3 := seat.global_basis.z
			var face := Vector2(face3.x, face3.z).normalized()
			var spot := _to2(seat.global_position)
			actions.append(_call(_go_to.bind(_seat_approach(seat).get("pos", seat.global_position + face3 * 0.5))))
			var sit := {"type": "sit", "seat": seat, "spot": spot, "face": face, "floor": _floor, "read": true,
				"height": seat.global_position.y - room.global_position.y,
				"time": _rng.randf_range(GameConfig.visitor_read_time.x, GameConfig.visitor_read_time.y) *
					(1.5 if _style(walker) == "liest" else 1.0)}
			var table: Variant = _table_in_front(seat)
			if table is Vector3:
				sit.read_table = table  # Buch aufgeschlagen auf dem Tisch (seit Etappe 8)
				_note("table")
			actions.append(sit)
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
	# vorn an der Theke: Korb auf die Theke, einmal klingeln, Ausweis hochhalten
	Audio.play_at("ui/counter_bell", _counter_node().global_transform * Vector3(-0.3, Counter.TOP_HEIGHT, 0.25), GameConfig.counter_bell_volume_db,
		Audio.vary(0.03))
	_checkout[walker] = 0
	_put_basket_on_counter(walker)
	walker.set_prop(&"card")
	return [{"type": "wait", "face": _counter_face(), "until": func(w: Passerby) -> bool: return int(_checkout.get(w, 0)) >= 3,
		"every": _hold_card}, _call(_after_stamp)]


func _hold_card(walker: Passerby, _delta: float) -> void:
	if walker._model and walker._model.has_method("show_hand_at"):
		walker._model.call("show_hand_at", _card_point() if int(_checkout.get(walker, 0)) == 0 else null)


## Fertig an der Theke: Ausweis und Bücher stecken in der Tüte – sie in die Hand, hinaus.
func _after_stamp(walker: Passerby) -> Array:
	_checkout.erase(walker)
	queue.erase(walker)
	if walker._model and walker._model.has_method("show_hand_at"):
		walker._model.call("show_hand_at", null)
	walker.set_prop(&"")
	# die Bücher stecken in der Bücherei-Tüte (den Korb räumt die Theken-Ansicht hinter die Theke)
	walker.give_bag(true, LIBRARY_BAG)
	if walker._model and walker._model.has_method("trigger_face"):
		walker._model.call("trigger_face", &"buy")
	return _leave_actions(walker)


## Zur Tür und hinaus, die Treppe hinunter und zurück auf den Gehweg (dort geht der alte Weg weiter).
func _leave_actions(walker: Passerby) -> Array:
	var p := _entrance_points()
	var rejoin: Vector2 = (_visit.get(walker, {}) as Dictionary).get("rejoin", p.foot)
	var steps: Array = [
		_call(_go_to.bind(Vector3(p.inside.x, 0.0, p.inside.y))),
		# ohne Ausleihe bleibt der Korb an der Tür (mit Ausleihe trägt man die Tüte)
		_call(func(w: Passerby) -> Array:
			if not bool((_visit.get(w, {}) as Dictionary).get("lent", false)):
				w.give_bag(false)
			return []),
		{"type": "door", "door": door_link, "from_pos": p.inside, "to_pos": p.landing, "middle": p.middle, "push": false,
			"floor": _floor, "fixed_path": true},
		_line([p.landing, p.foot], _floor, 0.0),
		_call(_left_library),
		_line([p.foot, rejoin], 0.0, 0.0, STREET_HALF_WIDTH),
	]
	return steps


func _left_library(walker: Passerby) -> Array:
	walker.remove_from_group(VISITOR_GROUP)
	walker.remove_from_group(Door.KEEPOUT_GROUP)
	walker.in_library = false
	_shelf_spots.erase(walker)
	walker.speed_pref = float((_visit.get(walker, {}) as Dictionary).get("speed", walker.speed_pref))
	# (die Bücherei-Tüte bleibt in der Hand – StreetLife._launch räumt sie später weg)
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
	var stops := _rng.randi_range(GameConfig.visitor_shelf_stops.x, GameConfig.visitor_shelf_stops.y)
	match _style(walker):
		"zielstrebig":
			stops = 1
		"stoebert":
			stops = maxi(stops, 3)
	var count := mini(all.size(), stops)
	return all.slice(0, count)


## Am Regal: passende Bücher herausnehmen (Lieblings-Genre; sonst manchmal etwas anderes).
func _take_books(walker: Passerby, shelf: BookShelf) -> Array:
	var visit: Dictionary = _visit.get(walker, {})
	if visit.is_empty() or not is_instance_valid(shelf):
		return []
	if not visit.has("want"):
		visit.want = _rng.randi_range(GameConfig.visitor_books.x, GameConfig.visitor_books.y)
		if String(visit.get("style", "")) == "zielstrebig":
			visit.want = mini(int(visit.want), 2)
		visit.other_ok = _rng.randf() < GameConfig.visitor_other_genre_chance and String(visit.get("style", "")) != "zielstrebig"
	var held: Array[Book] = visit.books
	var missing := int(visit.want) - held.size()
	if missing <= 0:
		return []
	var choice: Array[Book] = []
	# nur, was sie erreichen (Chibi-Größe: obere Fächer sind für die Spielfigur, seit Etappe 8)
	var candidates := shelf.get_books().filter(func(b: Book) -> bool: return _row_height(shelf, b) <= GameConfig.visitor_reach_height)
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
	var take := func(_w: Passerby = null) -> void:
		if not is_instance_valid(shelf):
			return
		var still: Array[Book] = []
		var on_shelf := shelf.get_books()
		for b in choice:
			if on_shelf.has(b):
				still.append(b)
		if still.is_empty():
			return
		shelf.remove_books(still, true)
		held.append_array(still)
		walker.give_bag(true, BASKET_MODELS[mini(3, held.size())])  # die Bücher liegen jetzt im Korb
		Audio.play_at("books/take", shelf.global_position + Vector3.UP, -4.0, Audio.vary(0.08))
	# ganz unten: bücken (Animation pick_up), sonst gleich nehmen
	if choice.any(func(b: Book) -> bool: return _row_height(shelf, b) <= GameConfig.visitor_bend_height):
		var face: Vector2 = visit.get("face", Vector2.ZERO)
		_note("bend")
		return [{"type": "stand", "anim": &"idle", "face": face, "clip": &"pick_up", "clip_max": 2.2, "time": 1.3,
			"cue": [0.9, take]}]
	take.call()
	return []


## Höhe des Fachs, in dem ein Buch steht (über dem Boden des Raums).
func _row_height(shelf: BookShelf, book: Book) -> float:
	var row := shelf.get_book_row(book)
	var rows := shelf.find_children("*", "BookRow", true, false)
	if row < 0 or row >= rows.size():
		return 0.8
	return (rows[row] as Node3D).global_position.y - room.global_position.y


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
	return _counter_node().global_transform * Vector3(-0.35, Counter.TOP_HEIGHT + GameConfig.counter_card_height, 0.38)


## E-Bereich auf der Theke („Bedienen“, nur wenn jemand wartet und man hinter der Theke steht) – öffnet die Theken-Ansicht.
func _add_stamp_interactable() -> void:
	# Nur ein schmaler Streifen über der Platte auf der Seite der Spielfigur, nur aktiv, wenn jemand wartet (sonst verdeckte er
	# Tablet und Bücher auf der Theke – seit Testrunde 7b), und die Theke leuchtet dabei nicht auf
	_stamp_interactable = Interactable.new()
	_stamp_interactable.name = "StampInteractable"
	_stamp_interactable.prompt_text = ""
	_stamp_interactable.highlight_owner = false
	_stamp_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.08, 0.3)
	_stamp_shape.shape = box
	_stamp_shape.disabled = true
	_stamp_interactable.add_child(_stamp_shape)
	_stamp_interactable.position = Vector3(-0.2, Counter.TOP_HEIGHT + 0.05, -0.15)
	_counter.add_child(_stamp_interactable)
	_stamp_interactable.interacted.connect(_on_stamp)
	# Theken-Ansicht (seit Etappe 8)
	_desk = CounterDesk.new()
	_desk.name = "CounterDesk"
	_counter.add_child(_desk)
	_desk.setup(self, _counter)


func _waiting_at_counter() -> Passerby:
	if queue.is_empty():
		return null
	var first := queue[0]
	if not is_instance_valid(first) or not _checkout.has(first) or int(_checkout[first]) >= 3 \
			or first.get_action_type() != "wait":
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


var _auto_wait := 0.0
var _debug_wait := 0.0


func _update_counter() -> void:
	if _counter_node() == null or _stamp_interactable == null:
		return
	var waiting := _waiting_at_counter()
	var word := ""
	if waiting and player_behind_counter() and not (_desk and _desk.is_open):
		word = "Bedienen"
	_stamp_interactable.prompt_text = word
	_stamp_shape.disabled = word.is_empty()
	if debug and not queue.is_empty():
		_debug_wait -= get_physics_process_delta_time()
		if _debug_wait <= 0.0:
			_debug_wait = 5.0
			var first := queue[0]
			print("  Theke: vorn %s, Schritt %s, Aktion %s, Schlange %d" % [first.name, _checkout.get(first, "-"),
				first.get_action_type(), queue.size()])
	if auto_stamp and waiting and _desk and not _desk.is_open:
		_auto_wait -= get_physics_process_delta_time()
		if _auto_wait <= 0.0:
			_auto_wait = 0.6
			_desk.auto_serve(waiting)


func _on_stamp(_who: Node) -> void:
	var walker := _waiting_at_counter()
	if walker == null or not player_behind_counter() or _desk == null:
		return
	_desk.open(walker)


# --- Für die Theken-Ansicht (CounterDesk) ---

## Wer wartet gerade vorn an der Theke (noch nicht fertig bedient)?
func waiting_guest() -> Passerby:
	return _waiting_at_counter()


## Der Gast gibt seinen Ausweis ab (er hält ihn nicht mehr hoch – er liegt jetzt auf der Theke).
func hand_over_card(walker: Passerby) -> void:
	if int(_checkout.get(walker, 0)) == 0:
		_checkout[walker] = 1
		walker.set_prop(&"")


func visit_books(walker: Passerby) -> Array[Book]:
	var books: Array[Book] = []
	for book: Book in (_visit.get(walker, {}) as Dictionary).get("books", []):
		books.append(book)
	return books


func visit_card(walker: Passerby) -> String:
	return str((_visit.get(walker, {}) as Dictionary).get("card", ""))


## Korb auf der Theke leer (die Bücher liegen gerade vor der Spielfigur) oder wieder gefüllt.
func show_basket_empty(empty: bool) -> void:
	if _counter_basket == null or not is_instance_valid(_counter_basket):
		return
	var t := _counter_basket.transform
	_counter_basket.queue_free()
	var walker := _waiting_at_counter()
	var count := 0 if empty or walker == null else _book_count(walker)
	var model := load(BASKET_MODELS[mini(3, count)]) as PackedScene
	_counter_basket = _place_on_counter(model.instantiate(), t.origin, t.basis)


## Ausgeliehen: Gebühren (das Geld ploppt beim Kontostand auf – kein Text), volle Stempelkarte = mehr Zeit; der Gast geht.
func complete_checkout(walker: Passerby, bonus: bool) -> void:
	if not is_instance_valid(walker):
		return
	var visit: Dictionary = _visit.get(walker, {})
	var books := visit_books(walker)
	Lending.lend(books, bool(visit.get("new", false)), GameConfig.stamp_bonus_extra_days if bonus else 0)
	visit.lent = true
	Audio.play("ui/kaching", GameConfig.checkout_kaching_db)
	Tutorial.report("guest_served")
	_checkout[walker] = 3


func _book_count(walker: Passerby) -> int:
	return ((_visit.get(walker, {}) as Dictionary).get("books", []) as Array).size()


## Etwas auf die Theke legen (Lage im Raum der Theke).
func _place_on_counter(node: Node3D, local: Vector3, basis: Basis) -> Node3D:
	var counter := _counter_node()
	counter.add_child(node)
	node.transform = Transform3D(basis, local)
	return node


## Korb des Besuchers auf die Kundenseite der Theke stellen (aus der Hand).
func _put_basket_on_counter(walker: Passerby) -> void:
	_clear_counter()
	walker.give_bag(false)
	var model := load(BASKET_MODELS[mini(3, _book_count(walker))]) as PackedScene
	if model == null:
		return
	_counter_basket = _place_on_counter(model.instantiate(), CounterDesk.BASKET + Vector3(0.0, Counter.TOP_HEIGHT + BASKET_DROP, 0.0),
		Basis(Vector3.UP, 0.4))
	Audio.play_at("books/place", _counter_basket.global_position, -6.0, Audio.vary(0.08))


func _clear_counter() -> void:
	if _counter_basket and is_instance_valid(_counter_basket):
		_counter_basket.queue_free()
	_counter_basket = null


## Der Korb des Gasts auf der Theke (oder null) – die Theken-Ansicht lässt ihn am Ende hinter die Theke gleiten.
func counter_basket() -> Node3D:
	return _counter_basket if _counter_basket and is_instance_valid(_counter_basket) else null


## Korb weg (hinter die Theke geräumt).
func clear_counter_basket() -> void:
	_clear_counter()


## Korb nehmen (take): seit dem Nachtest von Etappe 8 ohne Stapel – er ist einfach in der Hand, sobald der Gast hereinkommt
## (Wunsch der Entwicklerin). Zurückstellen gibt es nicht mehr (ohne Ausleihe bleibt er an der Tür, siehe _leave_actions).
func _basket_actions(take: bool) -> Array:
	if not take:
		return []
	return [_call(func(w: Passerby) -> Array:
		w.give_bag(true, BASKET_MODELS[0])
		return [])]


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
	# wer gern liest, nimmt lieber einen Platz am Tisch (seit Etappe 8)
	if _style(walker) == "liest":
		seats.sort_custom(func(a: SeatPoint, b: SeatPoint) -> bool: return _table_in_front(a) != null and _table_in_front(b) == null)
	for seat in seats:
		if not _seat_approach(seat).is_empty():
			return seat
	return null


## Wo man vor dem Hinsetzen steht: vor dem Sitz – steht dort ein Tisch, seitlich daneben. Leer, wenn kein Platz ist.
func _seat_approach(seat: SeatPoint) -> Dictionary:
	var front := seat.global_position + seat.global_basis.z * 0.5
	if _to2(_nearest_free(front)).distance_to(_to2(front)) < 0.35:
		return {"pos": front}
	if _table_in_front(seat) == null:
		return {}
	for side: float in [1.0, -1.0]:
		var aside := seat.global_position + seat.global_basis.x * side * 0.55 + seat.global_basis.z * 0.15
		var free := _nearest_free(aside)
		if _to2(free).distance_to(_to2(aside)) < 0.45:
			return {"pos": free}
	return {}


func _in_back_room(point: Vector3) -> bool:
	var local := room.to_local(point)
	return BackRoom.back_area().grow(0.05).has_point(Vector2(local.x, local.z))


## Stelle vor einem Regal (Welt) und Blickrichtung dorthin (2D), oder leer.
## Zum Regal: einen freien Platz davor wählen (links, Mitte, rechts – nie dort, wo schon jemand steht oder hingeht), stöbern,
## Bücher nehmen, Platz wieder freigeben (seit Testrunde 7b; vorher standen zwei am selben Fleck).
func _visit_shelf(walker: Passerby, shelf: BookShelf) -> Array:
	if not is_instance_valid(shelf):
		return []
	var spot := _shelf_spot(shelf, walker)
	if debug:
		print("  Regal %s Bücher %d Platz %s" % [shelf.get_path(), shelf.get_books().size(), spot])
	if spot.is_empty():
		return []
	_shelf_spots[walker] = spot.pos
	(_visit.get(walker, {}) as Dictionary)["face"] = spot.face
	var browse := _rng.randf_range(GameConfig.visitor_browse_time.x, GameConfig.visitor_browse_time.y)
	browse *= {"zielstrebig": 0.5, "stoebert": 1.6}.get(_style(walker), 1.0)
	return [_call(_go_to.bind(spot.pos)),
		{"type": "stand", "anim": &"browse", "face": spot.face, "time": browse},
		_call(_take_books.bind(shelf)),
		_call(func(w: Passerby) -> Array:
			_shelf_spots.erase(w)
			return [])]


func _shelf_spot(shelf: BookShelf, walker: Passerby) -> Dictionary:
	var item := FurnitureUtils.find_placed_furniture(shelf)
	var base := item if item else shelf as Node3D
	var forward := base.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var across := forward.cross(Vector3.UP).normalized()
	var face := Vector2(-forward.x, -forward.z)
	for offset: float in [0.0, -0.55, 0.55]:
		var desired := base.global_position + forward * 0.75 + across * offset
		var spot := _nearest_free(desired)
		if spot.distance_to(desired) > 0.9:
			continue
		var taken := false
		for other: Variant in _shelf_spots:
			if other != walker and is_instance_valid(other) and (_shelf_spots[other] as Vector3).distance_to(spot) < 0.5:
				taken = true
				break
		if not taken:
			return {"pos": spot, "face": face}
	return {}


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
	return ("drinnen %d, an der Theke %d, Stammgäste %d, Arten %s, am Tisch gelesen %d, gebückt %d, Wünsche %d (erfüllt %d), " +
		"Name passt zur Figur %d von %d, bekannte Gäste wieder da %d") % [
		Lending.visitors_inside(), queue.size(), counts.get("regular", 0), counts.get("styles", {}), counts.get("table", 0),
		counts.get("bend", 0), counts.get("wish", 0), counts.get("wish_done", 0), counts.get("name_ok", 0),
		int(counts.get("name_ok", 0)) + int(counts.get("name_wrong", 0)), counts.get("known_again", 0)]


## Zahlen für das Prüfwerkzeug (seit Etappe 8)
var counts := {"styles": {}}


func _note(key: String, sub: String = "") -> void:
	if sub.is_empty():
		counts[key] = int(counts.get(key, 0)) + 1
	else:
		var d: Dictionary = counts.get(key, {})
		d[sub] = int(d.get(sub, 0)) + 1
		counts[key] = d


# --- Stammgäste und Arten des Besuchs (seit Etappe 8) ---

func _style(walker: Passerby) -> String:
	return String((_visit.get(walker, {}) as Dictionary).get("style", "stoebert"))


func _pick_style() -> String:
	var weights: Dictionary = GameConfig.visit_style_weights
	var total := 0.0
	for key: String in weights:
		total += float(weights[key])
	var roll := _rng.randf() * total
	for key: String in weights:
		roll -= float(weights[key])
		if roll <= 0.0:
			return key
	return "stoebert"


## Sind schon so viele Besucher drinnen, wie hineinpassen?
func visitors_full() -> bool:
	return Lending.visitors_inside() >= Lending.max_at_once()


## Beim Losgehen eines Passanten, dessen Weg an der Bücherei vorbeiführt (StreetLife._launch, noch ungesehen): manchmal
## wird er ein Stammgast (festes Aussehen aus dem Namen); wer vorher einer war, bekommt ein neues, zufälliges Aussehen.
func assign_regular(walker: Passerby) -> void:
	# Seit dem Nachtest von Etappe 8: jeder, der an der Bücherei vorbeikommt, bekommt hier (noch ungesehen) ein Aussehen, das sich
	# merken lässt – Stammgäste und bekannte Gäste ihr eigenes, alle anderen ein neues (mit Ausweis gemerkt, falls sie hereinkommen)
	var was_known := not walker.regular_id.is_empty() or not walker.reader_id.is_empty()
	walker.regular_id = ""
	walker.reader_id = ""
	var busy := {}
	for other: Passerby in life._walkers:
		if other.active:
			busy[other.regular_id] = true
			busy[other.reader_id] = true
	if Lending.accepts_visitors() and _rng.randf() < GameConfig.regular_chance:
		var candidates: Array[Dictionary] = []
		var weights: Array[float] = []
		for regular in Regulars.all():
			var info := Lending.reader_info(regular.id)
			if busy.has(regular.id) or int(info.get("last_day", -1)) == GameClock.day:
				continue
			candidates.append(regular)
			weights.append(1.0 + Lending.friendship(regular.id) * 0.3)
		if not candidates.is_empty():
			var pick := candidates[_rng.rand_weighted(PackedFloat32Array(weights))]
			_apply_look(walker, int(pick.seed), int(pick.female))
			walker.regular_id = pick.id
			return
	# ein Gast, der schon einen Ausweis hat, kommt wieder – genauso, wie er beim ersten Mal aussah
	if Lending.accepts_visitors() and not Lending.roll_new_reader():
		var id := Lending.known_reader(busy)
		if not id.is_empty():
			var info := Lending.reader_info(id)
			_apply_look(walker, int(info.look), int(info.female))
			walker.reader_id = id
			return
	# sonst ein Unbekannter: neues Aussehen nur, wenn er bisher jemand Bekanntes war oder noch keines gemerkt hat
	if was_known or walker.look_seed == 0:
		_apply_look(walker, _rng.randi(), -1)
		walker.restyle(_rng)  # Unbekannte tragen manchmal eine Einkaufstasche


## Aussehen aus einer Zahl (immer gleich), Frau/Mann fest (1/0) oder zufällig (-1). Stammgäste und bekannte Gäste kommen ohne
## Einkaufstasche (sonst kämen sie nicht herein).
func _apply_look(walker: Passerby, seed: int, female: int) -> void:
	var look := RandomNumberGenerator.new()
	look.seed = seed
	walker.randomize_look(look, female)
	walker.look_seed = seed
	if female >= 0:
		walker.give_bag(false)


## Nur zurückbringen: zur Theke, Bücher auf die Kundenseite legen (bücken), wieder gehen.
func _return_actions(walker: Passerby) -> Array:
	var counter := _counter_node()
	if counter == null:
		return _leave_actions(walker)
	var spot := _nearest_free(counter.global_transform * Vector3(0.55, 0.0, 0.325 + 0.35))
	return [_call(_go_to.bind(spot)),
		{"type": "stand", "anim": &"idle", "face": _counter_face(), "clip": &"pick_up", "clip_max": 2.0, "time": 1.4,
			"cue": [0.8, func(_w: Passerby) -> void: Lending.return_oldest_to_counter()]},
		_call(_leave_actions)]


## Steht vor diesem Sitzplatz ein Tisch (Ablagefläche eines Tischs, 0,3–0,7 m hoch, bis 0,8 m vor dem Sitz)? Dann der Punkt
## auf der Platte, wo das Buch aufgeschlagen liegt – sonst null.
func _table_in_front(seat: SeatPoint) -> Variant:
	var forward := seat.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Variant = null
	var best_d := 0.8
	for item in room.get_placed_furniture():
		if item.data == null or item.data.category != FurnitureData.Category.TABLE:
			continue
		for surface in FurnitureUtils.find_surfaces(item):
			var top := surface.get_surface_height() - room.global_position.y
			if top < 0.3 or top > 0.7:
				continue
			var to := surface.global_position - seat.global_position
			to.y = 0.0
			var ahead := to.dot(forward)
			if ahead < 0.15 or ahead > best_d or absf(to.dot(forward.cross(Vector3.UP))) > 0.6:
				continue
			best_d = ahead
			var point := seat.global_position + forward * minf(ahead, 0.38)
			best = Vector3(point.x, surface.get_surface_height() + 0.012, point.z)
	return best


# --- Wünsche (seit Etappe 8) ---

var _wish_bubbles := {}        # Gast → Node3D (Gedankenblase)
var _wish_viewport: SubViewport
var _wish_time := 0.0
const WISH_FONT := preload("res://assets/ui/fonts/Caveat-Bold.woff2")


## Hat der Gast einen angenommenen Wunsch, und hält die Spielfigur ein Buch? (dann zählt ein Linksklick auf ihn als Geben)
func wants_book_from_player(walker: Passerby) -> bool:
	var wish: Dictionary = (_visit.get(walker, {}) as Dictionary).get("wish", {})
	return String(wish.get("state", "")) == "accepted" and BookStock.get_active_book() != null


## Schritte fürs Gespräch: offener Wunsch → er sagt ihn (annehmen oder ablehnen); angenommener → er wartet; sonst leer
## (dann das übliche Gespräch).
func wish_steps(walker: Passerby) -> Array:
	var visit: Dictionary = _visit.get(walker, {})
	var wish: Dictionary = visit.get("wish", {})
	var state := String(wish.get("state", ""))
	var hour := GameClock.minute_of_day() / 60.0
	var genre := Catalog.get_genre(String(wish.get("genre", "")))
	if genre == null or not state in ["open", "accepted"]:
		return []
	var line := func(section: String) -> String:
		return String(TalkLines.pick(section, hour, _rng).get("text", "")).replace("{genre}", "„%s“" % genre.display_name)
	var steps: Array = []
	if state == "accepted":
		steps.append({"text": line.call("wunsch_wartet")})
		return steps
	var hello := String(TalkLines.pick("gruss", hour, _rng).get("text", "Hallo!"))
	steps.append({"text": hello})
	steps.append({"text": line.call("wunsch"), "answers": [
		{"text": "Ich suche dir etwas heraus!", "reply": line.call("wunsch_ja"), "then": func() -> void: wish.state = "accepted"},
		{"text": "Leider gerade nicht.", "reply": line.call("wunsch_nein"), "then": func() -> void: wish.state = "declined"}]})
	return steps


## Linksklick mit Buch auf einen Gast: passt das Genre zum Wunsch, nimmt er es (in den Korb), stöbert weiter und gibt
## Trinkgeld; sonst schüttelt er freundlich den Kopf.
func give_book(walker: Passerby) -> void:
	var visit: Dictionary = _visit.get(walker, {})
	var wish: Dictionary = visit.get("wish", {})
	var book := BookStock.get_active_book()
	if book == null or String(wish.get("state", "")) != "accepted":
		return
	if book.genre_id != String(wish.genre):
		if walker._model and walker._model.has_method("trigger_face"):
			walker._model.call("trigger_face", &"window_wonder")
		if walker._model and walker._model.has_method("shake_head"):
			walker._model.call("shake_head")
		return
	BookStock.take_active()
	(visit.books as Array).append(book)
	walker.give_bag(true, BASKET_MODELS[mini(3, (visit.books as Array).size())])
	wish.state = "fulfilled"
	Wallet.earn(GameConfig.wish_tip, "Trinkgeld")
	Tutorial.report("wish")
	if not walker.regular_id.is_empty():
		Lending.add_friendship(walker.regular_id, GameConfig.wish_friendship)
	Audio.play_at("books/place", walker.global_position + Vector3.UP, -4.0, Audio.vary(0.08))
	if walker._model and walker._model.has_method("trigger_face"):
		walker._model.call("trigger_face", &"window_like")
	_note("wish_done")
	# kleines Dankeschön in der Sprechblase
	var thanks := String(TalkLines.pick("wunsch_danke", GameClock.minute_of_day() / 60.0, _rng).get("text", "Danke!"))
	Conversation.begin(walker, life.get_player(), [{"text": thanks}])


func _update_wish_bubbles(delta: float) -> void:
	_wish_time += delta
	for walker: Variant in _visit.keys():
		var w := walker as Passerby
		if w == null or not is_instance_valid(w):
			continue
		var wish: Dictionary = (_visit[w] as Dictionary).get("wish", {})
		var state := String(wish.get("state", ""))
		var show := state in ["open", "accepted"] and w.active and w.in_library
		var bubble: Node3D = _wish_bubbles.get(w)
		if show and bubble == null:
			bubble = _make_wish_bubble()
			_wish_bubbles[w] = bubble
		if bubble == null:
			continue
		if not show:
			bubble.queue_free()
			_wish_bubbles.erase(w)
			continue
		var symbol_sprite := bubble.get_node("Symbol") as Sprite3D
		var question := bubble.get_node("Question") as Label3D
		if state == "accepted" and symbol_sprite.texture == null:
			var genre := Catalog.get_genre(String(wish.genre))
			symbol_sprite.texture = BookArt.get_symbol_texture(genre.symbol) if genre else null
		symbol_sprite.visible = state == "accepted"
		question.visible = state == "open"
		var eye: Vector3 = w._model.call("eye_point") if w._model and w._model.has_method("eye_point") else w.global_position + Vector3.UP * 1.3
		bubble.global_position = eye + Vector3.UP * (GameConfig.wish_bubble_height + sin(_wish_time * 2.0 + hash(w) % 7) * 0.02)
	for walker: Variant in _wish_bubbles.keys():
		if not is_instance_valid(walker) or not _visit.has(walker):
			(_wish_bubbles[walker] as Node).queue_free()
			_wish_bubbles.erase(walker)


## Gedankenblase: weiße Wolke mit zwei kleinen Kreisen (immer zur Kamera gedreht), darin „?“ oder das Genre-Zeichen.
func _make_wish_bubble() -> Node3D:
	var root := Node3D.new()
	root.name = "WishBubble"
	life.add_child(root)
	root.top_level = true
	var cloud := Sprite3D.new()
	cloud.texture = _wish_cloud_texture()
	cloud.pixel_size = 0.34 / 256.0
	cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cloud.shaded = false
	cloud.no_depth_test = false
	cloud.render_priority = 1
	root.add_child(cloud)
	var question := Label3D.new()
	question.name = "Question"
	question.text = "?"
	question.font = WISH_FONT
	question.font_size = 140
	question.pixel_size = 0.0011
	question.modulate = Color(0.84, 0.47, 0.47)
	question.outline_size = 0
	question.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	question.position = Vector3(0.0, 0.015, 0.0)
	question.render_priority = 2
	root.add_child(question)
	var symbol := Sprite3D.new()
	symbol.name = "Symbol"
	symbol.pixel_size = 0.13 / float(BookArt.SYMBOL_CELL)
	symbol.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	symbol.shaded = false
	symbol.position = Vector3(0.0, 0.015, 0.0)
	symbol.render_priority = 2
	symbol.visible = false
	root.add_child(symbol)
	return root


func _wish_cloud_texture() -> Texture2D:
	if _wish_viewport == null:
		_wish_viewport = SubViewport.new()
		_wish_viewport.size = Vector2i(256, 256)
		_wish_viewport.transparent_bg = true
		_wish_viewport.disable_3d = true
		_wish_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(_wish_viewport)
		var painter := _CloudPainter.new()
		painter.size = Vector2(256, 256)
		_wish_viewport.add_child(painter)
	return _wish_viewport.get_texture()


class _CloudPainter extends Control:
	func _draw() -> void:
		var paper := Color(1.0, 0.985, 0.95)
		var line := Color(0.5, 0.39, 0.32, 0.5)
		var c := Vector2(128, 104)
		var puffs := [[Vector2(-52, 6), 44.0], [Vector2(0, -18), 54.0], [Vector2(52, 4), 44.0], [Vector2(-22, 34), 40.0], [Vector2(28, 34), 40.0]]
		for p: Array in puffs:
			draw_circle(c + (p[0] as Vector2), float(p[1]) + 3.0, line)
		for p: Array in puffs:
			draw_circle(c + (p[0] as Vector2), float(p[1]), paper)
		for small: Array in [[Vector2(70, 196), 14.0], [Vector2(52, 228), 8.0]]:
			draw_circle(small[0], float(small[1]) + 2.5, line)
			draw_circle(small[0], float(small[1]), paper)
