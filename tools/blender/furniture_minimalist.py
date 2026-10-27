"""Minimalistisch: ruhig und aufgeräumt – helles Holz, Weiß, Grau, gedeckte Akzente (Salbei,
Taubenblau, Sand, Terrakotta), klare, aber weiche Formen, wenige schöne Stücke (Etappe 6).

Jedes Objekt: Beschreibung + Bau-Funktion mit den Bausteinen aus storybook_furniture.py
(Blender-Koordinaten, Vorderseite -y).
"""

import math
import random

from mathutils import Matrix, Vector

import storybook_furniture as F
import storybook_greenery as G

STYLE = ["minimalist"]
OAK = (0.78, 0.62, 0.42)
BIRCH = (0.88, 0.8, 0.66)
WALNUT_L = (0.5, 0.35, 0.24)
WHITE = (0.93, 0.92, 0.88)
GREY = (0.66, 0.66, 0.63)
CHARCOAL = (0.3, 0.3, 0.3)
CREAM = (0.92, 0.89, 0.82)
SAGE = (0.62, 0.68, 0.58)
DUSTY_BLUE = (0.56, 0.64, 0.72)
SAND = (0.84, 0.76, 0.62)
CLAY = (0.76, 0.52, 0.42)
BLACK_METAL = (0.17, 0.17, 0.17)
WOODS = [("oak", "Eiche hell", OAK), ("birch", "Birke", BIRCH), ("walnut", "Nussbaum", WALNUT_L), ("white", "Weiß lackiert", WHITE)]
FABRICS = [("cream", "Creme", CREAM), ("sage", "Salbei", SAGE), ("blue", "Taubenblau", DUSTY_BLUE), ("sand", "Sand", SAND),
           ("grey", "Steingrau", GREY)]


def wood(k, color=OAK, slot="wood"):
    return k.mat(slot, color, grain="wood", rough=0.6, vary=0.06, bump=0.1)


def fabric(k, color=CREAM, slot="fabric"):
    # Bouclé: weich und körnig
    return k.mat(slot, color, grain="fabric", rough=0.95, vary=0.07, bump=0.45, scale=3.0)


def metal(k, color=BLACK_METAL, slot="metal"):
    return k.mat(slot, color, grain="smooth", rough=0.45, metal=0.4, vary=0.04)


def wood_variants(slot="wood"):
    return [(vid, name, {slot: col}) for vid, name, col in WOODS]


def fabric_variants(slot="fabric"):
    return [(vid, name, {slot: col}) for vid, name, col in FABRICS]


# --- Würfelregal ---

def build_cube_shelf(k):
    wood(k, BIRCH)
    W, D, H = 0.74, 0.36, 1.1
    t = 0.028
    c = k.part("Würfel", "wood", bevel=0.008)
    for x in (-W / 2 + t / 2, 0.0, W / 2 - t / 2):
        c.box((x, 0, H / 2 + 0.04), (t, D, H), step=0.3, dent=0.0008)
    for z in (0.04 + t / 2, 0.04 + H / 3, 0.04 + 2 * H / 3, 0.04 + H - t / 2):
        c.box((0, 0, z), (W, D, t), step=0.3, dent=0.0008)
    c.box((0, 0.17, H / 2 + 0.04), (W - 0.02, 0.012, H - 0.02), step=0.3, dent=0.0006)
    feet = k.part("Füße", "wood", bevel=0.004)
    for x in (-0.3, 0.3):
        for y in (-0.12, 0.12):
            feet.lathe([(0.0, 0.0), (0.022, 0.0), (0.024, 0.02), (0.02, 0.042), (0.0, 0.042)], (x, y, 0.0), segs=14)
    cell_w = W / 2 - t * 1.5
    for row in range(3):
        top = 0.04 + t + row * H / 3 + (0.0 if row == 0 else -t / 2)
        h = H / 3 - t * (1.5 if row == 0 else 1.0)
        for col in (-1, 1):
            k.row((col * (W / 4 - t / 4), -0.005, top), cell_w - 0.01, h, D - 0.03)
    for x in (-W / 2 + t / 2, 0.0, W / 2 - t / 2):
        k.collider((x, 0, H / 2 + 0.04), (t, D, H))
    for z in (0.04 + t / 2, 0.04 + H / 3, 0.04 + 2 * H / 3, 0.04 + H - t / 2):
        k.collider((0, 0, z), (W, D, t))
    k.collider((0, 0.17, H / 2 + 0.04), (W, 0.014, H))
    k.collider((0, 0, 0.02), (W - 0.04, D - 0.04, 0.04))
    k.surface((0, 0, 0.04 + H), (W - 0.02, D - 0.02))


# --- Schlankes Regal ---

def build_slim_shelf(k):
    wood(k)
    metal(k)
    W, D, H = 0.9, 0.34, 1.9
    posts = k.part("Stäbe", "metal", bevel=0.0)
    for x in (-W / 2 + 0.02, W / 2 - 0.02):
        for y in (-D / 2 + 0.02, D / 2 - 0.02):
            posts.tube([(x, y, 0.0), (x, y, H)], 0.011, segs=10, round_ends=True)
    tops = [0.12, 0.5, 0.88, 1.26, 1.62]
    boards = k.part("Böden", "wood", bevel=0.007)
    for z in tops + [H - 0.02]:
        F.pillow(boards, (0, 0, z - 0.012), (W, D, 0.026), roundness=8.0, step=0.06)
    stops = k.part("Rückenleiste", "metal", bevel=0.0)
    for z in tops:
        stops.tube([(-W / 2 + 0.02, D / 2 - 0.02, z + 0.08), (W / 2 - 0.02, D / 2 - 0.02, z + 0.08)], 0.005, segs=6)
    clear = tops[1:] + [H - 0.02]
    for i in range(len(tops) - 1, -1, -1):
        k.row((0, -0.01, tops[i]), W - 0.08, clear[i] - tops[i] - 0.026, D - 0.04)
    for z in tops + [H - 0.02]:
        k.collider((0, 0, z - 0.012), (W, D, 0.026))
    for x in (-W / 2 + 0.02, W / 2 - 0.02):
        k.collider((x, 0, H / 2), (0.03, D, H))
    k.surface((0, 0, H - 0.0), (W - 0.04, D - 0.04))


# --- Schalenstuhl ---

