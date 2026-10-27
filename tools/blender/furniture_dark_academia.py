"""Dark Academia: Studierzimmer und alte Bibliothek – Walnuss, Leder, Messing, Bordeaux,
Flaschengrün, Dunkelblau, Kerzenlicht (Etappe 6, Möbelkatalog im neuen Stil).

Jedes Objekt: eine Beschreibung (Name, Preis, Kategorie, Farben …) und eine Bau-Funktion, die mit
den Bausteinen aus storybook_furniture.py arbeitet (Blender-Koordinaten, Vorderseite -y).
"""

import math
import random

from mathutils import Matrix, Vector

import storybook_furniture as F
import storybook_greenery as G

STYLE = ["dark_academia"]
WALNUT = (0.36, 0.22, 0.14)
MAHOGANY = (0.42, 0.19, 0.13)
BRASS = (0.8, 0.62, 0.32)
IVORY = (0.93, 0.88, 0.74)
COGNAC = (0.56, 0.29, 0.15)
BORDEAUX = (0.42, 0.1, 0.13)
BOTTLE = (0.14, 0.27, 0.2)
NAVY = (0.14, 0.18, 0.31)
CHOCOLATE = (0.27, 0.16, 0.11)
WOODS = [("walnut", "Walnuss", WALNUT), ("mahogany", "Mahagoni", MAHOGANY), ("oak", "Räuchereiche", (0.44, 0.3, 0.18)),
         ("ebony", "Ebenholz", (0.19, 0.13, 0.1))]


def wood(k, color=WALNUT, slot="wood"):
    return k.mat(slot, color, grain="wood", rough=0.62, vary=0.08, bump=0.12)


def brass(k, slot="brass"):
    return k.mat(slot, BRASS, grain="smooth", rough=0.36, metal=0.65, vary=0.07, scale=5.0)


def leather(k, color=COGNAC, slot="leather"):
    return k.mat(slot, color, grain="smooth", rough=0.5, vary=0.13, scale=5.0, bump=0.18)


def wood_variants(slot="wood"):
    return [(vid, name, {slot: col}) for vid, name, col in WOODS]


# --- Ohrensessel ---

