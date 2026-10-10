class_name StreetLife
extends Node3D
## Leben auf der Straße (seit Etappe 5a): Passanten, Fahrräder, Autos und der Lieferwagen.
## Knoten "Outside/StreetLife" in der Hauptszene (liegt wie alles unter "Outside" auf
## Gehweg-Höhe). Alle Werte in GameConfig (Abschnitt „Leben auf der Straße“).
##
## Grundregel: Niemand erscheint oder verschwindet sichtbar.
## - Erscheinen und Verschwinden nur an festen Orten außer Sicht (Gruppe
##   Street.TRAFFIC_GROUP: hinter der runden Kurve am geraden Ende, hinter dem Torhaus, am Ende
##   der Gassen).
## - Zusätzlich wird jedes Mal geprüft, ob der Ort gerade im Blickfeld der Kamera liegt
##   (is_visible_spot: im Bild – mit Rand – und nicht von Häusern verdeckt). Wenn ja, wartet das
##   Erscheinen bzw. die Figur geht noch ein Stück weiter (oder wartet am Tor).
## Häuser verdecken die Sicht über ihre Kollision (Ebene "world") oder, wo man nicht hinkommt,
## über einen unsichtbaren Sichtblocker (Ebene "sight_blocker", siehe HouseFacade).
##
## Passanten gehen die Gehwege entlang (StreetPaths, StreetRoute), überqueren manchmal die
## Straße, schauen in Schaufenster (Modegeschäft, Pub, Bücherei: Knoten "WindowSpots" und
## GameConfig.passerby_window_house_types) und kommen aus den Gassen oder gehen hinein.
## Für den nächsten Schritt (Besucher): Kommt ein Passant an der Bücherei vorbei, ruft er
## passing(passant, "library") – hier kann er später entscheiden, hineinzugehen
## (Signal passing_library, Ort vor der Treppe: StreetPaths.library_entrance()).
##
## Leistung: Alle Figuren entstehen beim Start (Vorrat) und werden nur ein- und ausgeblendet –
## kein Zuckeln beim Erscheinen. Schatten nur in der Nähe (GameConfig.graphics_presets,
## "street_shadow_distance"), weit weg vereinfacht (street_detail_distance).
## Gespeichert wird hier nichts.

## Ein Passant kommt an einem besonderen Ort vorbei (gerade nur "library": vor der Bücherei).
signal passing_library(passerby: Passerby)
## Jemand erscheint bzw. verschwindet (für das Prüfwerkzeug): Passant oder Fahrzeug, Ort (x, z).
signal appeared(who: Node3D, spot: Vector2)
signal vanished(who: Node3D, spot: Vector2)

const GROUP := "street_life"
const OBSTACLE_GROUP := "street_obstacles"
## Abstand der Wege zu Schaufenstern von festen Hindernissen (Körpermitte, m)
const WINDOW_CLEARANCE := 0.45
## Spielfigur: Radius (wie ihre Kollision) und Abstand, den Passanten mindestens halten.
const PLAYER_RADIUS := 0.3
const PLAYER_GAP := 0.03
## Radius eines Kartonstapels vor der Tür (für Passanten).
const BOX_RADIUS := 0.4
## Ebenen, die die Sicht verdecken: world (1) und sight_blocker (8).
const SIGHT_MASK := 1 | 128
## Radius beim Ausmessen der Gehwege (Passant + etwas Luft zur Wand).
const FIT_RADIUS := 0.36
## So viele Figuren mehr im Vorrat, als gleichzeitig unterwegs sind (mehr Abwechslung).
const EXTRA_LOOKS := 4

## Spielfigur (für Ausweichen und Bremsen). Die Sichtprüfung nimmt immer die aktive Kamera.
@export var player_path: NodePath

## Gemeinsame Wege (einmal berechnet)
var centerline: StreetRoute
var sidewalks := {}  # Seite (1, -1) -> StreetRoute
var crossing_route: StreetRoute
var road_route: StreetRoute

var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _walkers: Array[Passerby] = []
var _vehicles: Array[StreetVehicle] = []
var _idle_bikes: Array[StreetVehicle] = []
var _idle_cars: Array[StreetVehicle] = []
var _bike_timer := 0.0
var _car_timer := 0.0
var _van: DeliveryVan
var _van_manager: DeliveryManager
var _idle_walkers: Array[Passerby] = []
var _walker_timer := 0.0
## Orte zum Erscheinen: { "kind", "place" ("east", "west", "alley", "opposite_alley"), "pos", "side" }
var _places: Array[Dictionary] = []
## Schaufenster: { "pos", "face", "s", "side" }
var _windows: Array[Dictionary] = []
var _static_obstacles: Array[Dictionary] = []
var _obstacles: Array[Dictionary] = []
var _library_s := 0.0
var _crossing := Vector2.ZERO
var _lod_timer := 0.0
var _started := false


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	_player = get_node_or_null(player_path) as Node3D
	centerline = StreetPaths.centerline()
	sidewalks[1] = StreetPaths.sidewalk_route(1)
	sidewalks[-1] = StreetPaths.sidewalk_route(-1)
	crossing_route = StreetPaths.crossing_route()
	road_route = StreetPaths.road_route()
	_crossing = StreetPaths.crossing_range()
	_library_s = centerline.project(StreetPaths.library_entrance()).x
	# Orte, Schaufenster und Hindernisse erst, wenn alle Nachbarn (Straße, Häuser) fertig sind
	_start.call_deferred()


