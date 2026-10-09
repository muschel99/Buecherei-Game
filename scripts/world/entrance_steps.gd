class_name EntranceSteps
extends Node3D
## Podest mit Stufen vor der Ladentür (seit Etappe 4d).
##
## Der Ladenboden liegt GameConfig.shop_floor_rise über dem Gehweg. Vor der schrägen
## Eingangswand steht ein Podest (Oberkante = Ladenboden); die Stufen laufen pyramidenförmig
## vorn und an beiden Seiten darum herum. Maße: GameConfig.entrance_… .
##
## Ursprung: außen auf der Hauswand in der Mitte der Tür, auf Höhe des Ladenbodens.
## +Z zeigt von der Wand weg nach draußen, +X läuft an der Wand entlang.
##
## Laufen: Die Spielfigur geht über eine unsichtbare Rampe (Kollision), die genau über die
## Stufenkanten läuft – so geht es weich hinauf und hinunter, ohne Hängenbleiben.
## Eigenes Modell: Einen Knoten "Model" (z. B. eine .glb-Szene) als Kind anlegen – dann baut
## das Script keine Platzhalter-Stufen, die Rampe (Kollision) bleibt.

@export var material: Material = preload("res://assets/materials/curb_stone.tres")


func _ready() -> void:
	var count := maxi(0, GameConfig.entrance_step_count)
	var tread := GameConfig.entrance_step_depth
	var total := GameConfig.shop_floor_rise
	var rise := total / float(count + 1)
	var half_width := GameConfig.entrance_podium_width / 2.0
	var depth := GameConfig.entrance_podium_depth
	if get_node_or_null("Model") == null:
		var builder := WorldMesh.new()
		var color := Color.WHITE  # Farbe kommt aus dem Material
		# Stufe k (0 = unterste, count = Podest): je höher, desto schmaler und flacher
		for k in count + 1:
			var extra := (count - k) * tread
			var w := half_width + extra
			var d := depth + extra
			var top := -total + (k + 1) * rise
			var bottom := top - rise
			# Auftritt (oben), Stirnseite (vorn), Seiten, Rückseite (sichtbar seitlich neben der Wand)
			builder.add_quad(Vector3(-w, top, 0), Vector3(w, top, 0), Vector3(w, top, d), Vector3(-w, top, d), Vector3.UP, color)
			builder.add_quad(Vector3(-w, bottom, d), Vector3(w, bottom, d), Vector3(w, top, d), Vector3(-w, top, d), Vector3.BACK, color)
			builder.add_quad(Vector3(-w, bottom, 0), Vector3(-w, bottom, d), Vector3(-w, top, d), Vector3(-w, top, 0), Vector3.LEFT, color)
			builder.add_quad(Vector3(w, bottom, 0), Vector3(w, bottom, d), Vector3(w, top, d), Vector3(w, top, 0), Vector3.RIGHT, color)
			builder.add_quad(Vector3(-w, bottom, 0), Vector3(w, bottom, 0), Vector3(w, top, 0), Vector3(-w, top, 0), Vector3.FORWARD, color)
		add_child(builder.make_instance("Steps", material))
	_build_ramp(count, tread, total, half_width, depth)


## Unsichtbare Rampe: unten eine Stufe vor der untersten Kante, oben das Podest. Sie berührt
## genau die Vorderkanten aller Stufen.
func _build_ramp(count: int, tread: float, total: float, half_width: float, depth: float) -> void:
	var reach := (count + 1) * tread
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-half_width - reach, -total, 0), Vector3(half_width + reach, -total, 0),
		Vector3(-half_width - reach, -total, depth + reach), Vector3(half_width + reach, -total, depth + reach),
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