def build_wingchair(k):
    wood(k)
    leather(k)
    brass(k)
    feet = k.part("Füße", "wood", bevel=0.004)
    for x in (-0.33, 0.33):
        for y in (-0.3, 0.3):
            F.turned_leg(feet, (x, y, 0.0), 0.09, 0.034, style="bun")
    up = k.part("Polster", "leather", bevel=0.0)
    base = ((0, 0.02, 0.225), (0.8, 0.74, 0.27))
    F.pillow(up, base[0], base[1], roundness=4.5, puff=0.004, step=0.04)
    F.piping(up, base[0], base[1], -0.1, r=0.0065, roundness=4.5)
    seat = k.part("Sitzkissen", "leather", bevel=0.0)
    cushion = ((0, -0.06, 0.425), (0.56, 0.6, 0.13))
    F.pillow(seat, cushion[0], cushion[1], roundness=4.0, puff=0.016, step=0.03)
    for zz in (0.04, -0.04):
        F.piping(seat, cushion[0], cushion[1], zz, r=0.005, roundness=4.0)
    back = k.part("Rückenlehne", "leather", bevel=0.0)
    tilt = Matrix.Translation((0, 0.3, 0.74)) @ Matrix.Rotation(math.radians(-8), 4, "X")
    F.pillow(back, (0, 0, 0), (0.68, 0.17, 0.66), roundness=3.6, puff=0.01, step=0.035, matrix=tilt)
    buttons = k.part("Knöpfe", "leather", bevel=0.0)
    for row, zz in enumerate((-0.16, 0.0, 0.16)):
        for col in range(3 if row != 1 else 2):
            xx = (-0.17 + col * 0.17) if row != 1 else (-0.085 + col * 0.17)
            F.button(buttons, tilt @ Vector((xx, -0.087, zz)), r=0.012, normal=tilt.to_3x3() @ Vector((0, -1, 0)))
    for side in (-1, 1):
        # Ohren: von der Armlehne bis fast oben, hinten fest an der Rückenlehne, vorn rund
        wing = k.part("Ohr", "leather", bevel=0.0)
        F.pillow(wing, (side * 0.34, 0.17, 0.79), (0.13, 0.4, 0.56), roundness=3.4, puff=0.006, step=0.035, turn=side * -7)
        arm = k.part("Armlehne", "leather", bevel=0.0)
        F.pillow(arm, (side * 0.36, -0.02, 0.5), (0.14, 0.74, 0.25), roundness=3.8, puff=0.008, step=0.035)
        # gerollte Front der Armlehne mit Messingnägeln
        roll = k.part("Armrolle", "leather", bevel=0.0)
        roll.lathe([(0.0, 0.0), (0.07, 0.0), (0.078, 0.01), (0.078, 0.03), (0.07, 0.04), (0.0, 0.04)],
                   (side * 0.36, -0.355, 0.54), segs=20, turn=(90, 0))
        nails = k.part("Ziernägel", "brass", bevel=0.0)
        for i in range(9):
            a = math.radians(-60 + i * 30)
            nails.blob((side * 0.36 + math.sin(a) * 0.064, -0.398, 0.54 + math.cos(a) * 0.064), 0.0055, subdiv=1, lump=0.05, scale=(1, 0.6, 1))
    nails = k.part("Ziernägel Sockel", "brass", bevel=0.0)
    x = -0.36
    while x <= 0.361:
        nails.blob((x, -0.36, 0.13), 0.0055, subdiv=1, lump=0.05, scale=(1, 0.6, 1))
        x += 0.034
    k.collider((0, 0.0, 0.18), (0.84, 0.78, 0.36))
    k.collider((0, -0.06, 0.245), (0.56, 0.6, 0.49))
    for side in (-1, 1):
        k.collider((side * 0.36, -0.02, 0.31), (0.14, 0.74, 0.62))
    k.collider((0, 0.3, 0.7), (0.74, 0.2, 0.68))
    k.surface((0, -0.07, 0.49), (0.46, 0.48))
    for side in (-1, 1):
        k.surface((side * 0.36, -0.03, 0.625), (0.1, 0.6))
    k.seat((0, -0.05, 0.49))
    k.interact = (Vector((0, -0.04, 0.62)), Vector((0.6, 0.62, 0.5)))


# --- Bibliotheksregal ---