func _start() -> void:
	_build_pool()
	_build_vehicle_pool()
	for side in [1, -1]:
		_fit_band_to_houses(sidewalks[side], side)
	_collect_places()
	_collect_windows()
	_collect_static_obstacles()
	_started = true
	if GameConfig.street_life_enabled:
		_fill_street()


## Zufall festlegen (Prüfwerkzeug, Testbilder): gleiche Zahl = gleicher Ablauf.
func seed_random(value: int) -> void:
	_rng.seed = value


## Gleiche Mittellinie (Gehwege, Fahrbahn, Überqueren)? Dann ist lat der Abstand zur Straßenmitte.
func is_centerline(route: StreetRoute) -> bool:
	return route == centerline or route == sidewalks.get(1) or route == sidewalks.get(-1) \
		or route == crossing_route or route == road_route


## Wie belebt die Straße gerade ist (1 = normal). Später kann das von der Tageszeit abhängen
## (Etappe 6): dann hier die Uhrzeit einrechnen – Anzahl und Abstände richten sich danach.
func activity() -> float:
	return maxf(0.0, GameConfig.street_activity)


func _physics_process(delta: float) -> void:
	if not _started or not GameConfig.street_life_enabled:
		return
	step(delta)


## Ein Schritt für alle (auch vom Prüfwerkzeug aufgerufen, um Zeit vorzuspulen).
func step(delta: float) -> void:
	_collect_obstacles()
	for walker in _walkers:
		walker.step(delta)
	for vehicle in _vehicles.duplicate():
		vehicle.step(delta)
	_spawn_walkers(delta)
	_spawn_vehicles(delta)
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.3
		_update_detail()


# --- Vorrat ---

func _build_pool() -> void:
	var scenes: Array[PackedScene] = []
	for path in GameConfig.passerby_scenes:
		var scene := load(path) as PackedScene
		if scene:
			scenes.append(scene)
	if scenes.is_empty():
		return
	var folder := Node3D.new()
	folder.name = "Passersby"
	add_child(folder)
	# Ein paar mehr Figuren als gleichzeitig unterwegs sind: so kommt nicht gleich dieselbe wieder
	for i in maxi(0, GameConfig.passerby_count) + EXTRA_LOOKS:
		var walker := scenes[i % scenes.size()].instantiate() as Passerby
		walker.name = "Passerby%d" % (i + 1)
		walker.life = self
		folder.add_child(walker)
		walker.finished.connect(_on_walker_finished)
		walker.randomize_look(_rng)
		_idle_walkers.append(walker)


## Fahrräder und Autos: ein kleiner Vorrat, beim Start gebaut.
func _build_vehicle_pool() -> void:
	var folder := Node3D.new()
	folder.name = "Vehicles"
	add_child(folder)
	for item in [[GameConfig.bike_scene, 2, _idle_bikes, "Cyclist"], [GameConfig.car_scene, GameConfig.car_count, _idle_cars, "Car"]]:
		var scene := load(item[0]) as PackedScene
		if scene == null:
			continue
		for i in maxi(0, item[1]):
			var vehicle := scene.instantiate() as StreetVehicle
			vehicle.name = "%s%d" % [item[3], i + 1]
			vehicle.life = self
			folder.add_child(vehicle)
			vehicle.finished.connect(_on_vehicle_finished.bind(item[2]))
			(item[2] as Array).append(vehicle)
	var van_scene := load(GameConfig.delivery_van_scene) as PackedScene
	if van_scene:
		_van = van_scene.instantiate() as DeliveryVan
		_van.name = "DeliveryVan"
		_van.life = self
		folder.add_child(_van)
		_van.randomize_look(_rng, GameConfig.delivery_van_color)
		_van.finished.connect(_on_van_finished)
	_bike_timer = _rng.randf_range(3.0, GameConfig.bike_interval.x)
	_car_timer = _rng.randf_range(8.0, GameConfig.car_interval.x)


func _on_vehicle_finished(vehicle: StreetVehicle, pool: Array) -> void:
	vanished.emit(vehicle, vehicle.pos)
	vehicle.set_active(false)
	_vehicles.erase(vehicle)
	pool.append(vehicle)


func _on_van_finished(van: StreetVehicle) -> void:
	vanished.emit(van, van.pos)
	van.set_active(false)
	_vehicles.erase(van)


func _on_walker_finished(walker: Passerby) -> void:
	vanished.emit(walker, walker.pos)
	walker.set_active(false)
	_walkers.erase(walker)
	_idle_walkers.append(walker)


# --- Orte ---

## Orte zum Erscheinen und Verschwinden aus der Gruppe Street.TRAFFIC_GROUP.
func _collect_places() -> void:
	_places.clear()
	for marker: Node3D in get_tree().get_nodes_in_group(Street.TRAFFIC_GROUP):
		var local := _to_local2(marker.global_position)
		var place := String(marker.get_meta("place", ""))
		var entry := {"kind": String(marker.get_meta("kind", "")), "place": place, "pos": local, "side": 0}
		if place in ["east", "west"]:
			entry.side = 1 if centerline.project(local).y > 0.0 else -1
		elif place == "alley":
			entry.side = 1
		elif place == "opposite_alley":
			entry.side = -1
		_places.append(entry)


