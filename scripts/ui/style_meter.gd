extends CanvasLayer
## Stilanzeige: Wie stark ist jeder Stil im Raum vertreten?
##
## Erscheint automatisch oben im Bild, solange der Gestaltungsmodus offen ist.
## Gezählt werden nur Möbel und Deko – Wandfarben und Böden sind stilneutral.
## Die Berechnung steckt in Room.get_style_shares() und wird später auch für
## Besucher (Etappe 4/6) und Musik (Etappe 9) gebraucht.

## Pfade zu Raum und Gestaltungsmodus (im Inspektor der Hauptszene eingetragen).
@export var room_path: NodePath
@export var build_mode_path: NodePath

@onready var _room: Room = get_node(room_path)
@onready var _build_mode: BuildMode = get_node(build_mode_path)
@onready var _row: HBoxContainer = %Row

var _bars := {}  # Stil -> ProgressBar
var _percent_labels := {}  # Stil -> Label


func _ready() -> void:
	hide()
	for style in StyleTags.ALL:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var name_label := Label.new()
		name_label.text = StyleTags.get_display_name(style)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", StyleTags.get_color(style))
		box.add_child(name_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(70, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = 100.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = StyleTags.get_color(style)
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		box.add_child(bar)
		_bars[style] = bar

		var percent := Label.new()
		percent.custom_minimum_size = Vector2(40, 0)
		percent.add_theme_font_size_override("font_size", 14)
		percent.add_theme_color_override("font_color", Color(1, 0.96, 0.88, 0.85))
		box.add_child(percent)
		_percent_labels[style] = percent
		_row.add_child(box)

	_room.layout_changed.connect(_refresh)
	_build_mode.active_changed.connect(_on_build_mode_active_changed)
	_refresh()


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden
	visible = _build_mode.is_active and not get_tree().paused


func _on_build_mode_active_changed(active: bool) -> void:
	visible = active and not get_tree().paused
	_refresh()


func _refresh() -> void:
	var shares := _room.get_style_shares()
	for style in StyleTags.ALL:
		var percent: float = shares[style] * 100.0
		_bars[style].value = percent
		_percent_labels[style].text = "%d %%" % roundi(percent)
