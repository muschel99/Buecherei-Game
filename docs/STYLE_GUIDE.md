# Stil-Leitfaden (seit Etappe 4g)

Grundlage: die Bildersammlung in `Game design/` (Ordner *Stilrichtung* = Konzeptbilder einzelner
Häuser und der Straße, Ordner *Inspiration* = Fotos typischer englischer Straßen). Die Figuren
(Bild „Charakter stil“) bleiben vorerst außen vor.

## Die Richtung in einem Satz
**Stilisierter Realismus:** echte Proportionen, echte Materialien und viele kleine, glaubwürdige
Details – aber ruhige, leicht vereinfachte Formen und weiche, warme Farben. Gemütlich, nicht
niedlich: keine Kulleraugen-Häuser, keine schiefen Comic-Wände, keine knalligen Bonbonfarben.

## Was die Bilder gemeinsam haben
- Englische Ladenstraße des 19. Jahrhunderts: Reihenhäuser aus **rotem Backstein**, hellem
  **Sandstein** und **Putz in warmen Cremetönen**, dazwischen **Fachwerk** (Torhaus, Gasse).
- **Ladenfronten aus lackiertem Holz** in tiefen Farben (Marineblau, Flaschengrün, Pflaume,
  Schwarz) mit Pilastern, Konsolen, Schild mit **goldener Schrift**, Sprossen-Oberlichtern,
  Brüstungen mit Füllungen und oft **gestreiften Markisen**.
- Obergeschosse mit **Schiebefenstern** (weiße Rahmen, Sprossen, helle Vorhänge),
  Fensterbänken und Verdachungen aus Stein.
- **Schieferdächer** (blaugrau) oder **Tonziegel** (rotbraun) mit **Gauben**,
  **Schornsteinen** mit Tonaufsätzen, Regenrinnen und Fallrohren.
- Straßenraum: **Kopfsteinpflaster**, große Gehwegplatten, Bordsteine, gusseiserne Laternen,
  Blumenkübel, Hängekörbe, Kreidetafeln. (Laternen und Blumen sind neue Objekte – kommen
  später, wenn wir sie einplanen.)
- Licht: **warmes, tief stehendes Sonnenlicht** (goldene Stunde), warme Schaufenster.

## Regeln für alle Modelle
1. **Der Grundriss im Spiel bleibt.** Breite, Tiefe und Traufhöhe jedes Haustyps (und die
   Lage im Plan) ändern sich nicht. Passt ein Konzeptbild nicht dazu, wird das Design
   angepasst, nicht der Plan (Beispiel Modegeschäft: Konzept etwa 7 m breit, im Spiel 5,4 m –
   der Ziergiebel ist schmaler, die Gauben kleiner, die Tür mittig in einer flachen Nische).
2. **Echte Maße:** Ziegel 21,5 × 6,5 cm, Stockwerke gut 3 m, Türen 2,1–2,3 m, Fenster etwa
   0,9 × 1,6 m, Dachneigung etwa 35°.
3. **Tiefe statt Fläche:** Fenster sitzen in Laibungen (12–15 cm tief), Rahmen und Gesimse
   stehen vor, Ladenfronten sind ein eigenes Bauteil vor der Wand. Das macht den Unterschied
   zwischen „Kulisse“ und „Haus“.
4. **Wenige, gemeinsame Materialien:** alles aus den Stil-Texturen
   (`assets/textures/style/`, 20 Ebenen). Kein Modell bringt eigene Bilder mit.
5. **Farben je Haus** kommen weiter aus Godot (Wandfarbe, Türfarbe, Akzentfarbe): Die Wand
   eines Hauses ist z. B. Sandstein, die Farbe sagt, welcher Ton. Ladenfront und Haustür =
   Türfarbe, Markise und Schild-Akzente = Akzentfarbe.
6. **Leistung:** ein Haus = ein Zeichenaufruf (+1 für Schaufensterglas). Etwa 5.000–15.000
   Dreiecke je Haus. Was man nie sieht (Rückseite), bleibt schlicht.
