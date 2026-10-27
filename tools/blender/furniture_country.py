"""Landhaus: ländlich, warm und bewohnt (Cottage, Shabby Chic) – bemaltes Holz in Creme, Salbei,
Rosé und Hellblau, Vichy-Karo und Blümchenstoffe, Spitze, Korb, Emaille, Keramik, Trockenblumen
(Etappe 6). Jedes Objekt: Beschreibung + Bau-Funktion (storybook_furniture, Vorderseite -y).
"""

import math
import random

from mathutils import Matrix, Vector

import storybook_furniture as F
import storybook_greenery as G

STYLE = ["country"]
PINE = (0.74, 0.56, 0.36)
CREAM = (0.93, 0.89, 0.8)
SAGE = (0.66, 0.74, 0.62)
ROSE = (0.88, 0.7, 0.7)
POWDER = (0.68, 0.78, 0.86)
BUTTER = (0.95, 0.88, 0.62)
WICKER = (0.72, 0.56, 0.36)
CHECK_RED = (0.75, 0.25, 0.25)
CHECK_BLUE = (0.35, 0.48, 0.7)
CHECK_GREEN = (0.45, 0.6, 0.45)
CHECK_PINK = (0.88, 0.55, 0.6)
PAINTS = [("cream", "Creme", CREAM), ("sage", "Salbei", SAGE), ("rose", "Altrosa", ROSE), ("powder", "Hellblau", POWDER),
          ("butter", "Butter", BUTTER)]
CHECKS = [("red", "Rot kariert", CHECK_RED), ("blue", "Blau kariert", CHECK_BLUE), ("green", "Grün kariert", CHECK_GREEN),
          ("pink", "Rosa kariert", CHECK_PINK)]


def paint(k, color=CREAM, slot="paint"):
    # gestrichenes Holz, leicht abgewetzt (Flecken), matt
    return k.mat(slot, color, grain="paint", rough=0.75, vary=0.09, bump=0.12, scale=5.0)


def pine(k, slot="wood"):
    return k.mat(slot, PINE, grain="wood", rough=0.65, vary=0.08, bump=0.1)


def check(k, color=CHECK_RED, slot="fabric", size=0.035, **extra):
    """Vichy-Karo (Farbvariante = Karofarbe, Grund bleibt hell). extra z. B. emit für Lampenschirme."""
    return k.mat(slot, color, grain="fabric", rough=0.92, vary=0.05, bump=0.25, pattern="check", pattern_size=size,
                 color3=(0.96, 0.93, 0.86), **extra)


def floral(k, color=CREAM, slot="fabric", size=0.06, flower=(0.86, 0.45, 0.52), heart=(0.95, 0.82, 0.35), **extra):
    """Blümchenstoff (Farbvariante = Grundfarbe, Blüten bleiben)."""
    return k.mat(slot, color, grain="fabric", rough=0.92, vary=0.05, bump=0.25, pattern="floral", pattern_size=size,
                 color2=flower, color3=heart, **extra)


def wicker(k, slot="wicker"):
    return k.mat(slot, WICKER, grain="wood", rough=0.8, vary=0.12, bump=0.2)


def paint_variants(slot="paint"):
    return [(vid, name, {slot: col}) for vid, name, col in PAINTS]


def check_variants(slot="fabric"):
    return [(vid, name, {slot: col}) for vid, name, col in CHECKS]


def weave(b, center, r_bottom, r_top, height, rnd, staves=24, rows=7, wall=0.006):
    """Korbgeflecht: senkrechte Staken und waagerechte Ruten, abwechselnd davor und dahinter."""
    c = Vector(center)
    for i in range(staves):
        a = 2 * math.pi * i / staves
        d = Vector((math.cos(a), math.sin(a), 0))
        b.tube([c + d * r_bottom, c + d * r_top + Vector((0, 0, height))], 0.0035, segs=5)
    for j in range(rows):
        t = (j + 0.5) / rows
        rr = r_bottom + (r_top - r_bottom) * t
        z = height * t
        pts = []
        for i in range(staves * 2 + 1):
            a = 2 * math.pi * i / (staves * 2)
            off = wall * (0.6 if (i + j) % 2 else -0.6)
            pts.append(c + Vector((math.cos(a) * (rr + off), math.sin(a) * (rr + off), z)))
        b.tube(pts, height / rows * 0.32, segs=5)


# --- Bemaltes Bücherregal ---

def build_painted_bookshelf(k):
    paint(k, SAGE)
    pine(k)
    W, D, H = 1.04, 0.36, 2.0
    c = k.part("Korpus", "paint", bevel=0.005)
    for side in (-1, 1):
        c.box((side * 0.5, 0, H / 2), (0.04, D, H), step=0.3, dent=0.0012)
    back = k.part("Rückwand", "paint", bevel=0.0)
    x = -0.48
    while x < 0.481:
        back.box((x + 0.03, 0.17, H / 2), (0.058, 0.014, H - 0.04), step=0.3, dent=0.0008)
        x += 0.06
    plinth = k.part("Sockel", "paint", bevel=0.006)
    plinth.box((0, -0.005, 0.06), (W, D, 0.12), step=0.3, dent=0.001)
    # Bogenschürze unten
    arch = [(-0.46, 0.0)] + [(-0.46 + 0.92 * i / 16, 0.045 - 0.03 * math.sin(math.pi * i / 16)) for i in range(17)] + [(0.46, 0.0)]
    plinth.slab([(x, y) for x, y in arch] + [(0.46, -0.0)], 0.02, Matrix.Translation((0, -0.19, 0.12)) @ Matrix.Rotation(math.radians(90), 4, "X"), dent=0.0)
    boards = k.part("Böden", "wood", bevel=0.004)
    tops = [0.12, 0.55, 0.98, 1.4]
    for t in tops[1:]:
        boards.box((0, -0.005, t - 0.015), (0.96, 0.33, 0.03), step=0.3, dent=0.0008)
    top = k.part("Kranz", "paint", bevel=0.006)
    top.box((0, -0.01, 1.82), (W + 0.04, D + 0.02, 0.03), step=0.3, dent=0.001)
    # Bogenkranz mit Herzchen-Ausschnitt angedeutet: geschwungene Blende
    crest = [(-0.52, 0.0), (0.52, 0.0)] + [(0.52 - 1.04 * i / 24, 0.06 + 0.1 * math.sin(math.pi * i / 24) ** 2) for i in range(25)]
    top.slab(crest, 0.022, Matrix.Translation((0, -0.17, 1.835)) @ Matrix.Rotation(math.radians(90), 4, "X"), dent=0.0)
    heart = k.part("Herz", "wood", bevel=0.0)
    hp = []
    for i in range(24):
        t = 2 * math.pi * i / 24
        hp.append((0.016 * math.sin(t) ** 3, 0.013 * math.cos(t) - 0.005 * math.cos(2 * t) - 0.002 * math.cos(3 * t)))
    heart.slab(hp, 0.006, Matrix.Translation((0, -0.183, 1.93)) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Scale(1.8, 4), dent=0.0)
    knobs = k.part("Rosetten", "wood", bevel=0.0)
    for side in (-1, 1):
        F.button(knobs, (side * 0.5, -0.185, 1.78), r=0.016, normal=(0, -1, 0))
    clear = tops[1:] + [1.805]
    for i in range(len(tops) - 1, -1, -1):
        k.row((0, -0.01, tops[i]), 0.94, clear[i] - tops[i] - 0.03, 0.31)
    for side in (-1, 1):
        k.collider((side * 0.5, 0, H / 2), (0.045, D, H))
    k.collider((0, 0.17, H / 2), (0.98, 0.016, H))
    k.collider((0, 0, 0.06), (W, D, 0.12))
    for t in tops[1:]:
        k.collider((0, -0.005, t - 0.015), (0.96, 0.33, 0.03))
    k.collider((0, -0.01, 1.82), (W + 0.04, D + 0.02, 0.03))
    k.surface((0, 0.02, 1.835), (W - 0.04, D - 0.08))


# --- Leiterregal ---

def build_ladder_shelf(k):
    paint(k, CREAM)
    pine(k)
    H = 1.6
    lean = math.radians(12)
    rails = k.part("Holme", "paint", bevel=0.0)
    for x in (-0.3, 0.3):
        rails.tube([(x, -0.2, 0.0), (x, -0.2 + math.tan(lean) * H, H)], 0.02, segs=10, round_ends=True)
    boards = k.part("Bretter", "wood", bevel=0.005)
    levels = [(0.25, 0.36), (0.65, 0.3), (1.05, 0.24), (1.42, 0.18)]
    for z, depth in levels:
        y_back = -0.2 + math.tan(lean) * z
        boards.box((0, y_back - depth / 2 + 0.03, z), (0.62, depth, 0.022), step=0.3, dent=0.0008)
        k.surface((0, y_back - depth / 2 + 0.03, z + 0.011), (0.56, depth - 0.02), max_height=0.3)
        k.collider((0, y_back - depth / 2 + 0.03, z), (0.62, depth, 0.022))
    for x in (-0.3, 0.3):
        k.collider((x, -0.2 + math.tan(lean) * H / 2, H / 2), (0.04, 0.06 + math.tan(lean) * H, H))


