#!/usr/bin/env python3
"""Draufsicht-Prüfung der Häuser (seit Etappe 4f) – für Claude im Browser-Container.

Liest scenes/world/houses.tscn und die Haustypen in scenes/world/houses/ und rechnet in der
Draufsicht (x, z wie im Spiel). Rechtecke für normale Häuser, der Grundriss mit Abschrägung für
Eckhäuser, beim Torhaus nur die beiden Pfeiler (die Durchfahrt ist offen).

  python3 tools/plan_check.py plan    Hausumrisse zeichnen -> screenshots/plan.png
  python3 tools/plan_check.py bound   Sichtstrahlen von der Grenze am geraden Ende
  python3 tools/plan_check.py gate    Anteil der Torhaus-Front, den man von der Ladentür sieht
  python3 tools/plan_check.py unseen  Häuser, die man von keiner erreichbaren Stelle aus sieht,
                                      und Blicke ins Leere (erreichbar = zu Fuß vom Platz aus)
Hinweis: Maße der Bücherei und Grenze stehen unten fest (wie in StreetLayout / GameConfig);
nach Änderungen dort hier anpassen.
"""
import glob
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
# Grenze am geraden Ende (StreetLayout.straight_bound_x) und Bereich davor
BOUND_X = 20.1
BOUND_SIDE = 1
NEAR_Z, FAR_Z = -4.5, -13.7
# Bücherei, Gasse daneben (Hofmauern, Mauer am Ende mit Haus dahinter) als Hindernisse
LIBRARY = [(-3.2, -2.0828), (-1.0828, -4.2), (3.2, -4.2), (3.2, 4.2), (-3.2, 4.2)]
ALLEY_BLOCKS = [[(-6.3, 8.92), (-2.9, 8.92), (-2.9, 15.0), (-6.3, 15.0)],
                [(-3.2, 4.2), (-2.9, 4.2), (-2.9, 8.92), (-3.2, 8.92)],
                [(-6.3, 5.9), (-6.0, 5.9), (-6.0, 8.92), (-6.3, 8.92)],
                # Kleine Gasse gegenüber (GameConfig.opposite_alley_x/_width/_depth): Mauer am Ende
                # und das Haus dahinter
                [(3.0, -22.3), (5.4, -22.3), (5.4, -22.0), (3.0, -22.0)],
                [(0.3, -31.0), (8.1, -31.0), (8.1, -25.0), (0.3, -25.0)]]
# Ladentür (StreetLayout.door_center) und Richtung nach draußen
DOOR = (-2.1414, -3.1414)
DOOR_OUT = (-0.7071, -0.7071)


def _props():
    props = {}
    for path in glob.glob(ROOT + "scenes/world/houses/*.tscn"):
        text = open(path).read()
        values = {}
        for key in ("width", "depth", "corner_angle", "chamfer_width", "side_length", "passage_width"):
            m = re.search(r"^%s = ([\d.]+)" % key, text, re.M)
            if m:
                values[key] = float(m.group(1))
        values.setdefault("width", 5.0)
        values.setdefault("depth", 8.0)
        props[os.path.basename(path)[:-5]] = values
    return props


def _corner_footprint(p):
    # Wie CornerHouseFacade.footprint()
    w = p["width"] / 2
    depth = p["depth"]
    angle = math.radians(p["corner_angle"])
    cut = p["chamfer_width"] / (2 * math.cos(angle / 2))
    along = (math.cos(angle), -math.sin(angle))
    side = depth if p["corner_angle"] >= 89.9 else p["side_length"]
    end = (w + along[0] * side, along[1] * side)
    points = [(-w, 0), (w - cut, 0), (w + along[0] * cut, along[1] * cut), end]
    if p["corner_angle"] < 89.9:
        back = (-math.sin(angle), -math.cos(angle))
        t = (depth + end[1]) / math.cos(angle)
        points.append((end[0] + back[0] * t, end[1] + back[1] * t))
    points.append((-w, -depth))
    return [points]


def _local_polygons(p):
    if "corner_angle" in p:
        return _corner_footprint(p)
    w, depth = p["width"] / 2, p["depth"]
    if "passage_width" in p:
        a = p["passage_width"] / 2
        return [[(-w, 0), (-a, 0), (-a, -depth), (-w, -depth)], [(a, 0), (w, 0), (w, -depth), (a, -depth)]]
    return [[(-w, 0), (w, 0), (w, -depth), (-w, -depth)]]