## Schaufenster: feste Punkte unter "WindowSpots" (Blickrichtung -Z des Punkts) und alle Häuser
## der Typen GameConfig.passerby_window_house_types (vor der Mitte der Hausfront).
func _collect_windows() -> void:
	_windows.clear()
	var spots := get_node_or_null("WindowSpots")
	if spots:
		for marker: Node3D in spots.get_children():
			var face := -marker.global_basis.z
			_add_window(_to_local2(marker.global_position), Vector2(face.x, face.z).normalized(), 0.0)
	var houses := get_node_or_null("../Houses")
	if houses == null:
		return
	for house: Node in houses.find_children("*", "HouseFacade", true, false):
		var type := (house as Node3D).scene_file_path.get_file().get_basename()
		if not type in GameConfig.passerby_window_house_types:
			continue
		var node := house as Node3D
		var front := node.global_basis.z
		var out := Vector2(front.x, front.z).normalized()
		var spread := maxf(0.0, float(house.get("width")) / 2.0 - 1.1)
		_add_window(_to_local2(node.global_position) + out * 0.75, -out, spread)


func _add_window(spot: Vector2, face: Vector2, spread: float) -> void:
	var lage := centerline.project(spot)
	_windows.append({"pos": spot, "face": face, "s": lage.x, "side": 1 if lage.y > 0.0 else -1,
		"spread": spread})


## Platz vor einem Schaufenster, dessen Hin- und Rückweg nicht durch feste Hindernisse
## (Kübel, Stufen …) führt (seit Etappe 4g); Vector2.INF, wenn keiner frei ist.
func _free_window_spot(spot: Dictionary, side: int, cursor: float, dir: int, comfort: float) -> Vector2:
	for attempt in 8:
		var at: Vector2 = spot.pos + Vector2(-spot.face.y, spot.face.x) * _rng.randf_range(-1.0, 1.0) * float(spot.spread)
		var lane_before := _ahead(centerline.project(at).x - dir * 1.2, cursor, dir)
		var from := _lane_point(side, lane_before, comfort)
		var to := _lane_point(side, lane_before + dir * 2.4, comfort)
		if _clear_of_static(from, at) and _clear_of_static(at, to):
			return at
	return Vector2.INF


func _clear_of_static(a: Vector2, b: Vector2) -> bool:
	for obstacle in _static_obstacles:
		var closest := Geometry2D.get_closest_point_to_segment(obstacle.pos, a, b)
		if closest.distance_to(obstacle.pos) < float(obstacle.radius) + WINDOW_CLEARANCE:
			return false
	return true


func _collect_static_obstacles() -> void:
	_static_obstacles.clear()
	for node: Node3D in get_tree().get_nodes_in_group(OBSTACLE_GROUP):
		_static_obstacles.append({"pos": _to_local2(node.global_position), "radius": float(node.get("radius")),
			"vel": Vector2.ZERO, "kind": "static"})


func _to_local2(global_point: Vector3) -> Vector2:
	var local := to_local(global_point)
	return Vector2(local.x, local.z)


## Passt den Gehweg-Streifen an die Häuser an: An jedem Punkt wird mit der Physik gemessen,
## wie weit man zur Hausseite hin gehen kann, ohne eine Wand, einen Pfeiler oder die Treppe zu
## berühren (Ebenen world und sight_blocker, auch bei eigenen Haus-Modellen). So bleiben
## Passanten auch in Kurven, an Eckhäusern und unter dem Torbogen sauber auf dem Gehweg.
func _fit_band_to_houses(route: StreetRoute, side: int) -> void:
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = FIT_RADIUS
	capsule.height = 1.25
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = SIGHT_MASK
	for i in route.points.size():
		var inner := route.comfort_low[i] if side > 0 else route.comfort_high[i]
		var outer := route.high[i] if side > 0 else route.low[i]
		var free := inner
		var lat := inner
		while (lat - outer) * side < 0.0:
			lat = minf(lat + 0.08, outer) if side > 0 else maxf(lat - 0.08, outer)
			var p := route.points[i] + route.normals[i] * lat
			query.transform = Transform3D(Basis.IDENTITY, to_global(Vector3(p.x, 0.72, p.y)))
			if _hits_solid(space.intersect_shape(query, 4)):
				break
			free = lat
		if side > 0:
			route.high[i] = free
			route.comfort_high[i] = maxf(minf(route.comfort_high[i], free), route.comfort_low[i])
		else:
			route.low[i] = free
			route.comfort_low[i] = minf(maxf(route.comfort_low[i], free), route.comfort_high[i])


## Trifft eine Abfrage etwas Festes? (Die Grenzen für die Spielfigur und Kartons zählen nicht.)
func _hits_solid(hits: Array[Dictionary]) -> bool:
	for hit in hits:
		var collider := hit.collider as Node
		if collider == null or collider.name == "Bounds" or collider.get_parent() is DeliveryBox:
			continue
		return true
	return false


# --- Hindernisse ---

## Alle unterwegs (für das Prüfwerkzeug).
func get_walkers() -> Array[Passerby]:
	return _walkers


## Alle Fahrzeuge unterwegs (für das Prüfwerkzeug).
func get_vehicles() -> Array[StreetVehicle]:
	return _vehicles


## Alle, denen man ausweichen muss: Passanten, Spielfigur, Kartons, feste Hindernisse
## (Treppe …). Je Eintrag: pos, radius, vel, kind, agent.
func _collect_obstacles() -> void:
	_obstacles.clear()
	for walker in _walkers:
		_obstacles.append({"pos": walker.pos, "radius": walker.radius * walker.scale.x,
			"vel": walker.velocity2, "kind": "walker", "agent": walker})
	if _player:
		var velocity := Vector2.ZERO
		if _player is CharacterBody3D:
			var v := (_player as CharacterBody3D).velocity
			velocity = Vector2(v.x, v.z)
		_obstacles.append({"pos": player_pos(), "radius": PLAYER_RADIUS, "vel": velocity, "kind": "player"})
	for box in _box_positions():
		_obstacles.append({"pos": box, "radius": BOX_RADIUS, "vel": Vector2.ZERO, "kind": "box"})
	_obstacles.append_array(_static_obstacles)


