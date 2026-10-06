class_name CarryIndicator
extends CanvasLayer
## Dezente Anzeige unten in der Mitte: welches Buch obenauf liegt und welche Bücher ich
## trage, z. B. "Du trägst 7 Bücher: 3 Krimi, 4 Fantasy" – mit einem Bücherstapel je Genre.
## Erscheint nur, wenn ich etwas trage, und nicht, solange ein Menü offen ist.

const FADE_TIME := 0.25

@onready var _panel: PanelContainer = %Panel
@onready var _icons: HBoxContainer = %Icons
@onready var _label: Label = %Label

var _tween: Tween
var _shown := false


func _ready() -> void:
	_panel.modulate.a = 0.0
	BookStock.carried_changed.connect(_update_text)
	_update_text()


func _process(_delta: float) -> void:
	# Im Pausenmenü, im Gestaltungsmodus und in Menüs ausblenden
	var should_show := not BookStock.carried.is_empty() and not get_tree().paused and not MenuStack.has_open()
	if should_show != _shown:
		_shown = should_show
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_panel, "modulate:a", 1.0 if should_show else 0.0, FADE_TIME)


func _update_text() -> void:
	var count := BookStock.carried.size()
	var counts := BookStock.get_carried_counts()
	for child in _icons.get_children():
		_icons.remove_child(child)
		child.queue_free()
	for genre_id in counts:
		var genre := Catalog.get_genre(genre_id)
		if genre == null:
			continue
		var icon := TextureRect.new()
		icon.texture = BookIcons.get_stack_icon(genre)
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icons.add_child(icon)
	var active := BookStock.get_active_book()
	_label.text = "Obenauf: „%s“" % active.title if active else ""
	_label.text += "\nDu trägst %d %s: %s" % [count, "Buch" if count == 1 else "Bücher", BookStock.describe_counts(counts)]
	if count > 1:
		_label.text += " · Mausrad: anderes Buch obenauf"
	_center.call_deferred()


## Genau so breit wie der Text und mittig unten.
func _center() -> void:
	var width := _panel.get_combined_minimum_size().x
	_panel.offset_left = -width / 2.0
	_panel.offset_right = width / 2.0
