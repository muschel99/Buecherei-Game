class_name CatLife
extends Node3D
## Katzen auf der Straße (seit Etappe 6g, verfeinert in 6h). Entsteht beim Start des Straßenlebens als Kind von
## StreetLife ("Outside/StreetLife/Cats") und wird von StreetLife.step mitbewegt.
##
## Jede Katze hat ihr eigenes Aussehen (GameConfig.cat_looks). Ab und zu (cat_interval) kommt eine vorbei – nur von
## den verdeckten Straßenenden her und nur dorthin zurück (verschwindet erst, wenn niemand hinschaut). Unterwegs:
## - läuft frei: mal an der Hauswand, mal mitten auf dem Gehweg, in Bögen; bleibt stehen und schnuppert,
## - setzt sich auf Bänke, Stühle, Fensterbänke und Stufen (ausgemessen: nur, was an der Hauswand hängt), putzt
##   sich, streckt sich, schläft eingerollt; springt immer vorwärts hinauf und herunter (vorher umdrehen),
## - schaut durchs Schaufenster der Bücherei (Kopf hoch),
## - kommt bei offener Tür herein: Stufen hinaufhüpfen, Weg zwischen den Möbeln, in ein Katzenkörbchen (bevorzugt),
##   sonst auf einen Sessel/ein Sofa, sonst auf einen Teppich; schnurrt, geht irgendwann wieder. Ist die Tür zu,
##   wartet sie seitlich unter dem Einwurf (draußen) bzw. neben der Tür (drinnen) – nie im Schwenkbereich,
## - spielt mit Spielzeug (Maus, Wollknäuel, Federbüschel, Ball): anstupsen, hinterher, draufspringen, tragen;
##   lässt es manchmal an einer Hauswand oder Laterne liegen – eine andere Katze findet es später,
## - lauert Vögeln am Boden auf (geduckt, anschleichen, Sprung) – die Vögel fliegen immer rechtzeitig weg,
## - spielt mit einer zweiten Katze Fangen.
## Über die Straße: am Bordstein warten, bis kein Fahrzeug kommt, hinunter auf die Fahrbahn, hinüber, hinauf.

const SPOTS_FILE := "res://data/animals/spots.json"
## Spielzeuge: Szene je Art
const TOYS := {"mouse": "res://assets/models/animals/cat_toy.glb", "yarn": "res://assets/models/animals/toy_yarn.glb",
	"feather": "res://assets/models/animals/toy_feather.glb", "ball": "res://assets/models/animals/toy_ball.glb"}
## Raster für Wege in der Bücherei (m) und was dort im Weg ist (world, furniture)
const GRID_CELL := 0.15
const FURNITURE_MASK := 1 | 8
## Abstand der Wege zur Hauswand und zu festen Hindernissen (m)
const WALL_GAP := 0.1
const STATIC_GAP := 0.24
## Zwischen Deko und Hauswand darf die Katze hindurch, wenn so viel Platz bleibt (m bis zum Rand des Hindernisses)
const DECO_GAP := 0.14
## Gartenmauern: Höhe der Mauerkrone über dem Gehweg (m), mindestens so lang (m)
const WALL_MIN_H := 0.55
const WALL_MAX_H := 0.78
const WALL_MIN_LENGTH := 1.4
const BLOCK_AHEAD := 0.55
const BLOCK_SIDE := 0.22
## Gruppe der Katzenkörbchen-Plätze (Marker „CatSpot“ in Möbeln) und Unterkategorie der Körbchen
const CAT_SPOT_GROUP := "cat_spots"

var street: StreetLife
## Zähler für das Prüfwerkzeug
var visible_spawns := 0
var visible_exits := 0
var visits := 0
var entered := 0
var hunts := 0
var plays := 0
var meetings := 0
var wall_walks := 0
var rubs := 0

var _outside: Node3D
var _rng := RandomNumberGenerator.new()
var _pool: Array[StreetCat] = []
var _cats: Array[StreetCat] = []
var _timer := 0.0
var _scan := 0.0
## Fensterbänke und Stufen für Katzen: { pos (Welt), out, taken }
var _sills: Array[Dictionary] = []
var _door: Door
var _room: Room
## Spielzeug: alle Knoten, liegende ({ node, pos }), Besitzerin je Spielzeug
var _toys: Array[Node3D] = []
var _toy_tweens := {}
var _hunted := {}
## Gartenmauern (seit Etappe 6h): { a, b (Welt, Mitte der Krone, Enden), out (zur Straße), s_a, s_b, side, taken }
var _walls: Array[Dictionary] = []
## Gegenstände, an denen genug Platz zum Reiben ist (beim Start ausgemessen, siehe _rub_samples)
var _rub_spots: Array[Dictionary] = []
## Begegnungen zweier Katzen: "id_id" -> Zeit bis zur nächsten möglichen
var _met := {}


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
		_collect_walls(data.get("perches", []))
	for o in street.get_static_obstacles():
		var lage := street.centerline.project(o.pos)
		if float(o.radius) > 0.5 or absf(lage.y) < GameConfig.street_width / 2.0 + 0.3:
			continue
		var samples := _rub_samples(o, 1 if lage.y > 0.0 else -1)
		var best := 0
		var run := 0
		for k in 48:
			run = run + 1 if samples.ok[k % 24] else 0
			best = maxi(best, run)
		if best >= 6:
			_rub_spots.append(o)
	_door = get_tree().get_first_node_in_group("doors") as Door
	_room = _outside.get_parent().get_node_or_null("GroundFloorRoom") as Room
	_build_pool()
	_build_toys()
	_timer = _rng.randf_range(GameConfig.cat_first_delay.x, GameConfig.cat_first_delay.y)


## Gartenmauern aus den ausgemessenen Plätzen: niedrige Plätze (Art "low") in Kronenhöhe je Haus, entlang der
## Hausfront sortiert und an Lücken (Gartenpforte) geteilt; jede Strecke wird zu einem Weg auf der Mitte der Krone.
func _collect_walls(perches: Array) -> void:
	var by_house := {}
	for p: Dictionary in perches:
		var h := float(p.pos[1])
		if p.get("kind", "") != "low" or h < WALL_MIN_H or h > WALL_MAX_H:
			continue
		var key := String(p.get("house", ""))
		if not by_house.has(key):
			by_house[key] = []
		(by_house[key] as Array).append(p)
	for key: String in by_house:
		var list: Array = by_house[key]
		if list.size() < 6:
			continue
		var out := Vector2(list[0].out[0], list[0].out[1]).normalized()
		var along := Vector2(-out.y, out.x)
		var items: Array = []
		for p: Dictionary in list:
			var q := Vector2(p.pos[0], p.pos[2])
			items.append([q.dot(along), q.dot(out), float(p.pos[1])])
		items.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		var start := 0
		for i in range(1, items.size() + 1):
			if i == items.size() or float(items[i][0]) - float(items[i - 1][0]) > 0.6:
				_add_wall(items.slice(start, i), along, out)
				start = i


func _add_wall(items: Array, along: Vector2, out: Vector2) -> void:
	if items.size() < 4:
		return
	var u0 := float(items[0][0]) + 0.12
	var u1 := float(items[-1][0]) - 0.12
	var vs: Array = items.map(func(x: Array) -> float: return x[1])
	var hs: Array = items.map(func(x: Array) -> float: return x[2])
	var v: float = (float(vs.min()) + float(vs.max())) / 2.0
	if u1 - u0 < WALL_MIN_LENGTH or float(vs.max()) - float(vs.min()) > 0.3 or float(hs.max()) - float(hs.min()) > 0.04:
		return
	var h: float = hs.reduce(func(acc: float, x: float) -> float: return acc + x, 0.0) / hs.size()
	var ends: Array[Vector3] = []
	var lages: Array[Vector2] = []
	for u: float in [u0, u1]:
		var q: Vector2 = along * u + out * v
		ends.append(_outside.to_global(Vector3(q.x, h, q.y)))
		lages.append(street.centerline.project(q))
	_walls.append({"a": ends[0], "b": ends[1], "out": Vector3(out.x, 0.0, out.y), "s_a": lages[0].x, "s_b": lages[1].x,
		"side": 1 if lages[0].y > 0.0 else -1, "taken": null})


