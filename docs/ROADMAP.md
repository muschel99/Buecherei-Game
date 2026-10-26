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
| 2h  | Kronleuchter, Kartons und Baumodus       | fertig        |
| 2i  | Kartons einsammeln und Lager-Animation   | fertig        |
| 3   | Bücher und Regale                        | fertig        |
| 3b  | Echte Bücher: Cover, Sammlung, einzeln einräumen | fertig |
| 3c  | Freies Einräumen, Deko im Regal und weniger Text | fertig |
| 3d  | Regalsteuerung, Etagen-Genres und Bücher als Deko | fertig |
| 3e  | Bücher drehen, Stapel blättern und Regal-Menü mit R | fertig |
| 3f  | Regal-Menü als Tablet und Fächer         | fertig        |
| 3g  | Tablet mit Apps und Lagerübersicht       | fertig        |
| 3h  | Shop-Namen, Lager mit Sammlung, R-Menü überall | fertig |
| 3i  | Fach-Automodus und Platzierungs-Fehler   | fertig        |
| 3j  | Vorschau unbeleuchtet, Bücher anlehnen und Aufsteller | fertig |
| 3k  | Tür, Buchmenü und Buchstützen           | fertig        |
| 3l  | Fassaden-App und fester Rückgabekasten   | fertig        |
| 4   | Außenwelt                                | fertig        |
| 4a  | Eckladen-Grundriss, feste Theke und Rückgabekasten | fertig |
| 4b  | Reparatur Eckladen (Schräge, Fassade, Fenster, Vorplatz, Licht) | fertig |
| 4c  | Eckladen sauber nachbessern (Gehrung, Gehweg, Obergeschoss) | fertig |
| 4d  | Straße, Gasse, Platz und Eingangstreppe  | fertig        |
| 4e  | Breitere Straße, ein gerades Straßenende und austauschbare Häuser | fertig |
| 4f  | Grenze am geraden Straßenende und Torhaus mit Durchfahrt | fertig |
| 4g  | Einheitlicher Stil: Modelle aus Blender (Häuser, Bücherei, Möbel, Innenraum) | in Arbeit |
| 4h  | Bilderbuch-Stil: Häuser neu, Licht, Pflaster, Pflanzen | fertig (Licht folgt) |
| 5   | Besucher                                 | in Arbeit     |
| 5a  | Leben auf der Straße                     | fertig        |
| 5b  | Figuren und Fahrzeuge im Stil            | in Arbeit     |
| 5c  | Chibi-Figuren (Mannequins, Gesichter)    | in Arbeit     |
| 6   | Wirtschaft und Tagesablauf               | offen         |
| 7   | Stilsystem und Besuchervielfalt          | offen         |
| 8   | Café                                     | offen         |
| 9   | Erweiterungen und Freischaltungen        | offen         |
| 10  | Atmosphäre und Sound                     | offen         |
| 11  | Story und Spiegel                        | offen         |
| 12  | Gasse, Fassade und Jahreszeiten          | offen         |
| 13  | Feinschliff                              | offen         |

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
Greift Teilen von Etappe 6 vor: Geld, Kaufen und Verkaufen sind schon da und so gebaut,
dass Etappe 6 darauf aufbauen kann (Einnahmen über `Wallet.earn`, Preise in den Datenblättern).
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

## Etappe 2h – Kronleuchter, Kartons und Baumodus
- [x] Kronleuchter und Rattan-Hängelampe werfen in keiner Grafikstufe Schatten mehr
      (vorher seltsame Bänder und Ringe an Wänden und Decke); Licht bleibt gleich warm.
      Alle Lampen geprüft (Übersicht in GAME_DESIGN, Abschnitt Einstellungen)
- [x] Ein Karton pro Objekt; ordentlich gestapelt (nebeneinander, bis 3 hoch, dann eine Reihe
      davor), leicht schief, ohne Überschneidung; auch über mehrere Bestellungen
- [x] Unterer Karton eingesammelt: die oberen rutschen sanft nach
- [x] Lieferort als verschiebbarer Punkt (Marker3D `Outside/Deliveries`), Werte in GameConfig
- [x] Alle Kartons mit Stapel und Drehung gespeichert; alte Sammelkartons werden zu Einzelkartons
- [x] Gestaltungsmodus zeigt nur, was im Inventar liegt (keine ausgegrauten Karten mehr);
      Filter nur mit belegten Unterkategorien; freundlicher Hinweis bei leerem Reiter

## Etappe 2i – Kartons einsammeln und Lager-Animation
- [x] Kartons von allen Seiten anwählbar, auch von oben; bei Stapeln reagiert immer der
      angesehene Karton. Ursache: Der E-Bereich endete genau auf Deckelhöhe, der feste Karton
      „gewann“. Lösung im Interaktionssystem: Trifft der Blick den festen Körper eines Objekts,
      gilt dessen E-Bereich (`Interactable.find_for`)
- [x] Alle E-Objekte geprüft; Sessel, Korbsessel und Sofa sind jetzt auch von hinten anwählbar
- [x] Lager-Anzeige unten rechts statt Schriftzug (`StorageIndicator`): Symbol ploppt auf,
      rutscht ins Lager, Lager federt kurz; Warteschlange mit 0,7 s Abstand (GameConfig);
      blendet danach aus
- [x] Symbole automatisch aus den 3D-Modellen (SubViewport, zwischengespeichert);
      wiederverwendbar für alles, was ins Lager geht (später z. B. Bücher)

## Etappe 3 – Bücher und Regale
Leitgedanke: Einsortieren soll befriedigend sein, aber nie mühsam – Bücher bewegt man immer
in Gruppen, ohne Zeitdruck.
- [x] Genres als Daten (`GenreData`, Ordner `data/genres/`): Name, Farbpalette der Buchrücken,
      Stil (freiwillig), Paketpreis, freigeschaltet; 5 frei, 11 angelegt und gesperrt
- [x] Bücher als Daten (`Book`: Titel, Genre, Zustand – vorerst immer gut)
- [x] Erfundene, zum Genre passende Titel aus Wortlisten (seit 3b ersetzt durch feste
      Bücherlisten in `data/books/`)
- [x] Bücherbestand getrennt vom Möbel-Inventar (`BookStock`): Lager, Regale,
      Rückgabekasten, getragene Bücher; Startbücher (`GameConfig.start_books_per_genre`)
- [x] Shop: Bereich „Bücher“ mit Bücherpaketen je Genre (`GameConfig.books_per_package`);
      ein Karton pro Paket, Lager-Anzeige mit Bücherstapel in Genre-Farben (`BookIcons`)
- [x] Tablet: Reiter „Bestand“ (im Regal, im Lager, unterwegs, gesamt)
- [x] Regale mit Buchfächern (`BookShelf`, `BookRow`); Bücher als MultiMesh mit eigenem
      Shader (Höhe, Dicke, Farbton, Bänder, Titelschild verschieden)
- [x] Regal-Menü (`ShelfMenu`): Genre oder „Gemischt“, aus dem Lager auffüllen, alles
      zurück ins Lager; Bücher gleiten nacheinander hinein und heraus
- [x] Genre-Schild am Regal (Platzhalter; seit 3c ersetzt durch einen Schriftzug beim Anschauen)
- [x] Regal verschieben: Bücher bleiben drin (auch in der Vorschau); mit X wegräumen:
      Bücher gehen ins Lager
- [x] Rückgabekasten (Startgeschenk, im Shop unter Theke); Testtaste F9
      (seit 3c zentral abschaltbar: `GameConfig.debug_keys_enabled`)
- [x] Bücher tragen: alle aus dem Kasten auf einmal, Anzeige unten (`CarryIndicator`);
      E am Regal räumt alle passenden ein, der Rest bleibt in der Hand
- [x] Alles wird gespeichert (Bestand, Regalinhalte, Schilder, Kasten, Getragenes);
      ältere Spielstände bekommen Startbücher und den Rückgabekasten einmalig dazu

## Etappe 3b – Echte Bücher: Cover, Sammlung, einzeln einräumen
Leitgedanke: Jedes Buch hat Charakter. Man kann jedes einzeln an seinen Platz stellen,
muss aber nie – Auffüllen, Einräumen und Sortieren gehen weiter mit einem Klick.
- [x] Kein Flimmern (Z-Fighting) mehr an Regalstreben und Möbelkanten: Wo zwei Flächen genau
      aufeinanderlagen, liegt die kleinere jetzt 2 mm innen (alle Möbel, Fenster, Türrahmen,
      Fußleisten, Gehweg und Karton geprüft)
- [x] 800 echte Titel (16 Genres × 50), deutsch und englisch, gemütlich und erfunden;
      Bücherlisten in `data/books/<genre>.txt` (Titel | Motiv), Titel als Katalog (`BookData`)
- [x] Jeder Titel: erfundener Autor, feste Größe, Farben, Gestaltung, passendes Motiv
- [x] Cover und Buchrücken aus Farben, Schrift und Formen (`BookCover`): sechs Gestaltungen
      (classic, picture, minimal, pattern, band, comic), 71 Motive (`BookMotifs`),
      Schriften vom eigenen PC je Genre (`GenreData.cover_font`)
- [x] Echte Buchrücken im Regal über ein gemeinsames Bild aller Rücken (`BookArt`-Atlas),
      weiterhin ein Zeichenaufruf je Regal
- [x] Sammlung: entdeckte Titel; Pakete bringen zuerst neue Titel, Hinweis beim Auspacken;
      ältere Spielstände bekommen für ihre Bücher passende echte Titel
- [x] Regale mit eigener Reihe je Brett; Buch anschauen = Infokarte mit Cover
- [x] E tippen: einzelnes Buch nehmen (auch aus der Mitte) bzw. an die markierte Stelle
      einstellen (Lücke öffnet sich, Vorschau schwebt davor); E halten: alle passenden
      einräumen bzw. Regal-Menü (`Interactable.supports_hold`, Ring um die Bildmitte)
- [x] Buch obenauf mit Cover in der Hand (unten rechts), Mausrad wechselt
- [x] Regal-Menü: Buch aus dem Lager wählen (Cover-Kacheln), nach Genre und Titel sortieren
- [x] Tablet: Reiter „Sammlung“ (alle Titel, unentdeckte als „?“), Spalte „Sammlung“ im Bestand

## Etappe 3c – Freies Einräumen, Deko im Regal und weniger Text
Leitgedanke: mehr Freiheit beim Einräumen, weniger Text auf dem Bildschirm.
- [x] Testtaste F10: 500 Taler Testgeld (`GameConfig.debug_money_amount`); alle Testtasten
      (F9, F10) zentral abschaltbar (`GameConfig.debug_keys_enabled`, Autoload `DebugKeys`)
- [x] Neue Steuerung für Bücher: bis zu 7 tragen (`GameConfig.max_carried_books`),
      Linksklick nimmt das angeschaute Buch (Regal, Rückgabekasten), Rechtsklick stellt das
      Buch obenauf ab, E halten räumt alle passenden ein, E tippen öffnet das Regal-Menü,
      Mausrad wechselt das Buch obenauf, Q halten legt alles ins Lager; Klicks nur im Spiel
      (nicht im Gestaltungsmodus oder in Menüs)
- [x] Volle Hände ohne Text: Der Stapel in der Hand wackelt kurz; in der Hand ein kleiner
      Stapel aus echten Buchrücken
