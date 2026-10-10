"""Baut die Requisiten im Stil (seit Etappe 4g, Teil 1b): Schneiderpuppe, Platzhalter-Outfits
und hängende Kleidungsstücke für Läden.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_props.py

Ergebnis: assets/models/props/<name>.glb (+ .import) und assets/models/source/props/<name>.blend.
Kleidung ist bewusst Platzhalter: Farbe = Akzentfarbe (in Godot je Stück einstellbar, Script
ShopProp). Später ersetzt ein eigenes Kleidungsmodell den Knoten "Outfit" bzw. "Model".
Ursprung: Puppen und Outfits unten auf dem Boden (Mitte), hängende Teile oben am Haken.
Vorderseite +Z.
"""

import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
from style_lib import Mat, V  # noqa: E402

LINEN = Mat("fabric", color=(0.86, 0.82, 0.73))
WOOD = Mat("timber")
BRASS = Mat("gold")
CLOTH = Mat("fabric", "accent")
CLOTH_PLAIN = Mat("plain", "accent")
COLLAR = Mat("plain", color=(0.93, 0.9, 0.84))
BUTTON = Mat("plain", color=(0.85, 0.8, 0.7))
BELT = Mat("plain", color=(0.3, 0.22, 0.16))


def lathe(b, y_radii, mat, segments=16, x=0.0, z=0.0, depth_scale=0.8):
    """Drehkörper entlang y: Liste (y, Radius); in der Tiefe etwas flacher (depth_scale)."""
    b.push(S.Matrix.Translation((x, 0, z)) @ S.Matrix.Diagonal((1.0, 1.0, depth_scale, 1.0)))
    pts = [V(0, y, 0) for y, _ in y_radii]
    radii = [r for _, r in y_radii]
    b.tube(pts, lambda t: _interp(radii, t), mat, segments=segments)
    b.pop()


def _interp(values, t):
    f = t * (len(values) - 1)
    i = min(int(f), len(values) - 2)
    return values[i] + (values[i + 1] - values[i]) * (f - i)


# Körpermaße der Puppe (Höhe, Radius) – Outfits liegen knapp darüber
TORSO = [(1.0, 0.16), (1.08, 0.165), (1.18, 0.125), (1.3, 0.15), (1.38, 0.165), (1.47, 0.15), (1.52, 0.1), (1.54, 0.05)]


def dress_form():
    b = S.Builder("dress_form")
    # Dreibein aus Holz, Messingstange, Leinen-Torso, kleiner Knauf
    for k in range(3):
        a = 2 * math.pi * k / 3
        b.tube([V(0, 0.42, 0), V(0.28 * math.cos(a), 0.0, 0.28 * math.sin(a))], 0.018, WOOD, segments=6)
    b.cylinder(V(0, 0.38, 0), 0.03, 0.08, WOOD, segments=10)
    b.cylinder(V(0, 0.4, 0), 0.012, 0.62, BRASS, segments=8)
    lathe(b, TORSO, LINEN)
    b.cylinder(V(0, 0.98, 0), 0.05, 0.03, WOOD, segments=10)
    b.cylinder(V(0, 1.54, 0), 0.03, 0.06, WOOD, segments=10)
    b.sphere(V(0, 1.62, 0), 0.03, BRASS, rings=4, segments=8)
    return b


def outfit_dress():
    """Kleid im Stil der 50er: Oberteil, ausgestellter Rock, kleiner Kragen, Gürtel."""
    b = S.Builder("outfit_dress")
    lathe(b, [(1.17, 0.135), (1.3, 0.16), (1.38, 0.175), (1.47, 0.16), (1.52, 0.115), (1.535, 0.075)], CLOTH)
    lathe(b, [(0.55, 0.36), (0.75, 0.32), (0.95, 0.25), (1.1, 0.17), (1.19, 0.135)], CLOTH, segments=20)
    lathe(b, [(1.16, 0.14), (1.2, 0.14)], BELT)
    for side in (-1, 1):
        lathe(b, [(1.38, 0.06), (1.44, 0.075), (1.48, 0.06)], CLOTH, x=side * 0.16, depth_scale=0.9)
    b.push(S.Matrix.Translation((0, 0, 0.12)))
    for side in (-1, 1):
        b.poly([V(0, 1.53, 0.01), V(side * 0.08, 1.55, -0.03), V(side * 0.09, 1.49, 0.0)][::(1 if side < 0 else -1)], COLLAR, both=True)
    for k in range(3):
        b.sphere(V(0, 1.27 + k * 0.07, 0.025), 0.01, BUTTON, rings=3, segments=6)
    b.pop()
    return b


