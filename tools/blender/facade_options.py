"""Die Auswahl für die Bücherei-Fassade (Etappe 6b, neu in 6c): Datenblätter data/facade/<kategorie>_<id>.tres
(FacadeOption) und die Materialien zum Austauschen (Mauerwerk, Naturstein, Ecksteine, Schild-Balken,
Markisenstoffe) in assets/materials/facade/. Wird am Ende von build_storybook_facade.py geschrieben
(auch allein: python3 tools/blender/facade_options.py).

Kategorien (in der App „Fassade“):
    wall / quoins              Mauerwerk der ganzen Fassade (Material) und Ecksteine (mit/ohne)
    ground / ground_color      Erdgeschoss: Mauerwerk wie oben, Naturstein oder Holzfront; Anstrich unten
    fascia                     Schild-Balken (Farbe, Holz oder Stein)
    window_ground / window     Fenster unten und oben (Form, Größe, Sprossen, Erker)
    frame_color                Rahmenfarbe oben
    door / door_lights / door_color   Türblatt, Seiten-/Oberlichter, Türfarbe
    awning / fabric            Markise und Stoff
    box / basket / plants / fullness  Blumenkästen, Ampeln, Pflanzenmischung, Fülle
    deco                       Deko draußen vor der Tür
Jede Option ist frei („unlocked“) oder gesperrt – zum Start frei: die alte Fassade, Backstein beige oder
rot, mit oder ohne Ecksteine. Preise in Talern – nur Änderungen kosten etwas.
"""

import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(ROOT, "data", "facade")
MAT_DIR = os.path.join(ROOT, "assets", "materials", "facade")
MARK = "; Erzeugt von tools/blender/facade_options.py"
GRAIN = {"plaster": 0, "stone": 1, "wood": 2, "brick": 3, "fabric": 4, "leaf": 5, "smooth": 6, "paint": 7, "ashlar": 8, "boards": 9}
PATTERN = {"check": 1, "floral": 2, "tartan": 3}
M = "res://assets/models/facade/%s.glb"

# Farben (sRGB wie im Inspektor); "weathered_*" = alt und verwittert (abblätternde Farbe)
PAINTS = [("green", "Bücherei-Grün", (0.13, 0.25, 0.18)), ("navy", "Nachtblau", (0.12, 0.16, 0.3)),
          ("bordeaux", "Bordeaux", (0.38, 0.1, 0.13)), ("cream", "Creme", (0.86, 0.82, 0.72)),
          ("sage", "Salbei", (0.42, 0.52, 0.42)), ("black", "Kohlschwarz", (0.11, 0.11, 0.12))]
FRAMES = [("cream", "Creme", (0.9, 0.86, 0.76)), ("white", "Weiß", (0.95, 0.94, 0.9)), ("green", "Grün", (0.13, 0.25, 0.18)),
          ("black", "Schwarz", (0.12, 0.12, 0.12)), ("blue", "Taubenblau", (0.36, 0.46, 0.6)), ("red", "Ochsenblut", (0.5, 0.17, 0.15))]
DOORS = [("green", "Bücherei-Grün", (0.13, 0.25, 0.18)), ("navy", "Nachtblau", (0.12, 0.16, 0.3)),
         ("red", "Briefkastenrot", (0.62, 0.16, 0.14)), ("yellow", "Senfgelb", (0.85, 0.66, 0.25)),
         ("sage", "Salbei", (0.42, 0.52, 0.42)), ("plum", "Pflaume", (0.36, 0.2, 0.32))]
OLD_GREEN = (0.24, 0.33, 0.27)
OLD_CREAM = (0.8, 0.76, 0.66)
BRICK_JOINT = (0.57, 0.5, 0.42)

