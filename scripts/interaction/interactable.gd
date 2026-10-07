class_name Interactable
extends Area3D
## Wiederverwendbarer Baustein für alles, womit man per E interagieren kann.
##
## So machst du ein Objekt interaktiv:
## 1. Füge dem Objekt einen Kind-Knoten vom Typ "Interactable" hinzu.
## 2. Gib dem Interactable eine CollisionShape3D, die das Objekt umschließt.
## 3. Trage im Inspektor bei "Prompt Text" ein kurzes Wort ein (z. B. "Öffnen"). Es erscheint
##    neben dem E-Symbol unter der Bildmitte (je nach Einstellung "Hinweise").
## 4. Verbinde das Signal "interacted" mit einer Funktion deines Objekts.
## Bücher nutzen zusätzlich die Maustasten (Tasten siehe Aktionen "book_take"/"book_place"):
## - Signal "take_requested": ein Buch nehmen (rechte Maustaste), Wort in take_text.
## - Signal "place_requested": das Buch obenauf abstellen (linke Maustaste kurz) – nur bei
##   Objekten mit handles_placing (z. B. Regal); sonst legt es die Spielfigur frei in die Welt.
## - Signal "place_all_requested": alle passenden Bücher einräumen (linke Maustaste halten) –
##   nur bei supports_place_all.
## Ein Menü zum Objekt (z. B. Regal-Menü) öffnet die Taste der Aktion "open_menu" (R):
## Signal "menu_requested", Wort in menu_text (leer = kein Menü). Bewusst eine eigene Taste,
## damit sich nie aus Versehen ein Menü öffnet.
##
## Man muss nicht genau den Interactable-Bereich treffen: Schaut man auf den festen Körper
## des Objekts (z. B. von oben auf einen Karton oder von hinten auf einen Sessel), findet
## find_for() das passende Interactable desselben Objekts (siehe Spielfigur).

## Wird gesendet, wenn die Spielfigur E drückt, während sie das Objekt ansieht.
## (Bei supports_hold: wenn E kurz getippt wurde.)
signal interacted(interactor: Node)
## Nur bei supports_hold: E wurde gedrückt gehalten (GameConfig.interact_hold_time).
signal held(interactor: Node)
## Ein Buch nehmen (rechte Maustaste), während die Spielfigur das Objekt ansieht.
signal take_requested(interactor: Node)
## Das Buch obenauf hier abstellen (linke Maustaste kurz) – nur bei handles_placing.
signal place_requested(interactor: Node)
## Alle passenden Bücher hier einräumen (linke Maustaste gehalten) – nur bei supports_place_all.
signal place_all_requested(interactor: Node)
## Das Menü dieses Objekts öffnen (R) – nur, wenn menu_text nicht leer ist.
signal menu_requested(interactor: Node)
## Wird jedes Bild gesendet, solange die Spielfigur das Objekt ansieht – mit Blickstrahl
## (Start und Richtung in der Welt). So kann ein Regal z. B. das angeschaute Buch finden.
signal aimed(from: Vector3, direction: Vector3)
## Die Spielfigur schaut nicht mehr hin.
signal aim_ended

