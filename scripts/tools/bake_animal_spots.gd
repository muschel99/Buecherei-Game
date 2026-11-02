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
## Seit Etappe 6h: Kollision je Material getrennt – Laub (Efeu, Ranken) und wehender Markisenstoff zählen nicht als
## fester Halt; Vögel sitzen auch IM Efeu ("ivy"), auf dünnen Kanten (Geländer, Fensterläden, Markisenstangen:
## "edge" = Halt nur entlang der Kante, "along" = Kante läuft nach vorn → Vogel sitzt quer), auf dem Rand von
## Blumenkästen und Töpfen ("rim", auch im zweiten Stock) – nie in der Erde. "wide" = breit genug für Tauben.
## Katzenplätze ("cat") nur, wo die Fläche an der Hauswand hängt (Fensterbänke, Stufen – keine Schilder/Ständer).
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
## Dünne Kanten: Halt quer dazu nur so viel (m)
const EDGE_HALF := 0.004
## Taube: Halt entlang der Kante, quer, Platz für den Körper
const WIDE_U := 0.07
const WIDE_V := 0.018
## Höchstens so viele Plätze je Haus und Art (sonst zu viele auf langen Dachrinnen)
const MAX_PER_KIND := {"roof": 70, "ledge": 45, "low": 30, "ivy": 30, "rim": 30}
## Katze: Fensterbank so tief/breit, Höhe über dem Gehweg (ab 12 cm: auch Stufen vor Haustüren)
const CAT_DEPTH := 0.15
const CAT_WIDTH := 0.34
const CAT_HEIGHT := Vector2(0.12, 1.3)
## Ebenen der Mess-Kollision: fest, Laub, wehender Stoff – eigene Ebenen (10–12), damit die groben
## Kollisionskästen der Häuser (Spiel-Kollision, oben auf Traufhöhe im Dach) nicht mitgemessen werden
const SOLID := 512
const FOLIAGE := 1024
const SWAY := 2048
const FOLIAGE_WORDS := ["blatt", "pflanze", "blüte", "bluete", "efeu", "laub", "ranke", "stiel", "zweig", "moos", "glyzin"]
## Vogelhäuschen: Platz an der Wand (Breite, Höhe, Tiefe) und Höhe der Mitte
const BIRDHOUSE_SIZE := Vector3(0.46, 0.62, 0.4)
const BIRDHOUSE_HEIGHT := Vector2(2.1, 2.9)

var _space: PhysicsDirectSpaceState3D
var _plant_boxes: Array = []  # [Transform3D (inverse), Vector3 halbe Größe]
var _plant_spots: Array[Node3D] = []
var _boxes_here: Array = []


