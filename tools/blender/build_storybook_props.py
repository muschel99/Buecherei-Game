"""Kleine Dinge auf der Straße im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_props.py [-- --render]
Ergebnis: assets/models/props/drain_grate.glb (Abflussdeckel am Bordstein, 0,5 x 0,34 m, Ursprung
Mitte unten, lange Seite entlang x), assets/models/props/street_bench.glb (Parkbank, seit Etappe 5c:
Holzlatten auf Gusseisen-Seitenteilen, 1,5 m lang, Sitz 0,45 m hoch; Ursprung am Boden unter der
Sitzmitte, Vorderseite nach +z, mit Kollision „…-colonly“) und
assets/models/source/props/storybook_props.blend.
Laternen: build_storybook_lamps.py.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

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


# Parkbank (Godot-Maße: x entlang, z nach vorn): Länge, Sitzhöhe, Sitztiefe
BENCH_LENGTH = 1.5
BENCH_SEAT = 0.25   # passend zu den Chibi-Figuren (seit Etappe 6c; ihre Sitz-Animation sitzt auf 0,22–0,27 m)
BENCH_DEPTH = 0.42


def street_bench(M, coll):
    """Parkbank: vier Sitzlatten und drei Lehnenlatten (leicht nach hinten geneigt) aus Holz auf zwei
    gusseisernen Seitenteilen mit geschwungener Armlehne. Blender: x entlang, -y vorn, z oben."""
    half = BENCH_LENGTH / 2
    wood = Body("Bank Latten", M["chair"], coll, seed=11, vary=0.08, bevel=0.008)
    # Sitz: Latten von vorn (-y) nach hinten, oben bündig mit BENCH_SEAT
    for k in range(4):
        y = -BENCH_DEPTH / 2 + 0.05 + k * 0.105
        wood.box((0.0, y, BENCH_SEAT - 0.018), (BENCH_LENGTH - 0.04, 0.088, 0.036), step=0.3, dent=0.002)
    # Lehne: drei Latten, oben weiter hinten (um x nach hinten gekippt)
    for k in range(3):
        z = BENCH_SEAT + 0.14 + k * 0.12
        y = BENCH_DEPTH / 2 - 0.02 + (z - BENCH_SEAT) * 0.27
        wood.box((0.0, y, z), (BENCH_LENGTH - 0.04, 0.03, 0.09), step=0.3, dent=0.002, turn=(-15, 0, 0))
    wood.build()
    iron = Body("Bank Eisen", M["lamp_iron"], coll, seed=12, vary=0.04, bevel=0.005)
    for sx in (-1, 1):
        x = sx * (half - 0.07)
        front, back = -BENCH_DEPTH / 2 + 0.02, BENCH_DEPTH / 2 - 0.02
        # vorderes Bein bis zur Armlehne, hinteres Bein bis über die Lehne (geschwungen)
        iron.tube([Vector((x, front - 0.03, 0.0)), Vector((x, front, 0.2)), Vector((x, front + 0.01, BENCH_SEAT)),
                   Vector((x, front - 0.01, BENCH_SEAT + 0.2))], 0.019, segs=8, smooth=2, round_ends=True)
        iron.tube([Vector((x, back + 0.06, 0.0)), Vector((x, back, 0.25)), Vector((x, back + 0.02, BENCH_SEAT)),
                   Vector((x, back + 0.11, BENCH_SEAT + 0.42))], 0.019, segs=8, smooth=2, round_ends=True)
        # Sitzträger und Armlehne (vorn eingerollt)
        iron.tube([Vector((x, front, BENCH_SEAT - 0.045)), Vector((x, back + 0.02, BENCH_SEAT - 0.045))], 0.016, segs=8,
                  round_ends=True)
        arm = [Vector((x, back + 0.06, BENCH_SEAT + 0.22)), Vector((x, 0.0, BENCH_SEAT + 0.235)),
               Vector((x, front - 0.02, BENCH_SEAT + 0.22)), Vector((x, front - 0.06, BENCH_SEAT + 0.18)),
               Vector((x, front - 0.04, BENCH_SEAT + 0.14)), Vector((x, front - 0.005, BENCH_SEAT + 0.16))]
        iron.tube(arm, 0.017, segs=8, smooth=2, round_ends=True)
        # kleine Füße
        for y in (front - 0.03, back + 0.06):
            iron.box((x, y, 0.012), (0.07, 0.06, 0.024), step=1, dent=0.001)
    iron.build()


def bench_collision(coll):
    """Kollision der Bank im Spiel: ein Kasten für Sitz und Lehne (Name „…-colonly“)."""
    b = Body("Bank-colonly", None, coll, vary=0)
    b.box((0.0, 0.02, (BENCH_SEAT + 0.45) / 2), (BENCH_LENGTH, BENCH_DEPTH + 0.12, BENCH_SEAT + 0.45), step=10, dent=0)
    obj = b.build()
    obj.display_type = "WIRE"
    obj.hide_render = True
    return obj


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
    # Parkbank
    coll = SB.collection("Parkbank", root)
    street_bench(M, coll)
    cols = [bench_collision(SB.collection("Kollision Parkbank", root))]
    objs = [o for o in coll.objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    path = os.path.join(OUT, "street_bench.glb")
    tris, n = SC.export_objects(objs, cols, path, palette=True, extra=[])
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, path)
    print("Spiel: %s (%d Dreiecke, %d Netze), offene Kanten: %s" % (path, tris, n, bad if bad else "keine"))
    if "--render" in argv:
        SC.render("parkbank", (1.6, -2.2, 1.3), (0, 0, BENCH_SEAT), 40, (1000, 750))
        SC.render("parkbank_seite", (2.2, 0.4, 0.8), (0, 0, BENCH_SEAT), 40, (1000, 750))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)


if __name__ == "__main__":
    main()
