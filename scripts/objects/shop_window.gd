class_name ShopWindow
extends Node3D
## Schaufenster des Ladens: die innere Fensterbank (zugleich Ablagefläche) und die feste Kollision von
## Bank, Glas und Seitenrahmen. Tiefe der Bank: GameConfig.window_sill_depth.
##
## Seit Etappe 6c baut die Fassade Rahmen, Glas und Sprossen in der gewählten Form (WindowUnit); diese
## Szene blendet dann ihre einfachen Platzhalter aus und passt Bank, Ablage und Kollision an die Form an
## (configure – rund: kleine Bank unter dem Kreis, Erker: tiefe Ablage bis vorn in den Erker).
##
## Die Fensterbank hat – wie Rahmen und Scheibe – eine feste Kollision (SillBody, Ebene "world"). So stehen
## Deko und Bücher auf der Bank, ragen aber nie in Rahmen oder Glas hinein. Für die Sichtprüfung des
## Straßenlebens gilt SillBody als durchsichtig (Metadaten "see_through").

## Oberkante der Fensterbank (2 mm über der Unterkante der Fensteröffnung, damit sich beide
## Flächen nie überdecken)
const SILL_TOP := -1.148
const SILL_THICKNESS := 0.05
const SILL_WIDTH := 2.7
## Ablagefläche: frei zwischen den seitlichen Rahmen, beginnt hinter der inneren Leiste
const SURFACE_WIDTH := 2.26
const SURFACE_START := 0.05
const SURFACE_EDGE_MARGIN := 0.01
## Platzhalter-Teile der Szene (weichen den Fenstern der Fassade)
const PLACEHOLDERS: Array[String] = ["FrameTop", "FrameBottom", "FrameLeft", "FrameRight", "Glass", "MuntinV1", "MuntinV2",
	"MuntinV3", "MuntinH1", "MuntinH2", "MuntinH3", "InnerRail"]

@onready var _sill: MeshInstance3D = $Sill
@onready var _surface: PlacementSurface = $SillSurface
@onready var _sill_shape: CollisionShape3D = $SillBody/Sill

var _pending: Array = []  # [Öffnung, Lage] – falls configure vor _ready kommt


func _ready() -> void:
	# Durch das Glas sieht man hindurch (Sichtprüfung von StreetLife, seit Etappe 5a)
	($SillBody as Node).set_meta("see_through", true)
	_shape_sill(SILL_TOP, SILL_WIDTH, SURFACE_WIDTH, 0.0)
	if not _pending.is_empty():
		configure(_pending[0], _pending[1])


## Passt Bank, Ablage und Kollision an ein Fenster der Fassade an. frame = Rahmen der Öffnung (Mitte unten
## auf der Außenseite, z nach draußen) in den Koordinaten dieses Knotens.
func configure(opening: Dictionary, frame: Transform3D) -> void:
	if not is_node_ready():
		_pending = [opening, frame]
		return
	for part in PLACEHOLDERS:
		var node := get_node_or_null(part) as Node3D
		if node:
			node.visible = false
	var style: FacadeOption = opening.style
	var outline: PackedVector2Array = opening.outline
	var b := OpeningShape.bounds(outline)
	var bottom := (frame * Vector3(0.0, b.position.y, 0.0)).y
	var round := style.shape == "round"
	var width := 1.1 if round else b.size.x + 0.3
	var surface_width := 0.9 if round else b.size.x - 0.14
	var bay := style.bay_depth
	if bay > 0.0:
		surface_width = b.size.x - bay * 1.24 - 0.2
	_shape_sill(bottom + 0.002, width, surface_width, bay)
	# Kollision des Glases (beim Erker vorn im Erker) und der Seiten
	var glass := $SillBody/Glass as CollisionShape3D
	var glass_box := BoxShape3D.new()
	glass_box.size = Vector3(b.size.x, b.size.y, 0.06)
	glass.shape = glass_box
	var center := frame * Vector3(0.0, b.get_center().y, -0.08 if bay <= 0.0 else bay)
	glass.position = center
	for side: String in ["SideLeft", "SideRight"]:
		var shape := get_node("SillBody/" + side) as CollisionShape3D
		var box := BoxShape3D.new()
		box.size = Vector3(0.12, b.size.y + 0.1, 0.3)
		shape.shape = box
		var x := b.size.x / 2.0 * (-1.0 if side == "SideLeft" else 1.0)
		shape.position = frame * Vector3(x, b.get_center().y, -0.1)
	if bay > 0.0:
		# Erker: schräge Seiten als eigene Kollisionen
		for k in 2:
			var name_k := "BayGlass%d" % k
			var shape := $SillBody.get_node_or_null(name_k) as CollisionShape3D
			if shape == null:
				shape = CollisionShape3D.new()
				shape.name = name_k
				$SillBody.add_child(shape)
			var box := BoxShape3D.new()
			box.size = Vector3(bay * 1.18, b.size.y, 0.06)
			shape.shape = box
			var sx := -1.0 if k == 0 else 1.0
			var p := frame * Vector3(sx * (b.size.x / 2.0 - bay * 0.31), b.get_center().y, bay / 2.0)
			shape.transform = Transform3D(Basis(Vector3.UP, sx * atan2(1.0, 0.62)) * frame.basis.orthonormalized(), p)


## Bank, Ablagefläche und Kollision: Oberkante (lokal), Breite, nutzbare Breite, Tiefe des Erkers.
func _shape_sill(top: float, width: float, surface_width: float, bay: float) -> void:
	var depth := maxf(GameConfig.window_sill_depth, 0.15)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, SILL_THICKNESS, depth)
	_sill.mesh = mesh
	_sill.position = Vector3(0.0, top - SILL_THICKNESS / 2.0, depth / 2.0)
	var body_box := BoxShape3D.new()
	body_box.size = mesh.size
	_sill_shape.shape = body_box
	_sill_shape.position = _sill.position
	# Ablagefläche: Ursprung = Oberkante der Bank; beim Erker reicht sie vorn bis in den Erker
	var start := SURFACE_START - (bay - 0.08 if bay > 0.0 else 0.0) - (0.1 if bay > 0.0 else 0.0)
	var usable := depth - start - SURFACE_EDGE_MARGIN
	var surface_box := BoxShape3D.new()
	surface_box.size = Vector3(surface_width, 0.03, usable)
	(_surface.get_node("CollisionShape3D") as CollisionShape3D).shape = surface_box
	_surface.position = Vector3(0.0, top, start + usable / 2.0)