7. **Kleine Unregelmäßigkeiten** gehören dazu (Steine leicht verschieden, etwas Flechte auf
   dem Dach). Seit dem Bilderbuch-Stil (unten) dürfen Häuser auch minimal schief und wellig
   sein – subtil, nie verformt.

## Pflanzen (seit Etappe 4g, Teil 4f)
- **Echte Blätter statt Kugeln:** jedes Blatt eine gebogene, leicht gefaltete Fläche mit
  echter Form (gezackter Rand, Lappen beim Efeu, Adern) aus den Pflanzen-Texturen; Blüten aus
  einzelnen Blütenblättern bzw. Einzelblüten (Geranien-Dolden, Hortensien-Bälle).
- **Alles hängt zusammen:** Blatt → Stiel → Trieb → Erde/Stamm. Efeu wächst aus einem
  Pflanzloch die Wand hoch, um Fenster und Fallrohre herum, über Gesimse hinweg, mit
  Haftwurzeln. Ranken hängen über Kastenränder, nicht durch sie hindurch.
- **Nichts steckt ineinander:** Pflanzen wachsen nicht in Wände, Töpfe, Kästen oder Zäune
  (style_plants: Space, settle). Töpfe und Kästen sind oben offen, mit Rand und Erde.
- **Üppig, aber gepflegt:** englische Blumenkästen und Hängekörbe quellen über (Geranien,
  Petunien, Lobelien, Efeu); Formgehölze (Buchskugel, Kegel, Hochstämmchen) sind sauber
  geschnitten.
- **Leistung:** kleine Blätter und Blüten mit wenigen Flächen, hinter Glas weniger Stiele
  (Detailstufe); Efeu höchstens etwa 1.400 Blätter je Pflanze.

## Läden von innen
- Wer durch Tür oder Schaufenster schaut, sieht einen ganzen Raum – nie ins Leere.
- **Dezent vintage:** wenige, gut gewählte Dinge statt Fülle; warme Hölzer, Messing, gedeckte
  Farben (Salbei, Altrosa, Senf, Petrol, Creme), ein Samt-Akzent.
- Innenräume leuchten leicht von selbst (Material-Leuchten statt Lampen-Licht), damit sie
  von der Straße warm wirken und nichts durch Wände strahlt.
- Ware (Kleidung …) ist austauschbar: eigene kleine Szenen, Farbe je Stück.

## Farbpalette (Richtwerte, sRGB)
| Was | Farbe |
|-----|-------|
| Backstein rot / braun | (0.6, 0.33, 0.25) / (0.5, 0.3, 0.24) |
| Sandstein, Putz creme | (0.9, 0.86, 0.8) / (0.86, 0.8, 0.68) |
| Stein-Zierteile | (0.81, 0.77, 0.67) |
| Ladenfront Marineblau | (0.1, 0.13, 0.21) |
| Ladenfront Flaschengrün | (0.12, 0.24, 0.18) |
| Weiße Fensterrahmen | (0.93, 0.92, 0.88) |
| Schiefer | (0.25, 0.27, 0.31) |
| Gold (Schrift, Beschläge) | (0.85, 0.66, 0.3) |

## Pläne für die einzelnen Häuser
| Haustyp | Vorbild | Umsetzung |
|---------|---------|-----------|
| `fashion_shop` | Vorlagebild der Entwicklerin (Bilderbuch) | **fertig (4h, Bilderbuch-Stil):** „Zwirn und Zwirbel“: Putz creme, taubenblaue Ladenfront, Nussbaum-Schild mit Goldschrift, terrakotta-rosa Markisen, Oberlicht, Gauben, Ziergiebel, Efeu, Blumenkästen, Buchs (`build_storybook_shop.py`) |
| `pub` | Inspiration „Westminster Arms“, „O'Brian's“ | dunkelgrüne Pub-Front mit großen Sprossenfenstern, Laternen, Hängekörbe, Ziegel darüber |
| `gatehouse` | Konzepte Torhaus (Ziegelbogen + Fachwerk) | Ziegel-Rundbogen mit hellen Bogensteinen, Fachwerk-Obergeschoss, Gaube |
| `terrace_*` | Inspiration Straßenfotos | **fertig (4g, Teil 2):** 45 schmal mit Schlusssteinen, 50 mit Erker, 55 georgianisch mit Brüstung, 60 breit mit Gaube; Wand je Haus Backstein, Putz oder Rauputz |
| `residential` | – | **fertig (4g, Teil 2):** mittige Tür unter Vordach mit Säulen und Giebel, Lorbeer-Kegel |
| `corner_*` | Konzept „flowershop“ | Eckladen mit Ladenfront in der Schräge |
| Bücherei | Konzept „Bookstore“, „The Book Nook“ | Ladenfront in der Schräge, Schild, Sprossenfenster |

