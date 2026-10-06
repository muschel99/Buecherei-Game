# Cozy Bücherei – Game Design

## Kurzbeschreibung
Ein gemütlicher Cozy-Simulator in der Ego-Perspektive. Man kauft ein altes, renovierungsbedürftiges
Reihenhaus in einer kleinen englischen Gasse und baut darin Schritt für Schritt eine Bücherei mit
optionalem Café auf. Am Anfang ist nur der erste Raum im Erdgeschoss nutzbar, weitere Räume und ein
Obergeschoss werden mit verdientem Geld freigeschaltet und renoviert.

## Grundprinzipien
- **Entspannt:** ohne Hektik, ohne Zeitdruck, ohne Strafen. Besucher warten geduldig.
- **Ästhetik:** gemütlich, nicht kitschig. Inspiriert von Miniatur-Book-Nooks, in Richtung
  Paralives oder Garden Life. Stimmung entsteht vor allem über warmes, weiches Licht.
- **Gestaltung:** Möbel und Raumteiler frei platzieren, Wände streichen, Böden tauschen.
  Kein freier Wandbau. Gestaltet wird in der Ego-Perspektive (Taste Tab), frei oder mit
  Einrasten. Deko kann auf Ablageflächen stehen oder an Wand und Tür hängen.
  Der Eingangsbereich vor der Tür bleibt frei. Gestaltet wird mit dem, was man besitzt
  (Inventar); Neues kauft man im Shop.
- **Stile:** Zum Start drei Stile: *Botanisch*, *Modern*, *Dark Academia*. Möbel tragen
  Stil-Merkmale. Der vorherrschende Stil bestimmt, welche Besucher kommen und welche Musik läuft.

## Bücherei-Wirtschaft

### Geld, Inventar, Shop und Lieferung (seit Etappe 2f)
- **Geld:** Ein zentraler Kontostand (Taler), zum Start 500 Taler. Er steht dezent oben links;
  Einnahmen und Ausgaben erscheinen kurz darunter (+80 / −320).
- **Inventar:** Alles, was mir gehört und gerade nicht im Raum steht. Möbel und Deko werden
  gezählt (z. B. „Bücherregal ×2“). Die Möbel, die zum Start im Raum stehen, gehören mir.
  Wandfarben, Böden und Decken kauft man einmal und kann sie danach unbegrenzt verwenden;
  ein paar schlichte Farben (Warmer Putz, Kalkweiß, Nebelgrau), ein Boden (Eichendielen) und
  zwei Decken sind von Anfang an da.
- **Shop am Tablet:** Auf der Theke steht ein Tablet. E öffnet den Shop (Mauszeiger sichtbar,
  Esc schließt ihn, die Figur steht solange still).
  - *Kaufen:* alle freigeschalteten Möbel, Deko, Wandfarben, Böden und Decken nach Kategorien,
    mit kleinem Vorschaubild, Preis und Stil-Merkmalen. Über der Liste helfen Filter beim Suchen
    (siehe „Filter“). Ein Klick legt etwas in den Warenkorb
    (Möbel auch mehrfach, Oberflächen einmal); „Bestellen“ bezahlt.
    Reicht das Geld nicht, steht dort freundlich, wie viel fehlt – ohne Strafe.
  - *Verkaufen:* Möbel aus dem Inventar (nicht die im Raum) bringen die Hälfte des Preises
    zurück (Anteil in GameConfig). Oberflächen behält man.
  - Das Tablet gehört fest zur Bücherei: Es steht nicht im Shop und lässt sich nicht verkaufen.
- **Lieferung:** Kurz nach der Bestellung (10 Sekunden, GameConfig) steht ein Karton pro
  Bestellung draußen neben der Eingangstür, und ein dezenter Hinweis erscheint:
  „Deine Lieferung ist da“. E auf den Karton: Der Inhalt wandert direkt ins Inventar, der
  Karton hebt sich, dreht sich und schrumpft sanft weg. Nichts tragen, nichts einsortieren.
