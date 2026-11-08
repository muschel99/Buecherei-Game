class_name BirdLife
extends Node3D
## Vögel auf der Straße (seit Etappe 6g, verfeinert in 6h). Entsteht beim Start des Straßenlebens als Kind von
## StreetLife ("Outside/StreetLife/Birds") und wird von StreetLife.step mitbewegt (auch beim Vorspulen).
##
## Kleine Singvögel (GameConfig.bird_species) und Tauben (pigeon_looks) kommen in Schwärmen – nie sichtbar aus
## dem Nichts: Der Weg beginnt hinter einem Haus (von der Straße verdeckt), führt über den First und in einem
## Bogen schräg hinab zum Platz. Mal landen sie zusammen (nebeneinander auf einer Rinne, einem Kastenrand), mal
## verteilen sie sich einzeln. Plätze:
## - an den Häusern ausgemessen (data/animals/spots.json, Werkzeug scenes/tools/bake_animal_spots.tscn):
##   Dachrinnen, Firste, Gesimse, Fensterbänke, Geländer, Fensterläden, Markisenstangen, Efeu, Rand von
##   Blumenkästen und Töpfen – Tauben nur auf breiten Dachplätzen und am Boden,
## - Querarme der Straßenlaternen und das Vogelhäuschen (nur Singvögel),
## - der Gehweg: Singvögel picken und hüpfen, Tauben gehen und picken,
## - der Gartenhof der Baumgasse (seit der Nachbesserung 3 von 6h): Singvögel picken auf dem Pflaster und im Gras hinter
##   dem Baum. Das Blätterdach reicht dort von Mauer zu Mauer (ab etwa 3 m) – darum fliegen sie nie von oben, sondern
##   tief durch die Gasse hinein und hinaus (Wegpunkte "mouth" und "low"). Dort ist es ruhig, Katzen treffen sie öfter.
## Ab und zu zieht ein Schwarm einfach über die Straße, ohne zu landen.
## Auffliegen: Kommt jemand einem sitzenden Vogel nahe (Kugel um den Vogel, gemessen bis zu Kopf und Füßen der
## Spielfigur, Passanten, Katzen, Fahrzeuge), fliegt der Schwarm auf und landet woanders. Auf Laternen und am
## Vogelhäuschen bleiben sie sitzen, wenn man nur vorbeigeht – dort erschreckt sie nur ein Sprung der Spielfigur.
## Zwitschern hängt am Vogel (eigene Laute je Art, sobald es Aufnahmen gibt; sonst „ambience/bird“).

const SPOTS_FILE := "res://data/animals/spots.json"
## Querarme der Straßenlaterne (Modell aus build_storybook_lamps.py): Oberkante je Abstand vom Mast
const LAMP_ARM_SPOTS := [[0.27, 2.784], [0.4, 2.779]]
## Ebenen, an denen Flugwege nicht vorbeikommen (Häuser: world und sight_blocker)
const HOUSE_MASK := 1 | 128
## Abstand zwischen zwei Vögeln am Boden (m) – Tauben brauchen mehr Platz
const GROUND_GAP := 0.17
const PIGEON_GAP := 0.4
## Plätze, an denen nur ein Sprung die Vögel erschreckt (Laternenarme, Vogelhäuschen)
const JUMP_ONLY := ["lamp", "birdhouse", "feed"]
## Plätze, die Tauben nehmen (sonst nur der Boden)
const PIGEON_KINDS := ["roof"]

var street: StreetLife
## Zähler für das Prüfwerkzeug: Erscheinen bzw. Verschwinden im Blickfeld (muss 0 bleiben)
var visible_spawns := 0
var visible_exits := 0
var flights := 0
var flyovers := 0
## Prüfwerkzeug: so viele Schwärme sind im Gartenhof gelandet
var court_flocks := 0
## Prüfwerkzeug: Vögel im Flug unter dem Boden (tiefer als die Fahrbahn) – muss 0 bleiben; letzte Fälle als Text
var below_ground := 0
var below_ground_log: Array[String] = []

var _outside: Node3D
var _rng := RandomNumberGenerator.new()
var _pool := {"bird": [], "pigeon": []}
var _birds: Array[StreetBird] = []
## Plätze: { pos (Welt), face, out (waagerecht), kind, house, edge, wide, taken }
var _perches: Array[Dictionary] = []
var _lamps: Array[Dictionary] = []
var _feeder: Array[Dictionary] = []
## Häuser: { front (Welt, Fußpunkt), out, along, width, depth, eaves, top (Welt-y) }
var _houses: Array[Dictionary] = []
## Schwärme: { birds, timer, landed, kind }
var _flocks: Array[Dictionary] = []
var _spawn := {"bird": 0.0, "pigeon": 0.0, "flyover": 0.0}
var _scan := 0.0
var _chirp_gap := 0.0
var _birdhouse: Node3D
var _flock_id := 0
## Gartenhof der Baumgasse (unter "Outside", x/z): siehe _setup_court
var _court := {}


func setup(life: StreetLife) -> void:
	street = life
	_outside = life.get_parent() as Node3D
	_rng.randomize()
	_load_spots()
	_collect_lamps()
	_setup_court()
	_build_pool("bird", GameConfig.bird_scene, GameConfig.bird_count + 2)
	_build_pool("pigeon", GameConfig.pigeon_scene, GameConfig.pigeon_count + 1)
	_spawn.bird = _rng.randf_range(1.5, 5.0)
	_spawn.pigeon = _rng.randf_range(4.0, 12.0)
	_spawn.flyover = _rng.randf_range(GameConfig.bird_flyover_interval.x * 0.4, GameConfig.bird_flyover_interval.y * 0.6)


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
		var face := out
		if String(p.get("edge", "")) == "along_v":
			# Kante läuft nach vorn (offener Fensterladen): quer darauf sitzen
			face = Vector3.UP.cross(out).normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
		_perches.append({"pos": _outside.to_global(Vector3(p.pos[0], p.pos[1], p.pos[2])), "face": face, "out": out,
			"kind": String(p.kind), "house": String(p.house), "wide": bool(p.get("wide", false)), "taken": null})
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


