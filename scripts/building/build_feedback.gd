class_name BuildFeedback
extends RefCounted
## Rückmeldung beim Gestalten (seit der großen Überarbeitung, Wunsch: „mehr satisfying“). Alles kurz, weich und leise:
## - Möbel abstellen (seit dem Nachtest der Überarbeitung, Wunsch: schönere Bewegung, kein Leuchten): das Möbel schwebt
##   herab und dreht sich dabei sanft in seine Lage, setzt weich auf (kurz gestaucht), ruckelt sich einmal zurecht (kleines,
##   abklingendes Kippeln über die Unterkante) und kommt zur Ruhe; zartes Staubwölkchen, Holz-„Tock“ (große Möbel tiefer).
##   Was darauf steht, macht dieselbe Bewegung mit. Wand-/Deckendinge schwingen sanft aus (wie ein Bild am Nagel).
## - Möbel aufheben: kleines „Plopp“ und ein Hauch Staub
## - Wand streichen: die neue Farbe breitet sich von der Pinselstelle aus (paint_wipe), Pinselstrich-Geräusch und ein
##   paar Farbtropfen in der neuen Farbe
## Werte: GameConfig.feedback_*. Geräusche: tools/make_feedback_sounds.py (furniture/place, pick, paint).

const PUFF_TEXTURE_SIZE := 64

static var _puff_material: StandardMaterial3D


## Ein Möbel steht an seinem neuen Platz. dependents = was darauf steht (macht die Bewegung mit).
static func furniture_placed(item: PlacedFurniture, dependents: Array, _is_new: bool) -> void:
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
		_animate(item, pieces, GameConfig.feedback_swing_time, _swing_motion.bind(
			item.data.allows(FurnitureData.PLACE_CEILING), randf() < 0.5))
	else:
		var axis := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		var turn := deg_to_rad(GameConfig.feedback_turn) * (1.0 if randf() < 0.5 else -1.0)
		_animate(item, pieces, GameConfig.feedback_settle_time, _settle_motion.bind(axis, size * 0.5, turn))
		# Staub erst beim Aufsetzen
		var delay := GameConfig.feedback_settle_time * SETTLE_CONTACT
		item.get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(item):
				_puff(item, item.global_position + Vector3.UP * 0.02, maxf(0.2, size * 0.55), 8 + int(size * 8.0)))


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
	for part_any in parts:
		# erst prüfen, dann typisieren (ein gelöschtes Objekt in „part: MeshInstance3D“ hält Godot 4.6 an)
		var part: MeshInstance3D = part_any if is_instance_valid(part_any) else null
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
		for part_any in parts:
			# erst prüfen, dann typisieren (ein gelöschtes Objekt in „part: MeshInstance3D“ hält Godot 4.6 an)
			var part: MeshInstance3D = part_any if is_instance_valid(part_any) else null
			if is_instance_valid(part) and part.material_overlay == overlay:
				part.material_overlay = null)


# --- Bewegungen ---

## Anteil der Zeit bis zum Aufsetzen (danach Stauchen und Kippeln).
const SETTLE_CONTACT := 0.38


## Spielt eine Bewegung „motion(t) → Transform3D im Raum des Hauptmöbels“ (t von 0 bis 1) auf den Modellen aller Teile ab
## (Kollision und Lage bleiben wie sie sind – nur das Bild bewegt sich), am Ende genau zurück auf die Ruhelage.
static func _animate(item: PlacedFurniture, pieces: Array, time: float, motion: Callable) -> void:
	var rests := {}   # Modell -> Ruhelage (lokal)
	var rel := {}     # Modell -> Lage seines Möbels relativ zum Hauptmöbel
	var inverse := item.global_transform.affine_inverse()
	for piece_any in pieces:
		# erst prüfen, dann typisieren (ein gelöschtes Objekt in „piece: PlacedFurniture“ hält Godot 4.6 an)
		var piece: PlacedFurniture = piece_any if is_instance_valid(piece_any) else null
		if not is_instance_valid(piece):
			continue
		var model := piece.get_model()
		if model == null:
			continue
		rests[model] = model.transform
		rel[model] = inverse * piece.global_transform
	if rests.is_empty():
		return
	var apply := func(t: float) -> void:
		var m: Transform3D = motion.call(t)
		for model_any in rests:
			# erst prüfen, dann typisieren (ein gelöschtes Objekt in „model: Node3D“ hält Godot 4.6 an)
			var model: Node3D = model_any if is_instance_valid(model_any) else null
			if is_instance_valid(model):
				var r: Transform3D = rel[model]
				model.transform = r.affine_inverse() * m * r * (rests[model] as Transform3D)
	apply.call(0.0)
	var tween := item.create_tween()
	tween.tween_method(apply, 0.0, 1.0, time)
	tween.tween_callback(func() -> void:
		for model_any in rests:
			# erst prüfen, dann typisieren (ein gelöschtes Objekt in „model: Node3D“ hält Godot 4.6 an)
			var model: Node3D = model_any if is_instance_valid(model_any) else null
			if is_instance_valid(model):
				model.transform = rests[model])


## Stehende Möbel: schweben herab und drehen sich dabei in ihre Lage, setzen auf (kurz gestaucht), kippeln einmal abklingend
## über die Unterkante und stehen still. axis = Kipp-Achse (waagerecht), half = halbe Breite, turn = Drehung am Anfang.
static func _settle_motion(t: float, axis: Vector3, half: float, turn: float) -> Transform3D:
	var h := GameConfig.feedback_drop_height
	var y := 0.0
	var yaw := 0.0
	var tilt := 0.0
	var squash := 0.0
	if t < SETTLE_CONTACT:
		var u := t / SETTLE_CONTACT
		y = h * (1.0 - u * u)                    # immer schneller hinunter, wie fallen
		yaw = turn * pow(1.0 - u, 2.0)            # dreht sich dabei sanft in die Lage
	else:
		var u := (t - SETTLE_CONTACT) / (1.0 - SETTLE_CONTACT)
		tilt = deg_to_rad(GameConfig.feedback_tilt) * exp(-4.5 * u) * sin(u * TAU * 1.5)
		squash = GameConfig.feedback_squash * exp(-7.0 * u) * cos(u * TAU * 2.0)
		y = half * sin(absf(tilt))                # über die Unterkante kippeln (nie in den Boden)
	var basis := Basis(Vector3.UP, yaw) * Basis(axis, tilt)
	basis = basis * Basis.from_scale(Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5))
	return Transform3D(basis, Vector3.UP * y)


## Wand-/Deckendinge: kurz kleiner, federn auf volle Größe und schwingen sanft aus (Bild am Nagel: um die Achse von der Wand weg;
## Deckenlampe: wie ein Pendel um den Aufhängepunkt).
static func _swing_motion(t: float, ceiling: bool, left: bool) -> Transform3D:
	var grow := minf(1.0, t / 0.35)
	var scale := lerpf(0.86, 1.0, 1.0 - pow(1.0 - grow, 3.0)) + 0.05 * sin(grow * PI) * (1.0 - grow)
	var swing := deg_to_rad(GameConfig.feedback_swing) * exp(-4.0 * t) * sin(t * TAU * 2.2) * (1.0 if left else -1.0)
	var basis := Basis(Vector3.RIGHT if ceiling else Vector3.BACK, swing) * Basis.from_scale(Vector3.ONE * scale)
	return Transform3D(basis, Vector3.ZERO)


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
