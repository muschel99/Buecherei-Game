# 01 – Mehr Draußen-Sachen
Status: resolved

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

24.11.2026: Runde 2 fertig: Parkbank (`out_park_bench`), Gartenstuhl (`out_garden_chair`, gleiche Bauart wie die
Gartenbank: `_garden_seat`), Klappstuhl (`out_folding_chair`), Holzhocker (`out_wood_stool`), Klapptisch
(`out_folding_table`), kleiner Holztisch (`out_wood_table`), Fass als Tisch (`out_barrel_table`). Nebenbei: Gartenbank
neu gebaut (hinteres Bein endete genau auf Höhe der Sitzlatten → Flimmern).

24.11.2026: Runde 3 fertig – 17 Pflanzen: Tulpen (`out_tulip_pot`), Rosmarin (`out_rosemary_pot`), Margeriten im
Emailleeimer (`out_marguerite_bucket`), Dahlien (`out_dahlia_pot`), Funkie (`out_hosta_bowl`), Farn im Zinkeimer
(`out_fern_bucket`), Kräuterkiste (`out_herb_crate`), Rosenbusch (`out_rose_bush`), Buchskegel (`out_box_cone`),
Lorbeerstämmchen (`out_bay_standard`), Ziergras (`out_grass_pot`), Sonnenblumen (`out_sunflower_bucket`), Stockrosen
(`out_hollyhock_pot`), Blumenkasten mit Geranien (`out_flower_box`), Kletterrose/Efeu/Glyzinie am Rankgitter
(`out_rose_trellis`, `out_ivy_trellis`, `out_wisteria_trellis`). Eimer haben Seitengriffe statt Henkel (der ginge durch die
Pflanze; `F.pot(handle=False)`). Neue Prüfung `tools/blender/plant_clip_check.py`.

24.11.2026: Runde 4 fertig – Deko: Fahrrad mit Blumenkörben (`out_flower_bike`, Rad aus `storybook_town.bicycle` + Halter am
Doppelständer), Schubkarre mit Blumen (`out_wheelbarrow`), Milchkanne mit Blumen (`out_milk_churn`), Zinkwanne mit
Sommerblumen (`out_zinc_tub`), Gießkanne (`out_watering_can`), Vogelhäuschen (`out_birdhouse`), Vogeltränke (`out_birdbath`),
Rosenkugel (`out_gazing_ball`), Igel aus Stein (`out_hedgehog`), Kürbisse (`out_pumpkins`). Zettel erledigt: zusammen 41 neue
Draußen-Sachen.
