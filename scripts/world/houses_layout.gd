class_name HousesLayout
extends RefCounted
## Plant, wo alle Nachbarhäuser stehen (seit Etappe 4e). Das Ergebnis schreibt der Erzeuger
## (scenes/world/tools/generate_houses.tscn) fest in scenes/world/houses.tscn – im Spiel
## selbst wird nichts mehr geplant. Lage aus StreetLayout, Haustypen aus GameConfig.
##
## Reihen (seit Etappe 4f folgen sie den runden Straßenenden, StreetLayout.end_path):
## - Bücherei-Seite: die festen Nachbarn (GameConfig.neighbor_house_types und
##   alley_house_types); dahinter weitere Häuser bis zu den Enden.
## - Gegenüber: Reihenhäuser über das gerade Mittelstück, das besondere Haus
##   (GameConfig.opposite_feature_house) möglichst genau gegenüber der Ladentür.
## - Gerades Ende (Gruppe StraightEnd): innen in der runden 90°-Kurve ein Eckhaus mit
##   abgeschrägter Ecke (GameConfig.straight_corner_house), außen Häuser, die der Kurve folgen
##   und ein Stück in die Seitenstraße. Fest bis zur Grenze, dahinter Kulisse.
## - Abbiegendes Ende (Gruppe GateStreet): innen in der sanften Kurve ein Eckhaus
##   (GameConfig.gate_corner_house), außen Häuser entlang der Kurve, beide Straßenseiten bis
##   zum Torhaus (alles fest, man kommt bis an den Bogen), dahinter die Kulisse entlang der
##   Kurve hinter dem Bogen.
## Häuser, die man von keiner erreichbaren Stelle aus sieht, werden nicht gebaut (seit 4f;
## prüfen mit tools/plan_check.py unseen).
## Jede Reihe wird lückenlos mit Reihenhaus-Typen gefüllt. Weil die Typen feste Breiten haben,
## überlappen sich Nachbarn dabei um wenige Zentimeter (unsichtbar); jedes zweite Haus steht
## 4 mm zurück, damit sich keine Flächen genau überdecken (kein Flimmern).

const STAGGER := 0.004

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
	_opposite_row(houses)
	_straight_end(houses, StreetLayout.straight_side())
	_gate_end(houses, StreetLayout.turning_side())
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


## Gegenüber: Reihenhäuser (Vorderseite +Z) über das gerade Mittelstück, das besondere Haus
## vor der Ladentür; seit Etappe 4f unterbrochen von einer kleinen Gasse.
static func _opposite_row(houses: Array[Dictionary]) -> void:
	var ends := [_opposite_row_end(-1), _opposite_row_end(1)]
	var row := Vector2(minf(ends[0], ends[1]), maxf(ends[0], ends[1]))
	var parts: Array[Vector2] = [row]
	var alley := StreetLayout.opposite_alley()
	if alley != Vector2.ZERO and alley.x > row.x and alley.y < row.y:
		parts = [Vector2(row.x, alley.x), Vector2(alley.y, row.y)]
	var door_x := StreetLayout.door_center().x
	for i in parts.size():
		var part := parts[i]
		var feature := GameConfig.opposite_feature_house if door_x > part.x and door_x < part.y else ""
		_opposite_part(houses, part, feature, i)


## Ein Stück der Reihe gegenüber (von – bis x), auf Wunsch mit dem besonderen Haus darin.
static func _opposite_part(houses: Array[Dictionary], part: Vector2, feature: String, index: int) -> void:
	var z := StreetLayout.opposite_front_z()
	var length := part.y - part.x
	var types := _choose(length - (HouseTypes.width_of(feature) if feature != "" else 0.0), 11 + index * 5)
	if feature != "":
		# An die Stelle, an der es der Ladentür am nächsten steht
		var best := 0
		var best_distance := INF
		for slot in types.size() + 1:
			var trial := types.duplicate()
			trial.insert(slot, feature)
			var centers := _centers(trial, length)
			var distance := absf(part.x + centers[slot] - StreetLayout.door_center().x)
			if distance < best_distance:
				best_distance = distance
				best = slot
		types.insert(best, feature)
	var start := houses.size()
	_place(houses, "Opposite", "Opposite%d_" % (index + 1), types, Vector2(part.x, z), Vector2(part.y, z), 0.0,
		STREET_COLORS, index * 2)
	for i in range(start, houses.size()):
		var house := houses[i]
		var half := HouseTypes.width_of(house.type) / 2.0
		house.solid = _reachable(house.position.x - half, house.position.x + half)


