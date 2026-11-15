class_name Conversation
extends CanvasLayer
## Ein Gespräch mit einem Passanten oder Gast (seit Etappe 8, Wünsche der Entwicklerin): E „Reden“ an einer Figur. Sie bleibt
## stehen und schaut dich an, deine Kamera hält den Blick auf ihr (nicht wegschauen, nicht weggehen). Unten im Bild erscheint
## eine weiche Sprechblase; die Schrift tippt sich Buchstabe für Buchstabe hinein, dazu sanftes Tastaturklackern (ui/type).
## Klick oder E: ganzer Satz sofort bzw. weiter. Ab und zu eine Frage mit zwei, drei Antworten zum Anklicken (keine ist
## falsch). Esc hat im Gespräch keine Funktion; es endet, wenn alles gesagt ist. Sätze: data/talk/talk.txt (TalkLines).
##
## Conversation.begin(figur, spielfigur[, schritte]) – schritte = [{"text": …}, {"text": Frage, "answers": [{text, reply}]}]
## (leer = Gruß, Plaudern, ab und zu eine Frage, Abschied). Die Figur braucht start_talk(spielfigur), end_talk(),
## talk_name() und talk_focus() (Punkt, auf den die Kamera schaut).

signal ended(speaker: Node)

const PAPER := Color(0.99, 0.96, 0.9)
const INK := Color(0.33, 0.23, 0.19)
const INK_SOFT := Color(0.5, 0.39, 0.32)
const ROSE := Color(0.96, 0.72, 0.74)
const ACCENT := Color(0.84, 0.47, 0.47)
const TITLE := preload("res://assets/ui/fonts/Caveat-Bold.woff2")
## Getippte Schrift in der Sprechblase (seit dem Nachtest von Etappe 8: rund und gut lesbar – passt zum Tippgeräusch)
const TYPED := preload("res://assets/ui/fonts/Nunito-SemiBold.woff2")
const TYPED_BOLD := preload("res://assets/ui/fonts/Nunito-Bold.woff2")

static var current: Conversation

var speaker: Node
var player: Node3D
var _steps: Array = []
var _index := -1
var _shown := 0.0
var _typing := false
var _bubble: Bubble
var _label: Label
var _answers: HBoxContainer
var _waiting_answer := false
var _ending := false
var _rng := RandomNumberGenerator.new()


## Gespräch beginnen (null, wenn die Figur gerade nicht reden kann oder schon ein Gespräch läuft).
static func begin(who: Node, player_node: Node3D, steps: Array = []) -> Conversation:
	if current and is_instance_valid(current):
		return null
	if not who.call("start_talk", player_node):
		return null
	var talk := Conversation.new()
	talk.speaker = who
	talk.player = player_node
	talk._steps = steps
	player_node.get_tree().root.add_child(talk)
	current = talk
	return talk


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if _steps.is_empty():
		_steps = default_steps(_rng, speaker.has_method("talk_close") and bool(speaker.call("talk_close")))
	MenuStack.open(self)
	if player:
		player.set("movement_enabled", false)
		player.set("interaction_enabled", false)
		player.set("look_locked", true)
	_build()
	_bubble.modulate.a = 0.0
	create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.25)
	_next()


## Das übliche Gespräch: Gruß, ein bis zwei Sätze zum Plaudern, ab und zu eine Frage, Abschied.
static func default_steps(rng: RandomNumberGenerator, close: bool = false) -> Array:
	var hour := GameClock.minute_of_day() / 60.0
	var steps: Array = []
	for section: String in ["gruss", "plaudern"]:
		var entry := TalkLines.pick(section, hour, rng)
		if not entry.is_empty():
			steps.append({"text": entry.text})
	if close:
		# Stammgäste, mit denen man befreundet ist, erzählen Persönlicheres (Abschnitt „vertraut“)
		var personal := TalkLines.pick("vertraut", hour, rng)
		if not personal.is_empty():
			steps.append({"text": personal.text})
	elif rng.randf() < GameConfig.talk_second_line_chance:
		var more := TalkLines.pick("plaudern", hour, rng)
		if not more.is_empty() and steps.all(func(s: Dictionary) -> bool: return s.text != more.text):
			steps.append({"text": more.text})
	if rng.randf() < GameConfig.talk_question_chance:
		var question := TalkLines.pick("frage", hour, rng)
		if not question.is_empty() and not (question.answers as Array).is_empty():
			steps.append({"text": question.text, "answers": question.answers})
	var bye := TalkLines.pick("tschuess", hour, rng)
	if not bye.is_empty():
		steps.append({"text": bye.text})
	return steps


