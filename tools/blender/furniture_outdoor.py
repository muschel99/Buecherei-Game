"""Draußen (seit „Draußen gestalten“): Dinge für den Gehweg vor der Bücherei – Gartenbank, Bistrostuhl und -tisch,
Kreidetafel-Aufsteller, Pflanzen in Töpfen. Kategorie „Draußen“ (nur sie dürfen draußen stehen, drinnen auch).
Jedes Objekt: Beschreibung + Bau-Funktion (storybook_furniture, Vorderseite -y). Sitzhöhe 0,30 m, Tischhöhe 0,5 m
(Chibi-Figuren) – direkt so gebaut. Kein Stil-Merkmal (passt zu jeder Bücherei).
"""

import math
import random

from mathutils import Matrix, Vector

import storybook_furniture as F
import storybook_greenery as G

STYLE = []
SAGE = (0.52, 0.64, 0.54)
CREAM = (0.92, 0.88, 0.78)
BLUE = (0.42, 0.55, 0.66)
OAK = (0.66, 0.48, 0.3)
IRON_GREEN = (0.24, 0.38, 0.3)
IRON_BLACK = (0.16, 0.16, 0.16)
ROSE = (0.86, 0.6, 0.62)
TERRA = (0.74, 0.42, 0.28)
PAINTS = [("sage", "Salbei", SAGE), ("cream", "Creme", CREAM), ("blue", "Taubenblau", BLUE), ("oak", "Eiche natur", OAK)]
IRONS = [("green", "Flaschengrün", IRON_GREEN), ("cream", "Creme", CREAM), ("black", "Schwarz", IRON_BLACK),
         ("rose", "Altrosa", ROSE)]
POTS = [("terra", "Terrakotta", TERRA), ("cream", "Creme glasiert", (0.9, 0.86, 0.76)), ("sage", "Salbei glasiert", SAGE),
        ("blue", "Blau glasiert", (0.38, 0.5, 0.66))]


def paint(k, color=SAGE, slot="paint"):
    return k.mat(slot, color, grain="paint", rough=0.7, vary=0.06, bump=0.12)


def iron(k, color=IRON_GREEN, slot="iron"):
    return k.mat(slot, color, grain="paint", rough=0.5, metal=0.35, vary=0.05, bump=0.08)


def pot_mat(k, color=TERRA):
    if color == TERRA:
        return k.mat("pot", color, grain="plaster", rough=0.9, vary=0.08, scale=3.0)
    return k.mat("pot", color, grain="smooth", rough=0.35, vary=0.05)


def variants(slot, table):
    return [(vid, name, {slot: col}) for vid, name, col in table]


# --- Gartenbank ---

