"""Wohnhäuser im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h): Reihenhäuser und Kulissen-
häuser wie auf den Vorlagebildern der Entwicklerin – Cottages mit cremefarbenem oder pastelligem
Putz, braunen Backsteinen oder großen Sandstein-Quadern, Terrakotta- oder Schieferdächern aus
Ziegelreihen, runden Gauben, Rundbogenfenstern mit dicken Holzrahmen, Brettertüren mit Bogen,
Blumenkästen, Steinsockeln und Ecksteinen. Jedes Teil ein geschlossener Körper mit weichen Kanten.

Gebaut wird ein Haus in Blender-Koordinaten (Front bei y = Vorgarten-Tiefe, zeigt nach -y; das
Haus reicht bis y = Tiefe; x quer, Mitte 0; z oben) aus einer Beschreibung (spec aus
build_street.make_spec: Breite, Geschosse, Dachform, Wandart, Fensterspalten, Tür, freie
Seitenwände …) und einem Stil (house_style: Farben, Fenster- und Türform, Gauben …).
Aufgerufen von tools/blender/build_storybook_street.py.

Pflanzen kommen nicht ins Haus-Modell: Das Haus legt leere Pflanzplätze an (Objekte
„PlantSpot_…“ mit Art und Größe), auf die das Spiel die austauschbaren Pflanzen-Szenen setzt.
"""

import math
import random
import zlib

import bpy
from mathutils import Matrix, Vector

import storybook_common as SC
import storybook_lib as SB
import storybook_town as T
from storybook_lib import Body

# --- Farben (sRGB) ---
PLASTER = {"Creme": (0.93, 0.86, 0.72), "Butter": (0.94, 0.85, 0.63), "Pfirsich": (0.94, 0.79, 0.65), "Rosé": (0.91, 0.77, 0.72),
           "Salbei": (0.81, 0.84, 0.71), "Sand": (0.89, 0.81, 0.67), "Aprikose": (0.93, 0.74, 0.58), "Nebel": (0.82, 0.84, 0.82)}
BRICK = {"Braun": (0.6, 0.38, 0.27), "Rost": (0.68, 0.42, 0.29), "Dunkel": (0.52, 0.33, 0.26), "Honig": (0.72, 0.52, 0.36)}
ASHLAR = {"Creme": (0.88, 0.8, 0.65), "Warm": (0.86, 0.76, 0.6), "Hell": (0.9, 0.85, 0.73)}
ROOF = {"Ton": (0.75, 0.42, 0.28), "Ziegelrot": (0.7, 0.36, 0.25), "Ton hell": (0.8, 0.5, 0.33), "Schiefer": (0.38, 0.38, 0.41),
        "Schiefer braun": (0.4, 0.35, 0.32)}
JOIN = {"Eiche": ((0.5, 0.32, 0.19), "wood"), "Honig": ((0.62, 0.42, 0.24), "wood"), "Nuss": ((0.37, 0.24, 0.15), "wood"),
        "Salbei": ((0.47, 0.58, 0.48), "paint"), "Petrol": ((0.25, 0.44, 0.45), "paint"), "Taubenblau": ((0.38, 0.47, 0.57), "paint"),
        "Creme": ((0.9, 0.86, 0.76), "paint"), "Tannengrün": ((0.21, 0.34, 0.25), "paint"), "Ochsenblut": ((0.52, 0.23, 0.19), "paint")}
ROOMS = [(0.86, 0.72, 0.56), (0.8, 0.66, 0.52), (0.88, 0.78, 0.62), (0.78, 0.62, 0.5), (0.84, 0.74, 0.66)]
CANOPY = {"Salbei": (0.42, 0.56, 0.44), "Petrol": (0.25, 0.48, 0.5), "Terrakotta": (0.76, 0.42, 0.3), "Schiefer": (0.33, 0.33, 0.36),
          "Senf": (0.82, 0.64, 0.3)}
BOX = {"Rot": (0.68, 0.22, 0.18), "Grün": (0.3, 0.42, 0.3), "Holz": (0.5, 0.33, 0.21), "Blau": (0.33, 0.43, 0.53), "Creme": (0.88, 0.84, 0.74)}


def pick(rnd, d, weights=None):
    keys = list(d)
    return rnd.choices(keys, weights=weights)[0] if weights else rnd.choice(keys)


def house_style(spec, key):
    """Stil eines Hauses (fest je Haus): Wand, Farben, Fenster- und Türform, Dach, Extras."""
    rnd = random.Random(zlib.crc32(("bilderbuch/" + key).encode()))
    wall = {"brick": "brick", "stone": "ashlar"}.get(spec["wall"], "plaster")
    fach = spec["fachwerk"]
    if fach:
        wall = "plaster"
    ground = rnd.choice(["ashlar", "plaster"]) if fach else wall
    palette = {"brick": BRICK, "ashlar": ASHLAR, "plaster": PLASTER}[wall]
    wall_name = pick(rnd, palette)
    if fach:
        wall_name = rnd.choice(["Creme", "Butter", "Sand"])
    ground_name = pick(rnd, ASHLAR) if ground == "ashlar" else wall_name
    roof = "front" if spec["roof"] == "front_gable" else "side"
    slate = spec["roof_mat"] == "slate" and rnd.random() < 0.5
    roof_name = rnd.choice(["Schiefer", "Schiefer braun"]) if slate else rnd.choice(["Ton", "Ton", "Ziegelrot", "Ton hell"])
    join = pick(rnd, JOIN, weights=[4, 2, 3, 3, 2, 3, 2, 2, 1])
    win = rnd.choice({"plaster": ["arch", "arch", "segment", "square"], "ashlar": ["square", "segment", "arch"],
                      "brick": ["segment", "segment", "arch"]}[wall])
    if fach:
        win = "square"
    door = "plank" if wall != "brick" or rnd.random() < 0.4 else "panel"
    dormers = list(spec["dormers"]) if roof == "side" else []
    if roof == "side" and not dormers and len(spec["storeys"]) == 2 and rnd.random() < 0.55:
        dormers = [0.0] if spec["width"] < 5.2 or rnd.random() < 0.5 else [-spec["width"] / 4, spec["width"] / 4]
    return {
        "rnd_seed": rnd.randrange(1 << 30), "wall": wall, "wall_color": palette[wall_name], "wall_name": wall_name,
        "ground": ground, "ground_color": (ASHLAR[ground_name] if ground == "ashlar" else palette[wall_name]), "ground_name": ground_name,
        "fachwerk": fach, "jetty": spec["jetty"] if fach else 0.0,
        "roof": roof, "roof_color": ROOF[roof_name], "roof_name": roof_name,
        "pitch": rnd.uniform(48, 54) if roof == "front" else rnd.uniform(38, 45),
        "join": join, "join_color": JOIN[join][0], "join_grain": JOIN[join][1],
        "window": win, "door": door, "door_rise": rnd.choice([0.3, 0.45, 0.5]) if door == "plank" else 0.0,
        "hood": door == "plank" and not fach and rnd.random() < 0.45,
        "shutters": (spec["shutters"] or rnd.random() < 0.25) and win == "square",
        "boxes": spec["flower_boxes"] or rnd.random() < 0.5, "box_color": pick(rnd, BOX),
        "canopy": pick(rnd, CANOPY) if rnd.random() < 0.35 else None,
        "dormers": dormers, "chimneys": spec["chimneys"] or ([rnd.choice([-1, 1])] if rnd.random() < 0.6 else []),
        "quoins": wall != "brick" and (spec["quoins"] or rnd.random() < 0.35),
        "band": wall != "plaster" and rnd.random() < 0.5,
        "eaves": "rafters" if wall == "plaster" or fach else "cornice",
        "balcony": spec["balcony"] is not None and wall != "plaster" and not fach,
        "settle": {"wave": rnd.uniform(0.012, 0.022), "wavelength": rnd.uniform(2.4, 3.4), "lean": rnd.uniform(-0.003, 0.001),
                   "roof_sag": rnd.uniform(0.03, 0.07), "ridge_tilt": rnd.uniform(-0.04, 0.04), "eaves_sag": rnd.uniform(0.01, 0.03)},
    }


