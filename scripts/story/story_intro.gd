class_name StoryIntro
extends Node
## Der Story-Anfang (Wunsch der Entwicklerin): Bei einem neuen Spiel steht man draußen vor dem Haus, das man gekauft hat. Die
## Maklerin (GameConfig.story_agent_*) begrüßt einen, geht voraus und zeigt an Stationen, was der Vorbesitzer dagelassen hat:
## Theke mit Tablet und Bücherkisten, Sessel und Deko-Regal, das Hinterzimmer, Rückgabekasten und Türschild – dann gibt sie den
## Schlüssel und geht. Texte: data/story/intro.txt (Stationen, Sätze, @blick = die Kamera schaut bei diesem Satz auf etwas).
##
## Ablauf: Die Maklerin ist eine Figur aus dem Vorrat des Straßenlebens (StreetLife.launch_scripted) mit festen Schritten:
## zur Station gehen, dort warten (Blick zur Spielfigur), bis das Gespräch dort vorbei ist. Das Gespräch beginnt von selbst,
## sobald man nah genug bei ihr ist (story_talk_distance, freie Sicht). main.gd legt den Knoten an, solange
## Tutorial.intro_done false ist; ist der Spielstand mittendrin gespeichert, beginnt die Geschichte beim nächsten Mal von vorn.

const TEXT_PATH := "res://data/story/intro.txt"
const STATIONS := ["start", "theke", "einrichtung", "hinterzimmer", "eingang"]
## Mitte des Ladens (Raumkoordinaten) – von Türen aus ein Stück dorthin treten
const ROOM_MIDDLE := Vector3(-0.2, 0.0, -0.2)
## Erst so lange nach der Ankunft reden (umdrehen, ankommen); an der ersten Station länger (Bild blendet noch auf)
const SETTLE_TIME := 0.5
const FIRST_DELAY := 2.0
## Kommt sie nicht an (versperrter Weg), beginnt das Gespräch nach so vielen Sekunden dort, wo sie gerade ist
const ARRIVE_TIMEOUT := 45.0

var _main: Node
var _life: StreetLife
var _visits: LibraryVisits
var _room: Room
var _player: Player
var _agent: Passerby
var _lines: Dictionary = {}
var _done: Array[bool] = []
var _arrived := -1
var _settle := FIRST_DELAY
var _since_done := 0.0
var _talk_index := -1
var _finished := false
var _leave_timer := 0.0


func _ready() -> void:
	_main = get_parent()
	_lines = load_lines()
	for i in STATIONS.size():
		_done.append(false)


func _exit_tree() -> void:
	Lending.hold_visitors = false


func _process(delta: float) -> void:
	if _agent == null:
		_try_setup()
		return
	if _finished:
		_leave_timer += delta
		if _leave_timer > 180.0 or not _agent.active or not _agent.scripted:
			queue_free()
		return
	if _main.get_node_or_null("TitleScreen") != null:
		return  # Hauptmenü noch offen
	var next := _done.find(false)
	if next < 0:
		return
	_since_done += delta
	if _arrived < next and _since_done > ARRIVE_TIMEOUT:
		_arrived = next
	if _arrived != next or _talk_index >= 0:
		return
	_settle -= delta
	if _settle > 0.0 or Conversation.current != null or MenuStack.has_open() or not _player_near():
		return
	_begin_talk(next)


# --- Vorbereiten ---

## Spielfigur vor die Treppe stellen, Maklerin losschicken (sobald Straßenleben und Bücherei bereit sind).
func _try_setup() -> void:
	_life = get_tree().get_first_node_in_group(StreetLife.GROUP) as StreetLife
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _life == null or _player == null or _life.library == null or not _life.library.is_ready():
		return
	_visits = _life.library
	_room = _visits.room
	var p := _visits.entrance_points()
	var out3 := StreetLayout.door_outward()
	var out := Vector2(out3.x, out3.z).normalized()
	var side := Vector2(-out.y, out.x)
	var foot: Vector2 = p.foot
	var agent_start := foot + out * 0.55 + side * 0.45
	var player_spot := foot + out * GameConfig.story_player_start_distance
	var actions: Array = [_arrive_step(0), _wait_step(0)]
	actions.append_array(_visits.enter_actions(agent_start))
	actions.append(_call(_went_inside))
	for i in range(1, STATIONS.size()):
		actions.append(_call(_go_station.bind(i)))
		actions.append(_arrive_step(i))
		actions.append(_wait_step(i))
	actions.append(_call(_goodbye_pause))
	actions.append_array(_visits.exit_house_actions())
	actions.append(_call(_went_outside))
	_agent = _life.launch_scripted(agent_start, player_spot - agent_start, actions, 0.0, GameConfig.story_agent_seed, 1,
		GameConfig.story_agent_name)
	if _agent == null:
		return  # gerade keine Figur frei – gleich noch einmal
	Lending.hold_visitors = true  # keine Gäste, solange die Maklerin da ist
	# Spielfigur draußen vor die Treppe, Blick zur Maklerin und zum Haus
	var spot := _life.to_global(Vector3(player_spot.x, 0.0, player_spot.y))
	_player.global_position = spot + Vector3.UP * 0.02
	_player.velocity = Vector3.ZERO
	var look := _life.to_global(Vector3(agent_start.x, 0.0, agent_start.y)) - spot
	_player.rotation.y = atan2(-look.x, -look.z)
	_player.head.rotation.x = deg_to_rad(4.0)


