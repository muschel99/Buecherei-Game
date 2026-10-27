"""Bausteine für Möbel und Deko im Bilderbuch-Stil (Etappe 6, Möbelkatalog im neuen Stil).

Gleiche Regeln wie draußen (docs/STYLE_GUIDE.md, „Bilderbuch-Stil“):
  - Jedes Teil (Bein, Sitz, Lehne, Blatt, Blüte, Topf) ist ein eigener, geschlossener Körper mit
    Volumen – in der .blend ein eigenes Objekt (Pflanzen: je Material ein Objekt, jedes Blatt eine
    eigene Insel, in Blender mit P → „Nach losen Teilen“ trennbar).
  - Weich und rund (Bevel-Modifikator, Kissen als Superellipsoid), leicht unregelmäßig: settle()
    verzieht alle Teile eines Objekts gemeinsam um wenige Millimeter (handgemacht, nie verbogen,
    Teile bleiben verbunden).
  - Einfärbbare Teile haben Materialien mit englischem Rollennamen (fabric, leather, paint, wood,
    metal, glass_shade, bloom, pot …) – die Farbvarianten im Datenblatt färben genau diese
    (FurnitureUtils.apply_variant, docs/ASSET_GUIDE.md „Farbvarianten“).

Koordinaten wie bei den Häusern: Blender x rechts, y nach hinten, z oben; die Vorderseite zeigt nach
-y (= Godot +Z). Stehende Dinge: Ursprung unten in der Mitte. Wand-Dinge: Ursprung hinten in der
Mitte (Rückseite bei y = 0, Mitte der Höhe bei z = 0). Decken-Dinge: Ursprung oben am
Aufhängepunkt (z = 0, das Ding hängt nach -z).

Kit sammelt neben den Körpern alles, was die Godot-Szene braucht (Kollision, Ablageflächen, Fächer,
Sitzplätze, Licht) – write_scene() schreibt daraus scenes/furniture/<id>.tscn.
"""

import json
import math
import os
import random
import shutil
import sys

import bpy
from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_greenery as G  # noqa: E402
import storybook_lib as SB  # noqa: E402
from storybook_lib import Body  # noqa: E402

ROOT = SC.ROOT
MODEL_DIR = os.path.join(ROOT, "assets", "models", "furniture")
SOURCE_DIR = os.path.join(ROOT, "assets", "models", "source", "furniture")
MAT_DIR = os.path.join(ROOT, "assets", "materials", "furniture")
SCENE_DIR = os.path.join(ROOT, "scenes", "furniture")
DATA_DIR = os.path.join(ROOT, "data", "furniture")
TEMPLATE_DIR = os.path.join(ROOT, "assets", "models", "templates", "furniture")
SHOTS = os.path.join(ROOT, "screenshots", "blender", "furniture")

# Steht in jeder erzeugten Datei. Speichert Godot die Datei (z. B. nach einer Änderung im Inspektor),
# verschwindet die Zeile – dann überschreibt das Bau-Script die Datei nie wieder.
MARK = "; Erzeugt von tools/blender/build_storybook_furniture.py"

CATEGORIES = {"shelf": 0, "seating": 1, "table": 2, "counter": 3, "lighting": 4, "deco": 5, "divider": 6}
PLACEMENT = {"floor": 1, "surface": 2, "wall": 4, "door": 8, "ceiling": 16}
GRID = 1.0 / 9.0

# Farbtöne (sRGB) für Pflanzen-Materialien, die die Pflanzen-Bausteine von draußen verlangen
PLANT_COLORS = {
    "leaf": (0.34, 0.52, 0.2), "leaf_dark": (0.15, 0.3, 0.12), "leaf_blue": (0.3, 0.45, 0.37),
    "leaf_lime": (0.5, 0.63, 0.22), "leaf_silver": (0.56, 0.62, 0.52), "leaf_bronze": (0.3, 0.14, 0.17),
    "box_leaf": (0.27, 0.45, 0.17), "ivy": (0.26, 0.42, 0.16), "ivy_young": (0.42, 0.58, 0.22),
    "olive_leaf": (0.52, 0.6, 0.4), "grass_leaf": (0.42, 0.56, 0.24), "leaf_core": (0.12, 0.21, 0.08),
    "stem": (0.4, 0.42, 0.22), "bark": (0.45, 0.34, 0.24), "soil": (0.25, 0.17, 0.11),
    "red": (0.86, 0.2, 0.17), "pink": (0.93, 0.52, 0.62), "rose": (0.82, 0.32, 0.45), "coral": (0.95, 0.45, 0.38),
    "lilac": (0.7, 0.58, 0.82), "blush_flower": (0.97, 0.8, 0.8), "cream_flower": (0.97, 0.93, 0.8),
    "white_flower": (0.95, 0.94, 0.9), "gold_flower": (0.93, 0.72, 0.25), "yellow_flower": (0.97, 0.84, 0.36),
    "orange_flower": (0.95, 0.52, 0.2), "peach_flower": (0.98, 0.72, 0.58), "purple_flower": (0.48, 0.27, 0.6),
    "magenta_flower": (0.78, 0.24, 0.5), "burgundy_flower": (0.48, 0.1, 0.17), "sky_flower": (0.58, 0.72, 0.92),
    "blue_flower": (0.42, 0.52, 0.85), "brown_disc": (0.3, 0.19, 0.1), "fruit": (0.95, 0.58, 0.2),
    "fruit_lemon": (0.97, 0.85, 0.3), "blue_flower_core": (0.3, 0.34, 0.58), "pink_core": (0.62, 0.3, 0.4),
    "bloom": (0.93, 0.52, 0.62), "bloom2": (0.97, 0.93, 0.8), "bloom_core": (0.93, 0.78, 0.3),
}


def srgb_lin(c):
    """sRGB -> linear (Godot-Farben in den .tres sind sRGB, hier für die Datenblätter unverändert)."""
    return tuple(c[:3])


class Mats(dict):
    """Materialien eines Objekts: fehlt ein Name (z. B. eine Blütenfarbe aus den Pflanzen-
    Bausteinen), wird er mit passender Voreinstellung angelegt."""

    def __missing__(self, key):
        plant = key in PLANT_COLORS and key not in ("soil", "bark")
        color = PLANT_COLORS.get(key, (0.75, 0.7, 0.62))
        grain = "leaf" if plant else ("wood" if key == "bark" else "plaster")
        mat = SC.make_material(key, color, grain=grain, rough=0.72 if plant else 0.9, vary=0.1, plant=plant)
        self[key] = mat
        return mat


