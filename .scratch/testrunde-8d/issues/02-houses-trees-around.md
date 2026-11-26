# 02 – Häuser und Bäume rund um den Garten, Wäldchen hinter dem Torhaus
Status: ready-for-agent

- Ein paar Häuser, die man vom Garten aus sieht, damit es nicht aussieht, als wäre die Stadt dort zu Ende.
- Mehr Bäume rund um den Garten hinter den Mauern (Natur). Viel Himmel soll bleiben, die Sicht nicht verbaut.
- In der Stadt ist kein Platz für Bäume: vielleicht hinter dem Torhaus in der Gasse ein oder zwei Häuser durch ein kleines
  Wäldchen oder einen Park ersetzen.
- Den Ausblick am besten nach dem Holzhäuschen fertig machen.

## Comments

26.11.2026: Teil 1 fertig (`tools/blender/build_storybook_backyard.py`, `town_house`, `town_around`, `outside_ground`):
- hinten drei Häuser mit 4 m breiten Lücken (dort Bäume), weiter hinten drei Dächer; rechts und links je zwei Häuser, zwei Häuser
  quer am Ende der Seitenstraße (gerades Ende, endet bei z = 9,9) – rundum geschlossen, Fenster mit Vorhängen, Fallrohr,
  Schornstein, schlichte Ziegelreihen (spart Dreiecke); Lage so, dass man sie von der Straße nicht sieht;
- Wiese ringsum bis 90 m weit (aus den Fenstern des Häuschens sieht man kein Ende), 21 Bäume hinter den Mauern;
- neuer Baum `tree_far` (Hinweis "far", 40 000 statt 101 000 Dreiecke) für alles hinter den Mauern; die fünf Bäume direkt
  vor dem hinteren Fenster bleiben normale Gartenbäume (die großen Blätter wirken von nah zu grob);
- Greenery: Bäume mit Hinweis stehen nur noch bei "garden" fest (`FIXED_TREE_HINTS`), "far" wird gedreht und skaliert.
Dazu (Wunsch der Entwicklerin): der Feldsteinsockel der Mauer ist an den Bachtunneln unterbrochen.
Noch offen: Park/Wäldchen hinter dem Torhaus.