def build_library_shelf(k):
    wood(k)
    brass(k)
    W, D = 1.12, 0.4
    carcass = k.part("Korpus", "wood", bevel=0.005)
    for side in (-1, 1):
        carcass.box((side * 0.54, 0.0, 1.08), (0.04, 0.38, 2.12), step=0.3, dent=0.0012)
    carcass.box((0, 0.181, 1.08), (1.05, 0.018, 2.06), step=0.3, dent=0.001)
    plinth = k.part("Sockel", "wood", bevel=0.006)
    plinth.box((0, -0.004, 0.05), (1.12, 0.39, 0.1), step=0.3, dent=0.001)
    plinth.box((0, -0.006, 0.112), (1.14, 0.402, 0.026), step=0.3, dent=0.001)
    boards = k.part("Böden", "wood", bevel=0.004)
    tops = [0.14, 0.55, 0.94, 1.32, 1.69]
    for t in tops[1:]:
        boards.box((0, -0.004, t - 0.015), (1.05, 0.36, 0.03), step=0.3, dent=0.0008)
    boards.box((0, 0.0, 2.075), (1.08, 0.38, 0.03), step=0.3, dent=0.0008)
    crown = k.part("Kranz", "wood", bevel=0.005)
    crown.box((0, -0.008, 2.11), (1.16, 0.416, 0.04), step=0.3, dent=0.001)
    crown.box((0, -0.014, 2.145), (1.2, 0.432, 0.03), step=0.3, dent=0.001)
    crown.box((0, -0.018, 2.172), (1.23, 0.444, 0.024), step=0.3, dent=0.001)
    dent = k.part("Zahnschnitt", "wood", bevel=0.002)
    x = -0.55
    while x <= 0.551:
        dent.box((x, -0.229, 2.122), (0.022, 0.014, 0.022), step=0.5, dent=0.0004)
        x += 0.044
    pil = k.part("Pilaster", "wood", bevel=0.003)
    for side in (-1, 1):
        pil.box((side * 0.54, -0.196, 1.04), (0.05, 0.014, 1.82), step=0.3, dent=0.0008)
        for dx in (-0.012, 0.012):
            pil.tube([(side * 0.54 + dx, -0.203, 0.2), (side * 0.54 + dx, -0.203, 1.88)], 0.0035, segs=6, round_ends=True)
    ros = k.part("Rosetten", "wood", bevel=0.0)
    for side in (-1, 1):
        F.button(ros, (side * 0.54, -0.204, 1.98), r=0.022, normal=(0, -1, 0))
        F.button(ros, (side * 0.54, -0.204, 0.16), r=0.018, normal=(0, -1, 0))
    labels = k.part("Messingschilder", "brass", bevel=0.001)
    for t in tops[1:]:
        labels.box((0, -0.184, t - 0.016), (0.07, 0.004, 0.024), step=0.5, dent=0.0)
    # Fächer (von oben nach unten), Kollision je Brett
    clear_tops = tops[1:] + [2.06]
    for i in range(len(tops) - 1, -1, -1):
        h = clear_tops[i] - tops[i] - (0.0 if i == len(tops) - 1 else 0.03)
        k.row((0, -0.01, tops[i]), 1.02, h, 0.34)
    for side in (-1, 1):
        k.collider((side * 0.54, 0, 1.09), (0.045, 0.4, 2.18))
    k.collider((0, 0.181, 1.08), (1.05, 0.02, 2.06))
    k.collider((0, 0, 0.07), (1.12, 0.4, 0.14))
    for t in tops[1:]:
        k.collider((0, -0.004, t - 0.015), (1.05, 0.36, 0.03))
    k.collider((0, -0.01, 2.122), (1.2, 0.43, 0.1))
    k.surface((0, -0.01, 2.184), (1.12, 0.4))


# --- Bankerlampe ---

