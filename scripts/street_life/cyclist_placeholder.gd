class_name CyclistPlaceholder
extends Node3D
## Platzhalter eines Fahrrads mit Fahrerin oder Fahrer (seit Etappe 5a): Rad und Körper sind ein
## Mesh, die Beine treten in die Pedale (zwei kleine Teile, bewegt von animate). Vorderseite
## nach +Z, Räder auf y = 0. Eigenes Modell: in scenes/street_life/cyclist.tscn den Knoten
## "Model" ersetzen (docs/ASSET_GUIDE.md).

const WHEEL := 0.34
const WHEEL_Z := 0.52
const HIP := Vector3(0.0, 1.0, -0.2)
const CRANK := Vector3(0.0, 0.36, 0.02)

var _body: MeshInstance3D
var _legs: Array[Node3D] = []
var _crank := 0.0


func _ready() -> void:
	if _body == null:
		build(RandomNumberGenerator.new(), Color(0.3, 0.45, 0.55))


func build(rng: RandomNumberGenerator, color: Color) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_legs.clear()
	var skin: Color = PasserbyPlaceholder.SKIN_COLORS[rng.randi() % PasserbyPlaceholder.SKIN_COLORS.size()]
	var hair: Color = PasserbyPlaceholder.HAIR_COLORS[rng.randi() % PasserbyPlaceholder.HAIR_COLORS.size()]
	var top: Color = PasserbyPlaceholder.TOP_COLORS[rng.randi() % PasserbyPlaceholder.TOP_COLORS.size()]
	var bottom: Color = PasserbyPlaceholder.BOTTOM_COLORS[rng.randi() % PasserbyPlaceholder.BOTTOM_COLORS.size()]
	var frame := StreetShapes.solid(color)
	var dark := StreetShapes.solid(Color(0.12, 0.12, 0.12))
	var metal := StreetShapes.glossy(Color(0.75, 0.75, 0.72))
	var shapes := StreetShapes.new()
	# Rad: Reifen, Rahmen, Lenker, Sattel, Korb vorn
	for z in [WHEEL_Z, -WHEEL_Z]:
		shapes.add_torus(Vector3(0.0, WHEEL, z), Vector3.RIGHT, WHEEL - 0.025, 0.025, dark, 20, 6)
		shapes.add_cylinder(Vector3(-0.03, WHEEL, z), Vector3(0.03, WHEEL, z), 0.04, metal, 8)
	var seat := Vector3(0.0, 0.92, -0.22)
	var head_tube := Vector3(0.0, 0.86, 0.38)
	for bar in [[Vector3(0.0, WHEEL, -WHEEL_Z), CRANK], [CRANK, seat], [seat, Vector3(0.0, WHEEL, -WHEEL_Z)],
			[CRANK, head_tube], [Vector3(0.0, 0.8, -0.15), head_tube], [head_tube, Vector3(0.0, WHEEL, WHEEL_Z)],
			[head_tube, Vector3(0.0, 1.06, 0.32)]]:
		shapes.add_cylinder(bar[0], bar[1], 0.022, frame, 8)
	shapes.add_cylinder(Vector3(-0.27, 1.06, 0.3), Vector3(0.27, 1.06, 0.3), 0.017, metal, 8)
	shapes.add_round_box(seat + Vector3(0.0, 0.04, 0.0), Vector3(0.14, 0.06, 0.24), dark, 0.6, 8, 4)
	if rng.randf() < 0.5:
		shapes.add_round_box(Vector3(0.0, 0.9, 0.55), Vector3(0.34, 0.22, 0.26), StreetShapes.solid(Color(0.72, 0.56, 0.36)), 0.35, 10, 5)
	# Fahrer: leicht nach vorn geneigt, Arme zum Lenker
	var lean := Basis(Vector3.RIGHT, 0.35)
	shapes.xform = Transform3D(lean, HIP)
	shapes.add_round_box(Vector3(0.0, 0.3, 0.0), Vector3(0.38, 0.58, 0.24), StreetShapes.solid(top), 0.42)
	shapes.xform = Transform3D.IDENTITY
	var shoulder_y := HIP.y + 0.52
	for x in [-0.2, 0.2]:
		shapes.add_cylinder(Vector3(x, shoulder_y, HIP.z + 0.2), Vector3(x * 1.25, 1.07, 0.3), 0.05, StreetShapes.solid(top), 8)
		shapes.add_ellipsoid(Vector3(x * 1.25, 1.07, 0.3), Vector3(0.07, 0.07, 0.07), StreetShapes.solid(skin), 6, 3)
	var head := Vector3(0.0, HIP.y + 0.72, HIP.z + 0.3)
	shapes.add_ellipsoid(head, Vector3(0.2, 0.24, 0.22), StreetShapes.solid(skin))
	shapes.add_ellipsoid(head + Vector3(0.0, 0.06, -0.015), Vector3(0.215, 0.16, 0.234), StreetShapes.solid(hair))
	shapes.add_round_box(head + Vector3(0.0, -0.01, -0.05), Vector3(0.21, 0.17, 0.13), StreetShapes.solid(hair), 0.85)
	_body = MeshInstance3D.new()
	_body.name = "Bike"
	_body.mesh = shapes.commit()
	add_child(_body)
	# Beine: Oberschenkel von der Hüfte, Unterschenkel zum Pedal (zwei Teile je Bein, in animate gestellt)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		add_child(leg)
		for part in ["Thigh", "Shin"]:
			var piece := MeshInstance3D.new()
			piece.name = part
			var leg_shapes := StreetShapes.new()
			leg_shapes.add_round_box(Vector3(0.0, -0.22, 0.0), Vector3(0.13, 0.48, 0.14), StreetShapes.solid(bottom), 0.6, 10, 5)
			if part == "Shin":
				leg_shapes.add_round_box(Vector3(0.0, -0.46, 0.05), Vector3(0.1, 0.07, 0.22), StreetShapes.solid(Color(0.15, 0.12, 0.1)), 0.5, 8, 4)
			piece.mesh = leg_shapes.commit()
			leg.add_child(piece)
		_legs.append(leg)
	animate(0.0, 0.0)