## Die Gartenmauern (für das Prüfwerkzeug und Testbilder).
func get_walls() -> Array[Dictionary]:
	return _walls


func seed_random(value: int) -> void:
	_rng.seed = value


func get_cats() -> Array[StreetCat]:
	return _cats


func _build_pool() -> void:
	var scene := load(GameConfig.cat_scene) as PackedScene
	var adult_scene := load(GameConfig.cat_adult_scene) as PackedScene
	if scene == null:
		return
	for i in GameConfig.cat_looks.size():
		var big := bool(GameConfig.cat_looks[i].get("adult", false)) and adult_scene != null
		var cat := (adult_scene if big else scene).instantiate() as StreetCat
		cat.name = "Cat%d" % (i + 1)
		cat.life = self
		cat.look = i
		add_child(cat)
		var look: Dictionary = GameConfig.cat_looks[i]
		# je Katze eigene Material-Kopien (Kennung cat_<n>): das Fell malt auch Augen und Blinzeln dieser Katze
		var fur := "Katze Fell groß" if big else "Katze Fell"
		cat.apply_look("cat_%d" % i, {fur: look.fur},
			{fur: {"tabby": float(look.get("tabby", 0.0)), "tabby_color": look.get("tabby_color", Color.WHITE),
				"second_color": look.fur2, "third_color": look.get("back", look.fur), "mask_from": float(look.get("patches", 0.55)),
				"mask_soft": 0.3, "eye_color": look.eye}})
		cat.scale = Vector3.ONE * float(look.get("size", 1.0))
		cat.radius = (0.2 if big else 0.2) * cat.scale.x  # große Katzen sind größer gesetzt (size)
		cat.finished.connect(_on_finished)
		_pool.append(cat)


func _build_toys() -> void:
	for kind in TOYS:
		var scene := load(TOYS[kind]) as PackedScene
		if scene == null:
			continue
		var toy := scene.instantiate() as Node3D
		toy.name = "Toy_" + kind
		toy.set_meta("kind", kind)
		toy.set_meta("loose", false)
		add_child(toy)
		toy.visible = false
		_toys.append(toy)


# --- Ablauf ---

func step(delta: float) -> void:
	for cat in _cats.duplicate():
		cat.step(delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(GameConfig.cat_interval.x, GameConfig.cat_interval.y)
		_spawn()
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.4
		_look_around()


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
		# Fangen: die erste rennt ein Stück, wartet geduckt, rennt weiter; die zweite rennt hinterher
		var dir := signf(exit.s - start.s) if exit.s != start.s else 1.0
		var s1: float = start.s + dir * _rng.randf_range(5.0, 7.0)
		var s2: float = s1 + dir * _rng.randf_range(4.0, 6.0)
		actions.append(_walk_along(start.side, start.s, s1, GameConfig.cat_run_speed, true))
		actions.append({"type": "anim", "anim": "crouch", "time": _rng.randf_range(1.0, 1.8)})
		actions.append(_walk_along(start.side, s1, s2, GameConfig.cat_run_speed, true))
		actions.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 5.0)})
		actions.append_array(_visit(start.side, s2, exit))
	else:
		actions.append_array(_visit(start.side, start.s, exit))
	var toy := _free_toy()
	if toy and _rng.randf() < GameConfig.cat_toy_chance:
		leader.give_toy(toy)
	leader.set_meta("plays", 0)
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
		chaser.set_meta("plays", 0)
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
		_store_toy(toy)
	cat.reset()
	_cats.erase(cat)
	_pool.append(cat)


## Jemand versperrt den Weg: draußen in einem kleinen Bogen zur Straße hin außen herum; klappt das nicht
## (oder ist auch der Bogen versperrt), umkehren zum nächsten verdeckten Ende. Drinnen weiter warten.
func blocked(cat: StreetCat, dir: Vector3) -> void:
	if cat.inside:
		return
	if not bool(cat._action.get("detour", false)):
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
			var rest := cat.get_actions().duplicate()
			var walk := cat._action.duplicate()
			var path := PackedVector3Array([cat.global_position, p1, p2, p3])
			var actions: Array[Dictionary] = [{"type": "walk", "points": path, "speed": GameConfig.cat_walk_speed, "detour": true}]
			var pts: PackedVector3Array = walk.get("points", PackedVector3Array())
			if not pts.is_empty():
				var best := 0
				for i in pts.size():
					if pts[i].distance_to(p3) < pts[best].distance_to(p3):
						best = i
				var tail := PackedVector3Array([p3])
				tail.append_array(pts.slice(best + 1))
				walk.points = tail
				actions.append(walk)
			actions.append_array(rest)
			cat.replace_actions(actions)
			return
	_release_claims(cat)
	_continue_visit(cat, true, dir)


## Vom jetzigen Ort aus weiter: vielleicht noch ein Halt, dann zu einem verdeckten Ende.
## blocked_dir: Dorthin ging es nicht weiter (jemand stand im Weg) – dann erst ein Stück zurück, weg von der Person
## (nicht seitlich zur Wand: dort steht oft gerade der, der vor dem Schaufenster wartet), dann umkehren.
func _continue_visit(cat: StreetCat, turn_back: bool = false, blocked_dir: Vector3 = Vector3.ZERO) -> void:
	var start := cat.global_position
	var actions: Array[Dictionary] = []
	if blocked_dir != Vector3.ZERO:
		var back := _step_back(cat, blocked_dir)
		if back != start:
			actions.append(_walk([start, back]))
			start = back
	var local := _outside.to_local(start)
	var lage := street.centerline.project(Vector2(local.x, local.z))
	var side := 1 if lage.y > 0.0 else -1
	var here := {"s": lage.x}
	var exit := _pick_end(here, blocked_dir if blocked_dir != Vector3.ZERO else (cat.global_basis.z if turn_back else Vector3.ZERO))
	if exit.is_empty():
		exit = _pick_end({})
	if exit.is_empty():
		return
	if blocked_dir == Vector3.ZERO:
		actions.append(_walk([start, _side_point(side, lage.x)]))
	actions.append_array(_visit(side, lage.x, exit, not turn_back))
	cat.replace_actions(actions)


## Ein Stück zurück, weg von dem, der im Weg steht (auf dem Gehweg, frei von Laternen und Kübeln); sonst bleibt die
## Katze, wo sie ist.
func _step_back(cat: StreetCat, blocked_dir: Vector3) -> Vector3:
	var flat := Vector3(blocked_dir.x, 0.0, blocked_dir.z).normalized()
	for dist in [0.8, 0.5]:
		var p := cat.global_position - flat * float(dist)
		var l := _outside.to_local(p)
		var lat := street.centerline.project(Vector2(l.x, l.z)).y
		if absf(lat) < GameConfig.street_width / 2.0 + 0.35 or not street.clear_of_static(Vector2(l.x, l.z), STATIC_GAP):
			continue
		return p
	return cat.global_position


## Fensterbank und Sitz wieder frei.
func _release_claims(cat: StreetCat) -> void:
	for sill in _sills:
		if sill.taken == cat:
			sill.taken = null
	for w in _walls:
		if w.taken == cat:
			w.taken = null
	cat._release_seat()
	for spot in get_tree().get_nodes_in_group(CAT_SPOT_GROUP):
		if spot.get_meta("occupant", null) == cat:
			spot.set_meta("occupant", null)


## Alle 0,4 s: Vögel am Boden in der Nähe (jagen) oder liegendes Spielzeug (spielen)?
func _look_around() -> void:
	_try_meet()
	for cat in _cats:
		if cat.inside or cat.get_action_type() != "walk" or cat.hunting or cat._action.get("run", false) \
				or cat._action.get("detour", false):
			continue
		if _try_hunt(cat):
			continue
		_try_toy(cat)


