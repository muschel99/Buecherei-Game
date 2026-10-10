class_name ShopWindow
extends Node3D
## Sprossenfenster des Ladens: passt beim Start die innere Fensterbank an
## GameConfig.window_sill_depth an (Tiefe von der Scheibe bis zur vorderen Kante).
##
## Die Fensterbank ist zugleich Ablagefläche (SillSurface) und hat – wie Rahmen und Scheibe –
## eine feste Kollision (SillBody, Ebene "world"). So stehen Deko und Bücher auf der Bank,
## ragen aber nie in Rahmen oder Glas hinein. Für die Sichtprüfung des Straßenlebens gilt
## SillBody als durchsichtig (Metadaten "see_through"). Austauschbares Modell: siehe Kommentar in
## scenes/objects/shop_window.tscn.

## Oberkante der Fensterbank (2 mm über der Unterkante der Fensteröffnung, damit sich beide
## Flächen nie überdecken)
const SILL_TOP := -1.148
const SILL_THICKNESS := 0.05
const SILL_WIDTH := 2.7
## Ablagefläche: frei zwischen den seitlichen Rahmen, beginnt hinter der inneren Leiste
const SURFACE_WIDTH := 2.26
const SURFACE_START := 0.05
const SURFACE_EDGE_MARGIN := 0.01

@onready var _sill: MeshInstance3D = $Sill
@onready var _surface: PlacementSurface = $SillSurface
@onready var _sill_shape: CollisionShape3D = $SillBody/Sill


func _ready() -> void:
	# Durch das Glas sieht man hindurch (Sichtprüfung von StreetLife, seit Etappe 5a)
	($SillBody as Node).set_meta("see_through", true)
	var depth := maxf(GameConfig.window_sill_depth, 0.15)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SILL_WIDTH, SILL_THICKNESS, depth)
	_sill.mesh = mesh
	_sill.position = Vector3(0.0, SILL_TOP - SILL_THICKNESS / 2.0, depth / 2.0)
	var body_box := BoxShape3D.new()
	body_box.size = mesh.size
	_sill_shape.shape = body_box
	_sill_shape.position = _sill.position
	# Ablagefläche: Ursprung = Oberkante der Bank
	var usable := depth - SURFACE_START - SURFACE_EDGE_MARGIN
	var surface_box := BoxShape3D.new()
	surface_box.size = Vector3(SURFACE_WIDTH, 0.03, usable)
	(_surface.get_node("CollisionShape3D") as CollisionShape3D).shape = surface_box
	_surface.position = Vector3(0.0, SILL_TOP, SURFACE_START + usable / 2.0)
