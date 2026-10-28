"""Feste Einbauten je Stil (Etappe 6): die Theke und der Einwurf des Rückgabekastens.

Theken (kind="counter"): alle gleich groß, damit Kollision und Ablagefläche der festen Theken-Szene
(scenes/furniture/counter.tscn) passen – 2 m breit, Platte genau auf 1 m, Blender-y von -0,345
(Kundenseite, vorn) bis 0,305 (hinten, wo ich stehe). Vorn Zierde, hinten offene Fächer und Schübe.
Einwürfe (kind="return_slot"): Ursprung hinten auf der Hauswand in der Mitte des Schlitzes,
Vorderseite -y, etwa 34 x 30 cm. Ergebnis: Modell + Datenblatt in data/counters/ bzw.
data/return_slots/ (siehe storybook_furniture.write_option_data), Auswahl in der App „Fassade“.
Teile (kind="part"): Kasse und Tablet auf der Theke – nur Modell, ihre Szenen binden die .glb ein.
"""

import math
import random

from mathutils import Matrix, Vector

import storybook_furniture as F
import furniture_country as FC
import furniture_dark_academia as FD
import furniture_minimalist as FM
import furniture_neutral as FN

# Maße der Theke (Blender-Koordinaten)
TOP_Z = 1.0                  # Oberkante der Platte (Ablagefläche der Theken-Szene)
TOP_Y = (-0.345, 0.305)      # Platte vorn/hinten
HALF_W = 0.94                # Korpus: halbe Breite
FRONT_Y, BACK_Y = -0.29, 0.25  # Korpus vorn/hinten
BASE_Z = 0.09                # Unterkante Korpus (darunter der Sockel)
UNDER_TOP = 0.955            # Unterkante der Platte
BOARD = 0.025                # Brettstärke
DIVIDER_X = 0.32             # Trennwände zwischen offenen Fächern (außen) und Schüben (Mitte)
SHELF_Z = 0.5                # Zwischenboden in den offenen Fächern
UP = Matrix.Rotation(math.radians(90), 4, "X")  # lokale xy-Ebene -> senkrecht, lokales +z -> vorn (-y)


def book_mats(k):
    k.mat("cover", (1, 1, 1), grain="paint", rough=0.7, vary=0.0, bump=0.05)
    k.mat("pages", (0.93, 0.88, 0.76), grain="paint", rough=0.85, vary=0.04)


def carcass(k, slot, inner=None):
    """Korpus mit offener Rückseite: Front, Seiten, Boden, zwei Trennwände, Zwischenböden links und
    rechts, in der Mitte ein Schubkasten-Block (Schübe setzt drawers())."""
    inner = inner or slot
    c = k.part("Korpus", slot, bevel=0.004)
    h = UNDER_TOP - BASE_Z
    zc = (UNDER_TOP + BASE_Z) / 2
    c.box((0, FRONT_Y + BOARD / 2, zc), (HALF_W * 2, BOARD, h), step=0.3, dent=0.0008)
    for side in (-1, 1):
        c.box((side * (HALF_W - BOARD / 2), (FRONT_Y + BACK_Y) / 2, zc), (BOARD, BACK_Y - FRONT_Y, h), step=0.3, dent=0.0008)
    i = k.part("Innenleben", inner, bevel=0.003)
    depth = BACK_Y - (FRONT_Y + BOARD)
    yc = (BACK_Y + FRONT_Y + BOARD) / 2
    i.box((0, yc, BASE_Z + BOARD / 2), (HALF_W * 2 - BOARD * 2 + 0.004, depth, BOARD), step=0.3, dent=0.0006)
    for side in (-1, 1):
        i.box((side * DIVIDER_X, yc, (UNDER_TOP + BASE_Z + BOARD) / 2), (0.022, depth, UNDER_TOP - BASE_Z - BOARD + 0.002),
              step=0.3, dent=0.0006)
        x0, x1 = DIVIDER_X + 0.011, HALF_W - BOARD
        i.box((side * (x0 + x1) / 2, yc - 0.008, SHELF_Z), (x1 - x0 + 0.004, depth - 0.016, 0.022), step=0.3, dent=0.0006)
    # Block hinter den Schüben (geschlossen, damit nichts durchscheint)
    i.box((0, yc - 0.01, (UNDER_TOP + BASE_Z + BOARD) / 2), (DIVIDER_X * 2 - 0.02, depth - 0.02, UNDER_TOP - BASE_Z - BOARD),
          step=0.3, dent=0.0)


def drawers(k, slot, handle_slot, handle="knob"):
    """Drei Schübe hinten in der Mitte (zu mir, +y); Griffe: knob, bar oder tab."""
    fr = k.part("Schübe", slot, bevel=0.004)
    hd = k.part("Griffe", handle_slot, bevel=0.0)
    span = UNDER_TOP - BASE_Z - BOARD
    hgt = span / 3 - 0.018
    for j in range(3):
        z = BASE_Z + BOARD + span / 3 * (j + 0.5)
        fr.box((0, BACK_Y - 0.004, z), (DIVIDER_X * 2 - 0.034, 0.022, hgt), step=0.3, dent=0.0006)
        p = (0, BACK_Y + 0.007, z + hgt * 0.18)
        if handle == "knob":
            F.knob(hd, p, r=0.013, normal=(0, 1, 0))
        elif handle == "bar":
            F.bar_handle(hd, p, 0.1, r=0.0045, depth=0.02, normal_y=1)
            hd.box((0, BACK_Y + 0.008, z - hgt * 0.15), (0.06, 0.003, 0.022), step=0.5, dent=0.0)
        else:
            hd.box((0, BACK_Y + 0.012, z + hgt / 2 - 0.012), (0.08, 0.026, 0.012), step=0.5, dent=0.0002)


