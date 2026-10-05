class_name Interactable
extends Area3D
## Wiederverwendbarer Baustein für alles, womit man per E interagieren kann.
##
## So machst du ein Objekt interaktiv:
## 1. Füge dem Objekt einen Kind-Knoten vom Typ "Interactable" hinzu.
## 2. Gib dem Interactable eine CollisionShape3D, die das Objekt umschließt.
## 3. Trage im Inspektor bei "Prompt Text" den Hinweis ein (z. B. "Lampe einschalten").
## 4. Verbinde das Signal "interacted" mit einer Funktion deines Objekts.

## Wird gesendet, wenn die Spielfigur E drückt, während sie das Objekt ansieht.
signal interacted(interactor: Node)

## Hinweistext, der unten in der Bildmitte erscheint (nach "E – ").
@export var prompt_text: String = "Benutzen"
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


## Wird von der Spielfigur aufgerufen.
func interact(interactor: Node) -> void:
	if is_enabled:
		interacted.emit(interactor)
