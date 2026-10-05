class_name StyleTags
extends RefCounted
## Die Einrichtungs-Stile des Spiels.
##
## Möbel, Wandfarben und Böden tragen ein oder mehrere Stil-Merkmale.
## Gespeichert werden sie als "Flags": Jeder Stil ist eine Zahl (1, 2, 4),
## mehrere Stile werden einfach zusammengezählt (z. B. Botanisch + Modern = 3).
## Im Inspektor erscheinen sie als Häkchen-Liste.

const BOTANICAL := 1
const MODERN := 2
const DARK_ACADEMIA := 4

## Alle Stile in Anzeige-Reihenfolge.
const ALL: Array[int] = [BOTANICAL, MODERN, DARK_ACADEMIA]

const _IDS := {
	BOTANICAL: "botanical",
	MODERN: "modern",
	DARK_ACADEMIA: "dark_academia",
}

const _NAMES := {
	BOTANICAL: "Botanisch",
	MODERN: "Modern",
	DARK_ACADEMIA: "Dark Academia",
}

## Erkennungsfarbe je Stil (für Katalog und Testanzeige).
const _COLORS := {
	BOTANICAL: Color(0.55, 0.75, 0.45),
	MODERN: Color(0.75, 0.82, 0.9),
	DARK_ACADEMIA: Color(0.75, 0.45, 0.35),
}


## Englischer Name, z. B. "dark_academia" (für Speicherdaten und Code).
static func get_id(style: int) -> String:
	return _IDS.get(style, "unknown")


## Deutscher Anzeigename, z. B. "Dark Academia".
static func get_display_name(style: int) -> String:
	return _NAMES.get(style, "?")


static func get_color(style: int) -> Color:
	return _COLORS.get(style, Color.WHITE)


## Zerlegt eine Flag-Zahl in die einzelnen Stile, z. B. 5 -> [1, 4].
static func to_list(flags: int) -> Array[int]:
	var result: Array[int] = []
	for style in ALL:
		if flags & style:
			result.append(style)
	return result


## Berechnet, wie stark jeder Stil vertreten ist.
## Erwartet eine Liste von Stil-Flags (z. B. von allen platzierten Möbeln).
## Jedes Möbelstück zählt einen Punkt; hat es mehrere Stile, wird der Punkt aufgeteilt.
## Ergebnis: Stil -> Anteil zwischen 0.0 und 1.0 (zusammen 1.0, oder alles 0 ohne Möbel).
static func calculate_shares(flags_list: Array[int]) -> Dictionary:
	var shares := {}
	for style in ALL:
		shares[style] = 0.0
	var total := 0.0
	for flags in flags_list:
		var styles := to_list(flags)
		if styles.is_empty():
			continue
		total += 1.0
		for style in styles:
			shares[style] += 1.0 / styles.size()
	if total > 0.0:
		for style in ALL:
			shares[style] /= total
	return shares
