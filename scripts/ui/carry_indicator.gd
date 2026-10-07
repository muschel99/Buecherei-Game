class_name CarryIndicator
extends CanvasLayer
## Ganz kleine Anzeige neben dem Buch in der Hand: ein Bücherstapel-Symbol mit der Zahl der
## getragenen Bücher (z. B. 3) – ohne Text. Sind die Hände voll
## (GameConfig.max_carried_books), ist die Zahl etwas wärmer gefärbt.
## Erscheint nur, wenn ich etwas trage, und nicht, solange ein Menü offen ist.

const FADE_TIME := 0.25
const COUNT_COLOR := Color(1.0, 0.96, 0.88, 0.92)
const FULL_COLOR := Color(1.0, 0.82, 0.55, 1.0)

@onready var _panel: PanelContainer = %Panel
@onready var _icon: TextureRect = %Icon
@onready var _count: Label = %Count

var _tween: Tween
var _shown := false


func _ready() -> void:
	_panel.modulate.a = 0.0
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
