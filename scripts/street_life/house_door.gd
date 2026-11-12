class_name HouseDoor
extends Node3D
## Eine Tür an einem Haus oder Laden der Straße (seit Etappe 6i). Das Modell (Blender) enthält das Türblatt als eigene
## Knoten „DoorLeaf …“ und den Punkt „DoorHinge_0“ (Scharnier; Extras: swing, width, height, dir_x/dir_y = zum Griff,
## out_x/out_y = nach außen, in Blender-Koordinaten). Dieser Knoten sitzt am Scharnier und dreht das Türblatt.
## Wer hindurchgeht, meldet sich an (request) und ab (release); ist niemand mehr dort, schließt sie sich wieder.
## Bewegt wird die Tür in StreetHomes.step – eine ruhende Tür kostet nichts.

const GROUP := "house_doors"

## Maße des Blatts (Meter), Drehsinn, Richtung zum Griff und nach außen (Welt)
var width := 1.0
var height := 2.2
var swing := 1.0
var latch_dir := Vector3.RIGHT
var out_dir := Vector3.BACK
## Ladentür: klingelt beim Öffnen
var has_bell := false

var _users: Array[Object] = []
## 0 = zu, 1 = offen
var _open := 0.0
var _hold := 0.0
var _moving := false


## Macht aus dem Punkt „DoorHinge_…“ eines Modells eine Tür: nimmt die Knoten leaf_prefix… desselben Modells mit
## („DoorLeaf …“, bei der Gartenpforte „GateLeaf …“).
static func attach(hinge: Node3D, leaf_prefix: String = "DoorLeaf") -> HouseDoor:
	var extras: Dictionary = hinge.get_meta("extras", {})
	var door := HouseDoor.new()
	door.name = "Door" + String(hinge.name).trim_prefix("DoorHinge")
	door.width = float(extras.get("width", 1.0))
	door.height = float(extras.get("height", 2.2))
	door.swing = float(extras.get("swing", 1.0))
	var parent := hinge.get_parent() as Node3D
	var transform_there := hinge.transform
	parent.add_child(door)
	door.transform = transform_there
	# Blender (x, y) → Godot (x, -z), im Raum des Modells
	door.latch_dir = (parent.global_basis * Vector3(float(extras.get("dir_x", 1.0)), 0.0, -float(extras.get("dir_y", 0.0)))).normalized()
	door.out_dir = (parent.global_basis * Vector3(float(extras.get("out_x", 0.0)), 0.0, -float(extras.get("out_y", -1.0)))).normalized()
	for node in parent.get_children():
		if node is MeshInstance3D and String(node.name).begins_with(leaf_prefix):
			(node as Node3D).reparent(door, true)
	door.add_to_group(GROUP)
	return door


## Mitte der Türöffnung (Welt, auf der Ebene des Türblatts).
func center() -> Vector3:
	return global_position + latch_dir * width / 2.0


func request(who: Object) -> void:
	if not _users.has(who):
		_users.append(who)


## Geht gerade jemand anderes durch die Tür? (Dann wartet man daneben, statt sich im Türrahmen zu begegnen.)
func busy_for(who: Object) -> bool:
	for user: Object in _users:
		if user != who and is_instance_valid(user):
			return true
	return false


func release(who: Object) -> void:
	_users.erase(who)
	_hold = GameConfig.house_door_hold_time


func is_closed() -> bool:
	return _open <= 0.001


func is_open() -> bool:
	return _open >= 0.92


func is_in_use() -> bool:
	return not _users.is_empty() or _open > 0.001


func step(delta: float) -> void:
	var wants_open := not _users.is_empty()
	_hold = maxf(0.0, _hold - delta)
	var target := 1.0 if wants_open or _hold > 0.0 else 0.0
	if is_equal_approx(_open, target):
		if _moving:
			_moving = false
			if target <= 0.0:
				Audio.play_at("doors/door_close", global_position, GameConfig.house_door_volume_db, Audio.vary(0.06))
		return
	if not _moving and target > 0.0:
		Audio.play_at("doors/door_open", global_position, GameConfig.house_door_volume_db, Audio.vary(0.06))
		if has_bell:
			Audio.play_at("doors/shop_bell", global_position, GameConfig.house_door_bell_volume_db, Audio.vary(0.04))
	_moving = true
	_open = move_toward(_open, target, delta / GameConfig.house_door_swing_time)
	# weich anfahren und abbremsen
	rotation.y = swing * deg_to_rad(GameConfig.house_door_open_angle) * smoothstep(0.0, 1.0, _open)