## Zwei Katzen begegnen sich (draußen auf demselben Gehweg, beide gerade unterwegs): aufeinander zu, Nase an Nase
## schnuppern, eine miaut – dann spielen sie Fangen, setzen sich zusammen oder gehen weiter.
func _try_meet() -> void:
	for key in _met.keys():
		_met[key] = float(_met[key]) - 0.4
		if float(_met[key]) <= 0.0:
			_met.erase(key)
	for i in _cats.size():
		for j in range(i + 1, _cats.size()):
			var a: StreetCat = _cats[i]
			var b: StreetCat = _cats[j]
			if not (_free_to_meet(a) and _free_to_meet(b)):
				continue
			var key := "%d_%d" % [a.get_instance_id(), b.get_instance_id()]
			if _met.has(key):
				continue
			var d := b.global_position - a.global_position
			d.y = 0.0
			if d.length() > GameConfig.cat_meet_distance or absf(b.global_position.y - a.global_position.y) > 0.1:
				continue
			var la := _outside.to_local(a.global_position)
			var lb := _outside.to_local(b.global_position)
			var side_a := signf(street.centerline.project(Vector2(la.x, la.z)).y)
			if side_a != signf(street.centerline.project(Vector2(lb.x, lb.z)).y):
				continue
			_met[key] = GameConfig.cat_meet_cooldown
			_meet(a, b, d.normalized())
			return


func _free_to_meet(cat: StreetCat) -> bool:
	if not (cat.active and not cat.inside and cat.on_ground() and not cat.hunting and not cat.has_toy()):
		return false
	if absf(cat.global_position.y - _outside.global_position.y) > 0.05 or cat._action.get("road", false):
		return false
	var type := cat.get_action_type()
	if type == "walk":
		return not cat._action.get("run", false) and not cat._action.get("detour", false) and not cat._action.has("anim")
	# eine sitzt oder schnuppert gerade, die andere kommt vorbei
	return type == "anim" and String(cat._action.get("anim", "")) in ["sit", "sniff", "groom", "idle"] and cat.posture != "lie"


func _meet(a: StreetCat, b: StreetCat, d: Vector3) -> void:
	_release_claims(a)
	_release_claims(b)
	var m := (a.global_position + b.global_position) / 2.0
	# Nase an Nase: jede so weit von der Mitte, wie ihre Nase vor ihr ist (große Katzen weiter)
	var pa := _ground_at(m - d * (a.nose_reach() + 0.02))
	var pb := _ground_at(m + d * (b.nose_reach() + 0.02))
	var sniff := _rng.randf_range(1.8, 3.0)
	var plan_a: Array[Dictionary] = [_walk([a.global_position, pa], 0.35), {"type": "turn", "face": d},
		{"type": "anim", "anim": "sniff", "time": sniff}]
	var plan_b: Array[Dictionary] = [_walk([b.global_position, pb], 0.35), {"type": "turn", "face": -d},
		{"type": "anim", "anim": "sniff", "time": sniff}]
	var greeter := a if _rng.randf() < 0.5 else b
	(plan_a if greeter == a else plan_b).append({"type": "call", "callable": func(c: StreetCat) -> void: c.meow()})
	var what := _rng.randf()
	if what < 0.45:
		# Fangen: eine rennt ein Stück davon, die andere hinterher (wie beim Auftauchen zu zweit)
		var runner := a if _rng.randf() < 0.5 else b
		var chaser := b if runner == a else a
		var l := _outside.to_local(runner.global_position)
		var lage := street.centerline.project(Vector2(l.x, l.z))
		var side := 1 if lage.y > 0.0 else -1
		var away := signf(street.centerline.direction_at(lage.x).dot(Vector2(d.x, d.z) * (1.0 if runner == b else -1.0)))
		if away == 0.0:
			away = 1.0
		var run_to := lage.x + away * _rng.randf_range(4.0, 7.0)
		var p_run := plan_a if runner == a else plan_b
		var p_chase := plan_b if runner == a else plan_a
		p_run.append({"type": "anim", "anim": "crouch", "time": 0.5})
		p_run.append(_walk_along(side, lage.x, run_to, GameConfig.cat_run_speed, true))
		p_run.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(1.5, 3.0)})
		p_chase.append({"type": "anim", "anim": "crouch", "time": 0.8})
		p_chase.append({"type": "follow", "cat": runner, "time": _rng.randf_range(3.5, 5.0), "distance": 0.45})
		p_chase.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(1.0, 2.5)})
	elif what < 0.8:
		# zusammen sitzen, eine putzt sich
		var face := _outside.to_global(Vector3.ZERO).direction_to(m)
		var lm := _outside.to_local(m)
		var nrm := street.centerline.normal_at(street.centerline.project(Vector2(lm.x, lm.z)).x)
		var to_street := -Vector3(nrm.x, 0.0, nrm.y) * signf(street.centerline.project(Vector2(lm.x, lm.z)).y)
		if to_street.length() < 0.5:
			to_street = face
		var t := _rng.randf_range(5.0, 10.0)
		for p in [plan_a, plan_b]:
			p.append({"type": "turn", "face": to_street.rotated(Vector3.UP, _rng.randf_range(-0.4, 0.4))})
			p.append({"type": "anim", "anim": "sit", "time": t * _rng.randf_range(0.6, 1.0)})
		plan_a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(2.0, 4.0)})
	for p in [plan_a, plan_b]:
		p.append({"type": "call", "callable": _continue_visit})
	a.replace_actions(plan_a)
	b.replace_actions(plan_b)
	meetings += 1


# --- Besuch planen ---

## Ein verdecktes Straßenende (Ort zum Erscheinen/Verschwinden der Passanten): { pos (x, z), s, side, place }.
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
		if _rng.randf() < GameConfig.cat_wall_chance:
			# Gartenmauer: hinauf, oben entlang (in Laufrichtung), am anderen Ende herunter
			var walls: Array[Dictionary] = []
			for w in _walls:
				if w.taken == null and minf(w.s_a, w.s_b) > lo + 0.5 and maxf(w.s_a, w.s_b) < hi - 0.5:
					walls.append(w)
			if not walls.is_empty():
				var w: Dictionary = walls[_rng.randi() % walls.size()]
				var forward := (float(w.s_b) - float(w.s_a)) * dir > 0.0
				plan.append({"kind": "wall", "s": w.s_a if forward else w.s_b, "s_end": w.s_b if forward else w.s_a,
					"side": w.side, "wall": w, "from_a": forward})
		if _rng.randf() < GameConfig.cat_rub_chance:
			# an einer Laterne, einem Kübel oder einer Bank reiben
			var rubs: Array[Dictionary] = []
			for o in _rub_spots:
				var lage := street.centerline.project(o.pos)
				if lage.x > lo + 1.0 and lage.x < hi - 1.0:
					rubs.append({"kind": "rub", "s": lage.x, "side": 1 if lage.y > 0.0 else -1, "obstacle": o})
			if StreetCat.debug:
				print("[Katzen] Reiben: %d Kandidaten (Platz an %d von %d Gegenständen)" % [rubs.size(), _rub_spots.size(),
					street.get_static_obstacles().size()])
			if not rubs.is_empty():
				plan.append(rubs[_rng.randi() % rubs.size()])
		if _rng.randf() < 0.5:
			plan.append({"kind": "pause", "s": s0 + dir * _rng.randf_range(3.0, 9.0), "side": side})
		if plan.is_empty():
			plan.append({"kind": "pause", "s": s0 + dir * _rng.randf_range(4.0, 9.0), "side": side})
		plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.s - b.s) * dir < 0.0)
		# nichts zwischen Anfang und Ende einer Mauer einplanen (die Katze ist dann oben)
		for w in plan.filter(func(x: Dictionary) -> bool: return x.kind == "wall"):
			plan.assign(plan.filter(func(x: Dictionary) -> bool:
				return x == w or (x.s - w.s) * dir <= 0.0 or (x.s - w.s_end) * dir >= 0.0))
	var actions: Array[Dictionary] = []
	var cur_side := side
	var cur_s := s0
	for stop in plan:
		if stop.side != cur_side:
			actions.append_array(_leg(cur_side, cur_s, stop.s))
			actions.append_array(_cross(cur_side, stop.s))
			cur_side = stop.side
			cur_s = stop.s
		actions.append_array(_leg(cur_side, cur_s, stop.s))
		cur_s = stop.s
		actions.append_array(_stop_actions(stop, _side_point(cur_side, cur_s)))
		cur_s = float(stop.get("s_end", stop.s))
		if _rng.randf() < 0.3:
			actions.append(_pause())
	if exit.side != cur_side:
		var cross_s: float = cur_s + (exit.s - cur_s) * 0.3
		actions.append(_walk_along(cur_side, cur_s, cross_s))
		actions.append_array(_cross(cur_side, cross_s))
		cur_side = exit.side
		cur_s = cross_s
	actions.append_array(_leg(cur_side, cur_s, exit.s))
	actions.append(_walk([_side_point(cur_side, exit.s), _ground(exit.pos)]))
	actions.append({"type": "leave"})
	return actions


