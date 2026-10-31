"""Autos und Fahrräder im Bilderbuch-Stil (seit Etappe 6c, ersetzt die Modelle aus build_vehicles.py).

Weich und rund wie Spielzeug, aber solide: die Karosserie ist EIN geschlossener Körper aus
Querschnitten (abgerundete Rechtecke, zweimal geglättet), Radkästen ausgeschnitten und mit
gerundetem Kotflügel-Rand; darüber Säulen als runde Röhren, ein weiches Dach und Scheiben zwischen
den Säulen (dahinter Sitze, Armaturenbrett, Lenkrad). Lampen, Grill, Stoßstangen, Türfugen und
Griffe sitzen genau auf der Haut (Sichtstrahlen auf die Karosserie).

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/build_storybook_vehicles.py [-- Namen] [--render]
    Namen: taxi mini traveller delivery_van bicycle (ohne Angabe: alle)

Ergebnis (gleiche Dateien wie bisher, Godot-Szenen bleiben): assets/models/vehicles/<name>.glb
(Karosserie), <name>_wheel.glb (ein Rad, Achse x, Außenseite +x – Godot setzt es viermal ein und
dreht es), delivery_van_door.glb (Schiebetür, Knoten "Door"), Fahrrad: bicycle_chibi.glb (Rahmen),
bicycle_chibi_saddle.glb (Sattel, Ursprung = Sitzpunkt), bicycle_chibi_crank.glb (Kurbel),
bicycle_wheel.glb, bicycle_chibi_basket.glb (Korb vorn); Quelle
assets/models/source/vehicles/storybook_vehicles.blend.
Koordinaten wie im Spiel: x links (aus Sicht des Fahrers), y oben, z nach vorn; Räder auf y = 0.
Farben: "Autolack" und "Autolack zwei" (Dach, obere Hälfte) bzw. "Fahrradlack" färbt Godot je
Fahrzeug um (VehicleModel, ChibiCyclistModel).
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storybook_common as SC  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

OUT = os.path.join(SC.ROOT, "assets", "models", "vehicles")
BLEND = os.path.join(SC.ROOT, "assets", "models", "source", "vehicles", "storybook_vehicles.blend")
STAMP = os.path.join(os.path.dirname(BLEND), "storybook_vehicles.stamp")

# Punkte je Querschnitt der Karosserie
RING = 24


def g(x, y, z):
    """Godot (x links, y oben, z vorn) -> Blender (x, -z, y)."""
    return Vector((x, -z, y))


def materials():
    M = SC.materials()
    mk = SC.make_material
    M["paint"] = mk("Autolack", (0.66, 0.16, 0.12), grain="smooth", rough=0.34, metal=0.08, vary=0.02, bump=0.02, own=True)
    M["paint2"] = mk("Autolack zwei", (0.93, 0.89, 0.8), grain="smooth", rough=0.38, vary=0.02, bump=0.02, own=True)
    M["bike_paint"] = mk("Fahrradlack", (0.52, 0.64, 0.48), grain="smooth", rough=0.42, metal=0.1, vary=0.02, bump=0.02, own=True)
    M["car_glass"] = mk("Autoglas", (0.78, 0.86, 0.9), grain="smooth", rough=0.04, glass=True, vary=0.0, bump=0.0)
    M["inside"] = mk("Auto innen", (0.26, 0.21, 0.18), grain="fabric", rough=0.95, vary=0.05)
    M["seat"] = mk("Autositz", (0.52, 0.32, 0.2), grain="fabric", rough=0.75, vary=0.06)
    M["head"] = mk("Scheinwerfer", (1.0, 0.96, 0.86), grain="smooth", rough=0.15, emit=0.7, emit_color=(1.0, 0.93, 0.78))
    M["tail"] = mk("Rücklicht", (0.78, 0.1, 0.07), grain="smooth", rough=0.3, emit=0.35, emit_color=(0.95, 0.18, 0.1))
    M["amber"] = mk("Blinker", (0.96, 0.6, 0.18), grain="smooth", rough=0.3, emit=0.25, emit_color=(1.0, 0.62, 0.2))
    M["plate"] = mk("Nummernschild", (0.93, 0.91, 0.84), grain="paint", rough=0.6, vary=0.03)
    M["seam"] = mk("Fuge Auto", (0.08, 0.07, 0.07), grain="smooth", rough=0.85, vary=0.0)
    M["tyre"] = mk("Reifen", (0.14, 0.13, 0.125), grain="smooth", rough=0.85, vary=0.02)
    M["wood"] = mk("Holz Esche", (0.74, 0.54, 0.33), grain="wood", rough=0.7, vary=0.08)
    M["taxi_sign"] = mk("Taxischild", (0.98, 0.8, 0.32), grain="smooth", rough=0.4, emit=0.55, emit_color=(1.0, 0.82, 0.4))
    M["ink"] = mk("Schrift dunkel", (0.12, 0.1, 0.09), grain="smooth", rough=0.6, vary=0.0)
    M["saddle"] = mk("Sattelleder", (0.38, 0.23, 0.14), grain="fabric", rough=0.6, vary=0.06)
    M["box"] = mk("Karton", (0.74, 0.57, 0.38), grain="fabric", rough=0.95, vary=0.08)
    return M


# --- Bausteine ------------------------------------------------------------------------------------

def ring_points(y0, y1, hw, p=3.0, tumble=0.05):
    """Abgerundetes Rechteck (Superellipse) im Querschnitt; oben um tumble schmaler."""
    yc, hh = (y0 + y1) / 2, (y1 - y0) / 2
    pts = []
    for i in range(RING):
        t = 2 * math.pi * i / RING
        c, s = math.cos(t), math.sin(t)
        x = math.copysign(abs(c) ** (2 / p), c)
        y = math.copysign(abs(s) ** (2 / p), s)
        pts.append((x * hw * (1 - tumble * max(0.0, y)), yc + y * hh))
    return pts


def round_ends(rings, rear=0.07, front=0.07):
    """Vor den ersten und hinter den letzten Querschnitt zwei kleinere setzen: runde Enden."""
    def shrink(r, dz, k):
        z, y0, y1, hw = r[:4]
        yc, hh = (y0 + y1) / 2, (y1 - y0) / 2
        return (z + dz, yc - hh * k, yc + hh * k, hw * k) + tuple(r[4:])
    first, last = rings[0], rings[-1]
    return [shrink(first, -rear, 0.4), shrink(first, -rear * 0.6, 0.78)] + list(rings) + \
        [shrink(last, front * 0.6, 0.78), shrink(last, front, 0.4)]


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.object.modifier_apply(modifier=mod.name)


def soft_shell(name, mat, coll, rings, levels=2, p=3.0, tumble=0.05):
    """Geschlossener, weicher Körper aus Querschnitten [(z, y0, y1, hw)] von hinten nach vorn."""
    b = Body(name, mat, coll, seed=1, vary=0.0)
    bm = b.bm
    loops = [[bm.verts.new(g(x, y, r[0])) for x, y in ring_points(r[1], r[2], r[3], p, tumble)] for r in rings]
    faces = []
    for a, c in zip(loops, loops[1:]):
        for i in range(RING):
            j = (i + 1) % RING
            faces.append(bm.faces.new((a[i], a[j], c[j], c[i])))
    centers = []
    for loop, r in ((loops[0], rings[0]), (loops[-1], rings[-1])):
        cen = bm.verts.new(g(0.0, (r[1] + r[2]) / 2, r[0]))
        centers.append(cen)
        for i in range(RING):
            faces.append(bm.faces.new((loop[i], loop[(i + 1) % RING], cen)))
    b._finish_island([v for lp in loops for v in lp] + centers, faces, (1.0, 1.0, 1.0))
    obj = b.build(smooth_angle=180)
    mod = obj.modifiers.new("Weich", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    apply_modifiers(obj)
    return obj


def cylinder_cutter(start, axis, radius, length, segs=40):
    """Schneide-Zylinder ab start entlang axis (Blender-Vektoren)."""
    b = Body("_cut", None, bpy.context.scene.collection, vary=0)
    faces = b.lathe([(0.0, 0.0), (radius, 0.0), (radius, length), (0.0, length)], (0, 0, 0), segs=segs)
    m = Matrix.Translation(start) @ frame(axis)
    for v in {v for f in faces for v in f.verts}:
        v.co = m @ v.co
    me = bpy.data.meshes.new("_cut")
    b.bm.to_mesh(me)
    b.bm.free()
    return bpy.data.objects.new("_cut", me)


def frame(normal, up=Vector((0, 0, 1))):
    """Drehung: lokal +z = normal, lokal x waagerecht."""
    z = Vector(normal).normalized()
    x = up.cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed().to_4x4()


def lathe_on(body, profile, center, axis, segs=16, tint=None):
    """Drehkörper (Profil wie Body.lathe) um eine beliebige Achse."""
    faces = body.lathe(profile, (0, 0, 0), segs=segs, tint=tint)
    m = Matrix.Translation(center) @ frame(axis)
    for v in {v for f in faces for v in f.verts}:
        v.co = m @ v.co
    return faces


def tree_of(objs):
    verts, polys = [], []
    for o in objs:
        me = o.data
        off = len(verts)
        verts += [o.matrix_world @ v.co for v in me.vertices]
        polys += [[off + i for i in p.vertices] for p in me.polygons]
    return BVHTree.FromPolygons(verts, polys)


def hit(tree, origin, direction):
    """Erster Treffer (Blender) von origin in direction, beides Godot-Angaben."""
    d = Vector((direction[0], -direction[2], direction[1])).normalized()
    loc, normal, _i, _d = tree.ray_cast(g(*origin), d)
    return (loc, normal) if loc is not None else (None, None)


def surface_y(tree, x, z, top=3.0):
    loc, _n = hit(tree, (x, top, z), (0, -1, 0))
    return loc.z if loc is not None else None


def slab_quad(body, corners, thick=0.006):
    """Ebene Platte durch vier Ecken (Blender, eben), Dicke mittig."""
    p0, p1, p2, p3 = corners
    u = (p1 - p0).normalized()
    v = (p3 - p0) - u * (p3 - p0).dot(u)
    v.normalize()
    n = u.cross(v)
    m = Matrix((u, v, n)).transposed().to_4x4()
    m.translation = p0 - n * thick / 2
    outline = [((q - p0).dot(u), (q - p0).dot(v)) for q in corners]
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(outline, outline[1:] + outline[:1]))
    if area < 0:
        outline.reverse()
    body.slab(outline, thick, m, dent=0.0)


# --- Auto -----------------------------------------------------------------------------------------

def build_car(M, coll, sp):
    """Ein Auto nach der Beschreibung sp (siehe TAXI, MINI …)."""
    paint, paint2 = M["paint"], M["paint2"]
    hw, wr = sp["hw"], sp["wr"]
    lower = soft_shell("Karosserie", paint, coll, round_ends(sp["rings"], sp.get("rear_round", 0.07), sp.get("front_round", 0.07)),
                       p=sp.get("p", 3.0))
    # Radkästen: auf jeder Seite eine Tasche (nicht quer durch das Auto)
    cut_r = wr + sp.get("arch_gap", 0.05)
    depth = sp.get("arch_depth", 0.3)
    cutters = []
    for wz in sp["wheels"]:
        for side in (-1, 1):
            x0 = side * (hw - depth) if side > 0 else -(hw + 0.4)
            cutters.append(cylinder_cutter(g(x0, wr, wz), Vector((1, 0, 0)), cut_r, depth + 0.4))
    SB.boolean_cut(lower, cutters)
    tree = tree_of([lower])
    lips = Body("Kotflügel", paint, coll, seed=2, vary=0.0)
    for wz in sp["wheels"]:
        for side in (-1, 1):
            pts = []
            for k in range(-4, 41):
                a = math.radians(k * 180 / 36)
                y, z = wr + math.sin(a) * (cut_r + 0.014), wz + math.cos(a) * (cut_r + 0.014)
                loc, n = hit(tree, (side * (hw + 0.6), y, z), (-side, 0, 0))
                if loc is not None and abs(loc.x) > hw - 0.12:
                    pts.append(loc + n * 0.004)
                elif pts:
                    break
            if len(pts) > 3:
                lips.tube(pts, 0.022, segs=8, smooth=1, round_ends=True, tint=(1.0, 1.0, 1.0))
    lips.build()

    # Säulen, Dach, Scheiben
    belt, roof = sp["belt"], sp["roof"]
    xb, xr = sp["xb"], sp["xr"]
    pillars = sp["pillars"]            # [(z unten, z oben, Material-Schlüssel)] von vorn nach hinten
    rz0, rz1 = sp["roof_z"]
    roof_mat = M[sp.get("roof_mat", "paint")]
    soft_shell("Dach", roof_mat, coll, round_ends([(rz0, roof - 0.1, roof, sp["roof_hw"]), (rz1, roof - 0.1, roof, sp["roof_hw"])],
                                                  0.05, 0.05), levels=2, p=3.4, tumble=0.0)
    bodies = {}

    def part(key, mat, seed=10, bevel=0.0):
        if key not in bodies:
            bodies[key] = Body(key, mat, coll, seed=seed, vary=0.03, bevel=bevel)
        return bodies[key]

    base_y = {}
    for zb, zt, mkey in pillars:
        for side in (-1, 1):
            yb = surface_y(tree, side * xb, zb) or belt
            base_y[(zb, side)] = yb
            part("Säulen " + mkey, M[mkey]).tube([g(side * xb, yb - 0.04, zb), g(side * xr, roof - 0.05, zt)], sp.get("pillar_r", 0.036),
                                                 segs=10, round_ends=True)
    glass = part("Scheiben", M["car_glass"])
    top_y = roof - 0.05
    fills = sp.get("bays", ["glass"] * (len(pillars) - 1))
    for i in range(len(pillars) - 1):
        (za, zat, _m), (zc, zct, _m2) = pillars[i], pillars[i + 1]
        for side in (-1, 1):
            kind = fills[i] if isinstance(fills[i], str) else fills[i][0 if side > 0 else 1]
            yb = min(base_y[(za, side)], base_y[(zc, side)]) - 0.03
            corners = [g(side * xb, yb, za), g(side * xb, yb, zc), g(side * xr, top_y, zct), g(side * xr, top_y, zat)]
            if kind == "glass":
                slab_quad(glass, corners)
            elif kind == "dark":
                slab_quad(part("Türöffnung", M["seam"]), corners, 0.01)
            elif kind == "panel":
                # geschlossene Seitenwand (Laderaum): dicker, in der zweiten Farbe
                slab_quad(part("Seitenwand", paint2), corners, 0.05)
            elif kind == "wood_panel":
                slab_quad(part("Seitenwand", paint2), corners, 0.04)
    # Front- und Heckscheibe zwischen den äußeren Säulen
    for (zb, zt, _m), ofs in ((pillars[0], 1), (pillars[-1], -1)):
        yb = base_y[(zb, 1)] - 0.03
        slab_quad(glass, [g(xb, yb, zb), g(-xb, yb, zb), g(-xr, top_y, zt), g(xr, top_y, zt)])
    if sp.get("screen_bar"):
        zb, zt, mkey = pillars[0]
        part("Säulen " + mkey, M[mkey]).tube([g(0, base_y[(zb, 1)] - 0.04, zb), g(0, roof - 0.05, zt)], 0.03, segs=8, round_ends=True)

    # Innen: Armaturenbrett, Lenkrad (rechts: Linksverkehr), Sitze
    za = pillars[0][0]
    ya = base_y[(za, 1)]
    inner = part("Innen", M["inside"], seed=20, bevel=0.02)
    inner.box(tuple(g(0, ya + 0.04, za - 0.16)), (2 * xb - 0.14, 0.2, 0.14), step=1, dent=0.002)
    wheel_c = g(-xb * 0.45, ya + 0.16, za - 0.36)
    ring = [wheel_c + (frame(g(0, 0.5, 1) - g(0, 0, 0)) @ Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.0)))
            for a in [2 * math.pi * k / 20 for k in range(20)]]
    # Lenkrad ohne Kantenrundung (die würde den dünnen Ring zu einer Scheibe aufblähen)
    steer = part("Lenkrad", M["inside"], seed=23)
    T.loop_tube(steer, ring, 0.016, segs=6, axis=tuple(g(0, 0.5, 1) - g(0, 0, 0)))
    steer.tube([wheel_c, g(-xb * 0.45, ya + 0.02, za - 0.2)], 0.02, segs=6, round_ends=True)
    seats = part("Sitze", M["seat"], seed=21, bevel=0.03)
    for z, pair in sp["seats"]:
        y = surface_y(tree, 0.0, z) or belt
        if pair:
            for sx in (-1, 1):
                seats.box(tuple(g(sx * xb * 0.48, y + 0.17, z)), (xb * 0.8, 0.13, 0.42), step=1, dent=0.006)
                seats.box(tuple(g(sx * xb * 0.48, y + 0.42, z - 0.02)), (0.24, 0.1, 0.12), step=1, dent=0.004)
        else:
            seats.box(tuple(g(0, y + 0.16, z)), (2 * xb - 0.16, 0.13, 0.4), step=1, dent=0.006)
    if sp.get("cargo"):
        boxes = part("Kartons", M["box"], seed=22, bevel=0.01)
        for (x, z, s, turn) in sp["cargo"]:
            y = surface_y(tree, x, z) or belt
            boxes.box(tuple(g(x, y + s / 2 - 0.05, z)), (s, s * 0.95, s * 0.8), step=1, dent=0.004, turn=(0, 0, turn))

    # Lampen
    chrome = part("Chrom", M["chrome"], seed=30)
    front_z, rear_z = sp["rings"][-1][0] + 1.0, sp["rings"][0][0] - 1.0
    for (x, y, r, kind) in sp["lamps"]:
        for sx in (-1, 1):
            back = kind in ("tail",)
            loc, n = hit(tree, (sx * x, y, rear_z if back else front_z), (0, 0, 1 if back else -1))
            if loc is None:
                continue
            c = loc - n * 0.012
            lathe_on(chrome, [(0.0, 0.0), (r + 0.016, 0.0), (r + 0.02, 0.018), (r + 0.006, 0.03), (r, 0.024), (0.0, 0.024)], c, n, segs=20)
            lathe_on(part("Licht " + kind, M[kind]), [(0.0, 0.0), (r, 0.0), (r * 0.96, 0.03), (r * 0.6, 0.042), (0.0, 0.046)],
                     c + n * 0.006, n, segs=20)
    # Grill
    if sp.get("grille"):
        gy, gh, gw, bars = sp["grille"]
        loc, n = hit(tree, (0.0, gy, front_z), (0, 0, -1))
        if loc is not None:
            m = Matrix.Translation(loc - n * 0.015) @ frame(n)
            part("Grill", M["seam"]).box((0, 0, 0.01), (gw, gh, 0.03), step=1, dent=0.0, matrix=m)
            outline = [m @ Vector((x, y, 0.03)) for x, y in SB.round_outline(28) for x, y in [(x * gw * 1.04, y * gh * 1.08)]]
            T.loop_tube(chrome, outline, 0.014, segs=6, axis=tuple(n))
            for k in range(bars):
                if sp.get("grille_flat"):
                    yy = -gh / 2 + gh * (k + 0.5) / bars
                    chrome.tube([m @ Vector((-gw * 0.46, yy, 0.03)), m @ Vector((gw * 0.46, yy, 0.03))], 0.007, segs=5, round_ends=True)
                else:
                    xx = -gw / 2 + gw * (k + 0.5) / bars
                    half = gh * 0.5 * math.sqrt(max(0.0, 1 - (2 * xx / gw) ** 2)) * 0.95
                    chrome.tube([m @ Vector((xx, -half, 0.03)), m @ Vector((xx, half, 0.03))], 0.008, segs=5, round_ends=True)
    # Stoßstangen: rund um die Ecken, auf Abstand zur Haut
    by = sp["bumper_y"]
    for end in (1, -1):
        zc = (sp["rings"][-1][0] - 0.6) if end > 0 else (sp["rings"][0][0] + 0.6)
        pts = []
        for k in range(-7, 8):
            a = math.radians(k * 11)
            d = (math.sin(a), 0.0, math.cos(a) * end)
            loc, n = hit(tree, (0.0, by, zc), d)
            if loc is not None:
                pts.append(loc + Vector((d[0], -d[2], 0.0)) * 0.035)
        if len(pts) > 4:
            chrome.tube(pts, 0.034, segs=10, smooth=1, round_ends=True)
    # Nummernschilder
    for end, y in ((1, sp["plate_y"]), (-1, sp["plate_y"] + 0.06)):
        loc, n = hit(tree, (0.0, y, front_z if end > 0 else rear_z), (0, 0, -end))
        if loc is not None:
            part("Schild", M["plate"], seed=31, bevel=0.006).box((0, 0, 0.005), (0.42, 0.1, 0.02), step=1, dent=0.0,
                                                                 matrix=Matrix.Translation(loc) @ frame(n))
    # Türfugen, Griffe, Spiegel
    seam = part("Fugen", M["seam"])
    for z in sp.get("seams", []):
        for side in (-1, 1):
            pts = []
            ytop = (surface_y(tree, side * xb, z) or belt) - 0.035
            y = sp["rings"][2][1] + 0.08
            while y < ytop:
                loc, n = hit(tree, (side * (hw + 0.5), y, z), (-side, 0, 0))
                if loc is not None:
                    pts.append(loc + n * 0.0015)
                y += 0.05
            if len(pts) > 2:
                seam.tube(pts, 0.0045, segs=5, round_ends=True)
    for z in sp.get("handles", []):
        for side in (-1, 1):
            loc, n = hit(tree, (side * (hw + 0.5), belt - 0.12, z), (-side, 0, 0))
            if loc is not None:
                c = loc + n * 0.012
                chrome.tube([c + Vector((0, 0.045, 0)), c - Vector((0, 0.045, 0))], 0.011, segs=6, round_ends=True)
    for side in (-1, 1):
        zb = pillars[0][0] - 0.06
        base = g(side * xb, (base_y[(pillars[0][0], side)]) + 0.02, zb)
        tip = base + Vector((side * 0.13, 0.03, 0.06))
        chrome.tube([base, tip], 0.012, segs=6, round_ends=True)
        part("Spiegel", paint, seed=32).blob(tuple(tip + Vector((side * 0.03, 0.0, 0.02))), 0.05, subdiv=2, lump=0.0, scale=(0.8, 0.45, 0.65))
    # Scheibenwischer
    zb, zt, _m = pillars[0]
    ya = base_y[(zb, 1)]
    for sx in (-0.3, 0.22):
        a = g(sx, ya + 0.03, zb - 0.01)
        b = g(sx + 0.32, ya + 0.03 + (roof - ya) * 0.35, zb + (zt - zb) * 0.35)
        seam.tube([a, b], 0.008, segs=5, round_ends=True)
    for b in bodies.values():
        b.build()
    return tree


# Maße wie die Szenen (scenes/street_life/car_*.tscn): Länge, Breite, Räder (z, Radius, x)
TAXI = dict(
    hw=0.87, wr=0.35, wheels=[1.36, -1.38],
    rings=[(-2.18, 0.36, 0.92, 0.82), (-1.9, 0.29, 0.98, 0.86), (-1.0, 0.27, 1.0, 0.87), (0.9, 0.27, 1.0, 0.87),
           (1.35, 0.29, 0.96, 0.86), (1.9, 0.31, 0.92, 0.84), (2.18, 0.34, 0.85, 0.79)],
    belt=1.0, roof=1.74, xb=0.79, xr=0.72, roof_hw=0.77, roof_z=(-1.3, 0.66),
    pillars=[(0.98, 0.6, "paint"), (0.06, 0.06, "paint"), (-0.68, -0.66, "paint"), (-1.62, -1.24, "paint")],
    seats=[(0.25, True), (-0.95, False)], lamps=[(0.6, 0.74, 0.085, "head"), (0.62, 0.55, 0.035, "amber"), (0.62, 0.76, 0.05, "tail")],
    grille=(0.62, 0.34, 0.5, 11), bumper_y=0.42, plate_y=0.38, seams=[0.62, 0.06, -0.68], handles=[0.0, -0.6],
)
MINI = dict(
    hw=0.705, wr=0.27, wheels=[1.02, -1.02], arch_depth=0.24,
    rings=[(-1.47, 0.27, 0.78, 0.66), (-1.2, 0.2, 0.8, 0.7), (0.0, 0.19, 0.8, 0.705), (0.75, 0.19, 0.8, 0.705),
           (1.2, 0.2, 0.78, 0.69), (1.47, 0.26, 0.72, 0.64)],
    belt=0.8, roof=1.33, xb=0.63, xr=0.57, roof_hw=0.62, roof_z=(-1.0, 0.55), roof_mat="paint2",
    pillars=[(0.78, 0.5, "paint"), (-0.12, -0.12, "paint"), (-1.1, -0.94, "paint")],
    seats=[(0.15, True), (-0.75, False)], lamps=[(0.46, 0.64, 0.075, "head"), (0.52, 0.5, 0.03, "amber"), (0.5, 0.66, 0.045, "tail")],
    grille=(0.5, 0.15, 0.56, 5), grille_flat=True, bumper_y=0.34, plate_y=0.38, seams=[0.56, -0.12], handles=[-0.04],
)
TRAVELLER = dict(
    hw=0.775, wr=0.31, wheels=[1.08, -1.12],
    rings=[(-1.86, 0.3, 0.9, 0.74), (-1.6, 0.22, 0.92, 0.77), (0.0, 0.21, 0.94, 0.775), (0.85, 0.21, 0.94, 0.77),
           (1.3, 0.23, 0.88, 0.75), (1.62, 0.25, 0.82, 0.72), (1.86, 0.3, 0.7, 0.66)],
    belt=0.94, roof=1.5, xb=0.71, xr=0.68, roof_hw=0.72, roof_z=(-1.86, 0.6), front_round=0.09, rear_round=0.04,
    pillars=[(0.9, 0.56, "paint"), (0.0, 0.0, "paint"), (-0.85, -0.85, "wood"), (-1.8, -1.8, "wood")],
    seats=[(0.25, True), (-0.6, False)], lamps=[(0.54, 0.7, 0.075, "head"), (0.58, 0.55, 0.03, "amber"), (0.6, 0.72, 0.045, "tail")],
    grille=(0.5, 0.2, 0.42, 7), bumper_y=0.38, plate_y=0.42, seams=[0.56, 0.0], handles=[-0.05],
    wood_frame=True,
)
VAN = dict(
    hw=0.88, wr=0.34, wheels=[1.2, -1.2], p=3.6,
    rings=[(-2.1, 0.34, 1.02, 0.85), (-1.9, 0.3, 1.05, 0.87), (0.0, 0.3, 1.05, 0.88), (1.65, 0.3, 1.05, 0.88),
           (1.95, 0.32, 1.03, 0.86), (2.1, 0.36, 0.99, 0.83)],
    belt=1.05, roof=1.98, xb=0.85, xr=0.83, roof_hw=0.87, roof_z=(-2.08, 2.04), roof_mat="paint2", pillar_r=0.04,
    front_round=0.05, rear_round=0.05,
    pillars=[(2.04, 1.95, "paint2"), (1.0, 1.0, "paint2"), (-0.05, -0.05, "paint2"), (-1.05, -1.05, "paint2"), (-2.04, -2.0, "paint2")],
    bays=["glass", ("open", "glass"), "glass", "panel"], screen_bar=True,   # "open" = Türöffnung (dahinter der Laderaum)
    seats=[(1.45, True)], cargo=[(0.25, -0.4, 0.38, 8), (-0.3, -0.7, 0.32, -14), (0.2, -1.3, 0.42, 4), (-0.25, -1.5, 0.36, 20)],
    lamps=[(0.62, 0.8, 0.09, "head"), (0.64, 0.6, 0.035, "amber"), (0.66, 0.8, 0.05, "tail")],
    grille=(0.62, 0.08, 0.5, 4), grille_flat=True, bumper_y=0.42, plate_y=0.46, seams=[1.0], handles=[0.92],
)
CARS = {"taxi": TAXI, "mini": MINI, "traveller": TRAVELLER, "delivery_van": VAN}
# Räder: Radius, Breite, Felge (Chrom oder zweite Farbe)
WHEELS = {"taxi": (0.35, 0.19, "chrome"), "mini": (0.27, 0.15, "chrome"), "traveller": (0.31, 0.16, "paint2"),
          "delivery_van": (0.34, 0.18, "paint2")}


def taxi_extras(M, coll, tree):
    """Taxi-Schild auf dem Dach (leuchtet gelb, Schrift vorn und hinten) und Trittbretter."""
    sign = Body("Taxischild", M["taxi_sign"], coll, seed=40, bevel=0.02)
    sign.box(tuple(g(0, 1.79, 0.05)), (0.5, 0.16, 0.13), step=1, dent=0.0)
    sign.build()
    ink = Body("Taxischrift", M["ink"], coll, seed=41)
    for z, flip in ((0.05 + 0.082, 1), (0.05 - 0.082, -1)):
        m = Matrix(((flip, 0, 0, 0), (0, 0, -flip, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        m = Matrix.Translation(g(0, 1.757, z)) @ m
        ink.text("TAXI", 0.075, 0.006, m, font="DejaVuSans-Bold.ttf", resolution=4)
    ink.build()
    step = Body("Trittbrett", M["seam"], coll, seed=42, bevel=0.012)
    for side in (-1, 1):
        step.box(tuple(g(side * 0.83, 0.28, -0.02)), (0.12, 1.5, 0.03), step=1, dent=0.0)
    step.build()


def traveller_extras(M, coll, tree):
    """Holzrahmen am Heck: Leiste unter den Fenstern und Mittelholm der Hecktüren (die hinteren
    Säulen sind schon aus Holz)."""
    wood = Body("Holzrahmen", M["wood"], coll, seed=45, vary=0.06, bevel=0.008)
    sp = TRAVELLER
    for side in (-1, 1):
        # Leisten genau auf der Haut (Sichtstrahlen von außen), Pfosten dazwischen
        for y, w, h in ((sp["belt"] - 0.07, 0.05, 0.06),):
            a, na = hit(tree, (side * 1.4, y, -0.12), (-side, 0, 0))
            b, nb = hit(tree, (side * 1.4, y, -1.66), (-side, 0, 0))
            if a is not None and b is not None:
                wood.span(tuple(a + na * 0.012), tuple(b + nb * 0.012), w, h, step=1, dent=0.002)

    lo, _n = hit(tree, (0.0, sp["belt"] - 0.1, -3.0), (0, 0, 1))
    if lo is not None:
        wood.span(tuple(lo + Vector((0, -0.02, 0))), tuple(g(0, sp["roof"] - 0.05, -1.82)), 0.05, 0.05, step=1, dent=0.002)
    wood.build()


def van_extras(M, coll, tree):
    """Logo von Nest & Nook auf beiden Seiten (Bild der Entwicklerin), dunkle Türöffnung hinter der
    Schiebetür, Zierleiste in der Gürtellinie."""
    logo = Body("Logo", SC.sign_material("delivery_van", "logo"), coll, seed=50)
    sp = VAN
    for side in (-1, 1):
        x = side * (sp["xb"] + 0.027)
        if side > 0:
            m = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        else:
            m = Matrix(((0, 0, -1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        # Seitenverhältnis wie das Bild (1024 x 496 Pixel)
        logo.panel(Matrix.Translation(g(x, 1.5, -1.55)) @ m, 0.86, 0.86 * 496 / 1024, 0.008)
    logo.build()
    dark = Body("Türöffnung unten", M["seam"], coll, seed=51, bevel=0.01)
    dark.box(tuple(g(sp["hw"] - 0.012, 0.69, 0.46)), (0.03, 0.84, 0.66), step=1, dent=0.0)
    dark.build()
    trim = Body("Zierleiste", M["paint2"], coll, seed=52)
    for side in (-1, 1):
        # auf der Türseite unterbrochen (dort liegt die Schiebetür auf)
        spans = [(-1.95, 1.9)] if side < 0 else [(-1.95, -0.06), (0.98, 1.9)]
        for z0, z1 in spans:
            pts = []
            n_pts = max(3, int((z1 - z0) / 0.25))
            for k in range(n_pts + 1):
                loc, n = hit(tree, (side * 1.5, 0.98, z0 + (z1 - z0) * k / n_pts), (-side, 0, 0))
                if loc is not None:
                    pts.append(loc + n * 0.006)
            if len(pts) > 2:
                trim.tube(pts, 0.014, segs=6, round_ends=True)
    trim.build()


def van_door(M, coll):
    """Schiebetür (geschlossen, in Wagen-Koordinaten): unten Wagenfarbe, oben creme mit Fenster."""
    x = VAN["hw"] + 0.016
    low = Body("Tür unten", M["paint"], coll, seed=60, vary=0.0, bevel=0.012)
    low.box(tuple(g(x, 0.7, 0.46)), (0.026, 0.86, 0.7), step=1, dent=0.0)
    low.build()
    up = Body("Tür oben", M["paint2"], coll, seed=61, vary=0.0, bevel=0.01)
    # Größen in Blender-Achsen: (quer, entlang des Wagens, Höhe)
    for c, s in (((x, 1.08, 0.46), (0.028, 0.86, 0.08)), ((x, 1.86, 0.46), (0.028, 0.86, 0.08)),
                 ((x, 1.47, 0.065), (0.028, 0.07, 0.72)), ((x, 1.47, 0.855), (0.028, 0.07, 0.72))):
        up.box(tuple(g(*c)), s, step=1, dent=0.0)
    up.build()
    gl = Body("Tür Scheibe", M["car_glass"], coll, seed=62)
    gl.box(tuple(g(x, 1.47, 0.46)), (0.008, 0.76, 0.74), step=1, dent=0.0)
    gl.build()
    ch = Body("Tür Griff", M["chrome"], coll, seed=63)
    ch.tube([g(x + 0.018, 0.93, 0.8), g(x + 0.018, 0.93, 0.66)], 0.012, segs=6, round_ends=True)
    ch.build()


def car_wheel(M, coll, radius, width, rim):
    """Rad: dicker, weicher Reifen und gewölbte Radkappe; Achse x, Außenseite +x."""
    r, w = radius, width
    tyre = Body("Reifen", M["tyre"], coll, seed=70, vary=0.0)
    tyre.lathe([(0.0, -w / 2), (r - 0.05, -w / 2), (r - 0.015, -w / 2 + 0.012), (r, -w / 2 + 0.045), (r, w / 2 - 0.045),
                (r - 0.015, w / 2 - 0.012), (r - 0.05, w / 2), (0.0, w / 2)], (0, 0, 0), segs=36, turn=(0, 90))
    tyre.build(smooth_angle=60)
    cap = Body("Radkappe", M[rim], coll, seed=71, vary=0.0)
    cap.lathe([(0.0, w / 2 - 0.02), (r * 0.64, w / 2 - 0.02), (r * 0.63, w / 2 + 0.004), (r * 0.5, w / 2 + 0.016),
               (r * 0.2, w / 2 + 0.03), (0.0, w / 2 + 0.034)], (0, 0, 0), segs=32, turn=(0, 90))
    cap.lathe([(0.0, -w / 2 - 0.012), (r * 0.3, -w / 2 - 0.012), (r * 0.3, -w / 2 + 0.02), (0.0, -w / 2 + 0.02)], (0, 0, 0), segs=16,
              turn=(0, 90))
    cap.build(smooth_angle=60)
    nut = Body("Radmuttern", M["chrome"], coll, seed=72, vary=0.0)
    for k in range(5):
        a = 2 * math.pi * k / 5
        c = Vector((w / 2 + 0.012, math.cos(a) * r * 0.36, math.sin(a) * r * 0.36))
        nut.lathe([(0.0, 0.0), (0.014, 0.0), (0.014, 0.012), (0.0, 0.016)], tuple(c), segs=8, turn=(0, 90))
    nut.build()


# --- Fahrrad (Maße wie chibi_ride.py / ChibiCyclistModel) -------------------------------------------

BIKE_R = 0.34
BIKE_WZ = 0.52
CRANK = (0.36, 0.02)       # Tretlager (y, z)
SEAT_TOP = (0.66, -0.222)  # oberes Ende des Sitzrohrs (Sattelstütze darin, Sattel bei y ≈ 0,75)
BARS = (1.06, 0.3)
GRIP = (0.28, 1.08, 0.10)
CRANK_ARM = 0.13


def bike_frame(M, coll):
    """Hollandrad mit tiefem Einstieg: alle Rohre rund, Schutzbleche, Kettenschutz, Gepäckträger,
    Lampe, Klingel, Lenker mit Ledergriffen (Räder, Kurbel, Sattel und Korb sind eigene Teile)."""
    paint, chrome = M["bike_paint"], M["chrome"]
    fr = Body("Rahmen", paint, coll, seed=80, vary=0.0)
    cy, cz = CRANK
    head_top, head_bot = g(0, 0.9, 0.33), g(0, 0.7, 0.37)
    c = g(0, cy, cz)
    fr.tube([head_bot - (head_top - head_bot) * 0.15, head_top + (head_top - head_bot) * 0.12], 0.027, segs=12, round_ends=True)
    fr.tube([head_bot, g(0, 0.6, 0.31), g(0, 0.48, 0.15), g(0, 0.39, 0.06), c], 0.024, segs=12, smooth=2, round_ends=True)
    seat_pts = [c, g(0, 0.52, -0.15), g(0, 0.6, -0.212), g(0, SEAT_TOP[0], SEAT_TOP[1])]
    fr.tube(seat_pts, 0.021, segs=12, smooth=2, round_ends=True)
    fr.tube([g(0, SEAT_TOP[0] - 0.05, SEAT_TOP[1] + 0.002), g(0, SEAT_TOP[0] + 0.01, SEAT_TOP[1])], 0.027, segs=12, round_ends=True)
    fr.tube([g(0, 0.84, 0.345), g(0, 0.7, 0.2), g(0, 0.58, 0.0), g(0, 0.53, -0.14)], 0.019, segs=10, smooth=2, round_ends=True)
    for sd in (-1, 1):
        r = g(sd * 0.056, BIKE_R, -BIKE_WZ)
        fr.tube([g(sd * 0.03, cy, cz - 0.02), r], 0.012, segs=8, round_ends=True)
        fr.tube([g(sd * 0.02, 0.57, -0.19), r], 0.011, segs=8, round_ends=True)
        fr.tube([head_bot + Vector((sd * 0.02, 0, 0)), g(sd * 0.047, 0.58, 0.43), g(sd * 0.052, BIKE_R, BIKE_WZ)], 0.012, segs=8, smooth=2,
                round_ends=True)
    # Schutzbleche (breite, flache Röhren) über beiden Rädern
    for wz, a0, a1 in ((BIKE_WZ, -15, 165), (-BIKE_WZ, 20, 200)):
        pts = [g(0, BIKE_R + math.sin(math.radians(a)) * (BIKE_R + 0.034), wz + math.cos(math.radians(a)) * (BIKE_R + 0.034))
               for a in range(a0, a1 + 1, 10)]
        fr.tube(pts, 0.024, segs=10, round_ends=True)
    # Kettenschutz
    fr.tube([g(0.06, cy + 0.04, cz + 0.06), g(0.06, BIKE_R + 0.01, -BIKE_WZ + 0.06)], 0.034, segs=12, round_ends=True)
    fr.build(smooth_angle=60)
    ch = Body("Chrom", chrome, coll, seed=81, vary=0.0)
    stem = g(0, BARS[0], BARS[1])
    ch.tube([head_top, stem], 0.015, segs=8, round_ends=True)
    for sd in (-1, 1):
        ch.tube([stem, g(sd * 0.12, BARS[0] + 0.02, BARS[1] - 0.01), g(sd * 0.24, GRIP[1] + 0.01, 0.2), g(sd * GRIP[0], GRIP[1], 0.14)],
                0.011, segs=8, smooth=2, round_ends=True)
    # Gepäckträger hinten
    ry = BIKE_R * 2 + 0.085
    for sd in (-1, 1):
        ch.tube([g(sd * 0.075, ry, -0.36), g(sd * 0.075, ry, -0.8)], 0.007, segs=6, round_ends=True)
        ch.tube([g(sd * 0.06, BIKE_R, -BIKE_WZ), g(sd * 0.075, ry, -0.78)], 0.007, segs=6, round_ends=True)
        ch.tube([g(sd * 0.075, ry, -0.38), g(sd * 0.03, 0.6, -0.2)], 0.006, segs=6, round_ends=True)
    for z in (-0.42, -0.58, -0.74):
        ch.tube([g(-0.075, ry, z), g(0.075, ry, z)], 0.006, segs=6, round_ends=True)
    # Klingel und Lampe
    ch.lathe([(0.0, 0.0), (0.026, 0.004), (0.028, 0.018), (0.0, 0.028)], tuple(g(0.09, BARS[0] + 0.02, BARS[1] - 0.02)), segs=12)
    lamp = g(0, 0.76, 0.44)
    lathe_on(ch, [(0.0, -0.035), (0.036, -0.03), (0.042, 0.02), (0.038, 0.03), (0.0, 0.03)], lamp, g(0, 0, 1) - g(0, 0, 0), segs=14)
    ch.tube([g(0, 0.73, 0.39), lamp], 0.008, segs=6, round_ends=True)
    ch.build()
    lens = Body("Lampe", M["head"], coll, seed=82)
    lathe_on(lens, [(0.0, 0.0), (0.033, 0.0), (0.03, 0.012), (0.0, 0.016)], lamp + (g(0, 0, 1) - g(0, 0, 0)) * 0.026, g(0, 0, 1) - g(0, 0, 0),
             segs=14)
    lens.build()
    grip = Body("Griffe", M["saddle"], coll, seed=83)
    for sd in (-1, 1):
        grip.tube([g(sd * GRIP[0], GRIP[1], 0.15), g(sd * GRIP[0], GRIP[1], 0.05)], 0.018, segs=10, round_ends=True)
    grip.build()
    tail = Body("Rücklicht", M["tail"], coll, seed=84, bevel=0.004)
    tail.box(tuple(g(0, ry - 0.025, -0.82)), (0.08, 0.025, 0.035), step=1, dent=0.0)
    tail.build()


def bike_saddle(M, coll):
    """Ledersattel mit Federn auf der Stütze; Ursprung = Sitzpunkt (Oberkante Sattel)."""
    s = Body("Sattel", M["saddle"], coll, seed=85, vary=0.0)
    s.blob(tuple(g(0, -0.032, -0.012)), 0.1, subdiv=3, lump=0.0, scale=(0.82, 0.95, 0.33))
    s.blob(tuple(g(0, -0.026, 0.07)), 0.05, subdiv=2, lump=0.0, scale=(0.75, 1.2, 0.5))
    s.build(smooth_angle=180)
    ch = Body("Stütze", M["chrome"], coll, seed=86, vary=0.0)
    ch.tube([g(0, -0.05, 0.0), g(0, -0.2, 0.0)], 0.0125, segs=10, round_ends=True)
    for sd in (-1, 1):
        coil = [g(sd * 0.045 * (1 - k / 12), -0.07 + k * 0.0035, -0.07 + k * 0.0055 + 0.004 * math.sin(k * 2.3)) for k in range(13)]
        ch.tube(coil, 0.005, segs=5, round_ends=True)
    ch.tube([g(-0.05, -0.068, -0.07), g(0.05, -0.068, -0.07)], 0.006, segs=6, round_ends=True)
    ch.build()


def bike_crank(M, coll):
    """Kettenblatt, Kurbeln und Pedale um das Tretlager (Ursprung); die linke Kurbel (x < 0) zeigt
    bei Winkel 0 nach vorn."""
    ch = Body("Kurbel", M["chrome"], coll, seed=87, vary=0.0)
    ch.lathe([(0.0, -0.005), (0.092, -0.005), (0.1, 0.0), (0.092, 0.005), (0.0, 0.005)], (0.04, 0, 0), segs=32, turn=(0, 90))
    ch.tube([g(-0.08, 0, 0), g(0.08, 0, 0)], 0.013, segs=8, round_ends=True)
    for side, ang in ((-1, 0.0), (1, math.pi)):
        end = g(side * 0.075, math.sin(ang) * CRANK_ARM, math.cos(ang) * CRANK_ARM)
        ch.tube([g(side * 0.075, 0, 0), end], 0.012, segs=8, round_ends=True)
    ch.build()
    ped = Body("Pedale", M["rubber"], coll, seed=88, vary=0.0, bevel=0.008)
    for side, ang in ((-1, 0.0), (1, math.pi)):
        ped.box(tuple(g(side * 0.1275, math.sin(ang) * CRANK_ARM, math.cos(ang) * CRANK_ARM)), (0.09, 0.07, 0.024), step=1, dent=0.0)
    ped.build()


def bike_wheel(M, coll):
    """Speichenrad: Reifen und Felge als Ringe ohne Fuge, Nabe, gekreuzte Speichen; Achse x."""
    tyre = Body("Reifen", M["tyre"], coll, seed=89, vary=0.0)
    T.loop_tube(tyre, [Vector((0, math.cos(a) * (BIKE_R - 0.021), math.sin(a) * (BIKE_R - 0.021))) for a in
                       [2 * math.pi * k / 48 for k in range(48)]], 0.021, segs=10, axis=(1, 0, 0))
    tyre.build(smooth_angle=180)
    ch = Body("Felge", M["chrome"], coll, seed=90, vary=0.0)
    T.loop_tube(ch, [Vector((0, math.cos(a) * (BIKE_R - 0.047), math.sin(a) * (BIKE_R - 0.047))) for a in
                     [2 * math.pi * k / 40 for k in range(40)]], 0.008, segs=6, axis=(1, 0, 0))
    ch.lathe([(0.0, -0.045), (0.015, -0.045), (0.022, -0.03), (0.013, 0.0), (0.022, 0.03), (0.015, 0.045), (0.0, 0.045)], (0, 0, 0), segs=14,
             turn=(0, 90))
    n = 24
    for k in range(n):
        side = 0.028 if k % 2 else -0.028
        a = 2 * math.pi * k / n
        a2 = a + (0.3 if k % 4 < 2 else -0.3)
        ch.tube([Vector((side, math.cos(a2) * 0.02, math.sin(a2) * 0.02)), Vector((0, math.cos(a) * (BIKE_R - 0.05), math.sin(a) * (BIKE_R - 0.05)))],
                0.0018, segs=4)
    ch.build()


def bike_basket(M, coll):
    """Geflochtener Korb vorn auf einem Träger (Streben zur Vorderachse)."""
    C = {"deco": coll}
    T.round_basket(M, C, "Korb", tuple(g(0, 0.83, 0.585)), 0.13, 0.16, 0.18, seed=91, stakes=18)
    ch = Body("Korbträger", M["chrome"], coll, seed=92, vary=0.0)
    base = g(0, 0.825, 0.585)
    T.loop_tube(ch, [base + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.0)) for a in [2 * math.pi * k / 24 for k in range(24)]], 0.006,
                segs=6)
    for sd in (-1, 1):
        ch.tube([g(sd * 0.055, BIKE_R, BIKE_WZ), g(sd * 0.08, 0.82, 0.62)], 0.006, segs=6, round_ends=True)
    ch.tube([g(0, 0.8, 0.39), g(0, 0.815, 0.47)], 0.007, segs=6, round_ends=True)
    ch.build()


# --- Export -------------------------------------------------------------------------------------------

def export(name, coll):
    objs = [o for o in coll.all_objects if o.type == "MESH"]
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    path = os.path.join(OUT, name + ".glb")
    tris, n = SC.export_objects(objs, [], path, palette=True, extra=[])
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, path)
    print("Spiel: %s (%d Dreiecke, %d Netze), offene Kanten: %s" % (path, tris, n, bad if bad else "keine"))


def tune_glass():
    """Autoglas etwas sichtbarer als Fensterglas (sonst wirken die Scheiben wie Löcher)."""
    path = os.path.join(SC.GAME_MAT_DIR, SC.slug("Autoglas") + ".tres")
    if os.path.exists(path):
        text = open(path).read().replace(", 0.06)", ", 0.16)")
        with open(path, "w") as f:
            f.write(text)


def isolate(colls):
    """Nur diese Sammlungen im Kontrollbild (die übrigen Fahrzeuge stehen am selben Platz)."""
    keep = {o for c in colls for o in c.all_objects}
    hidden = [o for o in bpy.data.objects if o.type == "MESH" and o not in keep and not o.hide_render and o.name != "Boden"]
    for o in hidden:
        o.hide_render = True
    return hidden


def render_views(name, length, height):
    SC.setup_render(True)
    floor = bpy.data.meshes.new("Boden")
    floor.from_pydata([(-12, -12, 0), (12, -12, 0), (12, 12, 0), (-12, 12, 0)], [], [(0, 1, 2, 3)])
    fo = bpy.data.objects.new("Boden", floor)
    fo.data.materials.append(SC.make_material("Boden grau", (0.55, 0.53, 0.5), grain="stone"))
    bpy.context.scene.collection.objects.link(fo)
    L = length
    SC.render(name + "_vorn", tuple(g(2.6, 1.5, L * 1.05)), tuple(g(0, height * 0.45, 0)), 40, (900, 650))
    SC.render(name + "_seite", tuple(g(-5.2, 1.1, 0.0)), tuple(g(0, height * 0.45, 0)), 40, (900, 650))
    SC.render(name + "_hinten", tuple(g(-2.4, 1.7, -L * 1.0)), tuple(g(0, height * 0.45, 0)), 40, (900, 650))
    bpy.data.objects.remove(fo)


def build_one(name, M, root, argv):
    if name in CARS:
        coll = SB.collection(name, root)
        sp = CARS[name]
        tree = build_car(M, coll, sp)
        {"taxi": taxi_extras, "traveller": traveller_extras, "delivery_van": van_extras}.get(name, lambda *a: None)(M, coll, tree)
        wcoll = SB.collection(name + "_wheel", root)
        r, w, rim = WHEELS[name]
        car_wheel(M, wcoll, r, w, rim)
        if "--no-export" not in argv:
            export(name, coll)
            export(name + "_wheel", wcoll)
        if name == "delivery_van":
            dcoll = SB.collection("delivery_van_door", root)
            van_door(M, dcoll)
            if "--no-export" not in argv:
                export("delivery_van_door", dcoll)
        if "--render" in argv:
            # Räder für das Kontrollbild an ihre Plätze
            tmp = []
            for wz in sp["wheels"]:
                for side in (-1, 1):
                    for o in wcoll.objects:
                        c = o.copy()
                        c.data = o.data
                        c.matrix_world = Matrix.Translation(g(side * (sp["hw"] - 0.13), r, wz)) @ \
                            (Matrix.Rotation(math.pi, 4, "Z") if side < 0 else Matrix.Identity(4))
                        coll.objects.link(c)
                        tmp.append(c)
            for o in wcoll.objects:
                o.hide_render = True
            shown = [coll] + ([SB.collection("delivery_van_door", root)] if name == "delivery_van" else [])
            hidden = isolate(shown)
            render_views(name, sp["rings"][-1][0] * 2, sp["roof"])
            for o in hidden:
                o.hide_render = False
            for c in tmp:
                bpy.data.objects.remove(c)
            for o in wcoll.objects:
                o.hide_render = False
    elif name == "bicycle":
        parts = {"bicycle_chibi": bike_frame, "bicycle_chibi_saddle": bike_saddle, "bicycle_chibi_crank": bike_crank,
                 "bicycle_wheel": bike_wheel, "bicycle_chibi_basket": bike_basket}
        colls = {}
        for part_name, fn in parts.items():
            colls[part_name] = SB.collection(part_name, root)
            fn(M, colls[part_name])
            if "--no-export" not in argv:
                export(part_name, colls[part_name])
        if "--render" in argv:
            tmp = []

            def place(cname, m):
                for o in colls[cname].all_objects:
                    if o.type == "MESH":
                        c = o.copy()
                        c.data = o.data
                        c.matrix_world = m @ o.matrix_world
                        colls["bicycle_chibi"].objects.link(c)
                        tmp.append(c)
            place("bicycle_chibi_saddle", Matrix.Translation(g(0, 0.75, -0.22)))
            place("bicycle_chibi_crank", Matrix.Translation(g(0, CRANK[0], CRANK[1])))
            place("bicycle_wheel", Matrix.Translation(g(0, BIKE_R, BIKE_WZ)))
            place("bicycle_wheel", Matrix.Translation(g(0, BIKE_R, -BIKE_WZ)))
            for cname in ("bicycle_chibi_saddle", "bicycle_chibi_crank", "bicycle_wheel"):
                for o in colls[cname].all_objects:
                    o.hide_render = True
            hidden = isolate([colls["bicycle_chibi"], colls["bicycle_chibi_basket"]])
            SC.setup_render(True)
            SC.render("fahrrad_seite", tuple(g(-2.6, 0.8, 0.0)), tuple(g(0, 0.6, 0)), 40, (900, 650))
            SC.render("fahrrad_vorn", tuple(g(1.4, 1.3, 1.6)), tuple(g(0, 0.65, 0)), 40, (900, 650))
            for c in tmp:
                bpy.data.objects.remove(c)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if SC.edited_by_hand(BLEND, STAMP) and "--force" not in argv:
        print("storybook_vehicles.blend wurde in Blender bearbeitet – nichts überschrieben (--force baut neu).")
        return
    names = [a for a in argv if not a.startswith("--")] or list(CARS) + ["bicycle"]
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = materials()
    root = SB.collection("Fahrzeuge (Bilderbuch)")
    for name in names:
        build_one(name, M, root, argv)
    tune_glass()
    if "--no-export" not in argv and not [a for a in argv if not a.startswith("--")]:
        os.makedirs(os.path.dirname(BLEND), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
        with open(STAMP, "w") as f:
            f.write(SC.blend_fingerprint(BLEND) + "\n")


if __name__ == "__main__":
    main()