def back_books(k, x0, x1, z, rnd, max_h=0.24, palette=None, lean=True):
    """Bücher auf einem Boden hinten im Fach, Rücken zu mir (+y)."""
    cover = k.part("Buchdeckel", "cover", bevel=0.0015, vary=0.0)
    pages = k.part("Buchseiten", "pages", bevel=0.0008, vary=0.02)
    palette = palette or FN.BOOK_COLORS
    x = x0
    while True:
        t = rnd.uniform(0.024, 0.042)
        if x + t > x1:
            break
        col = palette[rnd.randrange(len(palette))]
        F.book(cover, pages, (x + t / 2, 0.12, z), (t, rnd.uniform(0.15, 0.18), rnd.uniform(0.72, 1.0) * max_h), turn=180,
               tint=tuple(c * rnd.uniform(0.86, 1.1) for c in col))
        x += t + 0.0015
    if lean and x + 0.07 < x1:
        h = max_h * 0.9
        F.book(cover, pages, (x + 0.015 + math.sin(math.radians(16)) * h / 2, 0.12, z), (0.03, 0.16, h), turn=180, tilt=-16,
               tint=palette[0])


def book_pile(k, x, y, z, n, rnd, palette=None):
    """Ein paar liegende Bücher (Stapel)."""
    cover = k.part("Buchdeckel", "cover", bevel=0.0015, vary=0.0)
    pages = k.part("Buchseiten", "pages", bevel=0.0008, vary=0.02)
    palette = palette or FN.BOOK_COLORS
    for i in range(n):
        w, d, t = rnd.uniform(0.15, 0.2), rnd.uniform(0.21, 0.25), rnd.uniform(0.022, 0.034)
        m = Matrix.Translation((x + rnd.uniform(-0.01, 0.01), y, z + t / 2)) @ Matrix.Rotation(math.radians(rnd.uniform(-8, 8)), 4, "Z")
        col = palette[(i * 2 + 1) % len(palette)]
        cover.box((0, 0, 0), (w, d, t), step=0.5, dent=0.0008, tint=F.lin(col), matrix=m)
        pages.box((0.004, 0, 0), (w * 0.95, d * 0.94, t * 0.8), step=0.5, dent=0.0, matrix=m)
        z += t


def plinth(k, slot, inset=0.025):
    s = k.part("Sockel", slot, bevel=0.003)
    s.box((0, (FRONT_Y + BACK_Y) / 2 + inset / 2 - 0.01, BASE_Z / 2 + 0.001),
          (HALF_W * 2 - inset * 2, BACK_Y - FRONT_Y - inset * 1.5, BASE_Z + 0.002), step=0.3, dent=0.0006)


def framed_panels(k, frame_slot, field_slot, z0=0.16, z1=0.88, bar=0.045, raised=False):
    """Drei Felder vorn (zwischen den Ecken und Trennwänden), je Rahmen + Füllung. Liefert die
    Mitten und Größen der Füllungen."""
    fr = k.part("Rahmen", frame_slot, bevel=0.004)
    fi = k.part("Füllungen", field_slot, bevel=0.008 if raised else 0.003)
    spans = [(-HALF_W + 0.05, -DIVIDER_X - 0.035), (-DIVIDER_X + 0.035, DIVIDER_X - 0.035), (DIVIDER_X + 0.035, HALF_W - 0.05)]
    fields = []
    for x0, x1 in spans:
        xc, w = (x0 + x1) / 2, x1 - x0
        y = FRONT_Y - 0.005
        fr.box((xc, y, z1 - bar / 2), (w, 0.012, bar), step=0.3, dent=0.0006)
        fr.box((xc, y, z0 + bar / 2), (w, 0.012, bar), step=0.3, dent=0.0006)
        for sx in (x0 + bar / 2, x1 - bar / 2):
            fr.box((sx, y + 0.0005, (z0 + z1) / 2), (bar, 0.0115, z1 - z0 - bar * 1.6), step=0.3, dent=0.0006)
        fw, fh = w - bar * 2 + 0.004, z1 - z0 - bar * 2 + 0.004
        fi.box((xc, FRONT_Y - (0.007 if raised else 0.002), (z0 + z1) / 2), (fw, 0.012 if raised else 0.004, fh), step=0.3, dent=0.0006)
        fields.append((xc, (z0 + z1) / 2, fw, fh))
    return fields


# --- Schlichte Holztheke (stilneutral, Standard) ---

def build_counter_classic(k):
    FN.wood(k, FN.OAK_MID)
    k.mat("wood_dark", FN.WALNUT, grain="wood", rough=0.62, vary=0.07, bump=0.1)
    k.mat("metal", (0.25, 0.24, 0.22), grain="smooth", rough=0.45, metal=0.5, vary=0.04)
    k.mat("paper", (0.95, 0.93, 0.87), grain="paint", rough=0.85, vary=0.03)
    k.mat("box", (0.74, 0.6, 0.44), grain="paint", rough=0.85, vary=0.08)
    book_mats(k)
    rnd = random.Random(k.seed)
    carcass(k, "wood")
    plinth(k, "wood_dark")
    framed_panels(k, "wood", "wood")
    top = k.part("Platte", "wood", bevel=0.009)
    top.box((0, sum(TOP_Y) / 2, (UNDER_TOP + TOP_Z) / 2), (2.0, TOP_Y[1] - TOP_Y[0], TOP_Z - UNDER_TOP), step=0.3, dent=0.0008)
    drawers(k, "wood", "metal", handle="bar")
    # Hinten: Bücher, ein Karton, Papierstapel
    back_books(k, -HALF_W + 0.04, -DIVIDER_X - 0.05, BASE_Z + BOARD, rnd)
    back_books(k, -HALF_W + 0.06, -DIVIDER_X - 0.2, SHELF_Z + 0.011, rnd, max_h=0.22)
    bx = k.part("Karton", "box", bevel=0.004)
    bx.box((0.62, 0.02, BASE_Z + BOARD + 0.11), (0.42, 0.34, 0.22), step=0.3, dent=0.002)
    paper = k.part("Papier", "paper", bevel=0.001)
    for i in range(5):
        paper.box((0.55 + rnd.uniform(-0.01, 0.01), 0.04, SHELF_Z + 0.013 + i * 0.012), (0.21, 0.297, 0.01), step=0.5, dent=0.0004,
                  turn=(0, 0, rnd.uniform(-4, 4)))
    book_pile(k, 0.8, 0.05, SHELF_Z + 0.011, 3, rnd)


# --- Bibliothekstheke (Dark Academia) ---

