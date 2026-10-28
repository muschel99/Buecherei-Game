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
    F.lush_fern(p, 1.3, fronds=36)
    k.add_plant(p, soil, scale=rim / 0.2)
    k.collider((0, 0, 0.17), (0.33, 0.33, 0.34))


# --- Niedriges Bücherregal mit Messinggalerie ---

def build_low_shelf(k):
    wood(k)
    brass(k)
    W, D, H = 1.4, 0.36, 0.98
    feet = k.part("Füße", "wood", bevel=0.004)
    for x in (-0.64, 0.64):
        for y in (-0.13, 0.13):
            F.turned_leg(feet, (x, y, 0.0), 0.07, 0.03, style="bun")
    c = k.part("Korpus", "wood", bevel=0.005)
    for side in (-1, 1):
        c.box((side * 0.68, 0, 0.53), (0.04, D, 0.92), step=0.3, dent=0.001)
    c.box((0, 0.165, 0.53), (1.33, 0.018, 0.9), step=0.3, dent=0.001)
    c.box((0, 0, 0.085), (1.36, D - 0.01, 0.03), step=0.3, dent=0.001)
    c.box((0, -0.002, 0.53), (1.33, D - 0.04, 0.03), step=0.3, dent=0.001)
    top = k.part("Deckplatte", "wood", bevel=0.006)
    top.box((0, -0.005, 0.985), (1.44, D + 0.03, 0.035), step=0.3, dent=0.001)
    top.box((0, -0.005, 0.958), (1.4, D + 0.015, 0.02), step=0.3, dent=0.001)
    apron = k.part("Zierleiste", "wood", bevel=0.003)
    apron.box((0, -0.185, 0.115), (1.32, 0.02, 0.05), step=0.3, dent=0.0008)
    for x in (-0.33, 0.33):
        F.button(apron, (x, -0.197, 0.115), r=0.014, normal=(0, -1, 0))
    gal = k.part("Messinggalerie", "brass", bevel=0.0)
    gal.tube([(-0.68, 0.17, 1.13), (0.68, 0.17, 1.13)], 0.007, segs=8, round_ends=True)
    x = -0.68
    while x <= 0.681:
        gal.tube([(x, 0.17, 1.0), (x, 0.17, 1.13)], 0.0045, segs=6)
        gal.blob((x, 0.17, 1.13), 0.009, subdiv=1, lump=0.02)
        x += 0.17
    for t, h in ((0.1, 0.4), (0.545, 0.39)):
        k.row((0, -0.01, t), 1.3, h, 0.32)
    for side in (-1, 1):
        k.collider((side * 0.68, 0, 0.53), (0.045, D, 0.94))
    k.collider((0, 0.165, 0.53), (1.33, 0.02, 0.9))
    k.collider((0, 0, 0.05), (1.4, D, 0.1))
    k.collider((0, -0.002, 0.53), (1.33, D - 0.04, 0.03))
    k.collider((0, -0.005, 0.97), (1.44, D + 0.03, 0.035))
    k.surface((0, -0.01, 1.0025), (1.4, D))


# --- Chesterfield-Sofa ---

def build_chesterfield_sofa(k):
    wood(k)
    leather(k)
    brass(k)
    feet = k.part("Füße", "wood", bevel=0.004)
    for x in (-0.85, 0.85):
        for y in (-0.33, 0.33):
            F.turned_leg(feet, (x, y, 0.0), 0.08, 0.034, style="bun")
    base = k.part("Polster", "leather", bevel=0.0)
    F.pillow(base, (0, 0.0, 0.215), (1.84, 0.82, 0.27), roundness=5.0, puff=0.004, step=0.045)
    F.piping(base, (0, 0.0, 0.215), (1.84, 0.82, 0.27), -0.095, r=0.0065, roundness=5.0)
    back = k.part("Rückenlehne", "leather", bevel=0.0)
    F.pillow(back, (0, 0.32, 0.56), (1.6, 0.2, 0.44), roundness=5.0, puff=0.012, step=0.04)
    buttons = k.part("Knöpfe", "leather", bevel=0.0)
    for row, zz in enumerate((0.47, 0.57, 0.67)):
        n = 9 if row % 2 == 0 else 8
        for i in range(n):
            xx = -0.64 + i * 0.16 + (0.08 if row % 2 else 0.0)
            F.button(buttons, (xx, 0.218, zz), r=0.011, normal=(0, -1, 0))
    for side in (-1, 1):
        arm = k.part("Armlehne", "leather", bevel=0.0)
        F.pillow(arm, (side * 0.84, 0.0, 0.47), (0.18, 0.82, 0.44), roundness=5.0, puff=0.006, step=0.04)
        # Rolle oben außen über die ganze Tiefe
        arm.tube([(side * 0.86, -0.41, 0.69), (side * 0.86, 0.41, 0.69)], 0.075, segs=16, round_ends=True)
        for row, zz in enumerate((0.43, 0.55)):
            for i in range(4):
                F.button(buttons, (side * 0.748, -0.27 + i * 0.18 + (0.09 if row else 0.0), zz), r=0.01, normal=(-side, 0, 0))
        nails = k.part("Ziernägel", "brass", bevel=0.0)
        for i in range(11):
            a = math.radians(-90 + i * 18)
            nails.blob((side * 0.86 + math.sin(a) * 0.079, -0.415, 0.69 + math.cos(a) * 0.079), 0.0055, subdiv=1, lump=0.04, scale=(1, 0.6, 1))
    for i, xx in enumerate((-0.52, 0.0, 0.52)):
        cush = k.part("Sitzkissen", "leather", bevel=0.0)
        F.pillow(cush, (xx, -0.06, 0.41), (0.52, 0.62, 0.13), roundness=4.0, puff=0.018, step=0.032)
        for zz in (0.04, -0.04):
            F.piping(cush, (xx, -0.06, 0.41), (0.52, 0.62, 0.13), zz, r=0.005, roundness=4.0)
    nails = k.part("Ziernägel Sockel", "brass", bevel=0.0)
    x = -0.86
    while x <= 0.861:
        nails.blob((x, -0.412, 0.12), 0.0055, subdiv=1, lump=0.04, scale=(1, 0.6, 1))
        x += 0.036
    k.collider((0, 0, 0.175), (1.88, 0.84, 0.35))
    k.collider((0, -0.06, 0.24), (1.56, 0.62, 0.475))
    k.collider((0, 0.32, 0.6), (1.6, 0.2, 0.5))
    for side in (-1, 1):
        k.collider((side * 0.85, 0, 0.38), (0.2, 0.84, 0.76))
    k.surface((0, -0.07, 0.475), (1.5, 0.5))
    for side in (-1, 1):
        k.surface((side * 0.86, -0.02, 0.765), (0.1, 0.7))
    for xx in (-0.52, 0.0, 0.52):
        k.seat((xx, -0.06, 0.475))
    k.interact = (Vector((0, -0.04, 0.6)), Vector((1.6, 0.62, 0.5)))


# --- Schreibtisch mit Lederauflage ---

