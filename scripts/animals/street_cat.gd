class_name StreetCat
extends StreetAnimal
## Eine Katze (seit Etappe 6g, neu in 6h: weicher Körper, eigenes Skelett, Bewegungen nach echten Katzen,
## Gesicht). CatLife plant ihren Besuch als Folge von Schritten (wie bei Passanten):
## - walk (laufen; run = rennen, stalk = anschleichen), turn (umdrehen), anim (sitzen, putzen, liegen, schlafen,
##   strecken, schnuppern, lauern …; sitzen und hinlegen mit Übergang: erst hinten absetzen),
## - jump (hinauf/hinunter: Bank, Fensterbank, Sessel, Bordstein, Stufe – vorher immer zur Landestelle drehen,
##   dann mit dem Kopf voran), pounce (Sprung auf Spielzeug oder Vögel), bat (mit der Pfote anstupsen),
## - follow (Fangen), wait_road (vor dem Überqueren warten), wait_door (an der Tür warten), leave (verschwinden,
##   wenn niemand hinschaut), kleine Schritte (Platz belegen „claim“ … „claim_end“, Schnurren, drinnen/draußen,
##   Spielzeug ablegen/aufnehmen, Miau, „call“ = CatLife fragen).
## Gesicht (Formvarianten im Modell): blinzeln, „happy“ (zufrieden zugekniffen: beim Streicheln, freundlicher
## Blick zur Spielfigur), Augen zu beim Schlafen.
## Streicheln: E (Interactable „Streicheln“) oder später ein Passant: pet(wer).

signal finished(cat: StreetCat)
signal petted(by: Node3D)

## Natürliches Tempo der Bewegungen (m/s bei speed_scale 1; aus den Schrittlängen in animal_cat_anim.py)
const WALK_ANIM_SPEED := 0.3
const RUN_ANIM_SPEED := 1.13
const STALK_ANIM_SPEED := 0.14
## Wann sich die Katze bei Sprüngen bewegt (Anteil der Bewegung): [Absprung, Landung]
const JUMP_WINDOW := {"jump_up": Vector2(0.35, 0.7), "jump_down": Vector2(0.3, 0.66), "hop_up": Vector2(0.3, 0.78),
	"step_down": Vector2(0.2, 0.85), "pounce": Vector2(0.4, 0.75)}
## Mundstelle in der Ruhehaltung (unter dem Schnäuzchen; Spielzeug im Maul)
const MOUTH := Vector3(0.0, 0.166, 0.19)

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
## Haltung: "stand", "sit", "lie"
var posture := "stand"
## Jagt gerade (lauern, anschleichen, Sprung) – Vögel bemerken sie erst spät
var hunting := false

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
var _rest_purr := false
var _meow_wait := 0.0
## Schnattern beim Belauern, Begrüßen der Spielfigur, Rascheln an Pflanzen (seit Etappe 6h)
var _chatter_wait := 0.0
var _greeted := false
var _rustle_wait := 0.0
var _pet_left := 0.0
var _pet_face := Vector3.ZERO
var _toy: Node3D
var _toy_holder: Node3D
var _interactable: Interactable
var _head: AnimalHeadModifier
var _look := Vector2.ZERO
## Fell-Material dieser Katze (eigene Kopie, siehe CatLife._build_pool): malt die Augen (eye_blink, eye_happy)
var _face: ShaderMaterial
var _blink := 0.0
var _happy := 0.0
var _blink_timer := 2.0
var _friendly := 0.0


func _ready() -> void:
	super._ready()
	if skeleton:
		_head = AnimalHeadModifier.new()
		_head.name = "HeadLook"
		skeleton.add_child(_head)
	_interactable = get_node_or_null("Interactable") as Interactable
	if _interactable:
		_interactable.interacted.connect(func(who: Node) -> void: pet(who as Node3D))
	add_to_group(Door.KEEPOUT_GROUP)
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
		if anim:
			anim.stop()
		current_anim = &""
		_actions.clear()
		_action = {}
		hunting = false