def house_materials(M, st):
    """Materialien dieses Hauses (Name = Art + Farbe, mehrere Häuser teilen sie)."""
    mk = SC.make_material
    k = st["rnd_seed"] % len(ROOMS)
    M["h_room"] = mk("Zimmer warm %d" % (k + 1), ROOMS[k], glow=0.3, rough=0.95, vary=0.05, bump=0.05)
    wall_grain = {"plaster": "plaster", "brick": "brick", "ashlar": "ashlar"}
    g = st["wall"]
    M["h_wall"] = mk("%s %s" % ({"plaster": "Putz", "brick": "Ziegel", "ashlar": "Quader"}[g], st["wall_name"]), st["wall_color"],
                     grain=wall_grain[g], rough=0.92, vary=0.07, scale=1.6 if g == "plaster" else 4.0, bump=0.32 if g == "plaster" else 0.28,
                     color2=(0.57, 0.5, 0.42) if g == "brick" else (0.62, 0.56, 0.47))
    gg = st["ground"]
    M["h_ground"] = mk("%s %s" % ({"plaster": "Putz", "brick": "Ziegel", "ashlar": "Quader"}[gg], st["ground_name"]), st["ground_color"],
                       grain=wall_grain[gg], rough=0.92, vary=0.07, scale=1.6 if gg == "plaster" else 4.0, bump=0.3,
                       color2=(0.57, 0.5, 0.42) if gg == "brick" else (0.62, 0.56, 0.47))
    M["h_roof"] = mk("Dachziegel %s" % st["roof_name"], st["roof_color"], grain="stone", rough=0.9, vary=0.08, bump=0.2)
    rc = st["roof_color"]
    M["h_roof_cap"] = mk("Dachziegel %s First" % st["roof_name"], (rc[0] * 0.86, rc[1] * 0.86, rc[2] * 0.88), grain="stone", rough=0.9,
                         vary=0.06, bump=0.2)
    M["h_join"] = mk("%s %s" % ("Holz" if st["join_grain"] == "wood" else "Lack", st["join"]), st["join_color"], grain=st["join_grain"],
                     rough=0.78 if st["join_grain"] == "wood" else 0.72, vary=0.07, bump=0.2 if st["join_grain"] == "wood" else 0.12)
    jc = st["join_color"]
    M["h_join_dark"] = mk("%s %s dunkel" % ("Holz" if st["join_grain"] == "wood" else "Lack", st["join"]), tuple(c * 0.8 for c in jc),
                          grain=st["join_grain"], rough=0.78, vary=0.06, bump=0.15)
    M["h_door"] = mk("Holz Tür %s" % st["join"], jc if st["join_grain"] == "paint" else (jc[0] * 0.92, jc[1] * 0.9, jc[2] * 0.88),
                     grain=st["join_grain"], rough=0.78, vary=0.1, bump=0.25)
    M["h_box"] = mk("Lack Blumenkasten %s" % st["box_color"], BOX[st["box_color"]], grain="paint" if st["box_color"] != "Holz" else "wood",
                    rough=0.75, vary=0.06, bump=0.12)
    M["h_timber"] = M["oak_dark"]
    cn = st.get("canopy")
    if cn:
        M["h_canopy"] = mk("Markisenstoff %s" % cn, CANOPY[cn], grain="fabric", rough=0.95, vary=0.04, bump=0.15, wind=0.03)


# --- Bauteile ---

def arc_y(x, hx, hs, rise, inset=0.0):
    """Höhe des flachen Bogens (wie SB.arc_points) über x."""
    big_r = (hx * hx + rise * rise) / (2 * rise)
    cy = hs + rise - big_r
    r = big_r - inset
    return cy + math.sqrt(max(0.0, r * r - x * x))


def opening_outline(w, h, rise, inset=0.0, n=14):
    """Umriss einer Öffnung (unten Mitte = 0): Rechteck mit flachem Bogen oben (rise > 0)."""
    hx = w / 2 - inset
    if rise <= 0:
        return [(-hx, inset), (hx, inset), (hx, h - inset), (-hx, h - inset)]
    return [(-hx, inset), (hx, inset)] + SB.arc_points(w / 2, h - rise, rise, inset, n)


def cutter_for(fm, w, h, rise, depth=2.0):
    if rise > 0:
        return SB.slab_cutter(opening_outline(w, h, rise), fm, -depth / 2, depth)
    return SB.cutter((0, h / 2, 0), (w, h, depth), matrix=fm)


def window(M, C, name, fm, w, h, rise, panes=(2, 3), curtains=True, seed=1, frame="h_join"):
    """Holzfenster mit dickem, weich gerundetem Rahmen in der Laibung (fm = Mitte unten der Öffnung
    auf der Wandfläche; lokal x quer, y hoch, z nach außen): Rahmen, Bogen-Kopfstück (rise > 0),
    Sprossen, Glas, Vorhänge. Alles Körper."""
    hx, f, back, d = w / 2, 0.075, -0.13, 0.085
    hs = h - rise
    b = Body(name + " Rahmen", M[frame], C["windows"], seed=seed, vary=0.035, bevel=0.008)

    def lb(c, s):
        b.box(c, s, step=0.6, dent=0.002, matrix=fm)
    jh = hs - 0.03 if rise > 0 else h
    lb((-hx + f / 2, jh / 2, back), (f, jh, d))
    lb((hx - f / 2, jh / 2, back), (f, jh, d))
    lb((0, f / 2, back), (w - 2 * f + 0.004, f, d))
    if rise > 0:
        low = hs - 0.05
        head = SB.arc_points(hx, hs, rise) + [(-hx, low), (-hx + f, low)] + list(reversed(SB.arc_points(hx, hs, rise, f))) + \
            [(hx - f, low), (hx, low)]
        b.slab(head, d + 0.004, fm @ Matrix.Translation((0, 0, back - (d + 0.004) / 2)), dent=0.002)
        lb((0, hs, back + 0.004), (w - 2 * f + 0.004, 0.034, d - 0.02))
        top_inner = hs
    else:
        lb((0, h - f / 2, back), (w - 2 * f + 0.004, f, d))
        top_inner = h - f
    # Sprossen
    for i in range(1, panes[0]):
        xx = -hx + f + (w - 2 * f) * i / panes[0]
        top = arc_y(xx, hx, hs, rise, f) if rise > 0 else top_inner
        lb((xx, (f + top) / 2, back + 0.006), (0.03, top - f + 0.01, 0.05))
    for j in range(1, panes[1]):
        yy = f + (top_inner - f) * j / panes[1]
        lb((0, yy, back + 0.006), (w - 2 * f + 0.004, 0.03, 0.05))
    b.build()
    g = Body(name + " Glas", M["glass"], C["windows"], seed=seed + 1, vary=0.0)
    g.slab(opening_outline(w, h, rise, 0.012), 0.006, fm @ Matrix.Translation((0, 0, back - 0.025)), dent=0.0)
    g.build()
    if curtains:
        rnd = random.Random(seed)
        c = Body(name + " Vorhänge", M["curtain"], C["windows"], seed=seed + 2, vary=0.06)
        for side in (-1, 1):
            cw = w * rnd.uniform(0.24, 0.32)
            x0 = side * hx - (cw if side > 0 else 0) + side * 0.02
            folds = rnd.randint(4, 6)
            origin = fm @ Vector((x0, 0.04, back - 0.11))
            u = fm.to_3x3() @ Vector((cw, 0, 0))
            v = fm.to_3x3() @ Vector((0, hs - 0.1, 0))
            c.sheet(origin, u, v, 7, 3, 0.008, offset=lambda uu, vv, f_=folds: 0.022 * math.sin(uu * math.pi * f_) * (0.6 + 0.4 * vv))
        c.build()


def board_shutters(M, C, name, fm, w, h, mat="h_join", open_off=10.0, seed=1):
    """Brett-Fensterläden links und rechts (Cottage): drei Bretter, zwei Riegel und eine schräge
    Strebe (Z), fast an die Wand geklappt; eiserne Kloben. Sparsam: wenige Körper je Laden."""
    rnd = random.Random(seed)
    b = Body(name + " Läden", M[mat], C["windows"], seed=seed, vary=0.07, bevel=0.006)
    lw = w / 2 + 0.03
    phi = math.radians(open_off)
    for side in (-1, 1):
        hinge = Vector((side * (w / 2 + 0.04), 0.0, 0.035))
        lx = Vector((side * math.cos(phi), 0.0, math.sin(phi)))
        ly = Vector((0.0, 1.0, 0.0))
        lz = lx.cross(ly)
        leaf = fm @ Matrix(((lx.x, ly.x, lz.x, hinge.x), (lx.y, ly.y, lz.y, hinge.y), (lx.z, ly.z, lz.z, hinge.z), (0, 0, 0, 1)))
        pw = lw / 3
        for i in range(3):
            b.box((pw * (i + 0.5), h / 2, 0.0), (pw - 0.008, h - 0.02 * rnd.random(), 0.03), step=1, dent=0.002, matrix=leaf)
        for yy in (0.2, h - 0.2):
            b.box((lw / 2, yy, -side * 0.0 + 0.026), (lw - 0.06, 0.08, 0.022), step=1, dent=0.002, matrix=leaf)
        p0 = leaf @ Vector((0.06, 0.26, 0.026))
        p1 = leaf @ Vector((lw - 0.06, h - 0.26, 0.026))
        b.span(p0, p1, 0.07, 0.022, step=1, dent=0.002)
    b.build()


