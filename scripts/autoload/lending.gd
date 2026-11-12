extends Node
## Ausleihe der Bücherei (seit Etappe 7, Autoload "Lending"): Schild an der Tür (geöffnet/geschlossen), Leseausweise,
## verliehene Bücher (kommen nach GameConfig.loan_days Tagen über den Rückgabekasten zurück – ist er voll, auf die Theke),
## Gebühren (Wallet.earn) und die Zahlen des Tages (für den Notizzettel um 6 Uhr und die App „Statistik“).
## Wie viele Besucher heute kommen, plant Lending morgens (Tickets über den Tag verteilt); LibraryVisits fragt beim
## Vorbeigehen eines Passanten mit want_visitor(), ob jetzt jemand hereinkommt.
##
## Im Code: Lending.is_open, Lending.set_open(true), Lending.lend(bücher, neu), Lending.today, Lending.history.

signal open_changed(open: bool)
## Die Zahlen des Tages haben sich geändert (Besucher, Ausleihen, Rückgaben, Einnahmen).
signal stats_changed
## Ein Tag ist abgeschlossen (Zahlen des Vortags, für den Notizzettel).
signal day_closed(stats: Dictionary)

const ROOM_GROUP := &"library_room"

var save_key: String = "lending"
## Schild an der Tür: geöffnet (Besucher kommen) oder geschlossen
var is_open: bool = true
## So viele Leseausweise gibt es schon
var cards: int = 0
## Verliehen: [{books: Array[Book], day: int, minute: float}] – zurück ab diesem Tag und dieser Uhrzeit
var loans: Array[Dictionary] = []
## Zahlen des laufenden Tages: day, visitors, borrowed, returned, cards, income, nothing_found, to_counter
var today: Dictionary = {}
## Abgeschlossene Tage (neueste zuletzt), höchstens HISTORY_DAYS
var history: Array[Dictionary] = []
const HISTORY_DAYS := 60

## Heute geplante Besuche (Spielminuten des Tages, aufsteigend) und wie viele gerade da sind
var _tickets: Array[float] = []
var _planned_day := -1
var _inside: Array[Object] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	add_to_group(SaveManager.PERSIST_GROUP)
	today = _empty_day(GameClock.day)
	GameClock.minute_passed.connect(_on_minute)
	GameClock.day_started.connect(_on_day_started)


# --- Schild ---

func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	open_changed.emit(open)
	SaveManager.request_save()


## Kommen gerade Besucher? (Schild auf „Geöffnet“ und Öffnungszeit)
func accepts_visitors() -> bool:
	return is_open and GameClock.is_between(GameConfig.library_open_from_hour, GameConfig.library_open_until_hour)


# --- Besuche planen ---

## Soll der Passant, der gerade vor der Bücherei vorbeikommt, hereinkommen? (Ticket fällig, Platz frei)
func want_visitor() -> bool:
	if not accepts_visitors():
		return false
	_plan_day()
	var now := GameClock.minute_of_day()
	# verfallene Tickets (lange niemand vorbeigekommen, z. B. während geschlossen war) weg
	while not _tickets.is_empty() and now - _tickets[0] > GameConfig.visitor_ticket_expiry_hours * 60.0:
		_tickets.pop_front()
	if _tickets.is_empty() or _tickets[0] > now:
		return false
	return visitors_inside() < max_at_once()


## Prüfwerkzeug: so viele Besuche jetzt gleich fällig.
func debug_add_visits(count: int) -> void:
	_plan_day()
	var now := GameClock.minute_of_day()
	for i in count:
		_tickets.push_front(now)


## Ein Besucher kommt herein (Ticket verbraucht, zählt mit).
func visitor_entered(who: Object) -> void:
	if not _tickets.is_empty():
		_tickets.pop_front()
	if not _inside.has(who):
		_inside.append(who)
	_count("visitors")


func visitor_left(who: Object) -> void:
	_inside.erase(who)