def build_counter_dark_academia(k):
    FD.wood(k)
    FD.brass(k)
    FD.leather(k, FD.BOTTLE)
    k.mat("letters", (0.2, 0.13, 0.08), grain="smooth", rough=0.5, vary=0.02)
    k.mat("paper", (0.93, 0.89, 0.78), grain="paint", rough=0.85, vary=0.04)
    book_mats(k)
    rnd = random.Random(k.seed)
    carcass(k, "wood")
    plinth(k, "wood", inset=0.01)
    fields = framed_panels(k, "wood", "wood", z0=0.2, z1=0.86, raised=True)
    # Zierleisten um die Füllungen
    mold = k.part("Zierleisten", "wood", bevel=0.0)
    for xc, zc, fw, fh in fields:
        hw, hh = fw / 2 - 0.006, fh / 2 - 0.006
        pts = [(xc - hw, FRONT_Y - 0.0135, zc - hh), (xc + hw, FRONT_Y - 0.0135, zc - hh), (xc + hw, FRONT_Y - 0.0135, zc + hh),
               (xc - hw, FRONT_Y - 0.0135, zc + hh), (xc - hw, FRONT_Y - 0.0135, zc - hh)]
        mold.tube(pts, 0.0055, segs=6)
    # Pilaster mit Kanneluren an den Ecken und vor den Trennwänden
    pil = k.part("Pilaster", "wood", bevel=0.004)
    for x in (-HALF_W + 0.025, -DIVIDER_X, DIVIDER_X, HALF_W - 0.025):
        pil.box((x, FRONT_Y - 0.008, 0.53), (0.062, 0.018, 0.68), step=0.3, dent=0.0006)
        pil.box((x, FRONT_Y - 0.012, 0.9), (0.08, 0.026, 0.05), step=0.3, dent=0.0006)
        pil.box((x, FRONT_Y - 0.012, 0.165), (0.08, 0.026, 0.07), step=0.3, dent=0.0006)
        for dx in (-0.016, 0.0, 0.016):
            pil.tube([(x + dx, FRONT_Y - 0.017, 0.215), (x + dx, FRONT_Y - 0.017, 0.86)], 0.0045, segs=6, round_ends=True)
        # Konsole unter dem Überstand der Platte
        pil.box((x, FRONT_Y - 0.025, 0.937), (0.05, 0.05, 0.036), step=0.3, dent=0.0006)
    # Platte: Walnuss mit gestuftem Rand, grüne Lederauflage mit Goldlinie
    top = k.part("Platte", "wood", bevel=0.008)
    yc, d = sum(TOP_Y) / 2, TOP_Y[1] - TOP_Y[0]
    top.box((0, yc, 0.978), (2.0, d, 0.038), step=0.3, dent=0.0008)
    top.box((0, yc, UNDER_TOP + 0.004), (1.96, d - 0.03, 0.012), step=0.3, dent=0.0006)
    inlay = k.part("Lederauflage", "leather", bevel=0.002)
    inlay.box((0, yc + 0.01, 0.9965), (1.74, 0.44, 0.007), step=0.2, dent=0.0)
    gold = k.part("Goldprägung", "brass", bevel=0.0)
    hw, hd = 0.84, 0.2
    gold.tube([(-hw, yc + 0.01 - hd, 0.9995), (hw, yc + 0.01 - hd, 0.9995), (hw, yc + 0.01 + hd, 0.9995), (-hw, yc + 0.01 + hd, 0.9995),
               (-hw, yc + 0.01 - hd, 0.9995)], 0.0016, segs=4)
    # Messing-Fußstange vorn mit drei Haltern
    rail = k.part("Fußstange", "brass", bevel=0.0)
    rail.tube([(-0.86, -0.326, 0.15), (0.86, -0.326, 0.15)], 0.013, segs=12, round_ends=True)
    for x in (-0.7, 0.0, 0.7):
        rail.tube([(x, FRONT_Y - 0.004, 0.17), (x, -0.32, 0.17), (x, -0.326, 0.155)], 0.007, segs=8, smooth=1)
        rail.lathe([(0.0, 0.0), (0.022, 0.0), (0.022, 0.006), (0.0, 0.006)], (x, FRONT_Y - 0.002, 0.17), segs=16, turn=(90, 0))
    # Messingschild "Ausleihe" auf der mittleren Füllung
    plate = k.part("Schild", "brass", bevel=0.002)
    plate.box((0, FRONT_Y - 0.0155, 0.69), (0.34, 0.006, 0.075), step=0.5, dent=0.0)
    for sx in (-0.155, 0.155):
        plate.blob((sx, FRONT_Y - 0.019, 0.69), 0.005, subdiv=1, lump=0.0, scale=(1, 0.5, 1))
    letters = k.part("Schrift", "letters", bevel=0.0, settle=False)
    letters.text("AUSLEIHE", 0.042, 0.003, Matrix.Translation((0, FRONT_Y - 0.0185, 0.676)) @ UP, font="DejaVuSerif.ttf",
                 spacing=1.15, resolution=4)
    # Hinten: Messing-Bügelgriffe mit Kärtchen, Bücher, Karteikasten, Papiere
    drawers(k, "wood", "brass", handle="bar")
    lab = k.part("Kärtchen", "paper", bevel=0.0)
    span = UNDER_TOP - BASE_Z - BOARD
    for j in range(3):
        z = BASE_Z + BOARD + span / 3 * (j + 0.5)
        lab.box((0, BACK_Y + 0.0095, z - (span / 3 - 0.018) * 0.15), (0.05, 0.002, 0.016), step=0.5, dent=0.0)
    palette = [FD.BORDEAUX, FD.BOTTLE, FD.NAVY, FD.CHOCOLATE, FD.COGNAC]
    back_books(k, -HALF_W + 0.04, -DIVIDER_X - 0.03, BASE_Z + BOARD, rnd, palette=palette)
    back_books(k, -HALF_W + 0.04, -DIVIDER_X - 0.03, SHELF_Z + 0.011, rnd, max_h=0.26, palette=palette)
    back_books(k, DIVIDER_X + 0.04, HALF_W - 0.24, BASE_Z + BOARD, rnd, palette=palette, lean=False)
    box = k.part("Karteikasten", "wood", bevel=0.004)
    box.box((0.76, 0.06, SHELF_Z + 0.011 + 0.08), (0.24, 0.3, 0.16), step=0.3, dent=0.0008)
    hw2 = k.part("Beschläge", "brass", bevel=0.0)
    F.bar_handle(hw2, (0.76, 0.21, SHELF_Z + 0.12), 0.06, r=0.0035, depth=0.014, normal_y=1)
    hw2.box((0.76, 0.212, SHELF_Z + 0.07), (0.07, 0.003, 0.03), step=0.5, dent=0.0)
    book_pile(k, 0.48, 0.04, SHELF_Z + 0.011, 4, rnd, palette=palette)


