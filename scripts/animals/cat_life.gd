class_name CatLife
extends Node3D
## Katzen auf der Straße (seit Etappe 6g). Entsteht beim Start des Straßenlebens als Kind von StreetLife
## ("Outside/StreetLife/Cats") und wird von StreetLife.step mitbewegt.
##
## Jede Katze hat ihr eigenes Aussehen (GameConfig.cat_looks, je Aussehen genau eine Katze). Ab und zu
## (GameConfig.cat_interval) kommt eine vorbei – wie Passanten nur von den verdeckten Straßenenden her und
## nur dorthin zurück (verschwindet erst, wenn niemand hinschaut). Unterwegs (Chancen in GameConfig):
## - setzt sie sich auf eine Bank oder einen Stuhl (StreetSeat) oder auf eine breite Fensterbank
##   (data/animals/spots.json, "cat"), putzt sich, streckt sich, schläft,
## - schaut durchs Schaufenster in die Bücherei (Punkt WindowSpots/LibraryFront),
## - kommt bei offener Tür herein, legt sich auf einen freien Sessel oder ein Sofa (sonst auf einen Teppich),
##   schnurrt und geht irgendwann wieder (bei geschlossener Tür wartet sie davor und miaut leise),
## - spielt mit einer zweiten Katze Fangen oder trägt eine kleine Filzmaus.
## Katzen gehen nah an den Hauswänden, warten, wenn jemand im Weg ist, und überqueren die Straße nur, wenn
## kein Fahrzeug kommt; Fahrzeuge bremsen für sie (StreetLife.road_obstacles), Passanten gehen um sie herum.

const SPOTS_FILE := "res://data/animals/spots.json"
const TOY_SCENE := "res://assets/models/animals/cat_toy.glb"
## Raster für Wege in der Bücherei (m) und was dort im Weg ist (world, furniture)
const GRID_CELL := 0.15
const FURNITURE_MASK := 1 | 8
## Abstand der Wege zur Hauswand und zu festen Hindernissen (m)
const WALL_GAP := 0.1
const STATIC_GAP := 0.24

var street: StreetLife
## Zähler für das Prüfwerkzeug: Erscheinen bzw. Verschwinden im Blickfeld (muss 0 bleiben)
var visible_spawns := 0
var visible_exits := 0
var visits := 0
var entered := 0

var _outside: Node3D
var _rng := RandomNumberGenerator.new()
var _pool: Array[StreetCat] = []
var _cats: Array[StreetCat] = []
var _timer := 0.0
## Fensterbänke für Katzen: { pos (Welt), out, taken }
var _sills: Array[Dictionary] = []
var _door: Door
var _room: Room


func setup(life: StreetLife) -> void:
	street = life
	_outside = life.get_parent() as Node3D
	_rng.randomize()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPOTS_FILE)) if FileAccess.file_exists(SPOTS_FILE) else null
	if data is Dictionary:
		for p: Dictionary in data.get("perches", []):
			if p.get("cat", false):
				_sills.append({"pos": _outside.to_global(Vector3(p.pos[0], p.pos[1], p.pos[2])),
					"out": Vector3(p.out[0], 0.0, p.out[1]).normalized(), "taken": null})
	_door = get_tree().get_first_node_in_group("doors") as Door
	_room = _outside.get_parent().get_node_or_null("GroundFloorRoom") as Room
	_build_pool()
	_timer = _rng.randf_range(GameConfig.cat_first_delay.x, GameConfig.cat_first_delay.y)


func seed_random(value: int) -> void:
	_rng.seed = value


func get_cats() -> Array[StreetCat]:
	return _cats


