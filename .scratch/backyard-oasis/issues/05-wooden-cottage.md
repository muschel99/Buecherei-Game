# 05 – Holzhäuschen (fertiger Zustand)
Status: ready-for-agent
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
