class_name FacadeLayout
extends RefCounted
## Wo an der Bücherei welche Öffnung sitzt (seit Etappe 6c) – berechnet aus der Wahl (FacadeDesign):
## die beiden Schaufenster, die Tür (mit Seiten- und Oberlichtern) und die Fenster oben.
##
## Alle Lagen in Raumkoordinaten des Ladens (Ladenboden y = 0). Jede Wand der Fassade ist ein
## Stück des äußeren Grundrisses (wie in tools/blender/build_storybook_library.py) mit eigenem
## Rahmen: x entlang der Wand (vom Anfang p0), y nach oben, z nach draußen. Die Außenseite der
## Ladenwände liegt bei z = 0, ihre Innenseite bei z = -WALL_THICKNESS.

## Außenseite des Grundrisses (wie OUT in den Bau-Scripts, Godot: x, z): hinten, rechts, vorn, Schräge, links
const OUTLINE: Array[Vector2] = [Vector2(-3.2, 4.2), Vector2(3.2, 4.2), Vector2(3.2, -4.2), Vector2(-1.0828, -4.2), Vector2(-3.2, -2.0828)]
const SEGMENT_INDEX := {"back": 0, "right": 1, "front": 2, "diag": 3, "left": 4}
const WALL_THICKNESS := 0.2
## Höhen: Gehweg, Unterkante Schildbalken, Oberkante Ladengesims, Traufe (wie GROUND/FASCIA/TOP/E)
const GROUND := -0.5
const FASCIA_BOTTOM := 2.78
const TOP := 3.42
const EAVES := 6.42
## Schaufenster: Mitte entlang der Wand (vorn, links)
const SHOP_WINDOWS := {"front": 2.2, "left": 3.0828}
## Tür: Mitte der Schräge; Türblatt (Breite, Höhe, Bogen-Kämpfer bei runden Blättern)
const LEAF_W := 1.0
const LEAF_H := 2.2
const CASING := 0.05
const MULLION := 0.04
## Briefkasten-Platte (Mitte entlang der Schräge, Höhe, Breite x Höhe) – bleibt frei
const SLOT_U := 2.555
const SLOT_Y := 1.0
const SLOT_BOARD := Vector2(0.5, 0.46)


## Rahmen einer Wand (Ursprung p0 auf Ladenboden-Höhe, x entlang, y oben, z nach draußen).
static func segment_frame(segment: String) -> Transform3D:
	var i: int = SEGMENT_INDEX[segment]
	var p0 := OUTLINE[i]
	var p1 := OUTLINE[(i + 1) % OUTLINE.size()]
	var along := Vector3(p1.x - p0.x, 0.0, p1.y - p0.y).normalized()
	var out := along.cross(Vector3.UP)
	return Transform3D(Basis(along, Vector3.UP, out), Vector3(p0.x, 0.0, p0.y))


static func segment_length(segment: String) -> float:
	var i: int = SEGMENT_INDEX[segment]
	return OUTLINE[i].distance_to(OUTLINE[(i + 1) % OUTLINE.size()])


## Fensterplätze oben: [Wand, Mitte entlang der Wand] – Schräge 1, vorn 2, links 3 (wie window_slots()).
static func upper_slots() -> Array:
	var slots := []
	for segment in ["diag", "front", "left"]:
		var length := segment_length(segment)
		var n := maxi(1, int(length / 2.0))
		for k in n:
			slots.append([segment, length * (k + 0.5) / n])
	return slots


## Umriss eines Fensters nach seiner Wahl (Mitte unten = 0).
static func window_outline(style: FacadeOption) -> PackedVector2Array:
	var kind := shape_kind(style.shape)
	var rise := style.rise if kind == OpeningShape.Kind.ARCH else 0.0
	return OpeningShape.outline(kind, style.opening.x, style.opening.y, rise)


static func shape_kind(shape: String) -> OpeningShape.Kind:
	match shape:
		"arch":
			return OpeningShape.Kind.ARCH
		"round":
			return OpeningShape.Kind.ROUND
	return OpeningShape.Kind.RECT


## Alle Öffnungen nach einer Wahl: je {id, segment, u (Mitte entlang der Wand), bottom (Unterkante),
## outline (Mitte unten = 0), kind ("shop", "upper", "door"), style (FacadeOption)} – für die Tür dazu
## leaf (Umriss des Türblatts) und lights (FacadeOption der Seiten-/Oberlichter).
static func openings(config: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var shop := FacadeDesign.get_option("window_ground", config)
	if shop:
		for segment: String in SHOP_WINDOWS:
			result.append({"id": "shop_" + segment, "segment": segment, "u": SHOP_WINDOWS[segment], "bottom": shop.bottom,
				"outline": window_outline(shop), "kind": "shop", "style": shop})
	var upper := FacadeDesign.get_option("window", config)
	if upper:
		var k := 0
		for slot: Array in upper_slots():
			k += 1
			result.append({"id": "upper_%d" % k, "segment": slot[0], "u": slot[1], "bottom": upper.bottom,
				"outline": window_outline(upper), "kind": "upper", "style": upper})
	result.append(door_opening(config))
	return result


## Die Tür: Umriss der ganzen Öffnung (Türblatt + Rahmen + Seiten-/Oberlichter) und des Türblatts.
static func door_opening(config: Dictionary) -> Dictionary:
	var door := FacadeDesign.get_option("door", config)
	var lights := FacadeDesign.get_option("door_lights", config)
	var round_leaf := door != null and door.shape == "arch"
	var side := lights.side_width if lights else 0.0
	var transom := lights.transom if lights else 0.0
	var width := LEAF_W + 2.0 * CASING + (2.0 * (side + MULLION) if side > 0.0 else 0.0)
	var leaf := OpeningShape.outline(OpeningShape.Kind.ARCH if round_leaf else OpeningShape.Kind.RECT, LEAF_W, LEAF_H,
		LEAF_W / 2.0)
	var outline: PackedVector2Array
	if round_leaf:
		# Bogen über die ganze Breite; mit Oberlicht liegt der Kämpfer höher (Glas im Bogen über dem Blatt)
		var spring := LEAF_H - LEAF_W / 2.0 + CASING + (transom * 0.6 if transom > 0.0 else 0.0)
		outline = OpeningShape.outline(OpeningShape.Kind.ARCH, width, spring + width / 2.0, width / 2.0)
	else:
		var height := LEAF_H + CASING + (transom + MULLION if transom > 0.0 else 0.0)
		outline = OpeningShape.outline(OpeningShape.Kind.RECT, width, height)
	return {"id": "door", "segment": "diag", "u": segment_length("diag") / 2.0, "bottom": 0.0, "outline": outline, "kind": "door",
		"style": door, "lights": lights, "leaf": leaf}


## Umriss einer Öffnung in Wand-Koordinaten (x entlang der Wand ab p0, y Höhe).
static func outline_on_wall(opening: Dictionary) -> PackedVector2Array:
	return OpeningShape.moved(opening.outline, Vector2(opening.u, opening.bottom))


## Rahmen einer Öffnung: Ursprung Mitte unten auf der Außenseite der Wand, x entlang, z nach draußen.
static func opening_frame(opening: Dictionary) -> Transform3D:
	var frame := segment_frame(opening.segment)
	return frame * Transform3D(Basis.IDENTITY, Vector3(opening.u, opening.bottom, 0.0))
