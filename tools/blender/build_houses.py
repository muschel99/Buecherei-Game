"""Baut die Stil-Modelle der Häuser (seit Etappe 4g).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_houses.py -- fashion_shop
    blender -b --factory-startup --python tools/blender/build_houses.py -- fashion_shop --render
    blender -b --factory-startup --python tools/blender/build_houses.py -- fashion_shop --check
    blender -b --factory-startup --python tools/blender/build_houses.py -- all

Ergebnis je Haustyp:
    assets/models/houses/<typ>.glb            Modell für Godot (Knoten "Model" im Haustyp)
    assets/models/source/houses/<typ>.blend   zum Anschauen in Blender
    scenes/world/houses/<typ>_interior.tscn   Requisiten im Laden (Puppen, Kleidung), falls der
                                              Haustyp einen Laden hat (wird neu geschrieben!)
    screenshots/blender/<typ>-*.png           Kontrollbilder (--render) bzw. Prüfbilder (--check:
                                              Rückseiten pink = im Spiel ein Loch)

Maße (Breite, Tiefe, Traufhöhe) liest das Script aus scenes/world/houses/<typ>.tscn – so passt
das Modell immer genau auf den Platz im Spiel.
Requisiten (Puppen, Kleidung) baut tools/blender/build_props.py.
"""

import bpy
import math
import os
import re
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
import style_parts as P  # noqa: E402
import street_houses as H  # noqa: E402
from style_lib import Mat, V  # noqa: E402

# --- Gemeinsame Materialien (Ebene, Rolle, feste Farbe in sRGB) ---
WALL_STONE = Mat("stone", "wall")
BRICK = Mat("brick", color=(0.6, 0.33, 0.25))
TRIM = Mat("stone_trim")
JOINERY = Mat("paint", "door")
# Kein reines Weiß (sticht zu sehr hervor): Creme
WHITE = Mat("paint", color=(0.86, 0.84, 0.78))
SLATE = Mat("slate")
RIDGE = Mat("terracotta", color=(1, 1, 1))
LEAD = Mat("metal")
GOLD = Mat("gold")
CANVAS = Mat("canvas", "accent")
CURTAIN = Mat("fabric", color=(0.92, 0.9, 0.84))
DARK_GLASS = Mat("glass")
CLEAR_GLASS = Mat("glass", glass=True)
POT = Mat("terracotta")
TILES = Mat("paving", color=(1, 1, 1))

# Ladenraum (leicht leuchtend, damit er von draußen hell und einladend wirkt)
IN_FLOOR = Mat("boards", color=(0.66, 0.48, 0.32), glow=0.1)
IN_PAPER = Mat("render", color=(0.9, 0.84, 0.72), glow=0.16)
IN_SAGE = Mat("paint", color=(0.56, 0.6, 0.5), glow=0.12)
IN_SAGE_DARK = Mat("paint", color=(0.42, 0.46, 0.38), glow=0.1)
IN_CEILING = Mat("plain", color=(0.92, 0.88, 0.8), glow=0.16)
IN_WOOD = Mat("timber", glow=0.1)
IN_BRASS = Mat("gold", glow=0.05)
IN_VELVET = Mat("fabric", color=(0.46, 0.3, 0.36), glow=0.08)
IN_ROSE = Mat("fabric", color=(0.7, 0.5, 0.48), glow=0.08)
IN_MIRROR = Mat("plain", color=(0.74, 0.78, 0.8), glow=0.2)
LAMP = Mat("plain", color=(1.0, 0.88, 0.66), glow=1.0)

HOUSE_DIR = os.path.join(S.ROOT, "scenes", "world", "houses")
# Dachneigung der Stil-Modelle: etwa 35° (englische Schieferdächer). Der Platzhalter hat ein
# flacheres Dach (2 m); an Grundriss und Traufhöhe ändert das nichts.
STYLE_ROOF_PITCH = 35.0


def house_dims(type_id):
    """Maße aus der Haustyp-Szene (Standardwerte wie in house_facade.gd)."""
    type_id = re.sub(r"_side_(left|right|both)$", "", type_id)
    text = open(os.path.join(HOUSE_DIR, type_id + ".tscn")).read()

    def value(name, default):
        match = re.search(r"^%s = ([0-9.]+)" % name, text, re.M)
        return float(match.group(1)) if match else default

    depth = value("depth", 8.0)
    return {"width": value("width", 5.0), "depth": depth, "eaves": value("eaves_height", 6.6),
            "rise": (depth / 2 + 0.25) * math.tan(math.radians(STYLE_ROOF_PITCH))}


# --- Hülle: Dach, Brandwände, Schornsteine ---

def gable_roof(b, w, depth, eaves, rise, front_z, back_z, mat=SLATE):
    """Satteldach mit First parallel zur Straße, Firstziegel, Traufbrett hinten."""
    ridge_y = eaves + rise
    ridge_z = -depth / 2
    b.quad(V(-w, eaves, front_z), V(w, eaves, front_z), V(w, ridge_y, ridge_z), V(-w, ridge_y, ridge_z), mat)
    b.quad(V(w, eaves, back_z), V(-w, eaves, back_z), V(-w, ridge_y, ridge_z), V(w, ridge_y, ridge_z), mat)
    b.cylinder(V(-w, ridge_y + 0.02, ridge_z), 0.09, 2 * w, RIDGE, segments=8, caps=(True, True), axis="x")
    # Hinten: Traufbrett und Rinne schließen die Dachkante
    b.box((-w, eaves - 0.22, back_z), (w, eaves + 0.01, -depth), WHITE, skip=("front",))
    b.cylinder(V(-w, eaves - 0.04, back_z - 0.04), 0.055, 2 * w, LEAD, segments=8, caps=(True, True), axis="x")


def roof_y(z, eaves, rise, front_z, depth):
    """Höhe der vorderen Dachfläche über der Stelle z."""
    return eaves + (front_z - z) * rise / (front_z + depth / 2)


def party_walls(b, w, depth, eaves, rise, front_z, back_z, mat=BRICK, open_sides=()):
    """Seitenwände, Rückwand und Giebel (Brandwände zu den Nachbarn) mit Aufkantung über dem Dach.
    open_sides: Seiten (-1/1) ohne untere Wand (dort baut das Haus eine Wand mit Fenstern)."""
    ridge_y = eaves + rise
    for side in (-1, 1):
        x = side * w
        wall = [V(x, 0, -depth), V(x, 0, 0), V(x, eaves, 0), V(x, eaves, -depth)]
        gable = [V(x, eaves, back_z), V(x, eaves, front_z), V(x, ridge_y + 0.12, -depth / 2)]
        if side not in open_sides:
            b.poly(wall if side < 0 else wall[::-1], mat)
        b.poly(gable if side < 0 else gable[::-1], mat)
        # Aufkantung mit Abdeckstein, folgt dem Dach; am First ein kleiner Deckstein
        xc = side * (w - 0.17)
        front = V(xc, eaves - 0.08, front_z)
        ridge = V(xc, ridge_y - 0.08, -depth / 2)
        back = V(xc, eaves - 0.08, back_z)
        for pa, pb in ((front, ridge), (ridge, back)):
            b.beam(pa, pb, 0.3, 0.2, mat)
            b.beam(pa + V(0, 0.2, 0), pb + V(0, 0.2, 0), 0.34, 0.045, TRIM)
        b.box((xc - 0.18, ridge_y + 0.08, -depth / 2 - 0.2), (xc + 0.18, ridge_y + 0.2, -depth / 2 + 0.2), TRIM)
    b.quad(V(w, 0, -depth), V(-w, 0, -depth), V(-w, eaves, -depth), V(w, eaves, -depth), mat)


def chimney(b, x, z, base_y, top_y, width=0.62, deep=0.9, pots=2, mat=BRICK):
    """Schornstein mit Abdeckplatte und Tonaufsätzen."""
    hw = width / 2
    hd = deep / 2
    b.box((x - hw, base_y, z - hd), (x + hw, top_y - 0.1, z + hd), mat, skip=("bottom", "top"))
    b.box((x - hw - 0.05, top_y - 0.1, z - hd - 0.05), (x + hw + 0.05, top_y, z + hd + 0.05), TRIM)
    b.box((x - hw - 0.04, top_y - 0.3, z - hd - 0.04), (x + hw + 0.04, top_y - 0.22, z + hd + 0.04), TRIM)
    for k in range(pots):
        pz = z + (k - (pots - 1) / 2) * (deep / pots)
        b.cylinder(V(x, top_y, pz), 0.11, 0.38, POT, segments=10, radius_top=0.085, caps=(False, False))
        b.cylinder(V(x, top_y + 0.38, pz), 0.1, 0.05, POT, segments=10, caps=(True, False))
        # Oben dunkle Öffnung (als Deckel, damit man nicht in den Topf hinein und hindurch sieht)
        b.cylinder(V(x, top_y + 0.42, pz), 0.075, 0.012, Mat("plain", color=(0.06, 0.05, 0.05)), segments=10)
        b.poly([V(x + 0.1 * math.cos(a), top_y + 0.43, pz - 0.1 * math.sin(a)) for a in [2 * math.pi * k / 10 for k in range(10)]], POT)


# --- Fenster und Gauben ---

def sash_window(b, x, y0, w, h, reveal, panes=(2, 2), curtains=True, z=0.0):
    """Schiebefenster (zwei Flügel) in einer Wandöffnung (x = Mitte, y0 = Unterkante, z = Ebene
    der Wand), Glas dunkel, helle Vorhänge dahinter."""
    b.push(b.move(0, 0, z))
    x0, x1 = x - w / 2, x + w / 2
    y1 = y0 + h
    zg = -reveal + 0.02
    # Echtes Glas, dahinter Vorhänge bzw. ein kleiner, dämmriger Raum (wie bei den Wohnhäusern)
    b.quad(V(x0, y0, zg), V(x1, y0, zg), V(x1, y1, zg), V(x0, y1, zg), CLEAR_GLASS)
    import random
    rnd = random.Random(int(abs(x) * 100 + y0 * 1000 + z * 10))
    kind = rnd.choice(["nets", "nets", "closed", "blind"]) if curtains else "dim"
    H.backdrop(b, kind, x0 + 0.04, x1 - 0.04, y0 + 0.04, y1 - 0.04, zg, (x0 - 0.12, x1 + 0.12, y0 - 0.5, y1 + 0.3, 0.6), rnd)
    f = 0.055
    zf0, zf1 = zg - 0.01, zg + 0.06
    b.box((x0, y0, zf0), (x0 + f, y1, zf1), WHITE, skip=("back",))
    b.box((x1 - f, y0, zf0), (x1, y1, zf1), WHITE, skip=("back",))
    b.box((x0 + f, y1 - f, zf0), (x1 - f, y1, zf1), WHITE, skip=("back",))
    b.box((x0 + f, y0, zf0), (x1 - f, y0 + f, zf1), WHITE, skip=("back",))
    mid = y0 + h / 2
    b.box((x0 + f, mid - 0.03, zf0), (x1 - f, mid + 0.03, zf1 + 0.015), WHITE, skip=("back",))
    for sy0, sy1, dz in ((y0 + f, mid - 0.03, 0.0), (mid + 0.03, y1 - f, 0.015)):
        b.glazing_bars(x0 + f, sy0, x1 - f, sy1, zf0, zf1 - 0.02 + dz, panes[0], panes[1], 0.022, WHITE)
    b.pop()