def build_shell_chair(k):
    wood(k)
    k.mat("shell", SAGE, grain="smooth", rough=0.55, vary=0.04)
    legs = k.part("Beine", "wood", bevel=0.0)
    for x in (-0.19, 0.19):
        for y in (-0.17, 0.17):
            F.tapered_leg(legs, (x * 0.8, y * 0.75, 0.42), (x, y, 0.0), 0.018, 0.012)
    legs.tube([(-0.17, -0.0, 0.18), (0.17, 0.0, 0.18)], 0.009, segs=8, round_ends=True)
    seat = k.part("Schale", "shell", bevel=0.0)
    F.pillow(seat, (0, -0.02, 0.45), (0.46, 0.44, 0.05), roundness=2.6, puff=0.0, sag=0.02, step=0.03)
    # Rückenschale: ein Stück Röhre mit senkrechter Achse, sitzt hinten auf dem Sitz auf und
    # umfasst ihn seitlich (leicht nach hinten geneigt)
    back = k.part("Rücken", "shell", bevel=0.0)
    m = Matrix.Translation((0, 0.0, 0.615)) @ Matrix.Rotation(math.radians(-8), 4, "X") @ Matrix.Rotation(math.radians(-90), 4, "Y")
    F.arc_shell(back, m, 0.32, 0.225, 0.02, 98, 262, seg_a=24, seg_l=8)
    k.collider((0, -0.02, 0.235), (0.46, 0.44, 0.47))
    k.collider((0, 0.14, 0.62), (0.48, 0.12, 0.32))
    k.surface((0, -0.04, 0.475), (0.36, 0.32))
    k.seat((0, -0.04, 0.475))
    k.interact = (Vector((0, -0.02, 0.55)), Vector((0.46, 0.44, 0.4)))


# --- Loungesessel aus Bouclé ---

def build_lounge_chair(k):
    fabric(k)
    wood(k)
    legs = k.part("Füße", "wood", bevel=0.004)
    for x in (-0.28, 0.28):
        for y in (-0.26, 0.26):
            legs.lathe([(0.0, 0.0), (0.026, 0.0), (0.03, 0.05), (0.03, 0.09), (0.0, 0.09)], (x, y, 0.0), segs=14)
    base = k.part("Sockel", "fabric", bevel=0.0)
    F.pillow(base, (0, 0, 0.215), (0.78, 0.74, 0.26), roundness=3.0, puff=0.006, step=0.04)
    shell = k.part("Lehne", "fabric", bevel=0.0)
    path = []
    for a in range(-15, 196, 10):
        r = math.radians(a)
        path.append(Vector((math.cos(r) * 0.27, 0.04 + math.sin(r) * 0.25, 0.4 + 0.2 * max(0.0, math.sin(r)) ** 1.5)))
    shell.tube(path, lambda t: 0.11 + 0.06 * math.sin(math.pi * t), segs=20, smooth=2, round_ends=True)
    seat = k.part("Sitzkissen", "fabric", bevel=0.0)
    F.pillow(seat, (0, -0.06, 0.37), (0.5, 0.5, 0.13), roundness=2.8, puff=0.02, step=0.03)
    k.collider((0, 0, 0.21), (0.78, 0.74, 0.42))
    k.collider((0, -0.06, 0.25), (0.5, 0.5, 0.435))
    k.collider((0, 0.2, 0.55), (0.78, 0.3, 0.3))
    k.surface((0, -0.08, 0.435), (0.4, 0.38))
    k.seat((0, -0.07, 0.435))
    k.interact = (Vector((0, -0.04, 0.55)), Vector((0.66, 0.6, 0.45)))


# --- Weiches Zweisitzer-Sofa ---

def build_soft_sofa(k):
    fabric(k)
    wood(k)
    legs = k.part("Beine", "wood", bevel=0.0)
    for x in (-0.68, 0.68):
        for y in (-0.3, 0.3):
            F.tapered_leg(legs, (x, y, 0.13), (x * 1.03, y * 1.05, 0.0), 0.02, 0.014)
    base = k.part("Sockel", "fabric", bevel=0.0)
    F.pillow(base, (0, 0, 0.22), (1.6, 0.82, 0.2), roundness=3.4, puff=0.004, step=0.045)
    back = k.part("Rückenkissen", "fabric", bevel=0.0)
    for x in (-0.36, 0.36):
        F.pillow(back, (x, 0.28, 0.52), (0.7, 0.24, 0.4), roundness=2.8, puff=0.02, step=0.035)
    for side in (-1, 1):
        arm = k.part("Armlehne", "fabric", bevel=0.0)
        F.pillow(arm, (side * 0.74, 0.0, 0.42), (0.18, 0.82, 0.38), roundness=2.6, puff=0.008, step=0.035)
    for x in (-0.33, 0.33):
        cush = k.part("Sitzkissen", "fabric", bevel=0.0)
        F.pillow(cush, (x, -0.06, 0.38), (0.64, 0.62, 0.14), roundness=2.8, puff=0.02, step=0.035)
    k.collider((0, 0, 0.215), (1.62, 0.84, 0.43))
    k.collider((0, -0.06, 0.25), (1.3, 0.62, 0.45))
    k.collider((0, 0.28, 0.52), (1.42, 0.24, 0.4))
    for side in (-1, 1):
        k.collider((side * 0.74, 0, 0.3), (0.18, 0.84, 0.6))
    k.surface((0, -0.08, 0.45), (1.2, 0.48))
    for side in (-1, 1):
        k.surface((side * 0.74, -0.02, 0.61), (0.1, 0.6))
    for x in (-0.33, 0.33):
        k.seat((x, -0.08, 0.45))
    k.interact = (Vector((0, -0.04, 0.55)), Vector((1.3, 0.6, 0.45)))


# --- Runder Esstisch aus Eiche ---

def build_round_table(k):
    wood(k)
    top = k.part("Platte", "wood", bevel=0.008)
    top.lathe([(0.0, 0.0), (0.5, 0.0), (0.51, 0.014), (0.5, 0.03), (0.0, 0.03)], (0, 0, 0.72), segs=56, dent=0.0008)
    legs = k.part("Beine", "wood", bevel=0.0)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        F.tapered_leg(legs, d * 0.2 + Vector((0, 0, 0.72)), d * 0.34 + Vector((0, 0, 0.0)), 0.026, 0.017)
    legs.lathe([(0.0, 0.0), (0.26, 0.0), (0.26, 0.04), (0.0, 0.04)], (0, 0, 0.68), segs=40)
    k.collider((0, 0, 0.735), (1.0, 1.0, 0.03))
    k.collider((0, 0, 0.36), (0.6, 0.6, 0.72))
    k.surface((0, 0, 0.75), (0.86, 0.86))


