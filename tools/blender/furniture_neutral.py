"""Stilneutral: praktische, schlichte Dinge, die zu jedem Stil passen (Etappe 6) – Buch-Aufsteller,
Bücherstapel, Buchstützen, Lichtschalter, Bücherwagen, Tritt, Pouf, Deko-Regal, Schirmständer,
Garderobe, Wanduhr, Pflanzen in Terrakotta, Kerze im Glas, Gießkanne, Bilderrahmen, Türschild.
Jedes Objekt: Beschreibung + Bau-Funktion (storybook_furniture, Vorderseite -y). Kein Stil-Merkmal.
"""

import math
import random

from mathutils import Matrix, Vector

import storybook_furniture as F
import storybook_greenery as G

STYLE = []
BEECH = (0.8, 0.64, 0.46)
OAK_MID = (0.66, 0.48, 0.3)
WALNUT = (0.42, 0.28, 0.18)
WHITE = (0.93, 0.91, 0.86)
TERRA = (0.74, 0.42, 0.28)
WOODS = [("beech", "Buche", BEECH), ("oak", "Eiche", OAK_MID), ("walnut", "Nussbaum", WALNUT), ("white", "Weiß", WHITE)]
BOOK_COLORS = [(0.55, 0.18, 0.16), (0.16, 0.3, 0.22), (0.2, 0.24, 0.38), (0.62, 0.5, 0.3), (0.74, 0.55, 0.4), (0.35, 0.42, 0.5)]


def wood(k, color=BEECH, slot="wood"):
    return k.mat(slot, color, grain="wood", rough=0.62, vary=0.07, bump=0.1)


def wood_variants(slot="wood"):
    return [(vid, name, {slot: col}) for vid, name, col in WOODS]


def books_mats(k):
    k.mat("cover", (1, 1, 1), grain="paint", rough=0.7, vary=0.0, bump=0.05)
    k.mat("pages", (0.93, 0.88, 0.76), grain="paint", rough=0.85, vary=0.04)


# --- Buch-Aufsteller ---

def build_book_stand(k):
    wood(k)
    b = k.part("Aufsteller", "wood", bevel=0.003)
    b.box((0, 0.0125, 0.006), (0.2, 0.12, 0.012), step=0.3, dent=0.0004)
    b.box((0, -0.045, 0.021), (0.2, 0.012, 0.03), step=0.3, dent=0.0004)
    m = Matrix.Translation((0, 0.045, 0.0898)) @ Matrix.Rotation(math.radians(-20), 4, "X")
    b.box((0, 0, 0), (0.19, 0.012, 0.16), step=0.3, dent=0.0004, matrix=m)
    for x in (-0.05, 0.05):
        b.box((x, 0.078, 0.091), (0.014, 0.012, 0.16), step=0.3, dent=0.0004, turn=(-12, 0, 0))
    k.collider((0, 0.0125, 0.006), (0.2, 0.125, 0.012))
    k.collider((0, -0.045, 0.021), (0.2, 0.012, 0.03))
    k.collider((0, 0.06, 0.09), (0.19, 0.06, 0.16))
    k.book_spot = (Vector((0, 0.01, 0.012)), 20.0)


# --- Bücherstapel ---

def build_book_stack(k):
    books_mats(k)
    k.mat("ribbon", (0.72, 0.2, 0.2), grain="fabric", rough=0.8, vary=0.04)
    cover = k.part("Buchdeckel", "cover", bevel=0.0015, vary=0.0)
    pages = k.part("Buchseiten", "pages", bevel=0.0008)
    rnd = random.Random(k.seed)
    z = 0.0
    for i in range(5):
        w, d, t = rnd.uniform(0.17, 0.24), rnd.uniform(0.12, 0.17), rnd.uniform(0.025, 0.045)
        m = Matrix.Translation((rnd.uniform(-0.01, 0.01), rnd.uniform(-0.01, 0.01), z)) @ Matrix.Rotation(math.radians(rnd.uniform(-9, 9)), 4, "Z")
        cover.box((0, 0, t / 2), (w, d, t), step=0.5, dent=0.0008, tint=F.lin(BOOK_COLORS[i % len(BOOK_COLORS)]), matrix=m)
        pages.box((0.005, 0.0, t / 2), (w - 0.014, d - 0.012, t * 0.84), step=0.5, dent=0.0, matrix=m)
        z += t
    rib = k.part("Lesezeichen", "ribbon", bevel=0.0)
    rib.tube([(0.02, -0.06, z - 0.01), (0.025, -0.08, z - 0.02), (0.022, -0.09, z - 0.06)], 0.003, segs=4, smooth=1, round_ends=True)
    k.collider((0, 0, z / 2), (0.24, 0.17, z))
    k.surface((0, 0, z), (0.16, 0.11))


