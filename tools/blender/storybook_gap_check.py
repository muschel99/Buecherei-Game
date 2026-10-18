"""Lochprüfung für Bilderbuch-Häuser: findet Lücken, durch die man ins Haus schaut.

Aufruf (Blender im Hintergrund, mit der .blend des Hauses):
  blender -b assets/models/source/houses/pub_storybook.blend --python tools/blender/storybook_gap_check.py -- \\
      --size=5.6,8.0,6.55 [--hide=Gaststube und Zimmer] [--side=-1] [--keep]

So geht es: Die Einrichtung innen wird ausgeblendet, Glas ist (in Workbench) undurchsichtig, und
mitten ins Haus kommt ein pinker Prüfkörper. Jedes pinke Pixel im Bild ist also ein Loch in
Mauer, Rahmen, Tür oder Schild. Viele Blickpunkte von der Straße (Augenhöhe, nah und fern, nach
oben) – das Script zählt die pinken Pixel je Bild und speichert Bilder mit Loch nach
screenshots/blender/gap_check/ (mit --keep alle). --size = Breite, Tiefe, Traufhöhe (Meter),
--side = freie Seitenwand (-1 links, 1 rechts, 0 keine) für Blicke aus der Gasse.
Eckhäuser: --probe=x0,y0,x1,y1 (Prüfkörper im Grundriss, ganz innerhalb der Mauern; mit Höhen:
x0,y0,z0,x1,y1,z1) und
--ring=cx,cy,r (zusätzlich 16 Blicke rundherum auf Augenhöhe und von schräg unten).
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "screenshots", "blender", "gap_check")
INSIDE = ("Gaststube und Zimmer", "Innen", "Zimmer oben", "Licht", "Kollision (Spiel)")


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"size": "5.6,8.0,6.5", "hide": "", "side": "0", "probe": "", "ring": ""}
    keep = "--keep" in argv
    for a in argv:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            opts[k] = v
    w, d, e = (float(v) for v in opts["size"].split(","))
    hide = set(INSIDE) | {h for h in opts["hide"].split(",") if h}
    probe = [float(v) for v in opts["probe"].split(",")] if opts["probe"] else None
    ring = [float(v) for v in opts["ring"].split(",")] if opts["ring"] else None
    return w, d, e, hide, int(opts["side"]), keep, probe, ring


def setup(w, d, e, hide, probe_box=None):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "FLAT"
    sh.color_type = "OBJECT"
    sh.show_backface_culling = True       # wie im Spiel: Rückseiten unsichtbar
    sh.show_cavity = False
    sh.background_type = "WORLD"
    sc.view_settings.view_transform = "Standard"
    sc.world = sc.world or bpy.data.worlds.new("Welt")
    sc.world.color = (0.85, 0.9, 1.0)
    sc.render.resolution_x, sc.render.resolution_y = 640, 480
    for coll in bpy.data.collections:
        if coll.name in hide:
            for o in coll.all_objects:
                o.hide_render = True
    for i, o in enumerate(o for o in bpy.data.objects if o.type == "MESH"):
        h = (i * 0.618) % 1.0
        o.color = (0.35 + 0.5 * h, 0.4 + 0.5 * ((h * 7) % 1), 0.35 + 0.4 * ((h * 13) % 1), 1)
    # Prüfkörper: füllt das Haus innen (hinter der Tür-Ebene, innerhalb der Mauern)
    hw = w / 2 - 0.36
    me = bpy.data.meshes.new("_probe")
    lo, hi = Vector((-hw, 0.45, 0.12)), Vector((hw, d - 0.35, e - 0.15))
    if probe_box and len(probe_box) == 6:
        # mit Höhen: x0,y0,z0,x1,y1,z1 (z. B. nur das Obergeschoss über der Durchfahrt des Torhauses)
        lo, hi = Vector(probe_box[:3]), Vector(probe_box[3:])
    elif probe_box:
        lo, hi = Vector((probe_box[0], probe_box[1], 0.12)), Vector((probe_box[2], probe_box[3], e - 0.15))
    vs = [(x, y, z) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    me.from_pydata(vs, [], fs)
    me.update()
    probe = bpy.data.objects.new("_probe", me)
    probe.color = (1.0, 0.0, 1.0, 1.0)
    sc.collection.objects.link(probe)


def views(w, e, side, ring=None):
    """Blickpunkte (Kamera, Ziel, Brennweite): Straße in Augenhöhe, nah an Tür und Fenstern,
    schräg, nach oben zu Schild und Gesims, aus der Gasse."""
    out = {}
    hw = w / 2
    for i, x in enumerate((-hw - 1.5, -hw + 0.5, 0.0, hw - 0.5, hw + 1.5)):
        for j, dist in enumerate((1.0, 2.2, 4.5)):
            for k, tz in enumerate((1.2, 2.9, 4.8)):
                cam = (x, -dist, 1.6)
                tgt = (x * 0.4, 0.2, tz)
                out["strasse_%d_%d_%d" % (i, j, k)] = (cam, tgt, 24)
    for k, x in enumerate((-0.6, -0.2, 0.2, 0.6)):
        out["tuer_oben_%d" % k] = ((x, -0.7, 1.5), (0.0, 0.3, 2.7), 20)
        out["schild_unten_%d" % k] = ((x * 3, -1.0, 1.5), (x, 0.0, 3.1), 18)
    for k, x in enumerate((-hw + 0.6, hw - 0.6)):
        out["fenster_oben_%d" % k] = ((x, -3.0, 1.6), (x, 0.0, e - 1.0), 28)
    if ring:
        cx, cy, r = ring
        for k in range(16):
            a = 2 * math.pi * k / 16
            cam = (cx + math.cos(a) * r, cy + math.sin(a) * r, 1.6 if k % 2 == 0 else 1.1)
            out["rund_%02d" % k] = (cam, (cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55, 2.6), 26)
    if side:
        sx = side * (hw + 2.5)
        for k, y in enumerate((-1.0, 1.5, 4.0)):
            out["gasse_%d" % k] = ((sx, y, 1.6), (side * hw, y + 1.5, 2.6), 24)
    return out


def main():
    w, d, e, hide, side, keep, probe, ring = args()
    setup(w, d, e, hide, probe)
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    tmp = os.path.join(OUT, "_tmp.png")
    found = []
    for name, (cam, tgt, lens) in views(w, e, side, ring).items():
        data = bpy.data.cameras.new(name)
        data.lens = lens
        data.clip_start = 0.02
        obj = bpy.data.objects.new(name, data)
        sc.collection.objects.link(obj)
        obj.location = cam
        obj.rotation_euler = (Vector(tgt) - Vector(cam)).to_track_quat("-Z", "Y").to_euler()
        sc.camera = obj
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        px = np.array(img.pixels[:]).reshape(-1, 4)
        bpy.data.images.remove(img)
        pink = int(np.sum((px[:, 0] > 0.9) & (px[:, 1] < 0.1) & (px[:, 2] > 0.9)))
        if pink or keep:
            os.replace(tmp, os.path.join(OUT, name + ".png"))
        if pink:
            found.append((name, pink))
    if os.path.exists(tmp):
        os.remove(tmp)
    print("Lochprüfung: %d Blickpunkte" % len(views(w, e, side, ring)))
    if found:
        for name, n in found:
            print("  LOCH: %s – %d pinke Pixel (Bild: %s.png)" % (name, n, os.path.join(OUT, name)))
    else:
        print("  keine Löcher gefunden")


main()
