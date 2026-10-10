extends Node
## Prüfwerkzeug für das Leben auf der Straße (seit Etappe 5a) – für die Selbstkontrolle von
## Claude. Lädt die Hauptszene, stellt die Spielfigur nacheinander an viele erreichbare Stellen
## (Ladentür, Gehwege, Fahrbahn, beide Grenzen, Enden der Gassen, Platz, im Laden), dreht dort
## die Kamera langsam im Kreis und spult das Straßenleben vor. Am Ende steht ein Bericht:
## - Erscheinen/Verschwinden: wie oft, wo – und ob der Ort dabei im Blickfeld lag (muss 0 sein)
##   bzw. ob man ihn mit freier Sicht hätte sehen können, wenn man sich umdreht (nur zur Info),
## - Passanten, die sich überschneiden, in die Spielfigur, in Häuser, Treppe oder Kartons laufen,
## - Passanten, die hängen bleiben, und Fahrzeuge, die jemandem zu nahe kommen.
##
## Starten (Godot ohne Bildschirm):
##   godot --headless --path . res://scenes/tools/street_life_check.tscn -- --seconds=40 --seed=1
## Angaben nach "--": --seconds=<je Stelle> (Standard 45), --seed=<zahl>, --only=<stelle,…>,
## --deliver=<n> (Testlieferung mit n Kartons, sobald die erste Stelle beginnt).

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
	"overlap": [], "player_bump": [], "solid": [], "stuck": [], "vehicle_close": [],
	"min_walker_gap": INF, "min_player_gap": INF, "samples": 0, "vehicles": {}, "crossing": 0, "browsing": 0, "alley": 0,
}
var _track := {}  # Passant -> [letzte Stelle, Zeit seit Bewegung]
var _spot_name := ""


func _ready() -> void:
	_args = _parse_args()
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
	if _args.has("deliver"):
		var manager := get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager
		manager.place_order([{"kind": "furniture", "id": "armchair_velvet", "count": int(_args.deliver)}], 0.0)
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
	_count_place(spot, "+")
	if _life.is_visible_spot(spot):
		_report.appear_in_view.append("%s bei %s (Stelle %s)" % [who.name, spot, _spot_name])
	if _open_view(spot):
		_report.appear_open += 1


func _on_vanished(who: Node3D, spot: Vector2) -> void:
	_report.vanished += 1
	_count_place(spot, "-")
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
	for i in walkers.size():
		var a := walkers[i]
		for j in range(i + 1, walkers.size()):
			var b := walkers[j]
			var gap := a.pos.distance_to(b.pos) - a.radius * a.scale.x - b.radius * b.scale.x
			_report.min_walker_gap = minf(_report.min_walker_gap, gap)
			if gap < -0.08:
				_report.overlap.append("%s/%s %.2f m bei %s (%s)" % [a.name, b.name, gap, a.pos, _spot_name])
		var player_gap := a.pos.distance_to(player) - a.radius * a.scale.x - StreetLife.PLAYER_RADIUS
		_report.min_player_gap = minf(_report.min_player_gap, player_gap)
		if player_gap < -0.02:
			_report.player_bump.append("%s %.2f m (%s)" % [a.name, player_gap, _spot_name])
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


func _print_report() -> void:
	print("")
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
	print("Messungen mit Passanten beim Überqueren: %d, vor einem Schaufenster: %d, in einer Gasse: %d" % [
		_report.crossing, _report.browsing, _report.alley])
	print("Kleinster Abstand zwischen Passanten: %.2f m, zur Spielfigur: %.2f m" % [_report.min_walker_gap, _report.min_player_gap])
	for key in ["overlap", "player_bump", "solid", "stuck", "vehicle_close"]:
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
