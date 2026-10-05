extends CanvasLayer
## Testanzeige: Wie stark ist jeder Stil im Raum vertreten? (Ein- und ausschalten mit F3)
##
## Die Berechnung steckt in Room.get_style_shares() und wird später auch für
## Besucher (Etappe 4/6) und Musik (Etappe 9) gebraucht.

## Pfad zum Raum (im Inspektor der Hauptszene eingetragen).
@export var room_path: NodePath

@onready var _room: Room = get_node(room_path)
@onready var _rows: GridContainer = %Rows
@onready var _summary: Label = %Summary

var _bars := {}  # Stil -> ProgressBar
var _percent_labels := {}  # Stil -> Label


func _ready() -> void:
	hide()
	for style in StyleTags.ALL:
		var name_label := Label.new()
		name_label.text = StyleTags.get_display_name(style)
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", StyleTags.get_color(style))
		_rows.add_child(name_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(160, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = 100.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = StyleTags.get_color(style)
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		_rows.add_child(bar)
		_bars[style] = bar

		var percent := Label.new()
		percent.custom_minimum_size = Vector2(52, 0)
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		percent.add_theme_font_size_override("font_size", 15)
		_rows.add_child(percent)
		_percent_labels[style] = percent

	_room.layout_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_style_debug"):
		visible = not visible
		_refresh()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var shares := _room.get_style_shares()
	var leading_style := -1
	for style in StyleTags.ALL:
		var percent: float = shares[style] * 100.0
		_bars[style].value = percent
		_percent_labels[style].text = "%d %%" % roundi(percent)
		if leading_style == -1 or shares[style] > shares[leading_style]:
			leading_style = style
	var count := _room.get_placed_furniture().size()
	if shares[leading_style] <= 0.0:
		_summary.text = "%d Möbel · noch kein Stil" % count
	else:
		_summary.text = "%d Möbel · vorne: %s" % [count, StyleTags.get_display_name(leading_style)]