# --- Buchstützen aus Holz ---

def build_wood_bookend(k):
    """Einzelne Buchstütze (seit Etappe 6b): flache Seite +x zu den Büchern, Standfuß und Knauf
    außen – vorn und hinten gleich, damit sie um 180° gedreht auf der anderen Seite genauso aussieht."""
    wood(k)
    b = k.part("Buchstütze", "wood", bevel=0.004)
    # Aufrechtes Brett mit weichem Bogen oben (Umriss in der Ebene Tiefe/Höhe, Dicke nach +x)
    outline = [(-0.06, 0.0), (0.06, 0.0), (0.06, 0.12)]
    outline += [(0.06 * math.cos(math.pi * i / 12), 0.12 + 0.05 * math.sin(math.pi * i / 12)) for i in range(1, 12)]
    outline += [(-0.06, 0.12)]
    m = Matrix(((0, 0, 1, 0.011), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    b.slab(outline, 0.022, m, dent=0.0004)
    b.box((-0.012, 0, 0.012), (0.05, 0.11, 0.024), step=0.3, dent=0.0005)
    F.button(b, (0.009, 0, 0.12), r=0.018, normal=(-1, 0, 0))
    k.collider((0.0, 0, 0.085), (0.07, 0.12, 0.17))


# --- Lichtschalter ---

def build_light_switch(k):
    k.mat("porcelain", WHITE, grain="smooth", rough=0.3, vary=0.03)
    k.mat("brass", (0.8, 0.62, 0.32), grain="smooth", rough=0.36, metal=0.65, vary=0.06)
    plate = k.part("Platte", "porcelain", bevel=0.0)
    plate.lathe([(0.0, 0.0), (0.045, 0.0), (0.046, 0.006), (0.04, 0.014), (0.0, 0.016)], (0, 0, 0), segs=32, turn=(90, 0))
    lever = k.part("Kippschalter", "brass", bevel=0.0)
    lever.lathe([(0.0, 0.0), (0.012, 0.0), (0.014, 0.006), (0.0, 0.01)], (0, -0.016, 0), segs=16, turn=(90, 0))
    lever.tube([(0, -0.02, 0.0), (0, -0.04, 0.016)], 0.004, segs=8, round_ends=True)
    screws = k.part("Schrauben", "brass", bevel=0.0)
    for z in (-0.03, 0.03):
        F.button(screws, (0, -0.0158, z), r=0.0035, normal=(0, -1, 0))
    k.collider((0, -0.012, 0), (0.1, 0.024, 0.1))
    k.root_script = "res://scripts/objects/light_switch.gd"
    k.interact_prompt = "Licht"
    k.interact = (Vector((0, -0.04, 0)), Vector((0.2, 0.08, 0.2)))


# --- Bücherwagen ---

def build_book_cart(k):
    wood(k)
    k.mat("rubber", (0.2, 0.19, 0.18), grain="smooth", rough=0.8, vary=0.03)
    k.mat("metal", (0.3, 0.3, 0.3), grain="smooth", rough=0.5, metal=0.5, vary=0.04)
    W, D = 0.8, 0.38
    c = k.part("Wagen", "wood", bevel=0.005)
    for side in (-1, 1):
        c.box((side * 0.38, 0, 0.5), (0.03, D, 0.78), step=0.3, dent=0.001)
    for z in (0.14, 0.48):
        c.box((0, 0, z), (0.74, D - 0.02, 0.025), step=0.3, dent=0.0008)
    c.box((0, 0, 0.88), (0.8, D, 0.03), step=0.3, dent=0.0008)
    c.tube([(-0.39, 0.2, 0.84), (-0.42, 0.24, 0.84), (-0.42, 0.24, 0.6), (-0.39, 0.2, 0.6)], 0.012, segs=8, smooth=1, round_ends=True)
    wheels = k.part("Rollen", "rubber", bevel=0.0)
    forks = k.part("Rollenhalter", "metal", bevel=0.0)
    for x in (-0.33, 0.33):
        for y in (-0.14, 0.14):
            wheels.lathe([(0.0, -0.012), (0.035, -0.012), (0.04, 0.0), (0.035, 0.012), (0.0, 0.012)], (x, y, 0.04), segs=20, turn=(0, 90))
            forks.box((x, y, 0.09), (0.04, 0.03, 0.02), step=0.5, dent=0.0)
            forks.tube([(x, y, 0.1), (x, y, 0.115)], 0.008, segs=6)
    for t, h in ((0.48 + 0.0125, 0.36), (0.14 + 0.0125, 0.32)):
        k.row((0, -0.01, t), 0.72, h, D - 0.04)
    for side in (-1, 1):
        k.collider((side * 0.38, 0, 0.5), (0.03, D, 0.78))
    for z in (0.14, 0.48):
        k.collider((0, 0, z), (0.74, D - 0.02, 0.025))
    k.collider((0, 0, 0.88), (0.8, D, 0.03))
    k.collider((0, 0, 0.06), (0.76, D - 0.04, 0.12))
    k.surface((0, 0, 0.895), (0.76, D - 0.04))


# --- Bibliothekstritt ---

def build_step_stool(k):
    wood(k)
    k.mat("tread", (0.3, 0.26, 0.22), grain="fabric", rough=0.9, vary=0.05, bump=0.3)
    b = k.part("Tritt", "wood", bevel=0.006)
    for side in (-1, 1):
        b.box((side * 0.2, 0.0, 0.13), (0.03, 0.4, 0.26), step=0.3, dent=0.0008)
        b.box((side * 0.2, 0.1, 0.38), (0.03, 0.2, 0.25), step=0.3, dent=0.0008)
    b.box((0, -0.1, 0.25), (0.37, 0.2, 0.025), step=0.3, dent=0.0008)
    b.box((0, 0.1, 0.49), (0.37, 0.2, 0.025), step=0.3, dent=0.0008)
    b.box((0, -0.19, 0.06), (0.37, 0.02, 0.06), step=0.3, dent=0.0006)
    tread = k.part("Trittbelag", "tread", bevel=0.0)
    tread.box((0, -0.1, 0.264), (0.33, 0.16, 0.004), step=0.3, dent=0.0)
    tread.box((0, 0.1, 0.504), (0.33, 0.16, 0.004), step=0.3, dent=0.0)
    k.collider((0, -0.1, 0.13), (0.42, 0.2, 0.265))
    k.collider((0, 0.1, 0.25), (0.42, 0.2, 0.505))
    k.surface((0, 0.1, 0.505), (0.32, 0.16))
    k.surface((0, -0.1, 0.265), (0.32, 0.16))
    k.seat((0, 0.1, 0.505))
    k.interact = (Vector((0, 0.05, 0.4)), Vector((0.42, 0.42, 0.4)))


# --- Strickpouf ---

def build_knit_pouf(k):
    k.mat("knit", (0.86, 0.8, 0.7), grain="fabric", rough=0.95, vary=0.05, bump=0.5, scale=3.0)
    b = k.part("Pouf", "knit", bevel=0.0)
    b.lathe([(0.0, 0.0), (0.2, 0.0), (0.26, 0.04), (0.28, 0.2), (0.26, 0.36), (0.2, 0.4), (0.0, 0.41)], (0, 0, 0), segs=48, wave=0.025, waves=16)
    braid = k.part("Zopfmuster", "knit", bevel=0.0)
    for i in range(16):
        a = 2 * math.pi * (i + 0.5) / 16
        d = Vector((math.cos(a), math.sin(a), 0))
        for j in range(7):
            z = 0.06 + j * 0.045
            r = 0.27 + 0.012 * math.sin(math.pi * z / 0.4)
            braid.blob(d * r + Vector((0, 0, z)), 0.022, subdiv=1, lump=0.1, scale=(0.7, 0.7, 1.1))
    k.collider((0, 0, 0.2), (0.56, 0.56, 0.41))
    k.surface((0, 0, 0.41), (0.3, 0.3))
    k.seat((0, 0, 0.41))
    k.interact = (Vector((0, 0, 0.3)), Vector((0.56, 0.56, 0.4)))


# --- Deko-Regal (Startmöbel) ---

def build_deco_shelf(k):
    wood(k)
    W, D, H = 0.9, 0.3, 1.6
    c = k.part("Korpus", "wood", bevel=0.006)
    for side in (-1, 1):
        c.box((side * 0.43, 0, H / 2), (0.035, D, H), step=0.3, dent=0.001)
    c.box((0, 0.14, H / 2), (0.84, 0.014, H - 0.04), step=0.3, dent=0.0008)
    tops = [0.06, 0.48, 0.9, 1.3]
    for z in tops:
        c.box((0, 0, z - 0.012), (0.83, D - 0.01, 0.025), step=0.3, dent=0.0008)
    c.box((0, 0, H - 0.012), (W, D, 0.025), step=0.3, dent=0.0008)
    for i, z in enumerate(tops):
        clear = (tops[i + 1] if i + 1 < len(tops) else H - 0.025) - z - 0.025
        k.surface((0, -0.01, z), (0.8, D - 0.04), max_height=clear)
        k.collider((0, 0, z - 0.012), (0.83, D - 0.01, 0.025))
    k.surface((0, 0, H), (W - 0.04, D - 0.04))
    for side in (-1, 1):
        k.collider((side * 0.43, 0, H / 2), (0.035, D, H))
    k.collider((0, 0.14, H / 2), (0.84, 0.016, H))
    k.collider((0, 0, H - 0.012), (W, D, 0.025))


# --- Schirmständer ---

def build_umbrella_stand(k):
    k.mat("stand", (0.62, 0.64, 0.62), grain="smooth", rough=0.55, metal=0.4, vary=0.05)
    k.mat("canopy", (0.32, 0.44, 0.62), grain="fabric", rough=0.85, vary=0.05)
    k.mat("canopy2", (0.8, 0.32, 0.28), grain="fabric", rough=0.85, vary=0.05)
    k.mat("handle", WALNUT, grain="wood", rough=0.6, vary=0.06)
    st = k.part("Ständer", "stand", bevel=0.0)
    st.lathe([(0.0, 0.0), (0.12, 0.0), (0.125, 0.02), (0.115, 0.45), (0.122, 0.46), (0.118, 0.475), (0.105, 0.475), (0.103, 0.03), (0.0, 0.03)],
             (0, 0, 0), segs=36)
    for i, (mat, tilt, turn) in enumerate((("canopy", 8, 30), ("canopy2", -10, 200))):
        a = math.radians(turn)
        d = Vector((math.sin(math.radians(tilt)) * math.cos(a), math.sin(math.radians(tilt)) * math.sin(a), math.cos(math.radians(tilt))))
        base = Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.04))
        u = k.part("Schirm", mat, bevel=0.0)
        u.lathe([(0.0, 0.0), (0.012, 0.03), (0.04, 0.35), (0.032, 0.62), (0.008, 0.72), (0.0, 0.73)], base, segs=8, wave=0.15, waves=8,
                turn=(-math.degrees(math.atan2(d.y, d.z)), math.degrees(math.asin(d.x))))
        h = k.part("Griff", "handle", bevel=0.0)
        top = base + d * 0.74
        h.tube([top, top + d * 0.12, top + d * 0.15 + Vector((0.05, 0, 0)), top + d * 0.1 + Vector((0.09, 0, 0)),
                top + d * 0.06 + Vector((0.085, 0, 0))], 0.009, segs=8, smooth=2, round_ends=True)
    k.collider((0, 0, 0.24), (0.25, 0.25, 0.48))