func _call(callable: Callable) -> Dictionary:
	return {"type": "call", "callable": callable}


func _arrive_step(index: int) -> Dictionary:
	return _call(_arrive.bind(index))


## An der Station warten, bis das Gespräch dort vorbei ist (Blick zur Spielfigur).
func _wait_step(index: int) -> Dictionary:
	return {"type": "wait", "anim": &"idle", "until": _station_done.bind(index), "every": _face_player}


func _arrive(_walker: Passerby, index: int) -> Array:
	if index > _arrived:
		_arrived = index
		_settle = FIRST_DELAY if index == 0 else SETTLE_TIME
	return []


func _station_done(_walker: Passerby, index: int) -> bool:
	return _done[index]


func _face_player(walker: Passerby, _delta: float) -> void:
	if _player == null:
		return
	var d := _life.to_local2(_player.global_position) - walker.pos
	if d.length() > 0.05:
		walker.get_action()["face"] = d.normalized()


func _went_inside(walker: Passerby) -> Array:
	walker.add_to_group(Door.KEEPOUT_GROUP)
	walker.in_library = true
	return []


func _went_outside(walker: Passerby) -> Array:
	walker.remove_from_group(Door.KEEPOUT_GROUP)
	walker.in_library = false
	var rest := _life.exit_actions(walker.pos)
	queue_free.call_deferred()  # ab hier geht sie allein die Straße hinunter
	return rest


func _go_station(_walker: Passerby, index: int) -> Array:
	var point: Variant = _station_point(STATIONS[index])
	if point == null:
		_done[index] = true  # gibt es hier nicht (z. B. Möbel weggeräumt) – weiter zur nächsten Station
		return []
	return _visits.go_to_actions(point as Vector3)


## Kurz stehen bleiben, dann zur Tür.
func _goodbye_pause(walker: Passerby) -> Array:
	var d := _life.to_local2(_player.global_position) - walker.pos
	return [{"type": "stand", "face": d.normalized() if d.length() > 0.05 else Vector2.ZERO, "anim": &"idle",
		"time": GameConfig.story_goodbye_wait}]


# --- Gespräche ---

func _player_near() -> bool:
	var eye := _agent.talk_focus()
	var head := _player.camera.global_position
	if head.distance_to(eye) > GameConfig.story_talk_distance:
		return false
	# freie Sicht (nicht durch eine Wand oder die geschlossene Tür hindurch)
	var query := PhysicsRayQueryParameters3D.create(head, eye, 1)
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _begin_talk(index: int) -> void:
	var steps: Array = []
	for line: Dictionary in _lines.get(STATIONS[index], []):
		var step := {"text": line.text}
		var focus: Variant = _focus_point(String(line.look))
		if focus != null:
			step.focus = focus
		steps.append(step)
	if steps.is_empty():
		_done[index] = true
		return
	var talk := Conversation.begin(_agent, _player, steps)
	if talk == null:
		return
	_talk_index = index
	talk.line_started.connect(_on_line)
	talk.ended.connect(_on_talk_ended.bind(index))


## Bei Sätzen mit Blickpunkt dreht sie sich dorthin und zeigt darauf, sonst schaut sie die Spielfigur an.
func _on_line(_index: int, step: Dictionary) -> void:
	if _agent == null:
		return
	var target: Vector3 = step.focus if step.get("focus") is Vector3 else _player.global_position
	var d := _life.to_local2(target) - _agent.pos
	if d.length() > 0.05:
		_agent.get_action()["face"] = d.normalized()
	if step.get("focus") is Vector3 and _agent._model and _agent._model.has_method("play_clip"):
		_agent._model.call("play_clip", &"point", 2.2)