# --- Schlanker Schreibtisch ---

def build_slim_desk(k):
    wood(k)
    k.mat("paint", WHITE, grain="paint", rough=0.6, vary=0.04)
    W, D, H = 1.2, 0.58, 0.75
    top = k.part("Platte", "wood", bevel=0.008)
    F.pillow(top, (0, 0, H - 0.014), (W, D, 0.028), roundness=8.0, step=0.06)
    box = k.part("Schublade", "paint", bevel=0.006)
    box.box((0.25, 0.0, H - 0.075), (0.5, D - 0.06, 0.09), step=0.3, dent=0.0006)
    box.box((0.25, -D / 2 + 0.035, H - 0.075), (0.48, 0.012, 0.08), step=0.3, dent=0.0006)
    grip = k.part("Griffmulde", "wood", bevel=0.0)
    grip.tube([(0.17, -D / 2 + 0.026, H - 0.05), (0.33, -D / 2 + 0.026, H - 0.05)], 0.006, segs=8, round_ends=True)
    legs = k.part("Beine", "wood", bevel=0.0)
    for x in (-W / 2 + 0.06, W / 2 - 0.06):
        for y in (-D / 2 + 0.06, D / 2 - 0.06):
            F.tapered_leg(legs, (x, y, H - 0.03), (x * 1.02, y * 1.06, 0.0), 0.022, 0.015)
    k.collider((0, 0, H - 0.014), (W, D, 0.028))
    k.collider((0.25, 0, H - 0.075), (0.5, D - 0.06, 0.09))
    for x in (-W / 2 + 0.06, W / 2 - 0.06):
        k.collider((x, 0, H / 2), (0.04, D - 0.08, H))
    k.surface((0, 0, H), (W - 0.04, D - 0.04))


# --- Beistelltisch aus Metall ---

def build_tray_table(k):
    metal(k)
    tray = k.part("Tablett", "metal", bevel=0.0)
    tray.lathe([(0.0, 0.0), (0.21, 0.0), (0.225, 0.006), (0.228, 0.04), (0.222, 0.042), (0.214, 0.012), (0.0, 0.012)],
               (0, 0, 0.5), segs=40)
    legs = k.part("Beine", "metal", bevel=0.0)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        legs.tube([d * 0.15 + Vector((0, 0, 0.5)), d * 0.2 + Vector((0, 0, 0.0))], 0.009, segs=8, round_ends=True)
    F.ring(legs, (0, 0, 0.16), 0.185, 0.006, n=40)
    k.collider((0, 0, 0.52), (0.45, 0.45, 0.04))
    k.collider((0, 0, 0.25), (0.4, 0.4, 0.5))
    k.surface((0, 0, 0.512), (0.38, 0.38))


# --- Sideboard ---

def build_sideboard(k):
    wood(k)
    metal(k)
    W, D, H = 1.5, 0.42, 0.62
    body = k.part("Korpus", "wood", bevel=0.01)
    F.pillow(body, (0, 0, 0.17 + (H - 0.17) / 2), (W, D, H - 0.17), roundness=7.0, step=0.06)
    doors = k.part("Lamellentüren", "wood", bevel=0.0)
    x = -W / 2 + 0.07
    while x < W / 2 - 0.05:
        doors.tube([(x, -D / 2 + 0.002, 0.21), (x, -D / 2 + 0.002, H - 0.04)], 0.009, segs=8, round_ends=True)
        x += 0.026
    for xc in (-0.36, 0.0, 0.36):
        doors.box((xc + 0.17, -D / 2 - 0.004, (0.21 + H - 0.04) / 2), (0.006, 0.006, H - 0.27), step=0.5, dent=0.0)
    handles = k.part("Griffe", "metal", bevel=0.0)
    for xc in (-0.54, -0.18, 0.18, 0.54):
        handles.lathe([(0.0, 0.0), (0.012, 0.0), (0.012, 0.016), (0.0, 0.016)], (xc + 0.14, -D / 2 - 0.004, 0.42), segs=12, turn=(90, 0))
    legs = k.part("Beine", "wood", bevel=0.0)
    for x in (-W / 2 + 0.1, W / 2 - 0.1):
        for y in (-D / 2 + 0.07, D / 2 - 0.07):
            F.tapered_leg(legs, (x, y, 0.18), (x * 1.02, y * 1.08, 0.0), 0.022, 0.014)
    k.collider((0, 0, (H + 0.17) / 2), (W, D, H - 0.17))
    k.collider((0, 0, 0.09), (W - 0.1, D - 0.1, 0.18))
    k.surface((0, 0, H), (W - 0.06, D - 0.06))


# --- Lamellen-Raumteiler ---

def build_slat_divider(k):
    wood(k)
    base = k.part("Fuß", "wood", bevel=0.008)
    F.pillow(base, (0, 0, 0.025), (1.3, 0.3, 0.05), roundness=6.0, step=0.06)
    slats = k.part("Lamellen", "wood", bevel=0.0)
    x = -0.6
    i = 0
    while x <= 0.601:
        h = 1.7 + 0.04 * math.sin(i * 0.9)
        slats.tube([(x, 0, 0.04), (x, 0, h)], 0.017, segs=10, round_ends=True)
        x += 0.06
        i += 1
    for z in (0.5, 1.2):
        slats.tube([(-0.62, 0.022, z), (0.62, 0.022, z)], 0.008, segs=6, round_ends=True)
    k.collider((0, 0, 0.88), (1.3, 0.3, 1.76))


# --- Runder Wollteppich ---

def build_round_rug(k):
    k.mat("rug", SAND, grain="fabric", rough=0.98, vary=0.06, bump=0.5, scale=2.0)
    k.mat("rug_ring", WHITE, grain="fabric", rough=0.98, vary=0.05, bump=0.5)
    F.rug(k, "rug", (1.6, 1.6), thickness=0.014, shape="round")
    ring = k.part("Ring", "rug_ring", bevel=0.001, settle=False)
    pts = [(math.cos(2 * math.pi * i / 72) * 0.66, math.sin(2 * math.pi * i / 72) * 0.66) for i in range(72)]
    inner = [(x * 0.94, y * 0.94) for x, y in reversed(pts)]
    # Ring als Streifen aus vielen kleinen Platten (eine Platte mit Loch geht nicht)
    for i in range(72):
        j = (i + 1) % 72
        quad = [pts[i], pts[j], (pts[j][0] * 0.94, pts[j][1] * 0.94), (pts[i][0] * 0.94, pts[i][1] * 0.94)]
        ring.slab(quad, 0.0014, Matrix.Translation((0, 0, 0.0142)), dent=0.0)
    k.collider((0, 0, 0.007), (1.6, 1.6, 0.014))