# --- Garderobenständer ---

def build_coat_rack(k):
    wood(k)
    k.mat("scarf", (0.78, 0.3, 0.28), grain="fabric", rough=0.95, vary=0.06, bump=0.3, pattern="check", pattern_size=0.03,
          color3=(0.95, 0.9, 0.8))
    k.mat("hat", (0.32, 0.28, 0.24), grain="fabric", rough=0.9, vary=0.05)
    b = k.part("Ständer", "wood", bevel=0.0)
    b.tube([(0, 0, 0.05), (0, 0, 1.75)], 0.022, segs=12, round_ends=True)
    b.blob((0, 0, 1.78), 0.035, subdiv=2, lump=0.02)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        F.curved_leg(b, Vector((0, 0, 0.3)), d * 0.3 + Vector((0, 0, 0.01)), 0.02, 0.014, bow=0.05, outward=(0, 0, 0.5))
    for i in range(6):
        a = math.radians(30 + 60 * i)
        d = Vector((math.cos(a), math.sin(a), 0))
        z = 1.62 if i % 2 == 0 else 1.5
        b.tube([Vector((0, 0, z)), d * 0.12 + Vector((0, 0, z + 0.04)), d * 0.15 + Vector((0, 0, z + 0.1))], 0.009, segs=7, smooth=2, round_ends=True)
        b.blob(d * 0.15 + Vector((0, 0, z + 0.1)), 0.014, subdiv=1, lump=0.02)
    hat = k.part("Hut", "hat", bevel=0.0)
    hd = Vector((math.cos(math.radians(30)), math.sin(math.radians(30)), 0))
    hat.lathe([(0.0, 0.0), (0.15, 0.0), (0.16, 0.008), (0.1, 0.012), (0.095, 0.1), (0.07, 0.12), (0.0, 0.122)], hd * 0.15 + Vector((0, 0, 1.73)),
              segs=28, turn=(10, 0))
    scarf = k.part("Schal", "scarf", bevel=0.0)
    sd = Vector((math.cos(math.radians(150)), math.sin(math.radians(150)), 0))
    top = sd * 0.13 + Vector((0, 0, 1.6))
    scarf.tube([top + sd * 0.03 + Vector((0, -0.04, -0.6)), top + Vector((0, -0.04, -0.05)), top + Vector((0, 0.02, 0.03)), top + Vector((0, 0.06, -0.04)),
                top + sd * 0.02 + Vector((0, 0.07, -0.5))], 0.03, segs=8, smooth=2, round_ends=True)
    k.collider((0, 0, 0.9), (0.4, 0.4, 1.8))