- [x] Rückgabekasten: E nimmt so viele, wie in die Hände passen, Linksklick eins
- [x] Bücher frei auf jedes Regalbrett stellen: feines Raster (1 cm), Einrasten an Nachbarn,
      Deko und Seitenwand, zwischen Bücher schieben (Nachbarn rücken nur so weit wie nötig);
      halbdurchsichtige Vorschau, dezent rötlich, wenn es nicht passt (Shader `book_ghost`)
- [x] Auffüllen, E halten und Sortieren füllen freie Plätze und lassen Deko stehen
- [x] Kleine Deko auf Regalbrettern (jedes Brett hat automatisch eine Ablagefläche,
      `PlacementSurface.max_height` = Fachhöhe); Bücher und Deko überschneiden sich nie
- [x] Neue Regal-Deko im Shop: Buchstützen (Holz, Beton), Mini-Sukkulente, Bilderrahmen zum
      Hinstellen, kleiner Globus, Kerze im Glas, kleine Vase mit Lavendel; Unterkategorie
      „Buchstützen“
- [x] Genre-Schilder entfallen: Genre als ruhiger Schriftzug unten in der Bildmitte
      (`GenreCaption`), blendet sanft ein und aus
- [x] Weniger Text: kleine Tastensymbole mit höchstens einem Wort (`KeyHints`), Ring um das
      Symbol bei Halte-Aktionen, Einstellung „Hinweise“ (Aus, Nur Symbole, Symbol mit Wort);
      alle Hinweise im Spiel auf ein Wort gekürzt; Tastenhilfe im Pausenmenü erweitert
- [x] Buch-Infokarte kleiner, erst nach kurzem Anschauen (`GameConfig.book_info_delay`) oder
      kurz für das Buch in der Hand; „Du trägst …“ entfällt (kleines Stapel-Symbol mit Zahl)
- [x] Gestaltungsmodus und Hinweise oben gekürzt (Statuszeile nur Name oder Problem)
- [x] Freie Buchpositionen, Deko im Regal und getragene Bücher werden gespeichert; ältere
      Spielstände laden weiter (Bücher ohne Lage stehen dicht von links)
- Noch offen für später: Bücher frei auf Tische oder die Theke legen (bisher nur Regale und
  Rückgabekasten) – erledigt in Etappe 3d

## Etappe 3d – Regalsteuerung, Etagen-Genres und Bücher als Deko
Leitgedanke: Die Maus ist für Bücher da, E für alles andere – und Bücher dürfen überall liegen.
- [x] Neue Maussteuerung: Rechtsklick nimmt ein Buch (Regal, Tisch, Boden, Rückgabekasten),
      Linksklick legt das Buch obenauf genau dort ab, Linksklick halten am Regal räumt alle
      passenden ein, E halten am Regal öffnet das Regal-Menü (E tippen nicht mehr);
      Haltezeiten getrennt in GameConfig (`interact_hold_time`, `place_all_hold_time`,
      `store_books_hold_time`); ein kurzer Klick zählt nie als Halten und umgekehrt
- [x] Alles andere (Kartons, Lampen, Sitzen, Tür, Tablet, Rückgabekasten) bleibt bei E;
      Gestaltungsmodus unverändert
- [x] Hinweise beim Tragen klein am unteren Rand neben dem Stapel-Symbol (Ablegen, Einräumen,
      Lager, Ring um Q beim Halten); beim Anschauen: Buch „Nehmen“ (Maus rechts), Regal
      „Menü“ (E mit Halte-Ring); Tastenhilfe im Pausenmenü aktualisiert
- [x] Eigenes Genre pro Regaletage (oder „Gemischt“); Regal-Menü zeigt alle Etagen mit eigener
      Auswahl und der Schnellauswahl „Alle Etagen gleich“; Auffüllen, Einräumen und Sortieren
      beachten die Etagen; der Schriftzug zeigt das Genre der angeschauten Etage
- [x] Bücher frei in der Welt ablegen (Tische, Theke, Fensterbank, Sitzmöbel, Boden, jede
      Ablagefläche): flach mit Cover nach oben, nach Blickrichtung ausgerichtet, leicht schräg;
      Buch auf Buch = kleiner, versetzter Stapel (höchstens `GameConfig.loose_book_stack_max`)
- [x] Aufrecht hinstellen ohne neue Taste: Linksklick an eine Wand = angelehnt (Cover nach
      vorn), neben eine Buchstütze oder ein stehendes Buch = aufrecht in einer Reihe
- [x] Ausgelegte Bücher gehören zum Bestand („Ausgelegt“ im Shop-Reiter Bestand), wandern mit
      ihrem Möbelstück mit und kommen ins Lager, wenn es mit X weggeräumt wird
- [x] Wiederverwendbares System für später (Besucher): `LooseBooks.place` / `remove` /
      `find_spot`; Zustand „aufgeschlagen“ ist im Datenformat vorgesehen (`LooseBook.Pose.OPEN`)
- [x] Leistung: alle ausgelegten Bücher eines Raums in einem einzigen Zeichenaufruf (MultiMesh
      mit Cover-Atlas), Zielsuche nur in der Nähe
- [x] Speichern von Etagen-Genres und ausgelegten Büchern; alte Spielstände laden weiter
      (bisheriges Regal-Genre gilt für alle Etagen, keine ausgelegten Bücher)

## Etappe 3e – Bücher drehen, Stapel blättern und Regal-Menü mit R
Leitgedanke: Jede Aktion hat genau einen Weg, und kein Menü öffnet sich aus Versehen.
- [x] Mausrad dreht das Buch obenauf vor dem Ablegen um die Hochachse (wie Möbel im
      Gestaltungsmodus); Vorschau zeigt die Drehung; leichte Zufallsschräge bleibt; Drehung
      relativ zur Blickrichtung (auf Stapeln zum Buch darunter), nach dem Ablegen wieder 0;
      Schrittweite `GameConfig.book_turn_step`
- [x] Angelehnte Bücher ein Stück drehbar (`GameConfig.loose_book_lean_max_turn`); im Regal und
      in aufrechten Reihen hat das Mausrad keine Wirkung
- [x] E tippen blättert durch den Stapel in der Hand (Umschalt + E rückwärts); was selbst auf E
      reagiert (Lampe, Lichtschalter, Tür, Karton, Sitz, Tablet, Rückgabekasten), hat Vorrang;
      am Regal blättert E ebenfalls
- [x] R öffnet das Regal-Menü (kurzer Druck, ohne Halten und ohne Ring); R oder Esc schließt
      es; E halten am Regal entfällt
- [x] Regal-Menü entschlackt (ohne „Getragene einräumen“ und „Getragene Bücher ins Lager
      legen“) und bei jeder Auflösung vollständig sichtbar (Mittelteil scrollt bei Bedarf)
- [x] Hinweise: Mausrad „Drehen“, E „Blättern“ in den Tragehinweisen, am Regal R „Menü“;
      Tastenhilfe im Pausenmenü aktualisiert
- [x] Drehung ausgelegter Bücher wird gespeichert (steckt in der Lage); alte Spielstände laden
      unverändert
- Noch offen für später: Im Shop-Reiter „Bestand“ gibt es weiter den Knopf „Getragene Bücher
  ins Lager legen“ (gleiche Aktion wie Q halten) – beim Neubau des Tablets (Etappe 3g) prüfen

## Etappe 3f – Regal-Menü als Tablet und Fächer
Leitgedanke: Wenige klare Aktionen statt vieler Wege – und das Regal bleibt im Blick.
- [x] „Fach“ statt „Etage“: Fächer von oben links nach unten rechts durchnummeriert (Fach 1,
      Fach 2 …), überall umbenannt; Schnellauswahl „Alle Fächer gleich“
- [x] Linksklick halten räumt ab dem angeschauten Fach und der angeschauten Stelle ein (erst
      nach rechts, dann nach links), der Rest in die nächstgelegenen Fächer mit passendem
      Genre; Auffüllen aus dem Lager füllt weiter von oben nach unten
- [x] Gemeinsame Tablet-Vorlage (`TabletFrame`: Gehäuse, Bildschirm, Kreuz zum Schließen;
      `TabletIconButton`: gezeichnete Symbol-Knöpfe mit Tooltip) für Regal-Menü und
      Theken-Tablet; Tooltips und aufklappende Listen im warmen Stil
- [x] Regal-Menü neu als Tablet am rechten Bildrand: Genre je Fach, Buch aus dem Lager wählen
      (Cover-Kacheln auf dem Tablet), Auffüllen, Sortieren über ein Filtersymbol (nach Genre und
      Titel, Titel, Autor oder Farbe), Alle ins Lager; immer gleich groß, bei allen
      Auflösungen ganz sichtbar
- [x] Fach im Regal dezent hervorheben, wenn ich im Menü sein Auswahlfeld anfahre oder
      aufklappe; die Ansicht dreht sich beim Öffnen etwas (zoomt bei Bedarf heraus), sodass
      das Tablet das Regal nicht verdeckt
- [x] Gewählte Sortierart wird gespeichert; alte Spielstände laden weiter

## Etappe 3g – Tablet mit Apps und Lagerübersicht
Leitgedanke: Das Theken-Tablet fühlt sich wie ein echtes Tablet an – und Bücher kommen direkt
aus dem Lager in die Hand.
- [x] Theken-Tablet (`CounterTablet`) mit Startbildschirm: große App-Symbole mit Namen auf
      ruhigem Hintergrund, schmale Leiste mit Kontostand und getragenen Büchern; Home-Symbol
      zurück, Kreuz und Esc schließen das ganze Tablet; beim Öffnen immer der Startbildschirm
- [x] Apps als eigene kleine Szenen mit Datenblatt (neue App = Szene + Datenblatt in
      `data/tablet_apps/`, kein Code am Startbildschirm)
- [x] App „Einrichtung“: Möbel, Deko, Wandfarben, Böden, Decken kaufen und verkaufen
      (Warenkorb, Filter), umschalten mit zwei Symbolen
- [x] App „Bücher“: Bücherpakete je Genre kaufen (eigener Warenkorb)
- [x] App „Sammlung“: alle Titel je Genre, unentdeckte als „?“
- [x] App „Bestand“: je Genre Lager, Regal, ausgelegt, unterwegs mit Symbolen und Zahlen;
      1 bis 7 Bücher oder einzelne Titel (Cover-Kacheln) direkt aus dem Lager in die Hand;
      Tablet bleibt offen; volle Hände: ausgegraut und sanftes Wackeln, ohne Text
- [x] Der alte Shop mit Reitern entfällt; „Getragene Bücher ins Lager legen“ gibt es nur noch
      als Q halten
- [x] Bücher aus der Bestand-App werden wie andere getragene Bücher gespeichert; alte
      Spielstände laden weiter
- Ideen für spätere Apps: Vorbestellungen, Besucher, Einstellungen

## Etappe 3h – Shop-Namen, Lager mit Sammlung, R-Menü überall
Leitgedanke: Das Tablet ist zum Schauen und Einkaufen da, Bücher nehme ich über das R-Menü –
und das gibt es überall.
- [x] App „Lager“ statt „Bestand“ und „Sammlung“: je Genre Lager, Regal, ausgelegt, unterwegs
      mit Symbolen und Zahlen, darunter der Sammelstand; aufgeklappt die Sammlung des Genres
      (Cover-Kacheln, unentdeckte als „?“, wo meine Exemplare sind); nur zur Übersicht
- [x] Shops mit Namen und kleinem Logo: Einrichtung = „Nest & Nook“ (Haus mit Herz),
      Bücher = „Bücherladen“ (Platzhalter; Name nur im Datenblatt `data/tablet_apps/books.tres`);
      oben in der Leiste Logo, Ladenname und kurzer Untertitel
