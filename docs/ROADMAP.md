# Roadmap – Etappenplan

| Nr. | Etappe                                   | Status        |
|-----|------------------------------------------|---------------|
| 1   | Grundgerüst und erster Raum              | fertig        |
| 2   | Gestaltungsmodus                         | fertig        |
| 2b  | Gestaltungsmodus verbessern              | fertig        |
| 2c  | Feinschliff Gestaltung                   | fertig        |
| 2d  | Ergänzungen: Steuerung, Füllwerkzeug, Bildschirm | fertig |
| 2e  | Steuerung und Leistung                   | fertig        |
| 2f  | Inventar, Shop und Lieferung             | fertig        |
| 2g  | Fensterlicht und Filter                  | fertig        |
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

## Etappe 2e – Steuerung und Leistung
- [x] Höher und weicher springen (etwa 0,8 m, sanftere Schwerkraft in der Luft; Werte in GameConfig);
      auf Möbel springen und wieder herunter
- [x] Im Gestaltungsmodus mit X entfernen (statt Entf); Tastenhilfe und Pausenmenü angepasst
- [x] Mauszeiger erscheint nach dem Umsehen (rechte Maustaste) genau an der alten Stelle –
      in jeder Auflösung, im Fenster und im Vollbild
- [x] Leistung: Bildrate begrenzen (30/60/120/unbegrenzt, Standard 60), VSync standardmäßig an,
      im Pausenmenü höchstens 30 Bilder pro Sekunde
- [x] Grafikqualität Niedrig/Mittel/Hoch (`GameConfig.graphics_presets`)
- [x] Nur wichtige Lampen werfen Schatten (`LightSource.shadow_importance`), Kerzen nie
- [x] Bilder-pro-Sekunde-Anzeige (F3 oder Einstellungen); alle Einstellungen gespeichert

## Etappe 2f – Inventar, Shop und Lieferung
Greift Teilen von Etappe 5 vor: Geld, Kaufen und Verkaufen sind schon da und so gebaut,
dass Etappe 5 darauf aufbauen kann (Einnahmen über `Wallet.earn`, Preise in den Datenblättern).
- [x] Zentrales Geld-System (`Wallet`): Startgeld 500 Taler (`GameConfig.start_money`),
      dezente Anzeige oben links, jede Buchung mit kurzem Grund
- [x] Gestaltungsmodus wird zum Inventar (`Inventory`): nur Eigenes, mit Anzahl (×2);
      bei ×0 ausgegraut; Platzieren nimmt eins heraus, Aufheben und X legen es zurück
- [x] Möbel im Raum gehören zum Start; schlichte Startfarben und ein Boden
      (Datenblatt-Häkchen `owned_at_start`); Oberflächen einmal kaufen, unbegrenzt nutzen
- [x] Tablet auf der Theke (gehört fest zur Bücherei, `is_essential`): E öffnet den Shop
- [x] Shop „Kaufen“: alles Freigeschaltete nach Kategorien mit Vorschaubild, Preis und Stil;
      Warenkorb, Bestellen; reicht das Geld nicht, ein freundlicher Hinweis ohne Strafe
- [x] Shop „Verkaufen“: Möbel aus dem Inventar für 50 % (`GameConfig.sell_price_share`)
- [x] Lieferung: nach 10 s (`GameConfig.delivery_time`) ein Karton pro Bestellung vor der Tür,
      Hinweis „Deine Lieferung ist da“; E packt ihn mit kleiner Animation ins Inventar aus
- [x] Eingangstür mit E öffnen und schließen (Türschmuck schwingt mit); Gehweg vor der Tür
- [x] Geld, Inventar, Bestellungen unterwegs und Kartons werden gespeichert;
      ältere Spielstände funktionieren weiter (Tablet und Wandfarben werden ergänzt)

## Etappe 2g – Fensterlicht und Filter
- [x] Grafikfehler behoben: keine wandernde Linie mehr im Fensterlicht. Ursache waren die
      Schattenstufen (Kaskaden) der Sonne; ihre Übergänge werden jetzt weich überblendet.
      Schattenweite der Sonne 20 m (`GameConfig.sun_shadow_distance`); Grafikstufe Niedrig
      mit 2 statt 4 Stufen (schneller), Mittel und Hoch wie bisher
- [x] Unterkategorien im Datenformat (`FurnitureData.subcategory`, Liste in
      `FurnitureData.SUBCATEGORIES` – neue Unterkategorie = eine Zeile); alle Objekte zugeordnet
- [x] Pflanzen sind jetzt eine Unterkategorie von Deko (ein Reiter weniger);
      der Kerzenleuchter gehört zur Beleuchtung
- [x] Filter im Shop und im Gestaltungsmodus: Unterkategorie und Stil (Botanisch, Modern,
      Dark Academia, Neutral) als kleine Schaltflächen über der Liste, umbrechend bei
      schmalen Bildschirmen (`FilterBar`)

## Etappe 3 – Bücher und Regale
- Bücher als Daten (Titel, Genre, Zustand)
- Regale befüllen, Bücher einsortieren

## Etappe 4 – Besucher
- Besucher kommen herein, stöbern, leihen aus, warten geduldig an der Theke

## Etappe 5 – Wirtschaft und Tagesablauf
- Grundlage schon vorhanden (Etappe 2f): Geld (`Wallet`), Inventar, Shop mit Kaufen und
  Verkaufen, Lieferung
- Einnahmen: Leseausweise, Abstempeln, Leihgebühren, Mitgliedschaften (über `Wallet.earn`)
- Tag mit Öffnen-Schild, Pause und Vorspulen; Tagesabrechnung aus den Buchungen
- Preise und Startgeld ausbalancieren

## Etappe 6 – Stilsystem und Besuchervielfalt
- Stil-Merkmale an Möbeln (Botanisch, Modern, Dark Academia) – Grundlage seit Etappe 2 vorhanden
- Vorherrschender Stil beeinflusst Besucher und Musik

## Etappe 7 – Café
- Café-Module an der Theke anbauen

## Etappe 8 – Erweiterungen und Freischaltungen
- Weitere Räume, Obergeschoss, Genres freischalten, Renovieren
- Neue Möbel im Shop freischalten (Datenblatt-Feld `is_unlocked`)

## Etappe 9 – Atmosphäre und Sound
- Musik je Stil, Geräusche, Tageszeit-Licht

## Etappe 10 – Story und Spiegel
- Kleine unerklärliche Ereignisse, der Spiegel und seine Wesen

## Etappe 11 – Gasse, Fassade und Jahreszeiten
- Die Gasse vor dem Haus (bisher: ein Stück Gehweg als Platzhalter), Fassade gestalten,
  Jahreszeiten
- Vielleicht ein Lieferbote, der die Kartons bringt (bisher erscheinen sie einfach)

## Etappe 12 – Feinschliff
- Menüs, Einstellungen, Speichern/Laden, Balancing
