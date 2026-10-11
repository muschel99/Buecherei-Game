"""Prüft fertige Modelle auf schwebende Teile und Pflanzen, die in festen Teilen stecken
(seit Etappe 4g, Teil 4f). Ohne Bilder – Ergebnis als Liste im Terminal.

Aufruf (Terminal, im Projektordner):
    blender -b --factory-startup --python tools/blender/geo_check.py
    blender -b --factory-startup --python tools/blender/geo_check.py -- assets/models/houses/street/Opposite_Opposite1_4.glb

Was geprüft wird (je .glb, in den Koordinaten des Modells, Boden = Höhe 0):
  1. Schwebende Teile: Ein Teil = zusammenhängende Flächen. Teile, die sich berühren (Abstand
     unter TOUCH), hängen zusammen. Jede Gruppe muss den Boden berühren oder am größten Teil
     (dem Haus) hängen – sonst schwebt sie.
  2. Durchdringungen: Blätter und Blüten (Material "plant"), die Flächen fester Teile schneiden
     (Wände, Töpfe, Kästen, Zäune). Erde, Wasser, Stängel und Rinde zählen nicht als fest.
Gemeldet wird je Fund die Lage (Mitte) und die Größe – nah beieinander liegende Funde werden
zusammengefasst.

Mit --source baut das Script die Modelle direkt aus den Bau-Scripts (ohne zu speichern) und
nennt zu jedem Fund die Programmzeile, die das Teil gebaut hat:
    blender -b --factory-startup --python tools/blender/geo_check.py -- --source Opposite/Opposite1_4 fashion_shop
Namen: Häuser wie in houses.tscn (Gruppe/Name), Haustypen (fashion_shop, terrace_45 …),
alley_library, alley_opposite, library, Requisiten (street_lamp …); ohne Namen alle.
"""

import bpy  # noqa: F401  (Blender-Python wird für mathutils gebraucht)
import glob
import json
import math
import os
import struct
import sys
from collections import defaultdict

from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(__file__))
import style_lib as S  # noqa: E402
import style_plants as PL  # noqa: E402

TOUCH = 0.012
# Farben (linear) von Teilen, in die Pflanzen hineinwachsen dürfen
SOFT_COLORS = [S.srgb_to_linear(m.color) for m in (PL.STEM_GREEN, PL.STEM_BROWN, PL.IVY_STEM, PL.SOIL, PL.CHAIN)] + \
    [S.srgb_to_linear(c) for c in ((0.22, 0.27, 0.28), (0.45, 0.5, 0.38), (0.45, 0.55, 0.35), (0.62, 0.5, 0.36), (0.6, 0.52, 0.38),
                                   (0.48, 0.48, 0.36), (0.7, 0.64, 0.52))]


def read_glb(path):
    """Dreiecke je Material: {name: [(p0, p1, p2, farbe, ebene), …]} (nur Sichtbares)."""
    with open(path, "rb") as f:
        data = f.read()
    length_json = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length_json])
    binary = data[20 + length_json + 8:]

    def accessor(index):
        acc = doc["accessors"][index]
        view = doc["bufferViews"][acc["bufferView"]]
        size = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
        fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[acc["componentType"]]
        count = acc["count"]
        values = struct.unpack_from("<%d%s" % (count * size, fmt), binary, view.get("byteOffset", 0))
        if acc.get("normalized") and fmt == "B":
            values = [v / 255.0 for v in values]
        return [values[i * size:(i + 1) * size] for i in range(count)] if size > 1 else list(values)

    out = defaultdict(list)
    for node in doc["nodes"]:
        if node["name"].endswith("-colonly") or "mesh" not in node:
            continue
        for prim in doc["meshes"][node["mesh"]]["primitives"]:
            mat = doc["materials"][prim["material"]]["name"] if "material" in prim else "none"
            pos = accessor(prim["attributes"]["POSITION"])
            col = accessor(prim["attributes"]["COLOR_0"]) if "COLOR_0" in prim["attributes"] else None
            uv2 = accessor(prim["attributes"]["TEXCOORD_1"]) if "TEXCOORD_1" in prim["attributes"] else None
            idx = accessor(prim["indices"])
            for t in range(0, len(idx), 3):
                a, b, c = idx[t], idx[t + 1], idx[t + 2]
                out[mat].append((Vector(pos[a]), Vector(pos[b]), Vector(pos[c]), col[a][:3] if col else (1, 1, 1),
                                 int(round(uv2[a][0])) if uv2 else -1, 1.0 - col[a][3] if col else 0.0))
    return out


