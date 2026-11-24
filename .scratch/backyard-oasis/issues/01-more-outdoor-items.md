# 01 – Mehr Draußen-Sachen
Status: ready-for-agent

Viele weitere Dinge für die Abteilung „Draußen“ im Nest & Nook (Bau-Script `tools/blender/furniture_outdoor.py`,
ids `out_…`): Sitzplätze, Tischchen, sehr viele Pflanzen in allen Größen, Farben und Formen, Kundenstopper, kleine Regale
und Auslagen, in die man Bücher oder Deko stellen kann (Ablageflächen `k.surface`, Bücher `lean`/`lie`).
Details: `.scratch/outdoor-decor/issues/04`, `05`, `06`. Die Sachen sollen später auch im Garten stehen dürfen.

In vier Runden (je ein Commit): 1. Regale, Auslagen, Schilder · 2. Sitzplätze und Tischchen · 3. Pflanzen · 4. kleine Deko.

## Comments

24.11.2026: Runde 1 fertig (`tools/blender/furniture_outdoor.py`): Bücherkisten (`out_book_crates`), Bücherkarren
(`out_book_barrow`), Bücherschrank zum Tauschen (`out_swap_library`), Pflanzentreppe (`out_plant_stairs`), Blumen-Etagere
(`out_etagere`), Wegweiser (`out_signpost`), Schild am Ständer (`out_hanging_sign`). Draußen aufgestellte Regale sind
Deko mit Büchern – Besucher stöbern nur drinnen (`library_visits.gd`, `room.is_ancestor_of`). Das Möbel-Bau-Script meldet
jetzt je Objekt „Offene Kanten“.
