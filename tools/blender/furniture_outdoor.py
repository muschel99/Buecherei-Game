"""Draußen (seit „Draußen gestalten“): Dinge für den Gehweg vor der Bücherei – Gartenbank, Bistrostuhl und -tisch,
Kreidetafel-Aufsteller, Pflanzen in Töpfen. Kategorie „Draußen“ (nur sie dürfen draußen stehen, drinnen auch).
Jedes Objekt: Beschreibung + Bau-Funktion (storybook_furniture, Vorderseite -y). Sitzhöhe 0,30 m, Tischhöhe 0,5 m
(Chibi-Figuren) – direkt so gebaut. Kein Stil-Merkmal (passt zu jeder Bücherei).
"""

import math
import random

from mathutils import Matrix, Vector

import furniture_country as FC
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
PINE = (0.8, 0.64, 0.44)
CRATES = [("pine", "Kiefer natur", PINE), ("sage", "Salbei", SAGE), ("cream", "Creme", CREAM), ("blue", "Taubenblau", BLUE)]
# Schilder: dunkle Grundfarben, die Schrift ist immer cremeweiß
SIGNS = [("green", "Tannengrün", (0.22, 0.36, 0.28)), ("blue", "Nachtblau", (0.2, 0.28, 0.42)),
         ("brown", "Nussbraun", (0.4, 0.27, 0.16)), ("red", "Ochsenblut", (0.48, 0.18, 0.15))]
LETTERS = (0.95, 0.92, 0.84)
SLATS = [("oak", "Eiche natur", OAK), ("teak", "Teak", (0.5, 0.32, 0.2)), ("green", "Parkgrün", (0.3, 0.45, 0.32)),
         ("white", "Weiß", (0.9, 0.88, 0.82))]
ZINC = [("zinc", "Zink", (0.62, 0.64, 0.64)), ("white", "Emaille weiß", (0.92, 0.91, 0.88)),
        ("blue", "Emaille blau", (0.36, 0.5, 0.68)), ("cream", "Emaille creme", (0.9, 0.85, 0.72))]
# Blütenfarben (Material "bloom")
TULIPS = [("red", "Rot", (0.86, 0.2, 0.17)), ("yellow", "Gelb", (0.97, 0.84, 0.36)), ("pink", "Rosa", (0.93, 0.52, 0.62)),
          ("white", "Weiß", (0.95, 0.94, 0.9))]
DAHLIAS = [("burgundy", "Weinrot", (0.48, 0.1, 0.17)), ("orange", "Orange", (0.95, 0.52, 0.2)), ("pink", "Rosa", (0.93, 0.52, 0.62)),
           ("yellow", "Gelb", (0.97, 0.84, 0.36))]
ROSES = [("pink", "Rosa", (0.93, 0.52, 0.62)), ("red", "Rot", (0.75, 0.12, 0.16)), ("cream", "Creme", (0.97, 0.93, 0.8)),
         ("apricot", "Apricot", (0.98, 0.72, 0.58))]
PLUMES = [("peach", "Pfirsich", (0.98, 0.78, 0.62)), ("silver", "Silber", (0.86, 0.85, 0.8)), ("rust", "Rotbraun", (0.62, 0.34, 0.26)),
          ("gold", "Gold", (0.9, 0.76, 0.45))]
HOLLYHOCKS = [("pink", "Rosa", (0.93, 0.52, 0.62)), ("burgundy", "Weinrot", (0.48, 0.1, 0.17)), ("white", "Weiß", (0.95, 0.94, 0.9)),
              ("apricot", "Apricot", (0.98, 0.72, 0.58))]
WISTERIA = [("lilac", "Flieder", (0.7, 0.58, 0.82)), ("white", "Weiß", (0.95, 0.94, 0.9)), ("pink", "Rosa", (0.93, 0.7, 0.8)),
            ("violet", "Blauviolett", (0.55, 0.55, 0.85))]
WOODS = [("oak", "Eiche", OAK), ("dark", "Dunkle Eiche", (0.42, 0.28, 0.17)), ("grey", "Verwittert", (0.62, 0.58, 0.52)),
         ("honey", "Honig", (0.78, 0.58, 0.32))]


def paint(k, color=SAGE, slot="paint"):
    return k.mat(slot, color, grain="paint", rough=0.7, vary=0.06, bump=0.12)


def iron(k, color=IRON_GREEN, slot="iron"):
    return k.mat(slot, color, grain="paint", rough=0.5, metal=0.35, vary=0.05, bump=0.08)


def pot_mat(k, color=TERRA):
    if color == TERRA:
        return k.mat("pot", color, grain="plaster", rough=0.9, vary=0.08, scale=3.0)
    return k.mat("pot", color, grain="smooth", rough=0.35, vary=0.05)


def wood(k, color=OAK, slot="wood"):
    return k.mat(slot, color, grain="wood", rough=0.65, vary=0.08, bump=0.1)


def metal(k, color=IRON_BLACK, slot="metal"):
    return k.mat(slot, color, grain="smooth", rough=0.5, metal=0.45, vary=0.05)


def variants(slot, table):
    return [(vid, name, {slot: col}) for vid, name, col in table]


def plane_yz(x0, z0=0.0):
    """Ebene für Seitenbretter: Umriss in (Welt-y, Welt-z), Dicke nach +x ab x0."""
    return Matrix(((0, 0, 1, x0), (1, 0, 0, 0), (0, 1, 0, z0), (0, 0, 0, 1)))


def plane_xz(y0, z0=0.0, x0=0.0):
    """Ebene für Schilder (von vorn gesehen): Umriss in (Welt-x, Welt-z), Dicke nach -y (nach vorn) ab y0."""
    return Matrix(((1, 0, 0, x0), (0, 0, -1, y0), (0, 1, 0, z0), (0, 0, 0, 1)))


