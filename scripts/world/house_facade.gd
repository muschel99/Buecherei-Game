@tool
class_name HouseFacade
extends Node3D
## Ein Nachbarhaus (seit Etappe 4d, seit 4e je Haustyp eine eigene Szene in
## scenes/world/houses/): reine Kulisse, nicht betretbar.
##
## Solange kein Knoten "Model" in der Szene liegt, baut das Script einen schlichten Platzhalter:
## Hauskörper mit Fenstern, Tür, Sockel und Satteldach (First parallel zur Straße), auf Wunsch
## mit Schornstein, Ladenfront (große Schaufenster, Schild), Markise oder Vordach.
## Die Kollision (ein Kasten so groß wie der Hauskörper) baut es immer – auch mit eigenem Modell.
## Das Script läuft auch im Editor (@tool): Man sieht die Häuser dort, wie im Spiel.
##
## Ursprung: unten in der Mitte der Vorderseite (auf Gehweg-Höhe). Die Vorderseite zeigt nach
## +Z, das Haus reicht nach -Z (Tiefe). Wo die Häuser stehen: scenes/world/houses.tscn.
##
## Leistung: Alle Häuser mit gleichen Maßen teilen sich EIN Mesh und ein Material
## (assets/materials/house_facade.tres). Die Farben jedes Hauses (wall_color, door_color,
## accent_color) kommen als Instanz-Werte dazu – sie kosten nichts extra.

enum GroundFloor {
	WINDOWS,  ## Erdgeschoss mit normalen Fenstern und Haustür
	SHOPFRONT,  ## Ladenfront: große Schaufenster, Ladentür, Schild darüber
}

@export_group("Maße")
@export var width: float = 5.0:
	set(value):
		width = value
		_queue_rebuild()
@export var depth: float = 8.0:
	set(value):
		depth = value
		_queue_rebuild()
## Höhe der Traufe (Unterkante des Dachs) über dem Gehweg.
@export var eaves_height: float = 6.6:
	set(value):
		eaves_height = value
		_queue_rebuild()
## So hoch steigt das Dach bis zum First.
@export var roof_rise: float = 2.0:
	set(value):
		roof_rise = value
		_queue_rebuild()

@export_group("Aussehen")
## So viele Geschosse (Fensterreihen).
@export var storeys: int = 2:
	set(value):
		storeys = value
		_queue_rebuild()
## So viele Fenster nebeneinander (0 = so viele, wie gut passen).
@export var window_columns: int = 0:
	set(value):
		window_columns = value
		_queue_rebuild()
## Tür im Erdgeschoss: -1 = links, 0 = keine, 1 = rechts, 2 = Mitte (von vorn gesehen).
@export var door_side: int = 1:
	set(value):
		door_side = value
		_queue_rebuild()
@export var ground_floor: GroundFloor = GroundFloor.WINDOWS:
	set(value):
		ground_floor = value
		_queue_rebuild()
## Markise über der Ladenfront (in der Akzentfarbe).
@export var awning: bool = false:
	set(value):
		awning = value
		_queue_rebuild()
## Kleines Vordach über der Haustür.
@export var porch: bool = false:
	set(value):
		porch = value
		_queue_rebuild()
## Fenster auch in einer Seitenwand (seit Etappe 4f, für Häuser am Ende einer Reihe, deren
## Seitenwand man sieht): 0 = keine, -1 = links (-X), 1 = rechts (+X), 2 = beide.
@export var side_windows: int = 0:
	set(value):
		side_windows = value
		_queue_rebuild()
@export var chimney: bool = true:
	set(value):
		chimney = value
		_queue_rebuild()
@export var plinth_height: float = 0.35:
	set(value):
		plinth_height = value
		_queue_rebuild()
@export var plinth_proud: float = 0.03:
	set(value):
		plinth_proud = value
		_queue_rebuild()

@export_group("Dieses Haus")
## Wandfarbe, Türfarbe und Akzentfarbe (Schild, Markise) – je Haus frei wählbar.
@export var wall_color: Color = Color(0.55, 0.3, 0.24):
	set(value):
		wall_color = value
		_apply_colors()