func visitors_inside() -> int:
	_inside = _inside.filter(func(o: Object) -> bool: return is_instance_valid(o))
	return _inside.size()


## Wie „voll“ ist die Bücherei (0–1): Bücher in den Regalen und Sitzplätze.
func fullness() -> float:
	var books := 0
	for shelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
		if shelf is BookShelf:
			books += (shelf as BookShelf).get_books().size()
	var seats := 0
	var room := find_room()
	if room:
		for seating: Node in room.find_children("*", "Seating", true, false):
			seats += (seating as Seating).get_seats().size()
	var b := clampf(float(books) / GameConfig.visitors_books_for_full, 0.0, 1.0)
	var s := clampf(float(seats) / GameConfig.visitors_seats_for_full, 0.0, 1.0)
	return b * 0.7 + s * 0.3


func max_at_once() -> int:
	return int(round(lerpf(GameConfig.visitors_at_once_start, GameConfig.visitors_at_once_full, fullness())))


## Besuche des Tages über die Öffnungszeit verteilen (einmal am Tag; nach dem Laden nur noch für die restliche Zeit).
func _plan_day() -> void:
	if _planned_day == GameClock.day:
		return
	_planned_day = GameClock.day
	_tickets.clear()
	var start := GameConfig.visitors_per_day_start
	var count := int(round(lerpf(_rng.randi_range(start.x, start.y), GameConfig.visitors_per_day_full, fullness())))
	var from := GameConfig.library_open_from_hour * 60.0
	var to := GameConfig.library_open_until_hour * 60.0 - 20.0
	var now := GameClock.minute_of_day()
	for i in count:
		var t := _rng.randf_range(from, to)
		if t >= now - 10.0:
			_tickets.append(t)
	_tickets.sort()


# --- Ausleihe ---

## Ein Besucher ist an der Theke gestempelt: Bücher sind verliehen, Gebühren gehen ins Portemonnaie. Liefert die Einnahme.
func lend(books: Array[Book], new_card: bool) -> int:
	var income := books.size() * GameConfig.book_lend_fee
	if new_card:
		cards += 1
		income += GameConfig.library_card_fee
		_count("cards")
	if not books.is_empty():
		var days := _rng.randi_range(GameConfig.loan_days.x, GameConfig.loan_days.y)
		loans.append({"books": books.duplicate(), "day": GameClock.day + days, "minute": _rng.randf_range(0.0, 1439.0)})
		_count("borrowed", books.size())
	if income > 0:
		Wallet.earn(income, "Ausleihe")
		_count("income", income)
	SaveManager.request_save()
	return income


## Ist dieser Besucher neu (noch kein Ausweis)? Je mehr Ausweise es gibt, desto seltener.
func roll_new_reader() -> bool:
	var share := maxf(GameConfig.library_new_share_min, 1.0 - float(cards) / GameConfig.library_regulars)
	return _rng.randf() < share


## Jemand ist ohne Buch gegangen (nichts Passendes gefunden).
func nothing_found() -> void:
	_count("nothing_found")


## Zahl der verliehenen Bücher (alle Ausleihen).
func books_on_loan() -> int:
	var n := 0
	for loan in loans:
		n += (loan.books as Array).size()
	return n


# --- Rückgabe ---

func _on_minute(_minute: int) -> void:
	_return_due()


func _return_due() -> void:
	if loans.is_empty():
		return
	var day := GameClock.day
	var now := GameClock.minute_of_day()
	var due: Array[Book] = []
	var keep: Array[Dictionary] = []
	for loan in loans:
		if int(loan.day) < day or (int(loan.day) == day and float(loan.minute) <= now):
			for book: Book in loan.books:
				due.append(book)
		else:
			keep.append(loan)
	if due.is_empty():
		return
	var box := ReturnBox.find(get_tree())
	if box == null:
		return  # (noch) keine Bücherei geladen – später noch einmal
	loans = keep
	var rest := box.add_books(due)
	if not rest.is_empty():
		rest = _put_on_counter(rest)
		if _last_counter_count > 0:
			_count("to_counter", _last_counter_count)
	if not rest.is_empty():
		# Kein Platz mehr (Theke voll): ins Lager
		BookStock.store_books(rest)
	_count("returned", due.size())
	SaveManager.request_save()


