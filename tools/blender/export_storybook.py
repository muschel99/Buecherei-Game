"""Bringt das selbst bearbeitete Bilderbuch-Modegeschäft ins Spiel.

Für den Fall, dass die Blender-Datei von Hand weitergebaut wurde (Teile verschoben, umgeformt,
neue Teile …). Das Bau-Script build_storybook_shop.py würde sie sonst neu erzeugen – dieses
Script nimmt sie so, wie sie ist.

Aufruf (Terminal, im Projektordner):
    blender -b assets/models/source/houses/fashion_shop_storybook.blend --python tools/blender/export_storybook.py

Was es tut:
  - nimmt alles aus der Sammlung "Modegeschäft (Bilderbuch)" außer "Licht" (im Spiel leuchten
    die Materialien selbst) – die Sammlung "Umgebung (nur Vorschau)" bleibt draußen,
  - Teile mit "-colonly" am Namensende (Sammlung "Kollision (Spiel)") werden im Spiel zu
    Kollision und zu Hindernissen für Passanten,
  - fasst Teile mit gleichem Material zusammen, wendet Modifikatoren an (z. B. weiche Kanten),
  - alle Teile bleiben genau so (auch Blätter und Blüten sind kleine Körper); mit
    PLANT_TOPS_ONLY = True behielten Blätter nur ihre Oberseite (weniger Dreiecke),
  - schreibt assets/models/houses/fashion_shop.glb; Materialien mit passendem Godot-Material in
    assets/materials/storybook/ bekommen es zugeordnet (neue Materialien zeigen ihre Grundfarbe).
Die .blend-Datei selbst wird nicht verändert.
Danach Godot öffnen (importiert von selbst) bzw. headless: godot --headless --path . --import
"""

import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import build_storybook_shop as B  # noqa: E402

# True = Blätter und Blüten fürs Spiel nur als Oberseite (weniger Dreiecke, aber keine Körper mehr)
PLANT_TOPS_ONLY = False


def collect(coll, skip):
    out = []
    for child in coll.children:
        if child.name not in skip:
            out += collect(child, skip)
    return out + list(coll.objects)


def main():
    root = bpy.data.collections.get("Modegeschäft (Bilderbuch)")
    if root is None:
        print("Sammlung 'Modegeschäft (Bilderbuch)' fehlt – ist das die richtige Datei?")
        return
    objs = collect(root, {"Licht", "Kollision (Spiel)"})
    cols = [o for o in bpy.data.objects if o.name.endswith("-colonly")]
    simplify = (lambda m: PLANT_TOPS_ONLY and bool(m.get("spiel_pflanze")))
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = next((a.split("=", 1)[1] for a in argv if a.startswith("--out=")), B.GAME_GLB)
    tris, parts = B.export_objects(objs, cols, out, simplify)
    mapping = {}
    for mat in bpy.data.materials:
        path = os.path.join(B.GAME_MAT_DIR, B.slug(mat.name) + ".tres")
        if os.path.exists(path):
            mapping[mat.name] = "res://" + os.path.relpath(path, B.ROOT).replace(os.sep, "/")
    B.write_import_settings(mapping, out)
    print("Spiel: %s (%d Dreiecke, %d Netze)" % (out, tris, parts))


main()