## Kurzes Wort neben dem E-Symbol unter der Bildmitte (z. B. "Öffnen"), leer = kein E-Symbol.
@export var prompt_text: String = "Benutzen"
## Wort für langes Drücken (E-Symbol mit Ring), leer = keins.
@export var hold_prompt_text: String = ""
## Wort neben dem Symbol fürs Buch-Nehmen (rechte Maustaste, z. B. "Nehmen"), leer = keins.
@export var take_text: String = ""
## Wort neben dem R-Symbol (z. B. "Menü"), leer = dieses Objekt hat kein Menü.
@export var menu_text: String = ""
## Kann man E auch gedrückt halten (halten = eigene, lange Aktion)?
## Dann zählt ein kurzes Tippen erst beim Loslassen. (Gerade nutzt das kein Objekt.)
@export var supports_hold: bool = false
## Nimmt dieses Objekt Bücher selbst entgegen (linke Maustaste, z. B. Regal)? Sonst legt die
## Spielfigur das Buch frei in die Welt (LooseBooks).
@export var handles_placing: bool = false
## Kann man die linke Maustaste gedrückt halten, um alle passenden Bücher einzuräumen?
## Dann zählt ein kurzer Klick erst beim Loslassen.
@export var supports_place_all: bool = false
## Soll das ganze Objekt aufleuchten, wenn man es ansieht? (Regale heben stattdessen das
## angeschaute Buch hervor.)
@export var highlight_owner: bool = true
## Ausgeschaltete Interactables werden ignoriert.
@export var is_enabled: bool = true
## Größere Reichweite (GameConfig.long_interaction_distance), z. B. für Deckenlampen,
## die man vom Boden aus nicht so gut erreicht.
@export var long_reach: bool = false

const INTERACTABLE_LAYER := 2  # Physik-Ebene "interactable"


func _ready() -> void:
	# Nur auf der Ebene "interactable" liegen, selbst nichts erkennen müssen
	collision_layer = 0
	set_collision_layer_value(INTERACTABLE_LAYER, true)
	collision_mask = 0
	monitoring = false


## Wenn der Blick einen festen Körper trifft (Kollision eines Möbels, Kartons, Türblatts):
## das Interactable, das zu diesem Objekt gehört – oder null.
## Gesucht wird von dem getroffenen Körper aus nach oben, aber nur innerhalb des Objekts
## (Halt an PlacedFurniture und am Raum). Hat das Objekt mehrere (z. B. drei Sofaplätze),
## gilt das, das dem getroffenen Punkt am nächsten liegt.
static func find_for(collider: Node, hit_point: Vector3) -> Interactable:
	var node := collider.get_parent() if collider else null
	var depth := 0
	while node and depth < 4 and not node is PlacedFurniture and not node is Room and not node is Window:
		var best: Interactable = null
		var best_distance := INF
		for child in node.get_children():
			# direkt darunter oder eine Ebene tiefer (z. B. Seating/Interactable)
			var candidates: Array = [child]
			if not child is CollisionObject3D:
				candidates.append_array(child.get_children())
			for candidate in candidates:
				if candidate is Interactable and candidate.is_enabled:
					var distance: float = candidate.global_position.distance_to(hit_point)
					if distance < best_distance:
						best = candidate
						best_distance = distance
		if best:
			return best
		node = node.get_parent()
		depth += 1
	return null


## Wird von der Spielfigur aufgerufen.
func interact(interactor: Node) -> void:
	if is_enabled:
		interacted.emit(interactor)


## Wird von der Spielfigur aufgerufen, wenn E lange genug gehalten wurde.
func hold(interactor: Node) -> void:
	if is_enabled:
		held.emit(interactor)


## Buch nehmen (von der Spielfigur aufgerufen).
func request_take(interactor: Node) -> void:
	if is_enabled:
		take_requested.emit(interactor)


## Buch obenauf abstellen (von der Spielfigur aufgerufen).
func request_place(interactor: Node) -> void:
	if is_enabled:
		place_requested.emit(interactor)


## Alle passenden Bücher einräumen (von der Spielfigur aufgerufen, linke Maustaste gehalten).
func request_place_all(interactor: Node) -> void:
	if is_enabled:
		place_all_requested.emit(interactor)


## Menü öffnen (von der Spielfigur aufgerufen, Taste R).
func request_menu(interactor: Node) -> void:
	if is_enabled and not menu_text.is_empty():
		menu_requested.emit(interactor)


## Wird von der Spielfigur jedes Bild aufgerufen, solange sie hinschaut.
func update_aim(from: Vector3, direction: Vector3) -> void:
	if is_enabled:
		aimed.emit(from, direction)


## Wird von der Spielfigur aufgerufen, wenn sie wegschaut.
func end_aim() -> void:
	aim_ended.emit()
