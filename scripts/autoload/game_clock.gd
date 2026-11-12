extends Node
## Die Uhr des Spiels (seit Etappe 7, Autoload "GameClock"): Tag und Uhrzeit laufen wie bei den Sims einfach weiter –
## ein Spieltag dauert so viele Minuten echter Zeit, wie in den Einstellungen gewählt (Standard 24: eine Minute = eine
## Stunde). Kein Pausieren und kein Vorspulen; nur im Pausenmenü steht die Zeit (der Baum ist dann angehalten).
## Schlafen springt zur Weckzeit (sleep_until). Uhrzeit und Tag werden mit dem Spielstand gespeichert.
##
## Im Code: GameClock.hour() (0–23), GameClock.minute_of_day() (0–1439,99), GameClock.day (1, 2, …),
## GameClock.weekday_name(), GameClock.day_fraction() (0–1, Mitternacht = 0), GameClock.is_night().
## Signale: minute_passed (jede Spielminute), hour_changed(stunde), day_started(tag) um Mitternacht,
## morning(tag) um GameConfig.clock_morning_hour (Notizzettel), woke_up nach dem Schlafen.

signal minute_passed(minute: int)
signal hour_changed(hour: int)
signal day_started(day: int)
signal morning(day: int)
signal woke_up

const WEEKDAYS: Array[String] = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
const WEEKDAYS_SHORT: Array[String] = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
const MINUTES_PER_DAY := 1440.0

var save_key: String = "clock"
## Spieltag (1 = erster Tag, ein Montag)
var day: int = 1
var _minute: float = 0.0
var _last_minute: int = -1
var _last_hour: int = -1
## Uhr läuft (false z. B. in Werkzeug-Szenen, die eine feste Tageszeit brauchen)
var running: bool = true


func _ready() -> void:
	_minute = GameConfig.clock_start_hour * 60.0
	day = 1
	_last_minute = int(_minute)
	_last_hour = hour()
	add_to_group(SaveManager.PERSIST_GROUP)


func _process(delta: float) -> void:
	if not running:
		return
	advance(delta * MINUTES_PER_DAY / (day_length_minutes() * 60.0))


## Dauer eines Spieltags in Minuten echter Zeit (Einstellung „Tageslänge“).
func day_length_minutes() -> float:
	var options: Array = GameConfig.clock_day_length_options
	var index := clampi(int(Settings.get_value("gameplay/day_length")), 0, options.size() - 1)
	return float(options[index])


## Spielminuten weiterzählen (feuert die Signale für jede übersprungene volle Minute/Stunde, aber gebündelt).
func advance(minutes: float) -> void:
	if minutes <= 0.0:
		return
	_minute += minutes
	while _minute >= MINUTES_PER_DAY:
		_minute -= MINUTES_PER_DAY
		day += 1
		_last_minute = -1
		day_started.emit(day)
	var whole := int(_minute)
	if whole != _last_minute:
		_last_minute = whole
		minute_passed.emit(whole)
	var h := hour()
	if h != _last_hour:
		var before := _last_hour
		_last_hour = h
		hour_changed.emit(h)
		if h == GameConfig.clock_morning_hour and before != h:
			morning.emit(day)


## Uhrzeit setzen (gleicher Tag oder, wenn die Zeit davor liegt, nächster Tag) – z. B. Aufwachen.
func sleep_until(hour_value: int) -> void:
	var target := float(hour_value) * 60.0
	var minutes := target - _minute
	if minutes <= 0.0:
		minutes += MINUTES_PER_DAY
	advance(minutes)
	woke_up.emit()
	SaveManager.request_save()


func minute_of_day() -> float:
	return _minute


func hour() -> int:
	return int(_minute / 60.0)


## Anteil des Tages (0 = Mitternacht, 0,5 = Mittag).
func day_fraction() -> float:
	return _minute / MINUTES_PER_DAY


## Wochentag 0 (Montag) … 6 (Sonntag).
func weekday() -> int:
	return (day - 1) % 7


func weekday_name(short: bool = false) -> String:
	return (WEEKDAYS_SHORT if short else WEEKDAYS)[weekday()]


## Uhrzeit als Text, z. B. "9:40".
func time_text(minute: float = -1.0) -> String:
	var m := int(_minute if minute < 0.0 else minute)
	return "%d:%02d" % [m / 60, m % 60]


## Liegt die Uhrzeit zwischen from und to (Stunden, auch über Mitternacht, z. B. 20 bis 4)?
func is_between(from_hour: float, to_hour: float) -> bool:
	var h := _minute / 60.0
	if from_hour <= to_hour:
		return h >= from_hour and h < to_hour
	return h >= from_hour or h < to_hour


func is_night() -> bool:
	return is_between(GameConfig.clock_night_start, GameConfig.clock_night_end)


## Testtaste: eine Stunde vor.
func skip_hour() -> void:
	advance(60.0)


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	return {"day": day, "minute": _minute}


func load_save_data(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	_minute = clampf(float(data.get("minute", GameConfig.clock_start_hour * 60.0)), 0.0, MINUTES_PER_DAY - 0.01)
	_last_minute = int(_minute)
	_last_hour = hour()
	minute_passed.emit(_last_minute)
	hour_changed.emit(_last_hour)
