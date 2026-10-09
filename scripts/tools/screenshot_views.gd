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
	return PackedStringArray(["overview", "straight_end", "turning_end", "shop"])


static func get_set(set_name: String) -> Dictionary:
	match set_name:
		"overview":
			return overview()
		"straight_end":
			return straight_end()
		"turning_end":
			return turning_end()
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
		"street_west": look(0.0, curb + 0.8, -1.0, 0.0),
		"library_front": look(-2.0, StreetLayout.opposite_front_z() + 0.8, 0.3, 1.0, 0.15),
		"aerial_east": {"pos": Vector3(-6.0, 22.0, road_mid - 14.0), "target": Vector3(StreetLayout.straight_bound_x() + 6.0, 0.0, road_mid)},
		"aerial_west": {"pos": Vector3(4.0, 22.0, road_mid - 14.0), "target": Vector3(StreetLayout.west_end_x(), 0.0, road_mid - 6.0)},
		"high_street": {"pos": Vector3(0.0, y + 6.0, road_mid), "target": Vector3(-30.0, y, road_mid)},
	}


## Am geraden Straßenende: direkt an der unsichtbaren Grenze (so nah, wie die Spielfigur
## kommt) auf der Fahrbahn und beiden Gehwegen, geradeaus und schräg zu beiden Seiten.
static func straight_end() -> Dictionary:
	var side := float(StreetLayout.straight_side())
	var x := StreetLayout.straight_bound_x() - side * 0.62
	var near_walk := StreetLayout.HOUSE_FRONT - 0.32 if side > 0.0 else StreetLayout.recess_z() - 0.32
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


## Am abbiegenden Ende: Einblick in die Seitenstraße und auf das Torhaus mit Durchfahrt; direkt
## am Bogen (so nah, wie die Spielfigur kommt) mittig, an beiden Seiten und schräg durch den
## Bogen.
static func turning_end() -> Dictionary:
	var side := float(StreetLayout.turning_side())
	var road := StreetLayout.turning_road()
	var road_mid := StreetLayout.turning_road_center_x()
	var curb := StreetLayout.curb_z()
	var far := StreetLayout.far_curb_z()
	var gate := StreetLayout.gatehouse_front_z()
	var half := StreetLayout.gate_passage_width() / 2.0
	var at := gate - 0.15
	var y := eye()
	return {
		"from_street": look(road_mid - side * 9.0, (curb + far) / 2.0, side, -0.6),
		"corner": look(road_mid - side * 3.0, curb + 1.0, side * 0.6, -1.0),
		"side_road": look(road_mid, far - 1.0, 0.0, -1.0),
		"side_road_walk": look(road.x - 1.3, far - 0.5, 0.25, -1.0),
		"before_gate": look(road_mid + side * 0.8, gate + 5.0, 0.0, -1.0, 0.12),
		"at_gate": look(road_mid, at, 0.0, -1.0),
		"at_gate_left": look(road_mid - half + 0.35, at, 0.55, -1.0),
		"at_gate_right": look(road_mid + half - 0.35, at, -0.55, -1.0),
		"at_gate_up": look(road_mid, at, 0.0, -1.0, 0.7),
		"gate_close": {"pos": Vector3(road_mid - side * 4.0, y + 0.3, gate + 7.5),
			"target": Vector3(road_mid, y + 2.5, gate)},
		"aerial": {"pos": Vector3(road_mid - side * 14.0, 24.0, gate + 14.0),
			"target": Vector3(road_mid + side * 2.0, 0.0, gate - 4.0)},
		"aerial_behind": {"pos": Vector3(road_mid - side * 6.0, 32.0, gate - 34.0),
			"target": Vector3(road_mid - side * 4.0, 0.0, gate - 8.0)},
	}


## Im Laden: ein paar Blicke für Änderungen innen.
static func shop() -> Dictionary:
	return {
		"room_back": {"pos": Vector3(1.5, 1.6, 3.0), "target": Vector3(-1.5, 1.2, -3.0)},
		"room_front": {"pos": Vector3(-1.0, 1.6, -2.0), "target": Vector3(2.0, 1.2, 3.5)},
		"door_outside": look(StreetLayout.door_center().x - 3.0, StreetLayout.door_center().z - 3.0, 1.0, 1.0),
	}
