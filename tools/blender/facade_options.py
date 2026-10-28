"""Die Auswahl für die Bücherei-Fassade (Etappe 6b): Datenblätter data/facade/<kategorie>_<id>.tres
(FacadeOption) und die Materialien zum Austauschen (Wandputz/Stein/Holz oben, Naturstein unten,
Markisenstoffe) in assets/materials/facade/. Wird am Ende von build_storybook_facade.py geschrieben
(auch allein: … build_storybook_facade.py -- --data).

Kategorien (in der App „Fassade“ von oben nach unten):
    ground / ground_color      Erdgeschoss (Modell) und sein Anstrich
    upper                      Wand im Obergeschoss (Material; Holz ohne Ecksteine)
    window / frame_color       Fenster oben (Modell) und Rahmenfarbe
    awning / fabric            Markise (Modell oder keine) und Stoff
    door / door_color          Türblatt (Modell) und Türfarbe
    box / box_plant            Blumenkästen oben und was darin wächst (group = Pflanzenart)
    basket / basket_plant      Ampeln an der Schräge und was darin hängt
    fullness                   wie voll die Kästen und Ampeln sind
Preise in Talern – nur Änderungen kosten etwas (die App zählt sie beim „Bauen“ zusammen).
"""

import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(ROOT, "data", "facade")
MAT_DIR = os.path.join(ROOT, "assets", "materials", "facade")
MARK = "; Erzeugt von tools/blender/facade_options.py"
GRAIN = {"plaster": 0, "stone": 1, "wood": 2, "brick": 3, "fabric": 4, "leaf": 5, "smooth": 6, "paint": 7, "ashlar": 8, "boards": 9}
PATTERN = {"check": 1, "floral": 2, "tartan": 3}

# Farben (sRGB wie im Inspektor)
PAINTS = [("green", "Bücherei-Grün", (0.13, 0.25, 0.18)), ("navy", "Nachtblau", (0.12, 0.16, 0.3)),
          ("bordeaux", "Bordeaux", (0.38, 0.1, 0.13)), ("cream", "Creme", (0.86, 0.82, 0.72)),
          ("sage", "Salbei", (0.42, 0.52, 0.42)), ("black", "Kohlschwarz", (0.11, 0.11, 0.12))]
FRAMES = [("cream", "Creme", (0.9, 0.86, 0.76)), ("white", "Weiß", (0.95, 0.94, 0.9)), ("green", "Grün", (0.13, 0.25, 0.18)),
          ("black", "Schwarz", (0.12, 0.12, 0.12)), ("blue", "Taubenblau", (0.36, 0.46, 0.6)), ("red", "Ochsenblut", (0.5, 0.17, 0.15))]
DOORS = [("green", "Bücherei-Grün", (0.13, 0.25, 0.18)), ("navy", "Nachtblau", (0.12, 0.16, 0.3)),
         ("red", "Briefkastenrot", (0.62, 0.16, 0.14)), ("yellow", "Senfgelb", (0.85, 0.66, 0.25)),
         ("sage", "Salbei", (0.42, 0.52, 0.42)), ("plum", "Pflaume", (0.36, 0.2, 0.32))]

# Materialien zum Austauschen: Name -> Werte (wie storybook.gdshader)
WALLS = [
    ("brick_brown", "Ziegel braun", dict(color=(0.6, 0.38, 0.27), grain="brick", color2=(0.57, 0.5, 0.42), bump=0.28, rough=0.92, vary=0.07)),
    ("brick_red", "Ziegel rot", dict(color=(0.66, 0.33, 0.24), grain="brick", color2=(0.62, 0.55, 0.47), bump=0.28, rough=0.92, vary=0.07)),
    ("render_white", "Weißer Putz", dict(color=(0.93, 0.91, 0.86), grain="plaster", bump=0.3, rough=0.93, vary=0.06, scale=1.4)),
    ("render_cream", "Creme-Putz", dict(color=(0.92, 0.85, 0.7), grain="plaster", bump=0.3, rough=0.93, vary=0.07, scale=1.4)),
    ("render_rose", "Rosé-Putz", dict(color=(0.9, 0.75, 0.7), grain="plaster", bump=0.3, rough=0.93, vary=0.07, scale=1.4)),
    ("roughcast", "Rauputz", dict(color=(0.86, 0.82, 0.74), grain="plaster", bump=0.75, rough=0.96, vary=0.1, scale=3.0)),
    ("stone", "Naturstein", dict(color=(0.8, 0.74, 0.62), grain="ashlar", color2=(0.6, 0.56, 0.5), bump=0.3, rough=0.92, vary=0.09)),
    ("timber", "Holzbretter", dict(color=(0.56, 0.41, 0.28), grain="boards", bump=0.6, rough=0.75, vary=0.06)),
    ("timber_painted", "Bretter gestrichen", dict(color=(0.6, 0.66, 0.66), grain="boards", bump=0.6, rough=0.85, vary=0.04)),
]
STONES = [("sand", "Naturstein hell", dict(color=(0.84, 0.76, 0.62), grain="ashlar", color2=(0.62, 0.58, 0.52), bump=0.3, rough=0.92, vary=0.09)),
          ("grey", "Naturstein grau", dict(color=(0.64, 0.62, 0.58), grain="ashlar", color2=(0.48, 0.46, 0.44), bump=0.3, rough=0.92, vary=0.09))]
