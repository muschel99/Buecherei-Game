class_name Houses
extends Node3D
## Stellt die Nachbarhäuser auf (seit Etappe 4d) – reine Kulisse aus Platzhaltern
## (scenes/world/house_facade.tscn). Wo genau, ergibt sich aus StreetLayout und GameConfig.
##
## - Auf der Bücherei-Seite (von der Straße aus gesehen): Haus, Haus, Bücherei, Gasse, Haus,
##   Haus. Die beiden Häuser rechts der Bücherei (+X) stehen bündig mit ihrer Vorderwand, die
##   beiden hinter der Gasse (-X) zurückversetzt (davor liegt der kleine Platz).
## - Gegenüber: eine Zeile englischer Reihenhäuser, abwechselnd in Farbe und Höhe.
## - An den Enden der Straße: Häuser entlang der Seitenstraßen und quer an deren Ende, damit
##   die Straße hinter Häusern verschwindet.
## Dieser Knoten liegt (wie alles unter "Outside") auf Gehweg-Höhe.

## Szene für ein Haus (austauschbar, z. B. gegen eine Szene mit eigenem Modell).
@export var house_scene: PackedScene = preload("res://scenes/world/house_facade.tscn")
## Wandfarben der Reihenhäuser gegenüber (Backstein, Putz in hellen Tönen …), der Reihe nach.
@export var opposite_colors: Array[Color] = [
	Color(0.55, 0.3, 0.24), Color(0.86, 0.82, 0.72), Color(0.62, 0.72, 0.76),
	Color(0.5, 0.27, 0.22), Color(0.72, 0.78, 0.66), Color(0.9, 0.84, 0.76),
]
## Türfarben, der Reihe nach.
@export var door_colors: Array[Color] = [
	Color(0.18, 0.28, 0.42), Color(0.5, 0.12, 0.14), Color(0.16, 0.32, 0.24),
	Color(0.08, 0.08, 0.09), Color(0.62, 0.5, 0.2),
]
## Wandfarben der Nachbarhäuser auf der Bücherei-Seite, der Reihe nach.
@export var neighbor_colors: Array[Color] = [
	Color(0.5, 0.29, 0.23), Color(0.74, 0.8, 0.78), Color(0.84, 0.76, 0.62), Color(0.58, 0.34, 0.27),
]
## Wandfarben der Häuser an den Seitenstraßen (weit weg, eher gedeckt).
@export var far_colors: Array[Color] = [Color(0.6, 0.42, 0.34), Color(0.78, 0.74, 0.66), Color(0.52, 0.33, 0.27)]

var _count := 0


func _ready() -> void:
	_build_library_row()
	_build_opposite_row()
	_build_side_streets()


## Nachbarhäuser links und rechts der Bücherei (Vorderseite zur Straße, also nach -Z).
func _build_library_row() -> void:
	var heights := GameConfig.neighbor_house_heights
	var index := 0
	# Rechts der Bücherei (+X, von der Straße aus links): bündig mit ihrer Vorderwand
	var x := StreetLayout.HOUSE_RIGHT
	for width in GameConfig.neighbor_house_widths:
		_add_neighbor("Neighbor%d" % (index + 1), x + width / 2.0, StreetLayout.HOUSE_FRONT, width, index, heights)
		x += width
		index += 1
	# Hinter der Gasse (-X): zurückversetzt bis dorthin, wo die Schräge auf die Gassenwand trifft
	x = StreetLayout.alley_far_x()
	for width in GameConfig.alley_house_widths:
		_add_neighbor("Neighbor%d" % (index + 1), x - width / 2.0, StreetLayout.recess_z(), width, index, heights)
		x -= width
		index += 1


func _add_neighbor(node_name: String, x: float, front_z: float, width: float, index: int, heights: Array[float]) -> void:
	var house := _make_house(node_name, Vector3(x, 0.0, front_z), PI)
	house.width = width
	house.depth = GameConfig.neighbor_house_depth
	house.eaves_height = heights[index % heights.size()] if not heights.is_empty() else 6.8
	house.wall_color = neighbor_colors[index % neighbor_colors.size()]
	house.door_color = door_colors[(index + 1) % door_colors.size()]
	# Türen jeweils an der Seite weg von der Bücherei
	house.door_side = -1 if x > 0.0 else 1
	house.chimney = index % 2 == 0
	# Sockel so hoch wie der der Bücherei, damit das Band durchläuft
	house.plinth_height = GameConfig.shop_floor_rise
	house.plinth_proud = GameConfig.plinth_proud
	var distance := Vector2(x, front_z).distance_to(Vector2(StreetLayout.door_center().x, StreetLayout.door_center().z))
	house.casts_shadow = distance <= GameConfig.house_shadow_distance
	add_child(house)


