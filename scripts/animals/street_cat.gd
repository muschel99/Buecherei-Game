class_name StreetCat
extends StreetAnimal
## Eine Katze (seit Etappe 6g). CatLife plant ihren Besuch als Folge von Schritten (wie bei Passanten):
## laufen ("walk"), über die Straße flitzen ("cross"), sich umdrehen ("turn"), eine Bewegung zeigen ("anim":
## sitzen, putzen, strecken, liegen, schlafen), springen ("jump": auf Bank, Stuhl, Fensterbank, Sessel und
## wieder herunter), hinterherrennen ("follow", Fangen), an der Tür warten ("wait_door"), verschwinden
## ("leave": erst, wenn niemand hinschaut). Dazu kleine Schritte: Sitz belegen/freigeben, Schnurren an/aus,
## drinnen/draußen, Spielzeug ablegen/aufnehmen, Platz belegen ("claim" … "claim_end").
##
## Streicheln: E (Interactable „Streicheln“) oder später ein Passant: pet(wer) – die Katze bleibt stehen,
## dreht sich zu ihm, reibt den Kopf (Bewegung "pet") und schnurrt. can_be_petted() fragt vorher.

signal finished(cat: StreetCat)
signal petted(by: Node3D)

## Natürliches Tempo der Bewegungen (m/s bei speed_scale 1) – danach richtet sich das Abspieltempo
const WALK_ANIM_SPEED := 0.45
const RUN_ANIM_SPEED := 1.7

## Prüfwerkzeug: jeden Schritt ausgeben
static var debug := false

var life: CatLife
var look := 0
var active := false
var radius := 0.2
## Tempo auf dem Boden (x, z unter "Outside") – für Passanten, die ausweichen
var velocity2 := Vector2.ZERO
var inside := false
var seat: SeatPoint
## Woran die Katze gerade sitzt oder liegt (folgt dem Sitz, falls das Möbel verschoben wird)
var _rest_on: Node3D
var _rest_offset := Vector3.ZERO

var _actions: Array[Dictionary] = []
var _action: Dictionary = {}
var _t := 0.0
var _index := 0
var _yaw_target := 0.0
var _blocked := 0.0
var _jump_from := Vector3.ZERO
var _purr: AudioStreamPlayer3D
## Schnurrt auch ohne Streicheln (liegt gemütlich auf dem Sessel)
var _rest_purr := false
var _meow_wait := 0.0
var _pet_left := 0.0
var _pet_face := Vector3.ZERO
var _toy: Node3D
var _toy_holder: Node3D
var _interactable: Interactable


func _ready() -> void:
	super._ready()
	_interactable = get_node_or_null("Interactable") as Interactable
	if _interactable:
		_interactable.interacted.connect(func(who: Node) -> void: pet(who as Node3D))
	set_active(false)


func set_active(enabled: bool) -> void:
	active = enabled
	visible = enabled
	if _interactable:
		_interactable.is_enabled = enabled
	var body := get_node_or_null("Body") as CollisionObject3D
	if body:
		body.collision_layer = 64 if enabled else 0
	if not enabled:
		_rest_purr = false
		_stop_purr()
		_actions.clear()
		_action = {}


func begin(start: Vector3, face: Vector3, actions: Array[Dictionary]) -> void:
	global_position = start
	rotation = Vector3(0.0, StreetAnimal.yaw_of(face), 0.0)
	_yaw_target = rotation.y
	_actions = actions
	_action = {}
	_pet_left = 0.0
	inside = false
	set_outdoor(true)
	set_active(true)
	play(&"walk", 0.0)
	_next()


## Neue Schritte statt der restlichen (z. B. umkehren, weil jemand den Weg versperrt).
func replace_actions(actions: Array[Dictionary]) -> void:
	_actions = actions
	_next()


## Kleiner Bogen um jemanden herum: erst die Punkte, dann der Rest des Weges ab der Stelle nach dem Bogen.
func detour(points: PackedVector3Array) -> void:
	if get_action_type() == "walk":
		var current := _action.duplicate()
		var pts: PackedVector3Array = current.points
		var end := points[-1]
		var best := _index
		var best_d := INF
		for i in range(_index, pts.size()):
			var d := pts[i].distance_to(end)
			if d < best_d:
				best_d = d
				best = i
		var rest := PackedVector3Array([end])
		rest.append_array(pts.slice(best + 1))
		current.points = rest
		current.erase("detour")
		_actions.push_front(current)
	var path := PackedVector3Array([global_position])
	path.append_array(points)
	_actions.push_front({"type": "walk", "points": path, "speed": GameConfig.cat_walk_speed, "detour": true})
	_next()