def surround(M, C, name, fm, w, h, rise, kind, seed=1):
    """Fassung außen: Steinbank unten und je nach Wand ein Bogen aus Ziegeln (brick), ein Sturz mit
    Schlussstein (ashlar) oder ein weich gerundeter Rahmen aus hellem Stein (plaster)."""
    rnd = random.Random(seed)
    st = Body(name + " Bank und Fassung", M["trim"] if kind != "brick" else M["pub_arch"], C["walls"], seed=seed, vary=0.08, bevel=0.012)
    st.box((0, -0.05, 0.075), (w + 0.2, 0.1, 0.15), step=0.6, dent=0.004, matrix=fm)
    hs = h - rise
    if kind == "brick":
        # Bogen aus hellen Ziegeln, strahlenförmig, direkt auf der Öffnung
        rr = max(rise, 0.1)
        hx = w / 2
        big_r = (hx * hx + rr * rr) / (2 * rr)
        cy = hs + rr - big_r if rise > 0 else h - big_r + 0.0
        if rise <= 0:
            cy = h + rr - big_r
        r = big_r + 0.12
        half = math.asin(min(0.99, (hx + 0.13) / r))
        n = max(7, int(w / 0.09))
        for k in range(n):
            a = -half + 2 * half * (k + 0.5) / n
            m = fm @ Matrix.Translation((r * math.sin(a), cy + r * math.cos(a), 0.03)) @ Matrix.Rotation(-a, 4, "Z")
            st.box((0, 0, 0), (2 * r * math.sin(half / n) * 0.93, 0.24 * rnd.uniform(0.96, 1.04), 0.06), step=1, dent=0.003, matrix=m)
    elif kind == "ashlar":
        top = h + 0.02
        st.box((0, top + 0.1, 0.03), (w + 0.3, 0.2, 0.06), step=0.6, dent=0.004, matrix=fm)
        st.box((0, top + 0.12, 0.05), (0.2, 0.26, 0.1), step=1, dent=0.003, matrix=fm)
    else:
        # weicher Rahmen aus hellem Stein um die Öffnung (Faschen)
        band = 0.09
        for side in (-1, 1):
            x0 = side * (w / 2 + band / 2)
            st.box((x0, (0.15 + hs) / 2, 0.025), (band, hs - 0.15, 0.05), step=0.6, dent=0.003, matrix=fm)
        if rise > 0:
            arc_o = SB.arc_points(w / 2 + band, hs, rise + band * 0.6)
            arc_i = list(reversed(SB.arc_points(w / 2, hs, rise)))
            st.slab(arc_o + [(-w / 2 - band, hs - 0.06), (-w / 2, hs - 0.06)] + arc_i + [(w / 2, hs - 0.06), (w / 2 + band, hs - 0.06)], 0.05,
                    fm @ Matrix.Translation((0, 0, 0.0)), dent=0.002)
        else:
            st.box((0, h + band / 2, 0.025), (w + 2 * band, band, 0.05), step=0.6, dent=0.003, matrix=fm)
    st.build()


def plank_door(M, C, name, fm, w, h, rise, seed=1):
    """Brettertür mit Bogen (fm = Mitte unten der Öffnung auf der Wand): Rahmen mit Bogen-Kopf,
    Bretter (jedes ein Körper, Oberkante folgt dem Bogen), zwei Eisenbänder, Ringgriff, flache
    Steinplatte davor (2,5 cm)."""
    rnd = random.Random(seed)
    hx, f, dz, lift = w / 2, 0.08, -0.2, 0.025
    hs = h - rise
    fr = Body(name + " Rahmen", M["h_join_dark"], C["shop"], seed=seed, vary=0.04, bevel=0.01)
    fr.box((-hx + f / 2, (hs if rise > 0 else h) / 2, dz), (f, hs if rise > 0 else h, 0.16), step=0.6, dent=0.002, matrix=fm)
    fr.box((hx - f / 2, (hs if rise > 0 else h) / 2, dz), (f, hs if rise > 0 else h, 0.16), step=0.6, dent=0.002, matrix=fm)
    if rise > 0:
        low = hs - 0.06
        head = SB.arc_points(hx, hs, rise) + [(-hx, low), (-hx + f, low)] + list(reversed(SB.arc_points(hx, hs, rise, f))) + \
            [(hx - f, low), (hx, low)]
        fr.slab(head, 0.16, fm @ Matrix.Translation((0, 0, dz - 0.08)), dent=0.002)
    else:
        fr.box((0, h - f / 2, dz), (w - 2 * f + 0.004, f, 0.16), step=0.6, dent=0.002, matrix=fm)
    fr.build()
    leaf = Body(name + " Bretter", M["h_door"], C["shop"], seed=seed + 1, vary=0.09, bevel=0.006)
    inner = w - 2 * f + 0.012
    n = max(4, int(round(inner / 0.14)))
    pw = inner / n
    for i in range(n):
        x0 = -inner / 2 + i * pw + 0.003
        x1 = x0 + pw - 0.006
        t0 = (arc_y(x0, hx, hs, rise, f - 0.006) if rise > 0 else h - f + 0.006)
        t1 = (arc_y(x1, hx, hs, rise, f - 0.006) if rise > 0 else h - f + 0.006)
        leaf.slab([(x0, lift), (x1, lift), (x1, t1), (x0, t0)], 0.05, fm @ Matrix.Translation((0, 0, dz - 0.025)), dent=0.002)
    leaf.build()
    ir = Body(name + " Beschläge", M["lamp_iron"], C["shop"], seed=seed + 2, vary=0.03, bevel=0.003)
    for yy in (0.42, hs - 0.38):
        ir.box((-0.04, yy, dz + 0.03), (inner - 0.14, 0.045, 0.012), step=1, dent=0.001, matrix=fm)
        ir.blob(tuple(fm @ Vector((inner / 2 - 0.11, yy, dz + 0.03))), 0.03, subdiv=1, lump=0.0, scale=(1, 1, 0.4))
        for k in range(4):
            ir.blob(tuple(fm @ Vector((-inner / 2 + 0.06 + k * (inner - 0.2) / 3, yy, dz + 0.04))), 0.008, subdiv=1, lump=0.0)
    ring_c = fm @ Vector((hx - f - 0.14, 1.0, dz + 0.045))
    ax = (fm.to_3x3() @ Vector((0, 0, 1))).normalized()
    up = (fm.to_3x3() @ Vector((0, 1, 0))).normalized()
    side = (fm.to_3x3() @ Vector((1, 0, 0))).normalized()
    T.loop_tube(ir, [ring_c + (side * math.cos(a) + up * math.sin(a)) * 0.045 for a in [2 * math.pi * k / 16 for k in range(16)]], 0.007,
                segs=6, axis=tuple(ax))
    ir.lathe([(0.0, 0.0), (0.035, 0.0), (0.03, 0.012), (0.0, 0.016)], tuple(fm @ Vector((hx - f - 0.14, 1.045, dz + 0.025))), segs=12,
             turn=(-90, 0))
    ir.build()
    pl = Body(name + " Platte", M["stone"], C["shop"], seed=seed + 3, vary=0.06, bevel=0.012)
    pl.box((0, 0.0125, 0.3), (w + 0.3, 0.025, 0.6), step=0.6, dent=0.002, matrix=fm)
    pl.build()
    del rnd


def mailbox(M, C, name, fm, x, z, seed=1):
    """Kleiner Wand-Briefkasten (fm = Wandebene): Kasten mit gewölbtem Deckel, Einwurfschlitz mit
    Messingklappe, Namensschildchen. Farbe aus BOX/Lack."""
    rnd = random.Random(seed)
    col = rnd.choice(["Rot", "Grün", "Blau", "Creme"])
    mat = SC.make_material("Lack Briefkasten %s" % col, BOX[col], grain="paint", rough=0.6, vary=0.05, bump=0.1)
    M["h_mail_" + col] = mat
    b = Body(name, mat, C["deco"], seed=seed, vary=0.04, bevel=0.01)
    b.box((x, z, 0.06), (0.3, 0.34, 0.12), step=1, dent=0.002, matrix=fm)
    # gewölbter Deckel: liegende Walze entlang der Wand (Front: lokal x = Welt x)
    b.lathe([(0.0, -0.16), (0.065, -0.16), (0.07, -0.15), (0.07, 0.15), (0.065, 0.16), (0.0, 0.16)],
            tuple(fm @ Vector((x, z + 0.17, 0.06))), segs=12, turn=(0, 90))
    b.build()
    br = Body(name + " Klappe", M["gold"], C["deco"], seed=seed + 1, bevel=0.003)
    br.box((x, z + 0.06, 0.125), (0.18, 0.035, 0.012), step=1, dent=0.0005, matrix=fm)
    br.box((x, z - 0.08, 0.125), (0.1, 0.05, 0.008), step=1, dent=0.0005, matrix=fm)
    br.build()