func _build_pool() -> void:
	var scene := load(GameConfig.cat_scene) as PackedScene
	if scene == null:
		return
	var toy_scene := load(TOY_SCENE) as PackedScene
	for i in GameConfig.cat_looks.size():
		var cat := scene.instantiate() as StreetCat
		cat.name = "Cat%d" % (i + 1)
		cat.life = self
		cat.look = i
		add_child(cat)
		var look: Dictionary = GameConfig.cat_looks[i]
		cat.apply_look("cat_%d" % i, {"Katze Fell": look.fur, "Katze Fell hell": look.fur2, "Katze Auge": look.eye},
			{"Katze Fell": {"tabby": float(look.get("tabby", 0.0)), "tabby_color": look.get("tabby_color", Color.WHITE)}})
		cat.scale = Vector3.ONE * float(look.get("size", 1.0))
		cat.radius = 0.2 * cat.scale.x
		cat.finished.connect(_on_finished)
		if toy_scene:
			var toy := toy_scene.instantiate() as Node3D
			toy.name = "Toy%d" % (i + 1)
			_store_toy(toy)
			cat.set_meta("toy", toy)
		_pool.append(cat)


## Spielzeug, das gerade niemand trägt: versteckt unter CatLife.
func _store_toy(toy: Node3D) -> void:
	if toy.get_parent():
		toy.get_parent().remove_child(toy)
	add_child(toy)
	toy.visible = false


# --- Ablauf ---

func step(delta: float) -> void:
	for cat in _cats.duplicate():
		cat.step(delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(GameConfig.cat_interval.x, GameConfig.cat_interval.y)
		_spawn()


func _spawn() -> void:
	if _cats.size() >= GameConfig.cat_count or _pool.is_empty():
		return
	var start := _pick_end({})
	if start.is_empty():
		_timer = 3.0
		return
	var pair := _cats.is_empty() and _pool.size() >= 2 and GameConfig.cat_count >= 2 and _rng.randf() < GameConfig.cat_play_chance * 0.6
	var leader := _take_cat()
	var exit := _pick_end(start)
	if exit.is_empty():
		exit = start
	var actions: Array[Dictionary] = []
	var from := _side_point(start.side, start.s)
	actions.append(_walk([_ground(start.pos), from]))
	if pair:
		# Fangen: die erste rennt ein Stück, wartet, rennt weiter; die zweite rennt hinterher
		var dir := signf(exit.s - start.s) if exit.s != start.s else 1.0
		var s1: float = start.s + dir * _rng.randf_range(5.0, 7.0)
		var s2: float = s1 + dir * _rng.randf_range(4.0, 6.0)
		actions.append(_walk_along(start.side, start.s, s1, GameConfig.cat_run_speed, true))
		actions.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(1.2, 2.0)})
		actions.append(_walk_along(start.side, s1, s2, GameConfig.cat_run_speed, true))
		actions.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 5.0)})
		actions.append_array(_visit(start.side, s2, exit))
	else:
		actions.append_array(_visit(start.side, start.s, exit))
	if _rng.randf() < GameConfig.cat_toy_chance and leader.has_meta("toy"):
		leader.give_toy(leader.get_meta("toy"))
	leader.begin(_ground(start.pos), from - _ground(start.pos), actions)
	visits += 1
	if is_visible_point(leader.global_position + Vector3.UP * 0.2):
		visible_spawns += 1
	if pair:
		var chaser := _take_cat()
		var follow: Array[Dictionary] = [{"type": "anim", "anim": "idle", "time": 0.9},
			{"type": "follow", "cat": leader, "time": _rng.randf_range(9.0, 13.0), "distance": 0.65},
			{"type": "anim", "anim": "sit", "time": _rng.randf_range(2.0, 3.5)},
			{"type": "call", "callable": _continue_visit}]
		chaser.begin(_ground(start.pos), from - _ground(start.pos), follow)
		visits += 1


func _take_cat() -> StreetCat:
	var cat: StreetCat = _pool.pop_at(_rng.randi() % _pool.size())
	_cats.append(cat)
	return cat