func _build_pool(kind: String, path: String, count: int) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		return
	for i in count:
		var bird := scene.instantiate() as StreetBird
		bird.name = "%s%d" % [kind.capitalize(), i + 1]
		bird.kind = kind
		bird.life = self
		add_child(bird)
		bird.path_done.connect(_on_path_done)
		(_pool[kind] as Array).append(bird)


# --- Ablauf ---

func step(delta: float) -> void:
	var lowest := _outside.global_position.y - GameConfig.curb_height - 0.03
	for bird in _birds:
		bird.step(delta)
		if bird.state == StreetBird.State.FLY and bird.global_position.y < lowest and not bird.get_meta("below", false):
			bird.set_meta("below", true)
			below_ground += 1
			if below_ground_log.size() < 8:
				below_ground_log.append("%s bei %s (Weg %s → %s)" % [bird.name, bird.global_position.snapped(Vector3.ONE * 0.01),
					bird.debug_path_start().snapped(Vector3.ONE * 0.01), bird.debug_path_end().snapped(Vector3.ONE * 0.01)])
		elif bird.state != StreetBird.State.FLY:
			bird.set_meta("below", false)
	_chirp_gap -= delta
	for kind in ["bird", "pigeon"]:
		_spawn[kind] -= delta
		if _spawn[kind] <= 0.0:
			var gap: Vector2 = GameConfig.bird_spawn_interval if kind == "bird" else GameConfig.pigeon_spawn_interval
			_spawn[kind] = _rng.randf_range(gap.x, gap.y)
			_spawn_flock(kind)
	_spawn.flyover -= delta
	if _spawn.flyover <= 0.0:
		_spawn.flyover = _rng.randf_range(GameConfig.bird_flyover_interval.x, GameConfig.bird_flyover_interval.y)
		_spawn_flyover()
	for flock in _flocks.duplicate():
		if not flock.landed:
			continue
		flock.timer -= delta
		if flock.timer <= 0.0:
			_move_on(flock)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.12
		_check_threats()


func _count(kind: String) -> int:
	var n := 0
	for b in _birds:
		if b.kind == kind:
			n += 1
	return n


func _spawn_flock(kind: String) -> void:
	var limit := GameConfig.bird_count if kind == "bird" else GameConfig.pigeon_count
	var range_size: Vector2i = GameConfig.bird_flock_size if kind == "bird" else GameConfig.pigeon_flock_size
	var size := _rng.randi_range(range_size.x, range_size.y)
	size = mini(size, mini((_pool[kind] as Array).size(), limit - _count(kind)))
	if size <= 0 or _houses.is_empty():
		return
	var spots: Array[Dictionary] = []
	# in den Gartenhof der Baumgasse (auch weiter weg von der Spielfigur – dort finden die Katzen sie)
	if kind == "bird" and _rng.randf() < GameConfig.bird_court_share:
		spots = _court_spots(size)
	if spots.is_empty():
		spots = _pick_area(kind, size, _camera_pos(), GameConfig.bird_near_distance)
	if spots.is_empty():
		return
	var court := bool(spots[0].get("court", false))
	var entry := _court_entry() if court else _hidden_entry(spots[0].pos)
	if entry.is_empty():
		return
	_flock_id += 1
	var flock := {"birds": [], "timer": 0.0, "landed": false, "kind": kind, "id": _flock_id}
	var species := _pick_species(kind)
	for i in spots.size():
		var bird: StreetBird = (_pool[kind] as Array).pop_back()
		_birds.append(bird)
		_dress(bird, species)
		bird.flock = flock
		flock.birds.append(bird)
		var spot: Dictionary = spots[i]
		spot.taken = bird
		bird.spot = spot
		bird.leaving = false
		# jeder Vogel etwas versetzt hinter dem Dach hervor – aber nur, wo auch der versetzte Start verdeckt ist
		# (am Rand des Blickfelds kann er sonst schon sichtbar sein); sonst kleiner, zuletzt genau in der Mitte
		var offset: Vector3 = entry.along * _rng.randf_range(-0.8, 0.8) + Vector3.UP * _rng.randf_range(-0.3, 0.3)
		var path := _entry_path(entry, offset, spot, kind)
		for shrink in [0.4, 0.0]:
			if not is_visible_point(path[0]):
				break
			path = _entry_path(entry, offset * shrink, spot, kind)
		bird.fly_path(path, _speed(kind) * _rng.randf_range(0.92, 1.08), i * _rng.randf_range(0.15, 0.45))
		flights += 1
		if is_visible_point(path[0]):
			visible_spawns += 1
	_flocks.append(flock)