func in_detour() -> bool:
	return bool(_action.get("detour", false))


## Schritte vor die restlichen schieben (z. B. hinein in die Bücherei).
func insert_actions(actions: Array[Dictionary]) -> void:
	var rest := _actions.duplicate()
	_actions = actions
	_actions.append_array(rest)
	_next()


func get_action_type() -> String:
	return String(_action.get("type", ""))


## Steht die Katze auf dem Boden (nicht auf Bank, Fensterbank oder Sessel)?
func on_ground() -> bool:
	return active and _rest_on == null and get_action_type() != "jump"


func can_be_petted() -> bool:
	return active and get_action_type() not in ["jump", "cross", "leave"]


## Streicheln (Spielfigur mit E, später auch Passanten): Katze hält inne, dreht sich zu by, schnurrt.
func pet(by: Node3D, seconds: float = -1.0) -> void:
	if not can_be_petted():
		return
	var time := GameConfig.cat_pet_time if seconds < 0.0 else seconds
	if _pet_left <= 0.0 and randf() < 0.3:
		meow()
	_pet_left = maxf(_pet_left, time)
	if by:
		_pet_face = by.global_position - global_position
		_pet_face.y = 0.0
	_start_purr()
	petted.emit(by)


func meow() -> void:
	if _meow_wait > 0.0:
		return
	_meow_wait = GameConfig.cat_meow_cooldown
	Audio.play_on(self, GameConfig.cat_meow_sound, GameConfig.cat_meow_volume_db, Audio.vary(0.05), 16.0, Vector3(0.0, 0.3, 0.15))


## Spielzeug (Filzmaus) in den Mund nehmen: Knoten hängt am Kopf-Knochen.
func give_toy(toy: Node3D) -> void:
	_toy = toy
	if skeleton == null:
		add_child(toy)
		toy.position = Vector3(0.0, 0.27, 0.3)
		return
	if _toy_holder == null:
		var attach := BoneAttachment3D.new()
		attach.bone_name = "head"
		skeleton.add_child(attach)
		_toy_holder = Node3D.new()
		attach.add_child(_toy_holder)
		# Mundstelle in der Ruhehaltung (Modell: unter der Schnauze) relativ zum Kopf-Knochen
		var bone := skeleton.find_bone("head")
		if bone >= 0:
			_toy_holder.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * Transform3D(Basis(), Vector3(0.0, 0.272, 0.292))
	if toy.get_parent():
		toy.get_parent().remove_child(toy)
	_toy_holder.add_child(toy)
	toy.visible = true
	toy.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)


func take_toy_away() -> Node3D:
	var toy := _toy
	_toy = null
	if toy and toy.get_parent():
		toy.get_parent().remove_child(toy)
	return toy


func has_toy() -> bool:
	return _toy != null


# --- Ablauf ---

func step(delta: float) -> void:
	if not active:
		return
	_meow_wait -= delta
	velocity2 = Vector2.ZERO
	if _pet_left > 0.0:
		_pet_left -= delta
		_step_petting(delta)
		if _pet_left <= 0.0:
			if not _rest_purr:
				_stop_purr()
			_resume_anim()
		return
	if _rest_on and is_instance_valid(_rest_on):
		global_position = _rest_on.global_position + _rest_offset
	elif _rest_on:
		# Sitz ist weg (Möbel weggeräumt): herunterspringen und weiter
		_rest_on = null
		var floor := global_position
		floor.y = life.floor_y(self)
		_actions.push_front({"type": "jump", "to": floor + global_basis.z * 0.35, "face": global_basis.z})
		_next()
	match get_action_type():
		"walk", "cross":
			_step_walk(delta)
		"turn":
			_turn(delta, 5.0)
			if absf(angle_difference(rotation.y, _yaw_target)) < 0.08:
				_next()
		"anim", "wait_door", "leave":
			_turn(delta, 4.0)
			_t -= delta
			if get_action_type() == "wait_door":
				if life.door_open():
					_next()
				elif _t <= 0.0:
					_t = randf_range(18.0, 35.0)
					meow()
			elif get_action_type() == "leave":
				if _t <= 0.0:
					_t = 0.5
					if not life.is_visible_point(global_position + Vector3.UP * 0.2):
						finished.emit(self)
			elif _t <= 0.0:
				_next()
		"jump":
			_step_jump(delta)
		"follow":
			_step_follow(delta)
		_:
			_next()


func _next() -> void:
	while not _actions.is_empty():
		_action = _actions.pop_front()
		if _start_action():
			return
	_action = {}
	finished.emit(self)


