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
  Der Eingangsbereich vor der Tür bleibt frei – für Möbel und (seit Etappe 3k) auch für
  ausgelegte Bücher. Gestaltet wird mit dem, was man besitzt
  (Inventar); Neues kauft man am Theken-Tablet (Laden „Nest & Nook“).
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
- **Theken-Tablet mit Apps** (seit Etappe 3g, neu aufgeteilt in 3h): Auf der Theke steht ein
  Tablet. E öffnet es (Mauszeiger sichtbar, die Figur steht solange still) – als echte
  Tablet-Ansicht in derselben Gestaltung wie das Regal-Menü (gemeinsame Vorlage `TabletFrame`).
  Das Tablet ist zum Schauen und Einkaufen da; Bücher nimmt man über das R-Menü (siehe
  „Regal-Menü“).
  - **Startbildschirm:** große, freundliche App-Symbole mit Namen auf einem ruhigen,
    gemütlichen Hintergrund: Nest & Nook, Bücherladen, Lager, Statistik, Tipps & Tricks.
    Oben eine schmale Leiste mit dezent dem Kontostand. In einer App zeigt die Leiste ihr
    kleines Logo und ihren Namen – bei Läden den Ladennamen mit kurzem Untertitel, damit es
    sich wie ein richtiger Laden anfühlt.
  - Ein Klick auf ein Symbol öffnet die App; das **Home-Symbol** oben links führt zurück. Das
    **Kreuz** oben rechts und **Esc** schließen immer das ganze Tablet (nicht nur die App).
    Beim nächsten Öffnen startet es wieder auf dem Startbildschirm.
  - In den Apps gilt dieselbe Gestaltung wie im Regal-Menü: Symbol-Knöpfe mit kurzem Tooltip,
    wenig Text, bei jeder Auflösung ganz sichtbar.
  - **Neue Apps** (z. B. später Vorbestellungen, Besucher, Einstellungen) sind leicht: eine
    kleine Szene in `scenes/ui/tablet_apps/` und ein Datenblatt in `data/tablet_apps/` – der
    Startbildschirm zeigt sie von selbst (Reihenfolge, Name, Untertitel, Farbe und Symbol im
    Datenblatt). **Ladennamen ändern:** nur `display_name` im Datenblatt (z. B.
    `data/tablet_apps/books.tres` für den Bücherladen) – das ist die einzige Stelle.
  - **Laden „Nest & Nook“** (Möbel, Deko & Farben; App „furnishing“, Logo: kleines Haus mit
    Herz): oben links zwei Symbole – Kaufen (Tasche) und Verkaufen (Münze).
    - *Kaufen:* alle freigeschalteten Möbel, Deko, Wandfarben, Böden und Decken nach
      Kategorien, mit kleinem Vorschaubild, Preis und Stil-Merkmalen. Über der Liste helfen
      Filter beim Suchen (siehe „Filter“). Ein Klick legt etwas in den Warenkorb (Möbel auch
      mehrfach, Oberflächen einmal; − und + ändern die Anzahl); „Bestellen“ bezahlt. Reicht
      das Geld nicht, steht dort freundlich, wie viel fehlt – ohne Strafe.
    - *Verkaufen:* Möbel aus dem Inventar (nicht die im Raum) bringen die Hälfte des Preises
      zurück (Anteil in GameConfig). Oberflächen behält man.
  - **„Bücherladen“** (Platzhaltername, ein schönerer gemütlicher Name kommt später; App
    „books“, Logo: Einkaufstasche mit Buch): Bücherpakete je Genre kaufen (siehe „Bücher
    kaufen“), mit eigenem Warenkorb.
  - **App „Lager“:** Übersicht über alle Bücher mit der Sammlung, siehe „Bücher“ unten.
  - **App „Statistik“** (seit Etappe 3h): ein ruhiger Überblick zum gelegentlichen
    Reinschauen, bewusst kein Dashboard: ein paar große Zahlen (Bücher insgesamt, im Regal,
    ausgelegt, im Lager, Titel entdeckt) und schlichte Balken „Bücher je Genre“ in einer
    warmen Farbe. Später kommen Werte dazu, die es noch nicht gibt (Besucher, ausgeliehene
    Bücher je Genre, Kaffee und Kuchen …): Jedes System meldet sie selbst (Gruppe
    `stat_sources`, `get_stats()`); was es noch nicht gibt, erscheint einfach nicht.
  - **App „Tipps & Tricks“** (seit Etappe 3h): ein kleines, gemütliches Büchlein auf
    cremefarbenem Papier. Zuerst das Inhaltsverzeichnis (Themen mit kleinem Symbol, Pünktchen
    und Seitenzahl: Steuerung, Bücher einräumen, Regale und Fächer, Dekorieren, Einrichten und
    Stile, Einkaufen und Lieferung). Ein Klick schlägt das Thema auf; mit den Pfeilen neben
    dem Büchlein blättert man vor und zurück (über alle Themen hinweg, sanft überblendet), das
    Symbol oben links führt zurück ins Inhaltsverzeichnis. Wenig Text pro Seite, Tasten als
    kleine Kappen, unten ein zartes Symbol des Themas und die Seitenzahl. Alle Texte stehen in
    `data/tips/tips.txt` (Aufbau oben in der Datei: `= Thema | Symbol`, `== Überschrift`,
    Text, `<E>` für Tasten) – dort ergänzen, umschreiben oder umsortieren, ohne Code.
  - Das Tablet gehört fest zur Bücherei: Es ist nicht zu kaufen und lässt sich nicht verkaufen.
