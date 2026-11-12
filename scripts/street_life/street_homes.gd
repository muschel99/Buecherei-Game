class_name StreetHomes
extends Node
## Anwohner und Türen (seit Etappe 6i). Sucht beim Start alle Türen der Häuser (Modell mit „DoorHinge_…“, siehe HouseDoor),
## merkt sich Wohnhäuser und Läden und lässt die Anwohner leben: Sie kommen durch ihre Haustür heraus, gehen weg und später
## wieder heim, gießen Blumen, fegen vor der Tür oder schauen aus dem Fenster. Niemand erscheint oder verschwindet sichtbar:
## Anwohner erscheinen hinter der geschlossenen Haustür (und verschwinden dort), am Fenster nur, wenn man das Fenster
## gerade nicht sieht. Häufigkeiten: GameConfig (Abschnitt „Anwohner und Türen“).

var life: StreetLife
var doors: Array[HouseDoor] = []
## Wohnhäuser: { house, door, front, inner, mid, out, side, s, windows: [ { pos, floor, face, outer } ], plants: [ { stand, face } ] }
var homes: Array[Dictionary] = []
## Anwohner: { walker, home, state ("home", "out", "away", "window"), timer, activity, spot }
var residents: Array[Dictionary] = []
## Läden: wie Wohnhäuser, dazu { floor, counter: { pos, face }, vendor_spot, browse: [ … ], seats: [ { pos, face, height, floor, backrest,
## via, table, occupant, prop } ], vendor: Passerby, customers: [ … ], at_counter: Passerby, bag: Pfad der Tüte }
var shops: Array[Dictionary] = []
## Figuren drinnen (Fensterblick, Verkäufer, Gäste), die nicht als Passanten gezählt werden
var indoor: Array[Passerby] = []
## Feste Pub-Gäste: { walker, seat, kind, next_sip, sip_left }
var guests: Array[Dictionary] = []
var _lod_timer := 0.0
## Prüfausgaben (street_life_check)
static var debug := false
## Zähler Läden
var stat_shop_visits := 0
var stat_bags := 0
var stat_pub_visits := 0
var _rng := RandomNumberGenerator.new()
## Zähler fürs Prüfwerkzeug
var stat_doors_used := 0
var stat_water := 0
var stat_sweep := 0
var stat_windows := 0
var stat_errands := 0


func setup(owner_life: StreetLife, seed_value: int) -> void:
	life = owner_life
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_collect()
	_build_residents()


# --- Häuser finden ---

func _collect() -> void:
	var houses := life.get_node_or_null("../Houses")
	if houses == null:
		return
	var walkable: Vector2 = life.walkable_span()
	for house: Node3D in houses.find_children("*", "HouseFacade", true, false):
		var hinges := house.find_children("DoorHinge_*", "", true, false)
		var door_hinge: Node3D = null
		var gate_hinge: Node3D = null
		for hinge: Node in hinges:
			if String(hinge.name) == "DoorHinge_gate":
				gate_hinge = hinge as Node3D
			else:
				door_hinge = hinge as Node3D
		if door_hinge == null:
			continue
		var door := HouseDoor.attach(door_hinge)
		doors.append(door)
		var home := _make_home(house, door)
		if home.is_empty():
			continue
		if gate_hinge:
			_add_gate(home, gate_hinge)
		var is_shop := not house.find_children("ShopSpot_*", "", true, false).is_empty()
		if debug and is_shop:
			print("Laden %s: s=%.1f (begehbar %s), Seite %d, Weg frei: %s" % [house.name, home.s, walkable, home.side, _way_clear(home.front, home.side)])
		# nur Häuser am begehbaren Teil der Straße (dort, wo man hinkommt und sie sieht)
		if not is_shop and (float(home.s) < walkable.x or float(home.s) > walkable.y):
			continue  # (Läden auch dahinter: man sieht in sie hinein, Kundschaft kommt hin)
		if not _way_clear(home.front, home.side) and not is_shop:
			continue
		if not house.find_children("ShopSpot_*", "", true, false).is_empty():
			_add_shop(home, house)
			continue
		_add_windows(home, house)
		_add_plants(home, house)
		homes.append(home)