def build_banker_lamp(k):
    brass(k)
    k.mat("glass_shade", BOTTLE, grain="smooth", rough=0.22, vary=0.05, emit=0.25, emit_color=(0.3, 0.75, 0.45))
    k.mat("shade_inner", (0.95, 0.92, 0.82), grain="smooth", rough=0.4, vary=0.02, emit=2.2, emit_color=(1.0, 0.86, 0.62))
    base = k.part("Fuß", "brass", bevel=0.004)
    F.pillow(base, (0, 0.02, 0.016), (0.22, 0.15, 0.032), roundness=2.6, step=0.02)
    base.lathe([(0.0, 0.0), (0.04, 0.0), (0.035, 0.012), (0.014, 0.02), (0.0, 0.02)], (0, 0.03, 0.028), segs=16)
    stem = k.part("Stiel", "brass", bevel=0.0)
    stem.tube([(0, 0.03, 0.04), (0, 0.03, 0.27)], 0.0085, segs=10)
    stem.lathe([(0.0, 0.0), (0.014, 0.0), (0.016, 0.008), (0.014, 0.016), (0.0, 0.016)], (0, 0.03, 0.14), segs=12)
    # Halter quer unter dem Schirm
    stem.tube([(-0.11, 0.03, 0.27), (0.11, 0.03, 0.27)], 0.006, segs=8, round_ends=True)
    for x in (-0.11, 0.11):
        stem.tube([(x, 0.03, 0.265), (x, 0.03, 0.3)], 0.005, segs=8, round_ends=True)
    tilt = Matrix.Translation((0, 0.015, 0.3)) @ Matrix.Rotation(math.radians(-14), 4, "X")
    outer = k.part("Schirm", "glass_shade", bevel=0.0)
    F.arc_shell(outer, tilt, 0.32, 0.085, 0.004, -10, 190, seg_a=22, seg_l=12)
    inner = k.part("Schirm innen", "shade_inner", bevel=0.0)
    F.arc_shell(inner, tilt, 0.312, 0.0808, 0.002, -8, 188, seg_a=22, seg_l=12)
    rims = k.part("Schirmränder", "brass", bevel=0.0)
    for x in (-0.162, 0.162):
        pts = []
        for j in range(17):
            a = math.radians(-10 + 200 * j / 16)
            pts.append(tilt @ Vector((x, -math.cos(a) * 0.086, math.sin(a) * 0.086)))
        rims.tube(pts, 0.004, segs=6, round_ends=True)
    bulb = k.part("Glühbirne", "shade_inner", bevel=0.0)
    bulb.blob(tilt @ Vector((0, 0, 0.03)), 0.022, subdiv=2, lump=0.02, scale=(1.4, 1, 1))
    chain = k.part("Zugkette", "brass", bevel=0.0)
    top = tilt @ Vector((0.05, -0.07, -0.02))
    chain.tube([top, top - Vector((0, 0, 0.07))], 0.0012, segs=4)
    chain.blob(top - Vector((0, 0, 0.074)), 0.005, subdiv=1, lump=0.02)
    k.light_kind = "electric"
    k.shadow = "optional"
    k.light(tilt @ Vector((0, -0.02, 0.0)), energy=0.75, rng=3.2)
    k.collider((0, 0.02, 0.17), (0.34, 0.2, 0.34))


# --- Kerzenleuchter ---

def build_candelabra(k):
    brass(k)
    k.mat("wax", IVORY, grain="smooth", rough=0.55, vary=0.05, scale=8.0)
    b = k.part("Leuchter", "brass", bevel=0.0)
    b.lathe([(0.0, 0.0), (0.075, 0.0), (0.078, 0.008), (0.06, 0.018), (0.03, 0.03), (0.02, 0.05), (0.024, 0.06),
             (0.014, 0.075), (0.012, 0.16), (0.02, 0.17), (0.014, 0.18), (0.0, 0.182)], (0, 0, 0), segs=24)
    tops = [Vector((0, 0, 0.27))]
    for side in (-1, 1):
        arm = k.part("Arm", "brass", bevel=0.0)
        pts = [Vector((0, 0, 0.17)), Vector((side * 0.05, 0, 0.165)), Vector((side * 0.1, 0, 0.18)), Vector((side * 0.12, 0, 0.21)),
               Vector((side * 0.12, 0, 0.225))]
        arm.tube(pts, 0.0065, segs=8, smooth=2, round_ends=True)
        tops.append(Vector((side * 0.12, 0, 0.225)))
        # kleine Schnecke unter dem Arm
        curl = [Vector((side * (0.045 + 0.018 * math.cos(t)), 0, 0.15 + 0.018 * math.sin(t))) for t in [i * 0.5 for i in range(11)]]
        arm.tube(curl, 0.0035, segs=6, smooth=1, round_ends=True)
    center = k.part("Mittelstange", "brass", bevel=0.0)
    center.tube([(0, 0, 0.17), (0, 0, 0.27)], 0.009, segs=10)
    for t in tops:
        cup = k.part("Tülle", "brass", bevel=0.0)
        cup.lathe([(0.0, 0.0), (0.01, 0.0), (0.03, 0.006), (0.032, 0.01), (0.016, 0.012), (0.016, 0.03), (0.0, 0.03)], t, segs=18)
        F.candle(k, "wax", t + Vector((0, 0, 0.026)), 0.16 if t.z > 0.25 else 0.14, 0.0125, drips=4)
    k.light_kind = "flame"
    k.shadow = "none"
    k.light((0, 0, 0.47), energy=0.38, rng=2.3, shadow=False)
    k.collider((0, 0, 0.12), (0.16, 0.16, 0.24))
    k.interact = (Vector((0, 0, 0.27)), Vector((0.3, 0.12, 0.5)))


