"""Baut für jedes Wohnhaus der Straße ein eigenes Modell (seit Etappe 4g, Teil 2b).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_street.py
    blender -b --factory-startup --python tools/blender/build_street.py -- Opposite/Opposite1_3

Liest scenes/world/houses.tscn (welche Häuser es gibt, Haustyp = Breite und Türseite),
stellt für jedes Reihenhaus/Wohnhaus eine Beschreibung zusammen (feste Wünsche in SPECIAL,
der Rest per Zufall – aber bei jedem Bau gleich) und schreibt:
    assets/models/houses/street/<Gruppe>_<Name>.glb   eigenes Modell des Hauses
    scenes/world/houses.tscn                          je Haus unique_model, Farben, Wandmaterial
    assets/models/source/street.blend                 die ganze Straße zum Anschauen in Blender
Ladenhäuser, Pub, Eckhäuser und Torhaus behalten ihr Typ-Modell (bzw. den Platzhalter).
Achtung: generate_houses.tscn (Häuser neu aufstellen) überschreibt houses.tscn – danach
dieses Script noch einmal laufen lassen.
"""

import bpy
import math
import os
import random
import re
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
import street_houses as H  # noqa: E402
import build_houses as BH  # noqa: E402

HOUSES_TSCN = os.path.join(S.ROOT, "scenes", "world", "houses.tscn")
HOUSE_DIR = os.path.join(S.ROOT, "scenes", "world", "houses")
OUT_DIR = os.path.join(S.ROOT, "assets", "models", "houses", "street")
STREET_TYPES = ("terrace_45", "terrace_50", "terrace_55", "terrace_60", "residential", "pub")
LANDMARK_TYPES = ("corner_90", "corner_30", "gatehouse")

# Fenster- und Türfarben (sRGB): Braun, Grau, Grün, Blau in Abstufungen, selten Creme
JOINERY = {
    "dark_brown": (0.22, 0.15, 0.1), "brown": (0.33, 0.23, 0.15), "walnut": (0.28, 0.19, 0.13),
    "charcoal": (0.19, 0.2, 0.21), "gray": (0.36, 0.38, 0.38), "light_gray": (0.64, 0.65, 0.63),
    "dark_green": (0.11, 0.2, 0.15), "sage": (0.33, 0.4, 0.34), "forest": (0.16, 0.27, 0.2),
    "navy": (0.1, 0.14, 0.23), "slate_blue": (0.21, 0.28, 0.37), "steel_blue": (0.3, 0.37, 0.44),
    "cream": (0.84, 0.81, 0.72),
    # nur für den Blumenladen (Salbeigrün wie im Konzeptbild)
    "fern": (0.44, 0.55, 0.46),
    # nur für den Pub (fast schwarzes Blau wie im Inspirationsbild)
    "pub_black": (0.08, 0.1, 0.13),
    # Wolle- und Stoffladen (taubenblau wie "Petite Mercerie")
    "dove_blue": (0.42, 0.52, 0.6),
}
WALL_COLORS = {
    "brick": [(0.6, 0.33, 0.25), (0.52, 0.3, 0.24), (0.64, 0.4, 0.3), (0.47, 0.28, 0.22), (0.7, 0.58, 0.42)],
    "render": [(0.9, 0.86, 0.78), (0.86, 0.83, 0.75), (0.82, 0.84, 0.8), (0.78, 0.83, 0.85), (0.88, 0.8, 0.72), (0.84, 0.86, 0.76)],
    "roughcast": [(0.88, 0.85, 0.78), (0.82, 0.8, 0.74), (0.86, 0.82, 0.72)],
    "stone": [(0.84, 0.78, 0.64), (0.78, 0.75, 0.68)],
}

