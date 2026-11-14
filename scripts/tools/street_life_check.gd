extends Node
## Prüfwerkzeug für das Leben auf der Straße (seit Etappe 5a) – für die Selbstkontrolle von
## Claude. Lädt die Hauptszene, stellt die Spielfigur nacheinander an viele erreichbare Stellen
## (Ladentür, Gehwege, Fahrbahn, beide Grenzen, Enden der Gassen, Platz, im Laden), dreht dort
## die Kamera langsam im Kreis und spult das Straßenleben vor. Am Ende steht ein Bericht:
## - Erscheinen/Verschwinden: wie oft, wo – und ob der Ort dabei im Blickfeld lag (muss 0 sein)
##   bzw. ob man ihn mit freier Sicht hätte sehen können, wenn man sich umdreht (nur zur Info),
## - Passanten, die sich überschneiden, in die Spielfigur, in Häuser, Treppe oder Kartons laufen,
## - Passanten, die hängen bleiben (stuck: 40 s, stall: beim Gehen 2,5 s auf der Stelle, nicht
##   wegen der Spielfigur), und Fahrzeuge, die jemandem zu nahe kommen.
##
## Starten (Godot ohne Bildschirm):
##   godot --headless --path . res://scenes/tools/street_life_check.tscn -- --seconds=40 --seed=1
## Angaben nach "--": --seconds=<je Stelle> (Standard 45), --seed=<zahl>, --only=<stelle,…>,
## --deliver=<n> (Testlieferung mit n Kartons, sobald die erste Stelle beginnt), --door_open (Ladentür offen),
## --cats (Katzen kommen alle paar Sekunden, --enter=<0..1> Chance hineinzugehen; seit Etappe 6g), --no_animals,
## --cat_log (jeden Schritt der Katzen ausgeben), --hunt (Jagd und Spielzeug erzwingen), --throw (alle 15 s wirft die
## Spielfigur ein Spielzeug in Richtung der nächsten Katze), --garden (Vögel und Katzen in den Gartenhof der Baumgasse),
## --sills (Katzen gehen fast immer auf Fensterbänke).

const STEP := 1.0 / 30.0
const TURN_SPEED := deg_to_rad(40.0)
## Messen alle so viele Sekunden.
const SAMPLE := 0.5

var _args := {}
var _main: Node3D
var _life: StreetLife
var _player: Node3D
var _camera: Camera3D
var _report := {
	"appeared": 0, "vanished": 0, "appear_in_view": [], "vanish_in_view": [],
	"appear_open": 0, "vanish_open": 0, "places": {},
	"overlap": [], "player_bump": [], "solid": [], "stuck": [], "stall": [], "vehicle_close": [], "vehicle_cat": [], "floor": [],
	"min_walker_gap": INF, "min_player_gap": INF, "samples": 0, "vehicles": {}, "crossing": 0, "browsing": 0, "alley": 0, "sitting": 0,
}
var _track := {}  # Passant -> [letzte Stelle, Zeit seit Bewegung]
var _cat_track := {}  # Katze -> [letzte Stelle, Zeit ohne Bewegung beim Laufen]
var _cat_stuck: Array[String] = []
var _stall := {}  # Passant -> Sekunden, die er beim Gehen auf der Stelle tritt
var _spot_name := ""


