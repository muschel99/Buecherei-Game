class_name TitleBook
extends Node3D
## Hauptmenü als großes aufgeschlagenes Buch (seit der Testrunde nach Etappe 8d, Wunsch der Entwicklerin: „im Hintergrund ein
## großes aufgeschlagenes Buch, der Baum wie eine Abbildung in diesem Buch, der Notizzettel mit dem Menü liegt im Buch“).
## Eine eigene kleine Welt (TitleScreen zeigt sie in einem SubViewport): Das Buch (assets/models/title/title_book.glb,
## tools/blender/build_title_book.py) schwebt vor dem weichen Abendhimmel und wiegt sich sanft. Auf der rechten Seite liegt der
## Garten mit dem großen Baum als lebendiges Bild – die Welt TitleBackdrop (as_picture) in einem eigenen SubViewport, auf die
## Seite gedruckt (assets/shaders/title_page.gdshader): Die Krone wiegt sich, Laub fällt, Lichtpünktchen treiben. Links liegt
## der Notizzettel mit dem Menü (TitleScreen legt ihn mit page_frame auf die Seite). Hinter dem Buch segeln lose Seiten
## (TitleBackdrop.LoosePage) – nie davor, denn der Zettel liegt immer obenauf. Fliegende Bücher gibt es hier nicht mehr (Wunsch
## der Entwicklerin); das Buch ist genau frontal zu sehen und liegt etwas schief.
## Kamera, Neigung und Schweben: GameConfig.title_book_*, Kamera des Bilds: title_picture_*. Allein starten (F6) zum Ausprobieren.

const BACKDROP := preload("res://scenes/ui/title_backdrop.tscn")
const PAGE_SHADER := preload("res://assets/shaders/title_page.gdshader")
## Weit weg vom Ursprung, wie TitleBackdrop (dort liegen im Spiel die Bereiche des Ladens für den Herbst-Shader)
const WORLD_OFFSET := Vector3(400.0, 0.0, 400.0)
## Woher die Sonne scheint: tief und von vorn links wie im Garten – die Seiten liegen im warmen Abendlicht
const SUN_FROM := Vector3(-6.0, 6.0, 7.0)
## Maße des Buchs (wie build_title_book.py): Seitenbreite, halbe Seitenhöhe, höchste Stelle der Seiten über dem Deckel
const PAGE_WIDTH := 1.0
const PAGE_HALF_HEIGHT := 0.7
const PAGE_TOP := 0.1
## Bildfläche auf der rechten Seite (u0, v0, u1, v1 – wie im Shader) und Größe der Seite (m): daraus das Format des Bilds
const PICTURE_RECT := Vector4(0.1, 0.07, 0.92, 0.88)
const PAGE_SIZE := Vector2(1.0, 1.4)
## Lose Seiten hinter dem Buch: Bereich (Raum dieser Welt), Wind, Größe, Anzahl
const PAGE_AREA_MIN := Vector3(-3.0, -1.0, -2.2)
const PAGE_AREA_MAX := Vector3(2.4, 1.9, -0.8)
const PAGE_WIND := Vector3(0.07, 0.0, 0.0)
const LOOSE_PAGE_SIZE := Vector2(0.14, 0.19)
const LOOSE_PAGE_COUNT := 5

@onready var _camera: Camera3D = $Camera3D
@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _book: Node3D = $Book
var _time := 0.0
var _paint := PaintFilterEffect.new()
var _picture: SubViewport


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # wiegt sich auch, während das Notizbuch (Pause) offen ist
	position = WORLD_OFFSET
	_sun.look_at_from_position(SUN_FROM + WORLD_OFFSET, WORLD_OFFSET, Vector3.UP)
	_camera.fov = GameConfig.title_book_fov
	_camera.global_transform = Transform3D(Basis.looking_at(GameConfig.title_book_target - GameConfig.title_book_eye, Vector3.UP),
		GameConfig.title_book_eye + WORLD_OFFSET)
	_book.transform = _book_transform(0.0)
	_setup_pages()
	_add_loose_pages()
	# Malstil und Grafikstufe wie im Spiel
	var compositor := Compositor.new()
	compositor.compositor_effects = [_paint]
	_environment.compositor = compositor
	var preset := Settings.get_graphics_preset()
	_paint.apply_config(preset)
	_paint.enabled = int(Settings.get_value("graphics/paint_style")) == 1
	_environment.environment.ssao_enabled = bool(preset.get("ssao", true))
	if GameConfig.grade_enabled:
		_environment.environment.adjustment_enabled = true
		_environment.environment.adjustment_color_correction = CozyGrade.make_lut()


func _process(delta: float) -> void:
	_time += delta
	_book.transform = _book_transform(_time)