# Besondere Häuser (vor allem in Sichtweite der Bücherei) – alles andere entscheidet der Zufall
SPECIAL = {
    # Pub am Platz hinter der Gasse (Inspiration "Westminster Arms")
    "LibraryRow/Neighbor3": dict(shop="pub", wall="brick", wall_tone=0, joinery="pub_black", accent="pub_black", lintel="brick_arch",
                                 eaves_style="dentil", rooms=0, pots=[], panes="sash22", flower_boxes=True, steps=0, bay=False,
                                 balcony=None, roof="side", roof_mat="slate", quoins=False, shutters=False, string="none",
                                 dormers=0, storeys=2, chimneys=[1], side_ground_window=True),
    "LibraryRow/Neighbor2": dict(wall="brick", wall_tone=4, storeys=3, roof="parapet", balustrade=True, door_style="pilaster",
                                 panes="sash66", balcony="stone", balcony_floor=2, joinery="charcoal", rooms=1, room_kind="living",
                                 eaves_style="cornice", lintel="architrave", quoins=False, fanlight="fan"),
    "LibraryRow/Neighbor4": dict(wall="render", bay=False, steps=2, joinery="slate_blue", roof="side", roof_mat="slate", lintel="hood"),
    "Opposite/Opposite1_1": dict(wall="render", wall_tone=2, storeys=2, roof="mansard", dormers=3, joinery="gray", eaves_style="modillion",
                                 lintel="architrave", string="double"),
    "Opposite/Opposite1_2": dict(wall="brick", wall_tone=0, ivy=-1, eaves_style="corbel", balcony="juliet", balcony_floor=1,
                                 door_style="hood", joinery="dark_green", lintel="brick_arch", flower_boxes=True, setback=1.8),
    "Opposite/Opposite1_3": dict(fachwerk=True, roof="front_gable", roof_mat="clay", jetty=0.3, ground_wall="stone", wall="render",
                                 wall_tone=0, joinery="brown", accent="dark_green", shutters=True, panes="casement", rooms=1,
                                 room_kind="living", door_leaf="glazed"),
    # Der Blumenladen (gegenüber der Bücherei): Ladenfront statt Erdgeschoss, Blumen davor
    "Opposite/Opposite1_4": dict(wall="render", wall_tone=0, quoins=True, shop="flowers", joinery="fern", lintel="flat",
                                 eaves_style="gutter", rooms=0, pots=[], panes="sash22", flower_boxes=True, steps=0, bay=False,
                                 balcony=None, roof="side", roof_mat="clay", accent="fern", frame_cream=True, upper_cols=2,
                                 shutters=False, string="none", dormers=0, storeys=2),
    # Wolle- und Stoffladen rechts neben dem Blumenladen (Inspiration "Wolleshop"): zwei Etagen,
    # Giebel zur Straße, taubenblaue Ladenfront
    "Opposite/Opposite1_5": dict(shop="wool", wall="render", wall_tone=0, storeys=2, roof="front_gable", roof_mat="clay",
                                 joinery="dove_blue", accent="dove_blue", frame_cream=True, rooms=0, pots=[], steps=0, bay=False,
                                 balcony=None, flower_boxes=True, shutters=False, lintel="flat", string="none", dormers=0,
                                 panes="sash22", quoins=False, upper_cols=2),
    "Opposite/Opposite2_1": dict(wall="stone", storeys=3, joinery="dark_brown", eaves_style="modillion", lintel="architrave",
                                 balcony="stone", balcony_floor=2, string="band", panes="sash66", dormers=[0.0], door_style="pilaster"),
    "Opposite/Opposite2_2": dict(wall="roughcast", joinery="dark_green", accent="sage", shutters=True, roof_mat="clay", eaves_style="fascia"),
    "Opposite/Opposite2_3": dict(wall="brick", wall_tone=1, setback=1.8, door_style="hood", joinery="navy", flower_boxes=True,
                                 lintel="segment", rooms=1, room_kind="living"),
    "Opposite/Opposite2_4": dict(fachwerk=True, roof="side", roof_mat="clay", jetty=0.25, ground_wall="brick", wall="render",
                                 joinery="walnut", shutters=True, panes="casement"),
    "StraightEnd/Street1": dict(wall="brick", wall_tone=2, storeys=3, balcony="juliet", balcony_floor=1, joinery="steel_blue",
                                panes="sash66", lintel="brick_arch", eaves_style="dentil"),
    "StraightEnd/Street2": dict(fachwerk=True, roof="front_gable", roof_mat="clay", jetty=0.3, ground_wall="stone", wall="render",
                                wall_tone=1, joinery="dark_brown", accent="slate_blue", shutters=True, panes="casement"),
    "GateStreet/BehindOuter3": dict(fachwerk=True, roof="front_gable", roof_mat="clay", jetty=0.25, ground_wall="stone", wall="render"),
}