func _ready() -> void:
	_args = _parse_args()
	StreetHomes.debug = true
	if _args.has("no_animals"):
		GameConfig.animals_enabled = false
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_life = _main.get_node("Outside/StreetLife") as StreetLife
	if _args.has("seed"):
		_life.seed_random(int(_args.seed))
	_camera = Camera3D.new()
	_camera.fov = GameConfig.camera_fov
	_main.add_child(_camera)
	_camera.make_current()
	_life.appeared.connect(_on_appeared)
	_life.vanished.connect(_on_vanished)
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await get_tree().physics_frame
	if _args.has("door_open"):
		var door := get_tree().get_first_node_in_group("doors") as Door
		if door:
			door.set_open(true)
	StreetCat.debug = _args.has("cat_log")
	if _args.has("hunt"):
		# Prüfen: viele Vögel am Boden, Katzen jagen immer, tragen oft Spielzeug und lassen es liegen
		GameConfig.bird_ground_share = 0.9
		GameConfig.pigeon_ground_share = 1.0
		GameConfig.cat_hunt_chance = 1.0
		GameConfig.cat_toy_chance = 1.0
		GameConfig.cat_toy_leave_chance = 20.0
	if _args.has("sills"):
		# Fensterbänke prüfen (auch über Bänke): Katzen gehen möglichst immer dorthin
		GameConfig.cat_sill_chance = 1.0
		GameConfig.cat_seat_chance = 0.0
		GameConfig.cat_wall_chance = 0.0
	if _args.has("garden"):
		# Gartenhof der Baumgasse prüfen: Singvögel fast immer dorthin, Katzen gehen immer hin und jagen
		GameConfig.bird_court_share = 0.9
		GameConfig.cat_garden_chance = 1.0
		GameConfig.cat_garden_birds_chance = 1.0
		GameConfig.cat_hunt_chance = 1.0
	if _args.has("cats"):
		# Katzen öfter (zum Prüfen): alle paar Sekunden eine neue
		GameConfig.cat_interval = Vector2(4.0, 8.0)
		GameConfig.cat_first_delay = Vector2(1.0, 2.0)
		GameConfig.cat_enter_chance = float(_args.get("enter", GameConfig.cat_enter_chance))
	if _args.has("deliver"):
		var manager := get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager
		manager.place_order([{"kind": "furniture", "id": "armchair_velvet", "count": int(_args.deliver)}], 0.0)
	if _args.has("visitors"):
		# Bücherei-Besucher prüfen (seit Etappe 7): geöffnet, Besuche sofort fällig, an der Theke wird selbst gestempelt
		GameClock.load_save_data({"day": 1, "minute": 10.0 * 60.0})
		GameClock.running = false
		Lending.set_open(true)
		Lending.debug_add_visits(int(_args.visitors))
		var room := Lending.find_room()
		for entry: Array in [["bookshelf_country", Vector3(2.7, 0, -1.0), -PI / 2.0], ["bookshelf_min_tall", Vector3(-2.75, 0, 1.6), PI / 2.0],
				["armchair_velvet", Vector3(0.6, 0, 1.0), PI]]:
			var data := Catalog.get_furniture(String(entry[0]))
			if data and room:
				room.add_furniture(data, Transform3D(Basis(Vector3.UP, float(entry[2])), entry[1]), null)
		await get_tree().physics_frame
		for shelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
			(shelf as BookShelf).set_genre(BookShelf.MIXED)
			print("Regal gefüllt: %d Bücher" % (shelf as BookShelf).fill_from_storage())
		if _args.has("read"):
			GameConfig.visitor_read_chance = 1.0
		LibraryVisits.debug = true
		if _life.library:
			_life.library.auto_stamp = true
	if _args.has("hour"):
		# Uhrzeit fest (seit Testrunde 7b), z. B. --hour=23 für die Nachtruhe
		GameClock.load_save_data({"day": 1, "minute": float(_args.hour) * 60.0})
		GameClock.running = false
	if _args.has("day_test"):
		# Tageswechsel prüfen (seit Etappe 7): Zahlen gehen in die Geschichte, um 6 Uhr erscheint der Notizzettel
		GameClock.running = false
		GameClock.load_save_data({"day": 1, "minute": 23.0 * 60.0})
		Lending.today.visitors = 5
		Lending.today.borrowed = 3
		GameClock.sleep_until(GameConfig.clock_morning_hour)
		await get_tree().process_frame
		print("Tagestest: Tag %d, %s, Geschichte %s, Zettel gezeigt bis Tag %d" % [GameClock.day, GameClock.time_text(),
			Lending.history, Lending.note_shown_day])
		get_tree().quit()
		return
	var seconds := float(_args.get("seconds", 45.0))
	var only: PackedStringArray = String(_args.get("only", "")).split(",", false)
	var spots := _spots()
	for spot_name in spots:
		if not only.is_empty() and not spot_name in only:
			continue
		_spot_name = spot_name
		var spot: Dictionary = spots[spot_name]
		_player.global_position = spot.pos
		var yaw := 0.0
		var time := 0.0
		var sample := 0.0
		while time < seconds:
			yaw += TURN_SPEED * STEP
			_camera.global_position = spot.pos + Vector3.UP * 1.6
			_camera.global_rotation = Vector3(-0.05, yaw, 0.0)
			_life.step(STEP)
			time += STEP
			if _args.has("visitors") and fmod(time, 6.0) < STEP:
				for v in get_tree().get_nodes_in_group(LibraryVisits.VISITOR_GROUP):
					var w := v as Passerby
					var d := _life.library.door
					print("  Besucher t=%.0f pos=(%.2f, %.2f) y=%.2f %s phase=%d tür=%s %.2f" % [time, w.pos.x, w.pos.y, w.floor_y,
						w.get_action_type(), w._phase, d.is_open, d.open_amount()])
			if _args.has("throw") and fmod(time, 15.0) < STEP and _life.cats:
				_test_throw()
			if _args.has("hunt") and fmod(time, 20.0) < STEP and _life.cats and _life.birds:
				# Prüfen der Jagd: Vögel vor einer laufenden Katze absetzen
				for cat in _life.cats.get_cats():
					if cat.get_action_type() == "walk" and not cat.inside:
						_life.birds.debug_ground_flock(cat.global_position + cat.global_basis.z * 5.5)
						break
			sample += STEP
			if sample >= SAMPLE:
				sample = 0.0
				_measure()
			if int(time / STEP) % 90 == 0:
				await get_tree().physics_frame
		print("Stelle fertig: %s (%d unterwegs)" % [spot_name, _life.get_walkers().size()])
	var manager := get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager
	print("Kartons vor der Tür: %d, Bestellungen offen: %d" % [manager.get_box_count(), manager.get_order_count()])
	_print_report()
	get_tree().quit()