func _on_finished(cat: StreetCat) -> void:
	if not cat in _cats:
		return
	if is_visible_point(cat.global_position + Vector3.UP * 0.2):
		visible_exits += 1
	_release_claims(cat)
	var toy := cat.take_toy_away()
	if toy:
		cat.set_meta("toy", toy)
	# abgelegt und nicht wieder aufgenommen (Besuch abgebrochen): auch zurück
	var own: Node3D = cat.get_meta("toy", null)
	if own:
		_store_toy(own)
	cat.reset()
	_cats.erase(cat)
	_pool.append(cat)


## Jemand versperrt den Weg: draußen in einem kleinen Bogen zur Straße hin außen herum; klappt das nicht
## (oder ist auch der Bogen versperrt), umkehren zum nächsten verdeckten Ende. Drinnen weiter warten.
func blocked(cat: StreetCat, dir: Vector3) -> void:
	if cat.inside:
		return
	if not cat.in_detour():
		var local := _outside.to_local(cat.global_position)
		var lage := street.centerline.project(Vector2(local.x, local.z))
		var side := 1.0 if lage.y > 0.0 else -1.0
		var normal := street.centerline.normal_at(lage.x)
		var away := Vector3(normal.x, 0.0, normal.y) * -side
		var p1 := cat.global_position + away * 0.75 + dir * 0.35
		var p2 := p1 + dir * 1.4
		var p3 := cat.global_position + dir * 2.2
		var ok := true
		for p in [p1, p2]:
			var l := _outside.to_local(p)
			var lat := street.centerline.project(Vector2(l.x, l.z)).y
			if absf(lat) < GameConfig.street_width / 2.0 + 0.35 or not street.clear_of_static(Vector2(l.x, l.z), STATIC_GAP):
				ok = false
		if ok:
			cat.detour(PackedVector3Array([p1, p2, p3]))
			return
	_release_claims(cat)
	_continue_visit(cat, true)


## Vom jetzigen Ort aus weiter: vielleicht noch ein Halt, dann zu einem verdeckten Ende.
func _continue_visit(cat: StreetCat, turn_back: bool = false) -> void:
	var local := _outside.to_local(cat.global_position)
	var lage := street.centerline.project(Vector2(local.x, local.z))
	var side := 1 if lage.y > 0.0 else -1
	var here := {"s": lage.x}
	var exit := _pick_end(here, cat.global_basis.z if turn_back else Vector3.ZERO)
	if exit.is_empty():
		exit = _pick_end({})
	if exit.is_empty():
		return
	var actions: Array[Dictionary] = [_walk([cat.global_position, _side_point(side, lage.x)])]
	actions.append_array(_visit(side, lage.x, exit, not turn_back))
	cat.replace_actions(actions)


## Release: Fensterbank und Sitz wieder frei.
func _release_claims(cat: StreetCat) -> void:
	for sill in _sills:
		if sill.taken == cat:
			sill.taken = null
	cat._release_seat()


# --- Besuch planen ---

## Ein verdecktes Straßenende (Ort zum Erscheinen/Verschwinden der Passanten): { pos (x, z), s, side, place }.
## Mit from: möglichst das andere Ende (bzw. das hinter der Katze, wenn away gesetzt ist).
func _pick_end(from: Dictionary, away: Vector3 = Vector3.ZERO) -> Dictionary:
	var options: Array[Dictionary] = []
	for place in street.get_places():
		if place.kind != "walker" or not place.place in ["east", "west"]:
			continue
		if from.is_empty() and street.is_visible_spot(place.pos, 0.4, 0.3):
			continue
		var s := street.centerline.project(place.pos).x
		options.append({"pos": place.pos, "s": s, "side": place.side, "place": place.place})
	if options.is_empty():
		return {}
	if from.is_empty():
		return options[_rng.randi() % options.size()]
	options.shuffle()
	if away != Vector3.ZERO:
		# umkehren: das Ende in Blickrichtung zurück (Katze schaut gerade nach vorn – also das andere)
		var ahead := street.centerline.direction_at(from.s)
		var going := signf(Vector2(away.x, away.z).dot(ahead))
		for o in options:
			if signf(o.s - from.s) == -going:
				return o
	var best: Dictionary = options[0]
	for o in options:
		if absf(o.s - from.s) > absf(best.s - from.s):
			best = o
	return best