def build_garden_bench(k):
    """Gartenbank aus gestrichenem Holz: zwei Seitenrahmen (Vorderbein bis zur Armlehne, hinteres Bein geht schräg in die
    Lehne über), fünf Sitzlatten, drei Lehnlatten, Armlehnen, eine Strebe unten. Alles verzapft (steckt ineinander)."""
    paint(k)
    W, SEAT = 1.2, 0.3
    hw = W / 2 - 0.03
    b = k.part("Bank", "paint", bevel=0.006)
    for sx in (-1, 1):
        x = sx * hw
        # Vorderbein bis unter die Armlehne
        b.box((x, -0.18, 0.25), (0.05, 0.05, 0.5), step=0.3, dent=0.0008)
        # hinteres Bein: senkrecht bis zum Sitz, dann schräg nach hinten hinauf (Lehnpfosten)
        b.span((x, 0.16, 0.0), (x, 0.16, SEAT), 0.05, 0.05, step=0.3, dent=0.0008)
        b.span((x, 0.16, SEAT - 0.02), (x, 0.24, 0.74), 0.05, 0.05, step=0.3, dent=0.0008)
        # Sitzzarge seitlich und Armlehne
        b.span((x, -0.2, SEAT - 0.04), (x, 0.18, SEAT - 0.04), 0.045, 0.06, step=0.3, dent=0.0008)
        b.span((x, -0.22, 0.5), (x, 0.2, 0.53), 0.07, 0.03, step=0.3, dent=0.0008)
        # untere Strebe zwischen den Beinen
        b.span((x, -0.18, 0.08), (x, 0.16, 0.08), 0.03, 0.035, step=0.3, dent=0.0006)
    # Sitzlatten (liegen auf den Zargen)
    for i in range(5):
        y = -0.135 + i * 0.068
        b.box((0, y, SEAT - 0.0125), (W - 0.02, 0.06, 0.025), step=0.3, dent=0.0008)
    # Lehnlatten zwischen den schrägen Pfosten
    for z in (0.44, 0.55, 0.66):
        y = 0.16 + (z - SEAT) / (0.74 - SEAT) * 0.08 - 0.005
        b.box((0, y, z), (W - 0.06, 0.022, 0.075), step=0.3, dent=0.0008, turn=(-10, 0, 0))
    # Mittelstrebe unten (vorn nach hinten) und Querstrebe
    b.span((-hw, 0.0, 0.08), (hw, 0.0, 0.08), 0.03, 0.035, step=0.3, dent=0.0006)
    k.collider((0, -0.01, SEAT / 2), (W, 0.44, SEAT))
    k.collider((0, 0.2, 0.52), (W, 0.12, 0.44))
    for sx in (-1, 1):
        k.seat((sx * 0.27, -0.04, SEAT), 0.0)
    k.surface((0, -0.04, SEAT), (W - 0.2, 0.3))
    k.interact = (Vector((0, -0.04, 0.42)), Vector((W, 0.44, 0.4)))


# --- Bistrostuhl ---

def build_bistro_chair(k):
    """Pariser Bistrostuhl aus Metall: runder Sitz mit Rand, vier leicht gespreizte Beine mit Ring, Lehne als Bogen mit zwei
    Schnörkeln, der hinten in die Beine übergeht."""
    iron(k)
    SEAT = 0.3
    r = 0.19
    b = k.part("Stuhl", "iron", bevel=0.0)
    # Sitz: flache Scheibe mit Wulst am Rand
    b.lathe([(0.0, SEAT - 0.025), (r - 0.01, SEAT - 0.025), (r, SEAT - 0.012), (r - 0.004, SEAT), (0.0, SEAT - 0.004)],
            (0, 0, 0), segs=36)
    F.ring(b, (0, 0, SEAT - 0.014), r, 0.008, n=40, segs=6)
    # Beine: oben unter dem Sitzrand, unten etwas weiter außen
    legs = []
    for i in range(4):
        a = math.radians(45 + 90 * i)
        top = Vector((math.cos(a) * (r - 0.03), math.sin(a) * (r - 0.03), SEAT - 0.02))
        foot = Vector((math.cos(a) * (r + 0.02), math.sin(a) * (r + 0.02), 0.0))
        b.tube([top, foot], 0.011, segs=8, round_ends=True)
        legs.append((top, foot))
    # Ring zwischen den Beinen
    ring_z = 0.11
    pts = []
    for i in range(4):
        top, foot = legs[i]
        t = (top.z - ring_z) / top.z
        pts.append(top.lerp(foot, t))
    pts.append(pts[0])
    b.tube(pts, 0.006, segs=6)
    # Lehne: Bogen hinten (+y), die Enden sitzen auf dem Sitzrand
    def arc_point(a_deg, inset=0.004):
        t = (a_deg - 25.0) / 130.0
        h = 0.3 * max(0.0, math.sin(math.pi * t)) ** 0.6
        a = math.radians(a_deg)
        return Vector((math.cos(a) * (r - inset), math.sin(a) * (r - inset) + 0.02 * math.sin(math.pi * t), SEAT + h))
    b.tube([arc_point(25 + 130 * i / 20) for i in range(21)], 0.011, segs=8, smooth=1, round_ends=True)
    # zwei Stäbe vom Sitz bis in den Bogen
    for a_deg in (70, 110):
        top = arc_point(a_deg)
        base = Vector((top.x, top.y - 0.02, SEAT - 0.004))
        b.tube([base, top], 0.007, segs=6, round_ends=True)
    # Querbogen auf halber Höhe: beginnt und endet am Bogen
    z_mid = SEAT + 0.16
    lo = 25.0
    while arc_point(lo).z < z_mid and lo < 90:
        lo += 0.5
    hi = 180.0 - lo
    mid = []
    for i in range(11):
        a_deg = lo + (hi - lo) * i / 10
        pt = arc_point(a_deg)
        mid.append(Vector((pt.x, pt.y, z_mid)))
    b.tube(mid, 0.006, segs=6, smooth=1, round_ends=True)
    k.collider((0, 0, SEAT / 2), (2 * r, 2 * r, SEAT))
    k.collider((0, 0.15, SEAT + 0.15), (2 * r, 0.08, 0.3))
    k.seat((0, -0.03, SEAT), 0.0)
    k.surface((0, -0.03, SEAT), (0.24, 0.2))
    k.interact = (Vector((0, 0, 0.42)), Vector((2 * r, 2 * r, 0.4)))


