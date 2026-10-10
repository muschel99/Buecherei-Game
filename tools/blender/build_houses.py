"""Baut die Stil-Modelle der Häuser (seit Etappe 4g).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_houses.py -- fashion_shop
    blender -b --factory-startup --python tools/blender/build_houses.py -- fashion_shop --render
    blender -b --factory-startup --python tools/blender/build_houses.py -- all

Ergebnis je Haustyp:
    assets/models/houses/<typ>.glb            Modell für Godot (Knoten "Model" im Haustyp)
    assets/models/source/houses/<typ>.blend   zum Anschauen und Weiterbearbeiten in Blender
    screenshots/blender/<typ>-*.png           Kontrollbilder (nur mit --render, nicht in Git)

Maße (Breite, Tiefe, Traufhöhe) liest das Script aus scenes/world/houses/<typ>.tscn – so passt
das Modell immer genau auf den Platz im Spiel.
"""

import bpy
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
from style_lib import Mat, V  # noqa: E402

# --- Gemeinsame Materialien (Ebene, Rolle, feste Farbe in sRGB) ---
WALL_STONE = Mat("stone", "wall")
WALL_BRICK = Mat("brick", "wall")
WALL_RENDER = Mat("render", "wall")
BRICK = Mat("brick", color=(0.6, 0.33, 0.25))
TRIM = Mat("stone_trim")
JOINERY = Mat("paint", "door")
WHITE = Mat("paint", color=(0.93, 0.92, 0.88))
SLATE = Mat("slate")
RIDGE = Mat("terracotta", color=(1, 1, 1))
LEAD = Mat("metal")
GOLD = Mat("gold")
CANVAS = Mat("canvas", "accent")
CURTAIN = Mat("fabric")
DARK_GLASS = Mat("glass")
CLEAR_GLASS = Mat("glass", glass=True)
POT = Mat("terracotta")
SOIL = Mat("plain", color=(0.2, 0.15, 0.11))
LEAVES = Mat("foliage", color=(0.3, 0.42, 0.2))
LEAVES_DARK = Mat("foliage", color=(0.2, 0.3, 0.14))
FLOOR_BOARDS = Mat("timber", color=(1, 1, 1))
ROOM_WALL = Mat("render", color=(0.86, 0.8, 0.7), glow=0.12)
ROOM_CEILING = Mat("plain", color=(0.85, 0.81, 0.74), glow=0.12)
LAMP = Mat("plain", color=(1.0, 0.86, 0.62), glow=1.0)
TILES = Mat("paving", color=(1, 1, 1))

HOUSE_DIR = os.path.join(S.ROOT, "scenes", "world", "houses")
# Dachneigung der Stil-Modelle: etwa 35° (englische Schieferdächer). Der Platzhalter hat ein
# flacheres Dach (2 m); an Grundriss und Traufhöhe ändert das nichts.
STYLE_ROOF_PITCH = 35.0


def house_dims(type_id):
    """Maße aus der Haustyp-Szene (Standardwerte wie in house_facade.gd)."""
    text = open(os.path.join(HOUSE_DIR, type_id + ".tscn")).read()

    def value(name, default):
        match = re.search(r"^%s = ([0-9.]+)" % name, text, re.M)
        return float(match.group(1)) if match else default

    depth = value("depth", 8.0)
    return {"width": value("width", 5.0), "depth": depth, "eaves": value("eaves_height", 6.6),
            "rise": (depth / 2 + 0.25) * math.tan(math.radians(STYLE_ROOF_PITCH))}


# --- Wiederkehrende Teile ---

def gable_roof(b, w, depth, eaves, rise, front_z, back_z, mat=SLATE):
    """Satteldach mit First parallel zur Straße, Firstziegel."""
    ridge_y = eaves + rise
    ridge_z = -depth / 2
    b.quad(V(-w, eaves, front_z), V(w, eaves, front_z), V(w, ridge_y, ridge_z), V(-w, ridge_y, ridge_z), mat)
    b.quad(V(w, eaves, back_z), V(-w, eaves, back_z), V(-w, ridge_y, ridge_z), V(w, ridge_y, ridge_z), mat)
    b.cylinder(V(-w, ridge_y + 0.02, ridge_z), 0.09, 2 * w, RIDGE, segments=8, caps=(True, True), axis="x")


def roof_y(z, eaves, rise, front_z, depth):
    """Höhe der vorderen Dachfläche über der Stelle z."""
    return eaves + (front_z - z) * rise / (front_z + depth / 2)