def dormer(b, cx, fz, eaves, rise, front_z, depth, gw=0.44):
    """Gaube im vorderen Dach: Vorderseite bei fz, Breite 2 x gw. Dach und Ortgänge als
    geschlossene Platten (auch von unten sichtbar)."""
    base = roof_y(fz, eaves, rise, front_z, depth) - 0.06
    top = base + 1.0
    ridge = top + 0.34
    slope = rise / (front_z + depth / 2)
    back = front_z - (ridge + 0.05 - eaves) / slope - 0.1
    win_lo, win_hi = base + 0.2, top - 0.1
    b.wall_with_holes(cx - gw, cx + gw, base, top, fz, [(cx - 0.27, win_lo, cx + 0.27, win_hi)], SLATE, reveal=0.07, reveal_mat=WHITE)
    sash_window(b, cx, win_lo, 0.54, win_hi - win_lo, 0.07, panes=(2, 1), curtains=True, z=fz)
    b.frame(cx - 0.27, win_lo, cx + 0.27, win_hi, fz, fz + 0.04, 0.06, WHITE)
    b.box((cx - 0.36, win_lo - 0.1, fz), (cx + 0.36, win_lo - 0.04, fz + 0.08), WHITE, skip=("back",))
    b.quad(V(cx - gw, base, back), V(cx - gw, base, fz), V(cx - gw, top, fz), V(cx - gw, top, back), SLATE)
    b.quad(V(cx + gw, base, fz), V(cx + gw, base, back), V(cx + gw, top, back), V(cx + gw, top, fz), SLATE)
    b.poly([V(cx - gw, top, fz), V(cx + gw, top, fz), V(cx, ridge, fz)], WHITE)
    for s2 in (-1, 1):
        lo = V(cx + s2 * (gw + 0.08), top - 0.06, fz + 0.12)
        hi = V(cx, ridge + 0.05, fz + 0.12)
        pts = [lo, hi, V(hi.x, hi.y, back), V(lo.x, lo.y, back)]
        b.slab(pts if s2 < 0 else pts[::-1], 0.05, SLATE)
        # Ortgang-Brett (weiß), vorn unter der Dachkante
        b.beam(lo + V(0, -0.13, 0.0), hi + V(0, -0.13, 0.0), 0.04, 0.12, WHITE)
    b.cylinder(V(cx, ridge + 0.04, back), 0.05, fz + 0.12 - back, RIDGE, segments=6, caps=(False, True), axis="z")


# --- Ladenfront-Teile ---

def _arch_bar(b, cx, y_base, radius_x, radius_y, z0, z1, segments=10):
    """Bogensprosse im Oberlicht (Halbellipse aus kurzen Stücken)."""
    pts = []
    for i in range(segments + 1):
        a = math.pi * i / segments
        pts.append(V(cx - radius_x * math.cos(a), y_base + radius_y * math.sin(a), (z0 + z1) / 2))
    b.tube(pts, 0.012, JOINERY, segments=5)


def _awning(b, x0, x1, y_top, z_wall, reach, drop):
    """Markise: Tuch schräg nach vorn, Volant vorn, Seitenwangen (alles beidseitig)."""
    a, c = V(x0, y_top, z_wall), V(x1, y_top, z_wall)
    d, e = V(x1, y_top - drop, reach), V(x0, y_top - drop, reach)
    b.poly([a, c, d, e], CANVAS, both=True)
    val = 0.2
    b.poly([V(x0, y_top - drop - val, reach), V(x1, y_top - drop - val, reach), d, e], CANVAS, both=True)
    for x, flip in ((x0, True), (x1, False)):
        pts = [V(x, y_top, z_wall), V(x, y_top - drop, reach), V(x, y_top - drop - val, reach), V(x, y_top - drop - val * 0.5, z_wall + 0.25)]
        b.poly(pts if flip else pts[::-1], CANVAS, both=True)
    b.cylinder(V(x0, y_top - drop, reach - 0.02), 0.018, x1 - x0, LEAD, segments=6, caps=(True, True), axis="x")
    b.box((x0 - 0.03, y_top - 0.05, 0.0), (x1 + 0.03, y_top + 0.08, z_wall + 0.03), JOINERY)


def _recessed_door(b, half, transom, head, jz):
    """Ladentür in einer flachen Nische: geschlossene Seitenwände und Decke, Fliesenboden, Tür
    mit großer Glasscheibe (man sieht in den Laden), Oberlicht vorn."""
    back = -0.42
    x0, x1 = -half, half
    for lo, hi in ((x0 - 0.1, x0), (x1, x1 + 0.1)):
        b.box((lo, 0.02, back - 0.05), (hi, transom, 0.0), JOINERY)
    b.box((x0 - 0.1, transom, back - 0.05), (x1 + 0.1, transom + 0.08, jz), JOINERY)
    b.box((x0 - 0.02, 0, back), (x1 + 0.02, 0.06, 0.08), TILES, skip=("back",))
    gz = 0.06
    b.quad(V(x0, transom + 0.08, gz), V(x1, transom + 0.08, gz), V(x1, head, gz), V(x0, head, gz), CLEAR_GLASS)
    _arch_bar(b, 0.0, transom + 0.08, half - 0.03, head - transom - 0.12, gz, jz - 0.03)
    b.box((-0.012, transom + 0.08, gz), (0.012, head, jz - 0.03), JOINERY)
    # Blende hinter dem Oberlicht (zur Straße hin), damit man dort nicht in den Raum sieht
    b.quad(V(x0 - 0.1, transom + 0.08, -0.025), V(x1 + 0.1, transom + 0.08, -0.025), V(x1 + 0.1, head + 0.08, -0.025),
           V(x0 - 0.1, head + 0.08, -0.025), JOINERY)
    # Türblatt: Rahmen, große Scheibe oben, Füllung unten, Briefschlitz und Knauf (beidseitig)
    dz = back
    fw = 0.1
    t0, t1 = dz - 0.05, dz
    b.box((x0, 0.06, t0), (x0 + fw, transom, t1), JOINERY)
    b.box((x1 - fw, 0.06, t0), (x1, transom, t1), JOINERY)
    b.box((x0 + fw, 0.06, t0), (x1 - fw, 0.28, t1), JOINERY)
    b.box((x0 + fw, 0.82, t0), (x1 - fw, 0.92, t1), JOINERY)
    b.box((x0 + fw, transom - 0.1, t0), (x1 - fw, transom, t1), JOINERY)
    b.box((x0 + fw, 0.28, t0 + 0.01), (x1 - fw, 0.82, t1 - 0.01), JOINERY)
    b.frame(x0 + fw + 0.06, 0.35, x1 - fw - 0.06, 0.75, t1 - 0.01, t1 + 0.008, 0.022, JOINERY)
    b.quad(V(x0 + fw, 0.92, dz - 0.025), V(x1 - fw, 0.92, dz - 0.025), V(x1 - fw, transom - 0.1, dz - 0.025), V(x0 + fw, transom - 0.1, dz - 0.025), CLEAR_GLASS)
    b.box((-0.15, 0.86, t1), (0.15, 0.89, t1 + 0.012), GOLD)
    b.sphere(V(x1 - fw - 0.06, 1.0, dz + 0.04), 0.03, GOLD, rings=4, segments=8)
    b.sphere(V(x1 - fw - 0.06, 1.0, t0 - 0.04), 0.03, GOLD, rings=4, segments=8)
    # Kleines Schild an der Scheibe: "Geöffnet" (eigenes Bild, siehe SIGNS)
    cw, ch = OPEN_SIGN
    b.box((-cw / 2, 1.45, t1 - 0.02), (cw / 2, 1.45 + ch, t1 - 0.012), Mat("plain", color=(0.93, 0.9, 0.82)), skip=("front",))
    b.poly([V(-cw / 2, 1.45, t1 - 0.012), V(cw / 2, 1.45, t1 - 0.012), V(cw / 2, 1.45 + ch, t1 - 0.012), V(-cw / 2, 1.45 + ch, t1 - 0.012)],
           Mat("plain", sign="open"), uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])


# --- Ladenraum ---

def _wall_panelling(b, length, ceiling, chair_rail=1.02):
    """Wandverkleidung in Wand-Koordinaten (u = 0..length entlang der Wand, Vorderseite +z):
    Sockelleiste, Kassetten bis zur Stuhlleiste, Bilderleiste, Deckenprofil."""
    u0, u1 = 0.03, length - 0.03
    b.box((u0, 0.1, 0), (u1, chair_rail, 0.022), IN_SAGE)
    b.box((u0, 0.1, 0), (u1, 0.24, 0.035), IN_SAGE_DARK)
    b.box((u0, chair_rail - 0.03, 0), (u1, chair_rail + 0.03, 0.045), IN_SAGE_DARK)
    n = max(1, int((u1 - u0) / 0.75))
    step = (u1 - u0) / n
    for k in range(n):
        a = u0 + k * step + 0.1
        b.frame(a + 0.02, 0.36, a + step - 0.22, chair_rail - 0.16, 0.022, 0.032, 0.022, IN_SAGE_DARK)
    b.box((u0, 2.42, 0), (u1, 2.45, 0.025), IN_WOOD)
    b.box((u0, ceiling - 0.1, 0), (u1, ceiling, 0.07), IN_CEILING)


