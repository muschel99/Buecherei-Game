extends Node3D
## Lichtschalter: schaltet mit E alle Lampen im selben Raum.
##
## Ist mindestens eine Lampe an, gehen alle aus – sonst gehen alle an.
## Als Lampe zählt alles, was eine Funktion set_on() und eine Variable is_on hat
## (z. B. die Stehlampe, scripts/objects/floor_lamp.gd).

@onready var _interactable: Interactable = $Interactable


func _process(_delta: float) -> void:
	# Hinweistext passend zum aktuellen Zustand der Lampen
	var lamps := _find_lamps()
	if lamps.is_empty():
		_interactable.prompt_text = "Lichtschalter (keine Lampe im Raum)"
	elif _any_on(lamps):
		_interactable.prompt_text = "Licht im Raum ausschalten"
	else:
		_interactable.prompt_text = "Licht im Raum einschalten"


func _on_interactable_interacted(_interactor: Node) -> void:
	var lamps := _find_lamps()
	var turn_on := not _any_on(lamps)
	for lamp in lamps:
		lamp.set_on(turn_on)


func _any_on(lamps: Array[Node]) -> bool:
	for lamp in lamps:
		if lamp.is_on:
			return true
	return false


## Sucht den Raum, in dem der Schalter hängt, und fragt ihn nach seinen Lampen.
func _find_lamps() -> Array[Node]:
	var node: Node = get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node == null:
		return []
	return (node as Room).get_lamps()
