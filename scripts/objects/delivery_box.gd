class_name DeliveryBox
extends Node3D
## Ein Lieferkarton vor der Tür. Mit E wird er ausgepackt: Der Inhalt wandert direkt ins
## Inventar, der Karton schrumpft sanft und verschwindet.
##
## Den Inhalt trägt der Lieferdienst (DeliveryManager) ein, als Liste von Einträgen
## { "kind": "furniture" oder "surface", "id": "...", "count": Anzahl }.

## Wird gesendet, sobald der Karton ausgepackt ist (der Inhalt liegt dann im Inventar).
signal unpacked(box: DeliveryBox)

@onready var _interactable: Interactable = $Interactable
@onready var _body: StaticBody3D = $Body

var contents: Array = []


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_interactable.prompt_text = "Lieferung auspacken"


func _on_interacted(_interactor: Node) -> void:
	unpack()


## Legt den Inhalt ins Inventar und lässt den Karton sanft verschwinden.
func unpack() -> void:
	if not _interactable.is_enabled:
		return
	_interactable.is_enabled = false
	_body.collision_layer = 0
	for entry in contents:
		var id := str(entry.get("id", ""))
		if entry.get("kind") == "surface":
			Inventory.add_surface(id)
		else:
			Inventory.add_furniture(id, int(entry.get("count", 1)))
	Notice.post(self, "Ausgepackt: %s – liegt jetzt im Inventar." % describe_contents(contents))
	unpacked.emit(self)
	# Kleine Animation: Der Karton plustert sich kurz auf, hebt sich, dreht sich und
	# schrumpft dabei zu nichts – alles zusammen dauert GameConfig.unpack_time
	var duration := GameConfig.unpack_time
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector3.ONE * 1.12, duration * 0.25)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, duration * 0.75).set_delay(duration * 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + 0.25, duration)
	tween.tween_property(self, "rotation:y", rotation.y + PI * 0.5, duration)
	tween.chain().tween_callback(queue_free)


## Kurze Beschreibung des Inhalts, z. B. "Ohrensessel ×2, Kalkweiß".
static func describe_contents(entries: Array) -> String:
	var parts: Array[String] = []
	for entry in entries:
		var id := str(entry.get("id", ""))
		var resource: Resource = Catalog.get_surface(id) if entry.get("kind") == "surface" else Catalog.get_furniture(id)
		var item_name: String = resource.display_name if resource else id
		var count := int(entry.get("count", 1))
		parts.append(item_name if count <= 1 else "%s ×%d" % [item_name, count])
	return ", ".join(parts)
