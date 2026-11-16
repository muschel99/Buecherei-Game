class_name BuildFeedback
extends RefCounted
## Rückmeldung beim Gestalten (seit der großen Überarbeitung, Wunsch: „mehr satisfying“). Alles kurz, weich und leise:
## - Möbel abstellen: das Möbel plumpst sanft an seinen Platz (kurz fallen, leicht zusammendrücken, zurückfedern),
##   ein Staubwölkchen am Boden, bei Neuem ein paar goldene Funken, Holz-„Tock“ (große Möbel tiefer)
## - Möbel aufheben: kleines „Plopp“ und ein Hauch Staub
## - Wand streichen: die neue Farbe breitet sich von der Pinselstelle aus (paint_wipe), Pinselstrich-Geräusch und ein
##   paar Farbtropfen in der neuen Farbe
## Werte: GameConfig.feedback_*. Geräusche: tools/make_feedback_sounds.py (furniture/place, pick, paint).

const PUFF_TEXTURE_SIZE := 64

static var _puff_material: StandardMaterial3D
static var _spark_material: StandardMaterial3D


## Ein Möbel steht an seinem neuen Platz. dependents = was darauf steht (wandert mit, plumpst ohne Stauchen mit).
static func furniture_placed(item: PlacedFurniture, dependents: Array, is_new: bool) -> void:
	if item == null or not item.is_inside_tree():
		return
	var size := _size_of(item)
	var hanging := item.data.is_hanging()
	# Geräusch: große Möbel tiefer, kleine Deko heller
	var pitch := clampf(1.25 - size * 0.28, 0.72, 1.3) * Audio.vary(0.05)
	Audio.play_at("furniture/place", item.global_position, GameConfig.feedback_place_db - (4.0 if size < 0.4 else 0.0), pitch)
	if not GameConfig.feedback_animations:
		return
	var pieces: Array = [item]
	pieces.append_array(dependents)
	if hanging:
		_pop(item)
	else:
		for piece: PlacedFurniture in pieces:
			_plop(piece, piece == item and dependents.is_empty())
		_puff(item, item.global_position + Vector3.UP * 0.02, maxf(0.2, size * 0.55), 10 + int(size * 10.0))
	if is_new:
		_sparks(item, item.global_position + Vector3.UP * (0.15 if hanging else maxf(0.25, size * 0.5)), maxf(0.25, size * 0.5))


## Ein Möbel wurde aufgehoben (ist jetzt „in der Hand“).
static func furniture_picked(item: PlacedFurniture) -> void:
	if item == null or not item.is_inside_tree():
		return
	Audio.play_at("furniture/pick", item.global_position, GameConfig.feedback_pick_db, Audio.vary(0.06))
	if GameConfig.feedback_animations and not item.data.is_hanging():
		_puff(item.get_parent() as Node3D, item.global_position + Vector3.UP * 0.02, maxf(0.15, _size_of(item) * 0.4), 6)


## Gestrichen bzw. Boden/Decke neu gelegt: Pinselgeräusch und Farbtropfen.
static func painted(room: Node3D, point: Vector3, surface: SurfaceData, whole: bool) -> void:
	Audio.play_at("furniture/paint", point, GameConfig.feedback_paint_db + (2.0 if whole else 0.0), Audio.vary(0.08))
	if not GameConfig.feedback_animations or room == null:
		return
	var color := _surface_color(surface)
	_drops(room, point, color, 14 if whole else 8)


## Die neue Farbe breitet sich von der Pinselstelle aus: Eine Kopie des alten Belags liegt kurz als Überzug auf den Flächen,
## darin wächst ein Loch (Shader surface_pattern: reveal_center/reveal_radius).
static func paint_wipe(parts: Array, old_material: Material, point: Vector3, whole: bool) -> void:
	if not GameConfig.feedback_animations or not old_material is ShaderMaterial or parts.is_empty():
		return
	var overlay := (old_material as ShaderMaterial).duplicate() as ShaderMaterial
	overlay.set_shader_parameter("reveal_center", point)
	overlay.set_shader_parameter("reveal_radius", 0.0)
	var holder: MeshInstance3D = null
	for part: MeshInstance3D in parts:
		if is_instance_valid(part):
			part.material_overlay = overlay
			holder = part
	if holder == null:
		return
	var reach := 9.0 if whole else 2.4
	var time := GameConfig.feedback_paint_time * (1.6 if whole else 1.0)
	var tween := holder.create_tween()
	tween.tween_method(func(r: float) -> void: overlay.set_shader_parameter("reveal_radius", r), 0.0, reach, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		for part: MeshInstance3D in parts:
			if is_instance_valid(part) and part.material_overlay == overlay:
				part.material_overlay = null)


# --- Bewegungen ---