@export var door_color: Color = Color(0.18, 0.28, 0.42):
	set(value):
		door_color = value
		_apply_colors()
@export var accent_color: Color = Color(0.16, 0.3, 0.22):
	set(value):
		accent_color = value
		_apply_colors()
## Wirft das Haus Sonnenschatten? (Häuser weit weg oder gegenüber besser nicht.)
@export var casts_shadow: bool = true:
	set(value):
		casts_shadow = value
		_apply_colors()
## Hat das Haus eine feste Kollision? (Nur nötig, wo man hinkommt.)
@export var solid: bool = true:
	set(value):
		solid = value
		_queue_rebuild()

@export var material: Material = preload("res://assets/materials/house_facade.tres")

const WINDOW_WIDTH := 0.95
const WINDOW_HEIGHT := 1.45
const DOOR_WIDTH := 1.0
const DOOR_HEIGHT := 2.15
const FRAME := 0.07
const OVERHANG := 0.2

## Farben im Mesh (Alpha sagt, welche Farbe der Shader nimmt, siehe house_facade.gdshader)
const WALL := Color(1.0, 1.0, 1.0, 0.75)
const WALL_DARK := Color(0.82, 0.82, 0.82, 0.75)
const DOOR := Color(1.0, 1.0, 1.0, 0.5)
const ACCENT := Color(1.0, 1.0, 1.0, 0.25)
const ACCENT_DARK := Color(0.7, 0.7, 0.7, 0.25)
const TRIM := Color(0.93, 0.91, 0.86, 1.0)
const GLASS := Color(0.3, 0.34, 0.38, 1.0)
const SHOP_GLASS := Color(0.36, 0.4, 0.43, 1.0)
const ROOF := Color(0.3, 0.31, 0.34, 1.0)
const PLINTH := Color(0.38, 0.36, 0.34, 1.0)
const CHIMNEY_CAP := Color(0.74, 0.72, 0.68, 1.0)

## Gemeinsame Meshes: gleiche Maße = dasselbe Mesh (siehe _mesh_key)
static var _mesh_cache := {}

var _rebuild_queued := false
var _placeholder: MeshInstance3D
var _body: StaticBody3D


func _ready() -> void:
	# Kommt ein eigenes Modell ("Model") dazu, fällt weg oder wird ein Kind in "Model"
	# umbenannt: Platzhalter neu bauen (auch im Editor)
	child_entered_tree.connect(_on_child_changed)
	child_exiting_tree.connect(_on_child_changed)
	for child in get_children():
		_watch_name(child)
	_rebuild()


func _on_child_changed(child: Node) -> void:
	_watch_name(child)
	if child.name == "Model":
		_queue_rebuild()


func _watch_name(child: Node) -> void:
	if not child.renamed.is_connected(_queue_rebuild):
		child.renamed.connect(_queue_rebuild)


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


## Baut Platzhalter und Kollision (neu).
func _rebuild() -> void:
	_rebuild_queued = false
	for old: Node in [_placeholder, _body]:
		if old:
			remove_child(old)
			old.queue_free()
	_placeholder = null
	_body = null
	if solid:
		_build_collision()
	var model := get_node_or_null("Model")
	if model == null or model.is_queued_for_deletion():
		_placeholder = MeshInstance3D.new()
		_placeholder.name = "Placeholder"
		_placeholder.mesh = _get_mesh()
		add_child(_placeholder)
	_apply_colors()


## Farben und Schatten an den Platzhalter geben (kostet nichts extra: Instanz-Werte).
func _apply_colors() -> void:
	if _placeholder == null:
		return
	_placeholder.set_instance_shader_parameter("wall_color", wall_color)
	_placeholder.set_instance_shader_parameter("door_color", door_color)
	_placeholder.set_instance_shader_parameter("accent_color", accent_color)
	_placeholder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_collision() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 1  # Ebene "world"
	_body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, eaves_height, depth)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, eaves_height / 2.0, -depth / 2.0)
	_body.add_child(collision)
	add_child(_body)