## Halt-Punkte zwischen s0 und dem Ende, dann zum Ende und verschwinden.
func _visit(side: int, s0: float, exit: Dictionary, stops: bool = true) -> Array[Dictionary]:
	var dir := signf(exit.s - s0) if absf(exit.s - s0) > 0.1 else 1.0
	var plan: Array[Dictionary] = []
	if stops:
		var lo := minf(s0, exit.s)
		var hi := maxf(s0, exit.s)
		var used_seat := false
		if _rng.randf() < GameConfig.cat_seat_chance:
			var seats: Array[Dictionary] = []
			for e in street.get_street_seats():
				if e.s > lo + 1.0 and e.s < hi - 1.0 and (e.seat as SeatPoint).is_free():
					seats.append(e)
			if not seats.is_empty():
				var e: Dictionary = seats[_rng.randi() % seats.size()]
				plan.append({"kind": "seat", "s": e.s, "side": e.side, "entry": e})
				used_seat = true
		if not used_seat and _rng.randf() < GameConfig.cat_sill_chance:
			var free: Array[Dictionary] = []
			for sill in _sills:
				var l := _outside.to_local(sill.pos)
				var lage := street.centerline.project(Vector2(l.x, l.z))
				if sill.taken == null and lage.x > lo + 1.0 and lage.x < hi - 1.0:
					free.append({"kind": "sill", "s": lage.x, "side": 1 if lage.y > 0.0 else -1, "sill": sill})
			if not free.is_empty():
				plan.append(free[_rng.randi() % free.size()])
		var window := street.get_node_or_null("WindowSpots/LibraryFront") as Node3D
		var entrance := StreetPaths.library_entrance()
		var entrance_s := street.centerline.project(entrance).x
		if _door and _room and _rng.randf() < GameConfig.cat_enter_chance and entrance_s > lo and entrance_s < hi:
			plan.append({"kind": "door", "s": entrance_s, "side": 1})
		elif window and _rng.randf() < GameConfig.cat_window_chance:
			var w := _outside.to_local(window.global_position)
			var ws := street.centerline.project(Vector2(w.x, w.z)).x
			if ws > lo and ws < hi:
				plan.append({"kind": "window", "s": ws, "side": 1, "node": window})
		if plan.is_empty():
			plan.append({"kind": "pause", "s": s0 + dir * _rng.randf_range(4.0, 9.0), "side": side})
		plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.s - b.s) * dir < 0.0)
	var actions: Array[Dictionary] = []
	var cur_side := side
	var cur_s := s0
	for stop in plan:
		if stop.side != cur_side:
			actions.append(_walk_along(cur_side, cur_s, stop.s))
			actions.append(_cross(cur_side, stop.s))
			cur_side = stop.side
			cur_s = stop.s
		actions.append(_walk_along(cur_side, cur_s, stop.s))
		cur_s = stop.s
		actions.append_array(_stop_actions(stop, _side_point(cur_side, cur_s)))
		if _rng.randf() < 0.3:
			actions.append(_pause())
	if exit.side != cur_side:
		var cross_s: float = cur_s + (exit.s - cur_s) * 0.3
		actions.append(_walk_along(cur_side, cur_s, cross_s))
		actions.append(_cross(cur_side, cross_s))
		cur_side = exit.side
		cur_s = cross_s
	actions.append(_walk_along(cur_side, cur_s, exit.s))
	actions.append(_walk([_side_point(cur_side, exit.s), _ground(exit.pos)]))
	actions.append({"type": "leave"})
	return actions


