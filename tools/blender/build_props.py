"""Baut die Requisiten der Straße im Stil (seit Etappe 4g): Laternenmast, hängende Laterne am
Wandarm, Abflussdeckel.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_props.py

Ergebnis: assets/models/props/<name>.glb (+ .import) und assets/models/source/props/<name>.blend.
Vorderseite +Z.
"""

import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
from style_lib import Mat  # noqa: E402


def drain_grate():
    """Gusseiserner Abflussdeckel (Rinnstein-Einlauf), 0,5 x 0,34 m, flach auf der Fahrbahn.
    Ursprung = Mitte unten, lange Seite entlang x (am Bordstein entlang)."""
    b = S.Builder("drain_grate")
    iron = Mat("metal", color=(0.55, 0.55, 0.55))
    dark = Mat("plain", color=(0.04, 0.04, 0.04))
    w, d, h = 0.25, 0.17, 0.012
    # Rahmen
    for x0, x1, z0, z1 in ((-w, w, -d, -d + 0.04), (-w, w, d - 0.04, d), (-w, -w + 0.04, -d + 0.04, d - 0.04), (w - 0.04, w, -d + 0.04, d - 0.04)):
        b.box((x0, 0.0, z0), (x1, h, z1), iron, skip=("bottom",))
    # Dunkler Schacht unter den Schlitzen, darüber Stege quer
    b.box((-w + 0.04, 0.0, -d + 0.04), (w - 0.04, 0.002, d - 0.04), dark, skip=("bottom",))
    n = 9
    for k in range(1, n):
        x = -w + 0.04 + (2 * w - 0.08) * k / n
        b.box((x - 0.011, 0.0, -d + 0.04), (x + 0.011, h - 0.002, d - 0.04), iron, skip=("bottom",))
    # Mittelsteg etwas tiefer als die Stege (sonst decken sich die Oberseiten an den Kreuzungen)
    b.box((-w + 0.04, 0.0, -0.012), (w - 0.04, h - 0.005, 0.012), iron, skip=("bottom",))
    return b


def street_lamp():
    """Viktorianischer Laternenmast mit zwei Hängekörben (Ursprung am Fuß)."""
    import style_parts as P
    b = S.Builder("street_lamp")
    P.street_lamp(b)
    return b


def wall_street_lantern():
    """Hängende Straßenlaterne am Wandarm (Ursprung: Befestigung an der Wand, +Z von der Wand
    weg). Die Häuser tragen ihre Befestigungspunkte selbst (HouseFacade.lanterns)."""
    import style_parts as P
    b = S.Builder("wall_street_lantern")
    P.bracket_lantern(b)
    return b


PROPS = {
    "street_lamp": street_lamp,
    "wall_street_lantern": wall_street_lantern,
    "drain_grate": drain_grate,
}


def build(name):
    glb = os.path.join(S.ROOT, "assets", "models", "props", name + ".glb")
    if S.edited_by_hand(glb):
        print("%s: selbst bearbeitet – bleibt, wie es ist" % name)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    b = PROPS[name]()
    tris = S.write_glb(b, glb)
    S.write_import_settings(glb)
    print("%s: %d Dreiecke" % (name, tris))
    S.to_blender(b, {})
    blend = os.path.join(S.ROOT, "assets", "models", "source", "props", name + ".blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True, compress=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for prop in [a for a in argv if not a.startswith("--")] or list(PROPS):
        build(prop)
