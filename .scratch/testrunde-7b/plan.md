# Testrunde nach Etappe 7 (Liste der Entwicklerin vom 13.11.2026, Foto: liste.jpg)

Status: claimed

## Teil 1 – Nacht
- [x] Ab 22 Uhr kommt niemand mehr in die Straße, bis 5 Uhr Ruhe (höchstens mal eine Katze)
- [x] Nachts gießt und fegt niemand
- [x] Andere Läden ab 22 Uhr leer/geschlossen, Verkäufer gehen
- [x] Nicht in jedem Fenster Licht
- [x] Mond wärmeres Licht, mehr Nachtstimmung
- [x] Sterne erst später, dunkler und wärmer; ab und zu eine Sternschnuppe
- [x] Malfilter: nachts Linien dunkelblau statt braun; Linien in der Ferne zu dick

## Teil 2 – Besucher
- [x] Theke: Ausweis nehmen, stempeln, Bücher scannen (Schritte)
- [x] Einnahme ploppt oben links beim Geld auf, kein Text
- [x] Ladentür: wer hinaus will, hat Vorfahrt; nicht an der Theke blockieren
- [x] Lese-Animation; Sitzmöbel zu hoch
- [x] Besucher tragen einen kleinen Korb und legen die Bücher hinein
- [x] Türschild nur innen, Vorderseite zur Straße (innen die Rückseite)

## Teil 3 – Hinterzimmer
- [x] Bücherei nach hinten verlängern (Außenmauern, Dach, Sockel bis zum Boden), echte Tür statt Vorhang, prüfen gegen Haus hinter dem Modegeschäft

## Teil 4 – Straße
- [x] Katzen blockieren sich und den Eingang auf der Treppe
- [x] Gießkanne falsch gebaut (entfällt: Gießen und Fegen ganz entfernt, Wunsch der Entwicklerin)
- [x] Tür öffnen/schließen: Handbewegung der Passanten entfernt (Wunsch der Entwicklerin)
- [x] Lieferwagen ruckelt beim Start
- [x] Kartons stehen in der Deko

## Teil 5 – Bedienung
- [x] Hänger in der App „Fassade“ (siehe Teil 7)
- [x] Tooltip-Schrift bei Nest & Nook kaum lesbar
- [x] Gestaltungsmodus: Mausrad wählt Möbel, wenn nichts in der Hand
- [x] Theke und Katzen leuchten nicht mehr auf
- [x] Pausenmenü als Notizbuch (Antworten der Entwicklerin): zugeklapptes Buch gleitet ins Bild und öffnet sich mit schöner
  Animation, das Spiel steht still; erste Seite nur das Wichtigste (Weiter, Speichern, Beenden); bunte Haftnotizen an der Seite
  je Kategorie – Klick blättert dorthin, Notizen umgeblätterter Seiten wandern auf die linke Seite; Seiten gut gefüllt und
  übersichtlich; es soll wie ein richtiges, schönes Buch aussehen
- [x] Hitboxen: Stempel-Bereich auf der Theke nur noch klein und nur, wenn jemand wartet (verdeckte Tablet/Bücher)
- [x] Besucher in der Bücherei zu langsam: Tempo 1,05–1,35 m/s, kein Abbremsen voreinander
- [x] Gießen + Fegen ganz entfernt

## Teil 6 – Büchersystem (Antworten der Entwicklerin)
- [x] Bücherkisten je Genre unter der Theke: gezielt Bücher aus den Kisten nehmen (statt aus dem Lager über das R-Menü)
- [x] Regal-Menü: weniger Knöpfe, zeigt, was wo steht; Bücher leichter finden

## Teil 7 – Nachtest der Entwicklerin (Fassaden-Vorschau, Möbel)
„Die Fassadenvorschau hing und hat sehr lange geladen. Die Möbel sind zum Großteil falsch zusammengebaut und schweben in der
Luft.“ – „Achte auf die Möbel, bei denen die Beine nicht am Grundkörper befestigt sind.“
- [x] Alle 107 Möbel einzeln aus vier Blickwinkeln angesehen (`furniture_probe.tscn -- ids=…`)
- [x] Beinprüfung `tools/blender/leg_check.py` (jedes Bein steckt oben im Körper, alles steht auf dem Boden) – alle in Ordnung
- [x] Bau-Regel `Kit.attach_feet`: Beine knapp unter dem Körper werden bis in ihn verlängert (Sitzmöbel, Tische, Regale)
- [x] Füße unter die runden Polster gerückt: Chesterfield-Sessel/-Sofa, Bouclé-Sessel, Blümchensofa; Weintisch und Garderobe
  standen 1 cm über dem Boden (`curved_leg` hob den Fuß an)
- [x] Rückenlehne von Korbsessel und Schreibtischstuhl lag vorn; Armstützen tragen jetzt die Lehne
- [x] Freie Teile: Querstrebe Schalenstuhl, Ziernägel Chesterfield, Regalbretter schmales Regal, Schal an der Garderobe,
  Lamellen/Griff Sideboard, Ringe Planetenmodell, Teddy-Sohlen, Fransen der Schottenkaro-Decke, Stütze Bilderrahmen
- [x] Pouf: Zopfmuster statt abstehender Perlen; runde Armlehnen-Enden (Bouclé-Sessel, Blümchensofa)
- [x] Weicher Übergang beim Absenken der Sitze (keine Knickkante auf Polstern)
- [x] Was auf niedriger gewordenen Sitzmöbeln lag (Kissen, Decken, Bücher), rutscht beim Laden nach (`Room._settle_on_supports`)
- [x] Fassaden-Vorschau: Hänger beim Öffnen – Vorschau-Fenster zeichnen mit derselben Kantenglättung wie das Spiel (`Settings.match_preview_quality`; mit TAA ein paar Bilder je Änderung); gemessen: längstes Stocken etwa ein Fünftel
