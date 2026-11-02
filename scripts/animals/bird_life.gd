class_name BirdLife
extends Node3D
## Vögel auf der Straße (seit Etappe 6g). Entsteht beim Start des Straßenlebens als Kind von StreetLife
## ("Outside/StreetLife/Birds") und wird von StreetLife.step mitbewegt (auch beim Vorspulen im Prüfwerkzeug).
##
## Kleine Schwärme (GameConfig.bird_flock_size) einer Art (GameConfig.bird_species) fliegen hinter einem Dach
## hervor – nie sichtbar aus dem Nichts: Der Weg beginnt hinter einem Haus (von der Straße verdeckt), führt
## über den First und zu einem Platz in der Nähe der Kamera:
## - Dachrinnen, Firste, Gesimse, Schildkästen, Fensterbänke: ausgemessen in data/animals/spots.json
##   (Werkzeug scenes/tools/bake_animal_spots.tscn),
## - Querarme der Straßenlaternen (zwei Plätze je Seite),
## - das Vogelhäuschen an einer Hauswand gegenüber der Bücherei (Futterbrett, Rand, Sitzstange, First),
## - der Gehweg: picken und hüpfen.
## Nach einer Weile fliegen sie zu einem anderen Platz oder wieder hinter ein Dach (erst außer Sicht
## verschwinden sie). Kommt jemand Vögeln am Boden (oder auf niedrigen Fensterbänken) zu nahe – Spielfigur,
## Passant, Katze, Fahrzeug –, flattern sie mit Geräusch auf und landen woanders. Zwitschern hängt am Vogel.

const SPOTS_FILE := "res://data/animals/spots.json"
## Querarme der Straßenlaterne (Modell aus build_storybook_lamps.py): Oberkante je Abstand vom Mast
const LAMP_ARM_SPOTS := [[0.27, 2.784], [0.4, 2.779]]
## Ebenen, an denen Flugwege nicht vorbeikommen (Häuser: world und sight_blocker)
const HOUSE_MASK := 1 | 128
## Niedrige Plätze (Meter über dem Gehweg): Vögel dort fliegen auch auf, wenn jemand vorbeigeht
const LOW_PERCH := 1.5
## Abstand zwischen zwei Vögeln am Boden (m)
const GROUND_GAP := 0.17

var street: StreetLife
## Zähler für das Prüfwerkzeug: Erscheinen bzw. Verschwinden im Blickfeld (muss 0 bleiben)
var visible_spawns := 0
var visible_exits := 0
var flights := 0

var _outside: Node3D
var _rng := RandomNumberGenerator.new()
var _pool: Array[StreetBird] = []
var _birds: Array[StreetBird] = []
## Plätze: { pos (Welt), face, out (waagerecht, Welt), kind, house, taken }
var _perches: Array[Dictionary] = []
var _lamps: Array[Dictionary] = []
var _feeder: Array[Dictionary] = []
## Häuser: { front (Welt, Fußpunkt), out, along, width, depth, eaves, top (Welt-y) }
var _houses: Array[Dictionary] = []
## Schwärme: { birds, area, timer, landed }
var _flocks: Array[Dictionary] = []
var _spawn := 0.0
var _scan := 0.0
var _chirp_gap := 0.0
var _birdhouse: Node3D


func setup(life: StreetLife) -> void:
	street = life
	_outside = life.get_parent() as Node3D
	_rng.randomize()
	_load_spots()
	_collect_lamps()
	_build_pool()
	_spawn = _rng.randf_range(1.5, 5.0)


func seed_random(value: int) -> void:
	_rng.seed = value


func _exit_tree() -> void:
	# gemeinsame Material-Kopien der Tiere freigeben
	StreetAnimal._materials.clear()


func get_birds() -> Array[StreetBird]:
	return _birds


# --- Plätze ---

