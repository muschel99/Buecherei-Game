class_name HousesLayout
extends RefCounted
## Plant, wo alle Nachbarhäuser stehen (seit Etappe 4e). Das Ergebnis schreibt der Erzeuger
## (scenes/world/tools/generate_houses.tscn) fest in scenes/world/houses.tscn – im Spiel
## selbst wird nichts mehr geplant. Lage aus StreetLayout, Haustypen aus GameConfig.
##
## Reihen:
## - Bücherei-Seite: die festen Nachbarn (GameConfig.neighbor_house_types und
##   alley_house_types), am geraden Straßenende weitere Häuser bis zum Knick (fest bis zur
##   Grenze, dahinter nur Kulisse).
## - Gegenüber: Reihenhäuser über die ganze Länge, das besondere Haus
##   (GameConfig.opposite_feature_house) möglichst genau gegenüber der Ladentür.
## - An beiden Knicks: Häuser entlang der Seitenstraße und quer an ihrem Ende.
## Jede Reihe wird lückenlos mit Reihenhaus-Typen gefüllt. Weil die Typen feste Breiten haben,
## überlappen sich Nachbarn dabei um wenige Zentimeter (unsichtbar); jedes zweite Haus steht
## 4 mm zurück, damit sich keine Flächen genau überdecken (kein Flimmern).

const STAGGER := 0.004
## Ein Stück hinter die Häuser gegenüber reichen die Häuser quer am Ende der Seitenstraßen,
## damit man nirgends ins Leere schaut.
const CLOSURE_BEHIND := 6.0

## Wandfarben (der Reihe nach): Backstein und Putz in hellen Tönen
const STREET_COLORS: Array[Color] = [
	Color(0.55, 0.3, 0.24), Color(0.86, 0.82, 0.72), Color(0.62, 0.72, 0.76),
	Color(0.5, 0.27, 0.22), Color(0.72, 0.78, 0.66), Color(0.9, 0.84, 0.76),
]
const NEIGHBOR_COLORS: Array[Color] = [
	Color(0.9, 0.86, 0.8), Color(0.74, 0.8, 0.78), Color(0.84, 0.76, 0.62), Color(0.58, 0.34, 0.27),
]
const FAR_COLORS: Array[Color] = [Color(0.6, 0.42, 0.34), Color(0.78, 0.74, 0.66), Color(0.52, 0.33, 0.27)]
const DOOR_COLORS: Array[Color] = [
	Color(0.18, 0.28, 0.42), Color(0.5, 0.12, 0.14), Color(0.16, 0.32, 0.24),
	Color(0.08, 0.08, 0.09), Color(0.62, 0.5, 0.2),
]


## Alle Häuser: Liste von { "group", "name", "type", "position", "yaw", "wall_color",
## "door_color", "casts_shadow", "solid" }.
static func plan() -> Array[Dictionary]:
	var houses: Array[Dictionary] = []
	_library_row(houses)
	_straight_row(houses)
	_opposite_row(houses)
	_side_streets(houses)
	return houses


## Die festen Nachbarn links und rechts der Bücherei (Vorderseite zur Straße = -Z).
static func _library_row(houses: Array[Dictionary]) -> void:
	var index := 0
	var x := StreetLayout.HOUSE_RIGHT
	for id in GameConfig.neighbor_house_types:
		var width := HouseTypes.width_of(id)
		_add(houses, "LibraryRow", "Neighbor%d" % (index + 1), id, Vector2(x + width / 2.0, StreetLayout.HOUSE_FRONT), PI, index)
		x += width
		index += 1
	x = StreetLayout.alley_far_x()
	for id in GameConfig.alley_house_types:
		var width := HouseTypes.width_of(id)
		_add(houses, "LibraryRow", "Neighbor%d" % (index + 1), id, Vector2(x - width / 2.0, StreetLayout.recess_z()), PI, index)
		x -= width
		index += 1
	for house in houses:
		var spot := Vector2(house.position.x, house.position.z)
		var door := StreetLayout.door_center()
		house.casts_shadow = spot.distance_to(Vector2(door.x, door.z)) <= GameConfig.house_shadow_distance
		house.wall_color = NEIGHBOR_COLORS[houses.find(house) % NEIGHBOR_COLORS.size()]