# --- Korbsessel mit Karokissen ---

def build_wicker_chair(k):
    wicker(k)
    check(k, CHECK_RED)
    rnd = random.Random(k.seed)
    b = k.part("Geflecht", "wicker", bevel=0.0)
    weave(b, (0, 0, 0.05), 0.3, 0.32, 0.36, rnd, staves=30, rows=8)
    b.lathe([(0.0, 0.0), (0.3, 0.0), (0.3, 0.05), (0.0, 0.05)], (0, 0, 0.0), segs=30)
    F.ring(b, (0, 0, 0.41), 0.325, 0.02, n=48, segs=8)
    # hohe, runde Rückenlehne aus Geflecht (Bogen hinten)
    back = k.part("Lehne", "wicker", bevel=0.0)
    for i in range(17):
        a = math.radians(200 + 140 * i / 16)
        d = Vector((math.cos(a), math.sin(a), 0))
        h = 0.36 + 0.42 * math.sin(math.pi * i / 16)
        back.tube([d * 0.31 + Vector((0, 0, 0.41)), d * 0.3 + Vector((0, 0, 0.41 + h))], 0.004, segs=5)
    arc = [Vector((math.cos(math.radians(a)) * 0.3, math.sin(math.radians(a)) * 0.3, 0.41 + 0.36 + 0.42 * math.sin(math.pi * (a - 200) / 140)))
           for a in range(200, 341, 7)]
    back.tube(arc, 0.022, segs=8, smooth=1, round_ends=True)
    for j in range(6):
        pts = []
        for i in range(29):
            a = math.radians(200 + 140 * i / 28)
            h = (0.36 + 0.42 * math.sin(math.pi * i / 28)) * (j + 0.5) / 6
            pts.append(Vector((math.cos(a) * (0.305 + (0.004 if (i + j) % 2 else -0.004)), math.sin(a) * (0.305 + (0.004 if (i + j) % 2 else -0.004)), 0.41 + h)))
        back.tube(pts, 0.012, segs=5)
    cush = k.part("Sitzkissen", "fabric", bevel=0.0)
    F.pillow(cush, (0, -0.02, 0.47), (0.52, 0.52, 0.11), roundness=2.4, puff=0.02, step=0.03)
    back_c = k.part("Rückenkissen", "fabric", bevel=0.0)
    F.pillow(back_c, (0, 0.18, 0.7), (0.42, 0.14, 0.32), roundness=2.6, puff=0.02, step=0.03)
    k.collider((0, 0, 0.26), (0.66, 0.66, 0.52))
    k.collider((0, 0.2, 0.75), (0.62, 0.24, 0.6))
    k.surface((0, -0.05, 0.525), (0.38, 0.34))
    k.seat((0, -0.04, 0.525))
    k.interact = (Vector((0, -0.02, 0.6)), Vector((0.6, 0.6, 0.45)))


# --- Sprossenstuhl ---

def build_ladder_chair(k):
    paint(k, CREAM)
    check(k, CHECK_RED)
    legs = k.part("Beine", "paint", bevel=0.0)
    for x in (-0.2, 0.2):
        F.turned_leg(legs, (x, -0.19, 0.0), 0.45, 0.02, style="spindle", segs=12)
        legs.tube([(x, 0.18, 0.0), (x, 0.2, 0.45), (x * 0.96, 0.24, 0.98)], lambda t: 0.021 - 0.004 * t, segs=10, smooth=1, round_ends=True)
        legs.blob((x * 0.96, 0.24, 0.99), 0.025, subdiv=1, lump=0.03)
    for y in (-0.19, 0.18):
        legs.tube([(-0.2, y, 0.17), (0.2, y, 0.17)], 0.011, segs=8)
    seat = k.part("Sitz", "paint", bevel=0.005)
    F.pillow(seat, (0, 0.0, 0.44), (0.46, 0.44, 0.03), roundness=4.0, step=0.04)
    for z in (0.62, 0.75, 0.88):
        y = 0.2 + (z - 0.45) * 0.075
        legs.tube([(-0.19, y, z), (0.0, y + 0.02, z), (0.19, y, z)], 0.017, segs=8, smooth=1)
    pad = k.part("Sitzkissen", "fabric", bevel=0.0)
    F.pillow(pad, (0, -0.01, 0.475), (0.42, 0.4, 0.05), roundness=3.2, puff=0.012, step=0.025)
    bows = k.part("Schleifen", "fabric", bevel=0.0)
    for x in (-0.2, 0.2):
        c = Vector((x, 0.19, 0.48))
        for sg in (-1, 1):
            bows.blob(c + Vector((sg * 0.022, -0.012, 0.0)), 0.016, subdiv=1, lump=0.1, scale=(1.2, 0.5, 0.8))
        bows.tube([c, c + Vector((0.006, -0.01, -0.06))], 0.004, segs=5, round_ends=True)
    k.collider((0, 0, 0.25), (0.46, 0.44, 0.5))
    k.collider((0, 0.23, 0.74), (0.46, 0.08, 0.5))
    k.surface((0, -0.01, 0.5), (0.36, 0.34))
    k.seat((0, -0.02, 0.5))
    k.interact = (Vector((0, 0, 0.55)), Vector((0.46, 0.44, 0.4)))


# --- Blümchensofa ---

def build_floral_sofa(k):
    floral(k, CREAM)
    pine(k)
    feet = k.part("Füße", "wood", bevel=0.004)
    for x in (-0.7, 0.7):
        for y in (-0.3, 0.3):
            F.turned_leg(feet, (x, y, 0.0), 0.08, 0.03, style="bun")
    base = k.part("Polster", "fabric", bevel=0.0)
    F.pillow(base, (0, 0, 0.24), (1.6, 0.8, 0.26), roundness=3.6, puff=0.006, step=0.045)
    # Volant (Rüschen) rundherum unten
    ruffle = k.part("Volant", "fabric", bevel=0.0)
    ruffle.lathe([(0.0, 0.0), (0.4, 0.0), (0.405, 0.07), (0.0, 0.07)], (0, 0, 0.09), segs=72, wave=0.03, waves=24)
    for v in ruffle.bm.verts:
        v.co.x *= 2.0
    back = k.part("Rückenlehne", "fabric", bevel=0.0)
    F.pillow(back, (0, 0.3, 0.6), (1.56, 0.22, 0.46), roundness=3.0, puff=0.016, step=0.04)
    for side in (-1, 1):
        arm = k.part("Armlehne", "fabric", bevel=0.0)
        F.pillow(arm, (side * 0.74, 0.0, 0.45), (0.2, 0.8, 0.38), roundness=3.0, puff=0.008, step=0.04)
        arm.tube([(side * 0.76, -0.4, 0.62), (side * 0.76, 0.38, 0.62)], 0.07, segs=16, round_ends=True)
    for x in (-0.34, 0.34):
        cush = k.part("Sitzkissen", "fabric", bevel=0.0)
        F.pillow(cush, (x, -0.06, 0.42), (0.66, 0.6, 0.14), roundness=3.0, puff=0.02, step=0.035)
    k.mat("cushion", ROSE, grain="fabric", rough=0.92, vary=0.05, bump=0.25, pattern="check", pattern_size=0.03, color3=(0.96, 0.93, 0.86))
    for x, turn in ((-0.5, 12), (0.52, -10)):
        sc = k.part("Zierkissen", "cushion", bevel=0.0)
        m = Matrix.Translation((x, 0.12, 0.62)) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Rotation(math.radians(-70), 4, "X")
        F.pillow(sc, (0, 0, 0), (0.34, 0.34, 0.12), roundness=2.4, puff=0.03, step=0.03, matrix=m)
    k.collider((0, 0, 0.22), (1.62, 0.82, 0.44))
    k.collider((0, -0.06, 0.25), (1.3, 0.6, 0.49))
    k.collider((0, 0.3, 0.6), (1.56, 0.22, 0.46))
    for side in (-1, 1):
        k.collider((side * 0.75, 0, 0.35), (0.2, 0.82, 0.7))
    k.surface((0, -0.08, 0.49), (1.2, 0.46))
    for side in (-1, 1):
        k.surface((side * 0.76, -0.02, 0.69), (0.08, 0.6))
    for x in (-0.34, 0.34):
        k.seat((x, -0.08, 0.49))
    k.interact = (Vector((0, -0.04, 0.58)), Vector((1.3, 0.6, 0.45)))


# --- Bauerntisch ---

