class_name Player
extends CharacterBody3D
## Die Spielfigur in Ego-Perspektive.
##
## Laufen mit WASD (mit Umschalt schneller), Umsehen mit der Maus, Interagieren mit E.
## Springen mit der Leertaste, Hocken solange Strg gedrückt ist.
## Hinsetzen: E auf ein Sitzmöbel; aufstehen mit E, Leertaste oder einer Bewegungstaste.
## Manche Objekte (z. B. Regale) unterscheiden E tippen und E halten (Interactable.supports_hold).
## Bücher (nur mit der Maus, alles andere bleibt bei E):
## - Rechtsklick nimmt das angeschaute Buch (Interactable.take_requested).
## - Linksklick legt das Buch obenauf genau dort ab, wo ich hinschaue: ins Regal
##   (Interactable.place_requested) oder frei in die Welt (WORLD_PLACER_GROUP).
## - Linksklick halten am Regal räumt alle passenden ein (place_all_requested, mit Ring,
##   GameConfig.place_all_hold_time). Ein kurzer Klick zählt erst beim Loslassen.
## - Mausrad wechselt das Buch obenauf, Q halten legt alle getragenen Bücher ins Lager.
## Klicks zählen nur, solange der Mauszeiger gefangen ist (sonst fängt ein Klick ihn wieder).
## Alle Einstellwerte (Tempo, Mausempfindlichkeit ...) stehen in GameConfig.

## Wird gesendet, wenn sich das anvisierte interaktive Objekt ändert
## (null = gerade nichts Interaktives in der Bildmitte).
signal interaction_target_changed(target: Interactable)
## Wird gesendet, wenn sich die Figur hinsetzt (true) oder aufsteht (false).
signal seated_changed(seated: bool)
## Fortschritt beim Gedrückthalten (0 bis 1); -1 = nichts wird gehalten.
## action: "interact" (E am Objekt), "place_all" (linke Maustaste am Regal: alle einräumen)
## oder "store_books" (Q: alle Bücher ins Lager).
signal hold_progress_changed(progress: float, action: StringName)

## Gruppe des Knotens, der Bücher frei in der Welt ablegt (Tische, Boden …), siehe LooseBooks.
const WORLD_PLACER_GROUP := "world_book_placer"

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_target: Interactable = null
# E gedrückt halten: Ziel, gehaltene Zeit und ob die lange Aktion schon ausgelöst wurde
var _hold_target: Interactable = null
var _hold_time := 0.0
var _hold_done := false
# Q gedrückt halten (alle getragenen Bücher ins Lager): gehaltene Zeit, -1 = nicht gehalten
var _store_hold_time := -1.0
# Linke Maustaste am Regal gedrückt halten (alle einräumen): Ziel, Zeit, schon ausgelöst?
var _place_target: Interactable = null
var _world_placer: LooseBooks = null
var _place_hold_time := 0.0
var _place_hold_done := false
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
## Laufen, Springen und Hocken (z. B. aus, solange der Shop offen ist).
var movement_enabled: bool = true
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
	# Das Buch obenauf in der Hand (unten rechts im Bild)
	var held := HeldBook.new()
	held.name = "HeldBook"
	camera.add_child(held)
	# Mauszeiger im Spiel "fangen" (unsichtbar, bleibt im Fenster)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_around(event.relative)
	elif (event.is_action_pressed("interact") or event.is_action_pressed("jump")) and is_seated():
		stand_up()
	elif event.is_action_pressed("interact") and interaction_enabled:
		_start_interact()
	elif event.is_action_released("interact"):
		_finish_interact()
	elif (event.is_action_pressed("book_next") or event.is_action_pressed("book_previous")) \
			and interaction_enabled and BookStock.carried.size() > 1:
		BookStock.cycle_active(1 if event.is_action_pressed("book_next") else -1)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Falls die Maus frei ist (z. B. nach einem Fensterwechsel): per Klick wieder fangen.
		# Ist etwas offen (z. B. der Katalog), gehört der Mauszeiger dorthin.
		if not MenuStack.has_open():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("book_take") and _can_use_mouse():
		if is_instance_valid(_current_target):
			_current_target.request_take(self)
	elif event.is_action_pressed("book_place") and _can_use_mouse():
		_start_place()
	elif event.is_action_released("book_place"):
		_finish_place()
	elif event.is_action_pressed("store_books") and interaction_enabled and not BookStock.carried.is_empty():
		_store_hold_time = 0.0
	elif event.is_action_released("store_books"):
		_cancel_store_hold()


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


