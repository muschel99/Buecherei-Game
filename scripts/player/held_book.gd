class_name HeldBook
extends Node3D
## Das Buch, das ich gerade obenauf in der Hand halte – unten rechts im Bild, mit Cover.
## Trage ich mehrere, liegen darunter ein paar weitere (nur angedeutet).
## Sitzt an der Kamera der Spielfigur. Ausgeblendet in Menüs, im Gestaltungsmodus und im Sitzen.

## Lage vor der Kamera (rechts unten) und Größe (kleiner und näher = ragt seltener in Wände)
const OFFSET := Vector3(0.21, -0.12, -0.36)
const SCALE := 0.42

var _book_mesh: MeshInstance3D
var _material: ShaderMaterial
var _stack: MeshInstance3D
var _shown: Book = null
var _time := 0.0
var _player: Player


func _ready() -> void:
	position = OFFSET
	# Cover zeigt zu mir (Buchrücken links), leicht schräg gehalten
	rotation_degrees = Vector3(12.0, -90.0 + 14.0, 6.0)
	scale = Vector3.ONE * SCALE
	_material = BookLook.create_cover_material()
	_book_mesh = MeshInstance3D.new()
	_book_mesh.mesh = BookLook.get_mesh()
	_book_mesh.material_override = _material
	_book_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_book_mesh)
	# Angedeuteter Stapel weiterer Bücher darunter
	_stack = MeshInstance3D.new()
	_stack.mesh = BookLook.get_mesh()
	var stack_material := StandardMaterial3D.new()
	stack_material.albedo_color = Color(0.86, 0.82, 0.72)
	_stack.material_override = stack_material
	_stack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stack)
	# Die Spielfigur, zu der die Kamera gehört (zum Prüfen, ob sie sitzt)
	var node := get_parent()
	while node and not node is Player:
		node = node.get_parent()
	_player = node as Player
	BookStock.carried_changed.connect(_update)
	BookArt.atlas_ready.connect(_update)
	_update()


func _process(delta: float) -> void:
	visible = _shown != null and not MenuStack.has_open() and not get_tree().paused \
		and not (_player and _player.is_seated())
	# Ganz leichtes Wiegen, als hielte man es in der Hand
	_time += delta
	position = OFFSET + Vector3(0.0, sin(_time * 1.3) * 0.003, 0.0)


func _update() -> void:
	var book := BookStock.get_active_book()
	_shown = book
	if book == null:
		return
	var size := book.data.size
	_book_mesh.scale = size
	_material.set_shader_parameter("single_color", book.data.cover_color)
	_material.set_shader_parameter("single_spine_rect", BookArt.get_spine_uv(book.data))
	var data := book.data
	BookArt.request_cover(data, func(texture: Texture2D) -> void:
		if _shown and _shown.data == data and texture:
			_material.set_shader_parameter("cover_texture", texture))
	# Weitere Bücher als heller Block darunter (je Buch etwas dicker)
	var others := BookStock.carried.size() - 1
	_stack.visible = others > 0
	if others > 0:
		var thickness := minf(others * 0.025, 0.14)
		_stack.scale = Vector3(thickness, size.y * 0.96, size.z * 0.96)
		_stack.position = Vector3(-(size.x + thickness) / 2.0 - 0.002, -0.004, 0.006)
