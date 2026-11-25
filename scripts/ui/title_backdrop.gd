class_name TitleBackdrop
extends Node3D
## Bild hinter dem Hauptmenü (Wunsch der Entwicklerin: der große Baum mit der Rundbank einzeln, ohne Häuser, auf einem
## gemütlichen Hintergrund): eine eigene kleine Welt (TitleScreen zeigt sie in einem SubViewport) – Rasen-Insel mit Bank,
## Hocker und Trittsteinen (assets/models/title/title_garden.glb, tools/blender/build_title_garden.py), der Gartenbaum
## (scenes/world/plants/tree_garden_big.tscn), Blumenbeete (PLANTS unten), weicher Abendhimmel (assets/shaders/
## title_sky.gdshader), warmes, tiefes Sonnenlicht, schwebende Lichtpünktchen und der Malstil wie im Spiel.
## Seit dem zweiten Nachtest der Überarbeitung (Wunsch: „im Hauptmenü fehlt der Bezug zu den Büchern“): ein paar Bücher fliegen
## wie Vögel um den Baum – sie schlagen ihre Deckel wie Flügel, gleiten, legen sich in die Kurve (FlyingBook) –, und zwischen dem
## Herbstlaub segeln lose Buchseiten durch die Luft (_add_pages, LoosePage). Seit der Testrunde nach 8d (Wunsch der Entwicklerin)
## schlagen die Deckel nach unten wie ein Dach über den Seiten (vorher bog sich das Buch rückwärts über den Rücken), und die
## Seiten fallen wie echtes Papier: pendeln, kippen in den Schwung und drehen sich (vorher standen sie immer hochkant).
## Kamera: GameConfig.title_camera_* (wiegt sich sanft). Die Szene lässt sich auch allein starten (F6) zum Ausprobieren.

const PLANT_DIR := "res://scenes/world/plants/"
## Blumen auf der Insel: [Szene, Lage (x, z; m, Mitte der Bank = 0), Drehung (Grad), Größe]. Bank: Radius 0,95 m,
## Hocker bei (1,0 | 0,9), Trittsteine vorn bei x 0,5–0,9 und z 1,2–2,8, Rand der Insel bei 3,1 m.
const PLANTS := [
	["bed_hydrangea_pink", Vector2(-1.75, 1.25), 10.0, 1.2],
	["bed_lavender", Vector2(-1.15, 1.9), 40.0, 1.15],
	["bed_lavender", Vector2(-1.7, 2.15), 110.0, 1.0],
	["bed_daisy", Vector2(-2.3, 1.75), 0.0, 1.1],
	["bed_pansy", Vector2(-0.55, 2.45), 30.0, 1.0],
	["bed_hollyhock_pink", Vector2(-2.0, -1.05), 0.0, 1.1],
	["bed_foxglove", Vector2(-1.45, -1.75), 60.0, 1.1],
	["bed_foxglove", Vector2(-2.45, -0.3), 200.0, 1.0],
	["bed_peony", Vector2(-0.8, -2.35), 0.0, 1.1],
	["bed_hollyhock_pink", Vector2(0.95, -2.35), 90.0, 1.0],
	["bed_rose_bush", Vector2(1.85, -1.55), 0.0, 1.15],
	["bed_marguerite", Vector2(2.45, -0.55), 45.0, 1.05],
	["bed_daisy", Vector2(2.25, 1.3), 0.0, 1.0],
	["bed_tulips", Vector2(1.8, 2.05), 15.0, 1.1],
	["bed_pansy", Vector2(1.45, 2.6), 70.0, 1.0],
	["tuft_daisy", Vector2(2.7, 0.45), 0.0, 1.0],
	["tuft_grass", Vector2(-2.8, 0.65), 0.0, 1.0],
	["tuft_dandelion", Vector2(0.05, 2.85), 0.0, 1.0],
	["tuft_grass_tall", Vector2(-0.4, 2.85), 40.0, 1.0],
	["tuft_grass", Vector2(2.55, 1.95), 120.0, 1.0],
	["tuft_daisy", Vector2(-2.6, -1.4), 0.0, 1.0],
]
## Der Baum wird um seinen Stamm gedreht, damit sich die Krone nach links zum Notizzettel neigt (Wunsch der Entwicklerin;
## in 45°-Schritten, so laufen die Wurzeln weiter zwischen den acht Beinen der Rundbank hindurch)
const TREE_TURN := -135.0
## Woher die Sonne scheint (Punkt, von dem aus sie auf die Bank schaut – tief und von vorn links: warmes Abendlicht)
const SUN_FROM := Vector3(-7.0, 5.5, 8.0)

