extends Node
## Plätze für Tiere ausmessen (seit Etappe 6g). Ohne Bildschirm starten:
##   godot --headless --path . res://scenes/tools/bake_animal_spots.tscn
## Schreibt data/animals/spots.json (Koordinaten wie unter "Outside": x/z wie in der Welt, y ab Gehweg).
##
## Die Häuser haben im Spiel nur grobe Kollisionskästen. Hier bekommt jedes Haus-Modell einmal eine
## genaue Kollision (aus seinen Dreiecken); dann tasten senkrechte Strahlen vor und auf jedem Haus alle
## waagerechten Flächen ab: Dachrinnen, Firste, Gesimse, Schildkästen, Fensterbänke. Ein Platz zählt,
## wenn ein Vogel darauf Halt findet (Fläche rundherum), darüber frei ist (kein Dach im Nacken) und
## der Weg schräg nach vorn oben frei ist (Anflug und Abflug, keine Markise darüber). Plätze in
## Pflanzkästen und Töpfen (PlantSpot) fallen weg. Breite, tiefe Fensterbänke weit unten sind auch
## Katzenplätze ("cat": true). Außerdem: je Haus Vorderkante und höchster Punkt (für An- und Abflug
## hinter dem Dach) und eine freie, glatte Wandstelle für das Vogelhäuschen (gegenüber der Bücherei).
## Nach Änderungen an Häusern einfach neu starten.

const HOUSES_SCENE := "res://scenes/world/houses.tscn"
const OUT := "res://data/animals/spots.json"
## Abtastung (Meter): entlang der Hausfront, nach vorn, Abstand der Plätze
const STEP_U := 0.09
const STEP_V := 0.03
const SPACING := 0.16
## Waagerecht genug (Normale nach oben)
const FLAT := 0.93
## Vogel: Halt (± Meter) und Platz darüber
const FOOT_U := 0.035
const FOOT_V := 0.014
const FOOT_TOLERANCE := 0.012
const HEAD_RADIUS := 0.06
## Katze: Fensterbank so tief/breit, Höhe über dem Gehweg
const CAT_DEPTH := 0.15
const CAT_WIDTH := 0.34
const CAT_HEIGHT := Vector2(0.35, 1.25)
## Vogelhäuschen: Platz an der Wand (Breite, Höhe, Tiefe) und Höhe der Mitte
const BIRDHOUSE_SIZE := Vector3(0.46, 0.62, 0.4)
const BIRDHOUSE_HEIGHT := Vector2(2.1, 2.9)

var _space: PhysicsDirectSpaceState3D
var _plant_boxes: Array = []  # [Transform3D (inverse), Vector3 halbe Größe]


func _ready() -> void:
	var houses := (load(HOUSES_SCENE) as PackedScene).instantiate() as Node3D
	add_child(houses)
	for i in 4:
		await get_tree().process_frame
	var count := 0
	for mesh_instance: MeshInstance3D in houses.find_children("*", "MeshInstance3D", true, false):
		if not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		body.global_transform = mesh_instance.global_transform
		count += 1
	for spot: Node3D in houses.find_children("PlantSpot_*", "Node3D", true, false):
		var extras: Dictionary = spot.get_meta("extras", {})
		var size := Vector3(float(extras.get("width", 0.3)), float(extras.get("height", 0.4)), float(extras.get("depth", 0.2)))
		# Pflanzen wachsen über ihren Platz hinaus: großzügig sperren
		var half := Vector3(size.x / 2.0 + 0.12, size.y * 0.75 + 0.15, size.z / 2.0 + 0.12)
		var center := spot.global_transform * Vector3(0.0, half.y - 0.1, 0.0)
		_plant_boxes.append([Transform3D(spot.global_basis.orthonormalized(), center).affine_inverse(), half])
	print("Kollision für %d Teile, %d Pflanzplätze" % [count, _plant_boxes.size()])
	for i in 3:
		await get_tree().physics_frame
	_space = get_viewport().world_3d.direct_space_state
	var result := {"perches": [], "houses": [], "birdhouse": {}}
	var library := StreetPaths.library_entrance()
	var best_box := {}
	for house: Node3D in houses.find_children("*", "HouseFacade", true, false):
		house.set_meta("bake_path", String(houses.get_path_to(house)))
		var width := float(house.get("width"))
		var depth := float(house.get("depth"))
		var eaves := float(house.get("eaves_height"))
		var basis := house.global_basis.orthonormalized()
		var out := Vector2(basis.z.x, basis.z.z).normalized()
		var top := _house_top(house, width, depth)
		result.houses.append({"name": String(houses.get_path_to(house)), "front": _v3(house.global_position), "out": [out.x, out.y],
			"width": width, "depth": depth, "eaves": eaves, "top": top})
		var spots := _scan_house(house, width, depth, eaves, top)
		result.perches.append_array(spots)
		var box := _birdhouse_spot(house, width, eaves, library)
		if not box.is_empty() and (best_box.is_empty() or box.score < best_box.score):
			best_box = box
	if not best_box.is_empty():
		best_box.erase("score")
		result.birdhouse = best_box
	var cats := 0
	for spot in result.perches:
		cats += 1 if spot.get("cat", false) else 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t", false))
	file.close()
	print("Plätze: %d (davon %d für Katzen), Häuser: %d, Vogelhäuschen: %s" % [result.perches.size(), cats,
		result.houses.size(), "ja" if not result.birdhouse.is_empty() else "nein"])
	get_tree().quit()