def read_houses():
    """Häuser aus houses.tscn: Schlüssel "Gruppe/Name", Typ, Block-Text."""
    text = open(HOUSES_TSCN).read()
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource type="PackedScene" path="([^"]+)" id="([^"]+)"\]', text)}
    houses = []
    for m in re.finditer(r'\[node name="([^"]+)" parent="([^"]+)"[^\]]*instance=ExtResource\("([^"]+)"\)\]', text):
        type_id = os.path.basename(ext[m.group(3)])[:-5]
        houses.append({"key": "%s/%s" % (m.group(2), m.group(1)), "name": m.group(1), "group": m.group(2), "type": type_id})
    return text, houses


def type_values(type_id):
    text = open(os.path.join(HOUSE_DIR, type_id + ".tscn")).read()

    def value(name, default):
        m = re.search(r"^%s = (-?[0-9.]+)" % name, text, re.M)
        return float(m.group(1)) if m else default

    return {"width": value("width", 5.0), "depth": value("depth", 8.0), "eaves": value("eaves_height", 6.6),
            "door_side": int(value("door_side", 1)), "columns": int(value("window_columns", 0)), "porch": "porch = true" in text}


def house_block(text, house):
    m = re.search(r'\[node name="%s" parent="%s"[^\n]*\n(.*?)(?=\n\[|\Z)' % (re.escape(house["name"]), re.escape(house["group"])), text, re.S)
    return m.group(1) if m else ""


def make_spec(house, block):
    """Beschreibung eines Hauses: feste Wünsche (SPECIAL) + Zufall (fest je Haus)."""
    seed = zlib.crc32(house["key"].encode())
    rnd = random.Random(seed)
    tv = type_values(house["type"])
    sp = dict(SPECIAL.get(house["key"], {}))
    solid = "solid = false" not in block
    near = solid
    W = tv["width"]

    def pick(key, choices, weights=None):
        if key in sp:
            return sp[key]
        return rnd.choices(choices, weights=weights)[0] if weights else rnd.choice(choices)

    fachwerk = sp.get("fachwerk", (not near) and rnd.random() < 0.15)
    wall = pick("wall", ["brick", "render", "roughcast", "stone"], [5, 3, 2, 1])
    if fachwerk:
        wall = "render"
    n_storeys = sp.get("storeys", 3 if rnd.random() < 0.22 else 2)
    storeys = [round(rnd.uniform(3.15, 3.4), 2)] + [round(rnd.uniform(2.9, 3.15), 2) for _ in range(n_storeys - 1)]
    roof = pick("roof", ["side", "side", "side", "parapet", "mansard", "front_gable"] if not fachwerk else ["front_gable", "side"])
    if roof == "parapet" and fachwerk:
        roof = "side"
    roof_mat = pick("roof_mat", ["slate", "slate", "clay"]) if not fachwerk else sp.get("roof_mat", "clay")
    cols_n = tv["columns"] or (2 if W < 5.2 else 3)
    xs = [-W / 2 + W * (i + 0.5) / cols_n for i in range(cols_n)]
    door_side = tv["door_side"]
    door_col = {-1: 0, 1: cols_n - 1, 2: cols_n // 2}.get(door_side, 0)
    ww = pick("window_width", [0.85, 0.95, 1.05, 1.15])
    gw = min(1.35, ww + rnd.choice([0.0, 0.15, 0.3])) if cols_n == 2 else ww
    panes = pick("panes", ["sash22", "sash66", "topbars", "plain", "sash22"] if not fachwerk else ["casement"])
    joinery = JOINERY[pick("joinery", [k for k in JOINERY if k not in ("cream", "fern", "pub_black", "dove_blue")] + ["cream"])]
    accent = JOINERY[sp["accent"]] if "accent" in sp else joinery
    tone = sp.get("wall_tone", rnd.randrange(len(WALL_COLORS[wall])))
    wall_color = WALL_COLORS[wall][tone % len(WALL_COLORS[wall])]
    if fachwerk:
        wall_color = (0.9, 0.86, 0.76)
    bay = sp.get("bay", cols_n == 2 and rnd.random() < 0.2 and not fachwerk)
    bay_col = [i for i in range(cols_n) if i != door_col][0] if bay else -1
    balcony = pick("balcony", [None, None, None, "juliet", "stone"])
    upper_cols = [(x, ww) for x in xs]
    if sp.get("upper_cols") == 2 and cols_n == 3:
        upper_cols = [(-W / 4 - 0.05, ww), (W / 4 + 0.05, ww)]
    balcony_floor = sp.get("balcony_floor", n_storeys - 1 if n_storeys >= 3 else 1)
    balcony_col = -1
    if balcony and not fachwerk:
        balcony_col = cols_n // 2 if cols_n == 3 else [i for i in range(cols_n) if i != door_col][0]
    lintel = pick("lintel", ["flat", "key", "segment", "architrave", "hood"] + (["brick_arch", "brick_arch"] if wall == "brick" else []))
    eaves_style = pick("eaves_style", ["dentil", "modillion", "fascia", "cornice"] + (["corbel"] if wall == "brick" else []))
    dormers = sp.get("dormers", 0 if roof in ("front_gable", "parapet") or rnd.random() < 0.6 else rnd.choice([1, 2]))
    if isinstance(dormers, int):
        dormers = [0.0] if dormers == 1 else [(-W / 4 + W / 2 * k / max(1, dormers - 1)) * 0.9 for k in range(dormers)] if dormers > 1 else []
    spec = {
        "seed": seed, "width": W, "depth": tv["depth"], "storeys": storeys, "eaves": round(sum(storeys), 2),
        "wall": wall, "upper_wall": sp.get("upper_wall", wall), "ground_wall": sp.get("ground_wall", wall),
        "roof": roof, "roof_mat": roof_mat, "pitch": rnd.uniform(48, 55) if roof == "front_gable" else rnd.uniform(33, 42),
        "roof_front_z": {"parapet": -0.34, "mansard": 0.1}.get(roof, 0.25), "mansard_height": 2.1,
        "balustrade": sp.get("balustrade", False),
        "eaves_style": eaves_style, "lintel": lintel if not fachwerk else "timber", "sill": pick("sill", ["stone", "stone", "joinery"]),
        "quoins": sp.get("quoins", wall in ("brick", "render") and rnd.random() < 0.25 and not fachwerk),
        "string": pick("string", ["none", "band", "band", "double"] + (["brick"] if wall == "brick" else [])),
        "columns": [(x, gw) for x in xs], "upper_columns": upper_cols, "door_col": door_col,
        "door_style": "porch" if tv["porch"] else pick("door_style", ["simple", "simple", "pilaster", "hood"]),
        "door_leaf": pick("door_leaf", ["panel", "panel", "glazed"]), "fanlight": pick("fanlight", ["bars", "bars", "fan"]),
        "steps": sp.get("steps", 0 if not near else rnd.choice([0, 0, 0, 1])),
        "panes": panes, "panes_ground": panes if rnd.random() < 0.7 else ("topbars" if panes != "casement" else "casement"),
        "ground_window": (0.8, min(1.75, storeys[0] - 1.35)),
        "upper_sill": 0.75 if n_storeys == 2 else 0.8, "upper_window_h": rnd.uniform(1.5, 1.8),
        "bay_col": bay_col, "balcony": balcony, "balcony_floor": balcony_floor, "balcony_col": balcony_col,
        "flower_boxes": sp.get("flower_boxes", rnd.random() < 0.45), "shutters": sp.get("shutters", fachwerk or rnd.random() < 0.1),
        "fachwerk": fachwerk, "jetty": sp.get("jetty", 0.25 if fachwerk else 0.0),
        "ivy": sp.get("ivy", rnd.choice([-1, 1]) if wall == "brick" and rnd.random() < 0.15 else 0),
        "dormers": dormers, "chimneys": sp.get("chimneys", rnd.choice([[-1], [1], [-1, 1], []])),
        "rooms": sp.get("rooms", 1 if near and rnd.random() < 0.35 else 0), "room_kind": sp.get("room_kind", rnd.choice(["living", "kitchen"])),
        "room_floor": 0, "pots": sp.get("pots", rnd.choice([[], [], [-1], [1]]) if near else []),
        "setback": sp.get("setback", 0.0), "shop": sp.get("shop"), "frame_cream": sp.get("frame_cream", False),
        "side_ground_window": sp.get("side_ground_window", False),
        "closed_share": sp.get("closed_share", 0.15), "closed_ground": sp.get("closed_ground", False),
        "party_color": rnd.choice([(0.58, 0.33, 0.25), (0.52, 0.31, 0.24), (0.62, 0.38, 0.28)]),
        "downpipe_side": 1 if door_side < 0 else -1,
        "colors": {"wall": wall_color, "door": joinery, "accent": accent},
    }
    if spec["steps"] and spec["door_style"] == "porch":
        spec["steps"] = 1
    if spec["shop"]:
        spec["door_style"] = "simple"
    return spec


def _edited_by_hand(glb):
    """Wurde das Modell in Blender selbst bearbeitet und exportiert? Dann nicht überschreiben
    (unsere .glb tragen "Cozy Bücherei" als Erzeuger; ein Blender-Export nicht)."""
    if not os.path.exists(glb):
        return False
    with open(glb, "rb") as f:
        head = f.read(4096)
    return b"Cozy B" not in head


def _transform(block):
    m = re.search(r"transform = Transform3D\(([^)]*)\)", block)
    v = [float(t) for t in m.group(1).split(",")]
    return v[9], v[11], v[0], v[6]


def exposures(houses, text, specs):
    """Welche Seitenwände frei zu sehen sind: je Haus {Seite: ("full",) / ("partial", Länge)}.
    Bündiger Nachbar = verdeckt; Ecke eines Nachbarn auf der eigenen Seitenwand = nur das Stück
    davor frei (Nachbar zurückgesetzt); sonst ganz frei (Gasse, Ende der Reihe)."""
    shapes = []
    for h in houses:
        block = house_block(text, h)
        px, pz, c, sn = _transform(block)
        tv = type_values(h["type"])
        sb = specs[h["key"]]["setback"] if h["key"] in specs else 0.0
        shapes.append((h["key"], px, pz, c, sn, tv["width"], tv["depth"], sb))

    def at(shape, lx, lz):
        _, px, pz, c, sn = shape[:5]
        return (px + lx * c + lz * sn, pz - lx * sn + lz * c)

    def seg_dist(p, a, b2):
        ax, az = a
        bx, bz = b2
        dx, dz = bx - ax, bz - az
        ln2 = dx * dx + dz * dz
        t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / ln2)) if ln2 > 0 else 0.0
        return math.hypot(p[0] - (ax + t * dx), p[1] - (az + t * dz))

    result = {}
    for a in shapes:
        if a[0] not in specs:
            continue
        sides = {}
        for sgn in (-1, 1):
            corner = at(a, sgn * a[5] / 2, -a[7])
            back = at(a, sgn * a[5] / 2, -a[6])
            hidden = False
            partial = None
            for bshape in shapes:
                if bshape[0] == a[0]:
                    continue
                for s2 in (-1, 1):
                    bc = at(bshape, s2 * bshape[5] / 2, -bshape[7])
                    bb = at(bshape, s2 * bshape[5] / 2, -bshape[6])
                    if math.hypot(bc[0] - corner[0], bc[1] - corner[1]) < 0.45 or seg_dist(corner, bc, bb) < 0.45:
                        hidden = True
                    elif seg_dist(bc, corner, back) < 0.45:
                        d = math.hypot(bc[0] - corner[0], bc[1] - corner[1])
                        partial = d if partial is None else min(partial, d)
            if not hidden:
                sides[sgn] = ("partial", partial) if partial is not None else ("full",)
        result[a[0]] = sides
    return result


