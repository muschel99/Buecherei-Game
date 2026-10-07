extends Node
## Das Aussehen der Bücher: Schriften, Buchrücken-Atlas und Cover-Bilder.
##
## - Schriften: Für Titel gibt es drei Arten (GenreData.cover_font): mit Serifen (klassisch),
##   ohne Serifen (modern) und verspielt (kräftig, rund). Benutzt werden Schriften, die auf
##   dem PC installiert sind (SystemFont) – nichts wird heruntergeladen. Fehlt eine, nimmt
##   Godot automatisch eine ähnliche.
## - Buchrücken-Atlas: Beim Start werden alle Buchrücken einmal in ein großes Bild gezeichnet
##   (ein Feld je Titel). Alle Regale benutzen dieses eine Bild – so bleiben auch hunderte
##   Bücher leicht für den PC (ein Zeichenaufruf je Regal, siehe BookShelf).
## - Cover-Bilder: request_cover(titel, callback) zeichnet das Cover eines Titels als Bild
##   (z. B. für das Buch in der Hand) und merkt es sich.
## Im Code: BookArt.get_spine_atlas(), BookArt.get_spine_uv(titel), BookArt.get_title_font(titel)

## Wird gesendet, sobald der Buchrücken-Atlas fertig gezeichnet ist.
signal atlas_ready

## Größe eines Feldes im Atlas (Breite, Höhe in Pixeln). Der Buchrücken wird darin im
## passenden Seitenverhältnis gezeichnet.
const CELL := Vector2i(40, 256)
## So breit ist der Atlas höchstens (Pixel).
const ATLAS_WIDTH := 4096
## Größe der Cover-Bilder (Breite in Pixeln; die Höhe ergibt sich aus dem Buch).
const COVER_WIDTH := 256
## So viele Cover-Bilder werden gemerkt.
const COVER_CACHE_SIZE := 48

const _SERIF := ["Noto Serif", "DejaVu Serif", "Liberation Serif", "FreeSerif", "Georgia", "serif"]
const _SANS := ["Noto Sans", "Inter", "Cantarell", "DejaVu Sans", "Liberation Sans", "Arial", "sans-serif"]
const _PLAYFUL := ["Comic Neue", "Nunito", "Quicksand", "Comfortaa", "Ubuntu", "Cantarell", "Noto Sans",
	"DejaVu Sans", "sans-serif"]

var _fonts := {}  # GenreData.CoverFont -> Font
var _author_font: Font
var _atlas: ImageTexture
var _atlas_size := Vector2i(ATLAS_WIDTH, CELL.y)
var _is_atlas_ready := false
var _covers := {}  # BookData.id -> Texture2D
var _cover_order: Array[String] = []
var _cover_queue: Array = []  # [BookData, Callable]
var _cover_busy := false
var _cover_viewport: SubViewport
var _cover_view: BookCover


func _ready() -> void:
	_fonts[GenreData.CoverFont.SERIF] = _system_font(_SERIF, 600, false)
	_fonts[GenreData.CoverFont.SANS] = _system_font(_SANS, 700, false)
	_fonts[GenreData.CoverFont.PLAYFUL] = _system_font(_PLAYFUL, 800, false)
	_author_font = _system_font(_SERIF, 400, true)
	# Platzhalter, bis der Atlas gezeichnet ist (die Regale zeigen solange einfarbige Rücken)
	var blank := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0.5, 0.45, 0.4))
	_atlas = ImageTexture.create_from_image(blank)
	_assign_cells()
	_build_atlas.call_deferred()


# --- Schriften ---

## Die Titelschrift eines Buchs (je nach Genre).
func get_title_font(book: BookData) -> Font:
	var genre := book.get_genre() if book else null
	var kind: int = genre.cover_font if genre else GenreData.CoverFont.SERIF
	return _fonts.get(kind, ThemeDB.fallback_font)


## Schrift für Autorennamen (schlicht, kursiv).
func get_author_font() -> Font:
	return _author_font if _author_font else ThemeDB.fallback_font


func _system_font(names: Array, weight: int, italic: bool) -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_weight = weight
	font.font_italic = italic
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.fallbacks = [ThemeDB.fallback_font]
	return font


# --- Buchrücken-Atlas ---

## Das große Bild mit allen Buchrücken (für den Shader der Bücher).
func get_spine_atlas() -> Texture2D:
	return _atlas


func is_atlas_ready() -> bool:
	return _is_atlas_ready