## Ein Schwarm zieht über die Straße, ohne zu landen: hinter einem Haus hervor, quer oder schräg über die
## Straße und hinter einem Haus gegenüber (oder weiter vorn) wieder verschwinden.
func _spawn_flyover() -> void:
	var size := _rng.randi_range(GameConfig.bird_flyover_size.x, GameConfig.bird_flyover_size.y)
	size = mini(size, mini((_pool.bird as Array).size(), GameConfig.bird_count + 2 - _count("bird")))
	if size < 2 or _houses.is_empty():
		return
	var cam := _camera_pos()
	var near := _houses.filter(func(h: Dictionary) -> bool: return h.front.distance_to(cam) < 28.0)
	if near.size() < 2:
		return
	near.shuffle()
	var a: Dictionary = near[0]
	var b: Dictionary = {}
	for h: Dictionary in near:
		if h.out.dot(a.out) < -0.3 and h.front.distance_to(a.front) > 8.0:
			b = h
			break
	if b.is_empty():
		return
	var start := _behind(a, _rng.randf_range(-a.width / 3.0, a.width / 3.0))
	var end := _behind(b, _rng.randf_range(-b.width / 3.0, b.width / 3.0))
	if is_visible_point(start) or is_visible_point(end):
		return
	var height := maxf(a.top, b.top) + _rng.randf_range(1.2, 3.0)
	var ra: Vector3 = a.front - a.out * (a.depth * 0.45)
	var rb: Vector3 = b.front - b.out * (b.depth * 0.45)
	var mid := (ra + rb) / 2.0
	ra.y = a.top + 1.2
	rb.y = b.top + 1.2
	mid.y = height
	_flock_id += 1
	var flock := {"birds": [], "timer": 0.0, "landed": false, "kind": "bird", "flyover": true, "id": _flock_id}
	var species := _pick_species("bird")
	for i in size:
		var bird: StreetBird = (_pool.bird as Array).pop_back()
		_birds.append(bird)
		_dress(bird, species)
		bird.flock = flock
		bird.spot = {}
		bird.leaving = true
		flock.birds.append(bird)
		var off := Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1.2, 1.2))
		var points: Array[Vector3] = [start + off, ra + off * 0.8, mid + off, rb + off * 0.8, end + off]
		bird.fly_path(_smooth(points, true), GameConfig.bird_speed * 1.25 * _rng.randf_range(0.95, 1.05), i * _rng.randf_range(0.05, 0.2))
	flyovers += 1
	flights += size
	_flocks.append(flock)


## Prüfwerkzeug: einen Schwarm direkt am Boden an pos absetzen (ohne Anflug – nur zum Testen der Katzen-Jagd).
func debug_ground_flock(pos: Vector3, size: int = 3) -> void:
	_flock_id += 1
	var flock := {"birds": [], "timer": 60.0, "landed": true, "kind": "bird", "id": _flock_id}
	var center := Vector3(pos.x, _outside.global_position.y, pos.z)
	for i in mini(size, (_pool.bird as Array).size()):
		var bird: StreetBird = (_pool.bird as Array).pop_back()
		_birds.append(bird)
		_dress(bird, 0)
		bird.flock = flock
		flock.birds.append(bird)
		var spot := {"pos": center + Vector3(0.2 * i, 0.0, 0.15 * i), "face": Vector3.FORWARD, "out": Vector3.FORWARD,
			"kind": "ground", "house": "ground", "center": center, "taken": bird}
		bird.spot = spot
		bird.visible = true
		bird.settle(spot)
	_flocks.append(flock)


func _pick_species(kind: String) -> int:
	var list: Array = GameConfig.bird_species if kind == "bird" else GameConfig.pigeon_looks
	return _rng.randi() % maxi(1, list.size())


func _speed(kind: String) -> float:
	return GameConfig.bird_speed * (1.35 if kind == "pigeon" else 1.0)


func _dress(bird: StreetBird, species: int) -> void:
	bird.species = species
	if bird.kind == "pigeon":
		if GameConfig.pigeon_looks.is_empty():
			return
		var p: Dictionary = GameConfig.pigeon_looks[species]
		bird.apply_look("pigeon_%d" % species, {"Taube Gefieder": p.plumage, "Taube Flügel": p.wing, "Taube Beine": p.legs},
			{"Taube Gefieder": {"third_color": p.neck, "shimmer_color": p.shimmer, "mask_shimmer": 0.8, "second_color": p.plumage}})
		return
	if GameConfig.bird_species.is_empty():
		return
	var look: Dictionary = GameConfig.bird_species[species]
	bird.apply_look("bird_%d" % species, {"Vogel Gefieder": look.plumage, "Vogel Flügel": look.wing,
		"Vogel Schnabel": look.beak, "Vogel Beine": look.get("legs", Color(0.62, 0.48, 0.42))},
		{"Vogel Gefieder": {"second_color": look.breast, "third_color": look.get("cap", look.plumage)}})


func _on_path_done(bird: StreetBird) -> void:
	if bird.leaving:
		# erst verschwinden, wenn niemand hinschaut – sonst noch ein Stück weiter weg fliegen
		var end := bird.global_position
		if is_visible_point(end) and bird.global_position.distance_to(_camera_pos()) < 70.0:
			var away := end - _camera_pos()
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			bird.fly_path(PackedVector3Array([end, end + away * 3.0 + Vector3.UP * 0.6, end + away * 6.0 + Vector3.UP * 1.5]),
				GameConfig.bird_speed)
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
	if bool(bird.spot.get("court", false)):
		flock.timer *= GameConfig.bird_court_stay_factor
		if not flock.get("counted", false):
			flock.counted = true
			court_flocks += 1


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
	(_pool[bird.kind] as Array).append(bird)