- [x] Bücher nehmen nur über das R-Menü (am Theken-Tablet nicht mehr); es bleibt beim Nehmen
      offen, bis die Hand mit sieben Büchern voll ist (oder Esc, R, Kreuz); oben ein kleiner
      Stapel mit der Zahl der getragenen Bücher
- [x] R öffnet das Menü überall (auch im Sitzen): am Regal (auch mit Blick auf Deko darin) mit
      allen Regal-Teilen, sonst sind diese dezent ausgegraut („Kein Regal im Blick“), die
      Bücherauswahl geht immer (dann alle Genres); im Gestaltungsmodus, am Theken-Tablet und
      in der Pause öffnet R nichts
- [x] App „Statistik“: große Zahlen (Bücher insgesamt, im Regal, ausgelegt, im Lager, Titel
      entdeckt) und schlichte Balken je Genre; neue Werte später über die Gruppe
      `stat_sources` (`get_stats()`), fehlende Werte erscheinen nicht
- [x] App „Tipps & Tricks“ als kleines Büchlein: Inhaltsverzeichnis mit Symbolen und
      Seitenzahlen, Seiten zum Blättern, zurück ins Inhaltsverzeichnis; Texte in
      `data/tips/tips.txt` (leicht zu ergänzen und umzusortieren)
- [x] Tastenhilfe im Pausenmenü: R = Bücher-Menü überall
- [x] Nichts Neues zu speichern; alte Spielstände laden weiter
- Ideen für später: schönerer Name für den Bücherladen, Statistik mit Besuchern, Ausleihen,
  Kaffee und Kuchen (Etappen 5, 6, 8)

## Etappe 3i – Fach-Automodus und Platzierungs-Fehler
Leitgedanke: Bücher einfach hineinstellen, ohne vorher etwas festzulegen – und beim Ablegen
keine Grafikfehler und keine halb versenkten Bücher.
- [x] Tickbox „Auto“ je Fach (vor dem Genre-Dropdown): Das Fach nimmt jedes Buch an und
      übernimmt sein Genre aus den Büchern darin (alle gleich → dieses Genre, verschiedene →
      „Gemischt“, leer → keins); das Dropdown zeigt das erkannte Genre („Noch leer“); Standard
      für alle Fächer; Genre von Hand wählen schaltet „Auto“ aus, Haken weg lässt das Fach beim
      aktuellen Genre; Auffüllen nutzt das erkannte Genre
- [x] Dieselbe Kombi bei „Alle Fächer gleich“
- [x] Vorschau beim Ablegen ruhig und gleichmäßig: ohne Licht und Schatten der Szene, ein paar
      Millimeter zur Kamera hin gezeichnet (kein Flackern, keine Streifen)
- [x] Einheitliche Kollision: Ein Buch darf nirgends in ein anderes Objekt hineinragen (Prüfung
      mit den Kollisionsformen, Aufliegen und Anlehnen erlaubt) – sonst ist die Vorschau rot und
      das Ablegen gesperrt (Wackeln wie bisher); kein Abprallen mehr an Möbelseiten;
      Leiterregal mit passender Kollision (Seitenholme statt unsichtbarer Rückwand)
- [x] Fach-Genre samt „Auto“ wird gespeichert („row_auto“); alte Spielstände laden weiter
      (Fächer ohne gespeichertes Genre gelten als „Auto“, Fächer mit gewähltem Genre bleiben
      dabei)

## Etappe 3j – Vorschau unbeleuchtet, Bücher anlehnen und Aufsteller
Leitgedanke: Bücher schön präsentieren – angelehnt, auf Polstern, im Aufsteller – und eine
Vorschau, die überall gleich aussieht.
- [x] Gemeinsame „Blaupause“ für Bücher und Möbel (`blueprint.gdshader`): unbeleuchtet, ruhiges
      Blau, Deckkraft 0,88 (keine Hell-Dunkel-Kante an Lichtinseln), heller Rand und feine
      Buchkanten, rot bei gesperrten Stellen; in allen drei Grafikstufen geprüft
- [x] Bücher anlehnen an: Bücherstapel (Seite), Rücken- und Armlehnen von Sofas, Lehnen von
      Sesseln und Stühlen, große Blumentöpfe (`FurnitureData.books_can_lean`) – wie an der Wand,
      an niedrigeren Lehnen an deren Oberkante; nie frei hochkant, nie an kleiner Deko
- [ ] Anlehnen an die Rückwand im Bücherregal: noch offen (dort räumt das Regal in Reihen ein;
      bräuchte eine eigene Lösung im Regal)
- [x] Bücher flach auf Sofakissen und Sofadecke (`FurnitureData.books_can_lie`)
- [x] Neues Objekt „Buch-Aufsteller“ bei Nest & Nook (Deko, 18 Taler): hält genau ein Buch
      (Haltung „präsentiert“), Linksklick hinein, Rechtsklick heraus, belegt = rot; Buch zählt als
      „ausgelegt“, wandert mit, geht mit X ins Lager; auch im Bücherregal
- [x] Speichern: angelehnte Bücher, Bücher auf Polstern und Aufsteller mit Buch; alte
      Spielstände laden weiter

## Etappe 3k – Tür, Buchmenü und Buchstützen
Leitgedanke: Kleine Stolpersteine aus dem Weg räumen – Tür, Bücherauswahl, Buchstützen.
- [x] Eine offene Tür bleibt offen, wenn der Gestaltungsmodus angeht (man kommt weiter durch)
- [x] Keine Bücher im Schwenkbereich der Tür (Vorschau rot, wie bei Möbeln)
- [x] R-Menü: genommene Bücher bleiben sichtbar (ausgegraut, Handsymbol); noch ein Klick legt
      sie zurück ins Lager
- [x] R-Menü: Kategorie „Alle Bücher“
- [x] R-Menü: Cover-Kacheln dezent in der Farbe ihres Genres hinterlegt
- [x] Buchstützen: Bücher rasten an der Buchstütze ein, die Buchstütze nicht an Büchern
- [x] Speichern prüfen (ausgelegte Bücher, Buchstützen); alte Spielstände laden weiter

## Etappe 3l – Fassaden-App und fester Rückgabekasten
Leitgedanke: Ein einziger, fester Rückgabekasten in der Hauswand – angepasst statt aufgestellt.
- [x] Neue Tablet-App „Fassade“ (erweiterbar für Wandfarbe außen, Schild, Fenster …)
- [x] Genau ein fester Rückgabekasten in der Wand neben der Eingangstür: außen Einwurf,
      innen Entnahme; nicht kaufbar, nicht verkaufbar, nicht mehr im Inventar
- [x] Alte Spielstände: aufgestellte Rückgabekästen verschwinden, ihre Bücher wandern in den
      festen Kasten (was nicht passt, ins Lager)
- [x] Optik des Einwurfs in der Fassaden-App wählen (Platzhalter-Varianten, erweiterbar)
- [x] Innen mit E herausnehmen wie bisher; F9 legt zum Testen Bücher hinein
- [x] Platz für 50 Bücher (GameConfig), immer geschlossen, dezente Anzeige der Anzahl
- [x] Speichern: Inhalt und gewählte Variante; alte Spielstände laden weiter

## Etappe 4 – Außenwelt
Leitgedanke: Aus dem rechteckigen Testraum wird ein echter kleiner Eckladen im Londoner Stil;
die Gestaltung der Gasse und Fassade folgt in weiteren Unterschritten.

### Etappe 4a – Eckladen-Grundriss, feste Theke und Rückgabekasten
- [x] Neuer Grundriss: vordere linke Ecke abgeschrägt, schräge Eingangswand mit mittiger
      Ladentür; Mass der Schräge in `GameConfig.corner_cut` (die Ecke bleibt unbebaubar)
- [x] Je ein englisches Sprossenfenster in der unteren und der linken Wand; eigene,
      austauschbare Platzhalter-Szenen (`scenes/objects/shop_window.tscn` und
      `scenes/objects/shop_door.tscn` mit Sprossenfenster, Seitenteilen und Oberlicht)
- [x] Fester Rückgabekasten rückt in die schräge Eingangswand, rechts neben die Tür
- [x] Startraum fast leer: nur noch Theke, Sessel und Deko-Regal (+ Tablet auf der Theke)
- [x] Deko-Regal (neues Möbel, Unterkategorie „Deko-Regale“): bewusst kein Bücherregal –
      es dient nur zum Dekorieren; Bücherregale gibt es weiter im Shop zu kaufen
- [x] Theke gehört fest zum Laden (`is_essential` + neues Feld `is_fixed`): nicht kaufbar,
      nicht verkaufbar, nicht im Inventar; frei verschiebbar, aber nicht wegräumbar
- [x] Theken-Stil über die App „Fassade“ wählbar (Autoload `CounterStyle`, drei Platzhalter-
      Varianten); Struktur für spätere Theken-Module (Backshop, Kaffee) vorgesehen
- [x] Speicher-Version auf 2 erhöht: alte Spielstände passen nicht zur neuen Raumform und
      werden ignoriert (es beginnt ein frisches Spiel)
- Noch offen für später (weitere 4er-Schritte): Gasse und Gehweg rund um die Ecke, offene
  linke/rechte Seite für die Erweiterung

### Etappe 4b – Reparatur Eckladen
Leitgedanke: die Fehler aus 4a an der neuen Raumform sauber beheben, sonst nichts ändern.
- [x] Schräge Ecke durchgehend vom Boden bis zur Decke: Boden und Decke folgen jetzt der
      Schräge (CSG-Eckabschnitt, `PaintableGrid.cut_corner`), vorher ragte oben die Decke und
      unten der Boden als rechteckige Ecke hinaus
- [x] Außenhülle rundherum geschlossen und flach: der rechteckige Fassadenaufsatz (angedeutete
      zweite Etage) ist entfernt, der Laden ist ein sauberer Eckbau in einer Ladenhöhe
      (spätere Etagen bleiben möglich)
- [x] Beide Fenster von innen und außen vollständig sichtbar (der Rahmen steckte vorher ganz
      in der Wand) und von beiden Seiten durchsichtig
- [x] Z-Fighting in den Fenstern behoben (Glas, Rahmen und Sprossen liegen in verschiedenen
      Tiefen, nie in derselben Ebene)
- [x] Vorplatz an die Schräge angepasst: ein sauberer, begehbarer Streifen vor der schrägen
      Eingangswand; man tritt bequem hinaus und wieder hinein
- [x] „Deckenlicht ohne Lampe“ entfernt: das war ein verstecktes Hilfslicht (FillLight) knapp
      unter der Decke; der Raum wird jetzt vom Umgebungslicht und vom Fensterlicht erhellt

### Etappe 4c – Eckladen sauber nachbessern
Leitgedanke: die restlichen Fehler am Eckladen beheben und das Haus von außen vollständig
machen (mit Obergeschoss), sonst nichts am Spiel ändern. Diesmal vorab mit Testbildern aus
festen Blickwinkeln geprüft (Godot ohne Bildschirm gestartet).
- [x] Linkes Fenster von innen durchsichtig: Die streichbare Innenfläche der linken Wand hatte
      keine Aussparung (`openings`) und lag vor dem Fenster. Alle Öffnungen geprüft: Wandloch,
      Innenfläche und Rahmen liegen genau übereinander; der Türrahmen steckte ganz in der Wand
      und ist jetzt von beiden Seiten sichtbar; der Rückgabekasten braucht kein Loch (er sitzt
      innen und außen auf der Wand)