## Bilderbuch-Stil (seit Etappe 4h)
Die Welt wird zu einer **lebendig gewordenen Kinderbuch-Illustration**: Vintage-Charme in
moderner 3D-Darstellung – warm, einladend, liebevoll gestaltet und bewusst unperfekt. Ein alt
gewachsenes Dorf, idealisiert, ruhig und ordentlich, ohne Verfall, Schmutz oder störende Moderne.
Umgesetzt: Modegeschäft (`tools/blender/build_storybook_shop.py`). Die anderen Häuser folgen.

**Formen**
- Solide und handfest, wie aus echten Materialien, die sich über die Jahre gesetzt haben – **nicht**
  Knete, Play-Doh oder digitales Spielzeug. Häuser stehen fest im Boden, Dächer liegen auf.
- Nichts steht perfekt gerade: Wände minimal wellig, das Haus leicht geneigt, das Dach in der
  Mitte etwas durchgesackt, Fenster, Gauben, Markisen, Schilder, Balkone um Bruchteile eines
  Grads schief oder um Millimeter verschoben. Jedes Haus mit eigener Wölbung (`SETTLE`).
- Weiche Kanten (Bevel), aber klare, lesbare Proportionen.
- Jedes Teil ist ein **geschlossener Körper mit Dicke** (keine Einzelflächen), einzeln in
  Blender bearbeitbar; Bauteile in Sammlungen (Mauern, Dach, Fenster, Laden, Innen, Pflanzen,
  Deko, Licht).

**Farben**
- Basis: Sepia, Beige, warmes Braun, gebrochenes Weiß (Creme, Sand, helles Taupe).
- Akzente: satte Grüntöne (Wald, Oliv, Moos), Terrakotta und Ziegelrot bis Orange-Rot,
  Blautöne, Rosa, Senfgelb – mit vielen Abstufungen; kein Haus trägt genau denselben Ton.
- Jeder Baustein hat eigene Nuancen (Farbton je Teil, leichte Flecken). Kein Neon, kein reines
  Schwarz, kein reines Weiß.

**Materialien**
- Matt, sichtbare Materialität: Holzmaserung, Steinstruktur, leicht rauer Putz, Ziegel in
  echter Größe; nichts glänzt oder spiegelt (Glas klar, aber matt).

**Pflanzen**
- Üppig: Blumenkästen an möglichst jedem Fenster, Efeu an Fassaden, Büsche und Bäume.
- Natürlich, nicht symmetrisch: Äste in natürlichen Richtungen, Laub ungleich dicht, einzelne
  Blüten und Zweige stehen heraus; Buchs nicht exakt rund.

**Licht (kommt für die ganze Welt)**
- Warm um 3500 K, weiche fließende Schatten, keine harten Kontraste, mildes warmes Bloom um
  Lichtquellen, Laternen und Schaufenster im Glühbirnen-Look, Fensterlicht als Blickfang.
- Etwas mehr Umgebungsverdeckung in Ecken und Nischen, geringe Schärfentiefe.

**Wege**
- Kopfsteinpflaster oder gepflegter Naturweg, Steine bewusst nicht perfekt ausgerichtet
  (versetzte Reihen, kleine Höhenunterschiede, unterschiedliche Steinformen).
