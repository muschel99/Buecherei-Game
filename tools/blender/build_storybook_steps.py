"""Eingangstreppe der Bücherei im Bilderbuch-Stil (seit „Modelle schöner“, Wunsch der Entwicklerin: das Spiel noch schöner
machen, vor allem die Modelle). Vorher setzte Godot glatte, cremefarbene Blöcke zusammen (EntranceSteps); jetzt alte
Sandsteinstufen: jede Stufe aus einzelnen Steinen (vorn eine Reihe verschieden langer Blöcke, an den Seiten längs gelegte
Steine, oben auf dem Podest große Platten), Kanten weich abgerundet – in der Laufmitte stärker abgetreten –, schmale
Mörtelfugen dazwischen, jeder Stein mit eigenem Farbton, ein wenig Moos in den Ecken an der Hauswand.

Maße genau wie EntranceSteps (GameConfig: entrance_step_count 3, entrance_step_depth 0,28, entrance_side_step_depth 0,2,
entrance_podium_depth 0,7, shop_floor_rise 0,5; Breite der schrägen Wand 2,994 m) – die Deko auf den Stufen
(FacadeDesign deco_steps) und die Rampe (Kollision) passen weiter. Ändern sich diese Werte, hier anpassen.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_steps.py [-- --render] [--force]
Ergebnis: assets/models/facade/entrance_steps.glb (im Spiel Knoten „Model“ unter EntranceSteps) und
assets/models/source/props/entrance_steps.blend. Ursprung: außen auf der Hauswand in der Mitte der Tür, auf Höhe des
Ladenbodens; Godot +Z = von der Wand weg (Blender -y), +X entlang der Wand.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
from storybook_lib import Body  # noqa: E402

OUT = os.path.join(SC.ROOT, "assets", "models", "facade", "entrance_steps.glb")
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "props", "entrance_steps.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "entrance_steps.stamp")

# Maße (siehe oben, wie EntranceSteps in Godot)
COUNT = 3
TREAD = 0.28
SIDE = 0.2
RISE_TOTAL = 0.5
PODIUM = 0.7
WALL_WIDTH = 2.99411
HALF = max(0.3, WALL_WIDTH / 2.0 - COUNT * SIDE)
RISE = RISE_TOTAL / (COUNT + 1)
# Fugen: Breite zwischen den Steinen, so tief liegt der Mörtel unter der Trittfläche; Überstand der Stufenkante
JOINT = 0.007
MORTAR_DROP = 0.012
NOSING = 0.012
# Laufmitte: hier sind die Kanten stärker abgetreten (halbe Breite in m)
WORN_HALF = 0.55


def G(x, y, z):
    """Godot-Lage (x rechts, y oben, z nach draußen) → Blender (x, -z, y)."""
    return Vector((x, -z, y))


def stone(body, x0, x1, z0, z1, y0, y1, rnd):
    """Ein Stein von x0..x1 (entlang der Wand), z0..z1 (von der Wand weg), y0..y1 (Höhe) – leicht schief und verbeult."""
    cx, cz, cy = (x0 + x1) / 2, (z0 + z1) / 2, (y0 + y1) / 2
    lift = rnd.uniform(-0.003, 0.002)
    turn = (rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.35), rnd.uniform(-0.25, 0.25))
    body.box(G(cx, cy + lift, cz), (x1 - x0, z1 - z0, y1 - y0), step=0.12, turn=turn, dent=0.004, dent_scale=4.0)


def step_stones(bodies, k, rnd):
    """Stufe k (0 = unterste, COUNT = Podest): vorn eine Reihe Steine, an den Seiten längs gelegte, oben das Podest."""
    w = HALF + (COUNT - k) * SIDE
    d = PODIUM + (COUNT - k) * TREAD
    top = -RISE_TOTAL + (k + 1) * RISE
    bottom = top - RISE
    worn, edge = bodies
    if k == COUNT:
        # Podest: große Platten, zwei Reihen (hinten an der Wand, vorn mit Kante)
        rows = [(0.0, d * 0.48), (d * 0.48, d + NOSING)]
        for r, (z0, z1) in enumerate(rows):
            x = -w
            while x < w - 0.01:
                length = rnd.uniform(0.55, 0.8) if r == 1 else rnd.uniform(0.7, 1.0)
                x1 = min(w, x + length)
                if w - x1 < 0.3:
                    x1 = w
                body = worn if r == 1 and abs((x + x1) / 2) < WORN_HALF else edge
                stone(body, x + JOINT / 2, x1 - JOINT / 2, z0 + JOINT / 2, z1 - JOINT / 2, bottom, top, rnd)
                x = x1
        return
    w_next = HALF + (COUNT - k - 1) * SIDE
    d_next = PODIUM + (COUNT - k - 1) * TREAD
    # vorn: Blöcke über die ganze Breite, von etwas hinter der nächsten Stufe bis zur Kante (mit kleinem Überstand)
    z0 = d_next - 0.04
    x = -w
    while x < w - 0.01:
        x1 = min(w, x + rnd.uniform(0.45, 0.75))
        if w - x1 < 0.25:
            x1 = w
        body = worn if abs((x + x1) / 2) < WORN_HALF else edge
        stone(body, x + JOINT / 2, x1 - JOINT / 2, z0, d + NOSING, bottom, top, rnd)
        x = x1
    # Seiten: längs gelegte Steine von der Wand bis zur vorderen Reihe
    for sx in (-1, 1):
        xa, xb = sorted((sx * (w_next - 0.04), sx * (w + NOSING)))
        z = 0.0
        while z < z0 - 0.01:
            z1 = min(z0, z + rnd.uniform(0.35, 0.55))
            if z0 - z1 < 0.2:
                z1 = z0
            stone(edge, xa, xb, z + JOINT / 2, z1 - JOINT / 2, bottom, top, rnd)
            z = z1


def mortar(body, k):
    """Kern der Stufe unter den Steinen: Mörtel, der in den Fugen etwas tiefer sichtbar ist."""
    w = HALF + (COUNT - k) * SIDE
    d = PODIUM + (COUNT - k) * TREAD
    top = -RISE_TOTAL + (k + 1) * RISE
    bottom = top - RISE
    body.box(G(0.0, (bottom + top - MORTAR_DROP) / 2, (d - 0.012) / 2 + 0.002), (2 * w - 0.02, d - 0.016, RISE - MORTAR_DROP),
             step=0.3, dent=0.002)


def moss(body, rnd):
    """Moos-Polster: an der Hauswand neben dem Podest und in den inneren Ecken der Stufen an den Seiten."""
    spots = []
    for k in range(COUNT):
        w_next = HALF + (COUNT - k - 1) * SIDE
        top = -RISE_TOTAL + (k + 1) * RISE
        for sx in (-1, 1):
            if rnd.random() < 0.65:
                spots.append((sx * (w_next + 0.03), top, rnd.uniform(0.04, 0.2)))
    for x, y, z in spots:
        for n in range(rnd.randint(2, 4)):
            r = rnd.uniform(0.025, 0.045)
            body.blob(G(x + rnd.uniform(-0.04, 0.04), y + r * 0.25, z + rnd.uniform(-0.04, 0.04)), r, subdiv=2, lump=0.3,
                      scale=(1.3, 1.3, 0.45))


def doormat(mat_body, ink_body):
    """Kokos-Fußmatte vor der Tür (oben auf dem Podest, mittig, etwas schief): dunkler Rand, in der Mitte ein Herz."""
    top = 0.0
    w, d, t = 0.78, 0.46, 0.016
    turn = 2.5
    m = Matrix.Translation(G(0.04, top + t / 2 - 0.002, 0.34)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
    mat_body.box((0, 0, 0), (w, d, t), step=0.08, dent=0.0015, matrix=m)
    # Rand (2 mm höher, gleiche Unterkante – liegt auf der Matte)
    for (cx, cy, sx, sy) in ((0, d / 2 - 0.025, w - 0.01, 0.04), (0, -d / 2 + 0.025, w - 0.01, 0.04),
                             (w / 2 - 0.025, 0, 0.04, d - 0.09), (-w / 2 + 0.025, 0, 0.04, d - 0.09)):
        ink_body.box((cx, cy, 0.002), (sx, sy, t), step=0.08, dent=0.001, matrix=m)
    # Herz aus zwei Kreisbögen und einer Spitze
    pts = []
    for k in range(24):
        a = math.pi * k / 23
        pts.append((-0.032 + math.cos(math.pi - a) * 0.032, 0.012 + math.sin(math.pi - a) * 0.032))
    for k in range(24):
        a = math.pi * k / 23
        pts.append((0.032 + math.cos(math.pi - a) * 0.032, 0.012 + math.sin(math.pi - a) * 0.032))
    pts.append((0.0, -0.075))
    heart = [(x, y) for x, y in pts]
    # gegen den Uhrzeigersinn
    heart.reverse()
    ink_body.slab(heart, 0.004, m @ Matrix.Translation((0, 0, t / 2 - 0.001)), dent=0.0005)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if os.path.exists(STAMP) and SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("entrance_steps.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    # eigener Stein: wärmer und dunkler als der helle Fassaden-Sandstein, alt und abgetreten (Cycles zeigte sonst Seife)
    step_stone = SC.make_material("Sandstein Stufen", (0.66, 0.57, 0.46), grain="stone", rough=0.93, vary=0.12, bump=0.4)
    rnd = random.Random(23)
    root = SB.collection("Eingangstreppe")
    coll = SB.collection("Stufen", root)
    worn = Body("Stufen Laufmitte", step_stone, coll, seed=231, vary=0.16, bevel=0.014)
    edge = Body("Stufen", step_stone, coll, seed=232, vary=0.16, bevel=0.007)
    core = Body("Stufen Mörtel", M["curb"], coll, seed=233, vary=0.03, bevel=0.0)
    green = Body("Stufen Moos", M["box_leaf"], coll, seed=234, vary=0.12, bevel=0.0)
    coir = SC.make_material("Kokosmatte", (0.66, 0.48, 0.27), grain="fabric", rough=1.0, vary=0.08, bump=0.5)
    coir_dark = SC.make_material("Kokosmatte dunkel", (0.3, 0.19, 0.12), grain="fabric", rough=1.0, vary=0.06, bump=0.4)
    mat = Body("Fußmatte", coir, coll, seed=235, vary=0.05, bevel=0.004)
    mat_ink = Body("Fußmatte Rand", coir_dark, coll, seed=236, vary=0.04, bevel=0.002)
    doormat(mat, mat_ink)
    for k in range(COUNT + 1):
        step_stones((worn, edge), k, rnd)
        mortar(core, k)
    moss(green, rnd)
    for b in (worn, edge, core, green, mat, mat_ink):
        b.build()
    objs = [o for o in coll.objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tris, n = SC.export_objects(objs, [], OUT, palette=True, extra=[])
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, OUT)
    print("Spiel: %s (%d Dreiecke, %d Netze), Offene Kanten: %s" % (OUT, tris, n, bad if bad else "keine"))
    if "--render" in argv:
        SC.setup_render(True)
        SC.render("eingangstreppe", (2.6, -3.6, 1.0), (0, -0.6, -0.25), 35, (1200, 800))
        SC.render("eingangstreppe_nah", (0.9, -1.9, 0.55), (0.0, -0.4, -0.05), 35, (1200, 800))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
