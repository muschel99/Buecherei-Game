extends Node3D
## Bett im Hinterzimmer (seit Etappe 7): E = schlafen. Erlaubt von GameConfig.sleep_from_hour bis sleep_until_hour (über
## Mitternacht) und nur, wenn kein Besucher mehr im Laden ist. Dann wird das Bild langsam dunkel, die Uhr springt auf
## GameConfig.clock_morning_hour (GameClock.sleep_until – der Notizzettel des Vortags erscheint), und es wird wieder hell.
## Tagsüber steht neben E „Nicht müde“ (und es passiert nichts).

## Gruppe der Besucher in der Bücherei (Etappe 7, Teil 4): solange jemand darin ist, schläft man nicht.
const VISITOR_GROUP := &"library_visitors"

@onready var _interactable: Interactable = $Interactable

var _sleeping := false


func _process(_delta: float) -> void:
	if _interactable == null:
		return
	if _sleeping:
		_interactable.prompt_text = ""
	elif not can_sleep():
		_interactable.prompt_text = "Nicht müde" if not _sleep_time() else "Besucher da"
	else:
		_interactable.prompt_text = "Schlafen"


func _sleep_time() -> bool:
	return GameClock.is_between(GameConfig.sleep_from_hour, GameConfig.sleep_until_hour)


func can_sleep() -> bool:
	return _sleep_time() and get_tree().get_nodes_in_group(VISITOR_GROUP).is_empty()


func _on_interactable_interacted(_interactor: Node) -> void:
	if _sleeping or not can_sleep():
		return
	_sleeping = true
	var player := get_tree().root.find_child("Player", true, false)
	if player and "movement_enabled" in player:
		player.movement_enabled = false
	# Abdunkeln, schlafen (Uhr springt), wieder aufhellen
	var layer := CanvasLayer.new()
	layer.layer = 20
	var black := ColorRect.new()
	black.color = Color(0.03, 0.03, 0.06, 0.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	get_tree().root.add_child(layer)
	Audio.play("furniture/sit_down", -8.0)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, GameConfig.sleep_fade_time)
	tween.tween_interval(0.6)
	tween.tween_callback(func() -> void: GameClock.sleep_until(GameConfig.clock_morning_hour))
	tween.tween_interval(0.4)
	tween.tween_property(black, "color:a", 0.0, GameConfig.sleep_fade_time * 1.4)
	tween.tween_callback(func() -> void:
		layer.queue_free()
		_sleeping = false
		if player and "movement_enabled" in player:
			player.movement_enabled = true)