- **Lieferung:** Kurz nach der Bestellung (10 Sekunden, GameConfig) stehen die Kartons draußen
  neben der Eingangstür – **ein Karton pro Objekt** (drei Stühle und eine Lampe = vier Kartons) –,
  und ein dezenter Hinweis erscheint: „Lieferung ist da“.
  - Die Kartons stapeln sich ordentlich: erst nebeneinander an der Hauswand (4 Stapel), dann
    bis zu 3 übereinander, dann eine Reihe davor. Jeder steht leicht schief, keiner steckt im
    anderen. Auch mehrere Bestellungen stapeln sich so weiter; neue Kartons füllen Lücken.
  - E auf einen Karton – von jeder Seite und auch von oben: Der Inhalt wandert direkt ins
    Inventar, der Karton hebt sich, dreht sich und schrumpft sanft weg. Wird ein unterer Karton
    eingesammelt, rutschen die oberen nach. Es reagiert immer der Karton, den man ansieht.
  - **Lager-Anzeige** statt Text: Unten rechts erscheint dezent ein kleines Lager-Symbol
    (Häuschen). Darüber ploppt das Bild des Objekts mit einem kleinen „+“ auf, rutscht ein
    kurzes Stück hinein, und das Lager-Symbol federt kurz auf wie eine Blase. Danach blendet es
    nach ein paar Sekunden sanft aus. Mehrere Dinge erscheinen nacheinander (Abstand 0,7 s,
    GameConfig) – das Einsammeln selbst geht sofort, man muss nie warten. Die Bilder entstehen
    automatisch aus den 3D-Modellen (auch für eigene Modelle). Das System ist wiederverwendbar,
    z. B. später für Bücher.
  - Der Lieferort ist ein verschiebbarer Punkt (`Outside/Deliveries` in der Hauptszene);
    Richtung der Stapel im Inspektor, Stapelhöhe und -anzahl in GameConfig.
  - Nichts tragen, nichts einsortieren.
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
- Bei „Nest & Nook“ und im Gestaltungsmodus stehen über der Liste kleine Filter-Schaltflächen:
  „Alle“ und die Unterkategorien, die es dort gerade gibt, daneben der Stil-Filter
  „Alle Stile“, Botanisch, Modern, Dark Academia, Neutral (= ohne Stil-Merkmal).
  Leere Unterkategorien werden nicht gezeigt; sie erscheinen von selbst, sobald es
  passende Objekte gibt (im Gestaltungsmodus: sobald dort etwas im Inventar liegt). Bei schmalen Bildschirmen rutschen die Schaltflächen in eine
  zweite Zeile.
- Beim Wechsel der Kategorie springt die Unterkategorie auf „Alle“, der Stil bleibt.

### Bücher und Regale (seit Etappe 3, echte Bücher seit 3b, freies Einräumen seit 3c)
Grundsatz: Einsortieren soll befriedigend sein, aber nie mühsam. Man **kann** jedes Buch
einzeln an seinen Platz stellen, **muss** es aber nie: Auffüllen, Einräumen und Sortieren
gehen jederzeit mit einem Klick bzw. einem langen E. Kein Zeitdruck, keine Strafe.
Möglichst wenig Text auf dem Bildschirm: kleine Tastensymbole statt Sätzen, ausführliche
Erklärungen nur in der Tastenhilfe im Pausenmenü.

- **Genres** sind Daten (`data/genres/`, ein Datenblatt je Genre): Name, Farbpalette der
  Einbände, passender Stil (freiwillig, zählt noch nicht zur Stilberechnung), Preis eines
  Bücherpakets, freigeschaltet ja/nein, Schriftart und passende Cover-Gestaltungen.
  Umbenennen, hinzufügen und freischalten geht ohne Code.
  - Zum Start frei: Roman, Krimi, Fantasy, Sachbuch, Kinderbuch.
  - Angelegt, aber gesperrt (Freischaltung in Etappe 8): Klassiker, Lyrik, Natur und Garten,
    Philosophie, Science-Fiction, Kochen und Backen, Reisen, Kunst, Geschichte, Achtsamkeit,
    Comics und Graphic Novels.
- **Echte Bücher:** Jedes Genre hat 50 feste Titel (zusammen 800), deutsch und englisch, alle
  erfunden und gemütlich – nichts Düsteres, auch die Krimis sind gemütliche Rätsel
  („Das Rätsel der verschwundenen Teekanne“, „The Case of the Curious Cat“). Sie stehen in
  `data/books/<genre>.txt` (eine Zeile pro Buch: Titel | Motiv) und lassen sich leicht ergänzen.
- Jeder Titel hat eine erfundene Autorin bzw. einen erfundenen Autor, eine feste Größe
  (zufällig, aber immer gleich), Farben, eine **Gestaltung** und ein **Motiv**, das zum
  Titel passt (Leuchtturm, Teekanne, Fuchs, Drache … 71 Motive):
  - classic: Einband mit feinem Doppelrahmen und Goldschrift (Klassiker, Geschichte, Fantasy)
  - picture: großes Bild vor zweifarbigem Hintergrund (Kinderbuch, Reisen, Natur)
  - minimal: helles Papier, farbiger Streifen, große Schrift (Sachbuch, Philosophie, Lyrik)
  - pattern: Muster (Punkte, Streifen, Karos, Wellen) mit hellem Titelschild (Kochen, Kunst)
  - band: Bild oben, helles Titelfeld unten (Krimi, Roman)
  - comic: kräftige Farben, Rasterpunkte und Strahlenkranz (Comics)
  Schriften kommen vom eigenen PC (mit Serifen, ohne Serifen oder verspielt, je Genre).
- **Cover und Buchrücken:** Der Rücken (mit Titel, Bändern und kleinem Motiv) ist im Regal zu
  sehen. Das Cover sieht man, wenn man ein Buch im Regal kurz länger anschaut (etwa 0,5 s,
  `GameConfig.book_info_delay`: kleine, dezente Karte neben der Bildmitte mit Cover, Titel,
  Autor und Genre – nicht bei jedem flüchtigen Blick) und wenn man es in der Hand hält
  (das Buch obenauf mit Cover; nach dem Nehmen oder Wechseln zeigt die Karte es kurz).
- Von einem Titel kann es mehrere Exemplare geben; alle sehen gleich aus. Jedes Exemplar hat
  einen Zustand (vorerst immer „gut“; beschädigte Bücher kommen in Etappe 5).
