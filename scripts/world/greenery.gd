class_name Greenery
extends Node3D
## Pflanzen auf allen Pflanzplätzen (Stil-Umbau der Welt, Etappe 4h, Schritt 5).
##
## Die Modelle der Häuser, Läden, Gassen und der Bücherei enthalten leere Knoten „PlantSpot_<art>_<n>“
## mit Eigenschaften (Metadaten "extras": kind, width, depth, height, hint). Beim Start sucht Greenery
## alle diese Plätze und setzt passende Pflanzen-Szenen aus scenes/world/plants/ darauf (Wurzel PlantPiece:
## Art, Nennmaß, Gewicht, Hinweis). Neue Pflanze = neue Szene in diesem Ordner, kein Code.
##
## Leistung: Gleiche Pflanzen werden je Gebiet (cell_size) zu einem MultiMesh zusammengefasst – so
## zeichnet die ganze Straße ihre Pflanzen in wenigen Durchgängen. Pflanzen mit collision_radius
## (Bäumchen im Kübel) bekommen eine feste Kollision und ein Hindernis für Passanten.
## Liegt in main.tscn als erstes Kind von "Outside" (läuft vor dem Start des Straßenlebens).

const SPOT_PREFIX := "PlantSpot_"

## Ordner mit den Pflanzen-Szenen.
@export_dir var plants_dir := "res://scenes/world/plants"
## Größe eines Gebiets in Metern (je Gebiet und Pflanzenteil ein MultiMesh).
@export var cell_size := 36.0
## Ab dieser Entfernung (m) werden Pflanzen je Art weich ausgeblendet (0 = immer sichtbar). Kleine Dinge
## sieht man aus der Ferne ohnehin kaum – das spart viel Rechenzeit.
@export var fade_distances := {"box": 45.0, "potfill": 45.0, "basket": 45.0, "bed": 45.0, "pot": 50.0, "climber": 75.0,
	"hedge": 75.0, "tree": 0.0, "tubtree": 0.0, "tuft": 30.0, "walltuft": 35.0, "bucket": 45.0, "rim": 45.0}
## Im Umkreis (m) einer Pflanze bekommen Nachbarplätze möglichst eine andere Sorte (keine Kopien nebeneinander).
@export var variety_radius := 3.0
## Pflanzen in Töpfen etwas größer als der Topf (quellen über den Rand)
@export var pot_overflow := 1.22
## Wie oft an Töpfen Gras oder Ranken über den Rand wachsen (Art "rim", 0 … 1)
@export var rim_chance := 0.8
@export var enabled := true

## kind -> Array von Einträgen {id, scene, size, weight, radius, hint}
var _catalog := {}
## Teile (MeshInstance3D) einer Pflanzen-Szene: Pfad -> Array von {mesh, xform, material, shadow}
var _parts := {}
## Bündel: Schlüssel -> {mesh, material, shadow, transforms}
var _batches := {}
var _instances: Array[MultiMeshInstance3D] = []
var placed_count := 0
## Schon gesetzte Pflanzen: [Lage, id] (für die Vielfalt unter Nachbarn)
var _placed_ids: Array = []


func _ready() -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	_load_catalog()
	_place_all.call_deferred()
	Settings.setting_changed.connect(_on_setting_changed)


func _load_catalog() -> void:
	_catalog.clear()
	var files: PackedStringArray = ResourceLoader.list_directory(plants_dir)
	for file in files:
		if not file.ends_with(".tscn") and not file.ends_with(".scn"):
			continue
		var path := plants_dir.path_join(file)
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var root := scene.instantiate()
		if root is PlantPiece:
			var piece := root as PlantPiece
			if piece.weight > 0.0:
				var entry := {"id": file.get_basename(), "scene": scene, "path": path, "size": piece.nominal_size, "kind": piece.kind,
					"weight": piece.weight, "radius": piece.collision_radius, "hint": piece.hint}
				if not _catalog.has(piece.kind):
					_catalog[piece.kind] = []
				(_catalog[piece.kind] as Array).append(entry)
		root.free()


func _place_all() -> void:
	var inverse := global_transform.affine_inverse()
	for spot: Node in get_tree().root.find_children(SPOT_PREFIX + "*", "", true, false):
		if not spot is Node3D or not spot.has_meta("extras"):
			continue
		var extras: Dictionary = spot.get_meta("extras")
		var base: Transform3D = inverse * (spot as Node3D).global_transform
		for item: Array in _pieces_for(extras, base):
			_add_piece(item[0], base * (item[1] as Transform3D))
	_build_batches()