- [x] Schräge Wand auf Gehrung: Vordere, linke und schräge Wand sind hochgezogene Grundrisse
      (Trapeze, CSGPolygon3D) statt gerader Quader; vorher ragte die schräge Wand an beiden
      Enden 15 cm über. Boden- und Deckenplatte enden genau an der Außenkante
- [x] Zacken entfernt: Boden- und Deckenbelag werden genau an der Schräge abgeschnitten
      (`PaintableGrid`); vorher ragten Ecken der Belagfelder als Dreiecke durch die Wand
      (Deckenbelag an der Dachkante, Bodenbelag an der Tür)
- [x] Gehweg ohne Löcher: eine einzige Gehwegfläche (vor dem Haus, vor der Schräge, links neben
      dem Haus) auf Höhe des Ladenbodens, bündig an der Hauswand; Bordstein und unsichtbare
      Wand hinten links. Die alte, zu kurze Vorplatz-Platte ist entfernt. Mit Teststrahlen
      geprüft: an keinem von 42.200 Punkten (5-cm-Raster) fehlt fester Boden
- [x] Obergeschoss als geschlossene Außenhülle mit demselben Grundriss inklusive Schräge,
      Fenster-Platzhaltern (`scenes/objects/upper_window.tscn`) und schlichtem Walmdach
      (`scripts/rooms/upper_floors.gd`, Knoten „UpperFloors“ in der Hauptszene); Anzahl und Höhe
      in GameConfig (`upper_floor_count` = 1, `upper_floor_height` = 3,0 m), vorerst nicht
      betretbar, jedes Geschoss ein eigener Knoten für das spätere Freischalten. Die
      Außenwände des Ladens reichen bis zur Oberkante der Deckenplatte, damit kein heller
      Deckenstreifen in der Fassade zu sehen ist; die Decke im Laden bleibt, wie sie ist
- [x] Glatte Schattenkanten: Die „breite Sonnenscheibe“ (`light_angular_distance`) ist aus; der
      normale weiche Filter glättet die Kanten und ist günstiger zu berechnen

### Etappe 4d – Straße, Gasse, Platz und Eingangstreppe
Leitgedanke: Die Bücherei bekommt ihre Umgebung (Straße, Häuserreihen, Gasse, kleiner Platz),
liegt erhöht über ein paar Stufen, und zwei Kleinigkeiten im Laden werden besser.
- [x] Bodenleiste an der schrägen Eingangswand, links und rechts der Tür: endet am Türrahmen,
      in den Ecken auf Gehrung (auch die Leisten der Nachbarwände haben jetzt schräge Enden)
- [x] Tiefere innere Fensterbänke (`GameConfig.window_sill_depth` = 0,32 m ab der Scheibe),
      gebaut vom neuen Script `ShopWindow`; Bank, Glas und Seitenrahmen haben eine feste
      Kollision. Geprüft: Deko und Bücher passen auf beide Bänke. Der Start-Sessel steht eine
      Rasterzelle weiter vorn, damit er nicht unter die Bank ragt
- [x] Laden 0,5 m über dem Gehweg (`GameConfig.shop_floor_rise`): draußen liegt alles tiefer,
      innen bleibt alles, wie es ist. Podest mit drei umlaufenden Stufen (`EntranceSteps`,
      nie breiter als die schräge Wand), unsichtbare Rampe zum weichen Laufen (von vorn und
      beiden Seiten getestet), Sockel ums Haus (`UpperFloors`). Lieferkartons stapeln sich weg
      von der Treppe
- [x] Einspurige Straße mit Gehwegen und Bordsteinen (`Street`), Enden biegen vor quer
      stehenden Häusern in Seitenstraßen ab, weiche unsichtbare Grenzen, Punkte für späteren
      Verkehr (`TrafficPoints`); gegenüber englische Reihenhäuser (`HouseFacade`, `Houses`)
- [x] Bücherei-Seite: Haus, Haus, Bücherei, Gasse, Haus, Haus; Häuser hinter der Gasse
      zurückversetzt, davor ein kleiner gepflasterter Platz (`Plaza`); Gasse (`Alley`) mit
      Hofmauern und austauschbarem Ende (`AlleyEnd`). Lage aller Teile: `StreetLayout`,
      alle Maße in GameConfig
- [x] Leistung geprüft (alle drei Grafikstufen: rund 20–30 Zeichenaufrufe mehr), Selbstkontrolle
      mit Testbildern aus festen Blickwinkeln (Straße, Häuserreihe, Platz, Gasse, Treppe vorn
      und seitlich, Fensterbänke, Bodenleiste) und Lauftests an allen Grenzen
- [x] Nachtrag: Gasse und Platz durchgehend mit den großen Gehwegplatten (keine kleinen
      Pflastersteine, kein eigener Gehweg in der Gasse); nur die Straße bleibt glatt

### Etappe 4e – Breitere Straße, ein gerades Straßenende und austauschbare Häuser
Leitgedanke: Die Straße wird großzügiger, ein Ende läuft geradeaus weiter, und jedes Haus
lässt sich einzeln gegen ein eigenes Modell tauschen – mit Vorlagen in echter Größe.
- [x] Gehwege etwa 30 % breiter (2,6 m und 2,1 m), Fahrbahn etwa 50 % breiter (5,1 m); alles
      passt sich über StreetLayout an. Mit Teststrahlen geprüft (10-cm-Raster über alle
      erreichbaren Stellen): keine Löcher, keine doppelten Flächen, kein Schlupfloch
- [x] Nur noch ein Ende biegt ab, das andere läuft geradeaus weiter
      (`GameConfig.straight_street_end`, Standard „east“ = Seite der bündigen Nachbarn);
      weiche Grenze quer über Straße und Gehwege, dahinter 30 m Straße mit Häusern bis zum
      Knick (`straight_street_length`). Mit Testbildern von der Grenze aus geprüft (für beide
      Einstellungen): nirgends ein Blick um den Knick oder ins Leere
- [x] Jedes Haus ein eigener Knoten in `scenes/world/houses.tscn` (im Editor sichtbar; erzeugt
      von `scenes/world/tools/generate_houses.tscn`), Haustypen als eigene Szenen in
      `scenes/world/houses/` (feste Maße, gemeinsames Mesh, Farben je Haus per Shader).
      Modegeschäft neben der Bücherei, Pub hinter der Gasse am Platz, Wohnhaus gegenüber der Tür
- [x] Vorlagen-Modelle (.glb, echte Größe) für alle Haustypen, alle Möbel, Gassenende und
      Treppe in `assets/models/templates/` (erzeugt von `export_templates.tscn`; geprüft: gleiche
      Größe und Lage wie im Spiel)
- [x] Anleitung „Außenwelt“ und „Vorlagen zum Modellieren“ in docs/ASSET_GUIDE.md

### Etappe 4f – Grenze am geraden Straßenende und Torhaus mit Durchfahrt
Leitgedanke: Feinschliff an beiden Straßenenden – am geraden Ende weiter laufen dürfen und den
Knick näher heranholen, am abbiegenden Ende statt einer Hauswand ein Torhaus mit Durchfahrt.
Dazu eine feste Arbeitsregel: Testbilder aus festen Blickwinkeln bei jeder sichtbaren Änderung.
Im Nachtrag werden beide Enden rund und bekommen Eckhäuser mit abgeschrägter Ecke; im
Nachtrag 2 rückt das Torhaus näher, unsichtbare Häuser fallen weg, gegenüber kommt eine Gasse.
- [x] Gerades Straßenende: Die Grenze steht jetzt 6 m hinter den festen Nachbarhäusern
      (`GameConfig.straight_bound_offset`), die Häuser bis dorthin sind fest. Dahinter läuft
      die Straße nur noch 20 m bis zum Knick (`straight_street_length`, vorher 30 m ab den
      Nachbarhäusern); die Seitenstraße dort ist 12 m lang (`straight_side_street_length`),
      sodass man ihr Ende nie sieht. Geprüft mit Testbildern direkt an der Grenze (Fahrbahn,
      beide Gehwege, geradeaus und schräg), Sichtstrahlen von 101 Punkten in alle Richtungen
      (nirgends ins Leere, nie bis ans Ende der Seitenstraße, gut 3 m Reserve) und einem
      Lauftest mit Physik (die Figur bleibt überall an der Grenze stehen). Die Grenze ist
      geblieben; Knick und Seitenstraße hat der Nachtrag unten durch eine runde Kurve ersetzt
- [x] Abbiegendes Ende: Torhaus mit Durchfahrt statt Hauswand – neuer Haustyp „gatehouse“
      (`scenes/world/houses/gatehouse.tscn`, Script `GatehouseFacade`): gemauerter Rundbogen
      mit Bogen-, Schluss-, Kämpfer- und Ecksteinen, gewölbte Durchfahrt, Band für ein Schild,
      Fachwerk-Obergeschoss mit zwei Sprossenfenstern, mittige Gaube mit Sprossenfenster.
      Platzhalter nur, solange kein Knoten „Model“ darin liegt; Kollision nur an den Pfeilern
- [x] Die Straße läuft mit Pflaster und Bordsteinen durch den Bogen (darunter schmale Gehwege)
      und biegt dahinter in einer sanften Kurve zur Stadtmitte hin ab
      (`StreetLayout.gate_path()`, Werte `gate_…` in GameConfig); Kulissen-Häuser entlang der
      Kurve und quer am Ende (Gruppe `GateStreet` in houses.tscn). Die Seitenstraße ist bis an
      den Bogen begehbar (`side_street_length` = 8 m, das Torhaus schließt bündig an die
      Häuser gegenüber an); die Grenze liegt im Bogen. Geprüft: Testbilder (am Bogen mittig,
      seitlich, schräg, nach oben, aus der Seitenstraße, von oben), Sichtstrahlen von 617
      Punkten, Lauftest mit Physik; beide Einstellungen von `straight_street_end` getestet.
      Die Seitenstraße davor hat der Nachtrag unten durch eine sanfte Kurve ersetzt
- [x] Vorlage `assets/models/templates/houses/gatehouse.glb` und Anleitung in
      docs/ASSET_GUIDE.md („Das Torhaus durch ein eigenes Modell ersetzen“: Öffnung des Bogens
      frei lassen)
- [x] Nachtrag: beide Straßenenden rund. Das gerade Ende biegt 8 m hinter der Grenze in einer
      runden 90°-Kurve nach rechts zur Bücherei-Seite ab (vorher eckig nach links); die
      Straße zum Torhaus macht statt eines 90°-Abzweigs eine sanfte 30°-Kurve, sodass man das
      Torhaus von der Ladentür aus zu etwa 80 % sieht (gemessen: 79–82 % je nach Standort an
      der Tür). Beide Enden sind Wege mit Kurven (`StreetLayout.end_path`), Straße, Bordsteine
      und Gehwege folgen ihnen, die Häuser stehen entlang der Kurven
- [x] Nachtrag: Eckhäuser mit abgeschrägter Ecke innen in beiden Kurven (Schräge 2,2 m,
      kürzer als bei der Bücherei, mit kleiner Ladentür und Schild) – je ein eigener Haustyp
      mit Vorlage zum Modellieren: `corner_90` und `corner_30` (Script `CornerHouseFacade`)
- [x] Nachtrag: Die Seitenwand des ersten Hauses nach den zurückversetzten Häusern am Platz
      hat Fenster (`HouseFacade.side_windows`)