- **Sammlung:** Bücherpakete bringen zuerst Titel, die ich noch nicht kenne – man weiß nie
  genau, was als Nächstes kommt. Beim Auspacken freut sich ein kurzer Hinweis mit
  („7 neue Titel · Krimi“). Erst wenn alle 50 Titel eines Genres entdeckt
  sind, kommen doppelte (die mit den wenigsten Exemplaren zuerst). Grundlage für das spätere
  Freischalten einzelner Bücher (Etappe 8).
- **Bücherbestand** (getrennt vom Möbel-Inventar): Jedes Buch ist im Lager, in einem Regal,
  im Rückgabekasten oder in meinen Händen. Zum Start liegen 12 verschiedene Titel je freiem
  Genre im Lager (GameConfig).
- **Bücher kaufen:** Am Theken-Tablet gibt es den „Bücherladen“ mit einem Bücherpaket je
  freigeschaltetem Genre (10 Bücher, Anzahl in GameConfig, Preis im Genre-Datenblatt: 35–55 Taler)
  und dem Sammelstand („Sammlung: 12 von 50 Titeln“). Jedes Paket kommt als eigener Karton vor
  die Tür; E packt die Bücher ins Lager (Lager-Anzeige mit Bücherstapel in Genre-Farben).
- **App „Lager“** (seit Etappe 3h, vorher „Bestand“ und „Sammlung“): je Genre auf einen Blick,
  wie viele Bücher ich habe und wo sie sind – mit kleinen Symbolen und Zahlen statt Text:
  Kiste = im Lager, Regal = im Regal, liegendes Buch = ausgelegt, Pfeile = unterwegs (in der
  Hand oder im Rückgabekasten). Unter dem Genre klein, wie viele Titel ich schon entdeckt habe.
  Oben die Summe aller Bücher.
  - **Sammlung:** Der Pfeil rechts klappt ein Genre auf und zeigt seine Sammlung: alle 50
    Titel als Cover-Kacheln, unentdeckte als „?“, darunter klein, wo meine Exemplare gerade
    sind („2 im Lager · 1 im Regal“).
  - Nur zum Schauen: Bücher in die Hand nehmen geht hier nicht (dafür gibt es das R-Menü,
    überall). Getragene Bücher zurück ins Lager: Q halten.
- **Regale:** Bücherregale haben Bretter für Bücher und Deko (das obere Brett bleibt Ablage
  für Deko). Jedes Buch steht **frei** auf seinem Brett – links, rechts, in der Mitte, mit
  Lücken. Ein feines Raster (1 cm, `GameConfig.shelf_grid_step`) hält alles ordentlich.
  Die Maus ist für Bücher da, E für das Menü (seit Etappe 3d):
  - **Buch anschauen:** Es rutscht ein Stück heraus und leuchtet sanft; nach kurzem Hinsehen
    erscheint die kleine Karte. Unter dem Fadenkreuz: Maus rechts „Nehmen“, R „Menü“.
  - **Rechtsklick auf ein Buch:** genau dieses Buch nehmen (auch aus der Mitte) – es kommt
    obenauf auf den Stapel in der Hand. Die anderen bleiben stehen, wo sie sind.
  - **Mit Büchern in der Hand:** Wohin ich schaue, steht eine halbdurchsichtige Vorschau des
    Buchs obenauf. **Linksklick** stellt es genau dort ab. Nah an einem anderen Buch, an Deko
    oder an der Seitenwand rastet es bündig ein (`GameConfig.shelf_snap_distance`). Schaue
    ich zwischen zwei Bücher, schwebt die Vorschau davor; beim Abstellen rücken die Nachbarn
    nur so weit zur Seite wie nötig. Passt es nicht (kein Platz, anderes Genre des Fachs),
    ist die Vorschau dezent rötlich und schüttelt sich beim Klick kurz – ganz ohne Text.
  - **Linksklick halten** (ein Ring füllt sich, `GameConfig.place_all_hold_time`): alle
    getragenen Bücher, die in die Fächer passen, auf einmal einräumen – **dort, wo ich
    hinschaue** (seit Etappe 3f): Sie beginnen in dem Fach und an der Stelle, auf die ich
    schaue, und füllen von dort die freien Plätze dieses Fachs (erst nach rechts, dann nach
    links). Was dort nicht hinpasst (Platz oder Genre), kommt in die nächstgelegenen anderen
    Fächer mit passendem Genre. Was nirgends passt, bleibt in der Hand. Ein kurzer Klick zählt erst beim Loslassen; solange
    der Ring läuft, wird nichts abgestellt.
  - **R** (kurzer Druck, ohne Halten und ohne Ring): Regal-Menü (seit Etappe 3e; seit 3h
    überall, siehe unten). R ist bewusst eine eigene, ruhige Taste – so öffnet sich nie aus
    Versehen ein Menü. E öffnet am Regal nichts, sondern blättert durch die Bücher in der Hand.
  - **Fächer** (seit Etappe 3f statt „Etagen“ – ein Würfelregal hat mehrere Fächer pro Reihe):
    Sie sind von oben links nach unten rechts durchnummeriert (Fach 1, Fach 2 …). Jedes Fach
    hat sein eigenes Genre oder „Gemischt“, z. B. oben „Gemischt“, darunter „Krimi“ und
    „Kinderbuch“. Fächer ohne Genre nehmen jedes Buch.
  - **Automodus** (seit Etappe 3i, Standard für alle Fächer, auch für leere und neue): Steht
    ein Fach auf „Auto“, nimmt es jedes Buch an und übernimmt sein Genre aus den Büchern darin –
    alle vom selben Genre → dieses Genre, verschiedene → „Gemischt“, leer → kein Genre. So
    stelle ich einfach Bücher hinein, ohne vorher etwas festzulegen. Wähle ich ein Genre von
    Hand, ist das Fach darauf festgelegt (nimmt nur Bücher dieses Genres an, auch wenn es leer
    ist). Auto ist kein Genre, sondern ein eigener Schalter (siehe Regal-Menü).
