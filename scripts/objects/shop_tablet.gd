extends Node3D
## Das Tablet auf der Theke: Mit E öffnet sich das Theken-Tablet mit seinen Apps (CounterTablet).

func _on_interactable_interacted(_interactor: Node) -> void:
	get_tree().call_group(CounterTablet.GROUP, "open_tablet")