## Nach dem Sitzen: zu einem anderen Platz in der Nähe oder hinter ein Dach. Bei Gefahr (flee) weg vom Grund
## (away = Richtung weg von der Gefahr) und höher hinauf.
func _move_on(flock: Dictionary, flee: bool = false, away: Vector3 = Vector3.ZERO) -> void:
	var birds: Array = flock.birds.duplicate()
	if birds.is_empty():
		_flocks.erase(flock)
		return
	var kind := String(flock.get("kind", "bird"))
	var first: StreetBird = birds[0]
	var in_court := bool(first.spot.get("court", false))
	var stay := flee or _rng.randf() < GameConfig.bird_stay_nearby_share
	var spots: Array[Dictionary] = []
	if in_court and not flee and _rng.randf() < GameConfig.bird_court_stay_share:
		# im Hof bleiben: ein Stück weiter picken (eigene Plätze zählen nicht als besetzt)
		spots = _court_spots(birds.size(), flock)
	if spots.is_empty() and stay:
		spots = _pick_area(kind, birds.size(), first.global_position + away * 4.0, 16.0, not flee, flee)
	flock.landed = false
	var speed := _speed(kind) * (GameConfig.bird_flee_speed / GameConfig.bird_speed if flee else 1.0)
	if flee or _camera_pos().distance_to(first.global_position) < 14.0:
		# Flattern (eigene Aufnahme der Entwicklerin – fehlt sie, bleibt es still)
		var flap := "ambience/pigeon_flap" if kind == "pigeon" and not Audio.streams("ambience/pigeon_flap").is_empty() \
			else "ambience/bird_flap"
		Audio.play_on(first, flap, GameConfig.bird_flap_volume_db + (4.0 if flee else 0.0), Audio.vary(0.08),
			20.0, Vector3(0.0, 0.05, 0.0))
	for i in birds.size():
		var bird: StreetBird = birds[i]
		var from: Dictionary = bird.spot
		if from.get("taken") == bird:
			from.taken = null
		var delay := (i * _rng.randf_range(0.04, 0.12)) if flee else (i * _rng.randf_range(0.3, 0.9))
		if i < spots.size():
			var spot: Dictionary = spots[i]
			spot.taken = bird
			bird.spot = spot
			bird.fly_path(_hop_path(bird.global_position, from, spot, away), speed * _rng.randf_range(0.92, 1.08), delay)
		else:
			var exit := _court_entry() if bool(from.get("court", false)) else _hidden_entry(bird.global_position)
			if exit.is_empty():
				# kein verdeckter Platz zum Wegfliegen: einfach sitzen bleiben
				bird.spot = from
				from.taken = bird
				continue
			bird.leaving = true
			var offset: Vector3 = exit.along * _rng.randf_range(-0.8, 0.8)
			bird.fly_path(_exit_path(bird.global_position, from, exit, offset, away), speed * _rng.randf_range(0.92, 1.08), delay)
		flights += 1
	if flock.birds.is_empty():
		_flocks.erase(flock)


## Kommt jemand einem sitzenden Vogel zu nahe (Kugel um den Vogel), fliegt der ganze Schwarm auf. Auf Laternen
## und am Vogelhäuschen nur, wenn die Spielfigur dort springt.
func _check_threats() -> void:
	var threats := _threats()
	for flock in _flocks.duplicate():
		if flock.get("flyover", false):
			continue
		for bird: StreetBird in flock.birds:
			if bird.state != StreetBird.State.PERCH or bird.is_waiting():
				continue
			var p := bird.global_position
			var jump_only := String(bird.spot.get("kind", "")) in JUMP_ONLY
			var scared := false
			var away := Vector3.ZERO
			for t: Dictionary in threats:
				if jump_only and not t.get("jumping", false):
					continue
				var d := _segment_distance(p, t.a, t.b)
				if d < float(t.radius):
					scared = true
					away = p - t.a
					away.y = 0.0
					away = away.normalized() if away.length() > 0.01 else Vector3.ZERO
					break
			if scared:
				_move_on(flock, true, away)
				break


## Alle, vor denen Vögel auffliegen: { a, b (Füße, Kopf), radius, jumping }.
func _threats() -> Array:
	var result := []
	var r := GameConfig.bird_flee_radius
	var player := street.get_player()
	if player:
		var jumping := false
		if player is CharacterBody3D:
			var body := player as CharacterBody3D
			jumping = not body.is_on_floor() and body.velocity.y > -4.0
		result.append({"a": player.global_position, "b": player.global_position + Vector3.UP * 1.7, "radius": r,
			"jumping": jumping})
	for walker in street.get_walkers():
		result.append({"a": walker.global_position, "b": walker.global_position + Vector3.UP * 1.25, "radius": r})
	for vehicle in street.get_vehicles():
		var c := vehicle.global_position + Vector3.UP * 0.7
		result.append({"a": c, "b": c, "radius": GameConfig.bird_vehicle_flee_radius + vehicle.length * 0.3})
	if street.cats:
		for cat in street.cats.get_cats():
			result.append({"a": cat.global_position, "b": cat.global_position + Vector3.UP * 0.3,
				"radius": cat.bird_scare_radius()})
	return result


static func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-6 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Zwitschern (räumlich am Vogel), nicht zu viele gleichzeitig; eigene Laute je Art, wenn es sie gibt.
func chirp(bird: StreetBird) -> void:
	if _chirp_gap > 0.0 or bird.global_position.distance_to(_camera_pos()) > GameConfig.bird_chirp_distance:
		return
	var sound := "ambience/pigeon"
	if bird.kind == "bird":
		sound = "ambience/bird"
		if bird.species < GameConfig.bird_species.size():
			var own := String((GameConfig.bird_species[bird.species] as Dictionary).get("sound", ""))
			if own != "" and Audio.has_sound(own):
				sound = own
	if not Audio.has_sound(sound):
		return
	_chirp_gap = 0.9
	Audio.play_on(bird, sound, GameConfig.bird_chirp_volume_db, Audio.vary(0.1), GameConfig.bird_chirp_distance,
		Vector3(0.0, 0.07, 0.0))


