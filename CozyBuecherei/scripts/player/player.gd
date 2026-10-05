class_name Player
extends CharacterBody3D
## Die Spielfigur in Ego-Perspektive.
##
## Laufen mit WASD, Umsehen mit der Maus, Interagieren mit E.
## Alle Einstellwerte (Tempo, Mausempfindlichkeit ...) stehen in GameConfig.

## Wird gesendet, wenn sich das anvisierte interaktive Objekt ändert
## (null = gerade nichts Interaktives in der Bildmitte).
signal interaction_target_changed(target: Interactable)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_target: Interactable = null
var _head_bob_time: float = 0.0


func _ready() -> void:
	# Werte aus der zentralen Konfiguration übernehmen
	head.position.y = GameConfig.eye_height
	camera.fov = GameConfig.camera_fov
	interaction_ray.target_position = Vector3(0, 0, -GameConfig.interaction_distance)
	# Mauszeiger im Spiel "fangen" (unsichtbar, bleibt im Fenster)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_around(event.relative)
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event is InputEventMouseButton and event.pressed:
		# Falls die Maus frei ist (z. B. nach einem Fensterwechsel): per Klick wieder fangen
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_move(delta)
	_update_head_bob(delta)
	_update_interaction_target()


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
		velocity.y -= _gravity * delta


## Sanftes Laufen: Die Geschwindigkeit wird weich hoch- und heruntergeregelt.
func _move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Eingabe in Blickrichtung der Figur umrechnen
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	var target_velocity := direction * GameConfig.walk_speed

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
	if is_on_floor() and speed > 0.1:
		_head_bob_time += delta * GameConfig.head_bob_frequency * speed_ratio
	var target_y := sin(_head_bob_time) * GameConfig.head_bob_amount * speed_ratio
	camera.position.y = lerpf(camera.position.y, target_y, 10.0 * delta)


## Prüft, ob in der Bildmitte ein interaktives Objekt ist.
func _update_interaction_target() -> void:
	var new_target: Interactable = null
	if interaction_ray.is_colliding():
		var hit := interaction_ray.get_collider()
		if hit is Interactable and hit.is_enabled:
			new_target = hit

	if new_target != _current_target:
		_current_target = new_target
		interaction_target_changed.emit(_current_target)


func _try_interact() -> void:
	if is_instance_valid(_current_target):
		_current_target.interact(self)
