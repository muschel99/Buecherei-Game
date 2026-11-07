class_name FaceTriggers
extends RefCounted
## Gesichtsausdrücke der Passanten (seit Etappe 6c): Grundsätzlich schauen alle neutral-freundlich
## (BASE). Andere Ausdrücke gibt es nur bei einem Anlass – einem Auslöser, z. B. Lächeln beim Grüßen,
## Staunen vor einem Schaufenster, Lachen beim Plaudern. Neuer Anlass = neuer Eintrag in TRIGGERS und
## an der passenden Stelle ChibiPasserbyModel.trigger_face(&"name") aufrufen.

const Mood := ChibiCharacter.Mood
## Grundausdruck: offene Augen, leichtes Lächeln
const BASE := ChibiCharacter.Mood.NEUTRAL
## Auslöser → [mögliche Ausdrücke (einer davon zufällig), Dauer von, bis (Sekunden)]
const TRIGGERS := {
	&"greet": [[Mood.HAPPY, Mood.GRIN], 2.0, 3.0],              # jemanden grüßen
	&"wave": [[Mood.HAPPY, Mood.LAUGH], 1.6, 2.4],              # winken
	&"window_wonder": [[Mood.SURPRISED, Mood.EXCITED], 1.0, 1.8],  # Staunen vor dem Schaufenster
	&"window_like": [[Mood.HAPPY, Mood.CONTENT, Mood.STARSTRUCK], 1.8, 3.0],  # Gefällt mir!
	&"chat_talk": [[Mood.HAPPY, Mood.CONTENT], 1.5, 2.6],       # erzählt etwas
	&"chat_laugh": [[Mood.LAUGH, Mood.GRIN], 1.0, 1.8],         # lacht mit
	&"chat_listen": [[Mood.CONTENT], 1.5, 2.5],                 # hört zu
	&"stretch": [[Mood.CONTENT, Mood.SLEEPY], 1.2, 1.8],        # streckt sich
	&"watch": [[Mood.SURPRISED, Mood.WORRIED], 0.8, 1.2],       # Blick auf die Uhr
	&"sit_rest": [[Mood.CONTENT], 3.0, 5.0],                    # sitzt gemütlich
	&"yawn": [[Mood.SLEEPY], 2.5, 3.5],                         # gähnt (seit Etappe 6h)
	&"sigh": [[Mood.CONTENT, Mood.SLEEPY], 2.0, 3.0],           # seufzt zufrieden
	&"handshake": [[Mood.HAPPY, Mood.GRIN], 2.5, 3.5],          # Händeschütteln zur Begrüßung
	&"goodbye": [[Mood.HAPPY], 1.6, 2.4],                       # winkt zum Abschied
	&"pet": [[Mood.HAPPY, Mood.LOVE, Mood.CONTENT], 3.0, 5.0],  # streichelt eine Katze
}


## Ein Ausdruck für einen Auslöser: [Ausdruck, Dauer] (leer = unbekannter Auslöser).
static func pick(trigger: StringName) -> Array:
	if not TRIGGERS.has(trigger):
		return []
	var entry: Array = TRIGGERS[trigger]
	var moods: Array = entry[0]
	return [moods[randi() % moods.size()], randf_range(entry[1], entry[2])]
