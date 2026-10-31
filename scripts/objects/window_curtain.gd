@tool
class_name WindowCurtain
extends Node3D
## Vorhang oder Gardine an einem Schaufenster (seit Etappe 6c, Shop „Nest & Nook“): Das Modell baut sich
## selbst aus der Form seines Fensters – eckig, Bogen, rund oder Erker –, auch neu, wenn die Fenster in
## der App „Fassade“ umgebaut werden. Im Gestaltungsmodus rasten Vorhänge nur an Fenstern ein
## (FurnitureData.PLACE_WINDOW); Ursprung = Mitte unten an der Innenseite der Wand, +Z in den Raum.
##
## Arten: SHEER = Gardine über das ganze Fenster (leicht durchscheinend), DRAPES = zwei Vorhangbahnen an
## den Seiten, CAFE = Scheibengardine in der unteren Hälfte, TIED = zwei Bahnen, mit einem Band gerafft.
## Farben: Material „fabric“ (Farbvarianten im Datenblatt), Stange „rod“.

enum Style { SHEER, DRAPES, CAFE, TIED }

@export var style: Style = Style.DRAPES:
	set(value):
		style = value
		if is_inside_tree():
			rebuild()
@export var fabric: Material
@export var rod_material: Material

## So weit vor der Wand hängt der Stoff (m)
const HANG := 0.07
## Fenster, wenn keins zu finden ist (Vorschaubild im Shop): Sprossenfenster des Ladens
const DEFAULT_SIZE := Vector2(2.4, 2.3)


var _built_at := Vector3.INF


func _ready() -> void:
	rebuild()
	set_notify_transform(true)
	if not Engine.is_editor_hint() and not FacadeDesign.changed.is_connected(rebuild):
		FacadeDesign.changed.connect(rebuild)


## Die Vorschau im Gestaltungsmodus wandert von Fenster zu Fenster: dann neu anpassen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree() and global_position.distance_to(_built_at) > 0.2:
		rebuild.call_deferred()


## Baut den Stoff neu (passend zum Fenster, an dem der Vorhang hängt).
func rebuild() -> void:
	var outline := _find_outline()
	_built_at = global_position if is_inside_tree() else Vector3.INF
	# Alte Farbe (Variante) bzw. die Blaupause der Vorschau merken
	var overrides := {}
	var whole: Material = null
	var old := get_node_or_null("Cloth") as MeshInstance3D
	if old:
		whole = old.material_override
		for i in old.get_surface_override_material_count():
			if old.get_surface_override_material(i):
				overrides[i] = old.get_surface_override_material(i)
		remove_child(old)
		old.queue_free()
	var mesh := ArrayMesh.new()
	var cloth := OpeningMesh.new()
	var rod := OpeningMesh.new()
	_build(cloth, rod, outline)
	var cloth_mesh := cloth.mesh()
	if cloth_mesh.get_surface_count() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cloth_mesh.surface_get_arrays(0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, fabric)
	var rod_mesh := rod.mesh()
	if rod_mesh.get_surface_count() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rod_mesh.surface_get_arrays(0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, rod_material)
	var mi := MeshInstance3D.new()
	mi.name = "Cloth"
	mi.mesh = mesh
	mi.material_override = whole
	add_child(mi)
	for i in overrides:
		if i < mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, overrides[i])


## Umriss des Fensters in eigenen Koordinaten (x quer, y hoch ab Unterkante, Mitte 0).
func _find_outline() -> PackedVector2Array:
	var fallback := OpeningShape.outline(OpeningShape.Kind.RECT, DEFAULT_SIZE.x, DEFAULT_SIZE.y)
	if Engine.is_editor_hint() or not is_inside_tree():
		return fallback
	var room := _find_room()
	if room == null:
		return fallback
	var best: Dictionary = {}
	var best_distance := 0.6
	for o: Dictionary in FacadeLayout.openings(FacadeDesign.config):
		if o.kind != "shop":
			continue
		var frame := room.global_transform * FacadeLayout.opening_frame(o)
		var inside := frame * Vector3(0.0, 0.0, -FacadeLayout.WALL_THICKNESS)
		var d := inside.distance_to(global_position)
		if d < best_distance:
			best_distance = d
			best = o
	if best.is_empty():
		return fallback
	# Gespiegelt: der Vorhang schaut in den Raum (die Öffnung nach draußen)
	var mirrored := PackedVector2Array()
	var source: PackedVector2Array = best.outline
	for i in range(source.size() - 1, -1, -1):
		mirrored.append(Vector2(-source[i].x, source[i].y))
	return mirrored


func _find_room() -> Node3D:
	var node := get_parent()
	while node:
		if node is Room:
			return node as Node3D
		node = node.get_parent()
	return get_tree().root.find_child("GroundFloorRoom", true, false) as Node3D


