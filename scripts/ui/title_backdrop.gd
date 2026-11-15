class_name TitleBackdrop
extends Node3D
## Bild hinter dem Hauptmenü (Wunsch der Entwicklerin: der große Baum mit der Rundbank einzeln, ohne Häuser, auf einem
## gemütlichen Hintergrund): eine eigene kleine Welt (TitleScreen zeigt sie in einem SubViewport) – Rasen-Insel mit Bank,
## Hocker und Trittsteinen (assets/models/title/title_garden.glb, tools/blender/build_title_garden.py), der Gartenbaum
## (scenes/world/plants/tree_garden_big.tscn), Blumenbeete (PLANTS unten), weicher Abendhimmel (assets/shaders/
## title_sky.gdshader), warmes, tiefes Sonnenlicht, schwebende Lichtpünktchen und der Malstil wie im Spiel.
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
	_sun.look_at_from_position(SUN_FROM, Vector3(0.0, 1.2, 0.0))
	_camera.fov = GameConfig.title_camera_fov
	_camera.global_transform = view(0.0)
	_add_motes()
	# Malstil und Grafikstufe wie im Spiel
	var compositor := Compositor.new()
	compositor.compositor_effects = [_paint]
	_environment.compositor = compositor
	var preset := Settings.get_graphics_preset()
	_paint.apply_config(preset)
	_paint.enabled = int(Settings.get_value("graphics/paint_style")) == 1
	_environment.environment.ssao_enabled = bool(preset.get("ssao", true))
	_sun.shadow_enabled = true


func _process(delta: float) -> void:
	_time += delta
	_camera.global_transform = view(_time)


## Blickpunkt der Kamera zur Zeit t: ganz sanftes Wiegen um GameConfig.title_camera_eye / _target.
func view(t: float) -> Transform3D:
	var eye := GameConfig.title_camera_eye + Vector3(sin(t * 0.21) * 0.12, sin(t * 0.33) * 0.05, 0.0)
	var target := GameConfig.title_camera_target + Vector3(sin(t * 0.17) * 0.1, 0.0, cos(t * 0.13) * 0.06)
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


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