@onready var _camera: Camera3D = $Camera3D
@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
var _time := 0.0
var _paint := PaintFilterEffect.new()
## Die kleine Welt liegt weit weg vom Ursprung (seit der großen Überarbeitung): dort ist im Spiel der Laden, in dem sich
## im Herbst kein Laub färbt (season_inside) – so wird der Baum im Hauptmenü herbstlich wie draußen.
const WORLD_OFFSET := Vector3(400.0, 0.0, 400.0)
var _leaves: GPUParticles3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # wiegt sich auch, während das Notizbuch (Pause) offen ist
	var plants := $Plants as Node3D
	for entry: Array in PLANTS:
		var scene := load(PLANT_DIR + String(entry[0]) + ".tscn") as PackedScene
		if scene == null:
			continue
		var plant := scene.instantiate() as Node3D
		var spot: Vector2 = entry[1]
		plant.position = Vector3(spot.x, 0.0, spot.y)
		plant.rotation_degrees.y = float(entry[2])
		plant.scale = Vector3.ONE * float(entry[3])
		plants.add_child(plant)
	($Tree as Node3D).rotation_degrees.y = TREE_TURN
	position = WORLD_OFFSET
	_sun.look_at_from_position(SUN_FROM + WORLD_OFFSET, Vector3(0.0, 1.2, 0.0) + WORLD_OFFSET)
	_camera.fov = GameConfig.title_camera_fov
	_camera.global_transform = view(0.0)
	_add_motes()
	_add_flying_books()
	_add_pages()
	# Malstil und Grafikstufe wie im Spiel
	var compositor := Compositor.new()
	compositor.compositor_effects = [_paint]
	_environment.compositor = compositor
	var preset := Settings.get_graphics_preset()
	_paint.apply_config(preset)
	_paint.enabled = int(Settings.get_value("graphics/paint_style")) == 1
	_environment.environment.ssao_enabled = bool(preset.get("ssao", true))
	_sun.shadow_enabled = true
	# Farbabstimmung wie im Spiel (CozyGrade)
	if GameConfig.grade_enabled:
		_environment.environment.adjustment_enabled = true
		_environment.environment.adjustment_color_correction = CozyGrade.make_lut()
	_add_falling_leaves()


## Im Herbst segeln ab und zu Blätter aus der Krone und landen auf der Rasen-Insel (Höhenfeld nur aus Insel, Bank und
## Steinen – Baum und Blumen kommen auf Render-Ebene 2, sonst landeten Blätter in der Krone).
func _add_falling_leaves() -> void:
	for node: Node in [$Tree, $Plants]:
		_move_to_layer2(node)
	_leaves = AutumnLeaves.make_falling(GameConfig.title_leaf_count, 16.0, Vector3(2.4, 1.2, 2.0),
		Vector3(0.35, 0.0, 0.15), 0.42)
	_leaves.name = "FallingLeaves"
	_leaves.position = Vector3(-0.6, 5.4, 0.2)
	_leaves.visibility_aabb = AABB(Vector3(-8, -12, -8), Vector3(16, 16, 16))
	add_child(_leaves)
	var ground := GPUParticlesCollisionHeightField3D.new()
	ground.size = Vector3(12.0, 12.0, 12.0)
	ground.position = Vector3(0.0, 3.0, 0.0)
	ground.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	ground.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	ground.heightfield_mask = 1
	add_child(ground)
	Season.changed.connect(_on_season_changed)
	_on_season_changed(Season.current)


