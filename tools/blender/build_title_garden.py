"""Gartenstück fürs Hauptmenü (Wunsch der Entwicklerin: der große Baum mit der Rundbank einzeln, ohne Häuser, auf einem
gemütlichen Hintergrund).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_title_garden.py [-- --render] [--force]
Ergebnis: assets/models/title/title_garden.glb und assets/models/source/title/title_garden.blend
    Runde Rasen-Insel mit weicher Erdkante (wie ein kleines Stück Garten aus dem Hof der Baumgasse), darauf dieselbe runde
    Holzbank wie in der Gasse (build_storybook_alleys.round_bench: Lattenring, Lehne, Hocker mit Tasse und Buch) und
    Trittsteine. Ursprung = Mitte der Bank am Boden (dort steht im Spiel der Baum tree_garden_big). Godot-Koordinaten:
    x rechts, y oben, z nach vorn (Blender: x, -z, y). Baum und Blumen setzt die Szene scenes/ui/title_backdrop.tscn.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_storybook_alleys as A  # noqa: E402  (Bank und Materialien der Gasse)
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
from storybook_lib import Body  # noqa: E402

OUT = os.path.join(SC.ROOT, "assets", "models", "title", "title_garden.glb")
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "title", "title_garden.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "title_garden.stamp")
## Radius der Rasen-Insel (m) und wie tief die Erdkante darunter reicht
ISLAND_R = 3.1
SOIL_DEPTH = 0.85


def island(M, coll):
    """Rasen obenauf (in der Mitte eben, zum Rand hin sanft gerundet), darunter eine weich gerundete Erdkante."""
    r = ISLAND_R
    lawn = Body("Insel Rasen", M["lawn"], coll, seed=401, vary=0.1, bevel=0.0)
    lawn.lathe([(0.0, -0.16), (r - 0.12, -0.16), (r + 0.02, -0.11), (r + 0.04, -0.06), (r - 0.05, -0.015), (r - 0.6, 0.0),
                (0.0, 0.0)], (0.0, 0.0, 0.0), segs=56, wave=0.035, waves=7, dent=0.012)
    lawn.build()
    # darunter weich gerundete Erde (wie ein ausgestochenes Stück Garten)
    soil = Body("Insel Erde", M["soil"], coll, seed=402, vary=0.12, bevel=0.0)
    soil.lathe([(0.0, -SOIL_DEPTH), (r * 0.4, -SOIL_DEPTH + 0.05), (r * 0.75, -SOIL_DEPTH * 0.7), (r - 0.2, -0.36),
                (r - 0.05, -0.21), (r - 0.02, -0.13), (0.0, -0.13)], (0.0, 0.0, 0.0), segs=56, wave=0.05, waves=9, dent=0.02)
    soil.build()


def stepping_stones(M, coll, rnd):
    """Trittsteine vom vorderen Rand der Insel zur Bank (Godot +z = vorn = Blender -y)."""
    st = Body("Trittsteine", M["slab"], coll, seed=404, vary=0.12, bevel=0.012)
    for k in range(4):
        t = k / 3.0
        px = 0.55 + 0.35 * math.sin(t * 2.2)
        py = -(1.25 + t * 1.45)
        r = rnd.uniform(0.19, 0.24)
        st.lathe([(0.0, -0.01), (r, -0.01), (r * 1.02, 0.012), (r * 0.94, 0.03), (0.0, 0.032)], (px, py, 0.0), segs=12,
                 dent=0.008)
    st.build()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if os.path.exists(STAMP) and SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("title_garden.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    A.mats(M)
    rnd = random.Random(7)
    root = SB.collection("Titelgarten")
    coll = SB.collection("Garten", root)
    C = {"deco": coll}
    island(M, coll)
    stepping_stones(M, coll, rnd)
    A.round_bench(M, C, 0.0, 0.0, rnd)
    objs = [o for o in coll.objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tris, n = SC.export_objects(objs, [], OUT, palette=True, extra=[])
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, OUT)
    print("Spiel: %s (%d Dreiecke, %d Netze), Offene Kanten: %s" % (OUT, tris, n, bad if bad else "keine"))
    if "--render" in argv:
        SC.setup_render(True)
        SC.render("titelgarten", (4.5, -6.5, 2.6), (0, 0, 0.3), 30, (1200, 800))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