def party_walls(b, w, depth, eaves, rise, front_z, back_z, mat=BRICK, coping=True):
    """Seitenwände und Giebel (Brandwände zu den Nachbarn) mit kleiner Aufkantung über dem Dach."""
    ridge_y = eaves + rise
    for side in (-1, 1):
        x = side * w
        # Wand unten (nach außen zeigend)
        if side < 0:
            b.quad(V(x, 0, -depth), V(x, 0, 0), V(x, eaves, 0), V(x, eaves, -depth), mat)
            b.poly([V(x, eaves, back_z), V(x, eaves, front_z), V(x, ridge_y + 0.12, -depth / 2)], mat)
        else:
            b.quad(V(x, 0, 0), V(x, 0, -depth), V(x, eaves, -depth), V(x, eaves, 0), mat)
            b.poly([V(x, eaves, front_z), V(x, eaves, back_z), V(x, ridge_y + 0.12, -depth / 2)], mat)
        if coping:
            # Aufkantung der Brandwand über dem Dach mit Abdeckstein, folgt dem Dach
            xc = side * (w - 0.17)
            for z0, z1 in ((front_z, -depth / 2), (-depth / 2, back_z)):
                y0 = eaves - 0.12 if z0 == front_z or z1 == back_z else ridge_y
                pa = V(xc, eaves - 0.08, z0) if z0 == front_z else V(xc, ridge_y - 0.08, z0)
                pb = V(xc, ridge_y - 0.08, z1) if z1 == -depth / 2 else V(xc, eaves - 0.08, z1)
                b.beam(pa, pb, 0.3, 0.2, mat)
                b.beam(pa + V(0, 0.2, 0), pb + V(0, 0.2, 0), 0.34, 0.045, TRIM)
    b.quad(V(w, 0, -depth), V(-w, 0, -depth), V(-w, eaves, -depth), V(w, eaves, -depth), mat)


def chimney(b, x, z, base_y, top_y, width=0.62, deep=0.9, pots=2, mat=BRICK):
    """Schornstein mit Abdeckplatte und Tonaufsätzen."""
    hw = width / 2
    hd = deep / 2
    b.box((x - hw, base_y, z - hd), (x + hw, top_y, z + hd), mat, skip=("bottom",))
    b.box((x - hw - 0.05, top_y - 0.1, z - hd - 0.05), (x + hw + 0.05, top_y, z + hd + 0.05), TRIM)
    b.box((x - hw - 0.04, top_y - 0.3, z - hd - 0.04), (x + hw + 0.04, top_y - 0.22, z + hd + 0.04), TRIM)
    for k in range(pots):
        pz = z + (k - (pots - 1) / 2) * (deep / pots)
        b.cylinder(V(x, top_y, pz), 0.11, 0.38, POT, segments=10, radius_top=0.085)
        b.cylinder(V(x, top_y + 0.38, pz), 0.1, 0.05, POT, segments=10)


def sash_window(b, x, y0, w, h, reveal, panes=(2, 2), curtains=True, z=0.0):
    """Schiebefenster (zwei Flügel) in einer Wandöffnung (x = Mitte, y0 = Unterkante, z = Ebene
    der Wand), Glas dunkel, helle Vorhänge dahinter."""
    b.push(b.move(0, 0, z))
    x0, x1 = x - w / 2, x + w / 2
    y1 = y0 + h
    zg = -reveal + 0.02
    b.quad(V(x0, y0, zg), V(x1, y0, zg), V(x1, y1, zg), V(x0, y1, zg), DARK_GLASS)
    if curtains:
        cw = w * 0.24
        for cx0, cx1 in ((x0, x0 + cw), (x1 - cw, x1)):
            b.quad(V(cx0, y0 + 0.05, zg + 0.008), V(cx1, y0 + 0.05, zg + 0.008), V(cx1, y1, zg + 0.008), V(cx0, y1, zg + 0.008), CURTAIN)
    f = 0.055
    zf0, zf1 = zg - 0.01, zg + 0.06
    # Blendrahmen
    b.box((x0, y0, zf0), (x0 + f, y1, zf1), WHITE, skip=("back",))
    b.box((x1 - f, y0, zf0), (x1, y1, zf1), WHITE, skip=("back",))
    b.box((x0 + f, y1 - f, zf0), (x1 - f, y1, zf1), WHITE, skip=("back",))
    b.box((x0 + f, y0, zf0), (x1 - f, y0 + f, zf1), WHITE, skip=("back",))
    # Zwei Flügel: der obere etwas weiter vorn, Kämpfer in der Mitte
    mid = y0 + h / 2
    b.box((x0 + f, mid - 0.03, zf0), (x1 - f, mid + 0.03, zf1 + 0.015), WHITE, skip=("back",))
    for sy0, sy1, dz in ((y0 + f, mid - 0.03, 0.0), (mid + 0.03, y1 - f, 0.015)):
        b.glazing_bars(x0 + f, sy0, x1 - f, sy1, zf0, zf1 - 0.02 + dz, panes[0], panes[1], 0.022, WHITE)
    b.pop()


