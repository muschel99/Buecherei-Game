@tool
class_name ColorVariant
extends Resource
## Eine Farbvariante eines Möbelstücks (z. B. „Bordeaux“ beim Ledersessel).
##
## Eingefärbt werden nur die Teile, deren Material so heißt wie ein Eintrag in "colors"
## (z. B. "fabric" = Stoff, "leather" = Leder, "bloom" = Blüten). Alle anderen Teile (z. B. das
## Holzgestell) bleiben, wie sie sind. Das klappt auch mit eigenen Modellen: Im Blender das
## Material genauso nennen (Anleitung: docs/ASSET_GUIDE.md, „Farbvarianten“).
## Im Inventar ist jede Farbe ein eigener Eintrag; gespeichert wird die id.

## Eindeutiger Name innerhalb des Möbelstücks, z. B. "bordeaux" (steht im Spielstand –
## nach dem ersten Benutzen nicht mehr ändern).
@export var id: String = ""
## Name im Spiel, z. B. „Bordeaux“ (erscheint im Tooltip).
@export var display_name: String = ""
## Materialname -> neue Grundfarbe. Beispiel: { "fabric": Bordeaux, "piping": Gold }.
@export var colors: Dictionary[String, Color] = {}
## Farbe des kleinen Farbtupfers im Shop (Alpha 0 = die erste Farbe aus "colors").
@export var swatch: Color = Color(0, 0, 0, 0)


## Farbe des Farbtupfers.
func get_swatch() -> Color:
	if swatch.a > 0.0:
		return swatch
	for key in colors:
		return colors[key]
	return Color(0.8, 0.75, 0.65)


## Neue Grundfarbe für ein Material dieses Namens (oder null, wenn es nicht eingefärbt wird).
## Blender hängt an doppelte Namen ".001" an – das zählt mit („fabric.001“ = „fabric“).
func color_for(material_name: String) -> Variant:
	var key := material_name.to_lower()
	var dot := key.find(".")
	if dot > 0 and key.substr(dot + 1).is_valid_int():
		key = key.substr(0, dot)
	for name in colors:
		if name.to_lower() == key:
			return colors[name]
	return null
