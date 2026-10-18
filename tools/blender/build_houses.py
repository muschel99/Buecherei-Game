"""Baut die Stil-Modelle der Häuser (seit Etappe 4g).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_houses.py -- terrace_55
    blender -b --factory-startup --python tools/blender/build_houses.py -- terrace_55 --render
    blender -b --factory-startup --python tools/blender/build_houses.py -- terrace_55 --check
    blender -b --factory-startup --python tools/blender/build_houses.py -- all

Ergebnis je Haustyp:
    assets/models/houses/<typ>.glb            Modell für Godot (Knoten "Model" im Haustyp)
    assets/models/source/houses/<typ>.blend   zum Anschauen in Blender
    screenshots/blender/<typ>-*.png           Kontrollbilder (--render) bzw. Prüfbilder (--check:
                                              Rückseiten pink = im Spiel ein Loch)

Maße (Breite, Tiefe, Traufhöhe) liest das Script aus scenes/world/houses/<typ>.tscn – so passt
das Modell immer genau auf den Platz im Spiel.
Das Modegeschäft ist seit dem Bilderbuch-Stil ein eigenes Modell: tools/blender/build_storybook_shop.py.
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
import style_plants as PL  # noqa: E402
import street_houses as H  # noqa: E402
from style_lib import Mat, V  # noqa: E402

# --- Gemeinsame Materialien (Ebene, Rolle, feste Farbe in sRGB) ---
BRICK = Mat("brick", color=(0.6, 0.33, 0.25))
TRIM = Mat("stone_trim")
JOINERY = Mat("paint", "door")
# Kein reines Weiß (sticht zu sehr hervor): Creme
WHITE = Mat("paint", color=(0.86, 0.84, 0.78))
SLATE = Mat("slate")
RIDGE = Mat("terracotta", color=(1, 1, 1))
LEAD = Mat("metal")
GOLD = Mat("gold")
CURTAIN = Mat("fabric", color=(0.92, 0.9, 0.84))
DARK_GLASS = Mat("glass")
FROSTED_GLASS = Mat("glass", glass=True)
POT = Mat("terracotta")

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
    b.cylinder(V(-w + 0.003, ridge_y + 0.02, ridge_z), 0.09, 2 * w - 0.006, RIDGE, segments=8, caps=(True, True), axis="x")
    # Hinten: Traufbrett und Rinne schließen die Dachkante
    b.box((-w, eaves - 0.22, back_z), (w, eaves + 0.01, -depth), WHITE, skip=("front",))
    b.cylinder(V(-w + 0.003, eaves - 0.04, back_z - 0.04), 0.055, 2 * w - 0.006, LEAD, segments=8, caps=(True, True), axis="x")


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
        for k, (pa, pb) in enumerate(((front, ridge), (ridge, back))):
            narrow = 0.004 * k
            b.beam(pa, pb, 0.3 - narrow, 0.2, mat)
            dd = (pb - pa).normalized() * 0.02
            up = (pb - pa).normalized().cross(V(0, 1, 0)).normalized().cross((pb - pa).normalized()).normalized()
            b.beam(pa - dd + up * 0.2, pb + dd + up * 0.2, 0.34 - narrow, 0.045, TRIM)
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
    b.quad(V(x0, y0, zg), V(x1, y0, zg), V(x1, y1, zg), V(x0, y1, zg), FROSTED_GLASS)
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
    b.cylinder(V(x, 1.5, z + 0.032), 0.035, 0.015, GOLD, segments=10, axis="z", caps=(True, True))
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
            # Schaft: Ober- und Unterseite stecken in Fuß und Kapitell
            b.box((px - 0.09, 0, 0), (px + 0.09, top, 0.09), WHITE, skip=("back", "top", "bottom"))
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
    b.cylinder(V(-w + 0.003, eaves + 0.03, 0.22), 0.055, 2 * w - 0.006, LEAD, segments=8, caps=(True, True), axis="x")


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
    """Topf neben der Haustür: mit palette Lavendel oder Geranie, sonst ein Buchs- bzw.
    (hoher Topf) Lorbeerkegel."""
    import random
    rnd = random.Random(seed)
    h = 0.42 if tall else 0.28
    if palette:
        kind = "lavender" if palette == "lavender" else "geranium"
    else:
        kind = "cone" if tall else "box_low"
    PL.pot_plant(b, x, z, kind, rnd, 0.13, h, 0.16, palette=palette, wall_z=0.035)


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
            P.flower_box(b, x - 0.48, x + 0.48, f_y0 + 0.005, 0.045, 0.235, JOINERY,
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


# --- Schilder zum selbst Gestalten ---
# Jedes Schild ist eine Fläche mit eigenem Bild: assets/textures/signs/<typ>_<name>.png
# (Material assets/materials/signs/<typ>_<name>.tres). Fehlt das Bild, rendert das Script ein
# Startbild aus der Gestaltung unten. Vorhandene Bilder werden NIE überschrieben (eigene
# Gestaltung bleibt) – außer mit --reset-signs.
def _flower_fascia_design(b):
    """Startbild des Blumenladen-Schilds (wie im Konzeptbild): Holzbretter, helle Goldschrift,
    an den Enden kleine Blütenzweige."""
    fw, fh = 4.76, 0.43
    b.box((-fw / 2, -fh / 2, -0.02), (fw / 2, fh / 2, 0.0), Mat("paint", color=(0.44, 0.55, 0.46)))
    wood = Mat("boards", color=(0.55, 0.38, 0.24))
    b.box((-fw / 2 + 0.04, -fh / 2 + 0.035, 0.0), (fw / 2 - 0.04, fh / 2 - 0.035, 0.006), wood)
    start = len(b.faces)
    b.text("BLUMENLADEN", 0.0, 0.0, 0.006, 0.22, 0.012, Mat("gold", color=(1, 1, 1)), spacing=1.12)
    b.recenter(start, 0.0, 0.0)
    import random
    rnd = random.Random(4)
    for side in (-1, 1):
        for k in range(6):
            P.blossom_cluster(b, (side * (1.85 + k * 0.08), -0.03 + 0.07 * math.sin(k * 1.3), 0.012), 0.05,
                              rnd.choice(["rose", "white"]), rnd, count=4, size=0.03)


def _flower_hanging_design(b):
    """Startbild des grünen Hängeschilds: Salbeigrün, Goldrand, ein kleiner Strauß."""
    width, height = P.HANGING_SIGN
    import random
    rnd = random.Random(8)
    b.box((-width / 2 - 0.05, -height / 2 - 0.05, -0.03), (width / 2 + 0.05, height / 2 + 0.05, -0.02),
          Mat("plain", color=(0.5, 0.5, 0.5)))
    outline = P._arch_outline(width, height)
    b.slab([V(u, v, 0) for u, v in outline], 0.02, Mat("paint", color=(0.36, 0.48, 0.38)))
    inset = [V(u * 0.88, v * 0.9 - 0.01, 0.005) for u, v in outline] + [V(outline[0][0] * 0.88, outline[0][1] * 0.9 - 0.01, 0.005)]
    b.tube(inset, 0.007, GOLD, segments=4, caps=False)
    for k in range(7):
        a = -0.6 + k * 0.2
        b.tube([V(0, -0.15, 0.01), V(math.sin(a) * 0.14, -0.15 + math.cos(a) * 0.22, 0.01)], 0.006, Mat("plain", color=(0.3, 0.42, 0.24)), segments=3)
    P.blossom_cluster(b, (0, 0.06, 0.02), 0.12, "rose", rnd, count=12, size=0.035)
    P.blossom_cluster(b, (0, 0.06, 0.02), 0.12, "white", rnd, count=5, size=0.035)
    b.box((-0.06, -0.2, 0.0), (0.06, -0.12, 0.03), Mat("paint", color=(0.86, 0.82, 0.72)))


def _board(b, fw, fh, board, text, letters, size, gold=True, playful=False):
    """Schlichtes Startbild: Brett, feiner Rand, Schrift in der Mitte."""
    b.box((-fw / 2, -fh / 2, -0.02), (fw / 2, fh / 2, 0.0), board)
    edge = GOLD if gold else Mat("paint", color=(0.86, 0.82, 0.72))
    for y0 in (-fh / 2 + 0.03, fh / 2 - 0.045):
        b.box((-fw / 2 + 0.05, y0, 0.0), (fw / 2 - 0.05, y0 + 0.015, 0.008), edge)
    start = len(b.faces)
    if playful:
        b.playful_text(text, 0.0, 0.0, 0.0, size, 0.012, letters, font_path=S.PLAYFUL_FONT, seed=5, bounce=0.06, tilt=4, first_scale=1.25)
    else:
        b.text(text, 0.0, 0.0, 0.0, size, 0.012, letters, spacing=1.1)
    b.recenter(start, 0.0, 0.0)


def _pub_fascia(b):
    """Startbild des Pub-Schilds: dunkle Front, in der Mitte ein kleines Holzschild."""
    fw, fh = 4.96, 0.58
    b.box((-fw / 2, -fh / 2, -0.02), (fw / 2, fh / 2, 0.0), Mat("paint", color=(0.08, 0.1, 0.13)))
    b.box((-0.8, -0.2, 0.0), (0.8, 0.2, 0.02), Mat("timber", color=(1.25, 1.1, 1.0)))
    b.box((-0.76, -0.16, 0.02), (0.76, 0.16, 0.024), Mat("timber", color=(1.1, 0.95, 0.85)))
    start = len(b.faces)
    b.playful_text("The Ink & Ivy", 0.0, 0.0, 0.024, 0.15, 0.006, Mat("paint", color=(0.95, 0.9, 0.78)), font_path=S.PLAYFUL_FONT,
                   seed=12, bounce=0.04, tilt=3)
    b.recenter(start, 0.0, 0.0)


def _pub_hanging(b):
    """Startbild des runden Hängeschilds: dunkler Grund, Goldring, Tintenfass mit Feder."""
    width, height = P.HANGING_SIGN
    b.box((-width / 2 - 0.05, -height / 2 - 0.05, -0.03), (width / 2 + 0.05, height / 2 + 0.05, -0.02), Mat("plain", color=(0.5, 0.5, 0.5)))
    b.cylinder(V(0, 0, -0.02), height / 2, 0.02, Mat("paint", color=(0.08, 0.1, 0.13)), segments=32, axis="z", caps=(True, True))
    ring = [V(0.24 * math.cos(2 * math.pi * k / 32), 0.24 * math.sin(2 * math.pi * k / 32), 0.005) for k in range(33)]
    b.tube(ring, 0.008, GOLD, segments=4, caps=False)
    b.cylinder(V(0, -0.12, 0.0), 0.08, 0.02, Mat("paint", color=(0.85, 0.82, 0.74)), segments=16, axis="z", caps=(True, True))
    b.box((-0.08, -0.12, 0.0), (0.08, 0.0, 0.02), Mat("paint", color=(0.85, 0.82, 0.74)))
    b.beam(V(0.0, -0.02, 0.025), V(0.13, 0.16, 0.025), 0.03, 0.006, GOLD)
    b.beam(V(0.03, 0.02, 0.025), V(0.15, 0.2, 0.025), 0.06, 0.004, Mat("paint", color=(0.85, 0.82, 0.74)))


def _teapot_sign(b):
    """Startbild des Teestuben-Hängeschilds: schwarzer Grund, Goldrand, weiße Teekanne."""
    width, height = P.HANGING_SIGN
    b.box((-width / 2 - 0.05, -height / 2 - 0.05, -0.03), (width / 2 + 0.05, height / 2 + 0.05, -0.02), Mat("plain", color=(0.5, 0.5, 0.5)))
    outline = P._arch_outline(width, height)
    b.slab([V(u, v, 0) for u, v in outline], 0.02, Mat("paint", color=(0.07, 0.07, 0.08)))
    inset = [V(u * 0.88, v * 0.9 - 0.01, 0.005) for u, v in outline] + [V(outline[0][0] * 0.88, outline[0][1] * 0.9 - 0.01, 0.005)]
    b.tube(inset, 0.007, GOLD, segments=4, caps=False)
    white = Mat("paint", color=(0.93, 0.9, 0.84))
    b.sphere(V(0, -0.04, 0.0), 0.12, white, rings=6, segments=12, squash=0.85)
    b.tube([V(0.1, -0.06, 0.0), V(0.17, 0.0, 0.0), V(0.2, 0.04, 0.0)], lambda t: 0.025 - 0.012 * t, white, segments=6)
    b.tube([V(-0.1, 0.02, 0.0), V(-0.18, 0.0, 0.0), V(-0.11, -0.08, 0.0)], 0.014, white, segments=5)
    b.sphere(V(0, 0.08, 0.0), 0.025, GOLD, rings=3, segments=6)


def _wool_hanging(b):
    """Startbild des Wolleladen-Hängeschilds: Taubenblau, Goldrand, Wollknäuel mit Nadeln."""
    width, height = P.HANGING_SIGN
    b.box((-width / 2 - 0.05, -height / 2 - 0.05, -0.03), (width / 2 + 0.05, height / 2 + 0.05, -0.02), Mat("plain", color=(0.5, 0.5, 0.5)))
    outline = P._arch_outline(width, height)
    b.slab([V(u, v, 0) for u, v in outline], 0.02, Mat("paint", color=(0.42, 0.52, 0.6)))
    inset = [V(u * 0.88, v * 0.9 - 0.01, 0.005) for u, v in outline] + [V(outline[0][0] * 0.88, outline[0][1] * 0.9 - 0.01, 0.005)]
    b.tube(inset, 0.007, GOLD, segments=4, caps=False)
    b.sphere(V(0, -0.04, 0.0), 0.13, Mat("plain", color=(0.86, 0.6, 0.58)), rings=6, segments=12)
    for k in range(4):
        a = 0.4 + k * 0.5
        ring = [V(0.13 * math.cos(t) * math.cos(a), -0.04 + 0.13 * math.sin(t), 0.13 * math.cos(t) * math.sin(a) + 0.02) for t in [2 * math.pi * j / 16 for j in range(17)]]
        b.tube(ring, 0.004, Mat("plain", color=(0.7, 0.44, 0.44)), segments=3, caps=False)
    for dx in (-0.06, 0.06):
        b.beam(V(dx, 0.0, 0.14), V(dx * 3, 0.2, 0.14), 0.012, 0.01, Mat("timber"))


SIGNS = {
    "bakery_shop": {
        "fascia": (3.94, 0.43, 2048, lambda b: _board(b, 3.94, 0.43, Mat("paint", color=(0.12, 0.27, 0.28)), "Bäckerei", GOLD, 0.24,
                                                       playful=True)),
        "chalkboard": (P.CHALKBOARD_SIZE[0], P.CHALKBOARD_SIZE[1], 360, lambda b: P.chalkboard_design(b, ["Heute:", "Zimt-", "schnecken"], 71)),
    },
    "pub": {
        "fascia": (4.96, 0.58, 2048, lambda b: _pub_fascia(b)),
        "hanging": (P.HANGING_SIGN[0], P.HANGING_SIGN[1], 512, lambda b: _pub_hanging(b)),
        "chalkboard": (P.CHALKBOARD_SIZE[0], P.CHALKBOARD_SIZE[1], 360, lambda b: P.chalkboard_design(b, ["Heute:", "Pie &", "Cider"], 51)),
    },
    "corner_90": {
        "fascia": (1.6, 0.4, 768, lambda b: _board(b, 1.6, 0.4, Mat("paint", color=(0.07, 0.07, 0.08)), "Teestube", GOLD, 0.2, playful=True)),
        "hanging": (P.HANGING_SIGN[0], P.HANGING_SIGN[1], 512, lambda b: _teapot_sign(b)),
    },
    "corner_30": {
        "fascia": (1.6, 0.4, 768, lambda b: _board(b, 1.6, 0.4, Mat("paint", color=(0.42, 0.52, 0.6)), "Wolle & Stoff",
                                                    Mat("paint", color=(0.95, 0.92, 0.84)), 0.16, gold=False, playful=True)),
        "hanging": (P.HANGING_SIGN[0], P.HANGING_SIGN[1], 512, lambda b: _wool_hanging(b)),
        "chalkboard": (P.CHALKBOARD_SIZE[0], P.CHALKBOARD_SIZE[1], 360, lambda b: P.chalkboard_design(b, ["Neu:", "Merino-", "wolle"], 61)),
    },
    "gatehouse": {
        "fascia": (4.6, 0.42, 2048, lambda b: _board(b, 4.6, 0.42, Mat("paint", color=(0.16, 0.27, 0.2)), "ALTE TORGASSE", GOLD, 0.24)),
    },
    "flower_shop": {
        "fascia": (4.76, 0.43, 2048, _flower_fascia_design),
        "chalkboard": (P.CHALKBOARD_SIZE[0], P.CHALKBOARD_SIZE[1], 360, lambda b: P.chalkboard_design(b, ["Frisch:", "Tulpen", "& Rosen"], 41)),
        "hanging": (P.HANGING_SIGN[0], P.HANGING_SIGN[1], 512, _flower_hanging_design),
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
    b = result[0] if isinstance(result, tuple) else result
    glb = os.path.join(S.ROOT, "assets", "models", "houses", type_id + ".glb")
    tris = S.write_glb(b, glb)
    S.write_import_settings(glb, signs)
    print("%s: %d Dreiecke -> %s" % (type_id, tris, glb))
    S.to_blender(b, preview_colors)
    blend = os.path.join(S.ROOT, "assets", "models", "source", "houses", type_id + ".blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    if S.SHOW_BACKFACES:
        _check(type_id)
    elif render:
        _render(type_id)
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True, compress=True)


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