func _process(delta: float) -> void:
	_update_hold(delta)
	_update_place_hold(delta)
	_update_store_hold(delta)


# --- Springen und Hocken ---

## Sanfter Sprung: Die Startgeschwindigkeit ergibt genau die gewünschte Sprunghöhe.
func _jump() -> void:
	if movement_enabled and Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching:
		# Startgeschwindigkeit so, dass genau die gewünschte Höhe erreicht wird
		velocity.y = sqrt(2.0 * _gravity * GameConfig.air_gravity_scale * GameConfig.jump_height)


## Hocken, solange Strg gedrückt ist. Aufstehen nur, wenn über einem genug Platz ist.
func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch") and movement_enabled
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
	if not movement_enabled:
		input = Vector2.ZERO
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
	# Wurde das anvisierte Objekt inzwischen gelöscht (z. B. weggeräumt), vergessen wir es
	if not is_same(_current_target, null) and not is_instance_valid(_current_target):
		_current_target = null
		interaction_target_changed.emit(null)
	var new_target: Interactable = null
	if interaction_enabled and not is_seated() and interaction_ray.is_colliding():
		var hit := interaction_ray.get_collider()
		var point := interaction_ray.get_collision_point()
		# Fester Körper getroffen (z. B. Kartondeckel von oben)? Dann zählt sein Interactable.
		var target: Interactable = hit as Interactable
		if hit is Node and not hit.is_inside_tree():
			target = null  # gerade weggeräumt (z. B. beim Laden)
		elif target == null and hit is Node:
			target = Interactable.find_for(hit, point)
		if target and target.is_enabled:
			var distance := camera.global_position.distance_to(point)
			var reach := GameConfig.long_interaction_distance if target.long_reach else GameConfig.interaction_distance
			if distance <= reach:
				new_target = target
	# Ausgelegte Bücher (ohne Kollision): Liegt eins näher auf dem Blickstrahl, zählt es
	var loose := _get_world_placer()
	var from := camera.global_position
	var direction := -camera.global_basis.z
	if loose and interaction_enabled and not is_seated():
		var pick := loose.pick_distance(from, direction, GameConfig.interaction_distance)
		if pick < INF and pick < _solid_distance(from, direction):
			new_target = loose.get_interactable()

	if new_target != _current_target:
		# Dezente Hervorhebung wandert mit dem anvisierten Objekt (wenn das Objekt das möchte)
		if is_instance_valid(_current_target):
			_current_target.end_aim()
			if _current_target.highlight_owner:
				FurnitureUtils.set_interactable_highlighted(_current_target, false)
		if new_target and new_target.highlight_owner:
			FurnitureUtils.set_interactable_highlighted(new_target, true)
		_current_target = new_target
		interaction_target_changed.emit(_current_target)
	# Wohin genau ich schaue (z. B. welches Buch im Regal)
	if _current_target:
		_current_target.update_aim(from, direction)
	# Trage ich Bücher und schaue nicht auf ein Regal: Vorschau zum freien Ablegen
	if loose:
		var placing_target := is_instance_valid(_current_target) and _current_target.handles_placing \
			and _current_target != loose.get_interactable()
		var active := not BookStock.carried.is_empty() and interaction_enabled and not is_seated() \
			and not placing_target
		loose.update_world_aim(active, from, direction)


## E gedrückt: sofort benutzen – oder bei Objekten mit "halten" erst abwarten.
func _start_interact() -> void:
	if not is_instance_valid(_current_target):
		return
	if _current_target.supports_hold:
		_hold_target = _current_target
		_hold_time = 0.0
		_hold_done = false
	else:
		_current_target.interact(self)


## E losgelassen: Wurde nur kurz getippt, zählt es jetzt als normales Benutzen.
func _finish_interact() -> void:
	if _hold_target and not _hold_done and is_instance_valid(_hold_target) and _hold_target == _current_target:
		_hold_target.interact(self)
	_cancel_hold()


## Zählt die gehaltene Zeit; reicht sie, wird die lange Aktion ausgelöst.
func _update_hold(delta: float) -> void:
	if _hold_target == null:
		return
	if not is_instance_valid(_hold_target) or _hold_target != _current_target or not interaction_enabled \
			or not Input.is_action_pressed("interact"):
		_cancel_hold()
		return
	if _hold_done:
		return
	_hold_time += delta
	var progress := clampf(_hold_time / maxf(GameConfig.interact_hold_time, 0.01), 0.0, 1.0)
	hold_progress_changed.emit(progress, &"interact")
	if progress >= 1.0:
		_hold_done = true
		hold_progress_changed.emit(-1.0, &"interact")
		_hold_target.hold(self)