def front_text(part, string, size, x, y_face, z, back=False, jitter=0.03):
    """Schrift auf einer Fläche, die nach vorn (-y) zeigt (back=True: nach hinten, +y); y_face = Lage der Fläche,
    die Buchstaben stecken 0,2 mm darin. z = Grundlinie."""
    if back:
        face = Matrix.Translation((x, y_face - 0.0002, z)) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X")
    else:
        face = Matrix.Translation((x, y_face + 0.0002, z)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    return part.text(string, size, 0.0025, face, jitter=jitter, resolution=4, spacing=1.6)


def cross_foot(b, length, size, post, brace_top):
    """Kreuzfuß aus zwei überblatteten Balken (für Pfosten, die nicht eingegraben sind) mit vier Streben zum Pfosten.
    post = halbe Pfostenbreite, brace_top = Höhe, an der die Streben am Pfosten enden."""
    for sx, sy in ((length, size), (size, length)):
        b.box((0, 0, size / 2), (sx, sy, size), step=0.3, dent=0.0006)
    s = size * 0.55
    for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        foot = Vector((d[0] * length * 0.36, d[1] * length * 0.36, size + s * 0.35))
        top = Vector((d[0] * (post + s * 0.3), d[1] * (post + s * 0.3), brace_top))
        b.span(foot, top, s, s, step=0.3, dent=0.0005)


# --- Gartenbank ---

def build_garden_bench(k):
    """Gartenbank aus gestrichenem Holz: zwei Seitenrahmen (Vorderbein bis zur Armlehne, hinteres Bein geht schräg in die
    Lehne über), fünf Sitzlatten, drei Lehnlatten, Armlehnen, eine Strebe unten. Alles verzapft (steckt ineinander)."""
    _garden_seat(k, 1.2, (-0.27, 0.27))


def build_garden_chair(k):
    """Gartenstuhl: dieselbe Bauart wie die Gartenbank, nur für eine Person."""
    _garden_seat(k, 0.62, (0.0,))


def _garden_seat(k, W, seat_xs):
    """Gartenbank/-stuhl der Breite W mit Sitzplätzen bei seat_xs."""
    paint(k)
    SEAT = 0.3
    hw = W / 2 - 0.03
    b = k.part("Bank", "paint", bevel=0.006)
    for sx in (-1, 1):
        x = sx * hw
        # Vorderbein bis unter die Armlehne
        b.box((x, -0.18, 0.25), (0.05, 0.05, 0.5), step=0.3, dent=0.0008)
        # hinteres Bein: senkrecht bis zum Sitz, dann schräg nach hinten hinauf (Lehnpfosten)
        b.span((x, 0.16, 0.0), (x, 0.16, SEAT - 0.016), 0.05, 0.05, step=0.3, dent=0.0008)
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
    for x in seat_xs:
        k.seat((x, -0.04, SEAT), 0.0)
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

def _potted(k, radius, height, style, builder, scale_ref=0.2, container="potfill", scale=None):
    """Topf mit Pflanze; die Pflanze wird in Topfgröße der Bausteine gebaut (Rand scale_ref) und passend verkleinert –
    oder mit fester Größe scale. Ein vorher angelegtes Material "pot" (z. B. Zink) bleibt."""
    pot_mat(k, k.spec.get("pot_color", TERRA))
    soil, rim = F.pot(k, (0, 0, 0), radius, height, style=style, slot="pot", handle=False)
    if style == "bucket":
        _side_handles(k, radius, height)
    p = k.plant(container)
    builder(p)
    k.add_plant(p, soil, scale=scale if scale is not None else rim / scale_ref)
    return soil, rim


def bloom(k, table_or_color):
    """Blütenmaterial "bloom" in der ersten Farbe der Variantentabelle (oder einer Farbe)."""
    color = table_or_color[0][2] if isinstance(table_or_color, list) else table_or_color
    return k.mat("bloom", color, grain="leaf", rough=0.72, vary=0.1, plant=True)


def _side_handles(k, r, h):
    """Zwei kleine Griffe außen an den Seiten eines Eimers (statt des hohen Henkels, der durch die Pflanze ginge); sie
    sitzen kurz unter dem Rand an der Wand (Eimerwand dort: Radius 0,98·r)."""
    metal(k, (0.6, 0.6, 0.58))
    g = k.part("Griffe", "metal", bevel=0.0)
    z = h * 0.86
    w = r * 0.97
    for sx in (-1, 1):
        g.tube([(sx * w, -0.03, z), (sx * (w + 0.022), -0.024, z + 0.004), (sx * (w + 0.03), 0.0, z + 0.006),
                (sx * (w + 0.022), 0.024, z + 0.004), (sx * w, 0.03, z)], 0.004, segs=6, smooth=2, round_ends=True)


def zinc(k):
    """Zink- oder Emaille-Gefäß (Farbvarianten ZINC)."""
    return k.mat("pot", ZINC[0][2], grain="smooth", rough=0.4, metal=0.3, vary=0.05)


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


# --- Kleine Töpfe für die Treppe (passen auf eine Stufe: 28 cm tief, an den Seiten 20 cm breit) ---

def build_small_lavender(k):
    """Lavendel im kleinen Tontopf – passt auf eine Stufe."""
    _potted(k, 0.09, 0.11, "classic", lambda p: G.lavender_bush(p, color="lilac", spikes=26, height=0.42))
    k.collider((0, 0, 0.12), (0.2, 0.2, 0.24))


def build_small_geranium(k):
    """Geranie im kleinen Tontopf – passt auf eine Stufe."""
    _potted(k, 0.09, 0.1, "classic", lambda p: G.geranium_bush(p, "red"))
    k.collider((0, 0, 0.1), (0.2, 0.2, 0.2))


def build_small_heather(k):
    """Heidekraut im kleinen Topf – blüht bis in den Herbst."""
    _potted(k, 0.09, 0.1, "bowl", lambda p: G.heather(p, "magenta_flower", n=110, height=0.22))
    k.collider((0, 0, 0.1), (0.2, 0.2, 0.2))


def build_small_boxball(k):
    """Kleine Buchsbaumkugel im Topf – passt auf eine Stufe."""
    _potted(k, 0.095, 0.12, "bowl", lambda p: G.boxball(p, radius=0.19))
    k.collider((0, 0, 0.14), (0.2, 0.2, 0.28))


# --- Pflanzen, Runde 3: viele Größen, Farben und Formen ---

def build_tulip_pot(k):
    """Tulpen im kleinen Tontopf – passt auch auf eine Stufe."""
    bloom(k, TULIPS)
    _potted(k, 0.1, 0.12, "classic", lambda p: G.tulip_pot(p, "bloom", n=9))
    k.collider((0, 0, 0.15), (0.22, 0.22, 0.3))


def build_rosemary_pot(k):
    """Rosmarin im kleinen Topf – duftet, wenn man vorbeistreift."""
    _potted(k, 0.1, 0.12, "classic", lambda p: G.rosemary(p))
    k.collider((0, 0, 0.14), (0.22, 0.22, 0.28))


def build_marguerite_bucket(k):
    """Margeriten im Emailleeimer mit Henkel."""
    zinc(k)
    _potted(k, 0.15, 0.2, "bucket", lambda p: G.flower_bush(
        p, lambda q, c, at, up: G.daisy_head(q, at, up, 0.04, petal=c), ("white_flower",), n=13, height=0.4, leaf_mat="leaf_blue",
        leaf_shape="narrow", leaf=0.05))
    k.collider((0, 0, 0.22), (0.34, 0.34, 0.44))


def build_dahlia_pot(k):
    """Dahlien im Tontopf: runde, gefüllte Blüten über dunklem Laub."""
    bloom(k, DAHLIAS)
    _potted(k, 0.16, 0.2, "classic", lambda p: G.flower_bush(
        p, lambda q, c, at, up: G.pompon(q, c, at, up, 0.05), ("bloom",), n=8, height=0.42, leaf_mat="leaf_dark"))
    k.collider((0, 0, 0.24), (0.36, 0.36, 0.48))


def build_hosta_bowl(k):
    """Funkie in einer flachen Schale: große, blaugrüne Herzblätter."""
    _potted(k, 0.18, 0.16, "bowl", lambda p: G.hosta(p, 1.25, mats=("leaf_blue", "leaf_blue", "leaf")))
    k.collider((0, 0, 0.18), (0.42, 0.42, 0.36))


def build_fern_bucket(k):
    """Farn im Zinkeimer – mag den Schatten an der Hauswand."""
    zinc(k)
    _potted(k, 0.15, 0.2, "bucket", lambda p: F.lush_fern(p, 1.0, fronds=24))
    k.collider((0, 0, 0.22), (0.4, 0.4, 0.44))


def build_rose_bush(k):
    """Rosenbusch im Holzkübel."""
    bloom(k, ROSES)
    _potted(k, 0.2, 0.28, "tub", lambda p: G.rose_bush(p, ("bloom", "bloom"), height=0.5))
    k.collider((0, 0, 0.32), (0.44, 0.44, 0.64))


def build_box_cone(k):
    """Buchskegel im bauchigen Topf – streng geschnitten, sehr ordentlich."""
    _potted(k, 0.17, 0.22, "bowl", lambda p: G.cone_topiary(p, 0.85, 0.24))
    k.collider((0, 0, 0.45), (0.36, 0.36, 0.9))


def build_bay_standard(k):
    """Lorbeerstämmchen: eine geschnittene Kugel aus dunklen Blättern auf einem geraden Stamm, im Kübel."""
    _potted(k, 0.18, 0.26, "tub", lambda p: G.standard_ball(p, 0.6, 0.21, leaf_mat="leaf_dark"))
    k.collider((0, 0, 0.5), (0.4, 0.4, 1.0))


def build_grass_pot(k):
    """Ziergras im hohen Topf: lange, überhängende Halme mit weichen Rispen."""
    bloom(k, PLUMES)
    _potted(k, 0.14, 0.42, "cylinder", lambda p: G.grass_tuft(p, blades=64, height=0.55, mats=("grass_leaf", "leaf_blue", "grass_leaf"),
                                                                plume="bloom"))
    k.collider((0, 0, 0.42), (0.36, 0.36, 0.84))


def _sunflowers(p, stems=4, height=1.0):
    """Sonnenblumen: kräftige Stängel, große Herzblätter, die Köpfe schauen nach vorn und zur Sonne."""
    rnd = p.rnd
    up = Vector((0, 0, 1))
    for i in range(stems):
        a = 2 * math.pi * i / stems + rnd.uniform(-0.4, 0.4)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        base = out * 0.03
        top = base + out * rnd.uniform(0.03, 0.08) + up * height * rnd.uniform(0.72, 1.0)
        p.body("stem", vary=0.06).tube([base, base.lerp(top, 0.5) + out * 0.012, top], lambda t: 0.011 * (1 - 0.4 * t), segs=6, smooth=1,
                                       round_ends=True)
        for j in range(3):
            q = base.lerp(top, 0.3 + 0.18 * j)
            side = Vector((-out.y, out.x, 0.0)) * (1 if (i + j) % 2 else -1)
            G.leaf_on(p, q, (side + up * 0.35).normalized(), up, rnd.uniform(0.13, 0.16) * (1.1 - 0.2 * j), shape="heart", width=0.9,
                      petiole=0.025, mat="leaf")
        face = (out * 0.35 + Vector((0, -0.65, 0)) + up * 0.55).normalized()
        G.head_sunflower(p, "bloom", top + face * 0.012, face)


def build_sunflower_bucket(k):
    """Fünf Sonnenblumen im Zinkeimer."""
    zinc(k)
    bloom(k, (0.97, 0.78, 0.2))
    _potted(k, 0.16, 0.24, "bucket", lambda p: _sunflowers(p, 5, 1.0), container=None)
    k.collider((0, 0, 0.45), (0.4, 0.4, 0.9))


def build_hollyhock_pot(k):
    """Stockrosen im großen Tontopf: hohe Stängel voller Blüten – schön an der Hauswand."""
    bloom(k, HOLLYHOCKS)
    _potted(k, 0.2, 0.28, "classic", lambda p: G.hollyhock(p, ("bloom",), stems=4, height=1.4))
    k.collider((0, 0, 0.75), (0.5, 0.5, 1.5))


def _planter_box(k, builders, slot="crate", seg=0.28, ends=0.0):
    """Pflanzkasten aus Brettern (Boden, vier Wände auf zwei Füßen), innen Erde bis 4 cm unter den Rand; je Abschnitt
    (seg breit) eine Pflanze aus den Kasten-Bausteinen (Behälter „box“: innen 15,6 cm tief)."""
    n = len(builders)
    L, D, H, t = n * seg + 0.05 + 2 * ends, 0.206, 0.2, 0.025
    b = k.part("Kasten", slot, bevel=0.003)
    for x in (-(L / 2 - 0.08), L / 2 - 0.08):
        b.box((x, 0, 0.01), (0.04, D - 0.03, 0.02), step=0.3, dent=0.0005)
    b.box((0, 0, 0.0325), (L - 0.004, D - 0.004, 0.025), step=0.3, dent=0.0005)
    for sy in (-1, 1):
        b.box((0, sy * (D / 2 - t / 2), (0.045 + H) / 2), (L, t, H - 0.045), step=0.3, dent=0.0005)
    for sx in (-1, 1):
        b.box((sx * (L / 2 - t / 2), 0, (0.045 + H) / 2), (t, D - 2 * t - 0.002, H - 0.045), step=0.3, dent=0.0005)
    k.mat("soil", (0.25, 0.17, 0.11), grain="stone", rough=0.95, vary=0.12, bump=0.4)
    soil_z = H - 0.04          # Rand 4 cm über der Erde (Blätter, die über den Rand fallen, liegen nicht auf der Kante)
    e = k.part("Erde", "soil", bevel=0.0, settle=False)
    e.box((0, 0, (0.045 + soil_z) / 2), (L - 2 * t - 0.004, D - 2 * t - 0.004, soil_z - 0.045), step=0.1, dent=0.003)
    for i, builder in enumerate(builders):
        p = k.plant("box", seed_offset=i * 17)
        builder(p)
        k.add_plant(p, ((i - (n - 1) / 2) * seg, 0, soil_z))
    k.collider((0, 0, H / 2), (L, D, H))
    return L


def build_herb_crate(k):
    """Kräuterkiste: ein Holzkasten mit Rosmarin, Thymian und Basilikum."""
    wood(k, PINE, slot="crate")
    _planter_box(k, [G.herb_box], seg=0.31)


def build_flower_box(k):
    """Langer Blumenkasten am Boden mit drei Geranienpolstern – wie unter einem Fenster, nur auf dem Gehweg."""
    wood(k, OAK, slot="crate")
    bloom(k, (0.86, 0.2, 0.17))
    # die äußeren Polster wachsen breiter als ihr Abschnitt – an den Enden 4 cm mehr Platz
    _planter_box(k, [lambda p: G.box_geranium(p, "bloom")] * 3, ends=0.04)


def _lattice(b, x0, x1, z0, z1, y, step=0.15):
    """Rautengitter: Latten unter ±45°, auf das Rechteck zugeschnitten; die beiden Lagen liegen aufeinander (y ± 6 mm)."""
    for sign, yy in ((1, y - 0.006), (-1, y + 0.006)):
        c = (z0 - x1) if sign > 0 else (z0 + x0)
        end = (z1 - x0) if sign > 0 else (z1 + x1)
        c += step / 2
        while c < end:
            if sign > 0:   # z = x + c
                xa, xb = max(x0, z0 - c), min(x1, z1 - c)
            else:          # z = c - x
                xa, xb = max(x0, c - z1), min(x1, c - z0)
            if xb - xa > 0.03:
                pa = Vector((xa, yy, c + sign * xa))
                pb = Vector((xb, yy, c + sign * xb))
                b.span(pa, pb, 0.012, 0.022, step=0.3, dent=0.0004)
            c += step


def _trellis(k, kind, flower=None, plants=2):
    """Pflanzkasten mit Rankgitter: ein Holzkasten voll Erde (Rand ringsum), hinten zwei Pfosten mit Querleisten oben und
    unten, dazwischen ein Rautengitter; davor wächst die Kletterpflanze aus der Erde am Gitter hoch."""
    paint(k)
    k.mat("soil", (0.25, 0.17, 0.11), grain="stone", rough=0.95, vary=0.12, bump=0.4)
    W, D, H = 0.8, 0.4, 0.34
    box = k.part("Pflanzkasten", "paint", bevel=0.005)
    # Kasten wie in echt: Boden und vier Wände, innen bis 2 cm unter den Rand voll Erde (tief hängende Triebe liegen darin)
    box.box((0, 0, 0.02), (W - 0.03, D - 0.054, 0.04), step=0.3, dent=0.0006)
    for sy in (-1, 1):
        box.box((0, sy * (D / 2 - 0.0125), (H + 0.01) / 2), (W + 0.02, 0.025, H + 0.01), step=0.3, dent=0.0006)
    for sx in (-1, 1):
        box.box((sx * (W / 2 - 0.0025), 0, (H + 0.01) / 2), (0.025, D - 0.052, H + 0.01), step=0.3, dent=0.0006)
    soil = k.part("Erde", "soil", bevel=0.0, settle=False)
    soil.box((0, 0, (0.04 + H - 0.01) / 2), (W - 0.03, D - 0.054, H - 0.05), step=0.1, dent=0.003)
    ly, top = 0.12, 1.75
    lat = k.part("Rankgitter", "paint", bevel=0.003)
    for sx in (-1, 1):
        lat.box((sx * 0.37, ly, (H - 0.03 + top + 0.04) / 2), (0.04, 0.04, top + 0.04 - (H - 0.03)), step=0.3, dent=0.0006)
    lat.box((0, ly, top + 0.02), (W - 0.02, 0.05, 0.04), step=0.3, dent=0.0006)
    lat.box((0, ly, H + 0.06), (0.7, 0.03, 0.03), step=0.3, dent=0.0006)
    _lattice(lat, -0.35, 0.35, H + 0.075, top, ly)
    # zwei Pflanzen (links und rechts), damit das Gitter voll wird (die Kletterrose ist mit einer schon üppig); eine Ranke bleibt 10 cm vor ihrem Ursprung: so wächst
    # sie dicht vor dem Gitter, nicht durch die Latten
    spots = [(-0.17, 0.42), (0.17, 0.42)] if plants == 2 else [(0.0, W - 0.14)]
    for i, (x, width) in enumerate(spots):
        p = k.plant(None, seed_offset=i * 31)
        G.climber(p, width, 1.3, kind=kind, flower=flower)
        k.add_plant(p, (x, ly + 0.07, H - 0.01))
    k.collider((0, 0, H / 2), (W + 0.02, D, H))
    k.collider((0, ly, (H + top + 0.04) / 2), (W, 0.06, top + 0.04 - H))


def build_rose_trellis_box(k):
    """Kletterrose am Rankgitter im Pflanzkasten."""
    bloom(k, ROSES)
    _trellis(k, "rose", "bloom", plants=1)


def build_ivy_trellis(k):
    """Efeu am Rankgitter im Pflanzkasten – das ganze Jahr grün."""
    _trellis(k, "ivy")


def build_wisteria_trellis(k):
    """Glyzinie am Rankgitter im Pflanzkasten: helle Blätter und lange, hängende Blütentrauben."""
    bloom(k, WISTERIA)
    _trellis(k, "wisteria", "bloom")


# --- Laternen ---

def build_storm_lantern(k):
    """Sturmlaterne: Metallfuß mit Rand, Glaszylinder, gelochte Kappe, Drahtbügel und eine Kerze darin."""
    k.mat("metal", IRON_BLACK, grain="smooth", rough=0.5, metal=0.45, vary=0.05)
    k.mat("glass", (0.9, 0.95, 0.95), glass=True, rough=0.1, vary=0.0)
    k.mat("wax", (0.95, 0.92, 0.84), grain="smooth", rough=0.55, vary=0.03)
    m = k.part("Gestell", "metal", bevel=0.0)
    # Fuß: flache Schale, in der das Glas steht
    m.lathe([(0.0, 0.0), (0.085, 0.0), (0.088, 0.01), (0.075, 0.03), (0.07, 0.045), (0.064, 0.045), (0.064, 0.022), (0.0, 0.022)],
            (0, 0, 0), segs=28)
    # Kappe oben mit Rand und Knauf
    m.lathe([(0.0, 0.0), (0.066, 0.0), (0.07, 0.012), (0.05, 0.04), (0.02, 0.055), (0.0, 0.06)], (0, 0, 0.255), segs=28)
    # zwei Stangen vom Fuß zur Kappe (halten sie), Bügel oben
    for sx in (-1, 1):
        m.tube([(sx * 0.076, 0, 0.03), (sx * 0.076, 0, 0.262)], 0.004, segs=6, round_ends=True)
    m.tube([(-0.076, 0, 0.262)] + [(math.cos(math.radians(a)) * 0.076, 0, 0.262 + math.sin(math.radians(a)) * 0.09)
                                    for a in range(170, 9, -20)] + [(0.076, 0, 0.262)], 0.0035, segs=6, smooth=1)
    # Glaszylinder (Wand mit Innenseite), sitzt im Fuß und unter der Kappe
    glass = k.part("Glas", "glass", bevel=0.0)
    glass.lathe([(0.0, 0.03), (0.062, 0.03), (0.068, 0.12), (0.06, 0.255), (0.055, 0.255), (0.063, 0.12), (0.057, 0.035),
                 (0.0, 0.035)], (0, 0, 0), segs=28)
    F.candle(k, "wax", (0, 0, 0.035), 0.09, 0.024, drips=2, segs=14)
    k.light_kind = "flame"
    k.shadow = "none"
    k.light((0, 0, 0.15), energy=0.35, rng=2.2, shadow=False)
    k.collider((0, 0, 0.16), (0.18, 0.18, 0.32))


# --- Sitzplätze und Tischchen (Runde 2) ---

def bend(points, cut=0.04, n=4):
    """Polylinie mit runden Ecken: an jedem inneren Punkt ein kleiner Bogen (Länge cut zu jeder Seite), die geraden Stücke
    bleiben genau auf der Linie (Latten und Bretter, die daran sitzen, passen)."""
    pts = [Vector(p) for p in points]
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, c, b = pts[i - 1], pts[i], pts[i + 1]
        p0 = c + (a - c).normalized() * min(cut, (a - c).length * 0.45)
        p1 = c + (b - c).normalized() * min(cut, (b - c).length * 0.45)
        for j in range(n + 1):
            t = j / n
            out.append(p0 * (1 - t) ** 2 + c * 2 * t * (1 - t) + p1 * t * t)
    out.append(pts[-1])
    return out


def round_slats(b, radius, z0, thick, n, gap, step=0.3):
    """Runde Tischplatte aus n Latten (entlang x) mit schmalen Fugen; jede Latte ist ein eigener Körper (Umriss = Streifen
    im Kreis). radius = Kreis, z0 = Unterkante."""
    width = (2 * radius * 0.97 - (n - 1) * gap) / n
    y = -radius * 0.97
    for _ in range(n):
        y0, y1 = y, y + width
        y = y1 + gap

        def half(yy):
            return math.sqrt(max(radius * radius - yy * yy, 0.0))
        right = [(half(y0 + (y1 - y0) * j / 4), y0 + (y1 - y0) * j / 4) for j in range(5)]
        left = [(-x, yy) for x, yy in reversed(right)]
        b.slab(right + left, thick, Matrix.Translation((0, 0, z0)), dent=0.0005)


def build_park_bench(k):
    """Parkbank wie im Stadtpark: zwei Seitenteile aus Gusseisen (Vorderbein, das hintere Bein geht in die Lehne über,
    Armlehne mit Schnecke vorn, Bogen unter dem Sitz), dazu eine Zugstange; fünf Sitzlatten auf flachen Eisenschienen und
    vier Lehnlatten, die vorn auf den Lehnstützen sitzen."""
    wood(k, OAK, slot="slats")
    iron(k, (0.14, 0.16, 0.14))
    W, SEAT = 1.4, 0.3
    hw = W / 2 - 0.03
    r = 0.016
    fr = k.part("Gusseisen", "iron", bevel=0.0)
    back = bend([(0.2, r), (0.17, 0.15), (0.152, 0.28), (0.17, 0.45), (0.21, 0.6), (0.26, 0.75)], cut=0.03)
    for sx in (-1, 1):
        x = sx * hw
        fr.tube([(x, -0.19, r), (x, -0.205, 0.15), (x, -0.228, 0.3), (x, -0.235, 0.44), (x, -0.24, 0.484)], r, segs=10, smooth=2,
                round_ends=True)
        fr.tube([(x, y, z) for y, z in back], r, segs=10, round_ends=True)
        for y in (-0.19, 0.2):
            fr.lathe([(0.0, 0.0), (0.03, 0.0), (0.03, 0.008), (0.018, 0.02), (0.0, 0.024)], (x, y, 0), segs=12)
        # flache Schiene unter den Sitzlatten (vom Vorderbein bis zur Lehnstütze)
        fr.span((x, -0.215, SEAT - 0.0375), (x, 0.158, SEAT - 0.0375), 0.024, 0.025, step=0.3, dent=0.0)
        # Armlehne von der Lehnstütze nach vorn, vorn rollt sie sich nach unten ein
        fr.tube([(x, 0.19, 0.53), (x, -0.1, 0.515), (x, -0.25, 0.5), (x, -0.29, 0.475), (x, -0.295, 0.44), (x, -0.265, 0.425),
                 (x, -0.25, 0.445)], 0.014, segs=10, smooth=2, round_ends=True)
        # Bogen unter dem Sitz
        fr.tube([(x, -0.205, 0.1), (x, -0.1, 0.14), (x, 0.0, 0.152), (x, 0.1, 0.14), (x, 0.172, 0.1)], 0.011, segs=8, smooth=2,
                round_ends=True)
    fr.tube([(-hw, 0.0, 0.152), (hw, 0.0, 0.152)], 0.009, segs=8, round_ends=True)
    slats = k.part("Latten", "slats", bevel=0.005)
    for i in range(5):
        slats.box((0, -0.173 + i * 0.072, SEAT - 0.0125), (W, 0.062, 0.025), step=0.3, dent=0.0008)
    # Lehnlatten: vor der Lehnstütze, gekippt wie sie (über und unter der Armlehne, die hinten an der Stütze sitzt)
    for z in (0.38, 0.455, 0.6, 0.68):
        j = next(i for i in range(len(back) - 1) if back[i][1] <= z <= back[i + 1][1])
        (y0, z0), (y1, z1) = back[j], back[j + 1]
        y = y0 + (y1 - y0) * (z - z0) / (z1 - z0)
        phi = math.atan2(y1 - y0, z1 - z0)
        n = Vector((0, -math.cos(phi), math.sin(phi)))
        c = Vector((0, y, z)) + n * (r + 0.011)
        slats.box(c, (W, 0.022, 0.07), step=0.3, dent=0.0008, turn=(-math.degrees(phi), 0, 0))
    k.collider((0, -0.03, SEAT / 2), (W, 0.42, SEAT))
    k.collider((0, 0.2, 0.53), (W, 0.12, 0.46))
    for x in (-0.33, 0.33):
        k.seat((x, -0.05, SEAT), 0.0)
    k.surface((0, -0.04, SEAT), (W - 0.3, 0.3))
    k.interact = (Vector((0, -0.04, 0.42)), Vector((W, 0.44, 0.4)))


def build_folding_chair(k):
    """Klappstuhl (Bistro-Art): von der Seite ein X – außen geht das Bein vom Vorderfuß schräg nach hinten bis unter die
    Sitzkante und weiter als Lehne nach oben, innen das Bein vom Hinterfuß schräg nach vorn bis unter die Sitzvorderkante.
    Am Kreuz eine Niete (Drehpunkt), der Sitzrahmen liegt vorn auf, hinten ist er am Lehnbein. Holzlatten für Sitz und
    Lehne, je eine Querstange unten vorn und hinten."""
    iron(k)
    wood(k, OAK)
    SEAT = 0.3
    r = 0.011
    xa, xb = 0.205, 0.182
    zs = SEAT - 0.017 - r            # Mitte der Sitzrahmen-Rohre
    fr = k.part("Gestell", "iron", bevel=0.0)
    a_pts = [(-0.19, r), (0.13, zs), (0.2, 0.76)]
    b_pts = [(0.19, r), (-0.165, zs)]
    for sx in (-1, 1):
        fr.tube([(sx * xa, y, z) for y, z in bend(a_pts, cut=0.03)], r, segs=8, round_ends=True)
        fr.tube([(sx * xb, y, z) for y, z in b_pts], r, segs=8, round_ends=True)
        # Sitzrahmen seitlich (zwischen den beiden Beinen, berührt beide)
        fr.tube([(sx * 0.193, -0.172, zs), (sx * 0.193, 0.135, zs)], r, segs=8, round_ends=True)
    # Kreuzungspunkt der beiden Beine
    t = (0.19 + 0.19) / (0.32 + 0.355)
    py, pz = -0.19 + 0.32 * t, r + (zs - r) * t
    for sx in (-1, 1):
        fr.tube([(sx * (xb - 0.006), py, pz), (sx * (xa + 0.012), py, pz)], 0.0055, segs=8, round_ends=True)
    fr.tube([(-0.193, -0.172, zs), (0.193, -0.172, zs)], r, segs=8, round_ends=True)
    for (y0, z0), (y1, z1), x in ((a_pts[0], a_pts[1], xa), (b_pts[0], b_pts[1], xb)):
        u = 0.18
        fr.tube([(-x, y0 + (y1 - y0) * u, z0 + (z1 - z0) * u), (x, y0 + (y1 - y0) * u, z0 + (z1 - z0) * u)], 0.008, segs=8,
                round_ends=True)
    slats = k.part("Latten", "wood", bevel=0.004)
    for i in range(4):
        slats.box((0, -0.154 + i * 0.086, SEAT - 0.0085), (0.37, 0.072, 0.017), step=0.3, dent=0.0006)
    (y0, z0), (y1, z1) = a_pts[1], a_pts[2]
    phi = math.atan2(y1 - y0, z1 - z0)
    n = Vector((0, -math.cos(phi), math.sin(phi)))
    for z in (0.52, 0.64):
        y = y0 + (y1 - y0) * (z - z0) / (z1 - z0)
        slats.box(Vector((0, y, z)) + n * (r + 0.0085), (0.45, 0.017, 0.085), step=0.3, dent=0.0006,
                  turn=(-math.degrees(phi), 0, 0))
    k.collider((0, 0, SEAT / 2), (0.44, 0.4, SEAT))
    k.collider((0, 0.17, 0.53), (0.46, 0.08, 0.46))
    k.seat((0, -0.03, SEAT), 0.0)
    k.surface((0, -0.03, SEAT), (0.28, 0.2))
    k.interact = (Vector((0, 0, 0.42)), Vector((0.44, 0.4, 0.4)))


def build_folding_table(k):
    """Klapptisch passend zum Klappstuhl: zwei U-förmige Beingestelle, die sich von der Seite gesehen kreuzen (Nieten am
    Kreuz), oben je eine Querstange; darauf zwei Leisten und eine runde Platte aus sechs Holzlatten."""
    iron(k)
    wood(k, OAK)
    H, R = 0.5, 0.33
    r = 0.011
    zt = H - 0.024 - 0.02 - r         # Mitte der oberen Querstangen
    fr = k.part("Gestell", "iron", bevel=0.0)
    for x, (fy, ty) in ((0.215, (-0.24, 0.17)), (0.19, (0.24, -0.17))):
        for sx in (-1, 1):
            fr.tube([(sx * x, fy, r), (sx * x, ty, zt)], r, segs=8, round_ends=True)
        fr.tube([(-x - r * 0.5, ty, zt), (x + r * 0.5, ty, zt)], r, segs=8, round_ends=True)
    t = (0.24 + 0.24) / (0.41 + 0.41)     # dort kreuzen sich die Beine (y = 0)
    for sx in (-1, 1):
        fr.tube([(sx * (0.19 - 0.006), 0.0, r + (zt - r) * t), (sx * (0.215 + 0.012), 0.0, r + (zt - r) * t)], 0.0055, segs=8,
                round_ends=True)
    top = k.part("Platte", "wood", bevel=0.004)
    for x in (-0.13, 0.13):
        top.box((x, 0, zt + r + 0.01), (0.035, 0.52, 0.02), step=0.3, dent=0.0005)
    round_slats(top, R, H - 0.024, 0.024, 6, 0.008)
    k.collider((0, 0, H / 2), (2 * R, 2 * R, H))
    k.surface((0, 0, H), (1.35 * R, 1.35 * R))


def build_wood_stool(k):
    """Holzhocker: runde, an der Kante gerundete Sitzscheibe, drei gespreizte Beine (oben in der Scheibe verzapft) und drei
    Sprossen dazwischen."""
    paint(k)
    SEAT = 0.3
    b = k.part("Hocker", "paint", bevel=0.0)
    b.lathe([(0.0, SEAT - 0.035), (0.15, SEAT - 0.035), (0.16, SEAT - 0.025), (0.162, SEAT - 0.012), (0.155, SEAT - 0.002),
             (0.0, SEAT)], (0, 0, 0), segs=36, dent=0.0006)
    tops, feet = [], []
    for i in range(3):
        a = math.radians(90 + 120 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        top = d * 0.085 + Vector((0, 0, SEAT - 0.025))
        foot = d * 0.15 + Vector((0, 0, 0.0))
        F.tapered_leg(b, top, foot + Vector((0, 0, 0.014)), 0.018, 0.014)
        tops.append(top)
        feet.append(foot + Vector((0, 0, 0.014)))
    # Sprossen in drei Höhen (so treffen sich die Bohrungen im Bein nicht)
    for i in range(3):
        u = 0.62 + 0.08 * i
        b.tube([tops[i].lerp(feet[i], u), tops[(i + 1) % 3].lerp(feet[(i + 1) % 3], u)], 0.009, segs=8, round_ends=True)
    k.collider((0, 0, SEAT / 2), (0.32, 0.32, SEAT))
    k.seat((0, 0, SEAT), 0.0)
    k.surface((0, 0, SEAT), (0.2, 0.2))
    k.interact = (Vector((0, 0, 0.36)), Vector((0.34, 0.34, 0.3)))


def build_wood_table(k):
    """Kleiner Holztisch (passt zur Gartenbank): vier kantige Beine, Zargen ringsum (2 mm hinter den Beinkanten), oben sieben
    Latten mit schmalen Fugen."""
    paint(k)
    H, S = 0.5, 0.7
    b = k.part("Tisch", "paint", bevel=0.005)
    leg = 0.05
    lc = S / 2 - 0.065                 # Beinmitte
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * lc, sy * lc, (H - 0.024) / 2), (leg, leg, H - 0.024), step=0.3, dent=0.0006)
    ac = lc + leg / 2 - 0.011 - 0.004   # Zarge: Außenseite 4 mm hinter der Beinkante
    span_in = 2 * (lc - leg / 2)
    for sy in (-1, 1):
        b.box((0, sy * ac, H - 0.024 - 0.03), (span_in, 0.022, 0.06), step=0.3, dent=0.0006)
        b.box((sy * ac, 0, H - 0.024 - 0.03), (0.022, span_in, 0.06), step=0.3, dent=0.0006)
    n, gap = 7, 0.008
    w = (S - (n - 1) * gap) / n
    for i in range(n):
        b.box((0, -S / 2 + w / 2 + i * (w + gap), H - 0.012), (S, w, 0.024), step=0.3, dent=0.0006)
    k.collider((0, 0, H / 2), (S, S, H))
    k.surface((0, 0, H), (S - 0.04, S - 0.04))