## Schritt beginnen; false = sofort erledigt (kleine Schritte ohne Dauer).
func _start_action() -> bool:
	var type := String(_action.get("type", ""))
	_t = float(_action.get("time", 0.0))
	if debug:
		var info := String(_action.get("anim", "")) if type == "anim" else ""
		if type in ["walk", "cross"]:
			var pts: PackedVector3Array = _action.points
			info = "%d Punkte bis %s" % [pts.size(), pts[-1].snapped(Vector3.ONE * 0.01) if not pts.is_empty() else Vector3.ZERO]
		elif type == "jump":
			info = str((_action.to as Vector3).snapped(Vector3.ONE * 0.01))
		print("[Katze %s] %s %s  (bei %s)" % [name, type, info, global_position.snapped(Vector3.ONE * 0.01)])
	match type:
		"walk", "cross":
			_index = 1
			_blocked = 0.0
			var points: PackedVector3Array = _action.points
			if points.size() < 2:
				return false
			play(&"run" if _action.get("run", false) else &"walk", 0.2, _anim_speed())
			return true
		"turn":
			_yaw_target = StreetAnimal.yaw_of(_action.face)
			play(&"idle", 0.25)
			return true
		"anim":
			if _action.has("face"):
				_yaw_target = StreetAnimal.yaw_of(_action.face)
			play(StringName(_action.anim), float(_action.get("blend", 0.35)))
			if _action.anim == "stretch":
				_t = maxf(_t, anim_length(&"stretch"))
			return true
		"wait_door":
			if life.door_open():
				return false
			_yaw_target = StreetAnimal.yaw_of(_action.face)
			play(&"sit", 0.35)
			_t = randf_range(4.0, 10.0)
			return true
		"leave":
			play(&"sit", 0.3)
			_t = 0.0
			return true
		"jump":
			_jump_from = global_position
			_t = 0.0
			_rest_on = null
			if _action.has("face"):
				_yaw_target = StreetAnimal.yaw_of(_action.face)
			play(&"jump", 0.1)
			if anim:
				anim.seek(0.0, true)
			return true
		"follow":
			_t = float(_action.get("time", 6.0))
			play(&"run", 0.2, GameConfig.cat_run_speed / RUN_ANIM_SPEED)
			return true
		"claim":
			# Platz belegen (Sitz, Fensterbank); schon besetzt → alles bis "claim_end" auslassen
			if not bool((_action.callable as Callable).call(self)):
				while not _actions.is_empty() and _actions[0].get("type") != "claim_end":
					_actions.pop_front()
			return false
		"release_seat":
			_release_seat()
			return false
		"rest_on":
			_rest_on = _action.node
			_rest_offset = global_position - _rest_on.global_position
			return false
		"rest_off":
			_rest_on = null
			return false
		"purr_on":
			_rest_purr = true
			_start_purr()
			return false
		"purr_off":
			_rest_purr = false
			_stop_purr()
			return false
		"inside":
			inside = bool(_action.value)
			set_outdoor(not inside)
			return false
		"toy_drop":
			if _toy:
				var toy := take_toy_away()
				life.add_child(toy)
				toy.global_transform = Transform3D(global_basis, global_position + global_basis.z * 0.22 + Vector3.UP * 0.018)
				_action["toy"] = toy
				_actions_toy_hold(toy)
			return false
		"toy_take":
			var held: Node3D = _action.get("toy")
			if held and is_instance_valid(held):
				give_toy(held)
			return false
		"meow":
			meow()
			return false
		"call":
			(_action.callable as Callable).call(self)
			return false
	return false


## Abgelegtes Spielzeug merkt sich der nächste "toy_take"-Schritt.
func _actions_toy_hold(toy: Node3D) -> void:
	for a in _actions:
		if a.get("type") == "toy_take":
			a["toy"] = toy
			return


func _anim_speed() -> float:
	var speed := float(_action.get("speed", GameConfig.cat_walk_speed))
	return speed / (RUN_ANIM_SPEED if _action.get("run", false) else WALK_ANIM_SPEED)