## Welche Pflanzen auf einen Platz kommen: Liste von [Eintrag, Lage relativ zum Platz].
func _pieces_for(extras: Dictionary, base: Transform3D) -> Array:
	var kind := str(extras.get("kind", ""))
	var entries: Array = _catalog.get(kind, [])
	if entries.is_empty():
		return []
	var size := Vector3(float(extras.get("width", 0.3)), float(extras.get("height", 0.4)), float(extras.get("depth", 0.2)))
	var hint := str(extras.get("hint", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i((base.origin * 100.0).round()))
	var out := []
	match kind:
		"box":
			# Blumenkasten: Ausschnitte nebeneinander, zwei bis drei Sorten im Wechsel (nie zweimal dieselbe
			# nebeneinander), andere Sorten als an den Nachbarfenstern
			var sorts: Array = [_pick_varied(entries, hint, rng, base.origin)]
			for k in (2 if rng.randf() < 0.35 else 1):
				sorts.append(_pick_varied(entries, hint, rng, base.origin, sorts))
			for e: Dictionary in sorts:
				_placed_ids.append([base.origin, e.id])
			var nominal: Vector3 = (sorts[0] as Dictionary).size
			var n := maxi(1, roundi(size.x / nominal.x))
			var step := size.x / n
			var s := clampf(step / nominal.x, 0.8, 1.25) * 1.1   # etwas üppiger als der Kasten
			var prev := -1
			for i in n:
				var k := rng.randi_range(0, sorts.size() - 1)
				if sorts.size() > 1 and k == prev:
					k = (k + 1 + rng.randi_range(0, sorts.size() - 2)) % sorts.size()
				prev = k
				var t := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)).scaled(Vector3.ONE * s * rng.randf_range(0.92, 1.06)),
					Vector3(-size.x / 2.0 + step * (i + 0.5) + rng.randf_range(-0.02, 0.02), 0.0, 0.0))
				out.append([sorts[k], t])
		"potfill", "basket":
			var e: Dictionary = _pick_varied(entries, hint, rng, base.origin)
			_placed_ids.append([base.origin, e.id])
			var s := clampf(size.x / (e.size as Vector3).x * (pot_overflow if kind == "potfill" else 1.08), 0.3, 2.2)
			out.append([e, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3.ZERO)])
			if kind == "potfill":
				out.append_array(_rim_pieces(size.x / 0.4 * 1.08, 0.0, rng, base.origin))
		"bucket":
			# Schnittblumen im Eimer/Korb: Ursprung = Mitte des Rands, Breite = Innendurchmesser
			var e: Dictionary = _pick_varied(entries, hint, rng, base.origin, [], 1.2)
			_placed_ids.append([base.origin, e.id])
			var s := clampf(size.x / (e.size as Vector3).x, 0.6, 1.15)
			out.append([e, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3.ZERO)])
		"pot":
			var e: Dictionary = _pick_varied(entries, hint, rng, base.origin)
			_placed_ids.append([base.origin, e.id])
			out.append([e, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3.ZERO)])
			# Kübel der Pflanzen-Bibliothek: Erde 0,42 m hoch, innen 0,205 m Radius
			out.append_array(_rim_pieces(0.205 / 0.182, 0.4214, rng, base.origin))
		"walltuft":
			# Grasbüschel aus der Ecke Wand/Gehweg: verschieden groß, leicht verdreht (Spot zeigt nach vorn)
			var e: Dictionary = _pick_varied(entries, hint, rng, base.origin, [], 0.8)
			_placed_ids.append([base.origin, e.id])
			var s := rng.randf_range(0.65, 1.4)
			out.append([e, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.25, 0.25)).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)),
				Vector3.ZERO)])
		"climber":
			# die höchste Kletterpflanze, die passt (Hinweis bevorzugt); nie breiter als der Platz
			var fitting := entries.filter(func(x: Dictionary) -> bool: return (x.size as Vector3).y <= size.y * 1.15)
			if fitting.is_empty():
				fitting = entries
			var with_hint := fitting.filter(func(x: Dictionary) -> bool: return hint != "" and x.hint == hint)
			if not with_hint.is_empty():
				fitting = with_hint
			else:
				fitting = fitting.filter(func(x: Dictionary) -> bool: return x.hint == "")
			if fitting.is_empty():
				return out
			# bevorzugt Pflanzen, die (fast) in die Breite passen – sonst die schmalste
			var narrow := fitting.filter(func(x: Dictionary) -> bool: return (x.size as Vector3).x <= size.x * 1.25)
			if narrow.is_empty():
				var smallest := INF
				for x: Dictionary in fitting:
					smallest = minf(smallest, (x.size as Vector3).x)
				narrow = fitting.filter(func(x: Dictionary) -> bool: return (x.size as Vector3).x <= smallest + 0.01)
			var best := 0.0
			for x: Dictionary in narrow:
				best = maxf(best, (x.size as Vector3).y)
			var tall := narrow.filter(func(x: Dictionary) -> bool: return (x.size as Vector3).y >= best - 0.6)
			var e: Dictionary = _pick_varied(tall, "", rng, base.origin)
			_placed_ids.append([base.origin, e.id])
			var nominal: Vector3 = e.size
			# Breite nie größer als der Platz (Fenster bleiben frei); Höhe für sich, Breite höchstens
			# 30 % schmaler als die Höhe (sonst wirken die Blätter gestaucht)
			var sy := minf(size.y / nominal.y, 1.15)
			var sx := minf(size.x / nominal.x, sy)
			sy = minf(sy, sx / 0.7)
			if sy >= 0.5:
				out.append([e, Transform3D(Basis().scaled(Vector3(sx, sy, sx)), Vector3.ZERO)])
		"bed":
			var e0: Dictionary = entries[0]
			var cell := (e0.size as Vector3).x * 0.9
			var nx := maxi(1, floori(size.x / cell))
			var nz := maxi(1, floori(size.z / cell))
			for i in nx:
				for j in nz:
					var p := Vector3(-size.x / 2.0 + size.x * (i + 0.5) / nx + rng.randf_range(-0.06, 0.06), 0.0,
						-size.z / 2.0 + size.z * (j + 0.5) / nz + rng.randf_range(-0.06, 0.06))
					var e: Dictionary = _pick_varied(entries, hint, rng, base * p, [], 0.8)
					_placed_ids.append([base * p, e.id])
					out.append([e, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.85, 1.1)), p)])
		"hedge":
			var e0: Dictionary = entries[0]
			var step := (e0.size as Vector3).x * 0.8
			var n := maxi(1, floori(size.x / step))
			for i in n:
				var p := Vector3(-size.x / 2.0 + size.x * (i + 0.5) / n, 0.0, rng.randf_range(-0.12, 0.12))
				var e: Dictionary = _pick_varied(entries, hint, rng, base * p, [], 1.2)
				_placed_ids.append([base * p, e.id])
				out.append([e, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.85, 1.1)), p)])
		"tree":
			# Bäume mit Hinweis (z. B. "garden") gehören genau an ihren Platz: feste Lage, keine Drehung
			var pool := entries.filter(func(x: Dictionary) -> bool: return x.hint == hint)
			if pool.is_empty():
				pool = entries.filter(func(x: Dictionary) -> bool: return x.hint == "")
			if pool.is_empty():
				return out
			var e: Dictionary = _pick(pool, "", rng)
			if hint != "":
				out.append([e, Transform3D.IDENTITY])
			else:
				var s := clampf(size.y / (e.size as Vector3).y, 0.8, 1.2)
				out.append([e, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3.ZERO)])
		_:
			var e: Dictionary = _pick_varied(entries, hint, rng, base.origin, [], 1.0 if kind == "tuft" else variety_radius)
			_placed_ids.append([base.origin, e.id])
			var s := clampf(size.y / (e.size as Vector3).y, 0.8, 1.2) * (rng.randf_range(0.55, 1.45) if kind == "tuft" else 1.0)
			out.append([e, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3.ZERO)])
	return out