- Geld, Inventar, Bestellungen unterwegs und noch nicht abgeholte Kartons werden mit der
  Einrichtung gespeichert.

### Kategorien und Filter (seit Etappe 2g)
- Kategorien (Reiter): Regale, Sitzmöbel, Tische, Theke, Beleuchtung, Deko, Raumteiler sowie
  Wandfarben, Böden und Decken.
- Unterkategorien:
  - Regale: Bücherregale, Wandregale, Vitrinen
  - Sitzmöbel: Sessel, Sofas, Stühle, Hocker
  - Tische: Beistelltische, Couchtische, Schreibtische, Esstische
  - Beleuchtung: Tischlampen, Stehlampen, Deckenlampen, Wandlampen, Kerzen und Laternen,
    Lichtschalter
  - Deko: Pflanzen, Teppiche, Bilder und Wandschmuck, Figuren, Textilien (Kissen, Decken),
    Aufbewahrung und Organisation, Bücher
- Im Shop und im Gestaltungsmodus stehen über der Liste kleine Filter-Schaltflächen:
  „Alle“ und die Unterkategorien, die es dort gerade gibt, daneben der Stil-Filter
  „Alle Stile“, Botanisch, Modern, Dark Academia, Neutral (= ohne Stil-Merkmal).
  Leere Unterkategorien werden nicht gezeigt; sie erscheinen von selbst, sobald es
  passende Objekte gibt. Bei schmalen Bildschirmen rutschen die Schaltflächen in eine
  zweite Zeile.
- Beim Wechsel der Kategorie springt die Unterkategorie auf „Alle“, der Stil bleibt.

### Später (Etappe 5)
- Leihgebühren über Leseausweise (Buch abstempeln statt Wechselgeld).
- Mitgliedschaften.
- Café als zusätzliche Einnahmequelle.
- Bücher können kaputtgehen (Reparatur).
- Genres werden nach und nach freigeschaltet.

## Theke
- Modular: Kasse von Anfang an, dazu das Tablet mit dem Shop.
- Café-Elemente (z. B. Kaffeemaschine, Kuchenvitrine) später daneben anbaubar.
- Der gesamte Thekenblock ist frei platzierbar.

## Tagesablauf
- Verkürzter Tag: 20 bis 30 Minuten Echtzeit pro Spieltag.
- Öffnen-Schild an der Tür, Pause und Vorspulen.

## Story
- Kleine, unerklärliche, nicht gruselige Ereignisse.
- Später ein Spiegel, aus dem kleine Wesen heimlich Bücher ausleihen.

## Steuerung
**Grundregel:** Jede Interaktion in der Spielwelt läuft über die Taste E.
Esc schließt immer zuerst das, was gerade offen ist (Gestaltungsmodus, Shop, Menüs).
Nur wenn nichts offen ist, öffnet Esc das Pausenmenü.

| Taste          | Aktion                                         |
|----------------|------------------------------------------------|
| W A S D        | Laufen                                         |
| Umschalt       | Schneller laufen (gedrückt halten)             |
| Leertaste      | Springen (etwa 0,8 m hoch, weich); im Sitzen: aufstehen |
| Strg           | Hocken (gedrückt halten), langsamer laufen     |
| Maus           | Umsehen                                        |
| E              | Interagieren (Objekt in der Bildmitte): Lampen und Kerzen schalten, hinsetzen, Tür öffnen/schließen, Karton auspacken, Shop am Tablet öffnen |
| Tab            | Gestaltungsmodus (Inventar) öffnen/schließen   |
| F3             | Bilder pro Sekunde anzeigen/ausblenden         |
| Esc            | Schließt, was offen ist – sonst Pausenmenü     |

### Im Gestaltungsmodus
Unten erscheint das **Inventar**: nur Dinge, die mir gehören, mit Anzahl (×2). Stehen alle
Exemplare im Raum, ist die Karte ausgegraut (×0). Platzieren nimmt eins aus dem Inventar;
Aufheben und Wegräumen (X) legen es zurück – samt allem, was darauf steht.

