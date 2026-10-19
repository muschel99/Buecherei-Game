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
| `pub` | Vorlagebild der Entwicklerin (Bilderbuch) | **fertig (4h, Bilderbuch-Stil):** „The Ink & Ivy“: Backstein mit hellen Bögen, flaschengrüne Ladenfront, Fenster mit flachem Bogen, Zahnschnitt-Gesims, Gaststube, Bistrotische, Schilder als Bilder (`build_storybook_pub.py`) |
| `gatehouse` | Vorlagebild der Entwicklerin (Bilderbuch) | **fertig (4h, Bilderbuch-Stil):** Backstein, Rundbogen aus Sandstein mit Schlussstein, Gewölbe, grünes Schildband „Alte Torgasse“, Fachwerk mit Terrakotta-Gefachen, Gaube, Wandlaternen, beide Seiten gleich (`build_storybook_gatehouse.py`) |
| `terrace_*` | Inspiration Straßenfotos | **fertig (4g, Teil 2):** 45 schmal mit Schlusssteinen, 50 mit Erker, 55 georgianisch mit Brüstung, 60 breit mit Gaube; Wand je Haus Backstein, Putz oder Rauputz |
| `residential` | – | **fertig (4g, Teil 2):** mittige Tür unter Vordach mit Säulen und Giebel, Lorbeer-Kegel |
| `corner_90` | Vorlagebild der Entwicklerin (Bilderbuch) | **fertig (4h):** Teeladen „Teestube“: Backstein, schwarze Ladenfront mit Gold zur langen Straße, Fensterläden, Tee, Dosen und Kannen (`build_storybook_tea.py`) |
| `corner_30` | Vorlagebild der Entwicklerin (Bilderbuch) | **fertig (4h):** Wolle & Stoff: Putz creme, taubenblaue Schaufenster links und rechts, Tür in der Schräge, Schildband um beide Ecken (`build_storybook_wool.py`) |
| Blumenladen, Bäckerei | Vorlagebilder der Entwicklerin (Bilderbuch) | **fertig (4h):** Blumenladen farngrün mit Hollandrad und Pflanzkasten über dem Schild (`build_storybook_flowers.py`); Bäckerei mit Giebel zur Straße und rot-weißer Markise (`build_storybook_bakery.py`) |
| Bücherei | Konzept „Bookstore“, „The Book Nook“ | Ladenfront in der Schräge, Schild, Sprossenfenster |

## Bilderbuch-Stil (seit Etappe 4h)
Die Welt wird zu einer **lebendig gewordenen Kinderbuch-Illustration**: Vintage-Charme in
moderner 3D-Darstellung – warm, einladend, liebevoll gestaltet und bewusst unperfekt. Ein alt
gewachsenes Dorf, idealisiert, ruhig und ordentlich, ohne Verfall, Schmutz oder störende Moderne.
Umgesetzt: Modegeschäft (`build_storybook_shop.py`), Pub (`build_storybook_pub.py`), Bäckerei,
Blumenladen, Teeladen, Wolleladen und Torhaus (`build_storybook_<haus>.py`, gemeinsame Bausteine
`storybook_town.py`) in `tools/blender/`. Die anderen Häuser folgen. Pflanzen bleiben vorerst weg (nur Töpfe und Kübel);
Schilder sind weiter Bilder der Entwicklerin.

**Formen**
- Solide und handfest, wie aus echten Materialien, die sich über die Jahre gesetzt haben – **nicht**
  Knete, Play-Doh oder digitales Spielzeug. Häuser stehen fest im Boden, Dächer liegen auf.
- Nichts steht perfekt gerade: Wände minimal wellig, das Haus leicht geneigt, das Dach in der
  Mitte etwas durchgesackt, Fenster, Gauben, Markisen, Schilder, Balkone um Bruchteile eines
  Grads schief oder um Millimeter verschoben. Jedes Haus mit eigener Wölbung (`SETTLE`).