def build_barrel_table(k):
    """Fass als Tisch: ein kleines Eichenfass aus 18 gewölbten Dauben (innen ein Kern, oben der eingelassene Boden), vier
    Eisenreifen; obenauf zwei Leisten und eine runde Platte aus vier Brettern."""
    wood(k, OAK)
    metal(k, (0.22, 0.22, 0.21))
    H, R0, bulge, t = 0.44, 0.2, 0.028, 0.02
    n = 18
    fass = k.part("Fass", "wood", bevel=0.002)

    def radius(z):
        return R0 + bulge * math.sin(math.pi * min(max(z / H, 0.0), 1.0))
    for i in range(n):
        faces = fass.box((0, R0 - t / 2, H / 2), (2 * math.pi * R0 / n - 0.0015, t, H), step=0.04, dent=0.0005)
        rot = Matrix.Rotation(2 * math.pi * i / n, 3, "Z")
        for v in {v for f in faces for v in f.verts}:
            x, y, z = v.co
            s = radius(z) / R0
            v.co = rot @ Vector((x * s, y * s, z))
    # Kern innen (oben der Fassboden, 2,5 cm unter dem Rand)
    prof = [(0.0, 0.012)] + [(radius(z) - t - 0.002, z) for z in (0.012, 0.1, H / 2, H - 0.1, H - 0.025)] + [(0.0, H - 0.025)]
    fass.lathe(prof, (0, 0, 0), segs=36)
    hoops = k.part("Reifen", "metal", bevel=0.0)
    for z in (0.04, 0.13, H - 0.13, H - 0.04):
        # Naht des Reifens mitten auf einer Daube (nicht an einer Fuge)
        F.ring(hoops, (0, 0, z), radius(z) + 0.001, 0.006, matrix=Matrix.Rotation(math.radians(10), 4, "Z"), n=48, segs=6)
    top = k.part("Platte", "wood", bevel=0.004)
    for x in (-0.12, 0.12):
        top.box((x, 0, H + 0.0125), (0.04, 0.4, 0.025), step=0.3, dent=0.0005)
    round_slats(top, 0.3, H + 0.025, 0.03, 4, 0.005)
    k.collider((0, 0, H / 2), (2 * (R0 + bulge), 2 * (R0 + bulge), H))
    k.collider((0, 0, H + 0.0275), (0.6, 0.6, 0.055))
    k.surface((0, 0, H + 0.055), (0.42, 0.42))