func begin(start: Vector3, face: Vector3, actions: Array[Dictionary]) -> void:
	global_position = start
	rotation = Vector3(0.0, StreetAnimal.yaw_of(face), 0.0)
	_yaw_target = rotation.y
	_actions = actions
	_action = {}
	_pet_left = 0.0
	inside = false
	posture = "stand"
	set_outdoor(true)
	set_active(true)
	play(&"walk", 0.0)
	_next()


## Neue Schritte statt der restlichen (z. B. umkehren, jagen).
func replace_actions(actions: Array[Dictionary]) -> void:
	hunting = false
	_actions = actions
	_next()


## Schritte vor die restlichen schieben (z. B. hinein in die Bücherei).
func insert_actions(actions: Array[Dictionary]) -> void:
	var rest := _actions.duplicate()
	_actions = actions
	_actions.append_array(rest)
	_next()


func get_actions() -> Array[Dictionary]:
	return _actions


func get_action_type() -> String:
	return String(_action.get("type", ""))


## Steht die Katze auf dem Boden (nicht auf Bank, Fensterbank oder Sessel, nicht mitten im Sprung)?
func on_ground() -> bool:
	return active and _rest_on == null and get_action_type() not in ["jump", "pounce"]


## Wie nah Vögel diese Katze an sich heranlassen (m): beim Lauern und Anschleichen bemerken sie sie spät, beim
## Sprung fliegen sie sofort auf (die Katze fängt nie einen Vogel).
func bird_scare_radius() -> float:
	if get_action_type() == "pounce":
		return 3.5
	if hunting:
		return 1.15
	return GameConfig.bird_flee_radius + 0.5


func can_be_petted() -> bool:
	return active and get_action_type() not in ["jump", "pounce", "leave"] and not (get_action_type() == "walk" and _action.get("run", false))


## Streicheln (Spielfigur mit E, später auch Passanten): Katze hält inne, dreht sich zu by, kneift zufrieden die
## Augen zu und schnurrt; liegt sie, bleibt sie liegen und macht ein kurzes Miau.
func pet(by: Node3D, seconds: float = -1.0) -> void:
	if not can_be_petted():
		return
	var time := GameConfig.cat_pet_time if seconds < 0.0 else seconds
	if _pet_left <= 0.0 and (posture == "lie" or randf() < 0.3):
		meow()
	_pet_left = maxf(_pet_left, time)
	if by:
		_pet_face = by.global_position - global_position
		_pet_face.y = 0.0
	_start_purr()
	petted.emit(by)


func is_petted() -> bool:
	return _pet_left > 0.0


## Miauen (höchstens alle cat_meow_cooldown Sekunden): kurz, oder lang („lass mich rein“ an der Tür).
func meow(long := false) -> void:
	if _meow_wait > 0.0:
		return
	_meow_wait = GameConfig.cat_meow_cooldown
	Audio.play_on(self, GameConfig.cat_meow_long_sound if long else GameConfig.cat_meow_sound, GameConfig.cat_meow_volume_db,
		Audio.vary(0.05), 16.0, Vector3(0.0, 0.2, 0.16))


## Laute je Bild: Schnattern beim Belauern von Vögeln, Begrüßen der Spielfigur, Rascheln an Pflanzen.
func _update_voice(delta: float) -> void:
	_chatter_wait -= delta
	if hunting and _chatter_wait <= 0.0 and (current_anim == &"crouch" or current_anim == &"stalk"):
		_chatter_wait = randf_range(3.0, 7.0)
		Audio.play_on(self, GameConfig.cat_chatter_sound, GameConfig.cat_chatter_volume_db, Audio.vary(0.06), 12.0,
			Vector3(0.0, 0.18, 0.15))
	var player := life.street.get_player() if life else null
	if player:
		var dist := player.global_position.distance_to(global_position)
		if dist > GameConfig.cat_greet_distance * 1.8:
			_greeted = false
		elif not _greeted and dist < GameConfig.cat_greet_distance and not hunting and _look.length() > 5.0:
			_greeted = true
			if randf() < GameConfig.cat_greet_chance:
				meow()
	_rustle_wait -= delta
	if _rustle_wait <= 0.0 and velocity2.length() > 0.2 and on_ground():
		var greenery := get_tree().get_first_node_in_group(Greenery.GROUP) as Greenery
		if greenery and greenery.plant_near(global_position, 0.06):
			_rustle_wait = GameConfig.cat_plant_rustle_cooldown
			Audio.play_at("ambience/plant_rustle", global_position + Vector3.UP * 0.15, GameConfig.plant_rustle_volume_db - 4.0,
				Audio.vary(0.12) * 1.15)