def opal(k, slot="glass_shade", emit=1.8):
    return k.mat(slot, (0.97, 0.95, 0.9), grain="smooth", rough=0.3, vary=0.02, emit=emit, emit_color=(1.0, 0.86, 0.66))


# --- Kugel-Stehleuchte ---

def build_globe_floor_lamp(k):
    metal(k)
    opal(k)
    base = k.part("Fuß", "metal", bevel=0.0)
    base.lathe([(0.0, 0.0), (0.15, 0.0), (0.155, 0.01), (0.14, 0.022), (0.0, 0.024)], (0, 0, 0), segs=40)
    pole = k.part("Stab", "metal", bevel=0.0)
    pole.tube([(0, 0, 0.02), (0, 0, 1.38)], 0.009, segs=10)
    pole.lathe([(0.0, 0.0), (0.03, 0.0), (0.032, 0.02), (0.0, 0.03)], (0, 0, 1.37), segs=16)
    glass = k.part("Kugel", "glass_shade", bevel=0.0)
    F.sphere(glass, (0, 0, 1.55), 0.17, segs=32, rings=16)
    k.light_kind = "electric"
    k.shadow = "important"
    k.light((0, 0, 1.55), energy=1.5, rng=6.0)
    k.collider((0, 0, 0.86), (0.34, 0.34, 1.72))


# --- Pilzlampe ---

def build_mushroom_lamp(k):
    k.mat("shade", (0.94, 0.9, 0.82), grain="smooth", rough=0.35, vary=0.03, emit=1.6, emit_color=(1.0, 0.85, 0.62))
    k.mat("ceramic", (0.94, 0.9, 0.82), grain="smooth", rough=0.45, vary=0.04)
    stem = k.part("Fuß", "ceramic", bevel=0.0)
    stem.lathe([(0.0, 0.0), (0.075, 0.0), (0.078, 0.012), (0.05, 0.03), (0.03, 0.08), (0.025, 0.2), (0.032, 0.22), (0.0, 0.225)],
               (0, 0, 0), segs=32)
    cap = k.part("Schirm", "shade", bevel=0.0)
    cap.lathe([(0.0, 0.0), (0.14, 0.0), (0.15, 0.012), (0.13, 0.06), (0.08, 0.1), (0.0, 0.115)], (0, 0, 0.215), segs=40)
    k.light_kind = "electric"
    k.shadow = "optional"
    k.light((0, 0, 0.2), energy=0.7, rng=3.0)
    k.collider((0, 0, 0.165), (0.3, 0.3, 0.33))


# --- Opalglas-Pendelleuchte ---

def build_opal_pendant(k):
    k.mat("cord", CHARCOAL, grain="smooth", rough=0.6, vary=0.02)
    metal(k, WHITE)
    opal(k)
    top = k.part("Baldachin", "metal", bevel=0.0)
    top.lathe([(0.0, 0.0), (0.06, 0.0), (0.06, -0.02), (0.0, -0.022)], (0, 0, 0), segs=24)
    cord = k.part("Kabel", "cord", bevel=0.0)
    cord.tube([(0, 0, -0.02), (0, 0, -0.62)], 0.004, segs=6)
    holder = k.part("Fassung", "metal", bevel=0.0)
    holder.lathe([(0.0, 0.0), (0.03, 0.0), (0.035, -0.04), (0.0, -0.045)], (0, 0, -0.6), segs=18)
    glass = k.part("Glas", "glass_shade", bevel=0.0)
    F.sphere(glass, (0, 0, -0.78), 0.15, segs=32, rings=16)
    k.light_kind = "electric"
    k.shadow = "optional"
    k.light((0, 0, -0.78), energy=1.6, rng=7.0)
    k.collider((0, 0, -0.78), (0.3, 0.3, 0.3))
    k.interact = (Vector((0, 0, -0.62)), Vector((0.32, 0.32, 0.64)))


# --- Schwenkarm-Wandleuchte ---

def build_swing_wall_lamp(k):
    metal(k)
    k.mat("shade_inner", (0.97, 0.94, 0.86), grain="smooth", rough=0.4, vary=0.02, emit=2.0, emit_color=(1.0, 0.85, 0.6))
    plate = k.part("Wandplatte", "metal", bevel=0.0)
    plate.lathe([(0.0, 0.0), (0.045, 0.0), (0.045, 0.02), (0.0, 0.022)], (0, 0, 0), segs=24, turn=(90, 0))
    arm = k.part("Arm", "metal", bevel=0.0)
    arm.tube([(0, -0.02, 0.0), (0, -0.05, 0.0), (0.06, -0.24, 0.02), (0.06, -0.3, 0.02)], 0.007, segs=8, smooth=1, round_ends=True)
    arm.blob((0, -0.05, 0.0), 0.014, subdiv=1, lump=0.02)
    shade = k.part("Schirm", "metal", bevel=0.0)
    m = Vector((0.06, -0.31, -0.02))
    F.shade(shade, m, 0.085, 0.03, 0.1, kind="bell", segs=32, wall=0.004)
    inner = k.part("Innen", "shade_inner", bevel=0.0)
    inner.blob(m + Vector((0, 0, 0.04)), 0.028, subdiv=2, lump=0.02)
    k.light_kind = "electric"
    k.shadow = "none"
    k.light(m + Vector((0, 0, 0.0)), energy=0.8, rng=4.0, shadow=False)
    k.collider((0.03, -0.16, 0.02), (0.14, 0.32, 0.16))


# --- Stumpenkerzen auf Tablett ---