def landmark_spec(house, block):
    """Beschreibung für Eckhäuser und Torhaus (Maße aus der Haustyp-Szene)."""
    seed = zlib.crc32(house["key"].encode())
    rnd = random.Random(seed)
    t = house["type"]
    tv = type_values(t)
    text = open(os.path.join(HOUSE_DIR, t + ".tscn")).read()

    def val(name, default):
        m = re.search(r"^%s = (-?[0-9.]+)" % name, text, re.M)
        return float(m.group(1)) if m else default
    spec = {"seed": seed, "kind": "gate" if t == "gatehouse" else "corner", "width": tv["width"], "depth": tv["depth"],
            "eaves": tv["eaves"], "lintel": "flat", "sill": "stone", "panes": "sash22", "roof_mat": "clay" if t != "corner_30" else "slate",
            "wall": "brick", "frame_cream": False, "door_style": "simple"}
    if t == "gatehouse":
        spec.update(passage_width=val("passage_width", 6.5), arch_spring=val("arch_spring", 2.6), masonry_height=val("masonry_height", 6.4),
                    sign_band_height=val("sign_band_height", 0.5), jetty=val("jetty", 0.25), pitch=45.0, roof_mat="clay",
                    colors={"wall": (0.58, 0.33, 0.25), "door": JOINERY["forest"], "accent": JOINERY["forest"]})
    else:
        storeys = 2
        spec.update(corner_angle=val("corner_angle", 90.0), chamfer_width=val("chamfer_width", 2.2), side_length=val("side_length", 5.0),
                    roof_rise=1.8, storeys=[tv["eaves"] / storeys] * storeys,
                    wall="brick" if t == "corner_90" else "render", lintel="flat",
                    # Teestube: Tür und Schild auf der Wand zur langen Straße (die Schräge sieht man kaum)
                    door_edge=2 if t == "corner_90" else 1,
                    # Teestube: schwarz mit Gold, rosa Raum; Bäckerei: Petrol, rote Markisen, cremefarbener Raum
                    shop="tea" if t == "corner_90" else "bakery",
                    room_color=(0.88, 0.76, 0.74) if t == "corner_90" else (0.92, 0.88, 0.78),
                    hanging_sign=t == "corner_90",
                    colors={"wall": (0.62, 0.38, 0.28) if t == "corner_90" else (0.88, 0.84, 0.74),
                            "door": (0.07, 0.07, 0.08) if t == "corner_90" else (0.12, 0.27, 0.28),
                            "accent": (0.07, 0.07, 0.08) if t == "corner_90" else (0.66, 0.18, 0.18)})
    return spec


