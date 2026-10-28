extends Node
## Wie die Bücherei außen aussieht (seit Etappe 6b): je Kategorie die gewählte Option (FacadeOption,
## data/facade/). Die Fassade (LibraryFacade im Raum) baut sich danach, die App „Fassade“ ändert es
## erst mit „Bauen“ (apply). Wird mit dem Spielstand gespeichert.
##
## Dazu gehört, was innen am Rückgabekasten sitzt ("slot_inside": "match" = das passende Gegenstück
## zum gewählten Einwurf, "neutral" = eine schlichte Klappe). Einwurf und Theke selbst merken sich
## ReturnBox und CounterStyle.

## Die Fassade hat sich geändert (nach „Bauen“ oder beim Laden).
signal changed

## Kategorien in der Reihenfolge der App.
const CATEGORIES: Array[String] = ["ground", "ground_color", "upper", "window", "frame_color", "awning", "fabric", "door",
	"door_color", "box", "box_plant", "basket", "basket_plant", "fullness"]
## So sah die Bücherei bisher aus (grüne Holzfront, braune Ziegel, Bogenfenster …).
const DEFAULTS := {"ground": "classic", "ground_color": "green", "upper": "brick_brown", "window": "arched", "frame_color": "cream",
	"awning": "none", "fabric": "stripes_red", "door": "glazed", "door_color": "green", "box": "wood", "box_plant": "mixed",
	"basket": "bowl", "basket_plant": "trailing_mix", "fullness": "lush", "slot_inside": "match"}

## Name im Spielstand.
var save_key: String = "facade"
## Kategorie -> id der gewählten Option (dazu "slot_inside").
var config: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	add_to_group(SaveManager.PERSIST_GROUP)


## Die gewählte Option einer Kategorie in einer Wahl (ohne Angabe: der gebauten Fassade). Unbekannte
## ids (z. B. gelöschte Datenblätter) fallen auf den Standard bzw. die erste Option zurück.
func get_option(category: String, from: Dictionary = {}) -> FacadeOption:
	var source := from if not from.is_empty() else config
	var option := Catalog.get_facade_option(category, str(source.get(category, DEFAULTS.get(category, ""))))
	if option == null:
		option = Catalog.get_facade_option(category, str(DEFAULTS.get(category, "")))
	if option == null:
		var all := Catalog.get_facade_options(category)
		option = all[0] if not all.is_empty() else null
	return option


## Eine neue Wahl übernehmen (App „Fassade“: Bauen). Unbekannte Schlüssel bleiben weg.
func apply(new_config: Dictionary) -> void:
	config = normalized(new_config)
	changed.emit()
	SaveManager.request_save()


## Was es kostet, von „from“ auf „to“ umzubauen: die Preise der geänderten Kategorien.
static func cost_of(from: Dictionary, to: Dictionary) -> int:
	var total := 0
	for category in CATEGORIES:
		if str(from.get(category, "")) != str(to.get(category, "")):
			var option := Catalog.get_facade_option(category, str(to.get(category, "")))
			if option:
				total += option.price
	return total


## Vollständige Wahl: fehlende Kategorien mit dem Standard, nur bekannte Schlüssel.
static func normalized(source: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate()
	for key in DEFAULTS:
		if source.has(key):
			result[key] = str(source[key])
	return result


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	return {"config": config.duplicate()}


func load_save_data(data: Dictionary) -> void:
	config = normalized(data.get("config", {}) if data.get("config") is Dictionary else {})
	changed.emit()
