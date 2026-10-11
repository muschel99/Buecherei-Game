"""Prüfbilder der Pflanzen (seit Etappe 4g, Teil 4f): baut alle Pflanzen aus style_plants.py
nebeneinander auf und rendert sie mit Cycles – zum Anschauen vor dem Einbau in die Häuser.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/plant_showcase.py
    blender -b --factory-startup --python tools/blender/plant_showcase.py -- ivy pots
Gruppen: ivy (Efeu an einer Wand mit Fenster), pots (Kübelpflanzen), box (Blumenkasten und
Hängekorb), garden (Baum, Strauch, Farn, Funkie, Gras), bouquets (Sträuße im Eimer).
Bilder: screenshots/blender/plants/<gruppe>-<blick>.png
"""

import bpy
import math
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
import style_parts as P  # noqa: E402
import style_plants as PL  # noqa: E402
from style_lib import Mat, V  # noqa: E402

OUT = os.path.join(S.ROOT, "screenshots", "blender", "plants")
PAVING = Mat("paving", color=(0.75, 0.72, 0.66))
BRICK = Mat("brick", color=(0.6, 0.33, 0.25))
STONE = Mat("stone_trim")
COLORS = {"wall": (0.6, 0.33, 0.25), "door": (0.12, 0.24, 0.18), "accent": (0.12, 0.24, 0.18)}


def ground(b, x0, x1, z0, z1):
    b.poly([V(x0, 0, z1), V(x1, 0, z1), V(x1, 0, z0), V(x0, 0, z0)], PAVING)


def pot(b, x, z, r_bottom, height, r_top):
    """Terrakotta-Topf mit Rand und Erde (wie in den Häusern)."""
    b.cylinder(V(x, 0, z), r_bottom, height, P.POT, segments=16, radius_top=r_top, caps=(False, False))
    b.cylinder(V(x, height, z), r_top + 0.015, 0.05, P.POT, segments=16, caps=(False, True))
    b.cylinder(V(x, height - 0.04, z), r_top - 0.012, 0.012, PL.SOIL, segments=16)
    return height + 0.05, height - 0.028


def group_ivy(b, rnd):
    ground(b, -2.5, 2.5, 0.0, 3.0)
    window = (-0.45, 1.0, 0.45, 2.4)
    b.wall_with_holes(-2.0, 2.0, 0.0, 3.6, 0.0, [window], BRICK, reveal=0.12, reveal_mat=STONE)
    b.box((-2.0, 0.0, -0.3), (2.0, 3.6, -0.001), BRICK, skip=("front",))
    b.box((window[0], window[1] - 0.06, -0.12), (window[2], window[1], 0.06), STONE)
    b.quad(V(window[0], window[1], -0.1), V(window[2], window[1], -0.1), V(window[2], window[3], -0.1), V(window[0], window[3], -0.1),
           Mat("plain", color=(0.2, 0.22, 0.25)))
    PL.ivy_wall(b, -1.0, 0.0, 3.3, rnd, x_min=-1.95, x_max=1.95, holes=[window], stems=3, spread=1.0)
    return [("front", (0.0, 1.6, 4.2), (0.0, 1.7, 0.0)), ("left", (-2.6, 1.4, 2.4), (-0.6, 1.4, 0.0)),
            ("near", (-0.7, 1.3, 0.9), (-1.0, 1.0, 0.0)), ("graze", (1.8, 1.0, 0.5), (-1.0, 1.5, 0.0))]


def group_pots(b, rnd):
    ground(b, -3.0, 3.0, -1.0, 2.0)
    views = []
    plants = [("box_ball", None), ("cone", None), ("standard", None), ("olive", None), ("lavender", None),
              ("geranium", "red"), ("hydrangea", "hydrangea"), ("fern", None), ("petunia", "lavender"), ("daisy", None)]
    for k, (kind, palette) in enumerate(plants):
        x = -2.6 + (k % 5) * 1.3
        z = 0.0 if k < 5 else 1.2
        r = 0.2 if kind in ("olive", "hydrangea", "standard") else 0.16
        rim, soil = pot(b, x, z, r * 0.8, 0.4 if kind != "olive" else 0.48, r)
        PL.potted(b, x, z, rim, r - 0.012, soil, kind, random.Random(k + 5), palette, outer_r=r + 0.015)
    views.append(("front", (0.0, 1.7, 6.2), (0.0, 0.6, 0.6)))
    views.append(("near_left", (-1.9, 1.0, 1.4), (-2.0, 0.6, 0.0)))
    views.append(("near_back", (-1.3, 1.0, 2.6), (-1.6, 0.5, 1.2)))
    views.append(("olive", (0.35, 1.3, 1.3), (0.3, 1.1, 0.0)))
    views.append(("near_right", (1.4, 1.0, 2.6), (1.3, 0.5, 1.2)))
    views.append(("top", (0.0, 3.5, 2.5), (0.0, 0.3, 0.5)))
    return views