def build_farm_table(k):
    pine(k)
    paint(k, CREAM)
    W, D, H = 1.6, 0.85, 0.76
    top = k.part("Platte", "wood", bevel=0.006)
    planks = 5
    for i in range(planks):
        y = -D / 2 + D / planks * (i + 0.5)
        top.box((0, y, H - 0.02), (W, D / planks - 0.004, 0.04), step=0.3, dent=0.0015)
    frame = k.part("Zarge", "paint", bevel=0.005)
    frame.box((0, -D / 2 + 0.08, H - 0.09), (W - 0.2, 0.025, 0.1), step=0.3, dent=0.0008)
    frame.box((0, D / 2 - 0.08, H - 0.09), (W - 0.2, 0.025, 0.1), step=0.3, dent=0.0008)
    for x in (-W / 2 + 0.1, W / 2 - 0.1):
        frame.box((x, 0, H - 0.09), (0.025, D - 0.16, 0.1), step=0.3, dent=0.0008)
    legs = k.part("Beine", "paint", bevel=0.0)
    for x in (-W / 2 + 0.1, W / 2 - 0.1):
        for y in (-D / 2 + 0.08, D / 2 - 0.08):
            F.turned_leg(legs, (x, y, 0.0), H - 0.04, 0.035, style="baluster", segs=14)
    knob = k.part("Schubladenknopf", "wood", bevel=0.0)
    F.knob(knob, (0, -D / 2 + 0.067, H - 0.09), r=0.014)
    k.collider((0, 0, H - 0.02), (W, D, 0.04))
    for x in (-W / 2 + 0.1, W / 2 - 0.1):
        for y in (-D / 2 + 0.08, D / 2 - 0.08):
            k.collider((x, y, (H - 0.04) / 2), (0.07, 0.07, H - 0.04))
    k.surface((0, 0, H), (W - 0.04, D - 0.04))


# --- Teetisch mit Spitzendecke ---

def build_tea_table(k):
    pine(k)
    k.mat("lace", (0.97, 0.95, 0.9), grain="fabric", rough=0.9, vary=0.03, bump=0.2)
    top = k.part("Platte", "wood", bevel=0.005)
    top.lathe([(0.0, 0.0), (0.3, 0.0), (0.3, 0.025), (0.0, 0.025)], (0, 0, 0.6), segs=40)
    legs = k.part("Beine", "wood", bevel=0.0)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        F.turned_leg(legs, d * 0.2, 0.6, 0.022, style="spindle", segs=12)
    cloth = k.part("Spitzendecke", "lace", bevel=0.0)
    # Decke: oben flach, an den Seiten in weichen Falten herab, gewellter Saum
    cloth.lathe([(0.0, 0.627), (0.29, 0.627), (0.34, 0.6), (0.36, 0.5), (0.375, 0.4), (0.378, 0.39), (0.37, 0.39), (0.36, 0.48),
                 (0.33, 0.59), (0.28, 0.618), (0.0, 0.618)], (0, 0, 0), segs=64, wave=0.06, waves=12)
    scallop = k.part("Spitzensaum", "lace", bevel=0.0)
    for i in range(36):
        a = 2 * math.pi * i / 36
        d = Vector((math.cos(a), math.sin(a), 0))
        scallop.blob(d * 0.38 + Vector((0, 0, 0.385)), 0.014, subdiv=1, lump=0.1, scale=(1, 1, 0.6))
    k.collider((0, 0, 0.31), (0.6, 0.6, 0.62))
    k.surface((0, 0, 0.628), (0.5, 0.5))


# --- Stehlampe mit Rüschenschirm ---

def build_ruffle_floor_lamp(k):
    paint(k, CREAM)
    floral(k, (0.96, 0.92, 0.84), slot="shade", size=0.05, emit=1.2, emit_color=(1.0, 0.82, 0.55))
    base = k.part("Fuß", "paint", bevel=0.0)
    base.lathe([(0.0, 0.0), (0.17, 0.0), (0.17, 0.02), (0.12, 0.04), (0.05, 0.06), (0.0, 0.065)], (0, 0, 0), segs=36)
    pole = k.part("Stange", "paint", bevel=0.0)
    F.turned_leg(pole, (0, 0, 0.06), 1.3, 0.03, style="spindle", segs=14)
    harp = k.part("Fassung", "paint", bevel=0.0)
    harp.tube([(0, 0, 1.36), (0, 0, 1.52)], 0.006, segs=6)
    sh = k.part("Schirm", "shade", bevel=0.0)
    F.shade(sh, (0, 0, 1.38), 0.23, 0.15, 0.25, kind="bell", segs=56, wall=0.004)
    ruff = k.part("Rüsche", "shade", bevel=0.0)
    ruff.lathe([(0.225, 0.0), (0.26, -0.05), (0.258, -0.055), (0.222, -0.006)], (0, 0, 1.385), segs=72, wave=0.05, waves=30)
    bulb = k.part("Glühbirne", "shade", bevel=0.0)
    bulb.blob((0, 0, 1.46), 0.03, subdiv=2, lump=0.02, scale=(1, 1, 1.2))
    k.light_kind = "electric"
    k.shadow = "important"
    k.light((0, 0, 1.47), energy=1.5, rng=6.0)
    k.collider((0, 0, 0.82), (0.36, 0.36, 1.64))


# --- Keramiklampe mit Blümchenschirm ---

def build_ceramic_lamp(k):
    k.mat("ceramic", POWDER, grain="smooth", rough=0.4, vary=0.04)
    floral(k, (0.97, 0.94, 0.86), slot="shade", size=0.04, emit=1.2, emit_color=(1.0, 0.82, 0.55))
    k.mat("motif", (0.95, 0.94, 0.9), grain="smooth", rough=0.4, vary=0.02)
    jar = k.part("Fuß", "ceramic", bevel=0.0)
    jar.lathe([(0.0, 0.0), (0.06, 0.0), (0.075, 0.03), (0.09, 0.09), (0.085, 0.15), (0.05, 0.19), (0.03, 0.2), (0.032, 0.22),
               (0.0, 0.225)], (0, 0, 0), segs=36)
    dots = k.part("Blümchen", "motif", bevel=0.0)
    rnd = random.Random(k.seed)
    for i in range(14):
        a = 2 * math.pi * i / 14 + rnd.uniform(-0.15, 0.15)
        z = rnd.uniform(0.06, 0.16)
        r = 0.09 - abs(z - 0.1) * 0.25
        d = Vector((math.cos(a), math.sin(a), 0))
        dots.star(d * r + Vector((0, 0, z)), d, 0.022, 5, rnd, thick=0.002, cup=0.0)
    stem = k.part("Stiel", "motif", bevel=0.0)
    stem.tube([(0, 0, 0.22), (0, 0, 0.3)], 0.007, segs=8)
    sh = k.part("Schirm", "shade", bevel=0.0)
    F.shade(sh, (0, 0, 0.27), 0.15, 0.1, 0.17, kind="scallop", segs=48, wall=0.004)
    bulb = k.part("Glühbirne", "shade", bevel=0.0)
    bulb.blob((0, 0, 0.32), 0.022, subdiv=2, lump=0.02)
    k.light_kind = "electric"
    k.shadow = "optional"
    k.light((0, 0, 0.33), energy=0.75, rng=3.2)
    k.collider((0, 0, 0.22), (0.3, 0.3, 0.44))


# --- Emaille-Hängelampe ---

def build_enamel_pendant(k):
    k.mat("enamel", CREAM, grain="smooth", rough=0.35, vary=0.04)
    k.mat("enamel_rim", (0.2, 0.28, 0.45), grain="smooth", rough=0.35, vary=0.03)
    k.mat("cord", (0.75, 0.6, 0.4), grain="fabric", rough=0.9, vary=0.05)
    k.mat("bulb", (1.0, 0.88, 0.62), grain="smooth", rough=0.3, vary=0.02, emit=4.0, emit_color=(1.0, 0.8, 0.52))
    top = k.part("Baldachin", "enamel", bevel=0.0)
    top.lathe([(0.0, 0.0), (0.055, 0.0), (0.055, -0.02), (0.0, -0.024)], (0, 0, 0), segs=24)
    cord = k.part("Kabel", "cord", bevel=0.0)
    pts = [Vector((0, 0, -0.02))] + [Vector((0.003 * math.sin(i), 0.003 * math.cos(i), -0.02 - i * 0.05)) for i in range(1, 11)]
    cord.tube(pts, 0.004, segs=6, smooth=1)
    shade = k.part("Schirm", "enamel", bevel=0.0)
    F.shade(shade, (0, 0, -0.78), 0.2, 0.035, 0.18, kind="dome", segs=48, wall=0.004)
    rim = k.part("Rand", "enamel_rim", bevel=0.0)
    F.ring(rim, (0, 0, -0.78), 0.2, 0.006, n=56)
    cap = k.part("Kappe", "enamel_rim", bevel=0.0)
    cap.lathe([(0.0, 0.0), (0.04, 0.0), (0.035, 0.03), (0.0, 0.04)], (0, 0, -0.63), segs=20)
    bulb = k.part("Glühbirne", "bulb", bevel=0.0)
    bulb.blob((0, 0, -0.7), 0.035, subdiv=2, lump=0.02, scale=(1, 1, 1.15))
    k.light_kind = "electric"
    k.shadow = "optional"
    k.light((0, 0, -0.74), energy=1.6, rng=7.0)
    k.collider((0, 0, -0.69), (0.42, 0.42, 0.2))
    k.interact = (Vector((0, 0, -0.6)), Vector((0.42, 0.42, 0.42)))


