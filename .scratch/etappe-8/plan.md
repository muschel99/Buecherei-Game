# Etappe 8 – Besuchervielfalt, Gespräche, Theke (Plan aus der Befragung am 14.11.2026)
Status: ready-for-agent

Die Entwicklerin hat alle Punkte bestätigt („Alles ja“) und möchte, dass alles hintereinander gebaut wird – nach jedem
Schritt hochladen und weiter. Zusätzlich: **Das Spiel lädt in Godot sehr lange** (Start) – ansehen und verbessern (Schritt 0).

## Entscheidungen

**Größen (einheitlich, Chibi-Maß)** – Figuren 1,50–1,76 m, davon fast ein Drittel Kopf (Schultern ~1,05 m)
- Theke: Platte 1,0 → **0,85 m** (Würfelregal darunter passt sich an); Theken der anderen Läden später auch auf 0,85 m
- Tische: Esstische, Schreibtische, Bistro-, Teetisch Platte **0,5 m**; Couch-/Beistelltische **0,3 m**; Sideboards,
  Kommoden, Kamin bleiben; Sitzmöbel sind schon auf 0,3 m
- Bücherregale behalten ihre Höhe; Besucher greifen nur bis ~1,4 m (obere Fächer = Spielfigur/Deko)
- Spielfigur: Augenhöhe 1,6 → **1,45 m**, sitzend 0,72 → 0,62, hocken 1,0 → 0,85

**Bücher neu** (alle: Regal, ausgelegt, Hand, Kisten, Besucher) – ~25 % größer und dicker, weiche runde Kanten, leicht
gewölbte Einbände, sanftere Farben, gemalte Rücken; je Fach dafür ~¼ weniger. **Genre-Zeichen** (gemalt, unten auf dem
Rücken, auf dem Cover, auf dem Kistenschild, in der Gedankenblase): Roman Herz, Krimi Lupe, Fantasy Drache, Science-Fiction
Rakete, Klassiker Feder, Lyrik Notenblatt mit Blume, Kinderbuch Teddy, Comics Sprechblase, Kochen und Backen Kuchen, Natur
und Garten Blatt, Reisen Koffer, Kunst Pinsel, Geschichte Sanduhr, Philosophie Eule, Achtsamkeit Teetasse, Sachbuch Glühbirne.

**Theke bedienen (soll „satisfying“ sein)**
- **PC** (gemütlicher alter Rechner mit Kartenleser) **ersetzt die Kasse**
- **Theken-Ansicht**: E am wartenden Gast → Kamera nah an die Theke, alles mit der Maus, jeder Handgriff mit schönem
  Geräusch und kleiner Bewegung: (1) Ausweis in den Kartenleser – Klick, Piep, Name und Stempelkarte erscheinen am PC, der
  neue Stempel ploppt dort auf (kein Stempel-Werkzeug mehr) (2) Bücher einzeln über den Scanner ziehen – Piep, leuchtender
  Strich (3) Bücher dem Gast zuschieben. Endet von selbst, wenn niemand mehr wartet (der nächste rückt nach); Esc verlässt
  sie vorher (der Gast wartet weiter)
- **Stempelkarte** je Ausweis (10 Felder, ein Stempel je Besuch); am PC alle Ausweise mit Stempeln; volle Karte → der Gast
  bekommt ein **Lesezeichen** (Geschenk von dir) und darf seine Bücher **länger behalten**

**Besucher**
- Lieblingsgenre (geht zuerst dorthin) + Art des Besuchs: zielstrebig / stöbert lange / bleibt und liest / bringt nur zurück
- Lesen auch **am Tisch** (Stuhl am Tisch, Buch aufgeschlagen auf der Platte)
- **Stammgäste**: ~10, Namen denkt sich Claude aus (Entwicklerin ändert später), feste Kleidung aus der jetzigen
  Garderobe (die Entwicklerin entwirft später eigene Kleidungsstücke, die dann gebaut werden); Freundschaft wächst (Gespräche,
  erfüllte Wünsche) → kommen öfter, bringen Freunde mit, erzählen mehr (später Spiegel-Hinweise); sichtbar am PC
- Bewegungen: Türen gehen einfach auf (keine Tür-Animation), Bücken zum untersten Fach, Heben wo passend
- Keine Kinder

**Gespräche**
- Mit allen Passanten und Gästen reden (E „Reden“); Stammgäste/Anwohner haben mehr zu erzählen
- Angesprochene bleiben stehen und schauen dich an; **Kamera hält den Fokus** auf der Figur, man kann nicht wegschauen oder
  weggehen; das Gespräch endet, wenn es fertig ist; **Esc hat im Gespräch keine Funktion**; weiter mit Klick/E