## Alle Häuser mit denselben Maßen teilen sich ein Mesh.
func _get_mesh() -> Mesh:
	var key := _mesh_key()
	if not _mesh_cache.has(key):
		var builder := WorldMesh.new()
		_build_body(builder)
		_build_front(builder)
		_build_side_windows(builder)
		_build_roof(builder)
		_mesh_cache[key] = builder.commit(material)
	return _mesh_cache[key]


func _mesh_key() -> String:
	return str([width, depth, eaves_height, roof_rise, storeys, window_columns, door_side,
		ground_floor, awning, porch, chimney, plinth_height, plinth_proud, material, side_windows])


## Das reine Mesh des Platzhalters (z. B. für die Vorlagen zum Modellieren).
func get_placeholder_mesh() -> Mesh:
	return _get_mesh()


## Hauswände (vorn, an den Seiten, hinten) und der Sockel vorn.
func _build_body(builder: WorldMesh) -> void:
	var w := width / 2.0
	builder.add_box(Vector3(-w, 0.0, -depth), Vector3(w, eaves_height, 0.0), WALL,
		PackedStringArray(["bottom", "top"]))
	if plinth_height <= 0.0 or ground_floor == GroundFloor.SHOPFRONT:
		return
	var door := _door_range()
	var low := Vector3(-w, 0.0, 0.0)
	var high := Vector3(w, plinth_height, plinth_proud)
	var skip := PackedStringArray(["bottom", "back"])
	if door == Vector2.ZERO:
		builder.add_box(low, high, PLINTH, skip)
	else:
		# An der Tür ist der Sockel unterbrochen
		builder.add_box(low, Vector3(door.x, high.y, high.z), PLINTH, skip)
		builder.add_box(Vector3(door.y, 0.0, 0.0), high, PLINTH, skip)


## Fenster in den Seitenwänden (side_windows): je Geschoss gleichmäßig über die Tiefe verteilt.
## Gebaut in "Wand-Koordinaten" (x entlang der Wand, +z nach draußen, siehe WorldMesh.xform).
func _build_side_windows(builder: WorldMesh) -> void:
	var storey_height := eaves_height / maxf(1.0, storeys)
	var columns := maxi(1, floori((depth - 1.0) / 2.2))
	for side in [-1, 1]:
		if side_windows != side and side_windows != 2:
			continue
		var along := Vector3(0.0, 0.0, -side)
		builder.xform = Transform3D(Basis(along, Vector3.UP, Vector3(side, 0.0, 0.0)), Vector3(side * width / 2.0, 0.0, -depth / 2.0))
		for storey in storeys:
			var center_y := storey * storey_height + storey_height * 0.5 + (0.1 if storey == 0 else 0.0)
			for column in columns:
				_add_window(builder, -depth / 2.0 + depth * (column + 0.5) / columns, center_y)
	builder.xform = Transform3D.IDENTITY


## Fenster und Tür auf der Vorderseite (flach aufgesetzt, leicht vorstehend).
func _build_front(builder: WorldMesh) -> void:
	var columns := _column_count()
	var storey_height := eaves_height / maxf(1.0, storeys)
	for storey in storeys:
		if storey == 0 and ground_floor == GroundFloor.SHOPFRONT:
			_add_shopfront(builder, storey_height)
			continue
		var center_y := storey * storey_height + storey_height * 0.5 + (0.1 if storey == 0 else 0.0)
		for column in columns:
			var x := _column_x(column, columns)
			if storey == 0 and _is_door_column(column, columns):
				_add_door(builder, x)
			else:
				_add_window(builder, x, center_y)