func _load_spots() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPOTS_FILE)) if FileAccess.file_exists(SPOTS_FILE) else null
	if not data is Dictionary:
		push_warning("BirdLife: %s fehlt – scenes/tools/bake_animal_spots.tscn starten" % SPOTS_FILE)
		return
	for h: Dictionary in data.get("houses", []):
		var out := Vector3(h.out[0], 0.0, h.out[1]).normalized()
		var front := _outside.to_global(Vector3(h.front[0], h.front[1], h.front[2]))
		_houses.append({"front": front, "out": out, "along": Vector3.UP.cross(out).normalized(), "width": float(h.width),
			"depth": float(h.depth), "eaves": front.y + float(h.eaves), "top": front.y + float(h.top)})
	for p: Dictionary in data.get("perches", []):
		var out := Vector3(p.out[0], 0.0, p.out[1]).normalized()
		_perches.append({"pos": _outside.to_global(Vector3(p.pos[0], p.pos[1], p.pos[2])), "face": out, "out": out,
			"kind": String(p.kind), "house": String(p.house), "taken": null})
	var box: Dictionary = data.get("birdhouse", {})
	if not box.is_empty():
		_place_birdhouse(_outside.to_global(Vector3(box.pos[0], box.pos[1], box.pos[2])), Vector3(box.out[0], 0.0, box.out[1]).normalized())


## Vogelhäuschen an die ausgemessene Wandstelle hängen; seine Plätze (Perch_<n>) übernehmen.
func _place_birdhouse(wall: Vector3, out: Vector3) -> void:
	var scene := load(GameConfig.birdhouse_scene) as PackedScene
	if scene == null:
		return
	_birdhouse = scene.instantiate() as Node3D
	_birdhouse.name = "Birdhouse"
	add_child(_birdhouse)
	var along := Vector3.UP.cross(out).normalized()
	_birdhouse.global_transform = Transform3D(Basis(along, Vector3.UP, out), wall)
	for node: Node3D in _birdhouse.find_children("Perch_*", "Node3D", true, false):
		var extras: Dictionary = node.get_meta("extras", {})
		var kind := String(extras.get("kind", "rim"))
		# Blickrichtung: in = zur Mitte des Häuschens, out = nach vorn, along = längs (zufällig links/rechts)
		var face := out
		match String(extras.get("face", "out")):
			"in":
				face = -along if node.position.x > 0.0 else along
			"along":
				face = along if _rng.randf() < 0.5 else -along
		_feeder.append({"pos": node.global_position, "face": face, "out": out, "kind": "feed" if kind == "feed" else "birdhouse",
			"house": "birdhouse", "taken": null})


## Plätze auf den Querarmen der Straßenlaternen (Outside/Street/Lamps).
func _collect_lamps() -> void:
	var lamps := _outside.get_node_or_null("Street/Lamps")
	if lamps == null:
		return
	var road := _outside.to_global(Vector3(0.0, 0.0, StreetLayout.road_center_z()))
	for lamp: Node3D in lamps.get_children():
		var out := Vector3(0.0, 0.0, signf(road.z - lamp.global_position.z))
		for sx in [-1.0, 1.0]:
			for arm: Array in LAMP_ARM_SPOTS:
				var face := out if _rng.randf() < 0.5 else -out
				_lamps.append({"pos": lamp.to_global(Vector3(sx * float(arm[0]), float(arm[1]), 0.0)), "face": face, "out": out,
					"kind": "lamp", "house": "lamp_%s_%d" % [lamp.name, int(sx)], "taken": null})


func _build_pool() -> void:
	var scene := load(GameConfig.bird_scene) as PackedScene
	if scene == null:
		return
	for i in GameConfig.bird_count + 2:
		var bird := scene.instantiate() as StreetBird
		bird.name = "Bird%d" % (i + 1)
		bird.life = self
		add_child(bird)
		bird.path_done.connect(_on_path_done)
		_pool.append(bird)


# --- Ablauf ---

func step(delta: float) -> void:
	for bird in _birds:
		bird.step(delta)
	_chirp_gap -= delta
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = _rng.randf_range(GameConfig.bird_spawn_interval.x, GameConfig.bird_spawn_interval.y)
		_spawn_flock()
	for flock in _flocks.duplicate():
		if not flock.landed:
			continue
		flock.timer -= delta
		if flock.timer <= 0.0:
			_move_on(flock)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.15
		_check_threats()


