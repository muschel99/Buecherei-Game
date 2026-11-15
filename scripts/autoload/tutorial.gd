extends Node
## Autoload „Tutorial“ (seit dem Story-Anfang, Wünsche der Entwicklerin): Zuerst übergibt die Maklerin das Haus (StoryIntro,
## scripts/story/), danach erscheinen am Rand kleine To-do-Zettel für die ersten Schritte (TodoNote im HUD). Texte der Zettel:
## data/tutorial/todo.txt (Überschrift, Aufgaben mit Kennung). Erledigt ist eine Aufgabe, sobald ihre Kennung gemeldet wurde
## (report(kennung) an der passenden Stelle im Spiel) oder eine Prüfung hier sie erkennt (_poll: Regal steht, Bücher im Regal,
## Schild offen). Was schon vorher erledigt war, ist gleich abgehakt; ist ein Zettel fertig, kommt nach todo_next_delay der
## nächste. Ein neues Spiel ruft start_new_game(); ältere Spielstände ohne diesen Eintrag sehen weder Maklerin noch Zettel.

signal intro_finished
## Etwas auf den Zetteln hat sich geändert (abgehakt oder neuer Zettel)
signal todo_changed

const TODO_PATH := "res://data/tutorial/todo.txt"

var save_key: String = "tutorial"

## Hat die Maklerin alles gezeigt? (false = die Geschichte läuft bzw. beginnt beim nächsten Start von vorn)
var intro_done := true
## Welcher Zettel gerade dran ist (-1 = keine Zettel, z. B. alter Spielstand; = Anzahl = alle fertig)
var list_index := -1
## Schon erledigte Kennungen (auch die, deren Zettel noch nicht dran ist)
var events: Dictionary = {}

var _lists: Array[Dictionary] = []
var _next_timer := -1.0
var _poll_timer := 0.0


func _ready() -> void:
	add_to_group(SaveManager.PERSIST_GROUP)
	_lists = load_lists()
	GameClock.woke_up.connect(_on_woke_up)


func _process(delta: float) -> void:
	if not is_tracking():
		return
	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = 0.5
		_poll()
	if _next_timer >= 0.0:
		_next_timer -= delta
		if _next_timer < 0.0:
			_advance()


## Neues Spiel: die Geschichte beginnt (nach SaveManager.reset_to_start). Die Bücherei ist anfangs noch geschlossen – das
## Schild umzudrehen ist eine der ersten Aufgaben.
func start_new_game() -> void:
	intro_done = false
	list_index = 0
	events = {}
	_next_timer = -1.0
	Lending.set_open(false)


## Die Maklerin hat alles gezeigt und den Schlüssel übergeben: der erste Zettel erscheint.
func finish_intro() -> void:
	if intro_done:
		return
	intro_done = true
	intro_finished.emit()
	_skip_finished_lists()
	todo_changed.emit()
	SaveManager.request_save()


## Werden gerade Aufgaben gezählt? (neues Spiel, noch nicht alle Zettel fertig)
func is_tracking() -> bool:
	return list_index >= 0 and list_index < _lists.size()


## Der Zettel, der gerade am Rand hängt ({} = keiner): {"title": …, "tasks": [{"id", "text", "action"}]}.
func current_list() -> Dictionary:
	if not intro_done or not is_tracking():
		return {}
	return _lists[list_index]


func is_done(id: String) -> bool:
	return events.has(id)


## Etwas ist passiert (Kennung aus data/tutorial/todo.txt). Wird auch schon während der Geschichte gezählt.
func report(id: String) -> void:
	if not is_tracking() or events.has(id):
		return
	events[id] = true
	todo_changed.emit()
	if intro_done and _list_complete(list_index) and _next_timer < 0.0:
		_next_timer = GameConfig.todo_next_delay
	SaveManager.request_save()


func _list_complete(index: int) -> bool:
	for task: Dictionary in (_lists[index].tasks as Array):
		if not events.has(String(task.id)):
			return false
	return true


func _advance() -> void:
	list_index += 1
	_skip_finished_lists()
	todo_changed.emit()
	SaveManager.request_save()


## Zettel, deren Aufgaben schon alle erledigt sind, gar nicht erst zeigen.
func _skip_finished_lists() -> void:
	while is_tracking() and _list_complete(list_index):
		list_index += 1


## Zustände, die man besser nachsieht als meldet (sie können auf vielen Wegen entstehen).
func _poll() -> void:
	if Lending.is_open:
		report("open_sign")
	var room := Lending.find_room()
	if room == null:
		return
	var furniture := room.get_node_or_null("Furniture")
	if furniture and not events.has("shelf_placed"):
		for item in furniture.get_children():
			if item is PlacedFurniture and (item as PlacedFurniture).data \
					and (item as PlacedFurniture).data.subcategory == "bookshelf":
				report("shelf_placed")
				break
	if not events.has("shelved"):
		for shelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
			if shelf.is_inside_tree() and room.is_ancestor_of(shelf) and not (shelf.get_books() as Array).is_empty():
				report("shelved")
				break


func _on_woke_up() -> void:
	report("slept")


func get_save_data() -> Dictionary:
	return {"intro_done": intro_done, "list": list_index, "events": events.keys()}


func load_save_data(data: Dictionary) -> void:
	intro_done = bool(data.get("intro_done", true))
	list_index = int(data.get("list", -1))
	events = {}
	for id: Variant in data.get("events", []):
		events[str(id)] = true
	_next_timer = -1.0
	if intro_done:
		_skip_finished_lists()


## Zettel aus data/tutorial/todo.txt.
static func load_lists() -> Array[Dictionary]:
	var lists: Array[Dictionary] = []
	var file := FileAccess.open(TODO_PATH, FileAccess.READ)
	while file and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			lists.append({"title": line.trim_prefix("==").strip_edges(), "tasks": []})
			continue
		if lists.is_empty():
			continue
		var parts := line.split("|")
		if parts.size() < 2:
			continue
		var task := {"id": parts[0].strip_edges(), "text": parts[1].strip_edges(),
			"action": parts[2].strip_edges() if parts.size() > 2 else ""}
		(lists[lists.size() - 1].tasks as Array).append(task)
	return lists