- **R-Menü überall** (seit Etappe 3h): R öffnet das Menü immer, egal wohin ich schaue – so kann
  ich Bücher aus dem Lager holen, ohne vor einem Regal zu stehen (z. B. zum Dekorieren). Es
  ist dasselbe Menü; es erkennt nur, worauf ich schaue:
  - Schaue ich ein Regal an – oder Deko bzw. ein Buch, das darin steht –, gehört es zu diesem
    Regal (alles unten Beschriebene).
  - Schaue ich kein Regal an, steht oben „Bücher“ und „Kein Regal im Blick“; die Regal-Teile
    (Genre je Fach, „Alle Fächer gleich“, Auffüllen, Sortieren, Alle ins Lager) sind dezent
    ausgegraut und nicht anklickbar (Tooltip „Nur am Regal“). Die Ansicht dreht sich nicht.
  - Die **Bücherauswahl** ist immer da: ohne Regal mit allen Genres im Lager, am Regal mit den
    Genres, die in seine Fächer passen. Sie beginnt mit **„Alle Bücher“** (alle Genres
    zusammen, nach Genre und Titel geordnet); in der Liste darunter wählt man ein einzelnes
    Genre (seit Etappe 3k).
  - Jede Cover-Kachel ist **dezent in der Farbe ihres Genres** hinterlegt (Farbe aus dem
    Genre-Datenblatt, Stärke `GameConfig.book_picker_tint`) – so sieht man in „Alle Bücher“
    auf einen Blick, was wozu gehört.
  - **Genommene Bücher bleiben sichtbar** (seit Etappe 3k): Ein Buch, das ich gerade in die
    Hand genommen habe, verschwindet nicht aus der Übersicht, sondern wird leicht ausgegraut
    und bekommt ein kleines Handsymbol. Ein Klick auf diese Kachel legt es zurück ins Lager,
    die Markierung verschwindet. Das gilt für die Bücher, die ich im offenen Menü genommen
    habe.
  - **Mehrere Bücher nacheinander:** Nach einem Klick auf ein Cover bleibt das Menü offen; es
    schließt sich erst, wenn die Hände mit sieben Büchern voll sind (oder mit Esc, R oder dem
    Kreuz). Oben rechts zeigt ein kleiner Stapel, wie viele Bücher ich trage („3 / 7“).
  - Bücher aus dem Lager nimmt man nur hier (nicht am Theken-Tablet).
  - R geht auch im Sitzen; solange das Menü offen ist, stehe ich nicht aus Versehen auf. Im
    Gestaltungsmodus, am offenen Theken-Tablet und in der Pause öffnet R nichts.
- **Regal-Menü als Tablet** (R am Regal, seit Etappe 3f): Es erscheint als Tablet, groß und gut
  lesbar am rechten Bildrand – in derselben Gestaltung wie das Tablet an der Theke (gemeinsame
  Vorlage `TabletFrame`). Es ist immer gleich groß und bei jeder Auflösung ganz zu sehen; eine
  lange Fächerliste lässt sich scrollen. Bewusst schlicht: wenige klare Aktionen.
  - Oben eine Leiste mit **Symbol-Knöpfen** statt langer Textzeilen; fährt die Maus darüber,
    erscheint kurz ein Tooltip mit einem Wort:
    - **Buch aus dem Lager:** Cover-Kacheln der passenden Bücher im Lager direkt auf dem
      Tablet (Pfeil zurück); ein Klick legt das Buch obenauf in die Hand, dann stellt man es
      mit Linksklick an die gewünschte Stelle.
    - **Auffüllen:** Jedes Fach bekommt passende Bücher aus dem Lager, von oben nach unten;
      sie gleiten nacheinander in die freien Plätze (höchstens 2,5 Sekunden), je Genre nach
      Titel sortiert. Gemischte Fächer werden gleichmäßig aus allen Genres befüllt, Fächer
      ohne Genre bleiben leer. Bei „Auto“ zählt das erkannte Genre: Ein Auto-Fach mit Krimis
      bekommt Krimis, ein gemischtes Auto-Fach nur Bücher der Genres, die schon darin stehen;
      leere Auto-Fächer bleiben leer.
    - **Sortieren** (Filtersymbol): Ein Klick öffnet eine kleine Auswahl – nach Genre und
      Titel, nach Titel, nach Autor oder nach Farbe. Die Bücher rücken sanft an ihre neuen
      Plätze (dicht an dicht von links, jedes in ein passendes Fach); Deko bleibt stehen. Das
      Regal merkt sich die gewählte Art (wird gespeichert).
    - **Alle ins Lager:** alle Bücher des Regals zurück ins Lager.
  - Darunter **„Fächer“**: „Alle Fächer gleich“ und alle Fächer untereinander. Jede Zeile:
    Fachname, die Tickbox **„Auto“** (seit Etappe 3i), dann die Auswahlliste für das Genre
    („Gemischt“, Roman, Krimi, Fantasy …).
    - Ist „Auto“ angehakt, zeigt die Auswahlliste das erkannte Genre (leer: „Noch leer“) und
      folgt den Büchern, die hineinkommen oder herausgehen.
    - Die Auswahlliste bleibt immer anklickbar: Wähle ich von Hand ein Genre, geht „Auto“
      aus und das Fach ist festgelegt. Hake ich „Auto“ wieder an, gilt wieder das Genre aus den
      Büchern. Nehme ich den Haken weg, bleibt das Fach bei dem Genre, das es gerade hat.
    - „Alle Fächer gleich“ hat dieselbe Kombi und setzt alle Fächer auf einmal (sind die
      Fächer verschieden, steht dort „Verschieden“).
    - Bücher, die nach einem Wechsel nicht mehr passen, gleiten heraus und gehen ins Lager.
  - **Fach hervorheben:** Fahre ich über die Auswahlliste oder die Tickbox eines Fachs oder klappe die Liste auf,
    leuchtet genau dieses Fach im Regal dezent weiß (wie Möbel im Gestaltungsmodus); bei „Alle
    Fächer gleich“ alle Fächer.
  - **Das Regal bleibt sichtbar:** Beim Öffnen dreht sich die Ansicht sanft ein Stück nach
    rechts (und zoomt bei Bedarf etwas heraus, höchstens bis `GameConfig.shelf_menu_max_fov`),
    sodass das Regal links neben dem Tablet ganz zu sehen ist; die Kamera bleibt dabei an
    ihrem Platz. Beim Schließen gleitet sie zurück. Steht man sehr nah (unter 1 m) vor einem
    breiten Regal, kann sein äußerster Rand knapp hinter dem Tablet liegen.
  - Getragene Bücher räumt man nicht im Menü ein (dafür: Linksklick halten am Regal) und legt
    sie dort auch nicht ins Lager (dafür: Q halten) – jede Aktion hat nur einen Weg.
  - Schließen mit dem kleinen Kreuz oben rechts (wie im Browser), Esc oder R.