func _pause() -> Dictionary:
	var roll := _rng.randf()
	if roll < 0.4:
		return {"type": "anim", "anim": "sit", "time": _rng.randf_range(2.0, 5.0)}
	if roll < 0.75:
		return {"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 6.0)}
	return {"type": "anim", "anim": "stretch", "time": 0.0}


## Schritte für einen Halt; beginnt und endet am Punkt back auf dem Gehweg.
func _stop_actions(stop: Dictionary, back: Vector3) -> Array[Dictionary]:
	var a: Array[Dictionary] = []
	var rest := _rng.randf_range(GameConfig.cat_rest_time.x, GameConfig.cat_rest_time.y)
	match String(stop.kind):
		"seat":
			var e: Dictionary = stop.entry
			var seat: SeatPoint = e.seat
			var approach := _ground(e.approach)
			var face := Vector3(e.face.x, 0.0, e.face.y)
			a.append(_walk([back, approach]))
			a.append({"type": "claim", "callable": func(cat: StreetCat) -> bool: return _claim_seat(cat, seat)})
			a.append({"type": "jump", "to": seat.global_position, "face": face})
			a.append({"type": "rest_on", "node": seat})
			a.append({"type": "toy_drop"})
			a.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(3.0, 6.0)})
			a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(4.0, 7.0)})
			a.append({"type": "anim", "anim": "lie" if _rng.randf() < 0.4 else "sleep", "time": rest, "blend": 0.6})
			a.append({"type": "anim", "anim": "sit", "time": 1.5, "blend": 0.6})
			a.append({"type": "toy_take"})
			a.append({"type": "rest_off"})
			a.append({"type": "jump", "to": approach, "face": -face})
			a.append({"type": "release_seat"})
			a.append({"type": "anim", "anim": "stretch", "time": 0.0})
			a.append({"type": "claim_end"})
			a.append(_walk([approach, back]))
		"sill":
			var sill: Dictionary = stop.sill
			var out: Vector3 = sill.out
			var front: Vector3 = _ground_at(sill.pos + out * 0.45)
			a.append(_walk([back, front]))
			a.append({"type": "claim", "callable": func(cat: StreetCat) -> bool: return _claim_sill(cat, sill)})
			a.append({"type": "turn", "face": -out})
			a.append({"type": "jump", "to": sill.pos, "face": -out})
			a.append({"type": "turn", "face": out.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))})
			a.append({"type": "toy_drop"})
			a.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(3.0, 6.0)})
			a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 6.0)})
			a.append({"type": "anim", "anim": "lie", "time": rest * 0.7, "blend": 0.6})
			a.append({"type": "toy_take"})
			a.append({"type": "jump", "to": front + out * 0.15, "face": out})
			a.append({"type": "call", "callable": func(cat: StreetCat) -> void: _release_claims(cat)})
			a.append({"type": "claim_end"})
			a.append(_walk([front + out * 0.15, back]))
		"window":
			var node: Node3D = stop.node
			var face := -node.global_basis.z
			face.y = 0.0
			var spot := _ground_at(node.global_position + face.normalized() * 0.3)
			a.append(_walk([back, spot]))
			a.append({"type": "turn", "face": face})
			a.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(10.0, 20.0), "face": face})
			if _rng.randf() < 0.5:
				a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 5.0), "face": face})
			a.append(_walk([spot, back]))
		"door":
			var entrance := _ground(StreetPaths.library_entrance())
			var inward := -StreetLayout.door_outward()
			a.append(_walk([back, entrance]))
			a.append({"type": "turn", "face": inward})
			a.append({"type": "call", "callable": func(cat: StreetCat) -> void: _door_choice(cat, 0)})
			a.append(_walk([entrance, back]))
		"pause":
			a.append(_pause())
	return a


func _claim_sill(cat: StreetCat, sill: Dictionary) -> bool:
	if sill.taken != null and sill.taken != cat:
		return false
	sill.taken = cat
	return true


func _claim_seat(cat: StreetCat, seat: SeatPoint) -> bool:
	if not is_instance_valid(seat) or not seat.is_free():
		return false
	seat.occupant = cat
	cat.seat = seat
	return true