# --- Wanduhr ---

def build_wall_clock(k):
    wood(k)
    k.mat("dial", (0.96, 0.93, 0.86), grain="paint", rough=0.7, vary=0.03)
    k.mat("hands", (0.15, 0.13, 0.12), grain="smooth", rough=0.5, vary=0.02)
    rim = k.part("Rand", "wood", bevel=0.0)
    F.ring(rim, (0, -0.025, 0), 0.155, 0.022, matrix=Matrix.Rotation(math.radians(90), 4, "X"), n=48, segs=10)
    dial = k.part("Zifferblatt", "dial", bevel=0.0)
    dial.lathe([(0.0, 0.0), (0.15, 0.0), (0.15, 0.012), (0.0, 0.012)], (0, -0.006, 0), segs=48, turn=(90, 0))
    marks = k.part("Striche", "hands", bevel=0.0, settle=False)
    for i in range(12):
        a = 2 * math.pi * i / 12
        d = Vector((math.sin(a), 0, math.cos(a)))
        ln = 0.022 if i % 3 == 0 else 0.012
        marks.tube([d * 0.128 + Vector((0, -0.019, 0)), d * (0.128 - ln) + Vector((0, -0.019, 0))], 0.0035 if i % 3 == 0 else 0.0022, segs=4)
    hands = k.part("Zeiger", "hands", bevel=0.0, settle=False)
    hands.tube([Vector((0, -0.022, 0)), Vector((math.sin(math.radians(300)), 0, math.cos(math.radians(300)))) * 0.075 + Vector((0, -0.022, 0))], 0.004, segs=5, round_ends=True)
    hands.tube([Vector((0, -0.025, 0)), Vector((math.sin(math.radians(60)), 0, math.cos(math.radians(60)))) * 0.11 + Vector((0, -0.025, 0))], 0.0028, segs=5, round_ends=True)
    hands.blob((0, -0.027, 0), 0.008, subdiv=1, lump=0.02)
    k.collider((0, -0.025, 0), (0.36, 0.05, 0.36))