FABRIC = dict(grain="fabric", rough=0.95, vary=0.04, wind=0.035)
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
# Pflanzen: Art (group) -> [(id, Name, Pflanzen-Szenen, Farbtupfer)]
BOX_PLANTS = [
    ("mixed", "Bunte Mischung", [("mixed", "Bunte Mischung", ["box_mixed", "box_geranium_red", "box_lobelia", "box_petunia_white", "box_ivy"],
                                  (0.9, 0.45, 0.5))]),
    ("geranium", "Geranien", [("geranium_red", "Rot", ["box_geranium_red"], (0.8, 0.15, 0.15)),
                              ("geranium_pink", "Rosa", ["box_geranium_pink"], (0.92, 0.5, 0.62)),
                              ("geranium_coral", "Koralle", ["box_geranium_coral"], (0.95, 0.5, 0.38)),
                              ("geranium_white", "Weiß", ["box_geranium_white"], (0.96, 0.95, 0.92))]),
    ("petunia", "Petunien", [("petunia_pink", "Rosa", ["box_petunia"], (0.9, 0.45, 0.65)),
                             ("petunia_purple", "Lila", ["box_petunia_purple"], (0.55, 0.3, 0.65)),
                             ("petunia_white", "Weiß", ["box_petunia_white"], (0.96, 0.95, 0.92))]),
    ("begonia", "Begonien", [("begonia_pink", "Rosa", ["box_begonia_pink"], (0.92, 0.55, 0.62)),
                             ("begonia_red", "Rot", ["box_begonia_red"], (0.78, 0.18, 0.2))]),
    ("fuchsia", "Fuchsien", [("fuchsia_pink", "Rosa-Lila", ["box_fuchsia"], (0.85, 0.35, 0.6)),
                             ("fuchsia_red", "Rot", ["box_fuchsia_red"], (0.75, 0.15, 0.25))]),
    ("lobelia", "Lobelien", [("lobelia_blue", "Blau", ["box_lobelia"], (0.35, 0.42, 0.8)),
                             ("lobelia_white", "Weiß", ["box_lobelia_white"], (0.96, 0.95, 0.92))]),
    ("heather", "Heide", [("heather_pink", "Rosa", ["box_heather"], (0.8, 0.45, 0.65)),
                          ("heather_white", "Weiß", ["box_heather_white"], (0.95, 0.94, 0.9))]),
    ("pansy", "Stiefmütterchen", [("pansy", "Bunt", ["box_pansy"], (0.6, 0.4, 0.75))]),
    ("herbs", "Kräuter", [("herbs", "Kräuter", ["box_herbs"], (0.45, 0.6, 0.35))]),
    ("ivy", "Efeu", [("ivy", "Efeu", ["box_ivy"], (0.25, 0.42, 0.18))]),
]
BASKET_PLANTS = [
    ("trailing", "Hängepetunien", [("trailing_mix", "Gemischt", ["basket_trailing_pink", "basket_trailing_purple", "basket_trailing_blue"],
                                    (0.75, 0.45, 0.7)),
                                   ("trailing_pink", "Rosa", ["basket_trailing_pink"], (0.9, 0.5, 0.65)),
                                   ("trailing_purple", "Lila", ["basket_trailing_purple"], (0.55, 0.3, 0.65)),
                                   ("trailing_blue", "Blau", ["basket_trailing_blue"], (0.35, 0.42, 0.8)),
                                   ("trailing_red", "Rot", ["basket_trailing_red"], (0.78, 0.18, 0.2))]),
    ("fuchsia", "Fuchsien", [("fuchsia", "Fuchsien", ["basket_fuchsia"], (0.85, 0.35, 0.6))]),
]

