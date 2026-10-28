extends Node
## Welche Theke im Laden steht (die feste Theke, verschiedene Modelle je Stil).
##
## Dieses Autoload ist die eine zentrale Stelle für die Theken-Variante. Es ist bewusst von überall
## aufrufbar (CounterStyle.set_style("counter_country")), damit die Auswahl später leicht auch an
## einer anderen Stelle als der Fassaden-App angeboten werden kann (z. B. direkt beim Anschauen
## der Theke). Die Theke selbst (scenes/furniture/counter.tscn, Script counter.gd) hört auf das
## Signal "changed" und setzt das passende Modell ein.
##
## Die Varianten sind Datenblätter (CounterData) in data/counters/ – neue Theke = Modell +
## Datenblatt, kein Code. Ältere Spielstände mit den früheren Farb-Varianten ("wood_warm" …)
## finden ihre Theke über CounterData.legacy_ids.
##
## Module (z. B. Backshop-Auslage, Kaffeeautomat) sind vorgesehen: Sie hängen in der Theken-
## Szene unter dem Knoten "Modules" und werden hier in "modules" mitgespeichert. Umgesetzt ist
## davon noch nichts – die Struktur steht aber bereit.

## Wird gesendet, wenn sich die Theke (oder später die Module) ändern.
signal changed

## Name im Spielstand.
var save_key: String = "counter"
## Kennung der gewählten Theke (CounterData).
var style_id: String = ""
## Später aktive Module (Platzhalter). Liste von Modul-Kennungen.
var modules: Array = []


func _ready() -> void:
	if style_id.is_empty():
		style_id = _resolve(GameConfig.counter_default_style)
	add_to_group(SaveManager.PERSIST_GROUP)


## Alle Theken-Varianten (für die Auswahl in der App).
func get_all_styles() -> Array[CounterData]:
	return Catalog.get_all_counters()


## Datenblatt der gewählten Theke (null nur, wenn es gar keine gibt).
func get_style() -> CounterData:
	return get_style_data(style_id)


## Datenblatt einer bestimmten Theke (unbekannte Kennung = die Standard-Theke bzw. die erste).
func get_style_data(id: String) -> CounterData:
	var data := Catalog.get_counter(id)
	if data == null:
		data = Catalog.get_counter(GameConfig.counter_default_style)
	if data == null:
		var all := Catalog.get_all_counters()
		data = all[0] if not all.is_empty() else null
	return data


## Wählt eine Theke. notify = false: still (beim Start und Laden – kein Speichern).
func set_style(id: String, notify: bool = true) -> void:
	var resolved := _resolve(id)
	if resolved == style_id:
		return
	style_id = resolved
	changed.emit()
	if notify:
		SaveManager.request_save()


## Kennung, unter der die Theke im Katalog steht (frühere Kennungen werden übersetzt).
func _resolve(id: String) -> String:
	var data := get_style_data(id)
	return data.get_id() if data else id


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	return {"style": style_id, "modules": modules.duplicate()}


func load_save_data(data: Dictionary) -> void:
	modules = data.get("modules", []) if data.get("modules") is Array else []
	set_style(str(data.get("style", GameConfig.counter_default_style)), false)
	changed.emit()