def components(tris):
    """Zusammenhängende Teile (gemeinsame Ecken, auf 0,5 mm gerundet). Liefert je Dreieck die
    Nummer seines Teils."""
    parent = list(range(len(tris)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    seen = {}
    for i, tri in enumerate(tris):
        for p in tri[:3]:
            key = (round(p.x / 0.0005), round(p.y / 0.0005), round(p.z / 0.0005))
            j = seen.setdefault(key, i)
            if j != i:
                ri, rj = find(i), find(j)
                if ri != rj:
                    parent[ri] = rj
    return [find(i) for i in range(len(tris))]


def _cluster(points, cell=0.3):
    """Funde nach Lage zusammenfassen: (Mitte, Anzahl)."""
    groups = defaultdict(list)
    for p in points:
        groups[(round(p.x / cell), round(p.y / cell), round(p.z / cell))].append(p)
    out = []
    for pts in groups.values():
        c = sum(pts, Vector()) / len(pts)
        out.append((c, len(pts)))
    return sorted(out, key=lambda e: -e[1])


def check(path, report_limit=12):
    by_mat = read_glb(path)
    tris = []
    kinds = []
    for mat, lst in by_mat.items():
        for tri in lst:
            tris.append(tri[:5] + (None, tri[5]))
            kinds.append("glass" if mat.startswith("glass") else "plant" if mat == "plant" else "solid")
    return analyse(os.path.relpath(path, S.ROOT), tris, kinds, report_limit)


def analyse(name, tris, kinds, report_limit=12):
    """tris: (p0, p1, p2, Farbe linear, Ebene, Herkunft oder None, Leuchten), kinds: "plant"/"solid"/"glass".
    Glas hält Dinge (zählt als Berührung), wird selbst aber nicht als schwebend gemeldet. Große
    leuchtende Kästen (Zimmer hinter Fenstern, die Hauswand hat dort keine Dicke) ebenfalls nicht."""
    if not tris:
        return ["%s: leer" % name]
    comp = components(tris)
    verts = []
    polys = []
    for i, tri in enumerate(tris):
        base = len(verts)
        verts.extend(tri[:3])
        polys.append((base, base + 1, base + 2))
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=True)
    # 1) Schwebende Teile: Berührungen zwischen Teilen sammeln
    members = defaultdict(list)
    for i, c in enumerate(comp):
        members[c].append(i)
    link = {c: c for c in members}

    def find(c):
        while link[c] != c:
            link[c] = link[link[c]]
            c = link[c]
        return c

    grounded = set()
    for c, idxs in members.items():
        pts = {}
        for i in idxs:
            tri = tris[i]
            for k in range(3):
                p, q = tri[k], tri[(k + 1) % 3]
                pts[(round(p.x, 3), round(p.y, 3), round(p.z, 3))] = p
                steps = min(40, int((q - p).length / 0.05))
                for j in range(1, steps):
                    m = p.lerp(q, j / steps)
                    pts[(round(m.x, 3), round(m.y, 3), round(m.z, 3))] = m
        if min(p.y for p in pts.values()) < 0.004:
            grounded.add(c)
        # Ecken prüfen (bei großen Teilen eine Auswahl)
        sample = list(pts.values())
        if len(sample) > 400:
            step = len(sample) / 400
            sample = [sample[int(k * step)] for k in range(400)]
        for p in sample:
            for hit in tree.find_nearest_range(p, TOUCH):
                other = comp[hit[2]]
                if other != c:
                    ra, rb = find(c), find(other)
                    if ra != rb:
                        link[ra] = rb
    # Teile, die sich durchdringen, hängen auch zusammen
    for a, b2 in tree.overlap(tree):
        ca, cb = comp[a], comp[b2]
        if ca != cb:
            ra, rb = find(ca), find(cb)
            if ra != rb:
                link[ra] = rb
    roots = defaultdict(list)
    for c in members:
        roots[find(c)].append(c)
    biggest = max(roots, key=lambda r: sum(len(members[c]) for c in roots[r]))
    floating = []
    for r, cs in roots.items():
        if r == biggest or any(c in grounded for c in cs):
            continue
        idxs = [i for c in cs for i in members[c]]
        if all(kinds[i] == "glass" for i in idxs):
            continue
        pts = [p for i in idxs for p in tris[i][:3]]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        if max(hi - lo) > 0.6:
            # Fläche, die leuchtet (Zimmer hinter Fenstern, deren Inhalt) – nach Fläche gewichtet
            area = [((tris[i][1] - tris[i][0]).cross(tris[i][2] - tris[i][0])).length / 2 for i in idxs]
            lit = sum(a for a, i in zip(area, idxs) if tris[i][6] > 0.0 or kinds[i] == "glass")
            if lit >= 0.85 * sum(area):
                continue
        origins = sorted({tris[i][5] for i in idxs if tris[i][5]})
        floating.append(((lo + hi) / 2, hi - lo, len(idxs), "plant" if kinds[idxs[0]] == "plant" else "solid", origins))
    # 2) Pflanzen in festen Teilen: Schnitte Blatt/Blüte gegen feste Flächen
    solid_idx = [i for i, k in enumerate(kinds) if k == "solid" and not _soft(tris[i][3]) and tris[i][4] != FOLIAGE]
    plant_idx = [i for i, k in enumerate(kinds) if k == "plant" and tris[i][4] != PL_BARK]
    hits = []
    if solid_idx and plant_idx:
        solid = BVHTree.FromPolygons([p for i in solid_idx for p in tris[i][:3]], [(3 * k, 3 * k + 1, 3 * k + 2) for k in range(len(solid_idx))],
                                     all_triangles=True)
        plant = BVHTree.FromPolygons([p for i in plant_idx for p in tris[i][:3]], [(3 * k, 3 * k + 1, 3 * k + 2) for k in range(len(plant_idx))],
                                     all_triangles=True)
        for a, c in plant.overlap(solid):
            tri = tris[plant_idx[a]]
            hits.append(((tri[0] + tri[1] + tri[2]) / 3, tri[5], tris[solid_idx[c]][5]))
    lines = []
    if floating:
        lines.append("%s: %d schwebende Teile" % (name, len(floating)))
        for center, size, count, kind, origins in sorted(floating, key=lambda e: -e[2])[:report_limit]:
            lines.append("    schwebt (%s, %d Dreiecke) bei (%.2f, %.2f, %.2f), Größe %.2f x %.2f x %.2f%s" % (
                kind, count, center.x, center.y, center.z, size.x, size.y, size.z, ("  <- " + ", ".join(origins[:3])) if origins else ""))
    if hits:
        clusters = _cluster([h[0] for h in hits])
        lines.append("%s: %d Blatt-Dreiecke in festen Teilen (%d Stellen)" % (name, len(hits), len(clusters)))
        for c, count in clusters[:report_limit]:
            near = [h for h in hits if (h[0] - c).length < 0.25]
            src = sorted({"%s in %s" % (h[1], h[2]) for h in near if h[1]})
            lines.append("    steckt (%d) bei (%.2f, %.2f, %.2f)%s" % (count, c.x, c.y, c.z, ("  <- " + "; ".join(src[:2])) if src else ""))
    if not lines:
        lines.append("%s: in Ordnung" % name)
    return lines


PL_BARK = S.PLANT_LAYERS["bark"]["index"]
# Laub-Ebene der Häuser: Kern von Buchskugeln, Blütenbällen und Rosen (liegt absichtlich in den Blättern)
FOLIAGE = S.LAYERS["foliage"]["index"]


def _soft(color):
    return any(abs(color[0] - c[0]) < 0.004 and abs(color[1] - c[1]) < 0.004 and abs(color[2] - c[2]) < 0.004 for c in SOFT_COLORS)


def _origin():
    """Programmzeile außerhalb von style_lib/style_plants, die gerade baut (Datei:Zeile Funktion)."""
    f = sys._getframe(2)
    while f and os.path.basename(f.f_code.co_filename) in ("style_lib.py", "style_plants.py", "geo_check.py"):
        f = f.f_back
    if not f:
        return "?"
    return "%s:%d %s" % (os.path.basename(f.f_code.co_filename), f.f_lineno, f.f_code.co_name)


def from_builder(b):
    """Dreiecke eines Builders (mit Herkunft, siehe source_mode)."""
    tris, kinds = [], []
    b.finish()
    for face in b.faces:
        mat = face["mat"]
        info = S.layer_info(mat)
        color = S.srgb_to_linear(mat.color) if mat.role == "fixed" else (1.0, 1.0, 1.0)
        pts = face["pts"]
        for i in range(1, len(pts) - 1):
            tris.append((pts[0], pts[i], pts[i + 1], color, info["index"], face.get("origin"), mat.glow))
            kinds.append("glass" if mat.glass else "plant" if mat.plant else "solid")
    return tris, kinds


def source_mode(names):
    """Modelle aus den Bau-Scripts bauen (nichts wird gespeichert) und mit Herkunft prüfen."""
    original = S.Builder.poly

    def poly(self, pts, mat, *args, **kwargs):
        start = len(self.faces)
        original(self, pts, mat, *args, **kwargs)
        where = _origin()
        for face in self.faces[start:]:
            face["origin"] = where
    S.Builder.poly = poly
    import build_street as BS
    import build_houses as BH
    import street_houses as H
    text, houses = BS.read_houses()
    specs = {h["key"]: BS.make_spec(h, BS.house_block(text, h)) for h in houses if h["type"] in BS.STREET_TYPES}
    for key, sides in BS.exposures(houses, text, specs).items():
        specs[key]["exposed"] = sides
    for h in houses:
        if h["type"] in BS.LANDMARK_TYPES:
            specs[h["key"]] = BS.landmark_spec(h, BS.house_block(text, h))
    builders = {}
    for key, spec in specs.items():
        kind = spec.get("kind")
        builders[key] = (lambda k=key, sp=spec, kd=kind: H.build_corner(k, sp) if kd == "corner" else
                         H.build_gatehouse(k, sp) if kd == "gate" else H.build_house(k, sp))
    for type_id in BH.HOUSES:
        builders[type_id] = (lambda t=type_id: _type_builder(BH, t))
    import build_alleys as BA
    import build_library as BL
    import build_props as BP
    builders["alley_library"] = BA.library_alley
    builders["alley_opposite"] = BA.opposite_alley
    builders["library"] = BL.build
    for prop in BP.PROPS:
        builders[prop] = BP.PROPS[prop]
    for name in names or list(builders):
        if name not in builders:
            print("%s: unbekannt" % name)
            continue
        b = builders[name]()
        tris, kinds = from_builder(b)
        print("\n".join(analyse(name, tris, kinds, report_limit=40)))


def _type_builder(BH, type_id):
    out = BH.HOUSES[type_id][0]()
    return out[0] if isinstance(out, tuple) else out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--source" in argv:
        source_mode([a for a in argv if not a.startswith("--")])
        return
    paths = [os.path.join(S.ROOT, a) for a in argv if not a.startswith("--")]
    if not paths:
        for pattern in ("assets/models/houses/*.glb", "assets/models/houses/street/*.glb", "assets/models/world/*.glb",
                        "assets/models/props/*.glb"):
            paths += sorted(glob.glob(os.path.join(S.ROOT, pattern)))
    problems = 0
    for path in paths:
        lines = check(path)
        problems += 0 if lines[-1].endswith("in Ordnung") and len(lines) == 1 else 1
        print("\n".join(lines))
    print("Fertig: %d Modelle, %d mit Funden" % (len(paths), problems))


if __name__ == "__main__":
    main()