## Reihenhäuser gegenüber: Vorderseite zur Straße (+Z), gleich breit zwischen den Seitenstraßen.
func _build_opposite_row() -> void:
	var row := StreetLayout.opposite_row()
	var count := maxi(1, GameConfig.opposite_house_count)
	var width := (row.y - row.x) / count
	var heights := GameConfig.opposite_house_heights
	for i in count:
		var house := _make_house("Opposite%d" % (i + 1), Vector3(row.x + width * (i + 0.5), 0.0, StreetLayout.opposite_front_z()), 0.0)
		house.width = width
		house.depth = GameConfig.opposite_house_depth
		house.eaves_height = heights[i % heights.size()] if not heights.is_empty() else 6.5
		house.wall_color = opposite_colors[i % opposite_colors.size()]
		house.door_color = door_colors[i % door_colors.size()]
		house.door_side = 1 if i % 2 == 0 else -1
		house.chimney = i % 2 == 1
		house.casts_shadow = false  # sonst läge die Bücherei im Schatten (Sonne steht dahinter)
		add_child(house)


## Häuser entlang der Seitenstraßen (Vorderseite zur Seitenstraße) und quer an deren Ende.
func _build_side_streets() -> void:
	var end_z := StreetLayout.side_street_end_z()
	var depth := GameConfig.neighbor_house_depth
	# Außen an der Biegung: von der Häuserreihe der Bücherei bis zum Ende der Seitenstraße
	_add_row("EastSide", Vector2(StreetLayout.east_end_x(), StreetLayout.HOUSE_FRONT),
		Vector2(StreetLayout.east_end_x(), end_z), -PI / 2.0, depth, true)
	_add_row("WestSide", Vector2(StreetLayout.west_end_x(), end_z),
		Vector2(StreetLayout.west_end_x(), StreetLayout.recess_z()), PI / 2.0, depth, true)
	# Quer am Ende der Seitenstraßen (über Fahrbahn und beide Gehwege; ein Stück weiter
	# hinter die Häuser gegenüber, damit man nirgends ins Leere schaut)
	var behind := GameConfig.end_house_width
	_add_row("EastEnd", Vector2(StreetLayout.opposite_row().y - behind, end_z),
		Vector2(StreetLayout.east_end_x(), end_z), 0.0, depth, false)
	_add_row("WestEnd", Vector2(StreetLayout.west_end_x(), end_z),
		Vector2(StreetLayout.opposite_row().x + behind, end_z), 0.0, depth, false)


## Eine Reihe gleich breiter Häuser von Punkt a nach b (x, z); yaw dreht die Vorderseite
## (0 = nach +Z). Ohne Schatten; solid = feste Kollision (nur wo man hinkommt).
func _add_row(prefix: String, a: Vector2, b: Vector2, yaw: float, depth: float, solid: bool) -> void:
	var length := a.distance_to(b)
	var count := maxi(1, roundi(length / maxf(1.0, GameConfig.end_house_width)))
	for i in count:
		var spot := a.lerp(b, (i + 0.5) / count)
		var house := _make_house("%s%d" % [prefix, i + 1], Vector3(spot.x, 0.0, spot.y), yaw)
		house.width = length / count
		house.depth = depth
		house.eaves_height = GameConfig.end_house_height + (0.4 if (i + _count) % 2 == 0 else -0.3)
		house.wall_color = far_colors[(i + _count) % far_colors.size()]
		house.door_color = door_colors[(i + 2) % door_colors.size()]
		house.door_side = 1 if i % 2 == 0 else -1
		house.chimney = i % 2 == 0
		house.casts_shadow = false
		house.solid = solid
		add_child(house)


## Neues Haus (noch nicht eingefügt: Es baut sich beim Einfügen – also erst die Werte setzen,
## dann add_child).
func _make_house(node_name: String, spot: Vector3, yaw: float) -> HouseFacade:
	var house := house_scene.instantiate() as HouseFacade
	house.name = node_name
	house.position = spot
	house.rotation.y = yaw
	_count += 1
	return house