func _add_window(builder: WorldMesh, x: float, center_y: float) -> void:
	var hw := WINDOW_WIDTH / 2.0
	var hh := WINDOW_HEIGHT / 2.0
	builder.add_quad(Vector3(x - hw, center_y - hh, 0.01), Vector3(x + hw, center_y - hh, 0.01),
		Vector3(x + hw, center_y + hh, 0.01), Vector3(x - hw, center_y + hh, 0.01), Vector3.BACK, GLASS)
	var skip := PackedStringArray(["bottom", "back"])
	# Rahmen rundherum, Sprossenkreuz, Fensterbank
	builder.add_box(Vector3(x - hw - FRAME, center_y - hh, 0.0), Vector3(x - hw, center_y + hh, 0.05), TRIM, skip)
	builder.add_box(Vector3(x + hw, center_y - hh, 0.0), Vector3(x + hw + FRAME, center_y + hh, 0.05), TRIM, skip)
	builder.add_box(Vector3(x - hw - FRAME, center_y + hh, 0.0), Vector3(x + hw + FRAME, center_y + hh + FRAME, 0.05), TRIM, skip)
	builder.add_box(Vector3(x - 0.02, center_y - hh, 0.0), Vector3(x + 0.02, center_y + hh, 0.03), TRIM, skip)
	builder.add_box(Vector3(x - hw, center_y - 0.02, 0.0), Vector3(x + hw, center_y + 0.02, 0.028), TRIM, skip)
	builder.add_box(Vector3(x - hw - FRAME - 0.04, center_y - hh - 0.06, 0.0),
		Vector3(x + hw + FRAME + 0.04, center_y - hh, 0.09), TRIM, PackedStringArray(["back"]))


func _add_door(builder: WorldMesh, x: float) -> void:
	var hw := DOOR_WIDTH / 2.0
	builder.add_quad(Vector3(x - hw, 0.0, 0.012), Vector3(x + hw, 0.0, 0.012),
		Vector3(x + hw, DOOR_HEIGHT, 0.012), Vector3(x - hw, DOOR_HEIGHT, 0.012), Vector3.BACK, DOOR)
	var skip := PackedStringArray(["bottom", "back"])
	builder.add_box(Vector3(x - hw - FRAME, 0.0, 0.0), Vector3(x - hw, DOOR_HEIGHT + FRAME, 0.06), TRIM, skip)
	builder.add_box(Vector3(x + hw, 0.0, 0.0), Vector3(x + hw + FRAME, DOOR_HEIGHT + FRAME, 0.06), TRIM, skip)
	builder.add_box(Vector3(x - hw, DOOR_HEIGHT, 0.0), Vector3(x + hw, DOOR_HEIGHT + FRAME, 0.06), TRIM, skip)
	# Oberlicht über der Tür
	builder.add_quad(Vector3(x - hw, DOOR_HEIGHT + FRAME, 0.01), Vector3(x + hw, DOOR_HEIGHT + FRAME, 0.01),
		Vector3(x + hw, DOOR_HEIGHT + FRAME + 0.35, 0.01), Vector3(x - hw, DOOR_HEIGHT + FRAME + 0.35, 0.01),
		Vector3.BACK, GLASS)
	builder.add_box(Vector3(x - hw - FRAME, DOOR_HEIGHT + FRAME + 0.35, 0.0),
		Vector3(x + hw + FRAME, DOOR_HEIGHT + 2.0 * FRAME + 0.35, 0.06), TRIM, skip)
	if porch:
		# Kleines Vordach auf zwei Konsolen
		var top := DOOR_HEIGHT + 2.0 * FRAME + 0.45
		builder.add_box(Vector3(x - hw - 0.3, top, 0.0), Vector3(x + hw + 0.3, top + 0.08, 0.7), TRIM, PackedStringArray(["back"]))
		for side in [-1.0, 1.0]:
			var cx: float = x + side * (hw + 0.2)
			builder.add_box(Vector3(cx - 0.05, top - 0.35, 0.0), Vector3(cx + 0.05, top, 0.25), TRIM, skip)


