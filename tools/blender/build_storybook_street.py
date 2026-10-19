"""Baut alle Wohnhäuser der Straße im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_street.py
    blender -b --factory-startup --python tools/blender/build_storybook_street.py -- Opposite/Opposite1_3 [--render] [--force]

Liest scenes/world/houses.tscn (welche Häuser es gibt), stellt je Reihenhaus/Kulissenhaus die
Beschreibung zusammen (Maße, Geschosse, Dachform, Wandart, Fensterspalten, Tür, freie Seiten:
build_street.make_spec – dieselben Häuser wie bisher, aber neu gebaut) und baut es mit
storybook_houses.py. Ergebnis je Haus:
    assets/models/houses/storybook/<Gruppe>_<Name>.glb          Spiel (Sammel-Materialien, LODs)
    assets/models/source/houses/storybook/<Gruppe>_<Name>.blend  Einzelteile zum Weiterbauen
und in houses.tscn je Haus unique_model und (nach Plan) die hängende Straßenlaterne.
Läden, Pub, Eckhäuser und Torhaus haben eigene Scripts (build_street.STORYBOOK) und bleiben.
Eine in Blender bearbeitete .blend wird nicht überschrieben (nur mit --force); ins Spiel bringt
sie export_storybook.py.
"""

import math
import os
import re
import sys
import zlib

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_street as BS  # noqa: E402
import storybook_common as SC  # noqa: E402
import storybook_houses as SH  # noqa: E402
import storybook_lib as SB  # noqa: E402

OUT_DIR = os.path.join(SC.ROOT, "assets", "models", "houses", "storybook")
SRC_DIR = os.path.join(SC.ROOT, "assets", "models", "source", "houses", "storybook")
RES = "res://assets/models/houses/storybook/%s.glb"

# Hängende Straßenlaternen an Wohnhäusern (Plan in docs/ROADMAP.md): Haus -> bevorzugte Stelle
# entlang der Front (Mitte = 0) oder None (nahe der Tür)
LANTERNS = {
    "Opposite/Opposite1_1": -0.9, "Opposite/Opposite1_3": 0.3, "Opposite/Opposite2_1": -1.1, "Opposite/Opposite2_5": -0.05,
    "StraightEnd/Outer3": None, "GateStreet/Bend3": None, "GateStreet/BehindOuter3": None,
}


def collections(key):
    root = SB.collection("Haus " + key)
    C = {k: SB.collection(v, root) for k, v in (("walls", "Mauern"), ("roof", "Dach"), ("windows", "Fenster"), ("shop", "Tür"),
                                                ("inside", "Räume"), ("pots", "Kästen und Beete"), ("deco", "Deko"),
                                                ("plants", "Pflanzplätze"), ("light", "Licht"))}
    C["env"] = SB.collection("Umgebung (nur Vorschau)")
    C["collision"] = SB.collection("Kollision (Spiel)", root)
    return C