## Erreichbare Stellen (Fußpunkt der Spielfigur, global).
func _spots() -> Dictionary:
	var y := StreetLayout.ground_y()
	var door := StreetLayout.door_center()
	var out := StreetLayout.door_outward()
	var side := float(StreetLayout.straight_side())
	var bound := StreetLayout.straight_bound_x() - side * 0.62
	var road := StreetLayout.road_center_z()
	var gate := _gate_spot(-0.15, 0.0)
	var half := StreetLayout.gate_passage_width() / 2.0
	var alley_x := (StreetLayout.HOUSE_LEFT + StreetLayout.alley_far_x()) / 2.0
	var opp := StreetLayout.opposite_alley()
	return {
		"door": {"pos": Vector3(door.x + out.x * 0.5, 0.0, door.z + out.z * 0.5)},
		"shop_inside": {"pos": Vector3(0.0, 0.0, 1.0)},
		"near_walk": {"pos": Vector3(0.5, y, StreetLayout.HOUSE_FRONT - 1.0)},
		"far_walk": {"pos": Vector3(0.0, y, StreetLayout.opposite_front_z() + 0.8)},
		"road": {"pos": Vector3(-1.0, y, road)},
		"bound_near": {"pos": Vector3(bound, y, StreetLayout.HOUSE_FRONT - 0.32)},
		"bound_road": {"pos": Vector3(bound, y, road)},
		"bound_far": {"pos": Vector3(bound, y, StreetLayout.opposite_front_z() + 0.32)},
		"gate_middle": {"pos": Vector3(gate.x, y, gate.y)},
		"gate_left": {"pos": _v3(_gate_spot(-0.15, half - 0.35), y)},
		"gate_right": {"pos": _v3(_gate_spot(-0.15, -half + 0.35), y)},
		"plaza": {"pos": Vector3(StreetLayout.alley_row_end_x() + 3.0, y, StreetLayout.HOUSE_FRONT - 0.6)},
		"alley_end": {"pos": Vector3(alley_x, y, StreetLayout.alley_end_z() - 0.5)},
		"opposite_alley_end": {"pos": Vector3((opp.x + opp.y) / 2.0, y, StreetLayout.opposite_alley_end_z() + 0.5)},
		"opposite_alley_mouth": {"pos": Vector3((opp.x + opp.y) / 2.0, y, StreetLayout.opposite_front_z() - 1.0)},
	}