class Kit:
    """Ein Möbelstück im Bau: Körper, Materialien und alles für die Godot-Szene."""

    def __init__(self, spec):
        self.spec = spec
        self.id = spec["id"]
        seed = sum(ord(c) * (i + 1) for i, c in enumerate(self.id))
        self.rnd = random.Random(seed)
        self.seed = seed
        self.coll = SB.collection(spec["name"])
        self.M = Mats()
        self.bodies = []      # (Body, settle?) – werden in finish() gebaut
        self.objects = []     # fertige Blender-Objekte
        self.flames = []      # Flammen: eigene Objekte (Ursprung am Docht, schrumpfen beim Löschen)
        self.colliders = []   # (Mitte, Größe, Drehung z in Grad) in Blender-Koordinaten
        self.surfaces = []    # (Mitte der Oberkante, Größe x/y, lichte Höhe)
        self.seats = []       # (Punkt auf der Sitzfläche, Drehung z)
        self.rows = []        # Fächer: (Mitte Oberkante Brett, Breite, lichte Höhe, Tiefe)
        self.lights = []      # dict(pos, energy, range, color, shadow)
        self.light_kind = None   # "electric" / "flame"
        self.shadow = "important"
        self.interact = None  # (Mitte, Größe) des E-Bereichs (Lampen, Sitzmöbel)
        self.book_spot = None  # Buch-Aufsteller: (Punkt, Neigung)
        self.settle_amount = spec.get("settle", 1.0)

    # --- Materialien und Teile ---

    def mat(self, slot, color, **kw):
        """Material mit Rollennamen (z. B. "fabric"). Gleicher Name = dasselbe Material."""
        if slot in self.M:
            return self.M[slot]
        self.M[slot] = SC.make_material(slot, color, **kw)
        return self.M[slot]

    def part(self, name, slot, bevel=0.006, vary=0.04, settle=True):
        """Neuer Körper (ein Blender-Objekt) im Material slot."""
        b = Body(name, self.M[slot], self.coll, seed=self.seed + len(self.bodies) * 7, vary=vary, bevel=bevel)
        self.bodies.append((b, settle))
        return b

    def plant(self, container="potfill", seed_offset=0):
        """Pflanze aus den Pflanzen-Bausteinen von draußen (storybook_greenery)."""
        return G.Plant(self.M, self.coll, self.seed + 101 + seed_offset,
                       container=G.CONTAINERS.get(container) if container else None)

    def add_plant(self, p, at=(0, 0, 0), scale=1.0, turn=0.0):
        """Baut eine Pflanze (in Topfgröße der Bausteine gebaut) und setzt sie verkleinert auf at."""
        objs = p.build()
        m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Scale(scale, 4)
        for o in objs:
            o.data.transform(m)
            o.data.update()
            self.objects.append(o)
        return objs

    # --- Angaben für die Godot-Szene (Blender-Koordinaten) ---

    def collider(self, center, size, turn=0.0):
        self.colliders.append((Vector(center), Vector(size), turn))

    def surface(self, top_center, size_xy, max_height=0.0):
        self.surfaces.append((Vector(top_center), (size_xy[0], size_xy[1]), max_height))

    def seat(self, pos, turn=0.0):
        self.seats.append((Vector(pos), turn))

    def row(self, top_center, width, height, depth):
        self.rows.append((Vector(top_center), width, height, depth))

    def light(self, pos, energy=1.0, rng=4.0, color=(1.0, 0.74, 0.46), shadow=True):
        self.lights.append(dict(pos=Vector(pos), energy=energy, range=rng, color=color, shadow=shadow))

    def flame(self, base, size=0.022):
        """Kerzenflamme als eigenes Objekt, Ursprung am Docht (LightSource lässt sie wachsen/schrumpfen)."""
        if "flame" not in self.M:
            self.mat("flame", (1.0, 0.72, 0.32), grain="smooth", rough=0.4, vary=0.04, emit=6.0,
                     emit_color=(1.0, 0.66, 0.28))
        b = Body("Flamme", self.M["flame"], self.coll, seed=self.seed + 900 + len(self.flames), vary=0.02)
        h = size * 2.2
        b.lathe([(0.0, 0.0), (size * 0.32, h * 0.12), (size * 0.5, h * 0.35), (size * 0.38, h * 0.62),
                 (size * 0.14, h * 0.88), (0.0, h)], (0, 0, 0), segs=10)
        o = b.build(smooth_angle=180)
        o.location = Vector(base)
        self.flames.append(o)
        return o

    # --- Bauen ---

    def finish(self):
        """Alle Körper bauen und gemeinsam leicht verziehen (handgemacht)."""
        settled = []
        for b, does_settle in self.bodies:
            if not b.bm.verts:
                b.bm.free()
                continue
            o = b.build()
            self.objects.append(o)
            if does_settle:
                settled.append(o)
        settle(settled, self.seed, self.settle_amount)
        return self.objects


def settle(objs, seed, amount=1.0):
    """Verzieht alle Teile gemeinsam: Neigung um Bruchteile eines Grads, ein paar Millimeter weiche
    Wellen – dieselbe Verschiebung an derselben Stelle, darum bleiben Teile verbunden."""
    if not objs or amount <= 0:
        return
    rnd = random.Random(seed)
    lean_x = math.radians(rnd.uniform(-0.6, 0.6)) * amount
    lean_y = math.radians(rnd.uniform(-0.5, 0.5)) * amount
    off = Vector((rnd.uniform(0, 50), rnd.uniform(0, 50), rnd.uniform(0, 50)))
    wave = 0.0022 * amount
    for o in objs:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            d = Vector((p.z * lean_x, p.z * lean_y, 0.0)) + noise.noise_vector(p * 2.4 + off) * wave
            v.co = o.matrix_world.inverted() @ (p + d)
        o.data.update()


# --- Grundformen ---

def pillow(b, center, size, roundness=3.2, puff=0.0, sag=0.0, step=0.03, tint=None, turn=0.0, matrix=None):
    """Kissen, Polster, Matratze: ein fein unterteilter Kasten, der auf ein Superellipsoid gelegt wird
    (roundness 2 = Kugel, groß = fast Kasten). puff wölbt Ober- und Unterseite in der Mitte, sag lässt
    die Mitte etwas einsinken (benutzt)."""
    sx, sy, sz = size
    # in echter Größe unterteilt (lange und kurze Seiten gleich fein), dann auf das Superellipsoid
    faces = b.box((0, 0, 0), (sx, sy, sz), step=step, dent=0.0, tint=tint)
    verts = {v for f in faces for v in f.verts}
    m = Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
    if matrix is not None:
        m = matrix @ m
    n = roundness
    for v in verts:
        q = Vector((v.co.x / (sx / 2), v.co.y / (sy / 2), v.co.z / (sz / 2)))
        r = (abs(q.x) ** n + abs(q.y) ** n + abs(q.z) ** n) ** (1.0 / n)
        q /= max(r, 1e-6)
        bulge = (1 - q.x * q.x) * (1 - q.y * q.y)
        z = q.z * sz / 2 + (puff * bulge * (1 if q.z > 0 else -0.6)) - (sag * bulge if q.z > 0 else 0.0)
        v.co = m @ Vector((q.x * sx / 2, q.y * sy / 2, z))
    return faces


