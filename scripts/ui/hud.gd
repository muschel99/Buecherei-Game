extends CanvasLayer
## Anzeige über dem Spielbild: Punkt in der Bildmitte, Tastensymbole darunter und Kontostand.
##
## Bekommt von der Spielfigur über das Signal "interaction_target_changed"
## mitgeteilt, welches interaktive Objekt gerade anvisiert wird. Statt Sätzen erscheinen
## darunter nur kleine Tastensymbole mit höchstens einem Wort (KeyHints), z. B. [E] Öffnen.
## Halte-Aktionen (E halten, Q halten) zeigen einen Ring um ihr Symbol.

const FADE_TIME := 0.15
const CROSSHAIR_IDLE_ALPHA := 0.45
const CROSSHAIR_ACTIVE_SCALE := 1.6

## Platzhalter-Symbole für den Gestaltungsmodus (im Inspektor austauschbar).
@export var paint_roller_icon: Texture2D
@export var carpet_icon: Texture2D
@export var ceiling_icon: Texture2D

@onready var _crosshair: Panel = $Crosshair
@onready var _cursor_icon: TextureRect = $CursorIcon
@onready var _money_label: Label = %MoneyLabel
@onready var _money_change_label: Label = %MoneyChangeLabel

var _target: Interactable = null
var _hold_ring: HoldRing
var _key_hints: KeyHints
var _seated := false
var _storing := false  # Q wird gerade gehalten (alle Bücher ins Lager)
var _tween: Tween
var _money_tween: Tween


func _ready() -> void:
	_crosshair.modulate.a = CROSSHAIR_IDLE_ALPHA
	_money_change_label.modulate.a = 0.0
	_money_label.text = Wallet.format(Wallet.money)
	Wallet.money_changed.connect(_on_money_changed)
	# Ring um die Bildmitte beim Gedrückthalten von E
	_hold_ring = HoldRing.new()
	_hold_ring.set_anchors_preset(Control.PRESET_CENTER)
	_hold_ring.size = Vector2(40, 40)
	_hold_ring.position -= _hold_ring.size / 2.0
	add_child(_hold_ring)
	# Tastensymbole unter der Bildmitte
	_key_hints = KeyHints.new()
	_key_hints.anchor_left = 0.0
	_key_hints.anchor_right = 1.0
	_key_hints.anchor_top = 0.5
	_key_hints.anchor_bottom = 0.5
	_key_hints.offset_top = 16.0
	_key_hints.offset_bottom = 56.0
	add_child(_key_hints)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = not get_tree().paused
	# Laufend aktualisieren, da sich die Wörter ändern können (z. B. Licht an -> aus)
	_key_hints.show_hints(_current_hints())


## Welche Tastensymbole gerade passen (mit je einem kurzen Wort).
func _current_hints() -> Array:
	if _storing:
		return [{"input": "store_hold", "word": "Ins Lager"}]
	if _seated:
		return [{"input": "interact", "word": "Aufstehen"}]
	if not is_instance_valid(_target):
		return []
	var hints := []
	if not _target.take_text.is_empty():
		hints.append({"input": "take", "word": _target.take_text})
	if _target.supports_hold and not _target.hold_prompt_text.is_empty():
		hints.append({"input": "interact_hold", "word": _target.hold_prompt_text})
	if not _target.prompt_text.is_empty():
		hints.append({"input": "interact", "word": _target.prompt_text})
	return hints


## Kontostand aktualisieren; Einnahmen und Ausgaben erscheinen kurz darunter (+80 / −320).
func _on_money_changed(money: int, change: int) -> void:
	_money_label.text = Wallet.format(money)
	if change == 0:
		return
	_money_change_label.text = ("+" if change > 0 else "−") + Wallet.format(absi(change))
	if _money_tween:
		_money_tween.kill()
	_money_change_label.modulate.a = 1.0
	_money_tween = create_tween()
	_money_tween.tween_interval(1.6)
	_money_tween.tween_property(_money_change_label, "modulate:a", 0.0, 0.8)


## Fortschritt beim Gedrückthalten von E bzw. Q (-1 = Ring ausblenden). Der Ring liegt um
## das passende Tastensymbol – sind die Hinweise aus, um die Bildmitte.
func _on_player_hold_progress_changed(progress: float, action: StringName = &"interact") -> void:
	if action == &"store_books":
		_storing = progress >= 0.0
		_key_hints.show_hints(_current_hints())
	var input: String = {&"store_books": "store_hold", &"place_all": "place_all"}.get(action, "interact_hold")
	var on_icon := _key_hints.set_hold_progress(input, progress)
	_hold_ring.progress = -1.0 if on_icon else progress


## Im Sitzen dezent zeigen, wie man wieder aufsteht.
func _on_player_seated_changed(seated: bool) -> void:
	_seated = seated


func _on_player_interaction_target_changed(target: Interactable) -> void:
	_target = target
	var is_active := target != null

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	var crosshair_scale := Vector2.ONE * (CROSSHAIR_ACTIVE_SCALE if is_active else 1.0)
	_tween.tween_property(_crosshair, "scale", crosshair_scale, FADE_TIME)
	_tween.tween_property(_crosshair, "modulate:a", 1.0 if is_active else CROSSHAIR_IDLE_ALPHA, FADE_TIME)


## Im Katalog-Zustand des Gestaltungsmodus ist der Mauszeiger sichtbar – dann
## wird der Punkt in der Bildmitte nicht gebraucht.
func _on_build_mode_catalog_state_changed(in_catalog: bool) -> void:
	_crosshair.visible = not in_catalog and not _cursor_icon.visible


## Beim Gestalten: Farbroller (Wand), Teppich (Boden) oder Deckenroller statt des Punkts.
func _on_build_mode_cursor_icon_changed(icon: String) -> void:
	match icon:
		"roller":
			_cursor_icon.texture = paint_roller_icon
		"carpet":
			_cursor_icon.texture = carpet_icon
		"ceiling":
			_cursor_icon.texture = ceiling_icon
		_:
			_cursor_icon.texture = null
	_cursor_icon.visible = _cursor_icon.texture != null
	_crosshair.visible = not _cursor_icon.visible