## Lage des Buchs zur Zeit t: zur Kamera gekippt, liegt schief (links tiefer), schwebt ganz sanft auf und ab und wiegt sich ein
## wenig.
func _book_transform(t: float) -> Transform3D:
	var tilt := deg_to_rad(GameConfig.title_book_tilt + sin(t * 0.51) * GameConfig.title_book_sway * 0.6)
	var roll := deg_to_rad(GameConfig.title_book_roll + sin(t * 0.37 + 1.0) * GameConfig.title_book_sway)
	var bob := sin(t * 0.7) * GameConfig.title_book_bob
	return Transform3D(Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, tilt), Vector3(0.0, bob, 0.0))


## Wo eine Seite (side -1 = links, 1 = rechts) im Fenster dieser Welt liegt (Lage des Buchs ohne Schweben): Mitte, Breite und
## Höhe entlang der Seite und ihre Drehung (Bogenmaß, wie Control.rotation) – das Buch liegt schief.
func page_frame(side: float) -> Dictionary:
	var rest := global_transform * _book_transform(0.0)
	var inner := side * 0.002
	var outer := side * PAGE_WIDTH
	var mid := (inner + outer) / 2.0
	var at := func(x: float, z: float) -> Vector2: return _camera.unproject_position(rest * Vector3(x, PAGE_TOP, z))
	var left: Vector2 = at.call(minf(inner, outer), 0.0)
	var right: Vector2 = at.call(maxf(inner, outer), 0.0)
	var top: Vector2 = at.call(mid, -PAGE_HALF_HEIGHT)
	var bottom: Vector2 = at.call(mid, PAGE_HALF_HEIGHT)
	return {"center": at.call(mid, 0.0), "size": Vector2(left.distance_to(right), top.distance_to(bottom)),
		"angle": (right - left).angle()}


## „Weiterspielen“: Die Kamera fährt in das lebendige Bild auf der rechten Seite hinein (TitleScreen blendet dabei ins Spiel
## über) – zuletzt füllt der Garten das ganze Bild.
func fly_into_picture(duration: float) -> void:
	var rest := global_transform * _book_transform(0.0)
	var u := (PICTURE_RECT.x + PICTURE_RECT.z) / 2.0
	var v := (PICTURE_RECT.y + PICTURE_RECT.w) / 2.0
	var center := rest * Vector3(0.002 + u * (PAGE_WIDTH - 0.002), PAGE_TOP, -PAGE_HALF_HEIGHT + v * 2.0 * PAGE_HALF_HEIGHT)
	var normal := rest.basis.y.normalized()
	var end := Transform3D(Basis.looking_at(-normal, -rest.basis.z.normalized()), center + normal * 0.75)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "global_transform", end, duration)


## Papier auf beiden Seiten (Schatten zum Falz hin), rechts dazu das lebendige Bild des Gartens.
func _setup_pages() -> void:
	var left := _book.find_child("Seite links*", true, false) as MeshInstance3D
	var right := _book.find_child("Seite rechts*", true, false) as MeshInstance3D
	if left:
		var paper := ShaderMaterial.new()
		paper.shader = PAGE_SHADER
		paper.set_shader_parameter("fold_at", 1.0)
		left.material_override = paper
	if right:
		var page := ShaderMaterial.new()
		page.shader = PAGE_SHADER
		page.set_shader_parameter("fold_at", 0.0)
		page.set_shader_parameter("picture_rect", PICTURE_RECT)
		_picture = _make_picture()
		page.set_shader_parameter("picture", _picture.get_texture())
		page.set_shader_parameter("has_picture", true)
		right.material_override = page


## Eigene kleine Welt mit dem Garten (TitleBackdrop als Bild), hochkant im Format der Bildfläche.
func _make_picture() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "Picture"
	viewport.own_world_3d = true
	viewport.audio_listener_enable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var aspect := (PICTURE_RECT.z - PICTURE_RECT.x) * PAGE_SIZE.x / ((PICTURE_RECT.w - PICTURE_RECT.y) * PAGE_SIZE.y)
	var width := GameConfig.title_picture_width
	viewport.size = Vector2i(width, roundi(width / aspect))
	Settings.match_preview_quality(viewport)
	add_child(viewport)
	var garden := BACKDROP.instantiate() as TitleBackdrop
	garden.as_picture = true
	viewport.add_child(garden)
	return viewport


## Lose Seiten, die hinter dem Buch durch die Luft segeln.
func _add_loose_pages() -> void:
	for page in TitleBackdrop.make_pages(LOOSE_PAGE_COUNT, 11):
		page.area_min = PAGE_AREA_MIN
		page.area_max = PAGE_AREA_MAX
		page.wind = PAGE_WIND
		page.page_size = LOOSE_PAGE_SIZE
		add_child(page)