def piping(b, center, size, z_level, r=0.006, turn=0.0, roundness=3.2, n=48, matrix=None):
    """Keder (Paspel) rund um ein Kissen (pillow) auf Höhe z_level (m über/unter der Mitte). Mit
    size = (x, y, z) liegt er genau auf der gerundeten Kissenkante (Querschnitt auf dieser Höhe)."""
    shrink = 1.0
    if len(size) > 2:
        t = min(0.999, abs(2.0 * z_level / size[2]))
        shrink = (1.0 - t ** roundness) ** (1.0 / roundness)
    sx, sy = size[0] / 2 * shrink, size[1] / 2 * shrink
    pts = []
    for k in range(n + 1):
        a = 2 * math.pi * k / n
        c, s = math.cos(a), math.sin(a)
        rad = (abs(c) ** roundness + abs(s) ** roundness) ** (-1.0 / roundness)
        pts.append((c * rad * sx * 1.002, s * rad * sy * 1.002))
    m = Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
    if matrix is not None:
        m = matrix @ m
    path = [m @ Vector((x, y, z_level)) for x, y in pts]
    return b.tube(path, r, segs=6)


def button(b, pos, r=0.009, normal=(0, 0, 1)):
    """Polsterknopf: flache, runde Linse."""
    nrm = Vector(normal).normalized()
    rot = nrm.to_track_quat("Z", "Y").to_matrix().to_4x4()
    m = Matrix.Translation(Vector(pos)) @ rot
    prof = [(0.0, -r * 0.2), (r * 0.9, -r * 0.15), (r, r * 0.05), (r * 0.7, r * 0.35), (0.0, r * 0.45)]
    faces = b.lathe(prof, (0, 0, 0), segs=10)
    for v in {v for f in faces for v in f.verts}:
        v.co = m @ v.co
    return faces


def turned_leg(b, base, height, r, style="baluster", segs=14, flip=False):
    """Gedrechseltes Bein (Drehkörper). style: baluster (bauchig mit Ringen), taper (schlank
    zulaufend), bun (kurzer Kugelfuß), spindle (Spindel mit Perlen)."""
    h = height
    if style == "taper":
        prof = [(0.0, 0.0), (r * 0.55, 0.0), (r * 0.62, h * 0.04), (r * 0.8, h * 0.6), (r * 1.0, h * 0.97), (r * 0.9, h), (0.0, h)]
    elif style == "bun":
        prof = [(0.0, 0.0), (r * 0.6, 0.0), (r * 1.0, h * 0.35), (r * 0.95, h * 0.7), (r * 0.7, h * 0.92), (r * 0.75, h), (0.0, h)]
    elif style == "spindle":
        prof = [(0.0, 0.0), (r * 0.7, 0.0), (r * 0.75, h * 0.08), (r * 0.55, h * 0.14), (r * 0.9, h * 0.22),
                (r * 0.6, h * 0.3), (r * 0.62, h * 0.7), (r * 0.95, h * 0.78), (r * 0.6, h * 0.86), (r, h * 0.92), (r, h), (0.0, h)]
    else:
        prof = [(0.0, 0.0), (r * 0.7, 0.0), (r * 0.8, h * 0.05), (r * 0.6, h * 0.12), (r * 1.1, h * 0.35),
                (r * 0.75, h * 0.62), (r * 0.6, h * 0.7), (r * 0.95, h * 0.78), (r * 0.7, h * 0.84), (r, h * 0.9), (r, h), (0.0, h)]
    if flip:
        prof = [(x, h - z) for x, z in reversed(prof)]
    return b.lathe(prof, base, segs=segs, dent=0.0008)


def tapered_leg(b, top, bottom, r_top, r_bottom, segs=10, splay=None):
    """Schlankes, rundes Bein von top nach bottom (zulaufend)."""
    return b.tube([Vector(top), Vector(bottom)], lambda t: r_top + (r_bottom - r_top) * t, segs=segs, round_ends=True)


def knob(b, pos, r=0.012, normal=(0, -1, 0)):
    """Runder Möbelknauf (zeigt nach normal, Standard: nach vorn)."""
    nrm = Vector(normal).normalized()
    rot = nrm.to_track_quat("Z", "Y").to_matrix().to_4x4()
    prof = [(0.0, -0.002), (r * 0.35, -0.002), (r * 0.35, r * 0.5), (r * 0.9, r * 0.8), (r, r * 1.15), (r * 0.7, r * 1.5), (0.0, r * 1.6)]
    faces = b.lathe(prof, (0, 0, 0), segs=12)
    m = Matrix.Translation(Vector(pos)) @ rot
    for v in {v for f in faces for v in f.verts}:
        v.co = m @ v.co
    return faces


def bar_handle(b, center, width, r=0.005, depth=0.022, normal_y=-1):
    """Bügelgriff (Schublade, Truhe): flacher Bogen vor der Fläche."""
    c = Vector(center)
    pts = [c + Vector((-width / 2, 0, 0)), c + Vector((-width / 2, normal_y * depth, 0)),
           c + Vector((width / 2, normal_y * depth, 0)), c + Vector((width / 2, 0, 0))]
    return b.tube(pts, r, segs=7, smooth=2, round_ends=True)


def book(cover, pages, pos, size, turn=0.0, tint=None, tilt=0.0):
    """Ein Buch: Einband (cover) und Buchblock (pages) als eigene Körper. size = (Dicke x, Tiefe y,
    Höhe z) – steht aufrecht, Rücken nach vorn (-y). tilt = gekippt (Grad, um y)."""
    t, d, h = size
    m = Matrix.Translation(Vector(pos)) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ \
        Matrix.Rotation(math.radians(tilt), 4, "Y") @ Matrix.Translation((0, 0, h / 2))
    cover.box((0, 0, 0), (t, d, h), step=0.5, dent=0.0008, tint=tint, matrix=m)
    pages.box((0, d * 0.035, 0), (t * 0.84, d * 0.95, h * 0.94), step=0.5, dent=0.0, matrix=m @ Matrix.Translation((0, 0.0025, 0)))


def book_row(kit, cover_slot, pages_slot, start, length, max_h=0.26, depth=0.17, lean_last=True, palette=None, seed=0):
    """Eine Reihe Bücher von start nach +x (aufrecht, Rücken vorn), zuletzt eins angelehnt."""
    rnd = random.Random(kit.seed + seed)
    cover = kit.part("Buchdeckel", cover_slot, bevel=0.0015, vary=0.0)
    pages = kit.part("Buchseiten", pages_slot, bevel=0.0008, vary=0.02)
    palette = palette or [(0.55, 0.18, 0.16), (0.16, 0.3, 0.22), (0.2, 0.24, 0.38), (0.5, 0.36, 0.2), (0.62, 0.52, 0.32)]
    x = 0.0
    s = Vector(start)
    while True:
        t = rnd.uniform(0.022, 0.045)
        if x + t > length:
            break
        h = rnd.uniform(0.72, 1.0) * max_h
        col = palette[rnd.randrange(len(palette))]
        tint = tuple(c * rnd.uniform(0.85, 1.12) for c in col)
        book(cover, pages, s + Vector((x + t / 2, 0, 0)), (t, depth * rnd.uniform(0.85, 1.0), h), tint=tint)
        x += t + 0.0015
    if lean_last and x + 0.06 < length:
        t, h = 0.03, max_h * 0.9
        tilt = 18.0
        dx = math.sin(math.radians(tilt)) * h / 2
        book(cover, pages, s + Vector((x + t / 2 + dx, 0, 0.0)), (t, depth * 0.9, h), tilt=tilt,
             tint=tuple(c * 1.05 for c in palette[0]))