func _spawn_flock() -> void:
	var size := _rng.randi_range(GameConfig.bird_flock_size.x, GameConfig.bird_flock_size.y)
	size = mini(size, mini(_pool.size(), GameConfig.bird_count - _birds.size()))
	if size <= 0 or _houses.is_empty():
		return
	var spots := _pick_area(size, _camera_pos(), GameConfig.bird_near_distance, true)
	if spots.is_empty():
		return
	var entry := _hidden_entry(spots[0].pos)
	if entry.is_empty():
		return
	var flock := {"birds": [], "timer": 0.0, "landed": false}
	var species := _rng.randi() % maxi(1, GameConfig.bird_species.size())
	for i in spots.size():
		var bird: StreetBird = _pool.pop_back()
		_birds.append(bird)
		_dress(bird, species)
		bird.flock = flock
		flock.birds.append(bird)
		var spot: Dictionary = spots[i]
		spot.taken = bird
		bird.spot = spot
		bird.leaving = false
		# jeder Vogel etwas versetzt hinter dem Dach hervor
		var offset: Vector3 = entry.along * _rng.randf_range(-0.8, 0.8) + Vector3.UP * _rng.randf_range(-0.3, 0.3)
		var path := _entry_path(entry, offset, spot)
		bird.fly_path(path, GameConfig.bird_speed * _rng.randf_range(0.92, 1.08), i * _rng.randf_range(0.15, 0.45))
		flights += 1
		if is_visible_point(path[0]):
			visible_spawns += 1
	_flocks.append(flock)


func _dress(bird: StreetBird, species: int) -> void:
	bird.species = species
	if GameConfig.bird_species.is_empty():
		return
	var look: Dictionary = GameConfig.bird_species[species]
	bird.apply_look("bird_%d" % species, {"Vogel Gefieder": look.plumage, "Vogel Flügel": look.wing,
		"Vogel Brust": look.breast, "Vogel Schnabel": look.beak})


func _on_path_done(bird: StreetBird) -> void:
	if bird.leaving:
		# erst verschwinden, wenn niemand hinschaut – sonst noch ein Stück weiter weg fliegen
		var end := bird.global_position
		if is_visible_point(end) and bird.global_position.distance_to(_camera_pos()) < 70.0:
			var away := end - _camera_pos()
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			bird.fly_path(PackedVector3Array([end, end + away * 6.0 + Vector3.UP * 1.5]), GameConfig.bird_speed)
			return
		if is_visible_point(end):
			visible_exits += 1
		_release(bird)
		return
	bird.settle(bird.spot)
	var flock: Dictionary = bird.flock
	if flock.is_empty() or flock.landed:
		return
	for other: StreetBird in flock.birds:
		if other.state != StreetBird.State.PERCH:
			return
	flock.landed = true
	flock.timer = _rng.randf_range(GameConfig.bird_stay_time.x, GameConfig.bird_stay_time.y)


func _release(bird: StreetBird) -> void:
	if bird.spot.get("taken") == bird:
		bird.spot.taken = null
	var flock: Dictionary = bird.flock
	if not flock.is_empty():
		flock.birds.erase(bird)
		if flock.birds.is_empty():
			_flocks.erase(flock)
	bird.hide_bird()
	_birds.erase(bird)
	_pool.append(bird)


## Nach dem Sitzen: zu einem anderen Platz in der Nähe oder hinter ein Dach.
func _move_on(flock: Dictionary, flee: bool = false) -> void:
	var birds: Array = flock.birds.duplicate()
	if birds.is_empty():
		_flocks.erase(flock)
		return
	var first: StreetBird = birds[0]
	var stay := flee or _rng.randf() < GameConfig.bird_stay_nearby_share
	var spots: Array[Dictionary] = []
	if stay:
		spots = _pick_area(birds.size(), first.global_position, 16.0, not flee, flee)
	flock.landed = false
	var speed := GameConfig.bird_flee_speed if flee else GameConfig.bird_speed
	if flee or _camera_pos().distance_to(first.global_position) < 14.0:
		Audio.play_on(first, "ambience/bird_flap", GameConfig.bird_flap_volume_db + (4.0 if flee else 0.0), Audio.vary(0.08),
			20.0, Vector3(0.0, 0.05, 0.0))
	for i in birds.size():
		var bird: StreetBird = birds[i]
		var from: Dictionary = bird.spot
		if from.get("taken") == bird:
			from.taken = null
		var delay := (i * _rng.randf_range(0.05, 0.15)) if flee else (i * _rng.randf_range(0.3, 0.9))
		if i < spots.size():
			var spot: Dictionary = spots[i]
			spot.taken = bird
			bird.spot = spot
			bird.fly_path(_hop_path(bird.global_position, from, spot), speed * _rng.randf_range(0.92, 1.08), delay)
		else:
			var exit := _hidden_entry(bird.global_position)
			if exit.is_empty():
				# kein verdeckter Platz zum Wegfliegen: einfach sitzen bleiben
				bird.spot = from
				from.taken = bird
				bird.settle(from)
				continue
			bird.leaving = true
			var offset: Vector3 = exit.along * _rng.randf_range(-0.8, 0.8)
			var path := _entry_path(exit, offset, from)
			path.reverse()
			path[0] = bird.global_position
			bird.fly_path(path, speed * _rng.randf_range(0.92, 1.08), delay)
		flights += 1
	if flock.birds.is_empty():
		_flocks.erase(flock)


