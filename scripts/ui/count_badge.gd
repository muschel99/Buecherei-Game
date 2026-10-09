class_name CountBadge
extends CanvasLayer
## Kleine, dezente Anzeige rechts neben der Bildmitte: ein Buchsymbol und eine Zahl – z. B. wie
## viele Bücher im Rückgabekasten liegen, solange ich ihn anschaue. Kein weiterer Text.
## Von überall aus: CountBadge.show_count(self, 12) bzw. CountBadge.hide_badge(self).
## full = true zeigt die Zahl in der Hinweisfarbe (z. B. der Kasten ist voll).

const GROUP := "count_badge"
const FADE_TIME := 0.2
const TEXT_COLOR := Color(1.0, 0.96, 0.88, 0.95)
const FULL_COLOR := Color(0.96, 0.78, 0.48, 1.0)

var _panel: PanelContainer
var _number: Label
var _tween: Tween
var _sender: Object = null


static func show_count(sender: Node, count: int, full: bool = false) -> void:
	if sender.is_inside_tree():
		sender.get_tree().call_group(GROUP, "show_for", sender, count, full)


static func hide_badge(sender: Node) -> void:
	if sender.is_inside_tree():
		sender.get_tree().call_group(GROUP, "hide_for", sender)


func _ready() -> void:
	add_to_group(GROUP)
	layer = 2
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Rechts neben der Bildmitte, ungefähr auf Höhe des Punkts
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = 40
	_panel.offset_top = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.05, 0.48)
	style.set_corner_radius_all(9)
	style.content_margin_left = 9
	style.content_margin_right = 11
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	_panel.add_child(row)
	var glyph := BookGlyph.new()
	glyph.custom_minimum_size = Vector2(22, 22)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	_number = Label.new()
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number.add_theme_font_size_override("font_size", 18)
	row.add_child(_number)
	_panel.modulate.a = 0.0


func _process(_delta: float) -> void:
	# Im Pausenmenü und in Menüs ausblenden
	visible = not get_tree().paused and not MenuStack.has_open()
	# Der Absender ist verschwunden: ausblenden
	if not is_same(_sender, null) and (not is_instance_valid(_sender) or not (_sender as Node).is_inside_tree()):
		_sender = null
		_fade(0.0)


func show_for(sender: Object, count: int, full: bool) -> void:
	_number.text = str(count)
	_number.add_theme_color_override("font_color", FULL_COLOR if full else TEXT_COLOR)
	if _sender != sender:
		_sender = sender
		_fade(1.0)


func hide_for(sender: Object) -> void:
	if _sender != sender:
		return
	_sender = null
	_fade(0.0)


func _fade(alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", alpha, FADE_TIME)


## Gezeichnetes Buchsymbol: zwei aufrechte Bücher und eins angelehnt.
class BookGlyph:
	extends Control

	var color := CountBadge.TEXT_COLOR

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var factor := minf(size.x, size.y) / 22.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(factor, factor))
		draw_rect(Rect2(3, 5, 4.5, 14), color)
		draw_rect(Rect2(8.5, 3, 4.5, 16), color)
		draw_colored_polygon(PackedVector2Array([Vector2(14, 19), Vector2(17.5, 5), Vector2(21, 6),
			Vector2(17.5, 19.5)]), color)
		draw_line(Vector2(1, 20.5), Vector2(21, 20.5), color, 1.5, true)