# --- Regale und Auslagen ---

def _crate(k, b, x, z, W=0.5, D=0.3, H=0.3, t=0.015):
    """Alte Obstkiste, auf die Seite gelegt (offen nach vorn, -y); x/z = Mitte der Unterkante. Je zwei Latten unten und
    oben (über die ganze Breite, auf die Kopfbretter genagelt), zwei dicke Kopfbretter, drei Latten als Rückwand.
    Kollision nur für die Bretter – innen bleibt frei, damit man die Bücher trifft."""
    e = 0.02
    for zz in (z + t / 2, z + H - t / 2):
        for y0, y1 in ((-D / 2, -0.012), (0.012, D / 2)):
            b.box((x, (y0 + y1) / 2, zz), (W, y1 - y0, t), step=0.3, dent=0.0008)
        k.collider((x, 0, zz), (W, D, t))
    # Rückwand: drei Latten (2 mm hinter den Enden der Bodenlatten)
    inner = H - 2 * t
    gap = 0.015
    h = (inner - 2 * gap) / 3
    yb = D / 2 - t / 2 - 0.002
    for i in range(3):
        b.box((x, yb, z + t + h / 2 + i * (h + gap)), (W - 0.004, t, h), step=0.3, dent=0.0008)
    k.collider((x, yb, z + H / 2), (W, t, inner))
    # Kopfbretter zwischen den Latten (2 mm nach innen versetzt)
    y0, y1 = -D / 2 + 0.002, yb - t / 2
    for sx in (-1, 1):
        b.box((x + sx * (W / 2 - e / 2 - 0.002), (y0 + y1) / 2, z + H / 2), (e, y1 - y0, inner), step=0.3, dent=0.0008)
        k.collider((x + sx * (W / 2 - e / 2), 0, z + H / 2), (e, D, inner))
    # Fach für Bücher (zwischen den Kopfbrettern, vor der Rückwand)
    k.row((x, (y0 + y1) / 2 - 0.004, z + t), W - 2 * e - 0.02, inner - 0.006, y1 - y0 - 0.02)