def write_tscn(text, built):
    """houses.tscn: je Haus unique_model, Farben und Wandmaterial "wie gebaut" eintragen."""
    text = re.sub(r'\[ext_resource type="PackedScene" path="res://assets/models/houses/street/[^"]+" id="[^"]+"\]\n', "", text)
    lines = []
    for key, res_id, path, colors in built:
        lines.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (path, res_id))
    last = list(re.finditer(r'\[ext_resource [^\n]*\]\n', text))[-1]
    text = text[:last.end()] + "\n".join(lines) + "\n" + text[last.end():]
    for key, res_id, path, colors in built:
        group, name = key.split("/")
        pat = re.compile(r'(\[node name="%s" parent="%s"[^\n]*\n)(.*?)(?=\n\[|\Z)' % (re.escape(name), re.escape(group)), re.S)
        m = pat.search(text)
        body = m.group(2)
        body = "\n".join(l for l in body.split("\n") if not re.match(r"(unique_model|wall_color|door_color|accent_color|wall_material) =", l))

        def col(c):
            return "Color(%.3f, %.3f, %.3f, 1)" % c
        extra = ['unique_model = ExtResource("%s")' % res_id, "wall_color = " + col(colors["wall"]),
                 "door_color = " + col(colors["door"]), "accent_color = " + col(colors["accent"]), "wall_material = 1"]
        lines_body = body.rstrip("\n").split("\n")
        # nach der transform-Zeile einfügen
        out = []
        for l in lines_body:
            out.append(l)
            if l.startswith("transform ="):
                out.extend(extra)
        text = text[:m.start(2)] + "\n".join(out) + text[m.end(2):]
    with open(HOUSES_TSCN, "w") as f:
        f.write(text)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = [a for a in argv if not a.startswith("--")]
    check = "--check" in argv
    if check:
        S.SHOW_BACKFACES = True
    text, houses = read_houses()
    specs = {}
    for house in houses:
        if house["type"] in STREET_TYPES:
            specs[house["key"]] = make_spec(house, house_block(text, house))
    for key, sides in exposures(houses, text, specs).items():
        specs[key]["exposed"] = sides
    for house in houses:
        if house["type"] in LANDMARK_TYPES:
            specs[house["key"]] = landmark_spec(house, house_block(text, house))
    # Schild-Bilder der Läden (nur fehlende werden neu gezeichnet)
    shop_signs = {"flowers": BH.prepare_signs("flower_shop"), "pub": BH.prepare_signs("pub"), "wool_shop": BH.prepare_signs("wool_shop"),
                  "corner_90": BH.prepare_signs("corner_90"), "corner_30": BH.prepare_signs("corner_30"),
                  "gatehouse": BH.prepare_signs("gatehouse")}
    sign_set = {"flowers": "flower_shop", "pub": "pub", "wool": "wool_shop"}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    os.makedirs(OUT_DIR, exist_ok=True)
    built = []
    for house in houses:
        if house["key"] not in specs:
            continue
        block = house_block(text, house)
        spec = specs[house["key"]]
        file_id = house["key"].replace("/", "_")
        glb = os.path.join(OUT_DIR, file_id + ".glb")
        res = "res://assets/models/houses/street/%s.glb" % file_id
        res_id = "u_" + file_id
        if (not only or house["key"] in only) and _edited_by_hand(glb):
            print("%-26s selbst bearbeitet – bleibt, wie es ist" % house["key"])
        elif not only or house["key"] in only:
            kind = spec.get("kind")
            signs = house["type"] if kind else sign_set.get(spec.get("shop"))
            if kind == "corner":
                b = H.build_corner(file_id, spec)
            elif kind == "gate":
                b = H.build_gatehouse(file_id, spec)
            else:
                b = H.build_house(file_id, spec)
            tris = S.write_glb(b, glb)
            S.write_import_settings(glb, shop_signs.get(signs) or shop_signs.get(sign_set.get(spec.get("shop"))))
            if kind:
                print("%-26s %-12s %5d Dreiecke" % (house["key"], house["type"], tris))
            else:
                print("%-26s %-12s %5d Dreiecke  %s, %s, %d Geschosse%s%s  Seiten: %s" % (
                    house["key"], house["type"], tris, spec["wall"], spec["roof"], len(spec["storeys"]),
                    ", Fachwerk" if spec["fachwerk"] else "", ", Laden" if spec["shop"] else "", spec.get("exposed")))
            S.SIGN_PREFIX = (signs + "_") if signs else ""
            obj = S.to_blender(b, spec["colors"])
            px, pz, c, sn = _transform(block)
            obj.location = (px, -pz, 0)
            obj.rotation_euler = (0, 0, math.atan2(sn, c))
        built.append((house["key"], res_id, res, spec["colors"]))
    if check:
        # Prüfbilder je Haus (mit Nachbarn): von vorn und schräg von beiden Seiten, Rückseiten
        # pink. Nichts wird gespeichert oder eingetragen.
        _check_images(text, houses, specs, only)
        return
    write_tscn(text, built)
    blend = os.path.join(S.ROOT, "assets", "models", "source", "street.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True, compress=True)
    print("Fertig: %d Häuser" % len(built))


def _check_images(text, houses, specs, only):
    S.setup_render(resolution=(900, 700), samples=8)
    out = os.path.join(S.ROOT, "screenshots", "blender", "street_check")
    os.makedirs(out, exist_ok=True)
    for house in houses:
        if house["key"] not in specs or (only and house["key"] not in only):
            continue
        px, pz, c, sn = _transform(house_block(text, house))
        e = specs[house["key"]]["eaves"]
        far = 1.8 if specs[house["key"]].get("kind") == "gate" else 1.0

        def world(lx, ly, lz):
            return (px + lx * c + lz * sn, ly, pz - lx * sn + lz * c)
        name = house["key"].replace("/", "_")
        for view, (cam, target) in {
            "front": ((0, 1.7, 6.5 * far), (0, e * 0.5, 0)),
            "left": ((-4.5 * far, 1.7, 4.0 * far), (0.3, e * 0.45, -0.5)),
            "right": ((4.5 * far, 1.7, 4.0 * far), (-0.3, e * 0.45, -0.5)),
            "near": ((0.8, 1.6, 2.2), (0.0, 1.6, -1.0)),
        }.items():
            S.render_view(os.path.join(out, "%s-%s.png" % (name, view)), world(*cam), world(*target), lens=24)


if __name__ == "__main__":
    main()