- **Genre ohne Schild:** Schaue ich ein Regal an, erscheint unten in der Bildmitte nur das
  Genre-Wort des Fachs, auf das ich schaue (z. B. „Krimi“), in ruhiger Serifenschrift; es
  blendet sanft ein und aus.
- **Deko im Regal:** Im Gestaltungsmodus lässt sich kleine Deko frei entlang der Regalbretter
  stellen (kleine Pflanzen, Kerzen, Figuren, Bilderrahmen, Vasen, Buchstützen …). Nur, was in
  der Höhe ins Fach passt, und nur an freie Stellen: Bücher und Deko überschneiden sich nie.
  Für Regale gibt es im Shop Buchstützen (Holz, Beton), eine Mini-Sukkulente, einen
  Bilderrahmen zum Hinstellen, einen kleinen Globus, eine Kerze im Glas und eine kleine Vase
  mit Lavendel.
- **Leistung:** Alle Bücher eines Regals werden in einem einzigen Rutsch gezeichnet (MultiMesh);
  die Buchrücken kommen aus einem gemeinsamen Bild, das beim Start einmal gezeichnet wird.
  So bleiben auch hunderte Bücher im Raum leicht für den PC.
- **Gestalten:** Verschiebt man ein Regal, bleiben Bücher und Deko darin (auch in der Vorschau
  sichtbar). Räumt man es mit X weg, gehen seine Bücher ins Lager und die Deko ins Inventar.

### Bücher in der Hand und Rückgabekasten (seit Etappe 3, neue Steuerung seit 3c/3d/3e)
- Ich trage höchstens **7 Bücher** (`GameConfig.max_carried_books`). Das Buch obenauf sieht man
  unten rechts mit seinem Cover, dahinter die anderen als kleiner Stapel mit echten
  Buchrücken. Sind die Hände voll und ich möchte noch eins nehmen, wackelt der Stapel kurz –
  ohne Text.
- **Tragehinweise:** Solange ich Bücher trage, steht klein am unteren Rand neben dem
  Stapel-Symbol (mit der Zahl): Maus links „Ablegen“, am passenden Regal Maus links mit Ring
  „Einräumen“, Mausrad „Drehen“ (nur dort, wo das Drehen wirkt), E „Blättern“ (nur bei mehreren
  Büchern und wenn E gerade nichts anderes tut), Q mit Ring „Lager“ (je nach Einstellung
  „Hinweise“). Ohne Bücher verschwinden sie. Beim Halten füllt sich der Ring um das Symbol.
- **E blättert** (seit Etappe 3e): E tippen legt das nächste Buch obenauf, **Umschalt + E**
  das vorige. Schaue ich etwas an, das selbst auf E reagiert (Lampe, Lichtschalter, Tür,
  Karton, Sitz, Tablet, Rückgabekasten mit Büchern), hat diese Aktion Vorrang. Am Regal, an
  ausgelegten Büchern oder ohne Ziel blättert E.
- Das **Mausrad** dreht das Buch obenauf vor dem freien Ablegen (siehe „Bücher als Deko“).
- **Q halten:** Alle getragenen Bücher kommen ins Lager.
- **Rückgabekasten:** Kasten mit Einwurfschlitz und kleinem Fenster (Kategorie Theke), frei
  platzierbar, z. B. neben der Tür oder an der Theke. Zum Start liegt einer im Inventar,
  weitere gibt es im Shop.
- Später werfen Besucher dort ihre ausgeliehenen Bücher ein. Bis dahin legt die Testtaste **F9**
  ein paar Bücher bereits entdeckter Titel hinein.
- E am Kasten: so viele Bücher nehmen, wie in die Hände passen; Rechtsklick: eines. Dann am
  Regal: einzeln mit Linksklick abstellen oder alle passenden mit Linksklick halten. Was nicht
  passt, trage ich weiter.
- Keine Eile: Bücher dürfen beliebig lange im Kasten liegen oder getragen werden.

### Bücher als Deko: frei ablegen (seit Etappe 3d)
- Bücher aus der Hand lassen sich nicht nur ins Regal stellen, sondern überall ablegen, wo
  auch Deko hindarf: Tische, Theke, Fensterbank, Sitzmöbel (z. B. auf die Armlehne), Boden und
  andere Ablageflächen. **Linksklick** legt das Buch obenauf genau dorthin, wo ich hinschaue;
  vorher zeigt eine halbdurchsichtige Vorschau, wo es hinkommt (rötlich, wenn es dort nicht
  geht).
- **Blaupause** (seit Etappe 3i ruhig, seit 3j für Bücher und Möbel gleich): Die Vorschau ist
  eine „Blaupause“ in ruhigem Blau (rot, wenn es dort nicht geht) – unbeleuchtet, also ohne
  Licht und Schatten der Szene, und nur leicht durchsichtig (`GameConfig.preview_opacity`), damit
  auch an der Grenze einer Lichtinsel kein Hell und Dunkel von dahinter durchscheint. Ein hellerer
  Rand und bei Büchern feine Kanten zeigen die Form. Sie wird ein paar Millimeter zur Kamera hin
  gezeichnet, damit sie nie flackert. In allen drei Grafikstufen gleich.
