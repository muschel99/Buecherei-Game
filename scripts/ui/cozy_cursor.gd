class_name CozyCursor
extends RefCounted
## Mauszeiger im Cozy-Stil (Wunsch der Entwicklerin nach Etappe 8b: „ein süßerer Cursor – runder Pfeil, ohne Herz“): runder
## Pfeil in Creme mit warmbraunem Rand; über Knöpfen (Zeigerform „Hand“) derselbe Pfeil in Zartrosa. Bilder aus
## tools/make_cursor.py (assets/ui/cursors/, eigene Bilder gleichen Namens werden einfach genommen). Settings ruft apply() beim
## Start auf.

const ARROW := "res://assets/ui/cursors/cursor_arrow.png"
const HOVER := "res://assets/ui/cursors/cursor_hover.png"
## Spitze des Pfeils im Bild (wie HOTSPOT in tools/make_cursor.py)
const HOTSPOT := Vector2(4, 3)


static func apply() -> void:
	var arrow := load(ARROW) as Texture2D
	var hover := load(HOVER) as Texture2D
	if arrow:
		Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, HOTSPOT)
	if hover:
		Input.set_custom_mouse_cursor(hover, Input.CURSOR_POINTING_HAND, HOTSPOT)