## Kurze Pause: schnuppern, sitzen, putzen oder strecken.
func _pause() -> Dictionary:
	if _rng.randf() < GameConfig.cat_roll_chance:
		return {"type": "anim", "anim": "roll", "time": 0.0}     # hinlegen, auf den Rücken rollen, wälzen
	var roll := _rng.randf()
	if roll < 0.35:
		return {"type": "anim", "anim": "sniff", "time": _rng.randf_range(1.5, 3.5)}
	if roll < 0.6:
		return {"type": "anim", "anim": "sit", "time": _rng.randf_range(2.0, 5.0)}
	if roll < 0.85:
		return {"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 6.0)}
	return {"type": "anim", "anim": "stretch", "time": 0.0}


## Reiben: ein Bogen dicht um das Hindernis (Laterne, Kübel, Bank) – die Katze drückt die Flanke daran, Kopf voran.
## Rundherum geprüft (24 Stellen): nur auf dem Gehweg (bis an den Bordstein, nie auf die Fahrbahn, nicht in die Wand),
## frei von anderen Hindernissen (überlappende Kreise gehören zum selben Gegenstand). Beginnt an der freien Stelle
## nächst der Katze und läuft in die Richtung mit mehr Platz. Liefert {points, anim} („rub“ = Gegenstand links,
## „rub_r“ = rechts) oder ein leeres Dictionary.
func _rub_arc(o: Dictionary, back: Vector3, side: int) -> Dictionary:
	var samples := _rub_samples(o, side)
	var pts: Array = samples.points
	var ok: Array = samples.ok
	const N := 24
	var start := -1
	for k in N:
		if ok[k] and (start < 0 or pts[k].distance_to(back) < pts[start].distance_to(back)):
			start = k
	if start < 0:
		return {}
	var want := _rng.randi_range(6, 13)
	var down := PackedVector3Array()
	var up := PackedVector3Array()
	for step in want:
		var k := posmod(start - step, N)
		if not ok[k]:
			break
		down.append(pts[k])
	for step in want:
		var k := posmod(start + step, N)
		if not ok[k]:
			break
		up.append(pts[k])
	# abnehmender Winkel = Gegenstand links (siehe animal_cat_anim.anim_rub), zunehmender = rechts
	if down.size() >= up.size():
		return {"points": down, "anim": "rub"} if down.size() >= 4 else {}
	return {"points": up, "anim": "rub_r"} if up.size() >= 4 else {}


## 24 Stellen rund um ein Hindernis (Abstand zum Rand 0,11 m): {points, ok} – ok = auf dem Gehweg (bis an den
## Bordstein, nicht in die Wand) und frei von anderen Gegenständen (überlappende Kreise = derselbe Gegenstand).
func _rub_samples(o: Dictionary, side: int) -> Dictionary:
	var c := _ground(o.pos)
	var r := float(o.radius) + 0.11
	var band := _route(side).band_at(street.centerline.project(o.pos).x)
	var lat_lo := band.x - 0.4 if side > 0 else band.x - 0.04
	var lat_hi := band.y + 0.04 if side > 0 else band.y + 0.4
	var others: Array[Dictionary] = []
	for other in street.get_static_obstacles():
		if other != o and (other.pos as Vector2).distance_to(o.pos) > float(other.radius) + float(o.radius):
			others.append(other)
	var pts: Array[Vector3] = []
	var ok: Array[bool] = []
	for k in 24:
		var th := TAU * float(k) / 24.0
		var p := c + Vector3(cos(th), 0.0, sin(th)) * r
		var l := _outside.to_local(p)
		var lat := street.centerline.project(Vector2(l.x, l.z)).y
		var free := absf(lat) > GameConfig.street_width / 2.0 + 0.18 and lat > lat_lo and lat < lat_hi
		for other in others:
			if Vector2(l.x, l.z).distance_to(other.pos) < float(other.radius) + 0.09:
				free = false
		pts.append(_ground_at(p))
		ok.append(free)
	return {"points": pts, "ok": ok}


## Mauer belegen (immer nur eine Katze oben).
func _claim_wall(cat: StreetCat, w: Dictionary) -> bool:
	if w.taken != null and w.taken != cat:
		return false
	w.taken = cat
	return true


## Hinauf auf einen Platz und wieder herunter: vorher zur Landestelle drehen, dann vorwärts springen.
func _jump_on(a: Array[Dictionary], ground: Vector3, top: Vector3) -> void:
	a.append({"type": "turn", "face": top - ground})
	a.append({"type": "jump", "to": top})


func _jump_off(a: Array[Dictionary], top: Vector3, ground: Vector3) -> void:
	a.append({"type": "turn", "face": ground - top})
	a.append({"type": "jump", "to": ground})


## Schritte für einen Halt; beginnt und endet am Punkt back auf dem Gehweg.
func _stop_actions(stop: Dictionary, back: Vector3) -> Array[Dictionary]:
	var a: Array[Dictionary] = []
	var rest := _rng.randf_range(GameConfig.cat_rest_time.x, GameConfig.cat_rest_time.y)
	match String(stop.kind):
		"wall":
			var w: Dictionary = stop.wall
			var p0: Vector3 = w.a if stop.from_a else w.b
			var p1: Vector3 = w.b if stop.from_a else w.a
			var out: Vector3 = w.out
			var ground0 := _ground_at(p0 + out * 0.45)
			var ground1 := _ground_at(p1 + out * 0.45)
			a.append(_walk([back, ground0]))
			a.append({"type": "claim", "callable": func(cat: StreetCat) -> bool:
				var ok := _claim_wall(cat, w)
				if ok:
					wall_walks += 1
				return ok})
			_jump_on(a, ground0, p0)
			a.append({"type": "turn", "face": p1 - p0})
			var mid := p0.lerp(p1, _rng.randf_range(0.35, 0.65))
			a.append(_walk([p0, mid], GameConfig.cat_wall_speed))
			var what := _rng.randf()
			if what < 0.45:
				a.append({"type": "turn", "face": out.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))})
				a.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(3.0, 7.0)})
			elif what < 0.7:
				a.append({"type": "anim", "anim": "lie", "time": rest * 0.5})     # in der Sonne auf der Mauer
			elif what < 0.85:
				a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 5.0)})
			a.append({"type": "turn", "face": p1 - mid})
			a.append(_walk([mid, p1], GameConfig.cat_wall_speed))
			_jump_off(a, p1, ground1)
			a.append({"type": "call", "callable": func(_c: StreetCat) -> void: w.taken = null})
			a.append({"type": "claim_end"})
			var s_end := float(stop.s_end)
			a.append(_walk([ground1, _side_point(int(stop.side), s_end)]))
		"rub":
			var rub := _rub_arc(stop.obstacle, back, int(stop.side))
			if StreetCat.debug:
				print("[Katzen] Reiben an %s (r %.2f): %s" % [stop.obstacle.pos, float(stop.obstacle.radius),
					"Bogen mit %d Punkten" % (rub.points as PackedVector3Array).size() if not rub.is_empty() else "kein Platz"])
			if not rub.is_empty():
				var arc: PackedVector3Array = rub.points
				a.append(_walk([back, arc[0]]))
				a.append({"type": "purr_on"})
				a.append({"type": "call", "callable": func(_c: StreetCat) -> void: rubs += 1})
				a.append({"type": "walk", "points": arc, "speed": GameConfig.cat_rub_speed, "anim": rub.anim})
				a.append({"type": "purr_off"})
				a.append(_walk([arc[-1], _side_point(int(stop.side), float(stop.s))]))
		"seat":
			var e: Dictionary = stop.entry
			var seat: SeatPoint = e.seat
			var approach := _ground(e.approach)
			var face := Vector3(e.face.x, 0.0, e.face.y)
			a.append(_walk([back, approach]))
			a.append({"type": "claim", "callable": func(cat: StreetCat) -> bool: return _claim_seat(cat, seat)})
			_jump_on(a, approach, seat.global_position)
			a.append({"type": "rest_on", "node": seat})
			a.append({"type": "turn", "face": face})
			a.append({"type": "toy_drop"})
			a.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(3.0, 6.0)})
			a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(4.0, 7.0)})
			# auf einer Bank zum Liegen längs drehen (sonst ragt sie in die Lehne)
			var along := _bench_along(seat)
			if along != Vector3.ZERO:
				a.append({"type": "turn", "face": along})
			a.append({"type": "anim", "anim": "lie" if _rng.randf() < 0.4 else "sleep", "time": rest})
			a.append({"type": "anim", "anim": "sit", "time": 1.5})
			a.append({"type": "toy_take"})
			a.append({"type": "rest_off"})
			_jump_off(a, seat.global_position, approach + face * 0.1)
			a.append({"type": "release_seat"})
			a.append({"type": "claim_end"})
			a.append(_walk([approach + face * 0.1, back]))
		"sill":
			var sill: Dictionary = stop.sill
			var out: Vector3 = sill.out
			var front: Vector3 = _ground_at(sill.pos + out * 0.45)
			a.append(_walk([back, front]))
			a.append({"type": "claim", "callable": func(cat: StreetCat) -> bool: return _claim_sill(cat, sill)})
			_jump_on(a, front, sill.pos)
			a.append({"type": "turn", "face": out.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))})
			a.append({"type": "toy_drop"})
			a.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(3.0, 6.0)})
			a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 6.0)})
			a.append({"type": "anim", "anim": "lie", "time": rest * 0.7})
			a.append({"type": "toy_take"})
			_jump_off(a, sill.pos, front + out * 0.15)
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
			a.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(10.0, 20.0), "face": face, "look_up": true})
			if _rng.randf() < 0.5:
				a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(3.0, 5.0), "face": face})
			a.append(_walk([spot, back]))
		"door":
			var entrance := _ground(StreetPaths.library_entrance())
			a.append(_walk([back, entrance]))
			a.append({"type": "turn", "face": -StreetLayout.door_outward()})
			a.append({"type": "call", "callable": func(cat: StreetCat) -> void: _door_choice(cat)})
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


