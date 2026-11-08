"""Kleine Gegenstände der Anwohner und Gäste (seit Etappe 6i) im Bilderbuch-Stil:
  - watering_can  Gießkanne (Ursprung = Griff oben: dort hält sie die Hand; Tülle nach vorn +z)
  - broom         Reisigbesen (Ursprung = Unterkante der Borsten, Stiel nach oben +y)
  - mug           Bierkrug mit Schaum (Ursprung = Unterseite)
  - tea_cup       Teetasse auf Untertasse (Ursprung = Unterseite)
  - cake_plate    Teller mit Tortenstück und Kuchengabel (Ursprung = Unterseite des Tellers)

Jedes Teil ist ein geschlossener Körper. Koordinaten wie im Spiel: x quer, y oben, z vorn.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_chore_props.py [-- --render]
Ergebnis: assets/models/characters/props/<name>.glb, Quelle
assets/models/source/characters/props/storybook_chore_props.blend.
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

OUT = os.path.join(SC.ROOT, "assets", "models", "characters", "props")
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "characters", "props", "storybook_chore_props.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "storybook_chore_props.stamp")


def g(x, y, z):
    """Spiel (x, y oben, z vorn) -> Blender (x, -z, y)."""
    return Vector((x, -z, y))


def materials():
    mk = SC.make_material
    return {
        "zinc": mk("Zink Kanne", (0.5, 0.58, 0.55), grain="smooth", rough=0.5, vary=0.05),
        "zinc_dark": mk("Zink dunkel", (0.34, 0.41, 0.39), grain="smooth", rough=0.55, vary=0.05),
        "straw": mk("Reisig", (0.72, 0.56, 0.3), grain="wood", rough=0.9, vary=0.1),
        "wood": mk("Besenstiel", (0.58, 0.39, 0.22), grain="wood", rough=0.7, vary=0.06),
        "cord": mk("Bindfaden", (0.42, 0.28, 0.16), grain="fabric", rough=0.9, vary=0.05),
        "mug": mk("Krug Steingut", (0.7, 0.64, 0.5), grain="smooth", rough=0.5, vary=0.05),
        "beer": mk("Bier", (0.72, 0.45, 0.12), grain="smooth", rough=0.3, vary=0.04),
        "foam": mk("Schaum", (0.95, 0.92, 0.84), grain="smooth", rough=0.8, vary=0.03),
        "china": mk("Porzellan", (0.93, 0.9, 0.84), grain="smooth", rough=0.3, vary=0.02),
        "tea": mk("Tee", (0.5, 0.25, 0.08), grain="smooth", rough=0.25, vary=0.03),
        "cake": mk("Rührkuchen", (0.84, 0.64, 0.35), grain="fabric", rough=0.85, vary=0.05),
        "cream": mk("Sahne", (0.97, 0.93, 0.86), grain="smooth", rough=0.7, vary=0.03),
        "berry": mk("Erdbeere", (0.72, 0.13, 0.13), grain="smooth", rough=0.4, vary=0.08),
        "silver": mk("Silber", (0.72, 0.73, 0.72), grain="smooth", rough=0.35, vary=0.02),
    }


def watering_can(M, coll):
    # Bauch: unten breit, oben schmaler (hängt am Griff, Boden 27 cm tiefer)
    y0 = -0.31
    can = Body("Kanne", M["zinc"], coll, seed=1, vary=0.03, bevel=0.002)
    can.lathe([(0.0, 0.0), (0.082, 0.0), (0.09, 0.02), (0.085, 0.13), (0.06, 0.16), (0.05, 0.17), (0.0, 0.17)], g(0, y0, 0), segs=24)
    can.build()
    rim = Body("Kanne Ringe", M["zinc_dark"], coll, seed=2, vary=0.02, bevel=0.001)
    for h in (0.03, 0.11):
        rim.lathe([(0.0, h - 0.004), (0.092, h - 0.004), (0.094, h), (0.092, h + 0.004), (0.0, h + 0.004)], g(0, y0, 0), segs=24)
    rim.build()
    # Tülle nach vorn oben, Brause
    sp = Body("Tülle", M["zinc"], coll, seed=3, vary=0.02, bevel=0.0)
    sp.tube([g(0, y0 + 0.04, 0.07), g(0, y0 + 0.12, 0.17), g(0, y0 + 0.26, 0.28)], 0.017, segs=10, smooth=1, round_ends=True)
    rose = g(0, y0 + 0.28, 0.3)
    sp.lathe([(0.0, 0.0), (0.024, 0.0), (0.045, 0.045), (0.045, 0.05), (0.0, 0.05)], rose, segs=16, turn=(-55, 0))
    sp.build()
    # Griff: Bogen oben über dem Bauch (Ursprung = oberster Punkt), hinten ein zweiter
    hd = Body("Griff", M["zinc_dark"], coll, seed=4, vary=0.02)
    hd.tube([g(0, y0 + 0.15, -0.09), g(0, -0.06, -0.09), g(0, 0.0, 0.0), g(0, -0.06, 0.08), g(0, y0 + 0.15, 0.08)], 0.008, segs=8, smooth=2, round_ends=True)
    hd.build()


def broom(M, coll):
    stick = Body("Stiel", M["wood"], coll, seed=1, vary=0.05)
    stick.tube([g(0, 0.2, 0.0), g(0.002, 1.02, 0.0)], 0.012, segs=10, round_ends=True)
    stick.build()
    b = Body("Reisig", M["straw"], coll, seed=2, vary=0.12, bevel=0.0)
    rnd = b.rnd
    # dichtes Bündel: viele dünne Reiser von der Bindung nach unten gefächert
    for k in range(70):
        a = rnd.uniform(0, math.tau)
        r0 = 0.03 * math.sqrt(rnd.random())
        r1 = rnd.uniform(0.05, 0.13)
        top = g(math.cos(a) * r0, 0.26, math.sin(a) * r0 * 0.7)
        low = g(math.cos(a) * r1, rnd.uniform(0.0, 0.02), math.sin(a) * r1 * 0.7)
        mid = top.lerp(low, 0.55) + Vector((rnd.uniform(-0.01, 0.01), rnd.uniform(-0.01, 0.01), 0.0))
        b.tube([top, mid, low], 0.0035, segs=4, smooth=1, round_ends=True)
    b.build()
    c = Body("Bindung", M["cord"], coll, seed=3, vary=0.04)
    for h in (0.2, 0.24):
        c.lathe([(0.0, 0.0), (0.04, 0.0), (0.042, 0.012), (0.04, 0.024), (0.0, 0.024)], g(0, h, 0), segs=14)
    c.build()


def mug(M, coll):
    m = Body("Krug", M["mug"], coll, seed=1, vary=0.03, bevel=0.002)
    m.lathe([(0.0, 0.0), (0.042, 0.0), (0.046, 0.012), (0.045, 0.11), (0.042, 0.115), (0.0, 0.115)], g(0, 0, 0), segs=20)
    m.tube([g(0.044, 0.09, 0), g(0.075, 0.085, 0), g(0.078, 0.05, 0), g(0.044, 0.035, 0)], 0.007, segs=7, smooth=2, round_ends=True)
    m.build()
    f = Body("Schaum", M["foam"], coll, seed=2, vary=0.04)
    f.lathe([(0.0, 0.11), (0.043, 0.11), (0.046, 0.122), (0.03, 0.134), (0.0, 0.136)], g(0, 0, 0), segs=16, wave=0.003, waves=7)
    f.build()


def tea_cup(M, coll):
    s = Body("Untertasse", M["china"], coll, seed=1, vary=0.02, bevel=0.001)
    s.lathe([(0.0, 0.0), (0.04, 0.0), (0.075, 0.016), (0.078, 0.022), (0.0, 0.012)], g(0, 0, 0), segs=24)
    s.build()
    c = Body("Tasse", M["china"], coll, seed=2, vary=0.02, bevel=0.001)
    c.lathe([(0.0, 0.016), (0.028, 0.016), (0.042, 0.04), (0.046, 0.07), (0.044, 0.072), (0.0, 0.072)], g(0, 0, 0), segs=20)
    c.tube([g(0.044, 0.06, 0), g(0.066, 0.058, 0), g(0.066, 0.038, 0), g(0.04, 0.03, 0)], 0.005, segs=6, smooth=2, round_ends=True)
    c.build()
    t = Body("Tee", M["tea"], coll, seed=3, vary=0.02)
    t.lathe([(0.0, 0.0725), (0.04, 0.0725), (0.04, 0.074), (0.0, 0.074)], g(0, 0, 0), segs=16)
    t.build()


def cake_plate(M, coll):
    p = Body("Teller", M["china"], coll, seed=1, vary=0.02, bevel=0.001)
    p.lathe([(0.0, 0.0), (0.055, 0.0), (0.1, 0.012), (0.105, 0.02), (0.0, 0.01)], g(0, 0, 0), segs=28)
    p.build()
    # Tortenstück: Keil von oben, Höhe 5 cm
    k = Body("Kuchen", M["cake"], coll, seed=2, vary=0.04, bevel=0.003)
    outline = [(-0.02, 0.0), (0.06, -0.036), (0.06, 0.036)]
    from mathutils import Matrix
    k.slab(outline, 0.05, Matrix.Translation(g(0.0, 0.013, 0.0)) @ Matrix.Rotation(math.radians(0), 4, "Z"), dent=0.0)
    k.build()
    c = Body("Sahne", M["cream"], coll, seed=3, vary=0.03)
    c.blob(g(0.04, 0.066, 0.0), 0.019, subdiv=2, lump=0.2, scale=(1, 1, 0.8))
    c.build()
    b = Body("Erdbeere", M["berry"], coll, seed=4, vary=0.06)
    b.blob(g(0.041, 0.082, 0.0), 0.011, subdiv=2, lump=0.08, scale=(1, 1, 1.15))
    b.build()
    f = Body("Gabel", M["silver"], coll, seed=5, vary=0.02)
    f.tube([g(-0.08, 0.018, -0.05), g(-0.035, 0.018, -0.02)], 0.003, segs=6, round_ends=True)
    for k2 in (-0.008, 0.0, 0.008):
        f.tube([g(-0.032, 0.018, -0.02 + k2 * 0.6), g(-0.005, 0.018, -0.02 + k2)], 0.0013, segs=4, round_ends=True)
    f.build()


PROPS = {"watering_can": watering_can, "broom": broom, "mug": mug, "tea_cup": tea_cup, "cake_plate": cake_plate}


def export(name, coll):
    objs = [o for o in coll.all_objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    path = os.path.join(OUT, name + ".glb")
    os.makedirs(OUT, exist_ok=True)
    tris, n = SC.export_objects(objs, [], path, palette=True, extra=[])
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, path)
    print("Spiel: %s (%d Dreiecke, %d Netze), offene Kanten: %s" % (path, tris, n, bad if bad else "keine"))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("storybook_chore_props.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = materials()
    root = SB.collection("Gegenstände")
    colls = {}
    for name, fn in PROPS.items():
        colls[name] = SB.collection(name, root)
        fn(M, colls[name])
        export(name, colls[name])
    if "--render" in argv:
        x = 0.0
        for coll in colls.values():
            for o in coll.all_objects:
                o.location.x += x
            x += 0.42
        SC.setup_render(True)
        SC.render("gegenstaende", (0.85, -2.2, 0.6), (0.85, 0.0, 0.3), 45, (1200, 620))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
