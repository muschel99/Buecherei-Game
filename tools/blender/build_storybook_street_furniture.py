"""Englische Straßenmöbel im Bilderbuch-Stil (seit „Modelle schöner“, Wunsch der Entwicklerin: das Spiel noch schöner machen,
vor allem die Modelle – mehr Charme einer englischen Einkaufsstraße): roter Säulen-Briefkasten, rote Telefonzelle,
Straßenuhr auf einem Mast und gusseiserner Papierkorb. Ohne Markenzeichen (keine Krone, kein Firmenname).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_street_furniture.py [-- namen] [--render]
    namen: pillar_box phone_box street_clock litter_bin (ohne Namen alle)
Ergebnis: assets/models/props/<name>.glb (Ursprung am Boden in der Mitte, Vorderseite +z in Godot = -y in Blender, mit
Kollision „…-colonly“) und assets/models/source/props/street_furniture.blend. Im Spiel: Szenen
scenes/world/street_furniture/<name>.tscn (Model + StreetObstacle), aufgestellt in main.tscn unter Outside/StreetFurniture.
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
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "props", "street_furniture.blend")
UP = Matrix.Rotation(math.radians(90), 4, "X")   # lokale xy-Ebene senkrecht, lokales +z zeigt nach vorn (-y)


def mats(M):
    M["post_red"] = SC.make_material("Lack Briefkastenrot", (0.72, 0.1, 0.08), grain="paint", rough=0.45, vary=0.05, bump=0.08)
    M["post_black"] = SC.make_material("Lack Schwarz Sockel", (0.09, 0.085, 0.08), grain="paint", rough=0.55, vary=0.04)
    M["cast_iron"] = SC.make_material("Gusseisen dunkelgrün", (0.1, 0.16, 0.12), grain="paint", rough=0.55, vary=0.05, bump=0.08)
    M["gilt"] = SC.make_material("Vergoldung", (0.86, 0.66, 0.3), grain="smooth", rough=0.35, metal=0.6, vary=0.05)
    M["dial"] = SC.make_material("Zifferblatt Creme", (0.95, 0.91, 0.8), grain="smooth", rough=0.6, vary=0.02, emit=0.15)
    M["ink"] = SC.make_material("Zeiger Schwarz", (0.06, 0.055, 0.05), grain="smooth", rough=0.5, vary=0.0)
    M["sign_white"] = SC.make_material("Schild Weiß", (0.94, 0.92, 0.86), grain="smooth", rough=0.6, vary=0.02, emit=0.25)
    M["slot_dark"] = SC.make_material("Schlitz dunkel", (0.03, 0.025, 0.02), grain="smooth", rough=1.0, vary=0.0, bump=0.0)
    M["bin_liner"] = SC.make_material("Papierkorb innen", (0.08, 0.075, 0.07), grain="smooth", rough=0.9, vary=0.0)


def collider(coll, name, center, size):
    b = Body(name + "-colonly", None, coll, vary=0)
    b.box(center, size, step=10, dent=0)
    obj = b.build()
    obj.display_type = "WIRE"
    obj.hide_render = True
    return obj


# --- Säulen-Briefkasten (rund, rot, schwarzer Sockel, Kuppeldach mit Kragen) ---

def pillar_box(M, coll, cols):
    r = 0.245
    body = Body("Briefkasten", M["post_red"], coll, seed=401, vary=0.04, bevel=0.0)
    # Säule mit leichtem Fuß, Kragen unter dem Dach, gewölbtes Dach mit kleinem Knauf
    body.lathe([(0.0, 0.12), (r + 0.02, 0.12), (r + 0.02, 0.16), (r, 0.18), (r, 1.18), (r + 0.035, 1.2), (r + 0.045, 1.25),
                (r + 0.035, 1.28), (r - 0.005, 1.3), (r * 0.9, 1.38), (r * 0.66, 1.45), (r * 0.36, 1.49), (0.05, 1.505),
                (0.045, 1.53), (0.0, 1.535)], (0, 0, 0), segs=40, dent=0.0015)
    # Band unter dem Kragen und Band über dem Sockel (Zierringe)
    body.lathe([(r - 0.004, 1.06), (r + 0.012, 1.065), (r + 0.012, 1.085), (r - 0.004, 1.09)], (0, 0, 0), segs=40)
    body.lathe([(r - 0.004, 0.25), (r + 0.01, 0.255), (r + 0.01, 0.27), (r - 0.004, 0.275)], (0, 0, 0), segs=40)
    # Einwurf-Lippe vorn (Schlitz darunter dunkel)
    lip = Matrix.Translation((0, -r + 0.004, 1.0))
    body.box((0, -r - 0.012, 1.004), (0.26, 0.036, 0.022), step=0.1, dent=0.0005)
    body.build()
    slot = Body("Briefkasten Schlitz", M["slot_dark"], coll, seed=402, vary=0.0)
    slot.box((0, -r + 0.002, 0.975), (0.23, 0.02, 0.024), step=0.1, dent=0.0)
    slot.build()
    # Tür vorn: leicht erhabene Platte mit Rahmen, Schild mit Leerungszeiten, Schlüsselloch
    door = Body("Briefkasten Tür", M["post_red"], coll, seed=403, vary=0.03, bevel=0.003)
    for k in range(9):
        a = math.radians(-34 + k * 8.5)
        door.box((math.sin(a) * (r + 0.004), -math.cos(a) * (r + 0.004), 0.6), (0.038, 0.012, 0.6), step=0.2, dent=0.0004,
                 turn=(0, 0, math.degrees(a)))
    door.build()
    plate = Body("Briefkasten Schild", M["sign_white"], coll, seed=404, vary=0.0, bevel=0.002)
    plate.box((0, -r - 0.012, 0.8), (0.17, 0.008, 0.1), step=0.1, dent=0.0)
    plate.build()
    letters = Body("Briefkasten Schrift", M["gilt"], coll, seed=405, vary=0.0)
    letters.text("LETTERS", 0.034, 0.004, Matrix.Translation((0, -r - 0.012, 1.12)) @ UP, font="DejaVuSerif-Bold.ttf",
                 spacing=1.3, resolution=3)
    letters.build()
    ink = Body("Briefkasten Schildschrift", M["ink"], coll, seed=406, vary=0.0)
    for k, zz in enumerate((0.83, 0.805, 0.78)):
        ink.box((0, -r - 0.017, zz), (0.12 - k * 0.02, 0.003, 0.006), step=0.2, dent=0.0)
    ink.box((0.03, -r - 0.004, 0.45), (0.016, 0.01, 0.03), step=0.1, dent=0.0)
    ink.build()
    base = Body("Briefkasten Sockel", M["post_black"], coll, seed=407, vary=0.03, bevel=0.0)
    base.lathe([(0.0, 0.0), (r + 0.04, 0.0), (r + 0.045, 0.03), (r + 0.03, 0.1), (r + 0.022, 0.125), (0.0, 0.125)], (0, 0, 0),
               segs=40, dent=0.001)
    base.build()
    cols.append(collider(SB.collection("Kollision Briefkasten", coll), "Briefkasten", (0, 0, 0.75), (0.56, 0.56, 1.5)))


# --- Telefonzelle (rot, Kuppeldach, Sprossenfenster, beleuchtetes Schild) ---

PB_W, PB_H = 0.92, 2.45


def phone_box(M, coll, cols):
    w = PB_W
    half = w / 2
    red = Body("Telefonzelle", M["post_red"], coll, seed=501, vary=0.03, bevel=0.006)
    # Sockel
    red.box((0, 0, 0.055), (w + 0.06, w + 0.06, 0.11), step=0.3, dent=0.001)
    # Eckpfosten
    for sx in (-1, 1):
        for sy in (-1, 1):
            red.box((sx * (half - 0.04), sy * (half - 0.04), 1.17), (0.08, 0.08, 2.12), step=0.3, dent=0.0008)
    # oben: Schildkasten-Ring, Gesims und Kuppeldach (aus Stufen)
    red.box((0, 0, 2.31), (w + 0.02, w + 0.02, 0.06), step=0.3, dent=0.0008)
    red.box((0, 0, 2.36), (w + 0.07, w + 0.07, 0.04), step=0.3, dent=0.0008)
    for k in range(5):
        s = w + 0.05 - k * 0.11
        red.box((0, 0, 2.395 + k * 0.026), (s, s, 0.03), step=0.3, dent=0.0006)
    red.lathe([(0.0, 2.5), (0.1, 2.5), (0.1, 2.53), (0.05, 2.56), (0.0, 2.565)], (0, 0, 0), segs=16)
    # vier Seiten: Rahmen mit Sprossen (je 3 x 6 Scheiben), unten ein geschlossenes Feld
    glass_y0, glass_y1 = 0.48, 2.05
    for face in range(4):
        rot = Matrix.Rotation(math.radians(90 * face), 4, "Z")
        f = rot @ Matrix.Translation((0, -half + 0.03, 0))
        red.box((0, 0, 0.29), (w - 0.14, 0.04, 0.36), step=0.3, dent=0.0006, matrix=f)        # Feld unten
        red.box((0, 0, glass_y0 - 0.025), (w - 0.14, 0.05, 0.05), step=0.3, dent=0.0006, matrix=f)
        red.box((0, 0, glass_y1 + 0.025), (w - 0.14, 0.05, 0.05), step=0.3, dent=0.0006, matrix=f)
        red.box((0, 0, 2.17), (w - 0.14, 0.05, 0.18), step=0.3, dent=0.0006, matrix=f)       # Feld für das Schild
        for k in range(1, 3):
            x = -half + 0.07 + (w - 0.14) * k / 3
            red.box((x, 0, (glass_y0 + glass_y1) / 2), (0.022, 0.035, glass_y1 - glass_y0), step=0.3, dent=0.0004, matrix=f)
        for k in range(1, 6):
            z = glass_y0 + (glass_y1 - glass_y0) * k / 6
            red.box((0, 0, z), (w - 0.14, 0.035, 0.022), step=0.3, dent=0.0004, matrix=f)
        if face == 0:
            # Türgriff vorn (die Vorderseite ist die Tür)
            red.box((half - 0.13, -0.03, 1.15), (0.02, 0.03, 0.16), step=0.1, dent=0.0004, matrix=f)
    red.build()
    glass = Body("Telefonzelle Glas", M["glass"], coll, seed=502, vary=0.0)
    for face in range(4):
        rot = Matrix.Rotation(math.radians(90 * face), 4, "Z")
        f = rot @ Matrix.Translation((0, -half + 0.03, 0))
        glass.box((0, 0, (glass_y0 + glass_y1) / 2), (w - 0.15, 0.008, glass_y1 - glass_y0 + 0.01), step=1, dent=0.0, matrix=f)
    glass.build()
    # innen: Boden, Rückwand mit Ablage und Telefon (dunkel) – damit hinter dem Glas etwas ist
    inside = Body("Telefonzelle innen", M["in_dark"], coll, seed=503, vary=0.05, bevel=0.003)
    inside.box((0, 0, 0.12), (w - 0.1, w - 0.1, 0.02), step=0.5, dent=0.0)
    inside.box((0, half - 0.08, 1.05), (0.5, 0.06, 0.04), step=0.3, dent=0.0)
    inside.build()
    phone = Body("Telefonzelle Telefon", M["post_black"], coll, seed=504, vary=0.03, bevel=0.006)
    phone.box((0, half - 0.11, 1.3), (0.24, 0.1, 0.3), step=0.2, dent=0.0005)
    phone.tube([(-0.09, half - 0.17, 1.48), (0.0, half - 0.19, 1.5), (0.09, half - 0.17, 1.48)], 0.025, segs=8, round_ends=True)
    phone.build()
    # Schild „TELEPHONE“ auf allen vier Seiten (leuchtet sanft) und eine Lampe im Dach
    sign = Body("Telefonzelle Schild", M["sign_white"], coll, seed=505, vary=0.0, bevel=0.002)
    letters = Body("Telefonzelle Schrift", M["ink"], coll, seed=506, vary=0.0)
    for face in range(4):
        rot = Matrix.Rotation(math.radians(90 * face), 4, "Z")
        sign.box((0, 0, 0), (w - 0.24, 0.012, 0.1), step=0.3, dent=0.0,
                 matrix=rot @ Matrix.Translation((0, -half + 0.0, 2.17)))
        letters.text("TELEPHONE", 0.052, 0.003, rot @ Matrix.Translation((0, -half - 0.0075, 2.15)) @ UP,
                     font="DejaVuSans-Bold.ttf", spacing=1.6, resolution=3)
    sign.build()
    letters.build()
    cols.append(collider(SB.collection("Kollision Telefonzelle", coll), "Telefonzelle", (0, 0, 1.25), (w + 0.06, w + 0.06, 2.5)))


# --- Straßenuhr (Mast mit zwei Zifferblättern, Laternenkopf-Form) ---

def street_clock(M, coll, cols):
    iron = Body("Straßenuhr", M["cast_iron"], coll, seed=601, vary=0.04, bevel=0.0)
    # Sockel und kannelierter Mast
    iron.lathe([(0.0, 0.0), (0.17, 0.0), (0.17, 0.05), (0.14, 0.09), (0.12, 0.2), (0.1, 0.26), (0.075, 0.3), (0.06, 0.36),
                (0.055, 2.4), (0.08, 2.44), (0.085, 2.48), (0.0, 2.48)], (0, 0, 0), segs=24, dent=0.0008)
    for k in range(8):
        a = 2 * math.pi * k / 8
        iron.tube([(math.cos(a) * 0.058, math.sin(a) * 0.058, 0.4), (math.cos(a) * 0.055, math.sin(a) * 0.055, 2.36)], 0.007,
                  segs=5, round_ends=True)
    # Uhrkopf: zwei runde Gehäuse (vorn und hinten), gewölbtes Dach, Spitze
    cy, r = 2.82, 0.27
    iron.lathe([(0.0, -0.07), (r + 0.03, -0.07), (r + 0.04, -0.05), (r + 0.04, 0.05), (r + 0.03, 0.07), (0.0, 0.07)],
               (0, 0, cy), segs=40, turn=(90, 0))
    iron.box((0, 0, 2.5), (0.12, 0.12, 0.06), step=0.2, dent=0.0005)
    iron.tube([(0, 0, 2.48), (0, 0, cy - r - 0.02)], 0.05, segs=12)
    iron.lathe([(0.0, cy + r + 0.02), (0.08, cy + r + 0.02), (0.06, cy + r + 0.08), (0.03, cy + r + 0.13), (0.035, cy + r + 0.15),
                (0.0, cy + r + 0.22)], (0, 0, 0), segs=16)
    # kleine Voluten unter dem Kopf
    for sx in (-1, 1):
        iron.tube([(sx * 0.05, 0, 2.5), (sx * 0.16, 0, 2.52), (sx * 0.2, 0, 2.6), (sx * 0.16, 0, 2.64), (sx * 0.12, 0, 2.6)], 0.012,
                  segs=6, smooth=2, round_ends=True)
    iron.build()
    gilt = Body("Straßenuhr Gold", M["gilt"], coll, seed=602, vary=0.03, bevel=0.0)
    dial = Body("Straßenuhr Zifferblatt", M["dial"], coll, seed=603, vary=0.0, bevel=0.0)
    ink = Body("Straßenuhr Zeiger", M["ink"], coll, seed=604, vary=0.0)
    for side in (-1, 1):
        y = side * 0.07
        # Zifferblatt: flache Scheibe vor dem Gehäuse (Achse y), darauf ein goldener Ring als Röhre
        dial.tube([(0, y - side * 0.004, cy), (0, y + side * 0.006, cy)], r - 0.02, segs=40)
        ring = [(math.sin(2 * math.pi * k / 40) * (r - 0.02), y + side * 0.008, cy + math.cos(2 * math.pi * k / 40) * (r - 0.02))
                for k in range(41)]
        gilt.tube(ring, 0.011, segs=6)
        face_y = y + side * 0.008
        for h in range(12):
            a = 2 * math.pi * h / 12
            big = h % 3 == 0
            ink.box((math.sin(a) * (r - 0.06), face_y, cy + math.cos(a) * (r - 0.06)), (0.012 if big else 0.007, 0.003, 0.04 if big else 0.024),
                    step=0.1, dent=0.0, turn=(0, math.degrees(a) * -side, 0))
        # Zeiger auf zehn nach zehn
        for ang, length, width in ((-60.0, 0.14, 0.014), (60.0, 0.2, 0.01)):
            a = math.radians(ang)
            ink.box((math.sin(a) * length / 2 * -side, face_y + side * 0.003, cy + math.cos(a) * length / 2),
                    (width, 0.003, length), step=0.1, dent=0.0, turn=(0, -ang * side, 0))
        gilt.tube([(0, face_y, cy), (0, face_y + side * 0.008, cy)], 0.014, segs=12)
    gilt.lathe([(0.088, 2.44), (0.095, 2.445), (0.095, 2.46), (0.088, 2.465)], (0, 0, 0), segs=24)
    gilt.build()
    dial.build()
    ink.build()
    cols.append(collider(SB.collection("Kollision Uhr", coll), "Uhr", (0, 0, 1.3), (0.34, 0.34, 2.6)))


# --- Papierkorb (Gusseisen, dunkelgrün, Goldband) ---

def litter_bin(M, coll, cols):
    r = 0.22
    iron = Body("Papierkorb", M["cast_iron"], coll, seed=701, vary=0.04, bevel=0.0)
    iron.lathe([(0.0, 0.0), (r - 0.02, 0.0), (r, 0.03), (r - 0.012, 0.08), (r - 0.012, 0.66), (r + 0.01, 0.68), (r + 0.015, 0.72),
                (r + 0.005, 0.75), (r * 0.7, 0.78), (r * 0.7, 0.84), (r + 0.005, 0.85), (r + 0.005, 0.875), (r * 0.75, 0.91),
                (r * 0.35, 0.935), (0.035, 0.94), (0.035, 0.97), (0.0, 0.975)], (0, 0, 0), segs=32, dent=0.001)
    # senkrechte Rippen
    for k in range(16):
        a = 2 * math.pi * k / 16
        iron.tube([(math.cos(a) * (r - 0.006), math.sin(a) * (r - 0.006), 0.1), (math.cos(a) * (r - 0.006), math.sin(a) * (r - 0.006), 0.64)],
                  0.008, segs=5, round_ends=True)
    iron.build()
    gap = Body("Papierkorb Öffnung", M["bin_liner"], coll, seed=702, vary=0.0)
    gap.lathe([(r * 0.7 - 0.004, 0.785), (r * 0.7 + 0.002, 0.785), (r * 0.7 + 0.002, 0.835), (r * 0.7 - 0.004, 0.835)], (0, 0, 0), segs=32)
    gap.build()
    gilt = Body("Papierkorb Band", M["gilt"], coll, seed=703, vary=0.02, bevel=0.0)
    gilt.lathe([(r - 0.008, 0.36), (r + 0.006, 0.365), (r + 0.006, 0.4), (r - 0.008, 0.405)], (0, 0, 0), segs=32)
    gilt.build()
    letters = Body("Papierkorb Schrift", M["gilt"], coll, seed=704, vary=0.0)
    letters.text("LITTER", 0.04, 0.004, Matrix.Translation((0, -r - 0.004, 0.5)) @ UP, font="DejaVuSerif-Bold.ttf", spacing=1.3,
                 resolution=3)
    letters.build()
    cols.append(collider(SB.collection("Kollision Papierkorb", coll), "Papierkorb", (0, 0, 0.47), (0.46, 0.46, 0.94)))


ITEMS = {"pillar_box": (pillar_box, (1.5, -2.0, 1.2), (0, 0, 0.75)),
         "phone_box": (phone_box, (2.6, -3.6, 2.0), (0, 0, 1.25)),
         "street_clock": (street_clock, (2.0, -3.4, 2.4), (0, 0, 1.8)),
         "litter_bin": (litter_bin, (1.0, -1.4, 0.9), (0, 0, 0.5))}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    wanted = [a for a in argv if not a.startswith("--")] or list(ITEMS)
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    mats(M)
    root = SB.collection("Straßenmöbel")
    if "--render" in argv:
        SC.setup_render(True)
    for name in wanted:
        build, cam, target = ITEMS[name]
        coll = SB.collection(name, root)
        cols = []
        build(M, coll, cols)
        objs = [o for o in coll.objects if o.type == "MESH" and not o.name.endswith("-colonly")]
        bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
        path = os.path.join(OUT, name + ".glb")
        tris, n = SC.export_objects(objs, cols, path, palette=True, extra=[])
        mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
        SC.write_import_settings(mapping, path)
        print("Spiel: %s (%d Dreiecke, %d Netze), Offene Kanten: %s" % (path, tris, n, bad if bad else "keine"))
        if "--render" in argv:
            for o in root.all_objects:
                o.hide_render = o.users_collection[0] is not coll or o.name.endswith("-colonly")
            SC.render("strasse_" + name, cam, target, 35, (900, 1100))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)


if __name__ == "__main__":
    main()