# --- Bistrotisch ---

def build_bistro_table(k):
    """Runder Bistrotisch: Platte mit Rand, Säule mit Ringen, drei geschwungene Füße."""
    iron(k)
    H, R = 0.5, 0.3
    b = k.part("Tisch", "iron", bevel=0.0)
    b.lathe([(0.0, H - 0.025), (R - 0.008, H - 0.025), (R, H - 0.015), (R, H - 0.004), (R - 0.006, H), (0.0, H)], (0, 0, 0),
            segs=48)
    b.lathe([(0.0, 0.07), (0.03, 0.07), (0.022, 0.1), (0.018, H - 0.1), (0.03, H - 0.07), (0.06, H - 0.04), (0.07, H - 0.025),
             (0.0, H - 0.025)], (0, 0, 0), segs=20)
    for z in (0.18, 0.32):
        F.ring(b, (0, 0, z), 0.021, 0.006, n=20, segs=6)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        b.tube([Vector((0, 0, 0.09)), d * 0.12 + Vector((0, 0, 0.06)), d * 0.22 + Vector((0, 0, 0.012))], 0.013, segs=8,
               smooth=2, round_ends=True)
    k.collider((0, 0, H / 2), (2 * R, 2 * R, H))
    k.surface((0, 0, H), (1.25 * R, 1.25 * R))


# --- Kreidetafel-Aufsteller ---

def build_chalk_sign(k):
    """Kundenstopper: zwei Holzrahmen mit Kreidetafel, oben mit Scharnieren, unten mit einer Kette gespreizt. Vorn steht mit
    Kreide „Bücherei – komm rein & stöbere!“ mit einem kleinen Buch."""
    paint(k, OAK, slot="frame")
    k.mat("board", (0.17, 0.2, 0.19), grain="plaster", rough=0.95, vary=0.05, scale=4.0)
    k.mat("chalk", (0.95, 0.94, 0.9), grain="plaster", rough=1.0, vary=0.04)
    k.mat("chain", (0.4, 0.4, 0.38), grain="smooth", rough=0.5, metal=0.5, vary=0.03)
    H, W = 0.82, 0.5
    spread = math.radians(13)
    fr = k.part("Rahmen", "frame", bevel=0.004)
    board = k.part("Tafel", "board", bevel=0.0)
    chalk = k.part("Kreide", "chalk", bevel=0.0)
    for side in (-1, 1):
        # Rahmen kippt um die obere Kante (Scharnier) nach vorn (-y) bzw. hinten (+y)
        m = Matrix.Translation((0, 0, H)) @ Matrix.Rotation(side * spread, 4, "X") @ Matrix.Translation((0, 0, -H))
        for sx in (-1, 1):
            fr.box((sx * (W / 2 - 0.02), 0, H / 2), (0.04, 0.03, H), step=0.3, dent=0.0006, matrix=m)
        fr.box((0, 0, H - 0.02), (W, 0.03, 0.04), step=0.3, dent=0.0006, matrix=m)
        fr.box((0, 0, 0.18), (W, 0.03, 0.04), step=0.3, dent=0.0006, matrix=m)
        board.box((0, 0, (0.2 + H - 0.04) / 2), (W - 0.06, 0.014, H - 0.24), step=0.3, dent=0.0, matrix=m)
        if side < 0:
            # Schrift auf der Vorderseite der Tafel (zeigt nach -y), 0,2 mm in der Tafel
            face = m @ Matrix.Translation((0, -0.0068, 0)) @ Matrix.Rotation(math.radians(90), 4, "X")
            chalk.text("Bücherei", 0.075, 0.002, face @ Matrix.Translation((0, 0.62, 0)), jitter=0.06, resolution=4)
            chalk.text("komm rein", 0.045, 0.002, face @ Matrix.Translation((0, 0.51, 0)), jitter=0.08, resolution=4)
            chalk.text("& stöbere!", 0.045, 0.002, face @ Matrix.Translation((0, 0.45, 0)), jitter=0.08, resolution=4)
            chalk.box((0, 0.0, 0.0), (0.26, 0.006, 0.002), step=0.5, dent=0.0, matrix=face @ Matrix.Translation((0, 0.38, 0.001)))
            # kleines offenes Buch
            for sx in (-1, 1):
                pts = [(sx * 0.004, 0.0), (sx * 0.06, 0.012), (sx * 0.06, 0.06), (sx * 0.004, 0.05)]
                if sx < 0:
                    pts.reverse()
                chalk.slab(pts, 0.002, face @ Matrix.Translation((0, 0.25, 0)), dent=0.0)
    # Kette unten zwischen den Rahmen
    ch = k.part("Kette", "chain", bevel=0.0)
    y = math.tan(spread) * (H - 0.3)
    ch.tube([(0.0, -y, 0.3), (0.0, 0.0, 0.27), (0.0, y, 0.3)], 0.004, segs=5, smooth=1)
    k.collider((0, 0, H / 2), (W, 2 * math.tan(spread) * H, H))


