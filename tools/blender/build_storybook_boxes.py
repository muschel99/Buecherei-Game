"""Lieferkartons im Bilderbuch-Stil (seit „Modelle schöner“; vorher einfache Kästen aus der Anfangszeit).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_boxes.py [-- --render]
Ergebnis: assets/models/props/delivery_box.glb (Möbel- und Oberflächen-Lieferungen: Pappkarton mit weichen, leicht
eingedrückten Kanten, Klebeband über die Klappen, Versandetikett mit Haus-und-Herz-Zeichen, „Oben“-Pfeile) und
assets/models/props/delivery_box_books.glb (Bücherpaket: Karton mit Paketschnur über Kreuz, Schleife und einem Anhänger mit
Buchzeichen). Maße wie die Szene scenes/objects/delivery_box.tscn: 0,5 x 0,36 x 0,42 m (Godot x, Höhe, z), Ursprung am Boden
in der Mitte, Vorderseite +z (Blender -y). Quelle: assets/models/source/props/delivery_boxes.blend.
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

OUT = os.path.join(SC.ROOT, "assets", "models", "props")
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "props", "delivery_boxes.blend")
W, H, D = 0.5, 0.36, 0.42      # Blender: x, z (Höhe), y (Tiefe)
TOP = H - 0.006                # Oberkante der Pappe (der Rest bis H: Band, Schnur, Schleife)
UP = Matrix.Rotation(math.radians(90), 4, "X")


def mats(M):
    M["cardboard"] = SC.make_material("Pappe", (0.72, 0.55, 0.37), grain="plaster", rough=0.95, vary=0.06, scale=6.0, bump=0.25)
    M["tape"] = SC.make_material("Klebeband Papier", (0.78, 0.62, 0.42), grain="paint", rough=0.7, vary=0.04, bump=0.1)
    M["label"] = SC.make_material("Etikett", (0.96, 0.93, 0.86), grain="paint", rough=0.85, vary=0.02)
    M["print"] = SC.make_material("Druck Braun", (0.33, 0.21, 0.14), grain="smooth", rough=0.8, vary=0.0)
    M["rose_print"] = SC.make_material("Druck Rosa", (0.86, 0.45, 0.5), grain="smooth", rough=0.8, vary=0.0)
    M["twine"] = SC.make_material("Paketschnur", (0.82, 0.7, 0.5), grain="fabric", rough=1.0, vary=0.05, bump=0.3)
    M["seam"] = SC.make_material("Fuge Karton", (0.36, 0.26, 0.17), grain="smooth", rough=1.0, vary=0.0)


def carton(M, coll, name):
    """Der Karton: weicher Kasten, oben zwei Klappen mit Fuge in der Mitte, Klebeband über die Fuge und die Kanten herunter."""
    box = Body(name, M["cardboard"], coll, seed=41, vary=0.04, bevel=0.012)
    box.box((0, 0, TOP / 2), (W, D, TOP), step=0.08, dent=0.0018, dent_scale=5.0)
    box.build()
    # Fuge der Klappen an den Seiten (unter dem Band liegt sie verdeckt)
    seam = Body(name + " Fuge", M["seam"], coll, seed=42, vary=0.0)
    for sy in (-1, 1):
        seam.box((0, sy * (D / 2 + 0.0015), TOP - 0.018), (W - 0.05, 0.003, 0.003), step=0.2, dent=0.0)
    seam.build()
    tape = Body(name + " Klebeband", M["tape"], coll, seed=43, vary=0.03, bevel=0.0015)
    # über die Fuge der Klappen (entlang x) und an den Seiten hinunter – 1 mm in der Pappe
    tape.box((0, 0, TOP + 0.001), (W + 0.006, 0.06, 0.004), step=0.1, dent=0.0004)
    for sx in (-1, 1):
        tape.box((sx * (W / 2 + 0.002), 0, TOP - 0.055), (0.004, 0.06, 0.11), step=0.1, dent=0.0003)
    tape.build()


def label(M, coll, name):
    """Versandetikett vorn rechts: Zeilen, Haus mit Herz (Nest & Nook), Strichcode."""
    lab = Body(name + " Etikett", M["label"], coll, seed=44, vary=0.0, bevel=0.0015)
    lm = Matrix.Translation((0.1, -D / 2 - 0.0012, 0.17)) @ Matrix.Rotation(math.radians(-2.0), 4, "Y")
    lab.box((0, 0, 0), (0.15, 0.004, 0.1), step=0.1, dent=0.0004, matrix=lm)
    lab.build()
    ink = Body(name + " Etikett Druck", M["print"], coll, seed=45, vary=0.0)
    for k in range(3):
        ink.box((0.025, -0.003, 0.02 - k * 0.016), (0.07 - k * 0.012, 0.002, 0.005), step=0.2, dent=0.0, matrix=lm)
    for k in range(9):
        ink.box((0.01 + k * 0.007, -0.003, -0.036), (0.003 if k % 3 else 0.005, 0.002, 0.018), step=0.2, dent=0.0, matrix=lm)
    # Häuschen: Dach und Wände als Umriss
    house = [(-0.055, -0.02), (-0.025, -0.02), (-0.025, 0.012), (-0.04, 0.03), (-0.055, 0.012)]
    ink.slab([(x, z) for x, z in house], 0.002, lm @ Matrix.Translation((0, -0.002, 0)) @ UP, dent=0.0)
    ink.build()
    heart = Body(name + " Etikett Herz", M["rose_print"], coll, seed=46, vary=0.0)
    pts = []
    for k in range(12):
        a = math.pi * k / 11
        pts.append((-0.044 + math.cos(math.pi - a) * 0.004, 0.0 + math.sin(math.pi - a) * 0.004))
    for k in range(12):
        a = math.pi * k / 11
        pts.append((-0.036 + math.cos(math.pi - a) * 0.004, 0.0 + math.sin(math.pi - a) * 0.004))
    pts.append((-0.04, -0.01))
    pts.reverse()
    heart.slab(pts, 0.002, lm @ Matrix.Translation((0, -0.0035, 0)) @ UP, dent=0.0)
    heart.build()


def arrows(M, coll, name):
    """„Oben“-Pfeile auf beiden Seiten (zwei kleine Pfeile nebeneinander)."""
    ink = Body(name + " Pfeile", M["print"], coll, seed=47, vary=0.0)
    for sx in (-1, 1):
        for dy in (-0.035, 0.035):
            m = Matrix.Translation((sx * (W / 2 + 0.002), dy, 0.22)) @ Matrix.Rotation(math.radians(90 * sx), 4, "Z") @ UP
            arrow = [(-0.008, -0.03), (0.008, -0.03), (0.008, 0.0), (0.018, 0.0), (0.0, 0.025), (-0.018, 0.0), (-0.008, 0.0)]
            ink.slab(arrow, 0.0015, m, dent=0.0)
    ink.build()


def twine(M, coll, name):
    """Paketschnur über Kreuz um den Karton (liegt eng an), oben eine Schleife, an der Seite ein Anhänger mit Buch."""
    t = Body(name + " Schnur", M["twine"], coll, seed=48, vary=0.03)
    r = 0.004
    e = 0.002  # so weit liegt die Mitte der Schnur außen auf der Pappe (halb eingesunken, straff gezogen)
    top = TOP + e
    for along in ("x", "y"):
        if along == "x":
            ring = [(-W / 2 - e, 0, 0.004), (W / 2 + e, 0, 0.004), (W / 2 + e, 0, top), (-W / 2 - e, 0, top), (-W / 2 - e, 0, 0.004)]
        else:
            ring = [(0, -D / 2 - e, 0.004), (0, D / 2 + e, 0.004), (0, D / 2 + e, top), (0, -D / 2 - e, top), (0, -D / 2 - e, 0.004)]
        t.tube(ring, r, segs=5)
    # Schleife: zwei Schlaufen und zwei Enden
    for sx in (-1, 1):
        loop = [(0, 0, top), (sx * 0.03, -0.02, top + 0.016), (sx * 0.06, 0.0, top + 0.018), (sx * 0.03, 0.02, top + 0.012), (0, 0, top)]
        t.tube(loop, r, segs=5, smooth=2)
        t.tube([(0, 0, top), (sx * 0.02, -0.05, top + 0.002), (sx * 0.035, -0.08, top)], r, segs=5, smooth=1, round_ends=True)
    t.build()
    knot = Body(name + " Knoten", M["twine"], coll, seed=49, vary=0.03)
    knot.blob((0, 0, top + 0.004), 0.011, subdiv=1, lump=0.1, scale=(1, 1, 0.7))
    knot.build()
    # Anhänger an der Schnur vorn: Pappschild mit Buchzeichen
    tag = Body(name + " Anhänger", M["label"], coll, seed=50, vary=0.0, bevel=0.0015)
    tm = Matrix.Translation((0.045, -D / 2 - 0.007, TOP - 0.07)) @ Matrix.Rotation(math.radians(12), 4, "Y")
    outline = [(-0.035, -0.025), (0.035, -0.025), (0.035, 0.015), (0.0, 0.03), (-0.035, 0.015)]
    tag.slab(outline, 0.003, tm @ UP, dent=0.0002)
    tag.build()
    ink = Body(name + " Anhänger Buch", M["rose_print"], coll, seed=51, vary=0.0)
    for sx in (-1, 1):
        page = [(sx * 0.002, -0.012), (sx * 0.02, -0.01), (sx * 0.02, 0.008), (sx * 0.002, 0.006)]
        if sx < 0:
            page.reverse()
        ink.slab(page, 0.0015, tm @ Matrix.Translation((0, -0.0028, 0)) @ UP, dent=0.0)
    ink.build()
    # kurzer Faden vom Anhänger zur Schnur
    t2 = Body(name + " Faden", M["twine"], coll, seed=52, vary=0.0)
    t2.tube([tm @ Vector((0.0, -0.002, 0.026)), Vector((0.012, -D / 2 - e - 0.002, TOP - 0.02)), Vector((0.0, -D / 2 - e, TOP - 0.004))],
            0.0018, segs=4, smooth=1)
    t2.build()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    mats(M)
    root = SB.collection("Lieferkartons")
    if "--render" in argv:
        SC.setup_render(True)
    for name, books in (("delivery_box", False), ("delivery_box_books", True)):
        coll = SB.collection(name, root)
        carton(M, coll, name)
        if books:
            twine(M, coll, name)
        else:
            label(M, coll, name)
            arrows(M, coll, name)
        objs = [o for o in coll.objects if o.type == "MESH"]
        bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
        path = os.path.join(OUT, name + ".glb")
        tris, n = SC.export_objects(objs, [], path, palette=True, extra=[])
        mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
        SC.write_import_settings(mapping, path)
        print("Spiel: %s (%d Dreiecke, %d Netze), Offene Kanten: %s" % (path, tris, n, bad if bad else "keine"))
        if "--render" in argv:
            for o in root.all_objects:
                o.hide_render = o.users_collection[0] is not coll
            SC.render("karton_" + name, (0.55, -0.8, 0.6), (0, 0, 0.17), 40, (900, 750))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)


if __name__ == "__main__":
    main()