def door_hood(M, C, name, x, y_wall, z_top, w, seed=1):
    """Kleines Vordach über der Tür: Satteldach aus Ziegelreihen (Giebel zur Straße), Giebelbrett,
    zwei geschwungene Holzkonsolen."""
    L = 0.6
    span = w / 2 + 0.22
    frame = Matrix(((0, 1, 0, x), (-1, 0, 0, y_wall - L / 2), (0, 0, 1, 0), (0, 0, 0, 1)))
    ridge, _, a = T.cozy_roof(M, C, name, frame, L, span, z_top, 40.0, "h_roof", cap_mat="h_roof_cap", ends=(0.0, 0.06), seed=seed,
                              back_simple=False, tile_w=0.2, row=0.17)
    wd = Body(name + " Holz", M["h_join_dark"], C["shop"], seed=seed + 5, vary=0.05, bevel=0.008)
    yf = y_wall - L - 0.03
    wd.slab([(-span + 0.05, z_top + 0.02), (span - 0.05, z_top + 0.02), (0.0, ridge - 0.06)], 0.04,
            Matrix.Translation((x, yf + 0.04, 0)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))), dent=0.002)
    for s in (-1, 1):
        px = x + s * (span - 0.12)
        wd.tube([(px, y_wall - 0.02, z_top - 0.45), (px, y_wall - 0.2, z_top - 0.3), (px, yf + 0.08, z_top - 0.02)], 0.03, segs=8,
                smooth=2, round_ends=True)
        wd.box((px, y_wall - 0.02, z_top - 0.42), (0.08, 0.04, 0.14), step=1, dent=0.002)
    wd.build()


def rafters(M, C, name, x0, x1, y_front, z, n_every=0.55):
    """Sparrenköpfe unter der Traufe (kleine runde Holzbalken) und Traufbrett."""
    b = Body(name, M["h_join_dark"], C["roof"], seed=7, vary=0.06, bevel=0.01)
    x = x0 + 0.2
    while x < x1 - 0.15:
        b.box((x, y_front + 0.14, z - 0.06), (0.07, 0.34, 0.1), step=1, dent=0.003)
        x += n_every
    b.build()