def candle(kit, wax_slot, base, height, radius, drips=5, flame=True, segs=14):
    """Kerze mit unregelmäßigem Rand, herablaufenden Wachstropfen, Docht und Flamme."""
    rnd = random.Random(kit.seed + int(height * 1000) + int(base[0] * 997))
    b = kit.part("Kerze", wax_slot, bevel=0.0, vary=0.03)
    h, r = height, radius
    prof = [(0.0, 0.0), (r, 0.0), (r * 1.01, h * 0.5), (r * 0.99, h * 0.96), (r * 0.8, h), (r * 0.3, h * 0.985), (0.0, h * 0.99)]
    b.lathe(prof, base, segs=segs, dent=r * 0.03)
    c = Vector(base)
    for k in range(drips):
        a = rnd.uniform(0, 2 * math.pi)
        length = rnd.uniform(0.15, 0.55) * h
        top = c + Vector((math.cos(a) * r * 0.96, math.sin(a) * r * 0.96, h * 0.995))
        out = Vector((math.cos(a), math.sin(a), 0))
        pts = [top + out * r * 0.04, top - Vector((0, 0, length * 0.5)) + out * r * 0.07, top - Vector((0, 0, length)) + out * r * 0.06]
        b.tube(pts, lambda t, rr=r: rr * (0.12 - 0.04 * t), segs=6, smooth=1, round_ends=True)
        b.blob(pts[-1], r * 0.12, subdiv=1, lump=0.1, scale=(1, 1, 1.25))
    wick = kit.part("Docht", "wick" if "wick" in kit.M else _wick(kit), bevel=0.0)
    wick.tube([c + Vector((0, 0, h * 0.97)), c + Vector((0.001, 0, h + 0.012))], 0.0018, segs=5)
    if flame:
        kit.flame(c + Vector((0.0015, 0, h + 0.008)), size=max(0.014, r * 0.5))
    return h


def _wick(kit):
    kit.mat("wick", (0.12, 0.1, 0.08), grain="smooth", rough=0.9, vary=0.02)
    return "wick"


def shade(b, base, r_bottom, r_top, height, kind="pleat", segs=40, wall=0.004):
    """Lampenschirm als Röhre mit Wandstärke (offen oben und unten). kind: pleat (Falten), drum
    (gerade), dome (Kuppel, oben geschlossen mit Loch), bell (geschwungen), scallop (gewellter Saum)."""
    h = height
    if kind == "dome":
        outer = [(r_bottom, 0.0), (r_bottom * 0.98, h * 0.25), (r_bottom * 0.85, h * 0.6), (r_bottom * 0.55, h * 0.88), (r_top, h)]
    elif kind == "bell":
        outer = [(r_bottom, 0.0), (r_bottom * 0.92, h * 0.15), (r_top + (r_bottom - r_top) * 0.45, h * 0.55), (r_top, h)]
    else:
        outer = [(r_bottom, 0.0), (r_top + (r_bottom - r_top) * 0.5, h * 0.5), (r_top, h)]
    inner = [(max(r - wall, 0.002), z) for r, z in reversed(outer)]
    prof = outer + inner
    waves = 0
    wave = 0.0
    if kind == "pleat":
        waves, wave = 28, 0.035
    elif kind == "scallop":
        waves, wave = 10, 0.02
    return b.lathe(prof + [prof[0]], base, segs=segs, wave=wave, waves=waves)


def arc_shell(b, matrix, length, radius, wall, a0, a1, seg_a=20, seg_l=10):
    """Gebogene Schale mit Wandstärke (z. B. Schirm der Bankerlampe): ein Stück Röhre um die lokale
    x-Achse von Winkel a0 bis a1 (Grad, 0 = nach -y vorn, 90 = oben), Länge entlang x."""
    bm = b.bm
    outer, inner = [], []
    for i in range(seg_l + 1):
        x = -length / 2 + length * i / seg_l
        row_o, row_i = [], []
        for j in range(seg_a + 1):
            a = math.radians(a0 + (a1 - a0) * j / seg_a)
            d = Vector((0, -math.cos(a), math.sin(a)))
            row_o.append(bm.verts.new(matrix @ (Vector((x, 0, 0)) + d * radius)))
            row_i.append(bm.verts.new(matrix @ (Vector((x, 0, 0)) + d * (radius - wall))))
        outer.append(row_o)
        inner.append(row_i)
    faces = []
    for i in range(seg_l):
        for j in range(seg_a):
            faces.append(bm.faces.new((outer[i][j], outer[i + 1][j], outer[i + 1][j + 1], outer[i][j + 1])))
            faces.append(bm.faces.new((inner[i][j + 1], inner[i + 1][j + 1], inner[i + 1][j], inner[i][j])))
    for i in range(seg_l):
        for j in (0, seg_a):
            faces.append(bm.faces.new((outer[i][j], inner[i][j], inner[i + 1][j], outer[i + 1][j])))
    for i in (0, seg_l):
        for j in range(seg_a):
            faces.append(bm.faces.new((outer[i][j], outer[i][j + 1], inner[i][j + 1], inner[i][j])))
    b._finish_island([v for r in outer + inner for v in r], faces)
    return faces