- **Eine Regel für alles** (seit Etappe 3i): Ein Buch darf nie in ein anderes Objekt
  hineinragen – Möbel, Deko, Wände. Überschneidet sich die Vorschau mit etwas, ist sie rötlich,
  und ein Klick lässt sie nur kurz wackeln. Aufliegen und Anlehnen ist erlaubt. Das gilt flach,
  aufrecht und angelehnt gleich; die Vorschau liegt immer dort, wo ich hinschaue (sie springt
  nicht mehr vor ein Möbelstück). Geprüft wird mit den Kollisionsformen der Möbel – darum
  sollen sie zur sichtbaren Form passen (z. B. Leiterregal: die zwei Seitenholme statt einer
  unsichtbaren Rückwand).
- **Flach:** Standardmäßig liegt das Buch flach mit dem Cover nach oben (man sieht das echte
  Cover), ausgerichtet nach meiner Blickrichtung und minimal schräg. Auf ein liegendes Buch
  gelegt, entsteht ein kleiner, leicht versetzter Stapel (höchstens
  `GameConfig.loose_book_stack_max` Bücher).
- **Aufrecht, ganz ohne neue Taste:**
  - Schaue ich auf eine **Wand** (z. B. hinter dem Tisch oder am Boden), lehnt das Buch dort
    an, das Cover zeigt in den Raum (`GameConfig.loose_book_lean_angle`).
  - **Anlehnen an mehr Stellen** (seit Etappe 3j), genauso wie an der Wand: an die Rücken- und
    Armlehnen von Sofas, die Lehnen von Sesseln und Stühlen und an große Blumentöpfe (im
    Datenblatt `books_can_lean`). Das Buch steht dabei auf dem, was darunter ist (Sitzfläche,
    Boden, Tisch). Ist die Lehne niedriger als das Buch (z. B. eine Armlehne), liegt das Buch an
    ihrer Oberkante an.
  - **An einen Bücherstapel** (seit Etappe 3j): Schaue ich auf die Seite eines liegenden
    Stapels, lehnt das Buch daneben – wie leicht heruntergerutscht, oben an der Kante des
    Stapels. (Schaue ich von oben darauf, kommt es wie bisher obendrauf.)
  - An kleiner Deko (Figuren, kleine Vasen …) und an Lampen lehnt nichts an; dort ist die
    Vorschau rot. Frei hochkant hinstellen geht nie – zum Präsentieren gibt es den Aufsteller.
  - Im Bücherregal stehen Bücher in Reihen (das Regal räumt selbst ein); Anlehnen an seine
    Rückwand gibt es dort (noch) nicht.
  - Schaue ich auf eine **Buchstütze** oder ein **aufrecht stehendes Buch**, stellt sich das
    Buch aufrecht direkt daneben, der Rücken zeigt nach vorn – so entstehen kleine Buchreihen
    auf Tischen und der Theke.
  - **Buchstützen** (seit Etappe 3k): Bücher rasten an der Buchstütze ein, nicht umgekehrt.
    Ziele ich knapp neben eine Buchstütze (höchstens `GameConfig.bookend_snap_distance`, 5 cm),
    steht das Buch aufrecht und bündig an ihr (nur ein Hauch Luft). Im Bücherregal stehen
    Bücher ebenso bündig an der Buchstütze; schaue ich mit einem Buch in der Hand direkt auf
    eine Buchstütze im Regal, stellt das Regal das Buch an die Seite, auf die ich schaue. Die
    Buchstütze selbst rastet im Gestaltungsmodus nie an Büchern ein – sie steht genau dort, wo
    ich hinschaue, und darf bündig neben Bücher.
- **Flach auf Polster** (seit Etappe 3j): Auch auf Sofakissen und eine Sofadecke lassen sich
  Bücher flach legen (im Datenblatt `books_can_lie`), wie auf einen Tisch – Cover oben, leicht
  schräg, Stapel möglich.
- **Buch-Aufsteller** (seit Etappe 3j, bei Nest & Nook, 18 Taler): ein schlichter dreieckiger
  Aufsteller aus hellem Holz (Platzhalter). Als Deko darf er überall hin, wo Deko hindarf:
  Theke, Fensterbank, Tisch, Boden, Bücherregal und andere Regale.
  - **Linksklick** auf den Aufsteller (mit Buch in der Hand): Das Buch obenauf legt sich nach
    hinten geneigt hinein, Cover nach vorn (die Vorschau zeigt es vorher).
  - **Rechtsklick** auf das Buch: wieder in die Hand (obenauf).
  - Ein Aufsteller hält genau ein Buch; ist er belegt, ist die Vorschau rot und ein Klick lässt
    sie nur kurz wackeln. Passt das Buch nicht (z. B. Regalbrett darüber zu niedrig), auch rot.
  - Das Buch zählt zum Bestand als „ausgelegt“. Verschiebe ich den Aufsteller (oder das
    Möbelstück, auf dem er steht), wandert es mit; räume ich ihn mit X weg, geht es ins Lager.
  - Für eigene Modelle: Szene mit dem Knoten `BookStand` und dem Marker `BookSpot` (hintere
    Unterkante des Buchs, +Z nach vorn), Neigung `lean_angle`.
- **Drehen mit dem Mausrad** (seit Etappe 3e): Vor dem Ablegen dreht das Mausrad das Buch
  obenauf um die Hochachse – genauso wie Möbel im Gestaltungsmodus; die Vorschau zeigt die
  Drehung. So liegt ein Buch z. B. quer oder mit dem Buchrücken zu mir, und Stapel lassen sich
  aus unterschiedlich gedrehten Büchern bauen. Die leichte Zufallsschräge kommt dazu.
  - Die Drehung gilt relativ zu meiner Blickrichtung (auf einem Stapel relativ zum Buch
    darunter) und bleibt erhalten, bis ich ein Buch ablege (frei, ins Regal oder ins Lager);
    danach beginnt das nächste wieder gerade. Blättern mit E behält die Drehung.
    Schrittweite: `GameConfig.book_turn_step` (z. B. 5 = fast stufenlos).
  - An die Wand gelehnte Bücher lassen sich ein Stück zur Seite drehen (höchstens
    `GameConfig.loose_book_lean_max_turn`), damit das Cover sichtbar bleibt.
  - Im Regal und in Reihen aufrecht stehender Bücher bleibt der Buchrücken vorn – dort hat das
    Mausrad keine Wirkung.
