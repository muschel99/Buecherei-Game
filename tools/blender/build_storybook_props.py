"""Kleine Dinge auf der Straße im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_props.py [-- --render]
Ergebnis: assets/models/props/drain_grate.glb (Abflussdeckel am Bordstein, 0,5 x 0,34 m, Ursprung
Mitte unten, lange Seite entlang x) und assets/models/source/props/storybook_props.blend.
Laternen: build_storybook_lamps.py.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
from storybook_lib import Body  # noqa: E402

BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "props", "storybook_props.blend")
OUT = os.path.join(SC.ROOT, "assets", "models", "props")


def drain_grate(M, coll):
    """Gusseiserner Einlauf: weich gerundeter Rahmen, runde Stäbe quer, dunkler Schacht darunter.
    Godot: x entlang, z quer (Blender y = -z), y oben."""
    w, d, h = 0.25, 0.17, 0.014
    fr = Body("Abfluss Rahmen", M["iron_grate"], coll, seed=1, vary=0.05, bevel=0.006)
    for c, s in (((0, -d + 0.02, h / 2), (2 * w, 0.04, h)), ((0, d - 0.02, h / 2), (2 * w, 0.04, h)),
                 ((-w + 0.02, 0, h / 2), (0.04, 2 * d - 0.08, h)), ((w - 0.02, 0, h / 2), (0.04, 2 * d - 0.08, h))):
        fr.box(c, s, step=1, dent=0.0015)
    n = 9
    for k in range(1, n):
        x = -w + 0.04 + (2 * w - 0.08) * k / n
        fr.tube([Vector((x, -d + 0.035, h * 0.55)), Vector((x, d - 0.035, h * 0.55))], 0.0085, segs=6, round_ends=True)
    fr.tube([Vector((-w + 0.035, 0.0, h * 0.45)), Vector((w - 0.035, 0.0, h * 0.45))], 0.009, segs=6, round_ends=True)
    fr.build()
    pit = Body("Abfluss Schacht", M["pit"], coll, seed=2, vary=0.0)
    pit.box((0, 0, 0.001), (2 * w - 0.07, 2 * d - 0.07, 0.002), step=1, dent=0.0)
    pit.build()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    M["iron_grate"] = SC.make_material("Gusseisen", (0.27, 0.25, 0.23), grain="smooth", rough=0.7, metal=0.3, vary=0.06)
    M["pit"] = SC.make_material("Schacht dunkel", (0.06, 0.05, 0.05), grain="smooth", rough=1.0, vary=0.0, bump=0.0)
    root = SB.collection("Kleinteile (Bilderbuch)")
    coll = SB.collection("Abflussdeckel", root)
    drain_grate(M, coll)
    objs = [o for o in coll.objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    path = os.path.join(OUT, "drain_grate.glb")
    tris, n = SC.export_objects(objs, [], path, palette=True)
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, path)
    print("Spiel: %s (%d Dreiecke, %d Netze), offene Kanten: %s" % (path, tris, n, bad if bad else "keine"))
    if "--render" in argv:
        SC.setup_render(True)
        SC.render("abfluss", (0.5, -0.6, 0.5), (0, 0, 0), 40, (800, 600))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)


if __name__ == "__main__":
    main()
