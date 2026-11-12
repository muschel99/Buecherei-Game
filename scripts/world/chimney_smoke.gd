class_name ChimneySmoke
extends Node3D
## Rauch aus den Schornsteinen (seit Etappe 6j): Aus einem Teil der Häuser steigt ein dünner, heller Rauchfaden – in den
## Häusern wird gekocht und geheizt, die Straße wirkt bewohnt. Die Schornsteine stehen in data/animals/spots.json (das
## Werkzeug bake_animal_spots misst die höchsten Punkte jedes Hauses aus); je Schornstein ein kleiner Partikel-Erzeuger
## (wenige weiche Wölkchen, kein Schatten). Alle Werte in GameConfig (chimney_smoke_*). Liegt unter "Outside".

const SPOTS_FILE := "res://data/animals/spots.json"

var _material: StandardMaterial3D
var _process: ParticleProcessMaterial
var _mesh: QuadMesh


func _ready() -> void:
	if not GameConfig.chimney_smoke_enabled or not FileAccess.file_exists(SPOTS_FILE):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPOTS_FILE))
	if not data is Dictionary:
		return
	# Dach-Sitzplätze je Haus (über der Traufe)
	var houses := {}
	for h: Dictionary in data.get("houses", []):
		houses[String(h.name)] = {"eaves": float(h.front[1]) + float(h.eaves), "points": []}
	for p: Dictionary in data.get("perches", []):
		var entry: Dictionary = houses.get(String(p.get("house", "")), {})
		if entry.is_empty() or String(p.kind) != "roof" or float(p.pos[1]) < float(entry.eaves) + 0.8:
			continue
		(entry.points as Array).append(Vector3(p.pos[0], p.pos[1], p.pos[2]))
	var rng := RandomNumberGenerator.new()
	for house_name: String in houses:
		var top := _chimney_top(houses[house_name].points)
		if top == Vector3.INF:
			continue
		# nur ein Teil der Häuser (fest je Hausname)
		rng.seed = hash(house_name)
		if rng.randf() > GameConfig.chimney_smoke_share:
			continue
		_add_smoke(top, rng)


## Mitte des höchsten Schornsteinkopfs: eine kleine, dichte, ebene Gruppe von Sitzplätzen (der Rand des Schornsteins) –
## Firste sind lange Ketten und fallen heraus. Vector3.INF = kein Schornstein gefunden.
func _chimney_top(points: Array) -> Vector3:
	var count := points.size()
	var group: Array[int] = []
	for i in count:
		group.append(i)
	for i in count:
		for j in range(i + 1, count):
			if (points[i] as Vector3).distance_to(points[j]) < 0.35:
				var a := i
				while group[a] != a:
					a = group[a]
				var b := j
				while group[b] != b:
					b = group[b]
				group[a] = b
	var clusters := {}
	for i in count:
		var root := i
		while group[root] != root:
			root = group[root]
		if not clusters.has(root):
			clusters[root] = []
		(clusters[root] as Array).append(points[i])
	var best := Vector3.INF
	for members: Array in clusters.values():
		if members.size() < 6:
			continue
		var box := AABB(members[0], Vector3.ZERO)
		for q: Vector3 in members:
			box = box.expand(q)
		if box.size.x > 0.9 or box.size.z > 0.9 or box.size.y > 0.25 or maxf(box.size.x, box.size.z) < 0.35:
			continue
		var center := box.get_center()
		center.y = box.end.y
		if best == Vector3.INF or center.y > best.y:
			best = center
	return best


func _add_smoke(at: Vector3, rng: RandomNumberGenerator) -> void:
	if _material == null:
		_build_shared()
	var smoke := GPUParticles3D.new()
	smoke.name = "Smoke%d" % get_child_count()
	smoke.position = at + Vector3.UP * 0.05
	smoke.amount = GameConfig.chimney_smoke_amount
	smoke.lifetime = GameConfig.chimney_smoke_lifetime
	smoke.preprocess = GameConfig.chimney_smoke_lifetime
	smoke.randomness = 0.6
	smoke.speed_scale = rng.randf_range(0.85, 1.15)
	smoke.process_material = _process
	smoke.draw_pass_1 = _mesh
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.visibility_aabb = AABB(Vector3(-2.5, -0.5, -2.5), Vector3(7.0, 7.0, 5.0))
	add_child(smoke)


## Gemeinsames Material und Bewegung aller Rauchfäden (ein Material = wenig Aufwand).
func _build_shared() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_texture = texture
	_material.vertex_color_use_as_albedo = true
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_material.billboard_keep_scale = true
	_material.disable_receive_shadows = true
	_material.proximity_fade_enabled = false
	_mesh = QuadMesh.new()
	_mesh.size = Vector2.ONE
	_mesh.material = _material
	_process = ParticleProcessMaterial.new()
	_process.direction = Vector3.UP
	_process.spread = 10.0
	_process.initial_velocity_min = GameConfig.chimney_smoke_speed * 0.8
	_process.initial_velocity_max = GameConfig.chimney_smoke_speed * 1.2
	# der Wind trägt den Rauch langsam zur Seite, er steigt weiter
	_process.gravity = GameConfig.chimney_smoke_wind
	_process.damping_min = 0.05
	_process.damping_max = 0.1
	_process.angle_min = 0.0
	_process.angle_max = 360.0
	# Wölkchen wachsen beim Aufsteigen
	var size := Curve.new()
	size.add_point(Vector2(0.0, 0.22))
	size.add_point(Vector2(1.0, 1.0))
	var size_texture := CurveTexture.new()
	size_texture.curve = size
	_process.scale_curve = size_texture
	_process.scale_min = GameConfig.chimney_smoke_size * 0.8
	_process.scale_max = GameConfig.chimney_smoke_size * 1.25
	# erscheinen weich, werden dünner und vergehen
	var fade := Gradient.new()
	var c := GameConfig.chimney_smoke_color
	fade.set_color(0, Color(c.r, c.g, c.b, 0.0))
	fade.add_point(0.12, c)
	fade.set_color(fade.get_point_count() - 1, Color(c.r, c.g, c.b, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	_process.color_ramp = fade_texture