func _claim_basket(cat: StreetCat, spot: Node3D) -> bool:
	if not is_instance_valid(spot) or spot.get_meta("occupant", null) not in [null, cat]:
		return false
	spot.set_meta("occupant", cat)
	return true


## Bank (mehrere Sitzplätze nebeneinander): Richtung längs der Bank (zufällig links/rechts), sonst null.
func _bench_along(seat: SeatPoint) -> Vector3:
	var parent := seat.get_parent()
	var count := 0
	for child in parent.get_children():
		if child is SeatPoint:
			count += 1
	if count < 2:
		return Vector3.ZERO
	var along := seat.global_basis.x
	along.y = 0.0
	return along.normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)


## Vor der Treppe der Bücherei: hinaufhüpfen; Tür offen → hinein; zu → seitlich unter dem Einwurf warten
## (außerhalb des Schwenkbereichs), dann hinein; sonst nach einer Weile wieder hinunter.
func _door_choice(cat: StreetCat) -> void:
	var inside := _inside_target(cat)
	if inside.is_empty():
		return
	entered += 1
	cat.insert_actions(_inside_actions(cat, inside))


# --- Wege draußen ---

func _route(side: int) -> StreetRoute:
	return street.sidewalks[side]


## Gehweg-Punkt (Welt) an der Stelle s; lat_share 0 = an der Hauswand, 1 = mitten auf dem Gehweg. Hält Abstand zu
## Laternen, Bänken und der Treppe.
func _side_point(side: int, s: float, lat_share: float = 0.0, gap: float = STATIC_GAP) -> Vector3:
	var route := _route(side)
	var band := route.band_at(s)
	var comfort := route.comfort_at(s)
	var wall := band.y + WALL_GAP if side > 0 else band.x - WALL_GAP
	var mid := (comfort.x + comfort.y) / 2.0
	var lat := lerpf(wall, mid, clampf(lat_share, 0.0, 1.0))
	var p := route.point_at(s, lat)
	for i in 14:
		if street.clear_of_static(p, gap):
			break
		lat -= side * 0.1
		p = route.point_at(s, lat)
	return _ground(p)


## Freier Gang: mal an der Wand, mal mitten auf dem Gehweg, in sanften Bögen (Lage folgt einer weichen Welle).
func _walk_along(side: int, s0: float, s1: float, speed: float = -1.0, run: bool = false) -> Dictionary:
	var points := PackedVector3Array()
	var n := maxi(1, int(absf(s1 - s0) / 0.4))
	var phase := _rng.randf() * TAU
	var freq := _rng.randf_range(0.18, 0.45)
	var base := _rng.randf_range(0.0, 0.45)
	for i in n + 1:
		var s := lerpf(s0, s1, float(i) / n)
		var wave := 0.5 + 0.5 * sin(phase + s * freq * TAU / 4.0)
		var share := clampf(base + wave * 0.6, 0.0, 0.85)
		# Anfang und Ende an der Wand (dort schließen die nächsten Schritte an)
		var edge := minf(float(i), float(n - i)) / 3.0
		# zwischen Deko und Hauswand hindurch, wenn genug Platz bleibt (DECO_GAP statt des großen Abstands)
		points.append(_side_point(side, s, share * clampf(edge, 0.0, 1.0), DECO_GAP))
	# Strecken zwischen den Punkten dürfen nicht durch Kübel/Laternen gehen: sonst dort einen Punkt außen herum
	var fixed := PackedVector3Array()
	for i in points.size():
		if i > 0:
			var m := (points[i - 1] + points[i]) / 2.0
			var l := _outside.to_local(m)
			if not street.clear_of_static(Vector2(l.x, l.z), DECO_GAP * 0.8):
				var ms := street.centerline.project(Vector2(l.x, l.z)).x
				fixed.append(_side_point(side, ms, 0.0, STATIC_GAP))
		fixed.append(points[i])
	return {"type": "walk", "points": fixed, "speed": speed if speed > 0.0 else GameConfig.cat_walk_speed, "run": run}


## Ein Stück am Gehweg entlang – manchmal mit einem kurzen Rennen in der Mitte (übermütig, seit Etappe 6h).
func _leg(side: int, s0: float, s1: float) -> Array[Dictionary]:
	var a: Array[Dictionary] = []
	if absf(s1 - s0) > 6.0 and _rng.randf() < GameConfig.cat_run_chance:
		var k0 := lerpf(s0, s1, _rng.randf_range(0.15, 0.4))
		var k1 := k0 + signf(s1 - s0) * _rng.randf_range(2.5, 5.0)
		if absf(k1 - s0) < absf(s1 - s0) - 0.5:
			a.append(_walk_along(side, s0, k0))
			a.append(_walk_along(side, k0, k1, GameConfig.cat_run_speed, true))
			a.append(_walk_along(side, k1, s1))
			return a
	a.append(_walk_along(side, s0, s1))
	return a


func _walk(list: Array, speed: float = -1.0) -> Dictionary:
	var points := PackedVector3Array()
	for p: Vector3 in list:
		points.append(p)
	return {"type": "walk", "points": points, "speed": speed if speed > 0.0 else GameConfig.cat_walk_speed}