def topiary(b, x, z, seed):
    """Buchsbaumkugel im Terrakotta-Topf (mit Kollision)."""
    b.cylinder(V(x, 0, z), 0.2, 0.4, POT, segments=14, radius_top=0.24, caps=(False, False))
    b.cylinder(V(x, 0.4, z), 0.26, 0.06, POT, segments=14, caps=(False, True))
    b.cylinder(V(x, 0.36, z), 0.235, 0.05, SOIL, segments=14)
    b.cylinder(V(x, 0.4, z), 0.025, 0.22, Mat("timber"), segments=6)
    b.sphere(V(x, 0.82, z), 0.27, LEAVES, rings=7, segments=12, jitter=0.07, seed=seed)
    b.colliders.append(((x - 0.27, 0, z - 0.27), (x + 0.27, 1.1, z + 0.27)))


def mannequin(b, x, y, z, dress, seed):
    """Schlichte Schaufensterpuppe mit Kleid."""
    skin = Mat("plain", color=(0.9, 0.87, 0.82))
    b.cylinder(V(x, y, z), 0.14, 0.03, LEAD, segments=12)
    b.cylinder(V(x, y + 0.03, z), 0.015, 0.2, LEAD, segments=6)
    b.cylinder(V(x, y + 0.2, z), 0.24, 0.62, dress, segments=14, radius_top=0.11, caps=(True, False))
    b.cylinder(V(x, y + 0.82, z), 0.11, 0.3, dress, segments=12, radius_top=0.14, caps=(False, False))
    b.sphere(V(x, y + 1.12, z), 0.15, dress, rings=4, segments=12, squash=0.4)
    b.cylinder(V(x, y + 1.14, z), 0.035, 0.1, skin, segments=8)
    b.sphere(V(x, y + 1.33, z), 0.095, skin, rings=6, segments=10, squash=1.15)


def dormer(b, cx, fz, eaves, rise, front_z, depth, gw=0.44):
    """Gaube im vorderen Dach: Vorderseite bei fz, Breite 2 x gw."""
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
        b.poly(pts if s2 < 0 else pts[::-1], SLATE)
        # Ortgang-Brett (weiß)
        b.poly([lo, V(lo.x, lo.y - 0.12, lo.z), V(hi.x, hi.y - 0.12, hi.z), hi][::(-1 if s2 < 0 else 1)], WHITE)
        b.poly([lo, V(lo.x, lo.y - 0.12, lo.z), V(hi.x, hi.y - 0.12, hi.z), hi][::(1 if s2 < 0 else -1)], WHITE)
    b.cylinder(V(cx, ridge + 0.04, back), 0.05, fz + 0.12 - back, RIDGE, segments=6, caps=(False, True), axis="z")


# --- Haustypen ---