## Spielzeug ins Maul nehmen: Knoten hängt am Kopf-Knochen unter der Schnauze.
func give_toy(toy: Node3D) -> void:
	_toy = toy
	if skeleton == null:
		add_child(toy)
		toy.position = MOUTH
		return
	if _toy_holder == null:
		var attach := BoneAttachment3D.new()
		attach.bone_name = "head"
		skeleton.add_child(attach)
		_toy_holder = Node3D.new()
		attach.add_child(_toy_holder)
		var bone := skeleton.find_bone("head")
		if bone >= 0:
			_toy_holder.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * Transform3D(Basis(), MOUTH)
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


func get_toy() -> Node3D:
	return _toy


# --- Ablauf ---

func step(delta: float) -> void:
	if not active:
		return
	_meow_wait -= delta
	_update_voice(delta)
	velocity2 = Vector2.ZERO
	_update_look(delta)
	_update_face(delta)
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
		# Sitz ist weg (Möbel weggeräumt): umdrehen, vorwärts herunterspringen und weiter
		_rest_on = null
		var floor := global_position + global_basis.z * 0.35
		floor.y = life.floor_y(self)
		_actions.push_front({"type": "jump", "to": floor})
		_actions.push_front({"type": "turn", "face": global_basis.z})
		_next()
	match get_action_type():
		"walk":
			_step_walk(delta)
		"turn":
			_turn(delta, 5.0)
			if absf(angle_difference(rotation.y, _yaw_target)) < 0.08:
				_next()
		"anim", "wait_door", "leave", "wait_road":
			_step_wait(delta)
		"jump", "pounce":
			_step_jump(delta)
		"follow":
			_step_follow(delta)
		"bat":
			_step_bat(delta)
		_:
			_next()


func _step_wait(delta: float) -> void:
	_turn(delta, 4.0)
	_t -= delta
	match get_action_type():
		"wait_door":
			if life.door_open():
				_next()
			elif _t <= 0.0:
				_t = randf_range(18.0, 35.0)
				meow()
		"wait_road":
			if life.road_clear(global_position):
				_next()
		"leave":
			if _t <= 0.0:
				_t = 0.5
				if not life.is_visible_point(global_position + Vector3.UP * 0.2):
					finished.emit(self)
		_:
			# Übergang (hinsetzen/aufstehen) vorbei? Dann die eigentliche Bewegung
			if _action.has("then") and anim and not anim.is_playing():
				play(StringName(_action.then), 0.25)
				_action.erase("then")
			if _t <= 0.0:
				_next()


func _next() -> void:
	while not _actions.is_empty():
		_action = _actions.pop_front()
		if _start_action():
			return
	_action = {}
	finished.emit(self)


## Haltung wechseln: aus dem Sitzen erst aufstehen, aus dem Liegen erst strecken – liefert true, wenn ein Übergang
## eingeschoben wurde (dann kommt die Aktion danach wieder dran).
func _need_stand() -> bool:
	if posture == "sit":
		_actions.push_front(_action)
		_action = {"type": "anim", "anim": "stand_up", "time": anim_length(&"stand_up")}
		return true
	if posture == "lie":
		_actions.push_front(_action)
		_action = {"type": "anim", "anim": "stretch", "time": anim_length(&"stretch")}
		return true
	return false