## Ladenfront im Erdgeschoss: Pfeiler an den Seiten, Brüstung, große Schaufenster mit
## Sprossen, Ladentür und darüber ein Schild (Akzentfarbe), auf Wunsch eine Markise.
func _add_shopfront(builder: WorldMesh, storey_height: float) -> void:
	var w := width / 2.0
	var pier := 0.28
	var sign_bottom := minf(2.85, storey_height - 0.55)
	var sign_top := sign_bottom + 0.42
	var skip := PackedStringArray(["bottom", "back"])
	# Pfeiler und Gesims über dem Schild
	builder.add_box(Vector3(-w, 0.0, 0.0), Vector3(-w + pier, sign_top + 0.08, 0.1), TRIM, skip)
	builder.add_box(Vector3(w - pier, 0.0, 0.0), Vector3(w, sign_top + 0.08, 0.1), TRIM, skip)
	builder.add_box(Vector3(-w, sign_top, 0.0), Vector3(w, sign_top + 0.08, 0.16), TRIM, PackedStringArray(["back"]))
	# Schild
	builder.add_box(Vector3(-w + pier, sign_bottom, 0.0), Vector3(w - pier, sign_top, 0.12), ACCENT, skip)
	# Tür (links, rechts oder in der Mitte) und Schaufenster daneben
	var inner_left := -w + pier
	var inner_right := w - pier
	var door_x := 0.0
	if door_side == -1:
		door_x = inner_left + DOOR_WIDTH / 2.0 + 0.15
	elif door_side == 1:
		door_x = inner_right - DOOR_WIDTH / 2.0 - 0.15
	var glass_top := sign_bottom - 0.12
	var riser := 0.55
	var spans: Array[Vector2] = []
	if door_side == 0:
		spans.append(Vector2(inner_left, inner_right))
	else:
		var hw := DOOR_WIDTH / 2.0 + FRAME
		builder.add_quad(Vector3(door_x - DOOR_WIDTH / 2.0, 0.0, 0.012), Vector3(door_x + DOOR_WIDTH / 2.0, 0.0, 0.012),
			Vector3(door_x + DOOR_WIDTH / 2.0, 2.3, 0.012), Vector3(door_x - DOOR_WIDTH / 2.0, 2.3, 0.012), Vector3.BACK, DOOR)
		builder.add_quad(Vector3(door_x - DOOR_WIDTH / 2.0, 2.3, 0.01), Vector3(door_x + DOOR_WIDTH / 2.0, 2.3, 0.01),
			Vector3(door_x + DOOR_WIDTH / 2.0, glass_top, 0.01), Vector3(door_x - DOOR_WIDTH / 2.0, glass_top, 0.01),
			Vector3.BACK, SHOP_GLASS)
		builder.add_box(Vector3(door_x - DOOR_WIDTH / 2.0, 2.3, 0.0), Vector3(door_x + DOOR_WIDTH / 2.0, 2.3 + FRAME, 0.06), TRIM, skip)
		builder.add_box(Vector3(door_x - hw, 0.0, 0.0), Vector3(door_x - hw + FRAME, glass_top, 0.06), TRIM, skip)
		builder.add_box(Vector3(door_x + hw - FRAME, 0.0, 0.0), Vector3(door_x + hw, glass_top, 0.06), TRIM, skip)
		if inner_left < door_x - hw - 0.3:
			spans.append(Vector2(inner_left, door_x - hw))
		if door_x + hw + 0.3 < inner_right:
			spans.append(Vector2(door_x + hw, inner_right))
	builder.add_box(Vector3(inner_left, glass_top, 0.0), Vector3(inner_right, glass_top + FRAME, 0.06), TRIM, skip)
	for span in spans:
		# Brüstung, Glas, Rahmen unten und Sprossen etwa alle 1,1 m
		builder.add_box(Vector3(span.x, 0.0, 0.0), Vector3(span.y, riser, 0.06), ACCENT_DARK, skip)
		builder.add_box(Vector3(span.x, riser, 0.0), Vector3(span.y, riser + FRAME, 0.08), TRIM, skip)
		builder.add_quad(Vector3(span.x, riser + FRAME, 0.01), Vector3(span.y, riser + FRAME, 0.01),
			Vector3(span.y, glass_top, 0.01), Vector3(span.x, glass_top, 0.01), Vector3.BACK, SHOP_GLASS)
		var panes := maxi(1, roundi((span.y - span.x) / 1.1))
		for k in range(1, panes):
			var mx := span.x + (span.y - span.x) * k / panes
			builder.add_box(Vector3(mx - 0.03, riser, 0.0), Vector3(mx + 0.03, glass_top, 0.05), TRIM, skip)
	if awning:
		# Markise: schräg vom Schild nach vorn, mit kurzem Volant
		var reach := 1.1
		var drop := 0.4
		var a := Vector3(-w + pier, sign_bottom, 0.13)
		var b := Vector3(w - pier, sign_bottom, 0.13)
		var c := Vector3(w - pier, sign_bottom - drop, reach)
		var d := Vector3(-w + pier, sign_bottom - drop, reach)
		var up := (b - a).cross(d - a).normalized()
		if up.y < 0.0:
			up = -up
		builder.add_quad(a, b, c, d, up, ACCENT)
		builder.add_quad(a, b, c, d, -up, ACCENT_DARK)
		builder.add_box(Vector3(d.x, d.y - 0.22, reach - 0.01), Vector3(c.x, d.y, reach + 0.01), ACCENT,
			PackedStringArray(["top"]))