## Hier endet die Reihe gegenüber (x): am geraden Ende, wo die Kurve beginnt (dort folgen die
## Häuser der Kurve), am abbiegenden Ende am Eckhaus innen in der Kurve.
static func _opposite_row_end(side: int) -> float:
	if StreetLayout.is_straight(side):
		return StreetLayout.end_start_x(side)
	return _corner_placement(side).main_end.x


## Gerades Ende: Bücherei-Seite bis zum Eckhaus (fest bis zur Grenze), Eckhaus innen in der
## Kurve, außen die Häuser entlang der Kurve.
static func _straight_end(houses: Array[Dictionary], side: int) -> void:
	var group := "StraightEnd"
	var path := StreetLayout.end_path(side)
	var opp := StreetLayout.opposite_facade_offset()
	var corner := _corner_placement(side)
	var start := houses.size()
	_fill(houses, group, "Street", Vector2(StreetLayout.row_end_x(side), StreetLayout.HOUSE_FRONT),
		corner.main_end, PI, STREET_COLORS, 3, false)
	for i in range(start, houses.size()):
		var half := HouseTypes.width_of(houses[i].type) / 2.0
		houses[i].solid = _reachable(houses[i].position.x - half, houses[i].position.x + half)
	_expose_gable(houses, start, side)
	_add_corner(houses, group, corner, false)
	# Außen: Häuser folgen der Kurve in die Seitenstraße. Innen in der Seitenstraße und quer an
	# ihrem Ende stehen bewusst keine Häuser – die sieht man von nirgends (geprüft mit
	# tools/plan_check.py unseen); die Seitenstraße ist nur so lang, wie man hineinsieht.
	var outer := PackedVector2Array()
	for point in path:
		outer.append(StreetLayout.end_offset(point, -opp, side))
	_fill_curve(houses, group, "Outer", outer, path, FAR_COLORS, 0, false)


## Abbiegendes Ende: Eckhaus innen in der sanften Kurve, beide Straßenseiten bis zum Torhaus
## (fest), das Torhaus und die Kulisse hinter dem Bogen.
static func _gate_end(houses: Array[Dictionary], side: int) -> void:
	var group := "GateStreet"
	var path := StreetLayout.end_path(side)
	var front := StreetLayout.gatehouse_front()
	var front_dir: Vector2 = front.dir
	var lib := StreetLayout.library_facade_offset()
	var opp := StreetLayout.opposite_facade_offset()
	var corner := _corner_placement(side)
	_add_corner(houses, group, corner, true)
	# Gegenüber: vom Eckhaus geradeaus bis zum Torhaus
	_fill(houses, group, "Approach", corner.side_end, StreetLayout.end_offset(front, -opp, side),
		_facing(_library_normal(front_dir, side)), STREET_COLORS, 2, true)
	# Bücherei-Seite: von den festen Nachbarn durch die Kurve bis zum Torhaus
	var outer := PackedVector2Array([Vector2(StreetLayout.row_end_x(side), StreetLayout.HOUSE_FRONT)])
	var approach: Array[Dictionary] = []
	for point in path:
		if point.s <= front.s + 0.001:
			outer.append(StreetLayout.end_offset(point, lib, side))
			approach.append(point)
	var start := houses.size()
	_fill_curve(houses, group, "Bend", outer, approach, STREET_COLORS, 4, true)
	_expose_gable(houses, start, side)
	# Das Torhaus quer über der Straße, Vorderseite zur Bücherei hin; es behält die Farben aus
	# seiner Szene
	var type := GameConfig.gatehouse_type
	var gate := _add(houses, group, "Gatehouse", type, front.pos, _facing(-front_dir), 0)
	gate.wall_color = HouseTypes.value_of(type, "wall_color", gate.wall_color)
	gate.door_color = HouseTypes.value_of(type, "door_color", gate.door_color)
	gate.solid = true
	# Hinter dem Bogen: Häuser an beiden Straßenrändern entlang der Kurve und quer am Ende
	var back_s: float = front.s + StreetLayout.gate_depth()
	var behind: Array[Dictionary] = []
	for point in path:
		if point.s >= back_s - 0.001:
			behind.append(point)
	var offset := StreetLayout.gate_facade_offset()
	# Die Kurve hinter dem Bogen biegt zur Seite gegenüber ab: dort ist ihre Innenseite – die
	# Häuser innen reichen nur bis zum Ende der Kurve, außen bis zum Ende der Straße. Quer am Ende
	# stehen keine Häuser: So weit sieht man durch den Bogen nicht.
	for edge in [[-1.0, "BehindInner", 1, false], [1.0, "BehindOuter", 2, true]]:
		var line := PackedVector2Array()
		for point in behind:
			if edge[3] or point.part == "behind":
				line.append(StreetLayout.end_offset(point, edge[0] * offset, side))
		_fill_curve(houses, group, edge[1], line, behind, FAR_COLORS, edge[2], false)


