extends Node
## Die Geldbörse der Bücherei: der aktuelle Kontostand.
##
## Dieses Autoload ist die einzige Stelle, an der sich das Geld ändert.
## Im Code: Wallet.money, Wallet.can_afford(120), Wallet.spend(120, "Einkauf").
## Ab Etappe 5 kommen hier die Einnahmen (Leihgebühren, Mitgliedschaften, Café) mit
## Wallet.earn(...) dazu – jede Buchung trägt einen kurzen Grund, damit später z. B. eine
## Tagesabrechnung daraus entstehen kann.
## Der Kontostand wird mit dem Spielstand gespeichert (Gruppe "persist", siehe SaveManager).

## Wird gesendet, wenn sich der Kontostand ändert (change: + Einnahme, - Ausgabe).
signal money_changed(money: int, change: int)

## Name im Spielstand.
var save_key: String = "wallet"
## Aktueller Kontostand in Talern. Zum Start: GameConfig.start_money.
var money: int = 0


func _ready() -> void:
	money = GameConfig.start_money
	add_to_group(SaveManager.PERSIST_GROUP)


func can_afford(amount: int) -> bool:
	return amount <= money


## Gibt Geld aus. Liefert false (und ändert nichts), wenn es nicht reicht.
func spend(amount: int, reason: String = "") -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	_change(-amount, reason)
	return true


## Nimmt Geld ein (z. B. beim Verkaufen, ab Etappe 5 auch Leihgebühren).
func earn(amount: int, reason: String = "") -> void:
	if amount > 0:
		_change(amount, reason)


## Betrag mit Währung, z. B. "1.250 Taler".
func format(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return "%s%s%s %s" % ["-" if amount < 0 else "", digits, grouped, GameConfig.currency_name]


func _change(change: int, _reason: String) -> void:
	money += change
	money_changed.emit(money, change)
	SaveManager.request_save()


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	return {"money": money}


func load_save_data(data: Dictionary) -> void:
	money = int(data.get("money", GameConfig.start_money))
	money_changed.emit(money, 0)
