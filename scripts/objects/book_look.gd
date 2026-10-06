class_name BookLook
extends RefCounted
## Wie ein Buch aussieht: Größe, Farbe und Verzierung des Rückens.
##
## Alles entsteht aus der festen Zufallszahl des Buchs (Book.look) – so sieht ein Buch
## immer gleich aus, auch nach dem Laden. Die Spannweiten stehen in GameConfig
## (book_height_range, book_thickness_range, book_depth_range, book_color_variation).
## Gemeinsames Material für alle Bücher: get_material() (Shader book_spine.gdshader).

static var _material: ShaderMaterial
static var _mesh: BoxMesh


## Größe in Metern: x = Dicke (Rücken), y = Höhe, z = Tiefe.
static func get_size(book: Book) -> Vector3:
	var rng := _rng(book)
	var thickness := GameConfig.book_thickness_range
	var height := GameConfig.book_height_range
	var depth := GameConfig.book_depth_range
	# Höhe: meist mittel, ab und zu ein großes oder kleines Buch
	var h := lerpf(height.x, height.y, clampf((rng.randf() + rng.randf()) / 2.0 + rng.randf_range(-0.15, 0.15), 0.0, 1.0))
	var t := lerpf(thickness.x, thickness.y, pow(rng.randf(), 1.4))
	var d := lerpf(depth.x, depth.y, (h - height.x) / maxf(height.y - height.x, 0.001) * 0.7 + rng.randf() * 0.3)
	return Vector3(t, h, d)


## Farbe des Einbands: eine Farbe aus der Genre-Palette, leicht abgewandelt.
static func get_color(book: Book) -> Color:
	var rng := _rng(book)
	for i in 5:
		rng.randf()  # die ersten Zufallszahlen gehören zur Größe
	var genre := book.get_genre()
	var palette: Array[Color] = genre.spine_colors if genre and not genre.spine_colors.is_empty() \
		else [Color(0.5, 0.45, 0.4)]
	var color: Color = palette[rng.randi() % palette.size()]
	var amount := GameConfig.book_color_variation
	color.h = fposmod(color.h + rng.randf_range(-0.025, 0.025) * amount, 1.0)
	color.s = clampf(color.s + rng.randf_range(-0.08, 0.08) * amount, 0.0, 1.0)
	color.v = clampf(color.v + rng.randf_range(-0.12, 0.12) * amount, 0.05, 1.0)
	return color


## Verzierung des Rückens für den Shader: r = Bänder (0 / 0.5 / 1), g = Titelschild (0 / 1).
static func get_custom(book: Book) -> Color:
	var rng := _rng(book)
	for i in 10:
		rng.randf()  # die ersten Zufallszahlen gehören zu Größe und Farbe
	var bands := rng.randf()
	var band_value := 0.0 if bands < 0.45 else (0.5 if bands < 0.8 else 1.0)
	return Color(band_value, 1.0 if rng.randf() < 0.3 else 0.0, 0.0, 0.0)


## Ein Würfel der Größe 1 – jedes Buch ist dieser Würfel, auf seine Größe gestreckt.
static func get_mesh() -> BoxMesh:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3.ONE
	return _mesh


## Gemeinsames Material aller Bücher (Farbe kommt je Buch aus dem MultiMesh).
static func get_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://assets/shaders/book_spine.gdshader")
	return _material


## Ein neues MultiMesh für viele Bücher (Farbe und Verzierung je Buch).
static func create_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = get_mesh()
	return multimesh


static func _rng(book: Book) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = book.look
	return rng