def fashion_shop(type_id="fashion_shop"):
    """Modegeschäft nach dem Konzeptbild "fashionshop.png": Ladenfront in Marineblau mit
    goldener Schrift, gestreifte Markisen, Sandstein-Fassade mit Eckquadern, drei
    Schiebefenster mit Verdachungen, Zahnschnitt-Gesims, Ziergiebel mit Rosette, zwei Gauben."""
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

    # --- Obergeschoss: Sandstein mit drei Fenstern ---
    shop_top = 3.58
    win_w, win_h, win_y = 0.9, 1.62, 4.18
    xs = [-1.7, 0.0, 1.7]
    reveal = 0.14
    holes = [(x - win_w / 2, win_y, x + win_w / 2, win_y + win_h) for x in xs]
    b.wall_with_holes(-w, w, 3.4, E, 0.0, holes, WALL_STONE, reveal=reveal)
    for x in xs:
        sash_window(b, x, win_y, win_w, win_h, reveal)
        # Gewände, Fensterbank auf Konsolen, Verdachung mit Schlussstein
        b.frame(x - win_w / 2, win_y, x + win_w / 2, win_y + win_h, 0.0, 0.05, 0.11, TRIM, bottom=False)
        b.box((x - win_w / 2 - 0.17, win_y - 0.09, 0), (x + win_w / 2 + 0.17, win_y, 0.12), TRIM)
        for cx in (x - win_w / 2 - 0.08, x + win_w / 2 + 0.08):
            b.box((cx - 0.05, win_y - 0.24, 0), (cx + 0.05, win_y - 0.09, 0.08), TRIM, skip=("back",))
        top = win_y + win_h + 0.11
        b.box((x - win_w / 2 - 0.11, top, 0), (x + win_w / 2 + 0.11, top + 0.14, 0.07), TRIM, skip=("back",))
        b.extrude_x([(0, top + 0.14), (0, top + 0.3), (0.16, top + 0.3), (0.16, top + 0.25), (0.08, top + 0.14)],
                    x - win_w / 2 - 0.22, x + win_w / 2 + 0.22, TRIM)
        b.poly([V(x - 0.09, win_y + win_h + 0.18, 0.09), V(x - 0.06, win_y + win_h - 0.05, 0.09),
                V(x + 0.06, win_y + win_h - 0.05, 0.09), V(x + 0.09, win_y + win_h + 0.18, 0.09)], TRIM)
        b.box((x - 0.09, win_y + win_h - 0.05, 0.0), (x + 0.09, win_y + win_h + 0.18, 0.09), TRIM, skip=("back", "front"))
    # Sohlbank-Band unter den Fenstern
    b.box((-w, win_y - 0.2, 0), (w, win_y - 0.12, 0.05), TRIM, skip=("back",))
    # Eckquader (abwechselnd lang und kurz)
    y = shop_top + 0.06
    k = 0
    while y + 0.3 < E - 0.3:
        long_ = k % 2 == 0
        for side in (-1, 1):
            x_out = side * w
            x_in = side * (w - (0.44 if long_ else 0.3))
            lo_x, hi_x = sorted((x_out, x_in))
            b.box((lo_x, y, 0), (hi_x, y + 0.29, 0.035), TRIM, skip=("back",))
        y += 0.31
        k += 1
    # Fallrohr links
    b.cylinder(V(-w + 0.12, shop_top, 0.08), 0.04, E - shop_top + 0.05, LEAD, segments=8)

    # --- Traufgesims mit Zahnschnitt ---
    b.box((-w, E - 0.42, 0), (w, E - 0.28, 0.07), TRIM, skip=("back",))
    x = -w + 0.08
    while x + 0.06 < w:
        b.box((x, E - 0.28, 0.0), (x + 0.06, E - 0.18, 0.12), TRIM, skip=("back",))
        x += 0.13
    b.extrude_x([(0, E - 0.18), (0, E), (0.32, E), (0.32, E - 0.07), (0.22, E - 0.11), (0.15, E - 0.18)],
                -w - 0.02, w + 0.02, TRIM)
    b.cylinder(V(-w, E + 0.03, 0.27), 0.06, W, LEAD, segments=8, caps=(True, True), axis="x")

    # --- Ziergiebel mit Rosette ---
    pw = 1.0
    apex = E + 0.78
    zf = 0.08
    b.poly([V(-pw, E, zf), V(pw, E, zf), V(0, apex, zf)], WALL_STONE)
    for side in (-1, 1):
        a = V(side * (pw + 0.12), E - 0.02, 0.0)
        c = V(0, apex + 0.13, 0.0)
        u = (c - a).normalized()
        n = V(0, 0, 1)
        up = n.cross(u) if side > 0 else u.cross(n)
        t = 0.13
        a2, c2 = a + up * t, c + up * t
        f0, f1 = 0.0, 0.2
        pts_front = [V(a.x, a.y, f1), V(c.x, c.y, f1), V(c2.x, c2.y, f1), V(a2.x, a2.y, f1)]
        if side < 0:
            pts_front = pts_front[::-1]
        b.poly(pts_front, TRIM)
        # Oberseite und Unterseite des schrägen Gesimses
        top_pts = [V(a2.x, a2.y, f1), V(c2.x, c2.y, f1), V(c2.x, c2.y, f0), V(a2.x, a2.y, f0)]
        bot_pts = [V(a.x, a.y, f0), V(c.x, c.y, f0), V(c.x, c.y, f1), V(a.x, a.y, f1)]
        b.poly(top_pts if side > 0 else top_pts[::-1], TRIM)
        b.poly(bot_pts if side > 0 else bot_pts[::-1], TRIM)
    b.cylinder(V(0, E + 0.33, zf), 0.2, 0.05, TRIM, segments=20, axis="z")
    b.cylinder(V(0, E + 0.33, zf + 0.05), 0.15, 0.03, TRIM, segments=16, axis="z")
    for i in range(8):
        a = 2 * math.pi * i / 8
        b.sphere(V(0.09 * math.cos(a), E + 0.33 + 0.09 * math.sin(a), zf + 0.09), 0.03, TRIM, rings=3, segments=6)
    b.sphere(V(0, E + 0.33, zf + 0.09), 0.045, TRIM, rings=4, segments=8)
    # Dach hinter dem Ziergiebel (läuft in das Hauptdach)
    back = -1.9
    for side in (-1, 1):
        lo = V(side * (pw + 0.12), E + 0.06, 0.02)
        hi = V(0, apex + 0.16, 0.02)
        pts = [lo, hi, V(hi.x, hi.y, back), V(lo.x, lo.y, back)]
        b.poly(pts if side < 0 else pts[::-1], SLATE)
    b.poly([V(-pw, E, back), V(pw, E, back), V(0, apex, back)][::-1], WALL_STONE)

    # --- Gauben (mit Schiefer verkleidet, weißes Fenster, kleiner Giebel) ---
    for side in (-1, 1):
        dormer(b, side * 1.95, -0.7, E, R, front_z, D)

    # --- Ladenfront (Erdgeschoss) ---
    pil = 0.32
    fascia_lo, fascia_hi = 2.97, 3.4
    head = 2.86
    door_half = 0.62
    post = 0.1
    sill_y = 0.6
    transom = 2.3
    jz = 0.13
    # Pilaster mit Sockel und Konsole
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * w, side * (w - pil)))
        b.box((lo_x, 0, 0), (hi_x, fascia_hi, 0.16), JOINERY, skip=("back",))
        b.box((lo_x - 0.02, 0, 0), (hi_x + 0.02, 0.32, 0.19), JOINERY, skip=("back", "bottom"))
        b.box((lo_x + 0.04, 0.5, 0.16), (hi_x - 0.04, 2.7, 0.18), JOINERY, skip=("back", "bottom", "top"))
        # Konsole am Ende des Schilds (gestuft, wie eine Schnecke angedeutet)
        b.box((lo_x - 0.02, fascia_lo - 0.18, 0), (hi_x + 0.02, fascia_hi + 0.05, 0.26), JOINERY, skip=("back",))
        b.box((lo_x + 0.02, fascia_lo - 0.36, 0), (hi_x - 0.02, fascia_lo - 0.18, 0.21), JOINERY, skip=("back",))
        b.cylinder(V(lo_x + 0.02, fascia_lo + 0.12, 0.2), 0.08, hi_x - lo_x - 0.04, GOLD, segments=10, caps=(True, True), axis="x")
    # Schild mit Goldrand und Schrift
    b.box((-w + pil, fascia_lo, 0), (w - pil, fascia_hi, 0.2), JOINERY, skip=("back",))
    for y0, y1 in ((fascia_lo + 0.035, fascia_lo + 0.05), (fascia_hi - 0.05, fascia_hi - 0.035)):
        b.box((-w + pil + 0.06, y0, 0.2), (w - pil - 0.06, y1, 0.21), GOLD, skip=("back",))
    for x in (-w + pil + 0.06, w - pil - 0.075):
        b.box((x, fascia_lo + 0.035, 0.2), (x + 0.015, fascia_hi - 0.035, 0.21), GOLD, skip=("back",))
    b.text("ELEANOR'S FINE DRESSES", 0.0, fascia_lo + 0.12, 0.2, 0.2, 0.012, GOLD, spacing=1.08)
    # Gesims über dem Schild (mit Bleiabdeckung)
    b.extrude_x([(0, fascia_hi), (0, shop_top), (0.3, shop_top), (0.3, fascia_hi + 0.1), (0.22, fascia_hi + 0.05), (0.2, fascia_hi)],
                -w - 0.03, w + 0.03, JOINERY)
    b.box((-w - 0.03, shop_top, 0), (w + 0.03, shop_top + 0.02, 0.31), LEAD, skip=("back",))
    # Kopfriegel unter dem Schild
    b.box((-w + pil, head, 0), (w - pil, fascia_lo, jz), JOINERY, skip=("back",))
    # Türpfosten
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * door_half, side * (door_half + post)))
        b.box((lo_x, 0, 0), (hi_x, head, jz), JOINERY, skip=("back", "top"))
    # Schaufenster links und rechts
    win_x0 = w - pil
    win_x1 = door_half + post
    for side in (-1, 1):
        lo_x, hi_x = sorted((side * win_x0, side * win_x1))
        # Brüstung mit Füllungen, Sohlbank
        b.box((lo_x, 0, 0), (hi_x, sill_y - 0.05, 0.11), JOINERY, skip=("back",))
        b.frame(lo_x + 0.12, 0.12, hi_x - 0.12, sill_y - 0.17, 0.11, 0.13, 0.03, JOINERY)
        b.box((lo_x - 0.01, sill_y - 0.05, 0), (hi_x + 0.01, sill_y + 0.02, 0.17), JOINERY, skip=("back",))
        # Kämpfer (unter dem Oberlicht) und schmale Rahmen
        b.box((lo_x, transom, 0), (hi_x, transom + 0.08, jz), JOINERY, skip=("back",))
        b.box((lo_x, sill_y + 0.02, 0), (lo_x + 0.05, head, jz - 0.02), JOINERY, skip=("back", "top", "bottom"))
        b.box((hi_x - 0.05, sill_y + 0.02, 0), (hi_x, head, jz - 0.02), JOINERY, skip=("back", "top", "bottom"))
        # Glas (durchsichtig), Oberlicht mit Bogensprossen
        gz = 0.06
        b.quad(V(lo_x, sill_y + 0.02, gz), V(hi_x, sill_y + 0.02, gz), V(hi_x, head, gz), V(lo_x, head, gz), CLEAR_GLASS)
        cx = (lo_x + hi_x) / 2
        span = hi_x - lo_x - 0.1
        for i in range(1, 4):
            bx = lo_x + 0.05 + span * i / 4
            b.box((bx - 0.012, transom + 0.08, gz), (bx + 0.012, head, jz - 0.03), JOINERY, skip=("back",))
        _arch_bar(b, cx, transom + 0.08, span / 2, head - transom - 0.13, gz, jz - 0.03)
        # Schaufenster-Raum dahinter
        _display_box(b, lo_x + 0.02, hi_x - 0.02, sill_y + 0.02, head, gz - 0.005, -0.9)
        mannequin(b, cx - 0.35 * span / 1.6, sill_y + 0.02, -0.42, Mat("plain", color=(0.78, 0.58, 0.58)), 1)
        mannequin(b, cx + 0.35 * span / 1.6, sill_y + 0.02, -0.55, Mat("plain", color=(0.25, 0.3, 0.42) if side < 0 else (0.62, 0.52, 0.4)), 2)
        _clothes_rail(b, lo_x + 0.15, hi_x - 0.15, sill_y + 0.02, -0.82, side)
        # Markise (Akzentfarbe, gestreift)
        _awning(b, lo_x - 0.02, hi_x + 0.02, head, 0.15, 0.95, 0.5)
    # Tür in einer kleinen Nische, Oberlicht darüber
    _recessed_door(b, door_half, transom, head, jz)
    # Buchsbaum-Kübel neben der Tür
    for side in (-1, 1):
        topiary(b, side * (door_half + 0.42), 0.42, seed=3 + side)
    return b