## Kommt jemand Vögeln am Boden (oder auf niedrigen Plätzen) zu nahe, fliegt der ganze Schwarm auf.
func _check_threats() -> void:
	var threats := _threats()
	for flock in _flocks.duplicate():
		for bird: StreetBird in flock.birds:
			if bird.state != StreetBird.State.PERCH:
				continue
			var low := bird.is_on_ground() or bird.global_position.y - _outside.global_position.y < LOW_PERCH
			if not low:
				continue
			var p := bird.global_position
			var scared := false
			for t: Array in threats:
				var q: Vector3 = t[0]
				var r: float = t[1]
				if not bird.is_on_ground():
					r = minf(r, 1.2)
				if Vector2(p.x - q.x, p.z - q.z).length() < r:
					scared = true
					break
			if scared:
				_move_on(flock, true)
				break


## [Ort, Fluchtabstand] aller, vor denen Vögel auffliegen.
func _threats() -> Array:
	var result := []
	var player := street.get_player()
	if player:
		result.append([player.global_position, GameConfig.bird_flee_radius])
	for walker in street.get_walkers():
		result.append([walker.global_position, GameConfig.bird_flee_radius])
	for vehicle in street.get_vehicles():
		result.append([vehicle.global_position, GameConfig.bird_vehicle_flee_radius + vehicle.length * 0.3])
	if street.cats:
		for cat in street.cats.get_cats():
			result.append([cat.global_position, GameConfig.bird_flee_radius + 0.5])
	return result


## Zwitschern (räumlich am Vogel), nicht zu viele gleichzeitig.
func chirp(bird: StreetBird) -> void:
	if _chirp_gap > 0.0 or bird.global_position.distance_to(_camera_pos()) > GameConfig.bird_chirp_distance:
		return
	_chirp_gap = 0.9
	Audio.play_on(bird, "ambience/bird", GameConfig.bird_chirp_volume_db, Audio.vary(0.1),
		GameConfig.bird_chirp_distance, Vector3(0.0, 0.07, 0.0))


## Darf ein Vogel am Boden dorthin hüpfen (kein anderer Vogel zu nah)?
func ground_free(target: Vector3, bird: StreetBird) -> bool:
	for other in _birds:
		if other != bird and other.is_on_ground() and other.global_position.distance_to(target) < GROUND_GAP:
			return false
	return true


# --- Plätze wählen ---

## Plätze für einen Schwarm von size Vögeln in der Nähe von near (höchstens radius Meter): Gehweg,
## Vogelhäuschen, Laternenarme oder Plätze an den Häusern. high_only = nur oberhalb der Köpfe (Flucht).
func _pick_area(size: int, near: Vector3, radius: float, allow_ground: bool = true, high_only: bool = false) -> Array[Dictionary]:
	var roll := _rng.randf()
	var result: Array[Dictionary] = []
	if allow_ground and not high_only and roll < GameConfig.bird_ground_share:
		result = _ground_spots(size, near, radius)
	elif roll < GameConfig.bird_ground_share + GameConfig.bird_birdhouse_share:
		result = _group_from(_feeder, size, near, radius, 0.5)
	elif roll < GameConfig.bird_ground_share + GameConfig.bird_birdhouse_share + GameConfig.bird_lamp_share:
		result = _group_from(_lamps, size, near, radius, 0.6)
	if result.is_empty():
		result = _group_from(_perches, size, near, radius, 1.3, high_only)
	return result


