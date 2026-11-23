class_name Bunting
extends Node3D
## Wimpelketten quer über die Straße (seit „Modelle schöner“ – Charme einer englischen Einkaufsstraße): an den Stellen
## GameConfig.bunting_x sucht ein Sichtstrahl in Höhe bunting_height die Hauswände auf beiden Seiten; dazwischen hängt eine
## Schnur (durchhängend, bunting_sag) mit dreieckigen Stoffwimpeln in warmen Farben, die leicht im Wind schaukeln (Shader).
## Findet der Strahl auf einer Seite keine Wand (Gasse, Platz), bleibt diese Stelle leer. Alles in einem Netz je Kette,
## ohne Schatten und ohne Kollision. main.gd legt den Knoten unter Outside an.

const FLAG_W := 0.22
const FLAG_H := 0.3
const FLAG_GAP := 0.09
const CORD_RADIUS := 0.008
## Stoff: Farben (sRGB) der Wimpel, der Reihe nach mit kleinen Abweichungen
const COLORS: Array[Color] = [Color(0.93, 0.72, 0.36), Color(0.78, 0.4, 0.3), Color(0.55, 0.66, 0.52), Color(0.88, 0.6, 0.62),
	Color(0.96, 0.9, 0.78), Color(0.42, 0.58, 0.62), Color(0.84, 0.52, 0.32)]

const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float wind = 0.05;
varying float sway;
void vertex() {
	// UV.y = 0 an der Schnur, 1 an der Spitze; der Wind schiebt quer zur Kette (x) und etwas nach oben
	float t = TIME * 1.7 + NODE_POSITION_WORLD.x * 0.3 + VERTEX.z * 0.9;
	float s = sin(t) * 0.7 + sin(t * 2.3 + 1.3) * 0.3;
	VERTEX.x += s * wind * UV.y;
	VERTEX.y += abs(s) * wind * 0.25 * UV.y;
	sway = s;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = COLOR.rgb * 0.35;
}
"""


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	# erst, wenn die Häuser ihre Kollision haben
	for k in 3:
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	var rng := RandomNumberGenerator.new()
	rng.seed = 517
	var mid := StreetLayout.road_center_z()
	for x: float in GameConfig.bunting_x:
		var y: float = GameConfig.bunting_height + rng.randf_range(-0.25, 0.25)
		var a := _wall(space, Vector3(x, y, mid), Vector3(0, 0, 1))
		var b := _wall(space, Vector3(x, y, mid), Vector3(0, 0, -1))
		if a == Vector3.INF or b == Vector3.INF:
			continue
		var mesh := _make_mesh(a, b, rng)
		var inst := MeshInstance3D.new()
		inst.name = "Bunting"
		inst.mesh = mesh
		inst.material_override = material
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)


## Punkt an der Hauswand (lokal, 6 cm davor) in Richtung dir von from aus; Vector3.INF = keine Wand.
func _wall(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(to_global(from), to_global(from + dir * 14.0), 1 | (1 << 7))
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var collider := hit.collider as Object
	if collider and collider.has_meta("see_through"):
		return Vector3.INF
	return to_local(Vector3(hit.position)) - dir * 0.06


## Eine Kette von a nach b: Schnur als dünne Röhre entlang einer Durchhang-Kurve, Wimpel als Dreiecke darunter.
func _make_mesh(a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := a.distance_to(b)
	var sag: float = GameConfig.bunting_sag * length / 10.0
	var cord_color := Color(0.85, 0.8, 0.7)
	var steps := int(length / 0.25)
	var points: Array[Vector3] = []
	for k in steps + 1:
		var t := float(k) / steps
		points.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	# Schnur: sechseckige Röhre
	for k in steps:
		var p0 := points[k]
		var p1 := points[k + 1]
		var d := (p1 - p0).normalized()
		var side := d.cross(Vector3.UP).normalized()
		var up := side.cross(d).normalized()
		for j in 6:
			var a0 := TAU * j / 6.0
			var a1 := TAU * (j + 1) / 6.0
			var o0 := (side * cos(a0) + up * sin(a0)) * CORD_RADIUS
			var o1 := (side * cos(a1) + up * sin(a1)) * CORD_RADIUS
			_tri(st, p0 + o0, p1 + o0, p1 + o1, cord_color, 0.0)
			_tri(st, p0 + o0, p1 + o1, p0 + o1, cord_color, 0.0)
	# Wimpel: von der Mitte aus gleichmäßig verteilt, nicht ganz bis an die Wände
	var pitch := FLAG_W + FLAG_GAP
	var count := int((length - 0.6) / pitch)
	var start := (length - count * pitch) / 2.0 + FLAG_GAP / 2.0
	var color_index := rng.randi() % COLORS.size()
	for i in count:
		var s0 := (start + i * pitch) / length
		var s1 := (start + i * pitch + FLAG_W) / length
		var top0 := _on_curve(a, b, sag, s0)
		var top1 := _on_curve(a, b, sag, s1)
		var tip := (top0 + top1) / 2.0 + Vector3.DOWN * FLAG_H * rng.randf_range(0.92, 1.04)
		var col := COLORS[(color_index + i) % COLORS.size()]
		col = col.lightened(rng.randf_range(-0.04, 0.06)).srgb_to_linear()
		# beidseitig gezeichnet (cull_disabled); zwei Dreiecke = leicht gefaltet in der Mitte
		var fold := (top0 + top1) / 2.0 + Vector3(rng.randf_range(-0.015, 0.015), 0.0, 0.0)
		_tri_uv(st, top0, fold, tip, col)
		_tri_uv(st, fold, top1, tip, col)
	st.generate_normals()
	return st.commit()


func _on_curve(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)


func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, col: Color, v: float) -> void:
	for p in [p0, p1, p2]:
		st.set_color(col)
		st.set_uv(Vector2(0.0, v))
		st.add_vertex(p)


## Wimpel-Dreieck: UV.y = 0 oben an der Schnur, 1 an der Spitze (für den Wind).
func _tri_uv(st: SurfaceTool, top0: Vector3, top1: Vector3, tip: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(top0)
	st.set_color(col)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(top1)
	st.set_color(col)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(tip)