## Hinter der Gasse stehen die festen Nachbarn zurückversetzt; das erste Haus danach steht wieder
## vorn an der Straße. Seine Seitenwand zum kleinen Platz sieht man – sie bekommt Fenster.
static func _expose_gable(houses: Array[Dictionary], index: int, side: int) -> void:
	if side > 0 or index >= houses.size():
		return
	var house := houses[index]
	var local_x := Vector2(cos(house.yaw), -sin(house.yaw))
	house["props"] = {"side_windows": 1 if local_x.dot(Vector2(-side, 0.0)) > 0.0 else -1}


## --- Eckhäuser mit abgeschrägter Ecke (innen in den Kurven) ---

## Wo das Eckhaus innen in der Kurve eines Endes steht. Die gedachte Ecke liegt dort, wo sich
## die Hausfronten vor und nach der Kurve treffen. Ergebnis: { "type", "position", "yaw",
## "main_end" (Ende auf der Hausfront am geraden Mittelstück), "side_end" (Ende auf der
## Hausfront nach der Kurve) }.
static func _corner_placement(side: int) -> Dictionary:
	var straight := StreetLayout.is_straight(side)
	var type := GameConfig.straight_corner_house if straight else GameConfig.gate_corner_house
	var after: Dictionary = StreetLayout.end_path(side).back() if straight else StreetLayout.gatehouse_front()
	var dir: Vector2 = after.dir
	# Innenseite: am geraden Ende die Bücherei-Seite, am abbiegenden Ende gegenüber
	var inner := 1.0 if straight else -1.0
	var offset := StreetLayout.library_facade_offset() if straight else StreetLayout.opposite_facade_offset()
	var main_z := StreetLayout.road_center_z() + inner * offset
	var corner := StreetLayout.line_intersection(Vector2(0.0, main_z), Vector2.RIGHT,
		StreetLayout.end_offset(after, inner * offset, side), dir)
	# Richtungen von der Ecke weg und zur Straße hin (je Hausfront)
	var main_away := Vector2(-side, 0.0)
	var main_road := Vector2(0.0, -inner)
	var side_away := dir
	var side_road := -_library_normal(dir, side) * inner
	var angle := deg_to_rad(float(HouseTypes.value_of(type, "corner_angle", 90.0)))
	var width := HouseTypes.width_of(type)
	var side_length := HouseTypes.depth_of(type) if angle >= deg_to_rad(89.9) \
		else float(HouseTypes.value_of(type, "side_length", 5.0))
	# Die Vorderseite des Hauses (mit der Ecke rechts) liegt an der Hausfront, bei der die
	# Seitenfassade richtig herum nach hinten abknickt
	var options := [[main_away, main_road, side_away, true], [side_away, side_road, main_away, false]]
	var chosen: Array = options[0]
	for option in options:
		var facing: Vector2 = option[1]
		# Die Blickrichtung legt fest, wohin das lokale +X (rechts, mit der Ecke) zeigt
		var along_x := Vector2(facing.y, -facing.x)
		var expected := along_x * cos(angle) - facing * sin(angle)
		if along_x.dot(-(option[0] as Vector2)) > 0.95 and expected.dot(option[2]) > 0.95:
			chosen = option
			break
	var front_away: Vector2 = chosen[0]
	var other_away: Vector2 = chosen[2]
	var front_end := corner + front_away * width
	var other_end := corner + other_away * side_length
	return {
		"type": type,
		"position": corner + front_away * (width / 2.0),
		"yaw": _facing(chosen[1]),
		"main_end": front_end if chosen[3] else other_end,
		"side_end": other_end if chosen[3] else front_end,
	}