func _make_home(house: Node3D, door: HouseDoor) -> Dictionary:
	var mid := life.to_local2(door.center())
	var out := life.to_local2(door.center() + door.out_dir) - mid
	if out.length() < 0.01:
		return {}
	out = out.normalized()
	var front := mid + out * GameConfig.house_door_front_step
	var inner := mid - out * GameConfig.house_door_inside_step
	var lage := life.centerline.project(front)
	return {"house": house, "door": door, "mid": mid, "out": out, "front": front, "inner": inner, "s": lage.x,
		"side": 1 if lage.y > 0.0 else -1, "windows": [], "plants": []}


## Vorgarten mit Pforte: die Pforte wird eine zweite Tür; wer hinaus will, geht über den Plattenweg hindurch.
func _add_gate(home: Dictionary, hinge: Node3D) -> void:
	var gate := HouseDoor.attach(hinge, "GateLeaf")
	doors.append(gate)
	var mid := life.to_local2(gate.center())
	home.gate = gate
	home.gate_mid = mid
	home.gate_out = mid + (home.out as Vector2) * 0.55
	home.gate_in = mid - (home.out as Vector2) * 0.5


## Weg von der Tür zum Gehweg frei (keine Kübel, Laternen o. Ä.)? Wenige Stichproben genügen.
func _way_clear(front: Vector2, side: int) -> bool:
	var lane := _lane_at(front, side)
	for t in [0.0, 0.33, 0.66, 1.0]:
		if not life.clear_of_static(front.lerp(lane, t), 0.24):
			return false
	return true


func _lane_at(front: Vector2, side: int) -> Vector2:
	var route: StreetRoute = life.sidewalks[side]
	var on := route.project(front)
	var comfort := route.comfort_at(on.x)
	return route.point_at(on.x, lerpf(comfort.x, comfort.y, 0.5))


func _add_windows(home: Dictionary, house: Node3D) -> void:
	for node: Node in house.find_children("WindowSpot_*", "", true, false):
		var spot := node as Node3D
		var pos := life.to_local2(spot.global_position)
		var face: Vector2 = home.out
		var outer := spot.global_position + Vector3(face.x, 0.0, face.y) * 0.75 + Vector3.UP * 1.4
		(home.windows as Array).append({"pos": pos, "floor": life.to_local(spot.global_position).y, "face": face, "outer": outer})


## Stellen zum Gießen: Blumenkästen in Griffhöhe nah an der Tür und Beete des Vorgartens.
func _add_plants(home: Dictionary, house: Node3D) -> void:
	var face: Vector2 = -(home.out as Vector2)
	var done: Array[Vector2] = []
	var gated := home.has("gate")
	for node: Node in house.find_children("PlantSpot_*", "", true, false):
		var spot := node as Node3D
		var extras: Dictionary = spot.get_meta("extras", {})
		var kind := String(extras.get("kind", ""))
		if not kind in ["box", "bed", "pot"] or (gated and kind != "bed"):
			continue  # im Vorgarten gießt man die Beete (an Kästen hinter den Beeten käme man nicht heran)
		var height := life.to_local(spot.global_position).y
		if height > 1.6:
			continue
		var at := life.to_local2(spot.global_position)
		if at.distance_to(home.front) > 5.0 or done.any(func(d: Vector2) -> bool: return d.distance_to(at) < 1.2):
			continue
		var stand: Vector2
		if gated:
			# auf dem Plattenweg stehen und zum Beet hin gießen
			stand = (home.front as Vector2) + (home.out as Vector2) * 0.15
			face = (at - stand).normalized()
		else:
			stand = life.keep_on_sidewalk(home.side, at + (home.out as Vector2) * (0.62 if kind != "bed" else 0.85))
			if not life.clear_of_static(stand, 0.22):
				continue
		done.append(at)
		(home.plants as Array).append({"stand": stand, "face": face})


# --- Anwohner ---