## Schritt beginnen; false = sofort erledigt (kleine Schritte ohne Dauer).
func _start_action() -> bool:
	var type := String(_action.get("type", ""))
	if type in ["walk", "jump", "pounce", "follow"] and _need_stand():
		type = "anim"
	_t = float(_action.get("time", 0.0))
	if debug:
		var info := String(_action.get("anim", "")) if type == "anim" else ""
		if type == "walk":
			var pts: PackedVector3Array = _action.points
			info = "%d Punkte bis %s" % [pts.size(), pts[-1].snapped(Vector3.ONE * 0.01) if not pts.is_empty() else Vector3.ZERO]
		elif type in ["jump", "pounce"]:
			info = str((_action.to as Vector3).snapped(Vector3.ONE * 0.01))
		print("[Katze %s] %s %s  (bei %s)" % [name, type, info, global_position.snapped(Vector3.ONE * 0.01)])
	match type:
		"walk":
			_index = 1
			_blocked = 0.0
			var points: PackedVector3Array = _action.points
			if points.size() < 2:
				return false
			hunting = bool(_action.get("stalk", false))
			play(_walk_anim(), 0.2, _anim_speed())
			return true
		"turn":
			_yaw_target = StreetAnimal.yaw_of(_action.face)
			if posture == "stand":
				play(&"idle", 0.25)
			return true
		"anim":
			return _start_anim()
		"wait_door", "wait_road":
			if type == "wait_door" and life.door_open():
				return false
			if type == "wait_door":
				meow(true)       # „lass mich rein“
			if type == "wait_road" and life.road_clear(global_position):
				return false
			_yaw_target = StreetAnimal.yaw_of(_action.get("face", global_basis.z))
			_t = randf_range(4.0, 10.0)
			if posture != "sit" and type == "wait_door":
				_action["then"] = "sit"
				play(&"sit_down", 0.2)
				posture = "sit"
			else:
				play(&"idle", 0.3)
			return true
		"leave":
			play(&"sit" if posture == "sit" else &"idle", 0.3)
			_t = 0.0
			return true
		"jump", "pounce":
			_jump_from = global_position
			_t = 0.0
			_rest_on = null
			var to: Vector3 = _action.to
			var anim_name: StringName = &"pounce" if type == "pounce" else StringName(_action.get("anim", _jump_anim(to)))
			_action["anim"] = anim_name
			var flat := Vector3(to.x - _jump_from.x, 0.0, to.z - _jump_from.z)
			if flat.length() > 0.02:
				_yaw_target = StreetAnimal.yaw_of(flat)
			hunting = type == "pounce" and bool(_action.get("hunt", false))
			play(anim_name, 0.08)
			if anim:
				anim.seek(0.0, true)
			return true
		"follow":
			_t = float(_action.get("time", 6.0))
			play(&"run", 0.2, GameConfig.cat_run_speed / RUN_ANIM_SPEED)
			return true
		"bat":
			_t = 0.0
			_action["hit"] = false
			var toy: Node3D = _action.get("toy")
			if toy and is_instance_valid(toy):
				var d := toy.global_position - global_position
				d.y = 0.0
				if d.length() > 0.02:
					_yaw_target = StreetAnimal.yaw_of(d)
			posture = "stand"
			play(&"bat", 0.15)
			if anim:
				anim.seek(0.0, true)
			return true
		"claim":
			# Platz belegen (Sitz, Fensterbank, Körbchen); schon besetzt → alles bis "claim_end" auslassen
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
				life.drop_toy(self, toy, global_position + global_basis.z * 0.22)
			return false
		"toy_take":
			var held: Node3D = _action.get("toy", life.toy_near(self))
			if held and is_instance_valid(held) and held.global_position.distance_to(global_position) < 0.7:
				life.pick_toy(self, held)
			return false
		"meow":
			meow()
			return false
		"hunting":
			hunting = bool(_action.value)
			return false
		"call":
			(_action.callable as Callable).call(self)
			return false
	return false


## Bewegung mit Haltung: Sitzen und Liegen mit Übergang (erst hinten absetzen), danach die Schleife.
func _start_anim() -> bool:
	var want := StringName(_action.anim)
	if _action.has("face"):
		_yaw_target = StreetAnimal.yaw_of(_action.face)
	var blend := float(_action.get("blend", 0.3))
	if want in [&"sit", &"groom"] and posture == "stand":
		_action["then"] = String(want)
		play(&"sit_down", 0.2)
		if anim:
			anim.seek(0.0, true)
		posture = "sit"
		_t = maxf(_t, anim_length(&"sit_down"))
		return true
	if want in [&"lie", &"sleep"]:
		if posture == "stand":
			_action["then"] = String(want)
			play(&"sit_down", 0.2)
			if anim:
				anim.seek(0.0, true)
			_t = maxf(_t, anim_length(&"sit_down"))
		else:
			play(want, 0.8)
		posture = "lie"
		return true
	if want == &"sit":
		posture = "sit"
	elif want != &"groom":
		posture = "stand"
	if want in [&"stand_up", &"stretch"]:
		_t = maxf(_t, anim_length(want))
	if want == &"crouch":
		hunting = bool(_action.get("hunt", false))
	play(want, blend)
	if want in StreetAnimal.ONCE and anim:
		anim.seek(0.0, true)
	return true