- [x] Nachtrag: Prüfwerkzeug `tools/plan_check.py` (Plan von oben, Sichtstrahlen an der
      Grenze, Sichtanteil des Torhauses von der Tür); geprüft auch mit Lauftest (Torstraße auf
      fünf Spuren bis unter den Bogen, Grenze) und beiden Einstellungen von `straight_street_end`
- [x] Nachtrag 2: Das Torhaus rückt direkt hinter das Eckhaus in der sanften Kurve
      (`gate_approach_length` 4 m statt 14 m), die vier Häuser davor fallen weg, die Straße
      dahinter rückt mit – die Straße wirkt weniger weitläufig. Dafür sieht man das Torhaus
      von der Ladentür jetzt zu etwa 95 % (statt 80 %; mit dem Torhaus direkt hinter der
      Kurve lässt sich nicht mehr verdecken – geprüft auch mit späterer Kurve)
- [x] Nachtrag 2: Häuser, die man von keiner erreichbaren Stelle aus sieht, werden nicht mehr
      gebaut (innen in der Seitenstraße und quer am Ende am geraden Ende, quer am Ende hinter
      dem Bogen; Seitenstraße 8 m statt 14 m): 37 statt 51 Häuser. Geprüft mit
      `tools/plan_check.py unseen` (alle erreichbaren Stellen, jede Blickrichtung: kein Blick
      ins Leere, jedes Haus irgendwo sichtbar)
- [x] Nachtrag 2: Kleine Gasse (1,8 m) in der langen Häuserreihe gegenüber, begehbar bis zu
      einer Mauer mit Tor (`OppositeAlley`, Werte `opposite_alley_…` in GameConfig)
- [x] Nachtrag 3: Fehler behoben – nach dem Vorrücken stand in der 3-cm-Lücke zwischen
      Eckhaus und Torhaus ein ganzes Reihenhaus quer in beiden (Fenster ineinander); zu
      kurze Reihen (unter 2 m) bleiben jetzt leer (`HousesLayout.MIN_ROW_LENGTH`). Das Torhaus
      sitzt mittig zwischen den Hausfronten statt mittig auf der Fahrbahn (vorher links 1,9 m,
      rechts 1,4 m Pfeiler – wirkte schief; jetzt beide 1,65 m, `gate_center_offset`), ist
      9,8 m breit, und der Bogen ist höher (Kämpfer 2,6 m, Scheitel 5,85 m, Traufe 9,4 m)
      statt gedrungen. Vorlage neu erzeugt; Lauftest an beiden Pfeilern
- [x] Arbeitsregel „Screenshots und Selbstkontrolle“ in CLAUDE.md mit Werkzeug:
      `tools/setup_godot.sh` (Godot im Container einrichten), `tools/screenshots.sh`
      (Testbilder ohne Bildschirm, Szene `scenes/tools/screenshot_tour.tscn`, feste
      Blickwinkel in `scripts/tools/screenshot_views.gd`, Bilder in `screenshots/`)

### Etappe 4g – Einheitlicher Stil: Modelle aus Blender
Leitgedanke: Aus den Platzhaltern wird eine stimmige, stilisiert-realistische englische
Ladenstraße nach den Bildern in `Game design/` (Stil-Leitfaden: docs/STYLE_GUIDE.md). Die
Grundrisse im Spiel bleiben, wie sie sind; jedes Modell wird per Script in Blender gebaut und
ist austauschbar.
- [x] Teil 1 – Grundlagen: 20 nahtlose Stil-Texturen (Ziegel, Sandstein, Putz, Schiefer,
      Tonziegel, Lack, Glas, Laub, Pflaster …), selbst erzeugt
      (`scripts/tools/generate_style_textures.gd`); ein gemeinsames Material für alle Häuser
      (`house_style.tres`, ein Zeichenaufruf je Haus, Farben je Haus wie bisher); Blender-
      Bauteile und eigener .glb-Export (`tools/blender/style_lib.py`); HouseFacade gibt die
      Hausfarben auch an eigene Modelle weiter
- [x] Teil 1 – erstes Haus: Modegeschäft nach dem Konzeptbild (Marineblau, Goldschrift,
      Markisen, Sandstein, Ziergiebel, Gauben), Kontrollbilder aus Blender
- [x] Teil 1 – Stil-Leitfaden, Arbeitsregeln für den Dev-Container (CLAUDE.md), Dockerfile:
      Xvfb, Software-Vulkan und numpy für Testbilder und Blender-Export
- [x] Teil 1b – Modegeschäft überarbeitet (Rückmeldung): Löcher geschlossen (dünne Teile
      ohne Rückseite und aufeinanderliegende Flächen; neue Prüfung `--check` färbt Rückseiten
      pink), ganzer Ladenraum hinter Tür und Schaufenstern (dezent vintage), Name „Zwirn und
      Zwirbel“ in verspielter, größerer Schrift mit Faden-Kringel, Ausleger-Schild,
      Hängekorb, Blumenkästen, links Hortensie, rechts Olivenbäumchen und Kreidetafel;
      Puppen und Kleidung als austauschbare Platzhalter (`scenes/world/props/`, ShopProp)
- [x] Teil 1c – Ausleger-Schild und Hängekorb höher (über dem Ladengesims), Name mittig;
      alle Schilder sind Bilder zum selbst Gestalten (`assets/textures/signs/`, Startbilder
      werden nie überschrieben)
- [x] Teil 2 – Reihenhäuser (4 Breiten) und Wohnhaus: Baukasten in build_houses.py (Schiebefenster
      mit Stürzen, Haustür mit Oberlicht, Erker, georgianische Brüstung, Gaube, Vordach mit
      Säulen, Blumenkästen, Töpfe); Wandmaterial je Haus (Auto: rot/braun = Backstein, hell =
      Putz, jedes dritte Rauputz); Seitenfenster-Variante für Endhäuser
- [x] Teil 2b – Jedes Wohnhaus einzeln (Rückmeldung): eigenes Modell je Haus
      (`tools/blender/build_street.py`, Baukasten `street_houses.py`): verschiedene Höhen,
      Dachformen (Satteldach, Giebel zur Straße, Mansarddach, Brüstung mit Balustrade),
      Fachwerk (auch vorkragend, mit Läden), Traufen, Stürze, Eckquader, Gesimse, Fensterbreiten
      und Sprossen; echtes Glas mit Vorhängen, Gardinen, Rollos und vereinzelt Wohnzimmer/Küche;
      Fenster und Tür je Haus in Braun, Grau, Grün oder Blau; Sockel nicht mehr vor der Tür;
      Stufen mit Rampe, Erker, Balkone, Vorgarten mit Eisenzaun, Efeu; feinerer Rauputz;
      Schaufenster-Gucker meiden Kübel und Stufen
- [x] Teil 2c – Nachbesserungen: Fensterläden nur, wo Platz ist; Türnische bei Stufen mit
      Laibung; oberste Fenster unter dem Traufgesims; Seitenwände im Material der Front, freie
      Seiten (Gassen, Reihenenden) mit Fenstern, halb verdeckte mit Efeu; Innentüren in den
      Räumen, abwechslungsreiche Räume (Bild, Regal, Uhr, Spiegel, Pflanze, oben nur Decke
      und Lampe); kein Erker neben dem Pub; Efeu-Backsteinhaus zurückgesetzt mit Zaun;
      **Blumenladen** gegenüber der Bücherei (salbeigrüne Front, Blumentreppe, Fahrrad,
      Hängekörbe, Blumenkästen, kleiner Laden innen, Schild und Tafel als Bilder);
      Passanten: lange Hindernisse (Zaun, Fahrrad) als Reihe kleiner Kreise
- [x] Teil 2d – Fensterläden am Rahmen angeschlagen und schräg aufgeklappt (12–30°, je Laden
      anders); hintere Giebelwand der Giebelhäuser repariert; Prüfmodus
      `build_street.py -- --check <Häuser>` (Bilder je Haus mit Nachbarn, Rückseiten pink)
- [x] Teil 2e – Läden nur halb so weit offen (6–15°), nie einzeln, manche ganz zu; Glas leicht
      verschwommen (Shader `house_glass.gdshader`); Blumenladen näher am Konzeptbild (heller
      Putz, Tondach, cremefarbene Fenster, Holzschild, Rautengitter über der Tür, grünes
      Hängeschild, Hängekörbe an den Ecken, Efeu an den Pilastern, Fahrrad vor dem Regal);
      selbst bearbeitete Haus-Modelle werden beim Neubau nicht überschrieben
- [x] Teil 3 – Pub „The Ink & Ivy“ (dunkelgrüne Front, Fenster mit geätztem Glas unten,
      Doppeltür, Laternen, Hängekörbe, Fass mit Blumen, Tafel; innen Tresen, Zapfhähne,
      Flaschenregal, Tische), Eckhäuser „Teestube“ (corner_90, Backstein) und „Bäckerei“
      (corner_30, Putz) mit Ladentür in der Schräge und Schild, Torhaus „Alte Torgasse“
      (Backstein, heller Bogen mit Schlussstein, Ecksteine, gewölbte Durchfahrt mit Laternen,
      Schildband, vorkragendes Fachwerk mit Blumenkästen vorn und hinten, Tondach mit Gaube);
      alle Schilder als Bilder zum Gestalten
- [x] Teil 3b – Türklopfer entfernt (flimmerten), Glas gleichmäßig unscharf statt gewellt,
      Schaufenster klar; Pub nach Inspirationsbild (dunkle Front, Efeu, kleines Holzschild,
      rundes Hängeschild, Menütafel, Tisch und Stühle); Torhaus mit hellen Steinen bis zum
      Boden und hellem Bogen innen; Teestube mit Tür und Schild zur Straße
- [x] Teil 4a – Straße, Gehwege, Bordsteine, Platz und Gassen mit den Stil-Texturen
      (Kopfsteinpflaster, Gehwegplatten, Stein; Shader `ground_style.gdshader`),
      Abflussdeckel am Straßenrand (`drain_grate`, Abstand `Street.drain_spacing`)
- [x] Teil 4c – Läden mit Innenräumen (Inspiration Bäckerei, Teashop, Wolleshop): Bäckerei
      (Petrol, rote Markisen, Brotregale, Glastheke, Karofliesen, Lichterkette), Teestube
      (schwarz-gold, Teekannen-Schild, Tische mit Decken, Teekannen, Etagere, Teedosen; Tür zur
      Straße), neuer Wolle- und Stoffladen rechts neben dem Blumenladen (2 Etagen, Giebel zur
      Straße, Fächerregal mit Wolle, Stoffballen, Körbe, Sessel); dunkle, detailreiche
      Gaststube im Pub (Kamin, Sitznischen, Tresen mit Spiegel, Zinnkrüge), Seitenfenster in
      die Gaststube; Fenster der Läden auch von innen sichtbar; Türen ohne Lücke; Fahrrad
      gerade; Torbogen weich schattiert und mit Schatten; Shabby-Chic-Lack und verwitterte
      Texturen (Holz, Backstein, Putz, Sandstein)
- [x] Teil 4d – Rückmeldungen: Lack wieder glatt, Fensterbögen aus eigenen Ziegeln, Teestube
      innen mit rauem Glas, Bäckerei und Wolleladen getauscht (Bäckerei im schmalen Haus,
      Wolle & Stoff im Eckhaus), Blumenladen und Bäckerei voller eingerichtet;
      viktorianische Straßenlaternen mit Hängekörben, Wandlaternen am Torhaus, mehr Blumen;
      Gasse an der Bücherei länger mit hohen Hauswänden und Garten (Baum mit runder Bank),
      Gasse gegenüber verläuft sich zwischen Steinbögen (`build_alleys.py`); halb so viele
      Abflussdeckel; schneller rennen; Schatten über die ganze Straße (Sonne 70 m, alle Häuser,
      Passanten und Fahrzeuge); Lieferwagen nach 14–18 s; Passanten erscheinen nicht mehr
      sichtbar durch die Teestube, überqueren nicht neben Laternen