## Über die Straße: zur Bordsteinkante, warten bis frei, hinunter auf die Fahrbahn (Fahrbahnhöhe), zügig hinüber,
## am anderen Bordstein hinauf, ein Stück auf den Gehweg.
func _cross(side: int, s: float) -> Array[Dictionary]:
	var half := GameConfig.street_width / 2.0
	var a := _side_point(side, s)
	var curb_a := _lane(s, side * (half + 0.14), 0.0)
	var road_a := _lane(s, side * (half - 0.16), _road_y())
	var road_b := _lane(s, -side * (half - 0.16), _road_y())
	var curb_b := _lane(s, -side * (half + 0.14), 0.0)
	var b := _side_point(-side, s)
	var out: Array[Dictionary] = [_walk([a, curb_a])]
	out.append({"type": "turn", "face": road_a - curb_a})
	out.append({"type": "wait_road", "face": road_a - curb_a})
	out.append({"type": "jump", "to": road_a})
	var run := {"type": "walk", "points": PackedVector3Array([road_a, road_b]), "speed": GameConfig.cat_run_speed * 0.8,
		"run": true, "road": true}
	out.append(run)
	out.append({"type": "jump", "to": curb_b})
	out.append(_walk([curb_b, b]))
	return out


func _lane(s: float, lat: float, height: float) -> Vector3:
	var p := street.centerline.point_at(s, lat)
	return _outside.to_global(Vector3(p.x, height, p.y))


## Höhe der Fahrbahn unter "Outside" (Gehweg = 0).
func _road_y() -> float:
	return StreetLayout.road_y() - StreetLayout.ground_y()


func _ground(p: Variant) -> Vector3:
	if p is Vector2:
		return _outside.to_global(Vector3(p.x, 0.0, p.y))
	return p as Vector3


func _ground_at(p: Vector3) -> Vector3:
	return Vector3(p.x, _outside.global_position.y, p.z)


# --- Jagd auf Vögel ---

## Vögel am Boden in der Nähe und auf demselben Gehweg? Dann lauern, anschleichen, springen (Vögel fliegen weg).
func _try_hunt(cat: StreetCat) -> bool:
	if street.birds == null:
		return false
	for bird in street.birds.get_birds():
		if not bird.is_on_ground() or bird.flock.is_empty():
			continue
		var flock: Dictionary = bird.flock
		var key := "%d_%d" % [int(flock.get("id", 0)), cat.get_instance_id()]
		if _hunted.has(key):
			continue
		var center: Vector3 = bird.spot.get("center", bird.global_position)
		var d := Vector3(center.x - cat.global_position.x, 0.0, center.z - cat.global_position.z)
		if d.length() > 8.0 or d.length() < 2.6 or absf(center.y - cat.global_position.y) > 0.3:
			continue
		_hunted[key] = true
		if _rng.randf() > GameConfig.cat_hunt_chance:
			continue
		var dir := d.normalized()
		var ground_y := cat.global_position.y
		var a := center - dir * 3.0
		var b := center - dir * 1.3
		var c := center - dir * 0.25
		# nur auf dem Gehweg jagen (nie auf die Fahrbahn)
		var on_road := false
		for p: Vector3 in [a, b, c]:
			var l := _outside.to_local(p)
			if absf(street.centerline.project(Vector2(l.x, l.z)).y) < GameConfig.street_width / 2.0 + 0.25:
				on_road = true
		if on_road:
			continue
		a.y = ground_y
		b.y = ground_y
		c.y = ground_y
		var actions: Array[Dictionary] = []
		if cat.has_toy():
			actions.append({"type": "toy_drop"})
		actions.append(_walk([cat.global_position, a]))
		actions.append({"type": "hunting", "value": true})
		actions.append({"type": "turn", "face": dir})
		# Lauern, Anschleichen und Sprung merken sich ihren Schwarm: Sind die Vögel weg, bricht die Katze ab (kein
		# Sprung ins Leere) und schaut ihnen nach (siehe prey_gone, StreetCat._abort_hunt)
		actions.append({"type": "anim", "anim": "crouch", "time": _rng.randf_range(2.0, 3.5), "hunt": true, "prey": flock,
			"prey_at": center})
		actions.append({"type": "walk", "points": PackedVector3Array([a, b]), "speed": GameConfig.cat_stalk_speed, "stalk": true,
			"prey": flock, "prey_at": center})
		actions.append({"type": "anim", "anim": "crouch", "time": _rng.randf_range(0.6, 1.4), "hunt": true, "prey": flock,
			"prey_at": center})
		actions.append({"type": "pounce", "to": c, "hunt": true, "prey": flock, "prey_at": center})
		actions.append({"type": "hunting", "value": false})
		actions.append({"type": "anim", "anim": "sit", "time": 2.5, "look_up": true})
		actions.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(2.5, 4.0)})
		actions.append({"type": "toy_take"})
		actions.append({"type": "call", "callable": _continue_visit})
		cat.replace_actions(actions)
		hunts += 1
		return true
	return false


## Sind die Vögel, auf die eine Katze lauert, schon weg (keiner mehr am Boden nahe der Stelle)?
func prey_gone(action: Dictionary) -> bool:
	var flock: Dictionary = action.get("prey", {})
	if flock.is_empty():
		return false
	var at: Vector3 = action.get("prey_at", Vector3.ZERO)
	for b in flock.get("birds", []):
		var bird := b as StreetBird
		if is_instance_valid(bird) and bird.is_on_ground() and bird.global_position.distance_to(at) < 3.0:
			return false
	return true


# --- Spielzeug ---

func _free_toy() -> Node3D:
	var free := _toys.filter(func(t: Node3D) -> bool: return not t.visible)
	return free[_rng.randi() % free.size()] if not free.is_empty() else null


func _store_toy(toy: Node3D) -> void:
	if toy.get_parent() != self:
		if toy.get_parent():
			toy.get_parent().remove_child(toy)
		add_child(toy)
	toy.visible = false
	toy.set_meta("loose", false)


## Spielzeug ablegen (aus dem Maul): liegt dann frei in der Welt (auch für andere Katzen).
func drop_toy(_cat: StreetCat, toy: Node3D, at: Vector3) -> void:
	toy.set_meta("left_by", _cat)
	if toy.get_parent() != self:
		if toy.get_parent():
			toy.get_parent().remove_child(toy)
		add_child(toy)
	toy.visible = true
	var ground := Vector3(at.x, _cat.global_position.y + 0.015, at.z)
	toy.global_transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), ground)
	toy.set_meta("loose", true)


func pick_toy(cat: StreetCat, toy: Node3D) -> void:
	toy.set_meta("left_by", null)
	if _toy_tweens.has(toy):
		(_toy_tweens[toy] as Tween).kill()
		_toy_tweens.erase(toy)
	toy.set_meta("loose", false)
	cat.give_toy(toy)


## Liegendes Spielzeug in der Nähe der Katze (oder null).
func toy_near(cat: StreetCat, reach: float = 0.7) -> Node3D:
	for toy in _toys:
		if toy.visible and toy.get_meta("loose", false) and toy.global_position.distance_to(cat.global_position) < reach:
			return toy
	return null


## Angestupstes Spielzeug rollt (Ball, Wollknäuel) bzw. rutscht (Maus, Federn) ein Stück – nie in Wände, auf die
## Fahrbahn oder in Hindernisse.
func push_toy(toy: Node3D, dir: Vector3, strength: float) -> void:
	dir.y = 0.0
	dir = dir.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	var kind := String(toy.get_meta("kind", "mouse"))
	var rolls := kind in ["ball", "yarn"]
	var dist := _rng.randf_range(0.35, 0.9) * strength * (1.6 if rolls else 1.0)
	var start := toy.global_position
	var space := get_world_3d().direct_space_state
	var want := dist
	# an einer Wand: zur Seite (oder zurück) statt in die Wand
	for turn in [0.0, 1.4, -1.4, PI]:
		var d := dir.rotated(Vector3.UP, turn)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3.UP * 0.03, start + Vector3.UP * 0.03 + d * (want + 0.05), 1 | 8))
		dist = want if hit.is_empty() else maxf(0.0, start.distance_to(hit.position) - 0.06)
		if dist > want * 0.5:
			dir = d
			break
	var end := start + dir * dist
	var l := _outside.to_local(end)
	if not toy_inside(toy):
		var lat := street.centerline.project(Vector2(l.x, l.z)).y
		if absf(lat) < GameConfig.street_width / 2.0 + 0.2 or not street.clear_of_static(Vector2(l.x, l.z), 0.1):
			end = start + dir * dist * 0.3
	if _toy_tweens.has(toy):
		(_toy_tweens[toy] as Tween).kill()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var time := 0.45 + dist * 0.6
	tween.tween_property(toy, "global_position", end, time)
	if rolls:
		var axis := Vector3.UP.cross(dir).normalized()
		var turns := dist / 0.045
		var base := toy.global_basis
		tween.parallel().tween_method(func(k: float) -> void:
			if is_instance_valid(toy):
				toy.global_basis = Basis(axis, k * turns) * base, 0.0, 1.0, time)
	_toy_tweens[toy] = tween