func _walk_anim() -> StringName:
	if _action.get("stalk", false):
		return &"stalk"
	return &"run" if _action.get("run", false) else &"walk"


func _anim_speed() -> float:
	var speed := float(_action.get("speed", GameConfig.cat_walk_speed))
	if _action.get("stalk", false):
		return speed / STALK_ANIM_SPEED
	return speed / (RUN_ANIM_SPEED if _action.get("run", false) else WALK_ANIM_SPEED)


## Welche Sprung-Bewegung: nach oben hoch springen bzw. hüpfen, nach unten herunterspringen bzw. absteigen.
func _jump_anim(to: Vector3) -> StringName:
	var dy := to.y - global_position.y
	if dy > 0.2:
		return &"jump_up"
	if dy > 0.03:
		return &"hop_up"
	if dy < -0.2:
		return &"jump_down"
	if dy < -0.03:
		return &"step_down"
	return &"hop_up"


func _step_walk(delta: float) -> void:
	var points: PackedVector3Array = _action.points
	var speed := float(_action.get("speed", GameConfig.cat_walk_speed))
	var target := points[_index]
	var to := target - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() < 0.02 and absf(to.y) < 0.02:
		_index += 1
		if _index >= points.size():
			_next()
		return
	if flat.length() > 0.01:
		_yaw_target = StreetAnimal.yaw_of(flat)
	# versperrt? kurz warten, dann außen herum, sonst umkehren (auf der Fahrbahn zügig weiter)
	if flat.length() > 0.01 and not _action.get("road", false) and life.blocked_ahead(self, flat.normalized()):
		_blocked += delta
		play(&"idle", 0.25)
		_turn(delta, 6.0)
		if _blocked > 1.6:
			_blocked = 0.0
			life.blocked(self, flat.normalized())
		return
	if _blocked > 0.0:
		_blocked = 0.0
		play(_walk_anim(), 0.2, _anim_speed())
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


## Sprung: bis zum Absprung bleibt die Katze am Platz (ansetzen), dann in einem Bogen zur Landestelle, danach
## federt sie ab. Die Blickrichtung steht vorher fest (zur Landestelle) – nie rückwärts springen.
func _step_jump(delta: float) -> void:
	var anim_name := StringName(_action.get("anim", "jump_up"))
	var length := maxf(0.3, anim_length(anim_name))
	var window: Vector2 = JUMP_WINDOW.get(String(anim_name), Vector2(0.3, 0.7))
	_t += delta
	var k := clampf(_t / length, 0.0, 1.0)
	var u := clampf((k - window.x) / (window.y - window.x), 0.0, 1.0)
	if anim_name in [&"step_down", &"hop_up"]:
		u = u * u * (3.0 - 2.0 * u)
	var target: Vector3 = _action.to
	var p := _jump_from.lerp(target, u)
	var height := maxf(0.0, target.y - _jump_from.y)
	p.y += sin(u * PI) * (height * 0.3 + (0.04 if anim_name in [&"hop_up", &"step_down"] else 0.1))
	global_position = p
	_turn(delta, 9.0)
	if k >= 1.0:
		global_position = target
		hunting = false
		posture = "stand"
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
		play(&"crouch" if other.get_action_type() in ["anim", "bat"] else &"idle", 0.3)
	if dist > 0.05:
		_yaw_target = StreetAnimal.yaw_of(to)
	_turn(delta, 7.0)


## Mit der Pfote anstupsen: beim Treffer rollt/rutscht das Spielzeug ein Stück weg.
func _step_bat(delta: float) -> void:
	_t += delta
	_turn(delta, 8.0)
	if not _action.hit and _t > anim_length(&"bat") * 0.35:
		_action.hit = true
		var toy: Node3D = _action.get("toy")
		if toy and is_instance_valid(toy):
			life.push_toy(toy, global_basis.z, float(_action.get("strength", 0.6)))
	if _t >= anim_length(&"bat"):
		_next()