## Vor der Treppe der Bücherei: Tür offen → hinein; sonst kurz warten und noch einmal schauen.
func _door_choice(cat: StreetCat, tries: int) -> void:
	if door_open():
		var inside := _inside_actions(cat)
		if not inside.is_empty():
			entered += 1
			cat.insert_actions(inside)
			return
	if tries == 0:
		cat.insert_actions([{"type": "anim", "anim": "sit", "time": _rng.randf_range(5.0, 10.0)},
			{"type": "call", "callable": func(c: StreetCat) -> void: _door_choice(c, 1)}])


# --- Wege ---

func _route(side: int) -> StreetRoute:
	return street.sidewalks[side]


## Gehweg-Punkt (Welt) an der Stelle s: nah an der Hauswand, mit Abstand zu Laternen, Bänken, Treppe.
func _side_point(side: int, s: float) -> Vector3:
	var route := _route(side)
	var band := route.band_at(s)
	var lat := band.y + WALL_GAP if side > 0 else band.x - WALL_GAP
	var p := route.point_at(s, lat)
	for i in 14:
		if street.clear_of_static(p, STATIC_GAP):
			break
		lat -= side * 0.1
		p = route.point_at(s, lat)
	return _ground(p)


func _walk_along(side: int, s0: float, s1: float, speed: float = -1.0, run: bool = false) -> Dictionary:
	var points := PackedVector3Array()
	var n := maxi(1, int(absf(s1 - s0) / 0.4))
	for i in n + 1:
		points.append(_side_point(side, lerpf(s0, s1, float(i) / n)))
	return {"type": "walk", "points": points, "speed": speed if speed > 0.0 else GameConfig.cat_walk_speed, "run": run}


func _walk(list: Array, speed: float = -1.0) -> Dictionary:
	var points := PackedVector3Array()
	for p: Vector3 in list:
		points.append(p)
	return {"type": "walk", "points": points, "speed": speed if speed > 0.0 else GameConfig.cat_walk_speed}


## Über die Straße flitzen (gerade hinüber, erst wenn frei).
func _cross(side: int, s: float) -> Dictionary:
	var a := _side_point(side, s)
	var b := _side_point(-side, s)
	return {"type": "cross", "points": PackedVector3Array([a, b]), "speed": GameConfig.cat_run_speed, "run": true}


func _ground(p: Variant) -> Vector3:
	if p is Vector2:
		return _outside.to_global(Vector3(p.x, 0.0, p.y))
	return p as Vector3


func _ground_at(p: Vector3) -> Vector3:
	return Vector3(p.x, _outside.global_position.y, p.z)


# --- In der Bücherei ---

## Hinein, auf einen Sessel (oder Teppich), schlafen und schnurren, wieder hinaus. Leer = geht nicht.
func _inside_actions(cat: StreetCat) -> Array[Dictionary]:
	var target := _inside_target()
	if target.is_empty():
		return []
	var door := StreetLayout.door_center()
	var out := StreetLayout.door_outward()
	var room_y := _room.global_position.y + _room.floor_height
	var door_point := Vector3(door.x, room_y, door.z)
	var door_in := door_point - out * 0.55
	var grid := _room_grid()
	var path := _find_path(grid, door_in, target.front)
	if path.is_empty():
		return []
	var stairs := _stairs_up(door_point, out, room_y)
	var a: Array[Dictionary] = []
	a.append(_walk(stairs))
	a.append({"type": "inside", "value": true})
	var walk_in: Array = [door_point, door_in]
	walk_in.append_array(path)
	a.append(_walk(walk_in))
	var rest := _rng.randf_range(GameConfig.cat_inside_time.x, GameConfig.cat_inside_time.y)
	if target.has("seat"):
		var seat: SeatPoint = target.seat
		var face := seat.global_basis.z
		face.y = 0.0
		a.append({"type": "claim", "callable": func(c: StreetCat) -> bool: return _claim_seat(c, seat)})
		a.append({"type": "jump", "to": seat.global_position, "face": face})
		a.append({"type": "rest_on", "node": seat})
	else:
		a.append({"type": "turn", "face": target.face})
	a.append({"type": "toy_drop"})
	a.append({"type": "anim", "anim": "lie", "time": _rng.randf_range(4.0, 8.0), "blend": 0.6})
	a.append({"type": "purr_on"})
	a.append({"type": "anim", "anim": "sleep", "time": rest, "blend": 0.8})
	a.append({"type": "purr_off"})
	a.append({"type": "anim", "anim": "sit", "time": 2.0, "blend": 0.6})
	a.append({"type": "toy_take"})
	if target.has("seat"):
		a.append({"type": "rest_off"})
		a.append({"type": "jump", "to": target.front, "face": -(target.seat as SeatPoint).global_basis.z})
		a.append({"type": "release_seat"})
		a.append({"type": "claim_end"})
	a.append({"type": "anim", "anim": "stretch", "time": 0.0})
	var walk_out: Array = path.duplicate()
	walk_out.reverse()
	walk_out.append(door_in)
	a.append(_walk(walk_out))
	a.append({"type": "wait_door", "face": out})
	a.append(_walk([door_in, door_point]))
	a.append({"type": "inside", "value": false})
	var down := stairs.duplicate()
	down.reverse()
	a.append(_walk(down))
	return a