func toy_inside(toy: Node3D) -> bool:
	return _room != null and _room.is_inside_build_area(toy.global_position) and absf(toy.global_position.y - floor_y_room()) < 0.6


func floor_y_room() -> float:
	return _room.global_position.y + _room.floor_height if _room else 0.0


## Spielen: anstupsen, hinterher, draufspringen – ein paar Runden, dann mitnehmen oder liegen lassen.
func _play_actions(cat: StreetCat, toy: Node3D, rounds: int) -> Array[Dictionary]:
	var a: Array[Dictionary] = []
	a.append({"type": "call", "callable": func(c: StreetCat) -> void: _play_round(c, toy, rounds)})
	return a


func _play_round(cat: StreetCat, toy: Node3D, rounds: int) -> void:
	if not is_instance_valid(toy) or not toy.visible:
		return
	var a: Array[Dictionary] = []
	var to_toy := toy.global_position - cat.global_position
	to_toy.y = 0.0
	if to_toy.length() > 0.32:
		# hinterher (rennen, wenn es weit gerollt ist)
		var stop := toy.global_position - to_toy.normalized() * 0.24
		stop.y = cat.global_position.y
		if to_toy.length() > 0.9 and _rng.randf() < 0.5:
			a.append({"type": "turn", "face": to_toy})
			a.append({"type": "anim", "anim": "crouch", "time": _rng.randf_range(0.5, 1.2)})
			var land := toy.global_position - to_toy.normalized() * 0.12
			land.y = cat.global_position.y
			a.append({"type": "pounce", "to": land})
		else:
			a.append(_walk([cat.global_position, stop], GameConfig.cat_run_speed * 0.7 if to_toy.length() > 0.8 else -1.0))
	a.append({"type": "bat", "toy": toy, "strength": _rng.randf_range(0.5, 1.1)})
	if rounds > 1:
		a.append({"type": "call", "callable": func(c: StreetCat) -> void: _play_round(c, toy, rounds - 1)})
	else:
		a.append({"type": "call", "callable": func(c: StreetCat) -> void: _end_play(c, toy)})
	cat.insert_actions(a)


func _end_play(cat: StreetCat, toy: Node3D) -> void:
	if not is_instance_valid(toy) or not toy.visible:
		return
	var a: Array[Dictionary] = []
	if _rng.randf() < 0.55:
		# mitnehmen
		var stop := toy.global_position
		stop.y = cat.global_position.y
		a.append(_walk([cat.global_position, stop + (cat.global_position - stop).normalized() * 0.18]))
		a.append({"type": "toy_take", "toy": toy})
	else:
		a.append({"type": "anim", "anim": "sit", "time": _rng.randf_range(1.5, 3.0)})
		a.append({"type": "anim", "anim": "groom", "time": _rng.randf_range(2.0, 4.0)})
	if not cat.inside:
		a.append({"type": "call", "callable": _continue_visit})
	cat.insert_actions(a)


## Liegendes Spielzeug in Sicht? Hingehen, schnuppern, spielen. Trägt die Katze selbst etwas, lässt sie es manchmal
## an einer Hauswand oder Laterne liegen.
func _try_toy(cat: StreetCat) -> void:
	if cat.has_toy():
		# Wahrscheinlichkeit je Minute → je Blick (alle 0,4 s)
		if _rng.randf() < GameConfig.cat_toy_leave_chance * 0.4 / 60.0:
			_leave_toy(cat)
		return
	if int(cat.get_meta("plays", 0)) >= 2:
		return   # höchstens zweimal je Besuch spielen
	for toy in _toys:
		if not toy.visible or not toy.get_meta("loose", false) or toy_inside(toy):
			continue
		if toy.get_meta("left_by", null) == cat:
			continue   # das eigene, gerade liegen gelassene Spielzeug nicht gleich wieder holen
		var d := toy.global_position - cat.global_position
		d.y = 0.0
		if d.length() > 3.5 or d.length() < 0.2 or absf(toy.global_position.y - cat.global_position.y) > 0.3:
			continue
		var stop := toy.global_position - d.normalized() * 0.24
		stop.y = cat.global_position.y
		var a: Array[Dictionary] = [_walk([cat.global_position, stop])]
		a.append({"type": "turn", "face": d})
		a.append({"type": "anim", "anim": "sniff", "time": _rng.randf_range(1.2, 2.5)})
		a.append_array(_play_actions(cat, toy, _rng.randi_range(2, 4)))
		cat.replace_actions(a)
		cat.set_meta("plays", int(cat.get_meta("plays", 0)) + 1)
		plays += 1
		return


## Spielzeug an der Hauswand oder am Fuß einer Laterne liegen lassen (bleibt dort, bis eine Katze es findet).
func _leave_toy(cat: StreetCat) -> void:
	var local := _outside.to_local(cat.global_position)
	var lage := street.centerline.project(Vector2(local.x, local.z))
	var side := 1 if lage.y > 0.0 else -1
	var spot := _side_point(side, lage.x + cat.global_basis.z.dot(Vector3(1, 0, 0)) * 0.5, 0.0)
	var a: Array[Dictionary] = [_walk([cat.global_position, spot])]
	a.append({"type": "toy_drop"})
	a.append({"type": "anim", "anim": "sniff", "time": 1.5})
	a.append({"type": "call", "callable": _continue_visit})
	cat.replace_actions(a)


# --- In der Bücherei ---

## Hinein (Stufen hinaufhüpfen, an der Tür warten, wenn sie zu ist), ins Körbchen bzw. auf Sessel/Sofa/Teppich,
## schlafen und schnurren, wieder hinaus (drinnen neben der Tür warten, wenn sie zu ist), Stufen hinab.
func _inside_actions(cat: StreetCat, target: Dictionary) -> Array[Dictionary]:
	var door := StreetLayout.door_center()
	var out := StreetLayout.door_outward()
	var room_y := floor_y_room()
	var door_point := Vector3(door.x, room_y, door.z)
	var door_in := door_point - out * 0.6
	var grid := _room_grid()
	var path := _find_path(grid, door_in, target.front)
	if path.is_empty():
		return []
	var a: Array[Dictionary] = []
	a.append_array(_stairs(door_point, out, room_y, true, cat.adult))
	var wait_out := _wait_spot(false)
	a.append(_walk([_podium_point(door_point, out), wait_out]))
	a.append({"type": "wait_door", "face": door_point - wait_out})
	a.append(_walk([wait_out, door_point + out * 0.15]))
	a.append({"type": "inside", "value": true})
	var walk_in: Array = [door_point + out * 0.15]
	walk_in.append_array(_threshold(door_point, out, true))
	walk_in.append(door_in)
	walk_in.append_array(path)
	a.append(_walk(walk_in))
	var rest := _rng.randf_range(GameConfig.cat_inside_time.x, GameConfig.cat_inside_time.y)
	var top: Vector3 = target.top
	var face: Vector3 = target.face
	a.append({"type": "claim", "callable": target.claim})
	_jump_on(a, target.front, top)
	if target.has("node"):
		a.append({"type": "rest_on", "node": target.node})
	a.append({"type": "turn", "face": face})
	a.append({"type": "toy_drop"})
	a.append({"type": "anim", "anim": "lie", "time": _rng.randf_range(4.0, 8.0)})
	a.append({"type": "purr_on"})
	a.append({"type": "anim", "anim": "sleep", "time": rest})
	a.append({"type": "purr_off"})
	a.append({"type": "anim", "anim": "sit", "time": 2.0})
	a.append({"type": "toy_take"})
	a.append({"type": "rest_off"})
	_jump_off(a, top, target.front)
	a.append({"type": "release_seat"})
	a.append({"type": "call", "callable": func(c: StreetCat) -> void: _release_claims(c)})
	a.append({"type": "claim_end"})
	var walk_out: Array = path.duplicate()
	walk_out.reverse()
	var wait_in := _wait_spot(true)
	walk_out.append(wait_in)
	a.append(_walk(walk_out))
	a.append({"type": "wait_door", "face": door_point - wait_in})
	var walk_back: Array = [wait_in, door_in]
	walk_back.append_array(_threshold(door_point, out, false))
	walk_back.append(door_point + out * 0.15)
	a.append(_walk(walk_back))
	a.append({"type": "inside", "value": false})
	a.append_array(_stairs(door_point, out, room_y, false, cat.adult))
	return a