# --- Zitronenbäumchen ---

def build_citrus(k):
    k.mat("pot", TERRA, grain="plaster", rough=0.9, vary=0.08, scale=3.0)
    soil, rim = F.pot(k, (0, 0, 0), 0.18, 0.32, style="classic", slot="pot")
    p = k.plant()
    G.citrus(p, 0.75, "fruit_lemon")
    k.add_plant(p, soil, scale=rim / 0.2 * 1.05)
    k.collider((0, 0, 0.16), (0.4, 0.4, 0.32))


# --- Kakteen im Tontopf ---

def build_cacti(k):
    k.mat("pot", TERRA, grain="plaster", rough=0.9, vary=0.08, scale=3.0)
    k.mat("cactus", (0.36, 0.55, 0.36), grain="leaf", rough=0.7, vary=0.1)
    k.mat("bloom", (0.95, 0.45, 0.55), grain="leaf", rough=0.7, vary=0.1)
    soil, rim = F.pot(k, (0, 0, 0), 0.075, 0.09, style="classic", slot="pot")
    rnd = random.Random(k.seed)
    c = k.part("Kaktus", "cactus", bevel=0.0)
    for (dx, dy, h, r) in ((-0.025, 0.01, 0.16, 0.024), (0.03, -0.01, 0.1, 0.022), (0.0, 0.035, 0.06, 0.026)):
        base = soil + Vector((dx, dy, -0.01))
        c.lathe([(0.0, 0.0), (r * 0.9, 0.0), (r, h * 0.3), (r * 0.95, h * 0.8), (r * 0.6, h * 0.97), (0.0, h)], base, segs=16, wave=0.12, waves=8)
    c.tube([soil + Vector((-0.025, 0.01, 0.09)), soil + Vector((-0.05, 0.01, 0.1)), soil + Vector((-0.055, 0.01, 0.14))], 0.013, segs=10,
           smooth=1, round_ends=True)
    fl = k.part("Blüte", "bloom", bevel=0.0)
    fl.star(soil + Vector((-0.025, 0.01, 0.152)), Vector((0, 0, 1)), 0.02, 6, rnd, thick=0.003, cup=0.4)
    fl.star(soil + Vector((0.0, 0.035, 0.052)), Vector((0, 0, 1)), 0.016, 6, rnd, thick=0.003, cup=0.4)
    k.collider((0, 0, 0.1), (0.17, 0.17, 0.2))


# --- Kerze im Glas ---

