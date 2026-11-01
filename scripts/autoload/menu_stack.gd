extends Node
## Merkt sich, was gerade offen ist (Gestaltungsmodus, Menüs, später der Shop).
##
## Regel für das ganze Spiel: Esc schließt immer zuerst das, was zuletzt geöffnet
## wurde. Nur wenn nichts offen ist, öffnet Esc das Pausenmenü.
##
## So meldet sich etwas an: MenuStack.open(self) beim Öffnen, MenuStack.close(self)
## beim Schließen. Der Knoten braucht eine Funktion close_from_escape(), die ihn schließt.
## Optional: restore_mouse_mode(), um nach dem Pausenmenü den passenden Mauszustand
## wiederherzustellen (z. B. sichtbarer Mauszeiger im Katalog).

var _open: Array[Node] = []


func open(node: Node) -> void:
	if not _open.has(node):
		_open.append(node)


func close(node: Node) -> void:
	_open.erase(node)


## Ist gerade irgendetwas offen?
func has_open() -> bool:
	_forget_freed()
	return not _open.is_empty()


## Schließt das Oberste. Liefert true, wenn etwas geschlossen wurde.
func close_top() -> bool:
	_forget_freed()
	if _open.is_empty():
		return false
	_open.back().close_from_escape()
	return true


## Stellt den Mauszustand für das, was gerade oben liegt, wieder her.
func restore_mouse_mode() -> void:
	_forget_freed()
	if not _open.is_empty() and _open.back().has_method("restore_mouse_mode"):
		_open.back().restore_mouse_mode()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _forget_freed() -> void:
	_open = _open.filter(func(node: Node) -> bool: return is_instance_valid(node))