func _ready() -> void:
	var houses := (load(HOUSES_SCENE) as PackedScene).instantiate() as Node3D
	add_child(houses)
	for i in 4:
		await get_tree().process_frame
	var count := 0
	for mesh_instance: MeshInstance3D in houses.find_children("*", "MeshInstance3D", true, false):
		if not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var mesh := mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var single := ArrayMesh.new()
			single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface))
			var shape := single.create_trimesh_shape()
			if shape == null:
				continue
			# von beiden Seiten fest – sonst gehen Prüfstrahlen von unten durch Dachziegel hindurch, und Plätze
			# unter dem Dach (auf Böden im Dachstuhl) gälten als frei
			shape.backface_collision = true
			var body := StaticBody3D.new()
			body.collision_layer = _layer_of(mesh_instance.get_active_material(surface))
			body.collision_mask = 0
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.add_child(collision)
			add_child(body)
			body.global_transform = mesh_instance.global_transform
			count += 1
	for spot: Node3D in houses.find_children("PlantSpot_*", "Node3D", true, false):
		_plant_spots.append(spot)
		var extras: Dictionary = spot.get_meta("extras", {})
		var size := Vector3(float(extras.get("width", 0.3)), float(extras.get("height", 0.4)), float(extras.get("depth", 0.2)))
		# Pflanzen wachsen über ihren Platz hinaus: großzügig sperren
		var half := Vector3(size.x / 2.0 + 0.12, size.y * 0.75 + 0.15, size.z / 2.0 + 0.12)
		var center := spot.global_transform * Vector3(0.0, half.y - 0.1, 0.0)
		_plant_boxes.append([Transform3D(spot.global_basis.orthonormalized(), center).affine_inverse(), half, center])
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
		spots.append_array(_rims(house, out, eaves, spots))
		result.perches.append_array(_limit(spots))
		var box := _birdhouse_spot(house, width, eaves, library)
		if not box.is_empty() and (best_box.is_empty() or box.score < best_box.score):
			best_box = box
	if not best_box.is_empty():
		best_box.erase("score")
		result.birdhouse = best_box
	var cats := 0
	var kinds := {}
	for spot in result.perches:
		cats += 1 if spot.get("cat", false) else 0
		var key := String(spot.kind) + ("/kante" if spot.get("edge", "") != "" else "") + ("/breit" if spot.get("wide", false) else "")
		kinds[key] = int(kinds.get(key, 0)) + 1
	print("Arten: ", kinds)
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
	# nur die Pflanzplätze in der Nähe prüfen (schneller)
	var reach := width / 2.0 + depth + 2.5
	_boxes_here = _plant_boxes.filter(func(b: Array) -> bool:
		var c: Vector3 = b[2]
		return Vector2(c.x - house.global_position.x, c.z - house.global_position.z).length() < reach)
	var u := -width / 2.0 + 0.08
	while u <= width / 2.0 - 0.08:
		var v := -depth * 0.55
		while v <= 1.6:
			var base := house.to_global(Vector3(u, 0.0, v))
			var y := top + 1.0
			# Vor der Hauswand alle Flächen übereinander (auch weit vorn: Markisenstangen), auf dem Dach nur die oberste
			var layers := 8 if v > -0.4 else 1
			for k in layers:
				var hit := _ray(Vector3(base.x, y, base.z), Vector3(base.x, 0.05, base.z), SOLID | FOLIAGE | SWAY)
				if hit.is_empty():
					break
				var p: Vector3 = hit.position
				y = p.y - 0.03
				var layer := (hit.collider as CollisionObject3D).collision_layer
				if _too_close(p):
					continue
				var spot := {}
				if layer == SWAY:
					continue
				elif layer == FOLIAGE:
					if hit.normal.y < 0.55 or v > 0.9:
						continue
					spot = _check_ivy(p, out3)
				else:
					if hit.normal.y < FLAT:
						continue
					spot = _check_spot(p, out3, along)
				if spot.is_empty():
					continue
				if not spot.has("kind"):
					spot["kind"] = "roof" if p.y > eaves - 0.35 else ("low" if p.y < 1.6 else "ledge")
				spot["house"] = String(house.get_meta("bake_path"))
				_add_spaced(found, spot)
			v += STEP_V
		u += STEP_U
	return found


## Höchstens MAX_PER_KIND Plätze je Art (gleichmäßig verteilt über das Haus).
func _limit(spots: Array) -> Array:
	var by_kind := {}
	for spot in spots:
		(by_kind.get_or_add(spot.kind, []) as Array).append(spot)
	var result: Array = []
	for kind in by_kind:
		var list: Array = by_kind[kind]
		var limit := int(MAX_PER_KIND.get(kind, 40))
		if list.size() <= limit:
			result.append_array(list)
			continue
		# Katzenplätze immer behalten, sonst jeden n-ten
		var step := float(list.size()) / limit
		var i := 0.0
		var kept := {}
		while int(i) < list.size():
			kept[int(i)] = true
			i += step
		for k in list.size():
			if kept.has(k) or list[k].get("cat", false):
				result.append(list[k])
	return result


## Ein Platz im Efeu (Laub an der Wand): auf einem Blatt, darüber kein festes Teil, Anflug frei.
func _check_ivy(p: Vector3, out3: Vector3) -> Dictionary:
	if _blocked(p + Vector3.UP * 0.07, 0.045, SOLID | SWAY):
		return {}
	var from := p + Vector3.UP * 0.07
	if not _ray(from, p + out3 * 1.7 + Vector3.UP * 1.1, SOLID | SWAY).is_empty():
		return {}
	# Efeu wächst an einer Wand: dahinter (bis 45 cm) muss Mauer sein
	if _ray(p + Vector3.UP * 0.03, p + Vector3.UP * 0.03 - out3 * 0.45, SOLID).is_empty():
		return {}
	return {"pos": _v3(p), "out": [snappedf(out3.x, 0.001), snappedf(out3.z, 0.001)], "kind": "ivy"}