func _build_residents() -> void:
	if homes.is_empty():
		return
	var scene := load(GameConfig.passerby_scenes[0]) as PackedScene
	if scene == null:
		return
	var folder := Node3D.new()
	folder.name = "Residents"
	life.add_child(folder)
	var order := homes.duplicate()
	order.shuffle()
	for i in mini(GameConfig.resident_count, order.size()):
		var walker := scene.instantiate() as Passerby
		walker.name = "Resident%d" % (i + 1)
		walker.life = life
		folder.add_child(walker)
		walker.finished.connect(life._on_walker_finished)
		walker.randomize_look(life._rng)
		walker.give_bag(false)
		var res := {"walker": walker, "home": order[i], "state": "home", "timer": _rng.randf_range(1.0, GameConfig.resident_home_time.y)}
		walker.resident = res
		residents.append(res)


func step(delta: float) -> void:
	for door in doors:
		door.step(delta)
	for walker in indoor:
		if walker.visible:
			walker.step(delta)
	_update_shops(delta)
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.25
		_update_indoor_lod()
	for res in residents:
		res.timer = float(res.timer) - delta
		if float(res.timer) > 0.0:
			continue
		match String(res.state):
			"home":
				_next_activity(res)
			"away":
				if not _come_home(res):
					res.timer = 1.5  # Straßenende gerade im Blick: kurz warten
			"window":
				_leave_window(res)


## Wie viele Anwohner gerade draußen sind (sie zählen nicht zur Passanten-Menge, siehe StreetLife).
func residents_outside() -> int:
	var count := 0
	for res in residents:
		if String(res.state) == "out":
			count += 1
	return count


func _next_activity(res: Dictionary) -> void:
	var walker: Passerby = res.walker
	var home: Dictionary = res.home
	var door: HouseDoor = home.door
	var weights: Dictionary = GameConfig.resident_activity_weights.duplicate()
	if (home.plants as Array).is_empty():
		weights.erase("water")
	if (home.windows as Array).is_empty():
		weights.erase("window")
	if door.is_in_use() or life.door_blocked(home.front):
		weights.erase("errand")
		weights.erase("water")
		weights.erase("sweep")
	if weights.is_empty():
		res.timer = 2.0
		return
	var activity := String(ChibiPasserbyModel._weighted(_rng, weights, &"errand"))
	var plan := []
	match activity:
		"errand":
			plan = _plan_errand(res)
			stat_errands += 1
		"water":
			plan = _plan_chore(res, "water")
			stat_water += 1
		"sweep":
			plan = _plan_chore(res, "sweep")
			stat_sweep += 1
		"window":
			_go_to_window(res)
			return
	if plan.is_empty():
		res.timer = 2.0
		return
	var actions: Array[Dictionary] = []
	actions.assign(plan)
	stat_doors_used += 1
	walker.side = home.side
	walker.comfort_pref = _rng.randf_range(0.2, 0.8)
	walker.speed_pref = _rng.randf_range(GameConfig.passerby_speed_range.x, GameConfig.passerby_speed_range.y) * walker.speed_factor()
	res.state = "out"
	res.activity = activity
	life.resident_goes_out(walker)
	walker.begin(home.inner, actions, home.out, _inside_floor(home))
	walker.set_shadows(0)


func _inside_floor(home: Dictionary) -> float:
	return float(home.get("floor", 0.04))


## Tür-Schritt: von from nach to durch die Tür; vanish = dahinter verschwinden (nach Hause).
func door_step(home: Dictionary, leaving: bool, vanish: bool = false) -> Dictionary:
	return {"type": "door", "door": home.door, "from_pos": home.inner if leaving else home.front, "to_pos": home.front if leaving else home.inner,
		"middle": home.mid, "vanish": vanish, "push": not leaving, "floor": 0.0 if leaving else _inside_floor(home)}


## Durch die Gartenpforte (nur Häuser mit Vorgarten); Wege im Garten tragen "yard" (dort steht die Haus-Kollision, das ist richtig).
func gate_step(home: Dictionary, leaving: bool) -> Dictionary:
	return {"type": "door", "door": home.gate, "from_pos": home.gate_in if leaving else home.gate_out, "to_pos": home.gate_out if leaving else home.gate_in,
		"middle": home.gate_mid, "vanish": false, "push": not leaving, "floor": 0.0, "yard": true}