- Text: normale Sätze in einer **schönen Sprechblase unten im Bild** (einzige Ausnahme von „keine Sätze im Spielbild“),
  Buchstabe für Buchstabe wie getippt, dazu **sanftes Tastaturklackern** (kein Pling; Geräusch per Script, austauschbar)
- Ab und zu 2–3 freundliche Antworten (keine falsche Wahl)
- Themen: Wetter, Tageszeit, Bücher, Neuigkeiten aus der Straße (später Spiegel-Hinweise); Sätze in einer Textdatei wie die Tipps

**Wünsche** (nur Gäste in der Bücherei)
- Gast mit Wunsch: **Gedankenblase mit Fragezeichen** über dem Kopf; ansprechen → er sagt den Wunsch (immer ein **Genre**);
  man kann ihn immer wieder fragen; **annehmen** oder **ablehnen** (Ablehnen: er stöbert einfach weiter)
- Angenommen: Gedankenblase zeigt das Genre-Zeichen; Buch obenauf in der Hand + **Linksklick auf den Gast** → er steckt es in
  den Korb und stöbert weiter, bringt es mit zur Theke; falsches Genre: freundliches Kopfschütteln
- Ein Wunsch gilt nur für diesen Besuch
- Erfüllt → **Trinkgeld** für dich (ploppt am Kontostand auf, GameConfig) + ein Freundschaftsherz bei Stammgästen

## Schritte (je Schritt hochladen, dann weiter)
- [x] 0. Ladezeit: gemessen (ohne Grafik 3 s; die Zeit geht in die erste Bildvorbereitung der Grafikkarte, ~220 Pipelines);
  gemütlicher Ladebildschirm statt eingefrorenem Fenster, Buchrücken-Atlas wird zwischengespeichert, Zeitmessung „Start: …“
  in der Ausgabe (die Entwicklerin kann ihre Zahlen nennen)
- [x] 1. Größen: Theke 0,85 m (Modelle gestaucht `z_scale`, counter.tscn, `Counter.TOP_HEIGHT`, GenreCrates `HEIGHT_SCALE`),
  Tische (`Kit.lower_table`, `TABLE_HEIGHTS`: Ess-/Schreib-/Teetisch 0,5 m, Beistelltische 0,3 m), Spielfigur Augen 1,45 m,
  Körper 1,6 m, Hocke 0,85/1,0 m, sitzend 0,62 m über dem Sitz; alte Spielstände: Dinge auf Theke/Tischen rutschen nach
  (`Room.SETTLE_RANGE` 0,4). Besucher greifen nur bis ~1,4 m: kommt in Schritt 5
- [x] 2. Bücher neu: weiche Buchform (`BookLook`), dicker (~35 %) und etwas höher/tiefer (~8–10 % – die Fächer sind nur
  23–40 cm hoch), sanftere Farben, Genre-Zeichen (`GenreSymbols`) auf Rücken, Cover und Kistenschild; Kisten zeigen echte Titel
  des Lagers; Besucher tragen die neue Buchform
- [x] 3. Theke: PC statt Kasse (`CounterPc`, Bildschirm mit Stempelkarte), Theken-Ansicht (`CounterDesk`: Ausweis in den
  Kartenleser, Bücher über den Scanner, zuschieben), Stempelkarten (`Lending.readers`), volle Karte = Lesezeichen + 3 Tage mehr;
  neue Geräusche (Kartenleser, Piep, Plopp, Rutschen, Tastaturklackern für Schritt 4)
- [x] 4. Gespräche: E „Reden“ an jeder Figur (`Passerby` + `Conversation`), sie bleibt stehen und schaut dich an, Kamera
  hält den Blick, Sprechblase unten mit getippter Schrift und Tastaturklackern, ab und zu Antworten, Esc ohne Funktion, Sätze in
  `data/talk/talk.txt`
- [x] 5. Besucher: 10 Stammgäste (`data/visitors/regulars.txt`, feste Namen/Aussehen/Ausweise), Lieblingsgenre, vier Arten
  des Besuchs, Lesen am Tisch (Buch auf der Platte), Bücken zum untersten Fach, Griff nur bis 1,4 m, Freundschaft (Gespräche;
  Herzen am PC, vertraute Sätze, Freunde mitbringen)
- [x] 6. Wünsche: Gedankenblase mit „?“ über dem Kopf, im Gespräch annehmen/ablehnen, danach das Genre-Zeichen in der Blase,
  Buch per Linksklick übergeben (in den Korb, Trinkgeld, Freundschaft, Dankeschön)
- [ ] 7. Theken der anderen Läden auf 0,85 m