## Ein freier Platz (bevorzugt sichtbar) und freie Nachbarn am selben Haus bzw. derselben Laterne.
func _group_from(list: Array[Dictionary], size: int, near: Vector3, radius: float, spread: float, high_only: bool = false) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var ground := _outside.global_position.y
	var cats: Array[Vector3] = []
	if street.cats:
		for cat in street.cats.get_cats():
			cats.append(cat.global_position)
	for spot in list:
		if spot.taken != null or spot.pos.distance_to(near) > radius:
			continue
		if high_only and spot.pos.y - ground < 2.2:
			continue
		# nie neben einer Katze landen
		var near_cat := false
		for c in cats:
			if c.distance_to(spot.pos) < 1.8:
				near_cat = true
		if near_cat:
			continue
		candidates.append(spot)
	if candidates.is_empty():
		return []
	var first: Dictionary = {}
	for i in 6:
		var pick: Dictionary = candidates[_rng.randi() % candidates.size()]
		first = pick
		if is_visible_point(pick.pos + Vector3.UP * 0.05):
			break
	var result: Array[Dictionary] = [first]
	for spot in candidates:
		if result.size() >= size:
			break
		if spot != first and spot.house == first.house and spot.kind == first.kind and spot.pos.distance_to(first.pos) < spread:
			result.append(spot)
	# nicht genug Nachbarn: weitere Plätze am selben Haus
	for spot in candidates:
		if result.size() >= size:
			break
		if not spot in result and spot.house == first.house and spot.pos.distance_to(first.pos) < 4.0:
			result.append(spot)
	return result


## Plätze auf dem Gehweg (picken): ein Fleck auf einem der beiden Gehwege nahe der Kamera, weit genug
## von Leuten, Laternen, Bänken und Treppe; die Vögel verteilen sich darum herum.
func _ground_spots(size: int, near: Vector3, radius: float) -> Array[Dictionary]:
	var local := _outside.to_local(near)
	var s0 := street.centerline.project(Vector2(local.x, local.z)).x
	var threats := _threats()
	for attempt in 12:
		var side := 1 if _rng.randf() < 0.5 else -1
		var route: StreetRoute = street.sidewalks[side]
		var s := s0 + _rng.randf_range(-radius * 0.5, radius * 0.5)
		var comfort := route.comfort_at(s)
		if comfort.y - comfort.x < 1.0:
			continue
		var lat := _rng.randf_range(comfort.x + 0.5, comfort.y - 0.5)
		var c2 := route.point_at(s, lat)
		var center := _outside.to_global(Vector3(c2.x, 0.0, c2.y))
		if center.distance_to(near) > radius or not street.clear_of_static(c2, 0.9):
			continue
		var far := true
		for t: Array in threats:
			var q: Vector3 = t[0]
			if Vector2(center.x - q.x, center.z - q.z).length() < float(t[1]) * 1.8:
				far = false
				break
		if not far:
			continue
		var result: Array[Dictionary] = []
		for i in size:
			var p := center
			for k in 8:
				var a := _rng.randf() * TAU
				var r := 0.0 if i == 0 else _rng.randf_range(0.18, 0.45)
				p = center + Vector3(cos(a) * r, 0.0, sin(a) * r)
				var ok := true
				for other in result:
					if other.pos.distance_to(p) < GROUND_GAP * 1.4:
						ok = false
				if ok:
					break
			var b := _rng.randf() * TAU
			result.append({"pos": p, "face": Vector3(sin(b), 0.0, cos(b)), "out": Vector3(sin(b), 0.0, cos(b)), "kind": "ground",
				"house": "ground", "center": center, "taken": null})
		return result
	return []


# --- Flugwege ---

## Verdeckter Ort hinter einem Haus nahe target (von dort fliegen Vögel über den First herein bzw.
## dorthin hinaus). Liefert { pos, house, along } oder leer.
func _hidden_entry(target: Vector3) -> Dictionary:
	var houses := _houses.duplicate()
	houses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.front.distance_squared_to(target) < b.front.distance_squared_to(target))
	for i in mini(8, houses.size()):
		var h: Dictionary = houses[i]
		var lateral: float = _rng.randf_range(-h.width / 3.0, h.width / 3.0)
		var pos: Vector3 = h.front - h.out * (h.depth + 1.8) + h.along * lateral
		pos.y = h.front.y + (h.eaves - h.front.y) * 0.7
		if not is_visible_point(pos):
			return {"pos": pos, "house": h, "along": h.along, "lateral": lateral}
	return {}