func _yard_walk(a: Vector2, b: Vector2) -> Dictionary:
	var w := _route_to(a, b)
	w.yard = true
	return w


## Schritte von der Haustür bis auf den Gehweg (mit Pforte über den Gartenweg).
func _way_out(home: Dictionary, lane: Vector2) -> Array:
	var steps: Array = [door_step(home, true)]
	if home.has("gate"):
		steps.append(_yard_walk(home.front, home.gate_in))
		steps.append(gate_step(home, true))
		steps.append(_route_to(home.gate_out, lane))
	else:
		steps.append(_route_to(home.front, lane))
	return steps


## Schritte vom Gehweg ins Haus (verschwindet hinter der geschlossenen Tür).
func _way_in(home: Dictionary, lane: Vector2) -> Array:
	var steps: Array = []
	if home.has("gate"):
		steps.append(_route_to(lane, home.gate_out))
		steps.append(gate_step(home, false))
		steps.append(_yard_walk(home.gate_in, home.front))
	else:
		steps.append(_route_to(lane, home.front))
	steps.append(door_step(home, false, true))
	return steps


func _route_to(a: Vector2, b: Vector2) -> Dictionary:
	var route := StreetRoute.from_points(PackedVector2Array([a, b]), 0.3)
	return {"type": "walk", "route": route, "to": route.length(), "from_here": true, "fixed_path": true}


## Aus dem Haus, zu einem Ende der Straße (dort verschwindet man wie jeder Passant); später kommt man wieder (_come_home).
func _plan_errand(res: Dictionary) -> Array:
	var home: Dictionary = res.home
	var side: int = home.side
	var lane := _lane_at(home.get("gate_out", home.front), side)
	var to_end := -0.5 if _rng.randf() < 0.5 else life.centerline.length() + 0.5
	var actions: Array = _way_out(home, lane)
	actions.append({"type": "walk", "route": life.sidewalks[side], "to": to_end})
	actions.append({"type": "leave", "gate": false})
	return actions


## Gießen oder Fegen: heraus, an den Platz, arbeiten, zurück ins Haus.
func _plan_chore(res: Dictionary, kind: String) -> Array:
	var home: Dictionary = res.home
	var walker: Passerby = res.walker
	var stand: Vector2
	var face: Vector2
	if kind == "water":
		var plants: Array = home.plants
		var spot: Dictionary = plants[_rng.randi() % plants.size()]
		stand = spot.stand
		face = spot.face
	else:
		var along := Vector2(-(home.out as Vector2).y, (home.out as Vector2).x) * (1.0 if _rng.randf() < 0.5 else -1.0)
		if home.has("gate"):
			# im Vorgarten: auf dem Plattenweg, zur Pforte hin
			stand = (home.front as Vector2) + (home.out as Vector2) * 0.3
			face = (home.out as Vector2)
		else:
			stand = life.keep_on_sidewalk(home.side, (home.front as Vector2) + along * _rng.randf_range(0.2, 0.7) + (home.out as Vector2) * 0.1)
			face = (along + (home.out as Vector2) * 0.4).normalized()
	var time := _rng.randf_range(GameConfig.resident_water_time.x, GameConfig.resident_water_time.y) if kind == "water" else \
		_rng.randf_range(GameConfig.resident_sweep_time.x, GameConfig.resident_sweep_time.y)
	walker.give_bag(false)
	walker.set_prop(&"can" if kind == "water" else &"broom")
	var actions: Array = [door_step(home, true)]
	if stand.distance_to(home.front) > 0.05:
		actions.append(_yard_walk(home.front, stand))
	actions.append({"type": "chore", "kind": kind, "face": face, "time": time, "yard": true})
	if stand.distance_to(home.front) > 0.05:
		actions.append(_yard_walk(stand, home.front))
	actions.append(door_step(home, false, true))
	return actions


