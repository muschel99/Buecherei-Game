class_name OpenSign
extends Node3D
## Schild „Geöffnet / Geschlossen“ AUSSEN an der Ladentür (seit Etappe 7; seit dem Wunsch nach Etappe 8b außen: „man soll von
## außen sehen, ob geöffnet oder geschlossen ist“): Es hängt an einer Kordel an einem Haken oben am Türblatt und schwingt mit
## der Tür. Die Seite zur Straße zeigt den Stand, durch das Glas sieht man von innen die Rückseite – also das andere Wort.
## E dreht es um (draußen vor der Tür; Lending.set_open). Besucher kommen nur, wenn zur Straße „Geöffnet“ zeigt.
## Es baut sich selbst (Brett, Rand, Kordel, Haken, zwei Schriftzüge) und setzt sich vor die Innenseite des Türblatts
## (auch, wenn die Fassade ein anderes Türblatt einsetzt).

## Maße des Bretts (m) und Höhe der Mitte über dem Boden; der Haken sitzt so viel darüber.
const SIZE := Vector2(0.5, 0.2)
const CENTER_Y := 1.86
const HOOK_ABOVE := 0.15
## Mitte des Türblatts in Scharnier-Koordinaten (x)
const LEAF_X := -0.5
## Jede Seite hat ihre Farbe (wie echte Ladenschilder – den Stand sieht man schon von Weitem): grün „Geöffnet“, rot
## „Geschlossen“, die Schrift in Creme
const OPEN_COLOR := Color(0.33, 0.55, 0.36)
const CLOSED_COLOR := Color(0.72, 0.32, 0.29)
const TEXT_COLOR := Color(0.99, 0.95, 0.85)
const BOARD_COLOR := Color(0.93, 0.87, 0.74)
const FRAME_COLOR := Color(0.38, 0.24, 0.15)

var door: Door
## 1 = innen (zum Raum), -1 = außen (zur Straße)
var side := 1.0
var _board: Node3D
var _front: Label3D
var _back: Label3D
var _front_plate: MeshInstance3D
var _back_plate: MeshInstance3D
var _interactable: Interactable
var _flip: Tween
var _check := 0.0


## Hängt das Schild außen an die Ladentür.
static func attach(the_door: Door) -> void:
	var sign_node := OpenSign.new()
	sign_node.name = "OpenSign"
	sign_node.door = the_door
	sign_node.side = -1.0
	the_door.get_hinge().add_child(sign_node)


func _ready() -> void:
	_build()
	_fit_to_leaf()
	_show(Lending.is_open)
	Lending.open_changed.connect(_on_open_changed)


func _build() -> void:
	var font := load("res://assets/ui/fonts/Caveat-Bold.woff2") as Font  # wie von Hand aufs Schild gemalt
	_board = Node3D.new()
	_board.name = "Board"
	_board.position = Vector3(0.0, CENTER_Y, 0.0)
	add_child(_board)
	_board.add_child(_box(Vector3(SIZE.x, SIZE.y, 0.008), Vector3.ZERO, BOARD_COLOR))
	# farbige Seiten vorn und hinten (Farbe je Wort, _show)
	_front_plate = _box(Vector3(SIZE.x, SIZE.y, 0.003), Vector3(0, 0, 0.0055), OPEN_COLOR)
	_back_plate = _box(Vector3(SIZE.x, SIZE.y, 0.003), Vector3(0, 0, -0.0055), CLOSED_COLOR)
	_board.add_child(_front_plate)
	_board.add_child(_back_plate)
	# Rand (dunkles Holz) rundherum, etwas dicker als das Brett
	var t := 0.012
	_board.add_child(_box(Vector3(SIZE.x + t * 2.0, t, 0.016), Vector3(0, SIZE.y / 2.0 + t / 2.0, 0), FRAME_COLOR))
	_board.add_child(_box(Vector3(SIZE.x + t * 2.0, t, 0.016), Vector3(0, -SIZE.y / 2.0 - t / 2.0, 0), FRAME_COLOR))
	_board.add_child(_box(Vector3(t, SIZE.y, 0.016), Vector3(SIZE.x / 2.0 + t / 2.0, 0, 0), FRAME_COLOR))
	_board.add_child(_box(Vector3(t, SIZE.y, 0.016), Vector3(-SIZE.x / 2.0 - t / 2.0, 0, 0), FRAME_COLOR))
	# Kordel: von den oberen Ecken schräg hinauf zum Haken
	var hook := Vector3(0.0, SIZE.y / 2.0 + HOOK_ABOVE, 0.0)
	for side: float in [-1.0, 1.0]:
		var corner := Vector3(side * (SIZE.x / 2.0 - 0.03), SIZE.y / 2.0 + t, 0.0)
		_board.add_child(_cord(corner, hook))
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.009
	sphere.height = 0.018
	knob.mesh = sphere
	knob.material_override = _material(Color(0.62, 0.5, 0.28), 0.35, 0.8)
	knob.position = hook
	_board.add_child(knob)
	# Schrift: vorn (zu der Seite, an der das Schild hängt) der Stand bzw. die Rückseite, hinten (zum Türglas) das andere Wort
	_front = _label(font, false)
	_back = _label(font, true)
	_board.add_child(_front)
	_board.add_child(_back)
	# E-Bereich: etwas tiefer als das Brett, damit der Blick ihn vor der Tür trifft
	_interactable = Interactable.new()
	_interactable.name = "Interactable"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE.x + 0.06, SIZE.y + 0.08, 0.2)
	shape.shape = box
	_interactable.add_child(shape)
	_interactable.position = Vector3(0.0, 0.0, 0.08)
	_board.add_child(_interactable)
	_interactable.interacted.connect(func(_who: Node) -> void: Lending.set_open(not Lending.is_open))


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _material(color, 0.85, 0.0)
	return mesh