# --- Pflanzen ---

def _potted(k, radius, height, style, builder, scale_ref=0.2, container="potfill"):
    pot_mat(k, k.spec.get("pot_color", TERRA))
    soil, rim = F.pot(k, (0, 0, 0), radius, height, style=style, slot="pot")
    p = k.plant(container)
    builder(p)
    k.add_plant(p, soil, scale=rim / scale_ref)
    return soil, rim


def build_lavender_pot(k):
    """Lavendel im Tontopf (duftet nach Sommer)."""
    _potted(k, 0.16, 0.2, "classic", lambda p: G.lavender_bush(p, color="lilac", spikes=40, height=0.45))
    k.collider((0, 0, 0.18), (0.34, 0.34, 0.36))


def build_boxball_pot(k):
    """Buchsbaumkugel im runden Topf."""
    _potted(k, 0.19, 0.26, "bowl", lambda p: G.boxball(p, radius=0.2))
    k.collider((0, 0, 0.3), (0.4, 0.4, 0.6))


def build_olive_tub(k):
    """Olivenbäumchen im großen Kübel."""
    _potted(k, 0.24, 0.36, "tub", lambda p: G.olive(p, height=0.95, crown_r=0.28), scale_ref=0.31, container="tub")
    k.collider((0, 0, 0.5), (0.5, 0.5, 1.0))


def build_geranium_pot(k):
    """Geranien im Tontopf – wie an jedem englischen Fenster."""
    _potted(k, 0.15, 0.17, "classic", lambda p: G.geranium_bush(p, "red"))
    k.collider((0, 0, 0.15), (0.32, 0.32, 0.3))


def build_hydrangea_tub(k):
    """Große Hortensie im Holzkübel."""
    _potted(k, 0.22, 0.3, "tub", lambda p: G.hydrangea(p, "bloom", size=1.3, leaf_mat="leaf"), scale_ref=0.31, container="tub")
    k.collider((0, 0, 0.3), (0.46, 0.46, 0.6))


def build_rose_standard(k):
    """Rosenstämmchen im Topf: eine kleine Kugel aus Rosen auf einem Stamm."""
    _potted(k, 0.17, 0.24, "classic", lambda p: G.standard_rose(p))
    k.collider((0, 0, 0.45), (0.36, 0.36, 0.9))