def load_houses():
    """Liste von (Name, Gruppe, Typ, Umriss) und die Torhaus-Lage (Ursprung, x-Achse, z-Achse)."""
    props = _props()
    text = open(ROOT + "scenes/world/houses.tscn").read()
    ext = {m.group(2): m.group(1) for m in re.finditer(
        r'\[ext_resource [^\]]*path="res://scenes/world/houses/(\w+)\.tscn" id="([^"]+)"', text)}
    houses, gate = [], None
    for block in re.split(r"\n(?=\[node )", text):
        m = re.match(r'\[node name="(\w+)" parent="(\w+)"[^\]]*instance=ExtResource\("([^"]+)"\)', block)
        if not m:
            continue
        name, group, rid = m.groups()
        kind = ext[rid]
        v = [float(x) for x in re.search(r"transform = Transform3D\(([^)]*)\)", block).group(1).split(",")]
        ax, az, origin = (v[0], v[6]), (v[2], v[8]), (v[9], v[11])  # Spalten der Basis (Zeilen in der Datei)
        if name == "Gatehouse":
            gate = (origin, ax, az, props[kind]["width"])
        for poly in _local_polygons(props[kind]):
            world = [(origin[0] + ax[0] * x + az[0] * z, origin[1] + ax[1] * x + az[1] * z) for x, z in poly]
            houses.append((name, group, kind, world))
    return houses, gate


def _ray_hit(p, d, poly):
    best = None
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        ex, ez = b[0] - a[0], b[1] - a[1]
        den = d[0] * ez - d[1] * ex
        if abs(den) < 1e-9:
            continue
        t = ((a[0] - p[0]) * ez - (a[1] - p[1]) * ex) / den
        u = ((a[0] - p[0]) * d[1] - (a[1] - p[1]) * d[0]) / den
        if t > 1e-6 and 0 <= u <= 1:
            best = t if best is None else min(best, t)
    return best


def cast(houses, p, angle, skip=()):
    """Erstes Haus in Richtung angle (Bogenmaß): (Abstand, Name, Gruppe) oder (None, None, None)."""
    d = (math.cos(angle), math.sin(angle))
    best = (None, None, None)
    for name, group, _, poly in houses:
        if name in skip:
            continue
        h = _ray_hit(p, d, poly)
        if h is not None and (best[0] is None or h < best[0]):
            best = (h, name, group)
    return best


def _inside(p, poly):
    c = False
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]:
            c = not c
    return c


def check_bound(houses):
    """Von 101 Punkten an der Grenze (Fahrbahn und Gehwege) in alle Richtungen nach vorn."""
    x = BOUND_X - BOUND_SIDE * 0.6
    void, end = 0, 0
    for i in range(101):
        z = NEAR_Z + (FAR_Z - NEAR_Z) * i / 100
        for a10 in range(-900, 901, 5):
            angle = math.radians(a10 / 10) + (0 if BOUND_SIDE > 0 else math.pi)
            dist, name, group = cast(houses, (x, z), angle)
            if dist is None:
                void += 1
            elif group == "StraightEnd" and name.startswith("End"):
                end += 1
    print("Grenze: %d Strahlen ins Leere, %d bis ans Ende der Seitenstraße (beides soll 0 sein)" % (void, end))


def check_gate(houses, gate):
    """Anteil der Torhaus-Front (zwischen den Hausfronten), der von der Ladentür aus frei ist."""
    origin, ax, az, width = gate
    for label, step in (("Türmitte", 0.0), ("vor der Tür (0,6 m)", 0.6), ("vorn auf dem Podest", 1.7)):
        eye = (DOOR[0] + DOOR_OUT[0] * step, DOOR[1] + DOOR_OUT[1] * step)
        seen = total = 0
        for k in range(101):
            u = -width / 2 + width * k / 100
            p = (origin[0] + ax[0] * u + az[0] * 0.1, origin[1] + ax[1] * u + az[1] * 0.1)
            if any(_inside(p, poly) for name, _, _, poly in houses if name != "Gatehouse"):
                continue  # dieser Teil steckt hinter den Nachbarhäusern
            total += 1
            dx, dz = p[0] - eye[0], p[1] - eye[1]
            dist, _, _ = cast(houses, eye, math.atan2(dz, dx), skip=("Gatehouse",))
            if dist is None or dist >= math.hypot(dx, dz) - 0.05:
                seen += 1
        print("%s: %d %% der Torhaus-Front sichtbar" % (label, round(100 * seen / max(1, total))))


