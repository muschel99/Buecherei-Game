"""Herbst-Deko im Bilderbuch-Stil (seit der großen Überarbeitung, Jahreszeit Herbst):
Kürbisse in vier Sorten (groß orange, klein orange, cremeweiß, dunkelgrün) – rund, mit weichen Rippen, oben eine
kleine Mulde mit gebogenem Stiel. Das Spiel stellt sie im Herbst in kleinen Gruppen vor Läden, an Treppen und neben
Töpfe (scripts/world/autumn_decor.gd).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_autumn.py [-- --render]
Ergebnis: assets/models/props/autumn/pumpkin_<sorte>.glb (Ursprung Mitte unten, Godot-Achsen), Quelle
assets/models/source/props/storybook_autumn.blend; mit --render Kontrollbilder nach screenshots/blender/.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
from storybook_lib import Body  # noqa: E402

BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "props", "storybook_autumn.blend")
OUT = os.path.join(SC.ROOT, "assets", "models", "props", "autumn")

# Sorte: Halbmesser, Höhe, Farbe (sRGB), Rippen, Stielfarbe
PUMPKINS = {
    "orange_big": (0.17, 0.27, (0.93, 0.5, 0.13), 10, (0.42, 0.36, 0.2)),
    "orange_small": (0.1, 0.155, (0.95, 0.57, 0.17), 8, (0.36, 0.38, 0.2)),
    "cream": (0.14, 0.185, (0.93, 0.88, 0.76), 10, (0.45, 0.42, 0.28)),
    "green": (0.115, 0.16, (0.36, 0.42, 0.27), 9, (0.4, 0.36, 0.22)),
}


def pumpkin(M, coll, name, radius, height, color, ribs, stem_color, seed):
    """Ein Kürbis: Drehkörper mit Rippen (Falten im Umfang), unten leicht abgeflacht, oben eine Mulde; Stiel als
    gebogene Röhre, die in der Mulde steckt. Blender: z oben."""
    rnd = random.Random(seed)
    skin = SC.make_material("Kürbis " + name, color, grain="smooth", rough=0.62, vary=0.08, bump=0.15)
    body = Body("Kürbis " + name, skin, coll, seed=seed, vary=0.06, bevel=0.0)
    # Profil: volle, rundliche Form (Superellipse), unten und oben eine kleine Mulde
    n = 16
    profile = [(0.0, height * 0.07)]
    for i in range(1, n):
        t = i / n
        u = 2.0 * t - 1.0
        r = radius * (1.0 - abs(u) ** 2.3) ** (1.0 / 2.3)
        profile.append((r, height * t))
    dip = height * 0.9
    profile += [(radius * 0.17, height * 0.985), (0.0, dip)]
    body.lathe(profile, Vector((0, 0, 0)), segs=ribs * 4, wave=0.1, waves=ribs, dent=radius * 0.03)
    body.build(smooth_angle=180)
    stem = Body("Stiel " + name, SC.make_material("Kürbisstiel " + name, stem_color, grain="wood", rough=0.85),
                coll, seed=seed + 1, vary=0.08, bevel=0.0)
    lean = rnd.uniform(0.0, 2 * math.pi)
    d = Vector((math.cos(lean), math.sin(lean), 0.0))
    length = max(0.035, height * 0.32)
    pts = [Vector((0, 0, dip - 0.01)), Vector((0, 0, dip + length * 0.45)) + d * length * 0.08,
           Vector((0, 0, dip + length * 0.85)) + d * length * 0.32]
    stem.tube(pts, max(0.008, radius * 0.1), segs=7, smooth=1, round_ends=True, dome=True)
    stem.build()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    root = SB.collection("Herbst (Bilderbuch)")
    os.makedirs(OUT, exist_ok=True)
    seed = 300
    for name, (radius, height, color, ribs, stem_color) in PUMPKINS.items():
        coll = SB.collection("Kürbis " + name, root)
        pumpkin(M, coll, name, radius, height, color, ribs, stem_color, seed)
        seed += 7
        objs = [o for o in coll.objects if o.type == "MESH"]
        bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
        path = os.path.join(OUT, "pumpkin_%s.glb" % name)
        tris, count = SC.export_objects(objs, [], path, palette=True)
        mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
        SC.write_import_settings(mapping, path)
        print("Spiel: %s (%d Dreiecke, %d Netze), offene Kanten: %s" % (path, tris, count, bad if bad else "keine"))
    if "--render" in argv:
        # alle nebeneinander
        x = 0.0
        for coll in root.children:
            for o in coll.objects:
                o.location.x += x
            x += 0.42
        SC.setup_render(True)
        SC.render("kuerbisse", (0.63, -2.0, 0.7), (0.63, 0, 0.1), 50, (1000, 600))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)


if __name__ == "__main__":
    main()