# --- Laterne mit Kerze ---

def build_lantern(k):
    k.mat("metal", (0.28, 0.3, 0.27), grain="smooth", rough=0.55, metal=0.35, vary=0.06)
    k.mat("glass", (0.9, 0.95, 0.95), glass=True, rough=0.1, vary=0.0)
    k.mat("wax", (0.95, 0.92, 0.84), grain="smooth", rough=0.55, vary=0.03)
    m = k.part("Gestell", "metal", bevel=0.0)
    m.box((0, 0, 0.01), (0.2, 0.2, 0.02), step=0.5, dent=0.0004)
    for x in (-0.095, 0.095):
        for y in (-0.095, 0.095):
            m.tube([(x, y, 0.02), (x, y, 0.28)], 0.006, segs=6)
    m.box((0, 0, 0.29), (0.21, 0.21, 0.02), step=0.5, dent=0.0004)
    m.lathe([(0.0, 0.0), (0.13, 0.0), (0.06, 0.06), (0.03, 0.08), (0.0, 0.085)], (0, 0, 0.3), segs=4, spin=45)
    F.ring(m, (0, 0, 0.42), 0.035, 0.006, matrix=Matrix.Rotation(math.radians(90), 4, "X"), n=20)
    glass = k.part("Scheiben", "glass", bevel=0.0)
    for x, y, sx, sy in ((0, -0.093, 0.18, 0.004), (0, 0.093, 0.18, 0.004), (-0.093, 0, 0.004, 0.18), (0.093, 0, 0.004, 0.18)):
        glass.box((x, y, 0.155), (sx, sy, 0.25), step=0.5, dent=0.0)
    F.candle(k, "wax", (0, 0, 0.02), 0.12, 0.028, drips=3, segs=16)
    k.light_kind = "flame"
    k.shadow = "none"
    k.light((0, 0, 0.17), energy=0.35, rng=2.2, shadow=False)
    k.collider((0, 0, 0.2), (0.22, 0.22, 0.4))


# --- Wandleuchte mit Stoffschirm ---

def build_fabric_wall_lamp(k):
    paint(k, CREAM)
    check(k, CHECK_RED, slot="shade", size=0.025, emit=1.1, emit_color=(1.0, 0.82, 0.55))
    plate = k.part("Wandbrett", "paint", bevel=0.004)
    F.pillow(plate, (0, -0.012, 0.0), (0.09, 0.024, 0.18), roundness=4.0, step=0.02)
    arm = k.part("Arm", "paint", bevel=0.0)
    arm.tube([(0, -0.02, -0.04), (0, -0.1, -0.02), (0, -0.16, 0.03), (0, -0.17, 0.06)], 0.009, segs=8, smooth=2, round_ends=True)
    sh = k.part("Schirm", "shade", bevel=0.0)
    F.shade(sh, (0, -0.17, 0.05), 0.09, 0.06, 0.11, kind="drum", segs=36, wall=0.004)
    bulb = k.part("Glühbirne", "shade", bevel=0.0)
    bulb.blob((0, -0.17, 0.09), 0.02, subdiv=2, lump=0.02)
    k.light_kind = "electric"
    k.shadow = "none"
    k.light((0, -0.17, 0.1), energy=0.75, rng=3.8, shadow=False)
    k.collider((0, -0.1, 0.02), (0.2, 0.2, 0.22))


# --- Geflochtener Flickenteppich ---

def build_braided_rug(k):
    k.mat("rug", (0.82, 0.55, 0.55), grain="fabric", rough=0.95, vary=0.05, bump=0.4)
    k.mat("rug2", (0.55, 0.66, 0.5), grain="fabric", rough=0.95, vary=0.05, bump=0.4)
    k.mat("rug3", (0.94, 0.9, 0.8), grain="fabric", rough=0.95, vary=0.05, bump=0.4)
    k.mat("rug4", (0.55, 0.66, 0.8), grain="fabric", rough=0.95, vary=0.05, bump=0.4)
    rings = 22
    for i in range(rings):
        slot = ("rug", "rug", "rug3", "rug2", "rug2", "rug3", "rug4", "rug3")[i % 8]
        b = k.part("Zopf %d" % i, slot, bevel=0.0, settle=False)
        r = 0.03 + i * 0.027
        pts = []
        n = 20 + i * 5
        for j in range(n + 1):
            a = 2 * math.pi * j / n
            # Zopf: leicht gewellt (abwechselnd dicker und dünner wirkt wie geflochten)
            pts.append(Vector((math.cos(a) * (r + 0.3), math.sin(a) * r, 0.011)))
        b.tube(pts, lambda t, nn=n: 0.0145 * (1.0 + 0.12 * math.sin(t * nn * math.pi)), segs=5)
    k.collider((0, 0, 0.012), (1.8, 1.2, 0.024))

# --- Patchwork-Quilt ---

def build_quilt(k):
    k.mat("fabric", CHECK_BLUE, grain="fabric", rough=0.95, vary=0.05, bump=0.3)
    k.mat("patch", (1, 1, 1), grain="fabric", rough=0.95, vary=0.02, bump=0.3, pattern="floral", pattern_size=0.025,
          color2=(0.95, 0.95, 0.92), color3=(0.95, 0.85, 0.4))
    b = k.part("Quilt", "fabric", bevel=0.0)
    for i in range(4):
        F.pillow(b, (0.004 * (i % 2), -0.003 * i, 0.013 + i * 0.024), (0.52, 0.36, 0.028), roundness=6.0, puff=0.004, step=0.03,
                 turn=(i - 1.5) * 1.0)
    patches = k.part("Flicken", "patch", bevel=0.0)
    cols = [CHECK_RED, ROSE, SAGE, BUTTER, POWDER, (0.9, 0.62, 0.45)]
    rnd = random.Random(k.seed)
    for ix in range(6):
        for iy in range(4):
            x = -0.215 + ix * 0.086
            y = -0.13 + iy * 0.086
            patches.box((x, y, 0.103), (0.082, 0.082, 0.004), step=0.5, dent=0.0004, tint=cols[(ix + iy * 2) % len(cols)])
    k.collider((0, 0, 0.05), (0.54, 0.38, 0.1))
    k.surface((0, 0, 0.105), (0.48, 0.32))


# --- Rüschenkissen ---

def build_ruffle_cushion(k):
    floral(k, ROSE, size=0.045)
    b = k.part("Kissen", "fabric", bevel=0.0)
    F.pillow(b, (0, 0, 0.07), (0.38, 0.38, 0.14), roundness=2.6, puff=0.025, step=0.025)
    ruff = k.part("Rüsche", "fabric", bevel=0.0)
    n = 56
    for i in range(n):
        a = 2 * math.pi * i / n
        c, sn = math.cos(a), math.sin(a)
        rr = (abs(c) ** 2.6 + abs(sn) ** 2.6) ** (-1 / 2.6)
        d = Vector((c * rr, sn * rr, 0))
        ruff.blob(Vector((d.x * 0.205, d.y * 0.205, 0.07)), 0.022, subdiv=1, lump=0.15, scale=(1.0, 1.0, 0.45))
    btn = k.part("Knopf", "fabric", bevel=0.0)
    F.button(btn, (0, 0, 0.162), r=0.014)
    k.collider((0, 0, 0.07), (0.42, 0.42, 0.14))


# --- Trockenblumenkranz ---