## Punkte von der Stelle vor der Treppe hinauf bis zur Tür: an jeder Stufe ein kleiner Hüpfer.
func _stairs_up(door_point: Vector3, out: Vector3, room_y: float) -> Array:
	var count := GameConfig.entrance_step_count
	var tread := GameConfig.entrance_step_depth
	var rise := GameConfig.shop_floor_rise / float(count + 1)
	var podium := GameConfig.entrance_podium_depth
	var ground := room_y - GameConfig.shop_floor_rise
	var points: Array = [_ground(StreetPaths.library_entrance())]
	# Kanten von außen nach innen: unterste Stufe … Podest
	for k in count + 1:
		var edge := podium + (count - k) * tread
		var below := ground + k * rise
		points.append(door_point + out * (edge + 0.1) + Vector3.UP * (below - room_y))
		points.append(door_point + out * (edge - 0.08) + Vector3.UP * (below + rise - room_y))
	points.append(door_point)
	return points


## Ziel in der Bücherei: freier Sitz eines Sessels oder Sofas, sonst die Mitte eines Teppichs.
## { seat, front (Boden vor dem Sitz) } bzw. { front, face }.
func _inside_target() -> Dictionary:
	var seats: Array[SeatPoint] = []
	var rugs: Array[PlacedFurniture] = []
	for item in _room.get_placed_furniture():
		if item.data == null:
			continue
		var sub := String(item.data.subcategory)
		if sub in ["armchair", "sofa"]:
			for seating: Seating in item.find_children("*", "Seating", true, false):
				seats.append_array(seating.get_free_seats())
		elif sub == "rug":
			rugs.append(item)
	seats.shuffle()
	var room_y := _room.global_position.y + _room.floor_height
	for seat in seats:
		var forward := seat.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var front := Vector3(seat.global_position.x, room_y, seat.global_position.z) + forward * 0.5
		return {"seat": seat, "front": front}
	if not rugs.is_empty():
		var rug: PlacedFurniture = rugs[_rng.randi() % rugs.size()]
		var a := _rng.randf() * TAU
		return {"front": Vector3(rug.global_position.x, room_y, rug.global_position.z), "face": Vector3(sin(a), 0.0, cos(a))}
	return {}


## Raster der Bücherei: frei = dort passt eine Katze zwischen Möbeln und Wänden hindurch.
func _room_grid() -> Dictionary:
	var area := _room.build_area
	var nx := int(ceil(area.size.x / GRID_CELL))
	var nz := int(ceil(area.size.y / GRID_CELL))
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, nx, nz)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var space := get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 0.13
	shape.height = 0.26
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = FURNITURE_MASK
	for i in nx:
		for j in nz:
			var p := _cell_pos(Vector2i(i, j))
			query.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.17)
			if not _room.is_inside_build_area(p) or not space.intersect_shape(query, 1).is_empty():
				grid.set_point_solid(Vector2i(i, j), true)
	return {"grid": grid, "nx": nx, "nz": nz}