## Satteldach: First parallel zur Vorderseite, Giebeldreiecke an den Seiten, weiße Traufkante
## vorn und hinten, auf Wunsch ein Schornstein.
func _build_roof(builder: WorldMesh) -> void:
	var w := width / 2.0
	var base := eaves_height
	var ridge_y := base + roof_rise
	var ridge_z := -depth / 2.0
	var front_normal := Vector3(0.0, depth / 2.0 + OVERHANG, roof_rise).normalized()
	var back_normal := Vector3(0.0, depth / 2.0 + OVERHANG, -roof_rise).normalized()
	builder.add_quad(Vector3(-w, base, OVERHANG), Vector3(w, base, OVERHANG),
		Vector3(w, ridge_y, ridge_z), Vector3(-w, ridge_y, ridge_z), front_normal, ROOF)
	builder.add_quad(Vector3(-w, base, -depth - OVERHANG), Vector3(w, base, -depth - OVERHANG),
		Vector3(w, ridge_y, ridge_z), Vector3(-w, ridge_y, ridge_z), back_normal, ROOF)
	# Giebel (Wandfarbe)
	for side in [-1.0, 1.0]:
		var x: float = side * w
		builder.add_triangle(Vector3(x, base, 0.0), Vector3(x, base, -depth), Vector3(x, ridge_y, ridge_z),
			Vector3(side, 0.0, 0.0), WALL)
	# Traufkante
	builder.add_box(Vector3(-w, base - 0.18, 0.0), Vector3(w, base, OVERHANG), TRIM, PackedStringArray(["top"]))
	builder.add_box(Vector3(-w, base - 0.18, -depth - OVERHANG), Vector3(w, base, -depth), TRIM, PackedStringArray(["top"]))
	if chimney:
		var cx := w - 0.7 if door_side != -1 else -w + 0.7
		builder.add_box(Vector3(cx - 0.3, ridge_y - 0.6, ridge_z - 0.35), Vector3(cx + 0.3, ridge_y + 0.9, ridge_z + 0.35), WALL_DARK)
		builder.add_box(Vector3(cx - 0.36, ridge_y + 0.9, ridge_z - 0.41), Vector3(cx + 0.36, ridge_y + 0.98, ridge_z + 0.41), CHIMNEY_CAP)


func _column_count() -> int:
	if window_columns > 0:
		return window_columns
	return maxi(1, floori(width / 1.7))


## Mitte einer Fensterspalte (gleichmäßig verteilt).
func _column_x(column: int, columns: int) -> float:
	return -width / 2.0 + width * (column + 0.5) / columns


func _is_door_column(column: int, columns: int) -> bool:
	match door_side:
		-1:
			return column == 0
		1:
			return column == columns - 1
		2:
			return column == floori(columns / 2.0)
	return false


## Wo die Tür liegt (x von – bis), oder Vector2.ZERO ohne Tür.
func _door_range() -> Vector2:
	var columns := _column_count()
	for column in columns:
		if _is_door_column(column, columns):
			var x := _column_x(column, columns)
			return Vector2(x - DOOR_WIDTH / 2.0 - FRAME, x + DOOR_WIDTH / 2.0 + FRAME)
	return Vector2.ZERO
