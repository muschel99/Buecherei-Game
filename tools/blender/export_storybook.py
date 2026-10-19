"""Bringt ein selbst bearbeitetes Bilderbuch-Haus (Laden, Pub, Torhaus oder Wohnhaus) ins Spiel.

Für den Fall, dass die Blender-Datei von Hand weitergebaut wurde (Teile verschoben, umgeformt,
neue Teile …). Das Bau-Script build_storybook_shop.py würde sie sonst neu erzeugen – dieses
Script nimmt sie so, wie sie ist.

Aufruf (Terminal, im Projektordner):
    blender -b assets/models/source/houses/fashion_shop_storybook.blend --python tools/blender/export_storybook.py
    blender -b assets/models/source/houses/pub_storybook.blend --python tools/blender/export_storybook.py
    blender -b assets/models/source/houses/storybook/Opposite_Opposite1_3.blend --python tools/blender/export_storybook.py
    blender -b assets/models/source/plants/climber_ivy_40.blend --python tools/blender/export_storybook.py
  (Wohnhäuser: Teile werden fürs Spiel zu Sammel-Materialien zusammengelegt, Pflanzplätze
  „PlantSpot_…“ kommen mit – verschieben erlaubt, die Pflanze wandert mit)

Was es tut:
  - nimmt alles aus der Haus-Sammlung ("Modegeschäft (Bilderbuch)" bzw. "Pub (Bilderbuch)") außer "Licht" (im Spiel leuchten
    die Materialien selbst) – die Sammlung "Umgebung (nur Vorschau)" bleibt draußen,
  - Teile mit "-colonly" am Namensende (Sammlung "Kollision (Spiel)") werden im Spiel zu
    Kollision und zu Hindernissen für Passanten,
  - fasst Teile mit gleichem Material zusammen, wendet Modifikatoren an (z. B. weiche Kanten),
  - alle Teile bleiben genau so (auch Blätter und Blüten sind kleine Körper); mit
    PLANT_TOPS_ONLY = True behielten Blätter nur ihre Oberseite (weniger Dreiecke),
  - schreibt assets/models/houses/fashion_shop.glb bzw. pub.glb; Materialien mit passendem Godot-Material in
    assets/materials/storybook/ bekommen es zugeordnet (neue Materialien zeigen ihre Grundfarbe).
Die .blend-Datei selbst wird nicht verändert.
Danach Godot öffnen (importiert von selbst) bzw. headless: godot --headless --path . --import
"""

import bpy
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import storybook_common as SC  # noqa: E402

# Haus-Sammlung in der .blend -> Datei fürs Spiel (assets/models/houses/)
HOUSES = {"Modegeschäft (Bilderbuch)": "fashion_shop.glb", "Pub (Bilderbuch)": "pub.glb", "Bäckerei (Bilderbuch)": "bakery.glb",
          "Blumenladen (Bilderbuch)": "flower_shop.glb", "Teeladen (Bilderbuch)": "tea_shop.glb", "Wolleladen (Bilderbuch)": "wool_shop.glb",
          "Torhaus (Bilderbuch)": "gatehouse.glb"}

# True = Blätter und Blüten fürs Spiel nur als Oberseite (weniger Dreiecke, aber keine Körper mehr)
PLANT_TOPS_ONLY = False


def collect(coll, skip):
    out = []
    for child in coll.children:
        if child.name not in skip:
            out += collect(child, skip)
    return out + list(coll.objects)


def main():
    root, target = None, None
    palette = False
    for name, file in HOUSES.items():
        if name in bpy.data.collections:
            root, target = bpy.data.collections[name], os.path.join(SC.ROOT, "assets", "models", "houses", file)
    for coll in bpy.data.collections:
        # Pflanzen (build_storybook_plants.py): Sammlung „Pflanze <id>“
        if coll.name.startswith("Pflanze "):
            root = coll
            target = os.path.join(SC.ROOT, "assets", "models", "plants", coll.name[8:] + ".glb")
            palette = True
        # Wohnhäuser (build_storybook_street.py): Sammlung „Haus <Gruppe>/<Name>“
        if coll.name.startswith("Haus ") and "/" in coll.name:
            key = coll.name[5:]
            root = coll
            target = os.path.join(SC.ROOT, "assets", "models", "houses", "storybook", key.replace("/", "_") + ".glb")
            palette = True
    # Werte der Materialien fürs Spiel (beim Bau in der .blend gemerkt)
    for mat in bpy.data.materials:
        if "spiel_werte" in mat:
            SC.GAME_MATERIALS[mat.name] = json.loads(mat["spiel_werte"])
    if root is None:
        print("Keine Haus-Sammlung (%s) gefunden – ist das die richtige Datei?" % ", ".join(HOUSES))
        return
    objs = collect(root, {"Licht", "Kollision (Spiel)", "Pflanzplätze"})
    spots = [o for o in bpy.data.objects if o.name.startswith("PlantSpot_")]
    cols = [o for o in bpy.data.objects if o.name.endswith("-colonly")]
    simplify = (lambda m: PLANT_TOPS_ONLY and bool(m.get("spiel_pflanze")))
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = next((a.split("=", 1)[1] for a in argv if a.startswith("--out=")), target)
    tris, parts = SC.export_objects([o for o in objs if o.type == "MESH"], cols, out, simplify, palette=palette, extra=spots)
    if palette:
        SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    mapping = {}
    for mat in bpy.data.materials:
        path = os.path.join(SC.GAME_MAT_DIR, SC.slug(mat.name) + ".tres")
        if os.path.exists(path):
            mapping[mat.name] = "res://" + os.path.relpath(path, SC.ROOT).replace(os.sep, "/")
    SC.write_import_settings(mapping, out)
    print("Spiel: %s (%d Dreiecke, %d Netze)" % (out, tris, parts))


main()