# --- Helle Theke (Minimalistisch) ---

def build_counter_minimalist(k):
    k.mat("white", FM.WHITE, grain="paint", rough=0.7, vary=0.04, bump=0.06)
    FM.wood(k)
    k.mat("plinth", FM.CHARCOAL, grain="paint", rough=0.7, vary=0.04)
    k.mat("ceramic", (0.86, 0.83, 0.77), grain="plaster", rough=0.6, vary=0.06, scale=4.0)
    k.mat("clay", FM.CLAY, grain="plaster", rough=0.8, vary=0.08, scale=4.0)
    k.mat("linen", FM.SAND, grain="fabric", rough=0.95, vary=0.06, bump=0.3)
    book_mats(k)
    rnd = random.Random(k.seed)
    R = 0.2  # Rundung der vorderen Ecken
    # Korpus: runde vordere Ecken (Schalen), gerade Front und Seiten
    c = k.part("Korpus", "white", bevel=0.003)
    h = UNDER_TOP - BASE_Z
    zc = (UNDER_TOP + BASE_Z) / 2
    c.box((0, FRONT_Y + BOARD / 2, zc), ((HALF_W - R) * 2 + 0.004, BOARD, h), step=0.3, dent=0.0006)
    for side in (-1, 1):
        y0 = FRONT_Y + R - 0.002
        c.box((side * (HALF_W - BOARD / 2), (y0 + BACK_Y) / 2, zc), (BOARD, BACK_Y - y0, h), step=0.3, dent=0.0006)
        m = Matrix.Translation((side * (HALF_W - R), FRONT_Y + R, zc)) @ Matrix.Rotation(math.radians(-90), 4, "Y")
        F.arc_shell(c, m, h, R, BOARD, 0 if side < 0 else -90, 90 if side < 0 else 0, seg_a=14, seg_l=6)
    i = k.part("Innenleben", "white", bevel=0.003)
    depth = BACK_Y - (FRONT_Y + BOARD)
    yc = (BACK_Y + FRONT_Y + BOARD) / 2
    for side in (-1, 1):
        i.box((side * DIVIDER_X, yc, (UNDER_TOP + BASE_Z) / 2), (0.022, depth, UNDER_TOP - BASE_Z), step=0.3, dent=0.0006)
    sh = k.part("Böden", "wood", bevel=0.003)
    for side in (-1, 1):
        x0, x1 = DIVIDER_X + 0.011, HALF_W - BOARD
        # Boden unten und Zwischenboden in Eiche; in der runden Ecke bleibt vorn etwas Luft
        for z in (BASE_Z + BOARD / 2, SHELF_Z):
            sh.box((side * (x0 + x1) / 2, (BACK_Y + FRONT_Y + R) / 2, z), (x1 - x0 + 0.004, BACK_Y - FRONT_Y - R, 0.022),
                   step=0.3, dent=0.0004)
            sh.box((side * (x0 + HALF_W - R) / 2, yc, z), (HALF_W - R - x0, depth, 0.022), step=0.3, dent=0.0004)
    i.box((0, yc - 0.01, (UNDER_TOP + BASE_Z) / 2), (DIVIDER_X * 2 - 0.02, depth - 0.02, UNDER_TOP - BASE_Z), step=0.3, dent=0.0)
    # Sockel (zurückgesetzt, dunkel) und Platte (Eiche, runde Ecken wie der Korpus)
    pl = k.part("Sockel", "plinth", bevel=0.002)
    pl.slab(_rounded_rect(HALF_W - 0.03, FRONT_Y + 0.03, BACK_Y - 0.02, R - 0.03), BASE_Z + 0.002, Matrix.Identity(4), dent=0.0)
    top = k.part("Platte", "wood", bevel=0.008)
    top.slab(_rounded_rect(1.0, TOP_Y[0], TOP_Y[1], R + 0.055, back_r=0.03), TOP_Z - UNDER_TOP, Matrix.Translation((0, 0, UNDER_TOP)),
             dent=0.0)
    # Lamellen vorn (Eiche, halbrund) zwischen den runden Ecken
    fl = k.part("Lamellen", "wood", bevel=0.0)
    n = 40
    for j in range(n + 1):
        x = -(HALF_W - R - 0.02) + (HALF_W - R - 0.02) * 2 * j / n
        fl.tube([(x, FRONT_Y - 0.002, BASE_Z + 0.03), (x, FRONT_Y - 0.002, UNDER_TOP - 0.03)], 0.0135, segs=8, round_ends=True)
    # Hinten: grifflose Schübe mit Eichen-Leiste, Keramik, Leinenkiste, ein paar Bücher
    drawers(k, "white", "wood", handle="tab")
    cer = k.part("Vasen", "ceramic", bevel=0.0)
    cer.lathe([(0.0, 0.0), (0.05, 0.0), (0.07, 0.06), (0.06, 0.14), (0.03, 0.2), (0.032, 0.23), (0.026, 0.23), (0.0, 0.2)],
              (-0.75, 0.06, SHELF_Z + 0.011), segs=20)
    cl = k.part("Schale", "clay", bevel=0.0)
    cl.lathe([(0.0, 0.0), (0.04, 0.0), (0.085, 0.03), (0.09, 0.05), (0.08, 0.052), (0.035, 0.012), (0.0, 0.012)],
             (-0.53, 0.04, SHELF_Z + 0.011), segs=22)
    ln = k.part("Leinenkiste", "linen", bevel=0.01)
    F.pillow(ln, (0.62, 0.03, BASE_Z + BOARD + 0.1), (0.42, 0.32, 0.2), roundness=6.0, puff=0.004, step=0.05)
    back_books(k, DIVIDER_X + 0.05, HALF_W - 0.25, SHELF_Z + 0.011, rnd, max_h=0.22,
               palette=[FM.SAND, FM.SAGE, FM.DUSTY_BLUE, FM.CREAM, FM.CLAY], lean=False)
    book_pile(k, -0.62, 0.05, BASE_Z + BOARD, 3, rnd, palette=[FM.SAGE, FM.CREAM, FM.DUSTY_BLUE])


