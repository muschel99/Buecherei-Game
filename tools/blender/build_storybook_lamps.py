"""Laternen im Bilderbuch-Stil: Straßenlaterne (Mast) und hängende Laterne am Wandarm.

Beide tragen denselben Laternenkopf wie die Wandlaternen des Modegeschäfts
(storybook_parts.lantern_head, Vorbild: Straßenlaterne aus dem Beispielbild der Entwicklerin).
Jedes Teil ist ein geschlossener Körper mit weichen Kanten.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_lamps.py
    blender -b --factory-startup --python tools/blender/build_storybook_lamps.py -- --render

Ergebnis:
    assets/models/props/street_lamp.glb           Mast (Ursprung am Fuß, Straße setzt Kollision)
    assets/models/props/wall_street_lantern.glb   hängende Laterne (Ursprung: Wandplatte auf der
                                                  Wand, Laterne 0,72 m vor der Wand, Unterkante
                                                  0,62 m unter dem Befestigungspunkt)
    assets/models/source/props/storybook_lamps.blend   zum Weiterbauen (beide Laternen)
    screenshots/blender/storybook/lamp_*.png      Bilder (mit --render)
Maße wie bisher (street_houses.BRACKET_SPACE, Street.lamp_positions): Platz und Kollision passen.
"""

import bpy
import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import storybook_common as B  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_parts as SP  # noqa: E402
from storybook_lib import Body  # noqa: E402

PROPS_DIR = os.path.join(B.ROOT, "assets", "models", "props")
BLEND = os.path.join(B.ROOT, "assets", "models", "source", "props", "storybook_lamps.blend")
# Ebene einer Wand/Front: lokal y = oben, lokal z = zur Straße (Blender -y)
UPRIGHT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def hanging_basket(M, coll, name, center, radius, seed, palette=None):
    """Hängekorb (Weidengeflecht) an drei Ketten mit Erde; die Pflanzen setzt das Spiel auf den
    Pflanzplatz (Greenery: jede Laterne eine andere Ampel-Bepflanzung)."""
    rnd = random.Random(seed)
    c = Vector(center)
    b = Body(name + " Korb", M["box"], coll, seed=seed, vary=0.06, bevel=0.003)
    b.lathe([(0.0, -radius * 0.75), (radius * 0.45, -radius * 0.72), (radius * 0.85, -radius * 0.45), (radius, -0.02),
             (radius * 1.03, 0.0), (radius * 0.95, 0.01), (radius * 0.9, -0.03), (radius * 0.4, -radius * 0.62),
             (0.0, -radius * 0.64)], c, segs=24, dent=0.004)
    b.build()
    chain = Body(name + " Ketten", M["lamp_iron"], coll, seed=seed + 1)
    hook = c + Vector((0, 0, radius * 1.6))
    for k in range(3):
        a = 2 * math.pi * k / 3
        rim = c + Vector((math.cos(a) * radius * 0.95, math.sin(a) * radius * 0.95, 0.0))
        chain.tube([rim, hook], 0.004, segs=6, round_ends=True)
    chain.blob(hook, 0.012, subdiv=2, lump=0.0)
    chain.build()
    soil = Body(name + " Erde", M["soil"], coll, seed=seed + 2)
    soil.lathe([(0.0, -0.04), (radius * 0.88, -0.035), (radius * 0.86, -0.01), (0.0, 0.0)], c, segs=20, dent=0.004)
    soil.build()
    # Bepflanzung setzt das Spiel ein (Greenery, Art "basket"): Pflanzplatz knapp unter der Erde
    B.SPOTS["coll"] = coll
    B.plant_spot("basket", c + Vector((0, 0, -0.01)), (2 * radius * 0.88, 2 * radius * 0.88, 0.5), 0.0)


