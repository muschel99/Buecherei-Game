class_name Polaroid
extends Control
## Ein Polaroid-Foto neben dem Tablet (App „Fassade“, seit Etappe 6b): Papier mit breitem Rand unten,
## leicht schräg gelegt, oben ein Streifen Klebeband. Zeigt das Bild einer Vorschau (texture, z. B. die
## Bildfläche eines SubViewport – das Foto ist „live“) und darunter eine Zeile wie von Hand geschrieben.
## flash() lässt es kurz weiß aufblitzen (nach „Bauen“).

## Seitenverhältnis des Fotos (Breite : Höhe), passend zu GameConfig.facade_preview_size
const PHOTO_ASPECT := 1.2
## Rand des Papiers (Anteil der Breite): oben/seitlich und unten (dort steht die Zeile)
const BORDER := 0.055
const BOTTOM := 0.2
const PAPER_COLOR := Color(0.98, 0.96, 0.91)
const INK_COLOR := Color(0.27, 0.22, 0.2)
const CAPTION_FONT := "res://assets/ui/fonts/DejaVuSerif-Italic.ttf"

## Das Bild auf dem Foto.
var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Die Zeile unten auf dem Papier.
var caption: String = "":
	set(value):
		caption = value
		queue_redraw()
## Wie schräg das Polaroid liegt (Grad, positiv = im Uhrzeigersinn).
var tilt_degrees: float = 0.0:
	set(value):
		tilt_degrees = value
		rotation = deg_to_rad(value)
## Farbe des Klebebands (durchscheinend) und wo es sitzt (Anteil der Breite, 0,5 = Mitte).
var tape_color: Color = Color(0.85, 0.72, 0.5, 0.75)
var tape_at: float = 0.5

var _flash := 0.0
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(CAPTION_FONT):
		_font = load(CAPTION_FONT)


## Höhe des Papiers zu einer Breite.
static func height_for(width: float) -> float:
	return width * (BORDER + (1.0 - 2.0 * BORDER) / PHOTO_ASPECT + BOTTOM)


## Kurz weiß aufblitzen (wie ein Blitzlicht).
func flash() -> void:
	_flash = 1.0
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		_flash = value
		queue_redraw(), 0.85, 0.0, 0.6).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0


func _draw() -> void:
	var paper := Rect2(Vector2.ZERO, size)
	# Weicher Schatten: ein paar größer werdende, sehr helle Flächen
	for i in 4:
		var grow := 2.0 + i * 3.0
		draw_rect(Rect2(paper.position + Vector2(4.0, 7.0) - Vector2.ONE * grow / 2.0, paper.size + Vector2.ONE * grow),
			Color(0.05, 0.03, 0.02, 0.07))
	draw_rect(paper, PAPER_COLOR)
	# Foto mit dunklem Untergrund (solange noch kein Bild da ist) und feiner Kante
	var margin := size.x * BORDER
	var photo := Rect2(Vector2(margin, margin), Vector2(size.x - 2.0 * margin, (size.x - 2.0 * margin) / PHOTO_ASPECT))
	draw_rect(photo, Color(0.2, 0.17, 0.15))
	if texture:
		draw_texture_rect(texture, photo, false)
	draw_rect(photo, Color(0.0, 0.0, 0.0, 0.18), false, 1.0)
	if _flash > 0.0:
		draw_rect(photo, Color(1.0, 1.0, 0.97, _flash))
	# Zeile unten, etwas schräg wie mit Stift geschrieben
	if not caption.is_empty():
		var font: Font = _font if _font else get_theme_default_font()
		var font_size := int(clampf(size.x * 0.06, 14.0, 28.0))
		var baseline := photo.end.y + (size.y - photo.end.y) * 0.58 + font_size * 0.3
		draw_set_transform(Vector2(size.x / 2.0, baseline), deg_to_rad(-1.5))
		draw_string(font, Vector2(-size.x / 2.0, 0.0), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, INK_COLOR)
		draw_set_transform(Vector2.ZERO)
	# Klebeband oben (tape_at), leicht gedreht
	var tape_size := Vector2(size.x * 0.3, size.x * 0.075)
	draw_set_transform(Vector2(size.x * tape_at, 0.0), deg_to_rad(-4.0 if tape_at <= 0.5 else 6.0))
	draw_rect(Rect2(-tape_size / 2.0, tape_size), tape_color)
	draw_rect(Rect2(-tape_size / 2.0, tape_size), Color(1.0, 1.0, 1.0, 0.12), false, 1.0)
	draw_set_transform(Vector2.ZERO)