def outfit_coat():
    """Gerader Mantel bis unters Knie mit Revers, Gürtel und Knöpfen."""
    b = S.Builder("outfit_coat")
    lathe(b, [(0.45, 0.24), (0.8, 0.22), (1.05, 0.2), (1.18, 0.16), (1.3, 0.175), (1.4, 0.185), (1.48, 0.17), (1.53, 0.12), (1.545, 0.08)], CLOTH, segments=18)
    lathe(b, [(1.14, 0.17), (1.19, 0.17)], CLOTH_PLAIN)
    for side in (-1, 1):
        lathe(b, [(1.0, 0.055), (1.25, 0.06), (1.42, 0.075), (1.48, 0.07)], CLOTH, x=side * 0.2, depth_scale=0.9)
    for side in (-1, 1):
        b.poly([V(side * 0.01, 1.2, 0.165), V(side * 0.11, 1.5, 0.12), V(side * 0.03, 1.5, 0.15)][::(1 if side < 0 else -1)], CLOTH, both=True)
    for k in range(3):
        b.sphere(V(0.03, 0.75 + k * 0.17, 0.205), 0.014, BUTTON, rings=3, segments=6)
    return b


def _hanger(b):
    b.tube([V(0, 0, 0), V(0, 0.03, 0.0), V(0.02, 0.05, 0), V(0.04, 0.03, 0), V(0.03, 0.0, 0)][::-1], 0.004, BRASS, segments=4)
    b.tube([V(-0.2, -0.12, 0), V(0, -0.04, 0), V(0.2, -0.12, 0)], 0.012, WOOD, segments=5)
    b.tube([V(0, -0.01, 0), V(0, -0.04, 0)], 0.005, BRASS, segments=4)


def _flat_garment(b, outline, thickness, mat):
    """Flaches Kleidungsstück am Bügel: Umriss (x, y) in der Ebene z = 0, etwas Dicke."""
    pts = [V(x, y, thickness / 2) for x, y in outline]
    b.slab(pts, thickness, mat)


def garment_dress():
    b = S.Builder("garment_dress")
    _hanger(b)
    outline = [(-0.17, -0.12), (-0.21, -0.2), (-0.15, -0.24), (-0.14, -0.42), (-0.32, -1.0), (0.32, -1.0),
               (0.14, -0.42), (0.15, -0.24), (0.21, -0.2), (0.17, -0.12), (0.06, -0.1), (0.0, -0.16), (-0.06, -0.1)]
    _flat_garment(b, outline, 0.05, CLOTH)
    b.box((-0.145, -0.44, -0.03), (0.145, -0.4, 0.03), BELT)
    return b


def garment_blouse():
    b = S.Builder("garment_blouse")
    _hanger(b)
    outline = [(-0.17, -0.12), (-0.34, -0.38), (-0.28, -0.42), (-0.17, -0.27), (-0.17, -0.66), (0.17, -0.66),
               (0.17, -0.27), (0.28, -0.42), (0.34, -0.38), (0.17, -0.12), (0.06, -0.1), (0.0, -0.17), (-0.06, -0.1)]
    _flat_garment(b, outline, 0.04, CLOTH)
    for side in (-1, 1):
        b.poly([V(0, -0.17, 0.021), V(side * 0.09, -0.1, 0.021), V(side * 0.1, -0.2, 0.021)][::(1 if side > 0 else -1)], COLLAR, both=True)
    for k in range(4):
        b.sphere(V(0, -0.24 - k * 0.1, 0.026), 0.009, BUTTON, rings=3, segments=6)
    return b


PROPS = {
    "dress_form": dress_form,
    "outfit_dress": outfit_dress,
    "outfit_coat": outfit_coat,
    "garment_dress": garment_dress,
    "garment_blouse": garment_blouse,
}
PREVIEW_ACCENT = (0.72, 0.58, 0.3)


def build(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    b = PROPS[name]()
    glb = os.path.join(S.ROOT, "assets", "models", "props", name + ".glb")
    tris = S.write_glb(b, glb)
    S.write_import_settings(glb)
    print("%s: %d Dreiecke" % (name, tris))
    S.to_blender(b, {"accent": PREVIEW_ACCENT})
    blend = os.path.join(S.ROOT, "assets", "models", "source", "props", name + ".blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend, relative_remap=True, compress=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for prop in [a for a in argv if not a.startswith("--")] or list(PROPS):
        build(prop)