func _cell_pos(cell: Vector2i) -> Vector3:
	var area := _room.build_area
	var local := Vector3(area.position.x + (cell.x + 0.5) * GRID_CELL, _room.floor_height, area.position.y + (cell.y + 0.5) * GRID_CELL)
	return _room.to_global(local)


func _cell_of(p: Vector3, grid: Dictionary) -> Vector2i:
	var local := _room.to_local(p)
	var area := _room.build_area
	return Vector2i(clampi(int((local.x - area.position.x) / GRID_CELL), 0, grid.nx - 1),
		clampi(int((local.z - area.position.y) / GRID_CELL), 0, grid.nz - 1))


## Nächste freie Zelle (bis 4 Zellen Umkreis).
func _free_cell(cell: Vector2i, grid: Dictionary) -> Vector2i:
	var astar: AStarGrid2D = grid.grid
	if not astar.is_point_solid(cell):
		return cell
	for r in range(1, 5):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var c := cell + Vector2i(dx, dz)
				if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
					return c
	return Vector2i(-1, -1)


func _find_path(grid: Dictionary, from: Vector3, to: Vector3) -> Array:
	var astar: AStarGrid2D = grid.grid
	var a := _free_cell(_cell_of(from, grid), grid)
	var b := _free_cell(_cell_of(to, grid), grid)
	if a.x < 0 or b.x < 0:
		return []
	var cells := astar.get_id_path(a, b)
	if cells.is_empty():
		return []
	var result: Array = []
	for i in cells.size():
		# nur jede zweite Zelle und alle Ecken (weniger Zickzack)
		if i == cells.size() - 1 or i % 2 == 0:
			result.append(_cell_pos(cells[i]))
	result.append(to)
	return result


# --- Hilfen für die Katzen ---

func door_open() -> bool:
	return _door != null and _door.is_open


func floor_y(cat: StreetCat) -> float:
	if cat.inside and _room:
		return _room.global_position.y + _room.floor_height
	return _outside.global_position.y


func is_visible_point(point: Vector3) -> bool:
	return street.is_visible_point(point)


## Steht jemand direkt vor der Katze (Spielfigur, Passant, andere Katze)?
func blocked_ahead(cat: StreetCat, dir: Vector3) -> bool:
	var p := cat.global_position
	var others: Array = []
	var player := street.get_player()
	if player:
		others.append([player.global_position, StreetLife.PLAYER_RADIUS])
	if not cat.inside:
		for walker in street.get_walkers():
			others.append([walker.global_position, walker.radius * walker.scale.x])
	for other in _cats:
		if other != cat and other.on_ground() and other.inside == cat.inside:
			others.append([other.global_position, other.radius])
	for o: Array in others:
		var q: Vector3 = o[0]
		var d := Vector3(q.x - p.x, 0.0, q.z - p.z)
		if absf(q.y - p.y) > 1.2:
			continue
		var along := d.dot(dir)
		if along <= 0.05 or along > BLOCK_AHEAD + float(o[1]):
			continue
		if (d - dir * along).length() < BLOCK_SIDE + float(o[1]):
			return true
	return false


const BLOCK_AHEAD := 0.55
const BLOCK_SIDE := 0.22


## Fahrbahn frei zum Überqueren (kein Fahrzeug in der Nähe oder im Kommen)?
func road_clear(pos: Vector3) -> bool:
	var local := _outside.to_local(pos)
	var s := street.centerline.project(Vector2(local.x, local.z)).x
	for vehicle in street.get_vehicles():
		var ahead := (s - vehicle.get_s()) * vehicle.direction
		if ahead > -vehicle.length - 1.0 and ahead < 6.0 + vehicle.speed * 3.5:
			return false
	return true