# Mauerwerk (Material; frei = zum Start wählbar)
WALLS = [
    ("old_brick", "Alter Backstein", True, 0, dict(color=(0.6, 0.36, 0.26), grain="brick", color2=(0.6, 0.55, 0.48), bump=0.32, rough=0.94,
                                                   vary=0.09, weather=1.0, weather_color=(0.83, 0.77, 0.67))),
    ("brick_red", "Backstein rot", True, 120, dict(color=(0.66, 0.33, 0.24), grain="brick", color2=(0.62, 0.55, 0.47), bump=0.28, rough=0.92, vary=0.07)),
    ("brick_beige", "Backstein beige", True, 120, dict(color=(0.84, 0.72, 0.54), grain="brick", color2=(0.66, 0.62, 0.56), bump=0.28, rough=0.92, vary=0.06)),
    ("brick_brown", "Backstein braun", False, 120, dict(color=(0.6, 0.38, 0.27), grain="brick", color2=BRICK_JOINT, bump=0.28, rough=0.92, vary=0.07)),
    ("render_white", "Weißer Putz", False, 140, dict(color=(0.93, 0.91, 0.86), grain="plaster", bump=0.3, rough=0.93, vary=0.06, scale=1.4)),
    ("render_cream", "Creme-Putz", False, 140, dict(color=(0.92, 0.85, 0.7), grain="plaster", bump=0.3, rough=0.93, vary=0.07, scale=1.4)),
    ("render_rose", "Rosé-Putz", False, 140, dict(color=(0.9, 0.75, 0.7), grain="plaster", bump=0.3, rough=0.93, vary=0.07, scale=1.4)),
    ("roughcast", "Rauputz", False, 140, dict(color=(0.86, 0.82, 0.74), grain="plaster", bump=0.75, rough=0.96, vary=0.1, scale=3.0)),
    ("stone", "Naturstein", False, 200, dict(color=(0.8, 0.74, 0.62), grain="ashlar", color2=(0.6, 0.56, 0.5), bump=0.3, rough=0.92, vary=0.09)),
    ("timber", "Holzbretter", False, 180, dict(color=(0.56, 0.41, 0.28), grain="boards", bump=0.6, rough=0.75, vary=0.06)),
    ("timber_painted", "Bretter gestrichen", False, 180, dict(color=(0.6, 0.66, 0.66), grain="boards", bump=0.6, rough=0.85, vary=0.04)),
]
STONES = [("sand", "Naturstein hell", dict(color=(0.84, 0.76, 0.62), grain="ashlar", color2=(0.62, 0.58, 0.52), bump=0.3, rough=0.92, vary=0.09)),
          ("grey", "Naturstein grau", dict(color=(0.64, 0.62, 0.58), grain="ashlar", color2=(0.48, 0.46, 0.44), bump=0.3, rough=0.92, vary=0.09))]
QUOINS = [("sandstone", "Ecksteine Sandstein", True, dict(color=(0.86, 0.78, 0.63), grain="stone", bump=0.3, rough=0.9, vary=0.1)),
          ("grey", "Ecksteine grau", False, dict(color=(0.66, 0.65, 0.62), grain="stone", bump=0.3, rough=0.9, vary=0.1))]
FASCIA_MATS = [("oak", "Eiche natur", dict(color=(0.55, 0.38, 0.22), grain="wood", bump=0.1, rough=0.7, vary=0.08)),
               ("stone_sand", "Stein hell", dict(color=(0.84, 0.77, 0.64), grain="stone", bump=0.25, rough=0.9, vary=0.08)),
               ("stone_grey", "Stein grau", dict(color=(0.62, 0.61, 0.58), grain="stone", bump=0.25, rough=0.9, vary=0.08))]