## Höchster Punkt eines Hauses (First, Schornstein) über der Mitte seiner Breite.
func _house_top(house: Node3D, width: float, depth: float) -> float:
	var top := float(house.get("eaves_height"))
	for u in [-0.3, 0.0, 0.3]:
		for v in [0.35, 0.5, 0.65]:
			var p := house.to_global(Vector3(u * width, 0.0, -v * depth))
			var hit := _ray(p + Vector3.UP * 30.0, p)
			if not hit.is_empty():
				top = maxf(top, hit.position.y)
	return snappedf(top, 0.01)


## Alle Sitzplätze eines Hauses (vorn bis zur Mitte des Dachs).
func _scan_house(house: Node3D, width: float, depth: float, eaves: float, top: float) -> Array:
	var found: Array = []
	var basis := house.global_basis.orthonormalized()
	var out3 := Vector3(basis.z.x, 0.0, basis.z.z).normalized()
	var along := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var u := -width / 2.0 + 0.08
	while u <= width / 2.0 - 0.08:
		var v := -depth * 0.55
		while v <= 0.75:
			var base := house.to_global(Vector3(u, 0.0, v))
			var y := top + 1.0
			# Vor der Hauswand alle Flächen übereinander, auf dem Dach nur die oberste
			var layers := 6 if v > -0.4 else 1
			for k in layers:
				var hit := _ray(Vector3(base.x, y, base.z), Vector3(base.x, 0.3, base.z))
				if hit.is_empty():
					break
				var p: Vector3 = hit.position
				y = p.y - 0.03
				if hit.normal.y < FLAT:
					continue
				var spot := _check_spot(p, out3, along)
				if spot.is_empty():
					continue
				spot["kind"] = "roof" if p.y > eaves - 0.35 else ("low" if p.y < 1.6 else "ledge")
				spot["house"] = String(house.get_meta("bake_path"))
				_add_spaced(found, spot)
			v += STEP_V
		u += STEP_U
	return found


## Taugt diese Stelle als Sitzplatz? Liefert den Platz (leer = nein).
func _check_spot(p: Vector3, out3: Vector3, along: Vector3) -> Dictionary:
	if _in_plants(p):
		return {}
	# Halt: rundherum dieselbe Höhe
	for offset in [along * FOOT_U, -along * FOOT_U, out3 * FOOT_V, -out3 * FOOT_V]:
		if not _same_height(p + offset, p.y):
			return {}
	# Kopf frei
	if _blocked(p + Vector3.UP * (HEAD_RADIUS + 0.025), HEAD_RADIUS):
		return {}
	# Anflug schräg nach vorn oben frei
	var from := p + Vector3.UP * 0.07
	if not _ray(from, p + out3 * 1.7 + Vector3.UP * 1.1).is_empty():
		return {}
	if not _ray(from, p + out3 * 0.4 + Vector3.UP * 1.2).is_empty():
		return {}
	var spot := {"pos": _v3(p), "out": [snappedf(out3.x, 0.001), snappedf(out3.z, 0.001)]}
	# Katzen: tiefe, breite Fensterbänke weit unten
	if p.y >= CAT_HEIGHT.x and p.y <= CAT_HEIGHT.y:
		var deep := true
		for d in [CAT_DEPTH * 0.5, -CAT_DEPTH * 0.5]:
			for w in [-CAT_WIDTH / 2.0, 0.0, CAT_WIDTH / 2.0]:
				if not _same_height(p + out3 * d + along * w, p.y):
					deep = false
		if deep and not _blocked(p + Vector3.UP * 0.2, 0.15):
			spot["cat"] = true
	return spot


