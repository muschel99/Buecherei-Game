class_name BookInfoCard
extends CanvasLayer
## Kleine, dezente Karte neben der Bildmitte: Cover, Titel, Autor und Genre eines Buchs.
## Sie erscheint erst, wenn ich ein Buch im Regal kurz länger anschaue
## (GameConfig.book_info_delay) – nicht bei jedem flüchtigen Blick. Außerdem zeigt sie kurz
## das Buch obenauf in meiner Hand, wenn es wechselt (GameConfig.book_info_hand_time).
## Blendet sanft ein und aus.
## Von überall aus: BookInfoCard.show_book(self, buch) bzw. BookInfoCard.hide_card(self).

const GROUP := "book_info_card"
const FADE_TIME := 0.2
const COVER_WIDTH := 60.0

var _panel: PanelContainer
var _cover: BookCover
var _title: Label
var _author: Label
var _genre: Label
var _tween: Tween
var _sender: Object = null  # wer die Karte gerade zeigt (null = niemand)
var _waiting_book: Book = null  # angeschaut, aber noch nicht lange genug
var _waiting_sender: Object = null
var _waiting_time := 0.0
var _hand_time := 0.0  # Restzeit für das Buch in der Hand
var _last_active: Book = null


static func show_book(sender: Node, book: Book) -> void:
	if sender.is_inside_tree():
		sender.get_tree().call_group(GROUP, "show_for", sender, book)


static func hide_card(sender: Node) -> void:
	if sender.is_inside_tree():
		sender.get_tree().call_group(GROUP, "hide_for", sender)


func _ready() -> void:
	add_to_group(GROUP)
	layer = 2
	_build()
	_panel.modulate.a = 0.0
	_last_active = BookStock.get_active_book()
	BookStock.carried_changed.connect(_on_carried_changed)


func _process(delta: float) -> void:
	# Im Pausenmenü und in Menüs ausblenden
	visible = not get_tree().paused and not MenuStack.has_open()
	# Das Regal wurde weggeräumt, während ich hinschaute: Karte ausblenden
	if not is_same(_sender, null) and not is_same(_sender, BookStock) \
			and (not is_instance_valid(_sender) or not (_sender as Node).is_inside_tree()):
		_sender = null
		_fade(0.0)
	if _waiting_book and (not is_instance_valid(_waiting_sender) or not (_waiting_sender as Node).is_inside_tree()):
		_waiting_book = null
	# Erst nach kurzem Anschauen zeigen
	if _waiting_book:
		_waiting_time += delta
		if _waiting_time >= GameConfig.book_info_delay:
			_show_now(_waiting_sender, _waiting_book)
			_waiting_book = null
	# Das Buch in der Hand nur kurz zeigen
	if _sender == BookStock and _hand_time > 0.0:
		_hand_time -= delta
		if _hand_time <= 0.0:
			hide_for(BookStock)


## Ein Buch wird angeschaut: Die Karte erscheint nach GameConfig.book_info_delay Sekunden.
func show_for(sender: Object, book: Book) -> void:
	if _sender == sender and _sender != null:
		_fade(0.0)  # anderes Buch im selben Regal: alte Karte erst ausblenden
		_sender = null
	_waiting_book = book
	_waiting_sender = sender
	_waiting_time = 0.0


func hide_for(sender: Object) -> void:
	if _waiting_sender == sender:
		_waiting_book = null
		_waiting_sender = null
	if sender == _sender:
		_sender = null
		_fade(0.0)


## Neues Buch obenauf in der Hand (genommen oder mit dem Mausrad gewechselt): kurz zeigen.
func _on_carried_changed() -> void:
	var active := BookStock.get_active_book()
	if active == _last_active:
		return
	_last_active = active
	if active == null:
		hide_for(BookStock)
		return
	if _sender != null and _sender != BookStock:
		return  # gerade zeigt die Karte ein angeschautes Buch
	_show_now(BookStock, active)
	_hand_time = GameConfig.book_info_hand_time


func _show_now(sender: Object, book: Book) -> void:
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
	_panel.offset_left = 60
	_panel.offset_top = -140
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.05, 0.48)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_panel.add_child(row)
	_cover = BookCover.new()
	_cover.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_cover)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.custom_minimum_size.x = 160
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	_title = _label(15, Color(1.0, 0.96, 0.88, 0.95))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_title)
	_author = _label(12, Color(0.9, 0.84, 0.74, 0.85))
	text.add_child(_author)
	_genre = _label(12, Color.WHITE)
	text.add_child(_genre)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	return label
