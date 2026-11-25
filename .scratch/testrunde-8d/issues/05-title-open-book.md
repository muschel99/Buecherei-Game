# 05 – Hauptmenü: großes aufgeschlagenes Buch
Status: done

- Im Hintergrund ein großes aufgeschlagenes Buch, der Baum wie eine Abbildung in diesem Buch, der Notizzettel mit dem Menü
  liegt im Buch.
- Die fliegenden Bücher flattern falsch herum.
- Die fliegenden Seiten sind immer hochkant – sieht sehr unecht aus.

## Comments

25.11.2026: Entscheidungen der Entwicklerin: der Baum als **lebendiges Bild** (flach gedruckt mit Papier-Struktur und Rand, bewegt
sich aber sanft), das Buch **schwebt vor dem weichen Abendhimmel** (kein Tisch).
Plan: 1. fliegende Bücher und Seiten reparieren, 2. großes aufgeschlagenes Buch (Blender-Script), 3. Garten als lebendiges Bild
auf der rechten Seite, 4. Menü-Zettel auf der linken Seite, Bücher und Seiten fliegen ums Buch, „Weiterspielen“ fährt ins Bild.

Schritt 1 erledigt: Die Deckel der fliegenden Bücher schlagen nach unten wie ein Dach über den Seiten (vorher bog sich das Buch
rückwärts über den Rücken); lose Seiten fallen wie Papier (pendeln, kippen in den Schwung, drehen sich – `LoosePage`).

25.11.2026: Schritte 2–4 erledigt. Großes aufgeschlagenes Buch (`build_title_book.py`: Ledereinband mit Messingecken, gewölbte
Seiten mit Falz, Lesebändchen) schwebt vor dem Abendhimmel (`TitleBook`, `scenes/ui/title_book.tscn`); rechts der Garten als
lebendiges Bild (TitleBackdrop im eigenen SubViewport, gedruckt mit weichem Aquarell-Rand: `title_page.gdshader`); links der
Menü-Zettel, mit einer Büroklammer an der Seite angeheftet; „Weiterspielen“ fährt ins Bild hinein.
Nachträge der Entwicklerin beim Anschauen: Baum gerader (Kamera weit weg mit engem Sichtfeld, Stamm zur Kamera gedreht), Buch
genau frontal und schief (links tiefer), keine fliegenden Bücher mehr, Büroklammer statt Klebestreifen – nach ihrem Foto: von vorn
nur die vordere Schlaufe, oben schaut der Bogen über die Kante; der Zettel sitzt oben an der Seitenkante, die Klammer hält beide.