## Rand von Blumenkästen, Töpfen und Kübeln (vorn, zur Straße): Vögel sitzen auf der Kante, nie in der Erde.
func _rims(house: Node3D, out: Vector2, eaves: float, found: Array) -> Array:
	var result: Array = []
	var out3 := Vector3(out.x, 0.0, out.y)
	for spot in _plant_spots:
		if not house.is_ancestor_of(spot):
			continue
		var extras: Dictionary = spot.get_meta("extras", {})
		if not String(extras.get("kind", "")) in ["box", "pot", "tub", "basket", "bucket"]:
			continue
		var width := float(extras.get("width", 0.3))
		var depth := float(extras.get("depth", 0.2))
		var basis := spot.global_basis.orthonormalized()
		# die Seite des Gefäßes, die zur Straße zeigt
		var front := basis.z if basis.z.dot(out3) >= 0.0 else -basis.z
		var side := basis.x
		var count := maxi(1, int(width / 0.16))
		for i in count:
			var t := (i + 0.5) / count - 0.5
			for reach: float in [0.006, 0.014, 0.024, 0.036]:
				var q: Vector3 = spot.global_position + side * (t * width * 0.9) + front * (depth / 2.0 + reach)
				var hit := _ray(q + Vector3.UP * 0.18, q + Vector3.DOWN * 0.08, SOLID)
				if hit.is_empty() or hit.normal.y < 0.82:
					continue
				var p: Vector3 = hit.position
				if p.y < spot.global_position.y - 0.04:
					continue
				# Halt entlang des Rands, Kopf frei (Laub zählt nicht), Anflug frei
				if not (_same_height(p + side * 0.03, p.y) and _same_height(p - side * 0.03, p.y)):
					continue
				if _blocked(p + Vector3.UP * 0.075, 0.05, SOLID | SWAY):
					continue
				if not _ray(p + Vector3.UP * 0.07, p + front * 1.6 + Vector3.UP * 1.0, SOLID | SWAY).is_empty():
					continue
				var rim := {"pos": _v3(p), "out": [snappedf(front.x, 0.001), snappedf(front.z, 0.001)], "kind": "rim",
					"house": String(house.get_meta("bake_path"))}
				if not _too_close(p):
					_remember(p)
					result.append(rim)
				break
	return result


func _layer_of(material: Material) -> int:
	if material == null:
		return SOLID
	var name := material.resource_name.to_lower()
	if material is ShaderMaterial:
		var wind: Variant = (material as ShaderMaterial).get_shader_parameter("wind_strength")
		if wind != null and float(wind) > 0.0:
			return SWAY
		var shader := (material as ShaderMaterial).shader
		if shader and shader.resource_path.contains("plant"):
			return FOLIAGE
	for word in FOLIAGE_WORDS:
		if name.contains(word):
			return FOLIAGE
	return SOLID


## Taugt diese Stelle als Sitzplatz? Liefert den Platz (leer = nein).
func _check_spot(p: Vector3, out3: Vector3, along: Vector3) -> Dictionary:
	if _in_plants(p):
		return {}
	# Nie mitten auf einer schrägen Dachfläche (einzelne Ziegelkanten sind waagerecht, aber aus der Ferne zeichnet
	# Godot das Dach vereinfacht – dann schwebt der Vogel): dahinter höher und davor tiefer = Dachschräge
	for d in [out3, -out3, along, -along]:
		var behind := _height_at(p - d * 0.12, p.y)
		var ahead := _height_at(p + d * 0.12, p.y)
		if behind > p.y + 0.035 and ahead < p.y - 0.035 and ahead > -INF:
			return {}
	# Halt: entlang (u) und quer (v) dieselbe Höhe – oder nur entlang einer Richtung (dünne Kante)
	var u_ok := _same_height(p + along * FOOT_U, p.y) and _same_height(p - along * FOOT_U, p.y)
	var v_ok := _same_height(p + out3 * FOOT_V, p.y) and _same_height(p - out3 * FOOT_V, p.y)
	var edge := ""
	if not (u_ok and v_ok):
		var v_long := _same_height(p + out3 * FOOT_U, p.y) and _same_height(p - out3 * FOOT_U, p.y)
		var u_thin := _same_height(p + along * EDGE_HALF, p.y) and _same_height(p - along * EDGE_HALF, p.y)
		var v_thin := _same_height(p + out3 * EDGE_HALF, p.y) and _same_height(p - out3 * EDGE_HALF, p.y)
		if u_ok and v_thin:
			edge = "along_u"      # Kante entlang der Hauswand (Geländer, Stange): Vogel schaut nach vorn
		elif v_long and u_thin:
			edge = "along_v"      # Kante nach vorn (offener Fensterladen): Vogel sitzt quer
		else:
			return {}
	# Kopf frei (Laub darf drumherum sein); der Vogel sitzt eher vorn auf der Kante
	if _blocked(p + Vector3.UP * (HEAD_RADIUS + 0.025) + out3 * 0.015, HEAD_RADIUS, SOLID | SWAY):
		return {}
	# Anflug schräg nach vorn oben frei (Start etwas vor der Wand, nicht im Fensterrahmen)
	var from := p + Vector3.UP * 0.07 + out3 * 0.04
	if not _ray(from, p + out3 * 1.7 + Vector3.UP * 1.1, SOLID | SWAY).is_empty():
		return {}
	if not _ray(from, p + out3 * 0.4 + Vector3.UP * 1.2, SOLID | SWAY).is_empty():
		return {}
	var spot := {"pos": _v3(p), "out": [snappedf(out3.x, 0.001), snappedf(out3.z, 0.001)]}
	if edge != "":
		spot["edge"] = edge
	# Tauben: breiter Halt, viel Platz
	var dir := out3 if edge == "along_v" else along
	var across := along if edge == "along_v" else out3
	if _same_height(p + dir * WIDE_U, p.y) and _same_height(p - dir * WIDE_U, p.y) \
			and _same_height(p + across * WIDE_V, p.y) and _same_height(p - across * WIDE_V, p.y) \
			and not _blocked(p + Vector3.UP * 0.15, 0.1, SOLID | SWAY):
		spot["wide"] = true
	# Katzen: tiefe, breite Fensterbänke und Stufen weit unten – nur, wenn sie an der Hauswand hängen
	# (Schilder und Ständer vor dem Haus fallen um, wenn eine Katze hinaufspringt)
	if edge == "" and p.y >= CAT_HEIGHT.x and p.y <= CAT_HEIGHT.y:
		var deep := true
		for d in [CAT_DEPTH * 0.5, -CAT_DEPTH * 0.5]:
			for w in [-CAT_WIDTH / 2.0, 0.0, CAT_WIDTH / 2.0]:
				if not _same_height(p + out3 * d + along * w, p.y):
					deep = false
		var wall := not _ray(p + Vector3.UP * 0.12, p + Vector3.UP * 0.12 - out3 * 0.5, SOLID).is_empty()
		if deep and wall and not _blocked(p + Vector3.UP * 0.2, 0.15, SOLID | SWAY):
			spot["cat"] = true
	return spot