def _arch_bar(b, cx, y_base, radius_x, radius_y, z0, z1, segments=10):
    """Bogensprosse im Oberlicht (Halbellipse aus kurzen Stücken)."""
    t = 0.022
    for i in range(segments):
        a0 = math.pi * i / segments
        a1 = math.pi * (i + 1) / segments
        p0 = (cx - radius_x * math.cos(a0), y_base + radius_y * math.sin(a0))
        p1 = (cx - radius_x * math.cos(a1), y_base + radius_y * math.sin(a1))
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        ln = math.hypot(dx, dy)
        nx, ny = -dy / ln * t / 2, dx / ln * t / 2
        b.poly([V(p0[0] - nx, p0[1] - ny, z1), V(p1[0] - nx, p1[1] - ny, z1), V(p1[0] + nx, p1[1] + ny, z1), V(p0[0] + nx, p0[1] + ny, z1)], JOINERY)


def _display_box(b, x0, x1, y0, y1, z_front, z_back):
    """Schaufenster-Raum hinter dem Glas: Rückwand, Boden, Decke, Seiten (alles zeigt nach innen)."""
    b.quad(V(x0, y0, z_back), V(x1, y0, z_back), V(x1, y1, z_back), V(x0, y1, z_back), ROOM_WALL)
    b.quad(V(x0, y0, z_front), V(x1, y0, z_front), V(x1, y0, z_back), V(x0, y0, z_back), FLOOR_BOARDS)
    b.quad(V(x0, y1, z_back), V(x1, y1, z_back), V(x1, y1, z_front), V(x0, y1, z_front), ROOM_CEILING)
    b.quad(V(x0, y0, z_front), V(x0, y0, z_back), V(x0, y1, z_back), V(x0, y1, z_front), ROOM_WALL)
    b.quad(V(x1, y0, z_back), V(x1, y0, z_front), V(x1, y1, z_front), V(x1, y1, z_back), ROOM_WALL)
    # Leuchtleiste unter der Decke (warmes Licht)
    b.box((x0 + 0.1, y1 - 0.04, z_front - 0.2), (x1 - 0.1, y1 - 0.005, z_front - 0.12), LAMP, skip=("top",))


