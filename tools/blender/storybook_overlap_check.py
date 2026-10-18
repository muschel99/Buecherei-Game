"""Überschneidungs-Prüfung für Bilderbuch-Häuser: Stehen Töpfe, Kübel, Kästen, Tafeln, Tische
oder das Fahrrad in einer Wand, im Schaufenster, in der Ladenfront oder ineinander?

Aufruf (Blender im Hintergrund, mit der .blend des Hauses):
  blender -b assets/models/source/houses/wool_shop_storybook.blend --python tools/blender/storybook_overlap_check.py

Geprüft wird alles aus den Sammlungen „Töpfe …“ und „Deko“, was unten auf dem Boden steht
(Unterkante unter 20 cm), gegen alle Teile von Mauern, Fenstern und Ladenfront und gegen die
anderen Bodenteile (Dreiecke, die sich schneiden; weiche Kanten eingerechnet). Teile desselben
Gegenstands (Topf und Erde, Fahrrad-Rahmen und Reifen …) zählen zusammen. Ergebnis: „keine
Überschneidungen“ oder je Paar eine Zeile.
"""

import bmesh
import bpy
from mathutils.bvhtree import BVHTree

FACADE = ("Mauern", "Fenster", "Ladenfront", "Laden")
GROUND = ("Töpfe und Kübel", "Töpfe und Kästen", "Deko")
SUFFIXES = (" Erde", " Rahmen", " Bild", " Chrom", " Reifen", " Sattel und Griffe", " Korb vorn", " Korb hinten", " Korbstreben", " Platte",
            " Arm", " Halter", " Topf")


def group(name):
    """Teile eines Gegenstands gehören zusammen (Topf + Erde, Fahrrad-Rahmen + Reifen …)."""
    g = name
    changed = True
    while changed:
        changed = False
        for suf in SUFFIXES:
            if g.endswith(suf):
                g = g[:-len(suf)]
                changed = True
    return g


def tree(obj, dg):
    """BVH des fertigen Teils (mit Modifikatoren) in Weltkoordinaten."""
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(obj.matrix_world)
    t = BVHTree.FromBMesh(bm)
    lo = [min(v.co[i] for v in bm.verts) for i in range(3)]
    hi = [max(v.co[i] for v in bm.verts) for i in range(3)]
    bm.free()
    ev.to_mesh_clear()
    return t, lo, hi


def boxes_touch(a, b, pad=0.01):
    return all(a[1][i] + pad >= b[0][i] and b[1][i] + pad >= a[0][i] for i in range(3))


def main():
    dg = bpy.context.evaluated_depsgraph_get()
    facade, ground = [], []
    for coll in bpy.data.collections:
        objs = [o for o in coll.objects if o.type == "MESH" and not o.hide_render]
        if coll.name in FACADE:
            facade += objs
        elif coll.name in GROUND:
            ground += objs
    data = {}
    for o in facade + ground:
        t, lo, hi = tree(o, dg)
        data[o.name] = (t, (lo, hi))
    ground = [o for o in ground if data[o.name][1][0][2] < 0.2]
    found = []
    for i, g in enumerate(ground):
        tg, bg = data[g.name]
        for f in facade:
            tf, bf = data[f.name]
            if boxes_touch(bg, bf) and tg.overlap(tf):
                found.append((g.name, f.name))
        for h in ground[i + 1:]:
            if group(h.name) == group(g.name):
                continue
            th, bh = data[h.name]
            if boxes_touch(bg, bh) and tg.overlap(th):
                found.append((g.name, h.name))
    print("Überschneidungs-Prüfung: %d Bodenteile gegen %d Fassadenteile" % (len(ground), len(facade)))
    if found:
        for a, b in found:
            print("  ÜBERSCHNEIDUNG: %s  ↔  %s" % (a, b))
    else:
        print("  keine Überschneidungen")


main()
