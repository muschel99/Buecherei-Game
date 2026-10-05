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
  Der Eingangsbereich vor der Tür bleibt frei.
- **Stile:** Zum Start drei Stile: *Botanisch*, *Modern*, *Dark Academia*. Möbel tragen
  Stil-Merkmale. Der vorherrschende Stil bestimmt, welche Besucher kommen und welche Musik läuft.

## Bücherei-Wirtschaft
- Leihgebühren über Leseausweise (Buch abstempeln statt Wechselgeld).
- Mitgliedschaften.
- Café als zusätzliche Einnahmequelle.
- Bücher können kaputtgehen (Reparatur).
- Genres werden nach und nach freigeschaltet.

## Theke
- Modular: Kasse von Anfang an.
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
Esc schließt immer zuerst das, was gerade offen ist (Gestaltungsmodus, Menüs, später der Shop).
Nur wenn nichts offen ist, öffnet Esc das Pausenmenü.

| Taste          | Aktion                                         |
|----------------|------------------------------------------------|
| W A S D        | Laufen                                         |
| Umschalt       | Schneller laufen (gedrückt halten)             |
| Maus           | Umsehen                                        |
| E              | Interagieren (Objekt in der Bildmitte)         |
| Tab            | Gestaltungsmodus öffnen/schließen              |
| Esc            | Schließt, was offen ist – sonst Pausenmenü     |

### Im Gestaltungsmodus
Zwei Zustände:
- **Katalog-Zustand:** Mauszeiger sichtbar. Im Katalog stöbern und auswählen, platzierte Möbel
  anklicken (= aufheben). Laufen mit WASD geht weiter, Umsehen mit gehaltener rechter Maustaste.
- **Platzier-Zustand:** Sobald etwas ausgewählt oder aufgehoben ist, verschwindet der Mauszeiger
  und die Vorschau folgt dem Blick. Nach dem Platzieren oder Zurücklegen geht es automatisch
  zurück in den Katalog-Zustand.

| Taste                    | Aktion                                                         |
|--------------------------|----------------------------------------------------------------|
| Tab / Esc                | Gestaltungsmodus schließen (Gehaltenes geht zurück)            |
| Linksklick               | Auswählen / aufheben / platzieren / Abschnitt streichen         |
| Linksklick halten + ziehen | Mehrere Wandabschnitte bzw. Bodenfelder nacheinander          |
| Umschalt + Linksklick    | Ganze Wand streichen / ganzen Boden legen                      |
| Rechte Maustaste halten  | Umsehen (im Katalog-Zustand)                                   |
| Rechtsklick              | Zurücklegen / Auswahl beenden (im Platzier-Zustand)            |
| Mausrad                  | Drehen                                                         |
| G                        | Einrasten an/aus (Raster 12,5 cm und 15°-Schritte)              |
| Entf                     | Möbelstück entfernen                                           |

### Gestaltungsregeln
- Standard: frei platzieren und stufenlos drehen. Mit G rastet alles am Raster ein.
- Ein ausgewähltes Objekt zeigt mit der Vorderseite zum Spieler; eine Drehung mit dem Mausrad
  bleibt relativ zur Blickrichtung erhalten, bis es platziert ist.
- Jedes Objekt legt fest, wo es hindarf: Boden, Ablagefläche, Wand, Tür.
  Jedes Möbelstück legt fest, welche Ablageflächen es hat (Tische, Regalbretter, Sitzflächen,
  Armlehnen). Auch die Fensterbank ist eine Ablagefläche.
- Was auf einem Möbelstück steht, wandert beim Verschieben mit.
- Wände werden in senkrechten Abschnitten gestrichen (Standard 1 m breit), Böden in Feldern.
- Wandfarben und Böden sind stilneutral. Nur Möbel und Deko bestimmen den Stil. Die Stil-Anteile
  stehen oben im Bild, solange der Gestaltungsmodus offen ist.
- Ein Lichtschalter an der Wand schaltet alle Lampen im Raum: Ist mindestens eine an, gehen alle
  aus, sonst alle an.

## Das Haus
- Altes englisches Reihenhaus in einer schmalen Gasse.
- Erster Raum (Erdgeschoss, Straßenseite): ca. 6 x 8 Meter, großes Fenster und Eingangstür zur Gasse.
- Weitere Räume und Obergeschoss werden später freigeschaltet.