func _same_height(p: Vector3, height: float) -> bool:
	var hit := _ray(Vector3(p.x, height + 0.04, p.z), Vector3(p.x, height - 0.05, p.z))
	return not hit.is_empty() and absf(hit.position.y - height) <= FOOT_TOLERANCE and hit.normal.y > FLAT - 0.05


func _in_plants(p: Vector3) -> bool:
	for box in _plant_boxes:
		var local: Vector3 = (box[0] as Transform3D) * p
		var half: Vector3 = box[1]
		if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
			return true
	return false


## Neue Plätze nur mit Abstand zu den schon gefundenen (der höhere gewinnt nicht – der erste bleibt).
func _add_spaced(found: Array, spot: Dictionary) -> void:
	var p := Vector3(spot.pos[0], spot.pos[1], spot.pos[2])
	for other in found:
		var q := Vector3(other.pos[0], other.pos[1], other.pos[2])
		if p.distance_to(q) < SPACING:
			return
	found.append(spot)


## Freie, glatte Wandstelle für das Vogelhäuschen: nur an Häusern gegenüber der Bücherei, möglichst
## nah vor ihrer Tür (von dort und aus dem Schaufenster gut zu sehen). Kleinere Zahl = besser.
func _birdhouse_spot(house: Node3D, width: float, eaves: float, library: Vector2) -> Dictionary:
	var basis := house.global_basis.orthonormalized()
	var out3 := Vector3(basis.z.x, 0.0, basis.z.z).normalized()
	# Front zeigt zur Bücherei-Seite (gegenüber)?
	var to_library := Vector3(library.x, 0.0, library.y) - house.global_position
	if out3.dot(to_library.normalized()) < 0.6 or to_library.length() > 16.0:
		return {}
	# nur an Wohnhäusern (eigenes Modell aus build_storybook_street.py), nie an Läden
	var model: Resource = house.get("unique_model")
	if model == null or not model.resource_path.contains("/storybook/"):
		return {}
	var along := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var best := {}
	var u := -width / 2.0 + BIRDHOUSE_SIZE.x
	while u <= width / 2.0 - BIRDHOUSE_SIZE.x:
		var h := BIRDHOUSE_HEIGHT.x
		while h <= minf(BIRDHOUSE_HEIGHT.y, eaves - 0.8):
			var center := house.to_global(Vector3(u, 0.0, 0.0))
			center.y = h
			var wall := _flat_wall(center, out3, along)
			if not is_nan(wall):
				var p := center + out3 * wall
				var score := Vector2(p.x, p.z).distance_to(library) + absf(h - 2.45) * 2.0
				if best.is_empty() or score < best.score:
					best = {"pos": _v3(p), "out": [snappedf(out3.x, 0.001), snappedf(out3.z, 0.001)], "house": String(house.get_meta("bake_path")),
						"score": score}
			h += 0.1
		u += 0.1
	return best


## Wie weit vor (+) oder hinter (−) der Hausfront liegt die Wand an dieser Stelle – nur, wenn sie über die
## ganze Fläche des Vogelhäuschens glatt ist und davor nichts im Weg ist (NAN = nein).
func _flat_wall(center: Vector3, out3: Vector3, along: Vector3) -> float:
	var depths: Array[float] = []
	for i in 5:
		for j in 5:
			var p := center + along * ((i / 4.0 - 0.5) * BIRDHOUSE_SIZE.x) + Vector3.UP * ((j / 4.0 - 0.5) * BIRDHOUSE_SIZE.y)
			var hit := _ray(p + out3 * 0.8, p - out3 * 0.4)
			if hit.is_empty() or (hit.normal as Vector3).dot(out3) < 0.93:
				return NAN
			depths.append((hit.position - p).dot(out3))
	depths.sort()
	if depths[-1] - depths[0] > 0.025:
		return NAN
	var wall := depths[depths.size() / 2]
	# nur auf der Mauer selbst (nicht auf vorstehenden Ladenfronten, Erkern oder zurückgesetzten Türen)
	if absf(wall) > 0.08:
		return NAN
	# Platz davor (Kasten ohne die Wand selbst)
	var box := BoxShape3D.new()
	box.size = Vector3(BIRDHOUSE_SIZE.x + 0.2, BIRDHOUSE_SIZE.y + 0.3, BIRDHOUSE_SIZE.z)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(along, Vector3.UP, out3), center + out3 * (wall + 0.03 + BIRDHOUSE_SIZE.z / 2.0))
	if not _space.intersect_shape(query, 1).is_empty():
		return NAN
	return depths[depths.size() / 2]


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


func _blocked(center: Vector3, radius: float) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	return not _space.intersect_shape(query, 1).is_empty()


func _v3(p: Vector3) -> Array:
	return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]
