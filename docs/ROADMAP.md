# Roadmap – Etappenplan

| Nr. | Etappe                                   | Status        |
|-----|------------------------------------------|---------------|
| 1   | Grundgerüst und erster Raum              | fertig        |
| 2   | Gestaltungsmodus                         | fertig        |
| 2b  | Gestaltungsmodus verbessern              | fertig        |
| 2c  | Feinschliff Gestaltung                   | fertig        |
| 2d  | Ergänzungen: Steuerung, Füllwerkzeug, Bildschirm | fertig |
| 3   | Bücher und Regale                        | offen         |
| 4   | Besucher                                 | offen         |
| 5   | Wirtschaft und Tagesablauf               | offen         |
| 6   | Stilsystem und Besuchervielfalt          | offen         |
| 7   | Café                                     | offen         |
| 8   | Erweiterungen und Freischaltungen        | offen         |
| 9   | Atmosphäre und Sound                     | offen         |
| 10  | Story und Spiegel                        | offen         |
| 11  | Gasse, Fassade und Jahreszeiten          | offen         |
| 12  | Feinschliff                              | offen         |

## Etappe 1 – Grundgerüst und erster Raum
- [x] Godot-4-Projekt mit Ordnerstruktur
- [x] Dokumentation (GAME_DESIGN, ROADMAP, CLAUDE.md)
- [x] Spielfigur in Ego-Perspektive (WASD, Maus, sanfte Bewegung)
- [x] Testraum 6 x 8 m mit Fenster, Tür und Platzhalter-Möbeln
- [x] Gemütliche Beleuchtung (Sonne, Stehlampe, Bloom, SSAO, Tonemapping, Staub im Lichtstrahl)
- [x] Wiederverwendbares Interaktionssystem (Lampe mit E schalten)
- [x] Pausenmenü mit Esc (Weiter, Steuerung, Beenden)

## Etappe 2 – Gestaltungsmodus
- [x] Schneller laufen mit Umschalt (sanfter Übergang)
- [x] Möbel als Daten (`FurnitureData`, Ordner `data/furniture/`) – neue Möbel ohne Code
- [x] 23 Platzhalter-Möbel in drei Stilen und acht Kategorien (inkl. Theke mit Kasse und Stehlampe)
- [x] Gestaltungsmodus in der Ego-Perspektive, Katalog unten mit Reitern (Taste seit 2b: Tab)
- [x] Halbdurchsichtige Vorschau (grün/rot), Raster mit G, Drehen, Eingang bleibt frei
- [x] Deko auf Tischen und Regalbrettern; was auf einem Möbel steht, wandert beim Verschieben mit
- [x] Möbel aufheben, neu platzieren und mit Entf entfernen
- [x] 8 Wandfarben und 5 Böden als Daten (`SurfaceData`, Ordner `data/surfaces/`)
- [x] Stil-Anteile berechnen und anzeigen
- [x] Einrichtung automatisch speichern und beim Start laden (`SaveManager`, erweiterbar)
- [x] Tastenhilfe im Gestaltungsmodus

## Etappe 2b – Gestaltungsmodus verbessern
- [x] Gestaltungsmodus mit Tab öffnen und schließen; Esc schließt ihn (Gehaltenes geht zurück)
- [x] Allgemeine Esc-Regel: erst das Offene schließen, sonst Pausenmenü (`MenuStack`)
- [x] Katalog-Zustand (Mauszeiger, Umsehen mit rechter Maustaste, Möbel anklicken)
      und Platzier-Zustand (Vorschau folgt dem Blick) mit automatischem Wechsel
- [x] Drehen nur mit dem Mausrad; frei als Standard, G = Einrasten (12,5-cm-Raster, 15°-Schritte)
- [x] Vorderseite zeigt zum Spieler, Drehung bleibt relativ zum Blick
- [x] Ablageflächen-System (`PlacementSurface`): Tische, Regale, Sitzflächen, Armlehnen, Fensterbank
- [x] Aufhängen an Wand und Tür; Datenfeld „placement“ (Boden, Ablagefläche, Wand, Tür)
- [x] Neue Deko: Kissen, Wolldecke, Teddybär, Türkranz, Wandbild (Bücherstapel gab es schon)
- [x] Wände in Abschnitten streichen, Böden in Feldern legen (Klick, Ziehen, Umschalt + Klick)
- [x] Farbroller- und Teppich-Symbol in der Bildmitte
- [x] Wandfarben und Böden stilneutral; Stilanzeige automatisch oben im Gestaltungsmodus (F3 entfällt)
- [x] Lichtschalter schaltet alle Lampen im Raum

