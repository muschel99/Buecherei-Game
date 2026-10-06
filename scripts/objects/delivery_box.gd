class_name DeliveryBox
extends Node3D
## Ein Lieferkarton vor der Tür (ein Karton pro Objekt). Mit E wird er ausgepackt: Der Inhalt
## wandert direkt ins Inventar, der Karton schrumpft sanft und verschwindet.
## Wo er steht und wie er gestapelt wird, bestimmt der Lieferdienst (DeliveryManager).
##
## Den Inhalt trägt der Lieferdienst (DeliveryManager) ein, als Liste von Einträgen
## { "kind": "furniture" oder "surface", "id": "...", "count": Anzahl }.

## Wird gesendet, sobald der Karton ausgepackt ist (der Inhalt liegt dann im Inventar).
signal unpacked(box: DeliveryBox)

@onready var _interactable: Interactable = $Interactable
@onready var _body: StaticBody3D = $Body

var contents: Array = []
## Wie schief der Karton steht (-1 bis 1, fest für jeden Karton).
var turn: float = 0.0
## Steht noch ein Karton auf diesem? (Dann schrumpft er beim Auspacken an Ort und Stelle.)
var covered: bool = false

var _move_tween: Tween


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_interactable.prompt_text = "Lieferung auspacken"


func _on_interacted(_interactor: Node) -> void:
	unpack()


## Bewegt den Karton sanft an eine neue Stelle (z. B. Nachrutschen im Stapel).
## delay: so lange vorher warten; appear: erst beim Losgehen sichtbar werden.
func move_to(target: Transform3D, duration: float, delay: float = 0.0, bounce: bool = false, appear: bool = false) -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	if delay > 0.0:
		_move_tween.tween_interval(delay)
	if appear:
		_move_tween.tween_callback(show)
	var step := _move_tween.tween_property(self, "transform", target, duration)
	if bounce:
		step.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Legt den Inhalt ins Inventar und lässt den Karton sanft verschwinden.
func unpack() -> void:
	if not _interactable.is_enabled:
		return
	_interactable.is_enabled = false
	if _move_tween:
		_move_tween.kill()
	show()
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
	# schrumpft dabei zu nichts – alles zusammen dauert GameConfig.unpack_time.
	# Steht noch etwas auf ihm, schrumpft er nur an Ort und Stelle (die oberen rutschen nach).
	var duration := GameConfig.unpack_time
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	if not covered:
		tween.tween_property(self, "scale", Vector3.ONE * 1.12, duration * 0.25)
		tween.tween_property(self, "position:y", position.y + 0.25, duration)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, duration * 0.75).set_delay(duration * 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
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
	# Bei großen Lieferungen nur die ersten drei nennen, damit der Hinweis kurz bleibt
	if parts.size() > 3:
		var more := parts.size() - 3
		parts.resize(3)
		parts.append("und %d weitere" % more if more > 1 else "und 1 weiteres")
	return ", ".join(parts)
