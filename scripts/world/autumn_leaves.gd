class_name AutumnLeaves
extends Node3D
## Herbst draußen (seit der großen Überarbeitung, Wunsch der Entwicklerin: „cozy Herbst“):
## - Blätter fallen langsam rund um die Spielfigur (vom Wind herübergeweht) und dichter unter den Bäumen, flattern,
##   treiben im Wind und bleiben auf Straße und Gehweg liegen (Partikel, Shader autumn_leaf_fall/autumn_leaf).
## - Laub am Boden: dicht am Bordstein (in der Rinne) und am Fuß der Hauswände, sonst vereinzelt (ein MultiMesh).
## Alles nur im Herbst (Season.autumn, weich ein-/ausgeblendet). main.gd legt den Knoten unter Outside an; Lage wie
## StreetLife (x/z der Straße, Gehweg auf y = 0). Werte: GameConfig.autumn_*.
##
## Gelandet wird auf einem Höhenfeld aus allem Festen (Render-Ebene GROUND_LAYER: Boden, Häuser mit Dächern, Fensterbänken,
## Markisen, Treppe) – ohne Pflanzen, Passanten und Fahrzeuge (sonst blieben Blätter in der Luft hängen, wenn sie weitergehen).

const LEAF_SHADER := preload("res://assets/shaders/autumn_leaf.gdshader")
const FALL_SHADER := preload("res://assets/shaders/autumn_leaf_fall.gdshader")
## Render-Ebene nur für den Boden, auf dem fallende Blätter landen (Höhenfeld)
const GROUND_LAYER := 12
## Boden-Materialien (Shader), die zur Landefläche gehören
const GROUND_SHADERS := ["storybook_ground.gdshader"]

## Herbstfarben (sRGB): Gold, Orange, Rot, Braun
const PALETTE: Array[Color] = [Color(0.9, 0.68, 0.2), Color(0.9, 0.44, 0.13), Color(0.72, 0.2, 0.1),
	Color(0.6, 0.45, 0.22), Color(0.82, 0.56, 0.16)]

var _leaf_mesh: Mesh
var _falling: GPUParticles3D
var _tree_falls: Array[GPUParticles3D] = []
var _heightfield: GPUParticlesCollisionHeightField3D
var _litter: MultiMeshInstance3D
var _camera_ref: Camera3D
## Laub am Boden je Zelle (KICK_CELL m) – wo viel liegt, wirbelt die Spielfigur beim Gehen Blätter auf
const KICK_CELL := 0.75
var _litter_cells := {}
var _kick_wait := 0.0
var _player: CharacterBody3D


func _ready() -> void:
	_leaf_mesh = _make_leaf_mesh()
	# Erst wenn Straße, Häuser und Pflanzen stehen (Physik bereit für die Strahlen beim Laub am Boden)
	_setup.call_deferred()


func _setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_mark_ground(get_parent())
	# Häuser, Bücherei-Fassade, Obergeschosse, Treppe: Blätter landen auch auf Dächern, Fensterbänken und Markisen
	# (nur feste Teile – Passanten, Autos und Pflanzen nicht, sonst blieben Blätter in der Luft hängen)
	var main := get_parent().get_parent()
	for path in ["Outside/Houses", "Outside/Alley", "Outside/OppositeAlley", "Outside/Plaza", "UpperFloors", "EntranceSteps",
			"GroundFloorRoom/Facade"]:
		var node := main.get_node_or_null(path)
		if node:
			_mark_all(node)
	_build_falling()
	_build_tree_falls()
	_build_litter()
	Season.changed.connect(_on_season_changed)
	_apply_amount()


func _on_season_changed(_season: String) -> void:
	_apply_amount()


## Ein Blatt: flaches Viereck (x = Breite, z = Länge, Stiel bei -z), drei Spalten für die Wölbung.
static func _make_leaf_mesh() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.75, 1.0)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var material := ShaderMaterial.new()
	material.shader = LEAF_SHADER
	plane.material = material
	return plane


## Boden-Flächen kommen zusätzlich auf die Render-Ebene GROUND_LAYER (fürs Höhenfeld der Landung).
func _mark_ground(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i) as ShaderMaterial
			if material and material.shader and material.shader.resource_path.get_file() in GROUND_SHADERS:
				mesh_instance.set_layer_mask_value(GROUND_LAYER, true)
				break
	for child in node.get_children():
		_mark_ground(child)


## Alle festen Modelle darunter (Häuser) kommen auf die Landefläche – ohne Pflanzen (die wiegen sich im Wind).
func _mark_all(node: Node) -> void:
	var geometry := node as GeometryInstance3D
	if geometry and not geometry is GPUParticles3D and not geometry is MultiMeshInstance3D:
		var plant := false
		var mesh_instance := node as MeshInstance3D
		if mesh_instance and mesh_instance.mesh:
			for i in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(i) as ShaderMaterial
				if material and material.shader and material.shader.resource_path.ends_with("storybook_plant.gdshader"):
					plant = true
		if not plant:
			geometry.set_layer_mask_value(GROUND_LAYER, true)
	for child in node.get_children():
		_mark_all(child)


