# 01 – Gestaltungsmodus draußen
Status: resolved

Der Gestaltungsmodus (Tab) funktioniert auch draußen vor der Bücherei.
- Bebaubarer Streifen an der Hauswand der Bücherei (Gehweg), Tür/Treppe/Rückgabe-Einwurf und ein Durchgang bleiben frei.
- Nur Dinge aus der Abteilung „Draußen“ lassen sich dort abstellen.
- Aufgestellte Dinge sind Hindernisse für Passanten, Besucher und Katzen (sie gehen außen herum).
- Alles wird mit dem Spielstand gespeichert.

## Comments

23.11.2026: Erledigt – Draußen-Raum `OutdoorArea` (scenes/rooms/outdoor_area.tscn, Room.outdoor), Gestaltungsmodus wechselt
selbst zwischen drinnen und draußen, Kategorie OUTDOOR, Ausweich-Kreise für Passanten, Spielstand.

23.11.2026 (Nachtrag, Wunsch der Entwicklerin): Auch auf der Treppe darf kleine Deko stehen – Ablageflächen an den
Seiten jeder Stufe und neben der Tür (EntranceSteps._add_deco_zones, Gruppe Room.OUTDOOR_SURFACE_GROUP), Laufmitte
GameConfig.entrance_free_half frei, nur was ganz auf die Stufe passt; der Gestaltungsmodus schaut durch die Lauf-Rampe.