def build_wreath(k):
    k.mat("twig", (0.55, 0.42, 0.3), grain="wood", rough=0.85, vary=0.12)
    check(k, CHECK_RED, slot="bow", size=0.012)
    k.mat("dried_a", (0.85, 0.62, 0.62), grain="leaf", rough=0.8, vary=0.1)
    k.mat("dried_b", (0.96, 0.93, 0.85), grain="leaf", rough=0.8, vary=0.08)
    k.mat("lavender", (0.62, 0.52, 0.75), grain="leaf", rough=0.8, vary=0.1)
    k.mat("dried_leaf", (0.56, 0.62, 0.48), grain="leaf", rough=0.8, vary=0.1)
    rnd = random.Random(k.seed)
    tw = k.part("Zweige", "twig", bevel=0.0)
    R = 0.17
    for j in range(7):
        pts = []
        ph = rnd.uniform(0, 6.3)
        for i in range(41):
            a = 2 * math.pi * i / 40 + ph
            rr = R + 0.022 * math.sin(a * 3 + j) + rnd.uniform(-0.004, 0.004)
            pts.append(Vector((math.cos(a) * rr, -0.025 + 0.012 * math.sin(a * 2 + j), math.sin(a) * rr)))
        tw.tube(pts, 0.004, segs=5)
    leaves = k.part("Blätter", "dried_leaf", bevel=0.0)
    flowers_a = k.part("Blüten rosa", "dried_a", bevel=0.0)
    flowers_b = k.part("Blüten weiß", "dried_b", bevel=0.0)
    lav = k.part("Lavendel", "lavender", bevel=0.0)
    for i in range(30):
        a = 2 * math.pi * i / 30 + rnd.uniform(-0.08, 0.08)
        if math.sin(a) < -0.6:
            continue
        d = Vector((math.cos(a), 0, math.sin(a)))
        c = d * R + Vector((0, -0.04, 0))
        t = Vector((-math.sin(a), 0, math.cos(a)))
        leaves.leaf(c, (t + d * 0.3).normalized(), Vector((0, -1, 0)), 0.045, 0.02, shape="oval", thick=0.003, curl=0.1, segs=5)
        if i % 3 == 0:
            flowers_a.star(c + Vector((0, -0.012, 0)), Vector((0, -1, 0)), 0.026, 5, rnd, thick=0.004, cup=0.3)
        elif i % 3 == 1:
            for q in range(4):
                flowers_b.blob(c + Vector((rnd.uniform(-0.015, 0.015), -0.015, rnd.uniform(-0.015, 0.015))), 0.006, subdiv=1, lump=0.1)
        else:
            lav.tube([c, c + (t * 0.8 + d * 0.4).normalized() * 0.05], 0.006, segs=5, round_ends=True)
    bow = k.part("Schleife", "bow", bevel=0.0)
    c = Vector((0, -0.05, -R - 0.01))
    for sg in (-1, 1):
        bow.blob(c + Vector((sg * 0.035, 0, 0.012)), 0.03, subdiv=2, lump=0.1, scale=(1.3, 0.35, 0.8))
        bow.tube([c, c + Vector((sg * 0.025, -0.004, -0.08))], 0.009, segs=5, round_ends=True)
    bow.blob(c, 0.014, subdiv=1, lump=0.05)
    k.collider((0, -0.03, 0), (0.42, 0.06, 0.44))


# --- Stickrahmen-Wand ---

def build_embroidery_hoops(k):
    pine(k)
    k.mat("linen", CREAM, grain="fabric", rough=0.95, vary=0.04, bump=0.3)
    k.mat("thread_a", (0.85, 0.42, 0.48), grain="fabric", rough=0.9, vary=0.06)
    k.mat("thread_b", (0.95, 0.8, 0.35), grain="fabric", rough=0.9, vary=0.06)
    k.mat("thread_leaf", (0.45, 0.6, 0.4), grain="fabric", rough=0.9, vary=0.06)
    k.mat("brass", (0.8, 0.62, 0.32), grain="smooth", rough=0.4, metal=0.6, vary=0.05)
    rnd = random.Random(k.seed)
    hoops = [((-0.15, 0.05), 0.11), ((0.1, 0.1), 0.085), ((0.06, -0.12), 0.065)]
    for (x, z), R in hoops:
        rim = k.part("Ring", "wood", bevel=0.0)
        m = Matrix.Rotation(math.radians(90), 4, "X")
        F.ring(rim, (x, -0.012, z), R, 0.008, matrix=m, n=40)
        F.ring(rim, (x, -0.02, z), R + 0.004, 0.006, matrix=m, n=40)
        clasp = k.part("Schraube", "brass", bevel=0.0)
        clasp.tube([(x, -0.016, z + R + 0.004), (x, -0.016, z + R + 0.024)], 0.006, segs=8, round_ends=True)
        cloth = k.part("Stoff", "linen", bevel=0.0, settle=False)
        cloth.lathe([(0.0, 0.0), (R - 0.004, 0.0), (R - 0.004, 0.004), (0.0, 0.004)], (x, -0.008, z), segs=36, turn=(90, 0))
        stitches = k.part("Stickerei", "thread_leaf", bevel=0.0, settle=False)
        stitches.tube([(x, -0.0135, z - R * 0.7), (x + R * 0.1, -0.0135, z - R * 0.1), (x - R * 0.05, -0.0135, z + R * 0.3)], 0.0022,
                      segs=4, smooth=2, round_ends=True)
        for j in range(3):
            q = Vector((x + rnd.uniform(-0.4, 0.4) * R, -0.0135, z + rnd.uniform(-0.3, 0.5) * R))
            fl = k.part("Blüte", "thread_a" if j % 2 == 0 else "thread_b", bevel=0.0, settle=False)
            fl.star(q, Vector((0, -1, 0)), R * 0.32, 5, rnd, thick=0.002, cup=0.0)
            stitches.leaf(q + Vector((R * 0.15, 0, -R * 0.15)), Vector((1, 0, -0.6)).normalized(), Vector((0, -1, 0)), R * 0.25, R * 0.12,
                          shape="oval", thick=0.0018, curl=0.0, segs=5)
    k.collider((-0.03, -0.012, 0.0), (0.46, 0.03, 0.4))


# --- Trockenblumen in der Emaillekanne ---

def build_dried_flowers(k):
    k.mat("enamel", CREAM, grain="smooth", rough=0.35, vary=0.04)
    k.mat("enamel_rim", (0.22, 0.3, 0.5), grain="smooth", rough=0.35, vary=0.03)
    k.mat("lavender", (0.6, 0.5, 0.74), grain="leaf", rough=0.8, vary=0.1)
    k.mat("wheat", (0.86, 0.72, 0.45), grain="leaf", rough=0.8, vary=0.1)
    k.mat("gyps", (0.97, 0.96, 0.92), grain="leaf", rough=0.8, vary=0.05)
    k.mat("stem", (0.55, 0.58, 0.4), grain="leaf", rough=0.8, vary=0.08)
    jug = k.part("Kanne", "enamel", bevel=0.0)
    jug.lathe([(0.0, 0.0), (0.06, 0.0), (0.075, 0.04), (0.075, 0.12), (0.055, 0.17), (0.058, 0.19), (0.05, 0.19), (0.045, 0.17),
               (0.065, 0.12), (0.065, 0.04), (0.0, 0.01)], (0, 0, 0), segs=32)
    jug.tube([(0.07, 0, 0.16), (0.12, 0, 0.15), (0.12, 0, 0.07), (0.072, 0, 0.05)], 0.008, segs=7, smooth=2, round_ends=True)
    rim = k.part("Rand", "enamel_rim", bevel=0.0)
    F.ring(rim, (0, 0, 0.19), 0.055, 0.004, n=32)
    rnd = random.Random(k.seed)
    stems = k.part("Stiele", "stem", bevel=0.0)
    lav = k.part("Lavendel", "lavender", bevel=0.0)
    wheat = k.part("Ähren", "wheat", bevel=0.0)
    gyps = k.part("Schleierkraut", "gyps", bevel=0.0)
    for i in range(26):
        a = rnd.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a) * rnd.uniform(0.15, 0.55), math.sin(a) * rnd.uniform(0.15, 0.55), 1.0)).normalized()
        base = Vector((math.cos(a) * 0.02, math.sin(a) * 0.02, 0.12))
        top = base + d * rnd.uniform(0.2, 0.33)
        stems.tube([base, base.lerp(top, 0.5) + Vector((0, 0, 0.01)), top], 0.0022, segs=4, smooth=1)
        kind = i % 3
        if kind == 0:
            for j in range(7):
                lav.blob(top + d * (j * 0.009), 0.0055 - j * 0.0004, subdiv=1, lump=0.1, scale=(1, 1, 1.3))
        elif kind == 1:
            for j in range(6):
                for sg in (-1, 1):
                    wheat.blob(top + d * (j * 0.008) + d.cross(Vector((0, 0, 1))).normalized() * sg * 0.004, 0.004, subdiv=1, lump=0.05,
                               scale=(1, 1, 1.6))
        else:
            for j in range(9):
                gyps.blob(top + Vector((rnd.uniform(-0.025, 0.025), rnd.uniform(-0.025, 0.025), rnd.uniform(-0.01, 0.02))), 0.0045,
                          subdiv=1, lump=0.1)
    k.collider((0.02, 0, 0.1), (0.2, 0.16, 0.2))


# --- Körbe mit Karofutter ---