## Über die Türschwelle (der untere Rahmen der Türöffnung, FacadeLayout.CASING hoch, von 0,23 m innen bis 0,07 m
## außen vor der Wand): hinauf, darüber, hinunter – nie hindurch.
func _threshold(door_point: Vector3, out: Vector3, going_in: bool) -> Array:
	var top := Vector3.UP * (FacadeLayout.CASING + 0.006)
	var pts := [door_point + out * 0.115, door_point + out * 0.075 + top, door_point - out * 0.235 + top,
		door_point - out * 0.275]
	if not going_in:
		pts.reverse()
	return pts


func _podium_point(door_point: Vector3, out: Vector3) -> Vector3:
	return door_point + out * (GameConfig.entrance_podium_depth * 0.55)


## Warteplatz an der Tür: draußen auf dem Podest seitlich unter dem Einwurf, drinnen neben der Tür – immer
## außerhalb des Schwenkbereichs der Tür (die Tür geht nach innen auf).
func _wait_spot(inside_room: bool) -> Vector3:
	var door := StreetLayout.door_center()
	var out := StreetLayout.door_outward()
	var room_y := floor_y_room()
	var door_point := Vector3(door.x, room_y, door.z)
	var along := Vector3.UP.cross(out).normalized()
	var box := ReturnBox.find(get_tree())
	var side := 1.0
	if box:
		side = signf((box.global_position - door_point).dot(along))
		if side == 0.0:
			side = 1.0
	var candidates: Array[Vector3] = []
	if inside_room:
		for s in [side, -side]:
			for reach in [0.95, 1.2, 1.45]:
				candidates.append(door_point + along * s * reach - out * 0.35)
	else:
		for s in [side, -side]:
			for reach in [0.7, 0.55, 0.85]:
				candidates.append(door_point + along * s * reach + out * 0.3)
	for p in candidates:
		if _door and _door.in_swing(p + Vector3.UP * 0.1):
			continue
		if inside_room and _room and not _room.is_inside_build_area(p):
			continue
		return p
	return candidates[0]


## Treppe der Bücherei: an jeder Stufe hinaufhüpfen bzw. vorwärts hinuntersteigen.
func _stairs(door_point: Vector3, out: Vector3, room_y: float, up: bool, climb: bool = false) -> Array[Dictionary]:
	var count := GameConfig.entrance_step_count
	var tread := GameConfig.entrance_step_depth
	var rise := GameConfig.shop_floor_rise / float(count + 1)
	var podium := GameConfig.entrance_podium_depth
	var ground := room_y - GameConfig.shop_floor_rise
	var steps: Array = []    # [Punkt vor der Kante (unten), Punkt nach der Kante (oben)]
	for k in count + 1:
		var edge := podium + (count - k) * tread
		var below := ground + k * rise
		steps.append([door_point + out * (edge + 0.12) + Vector3.UP * (below - room_y),
			door_point + out * (edge - 0.1) + Vector3.UP * (below + rise - room_y)])
	var a: Array[Dictionary] = []
	var entrance := _ground(StreetPaths.library_entrance())
	if climb:
		# Große Katzen steigen Stufe für Stufe (ohne Hüpfen): vor jeder Kante unten, dahinter oben – im Gang
		var path: Array = [entrance]
		for st: Array in steps:
			path.append(st[0])
			path.append(st[1])
		path.append(_podium_point(door_point, out))
		if not up:
			path.reverse()
		a.append({"type": "turn", "face": (-out if up else out)})
		a.append(_walk(path, GameConfig.cat_stair_speed))
		return a
	if up:
		var last := entrance
		for st: Array in steps:
			a.append(_walk([last, st[0]]))
			a.append({"type": "turn", "face": -out})
			a.append({"type": "jump", "to": st[1]})
			last = st[1]
		a.append(_walk([last, _podium_point(door_point, out)]))
	else:
		var last := _podium_point(door_point, out)
		for i in range(steps.size() - 1, -1, -1):
			var st: Array = steps[i]
			a.append(_walk([last, st[1]]))
			a.append({"type": "turn", "face": out})
			a.append({"type": "jump", "to": st[0]})
			last = st[0]
		a.append(_walk([last, entrance]))
	return a


## Ziel in der Bücherei: ein freies Katzenkörbchen (bevorzugt), sonst ein freier Sitz eines Sessels oder Sofas,
## sonst die Mitte eines Teppichs. { top (Liegeplatz), front (Boden davor), face, claim, node }.
func _inside_target(cat: StreetCat = null) -> Dictionary:
	if _room == null or _door == null:
		return {}
	var room_y := floor_y_room()
	# Körbchen sind für die jungen Katzen gebaut – die großen nehmen Sessel, Sofa oder Teppich
	var baskets: Array[Node] = []
	if cat == null or not cat.adult:
		baskets = get_tree().get_nodes_in_group(CAT_SPOT_GROUP)
	for spot: Node3D in baskets:
		if not spot.is_inside_tree() or spot.get_meta("occupant", null) != null or not _room.is_ancestor_of(spot):
			continue
		var fwd := spot.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var front := Vector3(spot.global_position.x, room_y, spot.global_position.z) + fwd * 0.42
		return {"top": spot.global_position, "front": front, "face": -fwd.rotated(Vector3.UP, _rng.randf_range(-0.8, 0.8)),
			"node": spot, "claim": func(c: StreetCat) -> bool: return _claim_basket(c, spot)}
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
	for seat in seats:
		var forward := seat.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var front := Vector3(seat.global_position.x, room_y, seat.global_position.z) + forward * 0.5
		return {"top": seat.global_position, "front": front, "face": forward, "node": seat,
			"claim": func(c: StreetCat) -> bool: return _claim_seat(c, seat)}
	if not rugs.is_empty():
		var rug: PlacedFurniture = rugs[_rng.randi() % rugs.size()]
		var a := _rng.randf() * TAU
		var p := Vector3(rug.global_position.x, room_y, rug.global_position.z)
		return {"top": p, "front": p + Vector3(sin(a), 0.0, cos(a)) * 0.3, "face": Vector3(sin(a), 0.0, cos(a)),
			"claim": func(_c: StreetCat) -> bool: return true}
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
		# nur jede zweite Zelle (weniger Zickzack)
		if i == cells.size() - 1 or i % 2 == 0:
			result.append(_cell_pos(cells[i]))
	result.append(to)
	return result


# --- Hilfen für die Katzen ---

func door_open() -> bool:
	return _door != null and _door.is_open


func floor_y(cat: StreetCat) -> float:
	if cat.inside and _room:
		return floor_y_room()
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


## Fahrbahn frei zum Überqueren (kein Fahrzeug in der Nähe oder im Kommen)?
func road_clear(pos: Vector3) -> bool:
	var local := _outside.to_local(pos)
	var s := street.centerline.project(Vector2(local.x, local.z)).x
	for vehicle in street.get_vehicles():
		var ahead := (s - vehicle.get_s()) * vehicle.direction
		if ahead > -vehicle.length - 1.0 and ahead < 6.0 + vehicle.speed * 3.5:
			return false
	return true