def pot(kit, base, radius, height, style="classic", slot="pot", soil=True, segs=None, feet=False):
    """Blumentopf als Körper mit Wandstärke und Rand, innen Erde. Liefert die Höhe der Erde
    (Pflanzen setzen dort an) und den Innenradius. style: classic (Terrakotta mit Wulst), cylinder
    (gerade, weich gerundet), bowl (bauchig), urn (Fuß und Bauch), tub (Kübel mit Ringen),
    bucket (Emaille-/Zinkeimer mit Henkel), basket (geflochtener Korb)."""
    r, h = radius, height
    b = kit.part("Topf", slot, bevel=0.003, vary=0.04)
    wall = max(0.006, r * 0.08)
    if style == "cylinder":
        outside = [(0.0, 0.0), (r * 0.96, 0.0), (r, h * 0.05), (r, h * 0.97), (r * 0.97, h)]
        rim_in = r - wall
    elif style == "bowl":
        outside = [(0.0, 0.0), (r * 0.55, 0.0), (r * 0.9, h * 0.35), (r * 1.0, h * 0.75), (r * 0.98, h * 0.95), (r * 0.95, h)]
        rim_in = r * 0.95 - wall
    elif style == "urn":
        outside = [(0.0, 0.0), (r * 0.55, 0.0), (r * 0.56, h * 0.08), (r * 0.36, h * 0.14), (r * 0.38, h * 0.22),
                   (r * 0.9, h * 0.55), (r * 0.98, h * 0.82), (r * 1.08, h * 0.92), (r * 1.1, h * 0.97), (r * 1.04, h)]
        rim_in = r * 1.04 - wall
    elif style == "tub":
        outside = [(0.0, 0.0), (r * 0.86, 0.0), (r * 0.95, h * 0.5), (r, h * 0.95), (r * 0.98, h)]
        rim_in = r * 0.98 - wall
    elif style == "bucket":
        outside = [(0.0, 0.0), (r * 0.8, 0.0), (r * 0.82, h * 0.03), (r * 0.98, h * 0.94), (r * 1.03, h * 0.97), (r * 1.0, h)]
        rim_in = r - wall * 0.7
    else:  # classic
        outside = [(0.0, 0.0), (r * 0.72, 0.0), (r * 0.9, h * 0.8), (r * 1.06, h * 0.84), (r * 1.08, h * 0.93), (r * 1.04, h)]
        rim_in = r * 1.04 - wall * 1.2
    inside = [(rim_in, h - 0.003), (outside[-2][0] - wall, h * 0.8), (outside[1][0] - wall, wall), (0.0, wall)]
    segs = segs or (32 if r >= 0.12 else 24 if r >= 0.07 else 18)
    b.lathe(outside + inside, base, segs=segs, dent=0.002)
    c = Vector(base)
    if style == "tub":
        for zz in (h * 0.2, h * 0.72):
            rr = r * (0.88 + 0.1 * zz / h)
            b.lathe([(0.0, 0.0), (rr + 0.004, 0.0), (rr + 0.008, 0.007), (rr + 0.004, 0.014), (0.0, 0.014)],
                    c + Vector((0, 0, zz)), segs=segs)
    if style == "bucket":
        hb = kit.part("Henkel", slot if slot.startswith("metal") else "metal", bevel=0.0)
        if "metal" not in kit.M:
            kit.mat("metal", (0.6, 0.6, 0.58), grain="smooth", rough=0.5, metal=0.5)
        top = c + Vector((0, 0, h * 0.9))
        pts = [top + Vector((-r * 1.02, 0, 0)), top + Vector((-r * 0.7, 0, r * 0.7)), top + Vector((0, 0, r * 0.95)),
               top + Vector((r * 0.7, 0, r * 0.7)), top + Vector((r * 1.02, 0, 0))]
        hb.tube(pts, 0.0028, segs=6, smooth=2, round_ends=True)
    if feet:
        for k in range(3):
            a = 2 * math.pi * k / 3 + 0.5
            b.blob(c + Vector((math.cos(a) * r * 0.62, math.sin(a) * r * 0.62, 0.006)), r * 0.12, subdiv=1, lump=0.05, scale=(1, 1, 0.6))
    soil_z = h * 0.86
    if soil:
        if "soil" not in kit.M:
            kit.mat("soil", (0.25, 0.17, 0.11), grain="stone", rough=0.95, vary=0.12, bump=0.4)
        e = kit.part("Erde", "soil", bevel=0.0, vary=0.08, settle=False)
        sr = rim_in - 0.002
        e.lathe([(0.0, 0.0), (sr, 0.0), (sr * 0.97, 0.02), (sr * 0.5, 0.032), (0.0, 0.036)],
                c + Vector((0, 0, soil_z - 0.02)), segs=max(12, segs * 3 // 4), dent=0.004)
    return c + Vector((0, 0, soil_z + 0.012)), rim_in


def frame(b, center, width, height, depth, bar, normal_y=-1, style="flat"):
    """Bilderrahmen (vier Leisten auf Gehrung als ein Ring-Körper), Rückseite bei y = center.y."""
    c = Vector(center)
    hw, hh = width / 2, height / 2
    outline = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
    inner = [(-hw + bar, -hh + bar), (-hw + bar, hh - bar), (hw - bar, hh - bar), (hw - bar, -hh + bar)]
    # Ring aus zwei Umrissen: als Platte mit Loch geht nicht – darum vier Leisten mit Überlappung
    m = Matrix.Translation(c + Vector((0, normal_y * depth / 2, 0)))
    b.box((0, 0, hh - bar / 2), (width, depth, bar), step=0.5, dent=0.0006, matrix=m)
    b.box((0, 0, -hh + bar / 2), (width, depth, bar), step=0.5, dent=0.0006, matrix=m)
    b.box((-hw + bar / 2, 0, 0), (bar, depth * 0.99, height - bar * 1.6), step=0.5, dent=0.0006, matrix=m)
    b.box((hw - bar / 2, 0, 0), (bar, depth * 0.99, height - bar * 1.6), step=0.5, dent=0.0006, matrix=m)
    if style == "gilded":
        # innerer Wulst (Perlstab) für den Goldrahmen
        for zz in (hh - bar, -hh + bar):
            b.tube([c + Vector((-hw + bar, normal_y * depth * 0.6, zz)), c + Vector((hw - bar, normal_y * depth * 0.6, zz))], bar * 0.18, segs=6)
        for xx in (-hw + bar, hw - bar):
            b.tube([c + Vector((xx, normal_y * depth * 0.6, -hh + bar)), c + Vector((xx, normal_y * depth * 0.6, hh - bar))], bar * 0.18, segs=6)
    return outline, inner


def rug(kit, slot, size, thickness=0.012, shape="rect", fringe_slot=None, border=None, step=0.06):
    """Teppich: weiche Platte (rect, oval, round) mit optionaler Bordüre (inset, Farbe) und Fransen."""
    sx, sy = size
    b = kit.part("Teppich", slot, bevel=0.004, vary=0.02, settle=False)
    if shape == "rect":
        outline = SB.round_outline(48)
        # round_outline: Einheitskreis -> Rechteck mit runden Ecken
        pts = []
        for x, y in outline:
            n = 6.0
            r = (abs(x) ** n + abs(y) ** n) ** (1.0 / n)
            pts.append((x / r * sx / 2, y / r * sy / 2))
    else:
        pts = [(math.cos(2 * math.pi * k / 64) * sx / 2, math.sin(2 * math.pi * k / 64) * sy / 2) for k in range(64)]
    b.slab(pts, thickness, Matrix.Identity(4), dent=0.001)
    if border:
        inset, bslot = border
        bb = kit.part("Bordüre", bslot, bevel=0.002, vary=0.02, settle=False)
        inner = [(x * (1 - inset * 2 / sx), y * (1 - inset * 2 / sy)) for x, y in pts]
        bb.slab(inner, 0.002, Matrix.Translation((0, 0, thickness - 0.0005)), dent=0.0)
    if fringe_slot and shape == "rect":
        fb = kit.part("Fransen", fringe_slot, bevel=0.0, vary=0.05, settle=False)
        rnd = random.Random(kit.seed + 5)
        x = -sx / 2 + 0.03
        while x < sx / 2 - 0.02:
            for side in (-1, 1):
                y0 = side * sy / 2 * 0.985
                ln = rnd.uniform(0.04, 0.06)
                fb.tube([Vector((x, y0, thickness * 0.4)), Vector((x + rnd.uniform(-0.008, 0.008), y0 + side * ln * 0.6, 0.0035)),
                         Vector((x + rnd.uniform(-0.01, 0.01), y0 + side * ln, 0.0025))], 0.0022, segs=4, smooth=1, round_ends=True)
            x += 0.018
    return b


# --- Zimmerpflanzen (üppig; Ursprung = Erde, gebaut für einen Topf mit 20 cm Radius) ---

UP = Vector((0, 0, 1))


def lush_fern(p, size=1.0, fronds=20, leaf_mat="box_leaf", stem_mat="stem"):
    """Üppiger Farn: viele gebogene Wedel in zwei Lagen (innen steil, außen überhängend), jeder mit
    Fiederblättchen paarweise bis zur Spitze; junge, eingerollte Wedel in der Mitte."""
    rnd = p.rnd
    for k in range(fronds):
        outer = k % 2 == 0
        a = 2 * math.pi * k / fronds + rnd.uniform(-0.15, 0.15)
        out = Vector((math.cos(a), math.sin(a), 0))
        pts = [out * 0.01 + Vector((0, 0, 0.015))]
        d = (out * (0.55 if outer else 0.25) + UP).normalized()
        L = rnd.uniform(0.42, 0.56) * size * (1.0 if outer else 0.8)
        segs = 11
        for i in range(segs):
            d = (d + out * (0.15 if outer else 0.07) - UP * (0.1 if outer else 0.035)).normalized()
            pts.append(pts[-1] + d * L / segs)
        p.body(stem_mat, vary=0.06).tube(pts, lambda t: 0.0042 * size * (1 - 0.65 * t), segs=5, smooth=1, round_ends=True)
        for i in range(1, len(pts)):
            q = pts[i]
            tang = (pts[i] - pts[i - 1]).normalized()
            side = tang.cross(UP)
            if side.length < 1e-4:
                side = out.cross(UP)
            side.normalize()
            nrm = side.cross(tang).normalized()
            if nrm.z < 0:
                nrm = -nrm
            s = 0.06 * size * (1 - 0.62 * i / len(pts)) * rnd.uniform(0.9, 1.1)
            for sg in (-1, 1):
                p.body(leaf_mat, vary=0.1).leaf(q, (side * sg + tang * 0.45).normalized(), nrm, s, s * 0.42,
                                                shape="narrow", thick=0.0032, curl=0.18, segs=5)
    # eingerollte junge Wedel (Bischofsstäbe)
    for k in range(3):
        a = rnd.uniform(0, 2 * math.pi)
        base = Vector((math.cos(a) * 0.02, math.sin(a) * 0.02, 0.015))
        top = base + Vector((0, 0, 0.12 * size))
        curl = [base, top] + [top + Vector((math.cos(a) * 0.02 * (1 - t / 6) * math.sin(t), math.sin(a) * 0.02 * (1 - t / 6) * math.sin(t),
                                           0.02 * (1 - t / 6) * math.cos(t) - 0.02)) for t in [i * 0.6 for i in range(1, 9)]]
        p.body(stem_mat, vary=0.06).tube(curl, 0.0035 * size, segs=5, smooth=1, round_ends=True)


# --- Export ---

def write_materials(kit, names):
    """Godot-Materialien des Objekts nach assets/materials/furniture/<id>/<rolle>.tres. Liefert
    {Blender-Name: res-Pfad}."""
    out_dir = os.path.join(MAT_DIR, kit.id)
    os.makedirs(out_dir, exist_ok=True)
    result = {}
    for name in names:
        v = SC.GAME_MATERIALS.get(name)
        if v is None:
            continue
        path = os.path.join(out_dir, SC.slug(name) + ".tres")
        res = "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")
        result[name] = res
        c = v["color"]
        head = MARK + " (Möbel „%s“, Material „%s“).\n" % (kit.spec["name"], name)
        if v.get("glass"):
            emit = v.get("emit", 0.0)
            ec = v.get("emit_color") or c
            text = ('[gd_resource type="StandardMaterial3D" format=3]\n\n%s\n[resource]\nresource_name = "%s"\n'
                    'transparency = 1\nalbedo_color = Color(%.3f, %.3f, %.3f, %.2f)\nmetallic_specular = 0.2\nroughness = 0.25\n'
                    % (head, name, c[0], c[1], c[2], v.get("alpha", 0.35)))
            if emit > 0:
                text += ('emission_enabled = true\nemission = Color(%.3f, %.3f, %.3f, 1)\nemission_energy_multiplier = %.3f\n'
                         % (ec[0], ec[1], ec[2], emit * 0.45))
        else:
            c2 = v.get("color2") or c
            c3 = v.get("color3") or (0.95, 0.91, 0.82)
            ec = v.get("emit_color") or c
            emit = v.get("emit", 0.0)
            pattern = {"check": 1, "floral": 2, "tartan": 3}.get(v.get("pattern"), 0)
            text = ('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n%s\n'
                    '[ext_resource type="Shader" path="res://assets/shaders/%s.gdshader" id="1_shader"]\n\n'
                    '[resource]\nresource_name = "%s"\nrender_priority = 0\nshader = ExtResource("1_shader")\n'
                    'shader_parameter/base_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/second_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/third_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/grain = %d\nshader_parameter/stripe_width = %.3f\nshader_parameter/vary = %.3f\n'
                    'shader_parameter/blot_scale = %.3f\nshader_parameter/bump_strength = %.3f\nshader_parameter/rough = %.3f\n'
                    'shader_parameter/metal = %.3f\nshader_parameter/emission_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/emission_energy = %.3f\nshader_parameter/glow = %.3f\n'
                    'shader_parameter/pattern = %d\nshader_parameter/pattern_size = %.3f\n'
                    % (head, "storybook_plant" if v["plant"] else "storybook", name, c[0], c[1], c[2], c2[0], c2[1], c2[2],
                       c3[0], c3[1], c3[2], SC.GRAIN_ID[v.get("grain", "plaster")], v.get("stripes") or 0.0,
                       v.get("vary", 0.08), v.get("scale", 4.0), v.get("bump", 0.25), v.get("rough", 0.85), v.get("metal", 0.0),
                       ec[0], ec[1], ec[2], emit * 0.45, v["glow"], pattern, v.get("pattern_size", 0.04)))
        with open(path, "w") as f:
            f.write(text)
    return result


def write_import(glb_path, mapping):
    """.glb.import: Materialien extern (unsere .tres), Detailstufen an."""
    SC.write_import_settings(mapping, glb_path)


def is_generated(path):
    """Datei fehlt oder stammt noch unverändert vom Bau-Script (dann darf es sie neu schreiben)."""
    if not os.path.exists(path):
        return True
    with open(path, encoding="utf-8") as f:
        head = f.read(600)
    return MARK in head


def g(v):
    """Blender -> Godot (x, z, -y)."""
    return Vector((v[0], v[2], -v[1]))


def gsize(s):
    return Vector((s[0], s[2], s[1]))


def tf(pos, turn=0.0):
    """Godot-Transform als Text (Drehung um die Hochachse in Grad, Blender-Drehung um z)."""
    p = g(pos)
    a = math.radians(turn)
    c, s = math.cos(a), math.sin(a)
    # Drehung um Godot-y (Blender +z gegen den Uhrzeigersinn von oben = Godot +y); Godot schreibt
    # die Basis zeilenweise: (cos, 0, sin | 0, 1, 0 | -sin, 0, cos)
    return "Transform3D(%.5f, 0, %.5f, 0, 1, 0, %.5f, 0, %.5f, %.4f, %.4f, %.4f)" % (c, s, -s, c, p.x, p.y, p.z)


def pascal(name):
    return "".join(part.capitalize() for part in name.split("_"))


def write_scene(kit, bounds, force=False):
    """scenes/furniture/<id>.tscn: Modell (glb), Kollision, Ablageflächen, Fächer, Sitzplätze, Licht."""
    path = os.path.join(SCENE_DIR, kit.id + ".tscn")
    if not force and not is_generated(path):
        print("  Szene von Hand bearbeitet – bleibt:", os.path.relpath(path, ROOT))
        return
    spec = kit.spec
    ext = ['[ext_resource type="PackedScene" path="res://assets/models/furniture/%s.glb" id="1_model"]' % kit.id]
    ids = {}

    def script(key, path_res):
        if key not in ids:
            ids[key] = "%d_%s" % (len(ext) + 1, key)
            ext.append('[ext_resource type="Script" path="%s" id="%s"]' % (path_res, ids[key]))
        return ids[key]

    subs = []
    nodes = []

    def shape(size, kind="Box"):
        sid = "Shape_%d" % len(subs)
        gs = gsize(size)
        subs.append('[sub_resource type="BoxShape3D" id="%s"]\nsize = Vector3(%.4f, %.4f, %.4f)\n' % (sid, max(gs.x, 0.01), max(gs.y, 0.01), max(gs.z, 0.01)))
        return sid

    root = pascal(kit.id)
    lines = ['[node name="%s" type="Node3D"]' % root]
    if kit.light_kind:
        lines.append('script = ExtResource("%s")' % script("light", "res://scripts/objects/light_source.gd"))
        lines.append("kind = %d" % (1 if kit.light_kind == "flame" else 0))
        lines.append("shadow_importance = %d" % {"none": 0, "important": 1, "optional": 2}[kit.shadow])
    nodes.append("\n".join(lines) + "\n")
    nodes.append('[node name="Model" parent="." instance=ExtResource("1_model")]\n')
    # Kollision (fehlt eine Angabe: ein Kasten um das ganze Modell)
    colliders = kit.colliders or [((bounds[0] + bounds[1]) / 2, bounds[1] - bounds[0], 0.0)]
    nodes.append('[node name="Body" type="StaticBody3D" parent="."]\n')
    for i, (c, s, turn) in enumerate(colliders):
        nodes.append('[node name="Shape%d" type="CollisionShape3D" parent="Body"]\ntransform = %s\nshape = SubResource("%s")\n'
                     % (i, tf(c, turn), shape(s)))
    if kit.surfaces:
        nodes.append('[node name="Surfaces" type="Node3D" parent="."]\n')
        for i, (top, sxy, max_h) in enumerate(kit.surfaces):
            sid = shape((sxy[0], sxy[1], 0.03))
            text = ('[node name="Surface%d" type="Area3D" parent="Surfaces"]\ntransform = %s\ncollision_layer = 32\n'
                    'collision_mask = 0\nmonitoring = false\nscript = ExtResource("%s")\n' % (i, tf(top), script("surface", "res://scripts/building/placement_surface.gd")))
            if max_h > 0:
                text += "max_height = %.3f\n" % max_h
            nodes.append(text)
            nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Surfaces/Surface%d"]\nshape = SubResource("%s")\n' % (i, sid))
    if kit.rows:
        nodes.append('[node name="BookShelf" type="Node3D" parent="."]\nscript = ExtResource("%s")\n' % script("shelf", "res://scripts/objects/book_shelf.gd"))
        for i, (top, w, h, d) in enumerate(kit.rows):
            nodes.append('[node name="Row%d" type="Marker3D" parent="BookShelf"]\ntransform = %s\nscript = ExtResource("%s")\n'
                         'width = %.3f\nheight = %.3f\ndepth = %.3f\n' % (i + 1, tf(top), script("row", "res://scripts/objects/book_row.gd"), w, h, d))
        nodes.append('[node name="Interactable" type="Area3D" parent="BookShelf"]\ncollision_layer = 2\ncollision_mask = 0\n'
                     'monitoring = false\nscript = ExtResource("%s")\nprompt_text = "Menü"\n' % script("interact", "res://scripts/interaction/interactable.gd"))
    if kit.seats:
        nodes.append('[node name="Seating" type="Node3D" parent="."]\nscript = ExtResource("%s")\n' % script("seating", "res://scripts/objects/seating.gd"))
        for i, (pos, turn) in enumerate(kit.seats):
            nodes.append('[node name="Seat%d" type="Marker3D" parent="Seating"]\ntransform = %s\nscript = ExtResource("%s")\n'
                         % (i + 1, tf(pos, turn), script("seat", "res://scripts/objects/seat_point.gd")))
        ic, isz = kit.interact or ((bounds[0] + bounds[1]) / 2, bounds[1] - bounds[0])
        nodes.append('[node name="Interactable" type="Area3D" parent="Seating"]\ncollision_layer = 2\ncollision_mask = 0\n'
                     'monitoring = false\nscript = ExtResource("%s")\nprompt_text = "Sitzen"\n' % script("interact", "res://scripts/interaction/interactable.gd"))
        nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Seating/Interactable"]\ntransform = %s\nshape = SubResource("%s")\n'
                     % (tf(ic), shape(isz)))
    if kit.light_kind:
        for i, L in enumerate(kit.lights):
            c = L["color"]
            nodes.append('[node name="Light%d" type="OmniLight3D" parent="."]\ntransform = %s\nlight_color = Color(%.3f, %.3f, %.3f, 1)\n'
                         'light_energy = %.3f\nlight_size = 0.0\nshadow_enabled = %s\nshadow_blur = 2.0\nomni_range = %.2f\n'
                         % (i, tf(L["pos"]), c[0], c[1], c[2], L["energy"], "true" if L["shadow"] else "false", L["range"]))
        ic, isz = kit.interact or ((bounds[0] + bounds[1]) / 2, bounds[1] - bounds[0] + Vector((0.02, 0.02, 0.02)))
        text = ('[node name="Interactable" type="Area3D" parent="."]\ncollision_layer = 2\ncollision_mask = 0\nmonitoring = false\n'
                'script = ExtResource("%s")\nprompt_text = "%s"\n' % (script("interact", "res://scripts/interaction/interactable.gd"),
                                                                   "Löschen" if kit.light_kind == "flame" else "Aus"))
        if "ceiling" in _placements(spec):
            text += "long_reach = true\n"
        nodes.append(text)
        nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Interactable"]\ntransform = %s\nshape = SubResource("%s")\n'
                     % (tf(ic), shape(isz)))
    if kit.book_spot:
        pos, lean = kit.book_spot
        nodes.append('[node name="BookStand" type="Node3D" parent="."]\nscript = ExtResource("%s")\nlean_angle = %.1f\n'
                     % (script("stand", "res://scripts/objects/book_stand.gd"), lean))
        nodes.append('[node name="BookSpot" type="Marker3D" parent="BookStand"]\ntransform = %s\n' % tf(pos))
    connections = []
    if kit.light_kind:
        connections.append('[connection signal="interacted" from="Interactable" to="." method="_on_interactable_interacted"]')
    text = "[gd_scene format=3]\n\n%s – Modell, Kollision, Ablageflächen, Fächer und Licht. Wird beim Neubau\n; überschrieben, solange die Datei unverändert ist (speichert Godot sie, bleibt sie, wie sie ist).\n\n" % MARK
    text += "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n" + "\n".join(nodes) + "\n" + "\n".join(connections) + "\n"
    os.makedirs(SCENE_DIR, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def _placements(spec):
    p = spec.get("place", "floor")
    return [p] if isinstance(p, str) else list(p)


def _gd_string(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def write_data(kit, bounds, force=False):
    """data/furniture/<id>.tres: Datenblatt mit Name, Preis, Stil, Platzierung und Farbvarianten."""
    path = os.path.join(DATA_DIR, kit.id + ".tres")
    if not force and not is_generated(path):
        print("  Datenblatt von Hand bearbeitet – bleibt:", os.path.relpath(path, ROOT))
        return
    spec = kit.spec
    size = bounds[1] - bounds[0]
    # Grundfläche in Rasterfeldern (Breite x Tiefe), mindestens 1
    foot = (max(1, math.ceil(size.x / GRID - 0.15)), max(1, math.ceil(size.y / GRID - 0.15)))
    if _placements(spec)[0] in ("wall", "door"):
        foot = (max(1, math.ceil(size.x / GRID - 0.15)), max(1, math.ceil(size.z / GRID - 0.15)))
    subs = []
    refs = []
    for i, (vid, vname, colors) in enumerate(spec.get("variants", [])):
        entries = ", ".join('"%s": Color(%.3f, %.3f, %.3f, 1)' % (k, c[0], c[1], c[2]) for k, c in colors.items())
        subs.append('[sub_resource type="Resource" id="Variant_%d"]\nscript = ExtResource("2_variant")\nid = "%s"\ndisplay_name = %s\n'
                    'colors = Dictionary[String, Color]({%s})\n' % (i, vid, _gd_string(vname), entries))
        refs.append('SubResource("Variant_%d")' % i)
    placement = 0
    for p in _placements(spec):
        placement |= PLACEMENT[p]
    styles = ", ".join('"%s"' % s for s in spec.get("styles", []))
    lines = [
        '[gd_resource type="Resource" script_class="FurnitureData" load_steps=%d format=3]' % (3 + len(subs)),
        "",
        "%s – Werte gern im Inspektor ändern: Speichert Godot das\n; Datenblatt, überschreibt das Bau-Script es nicht mehr." % MARK,
        "",
        '[ext_resource type="Script" path="res://scripts/data/furniture_data.gd" id="1_data"]',
        '[ext_resource type="Script" path="res://scripts/data/color_variant.gd" id="2_variant"]',
        "",
    ] + subs + [
        "[resource]",
        'script = ExtResource("1_data")',
        'id = "%s"' % kit.id,
        "display_name = %s" % _gd_string(spec["name"]),
        "description = %s" % _gd_string(spec.get("desc", "")),
        "category = %d" % CATEGORIES[spec["category"]],
        'subcategory = "%s"' % spec.get("sub", ""),
        "price = %d" % spec["price"],
        "style_ids = Array[String]([%s])" % styles,
        'scene_path = "res://scenes/furniture/%s.tscn"' % kit.id,
        "footprint = Vector2i(%d, %d)" % foot,
        "is_unlocked = %s" % ("true" if spec.get("unlocked", True) else "false"),
        "is_essential = %s" % ("true" if spec.get("essential") else "false"),
        "is_fixed = %s" % ("true" if spec.get("fixed") else "false"),
        "placement = %d" % placement,
        "books_can_lean = %s" % ("true" if spec.get("lean") else "false"),
        "books_can_lie = %s" % ("true" if spec.get("lie") else "false"),
        'color_variants = Array[ExtResource("2_variant")]([%s])' % ", ".join(refs),
    ]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def bounds_of(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        ev = o.evaluated_get(dg)
        for v in ev.data.vertices:
            p = o.matrix_world @ v.co
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    return lo, hi


def export(kit, force_data=False, render=False):
    """Alles schreiben: .blend, .glb (+ .import, Materialien), Szene, Datenblatt, Vorlage."""
    objs = kit.objects
    flames = kit.flames
    bounds = bounds_of(objs + flames)
    os.makedirs(MODEL_DIR, exist_ok=True)
    os.makedirs(SOURCE_DIR, exist_ok=True)
    blend = os.path.join(SOURCE_DIR, kit.id + ".blend")
    glb = os.path.join(MODEL_DIR, kit.id + ".glb")
    tris, parts = SC.export_objects(objs, [], glb, extra=flames)
    names = list(dict.fromkeys(SC.LAST_EXPORT_MATERIALS + [o.data.materials[0].name for o in flames if o.data.materials]))
    mapping = write_materials(kit, names)
    write_import(glb, mapping)
    write_scene(kit, bounds, force=force_data)
    write_data(kit, bounds, force=force_data)
    os.makedirs(TEMPLATE_DIR, exist_ok=True)
    shutil.copyfile(glb, os.path.join(TEMPLATE_DIR, kit.id + ".glb"))
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    size = bounds[1] - bounds[0]
    print("  %-26s %6d Dreiecke, %2d Teile, %.2f x %.2f x %.2f m" % (kit.id, tris, parts + len(flames), size.x, size.y, size.z))
    return tris