- [x] Teil 4e – Bücherei von außen: alte englische Ladenfront aus dunkelgrünem Holz
      (Vertäfelung, Pilaster mit Konsolen, Sockelfelder, Schildband mit Bild, Gesims,
      Wandlaternen, Hängekörbe; `build_library.py`), Fenster fast bodentief (0,30–2,60 m,
      Fensterbank als Ablage bleibt), Obergeschoss aus Backstein
- [x] Teil 4e2 – Rückmeldungen: Laternenmasten nur noch auf der Bücherei-Seite (größere Abstände,
      keiner vor der Bücherei), gegenüber hängende Laternen an Wandarmen (`wall_street_lantern`,
      Plätze sucht `build_street.py`, `HouseFacade.lanterns`); Garten der Gasse hinten mit
      Backsteinwänden geschlossen, Fallrohre nie vor Fenstern; Bank zum Sitzen (Spielfigur und
      Passanten, die Platzhalter-Figur hat jetzt Knie); kleine Gasse gegenüber mit großem
      Kopfsteinpflaster, Passanten kommen von der Tür hinter den Bögen durch die unsichtbare
      Grenze; Passanten erscheinen nur noch an den Enden (unsichtbare Grenzen verdecken nicht
      mehr, Start nur hinter den Grenzen), weniger in den Gassen; Schilder des Blumenladens
      wieder verbunden
- [x] Teil 4e3 – Passanten bleiben nicht mehr hängen: an Engstellen (Laterne, Kübel, Kiste)
      kurz an den Fahrbahnrand, links aneinander vorbei, Überqueren nur an freien Stellen,
      Sicherheitsnetz (bei Klemmen kurz durch feste Hindernisse); Fehler behoben: Passanten aus
      dem Vorrat suchten ihren Weg an der alten Stelle. Prüfwerkzeug meldet jetzt auch kurzes
      Auf-der-Stelle-Treten ("stall")
- [x] Teil 4f – Echte Pflanzen und nichts schwebt mehr: Pflanzen-Texturen per Godot-Script
      (Efeu-, Laub-, Geranien-, Funkien-, Olivenblatt, Buchs- und Laubzweig, Farn, Gras, Blüten
      von Geranie, Hortensie, Petunie, Margerite, Lavendel, Rinde; Form über Alpha), eigenes
      Pflanzen-Material (beidseitig, Licht scheint durch); Pflanzen-Bibliothek
      `style_plants.py`: Efeu wächst zusammenhängend aus einem Pflanzloch die Wand hoch (Triebe,
      Haftwurzeln, Blätter an Stielen, um Fenster und Fallrohre herum, über Gesimse), Efeu auf
      dem Pub-Gesims aus einem Trog, Blumenkästen und Hängekörbe (Drahtkorb, Kokosmatte,
      Ketten) quellen über, Buchskugeln, Kegel, Hochstämmchen, Olivenbäumchen, Hortensien,
      Lavendel, Farne, Funkien, Rosen, Baum im Garten, Sträuße im Blumenladen (Tulpen, Rosen,
      Margeriten, Hortensien, Lavendel, Grün); Töpfe, Eimer, Kästen oben offen mit Rand und
      Erde; Blätter wachsen nie in Wände, Töpfe oder Kästen (`Space`, `settle`). Fehler
      behoben: Kreidetafeln schwebten 3,5 cm, Sträucher steckten in Töpfen, Töpfe/Kästen
      waren oben zu, Türknäufe, Schild, Bilder, Vorhang, Lampen, Lichterkette, Kerzenflammen,
      Stehlampe, Kranz, Balkongeländer, Auslage-Stufen, Wollknäuel, Knöpfe, Schild am Eckhaus,
      Wandlaternen am Torhaus und an der Bücherei schwebten. Neues Prüfwerkzeug
      `geo_check.py` (schwebende Teile, Blätter in festen Teilen, mit Programmzeile),
      Blickpunkte `details`
- [x] Teil 4f2 – Rückmeldungen zu den Pflanzen: vollere, buschige Töpfe in vier Größen (mit
      Grün unter den Blüten und Ranken über den Rand), Töpfe in unregelmäßigen Gruppen zu
      zweit oder dritt (`pot_cluster`) auf der Straße und in den Gassen, drei verschiedene
      Hängekörbe (Sommerkorb, Fuchsien im Weidenkorb, Petunien-Wasserfall), Fahrradkorb mit
      Grün und herabhängenden Ranken, Blumenladen aufgeräumt (keine Eimer mehr im Regal),
      Efeu bedeckt am Steinhaus beim Pub die ganze Wand (`ivy_cover`), hellere Schatten
      draußen (Himmelslicht `SkyFill` nur für die Außenwelt), neue Kreidetafeln der
      Entwicklerin und eine Tafel vor dem Wolleladen. Prüfwerkzeug findet jetzt auch Flimmern
      (zwei Flächen genau aufeinander) und Töpfe, die in Regalen oder Wänden stecken;
      viele kleine Flimmer-Stellen an Gesimsen, Dachrinnen, Fenstern und Zäunen behoben
- [ ] Teil 4g – Möbel und Deko im Stil, Innenraum der Bücherei
- [ ] Teil 5 – Möbel und Deko (42 Stück) im selben Stil
- [ ] Teil 6 – Innenraum der Bücherei (Wände, Boden, Decke, Fenster innen, Theke)

### Etappe 4h – Bilderbuch-Stil
Leitgedanke: Die Welt wird zu einer lebendig gewordenen Kinderbuch-Illustration – warm,
handwerklich, bewusst unperfekt, aber solide gebaut (Regeln: docs/STYLE_GUIDE.md, Abschnitt
„Bilderbuch-Stil“). Haus für Haus, Lage, Wege und Spielablauf bleiben gleich.
- [x] Modegeschäft „Zwirn und Zwirbel“ neu nach dem Vorlagebild der Entwicklerin
      (`tools/blender/build_storybook_shop.py`, Bausteine `storybook_lib.py`): cremefarbener
      Putz mit Ecksteinen, taubenblaue Ladenfront mit Nussbaum-Schild und Goldschrift,
      terrakotta-rosa Markisen, halbrundes Oberlicht über der Tür, vier Schneiderpuppen im warm
      leuchtenden Laden, Wandlaternen, Zahnschnitt-Gesims, Ziergiebel mit Rosette, zwei Gauben,
      Dach aus einzeln schiefen Ziegeln, Schornsteine; Efeu an beiden Ecken und über dem Schild,
      überquellende Blumenkästen mit Geranien und Hängepetunien, Buchs, Hortensie, Olivenbaum,
      Kreidetafel. Alles leicht verzogen (Wände wellig, Haus minimal geneigt, Dach in der Mitte
      durchgesackt, Bauteile um Bruchteile eines Grads schief). Jedes Teil ist ein geschlossener
      Körper und einzeln in Blender bearbeitbar (`assets/models/source/houses/fashion_shop_storybook.blend`);
      fürs Spiel eine leichtere Kopie (Blätter nur als Oberseite, Teile je Material
      zusammengefasst, Detailstufen) mit eigenem Shader `storybook.gdshader` (Materialien
      `assets/materials/storybook/`). Selbst bearbeitete .blend wird nie überschrieben,
      `export_storybook.py` bringt sie ins Spiel
- [x] Altes Modegeschäft entfernt (Modell, Puppen- und Kleidungs-Requisiten, Script `ShopProp`,
      Schild-Bilder)
- [x] Modegeschäft nachgebessert (Rückmeldung): Türzarge, flache Platte statt Stufen,
      Aufsteller richtig herum, Giebel unter den Gaubendächern, breitere weiche Kanten; jedes Blatt
      und jede Blüte ein kleiner Körper (auch im Spiel), runde Efeu-Triebe mit Herzblättern,
      üppige rote/rosa Geranien, große Hortensie, volle Olivenkrone
- [x] Laternen im Bilderbuch-Stil (`build_storybook_lamps.py`): ein gemeinsamer Laternenkopf nach
      dem Beispielbild für Straßenlaternen (neuer Mast mit Schnecken und zwei Hängekörben),
      hängende Laternen an den Häusern und Wandlaternen am Modegeschäft
- [x] Pub „The Ink & Ivy“ neu nach dem Vorlagebild (`build_storybook_pub.py`): ziegelroter
      Backstein mit hellen Bögen über den Fenstern, flaschengrüne Ladenfront mit Sprossenfenstern,
      Zahnschnitt-Gesims, Schieferdach, Gaststube (rote Wände, Tresen, Flaschenregal, Sitznischen,
      Kerzen), Bistrotische mit Stühlen, Terrakotta-Töpfe, Blumenkästen; alter Pub entfernt
- [x] Schilder der Entwicklerin (Bilder) auf Schild-Körpern bei Pub und Modegeschäft (Ladenschild,
      Ausleger-/Hängeschild, Kreidetafel, „Geöffnet“-Kärtchen)
- [x] Pflanzen an Pub und Modegeschäft vorerst entfernt – nur Töpfe, Kübel und Kästen
- [x] Pub ohne Lücken: Tür, Schildkasten, Fenster mit Bögen; Lochprüfung für alle
      Häuser (`tools/blender/storybook_gap_check.py`)
- [x] Fünf weitere Häuser nach den Vorlagebildern, gemeinsame Bausteine `storybook_town.py`
      (Wände entlang beliebiger Grundrisse, Walm- und Satteldächer aus einzelnen Ziegeln, Fensterläden,
      Türen, Ladenfronten, Schildkästen, Blumenampeln, Hollandrad, Stoff-Markisen):
      Bäckerei (Giebel zur Straße, rot-weiße Markise, Brot im Fenster), Blumenladen (Fahrrad mit
      Körben auf dem Ständer, Pflanzkasten über dem Schild, Ampeln, viele Töpfe), Teeladen (Eckhaus
      aus Backstein, Fensterläden, Tee, Dosen und Kannen statt Büchern), Wolleladen (Eckhaus mit
      30°-Knick, Schildband um beide Ecken, Schild nur über den Fenstern, viele Kübel, Wolle im
      Regal), Torhaus (Rundbogen aus Sandstein, Gewölbe, Schildband „Alte Torgasse“, Fachwerk,
      Gaube, Wandlaternen mit dem neuen Kopf); alte Modelle dieser Häuser entfernt
- [x] Markisen aus einem Stück Stoff (Blender-Stoffsimulation, mit Dicke), auch am Modegeschäft;
      im Spiel schwingen sie leicht im Wind (`wind_strength` im Shader)
- [x] Licht an der Straße geplant (Wunsch der Entwicklerin): Masten nur auf der Bücherei-Seite
      (x = −18,5 / −7,5 / 14, `Street.lamp_positions`), sonst hängende Straßenlaternen am Wandarm
      (`storybook_parts.street_wall_lantern`, gleicher Kopf). Neu an den Bilderbuch-Läden:
      Blumenladen (gegenüber der Bücherei-Tür), Teeladen (Ende der geraden Straße), Wolleladen
      (Torstraße); Torhaus mit zwei Wandlaternen; Pub braucht keine (Mast davor)