def _clothes_rail(b, x0, x1, floor_y, z, seed):
    """Kleiderstange mit ein paar Kleidungsstücken an der Rückwand."""
    import random
    rnd = random.Random(seed)
    top = floor_y + 1.45
    b.cylinder(V(x0, top, z), 0.012, x1 - x0, LEAD, segments=6, axis="x")
    colors = [(0.55, 0.42, 0.36), (0.3, 0.33, 0.4), (0.82, 0.78, 0.7), (0.5, 0.2, 0.24), (0.36, 0.42, 0.34), (0.75, 0.62, 0.56)]
    x = x0 + 0.08
    while x < x1 - 0.06:
        h = rnd.uniform(0.6, 0.95)
        c = colors[rnd.randrange(len(colors))]
        b.box((x, top - h, z - 0.16), (x + 0.025, top - 0.04, z + 0.1), Mat("plain", color=c), skip=("back",))
        x += rnd.uniform(0.05, 0.09)


def _awning(b, x0, x1, y_top, z_wall, reach, drop):
    """Markise: Tuch schräg nach vorn, Volant vorn, Seitenwangen."""
    a, c = V(x0, y_top, z_wall), V(x1, y_top, z_wall)
    d, e = V(x1, y_top - drop, reach), V(x0, y_top - drop, reach)
    b.poly([e, d, c, a], CANVAS)
    b.poly([a, c, d, e], CANVAS)
    val = 0.2
    b.quad(V(x0, y_top - drop - val, reach), V(x1, y_top - drop - val, reach), d, e, CANVAS)
    b.quad(V(x1, y_top - drop - val, reach - 0.005), V(x0, y_top - drop - val, reach - 0.005), V(x0, y_top - drop, reach - 0.005), V(x1, y_top - drop, reach - 0.005), CANVAS)
    for x, flip in ((x0, True), (x1, False)):
        pts = [V(x, y_top, z_wall), V(x, y_top - drop, reach), V(x, y_top - drop - val, reach), V(x, y_top - drop - val * 0.5, z_wall + 0.25)]
        b.poly(pts if flip else pts[::-1], CANVAS)
        b.poly(pts[::-1] if flip else pts, CANVAS)
    b.cylinder(V(x0, y_top - drop, reach - 0.02), 0.018, x1 - x0, LEAD, segments=6, axis="x")
    b.box((x0 - 0.03, y_top - 0.05, 0.0), (x1 + 0.03, y_top + 0.08, z_wall + 0.03), JOINERY)