def build_partners_desk(k):
    wood(k)
    leather(k, BOTTLE)
    brass(k)
    W, D, H = 1.4, 0.72, 0.76
    feet = k.part("Füße", "wood", bevel=0.004)
    for x in (-0.64, -0.26, 0.26, 0.64):
        for y in (-0.3, 0.3):
            F.turned_leg(feet, (x, y, 0.0), 0.06, 0.03, style="bun")
    ped = k.part("Unterschränke", "wood", bevel=0.005)
    for xc in (-0.45, 0.45):
        ped.box((xc, 0.0, 0.37), (0.44, D - 0.06, 0.62), step=0.3, dent=0.001)
        ped.box((xc, -0.005, 0.07), (0.47, D - 0.04, 0.03), step=0.3, dent=0.001)
    fronts = k.part("Schubladen", "wood", bevel=0.004)
    handles = k.part("Griffe", "brass", bevel=0.0)
    for xc in (-0.45, 0.45):
        for zc in (0.18, 0.37, 0.56):
            fronts.box((xc, -0.326, zc), (0.38, 0.02, 0.17), step=0.3, dent=0.0008)
            fronts.box((xc, -0.338, zc), (0.31, 0.008, 0.11), step=0.3, dent=0.0006)
            F.bar_handle(handles, (xc, -0.343, zc + 0.02), 0.08, r=0.0045, depth=0.02)
            handles.box((xc, -0.343, zc + 0.05), (0.04, 0.003, 0.016), step=0.5, dent=0.0)
    mid = k.part("Mittelschublade", "wood", bevel=0.004)
    mid.box((0, 0.0, 0.66), (0.46, D - 0.06, 0.1), step=0.3, dent=0.001)
    mid.box((0, -0.326, 0.665), (0.42, 0.02, 0.08), step=0.3, dent=0.0008)
    F.knob(handles, (0, -0.337, 0.665), r=0.011)
    top = k.part("Platte", "wood", bevel=0.007)
    top.box((0, -0.005, 0.735), (W, D, 0.045), step=0.3, dent=0.001)
    inlay = k.part("Lederauflage", "leather", bevel=0.002)
    inlay.box((0, -0.01, 0.7585), (W - 0.16, D - 0.16, 0.006), step=0.2, dent=0.0)
    gold = k.part("Goldprägung", "brass", bevel=0.0)
    hw, hd = (W - 0.2) / 2, (D - 0.2) / 2
    gold.tube([(-hw, -hd - 0.01, 0.762), (hw, -hd - 0.01, 0.762), (hw, hd - 0.01, 0.762), (-hw, hd - 0.01, 0.762), (-hw, -hd - 0.01, 0.762)],
              0.0018, segs=4)
    for xc in (-0.45, 0.45):
        k.collider((xc, 0, 0.36), (0.47, D - 0.04, 0.72))
    k.collider((0, -0.005, 0.7375), (W, D, 0.045))
    k.collider((0, 0, 0.66), (0.46, D - 0.06, 0.1))
    k.surface((0, -0.005, 0.76), (W - 0.04, D - 0.04))


# --- Schreibtischstuhl ---

def build_desk_chair(k):
    wood(k)
    leather(k, BOTTLE)
    brass(k)
    legs = k.part("Beine", "wood", bevel=0.0)
    for x in (-0.2, 0.2):
        for y in (-0.19, 0.17):
            F.turned_leg(legs, (x, y, 0.0), 0.43, 0.022, style="spindle", segs=12)
    rails = k.part("Streben", "wood", bevel=0.0)
    for y in (-0.19, 0.17):
        rails.tube([(-0.2, y, 0.16), (0.2, y, 0.16)], 0.011, segs=8)
    for x in (-0.2, 0.2):
        rails.tube([(x, -0.19, 0.12), (x, 0.17, 0.12)], 0.011, segs=8)
    frame = k.part("Sitzrahmen", "wood", bevel=0.005)
    F.pillow(frame, (0, -0.01, 0.435), (0.5, 0.46, 0.04), roundness=3.0, step=0.04)
    seat = k.part("Sitzpolster", "leather", bevel=0.0)
    F.pillow(seat, (0, -0.015, 0.47), (0.44, 0.4, 0.06), roundness=2.8, puff=0.014, step=0.03)
    nails = k.part("Ziernägel", "brass", bevel=0.0)
    for i in range(28):
        a = 2 * math.pi * i / 28
        cs, sn = math.cos(a), math.sin(a)
        rr = (abs(cs) ** 2.8 + abs(sn) ** 2.8) ** (-1 / 2.8)
        nails.blob((cs * rr * 0.222, -0.015 + sn * rr * 0.202, 0.458), 0.0045, subdiv=1, lump=0.03, scale=(1, 1, 0.6))
    back = k.part("Lehne", "wood", bevel=0.0)
    arc = [Vector((math.cos(math.radians(a)) * 0.25, 0.04 + math.sin(math.radians(a)) * 0.2, 0.73)) for a in range(200, 341, 10)]
    back.tube(arc, 0.022, segs=10, smooth=1, round_ends=True)
    for a in (205, 230, 255, 270, 285, 310, 335):
        x = math.cos(math.radians(a)) * 0.25
        y = 0.04 + math.sin(math.radians(a)) * 0.2
        back.tube([(x * 0.92, y * 0.92 + 0.004, 0.47), (x, y, 0.72)], 0.0085, segs=7)
    for side in (-1, 1):
        back.tube([(side * 0.235, -0.04, 0.47), (side * 0.235, -0.1, 0.62), (side * 0.235, -0.0, 0.7)], 0.014, segs=8, smooth=2, round_ends=True)
    k.collider((0, -0.01, 0.235), (0.5, 0.46, 0.5))
    k.collider((0, 0.08, 0.62), (0.52, 0.16, 0.26))
    k.surface((0, -0.03, 0.5), (0.38, 0.32))
    k.seat((0, -0.03, 0.5))
    k.interact = (Vector((0, -0.02, 0.55)), Vector((0.5, 0.46, 0.45)))


# --- Weintisch ---

def build_wine_table(k):
    wood(k)
    b = k.part("Platte", "wood", bevel=0.006)
    b.lathe([(0.0, 0.0), (0.25, 0.0), (0.262, 0.012), (0.258, 0.026), (0.24, 0.032), (0.0, 0.032)], (0, 0, 0.6), segs=40, dent=0.0008)
    stem = k.part("Säule", "wood", bevel=0.0)
    stem.lathe([(0.0, 0.0), (0.06, 0.0), (0.045, 0.04), (0.03, 0.08), (0.05, 0.16), (0.038, 0.26), (0.025, 0.36), (0.04, 0.42),
                (0.028, 0.46), (0.05, 0.49), (0.0, 0.5)], (0, 0, 0.1), segs=18)
    legs = k.part("Dreibein", "wood", bevel=0.0)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        out = Vector((math.cos(a), math.sin(a), 0))
        F.curved_leg(legs, out * 0.03 + Vector((0, 0, 0.16)), out * 0.24 + Vector((0, 0, 0.012)), 0.022, 0.012, bow=0.05, outward=(0, 0, 0.6))
    k.collider((0, 0, 0.616), (0.5, 0.5, 0.032))
    k.collider((0, 0, 0.3), (0.12, 0.12, 0.6))
    k.surface((0, 0, 0.632), (0.42, 0.42))


# --- Zettelkatalog ---

def build_card_catalog(k):
    wood(k)
    brass(k)
    k.mat("paper", (0.93, 0.89, 0.78), grain="paint", rough=0.85, vary=0.04)
    stand = k.part("Gestell", "wood", bevel=0.0)
    for x in (-0.3, 0.3):
        for y in (-0.17, 0.17):
            F.turned_leg(stand, (x, y, 0.0), 0.42, 0.022, style="taper", segs=12, flip=True)
    stand.box((0, 0, 0.43), (0.68, 0.42, 0.03), step=0.3, dent=0.0008)
    body = k.part("Kasten", "wood", bevel=0.005)
    body.box((0, 0, 0.8), (0.7, 0.44, 0.72), step=0.3, dent=0.001)
    body.box((0, -0.004, 1.175), (0.74, 0.47, 0.03), step=0.3, dent=0.001)
    drawers = k.part("Schübe", "wood", bevel=0.003)
    hw = k.part("Beschläge", "brass", bevel=0.0)
    labels = k.part("Kärtchen", "paper", bevel=0.0)
    for col in range(4):
        for row in range(6):
            x = -0.255 + col * 0.17
            z = 0.5 + row * 0.11
            drawers.box((x, -0.222, z), (0.155, 0.012, 0.095), step=0.3, dent=0.0006)
            hw.box((x, -0.23, z + 0.02), (0.06, 0.004, 0.026), step=0.5, dent=0.0)
            labels.box((x, -0.2315, z + 0.02), (0.05, 0.002, 0.018), step=0.5, dent=0.0)
            F.knob(hw, (x, -0.229, z - 0.018), r=0.008)
    k.collider((0, 0, 0.6), (0.74, 0.47, 1.2))
    k.surface((0, -0.004, 1.19), (0.72, 0.45))


