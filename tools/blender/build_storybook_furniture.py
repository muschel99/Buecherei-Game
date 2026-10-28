"""Baut den Möbelkatalog im Bilderbuch-Stil (Etappe 6).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_furniture.py -- [<id> …]
        [--style=dark_academia|minimalist|country|neutral|fixtures] [--force] [--adopt] [--list]

Ohne ids: alle Objekte (bzw. alle eines Stils). Je Objekt entstehen:
    assets/models/furniture/<id>.glb              Spiel-Modell (Teile je Material zusammengefasst)
    assets/models/source/furniture/<id>.blend     Einzelteile zum Nachmodellieren (Blender, Nomad Sculpt)
    assets/materials/furniture/<id>/<rolle>.tres  Godot-Materialien (Rollennamen = Farbvarianten)
    scenes/furniture/<id>.tscn                    Szene: Modell, Kollision, Ablageflächen, Fächer, Sitz, Licht
    data/furniture/<id>.tres                      Datenblatt mit Preis, Stil und Farbvarianten
    assets/models/templates/furniture/<id>.glb    Vorlage in echter Größe
Selbst bearbeitete Dateien bleiben: eine .blend, deren Fingerabdruck nicht mehr stimmt (dann wird
das ganze Objekt übersprungen, außer mit --force), und Szenen/Datenblätter, die Godot gespeichert
hat. --adopt überschreibt einmalig die alten Platzhalter-Datenblätter gleicher id.
Die Objekte selbst stehen in furniture_<stil>.py (je Objekt eine Beschreibung + Bau-Funktion).
Theken und Einwürfe des Rückgabekastens je Stil: furniture_fixtures.py (kind="counter"/"return_slot",
Modell + Datenblatt in data/counters/ bzw. data/return_slots/, keine eigene Szene).
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_furniture as F  # noqa: E402
import furniture_dark_academia  # noqa: E402

STYLES = {
    "dark_academia": furniture_dark_academia.ITEMS,
}
for _name in ("minimalist", "country", "neutral", "fixtures"):
    try:
        STYLES[_name] = __import__("furniture_" + _name).ITEMS
    except ImportError:
        STYLES[_name] = []


def all_items():
    for style, items in STYLES.items():
        for spec in items:
            yield style, spec


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SC.GAME_MATERIALS.clear()
    SC.SPOTS["coll"] = None
    SC.SPOTS["n"] = 0


def build(spec, force=False, adopt=False):
    source = F.dirs(spec)["source"]
    blend = os.path.join(source, spec["id"] + ".blend")
    stamp = os.path.join(source, spec["id"] + ".stamp")
    if not force and SC.edited_by_hand(blend, stamp):
        print("  %-26s .blend von Hand bearbeitet – übersprungen (--force baut trotzdem neu)" % spec["id"])
        return 0
    reset_scene()
    kit = F.Kit(spec)
    spec["build"](kit)
    kit.finish()
    tris = F.export(kit, force_data=adopt and spec.get("adopt", False))
    with open(stamp, "w") as f:
        f.write(SC.blend_fingerprint(blend))
    return tris


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    flags = [a for a in argv if a.startswith("--")]
    ids = [a for a in argv if not a.startswith("--")]
    style = next((f.split("=", 1)[1] for f in flags if f.startswith("--style=")), None)
    if "--list" in flags:
        for st, spec in all_items():
            print("%-14s %-26s %s" % (st, spec["id"], spec["name"]))
        return
    chosen = [(st, spec) for st, spec in all_items() if (not ids or spec["id"] in ids) and (style is None or st == style)]
    missing = set(ids) - {spec["id"] for _, spec in chosen}
    if missing:
        print("Unbekannte ids:", ", ".join(sorted(missing)))
    total = 0
    for st, spec in chosen:
        total += build(spec, force="--force" in flags, adopt="--adopt" in flags)
    print("Fertig: %d Objekte, zusammen %d Dreiecke." % (len(chosen), total))


main()