func _exit_tree() -> void:
	MenuStack.close(self)
	if current == self:
		current = null


func close_from_escape() -> void:
	pass  # im Gespräch hat Esc keine Funktion (Wunsch der Entwicklerin)


func restore_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _waiting_answer else Input.MOUSE_MODE_CAPTURED


# --- Ablauf ---

func _next() -> void:
	_index += 1
	_clear_answers()
	if _index >= _steps.size():
		_end()
		return
	_say(String((_steps[_index] as Dictionary).text))


func _say(text: String) -> void:
	_label.text = text
	_label.visible_characters = 0
	_shown = 0.0
	_typing = true
	_bubble.done = false
	if speaker and speaker.has_method("set_talking_now"):
		speaker.call("set_talking_now", true)


func _process(delta: float) -> void:
	_focus(delta)
	if not _typing:
		return
	var before := _label.visible_characters
	_shown += delta * GameConfig.talk_chars_per_second
	var now := mini(int(_shown), _label.text.length())
	if now != before:
		_label.visible_characters = now
		for i in range(before, now):
			if i % maxi(1, GameConfig.talk_clack_every) == 0 and _label.text[i] != " ":
				Audio.play("ui/type", GameConfig.talk_clack_db, _rng.randf_range(0.9, 1.1))
	if now >= _label.text.length():
		_finish_line()


func _finish_line() -> void:
	_typing = false
	_label.visible_characters = -1
	_bubble.done = true
	if speaker and speaker.has_method("set_talking_now"):
		speaker.call("set_talking_now", false)
	var step: Dictionary = _steps[_index]
	if step.has("answers"):
		_show_answers(step.answers)


func _unhandled_input(event: InputEvent) -> void:
	if _ending:
		return
	var advance: bool = event.is_action_pressed("interact") or \
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _waiting_answer:
		return
	if _typing:
		_shown = _label.text.length()
		_label.visible_characters = -1
		_finish_line()
	else:
		_next()


func _show_answers(answers: Array) -> void:
	_waiting_answer = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for answer: Dictionary in answers:
		var button := Button.new()
		button.text = String(answer.text)
		button.add_theme_font_override("font", TYPED_BOLD)
		button.add_theme_font_size_override("font_size", 25)
		for state in ["font_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, INK)
		button.add_theme_color_override("font_hover_color", ACCENT.darkened(0.15))
		for style: String in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = PAPER if style == "normal" else Color(1.0, 0.93, 0.92)
			box.border_color = Color(INK_SOFT, 0.45) if style == "normal" else ACCENT
			box.set_border_width_all(2)
			box.set_corner_radius_all(20)
			box.anti_aliasing = true
			box.shadow_color = Color(0.3, 0.2, 0.1, 0.15)
			box.shadow_size = 4
			box.shadow_offset = Vector2(0, 3)
			box.content_margin_left = 22
			box.content_margin_right = 22
			box.content_margin_top = 4
			box.content_margin_bottom = 6
			button.add_theme_stylebox_override(style, box)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: _choose(answer))
		_answers.add_child(button)
		button.modulate.a = 0.0
		create_tween().tween_property(button, "modulate:a", 1.0, 0.2)


func _choose(answer: Dictionary) -> void:
	_waiting_answer = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.play("ui/tab", -10.0, Audio.vary(0.05))
	_clear_answers()
	var reply := String(answer.get("reply", ""))
	if not reply.is_empty():
		_steps.insert(_index + 1, {"text": reply})
	if answer.has("then"):
		(answer.then as Callable).call()
	_next()


func _clear_answers() -> void:
	for child in _answers.get_children():
		child.queue_free()