## Begleiter am Topfrand (Art "rim"): ein oder zwei Stücke Gras bzw. Ranken, die über den Rand wachsen.
## scale = Größe des Topfs relativ zur Vorlage, lift = Höhe der Erde über dem Pflanzplatz.
func _rim_pieces(scale: float, lift: float, rng: RandomNumberGenerator, pos: Vector3) -> Array:
	var out := []
	var rims: Array = _catalog.get("rim", [])
	if rims.is_empty() or rng.randf() > rim_chance:
		return out
	var a := rng.randf_range(0.0, TAU)
	var used: Array = []
	for k in (1 if rng.randf() < 0.6 else 2):
		var e: Dictionary = _pick_varied(rims, "", rng, pos, used, 0.0)
		used.append(e)
		var t := Transform3D(Basis(Vector3.UP, a + k * PI + rng.randf_range(-0.7, 0.7)).scaled(Vector3.ONE * scale), Vector3(0.0, lift, 0.0))
		out.append([e, t])
	return out


## Wie _pick, aber Sorten, die schon in der Nähe (radius, sonst variety_radius) stehen oder in exclude
## liegen, kommen kaum noch dran – so stehen nie dieselben Pflanzen nebeneinander.
func _pick_varied(entries: Array, hint: String, rng: RandomNumberGenerator, pos: Vector3, exclude: Array = [],
		radius := -1.0) -> Dictionary:
	var r2 := pow(variety_radius if radius < 0.0 else radius, 2.0)
	var near := {}
	for item: Array in _placed_ids:
		if (item[0] as Vector3).distance_squared_to(pos) < r2:
			near[item[1]] = true
	for e: Dictionary in exclude:
		near[e.id] = true
	var weights: Array[float] = []
	var total := 0.0
	for e: Dictionary in entries:
		var w := float(e.weight) * (4.0 if hint != "" and e.hint == hint else 1.0)
		if near.has(e.id):
			w *= 0.03
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in entries.size():
		r -= weights[i]
		if r <= 0.0:
			return entries[i]
	return entries[-1]