def build_book_crates(k):
    """Bücherkisten: drei alte Obstkisten auf der Seite, zwei unten, eine etwas versetzt obendrauf – offen nach vorn, die
    Bücher stehen darin. Oben und neben der oberen Kiste ist Platz für Töpfe und Deko."""
    wood(k, PINE, slot="crate")
    W, D, H = 0.5, 0.3, 0.3
    b = k.part("Kisten", "crate", bevel=0.003)
    top_x = 0.03
    for x, z in ((-0.255, 0.0), (0.255, 0.0), (top_x, H)):
        _crate(k, b, x, z, W, D, H)
    k.surface((top_x, 0, 2 * H), (W - 0.04, D - 0.04))
    # neben der oberen Kiste: links von -0,505 bis -0,22, rechts von 0,28 bis 0,505
    left = (-0.255 - W / 2, top_x - W / 2)
    right = (top_x + W / 2, 0.255 + W / 2)
    for a, c in (left, right):
        k.surface(((a + c) / 2, 0, H), (c - a - 0.04, D - 0.04))


def _wheel(k, center, radius, hub_len=0.09, spokes=8):
    """Holzrad mit Nabe, Speichen, Felge und Eisenreifen; die Achse läuft entlang y."""
    c = Vector(center)
    upright = Matrix.Rotation(math.pi / 2, 4, "X")   # Ring-Ebene x/z
    w = k.part("Rad", "wood", bevel=0.0)
    F.ring(w, c, radius - 0.024, 0.018, matrix=upright, n=40, segs=8)
    h = hub_len / 2
    w.lathe([(0.0, -h), (0.03, -h), (0.042, -h * 0.5), (0.042, h * 0.5), (0.03, h), (0.0, h)], c, segs=16, turn=(90, 0))
    for i in range(spokes):
        a = 2 * math.pi * i / spokes + 0.2
        d = Vector((math.cos(a), 0, math.sin(a)))
        w.tube([c + d * 0.034, c + d * (radius - 0.032)], 0.009, segs=6)
    # Reifen um eine halbe Teilung gedreht, damit seine Flächen nie genau auf denen der Felge liegen (Flimmern)
    tire = k.part("Reifen", "metal", bevel=0.0)
    F.ring(tire, c, radius - 0.007, 0.007, matrix=upright @ Matrix.Rotation(math.pi / 48, 4, "Z"), n=48, segs=6)


def build_book_barrow(k):
    """Bücherkarren wie bei den Bücherständen am Fluss: ein Holzkasten auf zwei Holmen, rechts zwei Speichenräder auf einer
    Eisenachse (in zwei Lagerklötzen), links zwei Beine (an die Holme geschraubt) und zwei Griffe. Im Kasten zwei Reihen
    Bücher, die hintere auf einer Stufe; die Vorderwand ist niedrig, damit man die Buchrücken sieht."""
    paint(k)
    wood(k, OAK)
    metal(k)
    R = 0.27
    ax = 0.3
    floor_z = 0.39            # Unterkante Kastenboden = Oberkante Holme
    L, D = 0.9, 0.42
    # Räder, Achse, Lagerklötze
    for sy in (-1, 1):
        _wheel(k, (ax, sy * 0.29, R + 0.001), R)
    m = k.part("Achse", "metal", bevel=0.0)
    m.tube([(ax, -0.345, R + 0.001), (ax, 0.345, R + 0.001)], 0.013, segs=10, round_ends=True)
    frame = k.part("Gestell", "wood", bevel=0.004)
    for sy in (-1, 1):
        y = sy * 0.15
        frame.box((ax, y, (R - 0.035 + floor_z - 0.05) / 2), (0.09, 0.06, floor_z - 0.05 - (R - 0.035)), step=0.3, dent=0.0006)
        # Holm unter dem Kasten, links als runder Griff weiter
        frame.span((0.47, y, floor_z - 0.025), (-0.53, y, floor_z - 0.025), 0.05, 0.05, step=0.3, dent=0.0006)
        frame.tube([(-0.51, y, floor_z - 0.025), (-0.7, y, floor_z - 0.012), (-0.86, y, floor_z - 0.005)], 0.021, segs=10,
                   smooth=1, round_ends=True)
        # Bein außen am Holm, oben unter dem Kastenboden
        frame.box((-0.38, sy * 0.195, floor_z / 2), (0.045, 0.04, floor_z), step=0.3, dent=0.0006)
    frame.span((-0.38, -0.175, 0.12), (-0.38, 0.175, 0.12), 0.035, 0.04, step=0.3, dent=0.0005)
    # Kasten: Boden, schräge Seitenwände, niedrige Vorderwand, hohe Rückwand, Stufe für die hintere Reihe
    box = k.part("Kasten", "paint", bevel=0.004)
    top_front, top_back = floor_z + 0.12, floor_z + 0.36
    box.box((0, 0, floor_z + 0.01), (L, D, 0.02), step=0.3, dent=0.0006)
    inner_z = floor_z + 0.02
    for x0 in (-L / 2, L / 2 - 0.02):
        box.slab([(-D / 2, inner_z), (D / 2, inner_z), (D / 2, top_back), (-D / 2, top_front)], 0.02, plane_yz(x0), dent=0.0006)
    iw = L - 0.042
    box.box((0, -D / 2 + 0.01, (inner_z + top_front) / 2), (iw, 0.02, top_front - inner_z), step=0.3, dent=0.0006)
    box.box((0, D / 2 - 0.01, (inner_z + top_back) / 2), (iw, 0.02, top_back - inner_z), step=0.3, dent=0.0006)
    step_z = inner_z + 0.1
    box.box((0, 0.1, step_z - 0.01), (iw, 0.18, 0.02), step=0.3, dent=0.0006)
    box.box((0, 0.0, (inner_z + step_z - 0.02) / 2), (iw, 0.02, step_z - 0.02 - inner_z), step=0.3, dent=0.0006)
    k.row((0, -0.1, inner_z), iw - 0.02, 0.3, 0.16)
    k.row((0, 0.1, step_z), iw - 0.02, 0.3, 0.16)
    # Kollision: Wände, Boden, Stufe, Räder, Beine und Griffe – innen frei für die Bücher
    k.collider((0, 0, floor_z + 0.01), (L, D, 0.02))
    k.collider((0, -D / 2 + 0.01, (inner_z + top_front) / 2), (L, 0.02, top_front - inner_z))
    k.collider((0, D / 2 - 0.01, (inner_z + top_back) / 2), (L, 0.02, top_back - inner_z))
    for sx in (-1, 1):
        k.collider((sx * (L / 2 - 0.01), 0, (inner_z + top_back) / 2), (0.02, D, top_back - inner_z))
    k.collider((0, 0.1, (inner_z + step_z) / 2), (iw, 0.2, step_z - inner_z))
    k.collider((ax, 0, R), (2 * R, 0.66, 2 * R))
    k.collider((-0.38, 0, floor_z / 2), (0.05, 0.43, floor_z))
    k.collider((-0.68, 0, floor_z - 0.02), (0.36, 0.35, 0.06))