## Heimkommen: vom Straßenende auf dem eigenen Gehweg bis zur Tür und hinein.
func _come_home(res: Dictionary) -> bool:
	var home: Dictionary = res.home
	var walker: Passerby = res.walker
	var ends := life.get_places().filter(func(p: Dictionary) -> bool:
		return p.kind == "walker" and p.place in ["east", "west"] and p.side == home.side)
	ends.shuffle()
	for start: Dictionary in ends:
		if life.is_visible_spot(start.pos) or life.spot_crowded(start.pos) \
				or life.player_pos().distance_to(start.pos) < GameConfig.passerby_spawn_player_distance:
			continue
		var from_s: float = 0.0 if start.place == "east" else life.centerline.length()
		var start_pos: Vector2 = life._lane_point(home.side, from_s, 0.5)
		var lane := _lane_at(home.get("gate_out", home.front), home.side)
		var actions: Array[Dictionary] = [{"type": "walk", "route": life.sidewalks[home.side], "to": float(home.s)}]
		for step: Dictionary in _way_in(home, lane):
			actions.append(step)
		walker.side = home.side
		walker.comfort_pref = _rng.randf_range(0.2, 0.8)
		walker.speed_pref = _rng.randf_range(GameConfig.passerby_speed_range.x, GameConfig.passerby_speed_range.y) * walker.speed_factor()
		res.state = "out"
		res.activity = "coming_home"
		life.resident_goes_out(walker)
		walker.begin(start_pos, actions, life.centerline.direction_at(from_s) * (1.0 if from_s < 1.0 else -1.0))
		walker.set_shadows(0)
		return true
	return false


## Am Ende eines Weges (Passerby.finished): zu Hause angekommen oder am Straßenende verschwunden.
func resident_finished(walker: Passerby) -> void:
	var res := walker.resident
	walker.set_prop(&"")
	if String(res.get("activity", "")) == "errand":
		res.state = "away"
		res.timer = _rng.randf_range(GameConfig.resident_away_time.x, GameConfig.resident_away_time.y)
	else:
		res.state = "home"
		res.timer = _rng.randf_range(GameConfig.resident_home_time.x, GameConfig.resident_home_time.y)


## Ans Fenster: nur wenn es gerade niemand sieht, und auf Zeit (später nur, wenn man wieder nicht hinsieht).
func _go_to_window(res: Dictionary) -> void:
	var home: Dictionary = res.home
	var walker: Passerby = res.walker
	var windows: Array = (home.windows as Array).duplicate()
	windows.shuffle()
	for w: Dictionary in windows:
		if life.is_visible_point(w.outer):
			continue
		var time := _rng.randf_range(GameConfig.resident_window_time.x, GameConfig.resident_window_time.y)
		var actions: Array[Dictionary] = [{"type": "stand", "anim": &"idle", "face": w.face, "time": time + 3600.0}]
		walker.begin(w.pos, actions, w.face, float(w.floor))
		walker.set_shadows(0)
		walker.give_bag(false)
		res.state = "window"
		res.spot = w
		res.timer = time
		indoor.append(walker)
		stat_windows += 1
		return
	res.timer = 2.0


func _leave_window(res: Dictionary) -> void:
	var w: Dictionary = res.spot
	if life.is_visible_point(w.outer):
		res.timer = 1.5
		return
	var walker: Passerby = res.walker
	indoor.erase(walker)
	walker.set_active(false)
	res.state = "home"
	res.timer = _rng.randf_range(GameConfig.resident_home_time.x, GameConfig.resident_home_time.y)


# --- Läden (seit Etappe 6i) ---

