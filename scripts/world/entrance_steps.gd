class_name EntranceSteps
extends Node3D
## Podest mit Stufen vor der Ladentür (seit Etappe 4d).
##
## Der Ladenboden liegt GameConfig.shop_floor_rise über dem Gehweg. Vor der schrägen
## Eingangswand steht ein Podest (Oberkante = Ladenboden); die Stufen laufen pyramidenförmig
## vorn und an beiden Seiten darum herum. Die ganze Treppe ist genau so breit wie die schräge
## Wand (nie breiter). Maße: GameConfig.entrance_… .
##
## Ursprung: außen auf der Hauswand in der Mitte der Tür, auf Höhe des Ladenbodens.
## +Z zeigt von der Wand weg nach draußen, +X läuft an der Wand entlang.
##
## Laufen: Die Spielfigur geht über eine unsichtbare Rampe (Kollision), die genau über die
## Stufenkanten läuft – so geht es weich hinauf und hinunter, ohne Hängenbleiben.
## Eigenes Modell: Einen Knoten "Model" (z. B. eine .glb-Szene) als Kind anlegen – dann baut
## das Script keine Platzhalter-Stufen, die Rampe (Kollision) bleibt.
## Passanten gehen um die Treppe herum (StreetObstacle-Kreise, seit Etappe 5a).

@export var material: Material = preload("res://assets/materials/entrance_steps.tres")


func _ready() -> void:
	var count := maxi(0, GameConfig.entrance_step_count)
	var tread := GameConfig.entrance_step_depth
	var side := GameConfig.entrance_side_step_depth
	var total := GameConfig.shop_floor_rise
	var rise := total / float(count + 1)
	# Podest = Wandbreite minus die seitlichen Stufen
	var half_width := maxf(0.3, StreetLayout.diagonal_width() / 2.0 - count * side)
	var depth := GameConfig.entrance_podium_depth
	if get_node_or_null("Model") == null:
		var builder := WorldMesh.new()
		var color := Color.WHITE  # Farbe kommt aus dem Material
		# Stufe k (0 = unterste, count = Podest): je höher, desto schmaler und flacher. Vorder- und
		# Seitenkanten weich gerundet (Stil-Umbau, Etappe 4h)
		for k in count + 1:
			var w := half_width + (count - k) * side
			var d := depth + (count - k) * tread
			var top := -total + (k + 1) * rise
			var bottom := top - rise
			_rounded_step(builder, w, d, top, bottom, minf(STEP_ROUND, rise * 0.45), color)
		add_child(builder.make_instance("Steps", material))
	_build_ramp(count, tread, side, total, half_width, depth)
	_add_street_obstacles(half_width + count * side, depth + count * tread)


## Rundung der Stufenkanten in m.
const STEP_ROUND := 0.04