def flower_variants(slot):
    return [("red", "Rot", {slot: (0.86, 0.2, 0.17)}), ("pink", "Rosa", {slot: (0.93, 0.52, 0.62)}),
            ("white", "Weiß", {slot: (0.95, 0.94, 0.9)}), ("coral", "Koralle", {slot: (0.95, 0.45, 0.38)})]


ITEMS = [
    dict(id="out_garden_bench", name="Gartenbank", category="outdoor", sub="outdoor_seat", price=95,
         desc="Eine gestrichene Holzbank mit Armlehnen – für zwei, die kurz in ein Buch schauen.",
         styles=STYLE, place="floor", low_seat=False, attach_feet=False, build=build_garden_bench,
         variants=variants("paint", PAINTS)),
    dict(id="out_bistro_chair", name="Bistrostuhl", category="outdoor", sub="outdoor_seat", price=38,
         desc="Ein Pariser Bistrostuhl aus Metall mit geschwungener Lehne.",
         styles=STYLE, place="floor", low_seat=False, attach_feet=False, build=build_bistro_chair,
         variants=variants("iron", IRONS)),
    dict(id="out_bistro_table", name="Bistrotisch", category="outdoor", sub="outdoor_table", price=45,
         desc="Ein runder Metalltisch für eine Tasse Tee und ein Buch.",
         styles=STYLE, place="floor", attach_feet=False, build=build_bistro_table,
         variants=variants("iron", IRONS)),
    dict(id="out_chalk_sign", name="Kreidetafel-Aufsteller", category="outdoor", sub="outdoor_sign", price=30,
         desc="Ein Kundenstopper mit Kreideschrift: „Bücherei – komm rein & stöbere!“",
         styles=STYLE, place="floor", attach_feet=False, build=build_chalk_sign,
         variants=[("oak", "Eiche", {"frame": OAK}), ("cream", "Creme", {"frame": CREAM}), ("sage", "Salbei", {"frame": SAGE}),
                   ("black", "Schwarz", {"frame": (0.2, 0.2, 0.2)})]),
    dict(id="out_lavender_pot", name="Lavendel im Topf", category="outdoor", sub="outdoor_plant", price=16,
         desc="Ein Topf voll Lavendel – Bienen und Leser lieben ihn.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_lavender_pot,
         variants=variants("pot", POTS)),
    dict(id="out_boxball_pot", name="Buchsbaumkugel", category="outdoor", sub="outdoor_plant", price=24,
         desc="Eine rund geschnittene Buchsbaumkugel im bauchigen Topf.",
         styles=STYLE, place="floor", attach_feet=False, build=build_boxball_pot, variants=variants("pot", POTS)),
    dict(id="out_olive_tub", name="Olivenbäumchen", category="outdoor", sub="outdoor_plant", price=48,
         desc="Ein kleiner Olivenbaum im großen Kübel – ein Hauch Süden vor der Tür.",
         styles=STYLE, place="floor", attach_feet=False, build=build_olive_tub, variants=variants("pot", POTS)),
    dict(id="out_geranium_pot", name="Geranien im Topf", category="outdoor", sub="outdoor_plant", price=14,
         desc="Leuchtende Geranien im Tontopf.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_geranium_pot,
         variants=flower_variants("red")),
    dict(id="out_hydrangea_tub", name="Hortensie im Kübel", category="outdoor", sub="outdoor_plant", price=36,
         desc="Eine große Hortensie mit üppigen Blütenbällen im Holzkübel.",
         styles=STYLE, place="floor", attach_feet=False, build=build_hydrangea_tub,
         variants=[("pink", "Rosa", {"bloom": (0.93, 0.6, 0.7)}), ("blue", "Blau", {"bloom": (0.55, 0.66, 0.9)}),
                   ("white", "Weiß", {"bloom": (0.96, 0.95, 0.9)}), ("lilac", "Flieder", {"bloom": (0.72, 0.6, 0.85)})]),
    dict(id="out_rose_standard", name="Rosenstämmchen", category="outdoor", sub="outdoor_plant", price=32,
         desc="Ein Rosenstämmchen mit einer Krone voller Blüten.",
         styles=STYLE, place="floor", attach_feet=False, build=build_rose_standard, variants=variants("pot", POTS)),
]