func _on_season_changed(_season: String) -> void:
	if _leaves:
		_leaves.emitting = Season.is_autumn()
		_leaves.visible = Season.is_autumn()


func _move_to_layer2(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 2
	for child in node.get_children():
		_move_to_layer2(child)


func _process(delta: float) -> void:
	_time += delta
	_camera.global_transform = view(_time)


## Blickpunkt der Kamera zur Zeit t: ganz sanftes Wiegen um GameConfig.title_camera_eye / _target.
func view(t: float) -> Transform3D:
	var eye := GameConfig.title_camera_eye + WORLD_OFFSET + Vector3(sin(t * 0.21) * 0.12, sin(t * 0.33) * 0.05, 0.0)
	var target := GameConfig.title_camera_target + WORLD_OFFSET + Vector3(sin(t * 0.17) * 0.1, 0.0, cos(t * 0.13) * 0.06)
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


## Fliegende Bücher: [Einbandfarbe, Mitte der Bahn (m, Mitte der Bank = 0), Halbmesser quer/tief, Umlaufzeit (s), Phase].
## Die Bahnen liegen vor der Krone und im freien Himmel rechts neben dem Notizzettel (von der Kamera aus gesehen).
const FLYING_BOOKS := [
	[Color(0.84, 0.5, 0.52), Vector3(-2.5, 5.4, 3.4), Vector2(3.6, 1.5), 24.0, 0.0],
	[Color(0.47, 0.6, 0.5), Vector3(-3.2, 6.5, 2.6), Vector2(3.0, 1.3), 29.0, 2.4],
	[Color(0.93, 0.76, 0.42), Vector3(-1.8, 4.5, 4.0), Vector2(2.8, 1.2), 21.0, 4.1],
]
## So viel größer als ein echtes Buch (aus der Ferne sonst kaum zu erkennen)
const FLYING_BOOK_SCALE := 1.7
## So viele lose Seiten segeln gleichzeitig durch die Luft
const PAGE_COUNT := 7


func _add_flying_books() -> void:
	for entry: Array in FLYING_BOOKS:
		var book := FlyingBook.new()
		book.cover_color = entry[0]
		book.center = entry[1]
		book.radii = entry[2]
		book.period = float(entry[3])
		book.phase = float(entry[4])
		book.scale = Vector3.ONE * FLYING_BOOK_SCALE
		add_child(book)


## Lose Buchseiten, die langsam durch die Luft segeln (cremefarben, mit ein paar Zeilen), zwischen dem Herbstlaub.
func _add_pages() -> void:
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = _page_texture()
	material.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in PAGE_COUNT:
		var page := LoosePage.new()
		page.name = "Page%d" % i
		page.material_override = material
		page.rng_seed = rng.randi()
		# gleich zu Beginn über die ganze Höhe verteilt
		page.start_fraction = float(i) / float(PAGE_COUNT)
		add_child(page)


## Kleines Bild einer Buchseite: Creme mit weichem Rand und ein paar grauen Zeilen.
func _page_texture() -> ImageTexture:
	var image := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.98, 0.95, 0.87))
	for y in range(9, 58, 5):
		var end := 40 if y < 52 else 26
		for x in range(7, end):
			image.set_pixel(x, y, Color(0.62, 0.58, 0.55))
	for x in 48:
		image.set_pixel(x, 0, Color(0.9, 0.85, 0.75))
		image.set_pixel(x, 63, Color(0.9, 0.85, 0.75))
	return ImageTexture.create_from_image(image)