## Kartonstapel vor der Tür (je Stapel ein Punkt).
func _box_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var manager := get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager
	if manager == null:
		return result
	for spot in manager.get_box_spots():
		result.append(_to_local2(spot))
	return result


## Hindernisse in der Nähe eines Passanten (ohne ihn selbst).
func obstacles_near(walker: Passerby, distance: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var limit := distance * distance
	for obstacle in _obstacles:
		if obstacle.get("agent") == walker:
			continue
		if walker.pos.distance_squared_to(obstacle.pos) <= limit:
			result.append(obstacle)
	return result


func player_pos() -> Vector2:
	return _to_local2(_player.global_position) if _player else Vector2(INF, INF)


## Würde der Passant an dieser Stelle jemandem zu nahe kommen (Spielfigur, andere Passanten,
## Kartons, Treppe)? Wegbewegen ist immer erlaubt – so kann sich nie jemand festlaufen.
func blocks_move(walker: Passerby, new_pos: Vector2) -> bool:
	var own := walker.radius * walker.scale.x
	for obstacle in _obstacles:
		if obstacle.get("agent") == walker:
			continue
		var p: Vector2 = obstacle.pos
		var limit := own + float(obstacle.radius)
		limit += PLAYER_GAP if obstacle.kind == "player" else -0.03
		var new_dist := new_pos.distance_to(p)
		if new_dist < limit and new_dist < walker.pos.distance_to(p) - 0.0005:
			return true
	return false


## Weg von "from" zu einem Platz vor einem Schaufenster. Stehen dort Kartons (Lieferung vor der
## Bücherei) oder etwas anderes, rückt der Platz ein Stück vor (weg vom Fenster).
func window_route(from: Vector2, spot: Vector2, face: Vector2) -> StreetRoute:
	var blockers: Array[Dictionary] = []
	for box in _box_positions():
		blockers.append({"pos": box, "radius": BOX_RADIUS})
	blockers.append_array(_static_obstacles)
	for i in 9:
		var free := true
		for blocker in blockers:
			if spot.distance_to(blocker.pos) < float(blocker.radius) + 0.32:
				free = false
				break
		if free:
			return StreetRoute.from_points(PackedVector2Array([from, spot]), 0.35)
		spot -= face * 0.1
	return null  # zu weit weg vom Fenster: lieber auslassen


## Ist die Fahrbahn an der Stelle dieses Passanten frei zum Überqueren? Kein Fahrzeug darf in
## den nächsten Sekunden vorbeikommen (stehende Fahrzeuge dicht daneben zählen auch).
func road_clear_for(walker: Passerby) -> bool:
	var s := centerline.project(walker.pos, walker.get_route_s() - 3.0, walker.get_route_s() + 3.0).x
	for vehicle in _vehicles:
		var ahead := (s - vehicle.get_s()) * vehicle.direction
		var reach := vehicle.length / 2.0 + 1.5
		# Ein stehendes Fahrzeug hält nur auf, wenn es direkt davor steht
		var coming := maxf(6.0, vehicle.speed * 5.0) if vehicle.speed > 0.3 else 0.0
		if ahead > -reach and ahead < reach + coming:
			return false
	return true


## Alles, wofür ein Fahrzeug bremsen oder ausweichen muss: Passanten, Spielfigur, andere
## Fahrzeuge. Je Eintrag: pos, radius (halbe Breite), reach (halbe Länge in Fahrtrichtung),
## speed (Tempo in meine Richtung), kind.
func road_obstacles(vehicle: StreetVehicle) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var limit := (StreetVehicle.LOOK_AHEAD + 6.0) * (StreetVehicle.LOOK_AHEAD + 6.0)
	var half := GameConfig.street_width / 2.0
	for walker in _walkers:
		# Nur wer auf der Fahrbahn ist – wer am Bordstein wartet, wartet ja auf das Fahrzeug
		if walker.body_on_road() and walker.pos.distance_squared_to(vehicle.pos) < limit:
			result.append({"pos": walker.pos, "radius": walker.radius * walker.scale.x, "reach": 0.3,
				"speed": 0.0, "kind": "walker"})
	if _player and player_pos().distance_squared_to(vehicle.pos) < limit:
		var lat := centerline.project(player_pos(), vehicle.get_s() - 30.0, vehicle.get_s() + 30.0).y
		if absf(lat) - PLAYER_RADIUS < half + 0.3:
			result.append({"pos": player_pos(), "radius": PLAYER_RADIUS, "reach": 0.3, "speed": 0.0, "kind": "player"})
	for other in _vehicles:
		if other == vehicle or other.pos.distance_squared_to(vehicle.pos) > limit:
			continue
		var same := other.direction == vehicle.direction
		result.append({"pos": other.pos, "radius": other.width / 2.0, "reach": other.length / 2.0,
			"speed": other.speed if same else 0.0, "kind": "vehicle" if same else "vehicle_oncoming"})
	return result


## Steht die Spielfigur auf der Fahrbahn (oder ragt hinein)? (Prüfwerkzeug.)
func player_on_road() -> bool:
	return absf(centerline.project(player_pos()).y) - PLAYER_RADIUS < GameConfig.street_width / 2.0 + 0.3


## Ist eine Spur (lat) über "distance" Meter vor diesem Fahrzeug frei von anderen Fahrzeugen?
## (Fahrräder prüfen das, bevor sie zur Straßenmitte hin ausweichen.)
func lane_free(vehicle: StreetVehicle, lat: float, distance: float) -> bool:
	for other in _vehicles:
		if other == vehicle:
			continue
		var ahead := (other.get_s() - vehicle.get_s()) * vehicle.direction
		if ahead < -other.length or ahead > distance + 25.0:
			continue
		if absf(other.get_lat() - lat) < (other.width + vehicle.width) / 2.0 + 0.3:
			return false
	return true


## Ein Passant kommt an einem Ort vorbei (für den nächsten Schritt: Besucher).
func passing(walker: Passerby, place: String) -> void:
	if place == "library":
		passing_library.emit(walker)


# --- Sichtprüfung ---

## Liegt ein Ort (x, z unter "Outside", Höhe height über dem Boden, Breite ±radius) gerade im
## Blickfeld der Kamera? Im Bild (mit Rand GameConfig.street_view_margin) und nicht verdeckt.
func is_visible_spot(spot: Vector2, height: float = 1.8, radius: float = 0.4) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var samples: Array[Vector3] = []
	for h in [0.15, height * 0.5, height]:
		samples.append(to_global(Vector3(spot.x, h, spot.y)))
	var side := camera.global_basis.x * radius
	samples.append(to_global(Vector3(spot.x, height * 0.5, spot.y)) + side)
	samples.append(to_global(Vector3(spot.x, height * 0.5, spot.y)) - side)
	for point in samples:
		if _in_view(camera, point) and _line_of_sight(camera.global_position, point):
			return true
	return false


func _in_view(camera: Camera3D, point: Vector3) -> bool:
	var local := camera.global_transform.affine_inverse() * point
	if local.z > -camera.near:
		return false
	var margin := deg_to_rad(GameConfig.street_view_margin)
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(1.0, size.y)
	var half_v := deg_to_rad(camera.fov) / 2.0
	var half_h := atan(tan(half_v) * aspect)
	var depth := -local.z
	return absf(local.y) <= tan(minf(half_v + margin, 1.5)) * depth \
		and absf(local.x) <= tan(minf(half_h + margin, 1.5)) * depth


## Freie Sicht von a nach b? Häuser (Ebene world und sight_blocker) verdecken, Glas nicht
## (Körper mit Metadaten "see_through").
func _line_of_sight(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for i in 6:
		var query := PhysicsRayQueryParameters3D.create(from, to, StreetLife.SIGHT_MASK, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider := hit.collider as Object
		if collider and collider.has_meta("see_through"):
			exclude.append(hit.rid)
			continue
		return false
	return true



# --- Passanten planen ---

func _spawn_walkers(delta: float) -> void:
	var wanted := roundi(GameConfig.passerby_count * activity())
	if _walkers.size() >= wanted or _idle_walkers.is_empty():
		_walker_timer = minf(_walker_timer, GameConfig.passerby_spawn_interval.y)
		return
	_walker_timer -= delta
	if _walker_timer > 0.0:
		return
	if _start_walker():
		_walker_timer = _rng.randf_range(GameConfig.passerby_spawn_interval.x, GameConfig.passerby_spawn_interval.y) \
			/ maxf(0.2, activity())
	else:
		_walker_timer = 0.7  # alle Orte gerade im Blick: kurz warten


## Zum Start ist die Straße schon belebt: Passanten mitten auf dem Weg – aber nur dort, wo man
## gerade nicht hinsieht.
func _fill_street() -> void:
	var wanted := roundi(GameConfig.passerby_count * activity() * 0.7)
	for i in wanted * 4:
		if _walkers.size() >= wanted or _idle_walkers.is_empty():
			break
		var plan := _plan_walker(_pick_street_end())
		if plan.is_empty():
			continue
		# Eine Stelle auf dem ersten Stück Gehweg
		var first: Dictionary = plan.actions[0]
		if first.type != "walk" or not is_centerline(first.route):
			continue
		var route: StreetRoute = first.route
		var start_s := centerline.project(plan.start).x
		var s := lerpf(start_s, float(first.to), _rng.randf_range(0.1, 0.9))
		var comfort := route.comfort_at(s)
		var spot := route.point_at(s, lerpf(comfort.x, comfort.y, plan.comfort))
		if is_visible_spot(spot) or _crowded(spot):
			continue
		plan.start = spot
		_launch(plan)


## Neuer Passant an einem Ort außer Sicht.
func _start_walker() -> bool:
	var options: Array[Dictionary] = []
	var alleys := _places.filter(func(p: Dictionary) -> bool: return p.kind == "walker" and p.place.ends_with("alley"))
	if not alleys.is_empty() and _rng.randf() < GameConfig.passerby_alley_chance:
		options.append(alleys[_rng.randi() % alleys.size()])
	options.append(_pick_street_end())
	options.append(_pick_street_end())
	for start in options:
		if start.is_empty() or is_visible_spot(start.pos) or _crowded(start.pos):
			continue
		var plan := _plan_walker(start)
		if not plan.is_empty():
			_launch(plan)
			return true
	return false


func _pick_street_end() -> Dictionary:
	var ends := _places.filter(func(p: Dictionary) -> bool: return p.kind == "walker" and p.place in ["east", "west"])
	return ends[_rng.randi() % ends.size()] if not ends.is_empty() else {}


## Steht dort schon jemand?
func _crowded(spot: Vector2) -> bool:
	for walker in _walkers:
		if walker.pos.distance_to(spot) < 1.2:
			return true
	return player_pos().distance_to(spot) < 1.5


func _launch(plan: Dictionary) -> void:
	var walker: Passerby = _idle_walkers.pop_at(_rng.randi() % _idle_walkers.size())
	walker.speed_pref = plan.speed
	walker.comfort_pref = plan.comfort
	walker.side = plan.side
	_walkers.append(walker)
	var actions: Array[Dictionary] = []
	actions.assign(plan.actions)
	walker.begin(plan.start, actions, plan.face)
	walker.set_shadows(0)
	appeared.emit(walker, walker.pos)


## Plant den ganzen Weg eines Passanten vom Ort "start" aus. Ergebnis: { "start", "face",
## "side", "speed", "comfort", "actions" } oder leer.
func _plan_walker(start: Dictionary) -> Dictionary:
	if start.is_empty():
		return {}
	var length := centerline.length()
	var from_alley: bool = start.place.ends_with("alley")
	var start_side: int = start.side
	var actions: Array[Dictionary] = []
	var s0 := 0.0
	var dir := 1
	var alley_points := PackedVector2Array()
	# Ziel: das andere Straßenende oder (manchmal) eine Gasse
	var end_place := ""
	var alleys := _places.filter(func(p: Dictionary) -> bool:
		return p.kind == "walker" and p.place.ends_with("alley") and p.place != start.place)
	if not alleys.is_empty() and _rng.randf() < GameConfig.passerby_alley_chance:
		end_place = alleys[_rng.randi() % alleys.size()].place
	if from_alley:
		alley_points = _alley_points(start.place)
		s0 = centerline.project(alley_points[alley_points.size() - 1]).x
	else:
		s0 = 0.0 if start.place == "east" else length
	# Richtung: zum Ziel hin
	var end_s := 0.0
	var end_side := start_side
	if end_place != "":
		var points := _alley_points(end_place)
		end_s = centerline.project(points[points.size() - 1]).x
		end_side = 1 if end_place == "alley" else -1
	else:
		if from_alley:
			end_s = -0.5 if _rng.randf() < 0.5 else length + 0.5
		else:
			end_s = length + 0.5 if s0 < length / 2.0 else -0.5
		end_side = start_side
		if _rng.randf() < GameConfig.passerby_cross_chance:
			end_side = -start_side
	if absf(end_s - s0) < 3.0:
		return {}
	dir = 1 if end_s > s0 else -1
	# Überqueren nötig? Irgendwo im sichtbaren Mittelstück zwischen Start und Ziel
	var cross_s := NAN
	if end_side != start_side:
		var a := maxf(_crossing.x, minf(s0, end_s) + 2.0)
		var b := minf(_crossing.y, maxf(s0, end_s) - 2.0)
		if b - a > 1.0:
			cross_s = _rng.randf_range(a, b)
		elif end_place == "":
			end_side = start_side
		else:
			return {}
	# Schaufenster auf dem Weg (auf der Seite, auf der man dort gerade geht)
	var window := {}
	if _rng.randf() < GameConfig.passerby_window_chance:
		var choices: Array[Dictionary] = []
		for spot in _windows:
			var along: float = (float(spot.s) - s0) * dir
			var until: float = (end_s - s0) * dir
			if along < 2.0 or along > until - 2.0:
				continue
			var side_there := start_side
			if not is_nan(cross_s) and (float(spot.s) - cross_s) * dir > 0.0:
				side_there = end_side
			if side_there == int(spot.side):
				choices.append(spot)
		if not choices.is_empty():
			window = choices[_rng.randi() % choices.size()]

	var comfort := _rng.randf_range(0.2, 0.8)
	var speed := _rng.randf_range(GameConfig.passerby_speed_range.x, GameConfig.passerby_speed_range.y)
	var side := start_side
	# 1. aus der Gasse auf den Gehweg
	var start_pos: Vector2 = start.pos
	var face := Vector2.ZERO
	if from_alley:
		var points := alley_points.duplicate()
		points[0] = start_pos
		points.append(_lane_point(side, s0 + dir * 1.5, comfort))
		var route := StreetPaths.alley_route(points, _alley_half(start.place))
		actions.append({"type": "walk", "route": route, "to": route.length(), "alley": "out"})
		face = (points[1] - points[0]).normalized()
		s0 += dir * 1.5
	else:
		start_pos = _lane_point(side, s0, comfort)
		face = centerline.direction_at(s0) * float(dir)
	# 2. Ereignisse unterwegs, der Reihe nach
	var events: Array[Dictionary] = []
	if not is_nan(cross_s):
		events.append({"s": cross_s, "type": "cross"})
	if not window.is_empty():
		events.append({"s": float(window.s), "type": "window", "spot": window})
	if (_library_s - s0) * dir > 0.0 and (end_s - _library_s) * dir > 0.0:
		events.append({"s": _library_s, "type": "library"})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.s - s0) * dir < (b.s - s0) * dir)
	# Nie rückwärts: jedes Stück Gehweg endet frühestens dort, wo das vorige aufgehört hat
	var cursor := s0
	for event in events:
		match String(event.type):
			"cross":
				cursor = _ahead(event.s, cursor, dir)
				actions.append({"type": "walk", "route": sidewalks[side], "to": cursor})
				side = -side
				actions.append({"type": "cross", "to_side": side, "look_time": _rng.randf_range(1.0, 2.2)})
			"window":
				if side != int(event.spot.side):
					continue
				var spot: Dictionary = event.spot
				var at := _free_window_spot(spot, side, cursor, dir, comfort)
				if at == Vector2.INF:
					continue
				var lane_before := _ahead(centerline.project(at).x - dir * 1.2, cursor, dir)
				actions.append({"type": "walk", "route": sidewalks[side], "to": lane_before})
				cursor = lane_before + dir * 2.4
				var there := StreetRoute.from_points(PackedVector2Array([_lane_point(side, lane_before, comfort), at]), 0.35)
				# Der Weg zum Fenster wird erst beim Losgehen festgelegt (Kartons könnten davor stehen)
				actions.append({"type": "walk", "route": there, "to": there.length(), "visit": true, "spot": at, "face": spot.face})
				actions.append({"type": "stand", "face": spot.face, "anim": &"browse", "visit": true,
					"time": _rng.randf_range(GameConfig.passerby_window_time.x, GameConfig.passerby_window_time.y)})
				var back := StreetRoute.from_points(PackedVector2Array([at, _lane_point(side, lane_before + dir * 2.4, comfort)]), 0.35)
				actions.append({"type": "walk", "route": back, "to": back.length(), "from_here": true})
			"library":
				if side == 1 and (event.s - cursor) * dir > 0.0:
					cursor = event.s
					actions.append({"type": "walk", "route": sidewalks[side], "to": cursor, "passing": "library"})
	# 3. bis zum Ziel
	if end_place != "":
		var points := _alley_points(end_place)
		points.reverse()
		var join := _lane_point(side, end_s - dir * 1.5, comfort)
		actions.append({"type": "walk", "route": sidewalks[side], "to": end_s - dir * 1.5})
		var full := PackedVector2Array([join])
		full.append_array(points)
		var route := StreetPaths.alley_route(full, _alley_half(end_place))
		actions.append({"type": "walk", "route": route, "to": route.length(), "alley": "in"})
		var last := full[full.size() - 1]
		var before := full[full.size() - 2]
		actions.append({"type": "leave", "gate": true, "face": (last - before).normalized()})
	else:
		actions.append({"type": "walk", "route": sidewalks[side], "to": end_s})
		actions.append({"type": "leave", "gate": false})
	return {"start": start_pos, "face": face, "side": start_side, "speed": speed, "comfort": comfort, "actions": actions}


## Nie rückwärts: "to" frühestens bei "cursor" (in Laufrichtung dir).
func _ahead(to: float, cursor: float, dir: int) -> float:
	return to if (to - cursor) * dir >= 0.0 else cursor


## Die Spielfigur versperrt den Weg schon lange: Der Passant dreht um. Auf dem Gehweg geht er
## zum anderen Straßenende, in einer Gasse zurück zum Tor (wenn er herauskam) bzw. zurück auf
## die Straße und dort zu einem Ende (wenn er hineinwollte). Vor Schaufenstern wartet er weiter.
func turn_around(walker: Passerby) -> void:
	var action := walker.get_action()
	if action.get("type") != "walk":
		return
	var route: StreetRoute = action.route
	var actions: Array[Dictionary] = []
	if is_centerline(route):
		var to_end := -0.5 if walker.get_direction() > 0 else centerline.length() + 0.5
		actions.append({"type": "walk", "route": sidewalks[walker.side], "to": to_end})
		actions.append({"type": "leave", "gate": false})
	elif action.get("alley") == "out":
		actions.append({"type": "walk", "route": route, "to": 0.0})
		actions.append({"type": "leave", "gate": true, "face": (route.points[0] - route.points[1]).normalized()})
	elif action.get("visit", false):
		walker.skip_visit()
		return
	elif not is_centerline(route) and action.get("alley", "") == "":
		walker.skip_action()  # kurzer Weg (z. B. vom Schaufenster zurück): einfach weiter
		return
	elif action.get("alley") == "in":
		var to_end := -0.5 if _rng.randf() < 0.5 else centerline.length() + 0.5
		actions.append({"type": "walk", "route": route, "to": 0.0})
		actions.append({"type": "walk", "route": sidewalks[walker.side], "to": to_end})
		actions.append({"type": "leave", "gate": false})
	else:
		return
	walker.replace_actions(actions)


## Punkt auf einem Gehweg (bequeme Lage pref zwischen innen und außen).
func _lane_point(side: int, s: float, pref: float) -> Vector2:
	var route: StreetRoute = sidewalks[side]
	var comfort := route.comfort_at(s)
	return route.point_at(s, lerpf(comfort.x, comfort.y, pref))


## Weg in einer Gasse: vom Tor (Ort zum Erscheinen) bis zur Einmündung.
func _alley_points(place: String) -> PackedVector2Array:
	var points := StreetPaths.library_alley_points() if place == "alley" else StreetPaths.opposite_alley_points()
	for entry in _places:
		if entry.place == place and entry.kind == "walker":
			points[0] = entry.pos
	return points


func _alley_half(place: String) -> float:
	return StreetPaths.library_alley_half_width() if place == "alley" else StreetPaths.opposite_alley_half_width()


# --- Lieferwagen ---

## Gibt es einen Lieferwagen? (Sonst liefert der DeliveryManager wie früher direkt.)
func has_van() -> bool:
	return _van != null or not _started  # vor dem Start: Bestellungen warten auf den Wagen


## Der Lieferwagen soll losfahren (vom DeliveryManager). false = er ist noch unterwegs.
func send_van(manager: DeliveryManager) -> bool:
	if _van == null or _van.active or _van_manager != null:
		return false
	_van_manager = manager
	return true


## Wo gerade jemand steht (Spielfigur, Passanten) – dort stellt der Wagen keinen Karton ab.
func blocking_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if _player:
		points.append(_player.global_position)
	for walker in _walkers:
		points.append(walker.global_position)
	return points


## Startet den Lieferwagen am Anfang der Straße, sobald es dort niemand sieht und vor ihm
## niemand fährt.
func _spawn_van() -> void:
	if _van_manager == null or _van.active:
		return
	var start := road_route.point_at(0.0, _van.lane())
	if not direction_free(1, GameConfig.delivery_van_speed) or is_visible_spot(start, 2.2, 2.5):
		return
	_van.start_trip(road_route, _van_stop_s(), _van_stop_lat(), _van_manager)
	_van_manager = null
	_van.set_shadows(false)
	_vehicles.append(_van)
	appeared.emit(_van, _van.pos)


## Hier hält der Wagen: Seine Tür steht vor der Mitte der Kartonreihe (Lieferort).
func _van_stop_s() -> float:
	var deliveries := get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager
	var target := Vector2(0.0, StreetLayout.road_center_z())
	if deliveries:
		var along := deliveries.stack_direction.normalized() * GameConfig.delivery_stacks_per_row * DeliveryManager.STACK_SPACING / 2.0
		target = _to_local2(deliveries.global_position + deliveries.global_basis * along)
	return centerline.project(target).x - _van.door_point.z


## Dicht am Bordstein der Bücherei-Seite.
func _van_stop_lat() -> float:
	return GameConfig.street_width / 2.0 - 0.22 - _van.width / 2.0


# --- Fahrräder und Autos ---

func _spawn_vehicles(delta: float) -> void:
	if _van:
		_spawn_van()
	var calm := maxf(0.2, activity())
	_bike_timer -= delta
	if _bike_timer <= 0.0:
		if _idle_bikes.is_empty() or activity() <= 0.0 or not _start_vehicle(_idle_bikes, "bike",
				_rng.randf_range(GameConfig.bike_speed_range.x, GameConfig.bike_speed_range.y)):
			_bike_timer = 1.0
		else:
			_bike_timer = _rng.randf_range(GameConfig.bike_interval.x, GameConfig.bike_interval.y) / calm
	_car_timer -= delta
	if _car_timer <= 0.0:
		if _idle_cars.is_empty() or activity() <= 0.0 or not _start_vehicle(_idle_cars, "car", GameConfig.car_speed):
			_car_timer = 1.0
		else:
			_car_timer = _rng.randf_range(GameConfig.car_interval.x, GameConfig.car_interval.y) / calm


## Ein Fahrzeug an einem Straßenende losschicken – nur, wenn der Ort nicht im Blick ist und es
## dort niemanden einholen würde (in jeder Richtung höchstens ein langsameres Fahrzeug vorn).
func _start_vehicle(pool: Array[StreetVehicle], kind: String, cruise: float) -> bool:
	var starts := _places.filter(func(p: Dictionary) -> bool: return p.kind == kind and p.place in ["east", "west"])
	starts.shuffle()
	for start in starts:
		var dir := 1 if start.place == "east" else -1
		if not direction_free(dir, cruise) or is_visible_spot(start.pos, 1.8, 2.5):
			continue
		var vehicle: StreetVehicle = pool.pop_at(_rng.randi() % pool.size())
		var color: Color = GameConfig.car_colors[_rng.randi() % GameConfig.car_colors.size()] \
			if not GameConfig.car_colors.is_empty() else Color.WHITE
		if kind == "bike":
			color = Color.from_hsv(_rng.randf(), _rng.randf_range(0.3, 0.55), _rng.randf_range(0.45, 0.75))
		vehicle.randomize_look(_rng, color)
		vehicle.begin(road_route, dir, cruise)
		vehicle.set_shadows(false)
		_vehicles.append(vehicle)
		appeared.emit(vehicle, vehicle.pos)
		return true
	return false


## Darf in dieser Richtung ein neues Fahrzeug (mit diesem Tempo) losfahren? Nicht, solange
## vorn eins am Anfang der Strecke steht oder ein langsameres unterwegs ist (das neue würde es
## einholen) – so muss niemand überholen.
func direction_free(dir: int, cruise: float) -> bool:
	var start := 0.0 if dir > 0 else centerline.length()
	for other in _vehicles:
		if other.direction != dir:
			continue
		if absf(other.get_s() - start) < 30.0 or other.cruise_speed < cruise - 0.01 or other.has_method("is_delivering"):
			return false
	return true


# --- Detailstufe und Schatten ---

func _update_detail() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var preset := Settings.get_graphics_preset()
	var shadow_distance := float(preset.get("street_shadow_distance", 15.0))
	var detail_distance := float(preset.get("street_shadow_detail", 0.0))
	for walker in _walkers:
		var distance := camera.global_position.distance_to(walker.global_position)
		walker.set_shadows(0 if distance >= shadow_distance else (2 if distance < detail_distance else 1))
	for vehicle in _vehicles:
		var distance := camera.global_position.distance_to(vehicle.global_position)
		vehicle.set_shadows(distance < shadow_distance)