def _shop_interior(b, xi, floor_y, ceiling, z_front, z_back, windows, door_half):
    """Leicht vintage, dezent: Dielen, salbeigrüne Kassetten, cremefarbene Tapete, zwei
    Glas-Pendelleuchten, Theke mit Messingkasse, Wandregal mit gefalteten Stoffen und
    Hutschachteln, Umkleide mit Samtvorhang, Spiegel mit Goldrahmen, Sessel, Beistelltisch,
    Läufer, Kleiderstangen an beiden Seiten (Kleidung = Requisiten, siehe _interior_props)."""
    b.room((-xi, floor_y, z_back), (xi, ceiling, z_front),
           {"floor": IN_FLOOR, "ceiling": IN_CEILING, "back": IN_PAPER, "left": IN_PAPER, "right": IN_PAPER})
    # Innenseite der Vorderwand (zeigt in den Raum) mit Öffnungen für Schaufenster und Tür
    holes = [(lo, sill, hi, head) for lo, hi, sill, head in windows] + [(-door_half - 0.1, floor_y, door_half + 0.1, 2.38)]
    b.push(b.move(0, 0, z_front) @ b.turn_y(180))
    b.wall_with_holes(-xi, xi, floor_y, ceiling, 0.0, [(-h[2], h[1], -h[0], h[3]) for h in holes], IN_PAPER, reveal=0.03)
    b.pop()
    # Wandverkleidung: links, rechts, hinten
    depth = z_front - z_back
    for xf in (b.move(-xi, 0, z_front) @ b.turn_y(90), b.move(xi, 0, z_back) @ b.turn_y(-90)):
        b.push(xf)
        _wall_panelling(b, depth, ceiling)
        b.pop()
    b.push(b.move(-xi, 0, z_back))
    _wall_panelling(b, 2 * xi, ceiling)
    b.pop()
    # Schaufenster-Podeste (hell gestrichen, Dielen oben)
    for lo, hi, sill, head in windows:
        b.box((lo + 0.05, floor_y, z_front - 0.8), (hi - 0.05, sill - 0.04, z_front - 0.01), Mat("paint", color=(0.86, 0.81, 0.72), glow=0.12))
        b.box((lo + 0.03, sill - 0.04, z_front - 0.82), (hi - 0.03, sill - 0.01, z_front - 0.01), IN_FLOOR)
    # Läufer
    b.box((-1.0, floor_y, -3.6), (1.0, floor_y + 0.008, -1.4), Mat("plain", color=(0.48, 0.34, 0.33), glow=0.1))
    b.box((-0.88, floor_y, -3.48), (0.88, floor_y + 0.012, -1.52), Mat("fabric", color=(0.72, 0.56, 0.5), glow=0.1))
    # Pendelleuchten
    for z in (-1.9, -4.0):
        b.tube([V(0, ceiling, z), V(0, 2.72, z)], 0.006, LEAD, segments=4)
        b.cylinder(V(0, 2.66, z), 0.04, 0.07, IN_BRASS, segments=10, radius_top=0.025)
        b.sphere(V(0, 2.54, z), 0.14, LAMP, rings=6, segments=12)
        b.cylinder(V(0, ceiling - 0.02, z), 0.07, 0.02, IN_BRASS, segments=10)
    # Theke (salbeigrün mit Kassetten, Holzplatte) und Messingkasse
    cz0, cz1 = -5.0, -4.45
    b.box((-0.9, floor_y, cz0), (1.3, 0.98, cz1), IN_SAGE)
    for k in range(3):
        a = -0.82 + k * 0.72
        b.frame(a + 0.06, 0.25, a + 0.6, 0.82, cz1, cz1 + 0.012, 0.025, IN_SAGE_DARK)
    b.box((-0.95, 0.98, cz0 - 0.03), (1.35, 1.02, cz1 + 0.04), IN_WOOD)
    b.box((0.6, 1.02, -4.85), (1.0, 1.14, -4.55), IN_BRASS)
    b.poly([V(0.6, 1.14, -4.55), V(1.0, 1.14, -4.55), V(1.0, 1.26, -4.78), V(0.6, 1.26, -4.78)], IN_BRASS)
    b.box((0.6, 1.14, -4.85), (1.0, 1.26, -4.78), IN_BRASS)
    for side in (0.6, 1.0):
        b.poly([V(side, 1.14, -4.55), V(side, 1.26, -4.78), V(side, 1.14, -4.78)][::(1 if side > 0.8 else -1)], IN_BRASS)
    b.box((0.68, 1.26, -4.82), (0.92, 1.36, -4.79), Mat("plain", color=(0.95, 0.92, 0.84), glow=0.2))
    # Seidenpapier-Stapel und kleine Vase auf der Theke
    b.box((-0.7, 1.02, -4.85), (-0.3, 1.07, -4.6), Mat("plain", color=(0.86, 0.78, 0.66), glow=0.1))
    b.cylinder(V(0.1, 1.02, -4.7), 0.05, 0.16, Mat("plain", color=(0.72, 0.8, 0.82), glow=0.1), segments=10, radius_top=0.03)
    import random
    rnd = random.Random(5)
    P.blossom_cluster(b, (0.1, 1.22, -4.7), 0.06, "rose", rnd, count=6, size=0.025)
    # Wandregal hinter der Theke mit gefalteten Stoffen, Hutschachteln und einer Uhr darüber
    rz0, rz1 = z_back + 0.01, z_back + 0.3
    for x in (-1.3, 1.5):
        b.box((x - 0.025, 1.1, rz0), (x + 0.025, 2.3, rz1), IN_WOOD)
    folded = [(0.66, 0.46, 0.4), (0.3, 0.38, 0.4), (0.8, 0.72, 0.56), (0.4, 0.42, 0.32), (0.62, 0.36, 0.3), (0.78, 0.76, 0.7)]
    for level, y in enumerate((1.3, 1.75, 2.2)):
        b.box((-1.3, y - 0.03, rz0), (1.5, y, rz1), IN_WOOD)
        x = -1.2
        k = level
        while x < 1.3:
            if (k + level) % 4 == 3 and level < 2:
                for s in range(2):
                    r = 0.15 - s * 0.02
                    b.cylinder(V(x + 0.16, y + s * 0.17, (rz0 + rz1) / 2), r, 0.17, Mat("plain", color=folded[(k + s) % 6], glow=0.1), segments=14)
                x += 0.4
            else:
                hgt = y
                for s in range(rnd.randint(3, 5)):
                    t = rnd.uniform(0.035, 0.05)
                    b.box((x, hgt, rz0 + 0.03), (x + 0.28, hgt + t, rz1 - 0.02), Mat("fabric", color=folded[(k + s) % 6], glow=0.1))
                    hgt += t
                x += 0.36
            k += 1
    b.cylinder(V(0.1, 2.78, z_back + 0.01), 0.17, 0.04, IN_BRASS, segments=20, axis="z", caps=(True, True))
    b.cylinder(V(0.1, 2.78, z_back + 0.045), 0.145, 0.015, Mat("plain", color=(0.95, 0.92, 0.84), glow=0.2), segments=20, axis="z", caps=(True, True))
    b.beam(V(0.1, 2.78, z_back + 0.065), V(0.1, 2.88, z_back + 0.065), 0.012, 0.005, LEAD)
    b.beam(V(0.1, 2.78, z_back + 0.067), V(0.17, 2.76, z_back + 0.067), 0.012, 0.005, LEAD)
    # Umkleide hinten links: Messingstange, Samtvorhang (vorn halb zugezogen, seitlich offen)
    fx, fz = -1.6, -4.6
    b.tube([V(-xi, 2.4, fz), V(fx, 2.4, fz), V(fx, 2.4, z_back)], 0.015, IN_BRASS, segments=6)
    _curtain(b, V(-xi + 0.02, 0.14, fz), V(fx - 0.25, 0.14, fz), 2.38, IN_VELVET)
    _curtain(b, V(fx, 0.14, z_back + 0.05), V(fx, 0.14, z_back + 0.45), 2.38, IN_VELVET)
    b.box((-xi + 0.05, floor_y, z_back + 0.1), (-xi + 0.45, 0.55, z_back + 0.55), Mat("fabric", color=(0.6, 0.52, 0.44), glow=0.08))
    # Spiegel mit Goldrahmen an der rechten Wand
    mz0, mz1 = -5.25, -4.55
    b.box((xi - 0.04, 0.35, mz0), (xi, 2.25, mz1), IN_BRASS)
    b.box((xi - 0.05, 0.43, mz0 + 0.08), (xi - 0.04, 2.17, mz1 - 0.08), IN_MIRROR)
    b.sphere(V(xi - 0.05, 2.33, (mz0 + mz1) / 2), 0.07, IN_BRASS, rings=4, segments=8, squash=0.6)
    # Sessel (Samt, altrosa) und Beistelltisch
    _armchair(b, 1.95, floor_y, -3.85, -90)
    _side_table(b, 0.35, floor_y, -2.3, rnd)
    # Kleiderstangen links und rechts (Messing, mit Wandhaltern)
    for side, z0, z1 in ((-1, -1.15, -4.35), (1, -1.15, -3.2)):
        x = side * 2.2
        b.tube([V(x, 1.85, z0), V(x, 1.85, z1)], 0.014, IN_BRASS, segments=6)
        for z in (z0, z1):
            b.tube([V(x, 1.85, z), V(side * xi, 1.85, z)], 0.012, IN_BRASS, segments=5)
    # Bilder (Modezeichnungen) über den Stangen
    for side, z in ((-1, -2.0), (-1, -3.3), (1, -2.2)):
        x = side * (xi - 0.02)
        b.push(b.move(x, 2.5, z) @ b.turn_y(-90 * side))
        b.box((-0.22, 0, 0), (0.22, 0.5, 0.03), IN_BRASS)
        b.box((-0.18, 0.04, 0.03), (0.18, 0.46, 0.035), Mat("plain", color=(0.9, 0.86, 0.76), glow=0.15))
        b.box((-0.05, 0.1, 0.035), (0.05, 0.38, 0.038), Mat("plain", color=(0.55, 0.4, 0.4), glow=0.1))
        b.pop()
    # Farn im Topf neben der Theke
    b.cylinder(V(-1.2, floor_y, -4.2), 0.13, 0.28, POT, segments=12, radius_top=0.16)
    for k in range(9):
        a = 2 * math.pi * k / 9
        tip = V(-1.2 + 0.38 * math.cos(a), floor_y + 0.42 + 0.1 * math.sin(3 * a), -4.2 + 0.38 * math.sin(a))
        mid = V(-1.2 + 0.18 * math.cos(a), floor_y + 0.6, -4.2 + 0.18 * math.sin(a))
        b.tube([V(-1.2, floor_y + 0.3, -4.2), mid, tip], lambda t: 0.035 * (1 - t) + 0.006, Mat("foliage", color=(0.3, 0.45, 0.22), glow=0.08), segments=4)


def _curtain(b, a, c, top, mat, folds=6):
    """Faltiger Vorhang von a nach c (unten), bis zur Höhe top (beidseitig sichtbar)."""
    d = c - a
    n = folds * 2
    side = V(-d.z, 0, d.x).normalized()
    pts = []
    for k in range(n + 1):
        t = k / n
        off = side * (0.045 * (1 if k % 2 else -1))
        pts.append(a + d * t + off)
    for k in range(n):
        p0, p1 = pts[k], pts[k + 1]
        b.poly([p0, p1, V(p1.x, top, p1.z), V(p0.x, top, p0.z)], mat, both=True)


