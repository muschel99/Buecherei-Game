extends Node3D
## Das Tablet auf der Theke: Mit E öffnet sich der Shop (ShopWindow).

func _on_interactable_interacted(_interactor: Node) -> void:
	get_tree().call_group(ShopWindow.GROUP, "open_shop")