func _gate_spot(along: float, across: float) -> Vector2:
	var side := StreetLayout.turning_side()
	var front := StreetLayout.gatehouse_front()
	var moved := {"pos": (front.pos as Vector2) + (front.dir as Vector2) * along, "dir": front.dir}
	return StreetLayout.end_offset(moved, across, side)


func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


func _on_appeared(who: Node3D, spot: Vector2) -> void:
	_report.appeared += 1
	if who is StreetVehicle:
		var key := who.name.rstrip("0123456789")
		_report.vehicles[key] = int(_report.vehicles.get(key, 0)) + 1
	_count_place(spot, "+" if who is Passerby else "+Fahrzeug ")
	if _life.is_visible_spot(spot):
		_report.appear_in_view.append("%s bei %s (Stelle %s)" % [who.name, spot, _spot_name])
	if _open_view(spot):
		_report.appear_open += 1


func _on_vanished(who: Node3D, spot: Vector2) -> void:
	_report.vanished += 1
	_count_place(spot, "-" if who is Passerby else "-Fahrzeug ")
	if _life.is_visible_spot(spot):
		_report.vanish_in_view.append("%s bei %s (Stelle %s)" % [who.name, spot, _spot_name])
	if _open_view(spot):
		_report.vanish_open += 1


func _count_place(spot: Vector2, sign_text: String) -> void:
	var key := "%s(%d, %d)" % [sign_text, roundi(spot.x), roundi(spot.y)]
	_report.places[key] = int(_report.places.get(key, 0)) + 1


## Freie Sichtlinie vom Auge zur Stelle (egal, wohin man gerade schaut)?
func _open_view(spot: Vector2) -> bool:
	var eye := _camera.global_position
	for h in [0.3, 1.0, 1.7]:
		var target := _life.to_global(Vector3(spot.x, h, spot.y))
		if _life._line_of_sight(eye, target):
			return true
	return false