- **Rechtsklick** auf ein ausgelegtes Buch nimmt es wieder in die Hand; was darauf lag,
  rutscht nach.
- Ausgelegte Bücher gehören zu meinem Bestand („ausgelegt“). Verschiebe ich ein Möbelstück im
  Gestaltungsmodus, wandern die Bücher darauf mit; räume ich es mit X weg, gehen sie zurück
  ins Lager. Mitten auf ausgelegte Bücher lässt sich kein Möbelstück stellen („Hier liegen
  Bücher.“). Steht eine Buchstütze im Bücherregal, räumt dort das Regal selbst ein.
  Ausgelegte Bücher und Buchstützen werden gespeichert wie bisher; ältere Spielstände laden
  unverändert.
- Wiederverwendbar: Das System (`LooseBooks`, ein Knoten je Raum) ist so gebaut, dass später
  auch Besucher Bücher auf Tischen liegen lassen können, die man dann einsammelt. Im
  Datenformat (`LooseBook`) ist der Zustand „aufgeschlagen“ schon vorgesehen (noch nicht
  umgesetzt).
- Leistung: Alle ausgelegten Bücher eines Raums werden in einem einzigen Rutsch gezeichnet; die
  Cover kommen aus einem gemeinsamen Bild (bis zu 112 verschiedene Titel gleichzeitig mit
  Cover, weitere mit schlichtem Einband in ihrer Farbe).

### Speichern der Bücher
- Gespeichert werden Bestand, Sammlung, Regalinhalte (jedes Buch mit seiner Lage auf dem
  Brett), das Genre jedes Fachs, die gewählte Sortierart jedes Regals, Deko in den Regalen, ausgelegte Bücher (Lage samt gewählter
  Drehung, Haltung, Möbelstück darunter), Inhalt des Rückgabekastens, die getragenen Bücher
  und welches obenauf liegt.
- Ältere Spielstände laden weiter: Bücher ohne Lage stehen dicht von links, das bisherige
  Regal-Genre gilt für alle Fächer, ausgelegte Bücher gibt es dort noch keine, sortiert wird
  dort nach Genre und Titel.

### Testtasten (bis es Besucher und Einnahmen gibt)
- **F9:** ein paar Bücher in den Rückgabekasten. **F10:** 500 Taler Testgeld
  (`GameConfig.debug_money_amount`).
- Beide lassen sich zentral abschalten: `GameConfig.debug_keys_enabled = false`.

### Später (Etappe 5)
- Leihgebühren über Leseausweise (Buch abstempeln statt Wechselgeld).
- Mitgliedschaften.
- Café als zusätzliche Einnahmequelle.
- Bücher können kaputtgehen (Reparatur) – der Zustand ist im Buch schon vorgesehen.
- Genres werden nach und nach freigeschaltet (Etappe 8, `BookStock.unlock_genre`).

## Theke
- Modular: Kasse von Anfang an, dazu das Tablet mit seinen Apps (Nest & Nook, Bücherladen,
  Lager, Statistik, Tipps & Tricks).
- Der Rückgabekasten gehört zur Kategorie Theke.
- Café-Elemente (z. B. Kaffeemaschine, Kuchenvitrine) später daneben anbaubar.
- Der gesamte Thekenblock ist frei platzierbar.

## Tagesablauf
- Verkürzter Tag: 20 bis 30 Minuten Echtzeit pro Spieltag.
- Öffnen-Schild an der Tür, Pause und Vorspulen.

## Story
- Kleine, unerklärliche, nicht gruselige Ereignisse.
- Später ein Spiegel, aus dem kleine Wesen heimlich Bücher ausleihen.

## Steuerung
**Grundregel:** Jede Interaktion in der Spielwelt läuft über die Taste E. Man muss dafür nicht
eine bestimmte Stelle treffen: Wer auf irgendeinen Teil eines Objekts schaut (von vorn, der
Seite, hinten oder oben), kann es benutzen. Ausnahme Bücher (seit Etappe 3d): Rechtsklick
nimmt ein Buch, Linksklick legt das Buch obenauf ab (ins Regal oder frei auf Tisch, Boden …),
Linksklick halten am Regal räumt alle passenden ein, das Mausrad dreht das Buch vor dem
Ablegen (nur im Spiel; im Gestaltungsmodus bleibt die Maus wie bisher). Hat das angeschaute
Objekt keine eigene E-Aktion, blättert E durch die Bücher in der Hand. Das Regal-Menü öffnet
die eigene, ruhige Taste R – so öffnet sich nie aus Versehen ein Menü; seit Etappe 3h geht R
überall (ohne Regal im Blick nur mit der Bücherauswahl).
Schaut man auf etwas Interaktives, erscheint unter der Bildmitte nur ein kleines, weiches
Tastensymbol (abgerundetes E, R, Q oder eine Maus, auch mit hellem Mausrad) mit höchstens
einem Wort daneben („Nehmen“,
„Öffnen“, „Sitzen“). Halte-Aktionen haben einen feinen Ring um ihr Symbol, der sich beim
Halten füllt. In den Einstellungen unter „Hinweise“: Aus, Nur Symbole oder Symbol mit Wort
(Standard).
Esc schließt immer zuerst das, was gerade offen ist (Gestaltungsmodus, Tablet, Regal-Menü, Menüs).
Nur wenn nichts offen ist, öffnet Esc das Pausenmenü.

