class_name BookLook
extends RefCounted
## Wie ein Buch aussieht: Größe, Farbe und Verzierung des Rückens.
##
## Alles steht im Titel (BookData) – so sehen alle Exemplare eines Titels gleich aus,
## auch nach dem Laden. Die Spannweiten stehen in GameConfig
## (book_height_range, book_thickness_range, book_depth_range, book_color_variation).
## Gemeinsames Material für alle Bücher: get_material() (Shader book_spine.gdshader).

static var _material: ShaderMaterial
static var _mesh: BoxMesh


## Größe in Metern: x = Dicke (Rücken), y = Höhe, z = Tiefe (steht im Titel, BookData).
static func get_size(book: Book) -> Vector3:
	return book.data.size


## Farbe des Einbands.
static func get_color(book: Book) -> Color:
	return book.data.cover_color


## Verzierung des Rückens für den Shader: r = Bänder (0 / 0.5 / 1), g = Titelschild (0 / 1).
static func get_custom(book: Book) -> Color:
	match book.data.style:
		"classic":
			return Color(0.5, 0.0, 0.0, 0.0)
		"band", "pattern":
			return Color(0.0, 1.0, 0.0, 0.0)
		"comic":
			return Color(1.0, 0.0, 0.0, 0.0)
	return Color(0.0, 0.0, 0.0, 0.0)


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