def build_pillar_candles(k):
    k.mat("tray", GREY, grain="stone", rough=0.8, vary=0.06, bump=0.3)
    k.mat("wax", (0.95, 0.93, 0.88), grain="smooth", rough=0.55, vary=0.03, scale=8.0)
    tray = k.part("Tablett", "tray", bevel=0.0)
    tray.lathe([(0.0, 0.0), (0.15, 0.0), (0.16, 0.008), (0.162, 0.022), (0.152, 0.022), (0.146, 0.01), (0.0, 0.01)], (0, 0, 0), segs=40)
    for (x, y, h, r) in ((-0.06, 0.02, 0.15, 0.035), (0.045, 0.035, 0.11, 0.032), (0.0, -0.06, 0.08, 0.03)):
        F.candle(k, "wax", (x, y, 0.01), h, r, drips=2, segs=18)
    k.light_kind = "flame"
    k.shadow = "none"
    k.light((0, 0, 0.22), energy=0.3, rng=2.0, shadow=False)
    k.collider((0, 0, 0.08), (0.33, 0.33, 0.16))


# --- Waffeldecke mit Kissen ---

def build_waffle_throw(k):
    fabric(k, CREAM)
    k.mat("cushion", SAGE, grain="fabric", rough=0.95, vary=0.06, bump=0.4)
    b = k.part("Decke", "fabric", bevel=0.0)
    for i in range(3):
        F.pillow(b, (0.004 * i, -0.003 * i, 0.016 + i * 0.03), (0.48, 0.32, 0.034), roundness=5.0, puff=0.005, step=0.03, turn=(i - 1) * 1.2)
    b.tube([(-0.24, -0.16, 0.05), (0.24, -0.16, 0.05)], 0.031, segs=12, round_ends=True)
    c = k.part("Kissen", "cushion", bevel=0.0)
    F.pillow(c, (0.02, 0.02, 0.16), (0.36, 0.3, 0.13), roundness=2.6, puff=0.02, step=0.03, turn=8)
    F.piping(c, (0.02, 0.02, 0.16), (0.36, 0.3, 0.13), 0.0, r=0.005, roundness=2.6, matrix=Matrix.Rotation(math.radians(8), 4, "Z") @ Matrix.Translation((0, 0, 0)))
    k.collider((0, 0, 0.1), (0.5, 0.36, 0.2))
    k.surface((0.02, 0.02, 0.22), (0.28, 0.22))


# --- Linienbild ---

def build_line_art(k):
    wood(k)
    k.mat("paper", (0.95, 0.94, 0.9), grain="paint", rough=0.8, vary=0.02)
    k.mat("ink", CHARCOAL, grain="smooth", rough=0.6, vary=0.02)
    k.mat("accent", CLAY, grain="paint", rough=0.8, vary=0.04)
    W, H = 0.44, 0.58
    fr = k.part("Rahmen", "wood", bevel=0.002)
    F.frame(fr, (0, 0, 0), W, H, 0.03, 0.025)
    paper = k.part("Passepartout", "paper", bevel=0.0, settle=False)
    paper.box((0, -0.01, 0), (W - 0.03, 0.01, H - 0.03), step=0.3, dent=0.0)
    line = k.part("Linie", "ink", bevel=0.0, settle=False)
    pts = []
    for i in range(60):
        t = i / 59
        x = -0.1 + 0.2 * t + 0.05 * math.sin(t * 9)
        z = -0.13 + 0.26 * math.sin(t * math.pi) * (0.6 + 0.4 * math.cos(t * 7))
        pts.append(Vector((x, -0.0165, z)))
    line.tube(pts, 0.0025, segs=5, smooth=1, round_ends=True)
    dot = k.part("Sonne", "accent", bevel=0.0, settle=False)
    dot.lathe([(0.0, 0.0), (0.045, 0.0), (0.045, 0.003), (0.0, 0.004)], (0.06, -0.0155, 0.12), segs=32, turn=(90, 0))
    k.collider((0, -0.015, 0), (W, 0.03, H))


# --- Mobile ---

def build_mobile(k):
    metal(k)
    k.mat("disc_a", CLAY, grain="paint", rough=0.7, vary=0.04)
    k.mat("disc_b", SAGE, grain="paint", rough=0.7, vary=0.04)
    k.mat("disc_c", SAND, grain="paint", rough=0.7, vary=0.04)
    wire = k.part("Draht", "metal", bevel=0.0)
    wire.lathe([(0.0, 0.0), (0.025, 0.0), (0.025, -0.01), (0.0, -0.012)], (0, 0, 0), segs=16)
    wire.tube([(0, 0, -0.01), (0, 0, -0.25)], 0.0015, segs=4)

    def arm(center, span, depth, level):
        c = Vector(center)
        a, b = c + Vector((-span * 0.55, 0, 0)), c + Vector((span * 0.45, 0, 0))
        wire.tube([a, c + Vector((0, 0, 0.012)), b], 0.0022, segs=5, smooth=2, round_ends=True)
        for end, mat in ((a, "disc_a" if level % 2 else "disc_b"), (b, "disc_c")):
            if level < 2 and end is a:
                wire.tube([end, end - Vector((0, 0, depth))], 0.0015, segs=4)
                arm(end - Vector((0, 0, depth)), span * 0.7, depth * 0.9, level + 1)
            else:
                wire.tube([end, end - Vector((0, 0, 0.06))], 0.0015, segs=4)
                d = k.part("Scheibe", mat, bevel=0.0)
                d.lathe([(0.0, -0.004), (0.07 - level * 0.012, -0.004), (0.07 - level * 0.012, 0.004), (0.0, 0.004)],
                        end - Vector((0, 0, 0.06 + 0.07 - level * 0.012)), segs=28, turn=(90, 0))
    arm((0, 0, -0.25), 0.5, 0.18, 0)
    k.collider((-0.05, 0, -0.45), (0.55, 0.12, 0.4))


# --- Keramikvasen mit Zweig ---