## Ein Buch, das wie ein Vogel fliegt: Rücken oben in Flugrichtung, die Seiten unten; die beiden Deckel (mit Seiten) schlagen
## wie Flügel nach unten – wie ein Dach über den Seiten, höchstens bis ganz flach auf (weiter ginge ein echter Buchrücken nicht) –,
## dazwischen gleitet es fast flach offen; es folgt einer sanften, liegenden Acht und legt sich in die Kurve.
class FlyingBook extends Node3D:
	var cover_color := Color(0.84, 0.5, 0.52)
	var center := Vector3.ZERO
	var radii := Vector2(3.0, 2.0)
	var period := 25.0
	var phase := 0.0
	var _wings: Array[Node3D] = []
	var _t := 0.0

	func _ready() -> void:
		_t = phase
		var cover := StandardMaterial3D.new()
		cover.albedo_color = cover_color
		cover.roughness = 0.75
		var paper := StandardMaterial3D.new()
		paper.albedo_color = Color(0.97, 0.93, 0.84)
		paper.roughness = 0.95
		var spine := MeshInstance3D.new()
		var spine_mesh := BoxMesh.new()
		spine_mesh.size = Vector3(0.03, 0.03, 0.27)
		spine.mesh = spine_mesh
		spine.material_override = cover
		add_child(spine)
		for side: float in [-1.0, 1.0]:
			var wing := Node3D.new()
			add_child(wing)
			var board := MeshInstance3D.new()
			var board_mesh := BoxMesh.new()
			board_mesh.size = Vector3(0.19, 0.012, 0.27)
			board.mesh = board_mesh
			board.material_override = cover
			board.position = Vector3(side * 0.095, 0.0, 0.0)
			wing.add_child(board)
			var pages := MeshInstance3D.new()
			var pages_mesh := BoxMesh.new()
			pages_mesh.size = Vector3(0.175, 0.024, 0.25)
			pages.mesh = pages_mesh
			pages.material_override = paper
			pages.position = Vector3(side * 0.09, -0.017, 0.0)
			wing.add_child(pages)
			wing.set_meta(&"side", side)
			_wings.append(wing)

	func _process(delta: float) -> void:
		_t += delta
		var w := TAU / period
		var a := _t * w
		var here := _point(a)
		var ahead := _point(a + 0.05)
		var dir := (ahead - here).normalized()
		# sanftes Auf und Ab mit dem Flügelschlag, zwischendurch gleiten (Deckel fast offen)
		var glide := smoothstep(0.2, 0.8, 0.5 + 0.5 * sin(_t * 0.45 + phase))
		var flap_rate := 5.5
		# Deckel hängen 0 (flach offen) bis gut 1 (weit nach unten): beim Schlagen kräftig, beim Gleiten nur ein wenig
		var beat := 0.5 + 0.5 * sin(_t * flap_rate)
		var droop := lerpf(0.12 + 0.95 * beat, 0.14 + 0.08 * beat, glide)
		# der Abschlag (Deckel gehen nach unten) hebt das Buch ein wenig
		position = here + Vector3.UP * (0.08 * sin(_t * flap_rate - 0.6) * (1.0 - glide))
		# in die Kurve legen: seitliche Beschleunigung aus der Bahn
		var turn := (_point(a + 0.1) - here).normalized().cross(dir).y
		var basis := Basis.looking_at(-dir, Vector3.UP)  # Rücken zeigt in Flugrichtung (+z des Buchs nach vorn)
		basis = basis * Basis(Vector3.BACK, clampf(turn * 6.0, -0.5, 0.5))
		transform.basis = basis.scaled(scale)
		for wing in _wings:
			var side := float(wing.get_meta(&"side"))
			# beide Deckel nach unten (Dach-Form über den Seiten), Flügelschlag gegengleich um den Rücken
			wing.rotation = Vector3(0.0, 0.0, -side * droop)

	func _point(a: float) -> Vector3:
		return center + Vector3(cos(a) * radii.x, sin(2.0 * a) * 0.5, sin(a) * radii.y)