## Plumpsen: kurz von etwas weiter oben fallen, beim Aufsetzen leicht stauchen, zurückfedern (nur das Modell).
static func _plop(item: PlacedFurniture, squash: bool) -> void:
	var model := item.get_model()
	if model == null:
		return
	var rest := model.transform
	var drop := GameConfig.feedback_drop_height
	model.transform = Transform3D(rest.basis, rest.origin + Vector3.UP * drop)
	var tween := model.create_tween()
	tween.tween_property(model, "position:y", rest.origin.y, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if squash:
		var s := GameConfig.feedback_squash
		tween.tween_property(model, "scale", rest.basis.get_scale() * Vector3(1.0 + s, 1.0 - s * 1.4, 1.0 + s), 0.06) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(model, "scale", rest.basis.get_scale(), 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(model):
			model.transform = rest)


## Aufploppen (Wand- und Deckendinge): kurz kleiner, dann federnd auf volle Größe.
static func _pop(item: PlacedFurniture) -> void:
	var model := item.get_model()
	if model == null:
		return
	var rest := model.transform
	var scale := rest.basis.get_scale()
	model.scale = scale * 0.82
	var tween := model.create_tween()
	tween.tween_property(model, "scale", scale, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(model):
			model.transform = rest)


# --- Teilchen ---

## Staubwölkchen am Boden: weiche, helle Bällchen rollen nach außen und lösen sich auf.
static func _puff(parent: Node3D, at: Vector3, radius: float, count: int) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := _one_shot(parent, at, count, 0.75)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.6
	p.emission_ring_height = 0.02
	p.direction = Vector3(0, 0.25, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.55
	p.radial_accel_min = 0.4
	p.radial_accel_max = 0.8
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.gravity = Vector3(0, 0.12, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.13
	p.scale_amount_curve = _curve([Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 1.25)])
	p.color_ramp = _ramp([Color(1.0, 0.96, 0.88, 0.0), Color(1.0, 0.95, 0.86, 0.55), Color(1.0, 0.94, 0.84, 0.0)], [0.0, 0.15, 1.0])
	p.mesh = _quad(_puff_mat())
	p.emitting = true


## Goldene Funken: ein paar kleine Lichtpunkte steigen auf und funkeln (nur bei Neuem).
static func _sparks(parent: Node3D, at: Vector3, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := _one_shot(parent, at, 9, 1.1)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, 0.05, 0)
	p.damping_min = 0.6
	p.damping_max = 1.0
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.05
	p.scale_amount_curve = _curve([Vector2(0, 0.0), Vector2(0.2, 1.0), Vector2(0.6, 0.7), Vector2(1, 0.0)])
	p.color_ramp = _ramp([Color(1.0, 0.86, 0.5, 1.0), Color(1.0, 0.95, 0.8, 1.0), Color(1.0, 0.8, 0.45, 0.0)], [0.0, 0.5, 1.0])
	p.mesh = _quad(_spark_mat())
	p.emitting = true


## Ein Regalfach ist voll: kleine goldene Funken steigen entlang des ganzen Fachs auf (along = Richtung des Bretts).
static func row_sparkle(parent: Node3D, center: Vector3, along: Vector3, half_length: float) -> void:
	if not GameConfig.feedback_animations or parent == null or not parent.is_inside_tree():
		return
	var p := _one_shot(parent, center, 10 + int(half_length * 16.0), 1.2)
	p.explosiveness = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	var points := PackedVector3Array()
	for k in 24:
		points.append(along * lerpf(-half_length, half_length, k / 23.0))
	p.emission_points = points
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.22
	p.gravity = Vector3(0, 0.04, 0)
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.04
	p.scale_amount_curve = _curve([Vector2(0, 0.0), Vector2(0.2, 1.0), Vector2(0.65, 0.7), Vector2(1, 0.0)])
	p.color_ramp = _ramp([Color(1.0, 0.86, 0.5, 1.0), Color(1.0, 0.96, 0.82, 1.0), Color(1.0, 0.82, 0.5, 0.0)], [0.0, 0.5, 1.0])
	p.mesh = _quad(_spark_mat())
	p.emitting = true


## Farbtropfen in der neuen Farbe: springen von der Pinselstelle weg und fallen.
static func _drops(parent: Node3D, at: Vector3, color: Color, count: int) -> void:
	if not parent.is_inside_tree():
		return
	var p := _one_shot(parent, at, count, 0.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.018
	p.scale_amount_max = 0.035
	p.color = color
	p.color_ramp = _ramp([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.7, 1.0])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = _dot_texture()
	material.roughness = 0.4
	p.mesh = _quad(material)
	p.emitting = true


static func _one_shot(parent: Node3D, at: Vector3, count: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(count, 1)
	p.lifetime = lifetime
	p.explosiveness = 0.92
	p.randomness = 0.5
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	return p


static func _quad(material: Material) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	return quad


static func _puff_mat() -> StandardMaterial3D:
	if _puff_material == null:
		_puff_material = StandardMaterial3D.new()
		_puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff_material.vertex_color_use_as_albedo = true
		_puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_puff_material.albedo_texture = _dot_texture()
		_puff_material.proximity_fade_enabled = true
		_puff_material.proximity_fade_distance = 0.08
	return _puff_material


static func _spark_mat() -> StandardMaterial3D:
	if _spark_material == null:
		_spark_material = StandardMaterial3D.new()
		_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_material.vertex_color_use_as_albedo = true
		_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_material.albedo_texture = _dot_texture()
	return _spark_material


static func _dot_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = PUFF_TEXTURE_SIZE
	texture.height = PUFF_TEXTURE_SIZE
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture


static func _ramp(colors: Array[Color], offsets: Array[float]) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


static func _curve(points: Array[Vector2]) -> Curve:
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	return c


# --- Hilfen ---

## Ungefähre Größe (größere Seite der Grundfläche in m).
static func _size_of(item: PlacedFurniture) -> float:
	if item.data == null:
		return 0.5
	var f := item.data.get_footprint_size()
	return maxf(f.x, f.y)


static func _surface_color(surface: SurfaceData) -> Color:
	var material := surface.material as ShaderMaterial
	if material:
		var c: Variant = material.get_shader_parameter("base_color")
		if c is Color:
			return c
	return Color(0.9, 0.85, 0.75)