func _measure() -> void:
	_report.samples += 1
	# Katzen: laufen, kommen aber nicht vom Fleck (12 s)?
	if _life.cats:
		for cat in _life.cats.get_cats():
			var last: Array = _cat_track.get(cat, [cat.global_position, 0.0])
			if cat.get_action_type() in ["walk", "follow"] and cat.global_position.distance_to(last[0]) < 0.05:
				last[1] += SAMPLE
				if last[1] >= 12.0:
					_cat_stuck.append("%s bei %s (%s, Stelle %s)" % [cat.name, cat.global_position, cat.get_action_type(), _spot_name])
					last[1] = -1000.0
			else:
				last = [cat.global_position, 0.0 if last[1] >= 0.0 else last[1]]
			_cat_track[cat] = last
	var walkers := _life.get_walkers()
	var player := _life.player_pos()
	var space := _main.get_world_3d().direct_space_state
	for walker in walkers:
		if walker.on_road:
			_report.crossing += 1
		var action := walker.get_action()
		if action.get("anim", &"") == &"browse":
			_report.browsing += 1
		if action.has("alley"):
			_report.alley += 1
		if walker.get_action_type() == "sit":
			_report.sitting += 1
	_check_floor(walkers)
	for i in walkers.size():
		var a := walkers[i]
		for j in range(i + 1, walkers.size()):
			var b := walkers[j]
			var gap := a.pos.distance_to(b.pos) - a.radius * a.scale.x - b.radius * b.scale.x
			# zu zweit unterwegs: dürfen enger nebeneinander (Körper sind schmaler als der Ausweich-Kreis)
			if a.companion == b:
				gap += 0.24
			elif a.squeeze > 0.0 and b.squeeze > 0.0:
				gap += 0.5 - StreetLife.SQUEEZE_GAP  # Engstelle: Schulter an Schulter vorbei
			_report.min_walker_gap = minf(_report.min_walker_gap, gap)
			if gap < -0.08:
				_report.overlap.append("%s/%s %.2f m bei %s (%s): %s%s / %s%s" % [a.name, b.name, gap, a.pos, _spot_name,
					a.debug_text(), a.pair_text(), b.debug_text(), b.pair_text()])
		var player_gap := a.pos.distance_to(player) - a.radius * a.scale.x - StreetLife.PLAYER_RADIUS
		_report.min_player_gap = minf(_report.min_player_gap, player_gap)
		if player_gap < -0.02:
			_report.player_bump.append("%s %.2f m (%s)" % [a.name, player_gap, _spot_name])
		# Wer auf der Bank sitzt, steckt mit den Beinen in ihrer Kollision und bewegt sich nicht
		if a.get_action_type() == "sit":
			_track[a] = [a.pos, 0.0]
			continue
		# Durch eine Tür oder im Laden/Haus (seit Etappe 6i): das Gebäude ist dort das Ziel, kein Fehler
		if a.floor_y > 0.0 or a.get_action_type() in ["door", "chore", "buy"] or a.get_action().get("yard", false):
			_track[a] = [a.pos, 0.0]
			continue
		# In etwas Festes hinein? (Häuser, Mauern, Treppe, Kartons; nicht die Grenzen der Spielfigur)
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.17
		capsule.height = 1.2
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, _life.to_global(Vector3(a.pos.x, 0.95, a.pos.y)))
		query.collision_mask = StreetLife.SIGHT_MASK
		for hit in space.intersect_shape(query, 4):
			var collider := hit.collider as Node
			# Hüpfende Kartons zählen nicht: Das Werkzeug spult im Zeitraffer, das Hüpfen läuft in
			# echter Zeit (im Spiel landet ein Karton nie auf jemandem, siehe DeliveryManager)
			var box := collider.get_parent() as DeliveryBox if collider else null
			if collider and collider.name != "Bounds" and not (box and box.is_moving()):
				_report.solid.append("%s in %s bei %s (%s): %s" % [a.name, collider.get_path(), a.pos, _spot_name, a.debug_text()] + " | nah: %s, Karton bei %s" % [
					_life.obstacles_near(a, 1.0).map(func(o): return "%s@%s" % [o.kind, o.pos]),
					_life.to_local((collider as Node3D).global_position)])
		# Tritt jemand beim Gehen auf der Stelle (nicht wegen der Spielfigur)?
		var walking: bool = a.get_action_type() == "walk" or (a.get_action_type() == "leave" and not a.get_action().get("gate", false))
		if walking and a.velocity2.length() < 0.15 and a.pos.distance_to(player) > 2.0:
			_stall[a] = float(_stall.get(a, 0.0)) + SAMPLE
			if is_equal_approx(float(_stall[a]), 2.5):
				_report.stall.append("%s bei %s (%s): %s | nah: %s" % [a.name, a.pos, _spot_name, a.debug_text(),
					_life.obstacles_near(a, 1.6).map(func(o): return "%s@%s r%.2f%s" % [o.kind, o.pos, o.radius,
						(" (%s, v=%s)" % [o.agent.get_action_type(), o.vel]) if o.kind == "cat" else (
						" (%s %s%s)" % [o.agent.name, o.agent.get_action_type(), o.agent.pair_text()] if o.kind == "walker" else "")])]
					+ a.pair_text())
		else:
			_stall[a] = 0.0
		# Hängt jemand fest?
		var track: Array = _track.get(a, [a.pos, 0.0])
		if a.pos.distance_to(track[0]) > 0.4:
			track = [a.pos, 0.0]
		else:
			track[1] = float(track[1]) + SAMPLE
			if float(track[1]) > 40.0:
				_report.stuck.append("%s seit 40 s bei %s (%s): %s" % [a.name, a.pos, _spot_name, a.debug_text()])
				track = [a.pos, -1000.0]
		_track[a] = track
	for vehicle in _life.get_vehicles():
		var vtrack: Array = _track.get(vehicle, [vehicle.pos, 0.0])
		if vehicle.pos.distance_to(vtrack[0]) > 1.0:
			vtrack = [vehicle.pos, 0.0]
		else:
			vtrack[1] = float(vtrack[1]) + SAMPLE
			if float(vtrack[1]) > 30.0:
				var waits := " – wartet vor der Spielfigur (richtig)" if _life.player_on_road() else ""
				_report.stuck.append("seit 30 s: %s (%s)%s" % [vehicle.debug_text(), _spot_name, waits])
				vtrack = [vehicle.pos, -1000.0]
		_track[vehicle] = vtrack
		if _life.cats and vehicle.speed > 0.5:
			var forward2 := Vector2(sin(vehicle.rotation.y), cos(vehicle.rotation.y))
			for cat in _life.cats.get_cats():
				var cp := Vector2(_life.to_local(cat.global_position).x, _life.to_local(cat.global_position).z)
				var cd := cp - vehicle.pos
				var cx := maxf(absf(cd.dot(forward2)) - vehicle.length / 2.0, 0.0)
				var cy := maxf(absf(cd.dot(Vector2(forward2.y, -forward2.x))) - vehicle.width / 2.0, 0.0)
				if sqrt(cx * cx + cy * cy) < 0.15 and _life.to_local(cat.global_position).y < 0.3:
					_report.vehicle_cat.append("%s (%.1f m/s) durch %s (%s)" % [vehicle.name, vehicle.speed, cat.name, _spot_name])
		for walker in walkers:
			if vehicle.speed > 0.8 and vehicle.distance_to_walker(walker) < 0.5:
				_report.vehicle_close.append("%s (s=%.1f lat=%.2f %.1f m/s) nah an %s (%s, %s)" % [vehicle.name,
					vehicle.get_s(), vehicle.get_lat(), vehicle.speed, walker.name, _spot_name, walker.debug_text()])
		if vehicle.speed > 0.8:
			var p := _life.player_pos()
			var forward := Vector2(sin(vehicle.rotation.y), cos(vehicle.rotation.y))
			var d := p - vehicle.pos
			var dx := maxf(absf(d.dot(forward)) - vehicle.length / 2.0, 0.0)
			var dy := maxf(absf(d.dot(Vector2(forward.y, -forward.x))) - vehicle.width / 2.0, 0.0)
			if sqrt(dx * dx + dy * dy) < 0.45:
				_report.vehicle_close.append("%s nah an der Spielfigur (%s, %.1f m/s)" % [vehicle.name, _spot_name, vehicle.speed])


