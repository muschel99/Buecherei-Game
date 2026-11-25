# 05 – Holzhäuschen (fertiger Zustand)
Status: done
Blocked by: 02

- Hinten links im Garten ein Holzhäuschen – ein richtiges Zuhause: eigener Raum zum Einrichten (Gestaltungsmodus), dort schlafen.
- Der morsche Zustand und das Story-Projekt (reparieren lassen) kommen in Zettel 07.

## Comments

25.11.2026: Entscheidungen der Entwicklerin: innen **ein offener Raum** bis unters schräge Dach (Balken, Licht von den Gauben);
außen eine **ästhetische Mischung** aus Brettern (ihre Beispielbilder: Türkis/Himmelblau mit abblätternder Farbe, nacktes Holz
in Honig, Rotbraun, Grau, Dunkel, etwas Moosgrün); dazu ein **Vordach bzw. eine kleine Veranda** vor der Tür.
Schritt 1 erledigt: `tools/blender/build_storybook_cottage.py` → `assets/models/world/garden_cottage.glb` (Tiny House 4,6 × 3,6 m,
eine Etage, zwei Gauben mit eigenen Dächern, Veranda mit Satteldach auf zwei Pfosten, Fensterläden, Blumenkästen, Ofenrohr);
im Spiel `alley.gd` (`_build_cottage`: Lage aus GameConfig, Boden, Veranda und Rampe als Kollision, Tür
`scenes/objects/cottage_door.tscn` – Brettertür mit Z-Strebe, E öffnet, ohne Ladenglocke). Abblätternde Farbe: neuer Regler
`peel` in `storybook.gdshaderinc`; Bau-Scripts geben jetzt `weather`, `weather_color` und `peel` ans Spiel (nur eigene Materialien).
Weiter: Schritt 2 eigener Raum zum Einrichten (Gestaltungsmodus mit allen Möbeln), Schritt 3 schlafen.

25.11.2026: Nach dem Lageplan der Entwicklerin größer (5,8 × 4,4 m) und übers Eck in der Gartenecke (Mauern an den Seitenwänden),
Veranda zum Bach, Brücke direkt auf die Veranda. Schritt 2 erledigt: Raum „Zuhause“ (`Room.home`, `scenes/rooms/cottage_room.tscn`)
– alle Innen-Möbel, Wände streichen (neues Datenblatt `wall_wood_paneling`, gehört von Anfang an), Boden belegen (Eiche), an den
Wänden aufhängen (dünne Körper auf der Verkleidung); Wände nur bis zur Traufe (Giebel und Dach bleiben Holz), keine Decke zum
Gestalten. Veranda: gedrehte Fläche des Draußen-Raums (`Room.extra_build_frames`), nur Draußen-Deko. Gestaltungsmodus wechselt
in den Raum, in dem man steht (`BuildMode._room_at`). Maße und Öffnungen bringt das Modell mit (`GameSpot_cottage_room`).
Weiter: Schritt 3 – dort schlafen.

25.11.2026: Schritt 3 erledigt – Bett fürs Häuschen (`data/furniture/bed_cottage.tres`: Modell und Schlafen wie im Hinterzimmer,
frei aufstellbar, 180 Taler), steht beim ersten Start an der Rückwand neben dem Fenster (`alley.gd`); E = schlafen (wie bisher nur
nachts und wenn niemand mehr in der Bücherei ist). Bodenbelag füllt jetzt jede Fläche genau (Felder gedehnt, `PaintableGrid`).
Der morsche Zustand und das Story-Projekt kommen mit Zettel 07.