## Treten: Die Kurbel dreht sich passend zum Tempo, die Beine folgen den Pedalen.
func animate(speed: float, delta: float) -> void:
	if _legs.is_empty():
		return
	_crank = fmod(_crank + speed / (WHEEL * 2.4) * delta, TAU)
	for i in _legs.size():
		var side := -1.0 if i == 0 else 1.0
		var angle := _crank + (PI if i == 1 else 0.0)
		var pedal := CRANK + Vector3(side * 0.12, sin(angle) * 0.17, cos(angle) * 0.17)
		var hip := HIP + Vector3(side * 0.1, 0.0, 0.0)
		# Knie: zwischen Hüfte und Pedal, nach vorn geknickt (zwei Glieder à 0,46 m)
		var reach := hip.distance_to(pedal)
		var mid := (hip + pedal) / 2.0
		var bend := sqrt(maxf(0.0, 0.46 * 0.46 - reach * reach / 4.0))
		var axis := pedal - hip
		var perp := Vector3(0.0, -axis.z, axis.y).normalized()
		if perp.z < 0.0:
			perp = -perp  # das Knie zeigt nach vorn
		var knee := mid + perp * bend
		_aim(_legs[i].get_child(0) as Node3D, hip, knee)
		_aim(_legs[i].get_child(1) as Node3D, knee, pedal)


## Ein Glied (Mesh hängt nach -Y) von a nach b ausrichten.
func _aim(piece: Node3D, a: Vector3, b: Vector3) -> void:
	var down := (b - a).normalized()
	var x := Vector3.RIGHT
	var y := -down
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	piece.transform = Transform3D(Basis(x, y, z), a)
	piece.scale = Vector3(1.0, a.distance_to(b) / 0.46, 1.0)


func set_shadows(enabled: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		part.cast_shadow = mode