def build_one(key, spec, near, argv):
    file_id = key.replace("/", "_")
    glb = os.path.join(OUT_DIR, file_id + ".glb")
    blend = os.path.join(SRC_DIR, file_id + ".blend")
    stamp = os.path.join(SRC_DIR, file_id + ".stamp")
    if SC.edited_by_hand(blend, stamp) and "--force" not in argv:
        print("%-26s in Blender bearbeitet – bleibt (export_storybook.py bringt es ins Spiel)" % key)
        return None
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    # weiche Kanten: nahe Häuser zweistufig, ferne (Kulisse) einstufig
    SB.BEVEL_SEGMENTS = (2, 1) if near else (1, 1)
    M = SC.materials()
    st = SH.house_style(spec, key)
    if key in LANTERNS:
        st["canopy"] = None  # Häuser mit Straßenlaterne: keine Stoffmarkisen (die Laterne hängt sonst darin)
    SH.house_materials(M, st)
    C = collections(key)
    house = SH.House(M, C, spec, st, key, near=near).build()
    objs = [o for k, c in C.items() if k not in ("env", "collision", "plants") for o in c.objects]
    SC.settle(objs, st["settle"], house.hw, house.E, house.ridge)
    bad = [(o.name, SB.non_manifold(o)) for o in objs if o.type == "MESH" and SB.non_manifold(o)]
    meshes = [o for o in objs if o.type == "MESH" and o.users_collection[0] is not C["light"]]
    tris, parts = SC.export_objects(meshes, [], glb, palette=True, extra=house.spots)
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, glb)
    lantern = house.lantern_spot(LANTERNS[key]) if key in LANTERNS else None
    print("%-26s %6d Dreiecke, %2d Netze, %d Pflanzplätze, Laterne %s, offene Kanten: %s" % (
        key, tris, parts, len(house.spots), lantern, bad if bad else "keine"))
    if "--render" in argv:
        SC.pavement(M, C, seed=300, half=house.hw + 1.0)
        SC.setup_render("--quick" in argv)
        W, E = house.W, house.E
        SC.render("street_%s_vorn" % file_id, (0.0, -9.5 - W, 1.7), (0.0, 0.0, E * 0.55), 32, (900, 900))
        SC.render("street_%s_schraeg" % file_id, (W * 0.9 + 2.5, -6.0, 1.7), (0.0, house.sb, E * 0.5), 30, (900, 900))
    os.makedirs(SRC_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    with open(stamp, "w") as f:
        f.write(SC.blend_fingerprint(blend) + "\n")
    return {"key": key, "file_id": file_id, "lantern": lantern, "colors": st, "tris": tris}


def write_tscn(text, built):
    """houses.tscn: je gebautem Haus unique_model (neue .glb), Wandmaterial „wie gebaut“ und die
    Laterne (oder keine)."""
    for b in built:
        res_id = "u_" + b["file_id"]
        line = '[ext_resource type="PackedScene" path="%s" id="%s"]' % (RES % b["file_id"], res_id)
        text = re.sub(r'\[ext_resource type="PackedScene" path="[^"]+" id="%s"\]' % re.escape(res_id), line, text)
        if line not in text:
            last = list(re.finditer(r'\[ext_resource [^\n]*\]\n', text))[-1]
            text = text[:last.end()] + line + "\n" + text[last.end():]
        group, name = b["key"].split("/")
        pat = re.compile(r'(\[node name="%s" parent="%s"[^\n]*\n)(.*?)(?=\n\[|\Z)' % (re.escape(name), re.escape(group)), re.S)
        m = pat.search(text)
        body = "\n".join(l for l in m.group(2).split("\n") if not re.match(r"(unique_model|wall_material|lanterns) =", l))
        extra = ['unique_model = ExtResource("%s")' % res_id, "wall_material = 1"]
        if b["lantern"]:
            extra.append("lanterns = PackedVector3Array(%.3f, %.3f, %.3f)" % b["lantern"])
        out = []
        for l in body.rstrip("\n").split("\n"):
            out.append(l)
            if l.startswith("transform ="):
                out.extend(extra)
        text = text[:m.start(2)] + "\n".join(out) + text[m.end(2):]
    # Modelle, auf die nichts mehr zeigt, aus der Liste nehmen
    for m in list(re.finditer(r'\[ext_resource type="PackedScene" path="res://assets/models/houses/street/[^"]+" id="([^"]+)"\]\n', text)):
        if 'ExtResource("%s")' % m.group(1) not in text:
            text = text.replace(m.group(0), "")
    return text


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = [a for a in argv if not a.startswith("--")]
    text, houses = BS.read_houses()
    specs = {}
    for h in houses:
        if h["type"] in BS.STREET_TYPES:
            specs[h["key"]] = BS.make_spec(h, BS.house_block(text, h))
    for key, sides in BS.exposures(houses, text, specs).items():
        specs[key]["exposed"] = sides
    built = []
    for h in houses:
        key = h["key"]
        if key not in specs or key in BS.STORYBOOK or (only and key not in only):
            continue
        near = "solid = false" not in BS.house_block(text, h)
        r = build_one(key, specs[key], near, argv)
        if r:
            built.append(r)
    if "--no-tscn" not in argv:
        text = open(BS.HOUSES_TSCN).read()
        with open(BS.HOUSES_TSCN, "w") as f:
            f.write(write_tscn(text, built))
    print("Fertig: %d Häuser, zusammen %d Dreiecke" % (len(built), sum(b["tris"] for b in built)))


if __name__ == "__main__":
    main()
