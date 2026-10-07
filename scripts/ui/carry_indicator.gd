class_name CarryIndicator
extends CanvasLayer
## Kleine Leiste am unteren Rand, neben dem Buch in der Hand: ein Bücherstapel-Symbol mit der
## Zahl der getragenen Bücher (z. B. 3) und daneben die Tragehinweise als Tastensymbole
## (Ablegen, am Regal Einräumen, Lager – je nach Einstellung "Hinweise"). Sind die Hände voll
## (GameConfig.max_carried_books), ist die Zahl etwas wärmer gefärbt.
## Erscheint nur, wenn ich etwas trage, und nicht, solange ein Menü offen ist.
## Die Hinweise setzt das HUD: get_tree().call_group(CarryIndicator.GROUP, "show_hints", liste).

const GROUP := "carry_indicator"
const FADE_TIME := 0.25
const COUNT_COLOR := Color(1.0, 0.96, 0.88, 0.92)
const FULL_COLOR := Color(1.0, 0.82, 0.55, 1.0)

@onready var _panel: PanelContainer = %Panel
@onready var _icon: TextureRect = %Icon
@onready var _count: Label = %Count

var _tween: Tween
var _shown := false
var _hints: KeyHints


func _ready() -> void:
	add_to_group(GROUP)
	_panel.modulate.a = 0.0
	_hints = KeyHints.new()
	_hints.compact = true
	_hints.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hints.add_theme_constant_override("separation", 12)
	_panel.get_node("HBox").add_child(_hints)
	BookStock.carried_changed.connect(_update)
	_update()


func _process(_delta: float) -> void:
	# Im Pausenmenü, im Gestaltungsmodus und in Menüs ausblenden
	var should_show := not BookStock.carried.is_empty() and not get_tree().paused and not MenuStack.has_open()
	if should_show != _shown:
		_shown = should_show
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_panel, "modulate:a", 1.0 if should_show else 0.0, FADE_TIME)


func _update() -> void:
	var active := BookStock.get_active_book()
	if active:
		_icon.texture = BookIcons.get_stack_icon(active.get_genre())
	_count.text = str(BookStock.carried.size())
	_count.add_theme_color_override("font_color", FULL_COLOR if BookStock.is_hand_full() else COUNT_COLOR)


## Tragehinweise neben dem Stapel (vom HUD aufgerufen).
func show_hints(hints: Array) -> void:
	if _hints.show_hints(hints):
		_panel.reset_size.call_deferred()  # wieder genau so breit wie der Inhalt


## Ring um ein Tragehinweis-Symbol (z. B. Q halten). Liefert false, wenn es nicht zu sehen ist.
func set_hold_progress(input: String, progress: float) -> bool:
	return _shown and _hints.set_hold_progress(input, progress)
