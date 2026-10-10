class_name ScreenshotViews
extends RefCounted
## Feste Blickwinkel für die Testbilder (seit Etappe 4f, benutzt von ScreenshotTour).
## Jede Gruppe ist ein Dictionary Name -> { "pos": Kamera, "target": Zielpunkt, "fov": optional }.
## Lage aus StreetLayout, damit die Blickpunkte nach Maß-Änderungen in GameConfig mitwandern.
## Neue Gruppe: Funktion ergänzen und in all_sets() / get_set() eintragen.
##
## Koordinaten wie in der Hauptszene: Bücherei im Ursprung, Straße bei -Z, Gasse bei -X.
## Augenhöhe draußen: eye() (Gehweg + 1,6 m), wie die Spielfigur.


static func all_sets() -> PackedStringArray:
	return PackedStringArray(["overview", "straight_end", "turning_end", "corners", "shop"])


static func get_set(set_name: String) -> Dictionary:
	match set_name:
		"overview":
			return overview()
		"straight_end":
			return straight_end()
		"turning_end":
			return turning_end()
		"corners":
			return corners()
		"shop":
			return shop()
	push_error("Unbekannte Gruppe von Blickpunkten: " + set_name)
	return {}


## Augenhöhe der Spielfigur draußen.
static func eye() -> float:
	return StreetLayout.ground_y() + 1.6


## Blickpunkt in Augenhöhe: Kamera bei (x, z), Blick in Richtung (dx, dz).
static func look(x: float, z: float, dx: float, dz: float, pitch: float = 0.0) -> Dictionary:
	var y := eye()
	return {"pos": Vector3(x, y, z), "target": Vector3(x + dx * 10.0, y + pitch * 10.0, z + dz * 10.0)}


## Die Straße im Ganzen: von der Bücherei aus in beide Richtungen, die Bücherei von
## gegenüber und schräg von oben.
static func overview() -> Dictionary:
	var curb := StreetLayout.curb_z()
	var road_mid := curb - GameConfig.street_width / 2.0
	var y := eye()
	return {
		"street_east": look(0.0, curb + 0.8, 1.0, 0.0),
		"street_west": look(2.0, curb + 0.8, -1.0, 0.0),
		"library_front": look(-2.0, StreetLayout.opposite_front_z() + 0.8, 0.3, 1.0, 0.15),
		"aerial_east": {"pos": Vector3(-6.0, 22.0, road_mid - 14.0), "target": Vector3(StreetLayout.straight_bound_x() + 6.0, 0.0, road_mid)},
		"aerial_west": {"pos": Vector3(4.0, 22.0, road_mid - 14.0), "target": Vector3(StreetLayout.end_start_x(-1), 0.0, road_mid - 6.0)},
		"aerial_gate": {"pos": _ground3(_gate_point(-14.0, 0.0), 22.0), "target": _ground3(_gate_point(4.0, 0.0), 2.0)},
		"high_street": {"pos": Vector3(0.0, y + 6.0, road_mid), "target": Vector3(-30.0, y, road_mid)},
	}


## Am geraden Straßenende: direkt an der unsichtbaren Grenze (so nah, wie die Spielfigur
## kommt) auf der Fahrbahn und beiden Gehwegen, geradeaus und schräg zu beiden Seiten.
static func straight_end() -> Dictionary:
	var side := float(StreetLayout.straight_side())
	var x := StreetLayout.straight_bound_x() - side * 0.62
	var near_walk := StreetLayout.HOUSE_FRONT - 0.32
	var road := StreetLayout.curb_z() - GameConfig.street_width / 2.0
	var far_walk := StreetLayout.opposite_front_z() + 0.32
	var views := {}
	for spot in [["road", road], ["near_walk", near_walk], ["far_walk", far_walk]]:
		var z: float = spot[1]
		views["bound_%s" % spot[0]] = look(x, z, side, 0.0)
		views["bound_%s_left" % spot[0]] = look(x, z, side, -0.6)
		views["bound_%s_right" % spot[0]] = look(x, z, side, 0.6)
	views["approach"] = look(x - side * 12.0, road, side, 0.0)
	views["aerial"] = {"pos": Vector3(StreetLayout.straight_bound_x() - side * 8.0, 26.0, road - 12.0),
		"target": Vector3(StreetLayout.straight_bound_x() + side * 12.0, 0.0, road)}
	return views