## Darf ein Vogel am Boden dorthin (kein anderer Vogel zu nah)?
func ground_free(target: Vector3, bird: StreetBird) -> bool:
	var gap := PIGEON_GAP if bird.kind == "pigeon" else GROUND_GAP
	for other in _birds:
		if other != bird and other.is_on_ground() and other.global_position.distance_to(target) < gap:
			return false
	return true


# --- Plätze wählen ---

## Plätze für einen Schwarm von size Vögeln in der Nähe von near (höchstens radius Meter). Singvögel: Gehweg,
## Vogelhäuschen, Laternenarme oder Plätze an den Häusern (zusammen oder einzeln verteilt); Tauben: Gehweg oder
## breite Dachplätze. high_only = nur oberhalb der Köpfe (Flucht).
func _pick_area(kind: String, size: int, near: Vector3, radius: float, allow_ground: bool = true, high_only: bool = false) -> Array[Dictionary]:
	var roll := _rng.randf()
	var result: Array[Dictionary] = []
	if kind == "pigeon":
		if allow_ground and not high_only and roll < GameConfig.pigeon_ground_share:
			result = _ground_spots(size, near, radius, PIGEON_GAP * 1.4, 1.1)
		if result.is_empty():
			result = _group_from(_perches.filter(func(s: Dictionary) -> bool: return s.wide and s.kind in PIGEON_KINDS),
				size, near, radius * 1.4, 3.0, high_only, PIGEON_GAP)
		return result
	if allow_ground and not high_only and roll < GameConfig.bird_ground_share:
		result = _ground_spots(size, near, radius, GROUND_GAP * 1.4, 0.45)
	elif roll < GameConfig.bird_ground_share + GameConfig.bird_birdhouse_share:
		result = _group_from(_feeder, size, near, radius, 0.5)
	elif roll < GameConfig.bird_ground_share + GameConfig.bird_birdhouse_share + GameConfig.bird_lamp_share:
		result = _group_from(_lamps, size, near, radius, 0.6)
	if result.is_empty():
		if size > 1 and _rng.randf() < GameConfig.bird_scatter_share:
			result = _scattered(size, near, radius, high_only)
		else:
			result = _group_from(_perches, size, near, radius, 1.3, high_only)
	return result


func _cat_positions() -> Array[Vector3]:
	var cats: Array[Vector3] = []
	if street.cats:
		for cat in street.cats.get_cats():
			cats.append(cat.global_position)
	return cats


func _free(spot: Dictionary, near: Vector3, radius: float, high_only: bool, cats: Array[Vector3]) -> bool:
	if spot.taken != null or spot.pos.distance_to(near) > radius:
		return false
	if high_only and spot.pos.y - _outside.global_position.y < 2.2:
		return false
	# nie neben einer Katze landen
	for c in cats:
		if c.distance_to(spot.pos) < 1.8:
			return false
	return true


## Ein freier Platz (bevorzugt sichtbar) und freie Nachbarn am selben Haus bzw. derselben Laterne.
func _group_from(list: Array, size: int, near: Vector3, radius: float, spread: float, high_only: bool = false,
		gap: float = 0.0) -> Array[Dictionary]:
	var cats := _cat_positions()
	var candidates: Array[Dictionary] = []
	for spot: Dictionary in list:
		if _free(spot, near, radius, high_only, cats):
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
	for pass_spread in [spread, 4.0]:
		for spot in candidates:
			if result.size() >= size:
				break
			if spot in result or spot.house != first.house or spot.pos.distance_to(first.pos) > pass_spread:
				continue
			if pass_spread == spread and spot.kind != first.kind:
				continue
			var ok := true
			for other in result:
				if gap > 0.0 and other.pos.distance_to(spot.pos) < gap:
					ok = false
			if ok:
				result.append(spot)
	return result


## Einzelne Vögel verteilt auf verschiedene Plätze in der Nähe (je mindestens 1 m auseinander).
func _scattered(size: int, near: Vector3, radius: float, high_only: bool) -> Array[Dictionary]:
	var cats := _cat_positions()
	var pool: Array = _perches + _lamps
	pool.shuffle()
	var result: Array[Dictionary] = []
	var center := Vector3.INF
	for spot: Dictionary in pool:
		if result.size() >= size:
			break
		if not _free(spot, near, radius, high_only, cats):
			continue
		if center != Vector3.INF and spot.pos.distance_to(center) > 8.0:
			continue
		var ok := true
		for other in result:
			if other.pos.distance_to(spot.pos) < 1.0:
				ok = false
		if ok:
			result.append(spot)
			if center == Vector3.INF:
				center = spot.pos
	return result


## Plätze auf dem Gehweg: ein Fleck auf einem der beiden Gehwege nahe der Kamera, weit genug von Leuten,
## Laternen, Bänken und Treppe; die Vögel verteilen sich darum herum.
func _ground_spots(size: int, near: Vector3, radius: float, gap: float, spread: float) -> Array[Dictionary]:
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
		if center.distance_to(near) > radius or not street.clear_of_static(c2, 0.9 + spread):
			continue
		var far := true
		for t: Dictionary in threats:
			if Vector2(center.x - t.a.x, center.z - t.a.z).length() < float(t.radius) * 1.8:
				far = false
				break
		if not far:
			continue
		var result: Array[Dictionary] = []
		for i in size:
			var p := center
			for k in 10:
				var a := _rng.randf() * TAU
				var r := 0.0 if i == 0 else _rng.randf_range(gap, spread)
				p = center + Vector3(cos(a) * r, 0.0, sin(a) * r)
				var ok := true
				for other in result:
					if other.pos.distance_to(p) < gap:
						ok = false
				if ok:
					break
			var b := _rng.randf() * TAU
			result.append({"pos": p, "face": Vector3(sin(b), 0.0, cos(b)), "out": Vector3(sin(b), 0.0, cos(b)), "kind": "ground",
				"house": "ground", "center": center, "taken": null})
		return result
	return []