def build_candle_jar(k):
    k.mat("glass", (0.9, 0.95, 0.95), glass=True, rough=0.1, vary=0.0)
    k.mat("wax", (0.95, 0.92, 0.84), grain="smooth", rough=0.55, vary=0.03)
    wood(k)
    g = k.part("Glas", "glass", bevel=0.0)
    g.lathe([(0.0, 0.0), (0.042, 0.0), (0.044, 0.006), (0.044, 0.1), (0.04, 0.1), (0.04, 0.006), (0.0, 0.006)], (0, 0, 0), segs=28)
    w = k.part("Wachs", "wax", bevel=0.0)
    w.lathe([(0.0, 0.0), (0.039, 0.0), (0.039, 0.06), (0.03, 0.058), (0.0, 0.056)], (0, 0, 0.006), segs=24)
    wick = k.part("Docht", F._wick(k), bevel=0.0)
    wick.tube([(0, 0, 0.06), (0.001, 0, 0.074)], 0.0018, segs=5)
    k.flame((0.0015, 0, 0.07), size=0.016)
    lid = k.part("Deckel", "wood", bevel=0.002)
    lid.lathe([(0.0, 0.0), (0.046, 0.0), (0.046, 0.012), (0.0, 0.012)], (0.075, 0.02, 0.0), segs=28, turn=(0, 0))
    k.light_kind = "flame"
    k.shadow = "none"
    k.light((0, 0, 0.1), energy=0.25, rng=1.5, shadow=False)
    k.collider((0.02, 0.01, 0.05), (0.18, 0.1, 0.1))


# --- Gießkanne ---

def build_watering_can(k):
    k.mat("zinc", (0.66, 0.68, 0.66), grain="smooth", rough=0.5, metal=0.45, vary=0.06)
    b = k.part("Kanne", "zinc", bevel=0.0)
    b.lathe([(0.0, 0.0), (0.085, 0.0), (0.09, 0.01), (0.09, 0.17), (0.08, 0.2), (0.06, 0.21), (0.0, 0.212)], (0, 0, 0), segs=32)
    b.tube([(0.07, 0, 0.04), (0.16, 0, 0.12), (0.23, 0, 0.22)], lambda t: 0.014 - 0.006 * t, segs=8, smooth=1, round_ends=True)
    b.lathe([(0.0, 0.0), (0.012, 0.0), (0.026, 0.03), (0.0, 0.034)], (0.235, 0, 0.225), segs=16, turn=(0, 50))
    b.tube([(-0.06, 0, 0.2), (-0.03, 0, 0.3), (0.05, 0, 0.3), (0.07, 0, 0.21)], 0.008, segs=7, smooth=2, round_ends=True)
    b.tube([(-0.088, 0, 0.16), (-0.13, 0, 0.12), (-0.088, 0, 0.05)], 0.007, segs=7, smooth=2, round_ends=True)
    k.collider((0.05, 0, 0.14), (0.4, 0.2, 0.28))


# --- Bilderrahmen zum Hinstellen ---

def build_photo_frame(k):
    wood(k)
    k.mat("photo_sky", (0.7, 0.8, 0.86), grain="paint", rough=0.8, vary=0.06)
    k.mat("photo_land", (0.5, 0.62, 0.4), grain="paint", rough=0.8, vary=0.08)
    k.mat("passe", (0.95, 0.93, 0.88), grain="paint", rough=0.8, vary=0.02)
    tilt = Matrix.Translation((0, 0.0, 0.0)) @ Matrix.Rotation(math.radians(-12), 4, "X")
    fr = k.part("Rahmen", "wood", bevel=0.002)
    W, H = 0.16, 0.2
    m = tilt @ Matrix.Translation((0, 0, H / 2 + 0.005))
    for z, w, h in ((H / 2 - 0.009, W, 0.018), (-H / 2 + 0.009, W, 0.018)):
        fr.box((0, 0, z), (w, 0.016, h), step=0.5, dent=0.0004, matrix=m)
    for x in (-W / 2 + 0.009, W / 2 - 0.009):
        fr.box((x, 0, 0), (0.018, 0.0158, H - 0.03), step=0.5, dent=0.0004, matrix=m)
    pp = k.part("Passepartout", "passe", bevel=0.0, settle=False)
    pp.box((0, 0.002, 0), (W - 0.02, 0.006, H - 0.02), step=0.5, dent=0.0, matrix=m)
    sky = k.part("Foto Himmel", "photo_sky", bevel=0.0, settle=False)
    sky.box((0, -0.0015, 0.02), (W - 0.06, 0.002, 0.08), step=0.5, dent=0.0, matrix=m)
    land = k.part("Foto Wiese", "photo_land", bevel=0.0, settle=False)
    land.box((0, -0.0015, -0.04), (W - 0.06, 0.002, 0.05), step=0.5, dent=0.0, matrix=m)
    # Stütze hinten: oben an der Rückseite des schrägen Rahmens, unten auf dem Tisch
    fr.box((0, 0.08, 0.075), (0.03, 0.012, 0.16), step=0.5, dent=0.0004, turn=(25, 0, 0))
    k.collider((0, 0.02, 0.1), (W, 0.1, 0.2))


