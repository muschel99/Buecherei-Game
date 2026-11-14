"""Beinprüfung für den Möbelkatalog (seit Testrunde 7b, Wunsch der Entwicklerin: „achte auf die Möbel, bei denen die Beine
nicht am Grundkörper befestigt sind“).

Für jedes Möbelstück (Quelle assets/models/source/furniture/<id>.blend) sucht das Script alle Teile, die auf dem Boden stehen
und oben schmal enden (Beine, Füße, Kufen, Stangen) und prüft, ob ihr oberes Ende in einem anderen Teil steckt oder es berührt
(gemeldet wird nur, wenn direkt darüber – bis 10 cm – ein Teil liegt; freie Enden wie Pfosten oder Vasen zählen nicht).
Außerdem: steht das Möbelstück überhaupt auf dem Boden, und reichen alle Beine bis zum Boden?

Aufruf (im Projektordner):
    blender -b --factory-startup --python tools/blender/leg_check.py               alle Möbel
    blender -b --factory-startup --python tools/blender/leg_check.py -- sofa_min    nur diese ids
"""

import glob
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "assets", "models", "source", "furniture")
FLOOR = 0.01          # so tief beginnt ein Teil, das auf dem Boden steht (m)
TOP_BAND = 0.012      # oberes Ende eines Beins: alle Ecken so weit unter seiner Spitze
NARROW = 0.11         # oberes Ende schmaler als das = Bein/Fuß (breite Teile wie Korpus, Topf sind keine Beine)
TOUCH = 0.004         # so nah muss das Beinende an einem anderen Teil sein
PLANT_WORDS = ("leaf", "blatt", "bloom", "blüte", "flower", "petal", "plant", "stem", "lavendel", "zweig", "moss")


def islands_of(obj, depsgraph):
    """Zusammenhängende Stücke eines Objekts (mit Modifikatoren) in Weltkoordinaten: [(Ecken, Flächen)]."""
    ev = obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(obj.matrix_world)
    bm.verts.ensure_lookup_table()
    seen = set()
    result = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack = [f]
        group = []
        seen.add(f.index)
        while stack:
            cur = stack.pop()
            group.append(cur)
            for e in cur.edges:
                for nb in e.link_faces:
                    if nb.index not in seen:
                        seen.add(nb.index)
                        stack.append(nb)
        idx = {}
        verts = []
        polys = []
        for g in group:
            poly = []
            for v in g.verts:
                if v.index not in idx:
                    idx[v.index] = len(verts)
                    verts.append(v.co.copy())
                poly.append(idx[v.index])
            polys.append(poly)
        result.append((verts, polys))
    bm.free()
    ev.to_mesh_clear()
    return result


def is_plant(obj):
    names = [obj.name.lower()] + [m.name.lower() for m in obj.data.materials if m]
    return any(w in n for n in names for w in PLANT_WORDS)


def check(blend):
    bpy.ops.wm.open_mainfile(filepath=blend)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    parts = []   # (Objektname, Ecken, Flächen, BVH)
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.hide_render or is_plant(obj) or "colonly" in obj.name or obj.name.startswith("Flamme"):
            continue
        for verts, polys in islands_of(obj, depsgraph):
            if len(polys) < 4:
                continue
            parts.append((obj.name, verts, polys, BVHTree.FromPolygons(verts, polys)))
    if not parts:
        return []
    low = min(v.z for _n, verts, _p, _b in parts for v in verts)
    problems = []
    if low > 0.003:
        problems.append("steht nicht auf dem Boden (unterste Stelle %.3f m)" % low)
    if low < -0.05:
        return problems   # hängt an Wand oder Decke: keine Beine zu prüfen
    for i, (name, verts, polys, _bvh) in enumerate(parts):
        zmin = min(v.z for v in verts)
        zmax = max(v.z for v in verts)
        if zmin > low + FLOOR or zmax - zmin < 0.02:
            continue
        top = [v for v in verts if v.z > zmax - TOP_BAND]
        xs = [v.x for v in top]
        ys = [v.y for v in top]
        if max(max(xs) - min(xs), max(ys) - min(ys)) > NARROW:
            continue
        attached = False
        best = 9.0
        for j, (_n2, _v2, _p2, bvh) in enumerate(parts):
            if j == i:
                continue
            for p in top:
                hit = bvh.find_nearest(p, 0.2)
                if hit[0] is None:
                    continue
                loc, normal, _idx, dist = hit
                if dist < TOUCH or (p - loc).dot(normal) < 0.0:
                    attached = True
                    break
                best = min(best, dist)
            if attached:
                break
        if not attached:
            c = sum(top, Vector()) / len(top)
            # nur ein Befund, wenn direkt darüber etwas liegt, das das Bein tragen soll (freie Enden wie Pfosten, Vasen,
            # Buchstützen ragen einfach nach oben)
            above = None
            for j, (_n2, _v2, _p2, bvh) in enumerate(parts):
                if j != i:
                    hit = bvh.ray_cast(Vector((c.x, c.y, zmax - 0.002)), Vector((0, 0, 1)), 0.1)
                    if hit[0] is not None and (above is None or hit[3] < above):
                        above = hit[3]
            if above is None:
                continue
            problems.append("%s: Bein/Fuß bei (%.2f, %.2f) endet oben bei %.2f m frei (nächstes Teil %s)" % (
                name, c.x, c.y, zmax, ("%.1f cm" % (best * 100)) if best < 9 else "weit weg"))
    return problems


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    files = sorted(glob.glob(os.path.join(SOURCE, "*.blend")))
    if argv:
        files = [f for f in files if os.path.splitext(os.path.basename(f))[0] in argv]
    bad = 0
    for blend in files:
        name = os.path.splitext(os.path.basename(blend))[0]
        try:
            problems = check(blend)
        except Exception as exc:  # noqa: BLE001 – eine kaputte Datei soll die übrigen nicht aufhalten
            problems = ["Fehler beim Prüfen: %s" % exc]
        if problems:
            bad += 1
            print("BEINE %s:" % name)
            for p in problems:
                print("    " + p)
        else:
            print("BEINE %s: in Ordnung" % name)
    print("BEINE fertig: %d von %d Möbeln mit Befund" % (bad, len(files)))


main()