def build_swap_library(k):
    """Bücherschrank zum Tauschen: ein Holzhäuschen mit Satteldach auf einem Pfosten. Der Pfosten steht in einem Kreuzfuß
    mit vier Streben (so braucht er kein Loch im Pflaster), oben trägt eine Platte den Kasten. Zwei Fächer, zwei
    Glastüren (stehen offen), unter dem Giebel ein Schild „Bücher zum Tauschen“."""
    paint(k)
    wood(k, OAK)
    metal(k)
    k.mat("roof", (0.55, 0.26, 0.2), grain="paint", rough=0.75, vary=0.08, bump=0.15)
    k.mat("glass", (0.9, 0.95, 0.95), glass=True, rough=0.1, vary=0.0)
    k.mat("sign", CREAM, grain="paint", rough=0.7, vary=0.04)
    k.mat("letters", (0.25, 0.2, 0.16), grain="smooth", rough=0.6, vary=0.02)
    W, D = 0.54, 0.34
    z0 = 0.86                       # Unterkante Kasten
    zi = z0 + 0.025                 # Oberkante Boden
    zt = 1.42                       # Unterkante Deckel
    zr = zt + 0.025                 # Oberkante Deckel = Traufe
    post = k.part("Pfosten", "wood", bevel=0.004)
    cross_foot(post, 0.56, 0.07, 0.04, 0.26)
    post.box((0, 0, z0 / 2), (0.08, 0.08, z0 - 0.03), step=0.3, dent=0.0006)
    post.box((0, 0, z0 - 0.015), (0.2, 0.2, 0.03), step=0.3, dent=0.0006)
    c = k.part("Häuschen", "paint", bevel=0.004)
    c.box((0, 0, z0 + 0.0125), (W, D, 0.025), step=0.3, dent=0.0006)
    for sx in (-1, 1):
        c.box((sx * (W / 2 - 0.01), 0, (zi + zt) / 2), (0.02, D, zt - zi), step=0.3, dent=0.0006)
    iw = W - 0.042
    c.box((0, D / 2 - 0.01, (zi + zt) / 2), (iw, 0.02, zt - zi), step=0.3, dent=0.0006)
    c.box((0, 0, zt + 0.0125), (W, D, 0.025), step=0.3, dent=0.0006)
    shelf_z = (zi + zt) / 2
    c.box((0, -0.008, shelf_z), (iw, D - 0.036, 0.02), step=0.3, dent=0.0006)
    # Giebel vorn und hinten, darüber das Dach (zwei Bretter, First-Leiste)
    pitch = math.radians(40)
    apex = zr + (W / 2) * math.tan(pitch)
    for y0 in (-D / 2 + 0.02, D / 2):
        c.slab([(-W / 2 + 0.004, 0.0), (W / 2 - 0.004, 0.0), (0.0, apex - zr - 0.004)], 0.02, plane_xz(y0, zr), dent=0.0004)
    roof = k.part("Dach", "roof", bevel=0.004)
    over = 0.06
    run = W / 2 + over
    ry = (-D / 2 - 0.06 + D / 2 + 0.03) / 2
    rd = D + 0.09
    t = 0.02
    for sx in (-1, 1):
        n = Vector((sx * math.sin(pitch), 0, math.cos(pitch)))
        a = Vector((0, ry, apex)) + n * t / 2
        b = Vector((sx * run, ry, apex - run * math.tan(pitch))) + n * t / 2
        roof.span(a, b, rd, t, step=0.3, dent=0.0006)
    roof.tube([(0, ry - rd / 2 - 0.004, apex + 0.02), (0, ry + rd / 2 + 0.004, apex + 0.02)], 0.022, segs=10, round_ends=True)
    # Schild unter dem Giebel
    sign = k.part("Schild", "sign", bevel=0.003)
    sz0, sz1 = zr + 0.006, zr + 0.08
    sign.box((0, -D / 2 - 0.006, (sz0 + sz1) / 2), (0.3, 0.012, sz1 - sz0), step=0.3, dent=0.0004)
    letters = k.part("Schrift", "letters", bevel=0.0)
    front_text(letters, "Bücher", 0.03, 0, -D / 2 - 0.012, sz0 + 0.04)
    front_text(letters, "zum Tauschen", 0.02, 0, -D / 2 - 0.012, sz0 + 0.012)
    # Zwei Flügeltüren: Rahmen mit Glas, außen angeschlagen, je 100° offen (so steht der Schrank nur gut 70 cm tief);
    # die Scharniere bleiben am Drehpunkt, ein Lappen sitzt auf der Seitenwand
    open_deg = 100.0
    dz0, dz1 = z0 + 0.005, zt - 0.01
    yd = -D / 2 - 0.011
    dw, bar = W / 2 - 0.001, 0.04
    door = k.part("Türen", "paint", bevel=0.003)
    glass = k.part("Glas", "glass", bevel=0.0)
    hw = k.part("Beschläge", "metal", bevel=0.0)
    doors = []
    for sx in (-1, 1):
        hinge = Vector((sx * W / 2, yd, 0))
        turn = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(sx * open_deg), 4, "Z") @ Matrix.Translation(-hinge)
        mid = sx * (W / 4 + 0.0005)
        for x in (sx * (0.001 + bar / 2), sx * (W / 2 - bar / 2)):
            door.box((x, yd, (dz0 + dz1) / 2), (bar, 0.022, dz1 - dz0), step=0.3, dent=0.0004, matrix=turn)
        for z in (dz0 + bar / 2, dz1 - bar / 2):
            door.box((mid, yd, z), (dw - 2 * bar - 0.002, 0.022, bar), step=0.3, dent=0.0004, matrix=turn)
        door.box((mid, yd, (dz0 + dz1) / 2), (dw - 2 * bar - 0.002, 0.014, 0.02), step=0.3, dent=0.0004, matrix=turn)
        for z0_, z1_ in ((dz0 + bar - 0.006, (dz0 + dz1) / 2 - 0.004), ((dz0 + dz1) / 2 + 0.004, dz1 - bar + 0.006)):
            glass.box((mid, yd, (z0_ + z1_) / 2), (dw - 2 * bar + 0.01, 0.004, z1_ - z0_), step=0.5, dent=0.0, matrix=turn)
        F.knob(hw, turn @ Vector((sx * 0.024, yd - 0.011, (dz0 + dz1) / 2)), r=0.01, normal=(turn.to_3x3() @ Vector((0, -1, 0))))
        for z in (dz0 + 0.07, dz1 - 0.07):
            hw.tube([(sx * (W / 2 + 0.004), yd, z - 0.03), (sx * (W / 2 + 0.004), yd, z + 0.03)], 0.006, segs=8, round_ends=True)
            hw.box((sx * (W / 2 + 0.0015), (yd - D / 2 + 0.025) / 2, z), (0.003, -D / 2 + 0.025 - yd, 0.05), step=0.5, dent=0.0)
        doors.append((turn @ Vector((mid, yd, (dz0 + dz1) / 2)), sx * open_deg))
    # Fächer, Kollision
    k.row((0, -0.012, zi), iw - 0.02, shelf_z - 0.01 - zi - 0.005, D - 0.06)
    k.row((0, -0.012, shelf_z + 0.01), iw - 0.02, zt - shelf_z - 0.01 - 0.005, D - 0.06)
    k.collider((0, 0, z0 / 2), (0.1, 0.1, z0))
    k.collider((0, 0, 0.035), (0.56, 0.07, 0.07))
    k.collider((0, 0, 0.035), (0.07, 0.56, 0.07))
    k.collider((0, 0, z0 + 0.0125), (W, D, 0.025))
    for sx in (-1, 1):
        k.collider((sx * (W / 2 - 0.01), 0, (zi + zt) / 2), (0.02, D, zt - zi))
    k.collider((0, D / 2 - 0.01, (zi + zt) / 2), (iw, 0.02, zt - zi))
    k.collider((0, 0, shelf_z), (iw, D - 0.036, 0.02))
    k.collider((0, -0.015, (zt + apex) / 2 + 0.02), (W + 2 * over, D + 0.09, apex - zt + 0.04))
    for center, deg in doors:
        k.collider(center, (dw, 0.022, dz1 - dz0), turn=deg)


def build_plant_stairs(k):
    """Pflanzentreppe: zwei ausgesägte Seitenbretter in Treppenform (unten mit Bogen, so steht sie auf vier Füßen), drei
    Trittbretter darauf, hinten und vorn je eine Querleiste. Für Töpfe, Laternen und ein paar Bücher."""
    paint(k)
    b = k.part("Seiten", "paint", bevel=0.003)
    side = [(-0.27, 0.0), (-0.19, 0.0), (-0.165, 0.055), (-0.1, 0.095), (0.0, 0.11), (0.08, 0.095), (0.135, 0.055),
            (0.16, 0.0), (0.24, 0.0), (0.24, 0.64), (0.07, 0.64), (0.07, 0.42), (-0.1, 0.42), (-0.1, 0.2), (-0.27, 0.2)]
    for x0 in (-0.375, 0.35):
        b.slab(side, 0.025, plane_yz(x0), dent=0.0005)
    t = k.part("Bretter", "paint", bevel=0.004)
    steps = [(-0.29, -0.1, 0.2), (-0.12, 0.07, 0.42), (0.05, 0.238, 0.64)]
    for y0, y1, z in steps:
        t.box((0, (y0 + y1) / 2, z + 0.011), (0.746, y1 - y0, 0.022), step=0.3, dent=0.0006)
        k.collider((0, (y0 + y1) / 2, (z + 0.022) / 2), (0.75, y1 - y0, z + 0.022))
    t.box((0, 0.226, 0.3), (0.7, 0.024, 0.08), step=0.3, dent=0.0006)
    t.box((0, -0.25, 0.14), (0.7, 0.02, 0.06), step=0.3, dent=0.0006)
    k.surface((0, -0.2, 0.222), (0.7, 0.16))
    k.surface((0, -0.035, 0.442), (0.7, 0.15))
    k.surface((0, 0.145, 0.662), (0.7, 0.17))


