class_name BookIcons
extends RefCounted
## Kleine Bilder für Bücher: ein Bücherstapel in den Farben eines Genres.
##
## Gezeichnet aus einfachen Rechtecken (Platzhalter) – z. B. für die Lager-Anzeige,
## den Shop und die Bestandsliste. Jedes Bild entsteht einmal und wird dann gemerkt.
## Eigene Grafik: einfach ein Bild in assets/ui/icons/ legen und hier zurückgeben.

const SIZE := 64
const PAGE_COLOR := Color(0.93, 0.89, 0.8)
const BAND_COLOR := Color(0.92, 0.8, 0.5)

static var _stacks := {}  # genre_id -> Texture2D


## Ein kleiner Stapel liegender Bücher in den Farben des Genres.
static func get_stack_icon(genre: GenreData) -> Texture2D:
	var id := genre.get_id() if genre else ""
	if _stacks.has(id):
		return _stacks[id]
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var colors: Array[Color] = genre.spine_colors if genre and not genre.spine_colors.is_empty() \
		else [Color(0.55, 0.4, 0.3)]
	# Von unten nach oben: [Breite, Höhe, Verschiebung nach rechts]
	var books := [[52, 12, 4], [46, 10, 9], [50, 11, 3], [42, 10, 11]]
	var y := SIZE - 6
	for i in books.size():
		var width: int = books[i][0]
		var height: int = books[i][1]
		var x: int = books[i][2]
		y -= height
		_draw_book(image, Rect2i(x, y, width, height), colors[i % colors.size()])
		y -= 1
	var texture := ImageTexture.create_from_image(image)
	_stacks[id] = texture
	return texture


## Ein liegendes Buch: Einband in der Genre-Farbe, rechts die hellen Seiten,
## links am Rücken ein feiner heller Streifen.
static func _draw_book(image: Image, rect: Rect2i, color: Color) -> void:
	var dark := color.darkened(0.35)
	image.fill_rect(rect, dark)
	image.fill_rect(Rect2i(rect.position + Vector2i(1, 1), rect.size - Vector2i(2, 2)), color)
	# Seiten (rechts, etwas eingerückt)
	image.fill_rect(Rect2i(rect.end.x - 6, rect.position.y + 2, 4, rect.size.y - 4), PAGE_COLOR)
	# Streifen am Buchrücken
	image.fill_rect(Rect2i(rect.position.x + 5, rect.position.y + 1, 2, rect.size.y - 2), color.lerp(BAND_COLOR, 0.6))
	# Leichter Glanz oben
	image.fill_rect(Rect2i(rect.position.x + 1, rect.position.y + 1, rect.size.x - 8, 1), color.lightened(0.25))