def build_vases(k):
    k.mat("ceramic", WHITE, grain="smooth", rough=0.45, vary=0.04)
    k.mat("ceramic2", SAND, grain="stone", rough=0.8, vary=0.05, bump=0.3)
    v = k.part("Vase hoch", "ceramic", bevel=0.0)
    v.lathe([(0.0, 0.0), (0.045, 0.0), (0.055, 0.06), (0.045, 0.14), (0.016, 0.2), (0.016, 0.23), (0.022, 0.24), (0.012, 0.24),
             (0.01, 0.2), (0.0, 0.2)], (-0.04, 0.0, 0.0), segs=28)
    v2 = k.part("Vase rund", "ceramic2", bevel=0.0)
    v2.lathe([(0.0, 0.0), (0.04, 0.0), (0.06, 0.04), (0.055, 0.08), (0.02, 0.11), (0.024, 0.12), (0.016, 0.12), (0.0, 0.1)],
             (0.075, 0.02, 0.0), segs=28)
    v3 = k.part("Vase klein", "ceramic", bevel=0.0)
    v3.lathe([(0.0, 0.0), (0.028, 0.0), (0.03, 0.05), (0.012, 0.075), (0.014, 0.085), (0.0, 0.08)], (0.02, -0.07, 0.0), segs=24)
    p = k.plant(None)
    rnd = random.Random(k.seed)
    F.eucalyptus(p, Vector((-0.04, 0.0, 0.2)), Vector((0.25, -0.1, 1.0)), 0.32, rnd)
    F.eucalyptus(p, Vector((-0.04, 0.0, 0.2)), Vector((-0.3, 0.1, 1.0)), 0.26, rnd)
    k.add_plant(p, (0, 0, 0))
    k.collider((0.0, 0, 0.12), (0.22, 0.18, 0.24))


# --- Monstera ---

def build_monstera(k):
    k.mat("pot", WHITE, grain="smooth", rough=0.5, vary=0.04)
    wood(k)
    soil, rim = F.pot(k, (0, 0, 0.12), 0.17, 0.32, style="cylinder", slot="pot")
    stand = k.part("Pflanzenständer", "wood", bevel=0.0)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        F.tapered_leg(stand, d * 0.12 + Vector((0, 0, 0.13)), d * 0.17 + Vector((0, 0, 0.0)), 0.016, 0.011)
    F.ring(stand, (0, 0, 0.125), 0.14, 0.012, n=36)
    p = k.plant()
    F.monstera(p, 1.2, leaves=20)
    k.add_plant(p, soil, scale=rim / 0.2)
    k.collider((0, 0, 0.22), (0.36, 0.36, 0.44))


# --- Sukkulenten in der Betonschale ---

def build_succulents(k):
    k.mat("pot", (0.7, 0.69, 0.66), grain="stone", rough=0.85, vary=0.06, bump=0.35)
    k.mat("pebble", (0.86, 0.84, 0.8), grain="stone", rough=0.8, vary=0.1)
    soil, rim = F.pot(k, (0, 0, 0), 0.085, 0.06, style="bowl", slot="pot")
    p = k.plant(None)
    for (dx, dy, r, mat, n) in ((-0.03, 0.01, 0.045, "leaf_blue", 16), (0.035, -0.015, 0.038, "leaf_silver", 14),
                                (0.012, 0.045, 0.03, "leaf_lime", 12), (-0.02, -0.045, 0.028, "leaf_bronze", 11),
                                (0.055, 0.03, 0.024, "leaf_blue", 10), (-0.062, -0.012, 0.022, "leaf_lime", 9)):
        F.succulent_rosette(p, soil + Vector((dx, dy, 0.0)), r, mat=mat, n=n)
    k.add_plant(p, (0, 0, 0))
    peb = k.part("Kiesel", "pebble", bevel=0.0, settle=False)
    rnd = random.Random(k.seed)
    for i in range(10):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.02, rim * 0.85)
        peb.blob(soil + Vector((math.cos(a) * rr, math.sin(a) * rr, -0.002)), rnd.uniform(0.006, 0.01), subdiv=1, lump=0.15, scale=(1, 1, 0.6))
    k.collider((0, 0, 0.05), (0.18, 0.18, 0.1))


# --- Efeutute in der Hängeampel ---

def build_hanging_pothos(k):
    k.mat("pot", WHITE, grain="smooth", rough=0.5, vary=0.04)
    k.mat("cord", SAND, grain="fabric", rough=0.9, vary=0.04)
    hook = k.part("Haken", "pot", bevel=0.0)
    hook.lathe([(0.0, 0.0), (0.03, 0.0), (0.03, -0.012), (0.0, -0.014)], (0, 0, 0), segs=16)
    ring_top = Vector((0, 0, -0.05))
    F.ring(hook, ring_top, 0.012, 0.003, matrix=Matrix.Rotation(math.radians(90), 4, "X"), n=14)
    pot_base = Vector((0, 0, -0.62))
    soil, rim = F.pot(k, pot_base, 0.11, 0.12, style="bowl", slot="pot")
    cords = k.part("Schnüre", "cord", bevel=0.0)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        cords.tube([ring_top - Vector((0, 0, 0.01)), pot_base + d * rim * 1.04 + Vector((0, 0, 0.11))], 0.0025, segs=5)
    p = k.plant("pot")
    G.trailing(p, None, ranks=16, leaf_mat="leaf_lime", shape="heart")
    k.add_plant(p, soil, scale=rim / 0.205)
    k.collider((0, 0, -0.55), (0.3, 0.3, 0.2))
    k.interact = (Vector((0, 0, -0.4)), Vector((0.3, 0.3, 0.8)))


# --- Mondlampe ---

def build_moon_lamp(k):
    wood(k)
    k.mat("moon", (0.96, 0.92, 0.82), grain="stone", rough=0.7, vary=0.06, bump=0.5, emit=1.2, emit_color=(1.0, 0.9, 0.72))
    k.mat("crater", (0.85, 0.8, 0.7), grain="stone", rough=0.75, vary=0.05, emit=0.8, emit_color=(1.0, 0.86, 0.66))
    cup = k.part("Ständer", "wood", bevel=0.0)
    cup.lathe([(0.0, 0.0), (0.06, 0.0), (0.062, 0.01), (0.05, 0.02), (0.04, 0.035), (0.03, 0.035), (0.0, 0.028)], (0, 0, 0), segs=28)
    moon = k.part("Mond", "moon", bevel=0.0)
    c = Vector((0, 0, 0.13))
    F.sphere(moon, c, 0.1, segs=32, rings=16)
    craters = k.part("Krater", "crater", bevel=0.0)
    rnd = random.Random(k.seed)
    for i in range(11):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 0.4), rnd.uniform(-0.2, 1))).normalized()
        F.patch(craters, c + d * 0.099, d, rnd.uniform(0.008, 0.022), 0.003, rnd, wobble=0.2, segs=12)
    k.light_kind = "electric"
    k.shadow = "none"
    k.light(c, energy=0.5, rng=2.5, shadow=False)
    k.collider((0, 0, 0.115), (0.2, 0.2, 0.23))