# --- Türschild „Geöffnet“ ---

def build_open_sign(k):
    wood(k, WHITE)
    k.mat("letters", (0.3, 0.42, 0.32), grain="paint", rough=0.7, vary=0.04)
    k.mat("string", (0.85, 0.78, 0.62), grain="fabric", rough=0.9, vary=0.04)
    board = k.part("Schild", "wood", bevel=0.004)
    F.pillow(board, (0, -0.012, -0.08), (0.3, 0.024, 0.11), roundness=5.0, step=0.02)
    txt = k.part("Schrift", "letters", bevel=0.0)
    m = Matrix.Translation((0, -0.0245, -0.095)) @ Matrix.Rotation(math.radians(90), 4, "X")
    txt.text("Geöffnet", 0.05, 0.004, m, font="DejaVuSerif-Bold.ttf", jitter=0.06)
    string = k.part("Kordel", "string", bevel=0.0)
    string.tube([(-0.12, -0.012, -0.03), (-0.06, -0.012, 0.03), (0.0, -0.01, 0.06), (0.06, -0.012, 0.03), (0.12, -0.012, -0.03)], 0.0035, segs=5, smooth=2, round_ends=True)
    string.blob((0, -0.008, 0.062), 0.008, subdiv=1, lump=0.03)
    k.collider((0, -0.012, -0.04), (0.32, 0.03, 0.22))


