class_name Interactable
extends Area3D
## Wiederverwendbarer Baustein für alles, womit man per E interagieren kann.
##
## So machst du ein Objekt interaktiv:
## 1. Füge dem Objekt einen Kind-Knoten vom Typ "Interactable" hinzu.
## 2. Gib dem Interactable eine CollisionShape3D, die das Objekt umschließt.
## 3. Trage im Inspektor bei "Prompt Text" den Hinweis ein (z. B. "Lampe einschalten").
## 4. Verbinde das Signal "interacted" mit einer Funktion deines Objekts.
##
## Man muss nicht genau den Interactable-Bereich treffen: Schaut man auf den festen Körper
## des Objekts (z. B. von oben auf einen Karton oder von hinten auf einen Sessel), findet
## find_for() das passende Interactable desselben Objekts (siehe Spielfigur).

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
