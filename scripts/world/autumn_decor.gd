class_name AutumnDecor
extends Node3D
## Herbst-Deko draußen (seit der großen Überarbeitung): kleine Gruppen aus Kürbissen (groß/klein orange, cremeweiß,
## dunkelgrün; Modelle aus tools/blender/build_storybook_autumn.py) am Fuß der Hauswände – vor Läden, unter Fenstern,
## neben Töpfen. Nie vor Türen, nie am Lieferplatz, nie dort, wo schon etwas steht (Prüfung mit der Physik). Jede Gruppe
## hat eine kleine Kollision (Spielfigur) und einen StreetObstacle-Kreis (Passanten gehen darum herum).
## Nur im Herbst (Season); main.gd legt den Knoten unter Outside an, Lage wie StreetLife. Werte: GameConfig.autumn_decor_*.

const MODELS: Array[String] = [
	"res://assets/models/props/autumn/pumpkin_orange_big.glb",
	"res://assets/models/props/autumn/pumpkin_orange_small.glb",
	"res://assets/models/props/autumn/pumpkin_cream.glb",
	"res://assets/models/props/autumn/pumpkin_green.glb",
]
## Halbmesser der Modelle (für Abstände und Kollision)
const RADII: Array[float] = [0.18, 0.11, 0.15, 0.125]
## Abstand der Gruppen-Mitte zur Hauswand (m)
const WALL_GAP := 0.3

var _groups: Array[Node3D] = []


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	# erst, wenn Straßenleben (Türen, Gehwege) und Häuser fertig sind
	for k in 4:
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	_place_groups()
	Season.changed.connect(_on_season_changed)
	_apply()


func _place_groups() -> void:
	var life := get_tree().get_first_node_in_group(StreetLife.GROUP) as StreetLife
	var route := StreetPaths.centerline()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1031
	var avoid := _avoid_points(life)
	var obstacles := _obstacle_points()
	var space := get_world_3d().direct_space_state
	var s := rng.randf_range(1.0, 3.0)
	var count := 0
	while s < route.length():
		var part := route.part_at(s)
		if part in ["passage", "before_passage", "after_passage"]:
			s += GameConfig.autumn_decor_step
			continue
		for side: int in [1, -1]:
			if rng.randf() > GameConfig.autumn_decor_chance:
				continue
			var band := StreetPaths.sidewalk_band(part, side)
			var wall := absf(band.y if side > 0 else band.x) + StreetPaths.WALL_CLEARANCE
			var p2 := route.point_at(s, (wall - 1.3) * side)
			var out2 := route.point_at(s, (wall + 1.0) * side) - p2
			# Die echte Hauswand suchen (zweiter Nachtest: wo Häuser zurückspringen, standen Kürbisse sonst mitten
			# auf dem Gehweg) – nur an einer Wand, die fast quer zum Strahl steht und nah an der erwarteten Lage ist
			var center := _wall_spot(space, Vector3(p2.x, 0.0, p2.y), Vector3(out2.x, 0.0, out2.y).normalized())
			if center == Vector3.INF:
				continue
			if _near_any(center, avoid, 1.3) or _near_any(center, obstacles, OBSTACLE_GAP):
				continue
			if not _free(space, center, 0.22):
				continue
			var along2 := route.direction_at(s)
			_add_group(center, Vector3(along2.x, 0.0, along2.y), Vector3(-along2.y, 0.0, along2.x) * -side, rng)
			avoid.append(center)
			count += 1
		s += GameConfig.autumn_decor_step * rng.randf_range(0.7, 1.5)
	if life:
		life.refresh_static_obstacles()


## Mitte einer Gruppe vor der echten Hauswand: Strahl in Kniehöhe vom Gehweg nach außen (from = 1 m vor der erwarteten
## Wand). Ohne Wand in der Nähe, an unsichtbaren Grenzen (see_through) oder an schrägen Ecken: Vector3.INF.
func _wall_spot(space: PhysicsDirectSpaceState3D, from: Vector3, out: Vector3) -> Vector3:
	var start := from + Vector3.UP * 0.35
	var ray := PhysicsRayQueryParameters3D.create(to_global(start), to_global(start + out * 2.4), 1 | (1 << 7))
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return Vector3.INF
	var collider := hit.collider as Object
	if collider and collider.has_meta("see_through"):
		return Vector3.INF
	var normal := (global_basis.inverse() * Vector3(hit.normal)).normalized()
	if normal.dot(-out) < 0.6:
		return Vector3.INF
	var point := to_local(hit.position)
	var center := point - out * WALL_GAP
	return Vector3(center.x, 0.0, center.z)