def group_box(b, rnd):
    ground(b, -2.0, 2.0, 0.0, 2.5)
    b.box((-1.6, 0.0, -0.3), (1.6, 3.4, 0.0), BRICK, skip=("back",))
    sill = 1.0
    b.box((-0.7, sill - 0.06, 0.0), (0.7, sill, 0.08), STONE, skip=("back",))
    P.flower_box(b, -0.6, 0.6, sill + 0.005, 0.0, 0.2, Mat("paint", color=(0.12, 0.24, 0.18)), ["rose", "white", "coral"], seed=3)
    P.hanging_basket(b, 1.15, 2.6, 0.0, 0.5, seed=4)
    P.hanging_basket(b, -1.15, 2.6, 0.0, 0.5, seed=8)
    return [("front", (0.0, 1.5, 3.4), (0.0, 1.5, 0.0)), ("box_near", (-0.4, 1.4, 1.1), (0.0, 1.05, 0.1)),
            ("basket_near", (1.4, 1.8, 1.4), (1.15, 2.0, 0.5)), ("below", (0.2, 0.6, 1.0), (0.0, 1.1, 0.1))]


def group_garden(b, rnd):
    ground(b, -4.0, 4.0, -3.0, 4.0)
    PL.tree(b, V(0.0, 0.0, 0.0), 5.8, random.Random(2))
    PL.shrub(b, V(-2.5, 0.0, 2.0), 0.6, 1.1, random.Random(3), palette="hydrangea")
    PL.shrub(b, V(2.6, 0.0, 2.2), 0.5, 0.9, random.Random(4))
    PL.fern(b, V(-1.2, 0.0, 2.6), 0.6, random.Random(5))
    PL.hosta(b, V(1.2, 0.0, 2.8), 0.55, random.Random(6))
    for k in range(6):
        PL.grass(b, V(-0.5 + k * 0.25, 0.0, 3.2 + 0.1 * math.sin(k)), 0.25, random.Random(10 + k))
    return [("front", (0.0, 1.8, 9.0), (0.0, 2.4, 0.0)), ("near", (-0.8, 1.6, 4.5), (-0.5, 0.6, 2.0)),
            ("crown", (2.5, 1.6, 2.5), (0.0, 3.8, 0.0))]


def group_bouquets(b, rnd):
    ground(b, -2.0, 2.0, -0.5, 2.0)
    kinds = [("tulip", "rose"), ("rose", "red"), ("daisy", "white"), ("hydrangea", "hydrangea"), ("lavender", None), ("greens", None)]
    for k, (kind, palette) in enumerate(kinds):
        x = -1.5 + k * 0.6
        b.cylinder(V(x, 0, 0), 0.11, 0.32, P.ZINC, segments=12, radius_top=0.13, caps=(True, False))
        b.cylinder(V(x, 0.29, 0), 0.12, 0.012, Mat("plain", color=(0.25, 0.3, 0.32)), segments=12)
        PL.bouquet(b, V(x, 0.3, 0), 0.4, 0.12, random.Random(20 + k), kind, palette or "rose",
                   space=PL.PotSpace(x, 0, 0.12, 0.32, 0.3, outer=0.135))
    return [("front", (0.0, 1.2, 2.4), (0.0, 0.55, 0.0)), ("near", (-0.9, 0.95, 0.9), (-1.0, 0.65, 0.0)),
            ("near2", (0.9, 0.95, 0.9), (0.9, 0.65, 0.0))]


GROUPS = {"ivy": group_ivy, "pots": group_pots, "box": group_box, "garden": group_garden, "bouquets": group_bouquets}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in argv if not a.startswith("--")] or list(GROUPS)
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        started = time.time()
        bpy.ops.wm.read_factory_settings(use_empty=True)
        b = S.Builder("showcase_" + name)
        views = GROUPS[name](b, random.Random(1))
        tris = sum(len(f["pts"]) - 2 for f in b.faces)
        S.to_blender(b, COLORS)
        S.setup_render(resolution=(1000, 700), samples=16)
        bpy.context.scene.cycles.transparent_max_bounces = 64
        bpy.context.scene.cycles.max_bounces = 6
        print("%s: %d Dreiecke, gebaut in %.1f s" % (name, tris, time.time() - started))
        for view, cam, target in views:
            S.render_view(os.path.join(OUT, "%s-%s.png" % (name, view)), cam, target, lens=30)
        print("%s: fertig nach %.1f s" % (name, time.time() - started))


if __name__ == "__main__":
    main()