## Zufällige Wahl nach Gewicht; Einträge mit passendem Hinweis zählen viermal.
func _pick(entries: Array, hint: String, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for e: Dictionary in entries:
		total += float(e.weight) * (4.0 if hint != "" and e.hint == hint else 1.0)
	var r := rng.randf() * total
	for e: Dictionary in entries:
		r -= float(e.weight) * (4.0 if hint != "" and e.hint == hint else 1.0)
		if r <= 0.0:
			return e
	return entries[-1]


func _add_piece(entry: Dictionary, xform: Transform3D) -> void:
	placed_count += 1
	var path: String = entry.path
	if not _parts.has(path):
		_parts[path] = _collect_parts(entry.scene)
	var cell := Vector2i(floori(xform.origin.x / cell_size), floori(xform.origin.z / cell_size))
	var center := Vector3((cell.x + 0.5) * cell_size, 0.0, (cell.y + 0.5) * cell_size)
	var parts: Array = _parts[path]
	for i in parts.size():
		var part: Dictionary = parts[i]
		var key := "%s#%d@%d,%d" % [path, i, cell.x, cell.y]
		if not _batches.has(key):
			_batches[key] = {"mesh": part.mesh, "material": part.material, "shadow": part.shadow, "transforms": [],
				"center": center, "fade": float(fade_distances.get(entry.kind, 0.0))}
		# Lage relativ zur Mitte des Gebiets (dort steht das MultiMesh – für die Entfernung beim Ausblenden)
		(_batches[key].transforms as Array).append(Transform3D(Basis(), -center) * xform * (part.xform as Transform3D))
	if float(entry.radius) > 0.0:
		_add_collision(xform, float(entry.radius) * xform.basis.get_scale().x, (entry.size as Vector3).y * xform.basis.get_scale().y)


## Alle MeshInstance3D einer Szene mit ihrer Lage relativ zur Wurzel.
func _collect_parts(scene: PackedScene) -> Array:
	var root := scene.instantiate() as Node3D
	var out := []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := mi.transform
		var p := mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		out.append({"mesh": mi.mesh, "xform": t, "material": mi.material_override,
			"shadow": mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF})
	root.free()
	return out


func _build_batches() -> void:
	var shadows := _plant_shadows()
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var transforms: Array = batch.transforms
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = batch.mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Plants"
		mmi.multimesh = mm
		mmi.position = batch.center
		mmi.set_meta("fade", float(batch.fade))
		_apply_range(mmi)
		if batch.material:
			mmi.material_override = batch.material
		mmi.set_meta("casts", batch.shadow)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and batch.shadow \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_instances.append(mmi)
	_batches.clear()


## Feste Kollision (Zylinder) und Hindernis für Passanten, z. B. Bäumchen im Kübel.
func _add_collision(xform: Transform3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "PlantBody"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = minf(height, 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, shape.height / 2.0, 0.0)
	body.add_child(collision)
	body.position = xform.origin
	add_child(body)
	var obstacle := StreetObstacle.new()
	obstacle.name = "StreetObstacle"
	obstacle.radius = radius + 0.05
	obstacle.position = xform.origin
	add_child(obstacle)


## Ausblenden in der Ferne (Entfernung je Art x Faktor der Grafikstufe, plant_distance).
func _apply_range(mmi: MultiMeshInstance3D) -> void:
	var fade := float(mmi.get_meta("fade", 0.0))
	if fade <= 0.0:
		mmi.visibility_range_end = 0.0
		return
	var factor := float(Settings.get_graphics_preset().get("plant_distance", 1.0))
	mmi.visibility_range_end = fade * factor + cell_size * 0.7
	mmi.visibility_range_end_margin = 8.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _plant_shadows() -> bool:
	return bool(Settings.get_graphics_preset().get("plant_shadows", true))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != "graphics/quality":
		return
	var shadows := _plant_shadows()
	for mmi in _instances:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and bool(mmi.get_meta("casts")) \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_range(mmi)
