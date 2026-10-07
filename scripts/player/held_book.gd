class_name HeldBook
extends Node3D
## Die Bücher, die ich gerade trage – unten rechts im Bild. Vorn das Buch obenauf mit Cover,
## dahinter die übrigen als kleiner Stapel (echte Buchrücken, höchstens
## GameConfig.max_carried_books). Sind die Hände voll und ich möchte noch ein Buch nehmen,
## wackelt der Stapel kurz (BookStock.hands_full) – ganz ohne Text.
## Sitzt an der Kamera der Spielfigur. Ausgeblendet in Menüs, im Gestaltungsmodus und im Sitzen.

## Lage vor der Kamera (rechts unten) und Größe (kleiner und näher = ragt seltener in Wände)
const OFFSET := Vector3(0.21, -0.12, -0.36)
const SCALE := 0.42
## Wackeln bei vollen Händen: Dauer (Sekunden), Stärke (Grad) und Tempo
const WOBBLE_TIME := 0.45
const WOBBLE_ANGLE := 7.0
const WOBBLE_SPEED := 34.0

var _pivot: Node3D
var _book_mesh: MeshInstance3D
var _material: ShaderMaterial
var _stack: MultiMesh
var _shown: Book = null
var _time := 0.0
var _wobble := -1.0  # Zeit seit Beginn des Wackelns, -1 = wackelt nicht
var _player: Player


func _ready() -> void:
	position = OFFSET
	# Cover zeigt zu mir (Buchrücken links), leicht schräg gehalten
	rotation_degrees = Vector3(12.0, -90.0 + 14.0, 6.0)
	scale = Vector3.ONE * SCALE
	_pivot = Node3D.new()
	add_child(_pivot)
	_material = BookLook.create_cover_material()
	_book_mesh = MeshInstance3D.new()
	_book_mesh.mesh = BookLook.get_mesh()
	_book_mesh.material_override = _material
	_book_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_book_mesh)
	# Die übrigen getragenen Bücher dahinter (alle in einem Rutsch, wie im Regal)
	var stack := MultiMeshInstance3D.new()
	_stack = BookLook.create_multimesh()
	stack.multimesh = _stack
	stack.material_override = BookLook.get_material()
	stack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(stack)
	# Die Spielfigur, zu der die Kamera gehört (zum Prüfen, ob sie sitzt)
	var node := get_parent()
	while node and not node is Player:
		node = node.get_parent()
	_player = node as Player
	BookStock.carried_changed.connect(_update)
	BookStock.hands_full.connect(_start_wobble)
	BookArt.atlas_ready.connect(_update)
	_update()


func _process(delta: float) -> void:
	visible = _shown != null and not MenuStack.has_open() and not get_tree().paused \
		and not (_player and _player.is_seated())
	# Ganz leichtes Wiegen, als hielte man es in der Hand
	_time += delta
	position = OFFSET + Vector3(0.0, sin(_time * 1.3) * 0.003, 0.0)
	# Volle Hände: kurzes, sanftes Wackeln, das schnell abklingt
	if _wobble >= 0.0:
		_wobble += delta
		var fade := clampf(1.0 - _wobble / WOBBLE_TIME, 0.0, 1.0)
		var angle := deg_to_rad(WOBBLE_ANGLE) * sin(_wobble * WOBBLE_SPEED) * fade * fade
		_pivot.rotation = Vector3(angle * 0.4, 0.0, angle)
		if fade <= 0.0:
			_wobble = -1.0
			_pivot.rotation = Vector3.ZERO


func _start_wobble() -> void:
	_wobble = 0.0


func _update() -> void:
	var book := BookStock.get_active_book()
	_shown = book
	if book == null:
		_stack.instance_count = 0
		return
	var size := book.data.size
	_book_mesh.scale = size
	_material.set_shader_parameter("single_color", book.data.cover_color)
	_material.set_shader_parameter("single_spine_rect", BookArt.get_spine_uv(book.data))
	var data := book.data
	BookArt.request_cover(data, func(texture: Texture2D) -> void:
		if _shown and _shown.data == data and texture:
			_material.set_shader_parameter("cover_texture", texture))
	# Die übrigen Bücher dahinter: unten bündig, Rücken nach links, je ein Hauch verdreht
	var others: Array[Book] = []
	var count := BookStock.carried.size()
	for i in range(1, count):
		others.append(BookStock.carried[(BookStock.active_index + i) % count])
	_stack.instance_count = others.size()
	var x := -size.x / 2.0 - 0.003
	for i in others.size():
		var other := others[i]
		var other_size := other.data.size
		var yaw := (float((other.look >> 8) & 255) / 255.0 - 0.5) * 0.12
		var origin := Vector3(x - other_size.x / 2.0, (other_size.y - size.y) / 2.0,
			(size.z - other_size.z) / 2.0)
		_stack.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(other_size), origin))
		_stack.set_instance_color(i, BookLook.get_color(other))
		_stack.set_instance_custom_data(i, BookLook.get_custom(other))
		x -= other_size.x + 0.002