func _cancel_hold() -> void:
	if _hold_target != null:
		hold_progress_changed.emit(-1.0, &"interact")
	_hold_target = null
	_hold_done = false
	_hold_time = 0.0


## Maustasten für Bücher? Nur im Spiel (Maus gefangen, nicht im Sitzen, kein Menü, nicht
## im Gestaltungsmodus – dort ist interaction_enabled aus).
func _can_use_mouse() -> bool:
	return interaction_enabled and not is_seated() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# --- Bücher ablegen (linke Maustaste) ---

## Linke Maustaste gedrückt: das Buch obenauf ablegen – am Regal (mit "alle einräumen")
## erst abwarten, ob gehalten wird. Während der Ring läuft, wird noch nichts abgestellt.
func _start_place() -> void:
	if BookStock.carried.is_empty():
		return
	var target := _current_target if is_instance_valid(_current_target) and _current_target.handles_placing else null
	if target == null:
		_place_in_world()
	elif target.supports_place_all:
		_place_target = target
		_place_hold_time = 0.0
		_place_hold_done = false
	else:
		target.request_place(self)


## Linke Maustaste losgelassen: War es nur ein kurzer Klick, wird jetzt ein Buch abgestellt.
func _finish_place() -> void:
	if _place_target and not _place_hold_done and is_instance_valid(_place_target) \
			and _place_target == _current_target and interaction_enabled:
		_place_target.request_place(self)
	_cancel_place_hold()


## Zählt die gehaltene Zeit; ist der Ring voll, werden alle passenden Bücher eingeräumt.
func _update_place_hold(delta: float) -> void:
	if _place_target == null or _place_hold_done:
		return
	if not is_instance_valid(_place_target) or _place_target != _current_target or not interaction_enabled \
			or not _place_target.supports_place_all or not Input.is_action_pressed("book_place"):
		_cancel_place_hold()
		return
	_place_hold_time += delta
	var progress := clampf(_place_hold_time / maxf(GameConfig.place_all_hold_time, 0.01), 0.0, 1.0)
	hold_progress_changed.emit(progress, &"place_all")
	if progress >= 1.0:
		_place_hold_done = true
		hold_progress_changed.emit(-1.0, &"place_all")
		_place_target.request_place_all(self)


func _cancel_place_hold() -> void:
	if _place_target != null and not _place_hold_done:
		hold_progress_changed.emit(-1.0, &"place_all")
	_place_target = null
	_place_hold_done = false
	_place_hold_time = 0.0


## Kein Regal im Blick: Das Buch obenauf kommt frei in die Welt (Tisch, Boden …).
func _place_in_world() -> void:
	var placer := _get_world_placer()
	if placer:
		placer.place_active_book(self)


## Abstand bis zum ersten festen Körper auf dem Blickstrahl. E-Bereiche zählen nicht mit:
## Ein Buch auf dem Sofa liegt z. B. mitten im Bereich zum Hinsetzen.
func _solid_distance(from: Vector3, direction: Vector3) -> float:
	if not interaction_ray.is_colliding():
		return INF
	if not interaction_ray.get_collider() is Area3D:
		return from.distance_to(interaction_ray.get_collision_point())
	var to := from + direction * interaction_ray.target_position.length()
	var query := PhysicsRayQueryParameters3D.create(from, to, interaction_ray.collision_mask, [get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return from.distance_to(hit.position) if not hit.is_empty() else INF


## Der Knoten, der Bücher frei in der Welt ablegt (LooseBooks des Raums) – oder null.
func _get_world_placer() -> LooseBooks:
	if not is_instance_valid(_world_placer):
		_world_placer = get_tree().get_first_node_in_group(WORLD_PLACER_GROUP) as LooseBooks
	return _world_placer


## Q gehalten: Ist die Zeit um, kommen alle getragenen Bücher ins Lager.
func _update_store_hold(delta: float) -> void:
	if _store_hold_time < 0.0:
		return
	if not interaction_enabled or BookStock.carried.is_empty() or not Input.is_action_pressed("store_books"):
		_cancel_store_hold()
		return
	_store_hold_time += delta
	var progress := clampf(_store_hold_time / maxf(GameConfig.store_books_hold_time, 0.01), 0.0, 1.0)
	hold_progress_changed.emit(progress, &"store_books")
	if progress >= 1.0:
		_cancel_store_hold()
		BookStock.store_carried()


func _cancel_store_hold() -> void:
	if _store_hold_time >= 0.0:
		hold_progress_changed.emit(-1.0, &"store_books")
	_store_hold_time = -1.0