# (Kategorie, id, Name, Reihenfolge, Preis, Felder)
def options():
    out = []
    m = "res://assets/models/facade/%s.glb"
    for k, (oid, name, scene, price) in enumerate([("classic", "Klassisch", "ground_classic", 0), ("beadboard", "Nut und Feder", "ground_beadboard", 160),
                                                   ("victorian", "Viktorianisch", "ground_victorian", 220)]):
        out.append(("ground", oid, name, k * 10, price, dict(scene=m % scene)))
    for k, (oid, name, vals) in enumerate(STONES):
        out.append(("ground", "stone_" + oid, name, 40 + k * 10, 260, dict(scene=m % "ground_stone", material="facade_ground_stone_" + oid,
                                                                            swatch=vals["color"])))
    for k, (oid, name, col) in enumerate(PAINTS):
        out.append(("ground_color", oid, name, k * 10, 40, dict(color=col)))
    for k, (oid, name, vals) in enumerate(WALLS):
        out.append(("upper", oid, name, k * 10, 120, dict(material="facade_wall_" + oid, swatch=vals["color"], hide_quoins=oid.startswith("timber"))))
    for k, (oid, name, price) in enumerate([("arched", "Bogenfenster", 150), ("sash", "Sprossenfenster", 150), ("bay", "Erker", 300)]):
        out.append(("window", oid, name, k * 10, price, dict(scene=m % ("upper_" + oid))))
    for k, (oid, name, col) in enumerate(FRAMES):
        out.append(("frame_color", oid, name, k * 10, 30, dict(color=col)))
    out.append(("awning", "none", "Keine Markise", 0, 0, dict(swatch=(0.9, 0.9, 0.88))))
    for k, (oid, name) in enumerate([("classic", "Markise mit Volant"), ("dome", "Korbmarkise"), ("box", "Kastenmarkise")]):
        out.append(("awning", oid, name, 10 + k * 10, 120, dict(scene=m % ("awning_" + oid))))
    for k, (oid, name, vals) in enumerate(FABRICS):
        out.append(("fabric", oid, name, k * 10, 30, dict(material="facade_fabric_" + oid, swatch=vals["color2"] if "color2" in vals else vals["color"])))
    for k, (oid, name) in enumerate([("glazed", "Glastür"), ("panelled", "Kassettentür"), ("arched", "Bogentür"), ("cottage", "Landhaustür")]):
        out.append(("door", oid, name, k * 10, 90, dict(scene=m % ("door_" + oid))))
    for k, (oid, name, col) in enumerate(DOORS):
        out.append(("door_color", oid, name, k * 10, 30, dict(color=col)))
    for k, (oid, name) in enumerate([("wood", "Holzkasten"), ("zinc", "Zinkkasten"), ("terracotta", "Terrakotta"), ("wicker", "Weidenkorb")]):
        out.append(("box", oid, name, k * 10, 40, dict(scene=m % ("box_" + oid))))
    for k, (oid, name) in enumerate([("bowl", "Tonschale"), ("wire", "Draht mit Moos"), ("wicker", "Weidenkorb")]):
        out.append(("basket", oid, name, k * 10, 30, dict(scene=m % ("basket_" + oid))))
    for g, (group, gname, entries) in enumerate(BOX_PLANTS):
        for k, (oid, name, plants, sw) in enumerate(entries):
            out.append(("box_plant", oid, "%s · %s" % (gname, name) if len(entries) > 1 else gname, g * 10 + k, 20,
                        dict(group=group, plants=plants, swatch=sw)))
    for g, (group, gname, entries) in enumerate(BASKET_PLANTS):
        for k, (oid, name, plants, sw) in enumerate(entries):
            out.append(("basket_plant", oid, "%s · %s" % (gname, name) if len(entries) > 1 else gname, g * 10 + k, 15,
                        dict(group=group, plants=plants, swatch=sw)))
    for k, (oid, name, amount) in enumerate([("sparse", "Dezent", 0.7), ("lush", "Üppig", 1.0), ("overflowing", "Überquellend", 1.35)]):
        out.append(("fullness", oid, name, k * 10, 0, dict(amount=amount, swatch=(0.45 + 0.1 * k, 0.6, 0.4))))
    return out