Zwei Zustände:
- **Katalog-Zustand:** Mauszeiger sichtbar. Im Inventar stöbern und auswählen, platzierte Möbel
  anklicken (= aufheben, die Anzahl steigt um eins). Laufen mit WASD geht weiter, Umsehen mit gehaltener rechter Maustaste.
  Nach dem Umsehen erscheint der Mauszeiger genau dort wieder, wo man die Taste gedrückt hat.
- **Platzier-Zustand:** Sobald etwas ausgewählt oder aufgehoben ist, verschwindet der Mauszeiger
  und die Vorschau folgt dem Blick. Nach dem Platzieren oder Zurücklegen geht es automatisch
  zurück in den Katalog-Zustand.

| Taste                    | Aktion                                                         |
|--------------------------|----------------------------------------------------------------|
| Tab / Esc                | Gestaltungsmodus schließen (Gehaltenes geht zurück)            |
| Linksklick               | Auswählen / aufheben / platzieren / Abschnitt streichen         |
| Linksklick halten + ziehen | Mehrere Wand-, Boden- oder Deckenabschnitte nacheinander     |
| Umschalt + Linksklick    | Wand: ganze Wand · Boden/Decke: Füllwerkzeug (wie Farbeimer)   |
| Rechte Maustaste halten  | Umsehen (im Katalog-Zustand)                                   |
| Rechtsklick              | Auswahl beenden bzw. Aufgehobenes zurück an den alten Platz    |
| Mausrad                  | Drehen                                                         |
| G                        | Einrasten an/aus (Raster 1/9 m ≈ 11,1 cm und 15°-Schritte)      |
| X                        | Gehaltenes oder anvisiertes Objekt ins Inventar legen          |

### Gestaltungsregeln
- Standard: frei platzieren und stufenlos drehen. Mit G rastet alles am Raster ein.
- Ein ausgewähltes Objekt zeigt mit der Vorderseite zum Spieler; eine Drehung mit dem Mausrad
  bleibt relativ zur Blickrichtung erhalten, bis es platziert ist.
- Jedes Objekt legt fest, wo es hindarf: Boden, Ablagefläche, Wand, Tür, Decke.
  Jedes Möbelstück legt fest, welche Ablageflächen es hat (Tische, Regalbretter, Sitzflächen,
  Armlehnen). Auch die Fensterbank ist eine Ablagefläche.
- Was auf einem Möbelstück steht, wandert beim Verschieben mit.
- Wände werden in senkrechten Abschnitten gestrichen (Standard 1 m breit). Boden und Decke werden
  in Abschnitten von 3 x 3 Rasterfeldern (1/3 m) gestaltet; der Raum (6 x 8 m) geht darin ohne
  Rest auf (18 x 24 Abschnitte).
- Füllwerkzeug (Umschalt + Klick bei Boden und Decke): füllt alle zusammenhängenden Abschnitte
  mit demselben Belag wie der angeklickte – wie der Farbeimer in Paint. Grenzen sind Wände und
  Abschnitte mit anderem Belag; nur direkte Nachbarn zählen, nicht diagonale. Ohne Grenze wird
  der ganze Raum gefüllt.
- Hervorhebung: Worauf man im Gestaltungsmodus zeigt und was man mit E benutzen kann, wird
  dezent aufgehellt (feiner heller Rand) – das Objekt bleibt gut erkennbar.

### Stil
- Stil-Merkmale sind bei allen Objekten freiwillig: Möbel, Deko, Wandfarben, Böden, Decken und
  später Fenster und Türen. Ohne Stil-Merkmal ist ein Objekt stilneutral und zählt nicht mit.
- Bei Möbeln und Deko sind Stil-Merkmale die Regel. Stilneutral sind schlichte, praktische Dinge
  (Lichtschalter, Kasse/Theke, später z. B. das Tablet).
