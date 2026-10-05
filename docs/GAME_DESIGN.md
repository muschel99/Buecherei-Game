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
| E              | Interagieren (Objekt in der Bildmitte): Lampen und Kerzen schalten, hinsetzen … |
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
| Linksklick halten + ziehen | Mehrere Wand-, Boden- oder Deckenabschnitte nacheinander     |
| Umschalt + Linksklick    | Ganze Wand / ganzer Boden / ganze Decke                        |
| Rechte Maustaste halten  | Umsehen (im Katalog-Zustand)                                   |
| Rechtsklick              | Zurücklegen / Auswahl beenden (im Platzier-Zustand)            |
| Mausrad                  | Drehen                                                         |
| G                        | Einrasten an/aus (Raster 1/9 m ≈ 11,1 cm und 15°-Schritte)      |
| Entf                     | Möbelstück entfernen                                           |

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
- Erster Raum (Erdgeschoss, Straßenseite): ca. 6 x 8 Meter, großes Fenster und Eingangstür zur Gasse.
- Weitere Räume und Obergeschoss werden später freigeschaltet.