def _material_text(name, v):
    c = v["color"]
    c2 = v.get("color2") or c
    c3 = v.get("color3") or (0.95, 0.91, 0.82)
    return ('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n%s (Auswahl der Fassade „%s“).\n\n'
            '[ext_resource type="Shader" path="res://assets/shaders/storybook.gdshader" id="1_shader"]\n\n'
            '[resource]\nresource_name = "%s"\nrender_priority = 0\nshader = ExtResource("1_shader")\n'
            'shader_parameter/base_color = Color(%.3f, %.3f, %.3f, 1)\nshader_parameter/second_color = Color(%.3f, %.3f, %.3f, 1)\n'
            'shader_parameter/third_color = Color(%.3f, %.3f, %.3f, 1)\nshader_parameter/grain = %d\n'
            'shader_parameter/stripe_width = %.3f\nshader_parameter/vary = %.3f\nshader_parameter/blot_scale = %.3f\n'
            'shader_parameter/bump_strength = %.3f\nshader_parameter/rough = %.3f\nshader_parameter/metal = 0.0\n'
            'shader_parameter/emission_color = Color(0, 0, 0, 1)\nshader_parameter/emission_energy = 0.0\nshader_parameter/glow = 0.0\n'
            'shader_parameter/pattern = %d\nshader_parameter/pattern_size = %.3f\nshader_parameter/wind_strength = %.3f\n'
            % (MARK, name, name, c[0], c[1], c[2], c2[0], c2[1], c2[2], c3[0], c3[1], c3[2], GRAIN[v.get("grain", "plaster")],
               v.get("stripes", 0.0), v.get("vary", 0.08), v.get("scale", 4.0), v.get("bump", 0.25), v.get("rough", 0.85),
               PATTERN.get(v.get("pattern"), 0), v.get("pattern_size", 0.04), v.get("wind", 0.0)))


def _gd_string(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def _is_generated(path):
    if not os.path.exists(path):
        return True
    with open(path, encoding="utf-8") as f:
        return MARK in f.read(400)


def write_all():
    os.makedirs(MAT_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    mats = [("facade_wall_" + oid, vals) for oid, _, vals in WALLS] + [("facade_ground_stone_" + oid, vals) for oid, _, vals in STONES] + \
           [("facade_fabric_" + oid, vals) for oid, _, vals in FABRICS]
    for name, vals in mats:
        path = os.path.join(MAT_DIR, name + ".tres")
        if _is_generated(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write(_material_text(name, vals))
    count = 0
    for category, oid, name, order, price, extra in options():
        path = os.path.join(DATA_DIR, "%s_%s.tres" % (category, oid))
        if not _is_generated(path):
            continue
        ext = ['[ext_resource type="Script" path="res://scripts/data/facade_option.gd" id="1_data"]']
        lines = ['script = ExtResource("1_data")', 'id = "%s"' % oid, "display_name = %s" % _gd_string(name),
                 'category = "%s"' % category, "order = %d" % order, "price = %d" % price]
        if "scene" in extra:
            lines.append('scene_path = "%s"' % extra["scene"])
        if "material" in extra:
            ext.append('[ext_resource type="Material" path="res://assets/materials/facade/%s.tres" id="2_mat"]' % extra["material"])
            lines.append('material = ExtResource("2_mat")')
        if "color" in extra:
            c = extra["color"]
            lines.append("color = Color(%.3f, %.3f, %.3f, 1)" % c)
        if "swatch" in extra:
            c = extra["swatch"]
            lines.append("swatch = Color(%.3f, %.3f, %.3f, 1)" % c)
        if "group" in extra:
            lines.append('group = "%s"' % extra["group"])
        if "plants" in extra:
            lines.append("plants = PackedStringArray(%s)" % ", ".join('"%s"' % p for p in extra["plants"]))
        if "amount" in extra:
            lines.append("amount = %.2f" % extra["amount"])
        if extra.get("hide_quoins"):
            lines.append("hide_quoins = true")
        text = '[gd_resource type="Resource" script_class="FacadeOption" format=3]\n\n%s – im Inspektor ändern: Speichert Godot das\n' \
               '; Datenblatt, überschreibt das Script es nicht mehr.\n\n%s\n\n[resource]\n%s\n' % (MARK, "\n".join(ext), "\n".join(lines))
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        count += 1
    print("Fassade: %d Datenblätter, %d Materialien geschrieben." % (count, len(mats)))


if __name__ == "__main__":
    write_all()