func _build(cloth: OpeningMesh, rod: OpeningMesh, outline: PackedVector2Array) -> void:
	var b := OpeningShape.bounds(outline)
	var hw := b.size.x / 2.0
	# Der Stoff reicht etwas über das Fenster hinaus (oben und an den Seiten)
	var cover := OpeningShape.offset(outline, 0.07)
	var cb := OpeningShape.bounds(cover)
	var round := absf(b.size.x - b.size.y) < 0.05 and outline.size() > 30
	var straight_top := cb.end.y
	match style:
		Style.SHEER:
			# Gardine: oben und unten genau entlang der Fensterform (auch beim Rundfenster)
			_panel(cloth, cover, cb.position.x, cb.end.x, -1.0, INF, 0.018, 9.0, 0.0, true)
			_rod_along(rod, cover, round)
		Style.CAFE:
			var y := b.position.y + b.size.y * (0.5 if not round else 0.55)
			var span := OpeningShape.width_at(cover, y)
			_panel(cloth, cover, span.x, span.y, -1.0, y, 0.015, 11.0)
			rod.bar(Vector2(span.x - 0.03, y + 0.015), Vector2(span.y + 0.03, y + 0.015), 0.02, HANG - 0.012, HANG + 0.012)
		_:
			var panel_w := hw * (0.42 if style == Style.TIED else 0.48)
			var tie := b.position.y + b.size.y * 0.42 if style == Style.TIED else -1.0
			for side in [-1.0, 1.0]:
				var x_out: float = cb.end.x + 0.08 if side > 0.0 else cb.position.x - 0.08
				var x_in: float = x_out - side * (panel_w + 0.08)
				var lo := minf(x_in, x_out)
				var hi := maxf(x_in, x_out)
				_panel(cloth, cover, lo, hi, tie, INF, 0.035, 5.5, side)
			if round or outline.size() > 6:
				_rod_along(rod, cover, round)
			else:
				rod.bar(Vector2(cb.position.x - 0.18, straight_top + 0.02), Vector2(cb.end.x + 0.18, straight_top + 0.02), 0.03,
					HANG - 0.02, HANG + 0.02)


## Eine Stoffbahn zwischen x0 und x1: oben entlang der Fensterform (Umriss cover), unten bis zur Fensterbank
## bzw. bis y_max. tie > 0: unten zur Seite gerafft (Raffvorhang). Falten in z (Tiefe depth, Anzahl folds).
func _panel(cloth: OpeningMesh, cover: PackedVector2Array, x0: float, x1: float, tie: float, y_max: float, depth: float,
		folds: float, side: float = 0.0, follow_bottom: bool = false) -> void:
	var cb := OpeningShape.bounds(cover)
	var steps := maxi(8, roundi((x1 - x0) * 26.0))
	var rows := 14
	var bottom_y := cb.position.y + 0.04
	var grid := []  # [Zeile][Spalte] = Vector3
	for j in rows + 1:
		var row := []
		for i in steps + 1:
			var u := float(i) / steps
			var x := lerpf(x0, x1, u)
			# Oben folgt der Stoff der Fensterform; außerhalb (seitlich) gerade auf Höhe des Scheitels
			var span := WindowUnit.height_at(cover, clampf(x, cb.position.x + 0.001, cb.end.x - 0.001))
			var top := span.y if x > cb.position.x and x < cb.end.x else cb.end.y
			if span.y <= span.x:
				top = cb.end.y
			top = minf(top, y_max)
			var low := bottom_y if y_max == INF else maxf(bottom_y, span.x)
			if y_max != INF or follow_bottom:
				low = maxf(span.x, cb.position.y) + 0.02
			var v := float(j) / rows
			var y := lerpf(top, low, v)
			var fold := sin(u * folds * TAU) * depth * (0.6 + 0.4 * v)
			if tie > 0.0 and side != 0.0:
				# gerafft: zur Höhe des Bands hin zur Außenkante gezogen, darunter fällt der Stoff wieder auf
				var pull := clampf(1.0 - absf(y - tie) / 0.9, 0.0, 1.0) * 0.55
				var edge := x1 if side > 0.0 else x0
				x = lerpf(x, edge, pull * (1.0 - absf(u - (1.0 if side > 0.0 else 0.0))))
				fold *= 1.0 + pull
			row.append(Vector3(x, y, HANG + fold))
		grid.append(row)
	for j in rows:
		for i in steps:
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			var n := (b - a).cross(d - a).normalized()
			if n.z < 0.0:
				n = -n
			# Vorderseite (zum Raum) und Rückseite (vom Fenster aus gesehen)
			cloth.quad(a, b, c, d, n)
			var back := Vector3(0.0, 0.0, -0.004)
			cloth.quad(a + back, b + back, c + back, d + back, -n)


## Stange entlang der Oberkante der Fensterform (Bogen, Kreis) bzw. gerade.
func _rod_along(rod: OpeningMesh, cover: PackedVector2Array, round: bool) -> void:
	var cb := OpeningShape.bounds(cover)
	var points := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var x := lerpf(cb.position.x + 0.02, cb.end.x - 0.02, float(i) / steps)
		var span := WindowUnit.height_at(cover, x)
		points.append(Vector2(x, (span.y if span.y > span.x else cb.end.y) + 0.02))
	if round:
		# beim Rundfenster: gerade Stange über dem Kreis
		rod.bar(Vector2(cb.position.x - 0.1, cb.end.y + 0.03), Vector2(cb.end.x + 0.1, cb.end.y + 0.03), 0.03, HANG - 0.02, HANG + 0.02)
		return
	for i in points.size() - 1:
		rod.bar(points[i], points[i + 1], 0.025, HANG - 0.015, HANG + 0.015)