static func _fall_material(box: Vector3, wind: Vector3, fall_speed: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FALL_SHADER
	material.set_shader_parameter("emission_box", box)
	material.set_shader_parameter("wind", wind)
	material.set_shader_parameter("fall_speed", fall_speed)
	material.set_shader_parameter("flutter", GameConfig.autumn_flutter)
	return material


static func _draw_mesh() -> Mesh:
	var plane := _make_leaf_mesh() as PlaneMesh
	var material := ShaderMaterial.new()
	material.shader = LEAF_SHADER
	material.set_shader_parameter("tumble", 1.0)
	plane.material = material
	return plane


## Fallende Blätter (auch fürs Hauptmenü, TitleBackdrop): box = Halbmaße des Startkastens um den Knoten.
static func make_falling(amount: int, lifetime: float, box: Vector3, wind: Vector3, fall_speed: float) -> GPUParticles3D:
	var p := _new_particles(amount, lifetime)
	p.process_material = _fall_material(box, wind, fall_speed)
	return p


static func _new_particles(amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.preprocess = lifetime  # beim Start liegen schon Blätter, und es fällt schon
	p.local_coords = false
	p.collision_base_size = 0.02
	p.draw_pass_1 = _draw_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.randomness = 1.0
	return p


## Blätter, die rund um die Kamera vom Wind herübergeweht werden (folgen der Kamera).
func _build_falling() -> void:
	var box := Vector3(GameConfig.autumn_fall_radius, 3.0, GameConfig.autumn_fall_radius)
	_falling = _new_particles(GameConfig.autumn_fall_count, GameConfig.autumn_fall_lifetime)
	_falling.name = "FallingLeaves"
	_falling.process_material = _fall_material(box, GameConfig.autumn_wind, GameConfig.autumn_fall_speed)
	var r := GameConfig.autumn_fall_radius + 8.0
	_falling.visibility_aabb = AABB(Vector3(-r, -16.0, -r), Vector3(r * 2.0, 32.0, r * 2.0))
	add_child(_falling)
	# Landefläche: Höhenfeld aus dem Boden, folgt der Kamera
	_heightfield = GPUParticlesCollisionHeightField3D.new()
	_heightfield.name = "LeafGround"
	_heightfield.size = Vector3(r * 2.0, 30.0, r * 2.0)
	_heightfield.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_heightfield.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	_heightfield.follow_camera_enabled = true
	_heightfield.heightfield_mask = 1 << (GROUND_LAYER - 1)
	add_child(_heightfield)


## Unter jedem Baum (Greenery.trees) fallen mehr Blätter aus der Krone.
func _build_tree_falls() -> void:
	var greenery := get_tree().get_first_node_in_group(Greenery.GROUP) as Greenery
	if greenery == null:
		return
	for tree: Dictionary in greenery.trees:
		var size: Vector3 = tree.size
		var p := _new_particles(GameConfig.autumn_tree_count, GameConfig.autumn_tree_lifetime)
		p.name = "TreeLeaves"
		var crown := Vector3(size.x * 0.4, size.y * 0.18, size.z * 0.4)
		p.process_material = _fall_material(crown, GameConfig.autumn_wind * 0.4, GameConfig.autumn_fall_speed * 0.8)
		var center := greenery.to_global(tree.position) + Vector3.UP * size.y * 0.6
		p.visibility_aabb = AABB(Vector3(-size.x, -size.y, -size.z), size * 2.0)
		add_child(p)
		p.global_position = center
		_tree_falls.append(p)


## Laub am Boden: dicht in der Rinne am Bordstein und am Fuß der Hauswände, dazwischen vereinzelt. Wo etwas steht
## (Strahl von oben trifft höher als den Boden), liegt nichts.
func _build_litter() -> void:
	var route := StreetPaths.centerline()
	var half := GameConfig.street_width / 2.0
	var road_y := -GameConfig.curb_height
	var noise := FastNoiseLite.new()
	noise.seed = 1977
	noise.frequency = 0.09
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var length := route.length()
	var s := 0.0
	var step := GameConfig.autumn_litter_step
	while s < length:
		var part := route.part_at(s)
		for side: int in [1, -1]:
			var band := StreetPaths.sidewalk_band(part, side)
			var wall := absf(band.y if side > 0 else band.x) + StreetPaths.WALL_CLEARANCE
			var cluster := noise.get_noise_2d(s, side * 50.0) * 0.5 + 0.5
			# in der Rinne (Fahrbahn, dicht am Bordstein)
			if part not in ["passage"] and rng.randf() < smoothstep(0.25, 0.7, cluster) * GameConfig.autumn_litter_density:
				# dicht am Bordstein mehr, manchmal ein kleiner Haufen
				var lat: float = (half - 0.03 - pow(rng.randf(), 1.8) * 0.4) * side
				var pile := 3 if rng.randf() < 0.18 * cluster else 1
				for k in pile:
					_add_leaf(route, s + rng.randf_range(-step, step) * (1 + k), lat - side * k * 0.05, road_y, rng, xforms,
						colors, space, query)
			# am Fuß der Hauswand
			var at_wall := noise.get_noise_2d(s * 1.3, side * 90.0 + 7.0) * 0.5 + 0.5
			if rng.randf() < smoothstep(0.35, 0.8, at_wall) * GameConfig.autumn_litter_density * 0.8:
				var lat2: float = (wall - rng.randf_range(0.06, 0.45)) * side
				_add_leaf(route, s + rng.randf_range(-step, step), lat2, 0.0, rng, xforms, colors, space, query)
			# vereinzelt auf dem Gehweg
			if rng.randf() < GameConfig.autumn_litter_scatter:
				var lat3: float = rng.randf_range(half + 0.4, wall - 0.3) * side
				_add_leaf(route, s + rng.randf_range(-step, step), lat3, 0.0, rng, xforms, colors, space, query)
		# vereinzelt auf der Fahrbahn
		if rng.randf() < GameConfig.autumn_litter_scatter * 0.6:
			_add_leaf(route, s, rng.randf_range(-half + 0.4, half - 0.4), road_y, rng, xforms, colors, space, query)
		s += step
	_tree_litter(rng, xforms, colors, space)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _leaf_mesh
	multimesh.instance_count = xforms.size()
	for i in xforms.size():
		multimesh.set_instance_transform(i, xforms[i])
		multimesh.set_instance_color(i, colors[i])
	_litter = MultiMeshInstance3D.new()
	_litter.name = "LeafLitter"
	_litter.multimesh = multimesh
	_litter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_litter)


## Unter jedem Baum ein Laubteppich: dicht am Stamm, nach außen dünner, liegt auf dem, was der Strahl von oben trifft
## (Rasen, Pflaster) – nicht auf Bänken oder Beeten (höher als der Boden am Stamm).
func _tree_litter(rng: RandomNumberGenerator, xforms: Array[Transform3D], colors: Array[Color],
		space: PhysicsDirectSpaceState3D) -> void:
	var greenery := get_tree().get_first_node_in_group(Greenery.GROUP) as Greenery
	if greenery == null:
		return
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	for tree: Dictionary in greenery.trees:
		var size: Vector3 = tree.size
		var base := to_local(greenery.to_global(tree.position))
		# Ring um den Stamm (innen steht die Rundbank, außen beginnt irgendwann Pflaster): dort ist Rasen
		var inner := 1.25
		var reach := minf(maxf(size.x, size.z) * 0.4, 2.3)
		for k in GameConfig.autumn_tree_litter:
			var a := rng.randf() * TAU
			var r := sqrt(lerpf(inner * inner / (reach * reach), 1.0, rng.randf())) * reach
			var p := base + Vector3(cos(a) * r, 0.0, sin(a) * r)
			query.from = to_global(p + Vector3.UP * 1.2)
			query.to = to_global(p + Vector3.DOWN * 1.0)
			var hit := space.intersect_ray(query)
			if hit.is_empty() or hit.normal.y < 0.8:
				continue
			var y := to_local(hit.position).y
			if absf(y - base.y) > 0.35:
				continue
			# der Rasen ist ein flacher Körper (2,4 cm) ohne eigene Kollision: Blätter liegen obendrauf
			_leaf_at(Vector3(p.x, y + GameConfig.autumn_lawn_lift, p.z), rng, xforms, colors, 0)


func _leaf_at(at: Vector3, rng: RandomNumberGenerator, xforms: Array[Transform3D], colors: Array[Color], k: int) -> void:
	var size := rng.randf_range(GameConfig.autumn_leaf_size.x, GameConfig.autumn_leaf_size.y)
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	basis = basis.rotated(basis.x, rng.randf_range(-0.12, 0.12)).scaled(Vector3.ONE * size)
	xforms.append(Transform3D(basis, at + Vector3.UP * (0.004 + 0.002 * k)))
	var cell := Vector2i(floori(at.x / KICK_CELL), floori(at.z / KICK_CELL))
	_litter_cells[cell] = int(_litter_cells.get(cell, 0)) + 1
	var c := PALETTE[rng.randi() % PALETTE.size()]
	c = c.lerp(Color(0.52, 0.36, 0.2), rng.randf_range(0.05, 0.35)) * rng.randf_range(0.82, 1.0)
	c.a = 1.0
	colors.append(c)


## Ein Blatt (oft mit ein, zwei Nachbarn) an die Stelle s/lat der Mittellinie legen – nur, wenn dort nichts steht.
func _add_leaf(route: StreetRoute, s: float, lat: float, y: float, rng: RandomNumberGenerator, xforms: Array[Transform3D],
		colors: Array[Color], space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D) -> void:
	var p2 := route.point_at(clampf(s, 0.0, route.length()), lat)
	var local := Vector3(p2.x, y, p2.y)
	var top := to_global(local + Vector3.UP * 2.5)
	query.from = top
	query.to = to_global(local + Vector3.DOWN * 0.6)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or to_local(hit.position).y > 0.06:
		return  # nichts darunter (außerhalb) oder etwas steht dort (Bank, Kübel, Treppe …)
	var count := 1 + (1 if rng.randf() < 0.55 else 0) + (1 if rng.randf() < 0.3 else 0) + (1 if rng.randf() < 0.15 else 0)
	for k in count:
		var offset := Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1)) * float(k)
		_leaf_at(local + offset, rng, xforms, colors, k)