static func _add_corner(houses: Array[Dictionary], group: String, corner: Dictionary, solid: bool) -> void:
	var house := _add(houses, group, "Corner", corner.type, corner.position, corner.yaw, 0)
	house.wall_color = Color(0.86, 0.8, 0.68) if solid else Color(0.74, 0.8, 0.78)
	house.solid = solid


## Senkrechte zur Fahrtrichtung, die zur Bücherei-Seite zeigt (wie StreetLayout.end_offset).
static func _library_normal(dir: Vector2, side: int) -> Vector2:
	return Vector2(-dir.y, dir.x) * float(side)


## Drehung (yaw) eines Hauses, dessen Vorderseite in Richtung "front" (x, z) zeigt.
static func _facing(front: Vector2) -> float:
	return atan2(front.x, front.y)


## Häuser entlang einer (gekrümmten) Linie der Hausfronten: Jedes Haus steht mit beiden
## vorderen Ecken auf der Linie (wie eine Sehne), Vorderseite zur Straßenmitte (path).
## Die Überlänge der Häuser verteilt sich auf die Fugen – das letzte Haus endet am Ende der
## Linie.
static func _fill_curve(houses: Array[Dictionary], group: String, prefix: String, line: PackedVector2Array,
		path: Array[Dictionary], colors: Array[Color], color_offset: int, solid: bool) -> void:
	var length := 0.0
	for i in line.size() - 1:
		length += line[i].distance_to(line[i + 1])
	var types := _choose(length, int(absf(line[0].x * 7.0 + line[0].y * 13.0)))
	if types.is_empty():
		return
	var total := 0.0
	for id in types:
		total += HouseTypes.width_of(id)
	var overlap := (total - length) / maxf(1.0, types.size() - 1) if types.size() > 1 else 0.0
	var start := line[0]
	var segment := 0
	for i in types.size():
		var width := HouseTypes.width_of(types[i])
		var reach := _walk(line, start, segment, width)
		var end: Vector2 = reach[0]
		var along := (end - start).normalized()
		var middle := (start + end) / 2.0
		# Vorderseite senkrecht zur Sehne, zur Straßenmitte hin
		var front := Vector2(-along.y, along.x)
		if front.dot(_nearest_center(path, middle) - middle) < 0.0:
			front = -front
		var back := -front * (STAGGER if i % 2 == 1 else 0.0)
		var house := _add(houses, group, "%s%d" % [prefix, i + 1], types[i], middle + back, _facing(front), i)
		house.wall_color = colors[(i + color_offset) % colors.size()]
		house.solid = solid
		var next := _walk(line, start, segment, width - overlap)
		start = next[0]
		segment = next[1]


## Geht auf der Linie ab "from" (liegt auf Abschnitt "segment") bis zum Punkt im geraden
## Abstand "distance". Ergebnis: [Punkt, Abschnitt]. Hinter dem Ende geht es geradeaus weiter.
static func _walk(line: PackedVector2Array, from: Vector2, segment: int, distance: float) -> Array:
	var k := segment
	while k < line.size() - 1:
		if line[k + 1].distance_to(from) >= distance:
			return [_point_at_distance(from, line[k], line[k + 1], distance), k]
		k += 1
	var last := line[line.size() - 1]
	var dir := (last - line[line.size() - 2]).normalized()
	# Über das Ende hinaus: auf der Verlängerung den Punkt im Abstand "distance" suchen
	return [_point_at_distance(from, last, last + dir * (distance + 1.0), distance), line.size() - 2]


## Punkt auf der Strecke a–b mit Abstand "distance" von "from" (from liegt davor).
static func _point_at_distance(from: Vector2, a: Vector2, b: Vector2, distance: float) -> Vector2:
	# Schnitt eines Kreises um "from" mit der Strecke a–b (der weiter hinten liegende Punkt)
	var d := b - a
	var f := a - from
	var qa := d.dot(d)
	var qb := 2.0 * f.dot(d)
	var qc := f.dot(f) - distance * distance
	var disc := maxf(0.0, qb * qb - 4.0 * qa * qc)
	var t := clampf((-qb + sqrt(disc)) / (2.0 * qa), 0.0, 1.0)
	return a + d * t


## Nächster Punkt der Straßenmitte.
static func _nearest_center(path: Array[Dictionary], point: Vector2) -> Vector2:
	var best: Vector2 = path[0].pos
	for item in path:
		if (item.pos as Vector2).distance_squared_to(point) < best.distance_squared_to(point):
			best = item.pos
	return best


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
