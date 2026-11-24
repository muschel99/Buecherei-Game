"""Pflanzen-Prüfung für den Möbelkatalog (seit Etappe 8d, Zettel 01): Stecken Blätter, Blüten oder Stiele in Töpfen, Kästen,
Gittern oder Henkeln? (geo_check.py erkennt Pflanzen nur am Material „plant“ der Häuser – bei den Möbeln heißen sie „leaf“,
„bloom“, „stem“ …, dort hält es jedes Blatt für ein festes Teil.)

Pflanze ist, was ein Pflanzen-Material hat (die Namen aus storybook_furniture.PLANT_COLORS, z. B. leaf, bloom, stem, bark);
Erde und Wasser zählen nicht (Wurzeln und tief hängende Triebe dürfen in der Erde liegen); alles andere ist fest (Topf,
Kasten, Gitter, Korb, Stein …). Gemeldet wird je Pflanzen-Material, wie viele Dreiecke feste Teile schneiden, und wo
(Mitte, Höhe).

Aufruf (im Projektordner):
    blender -b --factory-startup --python tools/blender/plant_clip_check.py -- out_fern_bucket out_flower_box
"""

import os
import sys

import bmesh
import bpy
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_furniture as F  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "assets", "models", "source", "furniture")
IGNORE = {"soil", "water"}
PLANT = (set(F.PLANT_COLORS) | {"bloom", "bloom2", "bloom_core"}) - IGNORE


def material(o):
    return o.data.materials[0].name.split(".")[0] if o.data.materials else ""


def tree(objs):
    """BVH aller Dreiecke der Objekte (in Weltlage)."""
    bm = bmesh.new()
    for o in objs:
        me = o.data.copy()
        me.transform(o.matrix_world)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.faces.ensure_lookup_table()
    return BVHTree.FromBMesh(bm), bm


def check(fid):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(SOURCE, fid + ".blend"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    plants = [o for o in meshes if material(o) in PLANT]
    solid = [o for o in meshes if material(o) not in PLANT | IGNORE]
    if not solid or not plants:
        print("PFLANZEN %s: nichts zu prüfen" % fid)
        return 0
    solid_tree, _ = tree(solid)
    total = 0
    lines = []
    for o in plants:
        plant_tree, bm = tree([o])
        pairs = plant_tree.overlap(solid_tree)
        if not pairs:
            continue
        pts = [bm.faces[i].calc_center_median() for i, _ in pairs]
        c = sum(pts[1:], pts[0].copy()) / len(pts)
        zs = [p.z for p in pts]
        lines.append("    %-16s %4d Dreiecke bei (%.2f, %.2f, %.2f), Höhe %.2f bis %.2f" % (material(o), len(pairs), c.x, c.y, c.z,
                                                                                         min(zs), max(zs)))
        total += len(pairs)
    print("PFLANZEN %s: %s" % (fid, "in Ordnung" if not total else "%d Dreiecke in festen Teilen" % total))
    for line in lines:
        print(line)
    return total


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    found = sum(1 for fid in argv if check(fid))
    print("PFLANZEN fertig: %d von %d Möbeln mit Befund" % (found, len(argv)))


main()
