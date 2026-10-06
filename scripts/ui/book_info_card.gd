class_name BookInfoCard
extends CanvasLayer
## Kleine Karte neben der Bildmitte: zeigt das Buch, das ich gerade im Regal anschaue –
## Cover, Titel, Autor und Genre. Blendet sanft ein und aus.
## Von überall aus: BookInfoCard.show_book(self, buch) bzw. BookInfoCard.hide_card(self).

const GROUP := "book_info_card"
const FADE_TIME := 0.15
const COVER_WIDTH := 92.0

var _panel: PanelContainer
var _cover: BookCover
var _title: Label
var _author: Label
var _genre: Label
var _tween: Tween
var _sender: Object = null


static func show_book(sender: Node, book: Book) -> void:
	sender.get_tree().call_group(GROUP, "show_for", sender, book)


static func hide_card(sender: Node) -> void:
	sender.get_tree().call_group(GROUP, "hide_for", sender)


func _ready() -> void:
	add_to_group(GROUP)
	layer = 2
	_build()
	_panel.modulate.a = 0.0


func _process(_delta: float) -> void:
	# Im Pausenmenü und in Menüs ausblenden
	visible = not get_tree().paused and not MenuStack.has_open()


func show_for(sender: Object, book: Book) -> void:
	_sender = sender
	var data := book.data
	_cover.data = data
	_cover.custom_minimum_size = Vector2(COVER_WIDTH, COVER_WIDTH * data.size.y / data.size.z)
	_title.text = data.title
	_author.text = data.author
	var genre := data.get_genre()
	_genre.text = "● " + (genre.display_name if genre else "")
	_genre.add_theme_color_override("font_color", genre.get_main_color().lightened(0.45) if genre else Color.WHITE)
	_panel.reset_size()
	_fade(1.0)


func hide_for(sender: Object) -> void:
	if sender == _sender:
		_sender = null
		_fade(0.0)


func _fade(alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", alpha, FADE_TIME)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Rechts neben der Bildmitte
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = 70
	_panel.offset_top = -190
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.05, 0.62)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	_cover = BookCover.new()
	_cover.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_cover)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.custom_minimum_size.x = 210
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	_title = _label(17, Color(1.0, 0.96, 0.88))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_title)
	_author = _label(14, Color(0.9, 0.84, 0.74, 0.9))
	text.add_child(_author)
	_genre = _label(14, Color.WHITE)
	text.add_child(_genre)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	return label
