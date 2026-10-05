class_name Player
extends CharacterBody3D
## Die Spielfigur in Ego-Perspektive.
##
## Laufen mit WASD (mit Umschalt schneller), Umsehen mit der Maus, Interagieren mit E.
## Springen mit der Leertaste, Hocken solange Strg gedrückt ist.
## Hinsetzen: E auf ein Sitzmöbel; aufstehen mit E, Leertaste oder einer Bewegungstaste.
## Alle Einstellwerte (Tempo, Mausempfindlichkeit ...) stehen in GameConfig.

## Wird gesendet, wenn sich das anvisierte interaktive Objekt ändert
## (null = gerade nichts Interaktives in der Bildmitte).
signal interaction_target_changed(target: Interactable)
## Wird gesendet, wenn sich die Figur hinsetzt (true) oder aufsteht (false).
signal seated_changed(seated: bool)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_target: Interactable = null
var _head_bob_time: float = 0.0
# Sitzen: aktueller Sitzplatz, Stehposition davor und laufende Bewegung
var _seat: SeatPoint = null
var _stand_position := Vector3.ZERO
var _sit_tween: Tween
# Hocken: aktueller Zustand, Körperform und Höhe im Stehen
var _is_crouching := false
var _capsule: CapsuleShape3D
var _stand_body_height: float = 1.7
## Aktuelles Höchsttempo: gleitet weich zwischen walk_speed und sprint_speed hin und her.
var _current_max_speed: float = 0.0
## Im Gestaltungsmodus wird das Interagieren mit E abgeschaltet.
var interaction_enabled: bool = true:
	set(value):
		interaction_enabled = value
		if is_node_ready():
			_update_interaction_target()


func _ready() -> void:
	# Werte aus der zentralen Konfiguration übernehmen
	head.position.y = GameConfig.eye_height
	camera.fov = GameConfig.camera_fov
	# Der Strahl reicht so weit wie die größte Reichweite; ob ein Ziel nah genug ist,
	# wird danach je nach Objekt geprüft (siehe _update_interaction_target)
	var reach := maxf(GameConfig.interaction_distance, GameConfig.long_interaction_distance)
	interaction_ray.target_position = Vector3(0, 0, -reach)
	_current_max_speed = GameConfig.walk_speed
	# Eigene Kopie der Körperform, damit sie sich beim Hocken verkleinern lässt
	_capsule = _collision.shape.duplicate()
	_collision.shape = _capsule
	_stand_body_height = _capsule.height
	# Mauszeiger im Spiel "fangen" (unsichtbar, bleibt im Fenster)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_around(event.relative)
	elif (event.is_action_pressed("interact") or event.is_action_pressed("jump")) and is_seated():
		stand_up()
	elif event.is_action_pressed("interact") and interaction_enabled:
		_try_interact()
	elif event is InputEventMouseButton and event.pressed and not MenuStack.has_open():
		# Falls die Maus frei ist (z. B. nach einem Fensterwechsel): per Klick wieder fangen.
		# Ist etwas offen (z. B. der Katalog), gehört der Mauszeiger dorthin.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if _seat or (_sit_tween and _sit_tween.is_running()):
		# Im Sitzen (und während des Hinsetzens/Aufstehens) nicht laufen
		if _seat and not (_sit_tween and _sit_tween.is_running()) \
				and Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO:
			stand_up()
		camera.position.y = lerpf(camera.position.y, 0.0, 10.0 * delta)
		_update_interaction_target()
		return
	_apply_gravity(delta)
	_update_crouch(delta)
	_jump()
	_move(delta)
	_update_head_bob(delta)
	_update_interaction_target()


# --- Springen und Hocken ---

## Sanfter Sprung: Die Startgeschwindigkeit ergibt genau die gewünschte Sprunghöhe.
func _jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching:
		# Startgeschwindigkeit so, dass genau die gewünschte Höhe erreicht wird
		velocity.y = sqrt(2.0 * _gravity * GameConfig.air_gravity_scale * GameConfig.jump_height)


## Hocken, solange Strg gedrückt ist. Aufstehen nur, wenn über einem genug Platz ist.
func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch")
	if wants_crouch and not _is_crouching:
		_set_body_height(GameConfig.crouch_body_height)
		_is_crouching = true
	elif not wants_crouch and _is_crouching and _has_room_to_stand():
		_set_body_height(_stand_body_height)
		_is_crouching = false
	# Kamera gleitet sanft auf die passende Augenhöhe
	var target_eye := GameConfig.crouch_eye_height if _is_crouching else GameConfig.eye_height
	head.position.y = move_toward(head.position.y, target_eye, GameConfig.crouch_transition_speed * delta)


func is_crouching() -> bool:
	return _is_crouching


## Ändert die Körperhöhe; die Füße bleiben dabei auf dem Boden.
func _set_body_height(body_height: float) -> void:
	_capsule.height = body_height
	_collision.position.y = body_height / 2.0


## Ist über der hockenden Figur genug Platz zum Aufstehen?
func _has_room_to_stand() -> bool:
	var standing := CapsuleShape3D.new()
	standing.radius = _capsule.radius - 0.02
	standing.height = _stand_body_height - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (_stand_body_height / 2.0 + 0.02))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# --- Sitzen ---