func _on_talk_ended(_speaker: Node, index: int) -> void:
	_done[index] = true
	_talk_index = -1
	_since_done = 0.0
	if index == 0:
		Notice.post(self, "Folge %s" % GameConfig.story_agent_name)
	if _done.find(false) < 0:
		_finished = true
		Lending.hold_visitors = false
		Notice.post(self, "Schlüssel bekommen")
		Tutorial.finish_intro()


# --- Orte ---

## Wo die Maklerin an einer Station steht (Welt; null = Station fällt weg).
func _station_point(station: String) -> Variant:
	match station:
		"theke":
			var counter := _counter()
			if counter == null:
				return null
			return counter.global_position + counter.global_basis.z * 0.95 + counter.global_basis.x * 0.55
		"einrichtung":
			var chair := _furniture("armchair_velvet")
			var shelf := _furniture("deco_shelf_light")
			var spots: Array[Vector3] = []
			for item: Node3D in [chair, shelf]:
				if item:
					spots.append(item.global_position + item.global_basis.z * 1.0)
			if spots.is_empty():
				return null
			return spots[0] if spots.size() == 1 else spots[0].lerp(spots[1], 0.5)
		"hinterzimmer":
			if _room.find_children("*", "BackRoomDoor", true, false).is_empty():
				return null
			return _room.to_global(BackRoom.door_frame().origin + Vector3(-1.3, 0.0, 0.0))
		"eingang":
			var p := _visits.entrance_points()
			var inside: Vector2 = p.inside
			var point := _life.to_global(Vector3(inside.x, _visits.shop_floor(), inside.y))
			return point + (_room.to_global(ROOM_MIDDLE) - point).normalized() * 0.5
	return null


## Worauf die Kamera bei einem Satz schaut (null = auf die Maklerin).
func _focus_point(look: String) -> Variant:
	match look:
		"haus":
			return _room.to_global(StreetLayout.door_center() + Vector3(0.0, 2.4, 0.0))
		"theke":
			var counter := _counter()
			return counter.global_position + Vector3.UP * 0.85 if counter else null
		"tablet":
			var tablet := get_tree().get_first_node_in_group(ShopTablet.GROUP) as Node3D
			return tablet.global_position + Vector3.UP * 0.15 if tablet else null
		"kisten":
			var counter := _counter()
			return counter.global_position - counter.global_basis.z * 0.2 + Vector3.UP * 0.35 if counter else null
		"sessel":
			var chair := _furniture("armchair_velvet")
			return chair.global_position + Vector3.UP * 0.55 if chair else null
		"regal":
			var shelf := _furniture("deco_shelf_light")
			return shelf.global_position + Vector3.UP * 0.9 if shelf else null
		"hintertuer":
			return _room.to_global(BackRoom.door_frame().origin + Vector3(-0.05, 1.1, 0.0))
		"rueckgabe":
			var box := ReturnBox.find(get_tree())
			return box.global_position + Vector3.UP * 0.95 if box else null
		"schild":
			var signs := _room.find_children("*", "OpenSign", true, false)
			return (signs[0] as Node3D).global_position if not signs.is_empty() else null
	return null


func _counter() -> Node3D:
	return get_tree().get_first_node_in_group(Counter.GROUP) as Node3D


## Ein Möbelstück im Laden nach seinem Datenblatt (das erste, das dasteht).
func _furniture(id: String) -> Node3D:
	for item: PlacedFurniture in _room.find_children("*", "PlacedFurniture", true, false):
		if item.data and item.data.id == id:
			return item
	return null


# --- Texte ---

## Sätze je Station aus data/story/intro.txt: {station: [{text, look}]}.
static func load_lines() -> Dictionary:
	var lines := {}
	var file := FileAccess.open(TEXT_PATH, FileAccess.READ)
	var current := ""
	while file and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			current = line.trim_prefix("==").strip_edges()
			lines[current] = []
			continue
		if current.is_empty():
			continue
		var look := ""
		if line.begins_with("@"):
			var cut := line.find(" ")
			look = line.substr(1, cut - 1) if cut > 0 else line.substr(1)
			line = line.substr(cut + 1).strip_edges() if cut > 0 else ""
		if not line.is_empty():
			(lines[current] as Array).append({"text": line, "look": look})
	return lines
