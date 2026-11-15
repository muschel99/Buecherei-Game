# Hauptmenü, Story-Anfang, Tutorial und Namen (Wunsch der Entwicklerin, 15.11.2026)

Status: done

## Wünsche (Antworten der Entwicklerin)
- **Namen:** passen nicht zur Figur (Männer heißen Greta …); ein Name, aber die Figur sieht anders aus
- **Hauptmenü:** rechts der Baum mit der Bank (Gartenhof der Baumgasse), links ein Notizzettel mit dem Hauptmenü
- **Story:** Eine Maklerin „übergibt“ das Haus, das wir gekauft haben, und zeigt uns die Startausstattung, die schon da war
  (vom Vorbesitzer)
- **Tutorial:** Die Maklerin zeigt die wichtigsten Sachen, danach erscheinen am Rand kleine To-do-Listen für die kleinen Schritte

## Ursachen (Namen)
- Wiederkehrende Gäste: `Lending.returning_reader` gab einer beliebigen Figur einen beliebigen alten Ausweis
- Neue Ausweise: Name zufällig, ohne auf Frau/Mann zu achten (englische Autorennamen)
- Stammgäste: Aussehen aus dem Namen gewürfelt, Frau/Mann dabei zufällig

## Schritte (je Schritt hochladen, dann weiter)
- [x] 1. Namen: Vornamen nach Frau/Mann (`data/visitors/names.txt`, `PersonNames`), Ausweis merkt sich das Aussehen
  (`look`, `female`), bekannte Gäste kommen beim Losgehen mit ihrem Aussehen wieder (`LibraryVisits.assign_regular`),
  Stammgäste mit fester Spalte w/m, Name im Gespräch = Name auf dem Ausweis
- [x] 2. Hauptmenü: nach dem Laden Blick auf Baum und Rundbank im Gartenhof (rechts), links ein Notizzettel: Weiterspielen,
  Neues Spiel (mit Nachfrage), Einstellungen (Notizbuch), Beenden; Weiterspielen = Kamera gleitet zur Spielfigur
- [x] 3. Story-Anfang: neues Spiel beginnt draußen vor der Bücherei; die Maklerin begrüßt, geht voraus und zeigt an Stationen
  Theke mit Tablet, Bücherkisten vom Vorbesitzer, Hinterzimmer mit Bett, Rückgabekasten und Türschild; Schlüssel, Abschied
- [x] 4. To-do-Listen am Rand: kleine Aufgabenlisten nacheinander (Einrichten, Bücher, Öffnen, Gemütlich), haken sich von selbst
  ab, Tastensymbole, einklappbar; Texte in einer Datei