def build_etagere(k):
    """Blumen-Etagere aus Metall: drei Beine, die nach oben zusammenlaufen, mit drei runden Schalen (unten groß, oben klein),
    an deren Rand die Beine angeschweißt sind; oben enden die Beine mit Kugeln, unten stehen sie auf kleinen Füßen."""
    iron(k)
    b = k.part("Etagere", "iron", bevel=0.0)
    top = 0.82
    r0, r1 = 0.26, 0.12
    leg_r = 0.009

    def radius(z):
        return r0 + (r1 - r0) * z / top
    for i in range(3):
        a = math.radians(90 + 120 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        b.tube([d * radius(0.012) + Vector((0, 0, 0.012)), d * radius(top) + Vector((0, 0, top))], leg_r, segs=8, round_ends=True)
        b.lathe([(0.0, 0.0), (0.014, 0.0), (0.016, 0.01), (0.011, 0.022), (0.0, 0.026)], d * radius(0.012), segs=12)
        b.lathe([(0.0, -0.004), (0.012, 0.004), (0.015, 0.016), (0.01, 0.028), (0.0, 0.031)], d * radius(top) + Vector((0, 0, top)), segs=12)
    for z in (0.1, 0.4, 0.7):
        rim = radius(z + 0.03) - leg_r
        b.lathe([(0.0, z), (rim * 0.94, z), (rim, z + 0.03), (rim - 0.005, z + 0.03), (rim * 0.94 - 0.005, z + 0.006), (0.0, z + 0.006)],
                (0, 0, 0), segs=40)
        F.ring(b, (0, 0, z + 0.03), rim - 0.002, 0.005, n=48, segs=6)
        side = rim * 1.25
        k.surface((0, 0, z + 0.006), (side, side), max_height=0.28 if z < 0.6 else 0.0)
        k.collider((0, 0, z + 0.015), (2 * rim, 2 * rim, 0.03))
    k.collider((0, 0, top / 2), (0.06, 0.06, top))


# --- Schilder und Aufsteller ---

def _arrow(length, height, tail, left=True):
    """Umriss eines Pfeilschilds (Spitze, gerade Kanten, Schwalbenschwanz am Ende), gegen den Uhrzeigersinn."""
    h = height / 2
    head = h * 1.3
    pts = [(-length + tail, 0.0), (-length + tail + head, -h), (tail, -h), (tail - h * 0.6, 0.0), (tail, h), (-length + tail + head, h)]
    if not left:
        pts = [(-x, y) for x, y in reversed(pts)]
    return pts


def build_signpost(k):
    """Wegweiser: ein Holzpfosten mit Kappe im Kreuzfuß, vorn drei Pfeilschilder (angeschraubt, die Schrauben sieht man):
    „Bücherei“, „Lesegarten“, „Teestube“."""
    k.mat("sign", SIGNS[0][2], grain="paint", rough=0.7, vary=0.06, bump=0.1)
    wood(k, OAK)
    metal(k)
    k.mat("letters", LETTERS, grain="smooth", rough=0.6, vary=0.02)
    post = k.part("Pfosten", "wood", bevel=0.004)
    cross_foot(post, 0.5, 0.06, 0.035, 0.24)
    H = 1.36
    post.box((0, 0, H / 2), (0.07, 0.07, H), step=0.3, dent=0.0006)
    post.lathe([(0.0, 0.0), (0.055, 0.0), (0.055, 0.012), (0.0, 0.07)], (0, 0, H), segs=4, spin=45)
    s = k.part("Schilder", "sign", bevel=0.003)
    letters = k.part("Schrift", "letters", bevel=0.0)
    screws = k.part("Schrauben", "metal", bevel=0.0)
    y_front = -0.035 - 0.02
    for z, text, left in ((1.22, "Bücherei", True), (1.06, "Lesegarten", False), (0.9, "Teestube", True)):
        s.slab(_arrow(0.5, 0.1, 0.1, left), 0.02, plane_xz(-0.035, z), dent=0.0004)
        mid = -0.15 if left else 0.15
        front_text(letters, text, 0.042, mid, y_front, z - 0.016)
        for dz in (-0.025, 0.025):
            screws.lathe([(0.0, 0.0), (0.008, 0.0), (0.006, 0.003), (0.0, 0.004)], (0, y_front + 0.001, z + dz), segs=8, turn=(90, 0))
        k.collider((mid, -0.045, z), (0.5, 0.02, 0.1))
    k.collider((0, 0, H / 2), (0.08, 0.08, H))
    k.collider((0, 0, 0.03), (0.5, 0.06, 0.06))
    k.collider((0, 0, 0.03), (0.06, 0.5, 0.06))


def build_hanging_sign(k):
    """Schild am Ständer: ein Eisenständer auf vier geschwungenen Füßen (einer unter dem Schild) mit Kugel oben, ein Ausleger mit Schnecke und
    kleiner Strebe; daran hängt an zwei kurzen Ketten (drei Glieder, das unterste durch ein Loch im Brett) ein Holzschild
    „Willkommen – in der Bücherei“, beidseitig beschriftet."""
    metal(k)
    k.mat("sign", SIGNS[0][2], grain="paint", rough=0.7, vary=0.06, bump=0.1)
    k.mat("letters", LETTERS, grain="smooth", rough=0.6, vary=0.02)
    st = k.part("Ständer", "metal", bevel=0.0)
    # ein Fuß zeigt unter das Schild (sonst würde der Ständer in echt nach rechts kippen)
    for i in range(4):
        a = math.radians(90 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        st.tube([d * 0.015 + Vector((0, 0, 0.1)), d * 0.14 + Vector((0, 0, 0.065)), d * 0.29 + Vector((0, 0, 0.012))], 0.012, segs=8,
                smooth=2, round_ends=True)
    st.lathe([(0.0, 0.05), (0.03, 0.05), (0.034, 0.09), (0.022, 0.14), (0.0, 0.14)], (0, 0, 0), segs=16)
    top = 1.34
    st.tube([(0, 0, 0.12), (0, 0, top)], 0.016, segs=10)
    st.lathe([(0.0, -0.004), (0.02, 0.006), (0.026, 0.026), (0.016, 0.046), (0.0, 0.05)], (0, 0, top), segs=14)
    arm_z, arm_r = 1.22, 0.011
    arm_end = 0.66
    # Ausleger mit Schnecke am Ende (rollt sich nach unten ein) – ein einziger Stab, damit sich nichts doppelt
    curl = [(0.0, 0, arm_z), (arm_end * 0.5, 0, arm_z)]
    for i in range(29):
        u = i / 28
        a = u * 2 * math.pi * 1.15
        rr = 0.04 * (1 - 0.6 * u)
        curl.append((arm_end + rr * math.sin(a), 0, arm_z - 0.04 + rr * math.cos(a)))
    st.tube(curl, arm_r, segs=8, smooth=1, round_ends=True)
    # Strebe vom Pfosten zum Ausleger (sanfter Bogen)
    brace = [Vector((0.012, 0, arm_z - 0.17)), Vector((0.05, 0, arm_z - 0.09)), Vector((0.1, 0, arm_z - 0.035)),
             Vector((0.15, 0, arm_z))]
    st.tube(brace, 0.008, segs=8, smooth=2, round_ends=True)
    # Ketten: je drei Glieder (oben um den Ausleger, unten durch das Schild)
    chain = k.part("Ketten", "metal", bevel=0.0)
    lr, wr = 0.016, 0.0035
    in_yz = Matrix.Rotation(math.pi / 2, 4, "Y")
    in_xz = Matrix.Rotation(math.pi / 2, 4, "X")
    z1 = arm_z + arm_r + wr - lr - 0.003     # oberes Glied liegt auf dem Ausleger (3 mm hinein, nie fast tangential)
    link = 2 * lr - 2 * wr + 0.001            # Abstand der Glieder: jedes liegt auf dem nächsten (1 mm hinein)
    zs = [z1, z1 - link, z1 - 2 * link]
    sign_x0, sign_x1 = 0.16, 0.6
    for x in (sign_x0 + 0.05, sign_x1 - 0.05):
        for i, z in enumerate(zs):
            F.ring(chain, (x, 0, z), lr, wr, matrix=in_xz if i == 1 else in_yz, n=24, segs=8)
    hole_z = zs[2] - lr + wr
    top_z = hole_z + 0.014
    h = 0.27
    # Schild: Brett mit abgerundeten Ecken, beidseitig beschriftet
    sign = k.part("Schild", "sign", bevel=0.004)
    w = sign_x1 - sign_x0
    cr = 0.04
    outline = []
    for cx, cz, a0 in ((w / 2 - cr, -h / 2 + cr, -90), (w / 2 - cr, h / 2 - cr, 0), (-w / 2 + cr, h / 2 - cr, 90), (-w / 2 + cr, -h / 2 + cr, 180)):
        for j in range(7):
            a = math.radians(a0 + 90 * j / 6)
            outline.append((cx + cr * math.cos(a), cz + cr * math.sin(a)))
    t = 0.024
    mid_x, mid_z = (sign_x0 + sign_x1) / 2, top_z - h / 2
    sign.slab(outline, t, plane_xz(t / 2, mid_z, mid_x), dent=0.0004)
    letters = k.part("Schrift", "letters", bevel=0.0)
    for back in (False, True):
        y_face = t / 2 if back else -t / 2
        front_text(letters, "Willkommen", 0.052, mid_x, y_face, mid_z + 0.0, back=back)
        front_text(letters, "in der Bücherei", 0.03, mid_x, y_face, mid_z - 0.065, back=back)
    k.collider((0, 0, top / 2), (0.05, 0.05, top))
    k.collider((0, 0, 0.05), (0.6, 0.6, 0.1))
    k.collider((arm_end / 2, 0, arm_z), (arm_end + 0.06, 0.03, 0.1))
    k.collider((mid_x, 0, mid_z), (w, t, h))


def flower_variants(slot):
    return [("red", "Rot", {slot: (0.86, 0.2, 0.17)}), ("pink", "Rosa", {slot: (0.93, 0.52, 0.62)}),
            ("white", "Weiß", {slot: (0.95, 0.94, 0.9)}), ("coral", "Koralle", {slot: (0.95, 0.45, 0.38)})]


LANTERN_COLORS = [("black", "Schwarz", {"metal": IRON_BLACK}), ("green", "Altgrün", {"metal": (0.28, 0.3, 0.27)}),
                  ("cream", "Creme", {"metal": CREAM}), ("brass", "Messing", {"metal": (0.72, 0.56, 0.3)})]

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
    dict(id="out_small_lavender", name="Kleiner Lavendeltopf", category="outdoor", sub="outdoor_plant", price=8,
         desc="Ein kleiner Topf Lavendel – passt auch auf eine Stufe der Treppe.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_small_lavender, variants=variants("pot", POTS)),
    dict(id="out_small_geranium", name="Kleiner Geranientopf", category="outdoor", sub="outdoor_plant", price=7,
         desc="Eine Geranie im kleinen Tontopf – passt auch auf eine Stufe der Treppe.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_small_geranium,
         variants=flower_variants("red")),
    dict(id="out_small_heather", name="Heidekraut", category="outdoor", sub="outdoor_plant", price=7,
         desc="Heidekraut im kleinen Topf – blüht bis tief in den Herbst.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_small_heather,
         variants=[("magenta", "Pink", {"magenta_flower": (0.78, 0.24, 0.5)}), ("purple", "Lila", {"magenta_flower": (0.55, 0.32, 0.62)}),
                   ("white", "Weiß", {"magenta_flower": (0.95, 0.94, 0.9)}), ("rose", "Rosa", {"magenta_flower": (0.93, 0.6, 0.7)})]),
    dict(id="out_small_boxball", name="Kleine Buchsbaumkugel", category="outdoor", sub="outdoor_plant", price=10,
         desc="Eine kleine Buchsbaumkugel im Topf – passt auch auf eine Stufe der Treppe.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_small_boxball, variants=variants("pot", POTS)),
    dict(id="out_lantern_candle", name="Laterne mit Kerze", category="outdoor", sub="outdoor_light", price=22,
         desc="Eine kleine Laterne mit Glasscheiben und Kerze – schön auf der Treppe, wenn es dunkel wird.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=FC.build_lantern, variants=LANTERN_COLORS),
    dict(id="out_storm_lantern", name="Sturmlaterne", category="outdoor", sub="outdoor_light", price=18,
         desc="Eine Sturmlaterne mit Glaszylinder und Drahtbügel – die Kerze flackert auch bei Wind.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_storm_lantern, variants=LANTERN_COLORS),
    # Pflanzen (Runde 3)
    dict(id="out_tulip_pot", name="Tulpen im Topf", category="outdoor", sub="outdoor_plant", price=9,
         desc="Ein kleiner Topf voller Tulpen – passt auch auf eine Stufe der Treppe.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_tulip_pot, variants=variants("bloom", TULIPS)),
    dict(id="out_rosemary_pot", name="Rosmarin", category="outdoor", sub="outdoor_plant", price=8,
         desc="Rosmarin im kleinen Tontopf – duftet, wenn man vorbeistreift.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_rosemary_pot, variants=variants("pot", POTS)),
    dict(id="out_marguerite_bucket", name="Margeriten im Eimer", category="outdoor", sub="outdoor_plant", price=18,
         desc="Weiße Margeriten in einem Emailleeimer mit Henkel.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_marguerite_bucket, variants=variants("pot", ZINC)),
    dict(id="out_dahlia_pot", name="Dahlien", category="outdoor", sub="outdoor_plant", price=20,
         desc="Dahlien mit runden, gefüllten Blüten im Tontopf.",
         styles=STYLE, place="floor", attach_feet=False, build=build_dahlia_pot, variants=variants("bloom", DAHLIAS)),
    dict(id="out_hosta_bowl", name="Funkie in der Schale", category="outdoor", sub="outdoor_plant", price=19,
         desc="Große, blaugrüne Herzblätter in einer flachen Schale – mag den Schatten.",
         styles=STYLE, place="floor", attach_feet=False, build=build_hosta_bowl, variants=variants("pot", POTS)),
    dict(id="out_fern_bucket", name="Farn im Zinkeimer", category="outdoor", sub="outdoor_plant", price=17,
         desc="Ein üppiger Farn in einem alten Zinkeimer.",
         styles=STYLE, place="floor", attach_feet=False, build=build_fern_bucket, variants=variants("pot", ZINC)),
    dict(id="out_herb_crate", name="Kräuterkiste", category="outdoor", sub="outdoor_plant", price=24,
         desc="Ein Holzkasten mit Rosmarin, Thymian und Basilikum.",
         styles=STYLE, place=["floor", "surface"], attach_feet=False, build=build_herb_crate, variants=variants("crate", CRATES)),
    dict(id="out_rose_bush", name="Rosenbusch", category="outdoor", sub="outdoor_plant", price=34,
         desc="Ein Rosenbusch im Holzkübel – blüht den ganzen Sommer.",
         styles=STYLE, place="floor", attach_feet=False, build=build_rose_bush, variants=variants("bloom", ROSES)),
    dict(id="out_box_cone", name="Buchskegel", category="outdoor", sub="outdoor_plant", price=30,
         desc="Ein streng geschnittener Buchs in Kegelform im bauchigen Topf.",
         styles=STYLE, place="floor", attach_feet=False, build=build_box_cone, variants=variants("pot", POTS)),
    dict(id="out_bay_standard", name="Lorbeerstämmchen", category="outdoor", sub="outdoor_plant", price=42,
         desc="Eine dunkelgrüne Lorbeerkugel auf einem geraden Stamm – rechts und links der Tür sehr elegant.",
         styles=STYLE, place="floor", attach_feet=False, build=build_bay_standard, variants=variants("pot", POTS)),
    dict(id="out_grass_pot", name="Ziergras", category="outdoor", sub="outdoor_plant", price=26,
         desc="Ein hohes Ziergras mit weichen Rispen, das sich im Wind wiegt.",
         styles=STYLE, place="floor", attach_feet=False, build=build_grass_pot, variants=variants("bloom", PLUMES)),
    dict(id="out_sunflower_bucket", name="Sonnenblumen", category="outdoor", sub="outdoor_plant", price=22,
         desc="Fünf Sonnenblumen im Zinkeimer – sie schauen zur Sonne.",
         styles=STYLE, place="floor", attach_feet=False, build=build_sunflower_bucket, variants=variants("pot", ZINC)),
    dict(id="out_hollyhock_pot", name="Stockrosen", category="outdoor", sub="outdoor_plant", price=28,
         desc="Hohe Stockrosen voller Blüten im großen Tontopf – am schönsten an der Hauswand.",
         styles=STYLE, place="floor", attach_feet=False, build=build_hollyhock_pot, variants=variants("bloom", HOLLYHOCKS)),
    dict(id="out_flower_box", name="Blumenkasten mit Geranien", category="outdoor", sub="outdoor_plant", price=38,
         desc="Ein langer Holzkasten mit drei Geranienpolstern.",
         styles=STYLE, place="floor", attach_feet=False, build=build_flower_box, variants=flower_variants("bloom")),
    dict(id="out_rose_trellis", name="Kletterrose am Rankgitter", category="outdoor", sub="outdoor_plant", price=85,
         desc="Ein Pflanzkasten mit Rankgitter, an dem eine Kletterrose hochwächst.",
         styles=STYLE, place="floor", attach_feet=False, build=build_rose_trellis_box, variants=variants("bloom", ROSES)),
    dict(id="out_ivy_trellis", name="Efeu am Rankgitter", category="outdoor", sub="outdoor_plant", price=70,
         desc="Ein Pflanzkasten mit Rankgitter voller Efeu – das ganze Jahr grün.",
         styles=STYLE, place="floor", attach_feet=False, build=build_ivy_trellis, variants=variants("paint", PAINTS)),
    dict(id="out_wisteria_trellis", name="Glyzinie am Rankgitter", category="outdoor", sub="outdoor_plant", price=90,
         desc="Ein Pflanzkasten mit Rankgitter und einer Glyzinie mit langen, hängenden Blütentrauben.",
         styles=STYLE, place="floor", attach_feet=False, build=build_wisteria_trellis, variants=variants("bloom", WISTERIA)),
    # Sitzplätze und Tischchen (Runde 2)
    dict(id="out_park_bench", name="Parkbank", category="outdoor", sub="outdoor_seat", price=120,
         desc="Eine Bank wie im Stadtpark: Seitenteile aus Gusseisen mit Schnecken, dazu Holzlatten.",
         styles=STYLE, place="floor", low_seat=False, attach_feet=False, build=build_park_bench,
         variants=variants("slats", SLATS)),
    dict(id="out_garden_chair", name="Gartenstuhl", category="outdoor", sub="outdoor_seat", price=55,
         desc="Ein gestrichener Holzstuhl mit Armlehnen – passt zur Gartenbank.",
         styles=STYLE, place="floor", low_seat=False, attach_feet=False, build=build_garden_chair,
         variants=variants("paint", PAINTS)),
    dict(id="out_folding_chair", name="Klappstuhl", category="outdoor", sub="outdoor_seat", price=32,
         desc="Ein Bistro-Klappstuhl aus Metall mit Holzlatten – schnell aufgestellt, wenn die Sonne scheint.",
         styles=STYLE, place="floor", low_seat=False, attach_feet=False, build=build_folding_chair,
         variants=variants("iron", IRONS)),
    dict(id="out_wood_stool", name="Holzhocker", category="outdoor", sub="outdoor_seat", price=22,
         desc="Ein kleiner Hocker mit drei Beinen – zum Sitzen oder als Platz für einen Topf.",
         styles=STYLE, place="floor", low_seat=False, attach_feet=False, build=build_wood_stool,
         variants=variants("paint", PAINTS)),
    dict(id="out_folding_table", name="Klapptisch", category="outdoor", sub="outdoor_table", price=40,
         desc="Ein runder Klapptisch mit Holzlatten – passt zum Klappstuhl.",
         styles=STYLE, place="floor", attach_feet=False, build=build_folding_table, variants=variants("iron", IRONS)),
    dict(id="out_wood_table", name="Kleiner Holztisch", category="outdoor", sub="outdoor_table", price=60,
         desc="Ein quadratischer Gartentisch aus gestrichenem Holz – passt zur Gartenbank.",
         styles=STYLE, place="floor", attach_feet=False, build=build_wood_table, variants=variants("paint", PAINTS)),
    dict(id="out_barrel_table", name="Fass als Tisch", category="outdoor", sub="outdoor_table", price=50,
         desc="Ein altes Eichenfass mit Eisenreifen und einer runden Holzplatte obendrauf.",
         styles=STYLE, place="floor", attach_feet=False, build=build_barrel_table, variants=variants("wood", WOODS)),
    # Regale und Auslagen (Bücher stehen in den Fächern, Deko und Töpfe auf den Flächen)
    dict(id="out_book_crates", name="Bücherkisten", category="outdoor", sub="outdoor_shelf", price=40,
         desc="Drei alte Obstkisten, auf die Seite gelegt und gestapelt – ein Regal für Bücher, oben Platz für Töpfe.",
         styles=STYLE, place="floor", attach_feet=False, build=build_book_crates, variants=variants("crate", CRATES)),
    dict(id="out_book_barrow", name="Bücherkarren", category="outdoor", sub="outdoor_shelf", price=110,
         desc="Ein Holzkarren mit Speichenrädern wie bei den Bücherständen am Fluss – zwei Reihen Bücher zum Stöbern.",
         styles=STYLE, place="floor", attach_feet=False, build=build_book_barrow, variants=variants("paint", PAINTS)),
    dict(id="out_swap_library", name="Bücherschrank zum Tauschen", category="outdoor", sub="outdoor_shelf", price=90,
         desc="Ein Holzhäuschen auf einem Pfosten mit Glastür: Nimm ein Buch, bring ein Buch.",
         styles=STYLE, place="floor", attach_feet=False, build=build_swap_library, variants=variants("paint", PAINTS)),
    dict(id="out_plant_stairs", name="Pflanzentreppe", category="outdoor", sub="outdoor_shelf", price=55,
         desc="Drei Stufen aus Holz für Töpfe, Laternen und ein paar Bücher.",
         styles=STYLE, place="floor", attach_feet=False, build=build_plant_stairs, variants=variants("paint", PAINTS)),
    dict(id="out_etagere", name="Blumen-Etagere", category="outdoor", sub="outdoor_shelf", price=48,
         desc="Drei runde Schalen übereinander an einem Eisengestell – für kleine Töpfe und Laternen.",
         styles=STYLE, place="floor", attach_feet=False, build=build_etagere, variants=variants("iron", IRONS)),
    # Schilder
    dict(id="out_signpost", name="Wegweiser", category="outdoor", sub="outdoor_sign", price=45,
         desc="Ein Holzpfosten mit drei Pfeilen: Bücherei, Lesegarten, Teestube.",
         styles=STYLE, place="floor", attach_feet=False, build=build_signpost, variants=variants("sign", SIGNS)),
    dict(id="out_hanging_sign", name="Schild am Ständer", category="outdoor", sub="outdoor_sign", price=50,
         desc="Ein Eisenständer mit einem Holzschild an kurzen Ketten: „Willkommen in der Bücherei“.",
         styles=STYLE, place="floor", attach_feet=False, build=build_hanging_sign, variants=variants("sign", SIGNS)),
]