FABRIC = dict(grain="fabric", rough=0.95, vary=0.04, wind=0.04)
FABRICS = [
    ("stripes_red", "Streifen rot", dict(FABRIC, color=(0.93, 0.88, 0.78), color2=(0.66, 0.2, 0.18), stripes=0.13)),
    ("stripes_green", "Streifen grün", dict(FABRIC, color=(0.93, 0.88, 0.78), color2=(0.25, 0.42, 0.3), stripes=0.13)),
    ("stripes_blue", "Streifen blau", dict(FABRIC, color=(0.95, 0.93, 0.88), color2=(0.25, 0.36, 0.58), stripes=0.1)),
    ("plain_mustard", "Senf", dict(FABRIC, color=(0.84, 0.66, 0.3))),
    ("plain_sage", "Salbei", dict(FABRIC, color=(0.56, 0.64, 0.52))),
    ("plain_terracotta", "Terrakotta", dict(FABRIC, color=(0.74, 0.42, 0.3))),
    ("check_blue", "Karo blau", dict(FABRIC, color=(0.35, 0.48, 0.7), pattern="check", pattern_size=0.06, color3=(0.96, 0.94, 0.88))),
    ("floral_cream", "Blümchen", dict(FABRIC, color=(0.93, 0.89, 0.8), pattern="floral", pattern_size=0.09, color2=(0.86, 0.45, 0.52),
                                       color3=(0.95, 0.82, 0.35))),
]
# Fenster: (id, Name, Form, Breite, Höhe, Unterkante, Stich, Sprossen (Spalten, Reihen), Erker-Tiefe, Preis)
SHOP_WINDOWS = [
    ("sash", "Sprossenfenster", "rect", 2.4, 2.3, 0.3, 0.0, (4, 4), 0.0, 0),
    ("glass", "Ganz aus Glas", "rect", 2.4, 2.3, 0.3, 0.0, (1, 1), 0.0, 240),
    ("arched", "Bogenfenster", "arch", 2.4, 2.3, 0.3, 0.45, (4, 3), 0.0, 280),
    ("round", "Rundfenster", "round", 2.0, 2.0, 0.45, 0.0, (2, 2), 0.0, 300),
    ("bay", "Erkerfenster", "rect", 2.4, 2.25, 0.32, 0.0, (4, 3), 0.42, 420),
]
UPPER_WINDOWS = [
    ("sash", "Sprossenfenster", "rect", 0.95, 1.45, 4.27, 0.0, (2, 3), 0.0, 0),
    ("glass", "Ganz aus Glas", "rect", 0.95, 1.45, 4.27, 0.0, (2, 1), 0.0, 150),
    ("arched", "Bogenfenster", "arch", 0.95, 1.45, 4.27, 0.3, (2, 3), 0.0, 150),
    ("round", "Rundfenster", "round", 0.95, 0.95, 4.52, 0.0, (2, 2), 0.0, 180),
    ("bay", "Erker", "rect", 1.35, 1.53, 4.23, 0.0, (3, 2), 0.36, 300),
]
# Türblätter: (id, Name, Form des Blatts, Preis)
DOOR_LEAVES = [("panelled", "Kassettentür", "rect", 0), ("glazed", "Glastür", "rect", 90), ("cottage", "Landhaustür", "rect", 90),
               ("arched", "Bogenglas-Tür", "rect", 90), ("round_glazed", "Rundbogentür mit Glas", "arch", 140),
               ("round_cottage", "Rundbogen-Landhaustür", "arch", 140)]
# Seiten- und Oberlichter: (id, Name, Breite je Seite, Höhe oben, frei, Preis)
DOOR_LIGHTS = [("transom", "Oberlicht", 0.0, 0.32, True, 0), ("none", "Ohne Fenster", 0.0, 0.0, False, 40),
               ("sidelights", "Seitenlichter", 0.14, 0.0, False, 120), ("both", "Seiten- und Oberlicht", 0.14, 0.32, False, 150)]
# Pflanzenmischungen: (id, Name, Farbtupfer, Kasten-Pflanzen, Korb-Pflanzen, Ranken, frei)
MIXES = [
    ("colorful", "Farbenfroh", (0.92, 0.38, 0.42),
     ["box_geranium_red", "box_petunia_purple", "box_lobelia", "box_begonia_pink", "box_mixed", "potfill_marguerite", "box_geranium_coral"],
     ["basket_trailing_red", "basket_trailing_purple", "basket_trailing_blue", "basket_fuchsia"], ["rim_flowers", "rim_bacopa", "rim_ivy"], True),
    ("green", "Ganz grün", (0.3, 0.5, 0.28),
     ["box_ivy", "box_herbs", "potfill_fern", "potfill_hosta", "potfill_grass", "potfill_hosta_lime", "potfill_rosemary"],
     ["potfill_fern", "potfill_trailing", "potfill_hosta"], ["rim_ivy", "rim_ivy_long", "rim_grass"], False),
    ("pastel", "Pastell", (0.92, 0.7, 0.8),
     ["box_geranium_pink", "box_petunia_white", "box_lobelia_white", "box_heather", "box_begonia_pink", "potfill_hydrangea_pink",
      "potfill_heather_white"],
     ["basket_trailing_pink", "basket_fuchsia", "potfill_hydrangea_blue"], ["rim_bacopa", "rim_flowers"], False),
    ("wild", "Wild und rankend", (0.55, 0.62, 0.35),
     ["box_ivy", "box_fuchsia", "box_pansy", "potfill_marguerite", "box_herbs", "potfill_grass", "potfill_fuchsia"],
     ["potfill_trailing", "basket_trailing_blue", "basket_fuchsia"], ["rim_ivy_long", "rim_grass_flowers", "rim_ivy", "rim_grass"], False),
    ("cottage", "Bauerngarten", (0.62, 0.5, 0.8),
     ["potfill_lavender", "potfill_marguerite", "box_pansy", "potfill_dahlia", "box_geranium_coral", "potfill_rosemary", "potfill_mums"],
     ["basket_trailing_pink", "basket_trailing_purple", "basket_fuchsia"], ["rim_flowers", "rim_grass_flowers"], False),
    ("white", "Weiß und Grün", (0.95, 0.95, 0.9),
     ["box_geranium_white", "box_petunia_white", "box_lobelia_white", "box_heather_white", "box_ivy", "potfill_rose_white",
      "potfill_hydrangea_white"],
     ["potfill_hydrangea_white", "potfill_trailing", "potfill_heather_white"], ["rim_bacopa", "rim_ivy"], False),
]
# Deko vor der Tür: (id, Name, Modell, Preis)
DECO = [("bench", "Bank und Töpfe", "deco_bench", 160), ("steps", "Töpfe auf der Treppe", "deco_steps", 90),
        ("sign", "Aufsteller und Laterne", "deco_sign", 110), ("planters", "Kübelpflanzen", "deco_planters", 140),
        ("all", "Alles zusammen", "deco_all", 380)]


