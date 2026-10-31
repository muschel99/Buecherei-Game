extends Node
## Wie die Bücherei außen aussieht (seit Etappe 6b): je Kategorie die gewählte Option (FacadeOption,
## data/facade/). Die Fassade (LibraryFacade im Raum) baut sich danach, die App „Fassade“ ändert es
## erst mit „Bauen“ (build_draft). Wird mit dem Spielstand gespeichert.
##
## Dazu gehört, was innen am Rückgabekasten sitzt ("slot_inside": "match" = das passende Gegenstück
## zum gewählten Einwurf, "neutral" = eine schlichte Klappe). Einwurf und Theke selbst merken sich
## ReturnBox und CounterStyle.
##
## Der Entwurf (draft): was in der App gewählt, aber noch nicht gebaut ist – dieselben Schlüssel wie
## config, dazu "counter" (CounterData-id) und "slot" (ReturnSlotData-id). Er bleibt erhalten, wenn
## das Tablet zugeht, und wird mitgespeichert; „Bauen“ setzt ihn um, „Abbrechen“ verwirft ihn.

##
## Freischaltungen (seit Etappe 6c): Jede Option ist im Datenblatt frei (unlocked) oder gesperrt. Später
## schaltet die Geschichte nach und nach mehr frei (unlock, gespeichert); die Testtaste F11 schaltet alles
## frei (unlock_all, nicht gespeichert). Gesperrtes zeigt die App ausgegraut mit Schloss.

## Die Fassade hat sich geändert (nach „Bauen“ oder beim Laden).
signal changed
## Der Entwurf hat sich geändert (Vorschau in der App).
signal draft_changed
## Etwas wurde freigeschaltet.
signal unlocks_changed

## Kategorien in der Reihenfolge der App.
const CATEGORIES: Array[String] = ["wall", "quoins", "ground", "ground_color", "fascia", "window_ground", "window", "frame_color",
	"door", "door_lights", "door_color", "awning", "fabric", "box", "basket", "plants", "fullness", "deco"]
## Zum Spielstart: eine alte, heruntergekommene Backsteinfassade (bröckelnder Putz, verwitterte Farbe).
const DEFAULTS := {"wall": "old_brick", "quoins": "none", "ground": "wall", "ground_color": "weathered_green",
	"fascia": "weathered", "window_ground": "sash", "window": "sash", "frame_color": "weathered_cream", "door": "panelled",
	"door_lights": "transom", "door_color": "weathered_green", "awning": "none", "fabric": "stripes_red", "box": "none",
	"basket": "none", "plants": "colorful", "fullness": "lush", "deco": "none", "slot_inside": "match"}
## Spielstände vor Etappe 6c (Version 1) bekommen die neue Startfassade.
const SAVE_VERSION := 2

## Name im Spielstand.
var save_key: String = "facade"
## Kategorie -> id der gewählten Option (dazu "slot_inside").
var config: Dictionary = DEFAULTS.duplicate()
## Der Entwurf der App (leer = keiner, siehe oben).
var draft: Dictionary = {}
## Von der Geschichte freigeschaltet: "kategorie/id" -> true (gespeichert).
var unlocked_ids: Dictionary = {}
## Testtaste F11: alles frei (nicht gespeichert).
var unlock_all := false


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


## Ist diese Option frei wählbar?
func is_unlocked(option: FacadeOption) -> bool:
	if option == null:
		return false
	return option.unlocked or unlock_all or unlocked_ids.has(option.category + "/" + option.id)


## Schaltet eine Option frei (später durch die Geschichte).
func unlock(category: String, id: String) -> void:
	var key := category + "/" + id
	if unlocked_ids.has(key):
		return
	unlocked_ids[key] = true
	unlocks_changed.emit()
	SaveManager.request_save()


## Testtaste F11: alles freischalten.
func unlock_everything() -> void:
	unlock_all = true
	unlocks_changed.emit()


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


# --- Entwurf (App „Fassade“) ---

## Was jetzt gebaut ist – Fassade, Theke und Einwurf in einem.
func get_built() -> Dictionary:
	var result := config.duplicate()
	result["counter"] = CounterStyle.style_id
	var box := ReturnBox.find(get_tree())
	result["slot"] = box.slot_id if box else GameConfig.return_box_default_slot
	return result


## Der Entwurf (ohne Entwurf: das, was gebaut ist).
func get_draft() -> Dictionary:
	var result := get_built()
	for key in draft:
		if result.has(key):
			result[key] = str(draft[key])
	return result


## Eine Wahl im Entwurf ändern (key = Kategorie, "slot_inside", "counter" oder "slot").
func set_draft_value(key: String, id: String) -> void:
	var next := get_draft()
	next[key] = id
	draft = next
	draft_changed.emit()
	SaveManager.request_save()


## Unterscheidet sich der Entwurf von dem, was gebaut ist?
func has_changes() -> bool:
	return get_draft() != get_built()


## Was der Entwurf kostet (nur, was sich ändert).
func get_draft_cost() -> int:
	return total_cost(get_built(), get_draft())


## Kosten von „from“ nach „to“: Fassade (cost_of) plus neue Theke und neuer Einwurf.
static func total_cost(from: Dictionary, to: Dictionary) -> int:
	var total := cost_of(from, to)
	if str(from.get("counter", "")) != str(to.get("counter", "")):
		var counter := Catalog.get_counter(str(to.get("counter", "")))
		total += counter.price if counter else 0
	if str(from.get("slot", "")) != str(to.get("slot", "")):
		var slot := Catalog.get_return_slot(str(to.get("slot", "")))
		total += slot.price if slot else 0
	return total


## „Bauen“: bezahlen und den Entwurf umsetzen. false = zu wenig Geld (nichts passiert).
func build_draft() -> bool:
	if not has_changes():
		clear_draft()
		return true
	var target := get_draft()
	var cost := get_draft_cost()
	if cost > 0 and not Wallet.spend(cost, "Fassade umgebaut"):
		return false
	CounterStyle.set_style(str(target.get("counter", CounterStyle.style_id)))
	var box := ReturnBox.find(get_tree())
	if box:
		box.set_slot(str(target.get("slot", box.slot_id)))
	draft = {}
	apply(target)
	draft_changed.emit()
	return true


## „Abbrechen“: den Entwurf verwerfen.
func clear_draft() -> void:
	if draft.is_empty():
		return
	draft = {}
	draft_changed.emit()
	SaveManager.request_save()


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	return {"version": SAVE_VERSION, "config": config.duplicate(), "draft": draft.duplicate(), "unlocked": unlocked_ids.keys()}


func load_save_data(data: Dictionary) -> void:
	unlocked_ids.clear()
	for key in data.get("unlocked", []):
		unlocked_ids[str(key)] = true
	if int(data.get("version", 1)) < SAVE_VERSION:
		# Ältere Spielstände: neue Startfassade (die Kategorien haben sich mit Etappe 6c geändert)
		config = DEFAULTS.duplicate()
		draft = {}
	else:
		config = normalized(data.get("config", {}) if data.get("config") is Dictionary else {})
		draft = (data.get("draft") as Dictionary).duplicate() if data.get("draft") is Dictionary else {}
	changed.emit()
	draft_changed.emit()