- [ ] **Laternen an Wohnhäusern beim Neubau** (Plan): behalten an Opposite1_1, Opposite1_3,
      Opposite2_1, Opposite2_5 (gleiche Stelle wie jetzt, `LANTERNS` in build_street.py); neu an
      StraightEnd/Outer3 (Kurve am geraden Ende), GateStreet/Bend3 (Torstraße, Bücherei-Seite) und
      GateStreet/BehindOuter3 (hinter dem Torbogen); keine an LibraryRow/Neighbor2 und Neighbor4,
      StraightEnd/Street1 und Street2 (Masten bzw. Teeladen-Laterne in der Nähe)
- [ ] Pflanzen im Bilderbuch-Stil zurück (wenn die Entwicklerin so weit ist); dabei die Hängekörbe
      der Straßenlaterne prüfen: build_storybook_lamps.py baut sie zurzeit spärlicher als die
      hochgeladene street_lamp.glb (darum nicht neu exportiert)
- [ ] Wandlaternen an der Bücherei mit dem neuen Kopf (wenn sie dran ist)
- [ ] Weitere Häuser im Bilderbuch-Stil (jedes mit eigener Wölbung und eigenen Farbtönen)
- [ ] Licht der ganzen Welt: warm um 3500 K, weiche Schatten, mildes Bloom, etwas mehr
      Umgebungsverdeckung (AO), leichte Schärfentiefe, Fensterlicht als Blickfang
- [ ] Kopfsteinpflaster und Wege handverlegt (versetzte Reihen, kleine Höhenunterschiede)
- [ ] Mehr Grün an Straßenrändern und Plätzen (Büsche, Bäume)

### Stil-Umbau der Welt (Etappe 4h, selbstständig abgearbeitet)
Auftrag der Entwicklerin (2026-10-18): die ganze Welt im Stil der Ladenhäuser und der Vorlagebilder
(süß, weich, cozy, leicht stilisiert; Cottages mit cremefarbenem Putz, Terrakotta-Ziegeln, runden
Gauben, Rundbogenfenstern, braunen Backsteinen, rundem Kopfsteinpflaster, viel Grün). Jedes Detail
ein geschlossener Körper. Ohne Rückfragen: Entscheidungen werden unten unter „Entscheidungen“
notiert. Nach jedem Schritt: Screenshots prüfen, Spielablauf prüfen (Laufen, Grenzen, Kollision,
Lieferung, Laden, street_life_check), Commit + Push. Figuren und Straßenleben bleiben, wie sie sind.
Bricht eine Sitzung ab: hier beim ersten offenen Punkt weitermachen.
- [x] 1. Wohnhäuser neu (eigene Datei, Schema wie die Ladenhäuser): alle Reihenhäuser und
      Kulissenhäuser im neuen Stil, Breiten/Höhen/Farben der bisherigen Varianten als Anhaltspunkt,
      Laternen nach Plan (siehe oben), sparsam für alle drei Grafikstufen
- [x] 2. Gassenende, Hofmauern und die Fassade der Bücherei (außen) im neuen Stil
- [x] 3. Straße, Gehwege, Bordsteine, Platz, Gasse und Eingangstreppe: weiche Kanten, warme
      Steintöne, Platten und Pflaster leicht unregelmäßig (Shader storybook_ground.gdshader:
      rundes Kopfsteinpflaster, Platten in Reihen, Bordstein-Quader, Kleinpflaster; gerundete
      Bordstein- und Stufenkanten): weiche Kanten, warme
      Steintöne, Platten und Pflaster leicht unregelmäßig
- [x] 4. Kleine Dinge draußen (Abflussdeckel neu, Briefkästen und Brett-Fensterläden an den Häusern,
      Türen mit Eisenbändern, Laternen mit dem gemeinsamen Kopf, Schilder bleiben Bilder) (Laternen, Schilder, Türen, Fensterläden, Briefkästen, Abflussdeckel,
      Bank) im selben Stil
- [x] 5. Pflanzen ganz neu: üppig, verschlungen, rund; jedes Blatt ein Körper; Efeu und
      Kletterpflanzen an Fassaden, Blumenkästen, Kübelpflanzen vor Türen, Ranken an Torhaus und
      Gasse, kleine Bäume/Büsche auf dem Platz; als austauschbare Szenen mit Vorlagen in
      assets/models/templates/ (30 Pflanzen: Geranien, Petunien, gemischte Kästen, Busch,
      Hortensie, Olive, Lavendel, Ampeln, Efeu, Kletterrosen, Glyzinie, Funkie, Farn, Margeriten, Hecke,
      Rosenstrauch, Gartenbaum, Bäumchen im Kübel; Greenery setzt sie auf ~350 Pflanzplätze)
- [x] 6. Rundgang: Screenshots aller wichtigen Blickpunkte, angleichen (auch Ladenhäuser, falls
      nötig), Holzmaserung und Farben authentischer, so lange bis die Welt stimmig ist
- [x] 7. Doku: GAME_DESIGN.md, ROADMAP.md, ASSET_GUIDE.md (neue Dateien, eigene Modelle für Häuser
      und Pflanzen einsetzen); Zusammenfassung mit Screenshots und Entscheidungsliste

**Entscheidungen (selbst getroffen):**
- Wohnhäuser: dieselben 29 Häuser an denselben Stellen (Breite, Tiefe, Geschosse, Dachform,
  Wandart, Fensterspalten, Türseite, freie Seitenwände aus der bisherigen Beschreibung
  build_street.make_spec), aber komplett neu gebaut (tools/blender/storybook_houses.py +
  build_storybook_street.py). Der Bilderbuch-Stil je Haus (Putzfarbe, Ziegel-/Quaderton,
  Fensterform Rundbogen/Segmentbogen/Rechteck, Brettertür mit Bogen, Gauben, Markise, Vordach …)
  kommt fest aus dem Hausnamen – bei jedem Neubau gleich.
- Je Haus eine eigene .blend (assets/models/source/houses/storybook/) statt einer großen Datei –
  so lässt sich jedes Haus einzeln nachmodellieren und wird nicht überschrieben.
- Leistung: Im Spiel teilen sich gleichartige Oberflächen ein „Sammel-Material“ (Farbe steckt in
  den Ecken) → 8–10 Zeichenaufrufe je Haus statt ~30; Dächer aus Ziegelreihen (je Reihe ein Körper
  mit runden Ziegelkanten) statt Einzelziegeln; Rückseiten und ferne Kulissenhäuser schlichter;
  Godot-LODs mit Schwelle je Grafikstufe (GameConfig lod_threshold).
- Brett-Fensterläden mit Z-Riegel statt Lamellenläden (Cottage-Stil, ein Fünftel der Dreiecke).
- Keine Erker in den Gehweg (Passanten/Physik); stattdessen kleine Stoffmarkisen über einzelnen
  Erdgeschossfenstern (wie Vorlagebild 2). Vor Haustüren nur flache Platten, keine Stufen.
- Mansard-/Flachdach-Varianten der alten Häuser werden Satteldächer mit Gauben.
- Pflanzen gehören nicht ins Haus-Modell: Häuser legen leere Pflanzplätze an (PlantSpot_…),
  Schritt 5 setzt dort austauschbare Pflanzen-Szenen ein.
- Laternen an Wohnhäusern nach Plan über HouseFacade.lanterns (ein gemeinsames Modell).
- Bücherei: neue Außenhülle als Blender-Modell (grüne Holzfront wie bisher, darüber Ziegel-
  Obergeschoss mit Bogenfenstern, Walmdach aus Ziegelreihen); UpperFloors baut nur noch die leeren
  Geschoss-Knoten (build_visuals = false). Fenster, Tür und Wände des Ladens bleiben unverändert.
- Gassen: Rückwände mit Fenstern, Feldsteinsockeln und Dachansätzen, Hofmauern, Lattenzaun, runde
  Holzbank; Baum, Hecke, Beete, Efeu und Töpfe kommen in Schritt 5 auf Pflanzplätze.
- Kleine Wand-Briefkästen an etwa der Hälfte der nahen Wohnhäuser (Cozy-Detail, neu).
- Boden: eigener Shader ohne Bilder (Steine werden aus der Lage berechnet, aus der Ferne
  weich ausgeblendet); Farben je Material im Inspektor einstellbar.
- Häuser mit Straßenlaterne bekommen keine Stoffmarkisen (die Laterne hing sonst darin).
- Die Kübel-Ecke der Bäckerei zur kleinen Gasse bleibt frei (dort blieben Passanten stecken).
- Pflanzen: eigene Formen statt Kugeln – Blatt-Büschel aus vielen linsenförmigen Blättern um einen
  kleinen dunklen Blattkern (der Kern füllt Lücken, man sieht ihn kaum), Kletterpflanzen als dichte
  Blattpolster entlang geschwungener Triebe, Rosen aus Blütenblatt-Ringen, Hortensien aus vierblättrigen
  Blüten. Pflanzen stecken nicht in den Haus-Modellen, sondern kommen über Pflanzplätze und eigene
  Szenen (scenes/world/plants/) – austauschbar ohne Neubau der Häuser.
- Leistung der Pflanzen: gleiche Pflanzen je 26-m-Gebiet als MultiMesh, kleine Pflanzen werden in der
  Ferne ausgeblendet (Faktor je Grafikstufe plant_distance), auf „Niedrig“ ohne Pflanzenschatten.
- Pflanzen und Blumen wiegen sich leicht im Wind (gleicher Wind wie die Markisen).
- Auf dem Platz nur ein Bäumchen im Kübel (am Ende der Häuserreihe); ein zweites am Gasseneingang
  blockierte Passanten auf ihrem Weg in den Garten.
- Rundgang: echte Holzmaserung im Shader (Bretter in verschiedenen Tönen, Jahresringe, Poren, seltene
  Astlöcher, Fugen), wärmeres Kopfsteinpflaster; die Bäckerei bekam Fenster in der Seitenwand zur
  kleinen Gasse (vorher eine leere Fläche); Kletterpflanzen wachsen nicht mehr in Fensterläden.
- Die Ladenhäuser passen zum neuen Stil und wurden nur angeglichen (Pflanzplätze, Ziegel, Holz),
  nicht neu modelliert.
- Noch nicht im Bilderbuch-Stil: Möbel und Innenraum der Bücherei (gehören nicht zur Welt draußen),
  die Laternenmasten (Hängekörbe noch im alten Pflanzenstil).
- build_street.py baut nur noch mit „-- --alter-stil“ (sonst würde es die neuen Häuser in
  houses.tscn zurückstellen).

## Etappe 5 – Besucher
Leitgedanke: Bevor Kunden in die Bücherei kommen, wird erst die Straße lebendig (5a); danach
kommen Besucher herein (weitere Unterschritte).
- Besucher kommen herein, stöbern, leihen aus, warten geduldig an der Theke
- Besucher nehmen Bücher aus Regalen (`BookShelf.remove_books`) und werfen sie in den
  Rückgabekasten (`ReturnBox.add_books`); dann die Testtasten abschalten (`GameConfig.debug_keys_enabled`)