def options():
    """(Kategorie, id, Name, Reihenfolge, Preis, frei, Felder)."""
    out = []
    for k, (oid, name, free, price, vals) in enumerate(WALLS):
        out.append(("wall", oid, name, k * 10, price, free, dict(material="facade_wall_" + oid, swatch=vals["color"],
                                                                 hide_quoins=oid.startswith("timber"))))
    out.append(("quoins", "none", "Ohne Ecksteine", 0, 0, True, dict(swatch=(0.85, 0.82, 0.76))))
    for k, (oid, name, free, vals) in enumerate(QUOINS):
        out.append(("quoins", oid, name, 10 + k * 10, 80, free, dict(material="facade_quoin_" + oid, swatch=vals["color"])))
    out.append(("ground", "wall", "Mauerwerk wie oben", 0, 0, True, dict(family="masonry")))
    for k, (oid, name, vals) in enumerate(STONES):
        out.append(("ground", "stone_" + oid, name, 10 + k * 10, 260, False, dict(family="masonry", material="facade_ground_stone_" + oid,
                                                                                    swatch=vals["color"])))
    for k, (oid, name, price) in enumerate([("classic", "Holzfront klassisch", 220), ("beadboard", "Nut und Feder", 200),
                                            ("victorian", "Viktorianisch", 280)]):
        out.append(("ground", oid, name, 40 + k * 10, price, False, dict(family="wood", scene=M % ("ground_" + oid))))
    out.append(("ground_color", "weathered_green", "Altes Grün (verwittert)", 0, 0, True, dict(color=OLD_GREEN, weather=0.85)))
    for k, (oid, name, col) in enumerate(PAINTS):
        out.append(("ground_color", oid, name, 10 + k * 10, 40, False, dict(color=col)))
    out.append(("fascia", "weathered", "Altes Grün (verwittert)", 0, 0, True, dict(color=OLD_GREEN, weather=0.85)))
    for k, (oid, name, col) in enumerate(PAINTS):
        out.append(("fascia", oid, name, 10 + k * 10, 50, False, dict(color=col)))
    for k, (oid, name, vals) in enumerate(FASCIA_MATS):
        out.append(("fascia", oid, name, 80 + k * 10, 90, False, dict(material="facade_fascia_" + oid, swatch=vals["color"])))
    for cat, rows in (("window_ground", SHOP_WINDOWS), ("window", UPPER_WINDOWS)):
        for k, (oid, name, shape, w, h, bottom, rise, grid, bay, price) in enumerate(rows):
            out.append((cat, oid, name, k * 10, price, k == 0, dict(shape=shape, opening=(w, h), bottom=bottom, rise=rise, muntins=grid,
                                                                    bay_depth=bay)))
    out.append(("frame_color", "weathered_cream", "Altes Creme (verwittert)", 0, 0, True, dict(color=OLD_CREAM, weather=0.85)))
    for k, (oid, name, col) in enumerate(FRAMES):
        out.append(("frame_color", oid, name, 10 + k * 10, 30, False, dict(color=col)))
    for k, (oid, name, shape, price) in enumerate(DOOR_LEAVES):
        out.append(("door", oid, name, k * 10, price, k == 0, dict(scene=M % ("door_" + oid), shape=shape)))
    for k, (oid, name, side, transom, free, price) in enumerate(DOOR_LIGHTS):
        out.append(("door_lights", oid, name, k * 10, price, free, dict(side_width=side, transom=transom)))
    out.append(("door_color", "weathered_green", "Altes Grün (verwittert)", 0, 0, True, dict(color=OLD_GREEN, weather=0.85)))
    for k, (oid, name, col) in enumerate(DOORS):
        out.append(("door_color", oid, name, 10 + k * 10, 30, False, dict(color=col)))
    out.append(("awning", "none", "Keine Markise", 0, 0, True, dict(swatch=(0.9, 0.9, 0.88))))
    for k, (oid, name) in enumerate([("classic", "Markise mit Volant"), ("dome", "Korbmarkise"), ("box", "Kastenmarkise")]):
        out.append(("awning", oid, name, 10 + k * 10, 120, False, dict(scene=M % ("awning_" + oid))))
    for k, (oid, name, vals) in enumerate(FABRICS):
        out.append(("fabric", oid, name, k * 10, 30, k == 0, dict(material="facade_fabric_" + oid,
                                                                   swatch=vals["color2"] if "color2" in vals else vals["color"])))
    out.append(("box", "none", "Keine Blumenkästen", 0, 0, True, dict(swatch=(0.9, 0.9, 0.88))))
    for k, (oid, name) in enumerate([("wood", "Holzkasten"), ("zinc", "Zinkkasten"), ("terracotta", "Terrakotta"), ("wicker", "Weidenkorb")]):
        out.append(("box", oid, name, 10 + k * 10, 40, False, dict(scene=M % ("box_" + oid))))
    out.append(("basket", "none", "Keine Ampeln", 0, 0, True, dict(swatch=(0.9, 0.9, 0.88))))
    for k, (oid, name) in enumerate([("bowl", "Tonschale"), ("wire", "Draht mit Moos"), ("wicker", "Weidenkorb")]):
        out.append(("basket", oid, name, 10 + k * 10, 30, False, dict(scene=M % ("basket_" + oid))))
    for k, (oid, name, sw, box, basket, rims, free) in enumerate(MIXES):
        out.append(("plants", oid, name, k * 10, 60, free, dict(plants=box, basket_plants=basket, rim_plants=rims, swatch=sw)))
    for k, (oid, name, amount) in enumerate([("sparse", "Dezent", 0.7), ("lush", "Üppig", 1.0), ("overflowing", "Überquellend", 1.35)]):
        out.append(("fullness", oid, name, k * 10, 0, oid == "lush", dict(amount=amount, swatch=(0.45 + 0.1 * k, 0.6, 0.4))))
    out.append(("deco", "none", "Keine Deko", 0, 0, True, dict(swatch=(0.9, 0.9, 0.88))))
    for k, (oid, name, scene, price) in enumerate(DECO):
        out.append(("deco", oid, name, 10 + k * 10, price, False, dict(scene=M % scene)))
    return out


