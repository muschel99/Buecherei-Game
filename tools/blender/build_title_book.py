"""Großes aufgeschlagenes Buch fürs Hauptmenü (Wunsch der Entwicklerin nach der Testrunde von Etappe 8d: „im Hintergrund ein
großes aufgeschlagenes Buch, der Baum wie eine Abbildung in diesem Buch, der Notizzettel mit dem Menü liegt im Buch“).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_title_book.py [-- --render] [--force]
Ergebnis: assets/models/title/title_book.glb und assets/models/source/title/title_book.blend
    Ledereinband (zwei Deckel mit Messingecken, runder Rücken darunter), zwei Seitenblöcke, deren Seiten zur Mitte hin in den
    Falz abtauchen, und obenauf je ein dünnes Seitenblatt mit eigenem Material und UV (Godot legt darauf Papier bzw. das
    lebendige Bild: „Seite links“, „Seite rechts“ – u von links nach rechts über die Seite, v von oben nach unten).
    Lesebändchen auf der linken Seite, fällt unten heraus (im Hauptmenü steht das Buch aufrecht – es hängt nach Blender -y).
    Ursprung = Mitte des Falzes auf der Oberkante der Deckel.
    Godot-Koordinaten: x rechts, y oben, z nach vorn (Blender: x, -z, y) – das Buch liegt flach, oben = Blender +y = Godot -z.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
from storybook_lib import Body  # noqa: E402

OUT = os.path.join(SC.ROOT, "assets", "models", "title", "title_book.glb")
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "title", "title_book.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "title_book.stamp")

## Maße (m): Seitenbreite und -höhe, Dicke eines Seitenblocks, Deckel (Dicke, Überstand), Rücken (Radius)
W = 1.0
H = 1.4
T = 0.1
BOARD = 0.022
OVER = 0.035
SPINE_R = 0.07
## Lücke zwischen den beiden Blöcken im Falz und Abstand Seitenblatt – Block (gegen Z-Fighting)
GUTTER = 0.002
SHEET = 0.0015
## Messingecken: Schenkellänge (bleibt im freien Rand vor dem Seitenblock)
CORNER = 0.045


def top(u):
    """Höhe der Seitenoberfläche über dem Deckel bei u = 0 (Falz) … 1 (Außenkante): taucht in den Falz ab, wölbt sich
    nahe der Mitte am höchsten und fällt zur Außenkante sanft ab."""
    rise = math.sin(math.pi / 2.0 * min(u / 0.22, 1.0)) ** 0.8
    fall = SB.smooth(max(0.0, (u - 0.22) / 0.78))
    return T * (0.35 + 0.65 * rise - 0.12 * fall)


def mats():
    mk = SC.make_material
    return {
        "leather": mk("Buchdeckel Leder", (0.42, 0.19, 0.23), grain="smooth", rough=0.62, vary=0.06, bump=0.3, scale=3.0),
        "edges": mk("Buchkanten Papier", (0.92, 0.86, 0.73), grain="fabric", rough=0.95, vary=0.04),
        "brass": mk("Messing Buchecken", (0.8, 0.62, 0.32), grain="smooth", rough=0.38, metal=0.6, vary=0.04),
        "ribbon": mk("Lesebaendchen", (0.78, 0.42, 0.48), grain="fabric", rough=0.7, vary=0.05),
        "page_left": mk("Seite links", (0.97, 0.94, 0.86), grain="smooth", rough=0.92, vary=0.0, own=True),
        "page_right": mk("Seite rechts", (0.97, 0.94, 0.86), grain="smooth", rough=0.92, vary=0.0, own=True),
    }


def side_outline(sign, lift=0.0, n=40):
    """Querschnitt eines Seitenblocks (x, z) von unten am Falz über die gewölbte Oberseite zur Außenkante und zurück."""
    pts = [(sign * GUTTER, 0.001), (sign * W, 0.001)]
    for k in range(n, -1, -1):
        u = k / n
        pts.append((sign * (GUTTER + u * (W - GUTTER)), top(u) - lift))
    return pts if sign > 0 else list(reversed(pts))


def page_blocks(M, coll):
    """Zwei Seitenblöcke: Querschnitt (x, z) entlang y über die Seitenhöhe gezogen; die Kanten zeigen die Seiten."""
    blocks = Body("Seitenblöcke", M["edges"], coll, seed=811, vary=0.02, bevel=0.0)
    to_xz = Matrix(((1, 0, 0, 0), (0, 0, 1, -H / 2.0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Umriss (x, z), dick entlang +y
    for sign in (-1.0, 1.0):
        blocks.slab(side_outline(sign, lift=SHEET + 0.0005), H, to_xz, dent=0.0)
    blocks.build()


def page_sheets(M, coll):
    """Je Seite ein dünnes Blatt obenauf (geschlossen, 1,5 mm dick) mit UV auf der Oberseite für Papier bzw. Bild."""
    for sign, key, name in ((-1.0, "page_left", "Seite links"), (1.0, "page_right", "Seite rechts")):
        body = Body(name, M[key], coll, seed=812, vary=0.0, bevel=0.0)
        bm = body.bm
        uv = bm.loops.layers.uv.new("UVMap")
        nu, nv = 48, 8
        top_v, bot_v = {}, {}
        for i in range(nu + 1):
            u = i / nu
            x = sign * (GUTTER + u * (W - GUTTER))
            z = top(u)
            for j in range(nv + 1):
                y = -H / 2.0 + H * j / nv
                top_v[i, j] = bm.verts.new((x, y, z))
                bot_v[i, j] = bm.verts.new((x, y, z - SHEET))
        faces = []
        for i in range(nu):
            for j in range(nv):
                faces.append(bm.faces.new((top_v[i, j], top_v[i + 1, j], top_v[i + 1, j + 1], top_v[i, j + 1])))
                faces.append(bm.faces.new((bot_v[i, j + 1], bot_v[i + 1, j + 1], bot_v[i + 1, j], bot_v[i, j])))
        for i in range(nu):
            for j in (0, nv):
                faces.append(bm.faces.new((top_v[i, j], bot_v[i, j], bot_v[i + 1, j], top_v[i + 1, j])))
        for j in range(nv):
            for i in (0, nu):
                faces.append(bm.faces.new((top_v[i, j], top_v[i, j + 1], bot_v[i, j + 1], bot_v[i, j])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        top_set = set(top_v.values())
        for f in faces:
            f.smooth = True
            for loop in f.loops:
                if loop.vert in top_set:
                    p = loop.vert.co
                    # u von links nach rechts über die Seite, v (Blender) unten 0 … oben 1 (im Spiel: oben 0)
                    loop[uv].uv = ((p.x + W) / W if sign < 0 else p.x / W, (p.y + H / 2.0) / H)
                else:
                    loop[uv].uv = (0.0, 0.0)
        body._paint(list(top_v.values()) + list(bot_v.values()), (1.0, 1.0, 1.0))
        body.build(smooth_angle=60)


def covers(M, coll):
    """Zwei Deckel (Leder) mit Überstand, darunter der runde Rücken; Messingecken oben und unten an den Außenecken."""
    leather = Body("Einband", M["leather"], coll, seed=813, vary=0.04, bevel=0.006)
    for sign in (-1.0, 1.0):
        x0, x1 = sign * 0.004, sign * (W + OVER)
        leather.box(((x0 + x1) / 2.0, 0.0, -BOARD / 2.0), (abs(x1 - x0), H + 2.0 * OVER, BOARD), step=0.2, dent=0.002)
    # Rücken: halbe Rolle unter dem Falz (das Buch liegt offen, der Rücken wölbt sich nach unten)
    half = [(SPINE_R * math.cos(math.pi + math.pi * k / 14), SPINE_R * 0.8 * math.sin(math.pi + math.pi * k / 14))
            for k in range(15)]
    to_xz = Matrix(((1, 0, 0, 0), (0, 0, 1, -(H / 2.0 + OVER)), (0, 1, 0, -BOARD - 0.001), (0, 0, 0, 1)))
    leather.slab(list(reversed(half)), H + 2.0 * OVER, to_xz, dent=0.0)
    leather.build()
    # Messingecken: Kappen, die die Deckelecke oben, unten und an beiden Kanten umgreifen (die Ecke steckt darin, wie bei
    # echten Buchecken); sie bleiben im freien Rand vor dem Seitenblock
    brass = Body("Buchecken", M["brass"], coll, seed=814, vary=0.03, bevel=0.002)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * (W + OVER + 0.0015), sy * (H / 2.0 + OVER + 0.0015)
            leg = CORNER + 0.0015
            tri = [(cx, cy), (cx - sx * leg, cy), (cx, cy - sy * leg)]
            if sx * sy < 0:
                tri = list(reversed(tri))
            brass.slab(tri, BOARD + 0.004, Matrix.Translation((0.0, 0.0, -BOARD - 0.002)), dent=0.0)
    brass.build()


def ribbon(M, coll):
    """Lesebändchen auf der linken Seite (wo sie flach ist): liegt über die ganze Seite und fällt an der unteren Kante heraus.
    Im Hauptmenü steht das Buch aufrecht (unten = Blender -y): das Bändchen hängt dort senkrecht nach unten, vor der Kante des
    Deckels, und neigt sich ein wenig zum Buch hin."""
    rb = Body("Lesebaendchen", M["ribbon"], coll, seed=815, vary=0.03, bevel=0.0)
    x = -0.3
    width, thick = 0.028, 0.0016
    us = [(abs(x) + d - GUTTER) / (W - GUTTER) for d in (-width / 2.0, 0.0, width / 2.0)]
    z = max(top(u) for u in us) + 0.0006
    y_top, y_edge = H / 2.0 - 0.005, -H / 2.0
    rb.sheet((x - width / 2.0, y_edge, z + thick), (width, 0.0, 0.0), (0.0, y_top - y_edge, 0.0), 2, 12, thick)
    # frei hängend unter der Seitenkante (vor dem Deckel, der weiter unten übersteht), sanft gebogen
    hang = 0.3
    rb.sheet((x - width / 2.0, y_edge - hang, z * 0.55), (width, 0.0, 0.0), (0.0, hang - 0.001, z * 0.45 + thick), 2, 12, thick,
             offset=lambda u, v: 0.012 * math.sin(v * math.pi))
    rb.build()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if os.path.exists(STAMP) and SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("title_book.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = mats()
    root = SB.collection("Titelbuch")
    coll = SB.collection("Buch", root)
    covers(M, coll)
    page_blocks(M, coll)
    page_sheets(M, coll)
    ribbon(M, coll)
    objs = [o for o in coll.objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tris, n = SC.export_objects(objs, [], OUT, palette=True, extra=[])
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, OUT)
    print("Spiel: %s (%d Dreiecke, %d Netze), Offene Kanten: %s" % (OUT, tris, n, bad if bad else "keine"))
    if "--render" in argv:
        SC.setup_render(True)
        SC.render("titelbuch", (0.4, -2.6, 1.9), (0.0, 0.0, 0.05), 32, (1200, 800))
        SC.render("titelbuch_band", (-1.2, -1.6, 0.5), (-0.3, -0.85, 0.0), 40, (900, 700))
        SC.render("titelbuch_falz", (0.25, -0.9, 0.35), (0.0, -0.2, 0.06), 32, (1000, 700))
        SC.render("titelbuch_ecke", (1.35, -1.05, 0.3), (0.95, -0.7, 0.0), 40, (900, 700))
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(STAMP, "w") as f:
        f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
