class_name GenreCaption
extends CanvasLayer
## Ein kleiner, ruhiger Schriftzug unten in der Bildmitte: das Genre des Regals, das ich
## gerade anschaue – nur das Wort, z. B. "Krimi". Blendet sanft ein und aus.
## (Statt Schildern am Regal; die Schrift ist dieselbe ruhige Serifenschrift wie die
## Autorennamen auf den Covern, siehe BookArt.)
## Von überall aus: GenreCaption.show_text(self, "Krimi") bzw. GenreCaption.hide_text(self).

const GROUP := "genre_caption"
const FADE_IN_TIME := 0.45
const FADE_OUT_TIME := 0.7
const FONT_SIZE := 26
const TEXT_COLOR := Color(1.0, 0.95, 0.86, 0.85)
## Abstand vom unteren Bildrand (in Pixeln bei 1600 x 900)
const BOTTOM_MARGIN := 70.0

var _label: Label
var _tween: Tween
var _sender: Object = null


static func show_text(sender: Node, text: String) -> void:
	if sender.is_inside_tree():
		sender.get_tree().call_group(GROUP, "show_for", sender, text)


static func hide_text(sender: Node) -> void:
	if sender.is_inside_tree():
		sender.get_tree().call_group(GROUP, "hide_for", sender)


func _ready() -> void:
	add_to_group(GROUP)
	layer = 2
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_top = -BOTTOM_MARGIN - 40.0
	_label.offset_bottom = -BOTTOM_MARGIN
	# Ruhige Serifenschrift mit etwas Abstand zwischen den Buchstaben
	var font := FontVariation.new()
	font.base_font = BookArt.get_author_font()
	font.spacing_glyph = 2
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.add_theme_constant_override("shadow_outline_size", 6)
	_label.modulate.a = 0.0
	add_child(_label)


func _process(_delta: float) -> void:
	# Im Pausenmenü und in Menüs ausblenden
	visible = not get_tree().paused and not MenuStack.has_open()
	# Das Regal wurde weggeräumt, während ich hinschaute: Schriftzug ausblenden
	if not is_same(_sender, null) and (not is_instance_valid(_sender) or not (_sender as Node).is_inside_tree()):
		_sender = null
		_fade(0.0, FADE_OUT_TIME)


func show_for(sender: Object, text: String) -> void:
	if sender == _sender and text == _label.text:
		return
	_sender = sender
	_label.text = text
	_fade(1.0, FADE_IN_TIME)


func hide_for(sender: Object) -> void:
	if sender == _sender:
		_sender = null
		_fade(0.0, FADE_OUT_TIME)


func _fade(alpha: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_label, "modulate:a", alpha, time)