## Kamera folgen (fallende Blätter rund um die Spielfigur), Menge nach der Jahreszeit.
func _process(delta: float) -> void:
	if _falling == null:
		return
	_update_kick(delta)
	var camera := get_viewport().get_camera_3d()
	if camera:
		_falling.global_position = camera.global_position + Vector3.UP * GameConfig.autumn_fall_height
	if not is_equal_approx(_falling.amount_ratio, Season.autumn):
		_apply_amount()


## Durchs Laub gehen: ein paar Blätter wirbeln an den Füßen auf, leises Rascheln (nur im Herbst, nur wo Laub liegt).
func _update_kick(delta: float) -> void:
	_kick_wait -= delta
	if _kick_wait > 0.0 or Season.autumn < 0.5:
		return
	_kick_wait = 0.22
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		if _player == null:
			return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed < 1.2 or not _player.is_on_floor():
		return
	var feet := to_local(_player.global_position)
	var cell := Vector2i(floori(feet.x / KICK_CELL), floori(feet.z / KICK_CELL))
	var count := int(_litter_cells.get(cell, 0))
	if count < 3 or randf() > clampf(count / 10.0, 0.25, 0.9):
		return
	var kick := CPUParticles3D.new()
	kick.one_shot = true
	kick.amount = clampi(count / 2, 3, 7)
	kick.lifetime = 1.1
	kick.explosiveness = 0.9
	kick.local_coords = false
	kick.mesh = _draw_mesh_static()
	kick.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	kick.emission_sphere_radius = 0.2
	kick.direction = Vector3(_player.velocity.x, 2.5, _player.velocity.z).normalized()
	kick.spread = 45.0
	kick.initial_velocity_min = 0.6
	kick.initial_velocity_max = 1.2 + speed * 0.2
	kick.gravity = Vector3(0, -2.2, 0)
	kick.damping_min = 0.8
	kick.damping_max = 1.6
	kick.angular_velocity_min = -360.0
	kick.angular_velocity_max = 360.0
	kick.particle_flag_rotate_y = true
	kick.scale_amount_min = GameConfig.autumn_leaf_size.x
	kick.scale_amount_max = GameConfig.autumn_leaf_size.y
	kick.color_initial_ramp = _palette_gradient()
	kick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(kick)
	kick.global_position = _player.global_position + Vector3.UP * 0.05
	kick.finished.connect(kick.queue_free)
	kick.emitting = true
	Audio.play_at("ambience/plant_rustle", _player.global_position, GameConfig.autumn_kick_volume_db, Audio.vary(0.12))


var _kick_mesh: Mesh


## Blatt fürs Aufwirbeln: flach, Farbe aus der Teilchenfarbe (ohne Schaukeln, die Teilchen drehen sich selbst).
func _draw_mesh_static() -> Mesh:
	if _kick_mesh == null:
		var plane := _make_leaf_mesh() as PlaneMesh
		var material := ShaderMaterial.new()
		material.shader = LEAF_SHADER
		material.set_shader_parameter("tumble", 0.0)
		material.set_shader_parameter("fold", 0.3)
		plane.material = material
		_kick_mesh = plane
	return _kick_mesh


func _palette_gradient() -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in PALETTE.size():
		offsets.append(float(i) / (PALETTE.size() - 1))
		colors.append(PALETTE[i])
	g.offsets = offsets
	g.colors = colors
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g


func _apply_amount() -> void:
	var amount := Season.autumn
	var on := amount > 0.001
	for p: GPUParticles3D in [_falling] + _tree_falls:
		if p == null:
			continue
		p.amount_ratio = amount
		p.emitting = on
		p.visible = on
	if _litter:
		_litter.visible = on
	if _heightfield:
		_heightfield.visible = on