def _recessed_door(b, half, transom, head, jz):
    """Ladentür in einer flachen Nische: Seitenwände, Decke, Fliesenboden, Tür mit Glas,
    Oberlicht vorn."""
    back = -0.42
    x0, x1 = -half, half
    b.quad(V(x0, 0.02, 0), V(x0, 0.02, back), V(x0, transom, back), V(x0, transom, 0), JOINERY)
    b.quad(V(x1, 0.02, back), V(x1, 0.02, 0), V(x1, transom, 0), V(x1, transom, back), JOINERY)
    b.box((x0, transom, back), (x1, transom + 0.08, jz), JOINERY, skip=("back",))
    b.quad(V(x0, transom, back), V(x1, transom, back), V(x1, transom, 0), V(x0, transom, 0), JOINERY)
    b.box((x0 - 0.02, 0, back), (x1 + 0.02, 0.06, 0.08), TILES, skip=("back",))
    # Oberlicht über der Nische
    gz = 0.06
    b.quad(V(x0, transom + 0.08, gz), V(x1, transom + 0.08, gz), V(x1, head, gz), V(x0, head, gz), CLEAR_GLASS)
    _arch_bar(b, 0.0, transom + 0.08, half - 0.03, head - transom - 0.12, gz, jz - 0.03)
    b.box((-0.012, transom + 0.08, gz), (0.012, head, jz - 0.03), JOINERY, skip=("back",))
    b.quad(V(x0, transom + 0.08, gz - 0.3), V(x1, transom + 0.08, gz - 0.3), V(x1, head, gz - 0.3), V(x0, head, gz - 0.3), ROOM_CEILING)
    # Türblatt: Rahmen, Glas oben, Füllung unten, Briefschlitz und Knauf in Messing
    dz = back
    fw = 0.1
    b.box((x0, 0.06, dz - 0.05), (x0 + fw, transom, dz), JOINERY, skip=("back",))
    b.box((x1 - fw, 0.06, dz - 0.05), (x1, transom, dz), JOINERY, skip=("back",))
    b.box((x0 + fw, 0.06, dz - 0.05), (x1 - fw, 0.3, dz), JOINERY, skip=("back",))
    b.box((x0 + fw, 0.95, dz - 0.05), (x1 - fw, 1.07, dz), JOINERY, skip=("back",))
    b.box((x0 + fw, transom - 0.1, dz - 0.05), (x1 - fw, transom, dz), JOINERY, skip=("back",))
    b.box((x0 + fw, 0.3, dz - 0.05), (x1 - fw, 0.95, dz - 0.02), JOINERY, skip=("back",))
    b.frame(x0 + fw + 0.07, 0.38, x1 - fw - 0.07, 0.87, dz - 0.02, dz + 0.0, 0.025, JOINERY)
    b.quad(V(x0 + fw, 1.07, dz - 0.03), V(x1 - fw, 1.07, dz - 0.03), V(x1 - fw, transom - 0.1, dz - 0.03), V(x0 + fw, transom - 0.1, dz - 0.03), CLEAR_GLASS)
    b.glazing_bars(x0 + fw, 1.07, x1 - fw, transom - 0.1, dz - 0.04, dz - 0.02, 2, 3, 0.02, JOINERY)
    b.box((-0.16, 1.0, dz), (0.16, 1.04, dz + 0.012), GOLD, skip=("back",))
    b.sphere(V(x1 - fw - 0.06, 1.0, dz + 0.04), 0.03, GOLD, rings=4, segments=8)
    # Dunkler Laden hinter der Tür
    b.quad(V(x0, 0.06, dz - 0.9), V(x1, 0.06, dz - 0.9), V(x1, transom, dz - 0.9), V(x0, transom, dz - 0.9), Mat("plain", color=(0.25, 0.2, 0.16)))


HOUSES = {
    "fashion_shop": (fashion_shop, {"wall": (0.9, 0.86, 0.8), "door": (0.1, 0.13, 0.21), "accent": (0.17, 0.2, 0.3)}),
}


def build(type_id, render):
    func, preview_colors = HOUSES[type_id]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    b = func()
    glb = os.path.join(S.ROOT, "assets", "models", "houses", type_id + ".glb")
    tris = S.write_glb(b, glb)
    S.write_import_settings(glb)
    print("%s: %d Dreiecke -> %s" % (type_id, tris, glb))
    obj = S.to_blender(b, preview_colors)
    blend = os.path.join(S.ROOT, "assets", "models", "source", "houses", type_id + ".blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.file.make_paths_relative()
    if render:
        _render(type_id, b)
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True)


def _render(type_id, b):
    S.setup_render()
    # Gehweg als Boden
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
    S.render_view(os.path.join(out, type_id + "-roof.png"), (3.5, 5.0, 6.0), (0, 7.4, -1.0), lens=35)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = "--render" in argv
    names = [a for a in argv if not a.startswith("--")]
    if not names or names == ["all"]:
        names = list(HOUSES)
    for name in names:
        build(name, render)


main()