## Wo der Buchrücken eines Titels im Atlas liegt: Color(u, v, Breite, Höhe) – alles von 0 bis 1.
## Breite 0 = (noch) kein Rücken im Atlas.
func get_spine_uv(book: BookData) -> Color:
	if book == null or book.spine_cell < 0 or not _is_atlas_ready:
		return Color(0, 0, 0, 0)
	var area := _spine_area(book)
	return Color(area.position.x / _atlas_size.x, area.position.y / _atlas_size.y,
		area.size.x / _atlas_size.x, area.size.y / _atlas_size.y)


## Jeder Titel bekommt ein Feld im Atlas (auch nachträglich aufgenommene).
func _assign_cells() -> void:
	var index := 0
	for book in Catalog.get_all_books():
		book.spine_cell = index
		index += 1
	var columns := ATLAS_WIDTH / CELL.x
	var rows := maxi(1, ceili(float(index) / columns))
	_atlas_size = Vector2i(ATLAS_WIDTH, rows * CELL.y)


## Pixel-Rechteck des Buchrückens im Atlas: im Feld, im Seitenverhältnis des Buchs.
func _spine_area(book: BookData) -> Rect2:
	var columns := ATLAS_WIDTH / CELL.x
	var cell := Vector2(book.spine_cell % columns, book.spine_cell / columns) * Vector2(CELL)
	var ratio := book.size.x / book.size.y  # Breite : Höhe des Rückens
	var area_size := Vector2(CELL)
	if ratio < float(CELL.x) / CELL.y:
		area_size.x = CELL.y * ratio
	else:
		area_size.y = CELL.x / ratio
	area_size = area_size.floor().max(Vector2(4, 4))
	return Rect2(cell + (Vector2(CELL) - area_size) / 2.0, area_size)


## Zeichnet alle Buchrücken in einem Durchgang in ein unsichtbares Bild.
func _build_atlas() -> void:
	if DisplayServer.get_name() == "headless":
		return  # ohne Grafik (z. B. automatische Tests) gibt es nichts zu zeichnen
	var viewport := SubViewport.new()
	viewport.size = _atlas_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var root := Control.new()
	root.size = Vector2(_atlas_size)
	viewport.add_child(root)
	var columns := ATLAS_WIDTH / CELL.x
	for book in Catalog.get_all_books():
		var spine := BookCover.new()
		spine.data = book
		spine.side = BookCover.SPINE
		spine.position = Vector2(book.spine_cell % columns, book.spine_cell / columns) * Vector2(CELL)
		spine.size = Vector2(CELL)
		var area := _spine_area(book)
		spine.content_rect = Rect2(area.position - spine.position, area.size)
		root.add_child(spine)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		push_warning("BookArt: Buchrücken konnten nicht gezeichnet werden.")
		return
	image.generate_mipmaps()
	_atlas.set_image(image)
	_is_atlas_ready = true
	atlas_ready.emit()


# --- Cover-Bilder ---

## Bestellt das Cover eines Titels als Bild. callback(texture) kommt, sobald es fertig ist
## (sofort, wenn es schon gemerkt ist).
func request_cover(book: BookData, callback: Callable) -> void:
	if _covers.has(book.id):
		callback.call(_covers[book.id])
		return
	_cover_queue.append([book, callback])
	if not _cover_busy:
		_work_covers()


func _work_covers() -> void:
	_cover_busy = true
	if _cover_viewport == null:
		_cover_viewport = SubViewport.new()
		_cover_viewport.disable_3d = true
		_cover_viewport.transparent_bg = false
		_cover_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_cover_viewport)
		_cover_view = BookCover.new()
		_cover_viewport.add_child(_cover_view)
	while not _cover_queue.is_empty():
		var job: Array = _cover_queue.pop_front()
		var book: BookData = job[0]
		if not _covers.has(book.id):
			var height := roundi(COVER_WIDTH * book.size.y / book.size.z)
			_cover_viewport.size = Vector2i(COVER_WIDTH, height)
			_cover_view.size = Vector2(COVER_WIDTH, height)
			_cover_view.data = book
			_cover_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var image := _cover_viewport.get_texture().get_image()
			var texture: Texture2D = null
			if image and not image.is_empty():
				image.generate_mipmaps()
				texture = ImageTexture.create_from_image(image)
			_remember_cover(book.id, texture)
		if (job[1] as Callable).is_valid():
			(job[1] as Callable).call(_covers.get(book.id))
	_cover_busy = false


func _remember_cover(id: String, texture: Texture2D) -> void:
	_covers[id] = texture
	_cover_order.append(id)
	while _cover_order.size() > COVER_CACHE_SIZE:
		_covers.erase(_cover_order.pop_front())