def _armchair(b, x, floor_y, z, yaw):
    """Kleiner Samtsessel mit gedrechselten Beinen."""
    b.push(b.move(x, floor_y, z) @ b.turn_y(yaw))
    for lx in (-0.28, 0.28):
        for lz in (-0.26, 0.24):
            b.cylinder(V(lx, 0, lz), 0.025, 0.2, IN_WOOD, segments=6, radius_top=0.03)
    b.box((-0.34, 0.2, -0.32), (0.34, 0.44, 0.3), IN_ROSE)
    b.box((-0.3, 0.44, -0.28), (0.3, 0.5, 0.28), IN_ROSE)
    b.beam(V(0, 0.42, -0.28), V(0, 0.98, -0.36), 0.66, 0.14, IN_ROSE)
    for side in (-1, 1):
        b.box((side * 0.34 - 0.06, 0.44, -0.3), (side * 0.34 + 0.06, 0.62, 0.26), IN_ROSE)
        b.cylinder(V(side * 0.34, 0.62, -0.3), 0.06, 0.56, IN_ROSE, segments=8, axis="z", caps=(True, True))
    b.pop()


def _side_table(b, x, floor_y, z, rnd):
    """Runder Beistelltisch mit gefalteten Tüchern und einer Vase mit Trockenblumen."""
    b.cylinder(V(x, floor_y + 0.7, z), 0.36, 0.035, IN_WOOD, segments=20, caps=(True, True))
    b.cylinder(V(x, floor_y + 0.08, z), 0.035, 0.62, IN_WOOD, segments=8)
    for k in range(3):
        a = 2 * math.pi * k / 3
        b.tube([V(x, floor_y + 0.12, z), V(x + 0.24 * math.cos(a), floor_y, z + 0.24 * math.sin(a))], 0.018, IN_WOOD, segments=5)
    top = floor_y + 0.735
    b.box((x - 0.2, top, z - 0.12), (x + 0.05, top + 0.03, z + 0.1), Mat("fabric", color=(0.78, 0.68, 0.48), glow=0.1))
    b.box((x - 0.18, top + 0.03, z - 0.1), (x + 0.03, top + 0.055, z + 0.08), Mat("fabric", color=(0.4, 0.46, 0.44), glow=0.1))
    b.cylinder(V(x + 0.16, top, z + 0.02), 0.05, 0.2, Mat("plain", color=(0.86, 0.82, 0.72), glow=0.1), segments=10, radius_top=0.035)
    for k in range(6):
        a = 2 * math.pi * k / 6
        tip = V(x + 0.16 + 0.1 * math.cos(a), top + 0.42 + 0.05 * rnd.random(), z + 0.02 + 0.1 * math.sin(a))
        b.tube([V(x + 0.16, top + 0.18, z + 0.02), tip], 0.004, Mat("plain", color=(0.55, 0.5, 0.36)), segments=3)
        b.sphere(tip, 0.03, Mat("plain", color=(0.82, 0.7, 0.55), glow=0.05), rings=3, segments=6)


# --- Haustypen ---

def fashion_shop(type_id="fashion_shop"):
    """Modegeschäft "Zwirn und Zwirbel" (Konzeptbild "fashionshop.png", leicht vintage):
    marineblaue Ladenfront mit verspielter Goldschrift und Faden-Kringel, gestreifte Markisen,
    Tür mit großer Scheibe in einer Nische, Ausleger-Schild mit Garnrolle, Hängekorb,
    links Hortensie in Zinkwanne, rechts Olivenbäumchen und Kreidetafel; Sandstein mit
    Eckquadern, Schiebefenster mit Blumenkästen, Zahnschnitt-Gesims, Ziergiebel, Gauben.
    Dahinter ein ganzer Ladenraum (siehe _shop_interior)."""
    d = house_dims(type_id)
    W, D, E, R = d["width"], d["depth"], d["eaves"], d["rise"]
    w = W / 2
    b = S.Builder(type_id)
    front_z = 0.25
    back_z = -D - 0.2

    party_walls(b, w, D, E, R, front_z, back_z)
    gable_roof(b, w, D, E, R, front_z, back_z)
    for side in (-1, 1):
        chimney(b, side * (w - 0.42), -D / 2, E + R - 0.6, E + R + 1.0)

    # --- Obergeschoss: Sandstein mit drei Fenstern und Blumenkästen ---
    shop_top = 3.62
    win_w, win_h, win_y = 0.9, 1.62, 4.18
    xs = [-1.7, 0.0, 1.7]
    reveal = 0.14
    holes = [(x - win_w / 2, win_y, x + win_w / 2, win_y + win_h) for x in xs]
    b.wall_with_holes(-w, w, 3.4, E, 0.0, holes, WALL_STONE, reveal=reveal)
    for k, x in enumerate(xs):
        sash_window(b, x, win_y, win_w, win_h, reveal)
        b.frame(x - win_w / 2, win_y, x + win_w / 2, win_y + win_h, 0.0, 0.05, 0.11, TRIM, bottom=False)
        b.box((x - win_w / 2 - 0.17, win_y - 0.09, 0), (x + win_w / 2 + 0.17, win_y, 0.12), TRIM)
        for cx in (x - win_w / 2 - 0.08, x + win_w / 2 + 0.08):
            b.box((cx - 0.05, win_y - 0.24, 0), (cx + 0.05, win_y - 0.09, 0.08), TRIM, skip=("back",))
        top = win_y + win_h + 0.11
        b.box((x - win_w / 2 - 0.11, top, 0), (x + win_w / 2 + 0.11, top + 0.14, 0.07), TRIM, skip=("back",))
        b.extrude_x([(0, top + 0.14), (0, top + 0.3), (0.16, top + 0.3), (0.16, top + 0.25), (0.08, top + 0.14)],
                    x - win_w / 2 - 0.22, x + win_w / 2 + 0.22, TRIM)
        b.box((x - 0.08, win_y + win_h - 0.04, 0.0), (x + 0.08, win_y + win_h + 0.2, 0.09), TRIM, skip=("back",))
        P.flower_box(b, x - 0.5, x + 0.5, win_y + 0.005, 0.0, 0.2, JOINERY,
                     [["rose", "white"], ["coral", "lavender"], ["white", "rose"]][k], seed=11 + k)
    b.box((-w, win_y - 0.2, 0), (w, win_y - 0.12, 0.05), TRIM, skip=("back",))
    y = shop_top + 0.06
    k = 0
    while y + 0.3 < E - 0.3:
        long_ = k % 2 == 0
        for side in (-1, 1):
            lo_x, hi_x = sorted((side * w, side * (w - (0.44 if long_ else 0.3))))
            b.box((lo_x, y, 0), (hi_x, y + 0.29, 0.035), TRIM, skip=("back",))
        y += 0.31
        k += 1
    b.cylinder(V(-w + 0.12, shop_top, 0.08), 0.04, E - shop_top + 0.05, LEAD, segments=8, caps=(True, True))

    # --- Traufgesims mit Zahnschnitt ---
    b.box((-w, E - 0.42, 0), (w, E - 0.28, 0.07), TRIM, skip=("back",))
    x = -w + 0.08
    while x + 0.06 < w:
        b.box((x, E - 0.28, 0.0), (x + 0.06, E - 0.18, 0.12), TRIM, skip=("back",))
        x += 0.13
    b.extrude_x([(0, E - 0.18), (0, E), (0.32, E), (0.32, E - 0.07), (0.22, E - 0.11), (0.15, E - 0.18)],
                -w - 0.02, w + 0.02, TRIM)
    b.cylinder(V(-w, E + 0.03, 0.27), 0.06, W, LEAD, segments=8, caps=(True, True), axis="x")

    # --- Ziergiebel mit Rosette (geschlossener Körper, Dach als Platten) ---
    pw = 1.0
    apex = E + 0.78
    zf = 0.08
    b.slab([V(-pw, E, zf), V(pw, E, zf), V(0, apex, zf)], 2.0, WALL_STONE)
    for side in (-1, 1):
        b.beam(V(side * (pw + 0.12), E - 0.02, 0.1), V(0, apex + 0.1, 0.1), 0.22, 0.13, TRIM)
        lo = V(side * (pw + 0.14), E + 0.08, 0.0)
        hi = V(0, apex + 0.2, 0.0)
        pts = [lo, hi, V(hi.x, hi.y, -1.9), V(lo.x, lo.y, -1.9)]
        b.slab(pts if side < 0 else pts[::-1], 0.05, SLATE)
    b.cylinder(V(0, E + 0.33, zf), 0.2, 0.05, TRIM, segments=20, axis="z")
    b.cylinder(V(0, E + 0.33, zf + 0.05), 0.15, 0.03, TRIM, segments=16, axis="z")
    for i in range(8):
        a = 2 * math.pi * i / 8
        b.sphere(V(0.09 * math.cos(a), E + 0.33 + 0.09 * math.sin(a), zf + 0.09), 0.03, TRIM, rings=3, segments=6)
    b.sphere(V(0, E + 0.33, zf + 0.09), 0.045, TRIM, rings=4, segments=8)

    for side in (-1, 1):
        dormer(b, side * 1.95, -0.7, E, R, front_z, D)

    # --- Ladenfront (Erdgeschoss) ---
    pil = 0.32
    fascia_lo, fascia_hi = 2.94, 3.45
    head = 2.84
    door_half = 0.62
    post = 0.1
    sill_y = 0.6
    transom = 2.3
    jz = 0.13
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * w, side * (w - pil)))
        b.box((lo_x, 0, 0), (hi_x, fascia_hi, 0.16), JOINERY, skip=("back",))
        b.box((lo_x - 0.02, 0, 0), (hi_x + 0.02, 0.32, 0.19), JOINERY, skip=("back", "bottom"))
        b.box((lo_x + 0.04, 0.5, 0.16), (hi_x - 0.04, 2.4, 0.18), JOINERY, skip=("back", "bottom"))
        b.box((lo_x - 0.02, fascia_lo - 0.18, 0), (hi_x + 0.02, fascia_hi + 0.05, 0.26), JOINERY, skip=("back",))
        b.box((lo_x + 0.02, fascia_lo - 0.34, 0), (hi_x - 0.02, fascia_lo - 0.18, 0.21), JOINERY, skip=("back",))
        b.cylinder(V(lo_x + 0.02, fascia_lo + 0.12, 0.2), 0.08, hi_x - lo_x - 0.04, GOLD, segments=10, caps=(True, True), axis="x")
    # Ladenschild: die Vorderseite zeigt ein Bild (assets/textures/signs/fashion_shop_fascia.png,
    # Startbild = fascia_design) – zum selbst Gestalten austauschbar
    b.box((-w + pil, fascia_lo, 0), (w - pil, fascia_hi, 0.2), JOINERY, skip=("back", "front"))
    b.poly([V(-w + pil, fascia_lo, 0.2), V(w - pil, fascia_lo, 0.2), V(w - pil, fascia_hi, 0.2), V(-w + pil, fascia_hi, 0.2)],
           Mat("plain", sign="fascia"), uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    # Gesims über dem Schild
    b.extrude_x([(0, fascia_hi), (0, shop_top), (0.3, shop_top), (0.3, fascia_hi + 0.1), (0.22, fascia_hi + 0.05), (0.2, fascia_hi)],
                -w - 0.03, w + 0.03, JOINERY)
    b.box((-w - 0.03, shop_top, 0), (w + 0.03, shop_top + 0.02, 0.31), LEAD, skip=("back",))
    b.box((-w + pil, head, 0), (w - pil, fascia_lo, jz), JOINERY, skip=("back",))
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * door_half, side * (door_half + post)))
        b.box((lo_x, 0, 0), (hi_x, head, jz), JOINERY, skip=("back", "top"))
    win_x0 = w - pil
    win_x1 = door_half + post
    windows = []
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * win_x0, side * win_x1))
        windows.append((lo_x, hi_x, sill_y + 0.02, head))
        b.box((lo_x, 0, 0), (hi_x, sill_y - 0.05, 0.11), JOINERY, skip=("back",))
        b.frame(lo_x + 0.12, 0.12, hi_x - 0.12, sill_y - 0.17, 0.11, 0.13, 0.03, JOINERY)
        b.box((lo_x - 0.01, sill_y - 0.05, 0), (hi_x + 0.01, sill_y + 0.02, 0.17), JOINERY, skip=("back",))
        b.box((lo_x, transom, 0), (hi_x, transom + 0.08, jz), JOINERY)
        b.box((lo_x, sill_y + 0.02, -0.03), (lo_x + 0.05, head, jz - 0.02), JOINERY, skip=("top", "bottom"))
        b.box((hi_x - 0.05, sill_y + 0.02, -0.03), (hi_x, head, jz - 0.02), JOINERY, skip=("top", "bottom"))
        gz = 0.06
        b.quad(V(lo_x, sill_y + 0.02, gz), V(hi_x, sill_y + 0.02, gz), V(hi_x, head, gz), V(lo_x, head, gz), CLEAR_GLASS)
        cx = (lo_x + hi_x) / 2
        span = hi_x - lo_x - 0.1
        for i in range(1, 4):
            bx = lo_x + 0.05 + span * i / 4
            b.box((bx - 0.012, transom + 0.08, gz - 0.02), (bx + 0.012, head, jz - 0.03), JOINERY)
        _arch_bar(b, cx, transom + 0.08, span / 2, head - transom - 0.13, gz, jz - 0.03)
        _awning(b, lo_x - 0.02, hi_x + 0.02, head, 0.15, 0.95, 0.5)
    _recessed_door(b, door_half, transom, head, jz)

    # --- Ladenraum dahinter ---
    _shop_interior(b, w - 0.12, 0.1, 3.3, -0.03, -6.0, windows, door_half)

    # --- Vor dem Laden: links Hortensie, rechts Olivenbäumchen und Kreidetafel ---
    P.hydrangea_tub(b, -(door_half + 0.5), 0.42, seed=21)
    P.olive_tree(b, door_half + 0.46, 0.38, seed=22)
    P.chalkboard(b, 1.78, 0.5, Mat("plain", sign="chalkboard"), facing=-12)
    # Ausleger-Schild rechts (zur Bücherei hin), Hängekorb links – über dem Ladengesims an den
    # Eckquadern, also oberhalb der Markisen
    P.projecting_sign(b, w - 0.2, 4.32, 0.035, JOINERY, Mat("plain", sign="hanging"))
    P.hanging_basket(b, -(w - 0.2), 4.38, 0.035, 0.55, seed=25)
    return b, _fashion_props()