func _end() -> void:
	_ending = true
	var tween := create_tween()
	tween.tween_property(_bubble, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		MenuStack.close(self)
		if speaker and is_instance_valid(speaker):
			speaker.call("end_talk")
		if player and is_instance_valid(player):
			player.set("movement_enabled", true)
			player.set("interaction_enabled", true)
			player.set("look_locked", false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		MenuStack.restore_mouse_mode()
		ended.emit(speaker)
		current = null
		queue_free())


## Kamera hält den Blick auf der Figur (weich nachgeführt).
func _focus(delta: float) -> void:
	if player == null or not is_instance_valid(player) or speaker == null or not is_instance_valid(speaker):
		return
	var head := player.get("head") as Node3D
	if head == null:
		return
	var target: Vector3 = speaker.call("talk_focus")
	var from := head.global_position
	var d := target - from
	var flat := Vector2(d.x, d.z)
	if flat.length() < 0.05:
		return
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, flat.length())
	var k := 1.0 - exp(-GameConfig.talk_focus_speed * delta)
	player.rotation.y = lerp_angle(player.rotation.y, yaw, k)
	head.rotation.x = lerp_angle(head.rotation.x, pitch, k)


# --- Aussehen ---

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_bubble = Bubble.new()
	_bubble.speaker_name = String(speaker.call("talk_name")) if speaker else ""
	_bubble.anchor_left = 0.5
	_bubble.anchor_right = 0.5
	_bubble.anchor_top = 1.0
	_bubble.anchor_bottom = 1.0
	_bubble.offset_left = -440
	_bubble.offset_right = 440
	_bubble.offset_top = -250
	_bubble.offset_bottom = -40
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bubble)
	_label = Label.new()
	_label.add_theme_font_override("font", TYPED)
	_label.add_theme_font_size_override("font_size", 27)
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_constant_override("line_spacing", 2)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 44
	_label.offset_right = -44
	_label.offset_top = 46 if not _bubble.speaker_name.is_empty() else 34
	_label.offset_bottom = -30
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_label)
	_answers = HBoxContainer.new()
	_answers.alignment = BoxContainer.ALIGNMENT_CENTER
	_answers.add_theme_constant_override("separation", 18)
	_answers.anchor_left = 0.5
	_answers.anchor_right = 0.5
	_answers.anchor_top = 1.0
	_answers.anchor_bottom = 1.0
	_answers.offset_left = -440
	_answers.offset_right = 440
	_answers.offset_top = -320
	_answers.offset_bottom = -262
	root.add_child(_answers)


## Die Sprechblase: weiches, leicht unregelmäßiges Papier mit Schatten, Spitze nach oben zur Figur, Name auf einem rosa
## Zettel, am Satzende hüpft ein kleines Herz (weiter mit Klick oder E).
class Bubble extends Control:
	var speaker_name := ""
	var done := false:
		set(value):
			done = value
			queue_redraw()
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if done:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(0, 14), size - Vector2(0, 14))
		var shape := SoftShapes.rounded_all(r, 34.0, 1.6, 7)
		SoftShapes.shadow(self, shape, Vector2(4, 8), Color(0.2, 0.12, 0.06, 0.07), 4, 3.0)
		# Spitze nach oben (zur Figur in der Bildmitte)
		var tip := PackedVector2Array([Vector2(size.x * 0.5 - 26, 18), Vector2(size.x * 0.5 + 6, -14), Vector2(size.x * 0.5 + 24, 18)])
		draw_colored_polygon(tip, PAPER)
		draw_colored_polygon(shape, PAPER)
		draw_polyline(SoftShapes.closed(shape), Color(INK_SOFT, 0.3), 2.0, true)
		if not speaker_name.is_empty():
			var tw := TITLE.get_string_size(speaker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			var tag := SoftShapes.rounded_all(Rect2(Vector2(30, 0), Vector2(tw + 36, 40)), 12.0, 0.8, 3)
			draw_colored_polygon(tag, ROSE)
			draw_string(TITLE, Vector2(48, 30), speaker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
		if done:
			var bob := sin(_t * 4.0) * 3.0
			SoftShapes.heart(self, Vector2(size.x - 44, size.y - 30 + bob), 9.0, ACCENT)