## Eine Stufe als Quader (hinten an der Wand), vorn und an den Seiten weich gerundet: Auftritt,
## gerundete Kanten, gerundete Ecken vorn, senkrechte Stirn- und Seitenflächen, Rückseite.
func _rounded_step(builder: WorldMesh, w: float, d: float, top: float, bottom: float, r: float, color: Color) -> void:
	builder.add_quad(Vector3(-w + r, top, 0), Vector3(w - r, top, 0), Vector3(w - r, top, d - r), Vector3(-w + r, top, d - r), Vector3.UP, color)
	builder.add_round_edge(Vector2(-w + r, d), Vector2(w - r, d), Vector2(0.0, 1.0), top, r, color)
	builder.add_round_edge(Vector2(-w, 0.0), Vector2(-w, d - r), Vector2(-1.0, 0.0), top, r, color)
	builder.add_round_edge(Vector2(w, 0.0), Vector2(w, d - r), Vector2(1.0, 0.0), top, r, color)
	builder.add_quad(Vector3(-w + r, bottom, d), Vector3(w - r, bottom, d), Vector3(w - r, top - r, d), Vector3(-w + r, top - r, d),
		Vector3.BACK, color)
	builder.add_quad(Vector3(-w, bottom, 0), Vector3(-w, bottom, d - r), Vector3(-w, top - r, d - r), Vector3(-w, top - r, 0), Vector3.LEFT, color)
	builder.add_quad(Vector3(w, bottom, 0), Vector3(w, bottom, d - r), Vector3(w, top - r, d - r), Vector3(w, top - r, 0), Vector3.RIGHT, color)
	builder.add_quad(Vector3(-w, bottom, 0), Vector3(w, bottom, 0), Vector3(w, top, 0), Vector3(-w, top, 0), Vector3.FORWARD, color)
	# Ecken vorn: senkrecht ein Viertelzylinder, oben ein Achtel einer Kugel
	for sx in [-1.0, 1.0]:
		var c := Vector3(sx * (w - r), 0.0, d - r)
		var seg := 3
		for i in seg:
			var p0 := PI / 2.0 * float(i) / seg
			var p1 := PI / 2.0 * float(i + 1) / seg
			var h0 := Vector3(sx * sin(p0), 0.0, cos(p0))
			var h1 := Vector3(sx * sin(p1), 0.0, cos(p1))
			builder.add_quad_smooth(c + h0 * r + Vector3.UP * bottom, c + h1 * r + Vector3.UP * bottom,
				c + h1 * r + Vector3.UP * (top - r), c + h0 * r + Vector3.UP * (top - r), h0, h1, h1, h0, color)
			for j in seg:
				var t0 := PI / 2.0 * float(j) / seg
				var t1 := PI / 2.0 * float(j + 1) / seg
				var n00 := h0 * cos(t0) + Vector3.UP * sin(t0)
				var n10 := h1 * cos(t0) + Vector3.UP * sin(t0)
				var n11 := h1 * cos(t1) + Vector3.UP * sin(t1)
				var n01 := h0 * cos(t1) + Vector3.UP * sin(t1)
				var base := c + Vector3.UP * (top - r)
				builder.add_quad_smooth(base + n00 * r, base + n10 * r, base + n11 * r, base + n01 * r, n00, n10, n11, n01, color)


## Passanten gehen um die Treppe herum (seit Etappe 5a): Kreise entlang der Vorderkante und
## der Seiten (StreetObstacle), die zusammen die ganze Treppe abdecken.
func _add_street_obstacles(half: float, reach: float) -> void:
	var r := 0.42
	var spots: Array[Vector2] = []
	var count := maxi(2, ceili((half - r) * 2.0 / 0.7) + 1)
	for i in count:
		spots.append(Vector2(lerpf(-half + r, half - r, float(i) / (count - 1)), reach - r))
	for x in [-half + r, half - r]:
		spots.append(Vector2(x, r))
		spots.append(Vector2(x, (r + reach - r) / 2.0))
	for spot in spots:
		var obstacle := StreetObstacle.new()
		obstacle.name = "StreetObstacle"
		obstacle.radius = r
		obstacle.position = Vector3(spot.x, 0.0, spot.y)
		add_child(obstacle)


## Unsichtbare Rampe: unten eine Stufe vor der untersten Kante, oben das Podest. Sie berührt
## genau die Vorderkanten aller Stufen.
func _build_ramp(count: int, tread: float, side: float, total: float, half_width: float, depth: float) -> void:
	var reach := (count + 1) * tread
	var side_reach := (count + 1) * side
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-half_width - side_reach, -total, 0), Vector3(half_width + side_reach, -total, 0),
		Vector3(-half_width - side_reach, -total, depth + reach), Vector3(half_width + side_reach, -total, depth + reach),
		Vector3(-half_width, 0, 0), Vector3(half_width, 0, 0),
		Vector3(-half_width, 0, depth), Vector3(half_width, 0, depth),
	])
	var body := StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