# --- Paravent ---

def build_screen(k):
    wood(k)
    k.mat("fabric", BORDEAUX, grain="fabric", rough=0.92, vary=0.08, bump=0.3)
    brass(k)
    panels = [(-0.52, 18), (0.0, 0), (0.52, -18)]
    for xc, turn in panels:
        m = Matrix.Translation((xc, -0.05 if xc else 0.03, 0)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
        fr = k.part("Rahmen", "wood", bevel=0.004)
        fr.box((0, 0, 0.04), (0.5, 0.04, 0.08), step=0.3, dent=0.0008, matrix=m)
        for x in (-0.23, 0.23):
            fr.box((x, 0, 0.84), (0.04, 0.04, 1.68), step=0.3, dent=0.0008, matrix=m)
        # Bogen oben
        arc = [m @ Vector((math.cos(math.radians(a)) * 0.23, 0, 1.6 + math.sin(math.radians(a)) * 0.12)) for a in range(0, 181, 12)]
        fr.tube(arc, 0.022, segs=8, round_ends=True)
        fr.box((0, 0, 0.58), (0.44, 0.03, 0.03), step=0.3, dent=0.0006, matrix=m)
        cloth = k.part("Bespannung", "fabric", bevel=0.0)
        cloth.box((0, 0, 1.09), (0.43, 0.012, 0.98), step=0.08, dent=0.0015, matrix=m)
        cloth.box((0, 0, 0.33), (0.43, 0.012, 0.46), step=0.08, dent=0.0015, matrix=m)
        btn = k.part("Knöpfe", "fabric", bevel=0.0)
        for zz in (0.85, 1.1, 1.35):
            F.button(btn, m @ Vector((0, -0.008, zz)), r=0.012, normal=m.to_3x3() @ Vector((0, -1, 0)))
            F.button(btn, m @ Vector((0, 0.008, zz)), r=0.012, normal=m.to_3x3() @ Vector((0, 1, 0)))
        top = k.part("Knauf", "brass", bevel=0.0)
        top.blob(m @ Vector((0, 0, 1.735)), 0.018, subdiv=1, lump=0.02)
    for xc, turn in panels:
        k.collider((xc, -0.05 if xc else 0.03, 0.86), (0.5, 0.06, 1.72), turn=turn)


# --- Messing-Stehlampe mit Faltenschirm ---

def build_floor_lamp(k):
    brass(k)
    k.mat("shade", (0.93, 0.86, 0.7), grain="fabric", rough=0.9, vary=0.05, emit=1.2, emit_color=(1.0, 0.82, 0.55))
    base = k.part("Fuß", "brass", bevel=0.0)
    base.lathe([(0.0, 0.0), (0.16, 0.0), (0.165, 0.012), (0.14, 0.03), (0.06, 0.045), (0.03, 0.07), (0.0, 0.075)], (0, 0, 0), segs=36)
    pole = k.part("Stange", "brass", bevel=0.0)
    pole.lathe([(0.0, 0.0), (0.016, 0.0), (0.013, 0.3), (0.022, 0.32), (0.013, 0.34), (0.012, 0.8), (0.02, 0.82), (0.012, 0.84),
                (0.011, 1.38), (0.016, 1.4), (0.0, 1.41)], (0, 0, 0.07), segs=14)
    harp = k.part("Schirmträger", "brass", bevel=0.0)
    for a in (0, 120, 240):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        harp.tube([Vector((0, 0, 1.47)), d * 0.12 + Vector((0, 0, 1.49))], 0.003, segs=5)
    harp.blob((0, 0, 1.6), 0.012, subdiv=1, lump=0.02)
    harp.tube([(0, 0, 1.46), (0, 0, 1.6)], 0.0035, segs=6)
    sh = k.part("Schirm", "shade", bevel=0.0)
    F.shade(sh, (0, 0, 1.36), 0.24, 0.13, 0.27, kind="pleat", segs=56, wall=0.004)
    trim = k.part("Borte", "brass", bevel=0.0)
    F.ring(trim, (0, 0, 1.362), 0.243, 0.004, n=56)
    bulb = k.part("Glühbirne", "shade", bevel=0.0)
    bulb.blob((0, 0, 1.43), 0.03, subdiv=2, lump=0.02, scale=(1, 1, 1.2))
    k.light_kind = "electric"
    k.shadow = "important"
    k.light((0, 0, 1.47), energy=1.6, rng=6.0)
    k.collider((0, 0, 0.8), (0.32, 0.32, 1.6))


# --- Kronleuchter ---

def build_chandelier(k):
    brass(k)
    k.mat("wax", IVORY, grain="smooth", rough=0.55, vary=0.04)
    k.mat("bulb", (1.0, 0.86, 0.6), grain="smooth", rough=0.3, vary=0.02, emit=5.0, emit_color=(1.0, 0.78, 0.5))
    top = k.part("Baldachin", "brass", bevel=0.0)
    top.lathe([(0.0, 0.0), (0.075, 0.0), (0.07, -0.02), (0.04, -0.035), (0.0, -0.04)], (0, 0, 0), segs=24)
    chain = k.part("Kette", "brass", bevel=0.0)
    for i in range(9):
        z = -0.05 - i * 0.032
        rot = Matrix.Rotation(math.radians(90 * (i % 2)), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X")
        F.ring(chain, (0, 0, z), 0.012, 0.0025, matrix=rot, n=12, segs=5)
    body = k.part("Körper", "brass", bevel=0.0)
    body.lathe([(0.0, 0.0), (0.02, 0.0), (0.03, -0.04), (0.018, -0.08), (0.05, -0.12), (0.06, -0.15), (0.035, -0.19),
                (0.02, -0.24), (0.035, -0.27), (0.0, -0.29)], (0, 0, -0.33), segs=24)
    for i in range(6):
        a = math.radians(60 * i + 30)
        d = Vector((math.cos(a), math.sin(a), 0))
        arm = k.part("Arm", "brass", bevel=0.0)
        pts = [d * 0.05 + Vector((0, 0, -0.47)), d * 0.16 + Vector((0, 0, -0.52)), d * 0.27 + Vector((0, 0, -0.5)),
               d * 0.32 + Vector((0, 0, -0.45)), d * 0.32 + Vector((0, 0, -0.42))]
        arm.tube(pts, 0.007, segs=8, smooth=2, round_ends=True)
        cup = d * 0.32 + Vector((0, 0, -0.42))
        arm.lathe([(0.0, 0.0), (0.012, 0.0), (0.034, 0.008), (0.036, 0.012), (0.016, 0.014), (0.016, 0.03), (0.0, 0.03)], cup, segs=16)
        sleeve = k.part("Kerzenhülse", "wax", bevel=0.0)
        sleeve.lathe([(0.0, 0.0), (0.012, 0.0), (0.012, 0.09), (0.0, 0.09)], cup + Vector((0, 0, 0.028)), segs=12)
        bulb = k.part("Kerzenbirne", "bulb", bevel=0.0)
        bulb.lathe([(0.0, 0.0), (0.008, 0.0), (0.011, 0.012), (0.008, 0.026), (0.0, 0.034)], cup + Vector((0, 0, 0.118)), segs=10)
    k.light_kind = "electric"
    k.shadow = "none"
    k.light((0, 0, -0.42), energy=1.9, rng=7.5, shadow=False)
    k.collider((0, 0, -0.38), (0.72, 0.72, 0.36))
    k.interact = (Vector((0, 0, -0.38)), Vector((0.75, 0.75, 0.42)))


# --- Messing-Wandleuchte ---

def build_wall_lamp(k):
    brass(k)
    k.mat("glass_shade", (0.95, 0.9, 0.78), grain="smooth", rough=0.3, vary=0.03, emit=1.6, emit_color=(1.0, 0.82, 0.55))
    plate = k.part("Wandplatte", "brass", bevel=0.003)
    plate.lathe([(0.0, 0.0), (0.05, 0.0), (0.052, 0.008), (0.035, 0.016), (0.0, 0.018)], (0, -0.0, 0.0), segs=24, turn=(90, 0))
    arm = k.part("Arm", "brass", bevel=0.0)
    pts = [Vector((0, -0.012, 0.0)), Vector((0, -0.08, -0.03)), Vector((0, -0.16, 0.0)), Vector((0, -0.18, 0.06))]
    arm.tube(pts, 0.008, segs=8, smooth=2, round_ends=True)
    curl = [Vector((0, -0.06 - 0.025 * math.sin(t), -0.04 - 0.025 * math.cos(t))) for t in [i * 0.55 for i in range(11)]]
    arm.tube(curl, 0.004, segs=6, smooth=1, round_ends=True)
    arm.lathe([(0.0, 0.0), (0.015, 0.0), (0.03, 0.01), (0.03, 0.016), (0.0, 0.018)], (0, -0.18, 0.06), segs=16)
    glass = k.part("Tulpenglas", "glass_shade", bevel=0.0)
    glass.lathe([(0.012, 0.0), (0.03, 0.008), (0.055, 0.05), (0.07, 0.11), (0.074, 0.13), (0.07, 0.13), (0.052, 0.06), (0.026, 0.012),
                 (0.01, 0.006)], (0, -0.18, 0.075), segs=24, wave=0.03, waves=8)
    k.light_kind = "electric"
    k.shadow = "none"
    k.light((0, -0.18, 0.14), energy=0.8, rng=4.0, shadow=False)
    k.collider((0, -0.1, 0.06), (0.16, 0.2, 0.22))


# --- Globen ---

SEA = (0.22, 0.36, 0.5)
LAND = (0.8, 0.66, 0.4)


def _globe(k, center, r, axis_tilt=23.0, seed=0):
    """Globus: Meer (globe_sea, einfärbbar), Kontinente als flache Flicken (globe_land), Meridian
    aus Messing mit Achsstiften. Liefert die Drehmatrix der Achse."""
    k.mat("globe_sea", SEA, grain="paint", rough=0.55, vary=0.08, scale=3.0)
    k.mat("globe_land", LAND, grain="paint", rough=0.7, vary=0.1, scale=6.0)
    c = Vector(center)
    tilt = Matrix.Rotation(math.radians(axis_tilt), 4, "Y")
    ball = k.part("Globus", "globe_sea", bevel=0.0, vary=0.02)
    F.sphere(ball, c, r, segs=36, rings=18)
    land = k.part("Kontinente", "globe_land", bevel=0.0, vary=0.06)
    rnd = random.Random(k.seed + seed)
    # grobe Lage der Kontinente (Breite, Länge in Grad, Größe)
    for lat, lon, size in ((48, -100, 0.55), (-15, -60, 0.45), (50, 20, 0.4), (5, 20, 0.5), (55, 90, 0.6), (-25, 135, 0.35),
                           (75, -40, 0.25), (20, 78, 0.28)):
        la, lo = math.radians(lat), math.radians(lon)
        d = Vector((math.cos(la) * math.cos(lo), math.cos(la) * math.sin(lo), math.sin(la)))
        d = (tilt.to_3x3() @ d).normalized()
        F.patch(land, c + d * r * 0.995, d, r * size * 0.42, r * 0.025, rnd, wobble=0.45, segs=20)
    meridian = k.part("Meridian", "brass", bevel=0.0)
    ring_m = tilt @ Matrix.Rotation(math.radians(90), 4, "X")
    pts = [c + ring_m.to_3x3() @ Vector((math.cos(math.radians(a)) * r * 1.08, math.sin(math.radians(a)) * r * 1.08, 0)) for a in range(-100, 101, 8)]
    meridian.tube(pts, r * 0.03, segs=6, round_ends=True)
    axis = tilt.to_3x3() @ Vector((0, 0, 1))
    for sg in (-1, 1):
        meridian.tube([c + axis * r * 0.98 * sg, c + axis * r * 1.12 * sg], r * 0.022, segs=6, round_ends=True)
    return tilt


def build_globe_floor(k):
    wood(k)
    brass(k)
    _globe(k, (0, 0, 0.66), 0.24)
    stand = k.part("Gestell", "wood", bevel=0.0)
    F.ring(stand, (0, 0, 0.64), 0.3, 0.014, n=56, segs=8)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        out = Vector((math.cos(a), math.sin(a), 0))
        F.curved_leg(stand, out * 0.3 + Vector((0, 0, 0.64)), out * 0.27 + Vector((0, 0, 0.015)), 0.02, 0.016, bow=0.06,
                     outward=(out.x, out.y, 0.0))
        stand.blob(out * 0.278 + Vector((0, 0, 0.018)), 0.025, subdiv=1, lump=0.05, scale=(1, 1, 0.7))
    F.ring(stand, (0, 0, 0.2), 0.205, 0.011, n=48, segs=8)
    stand.tube([(0, 0, 0.2), (0, 0, 0.42)], 0.018, segs=10)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        out = Vector((math.cos(a), math.sin(a), 0))
        stand.tube([out * 0.205 + Vector((0, 0, 0.2)), Vector((0, 0, 0.2))], 0.009, segs=6)
    k.collider((0, 0, 0.47), (0.62, 0.62, 0.94))


def build_globe_small(k):
    wood(k)
    brass(k)
    base = k.part("Fuß", "wood", bevel=0.0)
    base.lathe([(0.0, 0.0), (0.075, 0.0), (0.078, 0.012), (0.05, 0.022), (0.022, 0.03), (0.016, 0.05), (0.0, 0.05)], (0, 0, 0), segs=28)
    stem = k.part("Stiel", "brass", bevel=0.0)
    stem.tube([(0, 0, 0.045), (0, 0, 0.08)], 0.008, segs=8)
    _globe(k, (0, 0, 0.18), 0.095)
    stem.tube([(0, 0, 0.075), (-0.035, 0, 0.088)], 0.0045, segs=6, round_ends=True)
    k.collider((0, 0, 0.14), (0.2, 0.2, 0.28))


# --- Büste auf Bücherstapel ---

def build_bust(k):
    k.mat("plaster", (0.93, 0.91, 0.86), grain="stone", rough=0.8, vary=0.05, bump=0.15)
    k.mat("cover", (1, 1, 1), grain="paint", rough=0.7, vary=0.0, bump=0.05)
    k.mat("pages", (0.93, 0.88, 0.76), grain="paint", rough=0.85, vary=0.04)
    cover = k.part("Buchdeckel", "cover", bevel=0.0015, vary=0.0)
    pages = k.part("Buchseiten", "pages", bevel=0.0008)
    z = 0.0
    for i, (w, d, t, col, turn) in enumerate(((0.24, 0.17, 0.04, BORDEAUX, 4), (0.22, 0.155, 0.032, BOTTLE, -6), (0.2, 0.14, 0.035, NAVY, 2))):
        m = Matrix.Translation((0, 0, z)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
        cover.box((0, 0, t / 2), (w, d, t), step=0.5, dent=0.0008, tint=F.lin(col), matrix=m)
        pages.box((0.004, 0.0, t / 2), (w - 0.012, d - 0.01, t * 0.84), step=0.5, dent=0.0, matrix=m)
        z += t
    b = k.part("Büste", "plaster", bevel=0.0, vary=0.02)
    b.lathe([(0.0, 0.0), (0.06, 0.0), (0.062, 0.012), (0.045, 0.02), (0.035, 0.035), (0.05, 0.045), (0.0, 0.05)], (0, 0, z), segs=24)
    base = z + 0.048
    F.pillow(b, (0, 0.0, base + 0.06), (0.2, 0.11, 0.13), roundness=2.6, step=0.02)
    b.tube([(0, 0, base + 0.1), (0, -0.004, base + 0.17)], 0.027, segs=12)
    head = Vector((0, -0.006, base + 0.215))
    b.blob(head, 0.06, subdiv=3, lump=0.03, scale=(0.82, 0.92, 1.05))
    b.blob(head + Vector((0, -0.057, -0.004)), 0.011, subdiv=1, lump=0.02, scale=(0.7, 1.0, 1.3))
    b.blob(head + Vector((0, -0.048, -0.034)), 0.016, subdiv=1, lump=0.02, scale=(1.0, 0.8, 0.6))
    rnd = random.Random(k.seed)
    for i in range(16):
        a = rnd.uniform(-2.4, 2.4)
        el = rnd.uniform(0.15, 1.2)
        d = Vector((math.sin(a) * math.cos(el), math.cos(a) * math.cos(el) * 0.9 + 0.1, math.sin(el)))
        b.blob(head + Vector((d.x * 0.048, d.y * 0.054, d.z * 0.058)), 0.017, subdiv=1, lump=0.15)
    k.collider((0, 0, (base + 0.28) / 2), (0.24, 0.17, base + 0.28))


# --- Schreibset ---

def build_writing_set(k):
    wood(k)
    brass(k)
    k.mat("ink_glass", (0.16, 0.18, 0.24), grain="smooth", rough=0.2, vary=0.03)
    k.mat("paper", (0.94, 0.9, 0.78), grain="paint", rough=0.85, vary=0.05)
    k.mat("feather", (0.95, 0.93, 0.88), grain="leaf", rough=0.7, vary=0.05)
    k.mat("wax_red", (0.62, 0.1, 0.12), grain="smooth", rough=0.45, vary=0.05)
    tray = k.part("Tablett", "wood", bevel=0.004)
    F.pillow(tray, (0, 0, 0.012), (0.38, 0.22, 0.024), roundness=4.0, step=0.025)
    tray.box((0, 0.1, 0.03), (0.36, 0.012, 0.02), step=0.3, dent=0.0004)
    bottle = k.part("Tintenfass", "ink_glass", bevel=0.0)
    bottle.lathe([(0.0, 0.0), (0.032, 0.0), (0.034, 0.008), (0.034, 0.04), (0.02, 0.05), (0.014, 0.052), (0.014, 0.062), (0.0, 0.062)],
                 (-0.1, 0.02, 0.024), segs=20)
    cap = k.part("Deckel", "brass", bevel=0.0)
    F.ring(cap, (-0.1, 0.02, 0.087), 0.0155, 0.004, n=16)
    quill = k.part("Federkiel", "feather", bevel=0.0)
    base = Vector((-0.095, 0.025, 0.07))
    d = Vector((0.35, 0.25, 1.0)).normalized()
    quill.tube([base, base + d * 0.23], lambda t: 0.003 * (1 - 0.6 * t), segs=6, round_ends=True)
    for sg in (-1, 1):
        side = d.cross(Vector((0, 0, 1))).normalized() * sg
        quill.leaf(base + d * 0.06, (d + side * 0.12).normalized(), side.cross(d).normalized() * sg, 0.17, 0.028,
                   shape="narrow", thick=0.0025, curl=0.1, segs=7)
    letters = k.part("Briefe", "paper", bevel=0.001)
    for i in range(4):
        letters.box((0.08 + i * 0.004, -0.01 + i * 0.003, 0.026 + i * 0.0032), (0.15, 0.1, 0.003), step=0.5, dent=0.0004,
                    turn=(0, 0, -6 + i * 4))
    ribbon = k.part("Band", "wax_red", bevel=0.0)
    ribbon.tube([(0.085, -0.07, 0.024), (0.085, -0.06, 0.04), (0.085, 0.04, 0.04), (0.085, 0.05, 0.024)], 0.0025, segs=5, smooth=1)
    seal = k.part("Siegel", "wax_red", bevel=0.0)
    F.patch(seal, (0.082, -0.01, 0.0405), (0, 0, 1), 0.016, 0.003, random.Random(k.seed), wobble=0.25)
    stamp = k.part("Petschaft", "wood", bevel=0.0)
    stamp.lathe([(0.0, 0.0), (0.012, 0.0), (0.009, 0.02), (0.006, 0.05), (0.012, 0.07), (0.0, 0.08)], (0.0, 0.06, 0.024), segs=14)
    F.knob(cap, (0.0, 0.06, 0.024), r=0.011, normal=(0, 0, -1))
    stick = k.part("Siegellack", "wax_red", bevel=0.0)
    stick.box((-0.02, -0.07, 0.03), (0.12, 0.012, 0.012), step=0.5, dent=0.0004, turn=(0, 0, 12))
    k.collider((0, 0, 0.04), (0.38, 0.22, 0.08))


# --- Perserteppich ---

def build_persian_rug(k):
    k.mat("rug", BORDEAUX, grain="fabric", rough=0.95, vary=0.08, bump=0.35, scale=2.0)
    k.mat("rug_border", (0.13, 0.17, 0.3), grain="fabric", rough=0.95, vary=0.08, bump=0.3)
    k.mat("rug_motif", (0.86, 0.76, 0.56), grain="fabric", rough=0.95, vary=0.08, bump=0.3)
    k.mat("fringe", (0.92, 0.88, 0.78), grain="fabric", rough=0.95, vary=0.05)
    W, D = 2.2, 1.5
    F.rug(k, "rug", (W, D), thickness=0.012, fringe_slot=None, border=(0.14, "rug_border"))
    inner = k.part("Innenfeld", "rug", bevel=0.001, settle=False)
    pts = [(math.cos(2 * math.pi * i / 48) * (W / 2 - 0.26), math.sin(2 * math.pi * i / 48) * (D / 2 - 0.26)) for i in range(48)]
    rect = []
    for x, y in pts:
        n = 8.0
        r = (abs(x / (W / 2 - 0.26)) ** n + abs(y / (D / 2 - 0.26)) ** n) ** (1 / n)
        rect.append((x / r, y / r))
    inner.slab(rect, 0.0015, Matrix.Translation((0, 0, 0.0128)), dent=0.0)
    motif = k.part("Muster", "rug_motif", bevel=0.001, settle=False)
    med = [(math.cos(2 * math.pi * i / 40) * 0.38 * (1 + 0.12 * math.cos(8 * math.pi * i / 40)),
            math.sin(2 * math.pi * i / 40) * 0.25 * (1 + 0.12 * math.cos(8 * math.pi * i / 40))) for i in range(40)]
    motif.slab(med, 0.0012, Matrix.Translation((0, 0, 0.0144)), dent=0.0)
    core = k.part("Medaillon", "rug_border", bevel=0.001, settle=False)
    core.slab([(x * 0.45, y * 0.45) for x, y in med], 0.0012, Matrix.Translation((0, 0, 0.0157)), dent=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            corner = [(sx * (W / 2 - 0.27) + sx * -math.cos(math.pi / 2 * i / 10) * 0.22, sy * (D / 2 - 0.27) + sy * -math.sin(math.pi / 2 * i / 10) * 0.16)
                      for i in range(11)] + [(sx * (W / 2 - 0.27), sy * (D / 2 - 0.27))]
            if sx * sy < 0:
                corner = list(reversed(corner))
            motif.slab(corner, 0.0012, Matrix.Translation((0, 0, 0.0144)), dent=0.0)
    for i in range(14):
        x = -W / 2 + 0.2 + i * (W - 0.4) / 13
        for sy in (-1, 1):
            dia = [(x, sy * (D / 2 - 0.07) - 0.025), (x + 0.025, sy * (D / 2 - 0.07)), (x, sy * (D / 2 - 0.07) + 0.025), (x - 0.025, sy * (D / 2 - 0.07))]
            motif.slab(dia, 0.0012, Matrix.Translation((0, 0, 0.0144)), dent=0.0)
    fringe = k.part("Fransen", "fringe", bevel=0.0, settle=False)
    rnd = random.Random(k.seed)
    y = -D / 2 + 0.03
    while y < D / 2 - 0.02:
        for sx in (-1, 1):
            x0 = sx * W / 2 * 0.99
            ln = rnd.uniform(0.05, 0.07)
            fringe.tube([Vector((x0, y, 0.006)), Vector((x0 + sx * ln * 0.6, y + rnd.uniform(-0.006, 0.006), 0.003)),
                         Vector((x0 + sx * ln, y + rnd.uniform(-0.01, 0.01), 0.0025))], 0.0022, segs=4, smooth=1, round_ends=True)
        y += 0.02
    k.collider((0, 0, 0.006), (W, D, 0.012))


# --- Schottenkaro-Decke (gefaltet) ---

def build_tartan_throw(k):
    k.mat("fabric", (0.5, 0.12, 0.12), grain="fabric", rough=0.95, vary=0.06, bump=0.3, color2=(0.12, 0.2, 0.15),
          color3=(0.85, 0.72, 0.4), pattern="tartan", pattern_size=0.05)
    b = k.part("Decke", "fabric", bevel=0.0)
    for i in range(3):
        F.pillow(b, (0.006 * i, -0.004 * i, 0.016 + i * 0.03), (0.5, 0.34, 0.034), roundness=5.0, puff=0.005, step=0.03, turn=(i - 1) * 1.5)
    fold = k.part("Faltkante", "fabric", bevel=0.0)
    fold.tube([(-0.25, -0.17, 0.05), (0.25, -0.17, 0.05)], 0.031, segs=12, round_ends=True)
    tassels = k.part("Fransen", "fabric", bevel=0.0)
    for i in range(14):
        x = -0.24 + i * 0.037
        for zz in (0.012, 0.072):
            tassels.tube([(x, 0.17, zz), (x + 0.004, 0.2, zz - 0.006), (x + 0.002, 0.22, zz - 0.012)], 0.003, segs=4, smooth=1, round_ends=True)
    k.collider((0, 0.01, 0.05), (0.52, 0.38, 0.1))
    k.surface((0, 0, 0.1), (0.46, 0.3))


# --- Ölgemälde im Goldrahmen ---

def build_painting(k):
    k.mat("frame", (0.82, 0.64, 0.3), grain="smooth", rough=0.38, metal=0.6, vary=0.08)
    k.mat("canvas_sky", (0.68, 0.74, 0.72), grain="plaster", rough=0.9, vary=0.12, bump=0.4, scale=8.0)
    k.mat("paint_hill", (0.36, 0.42, 0.24), grain="plaster", rough=0.9, vary=0.12, bump=0.4)
    k.mat("paint_far", (0.5, 0.55, 0.5), grain="plaster", rough=0.9, vary=0.1, bump=0.3)
    k.mat("paint_tree", (0.2, 0.3, 0.16), grain="plaster", rough=0.9, vary=0.12, bump=0.4)
    k.mat("paint_sun", (0.95, 0.82, 0.55), grain="plaster", rough=0.9, vary=0.05, bump=0.3)
    W, H = 0.72, 0.56
    fr = k.part("Rahmen", "frame", bevel=0.003)
    F.frame(fr, (0, 0, 0), W, H, 0.045, 0.07, style="gilded")
    back = k.part("Leinwand", "canvas_sky", bevel=0.0, settle=False)
    back.box((0, -0.012, 0), (W - 0.1, 0.012, H - 0.1), step=0.2, dent=0.0004)
    m = Matrix.Translation((0, -0.019, 0)) @ Matrix.Rotation(math.radians(90), 4, "X")
    far = k.part("Ferne Hügel", "paint_far", bevel=0.0, settle=False)
    far.slab([(-0.31, -0.05), (-0.18, 0.02), (-0.05, -0.02), (0.1, 0.05), (0.31, -0.01), (0.31, -0.2), (-0.31, -0.2)], 0.003, m, dent=0.0)
    hill = k.part("Hügel", "paint_hill", bevel=0.0, settle=False)
    hill.slab([(-0.31, -0.12), (-0.12, -0.06), (0.06, -0.1), (0.31, -0.04), (0.31, -0.23), (-0.31, -0.23)], 0.003,
              Matrix.Translation((0, -0.004, 0)) @ m, dent=0.0)
    sun = k.part("Sonne", "paint_sun", bevel=0.0, settle=False)
    sun.slab([(0.18 + math.cos(2 * math.pi * i / 20) * 0.04, 0.13 + math.sin(2 * math.pi * i / 20) * 0.04) for i in range(20)], 0.003, m, dent=0.0)
    trees = k.part("Bäume", "paint_tree", bevel=0.0, settle=False)
    for x, s in ((-0.2, 0.05), (-0.16, 0.038), (0.14, 0.045)):
        trees.blob((x, -0.026, -0.04 + s * 0.6), s * 0.55, subdiv=2, lump=0.2, scale=(0.9, 0.25, 1.2))
    k.collider((0, -0.025, 0), (W, 0.05, H))


# --- Efeu im Kupfertopf ---

def build_ivy_pot(k):
    k.mat("pot", (0.72, 0.42, 0.26), grain="smooth", rough=0.38, metal=0.6, vary=0.08)
    soil, rim = F.pot(k, (0, 0, 0), 0.07, 0.11, style="bucket", slot="pot")
    p = k.plant("pot")
    G.trailing(p, None, ranks=14, leaf_mat="ivy", shape="heart")
    k.add_plant(p, soil, scale=rim / 0.205)
    k.collider((0, 0, 0.055), (0.15, 0.15, 0.11))


# --- Messingteleskop ---

def build_telescope(k):
    wood(k)
    brass(k)
    k.mat("lens", (0.3, 0.38, 0.42), grain="smooth", rough=0.15, vary=0.02)
    head = Vector((0, 0.02, 1.12))
    legs = k.part("Dreibein", "wood", bevel=0.0)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        out = Vector((math.cos(a), math.sin(a), 0))
        legs.tube([head + out * 0.03 - Vector((0, 0, 0.03)), out * 0.42 + Vector((0, 0, 0.01))], lambda t: 0.018 - 0.006 * t, segs=8, round_ends=True)
        legs.blob(out * 0.42 + Vector((0, 0, 0.012)), 0.016, subdiv=1, lump=0.05)
    hub = k.part("Kopf", "brass", bevel=0.0)
    hub.lathe([(0.0, 0.0), (0.04, 0.0), (0.045, 0.02), (0.03, 0.05), (0.0, 0.055)], head - Vector((0, 0, 0.04)), segs=18)
    tube = k.part("Rohr", "brass", bevel=0.0)
    d = Vector((0, -0.85, 0.5)).normalized()
    start = head + Vector((0, 0, 0.05)) - d * 0.3
    for i, (ln, r) in enumerate(((0.44, 0.062), (0.32, 0.05), (0.24, 0.04))):
        a = start + d * (0.0 if i == 0 else sum((0.44, 0.32)[:i]) - 0.04 * i)
        tube.tube([a, a + d * ln], r, segs=24)
        tube.tube([a + d * ln * 0.98, a + d * (ln + 0.012)], r * 1.12, segs=24)
    lens = k.part("Linse", "lens", bevel=0.0)
    lens.tube([start + d * 0.9, start + d * 0.905], 0.034, segs=20)
    eye = k.part("Okular", "brass", bevel=0.0)
    eye.tube([start - d * 0.08, start + d * 0.01], 0.024, segs=14)
    k.collider((0, 0.0, 0.65), (0.8, 0.8, 1.3))


# --- Planetenmodell ---

def build_orrery(k):
    wood(k)
    brass(k)
    k.mat("sun", (0.98, 0.78, 0.3), grain="smooth", rough=0.35, metal=0.5, vary=0.05, emit=0.4, emit_color=(1.0, 0.75, 0.35))
    base = k.part("Sockel", "wood", bevel=0.0)
    base.lathe([(0.0, 0.0), (0.12, 0.0), (0.125, 0.012), (0.11, 0.03), (0.06, 0.04), (0.0, 0.042)], (0, 0, 0), segs=36)
    stem = k.part("Achse", "brass", bevel=0.0)
    stem.tube([(0, 0, 0.04), (0, 0, 0.22)], 0.006, segs=8)
    sun = k.part("Sonne", "sun", bevel=0.0)
    F.sphere(sun, (0, 0, 0.25), 0.035, segs=20, rings=10)
    planets = [(0.07, 0.009, (0.7, 0.62, 0.55), 0.21, 30), (0.11, 0.013, (0.85, 0.7, 0.45), 0.2, 110), (0.15, 0.014, (0.35, 0.5, 0.75), 0.19, 200),
               (0.19, 0.011, (0.75, 0.38, 0.25), 0.18, 300), (0.25, 0.026, (0.82, 0.68, 0.5), 0.17, 60)]
    for i, (dist, r, col, h, ang) in enumerate(planets):
        a = math.radians(ang)
        d = Vector((math.cos(a), math.sin(a), 0))
        arm = k.part("Arm", "brass", bevel=0.0)
        arm.tube([Vector((0, 0, h)), d * dist + Vector((0, 0, h)), d * dist + Vector((0, 0, h + 0.03))], 0.0025, segs=5, round_ends=True)
        pl = k.part("Planet", "planet_%d" % i, bevel=0.0)
        k.mat("planet_%d" % i, col, grain="paint", rough=0.6, vary=0.08)
        F.sphere(pl, d * dist + Vector((0, 0, h + 0.03 + r)), r, segs=14, rings=8)
        if i == 4:
            F.ring(arm, d * dist + Vector((0, 0, h + 0.03 + r)), r * 1.7, 0.003, matrix=Matrix.Rotation(math.radians(20), 4, "X"), n=24)
    F.ring(stem, (0, 0, 0.16), 0.255, 0.0025, n=48)
    k.collider((0, 0, 0.14), (0.52, 0.52, 0.28))


# --- Eulen-Buchstützen ---

def build_owl_bookend(k):
    """Einzelne Eulen-Buchstütze (seit Etappe 6b): Messingplatte mit flacher Seite +x zu den
    Büchern, die Eule sitzt im Profil davor und schaut nach außen (-x) – vorn und hinten gleich,
    um 180° gedreht hält sie den Bücherblock von der anderen Seite."""
    brass(k)
    k.mat("eyes", (0.15, 0.12, 0.1), grain="smooth", rough=0.3, vary=0.02)
    b = k.part("Eule", "brass", bevel=0.0)
    b.box((-0.004, 0, 0.004), (0.09, 0.1, 0.008), step=0.5, dent=0.0004)
    b.box((0.04, 0, 0.08), (0.008, 0.1, 0.16), step=0.5, dent=0.0004)
    body = Vector((-0.004, 0, 0.065))
    b.blob(body, 0.042, subdiv=2, lump=0.06, scale=(0.85, 0.9, 1.25))
    head = body + Vector((-0.004, 0, 0.065))
    b.blob(head, 0.034, subdiv=2, lump=0.04, scale=(0.9, 1.05, 0.85))
    for e in (-1, 1):
        # Federohren und Flügel
        b.blob(head + Vector((-0.008, e * 0.02, 0.028)), 0.01, subdiv=1, lump=0.05, scale=(0.7, 0.7, 1.4))
        b.blob(body + Vector((0.0, e * 0.036, -0.005)), 0.022, subdiv=1, lump=0.06, scale=(0.8, 0.45, 1.2))
    eyes = k.part("Augen", "eyes", bevel=0.0)
    for e in (-1, 1):
        F.button(b, head + Vector((-0.028, e * 0.014, 0.004)), r=0.011, normal=(-1, 0, 0.1))
        eyes.blob(head + Vector((-0.033, e * 0.014, 0.005)), 0.0055, subdiv=1, lump=0.02)
    b.blob(head + Vector((-0.033, 0, -0.012)), 0.006, subdiv=1, lump=0.02, scale=(1, 0.7, 1.2))
    k.collider((0.0, 0, 0.08), (0.09, 0.1, 0.16))


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
    dict(id="bookshelf_da_low", name="Niedriges Bücherregal", category="shelf", sub="bookshelf", price=160,
         desc="Halbhohes Regal mit Messinggalerie oben – zwei Fächer und viel Platz für Deko.",
         styles=STYLE, place="floor", build=build_low_shelf, variants=wood_variants()),
    dict(id="sofa_chesterfield", name="Chesterfield-Sofa", category="seating", sub="sofa", price=380,
         desc="Dreisitzer mit tiefen Knöpfen, gerollten Armlehnen und Messingnägeln.",
         styles=STYLE, place="floor", lean=True, adopt=True, build=build_chesterfield_sofa,
         variants=[("cognac", "Cognac", {"leather": COGNAC}), ("bordeaux", "Bordeaux", {"leather": BORDEAUX}),
                   ("bottle", "Flaschengrün", {"leather": BOTTLE}), ("navy", "Nachtblau", {"leather": NAVY}),
                   ("chocolate", "Schokolade", {"leather": CHOCOLATE})]),
    dict(id="desk_leather", name="Schreibtisch mit Lederauflage", category="table", sub="desk", price=260,
         desc="Schreibtisch mit zwei Unterschränken, Messinggriffen und Lederauflage mit Goldprägung.",
         styles=STYLE, place="floor", adopt=True, build=build_partners_desk,
         variants=[("walnut_green", "Walnuss · Grün", {"wood": WALNUT, "leather": BOTTLE}),
                   ("mahogany_red", "Mahagoni · Bordeaux", {"wood": MAHOGANY, "leather": BORDEAUX}),
                   ("oak_navy", "Räuchereiche · Blau", {"wood": (0.44, 0.3, 0.18), "leather": NAVY}),
                   ("ebony_cognac", "Ebenholz · Cognac", {"wood": (0.19, 0.13, 0.1), "leather": COGNAC})]),
    dict(id="chair_da", name="Schreibtischstuhl", category="seating", sub="chair", price=95,
         desc="Runder Stuhl mit Bogenlehne aus Spindeln und Ledersitz mit Ziernägeln.",
         styles=STYLE, place="floor", lean=True, build=build_desk_chair,
         variants=[("walnut_green", "Walnuss · Grün", {"wood": WALNUT, "leather": BOTTLE}),
                   ("mahogany_red", "Mahagoni · Bordeaux", {"wood": MAHOGANY, "leather": BORDEAUX}),
                   ("oak_cognac", "Räuchereiche · Cognac", {"wood": (0.44, 0.3, 0.18), "leather": COGNAC}),
                   ("ebony_navy", "Ebenholz · Blau", {"wood": (0.19, 0.13, 0.1), "leather": NAVY})]),
    dict(id="table_wine", name="Weintisch", category="table", sub="side_table", price=70,
         desc="Kleiner runder Tisch auf gedrechselter Säule und geschwungenem Dreibein.",
         styles=STYLE, place="floor", build=build_wine_table, variants=wood_variants()),
    dict(id="card_catalog", name="Zettelkatalog", category="shelf", sub="cabinet", price=210,
         desc="Vierundzwanzig kleine Schübe mit Messingrahmen für Karteikarten – das Herz jeder Bibliothek.",
         styles=STYLE, place="floor", build=build_card_catalog, variants=wood_variants()),
    dict(id="folding_screen", name="Paravent mit Samt", category="divider", sub="", price=150,
         desc="Drei Holzrahmen mit Bogen oben, mit Samt bespannt und geknöpft.",
         styles=STYLE, place="floor", adopt=True, build=build_screen,
         variants=[("bordeaux", "Bordeaux", {"fabric": BORDEAUX}), ("bottle", "Flaschengrün", {"fabric": BOTTLE}),
                   ("navy", "Nachtblau", {"fabric": NAVY}), ("mustard", "Senf", {"fabric": (0.66, 0.48, 0.16)})]),
    dict(id="floor_lamp_brass", name="Messing-Stehlampe", category="lighting", sub="floor_lamp", price=85,
         desc="Gedrechselte Messingstange und ein Faltenschirm, der warm leuchtet.",
         styles=STYLE, place="floor", adopt=True, build=build_floor_lamp,
         variants=[("cream", "Creme", {"shade": (0.93, 0.86, 0.7)}), ("bordeaux", "Bordeaux", {"shade": (0.55, 0.16, 0.18)}),
                   ("bottle", "Flaschengrün", {"shade": (0.2, 0.36, 0.26)}), ("navy", "Nachtblau", {"shade": (0.2, 0.25, 0.42)})]),
    dict(id="chandelier", name="Messing-Kronleuchter", category="lighting", sub="ceiling_lamp", price=320,
         desc="Sechs geschwungene Arme mit Kerzenbirnen an einer Messingkette.",
         styles=STYLE, place="ceiling", adopt=True, build=build_chandelier,
         variants=[("brass", "Messing", {"brass": BRASS}), ("silver", "Silber", {"brass": (0.74, 0.74, 0.72)}),
                   ("bronze", "Bronze", {"brass": (0.55, 0.38, 0.22)})]),
    dict(id="wall_lamp_da", name="Wandleuchte mit Tulpenglas", category="lighting", sub="wall_lamp", price=65,
         desc="Messingarm mit kleiner Schnecke und einem geriffelten Glas.",
         styles=STYLE, place="wall", build=build_wall_lamp,
         variants=[("brass", "Messing", {"brass": BRASS}), ("silver", "Silber", {"brass": (0.74, 0.74, 0.72)}),
                   ("bronze", "Bronze", {"brass": (0.55, 0.38, 0.22)})]),
    dict(id="globe_floor", name="Standglobus", category="deco", sub="figure", price=140,
         desc="Großer Globus mit Messingmeridian auf einem geschwungenen Holzgestell.",
         styles=STYLE, place="floor", build=build_globe_floor,
         variants=[("blue", "Altes Blau", {"globe_sea": SEA}), ("teal", "Petrol", {"globe_sea": (0.2, 0.42, 0.42)}),
                   ("parchment", "Pergament", {"globe_sea": (0.78, 0.68, 0.5)}), ("bordeaux", "Bordeaux", {"globe_sea": (0.42, 0.14, 0.16)})]),
    dict(id="globe_small", name="Tischglobus", category="deco", sub="figure", price=28,
         desc="Kleiner Globus auf Holzfuß – passt in jedes Regalfach.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_globe_small,
         variants=[("blue", "Altes Blau", {"globe_sea": SEA}), ("teal", "Petrol", {"globe_sea": (0.2, 0.42, 0.42)}),
                   ("parchment", "Pergament", {"globe_sea": (0.78, 0.68, 0.5)}), ("bordeaux", "Bordeaux", {"globe_sea": (0.42, 0.14, 0.16)})]),
    dict(id="bust_da", name="Büste auf Bücherstapel", category="deco", sub="figure", price=45,
         desc="Eine kleine Gelehrtenbüste mit Lockenkopf, thronend auf drei alten Büchern.",
         styles=STYLE, place=["surface", "floor"], build=build_bust,
         variants=[("marble", "Marmorweiß", {"plaster": (0.93, 0.91, 0.86)}), ("bronze", "Bronze", {"plaster": (0.5, 0.36, 0.22)}),
                   ("terracotta", "Terrakotta", {"plaster": (0.72, 0.42, 0.3)}), ("basalt", "Basalt", {"plaster": (0.22, 0.22, 0.23)})]),
    dict(id="writing_set", name="Schreibset", category="deco", sub="figure", price=32,
         desc="Tintenfass mit Federkiel, Briefe mit Band und Siegel, Petschaft und Siegellack auf einem Tablett.",
         styles=STYLE, place="surface", build=build_writing_set, variants=wood_variants()),
    dict(id="rug_persian", name="Perserteppich", category="deco", sub="rug", price=170,
         desc="Großer Teppich mit Bordüre, Medaillon und Fransen.",
         styles=STYLE, place="floor", build=build_persian_rug,
         variants=[("bordeaux", "Bordeaux", {"rug": BORDEAUX}), ("navy", "Nachtblau", {"rug": (0.16, 0.2, 0.36)}),
                   ("forest", "Waldgrün", {"rug": (0.18, 0.3, 0.22)}), ("rust", "Rost", {"rug": (0.6, 0.28, 0.16)})]),
    dict(id="throw_tartan", name="Schottenkaro-Decke", category="deco", sub="textile", price=30,
         desc="Gefaltete Wolldecke im Schottenkaro mit Fransen – für kalte Leseabende.",
         styles=STYLE, place=["surface", "floor"], lie=True, build=build_tartan_throw,
         variants=[("red", "Rot", {"fabric": (0.5, 0.12, 0.12)}), ("green", "Grün", {"fabric": (0.16, 0.3, 0.2)}),
                   ("navy", "Blau", {"fabric": (0.15, 0.2, 0.36)}), ("brown", "Braun", {"fabric": (0.4, 0.27, 0.16)})]),
    dict(id="painting_da", name="Ölgemälde im Goldrahmen", category="deco", sub="picture", price=85,
         desc="Eine Landschaft mit Hügeln und Abendsonne – jede Farbe ein kleines Relief.",
         styles=STYLE, place="wall", build=build_painting,
         variants=[("gold", "Gold", {"frame": (0.82, 0.64, 0.3)}), ("walnut", "Walnuss", {"frame": WALNUT}),
                   ("black", "Schwarz", {"frame": (0.12, 0.1, 0.09)})]),
    dict(id="plant_ivy_da", name="Efeu im Kupfertopf", category="deco", sub="plant", price=18,
         desc="Ein kleiner Efeu, der über den Rand des Kupfertopfs rankt – schön im Regal.",
         styles=STYLE, place=["surface", "floor"], build=build_ivy_pot,
         variants=[("copper", "Kupfer", {"pot": (0.72, 0.42, 0.26)}), ("brass", "Messing", {"pot": BRASS}),
                   ("iron", "Gusseisen", {"pot": (0.17, 0.16, 0.15)})]),
    dict(id="telescope", name="Messingteleskop", category="deco", sub="figure", price=150,
         desc="Ein ausziehbares Messingteleskop auf einem hölzernen Dreibein – für Sternennächte am Fenster.",
         styles=STYLE, place="floor", build=build_telescope,
         variants=[("brass", "Messing", {"brass": BRASS}), ("silver", "Silber", {"brass": (0.74, 0.74, 0.72)}),
                   ("copper", "Kupfer", {"brass": (0.72, 0.42, 0.26)})]),
    dict(id="orrery", name="Planetenmodell", category="deco", sub="figure", price=95,
         desc="Ein kleines Sonnensystem auf Messingarmen, die Sonne glüht sanft.",
         styles=STYLE, place=["surface", "floor"], build=build_orrery, variants=wood_variants()),
    dict(id="bookend_owls", name="Eulen-Buchstütze", category="deco", sub="bookend", price=14,
         desc="Eine kleine Messingeule an einer Platte – eine Stütze; zwei halten einen Bücherblock (Mausrad dreht).",
         styles=STYLE, place=["surface", "floor"], build=build_owl_bookend,
         variants=[("brass", "Messing", {"brass": BRASS}), ("bronze", "Bronze", {"brass": (0.5, 0.35, 0.2)}),
                   ("silver", "Silber", {"brass": (0.74, 0.74, 0.72)}), ("iron", "Gusseisen", {"brass": (0.2, 0.19, 0.18)})]),
]