## Prüfen: die Spielfigur wirft ein Spielzeug zur nächsten Katze (wie mit E).
func _test_throw() -> void:
	var c := _life.cats
	var player := _life.get_player()
	if player == null or c.get_cats().is_empty():
		return
	var toy: Node3D = null
	for t in c._toys:
		if not t.get_meta("held", false) and not t.get_parent() is StreetCat:
			toy = t
			break
	if toy == null:
		return
	var cat: StreetCat = c.get_cats()[0]
	var to := cat.global_position - player.global_position
	to.y = 0.0
	if to.length() > 12.0:
		return
	var start := player.global_position + Vector3.UP * 1.4
	c.throw_toy(toy, start, (to.normalized() * minf(to.length(), 6.0) * 0.8 + Vector3.UP * 2.5))


func _print_report() -> void:
	print("")
	if _life.birds:
		var b := _life.birds
		print("=== Tiere (seit Etappe 6g) ===")
		print("Vögel: Flüge %d, Durchflüge %d, gerade unterwegs %d, Erscheinen im Blickfeld %d, Verschwinden im Blickfeld %d, unter dem Boden %d" % [
			b.flights, b.flyovers, b.get_birds().size(), b.visible_spawns, b.visible_exits, b.below_ground])
		for line in b.below_ground_log:
			print("  BODEN: ", line)
		print("Vögel im Gartenhof der Baumgasse: gelandet %d Schwärme, gerade dort %d" % [b.court_flocks, b.court_birds()])
		print("Flugbahnen: mit steilem Stück (über 2 m steiler als 60°) %d, längstes solches Stück %.1f m" % [b.steep_paths, b.steepest_stretch])
		for line in b.steep_log:
			print("  STEIL: ", line)
	if _life.cats:
		var c := _life.cats
		print("Katzen: Besuche %d, in der Bücherei %d, gejagt %d, gespielt %d, Erscheinen im Blickfeld %d, Verschwinden im Blickfeld %d, festgefahren %d" % [
			c.visits, c.entered, c.hunts, c.plays, c.visible_spawns, c.visible_exits, _cat_stuck.size()])
		print("Katzen (seit 6h): Gartenmauern %d (bekannt: %d), Fensterbänke %d, gerieben %d, Begegnungen %d, Würfe %d (hinterher %d)" % [
			c.wall_walks, c.get_walls().size(), c.sill_sits, c.rubs, c.meetings, c.throws, c.chases])
		print("Katzen im Gartenhof: Abstecher %d, dort gejagt %d; über eine Bank aufs Fensterbrett: %d" % [c.garden_visits, c.court_hunts, c.bench_hops])
		for line in _cat_stuck:
			print("  ", line)
	print("Passanten (seit 6h): geplaudert %d (davon Hände geschüttelt %d), auf der Bank geplaudert %d, Katzen gestreichelt %d, zu zweit %d" % [
		_life.stat_chats, _life.stat_handshakes, _life.stat_seat_chats, _life.stat_pets, _life.stat_pairs])
	if _life.homes:
		var h := _life.homes
		print("Anwohner (seit 6i): Häuser %d, Anwohner %d, durch die Tür %d, Wege %d, gegossen %d, gefegt %d, am Fenster %d, gerade draußen %d" % [
			h.homes.size(), h.residents.size(), h.stat_doors_used, h.stat_errands, h.stat_water, h.stat_sweep, h.stat_windows, h.residents_outside()])
	print("Begegnungen (seit 6i): Umarmungen %d, zusammen weiter %d, über die Straße gewinkt %d" % [_life.stat_hugs, _life.stat_together, _life.stat_waves])
	if _life.homes:
		print("Läden (seit 6i): Läden %d, Besuche %d, Tüten %d, im Pub gesetzt %d, feste Gäste %d, Figuren drinnen %d" % [_life.homes.shops.size(),
			_life.homes.stat_shop_visits, _life.homes.stat_bags, _life.homes.stat_pub_visits, _life.homes.guests.size(), _life.homes.indoor.size()])
	if _life.library:
		var t := Lending.today
		print("Bücherei (seit 7): Besucher %d, ausgeliehen %d, nichts gefunden %d, neue Ausweise %d, Einnahmen %d, %s" % [
			int(t.visitors), int(t.borrowed), int(t.nothing_found), int(t.cards), int(t.income), _life.library.stats_text()])
	print("=== Bericht Straßenleben ===")
	print("Messungen: %d" % _report.samples)
	print("Erschienen: %d, im Blickfeld: %d, mit freier Sicht (beim Umdrehen): %d" % [
		_report.appeared, _report.appear_in_view.size(), _report.appear_open])
	print("Verschwunden: %d, im Blickfeld: %d, mit freier Sicht (beim Umdrehen): %d" % [
		_report.vanished, _report.vanish_in_view.size(), _report.vanish_open])
	for line in _report.appear_in_view + _report.vanish_in_view:
		print("  SICHTBAR: ", line)
	print("Orte (+ erscheinen, - verschwinden): ", _report.places)
	print("Fahrzeuge losgefahren: ", _report.vehicles)
	print("Messungen mit Passanten beim Überqueren: %d, vor einem Schaufenster: %d, in einer Gasse: %d, auf der Bank: %d" % [
		_report.crossing, _report.browsing, _report.alley, _report.sitting])
	print("Kleinster Abstand zwischen Passanten: %.2f m, zur Spielfigur: %.2f m" % [_report.min_walker_gap, _report.min_player_gap])
	for key in ["overlap", "player_bump", "solid", "stuck", "stall", "vehicle_close", "vehicle_cat", "floor"]:
		var list: Array = _report[key]
		print("%s: %d" % [key, list.size()])
		for i in mini(list.size(), 12):
			print("  ", list[i])


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		var clean := arg.trim_prefix("--")
		var eq := clean.find("=")
		if eq == -1:
			result[clean] = true
		else:
			result[clean.substr(0, eq)] = clean.substr(eq + 1)
	return result