def build_baskets(k):
    wicker(k)
    check(k, CHECK_RED, slot="fabric", size=0.025)
    rnd = random.Random(k.seed)
    for (x, y, r, h) in ((-0.12, 0.02, 0.15, 0.2), (0.17, -0.04, 0.11, 0.15)):
        b = k.part("Korb", "wicker", bevel=0.0)
        b.lathe([(0.0, 0.0), (r * 0.85, 0.0), (r * 0.85, 0.02), (0.0, 0.02)], (x, y, 0.0), segs=28)
        weave(b, (x, y, 0.0), r * 0.85, r, h, rnd, staves=26, rows=6, wall=0.005)
        F.ring(b, (x, y, h), r, 0.012, n=36, segs=7)
        for sg in (-1, 1):
            b.tube([(x + sg * r, y, h), (x + sg * r * 1.08, y, h + 0.03), (x + sg * r * 0.95, y, h + 0.045)], 0.007, segs=5, smooth=1,
                   round_ends=True)
        liner = k.part("Futter", "fabric", bevel=0.0)
        liner.lathe([(r * 0.82, h * 0.55), (r * 0.96, h * 0.95), (r * 1.06, h * 1.02), (r * 1.1, h * 0.86), (r * 1.08, h * 0.82),
                     (r * 1.0, h * 0.98), (r * 0.92, h * 0.93), (r * 0.78, h * 0.55)], (x, y, 0.0), segs=36, wave=0.04, waves=9)
    k.collider((0.0, 0, 0.1), (0.56, 0.32, 0.2))


# --- Teekanne mit Tassen ---

def build_tea_set(k):
    k.mat("ceramic", (0.96, 0.95, 0.91), grain="smooth", rough=0.35, vary=0.03, pattern="floral", pattern_size=0.03,
          color2=(0.86, 0.45, 0.52), color3=(0.95, 0.82, 0.35))
    k.mat("gold", (0.85, 0.68, 0.36), grain="smooth", rough=0.35, metal=0.6, vary=0.04)
    k.mat("tea", (0.45, 0.25, 0.12), grain="smooth", rough=0.2, vary=0.02)
    pot = k.part("Kanne", "ceramic", bevel=0.0)
    c = Vector((-0.06, 0.02, 0.0))
    pot.lathe([(0.0, 0.0), (0.05, 0.0), (0.075, 0.03), (0.085, 0.07), (0.075, 0.11), (0.05, 0.125), (0.0, 0.126)], c, segs=36)
    pot.tube([c + Vector((0.07, 0, 0.04)), c + Vector((0.11, 0, 0.08)), c + Vector((0.135, 0, 0.12))], lambda t: 0.014 - 0.006 * t, segs=8,
             smooth=1, round_ends=True)
    pot.tube([c + Vector((-0.07, 0, 0.1)), c + Vector((-0.115, 0, 0.09)), c + Vector((-0.11, 0, 0.04)), c + Vector((-0.072, 0, 0.035))],
             0.007, segs=7, smooth=2, round_ends=True)
    lid = k.part("Deckel", "ceramic", bevel=0.0)
    lid.lathe([(0.0, 0.0), (0.05, 0.0), (0.045, 0.012), (0.012, 0.02), (0.016, 0.032), (0.0, 0.036)], c + Vector((0, 0, 0.122)), segs=28)
    gold = k.part("Goldrand", "gold", bevel=0.0)
    F.ring(gold, c + Vector((0, 0, 0.123)), 0.05, 0.002, n=28)
    for (x, y) in ((0.1, -0.06), (0.14, 0.07)):
        saucer = k.part("Untertasse", "ceramic", bevel=0.0)
        saucer.lathe([(0.0, 0.0), (0.04, 0.0), (0.06, 0.008), (0.065, 0.014), (0.058, 0.015), (0.035, 0.008), (0.0, 0.008)], (x, y, 0.0), segs=30)
        cup = k.part("Tasse", "ceramic", bevel=0.0)
        cup.lathe([(0.0, 0.0), (0.025, 0.0), (0.04, 0.03), (0.045, 0.055), (0.04, 0.056), (0.036, 0.032), (0.0, 0.01)], (x, y, 0.008), segs=28)
        cup.tube([(x + 0.04, y, 0.05), (x + 0.06, y, 0.042), (x + 0.058, y, 0.026), (x + 0.038, y, 0.022)], 0.004, segs=6, smooth=2,
                 round_ends=True)
        tea = k.part("Tee", "tea", bevel=0.0, settle=False)
        tea.lathe([(0.0, 0.0), (0.036, 0.0), (0.036, 0.003), (0.0, 0.003)], (x, y, 0.052), segs=24)
        F.ring(gold, (x, y, 0.063), 0.0445, 0.0018, n=28)
    k.collider((0.02, 0.0, 0.08), (0.34, 0.24, 0.16))


# --- Rankgitter mit Kletterrose ---

def build_rose_trellis(k):
    paint(k, CREAM)
    k.mat("soil", (0.25, 0.17, 0.11), grain="stone", rough=0.95, vary=0.12, bump=0.4)
    box = k.part("Pflanzkasten", "paint", bevel=0.006)
    W = 1.1
    box.box((0, 0, 0.17), (W, 0.34, 0.34), step=0.3, dent=0.001)
    box.box((0, 0, 0.345), (W + 0.04, 0.38, 0.03), step=0.3, dent=0.001)
    soil = k.part("Erde", "soil", bevel=0.0, settle=False)
    soil.box((0, 0, 0.35), (W - 0.06, 0.28, 0.02), step=0.1, dent=0.004)
    lat = k.part("Rankgitter", "paint", bevel=0.0)
    for x in (-0.5, 0.5):
        lat.box((x, 0.03, 1.05), (0.04, 0.04, 1.42), step=0.3, dent=0.0008)
    for i in range(9):
        z = 0.42 + i * 0.165
        lat.tube([(-0.5, 0.03, z), (0.5, 0.03, z)], 0.008, segs=6)
    for i in range(7):
        x = -0.42 + i * 0.14
        lat.tube([(x, 0.035, 0.36), (x, 0.035, 1.74)], 0.008, segs=6)
    lat.box((0, 0.03, 1.77), (1.08, 0.05, 0.04), step=0.3, dent=0.0008)
    p = k.plant(None)
    G.climber(p, 0.95, 1.3, kind="rose", flower="bloom")
    k.add_plant(p, (0, 0.13, 0.355))
    k.collider((0, 0, 0.18), (W + 0.04, 0.38, 0.36))
    k.collider((0, 0.03, 1.07), (1.06, 0.08, 1.42))
    k.surface((0, 0.0, 0.36), (W - 0.06, 0.08))


# --- Geranie im Terrakottatopf ---

def build_geranium(k):
    k.mat("pot", (0.74, 0.42, 0.28), grain="plaster", rough=0.9, vary=0.08, scale=3.0)
    soil, rim = F.pot(k, (0, 0, 0), 0.085, 0.13, style="classic", slot="pot")
    p = k.plant()
    G.geranium_bush(p, "bloom")
    k.add_plant(p, soil, scale=rim / 0.2)
    k.collider((0, 0, 0.065), (0.19, 0.19, 0.13))


# --- Hortensie im Zinkeimer ---

def build_hydrangea(k):
    k.mat("pot", (0.66, 0.68, 0.66), grain="smooth", rough=0.55, metal=0.45, vary=0.06)
    soil, rim = F.pot(k, (0, 0, 0), 0.18, 0.3, style="bucket", slot="pot")
    p = k.plant()
    G.hydrangea(p, "bloom", size=1.15, leaf_mat="leaf")
    k.add_plant(p, soil, scale=rim / 0.2)
    k.collider((0, 0, 0.15), (0.38, 0.38, 0.3))


# --- Fuchsie in der Hängeampel ---

def build_fuchsia_basket(k):
    k.mat("pot", (0.36, 0.38, 0.34), grain="smooth", rough=0.6, metal=0.3, vary=0.06)
    k.mat("chain", (0.36, 0.38, 0.34), grain="smooth", rough=0.6, metal=0.3, vary=0.04)
    hook = k.part("Haken", "chain", bevel=0.0)
    hook.lathe([(0.0, 0.0), (0.03, 0.0), (0.03, -0.012), (0.0, -0.014)], (0, 0, 0), segs=16)
    top = Vector((0, 0, -0.06))
    F.ring(hook, top, 0.014, 0.003, matrix=Matrix.Rotation(math.radians(90), 4, "X"), n=14)
    base = Vector((0, 0, -0.6))
    soil, rim = F.pot(k, base, 0.13, 0.12, style="bowl", slot="pot")
    chains = k.part("Ketten", "chain", bevel=0.0)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        chains.tube([top - Vector((0, 0, 0.01)), base + d * rim * 1.05 + Vector((0, 0, 0.11))], 0.0022, segs=4)
    p = k.plant("basket")
    G.fuchsia(p, "bloom", "bloom2", leaf_mat="leaf_dark", trails=7)
    k.add_plant(p, soil, scale=rim / 0.155)
    k.collider((0, 0, -0.55), (0.32, 0.32, 0.22))
    k.interact = (Vector((0, 0, -0.4)), Vector((0.32, 0.32, 0.8)))


