class_name ShopTablet
extends Node3D
## Das Tablet auf der Theke: Mit E öffnet sich das Theken-Tablet mit seinen Apps (CounterTablet).
## Seit dem Nachtest von Etappe 8 steht es schräg auf einem Ständer, links daneben der Kartenleser (mit Kabel verbunden; Modell
## furniture_fixtures.build_tablet). Während man einen Gast bedient (CounterDesk), zeigt der Bildschirm „Bücherei-Ausleihe“
## (LoanScreen in einem SubViewport, als Fläche ohne Licht 1,5 mm vor dem Bildschirm) – sonst sein ruhiges warmes Leuchten.
## Lagen im Raum des Tablets (Godot-Achsen, Bildschirm nach +Z) – passend zum Modell (TABLET_TILT, READER_X dort).

const GROUP := &"shop_tablets"
const SCREEN_CENTER := Vector3(0.0, 0.0987, -0.0355)
const SCREEN_SIZE := Vector2(0.236, 0.152)
const SCREEN_TILT := -50.0
const READER_SLOT := Vector3(-0.24, 0.0405, 0.02)
const SCREEN_PIXELS := Vector2i(560, 360)

var screen: LoanScreen
var _viewport: SubViewport
var _quad: MeshInstance3D
var _redraw_left := 0.0


func _ready() -> void:
	add_to_group(GROUP)


func _on_interactable_interacted(_interactor: Node) -> void:
	get_tree().call_group(CounterTablet.GROUP, "open_tablet")


## Anzeige „Bücherei-Ausleihe“ ein- oder ausblenden (beim ersten Mal wird sie gebaut).
func show_loan(on: bool) -> void:
	if on and _quad == null:
		_build_screen()
	if _quad:
		_quad.visible = on
	if on:
		screen.show_wait()


func reader_slot_global() -> Vector3:
	return global_transform * READER_SLOT


func _build_screen() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SCREEN_PIXELS
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	screen = LoanScreen.new()
	screen.size = Vector2(SCREEN_PIXELS)
	screen.changed.connect(_redraw)
	_viewport.add_child(screen)
	_quad = MeshInstance3D.new()
	_quad.name = "LoanScreen"
	var mesh := QuadMesh.new()
	mesh.size = SCREEN_SIZE
	_quad.mesh = mesh
	# ohne Licht: der Bildschirm leuchtet selbst, die Farben bleiben genau so, wie gezeichnet
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.albedo_color = Color(0.94, 0.94, 0.94)
	_quad.material_override = material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(SCREEN_TILT)), SCREEN_CENTER)
	add_child(_quad)


func _process(delta: float) -> void:
	if _redraw_left > 0.0:
		_redraw_left -= delta
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _redraw_left > 0.0 else SubViewport.UPDATE_ONCE


## Bild neu zeichnen (seconds > 0: so lange laufend, z. B. während ein Stempel aufploppt).
func _redraw(seconds: float = 0.0) -> void:
	_redraw_left = maxf(_redraw_left, seconds)
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _redraw_left > 0.0 else SubViewport.UPDATE_ONCE