## Stehen alle auf einem Boden? Boden = was ein Strahl nach unten trifft (Gehweg, Laden, Möbel), auf der Fahrbahn deren
## Höhe (sie liegt nur optisch tiefer); Fensterbänke und Mauerkronen (ohne Kollision) aus der Vermessung, die Treppe wird
## ausgelassen (die Kollision dort ist eine Rampe). Meldet Figuren, die mehr als 5 cm schweben oder einsinken.
func _check_floor(walkers: Array) -> void:
	var space := _main.get_world_3d().direct_space_state
	var half := GameConfig.street_width / 2.0
	var door := StreetLayout.door_center()
	for w in walkers:
		if w.get_action_type() in ["sit", "leave"] or not w.visible or w.floor_y > 0.0:
			continue  # (floor_y > 0: geht drinnen auf dem Ladenboden, dort gibt es keine Bodenkollision)
		_floor_case(space, w.name, w.global_position, w.get_action_type(), half, door, [])
	if _life.cats:
		for cat in _life.cats.get_cats():
			if not cat.active or cat.get_action_type() in ["jump", "pounce", "leave"] or cat._rest_on != null or cat.seat != null:
				continue
			var ledges: Array[float] = []
			for sill in _life.cats._sills:
				if Vector2(sill.pos.x - cat.global_position.x, sill.pos.z - cat.global_position.z).length() < 0.8:
					ledges.append(float(sill.pos.y))
			for wall in _life.cats.get_walls():
				if wall.taken == cat:
					ledges.append(float(wall.a.y))
			_floor_case(space, cat.name, cat.global_position, cat.get_action_type(), half, door, ledges)
	if _life.birds:
		for bird in _life.birds.get_birds():
			if bird.is_on_ground():
				_floor_case(space, bird.name, bird.global_position, "ground", half, door, [])