# --- Vogelkäfig mit Blumen ---

def build_birdcage(k):
    paint(k, CREAM)
    k.mat("soil", (0.25, 0.17, 0.11), grain="stone", rough=0.95, vary=0.12, bump=0.4)
    cage = k.part("Käfig", "paint", bevel=0.0)
    cage.lathe([(0.0, 0.0), (0.16, 0.0), (0.17, 0.01), (0.16, 0.035), (0.0, 0.035)], (0, 0, 0), segs=36)
    n = 18
    for i in range(n):
        a = 2 * math.pi * i / n
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [d * 0.15 + Vector((0, 0, 0.035)), d * 0.15 + Vector((0, 0, 0.26))]
        for j in range(1, 7):
            t = j / 6
            pts.append(d * 0.15 * math.cos(t * math.pi / 2) + Vector((0, 0, 0.26 + 0.15 * math.sin(t * math.pi / 2))))
        cage.tube(pts, 0.0028, segs=4, smooth=1)
    for z in (0.12, 0.26):
        F.ring(cage, (0, 0, z), 0.152, 0.004, n=40)
    cage.blob((0, 0, 0.415), 0.018, subdiv=1, lump=0.03)
    F.ring(cage, (0, 0, 0.45), 0.028, 0.004, matrix=Matrix.Rotation(math.radians(90), 4, "X"), n=20)
    soil = k.part("Moos", "soil", bevel=0.0, settle=False)
    soil.lathe([(0.0, 0.0), (0.14, 0.0), (0.13, 0.02), (0.0, 0.025)], (0, 0, 0.035), segs=24, dent=0.004)
    p = k.plant("basket")
    G.trailing(p, ["bloom", "bloom2"], ranks=12, leaf_mat="leaf", shape="oval")
    k.add_plant(p, (0, 0, 0.055), scale=0.8)
    k.collider((0, 0, 0.21), (0.34, 0.34, 0.42))


# --- Teddybär ---

def build_teddy(k):
    k.mat("fur", (0.76, 0.55, 0.32), grain="fabric", rough=0.95, vary=0.08, bump=0.5, scale=3.0)
    k.mat("muzzle", (0.92, 0.82, 0.66), grain="fabric", rough=0.95, vary=0.05, bump=0.4)
    k.mat("eyes", (0.1, 0.08, 0.07), grain="smooth", rough=0.25, vary=0.02)
    check(k, CHECK_RED, slot="bow", size=0.012)
    b = k.part("Bär", "fur", bevel=0.0)
    b.blob((0, 0, 0.09), 0.075, subdiv=3, lump=0.04, scale=(1.0, 0.85, 1.15))
    head = Vector((0, -0.01, 0.2))
    b.blob(head, 0.065, subdiv=3, lump=0.03, scale=(1.05, 0.95, 0.95))
    for sg in (-1, 1):
        b.blob(head + Vector((sg * 0.05, 0.005, 0.048)), 0.022, subdiv=2, lump=0.03, scale=(1, 0.6, 1))
        b.tube([Vector((sg * 0.06, -0.01, 0.13)), Vector((sg * 0.085, -0.04, 0.07))], 0.024, segs=10, round_ends=True)
        b.tube([Vector((sg * 0.04, -0.03, 0.04)), Vector((sg * 0.05, -0.1, 0.03))], 0.03, segs=10, round_ends=True)
    m = k.part("Schnauze", "muzzle", bevel=0.0)
    m.blob(head + Vector((0, -0.055, -0.012)), 0.028, subdiv=2, lump=0.03, scale=(1.1, 0.7, 0.8))
    for sg in (-1, 1):
        m.blob(head + Vector((sg * 0.05, -0.01, 0.048)), 0.012, subdiv=1, lump=0.03, scale=(1, 0.5, 1))
        m.blob(Vector((sg * 0.05, -0.128, 0.03)), 0.018, subdiv=1, lump=0.03, scale=(1, 0.4, 1))
    e = k.part("Augen", "eyes", bevel=0.0)
    for sg in (-1, 1):
        e.blob(head + Vector((sg * 0.024, -0.058, 0.014)), 0.007, subdiv=1, lump=0.01)
    e.blob(head + Vector((0, -0.075, -0.004)), 0.009, subdiv=1, lump=0.02, scale=(1.3, 0.8, 0.8))
    bow = k.part("Schleife", "bow", bevel=0.0)
    c = head + Vector((0, -0.04, -0.06))
    for sg in (-1, 1):
        bow.blob(c + Vector((sg * 0.025, 0, 0)), 0.02, subdiv=2, lump=0.1, scale=(1.3, 0.45, 0.8))
    bow.blob(c, 0.01, subdiv=1, lump=0.05)
    k.collider((0, -0.03, 0.13), (0.2, 0.2, 0.26))