# --- Beton-Buchstützen ---

def build_arch_bookends(k):
    k.mat("concrete", (0.7, 0.69, 0.66), grain="stone", rough=0.85, vary=0.07, bump=0.4)
    for side in (-1, 1):
        b = k.part("Bogen", "concrete", bevel=0.004)
        # Viertelbogen: flache Seite innen (zu den Büchern), Bogen nach außen
        outline = [(0.0, 0.0)] + [(side * 0.12 * math.cos(math.pi / 2 * i / 14), 0.16 * math.sin(math.pi / 2 * i / 14)) for i in range(15)]
        m = Matrix.Translation((side * 0.09, 0.04, 0)) @ Matrix.Rotation(math.radians(90), 4, "X")
        b.slab(outline, 0.08, m, dent=0.0008)
    for side in (-1, 1):
        k.collider((side * 0.15, 0, 0.08), (0.12, 0.08, 0.16))

ITEMS = [
    dict(id="shelf_cube_white", name="Würfelregal", category="shelf", sub="bookshelf", price=140,
         desc="Sechs offene Würfel mit runden Kanten auf kleinen Füßen – jeder Würfel ein Fach.",
         styles=STYLE, place="floor", adopt=True, build=build_cube_shelf, variants=wood_variants()),
    dict(id="bookshelf_min_tall", name="Schlankes Regal", category="shelf", sub="bookshelf", price=170,
         desc="Fünf helle Böden an schlanken Metallstäben – luftig und ruhig.",
         styles=STYLE, place="floor", build=build_slim_shelf, variants=wood_variants()),
    dict(id="chair_shell", name="Schalenstuhl", category="seating", sub="chair", price=60,
         desc="Weiche Sitzschale mit runder Lehne auf schlanken Holzbeinen.",
         styles=STYLE, place="floor", lean=True, adopt=True, build=build_shell_chair,
         variants=[("sage", "Salbei", {"shell": SAGE}), ("white", "Weiß", {"shell": WHITE}), ("blue", "Taubenblau", {"shell": DUSTY_BLUE}),
                   ("clay", "Terrakotta", {"shell": CLAY}), ("charcoal", "Anthrazit", {"shell": CHARCOAL})]),
    dict(id="armchair_min", name="Loungesessel aus Bouclé", category="seating", sub="armchair", price=170,
         desc="Ein runder, weicher Sessel wie eine Muschel – zum Einkuscheln.",
         styles=STYLE, place="floor", lean=True, build=build_lounge_chair, variants=fabric_variants()),
    dict(id="sofa_min", name="Weiches Zweisitzer-Sofa", category="seating", sub="sofa", price=290,
         desc="Dicke, runde Kissen auf schlanken Holzbeinen.",
         styles=STYLE, place="floor", lean=True, build=build_soft_sofa, variants=fabric_variants()),
    dict(id="table_bistro", name="Runder Esstisch", category="table", sub="dining_table", price=110,
         desc="Runde Holzplatte auf vier schräg gestellten Beinen.",
         styles=STYLE, place="floor", adopt=True, build=build_round_table, variants=wood_variants()),
    dict(id="desk_min", name="Schlanker Schreibtisch", category="table", sub="desk", price=150,
         desc="Helle Platte, eine weiße Schublade mit Griffleiste, schlanke Beine.",
         styles=STYLE, place="floor", build=build_slim_desk, variants=wood_variants()),
    dict(id="side_table_min", name="Tablett-Beistelltisch", category="table", sub="side_table", price=55,
         desc="Ein rundes Metalltablett auf drei dünnen Beinen.",
         styles=STYLE, place="floor", build=build_tray_table,
         variants=[("black", "Schwarz", {"metal": BLACK_METAL}), ("white", "Weiß", {"metal": WHITE}), ("sage", "Salbei", {"metal": SAGE}),
                   ("brass", "Messing", {"metal": (0.78, 0.62, 0.34)})]),
    dict(id="sideboard_min", name="Sideboard mit Lamellen", category="shelf", sub="cabinet", price=220,
         desc="Niedriges Sideboard mit gerillten Türen und runden Knöpfen – oben viel Platz für Deko.",
         styles=STYLE, place="floor", build=build_sideboard, variants=wood_variants()),
    dict(id="divider_shelf", name="Lamellen-Raumteiler", category="divider", sub="", price=180,
         desc="Senkrechte Holzstäbe auf einem flachen Fuß – trennt, ohne zu verschließen.",
         styles=STYLE, place="floor", adopt=True, build=build_slat_divider, variants=wood_variants()),
    dict(id="rug_round", name="Runder Wollteppich", category="deco", sub="rug", price=90,
         desc="Ein weicher, runder Teppich mit einem feinen hellen Ring.",
         styles=STYLE, place="floor", build=build_round_rug,
         variants=[("sand", "Sand", {"rug": SAND}), ("grey", "Steingrau", {"rug": GREY}), ("sage", "Salbei", {"rug": SAGE}),
                   ("blue", "Taubenblau", {"rug": DUSTY_BLUE}), ("clay", "Terrakotta", {"rug": CLAY})]),
    dict(id="lamp_globe", name="Kugel-Stehleuchte", category="lighting", sub="floor_lamp", price=95,
         desc="Eine Opalglaskugel auf einem schlanken Stab – weiches, gleichmäßiges Licht.",
         styles=STYLE, place="floor", adopt=True, build=build_globe_floor_lamp,
         variants=[("black", "Schwarz", {"metal": BLACK_METAL}), ("white", "Weiß", {"metal": WHITE}),
                   ("brass", "Messing", {"metal": (0.78, 0.62, 0.34)}), ("sage", "Salbei", {"metal": SAGE})]),
    dict(id="lamp_mushroom", name="Pilzlampe", category="lighting", sub="table_lamp", price=60,
         desc="Ein runder Schirm auf einem schlanken Keramikfuß – leuchtet wie ein kleiner Pilz.",
         styles=STYLE, place=["surface", "floor"], build=build_mushroom_lamp,
         variants=[("cream", "Creme", {"shade": (0.94, 0.9, 0.82), "ceramic": (0.94, 0.9, 0.82)}),
                   ("sage", "Salbei", {"shade": SAGE, "ceramic": SAGE}), ("clay", "Terrakotta", {"shade": CLAY, "ceramic": CLAY}),
                   ("blue", "Taubenblau", {"shade": DUSTY_BLUE, "ceramic": DUSTY_BLUE})]),
    dict(id="pendant_modern", name="Opalglas-Pendelleuchte", category="lighting", sub="ceiling_lamp", price=110,
         desc="Eine schlichte Glaskugel an einem langen Kabel.",
         styles=STYLE, place="ceiling", adopt=True, build=build_opal_pendant,
         variants=[("white", "Weiß", {"metal": WHITE}), ("black", "Schwarz", {"metal": BLACK_METAL}),
                   ("brass", "Messing", {"metal": (0.78, 0.62, 0.34)})]),
    dict(id="wall_lamp_min", name="Schwenkarm-Wandleuchte", category="lighting", sub="wall_lamp", price=55,
         desc="Ein schlanker Arm mit kleinem Glockenschirm – perfekt über einem Sessel.",
         styles=STYLE, place="wall", build=build_swing_wall_lamp,
         variants=[("black", "Schwarz", {"metal": BLACK_METAL}), ("white", "Weiß", {"metal": WHITE}),
                   ("sage", "Salbei", {"metal": SAGE}), ("clay", "Terrakotta", {"metal": CLAY})]),
    dict(id="candles_min", name="Stumpenkerzen auf Tablett", category="lighting", sub="candle", price=24,
         desc="Drei Kerzen in verschiedenen Höhen auf einem runden Steintablett.",
         styles=STYLE, place=["surface", "floor"], build=build_pillar_candles,
         variants=[("white", "Weiß", {"wax": (0.95, 0.93, 0.88)}), ("sand", "Sand", {"wax": SAND}), ("sage", "Salbei", {"wax": SAGE}),
                   ("clay", "Terrakotta", {"wax": CLAY})]),
    dict(id="throw_waffle", name="Waffeldecke mit Kissen", category="deco", sub="textile", price=32,
         desc="Eine gefaltete Waffeldecke und ein weiches Kissen obendrauf.",
         styles=STYLE, place=["surface", "floor"], lie=True, build=build_waffle_throw,
         variants=[("sage", "Creme · Salbei", {"fabric": CREAM, "cushion": SAGE}), ("blue", "Creme · Taubenblau", {"fabric": CREAM, "cushion": DUSTY_BLUE}),
                   ("clay", "Sand · Terrakotta", {"fabric": SAND, "cushion": CLAY}), ("grey", "Grau · Weiß", {"fabric": GREY, "cushion": WHITE})]),
    dict(id="wall_picture", name="Linienbild", category="deco", sub="picture", price=45,
         desc="Eine einzige schwungvolle Linie und eine kleine Sonne, hinter Glas im schmalen Rahmen.",
         styles=STYLE, place="wall", adopt=True, build=build_line_art, variants=wood_variants()),
    dict(id="mobile_min", name="Mobile", category="deco", sub="picture", price=38,
         desc="Ein schwebendes Mobile aus Draht und farbigen Scheiben, das an der Decke hängt.",
         styles=STYLE, place="ceiling", build=build_mobile,
         variants=[("black", "Schwarz", {"metal": BLACK_METAL}), ("brass", "Messing", {"metal": (0.78, 0.62, 0.34)}),
                   ("white", "Weiß", {"metal": WHITE})]),
    dict(id="vase_branches", name="Keramikvasen mit Eukalyptus", category="deco", sub="vase", price=26,
         desc="Drei kleine Vasen, in der hohen zwei Eukalyptuszweige.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_vases,
         variants=[("white", "Weiß · Sand", {"ceramic": WHITE, "ceramic2": SAND}), ("sage", "Salbei · Weiß", {"ceramic": SAGE, "ceramic2": WHITE}),
                   ("clay", "Terrakotta · Sand", {"ceramic": CLAY, "ceramic2": SAND}), ("charcoal", "Anthrazit · Grau", {"ceramic": CHARCOAL, "ceramic2": GREY})]),
    dict(id="plant_monstera", name="Monstera auf Pflanzenständer", category="deco", sub="plant", price=75,
         desc="Eine große Monstera mit geschlitzten Blättern in einem Zylindertopf auf Holzbeinen.",
         styles=STYLE, place="floor", lean=True, adopt=True, build=build_monstera,
         variants=[("white", "Weiß", {"pot": WHITE}), ("clay", "Terrakotta", {"pot": CLAY}), ("sage", "Salbei", {"pot": SAGE}),
                   ("charcoal", "Anthrazit", {"pot": CHARCOAL})]),
    dict(id="succulent_mini", name="Sukkulenten in der Betonschale", category="deco", sub="plant", price=14,
         desc="Drei kleine Rosetten zwischen hellen Kieseln – für Regal und Fensterbank.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_succulents,
         variants=[("concrete", "Beton", {"pot": (0.7, 0.69, 0.66)}), ("white", "Weiß", {"pot": WHITE}), ("clay", "Terrakotta", {"pot": CLAY}),
                   ("charcoal", "Anthrazit", {"pot": CHARCOAL})]),
    dict(id="plant_pothos_hanging", name="Efeutute in der Hängeampel", category="deco", sub="plant", price=36,
         desc="Lange Ranken mit herzförmigen Blättern fallen aus einer Keramikschale an drei Schnüren.",
         styles=STYLE, place="ceiling", build=build_hanging_pothos,
         variants=[("white", "Weiß", {"pot": WHITE}), ("clay", "Terrakotta", {"pot": CLAY}), ("sage", "Salbei", {"pot": SAGE}),
                   ("blue", "Taubenblau", {"pot": DUSTY_BLUE})]),
    dict(id="moon_lamp", name="Mondlampe", category="lighting", sub="table_lamp", price=48,
         desc="Ein kleiner Mond mit Kratern auf einem Holzständer, der sanft leuchtet.",
         styles=STYLE, place=["surface", "floor"], build=build_moon_lamp, variants=wood_variants()),
    dict(id="bookend_concrete", name="Bogen-Buchstützen aus Beton", category="deco", sub="bookend", price=18,
         desc="Zwei schwere Viertelbögen aus Beton halten die Bücher.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_arch_bookends,
         variants=[("concrete", "Beton", {"concrete": (0.7, 0.69, 0.66)}), ("sand", "Sand", {"concrete": SAND}),
                   ("clay", "Terrakotta", {"concrete": CLAY}), ("charcoal", "Anthrazit", {"concrete": CHARCOAL})]),
]