## Am abbiegenden Ende: der Blick von der Ladentür zum Torhaus (soll zu etwa 80 % frei
## sein), durch die sanfte Kurve, direkt am Bogen (so nah, wie die Spielfigur kommt) mittig,
## an beiden Seiten und schräg durch den Bogen, und von oben.
static func turning_end() -> Dictionary:
	var door := StreetLayout.door_center()
	var out := StreetLayout.door_outward()
	var half := StreetLayout.gate_passage_width() / 2.0
	var gate := _gate_point(0.0, 0.0)
	var y := eye()
	var at := -0.15
	return {
		"door_view": {"pos": Vector3(door.x + out.x * 0.6, 1.6, door.z + out.z * 0.6), "target": _ground3(gate, y + 2.5)},
		"plaza_view": {"pos": _ground3(Vector2(StreetLayout.alley_row_end_x() + 3.0, StreetLayout.HOUSE_FRONT - 0.6), y),
			"target": _ground3(gate, y + 2.0)},
		"bend": _look_at(_gate_point(-StreetLayout.end_part_start(StreetLayout.turning_side(), "passage") + 2.0, 1.5), gate),
		"approach": _look_at(_gate_point(-9.0, 0.0), gate),
		"approach_walk": _look_at(_gate_point(-8.0, -3.6), _gate_point(0.0, 1.0)),
		"before_gate": _look_at(_gate_point(-5.0, 0.8), _gate_point(0.0, 0.8), 0.12),
		"at_gate": _look_at(_gate_point(at, 0.0), _gate_point(10.0, 0.0)),
		"at_gate_left": _look_at(_gate_point(at, half - 0.35), _gate_point(10.0, -half)),
		"at_gate_right": _look_at(_gate_point(at, -half + 0.35), _gate_point(10.0, half)),
		"at_gate_up": _look_at(_gate_point(at, 0.0), _gate_point(10.0, 0.0), 0.7),
		"gate_close": {"pos": _ground3(_gate_point(-7.5, 3.0), y + 0.3), "target": _ground3(gate, y + 2.5)},
		"aerial": {"pos": _ground3(_gate_point(-26.0, 12.0), 26.0), "target": _ground3(_gate_point(-6.0, 0.0), 0.0)},
		"aerial_behind": {"pos": _ground3(_gate_point(30.0, 4.0), 32.0), "target": _ground3(_gate_point(4.0, 0.0), 0.0)},
	}


## Die beiden Eckhäuser mit abgeschrägter Ecke (innen in den Kurven).
static func corners() -> Dictionary:
	var side := StreetLayout.straight_side()
	var bound := StreetLayout.straight_bound_x()
	var start := StreetLayout.end_start_x(side)
	var y := eye()
	var corner := Vector2(start + side * 3.0, StreetLayout.HOUSE_FRONT + 1.0)
	return {
		"straight_from_bound": look(bound - side * 0.62, StreetLayout.opposite_front_z() + 0.4, side, 0.75, 0.1),
		"straight_close": {"pos": Vector3(start + side * 2.0, y + 1.0, StreetLayout.opposite_front_z() + 1.0),
			"target": Vector3(corner.x, y + 1.5, corner.y)},
		"straight_aerial": {"pos": Vector3(start - side * 10.0, 22.0, StreetLayout.opposite_front_z() - 8.0),
			"target": Vector3(start + side * 6.0, 0.0, StreetLayout.HOUSE_FRONT + 4.0)},
		"gate_corner": _look_at(_gate_point(-StreetLayout.end_part_start(StreetLayout.turning_side(), "passage") - 6.0, 3.6),
			_gate_point(-StreetLayout.end_part_start(StreetLayout.turning_side(), "passage") + 3.0, -6.0), 0.12),
	}


## Punkt am abbiegenden Ende, gemessen ab der Vorderseite des Torhauses: "along" Meter in
## Fahrtrichtung (negativ = davor), "across" Meter zur Seite (positiv = Bücherei-Seite).
## Vor der sanften Kurve geht es auf dem geraden Mittelstück weiter.
static func _gate_point(along: float, across: float) -> Vector2:
	var side := StreetLayout.turning_side()
	var front := StreetLayout.gatehouse_front()
	var target_s: float = front.s + along
	var path := StreetLayout.end_path(side)
	if target_s <= 0.0:
		var start: Dictionary = path[0]
		var moved := {"pos": (start.pos as Vector2) + (start.dir as Vector2) * target_s, "dir": start.dir}
		return StreetLayout.end_offset(moved, across, side)
	var best: Dictionary = path[0]
	for point in path:
		if absf(point.s - target_s) < absf(best.s - target_s):
			best = point
	var extra: float = target_s - best.s
	var shifted := {"pos": (best.pos as Vector2) + (best.dir as Vector2) * extra, "dir": best.dir}
	return StreetLayout.end_offset(shifted, across, side)


static func _ground3(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, height, point.y)


## Blickpunkt in Augenhöhe von a nach b (x, z).
static func _look_at(a: Vector2, b: Vector2, pitch: float = 0.0) -> Dictionary:
	var y := eye()
	var dist := a.distance_to(b)
	return {"pos": Vector3(a.x, y, a.y), "target": Vector3(b.x, y + pitch * dist, b.y)}


## Im Laden: ein paar Blicke für Änderungen innen.
static func shop() -> Dictionary:
	return {
		"room_back": {"pos": Vector3(1.5, 1.6, 3.0), "target": Vector3(-1.5, 1.2, -3.0)},
		"room_front": {"pos": Vector3(-1.0, 1.6, -2.0), "target": Vector3(2.0, 1.2, 3.5)},
		"door_outside": look(StreetLayout.door_center().x - 3.0, StreetLayout.door_center().z - 3.0, 1.0, 1.0),
	}