ITEMS = [
    dict(id="bookshelf_country", name="Bemaltes Bücherregal", category="shelf", sub="bookshelf", price=190,
         desc="Gestrichenes Regal mit Bogenkranz, Herzchen, Bogenschürze und Rückwand aus Brettern. Vier Fächer.",
         styles=STYLE, place="floor", build=build_painted_bookshelf, variants=paint_variants()),
    dict(id="ladder_shelf", name="Leiterregal", category="shelf", sub="wall_shelf", price=95,
         desc="Ein angelehntes Leiterregal mit vier Brettern für Töpfe, Bücher und Krimskrams.",
         styles=STYLE, place="floor", adopt=True, build=build_ladder_shelf, variants=paint_variants()),
    dict(id="rattan_chair", name="Korbsessel mit Karokissen", category="seating", sub="armchair", price=130,
         desc="Geflochtener Sessel mit hohem, rundem Rücken und dicken Karokissen.",
         styles=STYLE, place="floor", lean=True, adopt=True, build=build_wicker_chair, variants=check_variants()),
    dict(id="chair_country", name="Sprossenstuhl", category="seating", sub="chair", price=70,
         desc="Gestrichener Stuhl mit drei geschwungenen Sprossen und Karokissen mit Schleifen.",
         styles=STYLE, place="floor", lean=True, build=build_ladder_chair,
         variants=[(vid, name, {"paint": col, "fabric": chk}) for (vid, name, col), (_, _, chk) in zip(PAINTS, CHECKS + [CHECKS[0]])]),
    dict(id="sofa_country", name="Blümchensofa", category="seating", sub="sofa", price=330,
         desc="Ein gemütliches Sofa mit Blümchenstoff, Volant und zwei karierten Kissen.",
         styles=STYLE, place="floor", lean=True, build=build_floral_sofa,
         variants=[("cream", "Creme", {"fabric": CREAM}), ("rose", "Rosé", {"fabric": ROSE}), ("blue", "Hellblau", {"fabric": POWDER}),
                   ("sage", "Salbei", {"fabric": SAGE})]),
    dict(id="table_oak", name="Bauerntisch", category="table", sub="dining_table", price=160,
         desc="Platte aus breiten Holzdielen auf gedrechselten, gestrichenen Beinen.",
         styles=STYLE, place="floor", adopt=True, build=build_farm_table, variants=paint_variants()),
    dict(id="tea_table", name="Teetisch mit Spitzendecke", category="table", sub="side_table", price=65,
         desc="Ein runder Tisch, über den eine Spitzendecke mit gewelltem Saum fällt.",
         styles=STYLE, place="floor", build=build_tea_table,
         variants=[("white", "Weiß", {"lace": (0.97, 0.95, 0.9)}), ("cream", "Creme", {"lace": CREAM}), ("rose", "Rosé", {"lace": ROSE}),
                   ("sage", "Salbei", {"lace": SAGE})]),
    dict(id="floor_lamp_country", name="Stehlampe mit Rüschenschirm", category="lighting", sub="floor_lamp", price=90,
         desc="Gedrechselter Fuß und ein geblümter Schirm mit Rüsche.",
         styles=STYLE, place="floor", build=build_ruffle_floor_lamp,
         variants=[("cream", "Creme", {"shade": (0.96, 0.92, 0.84)}), ("rose", "Rosé", {"shade": ROSE}), ("blue", "Hellblau", {"shade": POWDER}),
                   ("sage", "Salbei", {"shade": SAGE})]),
    dict(id="table_lamp_country", name="Keramiklampe mit Blümchenschirm", category="lighting", sub="table_lamp", price=58,
         desc="Ein bauchiger Keramikfuß mit gemalten Blüten und ein Schirm mit gewelltem Rand.",
         styles=STYLE, place=["surface", "floor"], build=build_ceramic_lamp,
         variants=[("blue", "Hellblau", {"ceramic": POWDER}), ("sage", "Salbei", {"ceramic": SAGE}), ("rose", "Rosé", {"ceramic": ROSE}),
                   ("butter", "Butter", {"ceramic": BUTTER})]),
    dict(id="pendant_rattan", name="Emaille-Hängelampe", category="lighting", sub="ceiling_lamp", price=95,
         desc="Ein Emailleschirm mit dunklem Rand an einem Textilkabel.",
         styles=STYLE, place="ceiling", adopt=True, build=build_enamel_pendant,
         variants=[("cream", "Creme", {"enamel": CREAM}), ("sage", "Salbei", {"enamel": SAGE}), ("red", "Rot", {"enamel": (0.72, 0.22, 0.2)}),
                   ("blue", "Hellblau", {"enamel": POWDER})]),
    dict(id="lantern_garden", name="Laterne mit Kerze", category="lighting", sub="candle", price=45,
         desc="Eine kleine Laterne mit Glasscheiben, Henkel und tropfender Kerze.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_lantern,
         variants=[("green", "Altgrün", {"metal": (0.28, 0.3, 0.27)}), ("cream", "Creme", {"metal": CREAM}), ("rose", "Altrosa", {"metal": ROSE}),
                   ("blue", "Hellblau", {"metal": POWDER})]),
    dict(id="wall_lamp_country", name="Wandleuchte mit Karoschirm", category="lighting", sub="wall_lamp", price=50,
         desc="Ein gestrichenes Wandbrett mit geschwungenem Arm und kleinem Karoschirm.",
         styles=STYLE, place="wall", build=build_fabric_wall_lamp, variants=check_variants("shade")),
    dict(id="rug_braided", name="Geflochtener Flickenteppich", category="deco", sub="rug", price=85,
         desc="Ein ovaler Teppich aus geflochtenen Stoffzöpfen in Rosé, Salbei, Creme und Hellblau.",
         styles=STYLE, place="floor", build=build_braided_rug,
         variants=[("rose", "Rosé", {"rug": ROSE}), ("red", "Rot", {"rug": CHECK_RED}), ("blue", "Blau", {"rug": CHECK_BLUE}),
                   ("butter", "Butter", {"rug": BUTTER})]),
    dict(id="blanket", name="Patchwork-Quilt", category="deco", sub="textile", price=38,
         desc="Ein gefalteter Quilt mit bunten Blümchenflicken.",
         styles=STYLE, place=["surface", "floor"], lie=True, adopt=True, build=build_quilt, variants=check_variants()),
    dict(id="cushion", name="Rüschenkissen", category="deco", sub="textile", price=20,
         desc="Ein weiches Blümchenkissen mit Rüschenrand und Stoffknopf.",
         styles=STYLE, place=["surface", "floor"], lie=True, adopt=True, build=build_ruffle_cushion,
         variants=[("rose", "Rosé", {"fabric": ROSE}), ("cream", "Creme", {"fabric": CREAM}), ("blue", "Hellblau", {"fabric": POWDER}),
                   ("sage", "Salbei", {"fabric": SAGE}), ("butter", "Butter", {"fabric": BUTTER})]),
    dict(id="wreath", name="Trockenblumenkranz", category="deco", sub="picture", price=40,
         desc="Ein Kranz aus Zweigen mit Trockenblumen, Lavendel und einer Karoschleife – für Tür und Wand.",
         styles=STYLE, place=["wall", "door"], adopt=True, build=build_wreath, variants=check_variants("bow")),
    dict(id="embroidery_hoops", name="Stickrahmen-Wand", category="deco", sub="picture", price=34,
         desc="Drei Stickrahmen mit gestickten Blüten und Ranken.",
         styles=STYLE, place="wall", build=build_embroidery_hoops,
         variants=[("cream", "Leinen", {"linen": CREAM}), ("sage", "Salbei", {"linen": SAGE}), ("rose", "Rosé", {"linen": ROSE}),
                   ("blue", "Hellblau", {"linen": POWDER})]),
    dict(id="vase_lavender", name="Trockenblumen in der Emaillekanne", category="deco", sub="vase", price=24,
         desc="Lavendel, Ähren und Schleierkraut in einer kleinen Emaillekanne mit blauem Rand.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_dried_flowers,
         variants=[("cream", "Creme", {"enamel": CREAM}), ("blue", "Hellblau", {"enamel": POWDER}), ("red", "Rot", {"enamel": (0.72, 0.22, 0.2)}),
                   ("sage", "Salbei", {"enamel": SAGE})]),
    dict(id="basket_country", name="Körbe mit Karofutter", category="deco", sub="storage", price=34,
         desc="Zwei geflochtene Körbe mit Henkeln und Karostoff über dem Rand.",
         styles=STYLE, place=["surface", "floor"], build=build_baskets, variants=check_variants()),
    dict(id="tea_set", name="Teekanne mit Tassen", category="deco", sub="tableware", price=30,
         desc="Eine geblümte Teekanne mit Goldrand und zwei Tassen Tee auf Untertassen.",
         styles=STYLE, place="surface", build=build_tea_set,
         variants=[("white", "Weiß", {"ceramic": (0.96, 0.95, 0.91)}), ("blue", "Hellblau", {"ceramic": POWDER}),
                   ("sage", "Salbei", {"ceramic": SAGE}), ("rose", "Rosé", {"ceramic": ROSE})]),
    dict(id="planter_divider", name="Rankgitter mit Kletterrose", category="divider", sub="", price=190,
         desc="Ein Pflanzkasten mit Rankgitter, an dem eine Rose hochklettert.",
         styles=STYLE, place="floor", lean=True, adopt=True, build=build_rose_trellis,
         variants=[("pink", "Rosa", {"bloom": (0.93, 0.55, 0.65)}), ("red", "Rot", {"bloom": (0.78, 0.15, 0.18)}),
                   ("white", "Weiß", {"bloom": (0.97, 0.95, 0.9)}), ("apricot", "Apricot", {"bloom": (0.98, 0.72, 0.52)})]),
    dict(id="plant_small", name="Geranie im Terrakottatopf", category="deco", sub="plant", price=16,
         desc="Eine kleine, üppig blühende Geranie für Fensterbank und Regal.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_geranium,
         variants=[("red", "Rot", {"bloom": (0.86, 0.2, 0.17)}), ("pink", "Rosa", {"bloom": (0.93, 0.52, 0.62)}),
                   ("white", "Weiß", {"bloom": (0.96, 0.95, 0.9)}), ("coral", "Koralle", {"bloom": (0.95, 0.45, 0.38)})]),
    dict(id="plant_hydrangea", name="Hortensie im Zinkeimer", category="deco", sub="plant", price=55,
         desc="Eine große Hortensie mit runden Blütenköpfen in einem Zinkeimer.",
         styles=STYLE, place="floor", lean=True, build=build_hydrangea,
         variants=[("blue", "Blau", {"bloom": (0.5, 0.6, 0.9)}), ("pink", "Rosa", {"bloom": (0.93, 0.6, 0.72)}),
                   ("white", "Weiß", {"bloom": (0.96, 0.95, 0.9)}), ("lilac", "Flieder", {"bloom": (0.72, 0.6, 0.85)})]),
    dict(id="plant_fuchsia_hanging", name="Fuchsie in der Hängeampel", category="deco", sub="plant", price=38,
         desc="Eine Ampel an drei Ketten, aus der Fuchsien mit vielen Glöckchen hängen.",
         styles=STYLE, place="ceiling", build=build_fuchsia_basket,
         variants=[("magenta", "Magenta", {"bloom": (0.78, 0.24, 0.5), "bloom2": (0.48, 0.27, 0.6)}),
                   ("red", "Rot", {"bloom": (0.8, 0.15, 0.2), "bloom2": (0.48, 0.27, 0.6)}),
                   ("white", "Weiß-Rosa", {"bloom": (0.97, 0.94, 0.92), "bloom2": (0.93, 0.52, 0.62)})]),
    dict(id="birdcage", name="Vogelkäfig mit Blumen", category="deco", sub="figure", price=48,
         desc="Ein alter Vogelkäfig – statt eines Vogels wohnen Blumen darin, die durch die Stäbe ranken.",
         styles=STYLE, place=["surface", "floor"], build=build_birdcage, variants=paint_variants()),
    dict(id="teddy", name="Teddybär", category="deco", sub="figure", price=28,
         desc="Ein kuscheliger Teddy mit Karoschleife.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_teddy,
         variants=[("honey", "Honig", {"fur": (0.76, 0.55, 0.32)}), ("chocolate", "Schokolade", {"fur": (0.42, 0.28, 0.18)}),
                   ("cream", "Creme", {"fur": (0.92, 0.85, 0.72)}), ("rose", "Rosé", {"fur": (0.88, 0.68, 0.66)})]),
]