# --- Reihenhäuser und Wohnhaus (Etappe 4g, Teil 2) ---

WALL = Mat("brick", "wall")
PLINTH = Mat("render", color=(0.4, 0.38, 0.36))


def _columns(width, count):
    return [-width / 2 + width * (i + 0.5) / count for i in range(count)]


def _door_column(door_side, count):
    return {-1: 0, 1: count - 1, 2: count // 2}.get(door_side, -1)


def _window_hole(x, y0, w, h):
    return (x - w / 2, y0, x + w / 2, y0 + h)


def plain_window(b, x, y0, w, h, lintel="stone", sill=True, reveal=0.13, panes=(2, 2)):
    """Schiebefenster in der Fassade (Loch kommt von der Wand) mit Sohlbank und Sturz."""
    sash_window(b, x, y0, w, h, reveal, panes=panes)
    x0, x1 = x - w / 2, x + w / 2
    if sill:
        b.box((x0 - 0.08, y0 - 0.08, 0), (x1 + 0.08, y0, 0.09), TRIM)
    top = y0 + h
    if lintel == "stone":
        b.box((x0 - 0.1, top, 0), (x1 + 0.1, top + 0.2, 0.03), TRIM, skip=("back",))
    elif lintel == "key":
        b.box((x0 - 0.12, top, 0), (x1 + 0.12, top + 0.2, 0.03), TRIM, skip=("back",))
        b.box((x - 0.07, top - 0.03, 0), (x + 0.07, top + 0.24, 0.06), TRIM, skip=("back",))
    elif lintel == "arch":
        # Flacher Bogen aus hochkant gestellten Steinen (in Steinfarbe)
        n = max(5, int((w + 0.2) / 0.075))
        for k in range(n):
            t = (k + 0.5) / n
            bx = x0 - 0.1 + (w + 0.2) * t
            lift = 0.05 * math.sin(math.pi * t)
            b.box((bx - 0.032, top + lift, 0), (bx + 0.032, top + lift + 0.22, 0.02), TRIM, skip=("back",))
    elif lintel == "architrave":
        b.frame(x0, y0, x1, top, 0.0, 0.04, 0.1, TRIM, bottom=False)
        b.box((x0 - 0.1, top + 0.1, 0), (x1 + 0.1, top + 0.24, 0.05), TRIM, skip=("back",))
        b.extrude_x([(0, top + 0.24), (0, top + 0.34), (0.12, top + 0.34), (0.12, top + 0.3), (0.06, top + 0.24)],
                    x0 - 0.18, x1 + 0.18, TRIM)


def front_door(b, x, style="simple", reveal=0.13, width=1.0, height=2.15):
    """Haustür in einer Laibung: Stufe, Rahmen, Kassettentür (Türfarbe), Oberlicht mit Sprossen,
    Messing-Klopfer und Briefschlitz. style: simple (Steinsturz), pilaster (Säulchen und Gebälk)."""
    hw = width / 2
    fan = 0.42
    top = height + fan
    z = -reveal
    b.box((x - hw, 0, z), (x + hw, 0.14, 0.0), TRIM, skip=("back",))
    f = 0.07
    b.box((x - hw, 0.14, z), (x - hw + f, top, z + 0.06), WHITE)
    b.box((x + hw - f, 0.14, z), (x + hw, top, z + 0.06), WHITE)
    b.box((x - hw + f, top - f, z), (x + hw - f, top, z + 0.06), WHITE, skip=("left", "right"))
    b.box((x - hw + f, height, z), (x + hw - f, height + 0.06, z + 0.06), WHITE, skip=("left", "right"))
    # Türblatt mit vier Füllungen
    dx0, dx1 = x - hw + f, x + hw - f
    b.box((dx0, 0.14, z - 0.02), (dx1, height, z + 0.03), JOINERY, skip=("back",))
    for (py0, py1) in ((0.3, 0.95), (1.1, height - 0.15)):
        for (px0, px1) in ((dx0 + 0.08, x - 0.04), (x + 0.04, dx1 - 0.08)):
            b.frame(px0, py0, px1, py1, z + 0.03, z + 0.045, 0.025, JOINERY)
    b.box((x - 0.12, 1.0, z + 0.03), (x + 0.12, 1.04, z + 0.042), GOLD)
    b.cylinder(V(x, 1.5, z + 0.03), 0.035, 0.015, GOLD, segments=10, axis="z", caps=(True, True))
    b.sphere(V(dx1 - 0.08, 1.02, z + 0.06), 0.028, GOLD, rings=4, segments=8)
    # Oberlicht
    gy0 = height + 0.06
    b.quad(V(dx0, gy0, z + 0.01), V(dx1, gy0, z + 0.01), V(dx1, top - f, z + 0.01), V(dx0, top - f, z + 0.01), DARK_GLASS)
    for k in range(1, 4):
        bx = dx0 + (dx1 - dx0) * k / 4
        b.box((bx - 0.012, gy0, z + 0.01), (bx + 0.012, top - f, z + 0.04), WHITE)
    if style == "simple":
        b.box((x - hw - 0.12, top, 0), (x + hw + 0.12, top + 0.22, 0.04), TRIM, skip=("back",))
    elif style == "pilaster":
        for side in (-1, 1):
            px = x + side * (hw + 0.1)
            b.box((px - 0.09, 0, 0), (px + 0.09, top, 0.09), WHITE, skip=("back",))
            b.box((px - 0.11, 0, 0), (px + 0.11, 0.25, 0.11), WHITE, skip=("back",))
            b.box((px - 0.11, top - 0.12, 0), (px + 0.11, top, 0.11), WHITE, skip=("back",))
        b.box((x - hw - 0.24, top, 0), (x + hw + 0.24, top + 0.2, 0.1), WHITE, skip=("back",))
        b.extrude_x([(0, top + 0.2), (0, top + 0.32), (0.18, top + 0.32), (0.18, top + 0.28), (0.12, top + 0.2)],
                    x - hw - 0.3, x + hw + 0.3, WHITE)
    return (x - hw, 0.0, x + hw, top)


def bay_window(b, cx, width, depth, height, solid_colliders=True):
    """Erker im Erdgeschoss: drei Fensterseiten (vorn und zwei schräge), Brüstung in Wandfarbe,
    Gesims und kleines Bleidach."""
    hw = width / 2
    side = depth  # 45°
    pts = [(cx - hw - side, 0.0), (cx - hw, depth), (cx + hw, depth), (cx + hw + side, 0.0)]
    sill = 0.75
    head = height - 0.35
    for i in range(3):
        (ax, az), (bx, bz) = pts[i], pts[i + 1]
        a, c = V(ax, 0, az), V(bx, 0, bz)
        along = (c - a)
        ln = along.length
        along.normalize()
        n = V(-along.z, 0, along.x)
        b.push(S.Matrix.Translation(a) @ S.Matrix(((along.x, 0, n.x, 0), (0, 1, 0, 0), (along.z, 0, n.z, 0), (0, 0, 0, 1))))
        b.box((0, 0, -0.02), (ln, sill, 0.0), WALL, skip=("back",))
        b.box((-0.02, sill, -0.02), (ln + 0.02, sill + 0.06, 0.06), TRIM, skip=("back",))
        wpad = 0.07
        b.quad(V(wpad, sill + 0.06, -0.06), V(ln - wpad, sill + 0.06, -0.06), V(ln - wpad, head, -0.06), V(wpad, head, -0.06), DARK_GLASS)
        cw = (ln - 2 * wpad) * 0.22
        for c0, c1 in ((wpad, wpad + cw), (ln - wpad - cw, ln - wpad)):
            b.quad(V(c0, sill + 0.1, -0.052), V(c1, sill + 0.1, -0.052), V(c1, head, -0.052), V(c0, head, -0.052), CURTAIN)
        b.box((0, sill + 0.06, -0.06), (wpad, head, 0.0), WHITE, skip=("back",))
        b.box((ln - wpad, sill + 0.06, -0.06), (ln, head, 0.0), WHITE, skip=("back",))
        mid = sill + 0.06 + (head - sill - 0.06) * 0.55
        b.box((wpad, mid - 0.03, -0.06), (ln - wpad, mid + 0.03, -0.01), WHITE, skip=("back",))
        b.glazing_bars(wpad, mid + 0.03, ln - wpad, head, -0.06, -0.035, 2, 1, 0.02, WHITE)
        b.box((0, head, -0.02), (ln, height, 0.0), WHITE, skip=("back",))
        b.pop()
    # Ecksäulchen, damit die schrägen Seiten sauber zusammenstoßen
    for px, pz in pts[1:3]:
        b.cylinder(V(px, 0, pz), 0.05, height, WHITE, segments=8, caps=(False, True))
    # Dach: Gesims-Kante und flaches Bleidach (geschlossene Platte)
    over = 0.06
    roof = [V(pts[0][0] - over, height, 0.0), V(pts[1][0] - over * 0.4, height, pts[1][1] + over),
            V(pts[2][0] + over * 0.4, height, pts[2][1] + over), V(pts[3][0] + over, height, 0.0)]
    b.slab([V(p.x, p.y + 0.08, p.z) for p in reversed(roof)][::-1], 0.08, WHITE)
    peak = [V(p.x, height + 0.08, p.z) for p in roof]
    top = [V(pts[0][0] + 0.15, height + 0.32, 0.0), V(pts[1][0] + 0.1, height + 0.32, pts[1][1] - 0.2),
           V(pts[2][0] - 0.1, height + 0.32, pts[2][1] - 0.2), V(pts[3][0] - 0.15, height + 0.32, 0.0)]
    for i in range(3):
        b.poly([peak[i], peak[i + 1], top[i + 1], top[i]], LEAD)
    b.poly([top[0], top[1], top[2], top[3]], LEAD)
    for i in range(3):
        (ax, az), (bx2, bz) = pts[i], pts[i + 1]
        b.colliders.append(((min(ax, bx2), 0, 0), (max(ax, bx2), 1.0, max(az, bz))))


def parapet(b, w, eaves, height=0.55):
    """Brüstung vor dem Dach (georgianisch): Wand über die Traufe hinaus mit Abdeckstein."""
    b.box((-w, eaves, -0.36), (w, eaves + height, 0.0), WALL, skip=("top",))
    b.box((-w - 0.02, eaves + height, -0.38), (w + 0.02, eaves + height + 0.07, 0.05), TRIM)
    b.box((-w, eaves - 0.25, 0), (w, eaves - 0.1, 0.06), TRIM, skip=("back",))


def eaves_band(b, w, eaves, style):
    """Traufe: dentil = kleine Steinkonsolen, cornice = Steingesims; dazu Traufbrett und Rinne."""
    if style == "dentil":
        x = -w + 0.06
        while x + 0.08 < w:
            b.box((x, eaves - 0.2, 0), (x + 0.08, eaves - 0.08, 0.08), TRIM, skip=("back",))
            x += 0.18
        # Traufbrett so tief wie der Dachüberstand (sonst sieht man unter das Dach)
        b.box((-w, eaves - 0.08, 0), (w, eaves, 0.28), TRIM, skip=("back",))
    else:
        b.extrude_x([(0, eaves - 0.25), (0, eaves), (0.26, eaves), (0.26, eaves - 0.07), (0.16, eaves - 0.13), (0.1, eaves - 0.25)],
                    -w - 0.01, w + 0.01, TRIM)
    b.cylinder(V(-w, eaves + 0.03, 0.22), 0.055, 2 * w, LEAD, segments=8, caps=(True, True), axis="x")


def porch(b, x, door_rect, depth=0.75):
    """Vordach auf zwei Säulen mit kleinem Giebel (Wohnhaus)."""
    x0, _, x1, top = door_rect
    hw = (x1 - x0) / 2 + 0.35
    y = top + 0.15
    for side in (-1, 1):
        cx = x + side * (hw - 0.1)
        b.box((cx - 0.13, 0, depth - 0.23), (cx + 0.13, 0.25, depth + 0.03), TRIM)
        b.cylinder(V(cx, 0.25, depth - 0.1), 0.08, y - 0.45, WHITE, segments=12, radius_top=0.07)
        b.box((cx - 0.11, y - 0.2, depth - 0.21), (cx + 0.11, y, depth + 0.01), WHITE)
        b.colliders.append(((cx - 0.14, 0, depth - 0.24), (cx + 0.14, 2.2, depth + 0.04)))
    b.box((x - hw - 0.05, y, -0.02), (x + hw + 0.05, y + 0.25, depth + 0.08), WHITE, skip=("back",))
    apex = y + 0.25 + 0.45
    b.slab([V(x - hw - 0.08, y + 0.25, depth + 0.1), V(x + hw + 0.08, y + 0.25, depth + 0.1), V(x, apex, depth + 0.1)], depth + 0.1, WHITE)
    for side in (-1, 1):
        lo = V(x + side * (hw + 0.12), y + 0.22, depth + 0.14)
        hi = V(x, apex + 0.05, depth + 0.14)
        pts = [lo, hi, V(hi.x, hi.y, -0.02), V(lo.x, lo.y, -0.02)]
        b.slab(pts if side < 0 else pts[::-1], 0.05, SLATE)


def small_pot(b, x, z, palette, seed, tall=False):
    """Kleiner Topf neben der Haustür (Lavendel oder Buchs)."""
    import random
    rnd = random.Random(seed)
    h = 0.42 if tall else 0.28
    b.cylinder(V(x, 0, z), 0.13, h, POT, segments=12, radius_top=0.16, caps=(False, True))
    if palette:
        b.sphere(V(x, h + 0.12, z), 0.16, P.leaf(seed), rings=5, segments=10, squash=0.8, jitter=0.12, seed=seed)
        P.blossom_cluster(b, (x, h + 0.13, z), 0.15, palette, rnd, count=10)
    else:
        b.cylinder(V(x, h, z), 0.12, 0.5, P.leaf(seed), segments=10, radius_top=0.02, caps=(True, True))
    b.colliders.append(((x - 0.17, 0, z - 0.17), (x + 0.17, 0.6, z + 0.17)))


TERRACES = {
    # door_style, ground ("windows"/"bay"), lintel, eaves, extras
    "terrace_45": dict(door_style="simple", ground="windows", lintel="key", eaves="dentil", boxes=[1, 1], pot="lavender"),
    "terrace_50": dict(door_style="simple", ground="bay", lintel="architrave", eaves="cornice", boxes=[0, 1], pot=None),
    "terrace_55": dict(door_style="pilaster", ground="windows", lintel="architrave", eaves="parapet", boxes=[0, 0, 0], pot="box",
                       tall=True),
    "terrace_60": dict(door_style="simple", ground="windows", lintel="arch", eaves="dentil", boxes=[1, 0, 1], pot="rose",
                       dormer=True),
    "residential": dict(door_style="porch", ground="windows", lintel="architrave", eaves="cornice", boxes=[1, 0, 1], pot="pair"),
}


def terrace(type_id, side_windows=0):
    """Reihenhaus bzw. Wohnhaus im Stil. Maße, Türseite und Fensterspalten aus der Haustyp-Szene;
    Wände in Wandfarbe (Material je Haus wählbar: HouseFacade.wall_material)."""
    spec = TERRACES[type_id]
    d = house_dims(type_id)
    text = open(os.path.join(HOUSE_DIR, type_id + ".tscn")).read()
    door_side = int(re.search(r"^door_side = (-?\d+)", text, re.M).group(1)) if re.search(r"^door_side", text, re.M) else 1
    cols_m = re.search(r"^window_columns = (\d+)", text, re.M)
    has_chimney = not re.search(r"^chimney = false", text, re.M)
    W, D, E, R = d["width"], d["depth"], d["eaves"], d["rise"]
    w = W / 2
    cols = int(cols_m.group(1)) if cols_m else max(1, int(W / 1.7))
    b = S.Builder(type_id if not side_windows else "%s_side" % type_id)
    # Mit Brüstung beginnt das Dach erst dahinter
    front_z = -0.34 if spec["eaves"] == "parapet" else 0.25
    back_z = -D - 0.2
    party_walls(b, w, D, E, R, front_z, back_z, open_sides=(-1, 1) if side_windows == 2 else (side_windows,))
    gable_roof(b, w, D, E, R, front_z, back_z)
    if has_chimney:
        chimney(b, (w - 0.36) * (1 if door_side != 1 else -1), -D / 2, E + R - 0.6, E + R + 0.9)
    storey = E / 2
    xs = _columns(W, cols)
    door_col = _door_column(door_side, cols)
    tall = spec.get("tall", False)
    win_w = 0.92 if cols >= 3 else 1.0
    g_y0, g_h = 0.8, min(1.85 if tall else 1.65, storey - 1.3)
    f_y0 = storey + (0.55 if tall else 0.7)
    f_h = min(1.95 if tall else 1.6, E - f_y0 - (0.75 if spec["eaves"] == "parapet" else 0.6))
    holes = []
    door_rect = None
    if door_col >= 0:
        door_rect = (xs[door_col] - 0.5, 0.0, xs[door_col] + 0.5, 2.15 + 0.42)
        holes.append(door_rect)
    bay = spec["ground"] == "bay"
    for i, x in enumerate(xs):
        if i != door_col and not bay:
            holes.append(_window_hole(x, g_y0, win_w, g_h))
        holes.append(_window_hole(x, f_y0, win_w, f_h))
    # Fassade mit Sockel und Gurtgesims
    b.wall_with_holes(-w, w, 0.0, E, 0.0, holes, WALL, reveal=0.13)
    b.box((-w, 0, 0), (w, 0.32, 0.03), PLINTH, skip=("back", "bottom"))
    b.box((-w, storey - 0.05, 0), (w, storey + 0.07, 0.05), TRIM, skip=("back",))
    for i, x in enumerate(xs):
        if i == door_col:
            continue
        if not bay:
            plain_window(b, x, g_y0, win_w, g_h, lintel=spec["lintel"])
    for i, x in enumerate(xs):
        plain_window(b, x, f_y0, win_w, f_h, lintel=spec["lintel"], panes=(2, 3) if tall else (2, 2))
        if spec["boxes"][i % len(spec["boxes"])]:
            P.flower_box(b, x - 0.48, x + 0.48, f_y0 + 0.005, 0.0, 0.19, JOINERY,
                         [["rose", "white"], ["lavender", "white"], ["coral", "rose"]][i % 3], seed=zlib.crc32(type_id.encode()) % 97 + i)
    if bay:
        bx = [x for i, x in enumerate(xs) if i != door_col][0]
        # Erker vor einer zugemauerten Fläche (das Loch fehlt absichtlich)
        bay_window(b, bx, 1.1, 0.45, storey - 0.25)
    if door_rect:
        style = spec["door_style"]
        front_door(b, xs[door_col], "simple" if style == "porch" else style)
        if style == "porch":
            porch(b, xs[door_col], door_rect)
    # Traufe
    if spec["eaves"] == "parapet":
        parapet(b, w, E)
    else:
        eaves_band(b, w, E, spec["eaves"])
    b.cylinder(V(w - 0.12 if door_side != 1 else -w + 0.12, 0.0, 0.07), 0.04, E + 0.05, LEAD, segments=8, caps=(True, True))
    if spec.get("dormer"):
        dormer(b, 0.0, -0.7, E, R, front_z, D, gw=0.5)
    # Töpfe an der Haustür (nur dekorativ, mit Kollision)
    if door_rect and spec.get("pot"):
        dx = xs[door_col]
        pot = spec["pot"]
        if pot == "pair":
            for s2 in (-1, 1):
                small_pot(b, dx + s2 * 0.95, 0.3, None, seed=31 + s2, tall=True)
        elif pot == "box":
            small_pot(b, dx + (0.85 if door_side == -1 else -0.85), 0.25, None, seed=33, tall=True)
        else:
            small_pot(b, dx + (0.78 if door_side == -1 else -0.78), 0.22, pot, seed=34)
    if side_windows:
        _side_wall_windows(b, w, D, E, storey, side_windows)
    return b


def _side_wall_windows(b, w, depth, eaves, storey, side):
    """Fenster in der freien Seitenwand eines Endhauses (Variante <typ>_side_left/right)."""
    for s2 in ((-1, 1) if side == 2 else (side,)):
        b.push(b.move(s2 * (w + 0.002), 0, -depth / 2) @ b.turn_y(90 * s2))
        holes = []
        for y0, h in ((0.8, 1.5), (storey + 0.7, 1.45)):
            for zc in (-depth / 4, depth / 4):
                holes.append(_window_hole(zc, y0, 0.9, h))
        b.wall_with_holes(-depth / 2, depth / 2, 0.0, eaves, 0.0, holes, WALL, reveal=0.12)
        for x0, y0, x1, y1 in holes:
            plain_window(b, (x0 + x1) / 2, y0, x1 - x0, y1 - y0, lintel="stone", reveal=0.12)
        b.pop()


# --- Requisiten im Laden (Puppen, Kleidung): eigene Szenen, austauschbar ---

VINTAGE = {
    "mustard": (0.74, 0.58, 0.28), "teal": (0.24, 0.42, 0.42), "rose": (0.74, 0.5, 0.5),
    "cream": (0.86, 0.8, 0.68), "bottle": (0.22, 0.34, 0.26), "rust": (0.62, 0.32, 0.22),
    "navy": (0.2, 0.24, 0.36), "plum": (0.44, 0.26, 0.34), "heather": (0.58, 0.56, 0.6),
}


def _fashion_props():
    """Liste (Szene, Lage x/y/z, Drehung in Grad, Farbe) – wird zu fashion_shop_interior.tscn."""
    v = VINTAGE
    props = [
        ("mannequin_dress", (-1.95, 0.6, -0.42), 18, v["mustard"]),
        ("mannequin_coat", (-1.15, 0.6, -0.5), -12, v["teal"]),
        ("mannequin_coat", (1.15, 0.6, -0.5), 12, v["rust"]),
        ("mannequin_dress", (1.95, 0.6, -0.42), -18, v["rose"]),
        ("mannequin_dress", (-1.25, 0.1, -2.6), 35, v["bottle"]),
    ]
    order = ["plum", "cream", "teal", "mustard", "heather", "rose", "navy", "rust", "bottle", "cream", "plum"]
    z = -1.3
    k = 0
    while z > -4.25:
        props.append(("garment_dress" if k % 3 != 1 else "garment_blouse", (-2.2, 1.85, z), 0, v[order[k % len(order)]]))
        z -= 0.27
        k += 1
    z = -1.3
    while z > -3.1:
        props.append(("garment_blouse" if k % 2 else "garment_dress", (2.2, 1.85, z), 0, v[order[k % len(order)]]))
        z -= 0.3
        k += 1
    return props


def write_interior_scene(type_id, props):
    """Schreibt scenes/world/houses/<typ>_interior.tscn mit allen Requisiten."""
    scenes = sorted({p[0] for p in props})
    ids = {name: "%d_%s" % (i + 1, name) for i, name in enumerate(scenes)}
    lines = ['[gd_scene load_steps=%d format=3]' % (len(scenes) + 1), "",
             "; Requisiten im Laden (Etappe 4g): erzeugt von tools/blender/build_houses.py – wird beim",
             "; Neubau überschrieben. Jede Puppe/jedes Kleidungsstück ist eine eigene Szene aus",
             "; scenes/world/props/ (Farbe im Inspektor: Color). Später ersetzt ein eigenes Modell den",
             "; Knoten \"Outfit\" (Puppe) bzw. \"Model\" (hängendes Teil).", ""]
    for name in scenes:
        lines.append('[ext_resource type="PackedScene" path="res://scenes/world/props/%s.tscn" id="%s"]' % (name, ids[name]))
    lines += ["", '[node name="Interior" type="Node3D"]', ""]
    counts = {}
    for name, (x, y, z), yaw, color in props:
        counts[name] = counts.get(name, 0) + 1
        a = math.radians(yaw)
        c, s = math.cos(a), math.sin(a)
        lines.append('[node name="%s%d" parent="." instance=ExtResource("%s")]' % (
            "".join(part.capitalize() for part in name.split("_")), counts[name], ids[name]))
        lines.append("transform = Transform3D(%.5f, 0, %.5f, 0, 1, 0, %.5f, 0, %.5f, %.3f, %.3f, %.3f)" % (c, -s, s, c, x, y, z))
        lines.append("color = Color(%.3f, %.3f, %.3f, 1)" % color)
        lines.append("")
    path = os.path.join(HOUSE_DIR, type_id + "_interior.tscn")
    with open(path, "w") as f:
        f.write("\n".join(lines))


# --- Schilder zum selbst Gestalten ---
# Jedes Schild ist eine Fläche mit eigenem Bild: assets/textures/signs/<typ>_<name>.png
# (Material assets/materials/signs/<typ>_<name>.tres). Fehlt das Bild, rendert das Script ein
# Startbild aus der Gestaltung unten. Vorhandene Bilder werden NIE überschrieben (eigene
# Gestaltung bleibt) – außer mit --reset-signs.
FASCIA = (4.76, 0.51)
OPEN_SIGN = (0.26, 0.11)
NAVY = (0.1, 0.13, 0.21)


def _fascia_design(b):
    """Startbild des Ladenschilds: Marineblau, Goldrand, verspielte Schrift mit Faden-Kringel
    und Nadel – Schrift samt Verzierung genau in der Mitte."""
    fw, fh = FASCIA
    board = Mat("paint", color=NAVY)
    b.box((-fw / 2, -fh / 2, -0.02), (fw / 2, fh / 2, 0.0), board)
    for y0 in (-fh / 2 + 0.035, fh / 2 - 0.05):
        b.box((-fw / 2 + 0.06, y0, 0.0), (fw / 2 - 0.06, y0 + 0.015, 0.01), GOLD)
    for x in (-fw / 2 + 0.06, fw / 2 - 0.075):
        b.box((x, -fh / 2 + 0.035, 0.0), (x + 0.015, fh / 2 - 0.035, 0.01), GOLD)
    start = len(b.faces)
    text_w = b.playful_text("Zwirn und Zwirbel", 0.0, 0.0, 0.0, 0.3, 0.022, GOLD,
                            font_path=S.PLAYFUL_FONT, seed=7, bounce=0.07, tilt=5, first_scale=1.3)
    tail_x = text_w / 2 + 0.03
    P.thread_spiral(b, (tail_x, 0.01), 0.1, 1.6, GOLD, 0.012, thickness=0.008)
    b.beam(V(tail_x + 0.22, -0.01, 0.012), V(tail_x + 0.36, 0.27, 0.012), 0.016, 0.01, GOLD)
    b.tube([V(tail_x + 0.03, -0.02, 0.012), V(tail_x + 0.14, -0.04, 0.012), V(tail_x + 0.24, 0.02, 0.012),
            V(tail_x + 0.33, 0.22, 0.012)], 0.006, GOLD, segments=4)
    b.recenter(start, 0.0, 0.0)


def _open_design(b):
    cw, ch = OPEN_SIGN
    b.box((-cw / 2, -ch / 2, -0.01), (cw / 2, ch / 2, 0.0), Mat("plain", color=(0.93, 0.9, 0.82)))
    start = len(b.faces)
    b.playful_text("Geöffnet", 0.0, 0.0, 0.0, 0.05, 0.002, Mat("paint", color=NAVY), font_path=S.PLAYFUL_FONT,
                   seed=3, bounce=0.05, tilt=3)
    b.recenter(start, 0.0, 0.0)


def _flower_fascia_design(b):
    """Startbild des Blumenladen-Schilds: helles Holz, cremefarbene Schrift, Blütenranken."""
    fw, fh = 4.76, 0.43
    b.box((-fw / 2, -fh / 2, -0.02), (fw / 2, fh / 2, 0.0), Mat("timber", color=(1, 1, 1)))
    b.box((-fw / 2 + 0.05, -fh / 2 + 0.04, 0.0), (fw / 2 - 0.05, fh / 2 - 0.04, 0.004), Mat("paint", color=(0.42, 0.52, 0.42)))
    start = len(b.faces)
    b.playful_text("Blumenladen", 0.0, 0.0, 0.004, 0.24, 0.015, Mat("paint", color=(0.93, 0.9, 0.82)), font_path=S.PLAYFUL_FONT,
                   seed=11, bounce=0.06, tilt=4, first_scale=1.25)
    b.recenter(start, 0.0, 0.0)
    import random
    rnd = random.Random(4)
    for side in (-1, 1):
        for k in range(5):
            P.blossom_cluster(b, (side * (1.75 + k * 0.1), -0.02 + 0.06 * math.sin(k), 0.01), 0.05, rnd.choice(["rose", "white", "lavender"]), rnd, count=4, size=0.03)


SIGNS = {
    "flower_shop": {
        "fascia": (4.76, 0.43, 2048, _flower_fascia_design),
        "chalkboard": (P.CHALKBOARD_SIZE[0], P.CHALKBOARD_SIZE[1], 360, lambda b: P.chalkboard_design(b, ["Frisch:", "Tulpen", "& Rosen"], 41)),
    },
    "fashion_shop": {
        # Name: (Breite, Höhe in Metern, Bildbreite in Pixeln, Gestaltung)
        "fascia": (FASCIA[0], FASCIA[1], 2048, _fascia_design),
        "hanging": (P.HANGING_SIGN[0], P.HANGING_SIGN[1], 512,
                    lambda b: P.hanging_sign_design(b, Mat("paint", color=NAVY), Mat("plain", color=(0.82, 0.52, 0.56)))),
        "chalkboard": (P.CHALKBOARD_SIZE[0], P.CHALKBOARD_SIZE[1], 360, lambda b: P.chalkboard_design(b, ["Neu:", "Herbst-", "mode"], 23)),
        "open": (OPEN_SIGN[0], OPEN_SIGN[1], 360, _open_design),
    },
}
SIGN_TEX_DIR = os.path.join(S.ROOT, "assets", "textures", "signs")
SIGN_MAT_DIR = os.path.join(S.ROOT, "assets", "materials", "signs")


def prepare_signs(type_id, reset=False):
    """Startbilder rendern (nur wenn sie fehlen) und Godot-Materialien anlegen. Liefert
    {Name: res-Pfad des Materials} für die Importeinstellungen."""
    out = {}
    os.makedirs(SIGN_TEX_DIR, exist_ok=True)
    os.makedirs(SIGN_MAT_DIR, exist_ok=True)
    for name, (width, height, pixels, design) in SIGNS.get(type_id, {}).items():
        base = "%s_%s" % (type_id, name)
        png = os.path.join(SIGN_TEX_DIR, base + ".png")
        if reset or not os.path.exists(png):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            b = S.Builder(base)
            design(b)
            S.to_blender(b, {})
            _sign_lighting()
            S.render_ortho(png, width, height, pixels)
            print("Startbild:", png)
        tres = os.path.join(SIGN_MAT_DIR, base + ".tres")
        if not os.path.exists(tres):
            with open(tres, "w") as f:
                f.write("""[gd_resource type="StandardMaterial3D" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/textures/signs/%s.png" id="1_image"]

[resource]
resource_name = "sign_%s"
albedo_texture = ExtResource("1_image")
roughness = 0.6
texture_filter = 5
""" % (base, name))
        out[name] = "res://assets/materials/signs/%s.tres" % base
    return out


def _sign_lighting():
    """Weiches, gleichmäßiges Licht für die Startbilder (Farben bleiben, wie sie sind)."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Flat")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.8, 0.78, 0.74, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 1.2
    sun_data.angle = math.radians(20)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(60), 0, math.radians(-30))
    scene.collection.objects.link(sun)


TERRACE_PREVIEW = {"wall": (0.58, 0.33, 0.26), "door": (0.16, 0.32, 0.24), "accent": (0.16, 0.3, 0.22)}
HOUSES = {
    "fashion_shop": (fashion_shop, {"wall": (0.9, 0.86, 0.8), "door": (0.1, 0.13, 0.21), "accent": (0.17, 0.2, 0.3)}),
    "terrace_45": (lambda: terrace("terrace_45"), TERRACE_PREVIEW),
    "terrace_50": (lambda: terrace("terrace_50"), dict(TERRACE_PREVIEW, door=(0.5, 0.12, 0.14))),
    "terrace_55": (lambda: terrace("terrace_55"), dict(TERRACE_PREVIEW, door=(0.08, 0.08, 0.09))),
    "terrace_55_side_left": (lambda: terrace("terrace_55", side_windows=-1), dict(TERRACE_PREVIEW, door=(0.08, 0.08, 0.09))),
    "terrace_60": (lambda: terrace("terrace_60"), dict(TERRACE_PREVIEW, door=(0.62, 0.5, 0.2))),
    "residential": (lambda: terrace("residential"), dict(TERRACE_PREVIEW, door=(0.18, 0.28, 0.42))),
}


def build(type_id, render, reset_signs=False):
    func, preview_colors = HOUSES[type_id]
    signs = prepare_signs(type_id, reset_signs)
    S.SIGN_PREFIX = type_id + "_"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    result = func()
    b, props = result if isinstance(result, tuple) else (result, [])
    glb = os.path.join(S.ROOT, "assets", "models", "houses", type_id + ".glb")
    tris = S.write_glb(b, glb)
    S.write_import_settings(glb, signs)
    print("%s: %d Dreiecke -> %s" % (type_id, tris, glb))
    if props:
        write_interior_scene(type_id, props)
    S.to_blender(b, preview_colors)
    _place_props_preview(props)
    blend = os.path.join(S.ROOT, "assets", "models", "source", "houses", type_id + ".blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    if S.SHOW_BACKFACES:
        _check(type_id)
    elif render:
        _render(type_id)
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True)


def _place_props_preview(props):
    """Requisiten für die Vorschau in Blender aufstellen (wie in der Interior-Szene)."""
    import build_props
    parts = {
        "mannequin_dress": ["dress_form", "outfit_dress"], "mannequin_coat": ["dress_form", "outfit_coat"],
        "garment_dress": ["garment_dress"], "garment_blouse": ["garment_blouse"],
    }
    built = {}
    for name, pos, yaw, color in props:
        for part in parts[name]:
            if part not in built:
                built[part] = build_props.PROPS[part]()
            colored = S.bake_role(built[part], "accent", color)
            colored.name = part
            obj = S.to_blender(colored, {})
            obj.location = (pos[0], -pos[2], pos[1])
            obj.rotation_euler = (0, 0, math.radians(yaw))


def _render(type_id):
    S.setup_render()
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, -10, 0))
    ground = bpy.context.active_object
    ground.data.materials.append(S.preview_material(Mat("paving"), {}))
    uv = ground.data.uv_layers.active.data
    for loop in ground.data.loops:
        co = ground.data.vertices[loop.vertex_index].co + ground.location
        uv[loop.index].uv = (co.x / 1.8, co.y / 1.8)
    out = os.path.join(S.ROOT, "screenshots", "blender")
    os.makedirs(out, exist_ok=True)
    d = house_dims(type_id)
    S.render_view(os.path.join(out, type_id + "-front.png"), (0, 1.7, 11.5), (0, d["eaves"] * 0.55, 0), lens=30)
    S.render_view(os.path.join(out, type_id + "-angle.png"), (-6.5, 1.6, 7.5), (0.3, 3.2, -0.5), lens=28)
    S.render_view(os.path.join(out, type_id + "-shopfront.png"), (1.6, 1.6, 3.6), (-0.3, 1.5, 0), lens=26)
    S.render_view(os.path.join(out, type_id + "-door.png"), (0.15, 1.6, 2.2), (0, 1.4, -5), lens=30)
    S.render_view(os.path.join(out, type_id + "-window.png"), (-1.4, 1.6, 2.4), (-1.0, 1.3, -3), lens=30)
    S.render_view(os.path.join(out, type_id + "-roof.png"), (3.5, 5.0, 6.0), (0, 7.4, -1.0), lens=35)


def _check(type_id):
    """Prüfbilder rundherum mit pinken Rückseiten (siehe style_lib.SHOW_BACKFACES)."""
    S.setup_render(resolution=(800, 560), samples=8)
    out = os.path.join(S.ROOT, "screenshots", "blender")
    os.makedirs(out, exist_ok=True)
    d = house_dims(type_id)
    e = d["eaves"]
    views = {
        "front_low": ((0, 1.6, 6.0), (0, 4.5, 0)),
        "left": ((-9, 3, 4), (0, 4, -3)),
        "right": ((9, 3, 4), (0, 4, -3)),
        "above_front": ((4, e + 6, 7), (0, e, -3)),
        "above_back": ((-5, e + 6, -14), (0, e, -4)),
        "side_high": ((12, e + 1, -4), (0, e, -4)),
        "back": ((2, 4, -16), (0, 4, -4)),
        "eaves_up": ((1.0, 1.7, 2.0), (0.5, e, -0.5)),
        "door": ((0.3, 1.6, 2.0), (0, 1.4, -5)),
        "window_left": ((-2.6, 1.5, 2.0), (-0.5, 1.4, -4)),
        "window_right": ((2.6, 1.5, 2.0), (0.5, 1.4, -4)),
        "under_awning": ((1.5, 1.3, 1.4), (1.6, 2.6, 0.2)),
        "win_detail": ((-1.2, 2.0, 1.2), (-1.6, 2.4, -0.5)),
        "door_top": ((0.0, 2.2, 1.0), (0.0, 2.75, -0.2)),
        "chimney": ((-1.0, 11.5, -2.5), (-2.28, 9.9, -4.0)),
        "clock": ((0.3, 2.2, -3.6), (0.1, 2.6, -6.0)),
        "props": ((-0.3, 1.5, -0.6), (-1.6, 1.3, -1.8)),
    }
    for name, (cam, target) in views.items():
        S.render_view(os.path.join(out, "%s-check-%s.png" % (type_id, name)), cam, target, lens=28)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = "--render" in argv
    if "--check" in argv:
        S.SHOW_BACKFACES = True
    names = [a for a in argv if not a.startswith("--")]
    if not names or names == ["all"]:
        names = list(HOUSES)
    for name in names:
        build(name, render, "--reset-signs" in argv)


if __name__ == "__main__":
    main()