## Am geraden Ende: Häuser auf der Bücherei-Seite von den festen Nachbarn bis zum Knick
## (fest bis zur Grenze, dahinter nur Kulisse).
static func _straight_row(houses: Array[Dictionary]) -> void:
	var start := houses.size()
	if StreetLayout.is_straight(1):
		_fill(houses, "StraightEnd", "Street", Vector2(StreetLayout.neighbor_row_end_x(), StreetLayout.HOUSE_FRONT),
			Vector2(StreetLayout.east_end_x(), StreetLayout.HOUSE_FRONT), PI, STREET_COLORS, 3, false)
	else:
		_fill(houses, "StraightEnd", "Street", Vector2(StreetLayout.west_end_x(), StreetLayout.recess_z()),
			Vector2(StreetLayout.alley_row_end_x(), StreetLayout.recess_z()), PI, STREET_COLORS, 3, false)
	for i in range(start, houses.size()):
		var half := HouseTypes.width_of(houses[i].type) / 2.0
		houses[i].solid = _reachable(houses[i].position.x - half, houses[i].position.x + half)


## Gegenüber: Reihenhäuser (Vorderseite +Z), das besondere Haus vor der Ladentür.
static func _opposite_row(houses: Array[Dictionary]) -> void:
	var row := StreetLayout.opposite_row()
	var z := StreetLayout.opposite_front_z()
	var feature := GameConfig.opposite_feature_house
	var types := _choose(row.y - row.x - (HouseTypes.width_of(feature) if feature != "" else 0.0), 11)
	if feature != "":
		# An die Stelle, an der es der Ladentür am nächsten steht
		var best := 0
		var best_distance := INF
		for slot in types.size() + 1:
			var trial := types.duplicate()
			trial.insert(slot, feature)
			var centers := _centers(trial, row.y - row.x)
			var distance := absf(row.x + centers[slot] - StreetLayout.door_center().x)
			if distance < best_distance:
				best_distance = distance
				best = slot
		types.insert(best, feature)
	var start := houses.size()
	_place(houses, "Opposite", "Opposite", types, Vector2(row.x, z), Vector2(row.y, z), 0.0, STREET_COLORS, 0)
	for i in range(start, houses.size()):
		var house := houses[i]
		var half := HouseTypes.width_of(house.type) / 2.0
		house.solid = _reachable(house.position.x - half, house.position.x + half)


## An beiden Knicks: entlang der Seitenstraße (Vorderseite zur Seitenstraße) und quer an
## ihrem Ende. Fest nur dort, wo man hinkommt (an der abbiegenden Seite).
static func _side_streets(houses: Array[Dictionary]) -> void:
	var end_e := StreetLayout.side_street_end_z(1)
	var end_w := StreetLayout.side_street_end_z(-1)
	var east := StreetLayout.east_end_x()
	var west := StreetLayout.west_end_x()
	var west_front := StreetLayout.recess_z()
	_fill(houses, "SideStreets", "EastSide", Vector2(east, StreetLayout.HOUSE_FRONT), Vector2(east, end_e),
		-PI / 2.0, FAR_COLORS, 0, not StreetLayout.is_straight(1))
	_fill(houses, "SideStreets", "WestSide", Vector2(west, end_w), Vector2(west, west_front),
		PI / 2.0, FAR_COLORS, 1, not StreetLayout.is_straight(-1))
	var row := StreetLayout.opposite_row()
	_fill(houses, "SideStreets", "EastEnd", Vector2(row.y - CLOSURE_BEHIND, end_e), Vector2(east, end_e),
		0.0, FAR_COLORS, 2, false)
	_fill(houses, "SideStreets", "WestEnd", Vector2(west, end_w), Vector2(row.x + CLOSURE_BEHIND, end_w),
		0.0, FAR_COLORS, 0, false)


## Füllt die Strecke von a nach b lückenlos mit Reihenhäusern.
static func _fill(houses: Array[Dictionary], group: String, prefix: String, a: Vector2, b: Vector2,
		yaw: float, colors: Array[Color], color_offset: int, solid: bool) -> void:
	var types := _choose(a.distance_to(b), int(absf(a.x * 7.0 + a.y * 13.0)))
	var start := houses.size()
	_place(houses, group, prefix, types, a, b, yaw, colors, color_offset)
	for i in range(start, houses.size()):
		houses[i].solid = solid