## Türen (alle Häuser und die Bücherei), Lieferplatz der Kartons, Bänke: dort keine Kürbisse.
func _avoid_points(life: StreetLife) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if life and life.homes:
		for door: HouseDoor in life.homes.doors:
			points.append(to_local(door.center()))
	var door := StreetLayout.door_center()
	points.append(to_local(Vector3(door.x, global_position.y, door.z)))
	var deliveries := get_parent().get_node_or_null("Deliveries") as Node3D
	if deliveries:
		points.append(to_local(deliveries.global_position))
		points.append(to_local(deliveries.global_position) + Vector3(1.5, 0.0, 0.0))
	for seat: Node in get_tree().get_nodes_in_group(StreetLife.SEAT_GROUP):
		if seat is Node3D:
			points.append(to_local((seat as Node3D).global_position))
	return points


## Hindernisse auf dem Gehweg (Laternen, Telefonzelle, Briefkasten, Bänke …): neben ihnen würde der Gehweg mit Kürbissen
## zu eng (seit „Modelle schöner“) – Abstand OBSTACLE_GAP.
func _obstacle_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for obstacle: Node in get_tree().get_nodes_in_group(StreetLife.OBSTACLE_GROUP):
		if obstacle is Node3D:
			points.append(to_local((obstacle as Node3D).global_position))
	return points


const OBSTACLE_GAP := 2.6


func _near_any(p: Vector3, points: Array[Vector3], distance: float) -> bool:
	for q in points:
		if Vector2(p.x - q.x, p.z - q.z).length() < distance:
			return true
	return false


## Ist hier Platz (nichts Festes im Kreis) und liegt der Gehweg darunter?
func _free(space: PhysicsDirectSpaceState3D, center: Vector3, radius: float) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(to_global(center + Vector3.UP * 2.0), to_global(center + Vector3.DOWN * 0.5), 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or absf(to_local(hit.position).y) > 0.05:
		return false
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, to_global(center + Vector3.UP * 0.3))
	query.collision_mask = 1 | (1 << 3)
	return space.intersect_shape(query, 1).is_empty()


## Eine Gruppe: ein bis drei Kürbisse dicht nebeneinander an der Wand (along = entlang der Wand, out = von der Wand weg).
func _add_group(center: Vector3, along: Vector3, out: Vector3, rng: RandomNumberGenerator) -> void:
	var group := Node3D.new()
	group.name = "Pumpkins%d" % _groups.size()
	group.position = center
	add_child(group)
	var picks: Array[int] = []
	var n := 1 + (1 if rng.randf() < 0.7 else 0) + (1 if rng.randf() < 0.4 else 0)
	picks.append(0 if rng.randf() < 0.6 else 2)
	for k in n - 1:
		picks.append([1, 1, 2, 3, 3][rng.randi() % 5])
	var x := -0.5 * (n - 1) * 0.3
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	group.add_child(body)
	for k in picks.size():
		var i := picks[k]
		var model := (load(MODELS[i]) as PackedScene).instantiate() as Node3D
		var offset := along * x + out * rng.randf_range(-0.06, 0.08)
		if k > 0 and RADII[i] < 0.13:
			offset += out * 0.14  # kleine vorn
		model.position = offset
		model.rotation.y = rng.randf_range(0.0, TAU)
		model.rotate_object_local(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
		group.add_child(model)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = RADII[i] * 0.9
		cylinder.height = RADII[i] * 1.4
		shape.shape = cylinder
		shape.position = offset + Vector3.UP * cylinder.height / 2.0
		body.add_child(shape)
		x += RADII[i] + 0.06 + (RADII[picks[k + 1]] if k + 1 < picks.size() else 0.0) * 0.6
	var obstacle := StreetObstacle.new()
	obstacle.radius = 0.32 + 0.08 * (n - 1)
	group.add_child(obstacle)
	_groups.append(group)


func _on_season_changed(_season: String) -> void:
	_apply()
	var life := get_tree().get_first_node_in_group(StreetLife.GROUP) as StreetLife
	if life:
		life.refresh_static_obstacles()


## Nur im Herbst sichtbar und fest (sonst auch nicht im Weg).
func _apply() -> void:
	var on := Season.is_autumn()
	for group in _groups:
		group.visible = on
		var body := group.get_node_or_null("Body") as StaticBody3D
		if body:
			body.collision_layer = 1 if on else 0
		for child in group.get_children():
			if child is StreetObstacle:
				if on and not child.is_in_group(StreetLife.OBSTACLE_GROUP):
					child.add_to_group(StreetLife.OBSTACLE_GROUP)
				elif not on and child.is_in_group(StreetLife.OBSTACLE_GROUP):
					child.remove_from_group(StreetLife.OBSTACLE_GROUP)