## Weg von einem verdeckten Ort hinter einem Haus über den First zum Platz.
func _entry_path(entry: Dictionary, offset: Vector3, spot: Dictionary) -> PackedVector3Array:
	var h: Dictionary = entry.house
	var lateral: Vector3 = h.along * float(entry.lateral)
	var ridge: Vector3 = h.front - h.out * (h.depth * 0.45) + lateral
	ridge.y = h.top + 1.0
	var over: Vector3 = h.front + h.out * 0.9 + lateral
	over.y = maxf(h.top + 0.3, spot.pos.y + 1.2)
	var points: Array[Vector3] = [entry.pos + offset, ridge + offset * 0.6, over + offset * 0.4]
	points.append_array(_approach(over, spot))
	return _smooth(_clear_route(points))


## Weg von einem Platz zum nächsten.
func _hop_path(from_pos: Vector3, from: Dictionary, spot: Dictionary) -> PackedVector3Array:
	var out: Vector3 = from.get("out", Vector3.UP)
	var lift := from_pos + Vector3.UP * 0.9 + (out * 0.9 if from.get("kind", "") != "ground" else Vector3.ZERO)
	var points: Array[Vector3] = [from_pos, lift]
	var approach := _approach(lift, spot)
	var mid := (lift + approach[0]) / 2.0
	if lift.distance_to(approach[0]) > 6.0:
		mid.y = maxf(mid.y, maxf(lift.y, approach[0].y) + 1.0)
		points.append(mid)
	points.append_array(approach)
	return _smooth(_clear_route(points))


## Die letzten beiden Punkte vor der Landung: schräg von vorn oben auf den Platz.
func _approach(from: Vector3, spot: Dictionary) -> Array[Vector3]:
	var target: Vector3 = spot.pos
	var dir: Vector3
	if spot.kind == "ground":
		dir = from - target
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	else:
		dir = spot.out
	return [target + dir * 1.5 + Vector3.UP * 1.0, target + dir * 0.35 + Vector3.UP * 0.22, target]


## Teilstücke, die durch ein Haus führen würden: über die Dächer heben.
func _clear_route(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = [points[0]]
	for i in range(1, points.size()):
		var a := result[-1]
		var b := points[i]
		if i < points.size() - 2 and not _segment_clear(a, b):
			var high := maxf(_roofs_near((a + b) / 2.0), maxf(a.y, b.y)) + 1.5
			var m1 := a.lerp(b, 0.25)
			var m2 := a.lerp(b, 0.75)
			m1.y = high
			m2.y = high
			result.append(Vector3(a.x, high, a.z))
			result.append(m1)
			result.append(m2)
			result.append(Vector3(b.x, high, b.z))
		result.append(b)
	return result


func _segment_clear(a: Vector3, b: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(a, b, HOUSE_MASK)
	return space.intersect_ray(query).is_empty()


func _roofs_near(p: Vector3) -> float:
	var top := p.y
	for h in _houses:
		if h.front.distance_to(p) < 14.0:
			top = maxf(top, h.top)
	return top


## Glatter Weg durch die Punkte (Catmull-Rom), Abtastung etwa alle 0,25 m.
func _smooth(points: Array[Vector3]) -> PackedVector3Array:
	var result := PackedVector3Array()
	if points.size() < 2:
		for p in points:
			result.append(p)
		return result
	for i in points.size() - 1:
		var p0 := points[i - 1] if i > 0 else points[i] * 2.0 - points[i + 1]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[i + 2] if i + 2 < points.size() else points[i + 1] * 2.0 - points[i]
		var n := maxi(1, int(p1.distance_to(p2) / 0.25))
		for k in n:
			var t := float(k) / n
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	result.append(points[-1])
	return result


# --- Sicht ---

func _camera_pos() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera:
		return camera.global_position
	var player := street.get_player()
	return player.global_position if player else Vector3.ZERO


## Ist ein Punkt (Welt) gerade zu sehen (im Bild mit Rand und nicht von Häusern verdeckt)?
func is_visible_point(point: Vector3) -> bool:
	return street.is_visible_point(point)