func _floor_case(space: PhysicsDirectSpaceState3D, who: String, p: Vector3, what: String, half: float, door: Vector3, ledges: Array) -> void:
	var local := _life.to_local(p)
	if Vector2(local.x - door.x, local.z - door.z).length() < 3.2:
		return  # Treppe
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.4, p + Vector3.DOWN * 1.2, 1 | 8)
	var hit := space.intersect_ray(query)
	var ground: float = hit.position.y if not hit.is_empty() else p.y
	var lat := _life.centerline.project(Vector2(local.x, local.z)).y
	var road := _life.to_global(Vector3(local.x, -GameConfig.curb_height, local.z)).y
	if absf(lat) < half and not hit.is_empty():
		ground = road
	var diff := p.y - ground
	if absf(diff) <= 0.05:
		return
	# genau an der Bordsteinkante zählen beide Höhen
	if absf(absf(lat) - half) < 0.15 and absf(p.y - road) <= 0.05:
		return
	for y: float in ledges:
		if absf(p.y - y) < 0.05:
			return
	if _report.floor.size() < 40:
		_report.floor.append("%s (%s) %+.2f m über dem Boden bei %s (%s)" % [who, what, diff, Vector3(local.x, local.y, local.z).snapped(Vector3.ONE * 0.01), _spot_name])