## Plätze eines Ladens aus dem Modell lesen, Verkäuferin/Verkäufer anlegen, feste Gäste setzen.
func _add_shop(shop: Dictionary, house: Node3D) -> void:
	shop.counter = {}
	shop.vendor_spot = {}
	shop.browse = []
	shop.seats = []
	shop.customers = []
	shop.at_counter = null
	shop.bag = _bag_for(house)
	for node: Node in house.find_children("ShopSpot_*", "", true, false):
		var spot := node as Node3D
		var parts := String(spot.name).split("_")
		if parts.size() < 3:
			continue
		var entry := _spot_entry(spot)
		match parts[1]:
			"counter":
				shop.counter = entry
				shop.floor = float(entry.floor)
			"vendor":
				shop.vendor_spot = entry
			"browse":
				(shop.browse as Array).append(entry)
			"seat":
				var extras: Dictionary = spot.get_meta("extras", {})
				entry.height = float(extras.get("height", 0.33)) - float(extras.get("floor", 0.08))
				entry.floor = float(extras.get("floor", 0.08))
				entry.backrest = float(extras.get("backrest", 0.13))
				var parent := spot.get_parent() as Node3D
				entry.via = life.to_local2(parent.to_global(Vector3(float(extras.get("via_x", 0.0)), 0.0, -float(extras.get("via_y", 0.0)))))
				entry.table = parent.to_global(Vector3(float(extras.get("table_x", 0.0)), float(extras.get("table_z", 0.54)), -float(extras.get("table_y", 0.0))))
				entry.occupant = null
				entry.prop = null
				(shop.seats as Array).append(entry)
	if (shop.counter as Dictionary).is_empty():
		return
	(shop.door as HouseDoor).has_bell = true
	shops.append(shop)
	if not (shop.vendor_spot as Dictionary).is_empty():
		shop.vendor = _make_indoor_figure("Vendor%d" % shops.size())
		var spot: Dictionary = shop.vendor_spot
		var actions: Array[Dictionary] = [{"type": "stand", "anim": &"idle", "face": spot.face, "time": INF}]
		(shop.vendor as Passerby).begin(spot.pos, actions, spot.face, float(spot.floor))
		(shop.vendor as Passerby).set_shadows(0)
		indoor.append(shop.vendor)
		shop.vendor_wait = _rng.randf_range(3.0, 10.0)
	var seats: Array = (shop.seats as Array).duplicate()
	seats.shuffle()
	for i in mini(GameConfig.pub_guest_count, seats.size()):
		_seat_guest(seats[i])


func _spot_entry(spot: Node3D) -> Dictionary:
	var extras: Dictionary = spot.get_meta("extras", {})
	var pos := life.to_local2(spot.global_position)
	var parent := spot.get_parent() as Node3D
	var dir := parent.global_basis * Vector3(float(extras.get("face_x", 0.0)), 0.0, -float(extras.get("face_y", 1.0)))
	var face := life.to_local2(spot.global_position + dir) - pos
	return {"pos": pos, "face": face.normalized(), "floor": life.to_local(spot.global_position).y}


func _bag_for(house: Node3D) -> String:
	var bags: Dictionary = GameConfig.shop_bag_models
	var path := String(house.get("unique_model").resource_path) if house.get("unique_model") else house.scene_file_path
	for key: String in bags:
		if path.contains(key):
			return String(bags[key])
	return ""


func _make_indoor_figure(figure_name: String) -> Passerby:
	var scene := load(GameConfig.passerby_scenes[0]) as PackedScene
	var folder := life.get_node_or_null("ShopFolk")
	if folder == null:
		folder = Node3D.new()
		folder.name = "ShopFolk"
		life.add_child(folder)
	var walker := scene.instantiate() as Passerby
	walker.name = figure_name
	walker.life = life
	folder.add_child(walker)
	walker.randomize_look(life._rng)
	walker.give_bag(false)
	return walker


## Ein fester Gast sitzt schon beim Start im Pub (Getränk oder Kuchen vor sich auf dem Tisch).
func _seat_guest(seat: Dictionary) -> void:
	var walker := _make_indoor_figure("PubGuest%d" % (guests.size() + 1))
	walker.begin_seated(seat.pos, seat.face, float(seat.height), float(seat.floor), float(seat.backrest))
	walker.set_shadows(0)
	seat.occupant = walker
	indoor.append(walker)
	var guest := {"walker": walker, "seat": seat, "kind": _table_kind(), "next_sip": _rng.randf_range(2.0, 10.0), "sip_left": 0.0}
	guests.append(guest)
	_set_table_prop(seat, String(guest.kind))