def plant_spot(C, kind, pos, size, n, facing=0.0):
    """Leerer Pflanzplatz (Objekt „PlantSpot_<art>_<n>“) mit Art und Größe als Eigenschaften:
    kind = box (Blumenkasten), pot (Kübel vor der Tür), climber (Kletterpflanze an der Wand),
    bed (Beet im Vorgarten). size = (Breite, Tiefe, Höhe) in m; facing = Drehung um z (Grad)."""
    e = bpy.data.objects.new("PlantSpot_%s_%d" % (kind, n), None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.25
    e.location = pos
    e.rotation_euler = (0.0, 0.0, math.radians(facing))
    e["kind"] = kind
    e["width"], e["depth"], e["height"] = (round(v, 3) for v in size)
    C["plants"].objects.link(e)
    return e


# --- Haus ---

class House:
    """Baut ein Wohnhaus. Ergebnis: Teile in den Sammlungen C, Pflanzplätze, Laternenplatz."""

    def __init__(self, M, C, spec, st, key, near=True):
        self.M, self.C, self.spec, self.st, self.key, self.near = M, C, spec, st, key, near
        self.rnd = random.Random(st["rnd_seed"])
        self.W, self.D = spec["width"], spec["depth"]
        self.hw = self.W / 2
        self.sb = spec["setback"]
        self.storeys = spec["storeys"]
        self.zs = [0.0]
        for s in self.storeys:
            self.zs.append(self.zs[-1] + s)
        self.E = self.zs[-1]
        self.jetty = st["jetty"]
        self.front = ((-self.hw, self.sb), (self.hw, self.sb))
        self.upper_front = ((-self.hw, self.sb - self.jetty), (self.hw, self.sb - self.jetty))
        self.spots = []
        self.lantern = None
        self.n_spot = 0

    def fx(self, x):
        return x + self.hw

    def spot(self, kind, pos, size, facing=0.0):
        self.spots.append(plant_spot(self.C, kind, pos, size, self.n_spot, facing))
        self.n_spot += 1

    # Öffnungen der Front
    def layout(self):
        sp, st = self.spec, self.st
        win = st["window"]
        self.ground = []
        for i, (x, w) in enumerate(sp["columns"]):
            if i == sp["door_col"]:
                dw = 1.0 if st["door"] == "plank" else 1.04
                dh = 2.3 if st["door"] == "plank" else 2.62
                self.door = dict(x=x, w=dw, h=dh, rise=st["door_rise"] if st["door"] == "plank" else 0.0)
            else:
                ww = min(1.1, w)
                h = min(1.6, self.storeys[0] - 1.45)
                self.ground.append(dict(x=x, z=0.82, w=ww, h=h, rise=self.rise(ww, win)))
        self.upper = []
        for f in range(1, len(self.storeys)):
            for x, w in sp["upper_columns"]:
                ww = min(1.0, w)
                h = min(1.5, self.storeys[f] - 1.35)
                self.upper.append(dict(x=x, z=self.zs[f] + 0.8, w=ww, h=h, rise=self.rise(ww, win), floor=f))

    def rise(self, w, kind):
        return {"arch": w * 0.32, "segment": 0.11, "square": 0.0}[kind]

    def build(self):
        self.layout()
        self.walls()
        self.plinth_and_quoins()
        self.front_openings()
        self.side_windows()
        self.roof()
        self.eaves()
        if self.st["fachwerk"]:
            self.timber()
        if self.sb > 0.5:
            self.garden()
        self.interior()
        self.place_spots()
        return self

    # Mauern
    def walls(self):
        M, C, st, hw, sb, E, D = self.M, self.C, self.st, self.hw, self.sb, self.E, self.D
        # Wände reichen bis in den Dachkern (keine Fuge); beim Giebel zur Straße nur knapp über
        # die Traufe, sonst stechen die Seitenwände aus den seitlichen Dachflächen
        top = E + (0.18 if st["roof"] == "side" else 0.08)
        z1 = self.zs[1] if st["fachwerk"] else top
        g = Body("Fassade unten" if st["fachwerk"] else "Fassade", M["h_ground"] if st["fachwerk"] else M["h_wall"], C["walls"], seed=1,
                 vary=0.03)
        T.wall_run(g, *self.front, 0.0, z1 + (0.02 if st["fachwerk"] else 0.0), thick=0.32, step=0.5)
        ops = []
        if st["roof"] == "front" and not st["fachwerk"]:
            g.slab([(0.0, top - 0.05), (self.W, top - 0.05), (self.W / 2, self.ridge_guess() - 0.14)], 0.32,
                   T.wall_matrix(*self.front) @ Matrix.Translation((0, 0, -0.32)), dent=0.006)
        front = g.build()
        door = self.door
        ops.append(cutter_for(T.wall_matrix(*self.front, self.fx(door["x"]), 0.0), door["w"], door["h"], door["rise"]))
        for o in self.ground:
            ops.append(cutter_for(T.wall_matrix(*self.front, self.fx(o["x"]), o["z"]), o["w"], o["h"], o["rise"]))
        if not st["fachwerk"]:
            for o in self.upper:
                ops.append(cutter_for(T.wall_matrix(*self.front, self.fx(o["x"]), o["z"]), o["w"], o["h"], o["rise"]))
            if st["roof"] == "front":
                gw = self.gable_window()
                if gw:
                    ops.append(cutter_for(T.wall_matrix(*self.front, self.fx(0.0), gw["z"]), gw["w"], gw["h"], gw["rise"]))
        SB.boolean_cut(front, ops)
        SC.add_bevel(front, 0.02)
        if st["fachwerk"]:
            u = Body("Gefache oben", M["h_wall"], C["walls"], seed=2, vary=0.04)
            T.wall_run(u, *self.upper_front, self.zs[1], top, thick=0.3, step=0.5)
            if st["roof"] == "front":
                u.slab([(0.0, top - 0.05), (self.W, top - 0.05), (self.W / 2, self.ridge_guess() - 0.14)], 0.3,
                       T.wall_matrix(*self.upper_front) @ Matrix.Translation((0, 0, -0.3)), dent=0.006)
            up = u.build()
            cuts = [cutter_for(T.wall_matrix(*self.upper_front, self.fx(o["x"]), o["z"]), o["w"], o["h"], o["rise"]) for o in self.upper]
            gw = self.gable_window() if st["roof"] == "front" else None
            if gw:
                cuts.append(cutter_for(T.wall_matrix(*self.upper_front, self.fx(0.0), gw["z"]), gw["w"], gw["h"], gw["rise"]))
            SB.boolean_cut(up, cuts)
            SC.add_bevel(up, 0.012)
        # Seitenwände (mit Giebel bei Satteldach längs der Straße) und Rückwand
        s = Body("Seitenwände und Rückwand", M["h_wall"], C["walls"], seed=3, vary=0.04)
        y0 = sb - self.jetty
        self.side_walls = {}
        for side in (-1, 1):
            p0, p1 = ((hw, y0), (hw, D)) if side > 0 else ((-hw, D), (-hw, y0))
            body = Body("Seitenwand %s" % ("rechts" if side > 0 else "links"), M["h_wall"], C["walls"], seed=4 + side, vary=0.04)
            T.wall_run(body, p0, p1, 0.0, top, thick=0.32, step=0.6)
            if st["roof"] == "side":
                L = D - y0
                body.slab([(0.0, top - 0.05), (L, top - 0.05), (L / 2, self.ridge_guess() - 0.14)], 0.32,
                          T.wall_matrix(p0, p1) @ Matrix.Translation((0, 0, -0.32)), dent=0.006)
            self.side_walls[side] = (body.build(), p0, p1)
        T.wall_run(s, (hw, D), (-hw, D), 0.0, top, thick=0.32, step=0.8)
        if st["roof"] == "front":
            s.slab([(0.0, top - 0.05), (self.W, top - 0.05), (self.W / 2, self.ridge_guess() - 0.14)], 0.32,
                   T.wall_matrix((hw, D), (-hw, D)) @ Matrix.Translation((0, 0, -0.32)), dent=0.006)
        s.build()

    def ridge_guess(self):
        a = math.radians(self.st["pitch"])
        if self.st["roof"] == "side":
            return self.E + ((self.D - (self.sb - self.jetty)) / 2 + 0.32) * math.tan(a)
        return self.E + (self.hw + 0.12) * math.tan(a)

    def gable_window(self):
        if self.ridge_guess() - self.E < 2.0:
            return None
        return dict(z=self.E + 0.35, w=0.62, h=0.85 if self.st["window"] != "square" else 0.7,
                    rise=0.2 if self.st["window"] != "square" else 0.0)

    def plinth_and_quoins(self):
        M, C, st, hw, sb = self.M, self.C, self.st, self.hw, self.sb
        d = self.door
        segs = [(-hw, d["x"] - d["w"] / 2 - 0.02), (d["x"] + d["w"] / 2 + 0.02, hw)]
        if self.near:
            # Sockel aus runden, unregelmäßigen Feldsteinen in zwei Reihen (jeder Stein ein Körper)
            p = Body("Sockelsteine", M["stone"], C["walls"], seed=8, vary=0.13, bevel=0.03)
            for a, b in segs:
                for row, (z0, z1) in enumerate(((0.0, 0.23), (0.23, 0.44))):
                    x = a + (0.12 if row else 0.0)
                    while x < b - 0.06:
                        wdt = min(self.rnd.uniform(0.3, 0.52), b - x)
                        if wdt > 0.08:
                            p.box((x + wdt / 2, sb - 0.035 + self.rnd.uniform(-0.01, 0.01), (z0 + z1) / 2),
                                  (wdt - 0.025, 0.13, z1 - z0 - 0.025), step=1, dent=0.012,
                                  turn=(self.rnd.uniform(-2, 2), 0, self.rnd.uniform(-1.5, 1.5)))
                        x += wdt
            p.build()
            if any(b - a > 0.05 for a, b in segs):
                f = Body("Sockelfuge", M["earth"], C["walls"], seed=9, vary=0.05)
                for a, b in segs:
                    if b - a > 0.05:
                        f.box(((a + b) / 2, sb + 0.0, 0.22), (b - a, 0.06, 0.44), step=1, dent=0.0)
                f.build()
        else:
            p = Body("Sockel", M["stone"], C["walls"], seed=8, vary=0.08, bevel=0.015)
            for a, b in segs:
                if b - a > 0.05:
                    p.box(((a + b) / 2, sb - 0.03, 0.22), (b - a, 0.12, 0.44), step=0.6, dent=0.006)
            p.build()
        exposed = self.spec.get("exposed", {})
        if st["quoins"] or exposed:
            q = Body("Ecksteine", M["stone"], C["walls"], seed=9, vary=0.1, bevel=0.014)
            ztop = self.zs[1] if st["fachwerk"] else self.E - 0.35
            for side in (-1, 1):
                if not st["quoins"] and side not in exposed:
                    continue
                z, k = 0.5, 0
                while z + 0.3 < ztop:
                    wdt = 0.42 if k % 2 == 0 else 0.27
                    q.box((side * (hw - wdt / 2 + 0.005), sb - 0.025, z + 0.14), (wdt, 0.06, 0.27), step=0.6, dent=0.004,
                          turn=(0, self.rnd.uniform(-1.2, 1.2), 0))
                    if side in exposed:
                        q.box((side * (hw + 0.025), sb + wdt / 2 - 0.005, z + 0.14), (0.06, wdt, 0.27), step=0.6, dent=0.004)
                    z += 0.3
                    k += 1
            q.build()
        if st["band"] and not st["fachwerk"]:
            bd = Body("Gurtgesims", M["trim"], C["walls"], seed=10, vary=0.05, bevel=0.012)
            for f in range(1, len(self.storeys)):
                bd.box((0, sb - 0.04, self.zs[f] + 0.05), (self.W + 0.01, 0.09, 0.12), step=0.6, dent=0.004)
            bd.build()

    def front_openings(self):
        M, C, st, sp = self.M, self.C, self.st, self.spec
        kind = "brick" if st["wall"] == "brick" else st["wall"]
        d = self.door
        fm = T.wall_matrix(*self.front, self.fx(d["x"]), 0.0, 0.0, self.rnd.uniform(-0.4, 0.4))
        if st["door"] == "plank":
            plank_door(self.M, C, "Haustür", fm, d["w"], d["h"], d["rise"], seed=20)
            if kind == "brick":
                surround(M, C, "Haustür", fm, d["w"], d["h"], d["rise"], "brick", seed=21)
            elif kind == "ashlar" or self.rnd.random() < 0.5:
                self.door_arch(fm, d)
        else:
            T.door(M, C, "Haustür", fm, d["w"] / 2, d["h"], "h_door", "h_join_dark", glazed=False, transom="bars", seed=20)
            surround(M, C, "Haustür", fm, d["w"] + 0.36, d["h"], 0.0, "brick" if kind == "brick" else "ashlar", seed=21)
        if st["hood"]:
            door_hood(M, C, "Vordach", d["x"], self.sb, d["h"] + 0.3, d["w"], seed=22)
        if self.near and self.rnd.random() < 0.55:
            # Briefkasten neben der Tür, auf der Seite mit mehr freier Wand
            side = 1 if d["x"] < 0 else -1
            mx = d["x"] + side * (d["w"] / 2 + (0.32 if st["door"] == "plank" else 0.42))
            if all(abs(mx - o["x"]) > o["w"] / 2 + 0.22 for o in self.ground) and abs(mx) < self.hw - 0.2:
                mailbox(M, C, "Briefkasten", T.wall_matrix(*self.front), self.fx(mx), 1.05, seed=zlib.crc32(self.key.encode()) % 997)
                self.mailbox_x = mx
        k = 0
        for o in self.ground:
            fm = T.wall_matrix(*self.front, self.fx(o["x"]), o["z"], 0.0, self.rnd.uniform(-1.0, 1.0))
            self.one_window("Fenster unten %d" % k, fm, o, kind, ground=True)
            k += 1
        front = self.upper_front if st["fachwerk"] else self.front
        for o in self.upper:
            fm = T.wall_matrix(*front, self.fx(o["x"]), o["z"], 0.0, self.rnd.uniform(-1.0, 1.0))
            self.one_window("Fenster %d" % k, fm, o, "timber" if st["fachwerk"] else kind, ground=False)
            k += 1
        if st["roof"] == "front":
            gw = self.gable_window()
            if gw:
                fm = T.wall_matrix(*front, self.fx(0.0), gw["z"], 0.0, self.rnd.uniform(-1.0, 1.0))
                window(M, C, "Giebelfenster", fm, gw["w"], gw["h"], gw["rise"], panes=(2, 2), curtains=self.near, seed=60)
                if not st["fachwerk"]:
                    surround(M, C, "Giebelfenster", fm, gw["w"], gw["h"], gw["rise"], kind, seed=61)
        if st["balcony"] and len(self.storeys) >= 2:
            self.juliet()

    def door_arch(self, fm, d):
        """Weicher Steinbogen um die Brettertür (Ashlar/Putz)."""
        st = Body("Türbogen", self.M["trim"], self.C["walls"], seed=23, vary=0.08, bevel=0.014)
        w, h, rise = d["w"], d["h"], d["rise"]
        band = 0.13
        hs = h - rise
        for side in (-1, 1):
            st.box((side * (w / 2 + band / 2 - 0.01), (0.44 + hs) / 2, 0.03), (band, hs - 0.44, 0.07), step=0.6, dent=0.003, matrix=fm)
        if rise > 0:
            arc_o = SB.arc_points(w / 2 + band - 0.01, hs, rise + band * 0.7)
            arc_i = list(reversed(SB.arc_points(w / 2 - 0.01, hs, rise)))
            st.slab(arc_o + [(-w / 2 - band + 0.01, hs - 0.05), (-w / 2 + 0.01, hs - 0.05)] + arc_i +
                    [(w / 2 - 0.01, hs - 0.05), (w / 2 + band - 0.01, hs - 0.05)], 0.07, fm @ Matrix.Translation((0, 0, -0.005)),
                    dent=0.003)
            # Schlussstein
            st.box((0, h + band * 0.55, 0.04), (0.16, band + 0.08, 0.09), step=1, dent=0.003, matrix=fm)
        else:
            st.box((0, h + band / 2, 0.03), (w + 2 * band, band, 0.07), step=0.6, dent=0.003, matrix=fm)
        st.build()

    def one_window(self, name, fm, o, kind, ground, front=True):
        M, C, st = self.M, self.C, self.st
        panes = (2, 3) if o["h"] > 1.3 else (2, 2)
        window(M, C, name, fm, o["w"], o["h"], o["rise"], panes=panes, curtains=self.near, seed=zlib.crc32(name.encode()) % 997)
        if kind != "timber":
            surround(M, C, name, fm, o["w"], o["h"], o["rise"], kind, seed=zlib.crc32(name.encode()) % 991)
        else:
            sl = Body(name + " Bank", M["h_timber"], C["walls"], seed=5, vary=0.06, bevel=0.01)
            sl.box((0, -0.04, 0.07), (o["w"] + 0.24, 0.08, 0.14), step=0.6, dent=0.003, matrix=fm)
            sl.build()
        if st["shutters"]:
            board_shutters(M, C, name, fm, o["w"], o["h"], mat="h_join", open_off=self.rnd.uniform(6, 12),
                           seed=zlib.crc32(name.encode()) % 983)
        if ground and front and self.near and st.get("canopy") and not st["shutters"]:
            # kleine Stoffmarkise über dem Fenster (wie auf dem Vorlagebild)
            top = o["h"] + 0.38
            T.placed(C["shop"], fm @ Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1))), T.cloth_awning, M, C,
                     name + " Markise", o["w"] + 0.3, top, 0.55, 0.32, valance=0.13, mat="h_canopy", frames=24,
                     seed=zlib.crc32(name.encode()) % 971)
            ground_box = False
        else:
            ground_box = self.rnd.random() < 0.3
        if st["boxes"] and (not ground or ground_box):
            bw = o["w"] + 0.18
            SC.planter_box(M, C["pots"], name + " Blumenkasten", fm @ Matrix.Translation((0, -0.06, 0.1)), bw, 0.2, 0.2,
                           seed=zlib.crc32(name.encode()) % 977, gap=0.1, mat="h_box")
            kb = Body(name + " Konsolen", M["lamp_iron"], C["pots"], seed=45, bevel=0.003)
            for sx in (-o["w"] / 2 + 0.06, o["w"] / 2 - 0.06):
                kb.tube([fm @ Vector((sx, -0.36, 0.04)), fm @ Vector((sx, -0.07, 0.4)), fm @ Vector((sx, -0.07, 0.04))], 0.009, segs=6,
                        round_ends=True)
            kb.build()
            # Mitte der Erde im Kasten; Blickrichtung = Wandnormale
            c = fm @ Vector((0, 0.2 - 0.045 + 0.02, 0.2))
            nrm = fm.to_3x3() @ Vector((0, 0, 1))
            self.spot("box", tuple(c), (bw - 0.06, 0.15, 0.4), facing=math.degrees(math.atan2(nrm.x, -nrm.y)))

    def juliet(self):
        """Französischer Balkon: schmiedeeisernes Gitter vor dem mittleren Fenster oben."""
        o = self.upper[len(self.upper) // 2] if len(self.upper) % 2 else self.upper[0]
        fm = T.wall_matrix(*self.front, self.fx(o["x"]), o["z"])
        ir = Body("Balkongitter", self.M["lamp_iron"], self.C["windows"], seed=30, bevel=0.003)
        w = o["w"] + 0.3
        for yy in (0.05, 0.85):
            ir.tube([fm @ Vector((-w / 2, yy, 0.16)), fm @ Vector((w / 2, yy, 0.16))], 0.012, segs=6, round_ends=True)
        n = int(w / 0.1)
        for i in range(n + 1):
            xx = -w / 2 + w * i / n
            ir.tube([fm @ Vector((xx, 0.05, 0.16)), fm @ Vector((xx, 0.85, 0.16))], 0.007, segs=5, round_ends=True)
        for sx in (-w / 2, w / 2):
            ir.tube([fm @ Vector((sx, 0.85, 0.16)), fm @ Vector((sx, 0.85, 0.0))], 0.01, segs=5, round_ends=True)
            ir.tube([fm @ Vector((sx, 0.05, 0.16)), fm @ Vector((sx, 0.05, 0.0))], 0.01, segs=5, round_ends=True)
        ir.build()

    def side_windows(self):
        """Freie Seitenwände (Gasse, Ende der Reihe): Fenster je Geschoss; nur ein Stück frei: nichts
        (dort kommt später eine Kletterpflanze hin)."""
        exposed = self.spec.get("exposed", {})
        for side, info in exposed.items():
            body, p0, p1 = self.side_walls[side]
            L = T.seg_len(p0, p1)
            if info[0] != "full":
                # nur vorn ein Stück frei: Kletterpflanze an der Seitenwand
                if info[1] > 0.5:
                    m = T.canon(p0, p1, info[1] / 2 if side > 0 else L - info[1] / 2, 0.0, 0.08)
                    c = m @ Vector((0, 0, 0))
                    self.spot("climber", (c.x, c.y, 0.0), (min(2.5, info[1] - 0.2), 0.3, self.E - 0.6),
                              facing=90.0 * side)
                continue
            cuts = []
            wins = []
            for f in range(len(self.storeys)):
                z0 = self.zs[f] + (0.85 if f == 0 else 0.8)
                h = min(1.45, self.storeys[f] - 1.4)
                u = 1.7
                while u < L - 1.2:
                    x = u if side > 0 else L - u
                    wins.append((x, z0, 0.85, h, f))
                    u += 2.7 if self.near else 3.6
            for x, z0, w, h, f in wins:
                cuts.append(cutter_for(T.wall_matrix(p0, p1, x, z0), w, h, self.rise(w, self.st["window"])))
            SB.boolean_cut(body, cuts)
            SC.add_bevel(body, 0.02)
            for k, (x, z0, w, h, f) in enumerate(wins):
                fm = T.wall_matrix(p0, p1, x, z0)
                o = dict(w=w, h=h, rise=self.rise(w, self.st["window"]))
                self.one_window("Seitenfenster %d %d" % (side, k), fm, o, self.st["wall"], ground=f == 0, front=False)
                # dahinter ein warmer Raum
                rm = Body("Seitenraum %d %d" % (side, k), self.M["h_room"], self.C["inside"], seed=70 + k, vary=0.04)
                rm.box((0, (self.zs[f] + self.zs[f + 1]) / 2 - z0, -1.6), (2.0, self.storeys[f] - 0.2, 0.08), step=1, dent=0.0, matrix=fm)
                for sx in (-1, 1):
                    rm.box((sx * 1.0, (self.zs[f] + self.zs[f + 1]) / 2 - z0, -0.95), (0.08, self.storeys[f] - 0.2, 1.3), step=1, dent=0.0,
                           matrix=fm)
                rm.box((0, self.zs[f] - z0 + 0.05, -0.95), (2.0, 0.08, 1.3), step=1, dent=0.0, matrix=fm)
                rm.box((0, self.zs[f + 1] - z0 - 0.15, -0.95), (2.0, 0.08, 1.3), step=1, dent=0.0, matrix=fm)
                rm.build()

    # Dach
    def roof(self):
        M, C, st, hw, E = self.M, self.C, self.st, self.hw, self.E
        y0 = self.sb - self.jetty
        a = math.radians(st["pitch"])
        if st["roof"] == "side":
            span = (self.D - y0) / 2 + 0.32
            yc = (y0 + self.D) / 2
            exposed = self.spec.get("exposed", {})
            # an freien Seiten steht das Dach über (Ortgang), an Brandwänden endet es bündig
            ends = (0.12 if -1 in exposed else 0.0, 0.12 if 1 in exposed else 0.0)
            holes, dormers = [], []
            x_start = -hw - ends[0]
            for dx in st["dormers"]:
                dw = 1.25
                yf = y0 + 0.55
                s0 = (yf - (yc - span)) / math.cos(a) - 0.25
                dormers.append((dx, yf, dw))
                holes.append((dx - dw / 2 - 0.06 - x_start, dx + dw / 2 + 0.06 - x_start, s0, s0 + 2.2))
            chim = []
            for side in st["chimneys"]:
                cx = side * (hw - 0.55)
                cy = yc + 0.25
                chim.append((cx, cy))
                s0 = (cy - 0.45 - (yc - span)) / math.cos(a)
                holes.append((cx - 0.4 - x_start, cx + 0.4 - x_start, s0, s0 + 3.0))
            frame = Matrix.Translation((0, yc, 0))
            ridge, zf, _ = T.cozy_roof(M, C, "Dach", frame, self.W, span, E, st["pitch"], "h_roof", cap_mat="h_roof_cap", ends=ends,
                                       holes=holes, seed=40, back_simple=True, verge=bool(self.spec.get("exposed")),
                                       front_simple=not self.near)
            self.ridge = ridge

            def roof_z(y):
                return zf(y - yc)
            for i, (dx, yf, dw) in enumerate(dormers):
                self.dormer("Gaube %d" % (i + 1), dx, yf, dw, roof_z, a, seed=50 + i)
            for i, (cx, cy) in enumerate(chim):
                T.chimney(M, C, "Schornstein %d" % (i + 1), (cx, cy, roof_z(cy) - 0.4), (0.6, 0.75), ridge + 0.75,
                          "brick" if st["wall"] != "brick" else "pub_brick", pots=1 + i % 2, seed=60 + i)
        else:
            L = self.D - y0 + 0.3
            yc = (y0 - 0.3 + self.D) / 2
            span = hw + 0.12
            frame = Matrix(((0, -1, 0, 0), (1, 0, 0, yc), (0, 0, 1, 0), (0, 0, 0, 1)))
            ridge, zf, _ = T.cozy_roof(M, C, "Dach", frame, L, span, E, st["pitch"], "h_roof", cap_mat="h_roof_cap", ends=(0.0, 0.0),
                                       seed=40, back_simple=False, verge=False, front_simple=not self.near)
            self.ridge = ridge
            # Ortgangbretter und Spitze am Giebel vorn
            w = Body("Ortgangbretter", M["h_join_dark"], C["roof"], seed=41, vary=0.05, bevel=0.012)
            yf = y0 - 0.32
            for side in (-1, 1):
                w.span(Vector((side * (span + 0.02), yf, E - 0.1)), Vector((0.0, yf, ridge + 0.1)), 0.06, 0.24, step=0.5, dent=0.003)
            w.build()
            f = Body("Firstspitze", M["lamp_iron"], C["roof"], seed=42, bevel=0.003)
            f.tube([(0.0, yf, ridge + 0.14), (0.0, yf, ridge + 0.5)], 0.012, segs=8, round_ends=True)
            f.blob((0.0, yf, ridge + 0.32), 0.03, subdiv=1, lump=0.0)
            f.build()
            for i, side in enumerate(st["chimneys"]):
                cy = self.D - 1.6
                cx = side * 0.35
                T.chimney(M, C, "Schornstein %d" % (i + 1), (cx, cy, ridge - 0.9), (0.6, 0.7), ridge + 0.75,
                          "brick" if st["wall"] != "brick" else "pub_brick", pots=1 + i % 2, seed=60 + i)

    def dormer(self, name, x, yf, w, roof_z, a, seed=50):
        """Gaube: Wand im Putz des Hauses, Fenster mit Bogen, kleines Satteldach aus Ziegelreihen,
        hinten verschwindet alles im Dach."""
        M, C, st = self.M, self.C, self.st
        win_w, win_h = w - 0.42, 0.9
        z_base = roof_z(yf) - 0.3
        wz0 = roof_z(yf) + 0.1
        eaves = wz0 + win_h + 0.2
        dpitch = 45.0
        span = w / 2 + 0.1
        dridge = eaves + span * math.tan(math.radians(dpitch))
        # hinten: wo das Hauptdach die Firsthöhe der Gaube erreicht
        y_back = yf + (dridge + 0.15 - roof_z(yf)) / math.tan(a)
        b = Body(name + " Wand", M["h_wall"], C["roof"], seed=seed, vary=0.04)
        b.box((x, (yf + y_back) / 2, (z_base + eaves) / 2), (w, y_back - yf, eaves - z_base), step=0.5, dent=0.004)
        b.slab([(-w / 2, eaves - 0.04), (w / 2, eaves - 0.04), (0.0, dridge - 0.12)], 0.25,
               Matrix.Translation((x, yf, 0)) @ Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1))) @
               Matrix.Rotation(0, 4, "Z"), dent=0.003)
        wall = b.build()
        rise = self.rise(win_w, st["window"]) if st["window"] != "square" else 0.0
        fm = SC.front_matrix(x, wz0, yf)
        SB.boolean_cut(wall, [cutter_for(fm, win_w, win_h, rise)])
        SC.add_bevel(wall, 0.015)
        window(M, C, name + " Fenster", fm, win_w, win_h, rise, panes=(2, 2), curtains=self.near, seed=seed + 3)
        sl = Body(name + " Bank", M["trim"], C["roof"], seed=seed + 4, vary=0.06, bevel=0.01)
        sl.box((x, yf - 0.05, wz0 - 0.02), (win_w + 0.16, 0.1, 0.1), step=0.6, dent=0.003)
        sl.build()
        L = y_back - yf + 0.18
        frame = Matrix(((0, -1, 0, x), (1, 0, 0, yf - 0.18 + L / 2), (0, 0, 1, 0), (0, 0, 0, 1)))
        T.cozy_roof(M, C, name + " Dach", frame, L, span, eaves, dpitch, "h_roof", cap_mat="h_roof_cap", ends=(0.0, 0.0), seed=seed + 5,
                    back_simple=False, tile_w=0.24, row=0.2, verge=True)
        wd = Body(name + " Ortgang", M["h_join_dark"], C["roof"], seed=seed + 6, vary=0.05, bevel=0.01)
        yv = yf - 0.2
        for side in (-1, 1):
            wd.span(Vector((x + side * (span + 0.01), yv, eaves - 0.08)), Vector((x, yv, dridge + 0.08)), 0.05, 0.18, step=0.5, dent=0.002)
        wd.build()

    def eaves(self):
        M, C, st, hw = self.M, self.C, self.st, self.hw
        E = self.E
        yF = self.sb - self.jetty
        if st["roof"] == "front":
            # Traufen seitlich – vorn nur ein Gesimsband auf Traufhöhe unter dem Giebel
            b = Body("Gesims", M["trim"] if st["eaves"] == "cornice" else M["h_join_dark"], C["walls"], seed=11, vary=0.05, bevel=0.012)
            b.box((0, yF - 0.05, E - 0.04), (self.W + 0.01, 0.1, 0.12), step=0.6, dent=0.004)
            b.build()
            self.gutter_side()
            return
        g = Body("Traufe", M["h_join_dark"], C["roof"], seed=12, vary=0.05, bevel=0.012)
        # Untersicht und Traufbrett (schließen den Überstand)
        g.box((0, yF - 0.16, E - 0.03), (self.W, 0.34, 0.06), step=0.6, dent=0.003)
        g.box((0, yF - 0.31, E - 0.04), (self.W, 0.05, 0.2), step=0.6, dent=0.003)
        g.build()
        if st["eaves"] == "cornice":
            c = Body("Traufgesims", M["trim"], C["walls"], seed=13, vary=0.05, bevel=0.012)
            c.box((0, yF - 0.05, E - 0.24), (self.W + 0.005, 0.1, 0.12), step=0.6, dent=0.004)
            x = -hw + 0.12
            while x < hw - 0.1:
                c.box((x, yF - 0.09, E - 0.13), (0.09, 0.18, 0.1), step=1, dent=0.003, turn=(0, self.rnd.uniform(-2, 2), 0))
                x += 0.24
            c.build()
        else:
            rafters(M, C, "Sparrenköpfe", -hw, hw, yF - 0.32, E - 0.04)
        r = Body("Dachrinne und Fallrohr", M["bronze"], C["roof"], seed=14)
        r.tube([(-hw - 0.01, yF - 0.38, E + 0.0), (0, yF - 0.39, E - 0.015), (hw + 0.01, yF - 0.38, E + 0.0)], 0.055, segs=10,
               round_ends=True)
        side = self.spec.get("downpipe_side", 1)
        px = side * (hw - 0.09)
        if abs(px - self.door["x"]) > self.door["w"] / 2 + 0.25:
            r.tube([(px, yF - 0.38, E - 0.02), (px, yF - 0.13, E - 0.35), (px, self.sb - 0.08, E - 0.7), (px, self.sb - 0.08, 0.15),
                    (px, self.sb - 0.16, 0.03)], 0.033, segs=10, smooth=2, round_ends=True)
        r.build()

    def gutter_side(self):
        pass

    def timber(self):
        """Fachwerk: Schwelle, Rähm, Ständer neben den Fenstern, gebogene Streben, Knaggen unter der
        Vorkragung – dicke, weich gerundete Eichenbalken."""
        M, C, hw = self.M, self.C, self.hw
        yU = self.sb - self.jetty
        fm = T.wall_matrix(*self.upper_front)
        t = Body("Fachwerk", M["h_timber"], C["walls"], seed=15, vary=0.09, bevel=0.016)

        def tb(x0, x1, y0, y1):
            t.box((self.fx((x0 + x1) / 2), (y0 + y1) / 2, 0.035), (x1 - x0, y1 - y0, 0.07), step=0.6, dent=0.004, matrix=fm)
        top = self.E
        for f in range(1, len(self.storeys)):
            z0, z1 = self.zs[f], self.zs[f + 1] if f + 1 < len(self.zs) else top
            tb(-hw, hw, z0, z0 + 0.18)
            tb(-hw, hw, z1 - 0.16, z1)
            posts = {-hw + 0.08, hw - 0.08}
            wins = [o for o in self.upper if o["floor"] == f]
            for o in wins:
                posts.add(o["x"] - o["w"] / 2 - 0.08)
                posts.add(o["x"] + o["w"] / 2 + 0.08)
                tb(o["x"] - o["w"] / 2 - 0.16, o["x"] + o["w"] / 2 + 0.16, o["z"] - 0.14, o["z"])
                tb(o["x"] - o["w"] / 2 - 0.16, o["x"] + o["w"] / 2 + 0.16, o["z"] + o["h"], o["z"] + o["h"] + 0.14)
            for x in sorted(posts):
                tb(x - 0.08, x + 0.08, z0 + 0.16, z1 - 0.14)
            # gebogene Streben in den Feldern ohne Fenster an den Rändern
            for side in (-1, 1):
                xs = sorted(posts)
                a, b = (xs[0], xs[1]) if side < 0 else (xs[-2], xs[-1])
                if b - a > 0.45:
                    p0 = fm @ Vector((self.fx(a + 0.08 if side < 0 else b - 0.08), z0 + 0.2, 0.04))
                    p1 = fm @ Vector((self.fx(b - 0.06 if side < 0 else a + 0.06), z1 - 0.2, 0.04))
                    mid = p0.lerp(p1, 0.5) + (fm.to_3x3() @ Vector((-side * 0.08, 0.05, 0)))
                    t.tube([p0, mid, p1], 0.055, segs=8, smooth=2, round_ends=True)
        if self.jetty > 0:
            # Knaggen unter der Vorkragung
            for x in (-hw + 0.25, -hw / 3, hw / 3, hw - 0.25):
                c = Vector((x, self.sb, self.zs[1] - 0.05))
                t.tube([c + Vector((0, 0.02, -0.4)), c + Vector((0, -self.jetty * 0.5, -0.12)), c + Vector((0, -self.jetty + 0.04, 0.02))],
                       0.06, segs=8, smooth=2, round_ends=True)
            t.box((0, yU + 0.15, self.zs[1] - 0.02), (self.W, 0.3 + self.jetty, 0.14), step=0.6, dent=0.004)
        t.build()

    def garden(self):
        """Vorgarten: niedrige Mauer mit Pforte, Plattenweg, zwei Beete (Pflanzplätze)."""
        M, C, hw, sb = self.M, self.C, self.hw, self.sb
        px = self.door["x"]
        wl = Body("Gartenmauer", M["h_ground"] if self.st["ground"] == "ashlar" else M["stone"], C["walls"], seed=16, vary=0.08, bevel=0.03)
        for a, b in ((-hw, px - 0.55), (px + 0.55, hw)):
            if b - a > 0.2:
                wl.box(((a + b) / 2, 0.15, 0.3), (b - a, 0.3, 0.6), step=0.5, dent=0.008)
                wl.box(((a + b) / 2, 0.15, 0.63), (b - a + 0.04, 0.36, 0.08), step=0.5, dent=0.006)
        for x in (px - 0.6, px + 0.6):
            wl.box((x, 0.15, 0.45), (0.3, 0.34, 0.9), step=0.5, dent=0.006)
            wl.lathe([(0.0, 0.0), (0.12, 0.0), (0.13, 0.05), (0.08, 0.12), (0.0, 0.15)], (x, 0.15, 0.9), segs=14)
        wl.build()
        gate = Body("Gartenpforte", M["h_join"], C["walls"], seed=17, vary=0.06, bevel=0.008)
        for i in range(7):
            x = px - 0.4 + 0.8 * i / 6
            gate.slab([(-0.035, 0.05), (0.035, 0.05), (0.035, 0.72), (0.0, 0.78), (-0.035, 0.72)], 0.025,
                      Matrix.Translation((x, 0.25, 0)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))), dent=0.001)
        for zz in (0.2, 0.6):
            gate.box((px, 0.24, zz), (0.84, 0.03, 0.06), step=1, dent=0.002)
        gate.build()
        pv = Body("Gartenweg", M["slab"], C["walls"], seed=18, vary=0.1, bevel=0.015)
        y = 0.35
        while y < sb - 0.1:
            d = min(0.42, sb - y)
            pv.box((px + self.rnd.uniform(-0.03, 0.03), y + d / 2, 0.02), (0.8, d - 0.03, 0.04), step=1, dent=0.004,
                   turn=(0, 0, self.rnd.uniform(-2, 2)))
            y += d
        pv.build()
        for a, b in ((-hw + 0.1, px - 0.5), (px + 0.5, hw - 0.1)):
            if b - a > 0.4:
                e = Body("Beet", M["soil"], C["pots"], seed=19, vary=0.1)
                e.blob(((a + b) / 2, (0.3 + sb) / 2, -0.02), 0.5, subdiv=2, lump=0.1, scale=((b - a) / 1.0, (sb - 0.4) / 1.0, 0.12))
                e.build()
                self.spot("bed", ((a + b) / 2, (0.3 + sb) / 2, 0.03), (b - a - 0.1, sb - 0.5, 0.9))

    def interior(self):
        """Warme Räume hinter den Fenstern (leuchten im Spiel leicht von selbst)."""
        M, C, hw, sb = self.M, self.C, self.hw, self.sb
        rm = Body("Räume", M["h_room"], C["inside"], seed=24, vary=0.05)
        for f in range(len(self.storeys)):
            yF = (sb - self.jetty) if f > 0 else sb
            y0 = yF + 0.3
            deep = 2.2 if self.near else 1.2
            z0, z1 = self.zs[f], self.zs[f + 1] if f + 1 < len(self.zs) else self.E
            rm.box((0, y0 + deep, (z0 + z1) / 2), (self.W - 0.62, 0.08, z1 - z0), step=1, dent=0.0)
            rm.box((0, y0 + deep / 2, z0 + 0.04), (self.W - 0.62, deep, 0.08), step=1, dent=0.0)
            rm.box((0, y0 + deep / 2, z1 - 0.12), (self.W - 0.62, deep, 0.08), step=1, dent=0.0)
            for s in (-1, 1):
                rm.box((s * (hw - 0.35), y0 + deep / 2, (z0 + z1) / 2), (0.06, deep, z1 - z0), step=1, dent=0.0)
            if self.near and self.st["window"] and f < len(self.storeys):
                SC.add_light("Zimmerlicht", (0.0, y0 + 0.9, z0 + 2.2), 2700, 25, C["light"], radius=0.15)
        rm.build()

    def place_spots(self):
        """Pflanzplätze an der Front: Kübel neben der Tür (nur nahe Häuser, genug Gehweg), Kletter-
        pflanze an einer freien Wandstelle, Laternenplatz (wird vom Bau-Script verwendet)."""
        d = self.door
        hw, sb = self.hw, self.sb
        # freie Wandstreifen im Erdgeschoss (zwischen Tür/Fenstern und Hauskanten)
        edges = sorted([(-hw, -hw)] + [(o["x"] - o["w"] / 2 - 0.12, o["x"] + o["w"] / 2 + 0.12) for o in self.ground] +
                       [(d["x"] - d["w"] / 2 - 0.2, d["x"] + d["w"] / 2 + 0.2), (hw, hw)])
        gaps = []
        for (a0, a1), (b0, b1) in zip(edges, edges[1:]):
            if b0 - a1 > 0.3:
                gaps.append((a1, b0))
        if sb < 0.5 and self.near:
            # Kübel neben der Tür, wenn dort Platz ist
            for side in (-1, 1):
                x = d["x"] + side * (d["w"] / 2 + 0.38)
                if any(a + 0.2 < x < b - 0.2 for a, b in gaps) and self.rnd.random() < 0.6:
                    self.spot("pot", (x, -0.3, 0.0), (0.5, 0.5, 1.0))
        # Kletterpflanze am breitesten freien Streifen (Hauswand), sonst neben der Tür
        if gaps:
            a, b = max(gaps, key=lambda g: g[1] - g[0])
            w = min(1.6, b - a)
            c = (a + b) / 2
            # nur so hoch, wie die Wand darüber frei ist (keine Fenster, Briefkasten, Markise)
            top = self.E - 0.8
            for o in self.upper:
                if abs(o["x"] - c) < o["w"] / 2 + w / 2 + 0.1:
                    top = min(top, o["z"] - 0.15)
            if self.st.get("hood") and abs(d["x"] - c) < d["w"] / 2 + w / 2 + 0.4:
                top = min(top, d["h"] + 0.2)
            if top > 1.2:
                self.spot("climber", (c, sb - 0.06, 0.0), (w, 0.3, top))
        self.gaps = gaps

    def lantern_spot(self, prefer=None):
        """Platz für die hängende Straßenlaterne (Godot-Hauskoordinaten: x, y = Höhe der Wandplatte,
        z = vor der Front): in einem freien Wandstreifen nahe der Tür, unter dem ersten Obergeschoss."""
        d = self.door
        best = None
        for a, b in getattr(self, "gaps", []):
            if b - a < 0.3:
                continue
            x = min(max((a + b) / 2, a + 0.15), b - 0.15)
            if self.st["hood"] and abs(x - d["x"]) < d["w"] / 2 + 0.55:
                continue  # nicht aus dem Vordach heraus
            cost = abs(x - (prefer if prefer is not None else d["x"]))
            if best is None or cost < best[0]:
                best = (cost, x)
        if best is None:
            return None
        z = self.zs[1] - 0.35
        return (round(best[1], 3), round(z, 3), round(-self.sb, 3))
