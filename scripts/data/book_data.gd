class_name BookData
extends RefCounted
## Ein Buchtitel aus dem Katalog: Titel, Autor, Genre, Motiv, Gestaltung, Größe und Farben.
##
## Die Titel stehen in Textdateien in data/books/ (eine je Genre, eine Zeile pro Buch).
## Der Katalog liest sie beim Start ein (Catalog.get_book, Catalog.get_books_of_genre).
## Alles, was nicht in der Zeile steht (Größe, Farben, Gestaltung, Autor), entsteht aus dem
## Titel – jedes Buch sieht also immer gleich aus, auch nach dem Laden.
## Von einem Titel kann es mehrere Exemplare geben (Book); alle sehen gleich aus.

## Gestaltungen für Cover und Buchrücken (siehe BookCover).
const STYLES := ["classic", "picture", "minimal", "pattern", "band", "comic"]

## Erfundene Namen für Autorinnen und Autoren (werden pro Titel fest kombiniert).
const FIRST_NAMES := ["Hattie", "Elsa", "Milo", "Ada", "Theo", "Ruth", "Ingrid", "Felix", "Greta",
	"Oskar", "Mabel", "Juno", "Lotte", "Henry", "Clara", "Ivy", "Nell", "Arthur", "Rosa", "Edwin",
	"Frieda", "Bertie", "Wilma", "Jonas", "Tilda", "Florian", "Agnes", "Rupert", "Paula", "Emil",
	"Pippa", "Konrad", "Ottilie", "Simon", "Marlene", "Casper", "Hedda", "Linus", "Imogen", "Wendel"]
const LAST_NAMES := ["Bramwell", "Fenwick", "Marsh", "Holloway", "Kornblum", "Ashdown", "Sommerfeld",
	"Winterberg", "Lindqvist", "Pennywhistle", "Applegate", "Thistlewood", "Morrow", "Brightwater",
	"Hollander", "Fairweather", "Lindenau", "Birchwood", "Waldmann", "Teasdale", "Merriweather",
	"Quill", "Honeycutt", "Sternberg", "Mooney", "Larkin", "Brook", "Haverford", "Kettering",
	"Rosenbaum", "Feldkamp", "Wren", "Hazelwood", "Abendroth", "Moosbach", "Tannhäuser", "Penrose"]
## Helle Papierfarbe (Seiten, helle Cover, Titelschilder)
const PAPER := Color(0.93, 0.89, 0.8)
const GOLD := Color(0.86, 0.72, 0.42)

## Eindeutiger Name, z. B. "crime/the-case-of-the-curious-cat" (wird im Spielstand gespeichert).
var id: String = ""
var title: String = ""
var author: String = ""
var genre_id: String = ""
## Kleines Bild auf Cover und Rücken (siehe BookMotifs), leer = nur Schrift.
var motif: String = ""
## Gestaltung (eine aus STYLES).
var style: String = "classic"
## Größe in Metern: x = Dicke (Rücken), y = Höhe, z = Tiefe.
var size: Vector3 = Vector3(0.03, 0.24, 0.17)
## Farben: Einband, Schmuckfarbe (Rahmen, Bänder, Motiv), Papier, Schrift auf dem Einband.
var cover_color: Color = Color(0.5, 0.4, 0.3)
var accent_color: Color = GOLD
var paper_color: Color = PAPER
var text_color: Color = PAPER
## Muster für die Gestaltung "pattern" (0 = Punkte, 1 = Streifen, 2 = Karos, 3 = Wellen)
var pattern: int = 0
## Feste Zufallszahl des Titels (für kleine Unterschiede in der Gestaltung).
var seed: int = 0
## Nummer im Buchrücken-Atlas (vergibt BookArt), -1 = noch keine.
var spine_cell: int = -1
## Nicht aus der Bücherliste (z. B. ein Titel, der aus der Liste gelöscht wurde).
var is_custom: bool = false