- Weiche Kanten (Bevel), aber klare, lesbare Proportionen.
- **Logisch geschlossen:** Türnischen oben mit einer Nischendecke schließen, Oberlicht direkt
  über dem Türblatt in derselben Ebene (sonst schaut man über der Tür ins Haus). Innenwände
  reichen bis dicht hinter die Schaufenster, Vertäfelung endet an Fenstern, Stühle schauen zum
  Tisch. Leicht schiefe Teile überlappen sich immer (nie genau Kante an Kante); Schilder sitzen
  auf einem geschlossenen Schildkasten in der Farbe der Holzfassade. Prüfen mit
  `storybook_gap_check.py` (muss „keine Löcher gefunden“ melden).
- **Markisen sind Stoff:** ein einziges Stück (Blenders Stoffsimulation: leichter Durchhang
  zwischen Kasten und Fallstange, Volant fällt frei), mit Dicke, ohne Seitenplatten oder Fugen;
  im Spiel schwingt der Stoff leicht im Wind. Kasten, Gelenkarme und Stange tragen ihn.
- **Oberflächen ruhig:** Putz mit sanften Kellenwellen, Stein weich unregelmäßig (keine Risslinien),
  gestrichenes Holz matt ohne Maserung, nur echtes Holz mit feinen Linien; nichts darf aus der
  Entfernung sandig flimmern. Markisen: Arme seitlich neben dem Stoff, nie darunter.
- **Nichts steht in der Wand:** Töpfe, Kübel, Kästen und Tafeln stehen frei vor Brüstung,
  Pilastern und Türpfosten (auch nicht im Nachbarhaus); Prüfung `storybook_overlap_check.py`.
- **Fahrräder und Gestelle logisch:** Räder stehen auf dem Boden, Ständer berühren den Boden,
  Rahmen, Gabel, Kette und Körbe hängen wirklich zusammen.
- **Bögen über Fenstern:** Fenster oben mit flachem Bogen, Steinbogen genau darauf (gleicher
  Mittelpunkt), Bögen und Bänke im hellen Gesims-Material, frei unter dem Traufgesims.
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
- **Blätter prall und rund** (Vorlagebilder der Entwicklerin): jedes Blatt ein glatter, kissenförmiger
  Körper mit runder Spitze, gut einzeln erkennbar, an sichtbaren Stielen; keine Körnung, keine
  spitzen Zacken. Blüten mit fünf runden Blütenblättern (Kerbe dazwischen), zu Kuppeln geordnet.
- **Keine Grundformen sichtbar:** Kerne in Büschen und Blütenköpfen sind klein und dunkel und ganz
  von Blättern/Blüten verdeckt – man sieht sie höchstens als Schatten.
- **Kletterpflanzen sind wilde Ranken:** verholzte Haupttriebe in Bögen und schrägen Schwüngen,
  Seitentriebe, die sich verzweigen oder herabhängen, einzelne Blätter in kleinen Büscheln – keine
  dichten Blattpolster, nie vor Fenstern.
- **Vielfalt:** viele Sorten (Geranien, Petunien, Männertreu, Begonien, Fuchsien, Kräuter, Heide,
  Stiefmütterchen, Tulpen, Margeriten, Dahlien, Rosen, Zitrus, Oliven, Buchs, Gräser …) in natürlichen
  Farben und verschiedenen Grüntönen; nebeneinander nie zweimal dieselbe Pflanze.
- **Ranken aus Gefäßen** legen sich über den Rand, nie durch Topf oder Kasten.
- **Grasbüschel** am Fuß der Hauswände, an Gassenmauern und am Bordstein.
- **Bäume:** natürlich verzweigt, Krone aus vielen Blattbüscheln; der Baum im Gartenhof ist groß und
  überspannt den ganzen Hof.
- **Fensterbögen** haben ein eigenes, ruhiges Material (kein Ziegelmuster der Wand). Über runden
  Fenstern sitzt immer ein gebogener Sturz, gerade Stürze nur über geraden Fenstern.

**Licht (kommt für die ganze Welt)**
- Warm um 3500 K, weiche fließende Schatten, keine harten Kontraste, mildes warmes Bloom um
  Lichtquellen, Laternen und Schaufenster im Glühbirnen-Look, Fensterlicht als Blickfang.
- Etwas mehr Umgebungsverdeckung in Ecken und Nischen, geringe Schärfentiefe.

**Wege**
- Kopfsteinpflaster oder gepflegter Naturweg, Steine bewusst nicht perfekt ausgerichtet
  (versetzte Reihen, kleine Höhenunterschiede, unterschiedliche Steinformen).