def _rounded_rect(half_w, y_front, y_back, r, back_r=0.0, n=8):
    """Umriss (gegen den Uhrzeigersinn) mit runden vorderen Ecken (r) und leicht runden hinteren (back_r)."""
    pts = []
    corners = [((half_w - r, y_front + r), r, -90, 0), ((half_w - back_r, y_back - back_r), back_r, 0, 90),
               ((-half_w + back_r, y_back - back_r), back_r, 90, 180), ((-half_w + r, y_front + r), r, 180, 270)]
    for (cx, cy), rr, a0, a1 in corners:
        steps = n if rr > 0 else 0
        for j in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * j / max(steps, 1))
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
            if steps == 0:
                break
    return pts


# --- Landhaustheke ---

def build_counter_country(k):
    FC.paint(k, FC.SAGE)
    FC.paint(k, (0.55, 0.64, 0.52), slot="paint_dark")
    FC.pine(k)
    FC.check(k, FC.CHECK_RED, slot="curtain", size=0.03)
    k.mat("porcelain", (0.95, 0.93, 0.88), grain="smooth", rough=0.35, vary=0.03)
    k.mat("bloom", FC.ROSE, grain="paint", rough=0.7, vary=0.06)
    k.mat("bloom_b", FC.BUTTER, grain="paint", rough=0.7, vary=0.06)
    k.mat("leafpaint", (0.45, 0.58, 0.4), grain="paint", rough=0.7, vary=0.06)
    k.mat("enamel", (0.92, 0.9, 0.84), grain="smooth", rough=0.4, vary=0.04)
    k.mat("enamel_rim", (0.2, 0.28, 0.45), grain="smooth", rough=0.4, vary=0.03)
    k.mat("linen", FC.CREAM, grain="fabric", rough=0.95, vary=0.05, bump=0.25)
    FC.floral(k, FC.POWDER, slot="linen_b", size=0.05)
    book_mats(k)
    rnd = random.Random(k.seed)
    carcass(k, "paint")
    plinth(k, "paint_dark", inset=0.015)
    # Vorn: Rahmen und Nut-und-Feder-Bretter (senkrecht, mit Perlstab an den Fugen)
    fields = framed_panels(k, "paint", "paint", z0=0.14, z1=0.88, bar=0.05)
    bead = k.part("Perlstäbe", "paint", bevel=0.0)
    for xc, zc, fw, fh in fields:
        n = max(3, int(round(fw / 0.085)))
        for j in range(1, n):
            x = xc - fw / 2 + fw * j / n
            bead.tube([(x, FRONT_Y - 0.003, zc - fh / 2 + 0.004), (x, FRONT_Y - 0.003, zc + fh / 2 - 0.004)], 0.0035, segs=5)
    # Gemalte Blumenranke auf dem oberen Rahmen der Mitte
    blooms = [k.part("Blüten rosa", "bloom", bevel=0.0, settle=False), k.part("Blüten gelb", "bloom_b", bevel=0.0, settle=False)]
    leaves = k.part("Blätter", "leafpaint", bevel=0.0, settle=False)
    zr = 0.88 - 0.025
    for j in range(9):
        x = -0.24 + 0.48 * j / 8
        if j % 2 == 0:
            blooms[(j // 2) % 2].star((x, FRONT_Y - 0.0135, zr), (0, -1, 0), 0.042, 5, rnd, thick=0.0025, cup=0.0)
        else:
            for s in (-1, 1):
                leaves.leaf((x - s * 0.008, FRONT_Y - 0.0125, zr), Vector((s * 0.85, 0, 0.45)).normalized(), Vector((0, -1, 0)), 0.042, 0.018,
                            shape="oval", thick=0.002, curl=0.0, segs=5)
    # Leiste unter der Platte, Platte aus Kiefer mit Hirnleisten
    crown = k.part("Gesims", "paint", bevel=0.0)
    crown.tube([(-HALF_W - 0.005, FRONT_Y - 0.008, UNDER_TOP - 0.012), (HALF_W + 0.005, FRONT_Y - 0.008, UNDER_TOP - 0.012)], 0.012, segs=8)
    top = k.part("Platte", "wood", bevel=0.007)
    yc, d = sum(TOP_Y) / 2, TOP_Y[1] - TOP_Y[0]
    top.box((0, yc, (UNDER_TOP + TOP_Z) / 2), (1.86 + 0.004, d - 0.01, TOP_Z - UNDER_TOP), step=0.3, dent=0.0008)
    for side in (-1, 1):
        top.box((side * 0.965, yc, (UNDER_TOP + TOP_Z) / 2 - 0.0005), (0.07, d, TOP_Z - UNDER_TOP - 0.001), step=0.3, dent=0.0006)
    # Hinten: Porzellanknäufe, Karo-Vorhang links, rechts Leinen, Emaillekanne, Bücher
    drawers(k, "paint", "porcelain", handle="knob")
    cur = k.part("Vorhang", "curtain", bevel=0.0)
    x0, x1 = -HALF_W + BOARD + 0.005, -DIVIDER_X - 0.016
    z_top, z_bot = UNDER_TOP - 0.03, BASE_Z + BOARD + 0.02
    folds = 9

    def wave(u, v):
        return 0.012 * math.sin(u * folds * 2 * math.pi) + 0.004 * v

    cur.sheet((x0, BACK_Y + 0.012, z_bot), (x1 - x0, 0, 0), (0, 0, z_top - z_bot), 72, 8, 0.004, offset=wave)
    rod = k.part("Stange", "porcelain", bevel=0.0)
    rod.tube([(x0 - 0.004, BACK_Y + 0.012, z_top + 0.008), (x1 + 0.004, BACK_Y + 0.012, z_top + 0.008)], 0.006, segs=8, round_ends=True)
    l1 = k.part("Leinen", "linen", bevel=0.0)
    l2 = k.part("Leinen geblümt", "linen_b", bevel=0.0)
    z = SHELF_Z + 0.011
    for j, part in enumerate((l1, l2, l1)):
        F.pillow(part, (0.78, 0.05, z + 0.016), (0.24, 0.26, 0.032), roundness=5.0, puff=0.003, step=0.04)
        z += 0.03
    en = k.part("Kanne", "enamel", bevel=0.0)
    en.lathe([(0.0, 0.0), (0.06, 0.0), (0.068, 0.04), (0.066, 0.12), (0.05, 0.17), (0.045, 0.2), (0.05, 0.215), (0.0, 0.215)],
             (0.5, 0.06, BASE_Z + BOARD), segs=20)
    en.tube([(0.5, 0.06 + 0.06, BASE_Z + BOARD + 0.17), (0.5, 0.06 + 0.11, BASE_Z + BOARD + 0.13),
             (0.5, 0.06 + 0.065, BASE_Z + BOARD + 0.06)], 0.007, segs=6, smooth=2)
    rim = k.part("Kannenrand", "enamel_rim", bevel=0.0)
    F.ring(rim, (0.5, 0.06, BASE_Z + BOARD + 0.212), 0.049, 0.004, n=24, segs=5)
    back_books(k, DIVIDER_X + 0.05, HALF_W - 0.42, SHELF_Z + 0.011, rnd, max_h=0.22,
               palette=[FC.CHECK_RED, FC.CHECK_GREEN, FC.CHECK_BLUE, FC.BUTTER, FC.ROSE])
    FC.wicker(k)
    basket = k.part("Korb", "wicker", bevel=0.0)
    FC.weave(basket, (0.76, 0.03, BASE_Z + BOARD + 0.004), 0.13, 0.15, 0.17, rnd, staves=22, rows=6)
    basket.lathe([(0.0, 0.0), (0.13, 0.0), (0.13, 0.008), (0.0, 0.008)], (0.76, 0.03, BASE_Z + BOARD), segs=22)


# --- Einwurf: Messingklappe (Dark Academia) ---

def build_slot_dark_academia(k):
    FD.wood(k)
    FD.brass(k)
    k.mat("dark", (0.06, 0.05, 0.04), grain="smooth", rough=0.9, vary=0.0)
    board = k.part("Brett", "wood", bevel=0.004)
    hw, z0, z1, arch = 0.17, -0.13, 0.1, 0.085
    outline = [(-hw, z0), (hw, z0)]
    for j in range(17):
        a = math.pi * j / 16
        outline.append((math.cos(a) * hw, z1 + math.sin(a) * arch))
    outline.append((-hw, z0))
    outline = outline[:-1]
    board.slab(outline, 0.022, UP, dent=0.0)
    mold = k.part("Profil", "wood", bevel=0.0)
    inner = [(x * 0.9, (z - (z0 + z1) / 2) * 0.9 + (z0 + z1) / 2) for x, z in outline]
    mold.tube([(x, -0.0235, z) for x, z in inner + inner[:1]], 0.0045, segs=6)
    plate = k.part("Messingplatte", "brass", bevel=0.003)
    plate.box((0, -0.025, -0.01), (0.25, 0.008, 0.075), step=0.5, dent=0.0)
    for sx in (-0.11, 0.11):
        for sz in (-0.038, 0.018):
            plate.blob((sx, -0.029, sz), 0.0042, subdiv=1, lump=0.0, scale=(1, 0.5, 1))
    k.part("Schlitz", "dark", bevel=0.0, settle=False).box((0, -0.028, -0.014), (0.19, 0.004, 0.02), step=0.5, dent=0.0)
    flap = k.part("Klappe", "brass", bevel=0.002)
    hinge = Matrix.Translation((0, -0.031, 0.0)) @ Matrix.Rotation(math.radians(-22), 4, "X")
    flap.box((0, -0.002, -0.016), (0.2, 0.004, 0.03), step=0.5, dent=0.0, matrix=hinge)
    flap.tube([(-0.1, -0.031, 0.0), (0.1, -0.031, 0.0)], 0.0035, segs=8, round_ends=True)
    flap.blob((0, -0.038, -0.024), 0.006, subdiv=1, lump=0.0, scale=(1.6, 0.8, 0.8))
    letters = k.part("Schrift", "brass", bevel=0.0, settle=False)
    letters.text("BÜCHER", 0.038, 0.003, Matrix.Translation((0, -0.022, 0.06)) @ UP, font="DejaVuSerif.ttf", spacing=1.15, resolution=4)
    letters.text("Rückgabe", 0.024, 0.0025, Matrix.Translation((0, -0.022, -0.1)) @ UP, font="DejaVuSerif-Italic.ttf", resolution=4)


# --- Einwurf: Schlichte Platte (Minimalistisch) ---

def build_slot_minimalist(k):
    k.mat("white", FM.WHITE, grain="paint", rough=0.6, vary=0.03, bump=0.04)
    FM.wood(k)
    k.mat("dark", (0.08, 0.08, 0.08), grain="smooth", rough=0.9, vary=0.0)
    k.mat("letters", FM.CHARCOAL, grain="smooth", rough=0.6, vary=0.02)
    plate = k.part("Platte", "white", bevel=0.006)
    pts = []
    hw, z0, z1, r = 0.15, -0.11, 0.1, 0.035
    for (cx, cz), a0 in (((hw - r, z0 + r), -90), ((hw - r, z1 - r), 0), ((-hw + r, z1 - r), 90), ((-hw + r, z0 + r), 180)):
        for j in range(7):
            a = math.radians(a0 + 90 * j / 6)
            pts.append((cx + math.cos(a) * r, cz + math.sin(a) * r))
    plate.slab(pts, 0.018, UP, dent=0.0)
    lip = k.part("Rand", "wood", bevel=0.0)
    lw, lh = 0.115, 0.017
    lip.tube([(-lw, -0.019, -lh), (lw, -0.019, -lh), (lw, -0.019, lh), (-lw, -0.019, lh), (-lw, -0.019, -lh)], 0.005, segs=6)
    k.part("Schlitz", "dark", bevel=0.0, settle=False).box((0, -0.0195, 0), (2 * lw - 0.004, 0.004, 2 * lh - 0.004), step=0.5, dent=0.0)
    ledge = k.part("Leiste", "wood", bevel=0.003)
    ledge.box((0, -0.024, -0.075), (0.18, 0.012, 0.008), step=0.5, dent=0.0)
    letters = k.part("Schrift", "letters", bevel=0.0, settle=False)
    letters.text("Rückgabe", 0.028, 0.002, Matrix.Translation((0, -0.018, 0.045)) @ UP, font="DejaVuSans.ttf", spacing=1.2, resolution=4)


# --- Einwurf: Briefkasten mit Dach (Landhaus) ---

def build_slot_country(k):
    FC.paint(k, FC.POWDER)
    FC.paint(k, FC.CREAM, slot="cream")
    k.mat("roof", (0.6, 0.32, 0.26), grain="paint", rough=0.8, vary=0.1, bump=0.15)
    k.mat("dark", (0.07, 0.06, 0.05), grain="smooth", rough=0.9, vary=0.0)
    k.mat("bloom", FC.ROSE, grain="paint", rough=0.7, vary=0.06)
    k.mat("bloom_b", FC.BUTTER, grain="paint", rough=0.7, vary=0.06)
    k.mat("leafpaint", (0.45, 0.58, 0.4), grain="paint", rough=0.7, vary=0.06)
    rnd = random.Random(k.seed)
    W, D, z0, z1 = 0.28, 0.06, -0.13, 0.11
    box = k.part("Kasten", "paint", bevel=0.006)
    box.box((0, -D / 2, (z0 + z1) / 2), (W, D, z1 - z0), step=0.3, dent=0.0008)
    # Giebel und Dach (First quer über die Mitte, hinten endet das Dach vor der Wand)
    ridge_z, eave_z, over = 0.175, 0.105, 0.03
    gab = k.part("Giebel", "paint", bevel=0.002)
    for sx in (-W / 2 + 0.006, W / 2 - 0.006):
        m = Matrix.Translation((sx - 0.006, 0, 0)) @ Matrix.Rotation(math.radians(90), 4, "Y")
        gab.slab([(-z1 + 0.004, -0.002), (-z1 + 0.004, -D), (-ridge_z, -D / 2)], 0.012, m, dent=0.0)
    roof = k.part("Dach", "roof", bevel=0.003)
    rise_per_m = (ridge_z - eave_z) / (D / 2 + over)
    lift = 0.007  # Dach liegt auf den Giebelkanten
    top = Vector((0, -D / 2, ridge_z + lift))
    roof.span(top, (0, -D - over, eave_z + lift), W + 0.05, 0.012, step=0.3, dent=0.0006)
    back_y = -0.009
    roof.span(top, (0, back_y, ridge_z - (back_y + D / 2) * rise_per_m + lift), W + 0.05, 0.012, step=0.3, dent=0.0006)
    roof.tube([(-W / 2 - 0.028, -D / 2, ridge_z + lift + 0.006), (W / 2 + 0.028, -D / 2, ridge_z + lift + 0.006)], 0.008, segs=8,
              round_ends=True)
    # Schlitz mit cremefarbener Klappe, Schrift, gemalte Blumen
    k.part("Schlitz", "dark", bevel=0.0, settle=False).box((0, -D - 0.0005, 0.04), (0.19, 0.004, 0.018), step=0.5, dent=0.0)
    flap = k.part("Klappe", "cream", bevel=0.002)
    hinge = Matrix.Translation((0, -D - 0.003, 0.056)) @ Matrix.Rotation(math.radians(-18), 4, "X")
    flap.box((0, -0.002, -0.018), (0.21, 0.005, 0.034), step=0.5, dent=0.0, matrix=hinge)
    k.mat("letters", (0.22, 0.3, 0.46), grain="paint", rough=0.6, vary=0.03)
    letters = k.part("Schrift", "letters", bevel=0.0, settle=False)
    letters.text("Bücher", 0.04, 0.003, Matrix.Translation((0, -D, -0.035)) @ UP, font="DejaVuSerif-Italic.ttf", resolution=4)
    blooms = [k.part("Blüten rosa", "bloom", bevel=0.0, settle=False), k.part("Blüten gelb", "bloom_b", bevel=0.0, settle=False)]
    leaves = k.part("Blätter", "leafpaint", bevel=0.0, settle=False)
    for j, x in enumerate((-0.09, -0.03, 0.03, 0.09)):
        zz = -0.095 + (0.008 if j % 2 else 0.0)
        blooms[j % 2].star((x, -D - 0.002, zz), (0, -1, 0), 0.022, 5, rnd, thick=0.002, cup=0.0)
        for s in (-1, 1):
            leaves.leaf((x + s * 0.008, -D - 0.0015, zz - 0.006), Vector((s, 0, -0.4)).normalized(), Vector((0, -1, 0)), 0.022, 0.01,
                        shape="oval", thick=0.0018, curl=0.0, segs=5)


# --- Kasse (Modul der Theke, stilneutral; Bedienseite -y, Anzeige auch nach hinten zur Kundschaft) ---

def build_cash_register(k):
    FN.wood(k, FN.OAK_MID)
    FD.brass(k)
    k.mat("key", (0.95, 0.92, 0.84), grain="smooth", rough=0.4, vary=0.03)
    k.mat("key_red", (0.72, 0.24, 0.2), grain="smooth", rough=0.4, vary=0.03)
    k.mat("screen", (0.98, 0.9, 0.72), grain="smooth", rough=0.3, vary=0.02, emit=1.4, emit_color=(1.0, 0.84, 0.58))
    base = k.part("Gehäuse", "wood", bevel=0.006)
    base.box((0, 0.0, 0.006), (0.38, 0.34, 0.012), step=0.3, dent=0.0004)
    base.box((0, 0.0, 0.056), (0.36, 0.32, 0.09), step=0.3, dent=0.0006)
    base.box((0, 0.11, 0.167), (0.24, 0.08, 0.135), step=0.3, dent=0.0006)
    base.box((0, 0.11, 0.24), (0.26, 0.095, 0.016), step=0.3, dent=0.0004)
    deck = Matrix.Translation((0, -0.055, 0.112)) @ Matrix.Rotation(math.radians(22), 4, "X")
    base.box((0, 0, 0), (0.34, 0.17, 0.05), step=0.3, dent=0.0004, matrix=deck)
    drawer = k.part("Schublade", "wood", bevel=0.004)
    drawer.box((0, -0.162, 0.052), (0.32, 0.012, 0.068), step=0.3, dent=0.0004)
    hw = k.part("Beschläge", "brass", bevel=0.0)
    F.knob(hw, (0, -0.168, 0.052), r=0.011)
    # Fenster der Anzeige (vorn und hinten) mit Messingrahmen
    win = k.part("Anzeige", "screen", bevel=0.0, settle=False)
    for y, sign in ((0.0695, -1), (0.1505, 1)):
        win.box((0, y, 0.19), (0.16, 0.004, 0.042), step=0.5, dent=0.0)
        hw.tube([(-0.084, y + sign * 0.002, 0.168), (0.084, y + sign * 0.002, 0.168), (0.084, y + sign * 0.002, 0.212),
                 (-0.084, y + sign * 0.002, 0.212), (-0.084, y + sign * 0.002, 0.168)], 0.003, segs=5)
    # Tasten: drei Reihen auf dem schrägen Feld, die rechte untere rot
    keys = k.part("Tasten", "key", bevel=0.0)
    red = k.part("Taste rot", "key_red", bevel=0.0)
    for row, ly in enumerate((-0.05, 0.0, 0.05)):
        for col in range(5):
            lx = -0.12 + col * 0.06
            stem = deck @ Vector((lx, ly, 0.025))
            top = deck @ Vector((lx, ly, 0.04))
            hw.tube([stem, top], 0.0035, segs=6)
            part = red if (row == 0 and col == 4) else keys
            part.lathe([(0.0, 0.0), (0.013, 0.0), (0.014, 0.004), (0.011, 0.008), (0.0, 0.009)], top, segs=14, turn=(22, 0))
    # Kurbel rechts
    hw.blob((0.186, 0.0, 0.058), 0.014, subdiv=1, lump=0.0, scale=(0.6, 1, 1))
    hw.tube([(0.19, 0.0, 0.058), (0.2, -0.02, 0.1), (0.2, -0.03, 0.125)], 0.0045, segs=6, smooth=1)
    wood_knob = k.part("Kurbelgriff", "wood", bevel=0.0)
    wood_knob.lathe([(0.0, 0.0), (0.008, 0.0), (0.009, 0.02), (0.006, 0.03), (0.0, 0.031)], (0.199, -0.03, 0.125), segs=12,
                    turn=(0, 90))


# --- Theken-Tablet (stilneutral; Bildschirm -y, leicht nach hinten gekippt) ---

def build_tablet(k):
    FN.wood(k, FN.OAK_MID)
    k.mat("case", (0.33, 0.24, 0.19), grain="smooth", rough=0.5, vary=0.08, scale=5.0, bump=0.12)
    k.mat("screen", (0.98, 0.9, 0.74), grain="smooth", rough=0.3, vary=0.02, emit=1.2, emit_color=(1.0, 0.86, 0.62))
    stand = k.part("Ständer", "wood", bevel=0.005)
    stand.box((0, 0.0, 0.008), (0.16, 0.11, 0.016), step=0.3, dent=0.0004)
    stand.box((0, -0.044, 0.022), (0.17, 0.02, 0.022), step=0.3, dent=0.0004)
    stand.span((0, 0.045, 0.012), (0, 0.03, 0.124), 0.04, 0.012, step=0.3, dent=0.0003)
    tilt = Matrix.Translation((0, -0.034, 0.026)) @ Matrix.Rotation(math.radians(-25), 4, "X")
    case = k.part("Hülle", "case", bevel=0.007)
    case.box((0, 0, 0.096), (0.27, 0.014, 0.19), step=0.3, dent=0.0004, matrix=tilt)
    screen = k.part("Bildschirm", "screen", bevel=0.0, settle=False)
    screen.box((0, -0.0075, 0.1), (0.236, 0.004, 0.152), step=0.5, dent=0.0, matrix=tilt)
    case.blob(tilt @ Vector((0, -0.007, 0.183)), 0.003, subdiv=1, lump=0.0)


ITEMS = [
    dict(id="counter_classic", kind="counter", name="Schlichte Holztheke", order=10, legacy=["wood_warm"], settle=0.35,
         desc="Eine ehrliche Theke aus Eiche mit drei Feldern vorn – passt zu allem.",
         styles=[], build=build_counter_classic),
    dict(id="counter_dark_academia", kind="counter", name="Bibliothekstheke", order=20, legacy=["wood_dark"], settle=0.35,
         desc="Walnuss mit Pilastern, grüner Lederauflage, Messingstange und dem Schild „Ausleihe“.",
         styles=["dark_academia"], build=build_counter_dark_academia),
    dict(id="counter_minimalist", kind="counter", name="Helle Theke", order=30, legacy=["painted_light"], settle=0.35,
         desc="Weiß mit runden Ecken, Eichenlamellen vorn und einer Platte aus heller Eiche.",
         styles=["minimalist"], build=build_counter_minimalist),
    dict(id="counter_country", kind="counter", name="Landhaustheke", order=40, settle=0.35,
         desc="Salbeigrün gestrichen, Kiefernplatte, gemalte Blumenranke und ein Karovorhang hinten.",
         styles=["country"], build=build_counter_country),
    dict(id="slot_dark_academia", kind="return_slot", name="Messingklappe", order=40, settle=0.3,
         desc="", styles=["dark_academia"], build=build_slot_dark_academia),
    dict(id="slot_minimalist", kind="return_slot", name="Schlichte Platte", order=50, settle=0.3,
         desc="", styles=["minimalist"], build=build_slot_minimalist),
    dict(id="slot_country", kind="return_slot", name="Briefkasten mit Dach", order=60, settle=0.3,
         desc="", styles=["country"], build=build_slot_country),
    dict(id="cash_register", kind="part", name="Kasse", settle=0.3, styles=[], build=build_cash_register),
    dict(id="tablet", kind="part", name="Theken-Tablet", settle=0.2, styles=[], build=build_tablet),
]