## Erzeugt einen Titel aus einer Zeile der Bücherliste.
static func create(genre: GenreData, new_title: String, new_motif: String = "", new_style: String = "",
		new_author: String = "") -> BookData:
	var data := BookData.new()
	data.genre_id = genre.get_id() if genre else "unknown"
	data.title = new_title
	data.id = "%s/%s" % [data.genre_id, slug(new_title)]
	data.motif = new_motif
	data.seed = hash(data.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = data.seed

	var styles: Array = genre.cover_styles if genre and not genre.cover_styles.is_empty() else ["classic"]
	data.style = new_style if STYLES.has(new_style) else str(styles[rng.randi() % styles.size()])
	if not STYLES.has(data.style):
		data.style = "classic"
	data.author = new_author if not new_author.is_empty() else \
		"%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], LAST_NAMES[rng.randi() % LAST_NAMES.size()]]
	data.size = _make_size(rng, data.style)
	data._make_colors(rng, genre)
	data.pattern = rng.randi() % 4
	return data


## Größe: meist mittel, ab und zu ein großes oder kleines Buch (Spannweiten in GameConfig).
static func _make_size(rng: RandomNumberGenerator, book_style: String) -> Vector3:
	var thickness := GameConfig.book_thickness_range
	var height := GameConfig.book_height_range
	var depth := GameConfig.book_depth_range
	var h_amount := clampf((rng.randf() + rng.randf()) / 2.0 + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
	var t_amount := pow(rng.randf(), 1.4)
	if book_style == "comic":
		t_amount *= 0.35  # Comics sind dünn
	var h := lerpf(height.x, height.y, h_amount)
	var t := lerpf(thickness.x, thickness.y, t_amount)
	var d := lerpf(depth.x, depth.y, h_amount * 0.7 + rng.randf() * 0.3)
	return Vector3(t, h, d)


## Farben passend zu Genre und Gestaltung.
func _make_colors(rng: RandomNumberGenerator, genre: GenreData) -> void:
	var palette: Array[Color] = genre.spine_colors if genre and not genre.spine_colors.is_empty() \
		else [Color(0.5, 0.45, 0.4)]
	var amount := GameConfig.book_color_variation
	var index := rng.randi() % palette.size()
	cover_color = palette[index]
	cover_color.h = fposmod(cover_color.h + rng.randf_range(-0.03, 0.03) * amount, 1.0)
	cover_color.s = clampf(cover_color.s + rng.randf_range(-0.08, 0.08) * amount, 0.0, 1.0)
	cover_color.v = clampf(cover_color.v + rng.randf_range(-0.1, 0.1) * amount, 0.08, 0.95)
	# Eine zweite Farbe aus der Palette (nicht dieselbe) für Schmuck und Motiv
	var second: Color = palette[(index + 1 + rng.randi() % maxi(palette.size() - 1, 1)) % palette.size()]
	paper_color = PAPER.lerp(Color(1.0, 0.97, 0.9), rng.randf() * 0.5)
	match style:
		"classic":
			accent_color = GOLD if rng.randf() < 0.7 else paper_color
			if cover_color.get_luminance() > 0.45:
				accent_color = cover_color.darkened(0.6)  # heller Einband: dunkle Schrift
		"comic":
			cover_color.s = clampf(cover_color.s + 0.2, 0.0, 1.0)
			cover_color.v = clampf(cover_color.v + 0.15, 0.3, 1.0)
			accent_color = Color(1.0, 0.86, 0.3) if cover_color.h < 0.1 or cover_color.h > 0.2 else Color(0.95, 0.35, 0.3)
		_:
			accent_color = second if absf(second.get_luminance() - cover_color.get_luminance()) > 0.18 \
				else (paper_color if cover_color.get_luminance() < 0.5 else cover_color.darkened(0.45))
	text_color = Color(0.15, 0.11, 0.09) if cover_color.get_luminance() > 0.55 else paper_color


## Kurzer, sicherer Name aus einem Titel: "Das Rätsel der Teekanne" -> "das-raetsel-der-teekanne".
static func slug(text: String) -> String:
	var result := text.to_lower()
	for pair in [["ä", "ae"], ["ö", "oe"], ["ü", "ue"], ["ß", "ss"], ["é", "e"], ["è", "e"], ["&", "und"]]:
		result = result.replace(pair[0], pair[1])
	var clean := ""
	for character in result:
		var code := character.unicode_at(0)
		var is_letter := (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if is_letter:
			clean += character
		elif not clean.is_empty() and not clean.ends_with("-"):
			clean += "-"
	return clean.trim_suffix("-")


## Das Genre-Datenblatt.
func get_genre() -> GenreData:
	return Catalog.get_genre(genre_id)