def _material_text(name, v):
    c = v["color"]
    c2 = v.get("color2") or c
    c3 = v.get("color3") or (0.95, 0.91, 0.82)
    wc = v.get("weather_color") or (0.84, 0.78, 0.68)
    return ('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n%s (Auswahl der Fassade „%s“).\n\n'
            '[ext_resource type="Shader" path="res://assets/shaders/storybook.gdshader" id="1_shader"]\n\n'
            '[resource]\nresource_name = "%s"\nrender_priority = 0\nshader = ExtResource("1_shader")\n'
            'shader_parameter/base_color = Color(%.3f, %.3f, %.3f, 1)\nshader_parameter/second_color = Color(%.3f, %.3f, %.3f, 1)\n'
            'shader_parameter/third_color = Color(%.3f, %.3f, %.3f, 1)\nshader_parameter/grain = %d\n'
            'shader_parameter/stripe_width = %.3f\nshader_parameter/vary = %.3f\nshader_parameter/blot_scale = %.3f\n'
            'shader_parameter/bump_strength = %.3f\nshader_parameter/rough = %.3f\nshader_parameter/metal = 0.0\n'
            'shader_parameter/emission_color = Color(0, 0, 0, 1)\nshader_parameter/emission_energy = 0.0\nshader_parameter/glow = 0.0\n'
            'shader_parameter/pattern = %d\nshader_parameter/pattern_size = %.3f\nshader_parameter/wind_strength = %.3f\n'
            'shader_parameter/weather = %.3f\nshader_parameter/weather_color = Color(%.3f, %.3f, %.3f, 1)\n'
            % (MARK, name, name, c[0], c[1], c[2], c2[0], c2[1], c2[2], c3[0], c3[1], c3[2], GRAIN[v.get("grain", "plaster")],
               v.get("stripes", 0.0), v.get("vary", 0.08), v.get("scale", 4.0), v.get("bump", 0.25), v.get("rough", 0.85),
               PATTERN.get(v.get("pattern"), 0), v.get("pattern_size", 0.04), v.get("wind", 0.0), v.get("weather", 0.0),
               wc[0], wc[1], wc[2]))