func _cord(a: Vector3, b: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.0018
	cylinder.bottom_radius = 0.0018
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 6
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.material_override = _material(Color(0.55, 0.42, 0.3), 0.9, 0.0)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.BACK).normalized()
	mesh.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) / 2.0)
	return mesh


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _label(font: Font, back: bool) -> Label3D:
	var label := Label3D.new()
	label.font = font
	label.font_size = 96
	label.pixel_size = 0.00095
	label.outline_size = 0
	label.double_sided = false
	label.shaded = true
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.position = Vector3(0.0, -0.006, -0.0078 if back else 0.0078)
	if back:
		label.rotation.y = PI
	return label


## Vor die Innen- bzw. Außenseite des Türblatts setzen (Türblatt-Modelle der Fassade sind verschieden dick).
func _fit_to_leaf() -> void:
	var inner := 0.03
	var outer := -0.03
	var hinge := get_parent() as Node3D
	if hinge:
		for node: Node in hinge.find_children("*", "GeometryInstance3D", true, false):
			var visual := node as GeometryInstance3D
			if visual == null or _in_sign(visual, hinge) or not visual.is_visible_in_tree():
				continue
			var box := hinge.global_transform.affine_inverse() * visual.global_transform * visual.get_aabb()
			# nur Teile im Bereich des Schilds (Türblatt, Glas, Sprossen)
			if box.position.y > CENTER_Y + 0.2 or box.end.y < CENTER_Y - 0.2 or box.size.z > 0.3:
				continue
			inner = maxf(inner, box.end.z)
			outer = minf(outer, box.position.z)
	position = Vector3(LEAF_X, 0.0, inner + 0.012 if side > 0.0 else outer - 0.012)
	rotation.y = 0.0 if side > 0.0 else PI


## Teil eines der Schilder (nicht des Türblatts)?
func _in_sign(node: Node, stop: Node) -> bool:
	while node and node != stop:
		if node is OpenSign:
			return true
		node = node.get_parent()
	return false


func _process(delta: float) -> void:
	# Türblatt kann sich ändern (Fassade): ab und zu neu anlegen
	_check -= delta
	if _check <= 0.0:
		_check = 1.5
		_fit_to_leaf()


func _on_open_changed(open: bool) -> void:
	# Umdrehen: halb herum, Schrift tauschen, zurück
	if _flip:
		_flip.kill()
	Audio.play_at("books/take", _board.global_position, -10.0, Audio.vary(0.1))
	_flip = create_tween().set_trans(Tween.TRANS_SINE)
	_flip.tween_property(_board, "rotation:y", PI / 2.0, 0.16).set_ease(Tween.EASE_IN)
	_flip.tween_callback(func() -> void:
		_show(open)
		_board.rotation.y = -PI / 2.0)
	_flip.tween_property(_board, "rotation:y", 0.0, 0.2).set_ease(Tween.EASE_OUT)


func _show(open: bool) -> void:
	# zur Straße der Stand, zur anderen Seite die Rückseite (das andere Wort). Hängt es außen (side < 0), ist die Vorderseite
	# die Straßenseite; hängt es innen, die Rückseite.
	var street := _front if side < 0.0 else _back
	var other := _back if side < 0.0 else _front
	street.text = "Geöffnet" if open else "Geschlossen"
	other.text = "Geschlossen" if open else "Geöffnet"
	street.modulate = TEXT_COLOR
	other.modulate = TEXT_COLOR
	var street_plate := _front_plate if side < 0.0 else _back_plate
	var other_plate := _back_plate if side < 0.0 else _front_plate
	(street_plate.material_override as StandardMaterial3D).albedo_color = OPEN_COLOR if open else CLOSED_COLOR
	(other_plate.material_override as StandardMaterial3D).albedo_color = CLOSED_COLOR if open else OPEN_COLOR
	_interactable.prompt_text = "Umdrehen"