func _step_petting(delta: float) -> void:
	var lying := posture == "lie" or _rest_on != null
	if _rest_on and is_instance_valid(_rest_on):
		global_position = _rest_on.global_position + _rest_offset
	if not lying and posture != "sit":
		if _pet_face.length() > 0.05:
			_yaw_target = StreetAnimal.yaw_of(_pet_face)
		play(&"pet", 0.3)
		_turn(delta, 5.0)


func _resume_anim() -> void:
	match get_action_type():
		"walk":
			play(_walk_anim(), 0.3, _anim_speed())
		"anim":
			play(StringName(_action.get("then", _action.anim)), 0.4)
		"wait_door", "leave", "wait_road":
			play(&"sit" if posture == "sit" else &"idle", 0.4)
		"turn":
			play(&"idle", 0.4)


func _turn(delta: float, rate: float) -> void:
	rotation.y = lerp_angle(rotation.y, _yaw_target, minf(1.0, delta * rate))


# --- Gesicht und Kopf ---

## Augen: ab und zu blinzeln; zufrieden zugekniffen beim Streicheln und als freundlicher Blick zur Spielfigur
## (langsames Blinzeln – so zeigen Katzen Vertrauen); zu beim Schlafen.
func _update_face(delta: float) -> void:
	var now_anim := String(_action.get("then", _action.get("anim", ""))) if get_action_type() == "anim" else ""
	var want_blink := 0.0
	var want_happy := 0.0
	if _pet_left > 0.0:
		want_happy = 1.0
	elif now_anim == "sleep":
		want_blink = 1.0
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = randf_range(2.5, 6.5)
		if _blink_timer < 0.14:
			want_blink = 1.0
		_friendly -= delta
		if _friendly > 0.0 and _friendly < 1.4:
			# ganz zu (zufriedene Bögen): halb geschlossen wurden die Augen zu dunklen Flecken
			want_happy = 1.0
		elif _friendly < -6.0 and _look.length() > 5.0 and randf() < delta * 0.25:
			_friendly = 2.0   # langsames Blinzeln zur Spielfigur
	_blink = move_toward(_blink, want_blink, delta * (12.0 if want_blink > _blink else 6.0))
	_happy = move_toward(_happy, want_happy, delta * 4.0)
	if _face == null and mesh and mesh.mesh:
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_surface_override_material(i) as ShaderMaterial
			if mat and mat.resource_name == "Katze Fell":
				_face = mat
	if _face:
		_face.set_shader_parameter(&"eye_blink", _blink * (1.0 - _happy))
		_face.set_shader_parameter(&"eye_happy", _happy)


## Kopf: beim Blick ins Schaufenster nach oben, sonst im Sitzen/Stehen zur Spielfigur, wenn sie nah ist.
func _update_look(delta: float) -> void:
	if _head == null:
		return
	var want := Vector2.ZERO
	var anim_name := String(_action.get("anim", "")) if get_action_type() == "anim" else ""
	if bool(_action.get("look_up", false)):
		want = Vector2(0.0, 26.0)
	elif _pet_left > 0.0 or get_action_type() in ["wait_door", "turn", "leave"] or anim_name in ["sit", "idle"]:
		var player := life.street.get_player() if life else null
		if player and player.global_position.distance_to(global_position) < 3.2:
			var eye := player.global_position + Vector3.UP * 1.5
			var local := global_transform.affine_inverse() * eye
			var head_y := 0.3 * scale.y
			var flat := Vector2(local.x, local.z)
			var yaw := rad_to_deg(atan2(local.x, local.z))
			want.x = clampf(yaw, -65.0, 65.0)
			want.y = clampf(rad_to_deg(atan2(local.y - head_y, flat.length())), -10.0, 30.0)
			if absf(yaw) > 110.0:
				want = Vector2.ZERO
	_look = _look.lerp(want, minf(1.0, delta * 3.0))
	_head.yaw = _look.x
	_head.pitch = _look.y


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