def _gd_string(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def _is_generated(path):
    if not os.path.exists(path):
        return True
    with open(path, encoding="utf-8") as f:
        return MARK in f.read(400)


def _vec(v):
    return ", ".join("%.3f" % x for x in v)


def write_all():
    os.makedirs(MAT_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    mats = [("facade_wall_" + oid, vals) for oid, _, _, _, vals in WALLS] + \
           [("facade_ground_stone_" + oid, vals) for oid, _, vals in STONES] + \
           [("facade_quoin_" + oid, vals) for oid, _, _, vals in QUOINS] + \
           [("facade_fascia_" + oid, vals) for oid, _, vals in FASCIA_MATS] + \
           [("facade_fabric_" + oid, vals) for oid, _, vals in FABRICS]
    for name, vals in mats:
        path = os.path.join(MAT_DIR, name + ".tres")
        if _is_generated(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write(_material_text(name, vals))
    count = 0
    wanted = set()
    for category, oid, name, order, price, free, extra in options():
        path = os.path.join(DATA_DIR, "%s_%s.tres" % (category, oid))
        wanted.add(os.path.basename(path))
        if not _is_generated(path):
            continue
        ext = ['[ext_resource type="Script" path="res://scripts/data/facade_option.gd" id="1_data"]']
        lines = ['script = ExtResource("1_data")', 'id = "%s"' % oid, "display_name = %s" % _gd_string(name),
                 'category = "%s"' % category, "unlocked = %s" % ("true" if free else "false"), "order = %d" % order, "price = %d" % price]
        if "scene" in extra:
            lines.append('scene_path = "%s"' % extra["scene"])
        if "material" in extra:
            ext.append('[ext_resource type="Material" path="res://assets/materials/facade/%s.tres" id="2_mat"]' % extra["material"])
            lines.append('material = ExtResource("2_mat")')
        if "color" in extra:
            lines.append("color = Color(%s, 1)" % _vec(extra["color"]))
        if "swatch" in extra:
            lines.append("swatch = Color(%s, 1)" % _vec(extra["swatch"]))
        if "group" in extra:
            lines.append('group = "%s"' % extra["group"])
        for key in ("plants", "basket_plants", "rim_plants"):
            if key in extra:
                lines.append("%s = PackedStringArray(%s)" % (key, ", ".join('"%s"' % p for p in extra[key])))
        if "amount" in extra:
            lines.append("amount = %.2f" % extra["amount"])
        if extra.get("hide_quoins"):
            lines.append("hide_quoins = true")
        if extra.get("weather"):
            lines.append("weather = %.2f" % extra["weather"])
        if "shape" in extra:
            lines.append('shape = "%s"' % extra["shape"])
        if "opening" in extra:
            lines.append("opening = Vector2(%s)" % _vec(extra["opening"]))
            lines.append("bottom = %.3f" % extra["bottom"])
            lines.append("rise = %.3f" % extra["rise"])
            lines.append("muntins = Vector2i(%d, %d)" % tuple(extra["muntins"]))
            lines.append("bay_depth = %.3f" % extra["bay_depth"])
        if "side_width" in extra:
            lines.append("side_width = %.3f" % extra["side_width"])
            lines.append("transom = %.3f" % extra["transom"])
        if "family" in extra:
            lines.append('family = "%s"' % extra["family"])
        text = '[gd_resource type="Resource" script_class="FacadeOption" format=3]\n\n%s – im Inspektor ändern: Speichert Godot das\n' \
               '; Datenblatt, überschreibt das Script es nicht mehr.\n\n%s\n\n[resource]\n%s\n' % (MARK, "\n".join(ext), "\n".join(lines))
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        count += 1
    # Alte, erzeugte Datenblätter, die es nicht mehr gibt (z. B. Kategorien vor Etappe 6c), aufräumen
    removed = 0
    for fn in os.listdir(DATA_DIR):
        if fn.endswith(".tres") and fn not in wanted and _is_generated(os.path.join(DATA_DIR, fn)):
            os.remove(os.path.join(DATA_DIR, fn))
            removed += 1
    print("Fassade: %d Datenblätter, %d Materialien geschrieben, %d alte entfernt." % (count, len(mats), removed))


if __name__ == "__main__":
    write_all()