# --- Gartenhof der Baumgasse (seit der Nachbesserung 3 von 6h) ---

## Lage des Hofs aus StreetLayout (unter "Outside", x/z): wo Schwärme picken (Mitte; die Vögel hüpfen bis 0,55 m darum),
## was dort im Weg ist (Rundbank um den Baum, Trittsteine, Beete, Töpfe an der Bücherei) und die Wegpunkte durch die Gasse.
func _setup_court() -> void:
	# nur mit Garten (Gassen-Modell mit Baum und Rundbank)
	var alley := _outside.get_node_or_null("Alley")
	if alley == null or alley.get("model_scene") == null:
		return
	var lx := StreetLayout.HOUSE_LEFT
	var fx := StreetLayout.alley_far_x()
	var end := StreetLayout.alley_end_z()
	var gz := end - GameConfig.alley_garden_depth
	var gx := fx - GameConfig.alley_garden_extra_width
	var tree := StreetLayout.garden_tree()
	var mid := (lx + fx) / 2.0
	_court = {
		# Pflaster der Gasse (vor und im Hof; nicht an den Töpfen der Bücherei) und Rasen hinter dem Baum
		"areas": [Rect2(fx + 0.7, gz - 2.0, (lx - 1.15) - (fx + 0.7), (end - 0.6) - (gz - 2.0)),
			Rect2(gx + 1.5, tree.y + 2.0, (fx - 0.6) - (gx + 1.5), (end - 0.6) - (tree.y + 2.0))],
		"lawn": Rect2(gx, gz, fx - gx, end - gz),
		"tree": tree,
		# Trittsteine zur Bank: quer von der Gasse (fx + 0,2) zum Baum, um tree.y + 0,9
		"stones": Rect2(gx, tree.y + 0.9 - 1.1, fx + 1.05 - gx, 2.2),
		"inside": Rect2(gx, gz - 1.5, lx - gx, end - gz + 1.8),
		# tief vor dem Blätterdach (das bei gz beginnt) und über der Mündung der Gasse
		"low": Vector3(mid, 2.3, gz - 3.4),
		"mouth": Vector3(mid, 4.8, StreetLayout.recess_z() + 0.8),
	}


## Wegpunkt des Hofs in Weltkoordinaten ("low" oder "mouth").
func _court_point(key: String) -> Vector3:
	return _outside.to_global(_court[key])


## Durch die Gasse: hinaus (Hof → tief → Mündung) oder hinein (Mündung → tief).
func _court_way(outward: bool) -> Array[Vector3]:
	var low := _court_point("low") + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.6, 0.6))
	var mouth := _court_point("mouth") + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.3, 0.4), 0.0)
	# (zwei getrennte Rückgaben: ein Ausdruck „… if … else …“ mit Listen ergibt in Godot 4.6 eine Liste ohne Typ)
	if outward:
		return [low, mouth]
	return [mouth, low]


## Verdeckter Ort zum Hinein- und Hinausfliegen: hinter einem Haus gegenüber der Gasse (der Weg führt dann über die
## Straße zur Mündung der Gasse).
func _court_entry() -> Dictionary:
	if _court.is_empty():
		return {}
	var toward_library := Vector3(_court.mouth.x, 0.0, _court.mouth.z) - Vector3(_court.mouth.x, 0.0, StreetLayout.opposite_front_z())
	return _hidden_entry(_court_point("mouth"), toward_library.normalized())


## Platz auf dem Rasen hinter dem Baum (im seitlichen Teil des Hofs)?
func _on_lawn(spot: Dictionary) -> bool:
	if _court.is_empty() or not bool(spot.get("court", false)):
		return false
	var l := _outside.to_local(spot.pos)
	return (_court.lawn as Rect2).has_point(Vector2(l.x, l.z))


## Punkt über dem Gang der Gasse auf gleicher Höhe (z) wie p – von dort aus geht es quer zum Rasen bzw. vom Rasen weg.
func _lane_above(p: Vector3) -> Vector3:
	var l := _outside.to_local(p)
	var lawn: Rect2 = _court.lawn
	return _outside.to_global(Vector3(lawn.end.x + 0.9, 1.5, clampf(l.z, lawn.position.y + 2.0, lawn.end.y - 0.5)))