def street_lamp(M, coll):
    """Viktorianischer Laternenmast (Ursprung am Fuß, knapp 4 m): runder Sockel, kannelierter
    Schaft, Ringe, schlanker Oberschaft, Querarme mit Schnecken und zwei Hängekörben, oben
    der gemeinsame Laternenkopf."""
    rnd = random.Random(41)
    post = Body("Mast", M["lamp_iron"], coll, seed=40, vary=0.03, bevel=0.006)
    post.lathe([(0.0, 0.0), (0.2, 0.0), (0.205, 0.04), (0.19, 0.07), (0.17, 0.09), (0.165, 0.2), (0.15, 0.24), (0.125, 0.3),
                (0.12, 0.36), (0.13, 0.39), (0.0, 0.4)], (0, 0, 0), segs=28)
    # kannelierter Schaft (Rillen über wave), oben schmaler
    post.lathe([(0.0, 0.0), (0.088, 0.0), (0.084, 0.45), (0.075, 0.9), (0.0, 0.91)], (0, 0, 0.38), segs=36, wave=0.07, waves=12)
    post.lathe([(0.0, 0.0), (0.1, 0.0), (0.108, 0.03), (0.1, 0.07), (0.0, 0.075)], (0, 0, 1.27), segs=24)
    post.lathe([(0.0, 0.0), (0.06, 0.0), (0.052, 1.0), (0.046, 1.7), (0.0, 1.71)], (0, 0, 1.33), segs=20)
    post.lathe([(0.0, 0.0), (0.075, 0.0), (0.082, 0.03), (0.07, 0.07), (0.05, 0.11), (0.042, 0.2), (0.07, 0.24), (0.0, 0.25)],
               (0, 0, 3.0), segs=24)
    # Querarme mit Schnecken darunter und Kugeln an den Enden
    arm_z = 2.72
    for sx in (-1, 1):
        arm = [Vector((0, 0, arm_z)), Vector((sx * 0.2, 0, arm_z + 0.05)), Vector((sx * 0.42, 0, arm_z + 0.04)), Vector((sx * 0.55, 0, arm_z))]
        post.tube(arm, 0.017, segs=10, smooth=2, round_ends=True)
        pts = []
        for k in range(28):
            t = k / 27
            a = 1.2 + t * 2.6 * math.pi
            r = 0.09 * (1 - 0.7 * t)
            pts.append(Vector((sx * (0.16 + r * math.cos(a)), 0, arm_z - 0.06 + r * math.sin(a))))
        post.tube([Vector((0.0, 0, arm_z - 0.2))] + pts, lambda t: 0.01 * (1 - 0.4 * t), segs=8, smooth=1, round_ends=True)
        post.blob((sx * 0.57, 0, arm_z + 0.005), 0.026, subdiv=2, lump=0.0)
        post.tube([Vector((sx * 0.5, 0, arm_z)), Vector((sx * 0.5, 0, arm_z - 0.08))], 0.007, segs=6, round_ends=True)
        hanging_basket(M, coll, "Hängekorb %s" % ("links" if sx < 0 else "rechts"), (sx * 0.5, 0, arm_z - 0.42), 0.17, 50 + sx,
                       palette=(("red", "pink", "rose") if sx < 0 else ("pink", "red", "blush_flower")))
    post.build()
    SP.lantern_head(M, coll, "Straßenlaterne Kopf", (0, 0, 3.24), scale=1.0, seed=44)


def wall_lantern(M, coll):
    """Hängende Laterne am geschwungenen Wandarm (Ursprung: Mitte der Wandplatte auf der Wand,
    Laterne vor der Wand, also bei -y). Gemeinsames Bauteil: storybook_parts.street_wall_lantern
    (dieselbe Laterne bauen die Bilderbuch-Häuser selbst ein)."""
    SP.street_wall_lantern(M, coll, "Wandarm", "Hängende Laterne Kopf", (0.0, 0.0, 0.0), seed=60)


def render(name, cam, target, lens, res):
    B.render(name, cam, target, lens, res)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    B.GAME_MATERIALS.clear()
    M = B.materials()
    root = SB.collection("Laternen (Bilderbuch)")
    street = SB.collection("Straßenlaterne", root)
    wall = SB.collection("Hängende Laterne", root)
    street_lamp(M, street)
    wall_lantern(M, wall)
    bad = [(o.name, SB.non_manifold(o)) for c in (street, wall) for o in c.objects if o.type == "MESH" and SB.non_manifold(o)]
    print("Offene Kanten: %s" % (bad if bad else "keine – alles geschlossene Körper"))
    mapping = B.write_game_materials()
    for coll, file in ((street, "street_lamp.glb"), (wall, "wall_street_lantern.glb")):
        path = os.path.join(PROPS_DIR, file)
        tris, parts = B.export_objects([o for o in coll.objects if o.type == "MESH"], [], path,
                                       extra=[o for o in coll.objects if o.type == "EMPTY"])
        B.write_import_settings(mapping, path)
        print("Spiel: %s (%d Dreiecke, %d Netze)" % (path, tris, parts))
    if "--render" in argv:
        B.setup_render("--quick" in argv)
        wall_obj_offset = Vector((1.6, 0, 1.4))
        for o in wall.objects:
            o.location = wall_obj_offset
        render("lamp_strasse", (2.2, -3.2, 2.3), (0, 0, 2.6), 35, (900, 1200))
        render("lamp_kopf", (0.9, -1.2, 3.7), (0, 0, 3.55), 40, (900, 1000))
        render("lamp_wand", (2.6, -2.0, 1.4), (1.6, -0.5, 1.2), 40, (900, 1000))
        for o in wall.objects:
            o.location = (0, 0, 0)
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    print("Gespeichert:", BLEND)


main()