ITEMS = [
    dict(id="book_stand", name="Buch-Aufsteller", category="deco", sub="books", price=18,
         desc="Ein kleiner Holzaufsteller, in dem ein Buch mit dem Cover nach vorn steht.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_book_stand, variants=wood_variants()),
    dict(id="book_stack", name="Bücherstapel", category="deco", sub="books", price=15,
         desc="Fünf alte Bücher aufeinander, mit Lesezeichen.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_book_stack,
         variants=[("red", "Rotes Lesezeichen", {"ribbon": (0.72, 0.2, 0.2)}), ("green", "Grünes Lesezeichen", {"ribbon": (0.3, 0.5, 0.32)}),
                   ("gold", "Goldenes Lesezeichen", {"ribbon": (0.85, 0.66, 0.3)})]),
    dict(id="bookend_wood", name="Buchstütze aus Holz", category="deco", sub="bookend", price=8,
         desc="Ein schlichtes Holzbrett mit rundem Knauf – eine Stütze; zwei halten einen Bücherblock (Mausrad dreht).",
         styles=STYLE, place=["surface", "floor"], build=build_wood_bookend, variants=wood_variants()),
    dict(id="light_switch", name="Lichtschalter", category="lighting", sub="switch", price=12,
         desc="Ein runder Porzellanschalter mit Messinghebel – schaltet alle Lampen im Raum.",
         styles=STYLE, place="wall", adopt=True, build=build_light_switch,
         variants=[("white", "Porzellan", {"porcelain": WHITE}), ("black", "Schwarz", {"porcelain": (0.16, 0.15, 0.15)}),
                   ("sage", "Salbei", {"porcelain": (0.66, 0.74, 0.62)})]),
    dict(id="book_cart", name="Bücherwagen", category="shelf", sub="bookshelf", price=120,
         desc="Ein rollender Wagen mit zwei Fächern – zum Bücherverteilen wie in einer echten Bibliothek.",
         styles=STYLE, place="floor", build=build_book_cart, variants=wood_variants()),
    dict(id="step_stool", name="Bibliothekstritt", category="seating", sub="stool", price=55,
         desc="Ein zweistufiger Tritt zum Hinaufsteigen und Draufsetzen.",
         styles=STYLE, place="floor", build=build_step_stool, variants=wood_variants()),
    dict(id="pouf", name="Strickpouf", category="seating", sub="stool", price=48,
         desc="Ein dicker, runder Pouf mit Zopfmuster.",
         styles=STYLE, place="floor", lie=True, build=build_knit_pouf,
         variants=[("oat", "Hafer", {"knit": (0.86, 0.8, 0.7)}), ("grey", "Grau", {"knit": (0.62, 0.62, 0.6)}),
                   ("rose", "Rosé", {"knit": (0.86, 0.66, 0.64)}), ("sage", "Salbei", {"knit": (0.62, 0.7, 0.58)}),
                   ("mustard", "Senf", {"knit": (0.82, 0.64, 0.28)})]),
    dict(id="deco_shelf_light", name="Deko-Regal", category="shelf", sub="deco_shelf", price=120,
         desc="Ein schlichtes offenes Regal nur für Deko – Pflanzen, Kerzen, Figuren.",
         styles=STYLE, place="floor", adopt=True, build=build_deco_shelf, variants=wood_variants()),
    dict(id="umbrella_stand", name="Schirmständer", category="deco", sub="storage", price=40,
         desc="Ein Zinkständer mit zwei bunten Schirmen – für Regentage am Eingang.",
         styles=STYLE, place="floor", build=build_umbrella_stand,
         variants=[("zinc", "Zink", {"stand": (0.62, 0.64, 0.62)}), ("cream", "Creme", {"stand": (0.92, 0.88, 0.8)}),
                   ("green", "Grün", {"stand": (0.3, 0.42, 0.32)}), ("black", "Schwarz", {"stand": (0.18, 0.18, 0.18)})]),
    dict(id="coat_rack", name="Garderobenständer", category="deco", sub="storage", price=70,
         desc="Ein Holzständer mit sechs Haken, an denen ein Hut und ein Karoschal hängen.",
         styles=STYLE, place="floor", build=build_coat_rack, variants=wood_variants()),
    dict(id="wall_clock", name="Wanduhr", category="deco", sub="picture", price=36,
         desc="Eine runde Uhr mit Holzrand – sie zeigt immer kurz nach zehn.",
         styles=STYLE, place="wall", build=build_wall_clock, variants=wood_variants()),
    dict(id="plant_citrus", name="Zitronenbäumchen", category="deco", sub="plant", price=70,
         desc="Ein kleines Bäumchen mit Zitronen in einem Terrakottatopf.",
         styles=STYLE, place="floor", lean=True, build=build_citrus,
         variants=[("terra", "Terrakotta", {"pot": TERRA}), ("white", "Weiß", {"pot": WHITE}), ("blue", "Blau", {"pot": (0.42, 0.52, 0.66)}),
                   ("green", "Grün", {"pot": (0.42, 0.54, 0.4)})]),
    dict(id="plant_cactus", name="Kakteen im Tontopf", category="deco", sub="plant", price=14,
         desc="Drei kleine Kakteen, zwei davon mit Blüte.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_cacti,
         variants=[("pink", "Rosa Blüte", {"bloom": (0.95, 0.45, 0.55)}), ("yellow", "Gelbe Blüte", {"bloom": (0.97, 0.84, 0.36)}),
                   ("white", "Weiße Blüte", {"bloom": (0.96, 0.95, 0.9)})]),
    dict(id="candle_jar", name="Kerze im Glas", category="lighting", sub="candle", price=10,
         desc="Eine Kerze in einem schlichten Glas, daneben der Holzdeckel.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_candle_jar,
         variants=[("cream", "Creme", {"wax": (0.95, 0.92, 0.84)}), ("rose", "Rosé", {"wax": (0.92, 0.72, 0.72)}),
                   ("sage", "Salbei", {"wax": (0.7, 0.78, 0.66)}), ("honey", "Honig", {"wax": (0.92, 0.75, 0.45)})]),
    dict(id="watering_can", name="Gießkanne", category="deco", sub="figure", price=22,
         desc="Eine kleine Gießkanne aus Zink mit langem Ausguss.",
         styles=STYLE, place=["surface", "floor"], build=build_watering_can,
         variants=[("zinc", "Zink", {"zinc": (0.66, 0.68, 0.66)}), ("green", "Grün", {"zinc": (0.42, 0.56, 0.44)}),
                   ("red", "Rot", {"zinc": (0.72, 0.24, 0.22)}), ("cream", "Creme", {"zinc": (0.92, 0.88, 0.8)})]),
    dict(id="photo_frame", name="Bilderrahmen zum Hinstellen", category="deco", sub="picture", price=12,
         desc="Ein kleiner Holzrahmen mit Stütze und einem Foto von einer Sommerwiese.",
         styles=STYLE, place=["surface", "floor"], adopt=True, build=build_photo_frame, variants=wood_variants()),
    dict(id="open_sign", name="Türschild „Geöffnet“", category="deco", sub="picture", price=15,
         desc="Ein kleines Holzschild an einer Kordel – für die Ladentür.",
         styles=STYLE, place=["door", "wall"], build=build_open_sign,
         variants=[("white", "Weiß · Grün", {"wood": WHITE, "letters": (0.3, 0.42, 0.32)}),
                   ("green", "Grün · Creme", {"wood": (0.3, 0.42, 0.32), "letters": (0.95, 0.92, 0.84)}),
                   ("navy", "Blau · Gold", {"wood": (0.16, 0.2, 0.32), "letters": (0.85, 0.66, 0.3)})]),
]