## Die letzten Punkte zu einem Platz im Hof: auf den Rasen hinter dem Baum quer aus der Gasse (vom Gang her), sonst
## direkt.
func _court_arrival(spot: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var from := _court_point("low")
	if _on_lawn(spot):
		from = _lane_above(spot.pos)
		points.append(from)
	points.append_array(_landing(from, spot))
	return points


## Liegt ein Punkt (Welt) im Hof oder in der Gasse davor?
func in_court(point: Vector3) -> bool:
	if _court.is_empty():
		return false
	var l := _outside.to_local(point)
	return (_court.inside as Rect2).has_point(Vector2(l.x, l.z))


## Wie viele Vögel picken gerade im Hof (oder fliegen dorthin)?
func court_birds() -> int:
	var n := 0
	for b in _birds:
		if bool(b.spot.get("court", false)) and not b.leaving:
			n += 1
	return n


## Ist hier Platz für die Mitte eines Schwarms (nicht an Bank, Trittsteinen)?
func _court_center_ok(c: Vector2) -> bool:
	if c.distance_to(_court.tree) < 1.6:
		return false
	return not (_court.stones as Rect2).has_point(c)


## Plätze für einen Schwarm im Hof: eine freie Stelle (weit weg von Leuten und Katzen), die Vögel verteilen sich darum.
## Nur ein Schwarm zur Zeit (außer own = der Schwarm, der dort gerade umzieht).
func _court_spots(size: int, own: Dictionary = {}) -> Array[Dictionary]:
	if _court.is_empty():
		return []
	for b in _birds:
		if bool(b.spot.get("court", false)) and not b.leaving and int(b.flock.get("id", -1)) != int(own.get("id", -2)):
			return []
	var threats := _threats()
	var cats := _cat_positions()
	var gap := GROUND_GAP * 1.4
	var spread := 0.45
	for attempt in 16:
		var area: Rect2 = _court.areas[0 if _rng.randf() < 0.65 else 1]
		var c := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		if not _court_center_ok(c):
			continue
		var y := 0.024 if (_court.lawn as Rect2).has_point(c) else 0.0   # Rasen liegt 2,4 cm hoch
		var center := _outside.to_global(Vector3(c.x, y, c.y))
		var far := true
		for t: Dictionary in threats:
			if Vector2(center.x - t.a.x, center.z - t.a.z).length() < float(t.radius) * 1.8:
				far = false
				break
		for cp in cats:
			if cp.distance_to(center) < 3.5:
				far = false
		if not far:
			continue
		var result: Array[Dictionary] = []
		for i in size:
			var p := center
			for k in 10:
				var a := _rng.randf() * TAU
				var r := 0.0 if i == 0 else _rng.randf_range(gap, spread)
				p = center + Vector3(cos(a) * r, 0.0, sin(a) * r)
				var ok := true
				for other in result:
					if other.pos.distance_to(p) < gap:
						ok = false
				if ok:
					break
			var b := _rng.randf() * TAU
			result.append({"pos": p, "face": Vector3(sin(b), 0.0, cos(b)), "out": Vector3(sin(b), 0.0, cos(b)), "kind": "ground",
				"house": "court", "center": center, "court": true, "taken": null})
		return result
	return []


# --- Flugwege ---

## Verdeckter Ort hinter einem Haus nahe target (von dort fliegen Vögel über den First herein bzw.
## dorthin hinaus). Liefert { pos, house, along, lateral } oder leer.
func _hidden_entry(target: Vector3, facing: Vector3 = Vector3.ZERO) -> Dictionary:
	var houses: Array[Dictionary] = []
	for h in _houses:
		if facing == Vector3.ZERO or (h.out as Vector3).dot(facing) > 0.5:
			houses.append(h)
	houses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.front.distance_squared_to(target) < b.front.distance_squared_to(target))
	for i in mini(8, houses.size()):
		var h: Dictionary = houses[i]
		var lateral: float = _rng.randf_range(-h.width / 3.0, h.width / 3.0)
		var pos := _behind(h, lateral)
		if not is_visible_point(pos):
			return {"pos": pos, "house": h, "along": h.along, "lateral": lateral}
	return {}


## Punkt hinter einem Haus (von der Straße verdeckt), weit genug zurück für einen flachen Steigflug.
func _behind(h: Dictionary, lateral: float) -> Vector3:
	var pos: Vector3 = h.front - h.out * (h.depth + 3.5) + h.along * lateral
	pos.y = h.front.y + (h.eaves - h.front.y) * 0.8
	return pos


## Weg von hinter einem Haus über den First und in einem Bogen hinab zum Platz.
func _entry_path(entry: Dictionary, offset: Vector3, spot: Dictionary, kind: String) -> PackedVector3Array:
	var h: Dictionary = entry.house
	var lateral: Vector3 = h.along * float(entry.lateral)
	var ridge: Vector3 = h.front - h.out * (h.depth * 0.45) + lateral
	ridge.y = h.top + 1.0
	var over: Vector3 = h.front + h.out * 1.2 + lateral
	over.y = maxf(h.top + 0.3, spot.pos.y + 1.5)
	var points: Array[Vector3] = [entry.pos + offset, ridge + offset * 0.6, over + offset * 0.4]
	if bool(spot.get("court", false)):
		# über die Straße zur Mündung der Gasse, tief hindurch und unter dem Blätterdach zum Platz
		points.append_array(_court_way(false))
		points.append_array(_court_arrival(spot))
		return _smooth(_clear_route(points), kind == "bird")
	points.append_array(_landing(over, spot))
	return _smooth(_clear_route(points), kind == "bird")


## Weg vom Platz über den First hinter ein Haus (Wegfliegen außer Sicht).
func _exit_path(from_pos: Vector3, from: Dictionary, exit: Dictionary, offset: Vector3, away: Vector3) -> PackedVector3Array:
	var h: Dictionary = exit.house
	var lateral: Vector3 = h.along * float(exit.lateral)
	var ridge: Vector3 = h.front - h.out * (h.depth * 0.45) + lateral
	ridge.y = h.top + 1.0
	var over: Vector3 = h.front + h.out * 1.2 + lateral
	over.y = maxf(h.top + 0.3, from_pos.y + 1.5)
	var points: Array[Vector3] = _takeoff(from_pos, from, away)
	if bool(from.get("court", false)):
		points.append_array(_court_way(true))
	points.append_array([over + offset * 0.4, ridge + offset * 0.6, exit.pos + offset])
	return _smooth(_clear_route(points, 2), true)


