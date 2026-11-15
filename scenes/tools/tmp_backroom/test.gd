extends Node
## Vorübergehend: Läuft die Spielfigur ins Hinterzimmer? (Tür per Blick + E, dann hineingehen)

var main: Node
var player: CharacterBody3D
var room: Room

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 30:
		await get_tree().physics_frame
	player = main.get_node("Player")
	room = main.get_node("GroundFloorRoom")
	var door := room.get_node("BackRoom/BackDoor") as BackRoomDoor
	print("Tür bei ", door.global_position, " offen=", door.is_open)
	# Wege: 1) aus der Ladenmitte zur Tür (um die Theke herum), 2) vor der Tür hinein
	var start := room.to_global(Vector3(0.0, 0.05, 1.5))
	player.global_position = start
	await _walk_to(room.to_global(Vector3(0.3, 0.0, 3.55)), 4.0)
	print("hinter Theke links: ", room.to_local(player.global_position))
	await _walk_to(room.to_global(Vector3(1.5, 0.0, 3.55)), 4.0)
	print("vor der Tür: ", room.to_local(player.global_position))
	# zur Tür schauen
	_face(door.global_position + Vector3.UP * 1.2)
	for i in 5:
		await get_tree().physics_frame
	var target = player.get("_current_target")
	print("Ziel beim Blick auf die Tür: ", target, " prompt=", (target as Interactable).prompt_text if target else "-",
		" Eltern=", (target as Node).get_parent().name if target else "-")
	var ray: RayCast3D = player.interaction_ray
	print("Strahl trifft: ", ray.get_collider(), " bei ", ray.get_collision_point() if ray.is_colliding() else Vector3.ZERO)
	door.set_open(true)
	for i in 40:
		await get_tree().physics_frame
	await _walk_to(room.to_global(Vector3(1.5, 0.0, 5.5)), 5.0)
	var p := room.to_local(player.global_position)
	print("Ende: ", p, " im Hinterzimmer=", BackRoom.back_area().has_point(Vector2(p.x, p.z)))
	get_tree().quit()

func _face(point: Vector3) -> void:
	var d := point - player.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	var head: Node3D = player.head
	var flat := Vector2(d.x, d.z).length()
	head.rotation.x = atan2(d.y - GameConfig.eye_height, flat)

func _walk_to(target: Vector3, seconds: float) -> void:
	player.set("movement_enabled", false)
	var t := 0.0
	var stuck := 0.0
	var last := player.global_position
	while t < seconds:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		var d := target - player.global_position
		d.y = 0.0
		if d.length() < 0.08:
			return
		player.velocity = d.normalized() * 1.6 + Vector3.DOWN * 2.0
		player.move_and_slide()
		if player.global_position.distance_to(last) < 0.002:
			stuck += dt
			if stuck > 0.6:
				print("  festgeklemmt bei ", room.to_local(player.global_position), " an ", _hit_names())
				return
		else:
			stuck = 0.0
		last = player.global_position

func _hit_names() -> String:
	var names := []
	for i in player.get_slide_collision_count():
		var c := player.get_slide_collision(i).get_collider() as Node
		names.append(str(c.get_path()) if c else "?")
	return ", ".join(names)
