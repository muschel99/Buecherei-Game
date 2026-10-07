class_name KeyHints
extends HBoxContainer
## Die Hinweise unter der Bildmitte: kleine Tastensymbole, höchstens mit einem kurzen Wort
## daneben (z. B. [E] Öffnen, [Maus rechts] Nehmen). Keine Sätze – ausführliche Erklärungen
## stehen in der Tastenhilfe im Pausenmenü. Das HUD nutzt zwei davon: unter der Bildmitte
## (was das angeschaute Objekt kann) und unten neben dem Bücherstapel (Tragehinweise).
##
## show_hints(liste): Jeder Eintrag ist ein Dictionary { "input": …, "word": … }.
##   "input": "interact" (E tippen), "interact_hold" (E halten, mit Ring),
##            "take" (Buch nehmen, Maustaste der Aktion "book_take"),
##            "place" (Buch ablegen, Maustaste der Aktion "book_place"),
##            "place_all" (Ablegen-Taste halten, mit Ring), "store_hold" (Q halten, mit Ring),
##            "menu" (Menü öffnen, Taste der Aktion "open_menu", R),
##            "rotate" (Buch drehen, Mausrad der Aktion "book_rotate"),
##            "cycle" (durch die Bücher in der Hand blättern, E)
## Wie viel zu sehen ist, stellt der Spieler im Pausenmenü unter Einstellungen → "Hinweise"
## ein (Aus, Nur Symbole, Symbol mit Wort; siehe Settings).

const WORD_COLOR := Color(1.0, 0.96, 0.88, 0.95)
const FADE_TIME := 0.15

## Kleinere Schrift und enger (für die Tragehinweise am unteren Rand).
var compact: bool = false

var _shown: Array = []
var _mode_shown := -1
var _icons: Dictionary = {}  # input -> KeyHintIcon
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)
	modulate.a = 0.0


## Zeigt diese Hinweise (eine leere Liste blendet sie aus). Liefert true, wenn sich etwas
## geändert hat.
func show_hints(hints: Array) -> bool:
	var mode := int(Settings.get_value("interface/hints"))
	var wanted: Array = [] if mode == Settings.HINTS_OFF else hints
	if wanted == _shown and mode == _mode_shown:
		return false
	_mode_shown = mode
	_shown = wanted.duplicate(true)
	if _shown.is_empty():
		_fade(0.0)  # die alten Symbole blenden sanft aus
		return true
	_rebuild(mode == Settings.HINTS_WORDS)
	_fade(1.0)
	return true


## Sind gerade Symbole zu sehen?
func is_showing() -> bool:
	return not _shown.is_empty()


## Fortschritt beim Gedrückthalten (Ring um das Symbol). Liefert false, wenn das Symbol gerade
## nicht zu sehen ist (dann zeigt das HUD den Ring um die Bildmitte).
func set_hold_progress(input: String, progress: float) -> bool:
	var icon: KeyHintIcon = _icons.get(input)
	if progress < 0.0:
		for other: KeyHintIcon in _icons.values():
			other.progress = -1.0
	if icon == null or _shown.is_empty():
		return false
	icon.progress = progress
	return true


func _rebuild(with_words: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_icons.clear()
	for hint: Dictionary in _shown:
		var input: String = hint.get("input", "interact")
		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 2 if compact else 4)
		var icon := KeyHintIcon.new()
		match input:
			"take":
				_setup_icon(icon, "book_take", false)
			"place":
				_setup_icon(icon, "book_place", false)
			"place_all":
				_setup_icon(icon, "book_place", true)
			"store_hold":
				_setup_icon(icon, "store_books", true)
			"menu":
				_setup_icon(icon, "open_menu", false)
			"rotate":
				_setup_icon(icon, "book_rotate", false)
			"cycle":
				_setup_icon(icon, "interact", false)
			_:
				_setup_icon(icon, "interact", input == "interact_hold")
		item.add_child(icon)
		_icons[input] = icon
		var word: String = hint.get("word", "")
		if with_words and not word.is_empty():
			var label := Label.new()
			label.text = word
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 14 if compact else 16)
			label.add_theme_color_override("font_color", WORD_COLOR)
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			label.add_theme_constant_override("shadow_outline_size", 4)
			item.add_child(label)
		add_child(item)


func _fade(alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", alpha, FADE_TIME)


## Symbol passend zur Taste einer Aktion: Maus links/rechts, Mausrad oder eine Taste mit
## Buchstaben.
## So stimmen die Symbole auch, wenn die Tasten später anders belegt werden.
static func _setup_icon(icon: KeyHintIcon, action: StringName, hold: bool) -> void:
	icon.is_hold = hold
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					icon.kind = KeyHintIcon.Kind.MOUSE_RIGHT
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					icon.kind = KeyHintIcon.Kind.MOUSE_WHEEL
				_:
					icon.kind = KeyHintIcon.Kind.MOUSE_LEFT
			return
	icon.kind = KeyHintIcon.Kind.KEY
	icon.key_text = _key_name(action)


## Tastenname einer Aktion (z. B. "E"), damit das Symbol auch nach einer Tastenänderung stimmt.
static func _key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)) \
				if event.physical_keycode != 0 else event.as_text_keycode()
	return "?"
