extends Node3D
## Die Theke im Laden. Sie gehört fest zum Laden (siehe data/furniture/counter_register.tres:
## is_fixed, is_essential) und lässt sich nur verschieben, nicht wegräumen.
##
## Wie sie aussieht, holt sie sich zentral von CounterStyle: Jede Theken-Variante ist ein
## Datenblatt (CounterData in data/counters/) mit eigenem Modell, das hier unter "Model"
## eingesetzt wird. Wähle ich am Tablet (App "Fassade") eine andere Theke, meldet CounterStyle das
## über sein Signal "changed", und das Modell wird sofort getauscht. Kollision und Ablagefläche
## bleiben gleich (alle Theken sind gleich groß, Platte genau auf 1 m).
##
## Module (z. B. später eine Backshop-Auslage oder ein Kaffeeautomat) hängen unter dem Knoten
## "Modules" – die Struktur steht bereit, umgesetzt wird davon noch nichts.

## Pfad des gerade eingesetzten Modells (getauscht wird nur, wenn sich etwas ändert).
var _model_path: String = ""


func _notification(what: int) -> void:
	# Gleich beim Erzeugen das richtige Modell einsetzen – noch bevor z. B. die Vorschau im
	# Gestaltungsmodus die Teile blau einfärbt
	if what == NOTIFICATION_SCENE_INSTANTIATED and not Engine.is_editor_hint():
		_apply_style()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	CounterStyle.changed.connect(_apply_style)
	_apply_style()


## Setzt das Modell der gewählten Theke unter "Model" ein (das bisherige fliegt raus).
func _apply_style() -> void:
	var data := CounterStyle.get_style()
	var model_root := get_node_or_null("Model") as Node3D
	if data == null or model_root == null or data.scene_path == _model_path:
		return
	# Steckt schon das richtige Modell in der Szene (Standard-Theke), bleibt es
	if model_root.get_child_count() == 1 and model_root.get_child(0).scene_file_path == data.scene_path:
		_model_path = data.scene_path
		return
	var packed := load(data.scene_path) as PackedScene if ResourceLoader.exists(data.scene_path) else null
	if packed == null:
		push_warning("Theke '%s': Modell '%s' nicht gefunden." % [data.display_name, data.scene_path])
		return
	for child in model_root.get_children():
		model_root.remove_child(child)
		# Beim Erzeugen ist die Theke noch nicht in der Szene: dann gleich freigeben
		if is_inside_tree():
			child.queue_free()
		else:
			child.free()
	var model := packed.instantiate()
	model.name = "CounterModel"
	model_root.add_child(model)
	_model_path = data.scene_path