| Taste          | Aktion                                         |
|----------------|------------------------------------------------|
| W A S D        | Laufen                                         |
| Umschalt       | Schneller laufen (gedrückt halten)             |
| Leertaste      | Springen (etwa 0,8 m hoch, weich); im Sitzen: aufstehen |
| Strg           | Hocken (gedrückt halten), langsamer laufen     |
| Maus           | Umsehen                                        |
| E              | Interagieren (Objekt in der Bildmitte): Lampen und Kerzen schalten, hinsetzen, Tür öffnen/schließen, Karton auspacken, Theken-Tablet öffnen, Bücher aus dem Rückgabekasten nehmen |
| E beim Tragen  | Anderes Buch obenauf (Umschalt + E: zurück) – wenn das Angeschaute nichts mit E macht |
| R              | Bücher-Menü als Tablet, überall: Bücher aus dem Lager nehmen; am Regal auch Genre je Fach, auffüllen, sortieren (noch einmal R, Esc oder das Kreuz schließt es) |
| Rechtsklick    | Buch nehmen (Regal, Tisch, Boden, Rückgabekasten) – bis zu 7 tragen |
| Linksklick     | Buch obenauf genau dort ablegen, wo ich hinschaue (Regal, Tisch, Boden …) |
| Linksklick halten | Am Regal: alle passenden Bücher einräumen – ab dem Fach und der Stelle, auf die ich schaue |
| Mausrad        | Beim Tragen: Buch vor dem Ablegen drehen (flach oder angelehnt) |
| Q halten       | Alle getragenen Bücher ins Lager legen         |
| Tab            | Gestaltungsmodus (Inventar) öffnen/schließen   |
| F3             | Bilder pro Sekunde anzeigen/ausblenden         |
| F9             | Test: zufällige Bücher in den Rückgabekasten (bis es Besucher gibt) |
| F10            | Test: 500 Taler dazu                           |
| Esc            | Schließt, was offen ist – sonst Pausenmenü     |

### Im Gestaltungsmodus
Unten erscheint das **Inventar**: nur Dinge, die gerade im Inventar liegen, mit Anzahl (×2).
Was ganz im Raum steht, erscheint dort nicht (so bleibt es auch bei sehr vielen Objekten
übersichtlich); Wandfarben, Böden und Decken, die mir gehören, sind immer da. Ist ein Reiter
leer, steht dort freundlich: „Hier ist noch nichts. Bei „Nest & Nook“ am Theken-Tablet findest du mehr.“
Platzieren nimmt eins aus dem Inventar; Aufheben und Wegräumen (X) legen es zurück – samt
allem, was darauf steht.

Zwei Zustände:
- **Katalog-Zustand:** Mauszeiger sichtbar. Im Inventar stöbern und auswählen, platzierte Möbel
  anklicken (= aufheben, die Anzahl steigt um eins). Laufen mit WASD geht weiter, Umsehen mit gehaltener rechter Maustaste.
  Nach dem Umsehen erscheint der Mauszeiger genau dort wieder, wo man die Taste gedrückt hat.
- **Platzier-Zustand:** Sobald etwas ausgewählt oder aufgehoben ist, verschwindet der Mauszeiger
  und die Vorschau folgt dem Blick. Nach dem Platzieren oder Zurücklegen geht es automatisch
  zurück in den Katalog-Zustand.
- Die Statuszeile unten zeigt nur kurz den Namen (z. B. „Kleiner Globus ×1“) oder, warum es
  gerade nicht passt („Zu hoch für dieses Fach.“, „Hier stehen Bücher.“). Die Tasten stehen in
  der Tastenhilfe rechts.

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
  schwingt mit. Seit Etappe 3k bleibt eine offene Tür auch im Gestaltungsmodus offen, damit
  ich hindurchgehen kann; an die offene Tür hängt man nichts (Vorschau rot), und was an ihr
  hängt, lässt sich erst bei geschlossener Tür verschieben oder wegräumen.
- Der Schwenkbereich der Tür bleibt frei: Dort lassen sich weder Möbel noch Bücher abstellen
  (Vorschau rot, wie gewohnt).
- Vor der Tür liegt ein Stück Gehweg der Gasse (Platzhalter) mit Bordstein; links und rechts
  stehen die Nachbarhäuser. Hier kommen die Lieferkartons an.

## Einstellungen
- Im Pausenmenü unter „Einstellungen“: Fenster oder Vollbild, Auflösung (gängige Auflösungen
  inklusive Ultrawide), VSync (Standard: an), Bildrate begrenzen (30, 60, 120 oder unbegrenzt;
  Standard: 60). Gespeichert in einer eigenen Datei, getrennt vom Spielstand.
- Grafikqualität Niedrig, Mittel (Standard) oder Hoch. Die Werte jeder Stufe stehen in
  `GameConfig.graphics_presets` (Schatten, Umgebungslicht, Nebel, Kantenglättung, Staub …).
- Sparsame Schatten für ruhige Leistung: Nur wichtige Lampen werfen Schatten.
  - Sonne: immer.
  - Steh- und Kugelleuchte: ab „Mittel“ (der Schirm der Stehlampe wirft den gemütlichen
    Lichtkegel nach oben und unten).
  - Schlichte Pendelleuchte: nur auf „Hoch“.
  - Nie: Kerzen, Laternen, Kronleuchter und Rattan-Hängelampe. Ihr Licht sitzt zwischen vielen
    kleinen Teilen (Arme, Kerzen, Ring, Geflecht), deren Schatten seltsame Streifen und Ringe an
    Wände und Decke werfen würden; ihr Licht bleibt trotzdem genauso warm.
- Fensterlicht: Die Sonne verteilt ihre Schatten auf Stufen (Kaskaden) – nah fein, fern gröber.
  Die Übergänge werden weich überblendet, damit keine Linie im Fensterlicht entsteht.
  Niedrig nutzt 2 Stufen, Mittel und Hoch 4. Schattenweite der Sonne: 20 m (GameConfig).
- Im Pausenmenü läuft das Spiel mit höchstens 30 Bildern pro Sekunde, damit der Rechner ruht.
- Bilder pro Sekunde anzeigen: in den Einstellungen oder mit F3.
- Hinweise (Tastensymbole unter der Bildmitte): Aus, Nur Symbole oder Symbol mit Wort
  (Standard).
- Alle Menüs und Anzeigen passen sich an jede Auflösung und jedes Seitenverhältnis an.
- Später dazu: Lautstärke, Mausempfindlichkeit, Tageslänge.
- Weitere Räume und Obergeschoss werden später freigeschaltet.