func is_seated() -> bool:
	return _seat != null


## Der Punkt, auf den die Figur gerade schaut (oder ein Punkt 2 m voraus).
func get_aim_point() -> Vector3:
	if interaction_ray.is_colliding():
		return interaction_ray.get_collision_point()
	return camera.global_position - camera.global_basis.z * 2.0


## Setzt sich auf einen Sitzplatz: Die Kamera gleitet sanft auf Sitzhöhe.
func sit_down(seat: SeatPoint) -> void:
	if _seat or not seat.is_free():
		return
	_seat = seat
	seat.occupant = self
	_stand_position = global_position
	velocity = Vector3.ZERO
	_collision.disabled = true
	# Blick in Richtung der Vorderseite des Sitzmöbels (die Figur schaut entlang -Z)
	var forward := seat.global_basis.z
	var target_yaw := atan2(-forward.x, -forward.z)
	var start_yaw := rotation.y
	var end_yaw := start_yaw + wrapf(target_yaw - start_yaw, -PI, PI)
	_move_body(seat.global_position, end_yaw, GameConfig.seated_eye_height)
	# Blick sanft geradeaus richten (leicht nach unten, wie man eben sitzt)
	_sit_tween.tween_property(head, "rotation:x", deg_to_rad(-8.0), GameConfig.sit_transition_time)
	_update_interaction_target()
	seated_changed.emit(true)


## Steht wieder auf und geht an die Stelle zurück, an der man vorher stand.
func stand_up() -> void:
	if not _seat:
		return
	_seat.occupant = null
	_seat = null
	_move_body(_stand_position, rotation.y, GameConfig.eye_height)
	_sit_tween.finished.connect(func() -> void: _collision.disabled = false)
	seated_changed.emit(false)


func _move_body(target_position: Vector3, target_yaw: float, eye: float) -> void:
	if _sit_tween:
		_sit_tween.kill()
	var duration := GameConfig.sit_transition_time
	_sit_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sit_tween.tween_property(self, "global_position", target_position, duration)
	_sit_tween.tween_property(self, "rotation:y", target_yaw, duration)
	_sit_tween.tween_property(head, "position:y", eye, duration)


## Dreht die Figur (links/rechts) und den Kopf (hoch/runter) mit der Maus.
func _look_around(mouse_delta: Vector2) -> void:
	var sensitivity := deg_to_rad(GameConfig.mouse_sensitivity)
	var vertical := mouse_delta.y * (-1.0 if GameConfig.invert_mouse_y else 1.0)
	rotate_y(-mouse_delta.x * sensitivity)
	head.rotate_x(-vertical * sensitivity)
	var limit := deg_to_rad(GameConfig.max_look_angle)
	head.rotation.x = clampf(head.rotation.x, -limit, limit)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * GameConfig.air_gravity_scale * delta


## Sanftes Laufen: Die Geschwindigkeit wird weich hoch- und heruntergeregelt.
func _move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Eingabe in Blickrichtung der Figur umrechnen
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)

	# Schnell laufen, solange die Umschalttaste gedrückt ist – mit sanftem Übergang
	var wanted_speed := GameConfig.walk_speed
	if _is_crouching:
		wanted_speed = GameConfig.crouch_speed
	elif Input.is_action_pressed("sprint") and input != Vector2.ZERO:
		wanted_speed = GameConfig.sprint_speed
	_current_max_speed = move_toward(_current_max_speed, wanted_speed, GameConfig.sprint_blend_rate * delta)
	var target_velocity := direction * _current_max_speed

	var rate := GameConfig.acceleration if input != Vector2.ZERO else GameConfig.deceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()


## Leichtes Auf und Ab der Kamera beim Gehen.
func _update_head_bob(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio := clampf(speed / GameConfig.walk_speed, 0.0, 1.0)
	# Beim schnellen Laufen werden die Schritte schneller, das Wippen aber nicht stärker
	var step_ratio := speed / GameConfig.walk_speed
	if is_on_floor() and speed > 0.1:
		_head_bob_time += delta * GameConfig.head_bob_frequency * step_ratio
	var target_y := sin(_head_bob_time) * GameConfig.head_bob_amount * speed_ratio
	camera.position.y = lerpf(camera.position.y, target_y, 10.0 * delta)


## Prüft, ob in der Bildmitte ein interaktives Objekt ist.
func _update_interaction_target() -> void:
	var new_target: Interactable = null
	if interaction_enabled and not is_seated() and interaction_ray.is_colliding():
		var hit := interaction_ray.get_collider()
		if hit is Interactable and hit.is_enabled:
			var distance := camera.global_position.distance_to(interaction_ray.get_collision_point())
			var reach := GameConfig.long_interaction_distance if hit.long_reach else GameConfig.interaction_distance
			if distance <= reach:
				new_target = hit

	if new_target != _current_target:
		# Dezente Hervorhebung wandert mit dem anvisierten Objekt
		FurnitureUtils.set_interactable_highlighted(_current_target, false)
		FurnitureUtils.set_interactable_highlighted(new_target, true)
		_current_target = new_target
		interaction_target_changed.emit(_current_target)


func _try_interact() -> void:
	if is_instance_valid(_current_target):
		_current_target.interact(self)
