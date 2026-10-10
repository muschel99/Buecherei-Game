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

HOUSES_TSCN = os.path.join(S.ROOT, "scenes", "world", "houses.tscn")
HOUSE_DIR = os.path.join(S.ROOT, "scenes", "world", "houses")
OUT_DIR = os.path.join(S.ROOT, "assets", "models", "houses", "street")
STREET_TYPES = ("terrace_45", "terrace_50", "terrace_55", "terrace_60", "residential")

# Fenster- und Türfarben (sRGB): Braun, Grau, Grün, Blau in Abstufungen, selten Creme
JOINERY = {
    "dark_brown": (0.22, 0.15, 0.1), "brown": (0.33, 0.23, 0.15), "walnut": (0.28, 0.19, 0.13),
    "charcoal": (0.19, 0.2, 0.21), "gray": (0.36, 0.38, 0.38), "light_gray": (0.64, 0.65, 0.63),
    "dark_green": (0.11, 0.2, 0.15), "sage": (0.33, 0.4, 0.34), "forest": (0.16, 0.27, 0.2),
    "navy": (0.1, 0.14, 0.23), "slate_blue": (0.21, 0.28, 0.37), "steel_blue": (0.3, 0.37, 0.44),
    "cream": (0.84, 0.81, 0.72),
}
WALL_COLORS = {
    "brick": [(0.6, 0.33, 0.25), (0.52, 0.3, 0.24), (0.64, 0.4, 0.3), (0.47, 0.28, 0.22), (0.7, 0.58, 0.42)],
    "render": [(0.9, 0.86, 0.78), (0.86, 0.83, 0.75), (0.82, 0.84, 0.8), (0.78, 0.83, 0.85), (0.88, 0.8, 0.72), (0.84, 0.86, 0.76)],
    "roughcast": [(0.88, 0.85, 0.78), (0.82, 0.8, 0.74), (0.86, 0.82, 0.72)],
    "stone": [(0.84, 0.78, 0.64), (0.78, 0.75, 0.68)],
}

# Besondere Häuser (vor allem in Sichtweite der Bücherei) – alles andere entscheidet der Zufall
SPECIAL = {
    "LibraryRow/Neighbor2": dict(wall="brick", wall_tone=4, storeys=3, roof="parapet", balustrade=True, door_style="pilaster",
                                 panes="sash66", balcony="stone", balcony_floor=2, joinery="charcoal", rooms=1, room_kind="living",
                                 eaves_style="cornice", lintel="architrave", quoins=False, fanlight="fan"),
    "LibraryRow/Neighbor4": dict(wall="render", bay=True, steps=2, joinery="slate_blue", roof="side", roof_mat="slate", lintel="hood"),
    "Opposite/Opposite1_1": dict(wall="render", wall_tone=2, storeys=2, roof="mansard", dormers=3, joinery="gray", eaves_style="modillion",
                                 lintel="architrave", string="double"),
    "Opposite/Opposite1_2": dict(wall="brick", wall_tone=0, ivy=-1, eaves_style="corbel", balcony="juliet", balcony_floor=1,
                                 door_style="hood", joinery="dark_green", lintel="brick_arch", flower_boxes=True),
    "Opposite/Opposite1_3": dict(fachwerk=True, roof="front_gable", roof_mat="clay", jetty=0.3, ground_wall="stone", wall="render",
                                 wall_tone=0, joinery="brown", accent="dark_green", shutters=True, panes="casement", rooms=1,
                                 room_kind="living", door_leaf="glazed"),
    "Opposite/Opposite1_4": dict(wall="brick", wall_tone=0, quoins=True, door_style="porch", steps=1, joinery="navy", lintel="architrave",
                                 eaves_style="modillion", rooms=1, room_kind="living", pots=[-1, 1], panes="topbars"),
    "Opposite/Opposite1_5": dict(wall="render", wall_tone=3, steps=2, joinery="sage", rooms=1, room_kind="kitchen", flower_boxes=True,
                                 lintel="flat", eaves_style="fascia", roof_mat="clay", pots=[1]),
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
    side_windows = int(re.search(r"side_windows = (-?\d+)", block).group(1)) if "side_windows" in block else 0

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
    joinery = JOINERY[pick("joinery", [k for k in JOINERY if k != "cream"] + ["cream"])]
    accent = JOINERY[sp["accent"]] if "accent" in sp else joinery
    tone = sp.get("wall_tone", rnd.randrange(len(WALL_COLORS[wall])))
    wall_color = WALL_COLORS[wall][tone % len(WALL_COLORS[wall])]
    if fachwerk:
        wall_color = (0.9, 0.86, 0.76)
    bay = sp.get("bay", cols_n == 2 and rnd.random() < 0.2 and not fachwerk)
    bay_col = [i for i in range(cols_n) if i != door_col][0] if bay else -1
    balcony = pick("balcony", [None, None, None, "juliet", "stone"])
    upper_cols = [(x, ww) for x in xs]
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
        "setback": sp.get("setback", 0.0), "side_windows": side_windows, "open_sides": (side_windows,) if side_windows else (),
        "party_color": rnd.choice([(0.58, 0.33, 0.25), (0.52, 0.31, 0.24), (0.62, 0.38, 0.28)]),
        "downpipe_side": 1 if door_side < 0 else -1,
        "colors": {"wall": wall_color, "door": joinery, "accent": accent},
    }
    if spec["steps"] and spec["door_style"] == "porch":
        spec["steps"] = 1
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
    text, houses = read_houses()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    os.makedirs(OUT_DIR, exist_ok=True)
    built = []
    for house in houses:
        if house["type"] not in STREET_TYPES:
            continue
        block = house_block(text, house)
        spec = make_spec(house, block)
        file_id = house["key"].replace("/", "_")
        glb = os.path.join(OUT_DIR, file_id + ".glb")
        res = "res://assets/models/houses/street/%s.glb" % file_id
        res_id = "u_" + file_id
        if not only or house["key"] in only:
            b = H.build_house(file_id, spec)
            tris = S.write_glb(b, glb)
            S.write_import_settings(glb)
            print("%-26s %-12s %5d Dreiecke  %s, %s, %d Geschosse%s" % (
                house["key"], house["type"], tris, spec["wall"], spec["roof"], len(spec["storeys"]),
                ", Fachwerk" if spec["fachwerk"] else ""))
            obj = S.to_blender(b, spec["colors"])
            m = re.search(r"transform = Transform3D\(([^)]*)\)", block)
            v = [float(t) for t in m.group(1).split(",")]
            yaw = math.atan2(v[6], v[0])
            obj.location = (v[9], -v[11], v[10])
            obj.rotation_euler = (0, 0, yaw)
        built.append((house["key"], res_id, res, spec["colors"]))
    write_tscn(text, built)
    blend = os.path.join(S.ROOT, "assets", "models", "source", "street.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True)
    print("Fertig: %d Häuser" % len(built))


main()