func _table_kind() -> String:
	return String(ChibiPasserbyModel._weighted(_rng, GameConfig.pub_table_weights, &"mug"))


## Getränk oder Kuchenteller auf den Tisch vor dem Sitz stellen (bzw. wegräumen: kind "").
func _set_table_prop(seat: Dictionary, kind: String) -> void:
	if seat.prop:
		(seat.prop as Node3D).queue_free()
		seat.prop = null
	if kind.is_empty():
		return
	var scene := load(String(GameConfig.passerby_prop_models.get(kind, ""))) as PackedScene
	if scene == null:
		return
	var node := scene.instantiate() as Node3D
	life.add_child(node)
	node.global_position = seat.table
	node.rotation.y = _rng.randf_range(-0.5, 0.5)
	seat.prop = node


func _update_shops(delta: float) -> void:
	for shop in shops:
		var vendor: Passerby = shop.get("vendor")
		if vendor == null or not vendor.visible:
			continue
		shop.vendor_wait = float(shop.vendor_wait) - delta
		if float(shop.vendor_wait) <= 0.0 and shop.at_counter == null:
			shop.vendor_wait = _rng.randf_range(GameConfig.shop_vendor_pause.x, GameConfig.shop_vendor_pause.y)
			vendor.play_idle_clip(ChibiPasserbyModel._weighted(_rng, GameConfig.shop_vendor_clips, &"look_around"))
	for guest in guests:
		_update_guest(guest, delta)


## Fester Gast: ab und zu ein Schluck oder ein Bissen (nur wenn er gerade nicht erzählt).
func _update_guest(guest: Dictionary, delta: float) -> void:
	var walker: Passerby = guest.walker
	var seat: Dictionary = guest.seat
	if float(guest.sip_left) > 0.0:
		guest.sip_left = float(guest.sip_left) - delta
		if float(guest.sip_left) <= 0.0:
			# wieder abgestellt
			walker.set_prop(&"")
			if seat.prop:
				(seat.prop as Node3D).visible = true
		return
	guest.next_sip = float(guest.next_sip) - delta
	if float(guest.next_sip) > 0.0 or walker.chat != null or not walker.visible:
		return
	guest.next_sip = _rng.randf_range(GameConfig.pub_sip_interval.x, GameConfig.pub_sip_interval.y)
	var kind := String(guest.kind)
	if kind != "cake":
		if seat.prop:
			(seat.prop as Node3D).visible = false
		walker.set_prop(StringName(kind))
	walker.take_sip()
	guest.sip_left = 2.8


## Frei, zum Laden hineinzugehen?
func shop_has_room(shop: Dictionary) -> bool:
	return (shop.customers as Array).size() < GameConfig.shop_capacity


func shop_enter(shop: Dictionary, walker: Passerby) -> void:
	if not (shop.customers as Array).has(walker):
		(shop.customers as Array).append(walker)


func shop_leave(shop: Dictionary, walker: Passerby) -> void:
	(shop.customers as Array).erase(walker)


## Darf man die Theke benutzen? Merkt sich, wer gerade dort steht.
func claim_counter(shop: Dictionary, walker: Passerby) -> bool:
	if shop.at_counter == null or not is_instance_valid(shop.at_counter) or not (shop.at_counter as Passerby).active:
		shop.at_counter = walker
	return shop.at_counter == walker


func release_counter(shop: Dictionary, walker: Passerby) -> void:
	if shop.at_counter == walker:
		shop.at_counter = null