def _blockers(houses, gate):
    """Alles, wo man nicht hinkommt: Häuser, Bücherei, Gasse, die beiden Grenzen."""
    blocks = [poly for *_, poly in houses] + [LIBRARY] + ALLEY_BLOCKS
    blocks.append([(BOUND_X - 0.3, -3.7), (BOUND_X + 0.3, -3.7), (BOUND_X + 0.3, -14.5), (BOUND_X - 0.3, -14.5)])
    origin, ax, az, _ = gate
    mid = (origin[0] - az[0] * 0.8, origin[1] - az[1] * 0.8)  # Grenze im Bogen (Street.GATE_BOUND_INSIDE)
    corners = []
    for u, v in ((-3.55, -0.3), (3.55, -0.3), (3.55, 0.3), (-3.55, 0.3)):
        corners.append((mid[0] + ax[0] * u + az[0] * v, mid[1] + ax[1] * u + az[1] * v))
    blocks.append(corners)
    return blocks


def reachable_points(houses, gate, step=0.5):
    """Rasterpunkte, die man vom Gehweg vor der Bücherei aus zu Fuß erreicht (0,3 m Abstand)."""
    blocks = _blockers(houses, gate)
    def free(p):
        for dx, dz in ((0, 0), (0.3, 0), (-0.3, 0), (0, 0.3), (0, -0.3)):
            q = (p[0] + dx, p[1] + dz)
            if any(_inside(q, poly) for poly in blocks):
                return False
        return True
    start = (0.0, -6.0)
    seen = {start}
    todo = [start]
    while todo:
        p = todo.pop()
        for dx, dz in ((step, 0), (-step, 0), (0, step), (0, -step)):
            q = (round(p[0] + dx, 3), round(p[1] + dz, 3))
            if q not in seen and abs(q[0]) < 120 and abs(q[1]) < 120 and free(q):
                seen.add(q)
                todo.append(q)
    return sorted(seen)


def check_unseen(houses, gate):
    points = reachable_points(houses, gate)
    occluders = houses + [("Library", "-", "-", LIBRARY)] + [("Alley", "-", "-", b) for b in ALLEY_BLOCKS]
    hits = {}
    void = []
    sample = [p for i, p in enumerate(points) if i % 6 == 0]
    for p in sample:
        for a in range(0, 360, 2):
            dist, name, group = cast(occluders, p, math.radians(a))
            if dist is None:
                void.append((p, a))
            else:
                hits[name] = hits.get(name, 0) + 1
    print("Erreichbare Rasterpunkte: %d (geprüft: %d, je 180 Blickrichtungen)" % (len(points), len(sample)))
    print("Blicke ins Leere: %d" % len(void), void[:5])
    unseen = {}
    for name, group, kind, _ in houses:
        if name not in hits and not name.startswith("Gatehouse"):
            unseen.setdefault(group, []).append(name)
    for group, names in unseen.items():
        print("Nie zu sehen (%s): %s" % (group, ", ".join(sorted(set(names)))))
    return hits


def draw(houses, path):
    from PIL import Image, ImageDraw
    xs = [x for *_, poly in houses for x, _ in poly]
    zs = [z for *_, poly in houses for _, z in poly]
    x0, x1, z0, z1 = min(xs) - 3, max(xs) + 3, min(zs) - 3, max(zs) + 3
    k = 1600 / (x1 - x0)
    image = Image.new("RGB", (1600, int((z1 - z0) * k)), (245, 240, 230))
    pen = ImageDraw.Draw(image)
    at = lambda x, z: ((x - x0) * k, (z - z0) * k)
    colors = {"LibraryRow": (200, 120, 90), "Opposite": (120, 150, 190), "StraightEnd": (140, 180, 120),
              "GateStreet": (200, 170, 90)}
    for name, group, kind, poly in houses:
        pen.polygon([at(*q) for q in poly], fill=colors.get(group, (150, 150, 150)), outline=(40, 40, 40))
        if kind.startswith(("corner", "gatehouse")):
            cx = sum(q[0] for q in poly) / len(poly)
            cz = sum(q[1] for q in poly) / len(poly)
            pen.text(at(cx, cz), kind, fill=(0, 0, 0))
    library = [(-3.2, -2.0828), (-1.0828, -4.2), (3.2, -4.2), (3.2, 4.2), (-3.2, 4.2)]
    pen.polygon([at(*q) for q in library], fill=(220, 60, 60))
    pen.line([at(BOUND_X, NEAR_Z), at(BOUND_X, FAR_Z)], fill=(200, 0, 200), width=3)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("Plan gespeichert:", path, "(oben = -Z = Straße/gegenüber, Bücherei rot, Grenze lila)")


if __name__ == "__main__":
    houses, gate = load_houses()
    command = sys.argv[1] if len(sys.argv) > 1 else "plan"
    if command == "plan":
        draw(houses, ROOT + "screenshots/plan.png")
    elif command == "bound":
        check_bound(houses)
    elif command == "gate":
        check_gate(houses, gate)
    elif command == "unseen":
        check_unseen(houses, gate)
    else:
        print(__doc__)