## Schwebende Lichtpünktchen (Pollen im Abendlicht): weiche, warme Punkte, die langsam um den Baum treiben.
func _add_motes() -> void:
	var motes := GPUParticles3D.new()
	motes.name = "Motes"
	motes.amount = 70
	motes.lifetime = 14.0
	motes.preprocess = 14.0
	motes.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 10, 12))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(4.5, 2.6, 3.5)
	process.gravity = Vector3(0.0, 0.015, 0.0)
	process.direction = Vector3(0.3, 0.2, 0.1)
	process.spread = 180.0
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.08
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_scale = 3.0
	process.turbulence_noise_speed = Vector3(0.02, 0.02, 0.02)
	process.scale_min = 0.6
	process.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	motes.process_material = process
	motes.position = Vector3(0.6, 2.8, 0.4)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.86, 0.6, 0.85)
	var dot := Gradient.new()
	dot.set_color(0, Color(1, 1, 1, 1))
	dot.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = dot
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	material.albedo_texture = tex
	quad.material = material
	motes.draw_pass_1 = quad
	add_child(motes)


## Eine lose Buchseite, die wie echtes Papier fällt: Sie pendelt hin und her, kippt dabei in den Schwung (am Umkehrpunkt steil,
## in der Mitte flach), dreht sich langsam um sich selbst und treibt mit dem Wind. Unten (oder weit rechts) blendet sie aus und
## beginnt oben neu; dort blendet sie wieder ein.
class LoosePage extends MeshInstance3D:
	## Bereich, in dem die Seiten fallen (Raum der kleinen Welt): links oben beginnen, nach rechts treiben
	const AREA_MIN := Vector3(-6.5, 1.0, -0.5)
	const AREA_MAX := Vector3(1.0, 6.5, 5.0)
	const WIND := Vector3(0.12, 0.0, 0.03)
	var rng_seed := 0
	## wie weit die Seite beim Start schon gefallen ist (0 = oben, 1 = unten)
	var start_fraction := 0.0
	var _rng := RandomNumberGenerator.new()
	var _origin := Vector3.ZERO
	var _t := 0.0
	var _fall := 0.2
	var _swing := 0.5
	var _rate := 1.4
	var _yaw := 0.0
	var _spin := 0.3
	var _phase := 0.0

	func _ready() -> void:
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.3, 0.4)
		mesh = plane
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rng.seed = rng_seed
		_restart()
		_t = start_fraction * (AREA_MAX.y - AREA_MIN.y) / _fall

	func _restart() -> void:
		_origin = Vector3(_rng.randf_range(AREA_MIN.x, AREA_MAX.x - 2.5), AREA_MAX.y, _rng.randf_range(AREA_MIN.z, AREA_MAX.z))
		_t = 0.0
		_fall = _rng.randf_range(0.16, 0.26)
		_swing = _rng.randf_range(0.35, 0.6)
		_rate = _rng.randf_range(1.1, 1.6)
		_yaw = _rng.randf_range(0.0, TAU)
		_spin = _rng.randf_range(-0.35, 0.35)
		_phase = _rng.randf_range(0.0, TAU)

	func _process(delta: float) -> void:
		_t += delta
		var a := _t * _rate + _phase
		# Pendel quer zur Blattrichtung; am Umkehrpunkt bremst das Blatt und fällt kurz schneller
		var yaw := _yaw + _t * _spin
		var across := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		var drop := _t * _fall + 0.04 * (1.0 - cos(2.0 * a))
		position = _origin + WIND * _t + across * (_swing * sin(a)) + Vector3.DOWN * drop
		# kippen in den Schwung (die Kante zeigt in die Bewegung), dazu ein leichtes Nicken
		var bank := -0.75 * cos(a)
		var pitch := 0.18 * sin(2.0 * a + 0.7)
		basis = Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, bank) * Basis(Vector3.RIGHT, pitch)
		# weich ein- und ausblenden (oben und unten im Bereich)
		var height := (position.y - AREA_MIN.y) / (AREA_MAX.y - AREA_MIN.y)
		transparency = 1.0 - clampf(minf((1.0 - height) * 8.0, height * 6.0), 0.0, 1.0)
		if position.y < AREA_MIN.y or position.x > AREA_MAX.x + 3.0:
			_restart()