## Stellt die Häuser der Reihe nach von a nach b; Überlänge verteilt sich auf die Fugen.
static func _place(houses: Array[Dictionary], group: String, prefix: String, types: Array, a: Vector2,
		b: Vector2, yaw: float, colors: Array[Color], color_offset: int) -> void:
	var length := a.distance_to(b)
	var along := (b - a).normalized()
	var back := Vector2(-sin(yaw), -cos(yaw))  # von der Vorderseite nach hinten
	var centers := _centers(types, length)
	for i in types.size():
		var spot := a + along * centers[i] + back * (STAGGER if i % 2 == 1 else 0.0)
		var house := _add(houses, group, "%s%d" % [prefix, i + 1], types[i], spot, yaw, i)
		house.wall_color = colors[(i + color_offset) % colors.size()]
		house.casts_shadow = false


## Mitten der Häuser entlang einer Reihe der Länge length (Überlänge auf die Fugen verteilt).
static func _centers(types: Array, length: float) -> Array[float]:
	var total := 0.0
	for id in types:
		total += HouseTypes.width_of(id)
	var overlap := (total - length) / maxf(1.0, types.size() - 1)
	var centers: Array[float] = []
	var cursor := 0.0 if types.size() > 1 else (length - total) / 2.0
	for id in types:
		var width := HouseTypes.width_of(id)
		centers.append(cursor + width / 2.0)
		cursor += width - overlap
	return centers


## Wählt Reihenhaus-Typen, die zusammen mindestens length lang sind – so knapp wie möglich.
## Erst abwechselnd aus allen Typen (Reihenfolge je nach seed, immer gleich), die letzten
## Häuser so, dass die Länge möglichst genau aufgeht.
static func _choose(length: float, seed: int) -> Array:
	var pool := GameConfig.terrace_house_types
	if pool.is_empty() or length <= 0.0:
		return []
	var widest := 0.0
	for id in pool:
		widest = maxf(widest, HouseTypes.width_of(id))
	var result: Array = []
	var total := 0.0
	var turn := seed
	while length - total > 3.0 * widest:
		var id: String = pool[turn % pool.size()]
		result.append(id)
		total += HouseTypes.width_of(id)
		turn += 1
	result.append_array(_fit(length - total, pool))
	return result


## Kleinste Auswahl aus pool, die mindestens rest lang ist (so knapp wie möglich).
static func _fit(rest: float, pool: Array[String]) -> Array:
	var widths: Array[int] = []
	for id in pool:
		widths.append(roundi(HouseTypes.width_of(id) * 100.0))
	var target := roundi(rest * 100.0)
	var limit: int = target + int(widths.max())
	var last := {0: -1}
	var best := -1
	for total in range(0, limit + 1):
		if not last.has(total):
			continue
		if total >= target:
			best = total
			break
		for k in widths.size():
			var next := total + widths[k]
			if next <= limit and not last.has(next):
				last[next] = k
	var result: Array = []
	var left := best
	while left > 0:
		var k: int = last[left]
		result.append(pool[k])
		left -= widths[k]
	return result


static func _add(houses: Array[Dictionary], group: String, house_name: String, type: String, spot: Vector2,
		yaw: float, index: int) -> Dictionary:
	var house := {
		"group": group, "name": house_name, "type": type,
		"position": Vector3(spot.x, 0.0, spot.y), "yaw": yaw,
		"wall_color": STREET_COLORS[index % STREET_COLORS.size()],
		"door_color": DOOR_COLORS[(index + 1) % DOOR_COLORS.size()],
		"casts_shadow": false, "solid": true,
	}
	houses.append(house)
	return house


## Liegt ein Haus (von x0 bis x1) dort, wo man hinkommt (vor der Grenze am geraden Ende)?
static func _reachable(x0: float, x1: float) -> bool:
	var bound := StreetLayout.straight_bound_x()
	return x0 < bound + 0.5 if StreetLayout.is_straight(1) else x1 > bound - 0.5