- Die bisherigen Wandfarben, Böden und Decken sind stilneutral. Besondere Designs (z. B. eine
  Dark-Academia-Holzvertäfelung) bekommen später Stil-Merkmale; jede verwendete Oberfläche mit
  Stil zählt dann wie ein Möbelstück.
- Die Stil-Anteile stehen oben im Bild, solange der Gestaltungsmodus offen ist.

### Licht
- Alle Lichtquellen lassen sich mit E schalten (gemeinsames System `LightSource`).
- Elektrische Lampen (Steh-, Kugel- und Deckenlampen) blenden sanft auf und ab.
  Kerzen und Laternen werden einzeln angezündet und gelöscht; die Flamme erlischt sanft.
- Ein Lichtschalter an der Wand schaltet alle elektrischen Lampen im Raum: Ist mindestens eine an,
  gehen alle aus, sonst alle an. Auf Wunsch auch Kerzen und Laternen (Option in GameConfig).
- Deckenlampen hängen an der Decke und lassen sich aus etwas größerer Entfernung schalten.

### Sitzen
- E auf ein Sitzmöbel: Man setzt sich, die Kamera gleitet sanft auf Sitzhöhe. Umsehen geht weiter,
  aufstehen mit E oder einer Bewegungstaste.
- Jedes Sitzmöbel hat eigene Sitzplätze (das Sofa drei). Sie merken sich, ob sie besetzt sind –
  später setzen sich dort auch Besucher hin.

## Das Haus
- Altes englisches Reihenhaus in einer schmalen Gasse.
- Erster Raum (Erdgeschoss, Straßenseite): 6 x 8 Meter, 3,2 Meter hoch (Raumhöhe in GameConfig),
  großes Fenster (0,8 bis 2,6 m) und Eingangstür (2,2 m) zur Gasse. Die Decke ist zu Beginn
  schlicht; Balken gibt es als Deckenvariante.
- Die Eingangstür öffnet sich mit E sanft nach innen; was an ihr hängt (z. B. ein Türkranz),
  schwingt mit. Beim Gestalten ist sie geschlossen.
- Vor der Tür liegt ein Stück Gehweg der Gasse (Platzhalter) mit Bordstein; links und rechts
  stehen die Nachbarhäuser. Hier kommen die Lieferkartons an.

## Einstellungen
- Im Pausenmenü unter „Einstellungen“: Fenster oder Vollbild, Auflösung (gängige Auflösungen
  inklusive Ultrawide), VSync (Standard: an), Bildrate begrenzen (30, 60, 120 oder unbegrenzt;
  Standard: 60). Gespeichert in einer eigenen Datei, getrennt vom Spielstand.
- Grafikqualität Niedrig, Mittel (Standard) oder Hoch. Die Werte jeder Stufe stehen in
  `GameConfig.graphics_presets` (Schatten, Umgebungslicht, Nebel, Kantenglättung, Staub …).
- Sparsame Schatten für ruhige Leistung: Nur wichtige Lampen werfen Schatten (Sonne, Stehlampe;
  auf „Hoch“ auch Deckenlampen). Kleine Lichter wie Kerzen und Laternen haben keine eigenen Schatten.
- Fensterlicht: Die Sonne verteilt ihre Schatten auf Stufen (Kaskaden) – nah fein, fern gröber.
  Die Übergänge werden weich überblendet, damit keine Linie im Fensterlicht entsteht.
  Niedrig nutzt 2 Stufen, Mittel und Hoch 4. Schattenweite der Sonne: 20 m (GameConfig).
- Im Pausenmenü läuft das Spiel mit höchstens 30 Bildern pro Sekunde, damit der Rechner ruht.
- Bilder pro Sekunde anzeigen: in den Einstellungen oder mit F3.
- Alle Menüs und Anzeigen passen sich an jede Auflösung und jedes Seitenverhältnis an.
- Später dazu: Lautstärke, Mausempfindlichkeit, Tageslänge.
- Weitere Räume und Obergeschoss werden später freigeschaltet.