### Etappe 5a – Leben auf der Straße
Leitgedanke: Passanten, Fahrräder, ein, zwei Autos und ein kleiner Lieferwagen machen die
Straße lebendig – ruhig und gemütlich, keine volle Innenstadt. Grundregel: Niemand erscheint
oder verschwindet sichtbar.
- [x] Feste Orte zum Erscheinen und Verschwinden außer Sicht (TrafficPoints an beiden
      Straßenenden hinter den Kurven, neu: je ein Punkt vor dem Tor am Ende beider Gassen) und
      bei jedem Erscheinen/Verschwinden eine Sichtprüfung (im Bild mit Rand und nicht von Häusern
      verdeckt; Häuser ohne feste Kollision haben dafür einen unsichtbaren Sichtblocker, neue
      Physik-Ebene `sight_blocker`; durch Fenster und den Torbogen sieht man hindurch). Ist der
      Ort zu sehen, wartet das Erscheinen; wer verschwinden will, geht ein Stück weiter oder
      wartet am Gassentor. Geprüft mit dem neuen Prüfwerkzeug `scenes/tools/street_life_check.tscn`
      (15 erreichbare Stellen, Kamera rundherum, je 60–80 s vorgespult, mehrere Zufallsläufe:
      jeweils über 100 Mal erschienen und verschwunden, 0 Mal im Blickfeld) und Testbildern
      von den Grenzen, dem Torbogen und den Enden der Gassen
- [x] Passanten auf beiden Gehwegen, in beide Richtungen, verschiedenes Tempo; sie weichen
      einander aus (links, wie in England), ebenso der Spielfigur, der Treppe und den Kartons,
      laufen nie in die Spielfigur und drehen um, wenn sie lange den Weg versperrt. Die Gehwege
      werden beim Start mit der Physik an die Häuser angepasst (Kurven, Eckhäuser, Torbogen).
      Geprüft: keine Überschneidungen, niemand in Häusern, niemand hängt fest; Lauftest mit
      Physik (die Spielfigur gleitet an Passanten vorbei bzw. kommt immer frei zurück)
- [x] Passanten überqueren manchmal die Straße (Bordstein, umschauen, warten, hinüber),
      bleiben vor Schaufenstern stehen (Modegeschäft, Pub, Bücherei; weitere Punkte unter
      `Outside/StreetLife/WindowSpots`) und kommen aus den Gassen oder verschwinden darin
- [x] Für den nächsten Schritt vorbereitet: Signal `StreetLife.passing_library`, wenn ein Passant
      vor der Bücherei vorbeikommt, und ein fester Punkt vor der Treppe
      (`StreetPaths.library_entrance()`)
- [x] Austauschbare Platzhalter-Figur (`scenes/street_life/passerby.tscn`: Kopf mit Frisur,
      Körper, Arme, Beine, Laufbewegung, eigene Farben und Größen), vorbereitet für eigene
      Figuren mit AnimationPlayer (Gehen, Stehen, Umschauen, Schaufenster); Anleitung in
      docs/ASSET_GUIDE.md („Eigene Passanten“)
- [x] Fahrradfahrer fahren durch, in beide Richtungen, ohne anzuhalten (langsam außen um
      Hindernisse herum) – austauschbare Szene mit tretender Platzhalter-Figur
- [x] Höchstens zwei Autos (Linksverkehr), bremsen weich für Fußgänger auf der Fahrbahn und
      die Spielfigur; unter dem Torbogen langsam; niemand muss überholen
- [x] Kleiner, rundlicher Lieferwagen bringt die Kartons: kommt vom geraden Ende, hält vor der
      Bücherei, Schiebetür auf, die Kartons hüpfen einzeln an ihren Platz (nicht dorthin, wo
      jemand steht; sonst wartet er), fährt weiter und verschwindet hinter dem Torhaus.
      Bestellungen während der Fahrt kommen bei der nächsten Fahrt; was im Wagen ist, wird
      gespeichert (getestet: speichern, laden, Kartons kommen). Kartons höchstens zwei Reihen
      tief (der Gehweg bleibt frei). Vorlagen in echter Größe:
      `assets/models/templates/street_life/` (Lieferwagen, Auto, Fahrrad, Passant)
- [x] Alle Werte in GameConfig (Abschnitt „Leben auf der Straße“, ruhige Startwerte,
      `street_activity` für alles zusammen); später von der Tageszeit abhängig über
      `StreetLife.activity()`
- [x] Leistung: alle Figuren beim Start gebaut (nur ein- und ausblenden), ein gemeinsames
      Material, Schatten nur in der Nähe (je Grafikstufe; auf Mittel ein einfacher Schatten in
      Grundhaltung), weit weg vereinfacht. Gemessen: Niedrig etwa 11–16, Mittel 15–26, Hoch
      35–42 Zeichenaufrufe mehr (rund 5–10 %)
- [x] Testbilder-Werkzeug erweitert: `--simulate`, `--seed`, `--deliver`, `--focus`, `--stats`,
      `--quality`, Blickpunkt-Gruppe `street_life`

### Etappe 5b – Figuren und Fahrzeuge im Stil
Leitgedanke: Statt Platzhaltern echte Figuren (warm, stilisiert, Frisuren aus dicken Strähnen –
Richtung Disney Dreamlight Valley) und Fahrzeuge, die zur englischen Altstadt passen.
- [x] Figuren-Baukasten (`tools/blender/build_characters.py`, `character_lib.py`):
      Quaternius-Grundkörper (CC0) weicher gemacht, Kopf etwas größer, Formregler „Rundlich“,
      „Schlank“, „Kraeftig“; Kleidung als Hülle um den Körper (gleiche Gewichte und Formregler,
      gerade Säume, Bündchen, Schichten innen → außen), Röcke und Mantelschöße als Glocke,
      Schuhe aus Querschnitten, Frisuren aus Strähnen (lang, lockig, Dutt, kurz, Seitenscheitel),
      Bart, Mütze, Schal; 3 Frauen und 3 Männer; Baukasten je Grundkörper; Mixamo-Dateien
- [x] Fahrzeuge (`tools/blender/build_vehicles.py`): Taxi, Mini, Kombi mit Holzrahmen,
      Lieferwagen (Bulli mit Nest-&-Nook-Logo als austauschbares Bild), Hollandrad; Räder und
      Kurbel drehen sich (`VehicleModel`, `CyclistPlaceholder`); neue Stil-Ebenen Autolack,
      Chrom, Gummi, Leder; das Rad vor dem Blumenladen ist dasselbe Hollandrad
- [ ] Animationen von Mixamo (Gehen, Stehen, Umschauen, Sitzen …) übertragen und die Figuren
      als Passanten einsetzen (danach: Fahrer auf den Rädern, Besucher in der Bücherei)

### Etappe 5c – Chibi-Figuren
Leitgedanke: niedlicher und gemütlicher als die realistischen Figuren – Chibi-Proportionen
(Kopf 30 % der Körpergröße), weiche Vinyl-Formen, gezeichnete Manga-Gesichter.
- [x] Grundkörper: Frau und Mann je klein/mittel/groß, Formregler dünn/dick, Bandeau + Slip bzw.
      Boxershorts, Bauch mit Nabel, Knopfnase, Ohren; T-Pose, Skelett mit Godot-Humanoid-Namen;
      Mixamo-Dateien
- [x] Gezeichnetes Gesicht mit Ausdrücken, Blickrichtung, Blinzeln und Sprechen (Shader +
      `ChibiCharacter`), Frauen mit Schmuckwimpern
- [x] Körper neu gebaut (Rückmeldung der Entwicklerin: Licht wirkte kaputt, Brust unter den Armen
      verformte sich, Hand verdreht, ungesunde Schultern): Netz nur aus Vierecken mit Ringen um die
      Gelenke (Käfig `chibi_cage.py`, zweimal geglättet und auf die Form gelegt), Normalen aus dem Netz,
      Arme/Beine ohne Beulen, flachere Schultern, neue Hand (Handfläche unten, Schwimmhaut, Daumen vorn),
      neues Skelett mit breiten, weichen Gewichten (`chibi_rig.py`), Bewegungsprobe `--views=poses`;
      dünn/dick verschieben die Gelenke in Godot (`ChibiShapeModifier`); Mixamo-Datei mit unserem
      Skelett (Mixamo-Namen), dazu eine ohne Skelett als Ersatz
- [x] Einfache Grundausstattung: T-Shirt, Pullover, Hose, Rock, Schuhe; Frisuren Bob mit Pony, Dutt,
      Zöpfe, Kurzhaar (`chibi_outfit.py`; Kleidung = Hülle aus dem Körper mit denselben Gewichten und
      Formreglern, Rock als Glocke, Frisuren aus weichen Grundformen am Kopf-Knochen); in Godot
      wählbar mit Farben (`ChibiCharacter`: top, bottom, shoes, hair)
- [x] Chibi-Figuren als Passanten (`passerby_chibi.tscn`, `ChibiPasserbyModel`: zufälliges Aussehen,
      einfache eigene Bewegung); street_life_check ohne Fehler
- [x] Mixamo-Animationen übertragen (Gehen, Stehen, Schaufenster, Hinsetzen, Sitzen, Aufstehen;
      `chibi_anim.py`, je Knochen die Drehung gegenüber der T-Pose, Hüfte im Verhältnis der Größe);
      Umschauen mit gedrehtem Kopf (`ChibiHeadModifier`); Rock folgt den Beinen, Hosenrock darunter
- [ ] Radfahrer als Chibi-Figuren (eigene Tret-Animation; die alten Radfahrer traten rückwärts),
      danach mehr Kleidung

## Etappe 6 – Wirtschaft und Tagesablauf
- Grundlage schon vorhanden (Etappe 2f): Geld (`Wallet`), Inventar, Shop mit Kaufen und
  Verkaufen, Lieferung
- Einnahmen: Leseausweise, Abstempeln, Leihgebühren, Mitgliedschaften (über `Wallet.earn`)
- Beschädigte Bücher und Reparatur (Feld `Book.condition` ist schon vorhanden)
- Tag mit Öffnen-Schild, Pause und Vorspulen; Tagesabrechnung aus den Buchungen
- Preise und Startgeld ausbalancieren

## Etappe 7 – Stilsystem und Besuchervielfalt
- Stil-Merkmale an Möbeln (Botanisch, Modern, Dark Academia) – Grundlage seit Etappe 2 vorhanden
- Genres tragen schon einen passenden Stil (Datenblatt) – kann später mitzählen
- Vorherrschender Stil beeinflusst Besucher und Musik

## Etappe 8 – Café
- Café-Module an der Theke anbauen (die Theke ist seit Etappe 4a dafür vorbereitet)

## Etappe 9 – Erweiterungen und Freischaltungen
- Weitere Räume, Obergeschoss, Genres freischalten (`BookStock.unlock_genre`), Renovieren
- Einzelne Bücher nach und nach freischalten und sammeln (Grundlage: Sammlung in BookStock,
  `is_discovered`, `mark_discovered`; Pakete wählen bisher automatisch neue Titel)
- Neue Möbel im Shop freischalten (Datenblatt-Feld `is_unlocked`)

## Etappe 10 – Atmosphäre und Sound
- Musik je Stil, Geräusche, Tageszeit-Licht

## Etappe 11 – Story und Spiegel
- Kleine unerklärliche Ereignisse, der Spiegel und seine Wesen

## Etappe 12 – Gasse, Fassade und Jahreszeiten
- Die Gasse vor dem Haus (bisher: ein Stück Gehweg als Platzhalter), Fassade gestalten
  (in der App „Fassade“ aus Etappe 3l, z. B. Wandfarbe außen, Schild, Fenster), Jahreszeiten
  – baut auf der Außenwelt aus Etappe 4 auf

## Etappe 13 – Feinschliff
- Menüs, Einstellungen, Speichern/Laden, Balancing
