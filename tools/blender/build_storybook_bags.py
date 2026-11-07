"""Einkaufstaschen der Passanten im Bilderbuch-Stil (seit Etappe 6h, Teil 8).

Passanten mit der Gangart „Gehen mit Einkaufstasche“ (Animationen walk_bag, idle_bag, watch_bag) tragen
eine Tasche in der rechten Hand. Zwei Arten:
  - shopping_bag_paper: Papiertüte (Packpapier, gedrehte Papierkordeln), oben schauen ein Baguette,
    ein Apfel und Lauchgrün heraus
  - shopping_bag_tote: Stoffbeutel (Leinen mit grünem Streifen, flache Henkel), darin Blumen und ein Buch

Jedes Teil ist ein geschlossener Körper; die Tüte ist hohl (Wände, Boden, umgeschlagener Rand), innen
eine Füllung, auf der der Inhalt steht. Ursprung = Griffpunkt (dort hält die Hand die Henkel), die Tasche
hängt darunter. Koordinaten wie im Spiel: x quer (schmale Seite), y oben, z entlang (breite Seite in
Gehrichtung). ChibiPasserbyModel hängt die Tasche an die rechte Hand und lässt sie senkrecht pendeln.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_bags.py [-- --render]

Ergebnis: assets/models/characters/props/<name>.glb, Quelle
assets/models/source/characters/props/storybook_bags.blend.
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
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "characters", "props", "storybook_bags.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "storybook_bags.stamp")

# Maße der Tasche (m): quer, hoch, entlang; Abstand Griffpunkt – Oberkante; Wandstärke
DEPTH = 0.085
HEIGHT = 0.19
WIDTH = 0.17
HANG = 0.075
WALL = 0.004


def g(x, y, z):
    """Spiel (x, y oben, z vorn) -> Blender (x, -z, y)."""
    return Vector((x, -z, y))


def gsize(x, y, z):
    return (x, z, y)


def materials():
    mk = SC.make_material
    return {
        "paper": mk("Packpapier", (0.71, 0.53, 0.34), grain="fabric", rough=0.95, vary=0.06),
        "paper_in": mk("Packpapier innen", (0.42, 0.3, 0.19), grain="fabric", rough=0.98, vary=0.05),
        "cord": mk("Papierkordel", (0.62, 0.45, 0.28), grain="fabric", rough=0.95, vary=0.04),
        "bread": mk("Brotkruste", (0.8, 0.52, 0.25), grain="fabric", rough=0.8, vary=0.08),
        "apple": mk("Apfel rot", (0.72, 0.17, 0.12), grain="smooth", rough=0.45, vary=0.08),
        "stem": mk("Stiel braun", (0.33, 0.22, 0.12), grain="wood", rough=0.9, vary=0.05),
        "leek": mk("Blatt Lauch", (0.36, 0.52, 0.22), grain="leaf", rough=0.7, vary=0.1, plant=True),
        "linen": mk("Stoffbeutel Leinen", (0.87, 0.81, 0.68), grain="fabric", rough=0.95, vary=0.04),
        "linen_in": mk("Stoffbeutel innen", (0.5, 0.45, 0.36), grain="fabric", rough=0.98, vary=0.04),
        "band": mk("Stoffbeutel Streifen", (0.33, 0.47, 0.37), grain="fabric", rough=0.95, vary=0.04),
        "book": mk("Buch Leinen rot", (0.62, 0.2, 0.17), grain="fabric", rough=0.85, vary=0.05),
        "pages": mk("Buch Seiten", (0.93, 0.89, 0.78), grain="paint", rough=0.9, vary=0.03),
        "leaf": mk("Blatt Geranie", (0.28, 0.44, 0.17), grain="leaf", rough=0.75, vary=0.1, plant=True),
        "pink": mk("Blüte Rosa", (0.93, 0.46, 0.6), grain="fabric", rough=0.7, vary=0.12, plant=True),
        "cream": mk("Blüte Creme", (0.96, 0.93, 0.85), grain="fabric", rough=0.7, vary=0.05, plant=True),
        "stalk": mk("Stiel grün", (0.3, 0.42, 0.18), grain="smooth", rough=0.8, vary=0.06),
    }


def shell(M, coll, wall, inside, rim, seed):
    """Hohle Tasche: vier Wände, Boden, umgeschlagener Rand oben, Füllung innen (2,5 cm unter dem Rand)."""
    top = -HANG
    mid = top - HEIGHT / 2
    b = Body("Wände", M[wall], coll, seed=seed, vary=0.03, bevel=0.0015)
    for sx in (-1, 1):  # breite Wände (quer zu x)
        b.box(g(sx * (DEPTH / 2 - WALL / 2), mid, 0), gsize(WALL, HEIGHT, WIDTH), step=0.05, dent=0.0012, dent_scale=14.0)
    for sz in (-1, 1):  # schmale Seiten, mit leichtem Falz nach innen
        b.box(g(0, mid, sz * (WIDTH / 2 - WALL / 2)), gsize(DEPTH - WALL, HEIGHT, WALL), step=0.05, dent=0.0012, dent_scale=14.0)
    b.box(g(0, top - HEIGHT + WALL / 2, 0), gsize(DEPTH - WALL, WALL, WIDTH - WALL), step=0.05, dent=0.0)
    b.build()
    r = Body("Rand", M[rim], coll, seed=seed + 1, vary=0.02, bevel=0.0015)
    band = 0.016
    for sx in (-1, 1):
        r.box(g(sx * (DEPTH / 2 + 0.0012), top - band / 2, 0), gsize(WALL + 0.0024, band, WIDTH + 0.0048), step=0.05, dent=0.0)
    for sz in (-1, 1):
        r.box(g(0, top - band / 2, sz * (WIDTH / 2 + 0.0012)), gsize(DEPTH, band, WALL + 0.0024), step=0.05, dent=0.0)
    r.build()
    f = Body("Füllung", M[inside], coll, seed=seed + 2, vary=0.02)
    f.box(g(0, top - 0.025 - 0.05, 0), gsize(DEPTH - 2 * WALL + 0.002, 0.1, WIDTH - 2 * WALL + 0.002), step=0.05, dent=0.002)
    f.build()


def cord_handles(M, coll):
    """Gedrehte Papierkordeln: je breite Wand eine Schlaufe, beide treffen sich im Griffpunkt."""
    h = Body("Henkel", M["cord"], coll, seed=5, vary=0.02)
    top = -HANG
    for sx in (-1, 1):
        x0 = sx * (DEPTH / 2 - WALL / 2)
        pts = [g(x0, top - 0.022, -0.042), g(x0 * 0.92, top + 0.004, -0.04), g(sx * 0.02, top * 0.45, -0.024),
               g(sx * 0.006, -0.004, -0.008), g(sx * 0.006, -0.004, 0.008), g(sx * 0.02, top * 0.45, 0.024),
               g(x0 * 0.92, top + 0.004, 0.04), g(x0, top - 0.022, 0.042)]
        h.tube(pts, 0.0034, segs=6, smooth=2, round_ends=True)
        # Knoten innen (die Kordel ist durch die Wand gefädelt)
        for sz in (-1, 1):
            h.blob(g(x0 - sx * 0.006, top - 0.022, sz * 0.042), 0.006, subdiv=1, lump=0.1)
    h.build()


def strap_handles(M, coll):
    """Flache Stoffhenkel, außen an den breiten Wänden angenäht."""
    h = Body("Henkel", M["linen"], coll, seed=6, vary=0.02, bevel=0.001)
    top = -HANG
    for sx in (-1, 1):
        x0 = sx * (DEPTH / 2 + 0.0025)
        for sz in (-1, 1):
            # angenähtes Stück an der Wand, dann hoch zum Griff
            h.span(g(x0, top - 0.035, sz * 0.04), g(x0, top + 0.002, sz * 0.04), 0.004, 0.018, step=0.02, dent=0.0)
        pts = [g(x0, top - 0.004, -0.04), g(x0 * 0.85, top + 0.012, -0.036), g(sx * 0.016, top * 0.4, -0.02),
               g(sx * 0.005, -0.003, -0.007), g(sx * 0.005, -0.003, 0.007), g(sx * 0.016, top * 0.4, 0.02),
               g(x0 * 0.85, top + 0.012, 0.036), g(x0, top - 0.004, 0.04)]
        h.tube(pts, 0.0035, segs=6, smooth=2, round_ends=True)
    h.build()


def paper_bag(M, coll):
    shell(M, coll, "paper", "paper_in", "paper", seed=11)
    cord_handles(M, coll)
    top = -HANG
    # Baguette am einen Ende, schräg nach außen (weg von Hand und Henkeln)
    br = Body("Baguette", M["bread"], coll, seed=21, vary=0.04)
    br.tube([g(0.006, top - 0.11, 0.05), g(0.004, top + 0.0, 0.062), g(0.0, top + 0.075, 0.085)], 0.016, segs=10, smooth=2,
            round_ends=True)
    for k in range(3):  # Einschnitte als flache Wülste
        t = 0.3 + k * 0.22
        c = g(-0.002, top - 0.01 + t * 0.085, 0.064 + t * 0.022)
        br.blob(c + Vector((-0.012, 0, 0)), 0.006, subdiv=1, lump=0.05, scale=(0.5, 1.6, 0.9))
    br.build()
    # Apfel obenauf
    ap = Body("Apfel", M["apple"], coll, seed=22, vary=0.06)
    ap.blob(g(0.018, top - 0.008, -0.012), 0.021, subdiv=2, lump=0.06, scale=(1.0, 1.0, 0.92))
    ap.build()
    st = Body("Apfelstiel", M["stem"], coll, seed=23, vary=0.03)
    st.tube([g(0.018, top + 0.008, -0.012), g(0.021, top + 0.022, -0.01)], 0.0018, segs=5, round_ends=True)
    st.build()
    # Lauchgrün am anderen Ende, fächert nach außen
    lk = Body("Lauch", M["leek"], coll, seed=24, vary=0.1)
    base = g(-0.014, top - 0.03, -0.05)
    for k, (dx, dz, ln) in enumerate([(-0.25, -0.35, 0.11), (0.2, -0.45, 0.12), (0.0, -0.2, 0.13), (-0.4, -0.55, 0.095)]):
        d = Vector((dx, -dz, 1.0)).normalized()  # Blender-Richtung (x, -z, y)
        lk.leaf(base + Vector((k * 0.004 - 0.006, 0, 0)), d, Vector((1, 0.3 * (k - 1.5), 0)), ln, 0.022, shape="narrow",
                thick=0.003, curl=0.25)
    lk.build()


def tote_bag(M, coll):
    shell(M, coll, "linen", "linen_in", "linen", seed=31)
    strap_handles(M, coll)
    top = -HANG
    # grüner Streifen rundherum
    bd = Body("Streifen", M["band"], coll, seed=32, vary=0.02)
    y = top - HEIGHT * 0.55
    for sx in (-1, 1):
        bd.box(g(sx * (DEPTH / 2 + 0.0008), y, 0), gsize(0.0022, 0.022, WIDTH + 0.0016), step=0.05, dent=0.0)
    for sz in (-1, 1):
        bd.box(g(0, y, sz * (WIDTH / 2 + 0.0008)), gsize(DEPTH + 0.0016, 0.022, 0.0022), step=0.05, dent=0.0)
    bd.build()
    # Buch, schräg an der einen Seite
    bk = Body("Buch", M["book"], coll, seed=33, vary=0.03, bevel=0.0012)
    bk.box(g(-0.012, top - 0.045, 0.036), gsize(0.022, 0.12, 0.08), step=0.05, dent=0.0)
    bk.build()
    pg = Body("Seiten", M["pages"], coll, seed=34, vary=0.02)
    pg.box(g(-0.012, top - 0.043, 0.036), gsize(0.018, 0.114, 0.0815), step=0.05, dent=0.0)
    pg.build()
    # kleiner Strauß am anderen Ende
    stalks = Body("Stiele", M["stalk"], coll, seed=35, vary=0.05)
    leaves = Body("Blätter", M["leaf"], coll, seed=36, vary=0.1)
    pink = Body("Blüten rosa", M["pink"], coll, seed=37, vary=0.1)
    cream = Body("Blüten creme", M["cream"], coll, seed=38, vary=0.06)
    rnd = pink.rnd
    heads = [(0.012, -0.052, 0.07), (-0.014, -0.06, 0.08), (0.004, -0.075, 0.062), (-0.006, -0.04, 0.09), (0.018, -0.068, 0.085)]
    for k, (hx, hz, hy) in enumerate(heads):
        tip = g(hx, top + hy - 0.02, hz)
        stalks.tube([g(hx * 0.4, top - 0.07, -0.05), tip], 0.002, segs=5, round_ends=True)
        (pink if k % 2 == 0 else cream).star(tip + Vector((0, 0, 0.004)), Vector((hx * 3, -hz * 2 - 0.1, 1.0)), 0.016, 5, rnd,
                                            thick=0.004)
    for k in range(4):
        a = k * 1.7
        d = Vector((math.cos(a) * 0.7, math.sin(a) * 0.7 + 0.4, 0.8)).normalized()
        leaves.leaf(g(0.0, top - 0.01, -0.052), d, Vector((0, 0, 1)), 0.045, 0.02, shape="oval", thick=0.003, curl=0.2)
    for b in (stalks, leaves, pink, cream):
        b.build()


BAGS = {"shopping_bag_paper": paper_bag, "shopping_bag_tote": tote_bag}


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
        print("storybook_bags.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = materials()
    root = SB.collection("Einkaufstaschen")
    colls = {}
    for i, (name, fn) in enumerate(BAGS.items()):
        colls[name] = SB.collection(name, root)
        fn(M, colls[name])
        export(name, colls[name])
    if "--render" in argv:
        # beide nebeneinander (die Tüten liegen sonst am selben Platz)
        for o in colls["shopping_bag_tote"].all_objects:
            o.location.x += 0.22
        SC.setup_render(True)
        SC.render("taschen_schraeg", (0.55, -0.55, 0.05), (0.11, 0.0, -0.15), 50, (900, 650))
        SC.render("taschen_seite", (0.11, -0.7, -0.12), (0.11, 0.0, -0.15), 50, (900, 650))
        SC.render("taschen_oben", (0.3, -0.35, 0.35), (0.11, 0.0, -0.12), 50, (900, 650))
        for o in colls["shopping_bag_tote"].all_objects:
            o.location.x -= 0.22
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