## Weg von einem Platz zum nächsten.
func _hop_path(from_pos: Vector3, from: Dictionary, spot: Dictionary, away: Vector3 = Vector3.ZERO) -> PackedVector3Array:
	var points: Array[Vector3] = _takeoff(from_pos, from, away)
	var from_court := bool(from.get("court", false))
	var to_court := bool(spot.get("court", false))
	if from_court and to_court:
		# im Hof ein Stück weiter: flach unter dem Blätterdach (bleibt unter 2 m)
		var lift2 := points[-1]
		if _on_lawn(spot):
			points.append_array(_court_arrival(spot))
			return _smooth(points, false)
		var mid := (lift2 + (spot.pos as Vector3)) / 2.0
		mid.y = minf(maxf(lift2.y, (spot.pos as Vector3).y) + 0.5, _outside.global_position.y + 2.0)
		points.append(mid)
		points.append_array(_landing(mid, spot))
		return _smooth(points, false)
	if from_court:
		points.append_array(_court_way(true))
	elif to_court:
		points.append_array(_court_way(false))
		points.append_array(_court_arrival(spot))
		return _smooth(_clear_route(points), String(from.get("kind", "")) != "pigeon")
	var lift := points[-1]
	var landing := _landing(lift, spot)
	if lift.distance_to(landing[0]) > 5.0:
		var mid := (lift + landing[0]) / 2.0
		mid.y = maxf(mid.y, maxf(lift.y, landing[0].y) + 0.8)
		points.append(mid)
	points.append_array(landing)
	return _smooth(_clear_route(points), String(from.get("kind", "")) != "pigeon")


## Abheben in einem flachen Bogen: nach vorn (vom Haus weg) bzw. weg von der Gefahr, dabei steigen.
func _takeoff(from_pos: Vector3, from: Dictionary, away: Vector3) -> Array[Vector3]:
	if bool(from.get("court", false)):
		# im Hof: zur Gasse hin auffliegen (nie in Bank, Stamm oder Blätterdach), etwas steiler
		# vom Rasen hinter dem Baum erst quer zur Gasse (nie dicht am Stamm vorbei)
		var to_low: Vector3 = (_lane_above(from_pos) if _on_lawn(from) else _court_point("low")) - from_pos
		to_low.y = 0.0
		var d := to_low.normalized() if to_low.length() > 0.1 else Vector3.BACK
		return [from_pos, from_pos + d * 0.4 + Vector3.UP * 0.35, from_pos + d * 1.5 + Vector3.UP * 1.2]
	var dir: Vector3 = away if away != Vector3.ZERO else from.get("out", Vector3.FORWARD)
	if String(from.get("kind", "")) == "ground" and away == Vector3.ZERO:
		dir = from.get("face", Vector3.FORWARD)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
	return [from_pos, from_pos + dir * 0.45 + Vector3.UP * 0.2, from_pos + dir * 1.6 + Vector3.UP * 0.75]


## Die letzten Punkte vor der Landung: in flachem Bogen schräg von vorn oben auf den Platz (etwa 25°), kurz vor
## dem Aufsetzen fast waagerecht.
func _landing(from: Vector3, spot: Dictionary) -> Array[Vector3]:
	var target: Vector3 = spot.pos
	var dir: Vector3
	if spot.kind == "ground":
		dir = from - target
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	else:
		dir = (spot.out as Vector3).rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	return [target + dir * 2.6 + Vector3.UP * 1.1, target + dir * 0.9 + Vector3.UP * 0.3,
		target + dir * 0.18 + Vector3.UP * 0.04, target]


## Teilstücke, die durch ein Haus führen würden: über die Dächer heben (Landung und Abflug bleiben).
func _clear_route(points: Array[Vector3], keep_start: int = 0) -> Array[Vector3]:
	var result: Array[Vector3] = [points[0]]
	for i in range(1, points.size()):
		var a := result[-1]
		var b := points[i]
		if i > keep_start and i < points.size() - 3 and not _segment_clear(a, b):
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


## Glatter Weg durch die Punkte (Catmull-Rom), Abtastung etwa alle 0,2 m. waves = kleine Vögel fliegen in
## sanften Wellen (Flügelschläge – Gleiten), nicht am Anfang und vor der Landung.
func _smooth(points: Array[Vector3], waves: bool = false) -> PackedVector3Array:
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
		var n := maxi(1, int(p1.distance_to(p2) / 0.2))
		for k in n:
			var t := float(k) / n
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	result.append(points[-1])
	# Nie tiefer als Start oder Ziel (die weiche Kurve schwingt an scharfen Ecken sonst unter den Boden aus – Vögel
	# tauchten beim Abheben vom Gehweg bis zu 30 cm in den Boden)
	var floor_y := minf(points[0].y, points[-1].y)
	if waves and result.size() > 4:
		var total := 0.0
		var lengths := PackedFloat32Array([0.0])
		for i in range(1, result.size()):
			total += result[i].distance_to(result[i - 1])
			lengths.append(total)
		for i in result.size():
			var s := lengths[i]
			var fade := smoothstep(0.0, 2.5, s) * smoothstep(0.0, 3.5, total - s)
			result[i].y += sin(s / 1.7 * TAU) * 0.12 * fade
	for i in result.size():
		result[i].y = maxf(result[i].y, floor_y)
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
