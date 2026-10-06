extends CanvasLayer
## Anzeige über dem Spielbild: Punkt in der Bildmitte, Hinweistext und Kontostand.
##
## Bekommt von der Spielfigur über das Signal "interaction_target_changed"
## mitgeteilt, welches interaktive Objekt gerade anvisiert wird.

const FADE_TIME := 0.15
const CROSSHAIR_IDLE_ALPHA := 0.45
const CROSSHAIR_ACTIVE_SCALE := 1.6

## Platzhalter-Symbole für den Gestaltungsmodus (im Inspektor austauschbar).
@export var paint_roller_icon: Texture2D
@export var carpet_icon: Texture2D
@export var ceiling_icon: Texture2D

@onready var _crosshair: Panel = $Crosshair
@onready var _cursor_icon: TextureRect = $CursorIcon
@onready var _prompt_label: Label = $PromptLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _money_change_label: Label = %MoneyChangeLabel

var _target: Interactable = null
var _seated := false
var _tween: Tween
var _money_tween: Tween


func _ready() -> void:
	_crosshair.modulate.a = CROSSHAIR_IDLE_ALPHA
	_prompt_label.modulate.a = 0.0
	_money_change_label.modulate.a = 0.0
	_money_label.text = Wallet.format(Wallet.money)
	Wallet.money_changed.connect(_on_money_changed)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = not get_tree().paused
	# Text laufend aktualisieren, da er sich ändern kann (z. B. "einschalten" -> "ausschalten")
	if _seated:
		_prompt_label.text = "%s, Leertaste oder Laufen – Aufstehen" % _get_key_name("interact")
	elif is_instance_valid(_target):
		_prompt_label.text = "%s – %s" % [_get_key_name("interact"), _target.prompt_text]


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


## Im Sitzen dezent zeigen, wie man wieder aufsteht.
func _on_player_seated_changed(seated: bool) -> void:
	_seated = seated
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_prompt_label, "modulate:a", 0.7 if seated else 0.0, FADE_TIME)


func _on_player_interaction_target_changed(target: Interactable) -> void:
	_target = target
	var is_active := target != null

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	var crosshair_scale := Vector2.ONE * (CROSSHAIR_ACTIVE_SCALE if is_active else 1.0)
	_tween.tween_property(_crosshair, "scale", crosshair_scale, FADE_TIME)
	_tween.tween_property(_crosshair, "modulate:a", 1.0 if is_active else CROSSHAIR_IDLE_ALPHA, FADE_TIME)
	_tween.tween_property(_prompt_label, "modulate:a", 1.0 if is_active else 0.0, FADE_TIME)


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


## Liefert den Tastennamen einer Aktion (z. B. "E"), damit der Hinweis
## auch nach einer späteren Tastenänderung stimmt.
func _get_key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "?"