## Höhe der festen Fläche an dieser Stelle (in der Nähe von height), -INF = nichts darunter.
func _height_at(p: Vector3, height: float) -> float:
	var hit := _ray(Vector3(p.x, height + 0.25, p.z), Vector3(p.x, height - 0.25, p.z), SOLID)
	return hit.position.y if not hit.is_empty() else -INF


func _same_height(p: Vector3, height: float) -> bool:
	var hit := _ray(Vector3(p.x, height + 0.04, p.z), Vector3(p.x, height - 0.05, p.z), SOLID)
	return not hit.is_empty() and absf(hit.position.y - height) <= FOOT_TOLERANCE and hit.normal.y > FLAT - 0.05


func _in_plants(p: Vector3) -> bool:
	for box in _boxes_here:
		var local: Vector3 = (box[0] as Transform3D) * p
		var half: Vector3 = box[1]
		if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
			return true
	return false


## Neue Plätze nur mit Abstand zu den schon gefundenen (der erste bleibt). Schnell über ein Raster
## (Zellen so groß wie der Abstand: nur die 27 Nachbarzellen prüfen).
var _grid := {}


func _too_close(p: Vector3) -> bool:
	var c := Vector3i(floori(p.x / SPACING), floori(p.y / SPACING), floori(p.z / SPACING))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for q: Vector3 in _grid.get(c + Vector3i(dx, dy, dz), []):
					if p.distance_to(q) < SPACING:
						return true
	return false


func _remember(p: Vector3) -> void:
	var c := Vector3i(floori(p.x / SPACING), floori(p.y / SPACING), floori(p.z / SPACING))
	(_grid.get_or_add(c, []) as Array).append(p)


func _add_spaced(found: Array, spot: Dictionary) -> void:
	var p := Vector3(spot.pos[0], spot.pos[1], spot.pos[2])
	if _too_close(p):
		return
	_remember(p)
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
	query.collision_mask = SOLID | FOLIAGE | SWAY
	query.transform = Transform3D(Basis(along, Vector3.UP, out3), center + out3 * (wall + 0.03 + BIRDHOUSE_SIZE.z / 2.0))
	if not _space.intersect_shape(query, 1).is_empty():
		return NAN
	return depths[depths.size() / 2]


func _ray(from: Vector3, to: Vector3, mask: int = SOLID) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask))


func _blocked(center: Vector3, radius: float, mask: int = SOLID) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = mask
	query.transform = Transform3D(Basis.IDENTITY, center)
	return not _space.intersect_shape(query, 1).is_empty()


func _v3(p: Vector3) -> Array:
	return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]