func _step_walk(delta: float) -> void:
	var points: PackedVector3Array = _action.points
	if get_action_type() == "cross" and _index == 1 and not _action.get("started", false):
		# erst loslaufen, wenn die Fahrbahn frei ist
		if not life.road_clear(global_position):
			play(&"sit", 0.3)
			return
		_action["started"] = true
		play(&"run", 0.15, _anim_speed())
	var speed := float(_action.get("speed", GameConfig.cat_walk_speed))
	var target := points[_index]
	var to := target - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() < 0.02 and absf(to.y) < 0.02:
		# schon da: nächster Punkt
		_index += 1
		if _index >= points.size():
			_next()
		return
	if flat.length() > 0.01:
		_yaw_target = StreetAnimal.yaw_of(flat)
	# versperrt? kurz warten, dann außen herum, sonst umkehren (nicht beim Überqueren: dort zügig weiter)
	if get_action_type() == "walk" and flat.length() > 0.01 and life.blocked_ahead(self, flat.normalized()):
		_blocked += delta
		play(&"idle", 0.25)
		_turn(delta, 6.0)
		if _blocked > 1.6:
			_blocked = 0.0
			life.blocked(self, flat.normalized())
		return
	if _blocked > 0.0:
		_blocked = 0.0
		play(&"run" if _action.get("run", false) else &"walk", 0.2, _anim_speed())
	var move := speed * delta
	var dist := to.length()
	var before := global_position
	if dist <= move:
		global_position = target
		_index += 1
		if _index >= points.size():
			_next()
			return
	else:
		global_position += to / dist * move
	var moved := (global_position - before) / maxf(delta, 0.0001)
	velocity2 = Vector2(moved.x, moved.z)
	_turn(delta, 7.0)


func _step_jump(delta: float) -> void:
	var length := maxf(0.3, anim_length(&"jump"))
	_t += delta
	var k := clampf(_t / length, 0.0, 1.0)
	# Absprung nach einem Viertel der Bewegung, Landung bei drei Vierteln
	var u := smoothstep(0.22, 0.78, k)
	var target: Vector3 = _action.to
	var p := _jump_from.lerp(target, u)
	p.y += sin(u * PI) * (maxf(0.0, target.y - _jump_from.y) * 0.35 + 0.12)
	global_position = p
	var flat := Vector3(target.x - _jump_from.x, 0.0, target.z - _jump_from.z)
	if not _action.has("face") and flat.length() > 0.02:
		_yaw_target = StreetAnimal.yaw_of(flat)
	_turn(delta, 8.0)
	if k >= 1.0:
		global_position = target
		_next()


func _step_follow(delta: float) -> void:
	var other: StreetCat = _action.get("cat")
	_t -= delta
	if other == null or not other.active or _t <= 0.0:
		_next()
		return
	var to := other.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var keep := float(_action.get("distance", 0.7))
	if dist > keep:
		var speed := GameConfig.cat_run_speed * clampf((dist - keep) / 0.8, 0.35, 1.15)
		global_position += to / dist * minf(speed * delta, dist - keep)
		global_position.y = other.global_position.y if other.on_ground() else global_position.y
		play(&"run" if speed > 1.0 else &"walk", 0.2, speed / (RUN_ANIM_SPEED if speed > 1.0 else WALK_ANIM_SPEED))
		velocity2 = Vector2(to.x, to.z).normalized() * speed
	else:
		play(&"sit" if other.get_action_type() == "anim" else &"idle", 0.3)
	if dist > 0.05:
		_yaw_target = StreetAnimal.yaw_of(to)
	_turn(delta, 7.0)


func _step_petting(delta: float) -> void:
	var resting := _rest_on != null or get_action_type() in ["anim", "wait_door"] and String(_action.get("anim", "")) in ["lie", "sleep"]
	if _rest_on and is_instance_valid(_rest_on):
		global_position = _rest_on.global_position + _rest_offset
	if not resting:
		if _pet_face.length() > 0.05:
			_yaw_target = StreetAnimal.yaw_of(_pet_face)
		play(&"pet", 0.3)
		_turn(delta, 5.0)


func _resume_anim() -> void:
	match get_action_type():
		"walk":
			play(&"run" if _action.get("run", false) else &"walk", 0.3, _anim_speed())
		"anim":
			play(StringName(_action.anim), 0.4)
		"wait_door", "leave", "turn":
			play(&"sit" if get_action_type() != "turn" else &"idle", 0.4)


func _turn(delta: float, rate: float) -> void:
	rotation.y = lerp_angle(rotation.y, _yaw_target, minf(1.0, delta * rate))


func _release_seat() -> void:
	if seat and is_instance_valid(seat) and seat.occupant == self:
		seat.occupant = null
	seat = null


func _start_purr() -> void:
	if _purr and is_instance_valid(_purr):
		return
	_purr = Audio.loop_at(self, "ambience/cat_purr", GameConfig.cat_purr_volume_db, 6.0)
	if _purr:
		_purr.position = Vector3(0.0, 0.2, 0.1)
		_purr.play()


func _stop_purr() -> void:
	if _purr and is_instance_valid(_purr):
		_purr.queue_free()
	_purr = null


## Für CatLife beim Verschwinden: alles freigeben.
func reset() -> void:
	_release_seat()
	_rest_on = null
	set_active(false)