var _last_counter_count := 0


## Rückgaben, die nicht mehr in den Kasten passen, landen auf der Theke (flach gestapelt). Liefert, was nicht passt.
func _put_on_counter(books: Array[Book]) -> Array[Book]:
	_last_counter_count = 0
	var room := find_room()
	var counter := get_tree().get_first_node_in_group(&"counters") as Node3D
	if room == null or counter == null or room.loose_books == null:
		return books
	var rest: Array[Book] = []
	for i in books.size():
		var book := books[i]
		# links auf der Platte (rechts steht die Kasse), zwei kleine Stapel
		var local := Vector3(-0.72 + 0.26 * float(i % 2), 1.6, 0.05)
		var from := counter.global_transform * local
		var plan := room.loose_books.find_spot(from, Vector3.DOWN, book, _rng.randf_range(-8.0, 8.0))
		if plan.is_empty() or not plan.get("ok", false):
			rest.append(book)
			continue
		room.loose_books.place(book, plan.transform, plan.support_uid, plan.pose)
		_last_counter_count += 1
	return rest


# --- Tage ---

func _on_day_started(day: int) -> void:
	# Mitternacht: der Vortag ist abgeschlossen
	var done := today.duplicate()
	history.append(done)
	while history.size() > HISTORY_DAYS:
		history.pop_front()
	today = _empty_day(day)
	day_closed.emit(done)
	stats_changed.emit()


func _empty_day(day: int) -> Dictionary:
	return {"day": day, "visitors": 0, "borrowed": 0, "returned": 0, "cards": 0, "income": 0, "nothing_found": 0, "to_counter": 0}


func _count(key: String, amount: int = 1) -> void:
	if int(today.get("day", 0)) != GameClock.day:
		today = _empty_day(GameClock.day)
	today[key] = int(today.get(key, 0)) + amount
	stats_changed.emit()


## Der Raum der Bücherei (Erdgeschoss).
func find_room() -> Room:
	return get_tree().get_first_node_in_group(ROOM_GROUP) as Room


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	var saved_loans := []
	for loan in loans:
		saved_loans.append({"books": Book.list_to_save_data(loan.books), "day": loan.day, "minute": loan.minute})
	# Bücher, die Besucher gerade in der Hand haben: nach dem Laden gleich im Rückgabekasten (Besucher werden nicht gespeichert)
	for node in get_tree().get_nodes_in_group(&"library_visits"):
		var held: Array[Book] = node.call("held_books")
		if not held.is_empty():
			saved_loans.append({"books": Book.list_to_save_data(held), "day": 0, "minute": 0.0})
	return {"open": is_open, "cards": cards, "loans": saved_loans, "today": today, "history": history}


func load_save_data(data: Dictionary) -> void:
	is_open = bool(data.get("open", true))
	cards = int(data.get("cards", 0))
	loans.clear()
	for entry: Variant in data.get("loans", []):
		if entry is Dictionary:
			var books := Book.list_from_save_data(entry.get("books", []))
			if not books.is_empty():
				loans.append({"books": books, "day": int(entry.get("day", 0)), "minute": float(entry.get("minute", 0.0))})
	var saved_today: Variant = data.get("today", {})
	today = _empty_day(GameClock.day)
	if saved_today is Dictionary:
		for key: String in today:
			today[key] = int((saved_today as Dictionary).get(key, today[key]))
	history.clear()
	for entry: Variant in data.get("history", []):
		if entry is Dictionary:
			var day_stats := _empty_day(0)
			for key: String in day_stats:
				day_stats[key] = int((entry as Dictionary).get(key, 0))
			history.append(day_stats)
	_planned_day = -1
	open_changed.emit(is_open)
	stats_changed.emit()
