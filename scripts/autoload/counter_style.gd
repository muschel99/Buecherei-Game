extends Node
## Der Stil der (fest verbauten) Theke.
##
## Dieses Autoload ist die eine zentrale Stelle für den Theken-Stil. Es ist bewusst von überall
## aufrufbar (CounterStyle.set_style("wood_dark")), damit die Stilauswahl später leicht auch an
## einer anderen Stelle als der Fassaden-App angeboten werden kann (z. B. direkt beim Anschauen
## der Theke). Die Theke selbst (scenes/furniture/counter.tscn, Script counter.gd) hört auf das
## Signal "changed" und färbt sich entsprechend.
##
## Neue Stilvariante: einfach einen Eintrag in STYLES ergänzen (id, Name und die drei Farben
## für Korpus, Frontblende und Platte). Kein weiterer Code nötig.
##
## Module (z. B. Backshop-Auslage, Kaffeeautomat) sind vorgesehen: Sie hängen in der Theken-
## Szene unter dem Knoten "Modules" und werden hier in "modules" mitgespeichert. Umgesetzt wird
## davon in Etappe 4a noch nichts – die Struktur steht aber bereit.

## Wird gesendet, wenn sich der Stil (oder später die Module) der Theke ändern.
signal changed

## Platzhalter-Stilvarianten der Theke. Farben als Platzhalter – leicht austauschbar.
const STYLES := [
	{"id": "wood_warm", "name": "Schlichtes Holz",
		"cabinet": Color(0.47, 0.33, 0.21), "panel": Color(0.56, 0.41, 0.27), "top": Color(0.69, 0.53, 0.35)},
	{"id": "wood_dark", "name": "Dunkles Holz",
		"cabinet": Color(0.23, 0.16, 0.11), "panel": Color(0.30, 0.21, 0.15), "top": Color(0.40, 0.29, 0.20)},
	{"id": "painted_light", "name": "Hell lackiert",
		"cabinet": Color(0.90, 0.89, 0.85), "panel": Color(0.82, 0.80, 0.75), "top": Color(0.70, 0.55, 0.37)},
]

## Name im Spielstand.
var save_key: String = "counter"
## Kennung der gewählten Stilvariante.
var style_id: String = ""
## Später aktive Module (Platzhalter für Etappe 4b+). Liste von Modul-Kennungen.
var modules: Array = []


func _ready() -> void:
	if style_id.is_empty():
		style_id = GameConfig.counter_default_style
	add_to_group(SaveManager.PERSIST_GROUP)


## Alle Stilvarianten (für die Auswahl in der App).
func get_all_styles() -> Array:
	return STYLES


## Datenblatt der gewählten Variante (unbekannte Kennung = die erste).
func get_style() -> Dictionary:
	return get_style_data(style_id)


## Datenblatt einer bestimmten Variante (unbekannte Kennung = die erste).
func get_style_data(id: String) -> Dictionary:
	for style in STYLES:
		if style["id"] == id:
			return style
	return STYLES[0]


## Wählt eine Stilvariante. notify = false: still (beim Start und Laden – kein Speichern).
func set_style(id: String, notify: bool = true) -> void:
	var data := get_style_data(id)
	if data["id"] == style_id:
		return
	style_id = data["id"]
	changed.emit()
	if notify:
		SaveManager.request_save()


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	return {"style": style_id, "modules": modules.duplicate()}


func load_save_data(data: Dictionary) -> void:
	modules = data.get("modules", []) if data.get("modules") is Array else []
	set_style(str(data.get("style", GameConfig.counter_default_style)), false)
	changed.emit()