## Etappe 2c – Feinschliff Gestaltung
- [x] Böden in Abschnitten aus 3 x 3 Rasterfeldern; Raster jetzt 1/9 m, damit der Raum
      (6 x 8 m) ohne Rest aufgeht (18 x 24 Abschnitte); alte Spielstände werden umgerechnet
- [x] Decke gestalten wie den Boden; 7 Platzhalter (Farben, Holzdecke, Holzbalken, Kassetten);
      Deckenroller-Symbol
- [x] Stil-Merkmale überall freiwillig, stilneutrale Objekte zählen nicht; Oberflächen mit Stil zählen mit
- [x] Dezente Hervorhebung (Aufhellung mit feinem Rand), auch für E-Objekte; Stärke in GameConfig
- [x] Decke als Platzierungsort; Deckenlampen für alle drei Stile, größere Reichweite für E
- [x] Gemeinsames Lichtsystem (`LightSource`): alles, was leuchtet, ist mit E schaltbar;
      Flammen erlöschen sanft; Lichtschalter optional auch für Kerzen und Laternen
- [x] Hinsetzen mit E, Sitzplätze je Sitzmöbel (`Seating`, `SeatPoint`)

## Etappe 2d – Ergänzungen: Steuerung, Füllwerkzeug, Bildschirm
- [x] Springen (Leertaste) und Hocken (Strg halten), im Sitzen aufstehen mit Leertaste;
      Werte in GameConfig
- [x] Deckenbalken aus dem Grundraum entfernt (Deckenvariante „Holzbalken“ bleibt;
      platzierbare Balken folgen später)
- [x] Füllwerkzeug für Boden und Decke wie der Farbeimer in Paint (Umschalt + Klick)
- [x] Bildschirmeinstellungen im Pausenmenü (Fenster/Vollbild, Auflösung, VSync), gespeichert;
      alle Menüs passen sich an jede Auflösung und jedes Seitenverhältnis an
- [x] Raumhöhe 3,2 m (vorher 3,0 m) in GameConfig; Fenster und Tür höher;
      Deckenobjekte aus alten Spielständen wandern mit

## Etappe 3 – Bücher und Regale
- Bücher als Daten (Titel, Genre, Zustand)
- Regale befüllen, Bücher einsortieren

## Etappe 4 – Besucher
- Besucher kommen herein, stöbern, leihen aus, warten geduldig an der Theke

## Etappe 5 – Wirtschaft und Tagesablauf
- Leseausweise, Abstempeln, Leihgebühren, Mitgliedschaften
- Tag mit Öffnen-Schild, Pause und Vorspulen

## Etappe 6 – Stilsystem und Besuchervielfalt
- Stil-Merkmale an Möbeln (Botanisch, Modern, Dark Academia) – Grundlage seit Etappe 2 vorhanden
- Vorherrschender Stil beeinflusst Besucher und Musik

## Etappe 7 – Café
- Café-Module an der Theke anbauen

## Etappe 8 – Erweiterungen und Freischaltungen
- Weitere Räume, Obergeschoss, Genres freischalten, Renovieren

## Etappe 9 – Atmosphäre und Sound
- Musik je Stil, Geräusche, Tageszeit-Licht

## Etappe 10 – Story und Spiegel
- Kleine unerklärliche Ereignisse, der Spiegel und seine Wesen

## Etappe 11 – Gasse, Fassade und Jahreszeiten
- Die Gasse vor dem Haus, Fassade gestalten, Jahreszeiten

## Etappe 12 – Feinschliff
- Menüs, Einstellungen, Speichern/Laden, Balancing