## Ladenbesuch für die Planung eines Passanten: von lane_in auf dem Gehweg hinein, Regale anschauen, an die Theke (oder im Pub an
## einen freien Tisch), mit Tüte wieder hinaus nach lane_out.
func shop_visit_actions(shop: Dictionary, lane_in: Vector2, lane_out: Vector2) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var way := _route_to(lane_in, shop.front)
	way.shop_visit = true
	way.shop_enter = shop
	actions.append(way)
	var inside := door_step(shop, false)
	inside.shop_visit = true
	actions.append(inside)
	var last: Vector2 = shop.inner
	var seat: Dictionary = {}
	for candidate: Dictionary in (shop.seats as Array):
		if candidate.occupant == null:
			seat = candidate
			break
	if not seat.is_empty() and _rng.randf() < GameConfig.pub_sit_chance:
		# Im Pub: am Tisch vorbei zum freien Platz, hinsetzen, später zurück zur Tür
		seat.occupant = true  # reserviert (wird beim Hinsetzen zur Figur)
		var to_via := _route_to(shop.inner, seat.via)
		to_via.shop_visit = true
		actions.append(to_via)
		var time := _rng.randf_range(GameConfig.pub_visit_time.x, GameConfig.pub_visit_time.y)
		actions.append({"type": "sit", "seat": null, "spot": seat.pos, "face": seat.face, "height": float(seat.height), "time": time,
			"front": GameConfig.pub_seat_front, "pub_seat": seat, "shop_visit": true, "floor": float(seat.floor)})
		var back := _route_to(seat.via, shop.inner)
		back.shop_visit = true
		actions.append(back)
		stat_pub_visits += 1
	else:
		var options := (shop.browse as Array).duplicate()
		options.shuffle()
		for i in mini(_rng.randi_range(1, 2), options.size()):
			var spot: Dictionary = options[i]
			var w := _route_to(last, spot.pos)
			w.shop_visit = true
			actions.append(w)
			actions.append({"type": "stand", "anim": &"browse", "face": spot.face, "shop_visit": true,
				"time": _rng.randf_range(GameConfig.shop_browse_time.x, GameConfig.shop_browse_time.y)})
			last = spot.pos
		var counter: Dictionary = shop.counter
		actions.append({"type": "buy", "shop": shop, "spot": counter.pos, "face": counter.face, "shop_visit": true,
			"time": _rng.randf_range(GameConfig.shop_counter_time.x, GameConfig.shop_counter_time.y)})
		var back := _route_to(counter.pos, shop.inner)
		back.shop_visit = true
		actions.append(back)
	var outside := door_step(shop, true)
	outside.shop_visit = true
	outside.shop_exit = shop
	actions.append(outside)
	var away := _route_to(shop.front, lane_out)
	actions.append(away)
	stat_shop_visits += 1
	return actions


## Ein Laden auf dem Weg (Seite und Richtung wie bei den Schaufenstern) oder leer.
func pick_shop(s0: float, end_s: float, dir: int, start_side: int, cross_s: float, end_side: int) -> Dictionary:
	var choices: Array[Dictionary] = []
	for shop in shops:
		var along := (float(shop.s) - s0) * dir
		if along < 2.5 or along > (end_s - s0) * dir - 2.5:
			continue
		var side_there := start_side
		if not is_nan(cross_s) and (float(shop.s) - cross_s) * dir > 0.0:
			side_there = end_side
		if side_there == int(shop.side):
			choices.append(shop)
	return choices[_rng.randi() % choices.size()] if not choices.is_empty() else {}


## Für Testbilder: Sichtbarkeit neu prüfen und einmal rechnen.
func refresh_indoor(delta: float) -> void:
	_update_indoor_lod()
	for walker in indoor:
		if walker.visible:
			walker.step(delta)


## Figuren drinnen: außerhalb des Blickfelds ausgeblendet (rechnen dann auch keine Animation).
func _update_indoor_lod() -> void:
	var camera := life.get_viewport().get_camera_3d()
	if camera == null:
		return
	for walker in indoor:
		var near := camera.global_position.distance_to(walker.global_position) < 7.0
		walker.visible = walker.active and (near or life.in_view_point(walker.global_position + Vector3.UP))


## Ein Besucher hat sich im Pub gesetzt: Getränk oder Kuchen kommt auf den Tisch; aufgestanden: wieder weg.
func pub_sat_down(walker: Passerby, seat: Dictionary) -> void:
	seat.occupant = walker
	_set_table_prop(seat, _table_kind())


func pub_stood_up(_walker: Passerby, seat: Dictionary) -> void:
	seat.occupant = null
	_set_table_prop(seat, "")