# --- Farn im Messingtopf ---

def build_fern_urn(k):
    brass(k)
    k.mat("pot", BRASS, grain="smooth", rough=0.36, metal=0.65, vary=0.07, scale=5.0)
    soil, rim = F.pot(k, (0, 0, 0), 0.15, 0.34, style="urn", slot="pot")
    p = k.plant()
    F.lush_fern(p, 1.25, fronds=22)
    k.add_plant(p, soil, scale=rim / 0.2)
    k.collider((0, 0, 0.17), (0.33, 0.33, 0.34))


ITEMS = [
    dict(id="armchair_velvet", name="Chesterfield-Ohrensessel", category="seating", sub="armchair", price=190,
         desc="Tiefer Ledersessel mit Knöpfen, Ohren und Messingnägeln – zum Versinken mit einem dicken Buch.",
         styles=STYLE, place="floor", lean=True, adopt=True, build=build_wingchair,
         variants=[("cognac", "Cognac", {"leather": COGNAC}), ("bordeaux", "Bordeaux", {"leather": BORDEAUX}),
                   ("bottle", "Flaschengrün", {"leather": BOTTLE}), ("navy", "Nachtblau", {"leather": NAVY}),
                   ("chocolate", "Schokolade", {"leather": CHOCOLATE})]),
    dict(id="bookshelf_oak", name="Bibliotheksregal", category="shelf", sub="bookshelf", price=230,
         desc="Hohes Regal aus dunklem Holz mit Kranz, Zahnschnitt, Pilastern und Messingschildern. Fünf Fächer.",
         styles=STYLE, place="floor", adopt=True, build=build_library_shelf, variants=wood_variants()),
    dict(id="lamp_banker", name="Bankerlampe", category="lighting", sub="table_lamp", price=75,
         desc="Messingfuß und grüner Glasschirm – warmes Licht zum Lesen und Schreiben.",
         styles=STYLE, place=["surface", "floor"], build=build_banker_lamp,
         variants=[("green", "Flaschengrün", {"glass_shade": BOTTLE}), ("amber", "Bernstein", {"glass_shade": (0.62, 0.38, 0.12)}),
                   ("oxblood", "Ochsenblut", {"glass_shade": (0.45, 0.1, 0.1)}), ("navy", "Nachtblau", {"glass_shade": (0.14, 0.2, 0.42)})]),
    dict(id="candelabra", name="Kerzenleuchter mit drei Armen", category="lighting", sub="candle", price=55,
         desc="Messingleuchter mit geschwungenen Armen und tropfenden Kerzen.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_candelabra,
         variants=[("ivory", "Messing · Elfenbein", {"brass": BRASS, "wax": IVORY}),
                   ("bordeaux", "Messing · Bordeaux", {"brass": BRASS, "wax": (0.52, 0.14, 0.16)}),
                   ("silver", "Silber · Elfenbein", {"brass": (0.74, 0.74, 0.72), "wax": IVORY}),
                   ("bronze", "Bronze · Honig", {"brass": (0.55, 0.38, 0.22), "wax": (0.9, 0.72, 0.42)})]),
    dict(id="plant_fern_urn", name="Farn im Messingtopf", category="deco", sub="plant", price=60,
         desc="Ein üppiger Farn in einer Messing-Urne mit Fuß.",
         styles=STYLE, place="floor", lean=True, build=build_fern_urn,
         variants=[("brass", "Messing", {"pot": BRASS}), ("copper", "Kupfer", {"pot": (0.72, 0.42, 0.26)}),
                   ("verdigris", "Grünspan", {"pot": (0.38, 0.56, 0.48)}), ("iron", "Gusseisen", {"pot": (0.17, 0.16, 0.15)})]),
]
