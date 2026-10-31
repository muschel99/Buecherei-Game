"""Die Bücherei-Fassade als Baukasten (Etappe 6b): Statt eines festen Modells entstehen austauschbare
Teile, die das Spiel nach der Wahl in der App „Fassade“ zusammensetzt (LibraryFacade):

    core                  Dach, Schornstein, Rinne, Gesimse, Zahnschnitt, Laternen, Rückwand, Sockel hinten
                          und Ankerpunkte (leere Knoten „Anchor_…“) für Markisen und Ampeln
    ground_<art>          Erdgeschoss: classic (Pilaster, Füllungen), beadboard (Nut und Feder),
                          victorian (Kanneluren, Konsolen, Zierrahmen), stone (Naturstein) – je mit
                          Schildkästen und einer geschlossenen Montageplatte für den Briefkasten
    upper_<fenster>       Obergeschoss: sash (Sprossenfenster), arched (Bogenfenster), bay (Erker) –
                          Wand, Fenster, Fassungen, Ecksteine, Räume dahinter, Anker „Anchor_box_<n>“
    awning_<form>         Markise für ein Schaufenster: classic (Volant), dome (Korb), box (Kasten)
    door_<art>            Türblatt (Scharnier-Koordinaten der Ladentür): glazed, panelled, arched, cottage
    box_<art>             Blumenkasten: wood, zinc, terracotta, wicker (mit „FacadeSpot_box“)
    basket_<art>          Ampel mit Wandarm: bowl (Tonschale), wire (Draht und Moos), wicker (Weide)

Austauschbare Flächen haben Rollen-Materialien (facade_paint, facade_paint_dark, facade_upper_wall,
facade_quoin, facade_frame, facade_awning, facade_door, facade_stone) – das Spiel färbt bzw. ersetzt sie.
Dazu schreibt das Script die Materialien der Auswahl (Wandputz/Stein/Holz, Markisenstoffe) und die
Datenblätter data/facade/*.tres (FacadeOption).

Aufruf:  blender -b --factory-startup --python tools/blender/build_storybook_facade.py -- [teil …] [--data]
Ohne Teile: alles. Teile wie oben (z. B. ground_classic door_glazed), --data nur Datenblätter + Materialien.
Ergebnis: assets/models/facade/<teil>.glb, Quellen assets/models/source/facade/<teil>.blend.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_storybook_library as L  # noqa: E402
import storybook_common as SC  # noqa: E402
import storybook_houses as SH  # noqa: E402
import storybook_lib as SB  # noqa: E402
import storybook_town as T  # noqa: E402
from storybook_lib import Body  # noqa: E402

MODEL_DIR = os.path.join(SC.ROOT, "assets", "models", "facade")
SOURCE_DIR = os.path.join(SC.ROOT, "assets", "models", "source", "facade")
DATA_DIR = os.path.join(SC.ROOT, "data", "facade")
MARK = "; Erzeugt von tools/blender/build_storybook_facade.py"

OUT, FRONT, LEFT, DIAG = L.OUT, L.FRONT, L.LEFT, L.DIAG
GROUND, FASCIA, TOP, E = L.GROUND, L.FASCIA, L.TOP, L.E
WIN, DOOR = L.WIN, L.DOOR
DIAG_LEN = L.DIAG_LEN
# Briefkasten (Rückgabekasten-Einwurf): Mitte entlang der Schräge, Höhe, Montageebene vor der Wand.
# Muss zu GameConfig.facade_slot_out passen (dort sitzt der Einwurf auf der Platte).
SLOT_X, SLOT_Z, SLOT_OUT = 2.555, 1.0, 0.07
SLOT_BOARD = (0.5, 0.46)
# Obere Fenster: Breite, Höhe, Unterkante
UP_W, UP_H, UP_Z = 0.95, 1.45, TOP + 0.85
# Markise: Oberkante unter dem Schildkasten, Ausladung, Höhe
AWN_TOP, AWN_REACH, AWN_DROP = FASCIA[0] - 0.04, 0.95, 0.5


# --- Materialien (Rollen) ---

def role_materials(M):
    mk = SC.make_material
    M["green"] = mk("facade_paint", (0.13, 0.25, 0.18), grain="paint", rough=0.7, vary=0.06, bump=0.12)
    M["green_dark"] = mk("facade_paint_dark", (0.09, 0.18, 0.13), grain="paint", rough=0.7, vary=0.05, bump=0.12)
    M["h_wall"] = mk("facade_upper_wall", (0.6, 0.38, 0.27), grain="brick", rough=0.92, vary=0.07, bump=0.28, color2=(0.57, 0.5, 0.42))
    M["quoin"] = mk("facade_quoin", (0.85, 0.77, 0.62), grain="stone", rough=0.9, vary=0.1, bump=0.3)
    M["h_join"] = mk("facade_frame", (0.9, 0.86, 0.76), grain="paint", rough=0.72, vary=0.06, bump=0.12)
    M["awning"] = mk("facade_awning", (0.93, 0.88, 0.78), grain="fabric", rough=0.95, vary=0.04, stripes=0.13, color2=(0.62, 0.2, 0.18), wind=0.035)
    M["door"] = mk("facade_door", (0.13, 0.25, 0.18), grain="paint", rough=0.7, vary=0.06, bump=0.12)
    M["fascia"] = mk("facade_fascia", (0.24, 0.33, 0.27), grain="paint", rough=0.7, vary=0.06, bump=0.12)
    M["stone_wall"] = mk("facade_stone", (0.84, 0.76, 0.62), grain="ashlar", rough=0.92, vary=0.09, bump=0.3, color2=(0.62, 0.58, 0.52))
    M["h_room"] = mk("Zimmer warm 1", SH.ROOMS[0], glow=0.3, rough=0.95, vary=0.05, bump=0.05)
    M["moss"] = mk("Moos Ampel", (0.32, 0.42, 0.2), grain="fabric", rough=1.0, vary=0.15, bump=0.5)
    M["terracotta"] = mk("Terrakotta Kasten", (0.74, 0.44, 0.3), rough=0.92, vary=0.08, scale=6)


def fresh(title):
    """Leere Szene mit Materialien und Sammlungen (wie die Häuser)."""
    SC.GAME_MATERIALS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    SB.BEVEL_SEGMENTS = (2, 1)
    M = SC.materials()
    L.mats(M)
    role_materials(M)
    root = SB.collection(title)
    SC.SPOTS["coll"] = None
    C = {k: SB.collection(v, root) for k, v in (("walls", "Mauern"), ("roof", "Dach"), ("windows", "Fenster"), ("shop", "Ladenfront"),
                                                ("inside", "Räume"), ("pots", "Kästen"), ("deco", "Deko"), ("anchors", "Anker"),
                                                ("light", "Licht"), ("plants", "Pflanzplätze"))}
    return M, C


def anchor(C, name, matrix):
    """Leerer Ankerpunkt (im Spiel ein Node3D: +Z nach außen, +Y oben, +X entlang der Wand)."""
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.3
    e.matrix_world = matrix
    C["anchors"].objects.link(e)
    return e


# --- Kern ---

def build_core():
    M, C = fresh("Fassade Kern")
    rnd = random.Random(1924)
    L.plinth(M, C, rnd)
    L.back_skin(M, C)
    L.roof(M, C)
    c = Body("Gesimse oben", M["trim"], C["walls"], seed=33, vary=0.05, bevel=0.012)
    T.band(c, OUT, (0, 2, 3, 4), TOP + 0.02, 0.12, -0.02, 0.1)
    T.band(c, OUT, (0, 2, 3, 4), E - 0.32, 0.12, -0.02, 0.1)
    T.band(c, OUT, (0, 2, 3, 4), E - 0.08, 0.1, -0.02, 0.3)
    c.build()
    d = Body("Zahnschnitt", M["trim"], C["walls"], seed=34, vary=0.06, bevel=0.008)
    for i in (2, 3, 4):
        p0, p1 = T.seg(OUT, i)
        seg_l = T.seg_len(p0, p1)
        fm = T.wall_matrix(p0, p1)
        x = 0.12
        while x < seg_l - 0.1:
            d.box((x, E - 0.15, 0.09), (0.08, 0.1, 0.18), step=1, dent=0.002, turn=(0, 0, rnd.uniform(-2, 2)), matrix=fm)
            x += 0.2
    d.build()
    T.floor_slab(M, C, "Obergeschoss Decke", "h_room", OUT, 0.29, E - 0.3, 0.08)
    # Wandlaternen (vor jeder Erdgeschoss-Front, Platte 9 cm vor der Wand)
    for seg, x, name in ((FRONT, 3.75, "vorn"), (LEFT, 5.33, "links")):
        T.placed(C["deco"], T.canon(*seg, x, 0.0, 0.09), T.wall_lantern, M, C, "Wandlaterne %s" % name, 0.0, 2.55, seed=130)
    # Pflanzplatz für den Kübel an der Gassenwand (wie bisher; Greenery bepflanzt ihn)
    pm = T.canon(*LEFT, 5.78, GROUND, 0.32)
    SH.plant_spot(C, "pot", tuple(pm @ Vector((0, 0, 0))), (0.5, 0.5, 1.0), facing=-90.0)
    # Schild-Balken (seit Etappe 6c im Kern: Farbe, Holz oder Stein wählbar, Rolle facade_fascia)
    for seg, win_x, side_name in ((FRONT, L.FRONT_WIN_X, "vorn"), (LEFT, L.LEFT_WIN_X, "links")):
        p0, p1 = seg
        seg_l = T.seg_len(p0, p1)
        signs = [(win_x - seg_l / 2, 3.6, SC.sign_material("library", "fascia"), 2048 / 296)]
        T.fascia(M, C, "Schildkasten %s" % side_name, T.wall_matrix(p0, p1, seg_l / 2), seg_l + 0.04, FASCIA[0], FASCIA[1] - FASCIA[0],
                 "fascia", signs=signs, depth=0.22)
    T.fascia(M, C, "Schildkasten Tür", T.wall_matrix(DIAG[0], DIAG[1], DIAG_LEN / 2), DIAG_LEN + 0.04, FASCIA[0], FASCIA[1] - FASCIA[0],
             "fascia", signs=[(0.0, 2.6, SC.sign_material("library", "door"), 1536 / 267)], depth=0.22)
    # Anker: Markisen unter dem Schildkasten, Ampeln an den Ecken der Schräge
    anchor(C, "Anchor_awning_front", T.canon(*FRONT, L.FRONT_WIN_X, AWN_TOP, 0.06))
    anchor(C, "Anchor_awning_left", T.canon(*LEFT, L.LEFT_WIN_X, AWN_TOP, 0.06))
    for k, x in ((1, 0.18), (2, DIAG_LEN - 0.18)):
        anchor(C, "Anchor_basket_%d" % k, T.canon(*DIAG, x, TOP + 0.05, 0.0))
    return C, ("walls", "roof", "deco")


# --- Erdgeschoss ---

def build_ground(variant):
    M, C = fresh("Fassade Erdgeschoss %s" % variant)
    for seg, win_x, side_name in ((FRONT, L.FRONT_WIN_X, "vorn"), (LEFT, L.LEFT_WIN_X, "links")):
        ground_side(M, C, variant, seg, win_x, side_name)
    ground_diagonal(M, C, variant)
    return C, ("shop", "walls")


def _gb(body, fm):
    def gb(c, s, step=0.6, dent=0.003):
        body.box(c, s, step=step, dent=dent, matrix=fm)
    return gb


def fill_region(M, C, variant, fm, a, b, z0, z1, name, seed):
    """Wandfeld (entlang der Wand von a bis b, Höhe z0 bis z1) in der Art des Erdgeschosses."""
    if b - a < 0.06 or z1 - z0 < 0.04:
        return
    rnd = random.Random(seed)
    if variant == "stone":
        s = Body(name + " Stein", M["stone_wall"], C["walls"], seed=seed, vary=0.03, bevel=0.01)
        s.box(((a + b) / 2, (z0 + z1) / 2, 0.035), (b - a, z1 - z0, 0.07), step=0.6, dent=0.002, matrix=fm)
        s.build()
        return
    g = Body(name, M["green"], C["shop"], seed=seed, vary=0.04, bevel=0.012)
    gb = _gb(g, fm)
    gb(((a + b) / 2, (z0 + z1) / 2, 0.03), (b - a, z1 - z0, 0.06))
    w, h = b - a, z1 - z0
    if variant == "classic":
        if w > 0.5 and h > 0.5:
            n = max(1, round((h - 0.4) / 1.0))
            for j in range(n):
                y0 = z0 + 0.3 + (h - 0.5) * j / n
                y1 = z0 + 0.3 + (h - 0.5) * (j + 1) / n - 0.1
                gb(((a + b) / 2, (y0 + y1) / 2, 0.075), (w - 0.36, y1 - y0, 0.03))
    elif variant == "beadboard":
        # Nut und Feder: senkrechte Bretter mit Perlstab an den Fugen, unten Fußleiste, oben Riegel
        if h > 0.3:
            gb(((a + b) / 2, z0 + 0.08, 0.07), (w, 0.16, 0.08))
            gb(((a + b) / 2, z1 - 0.05, 0.065), (w, 0.1, 0.07))
            beads = Body(name + " Perlstäbe", M["green"], C["shop"], seed=seed + 1, vary=0.03)
            x = a + 0.1
            while x < b - 0.06:
                beads.tube([fm @ Vector((x, z0 + 0.16, 0.06)), fm @ Vector((x, z1 - 0.1, 0.06))], 0.006, segs=6)
                x += 0.1
            beads.build()
    elif variant == "victorian":
        if w > 0.35 and h > 0.35:
            n = max(1, round((h - 0.3) / 0.9))
            frames = Body(name + " Zierrahmen", M["green"], C["shop"], seed=seed + 2, vary=0.03)
            rosettes = Body(name + " Rosetten", M["gold"], C["shop"], seed=seed + 3, vary=0.04)
            for j in range(n):
                y0 = z0 + 0.22 + (h - 0.36) * j / n
                y1 = z0 + 0.22 + (h - 0.36) * (j + 1) / n - 0.12
                hw, hh = (w - 0.32) / 2, (y1 - y0) / 2
                cx, cy = (a + b) / 2, (y0 + y1) / 2
                gb((cx, cy, 0.072), (w - 0.4, y1 - y0 - 0.08, 0.024))
                for inset in (0.0, 0.05):
                    pts = [(cx - hw + inset, cy - hh + inset), (cx + hw - inset, cy - hh + inset), (cx + hw - inset, cy + hh - inset),
                           (cx - hw + inset, cy + hh - inset), (cx - hw + inset, cy - hh + inset)]
                    frames.tube([fm @ Vector((x, y, 0.07 + inset * 0.1)) for x, y in pts], 0.011 if inset == 0.0 else 0.007, segs=6)
                if hw > 0.18 and hh > 0.18:
                    rosettes.blob(fm @ Vector((cx, cy, 0.095)), 0.03, subdiv=1, lump=0.05, scale=(1, 1, 0.5))
                    for k in range(6):
                        ang = math.tau * k / 6 + rnd.uniform(-0.1, 0.1)
                        rosettes.blob(fm @ Vector((cx + math.cos(ang) * 0.045, cy + math.sin(ang) * 0.045, 0.09)), 0.016, subdiv=1,
                                      lump=0.04, scale=(1, 1, 0.5))
            frames.build()
            rosettes.build()
    g.build()


def pilasters(M, C, variant, fm, xs, name, seed):
    """Pilaster in der Art der Front (Stein: Ecksteine an den Enden)."""
    if variant == "stone":
        q = Body(name + " Ecksteine", M["stone_wall"], C["walls"], seed=seed, vary=0.08, bevel=0.014)
        for x in xs:
            z, j = GROUND + 0.05, 0
            while z + 0.3 < FASCIA[0]:
                wdt = 0.34 if j % 2 == 0 else 0.24
                q.box((x, z + 0.14, 0.06), (wdt, 0.27, 0.12), step=0.6, dent=0.004, matrix=fm)
                z += 0.3
                j += 1
        q.build()
        return
    g = Body(name, M["green"], C["shop"], seed=seed, vary=0.04, bevel=0.012)
    gb = _gb(g, fm)
    gold = Body(name + " Gold", M["gold"], C["shop"], seed=seed + 1, vary=0.04)
    for x in xs:
        if variant == "beadboard":
            gb((x, (GROUND + FASCIA[0]) / 2, 0.06), (0.22, FASCIA[0] - GROUND, 0.12))
            gb((x, FASCIA[0] - 0.08, 0.08), (0.28, 0.16, 0.16))
            continue
        gb((x, (GROUND + FASCIA[0]) / 2, 0.08), (0.3, FASCIA[0] - GROUND, 0.16))
        gb((x, GROUND + 0.2, 0.1), (0.36, 0.4, 0.2))
        gb((x, FASCIA[0] - 0.12, 0.12), (0.36, 0.24, 0.24))
        gold.tube([fm @ Vector((x - 0.17, FASCIA[0] - 0.06, 0.25)), fm @ Vector((x + 0.17, FASCIA[0] - 0.06, 0.25))], 0.04, segs=10,
                  round_ends=True)
        if variant == "victorian":
            # Kanneluren und eine Konsole unter dem Schildkasten
            for dx in (-0.07, 0.0, 0.07):
                g.tube([fm @ Vector((x + dx, GROUND + 0.45, 0.165)), fm @ Vector((x + dx, FASCIA[0] - 0.3, 0.165))], 0.014, segs=8,
                       round_ends=True)
            gb((x, FASCIA[0] + 0.12, 0.2), (0.22, 0.3, 0.2))
            gold.blob(fm @ Vector((x, FASCIA[0] + 0.05, 0.31)), 0.035, subdiv=1, lump=0.04, scale=(1, 1, 0.6))
    g.build()
    gold.build()


def ground_side(M, C, variant, seg, win_x, side_name):
    """Eine Ladenseite (vorn oder links): Fensterrahmen, Brüstung, Felder, Pilaster, Schildkasten."""
    p0, p1 = seg
    seg_l = T.seg_len(p0, p1)
    fm = T.wall_matrix(p0, p1)
    x0, x1 = win_x - WIN["w"] / 2, win_x + WIN["w"] / 2
    seed = 300 if side_name == "vorn" else 400
    # Seit Etappe 6c bleibt das Feld um das Fenster frei (x0 - 0,1 … x1 + 0,1, ganze Höhe): Fenster,
    # Rahmen, Bank und Brüstung baut die Fassade in Godot passend zur gewählten Form.
    regions = [
        (0.0, x0 - 0.1, GROUND, FASCIA[0]),                            # links neben dem Fenster
        (x1 + 0.1, seg_l, GROUND, FASCIA[0]),                          # rechts
    ]
    for k, (a, b, z0, z1) in enumerate(regions):
        fill_region(M, C, variant, fm, a, b, z0, z1, "Feld %s %d" % (side_name, k + 1), seed + 10 + k)
    xs = [x for x in (0.16, x0 - 0.16, x1 + 0.16, seg_l - 0.16) if 0.1 < x < seg_l - 0.1]
    if variant == "stone":
        xs = [0.17, seg_l - 0.17]
    pilasters(M, C, variant, fm, xs, "Pilaster %s" % side_name, seed + 20)
    if variant == "victorian":
        dent = Body("Zahnschnitt %s" % side_name, M["green_dark"], C["shop"], seed=seed + 30, vary=0.04, bevel=0.006)
        x = 0.1
        while x < seg_l - 0.08:
            dent.box((x, FASCIA[0] - 0.035, 0.22), (0.06, 0.07, 0.1), step=1, dent=0.002, matrix=fm)
            x += 0.13
        dent.build()


def ground_diagonal(M, C, variant):
    """Die Schräge mit der Tür: Türrahmen, Felder links, über der Tür und rechts – rechts eine
    geschlossene Montageplatte mit Rahmen für den Briefkasten (kein Loch mehr), Schildkasten."""
    p0, p1 = DIAG
    seg_l = DIAG_LEN
    fm = T.wall_matrix(p0, p1)
    dc = seg_l / 2
    d0, d1 = dc - DOOR["w"] / 2, dc + DOOR["w"] / 2
    # Seit Etappe 6c bleibt das Feld um die Tür frei (d0 - 0,12 … d1 + 0,12): Türöffnung, Seiten- und
    # Oberlichter baut die Fassade in Godot passend zur gewählten Tür.
    fill_region(M, C, variant, fm, 0.0, d0 - 0.12, GROUND, FASCIA[0], "Feld Tür links", 510)
    # Rechts der Tür: unter und über der Montageplatte das Feld, dazwischen schmale Leisten
    a, b = d1 + 0.12, seg_l
    bw, bh = SLOT_BOARD
    bz0, bz1 = SLOT_Z - bh / 2, SLOT_Z + bh / 2
    fill_region(M, C, variant, fm, a, b, GROUND, bz0 - 0.04, "Feld Briefkasten unten", 512)
    fill_region(M, C, variant, fm, a, b, bz1 + 0.04, FASCIA[0], "Feld Briefkasten oben", 513)
    mat = M["stone_wall"] if variant == "stone" else M["green"]
    board = Body("Briefkasten Platte", mat, C["shop"], seed=514, vary=0.03, bevel=0.008)
    # Grundplatte über die ganze Breite (lückenlos zwischen den Feldern), davor die Montageplatte
    board.box(((a + b) / 2, SLOT_Z, 0.03), (b - a, bh + 0.1, 0.06), step=0.6, dent=0.002, matrix=fm)
    board.box((SLOT_X, SLOT_Z, SLOT_OUT / 2), (bw, bh, SLOT_OUT), step=0.6, dent=0.0015, matrix=fm)
    board.build()
    frame = Body("Briefkasten Rahmen", M["green_dark"] if variant != "stone" else M["stone_wall"], C["shop"], seed=515, vary=0.04)
    hw, hh = bw / 2 + 0.025, bh / 2 + 0.025
    pts = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh), (-hw, -hh)]
    frame.tube([fm @ Vector((SLOT_X + x, SLOT_Z + y, SLOT_OUT - 0.002)) for x, y in pts], 0.016 if variant != "stone" else 0.024, segs=8)
    frame.build()
    if variant == "stone":
        pilasters(M, C, variant, fm, [0.17, seg_l - 0.17], "Ecksteine Schräge", 520)


# Obergeschoss: seit Etappe 6c in Godot gebaut (scripts/world/library_facade.gd) – Mauerwerk mit Löchern in
# der Form der gewählten Fenster, Fenster aus WindowUnit.


# --- Markisen (im Rahmen canon: Wand bei y = 0, außen -y, Mitte x = 0, Oberkante z = 0) ---

def build_awning(shape):
    M, C = fresh("Markise %s" % shape)
    width = WIN["w"] + 0.4
    if shape == "classic":
        T.cloth_awning(M, C, "Markise", width, 0.0, AWN_REACH, AWN_DROP, valance=0.22, mat="awning", seed=7)
    elif shape == "dome":
        dome_awning(M, C, width)
    else:
        box_awning(M, C, width)
    return C, ("shop", "deco", "walls")


def dome_awning(M, C, width):
    """Korbmarkise: ein Viertel-Zylinder vom Kasten zur Vorderkante, an den Enden runde Ohren,
    unten eine Bogenkante. Gestell aus Eisen."""
    r = AWN_REACH * 0.9
    cloth = Body("Markise Stoff", M["awning"], C["shop"], seed=8, vary=0.03)

    def surface(u, v, rr):
        # Viertelkreis um die Achse (y = 0, z = -r): 0° = oben an der Wand, 90° = vorn unten
        ang = v * math.pi / 2
        x = -width / 2 + width * u
        return Vector((x, -math.sin(ang) * rr, -r + math.cos(ang) * rr))
    nu, nv = 40, 14
    bm = cloth.bm
    outer = [[bm.verts.new(surface(i / nu, j / nv, r)) for j in range(nv + 1)] for i in range(nu + 1)]
    inner = [[bm.verts.new(surface(i / nu, j / nv, r - 0.012)) for j in range(nv + 1)] for i in range(nu + 1)]
    faces = []
    for i in range(nu):
        for j in range(nv):
            faces.append(bm.faces.new((outer[i][j], outer[i + 1][j], outer[i + 1][j + 1], outer[i][j + 1])))
            faces.append(bm.faces.new((inner[i][j + 1], inner[i + 1][j + 1], inner[i + 1][j], inner[i][j])))
    for i in range(nu):
        for j in (0, nv):
            faces.append(bm.faces.new((outer[i][j], inner[i][j], inner[i + 1][j], outer[i + 1][j])))
    for i in (0, nu):
        for j in range(nv):
            faces.append(bm.faces.new((outer[i][j], outer[i][j + 1], inner[i][j + 1], inner[i][j])))
    cloth._finish_island([v for row in outer + inner for v in row], faces)
    # Ohren an den Enden (Viertelscheiben)
    for side in (-1, 1):
        pts = [(0.0, 0.0)] + [(-math.sin(math.pi / 2 * k / 12) * r, -r + math.cos(math.pi / 2 * k / 12) * r) for k in range(13)]
        m = Matrix.Translation((side * width / 2 - (0.012 if side > 0 else 0.0), 0, 0)) @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        cloth.slab(pts, 0.012, m, dent=0.0)
    cloth.build()
    iron = Body("Markise Gestell", M["lamp_iron"], C["deco"], seed=9, vary=0.03, bevel=0.003)
    for side in (-1, 1):
        x = side * (width / 2 + 0.008)
        iron.tube([(x, -math.sin(math.pi / 2 * k / 10) * (r + 0.01), -r + math.cos(math.pi / 2 * k / 10) * (r + 0.01)) for k in range(11)],
                  0.008, segs=6, round_ends=True)
    iron.tube([(-width / 2 - 0.01, -r - 0.01, -r), (width / 2 + 0.01, -r - 0.01, -r)], 0.01, segs=8, round_ends=True)
    iron.build()
    # Bogenkante: kleine Halbkreise unter der Vorderkante
    val = Body("Markise Bogenkante", M["awning"], C["shop"], seed=10, vary=0.03)
    n = int(width / 0.22)
    for k in range(n):
        cx = -width / 2 + width * (k + 0.5) / n
        pts = [(cx + math.cos(math.pi * t / 8) * width / n / 2, -math.sin(math.pi * t / 8) * 0.09) for t in range(9)]
        val.slab(pts[::-1], 0.012, Matrix.Translation((0, -r + 0.006, -r)) @ Matrix.Rotation(math.radians(90), 4, "X"), dent=0.0)
    val.build()


def box_awning(M, C, width):
    """Kastenmarkise: Kasten an der Wand, gerade schräge Stoffbahn, Volant mit Wellenkante,
    Gelenkarme seitlich."""
    drop = AWN_DROP * 0.85
    box = Body("Markise Kasten", M["green"], C["walls"], seed=11, vary=0.03, bevel=0.01)
    box.box((0, -0.07, -0.06), (width + 0.1, 0.14, 0.12), step=0.5, dent=0.002)
    box.build()
    cloth = Body("Markise Stoff", M["awning"], C["shop"], seed=12, vary=0.03)
    a = Vector((0, -0.12, -0.1))
    b = Vector((0, -AWN_REACH, -drop))
    cloth.sheet(Vector((-width / 2, a.y, a.z)), Vector((width, 0, 0)), Vector((0, b.y - a.y, b.z - a.z)), 30, 12, 0.012,
                offset=lambda u, v: 0.025 * math.sin(v * math.pi))
    # Volant mit Wellenkante
    n = int(width / 0.16)
    pts = [(-width / 2, 0.0), (width / 2, 0.0)]
    wave = [(width / 2 - width * k / (n * 4), -0.16 - 0.035 * math.sin(math.pi * 2 * k / 4)) for k in range(n * 4 + 1)]
    cloth.slab([(-width / 2, 0.0), (width / 2, 0.0)] + wave, 0.012,
               Matrix.Translation((0, b.y, b.z)) @ Matrix.Rotation(math.radians(90), 4, "X"), dent=0.0)
    cloth.build()
    iron = Body("Markise Arme", M["lamp_iron"], C["deco"], seed=13, vary=0.03, bevel=0.003)
    iron.tube([(-width / 2 - 0.01, b.y, b.z), (width / 2 + 0.01, b.y, b.z)], 0.014, segs=8, round_ends=True)
    for side in (-1, 1):
        x = side * (width / 2 + 0.03)
        iron.tube([(x, -0.05, -0.45), (x, b.y * 0.5, -0.32), (x, b.y, b.z)], 0.012, segs=8, smooth=1, round_ends=True)
    iron.build()


# --- Türblätter (Scharnier-Koordinaten der Ladentür; Blender +y = draußen) ---

DOOR_W, DOOR_H, DOOR_T = 0.98, 2.18, 0.05


def build_door(kind):
    M, C = fresh("Türblatt %s" % kind)
    rnd = random.Random(70)
    leaf = Body("Türblatt", M["door"], C["shop"], seed=71, vary=0.04, bevel=0.008)
    cx = -0.5    # Mitte des Blatts (Scharnier bei x = 0)

    def lb(c, s, step=0.5):
        # c = (quer, Höhe, Tiefe), s = (Breite, Höhe, Dicke) – in Blender ist z oben, y außen
        leaf.box((cx + c[0], c[2], c[1]), (s[0], s[2], s[1]), step=step, dent=0.0015)
    glass = Body("Türglas", M["glass"], C["windows"], seed=72, vary=0.0)
    if kind == "cottage":
        # Senkrechte Bretter, innen Riegel und Strebe, oben ein kleines Fenster mit Sprossen
        n = 6
        # Fensterchen oben in der Mitte (zwischen den Brettern 2 und 3): Breite, Höhe, Unterkante
        win = (0.34, 0.36, 1.68)
        for i in range(n):
            x = -DOOR_W / 2 + DOOR_W * (i + 0.5) / n
            if i in (2, 3):
                lb((x, (win[2] - 0.02) / 2, 0), (DOOR_W / n + 0.002, win[2] - 0.02, DOOR_T), step=1)
                top0 = win[2] + win[1] + 0.02
                lb((x, (top0 + DOOR_H) / 2, 0), (DOOR_W / n + 0.002, DOOR_H - top0, DOOR_T), step=1)
            else:
                lb((x, DOOR_H / 2, 0), (DOOR_W / n + 0.002, DOOR_H - rnd.uniform(0.0, 0.01), DOOR_T), step=1)
        for z in (0.35, 1.45):
            lb((0, z, -0.035), (DOOR_W - 0.06, 0.12, 0.025))
        leaf.span(Vector((cx - 0.38, -0.035, 0.42)), Vector((cx + 0.38, -0.035, 1.38)), 0.1, 0.025, step=1, dent=0.001)
        lb((0, win[2] - 0.02, 0.0), (win[0] + 0.08, 0.04, DOOR_T + 0.01))
        lb((0, win[2] + win[1] + 0.02, 0.0), (win[0] + 0.08, 0.04, DOOR_T + 0.01))
        lb((0, win[2] + win[1] / 2, 0.0), (0.025, win[1], DOOR_T * 0.6))
        lb((0, win[2] + win[1] / 2, 0.0), (win[0], 0.025, DOOR_T * 0.6))
        glass.box((cx, 0, win[2] + win[1] / 2), (win[0], 0.006, win[1]), step=1, dent=0.0)
        straps = Body("Beschläge", M["lamp_iron"], C["deco"], seed=73, vary=0.03, bevel=0.002)
        for z in (0.35, 1.45):
            straps.box((cx + 0.26, DOOR_T / 2 + 0.004, z), (0.5, 0.008, 0.05), step=1, dent=0.0)
            straps.blob((cx + 0.02, DOOR_T / 2 + 0.01, z), 0.012, subdiv=1, lump=0.0)
        straps.build()
    else:
        # Rahmen (Friese) rundherum; Füllungen dünner und etwas größer als ihr Feld (überlappen –
        # nirgends ein Spalt), auf beiden Seiten ein flacher Spiegel
        stile, rail = 0.11, 0.13
        inner_w = DOOR_W - 2 * stile
        lb((-DOOR_W / 2 + stile / 2, DOOR_H / 2, 0), (stile, DOOR_H, DOOR_T))
        lb((DOOR_W / 2 - stile / 2, DOOR_H / 2, 0), (stile, DOOR_H, DOOR_T))
        lb((0, 0.1, 0), (inner_w + 0.004, 0.2, DOOR_T))
        lb((0, DOOR_H - rail / 2, 0), (inner_w + 0.004, rail, DOOR_T))

        def panel(z0, z1):
            for col in (-1, 1):
                px = col * inner_w / 4
                lb((px, (z0 + z1) / 2, 0), (inner_w / 2 + 0.01, z1 - z0 + 0.03, DOOR_T * 0.55))
                for side in (1, -1):
                    lb((px, (z0 + z1) / 2, side * DOOR_T * 0.3), (inner_w / 2 - 0.12, z1 - z0 - 0.12, 0.014))
            lb((0, (z0 + z1) / 2, 0), (0.06, z1 - z0 + 0.01, DOOR_T))
        if kind == "panelled":
            rows = ((0.2, 0.87), (0.93, 1.47), (1.53, DOOR_H - rail))
            for z0, z1 in rows:
                panel(z0, z1)
            for z in (0.9, 1.5):
                lb((0, z, 0), (inner_w + 0.004, 0.08, DOOR_T))
        else:
            # Unten zwei Füllungen, oben Glas (glazed: gerade mit Sprossen, arched: mit Bogen)
            panel(0.2, 0.86)
            lb((0, 0.92, 0), (inner_w + 0.004, 0.12, DOOR_T))
            gz0, gz1 = 0.98, DOOR_H - rail
            upright = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # Umriss in x/z, Dicke nach -y
            if kind == "arched":
                rise = 0.18
                spring = gz1 - 0.04 - rise
                arc = [(inner_w / 2 * math.cos(math.pi * k / 16), spring + rise * math.sin(math.pi * k / 16)) for k in range(17)]
                # Zwickel über dem Bogen: ein Stück Holz (oben gerade, unten der Bogen)
                head = [(inner_w / 2 + 0.004, spring)] + arc[1:-1] + [(-inner_w / 2 - 0.004, spring), (-inner_w / 2 - 0.004, gz1 + 0.004),
                                                                      (inner_w / 2 + 0.004, gz1 + 0.004)]
                leaf.slab([(cx + x, z) for x, z in head], DOOR_T, Matrix.Translation((0, DOOR_T / 2, 0)) @ upright, dent=0.0)
                glass.slab([(cx + x, z) for x, z in [(inner_w / 2, gz0)] + arc + [(-inner_w / 2, gz0)]], 0.006,
                           Matrix.Translation((0, 0.003, 0)) @ upright, dent=0.0)
                lb((0, (gz0 + spring + rise) / 2, 0.0), (0.025, spring + rise - gz0, DOOR_T * 0.6))
                lb((0, gz0 + (spring - gz0) * 0.55, 0.0), (inner_w, 0.025, DOOR_T * 0.6))
            else:
                glass.box((cx, 0, (gz0 + gz1) / 2), (inner_w, 0.006, gz1 - gz0), step=1, dent=0.0)
                lb((0, (gz0 + gz1) / 2, 0.0), (0.03, gz1 - gz0, DOOR_T * 0.6))
                for j in (1, 2):
                    lb((0, gz0 + (gz1 - gz0) * j / 3, 0.0), (inner_w, 0.03, DOOR_T * 0.6))
    leaf.build()
    glass.build()
    knobs = Body("Türknäufe", M["gold"], C["deco"], seed=74, vary=0.04)
    for s in (1, -1):
        knobs.lathe([(0.0, 0.0), (0.022, 0.0), (0.012, 0.03), (0.026, 0.05), (0.02, 0.07), (0.0, 0.072)],
                    (cx - 0.4, s * DOOR_T / 2, 1.0), segs=14, turn=(-90 * s, 0))
    knobs.build()
    return C, ("shop", "windows", "deco")


def build_round_door(kind):
    """Türblatt mit Rundbogen oben (seit Etappe 6c): Halbkreis über die ganze Breite (Radius DOOR_W / 2).
    round_cottage: senkrechte Bretter, oben im Bogen abgeschnitten, Riegel, kleines rundes Fenster.
    round_glazed: Rahmen mit Füllungen unten, oben Glas unter dem Bogen mit Sprosse."""
    M, C = fresh("Türblatt %s" % kind)
    cx = -0.5
    r = DOOR_W / 2
    spring = DOOR_H - r
    upright = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # Umriss in x/z, Dicke nach -y
    leaf = Body("Türblatt", M["door"], C["shop"], seed=81, vary=0.04, bevel=0.008)
    glass = Body("Türglas", M["glass"], C["windows"], seed=82, vary=0.0)

    def top(x, inset=0.0):
        rr = r - inset
        return spring + math.sqrt(max(rr * rr - x * x, 0.0))

    def column(xa, xb, z0, inset=0.0, steps=6):
        pts = [(xa, z0), (xb, z0)]
        pts += [(xb - (xb - xa) * k / steps, top(xb - (xb - xa) * k / steps, inset)) for k in range(steps + 1)]
        return [(cx + x, z) for x, z in pts]

    def slab(body, pts, thick, y=0.0):
        body.slab(pts, thick, Matrix.Translation((0, thick / 2 + y, 0)) @ upright, dent=0.0)

    def lb(c, s_):
        leaf.box((cx + c[0], c[2], c[1]), (s_[0], s_[2], s_[1]), step=0.5, dent=0.0015)
    if kind == "round_cottage":
        n = 7
        for i in range(n):
            xa = -r + DOOR_W * i / n - 0.001
            xb = -r + DOOR_W * (i + 1) / n + 0.001
            slab(leaf, column(max(xa, -r + 0.001), min(xb, r - 0.001), 0.0), DOOR_T)
        for z in (0.35, 1.35):
            lb((0, z, -0.035), (DOOR_W - 0.08, 0.12, 0.025))
        # rundes Fensterchen oben in der Mitte
        wz = spring + 0.05
        ring = [(cx + math.cos(math.tau * k / 24) * 0.15, wz + math.sin(math.tau * k / 24) * 0.15) for k in range(24)]
        inner = [(cx + math.cos(math.tau * k / 24) * 0.12, wz + math.sin(math.tau * k / 24) * 0.12) for k in range(24)]
        slab(glass, inner, 0.006, -0.001)
        frame = Body("Fensterring", M["door"], C["shop"], seed=83, vary=0.03)
        frame.tube([(x, DOOR_T / 2 + 0.006, z) for x, z in ring + ring[:1]], 0.018, segs=8)
        frame.tube([(x, -DOOR_T / 2 - 0.006, z) for x, z in ring + ring[:1]], 0.018, segs=8)
        frame.build()
        straps = Body("Beschläge", M["lamp_iron"], C["deco"], seed=84, vary=0.03, bevel=0.002)
        for z in (0.35, 1.35):
            straps.box((cx + 0.26, DOOR_T / 2 + 0.004, z), (0.5, 0.008, 0.05), step=1, dent=0.0)
        straps.build()
    else:
        stile = 0.11
        inner_w = DOOR_W - 2 * stile
        # Seitenfriese bis zum Kämpfer, Bogenfries oben, Riegel unten und in der Mitte
        lb((-r + stile / 2, spring / 2, 0), (stile, spring + 0.01, DOOR_T))
        lb((r - stile / 2, spring / 2, 0), (stile, spring + 0.01, DOOR_T))
        lb((0, 0.1, 0), (inner_w + 0.004, 0.2, DOOR_T))
        lb((0, 0.92, 0), (inner_w + 0.004, 0.12, DOOR_T))
        band = [(cx + math.cos(math.pi * k / 20) * r, spring + math.sin(math.pi * k / 20) * r) for k in range(21)]
        band += [(cx + math.cos(math.pi * k / 20) * (r - stile), spring + math.sin(math.pi * k / 20) * (r - stile)) for k in range(20, -1, -1)]
        slab(leaf, band, DOOR_T)
        for col in (-1, 1):
            px = col * inner_w / 4
            lb((px, 0.53, 0), (inner_w / 2 + 0.01, 0.69, DOOR_T * 0.55))
            for side in (1, -1):
                lb((px, 0.53, side * DOOR_T * 0.3), (inner_w / 2 - 0.12, 0.54, 0.014))
        lb((0, 0.53, 0), (0.06, 0.67, DOOR_T))
        gz0 = 0.98
        pts = [(cx - inner_w / 2, gz0), (cx + inner_w / 2, gz0)]
        pts += [(cx + math.cos(math.pi * k / 20) * (inner_w / 2), spring + math.sin(math.pi * k / 20) * (inner_w / 2)) for k in range(21)]
        slab(glass, pts, 0.006, -0.003)
        lb((0, (gz0 + spring + inner_w / 2) / 2, 0.0), (0.025, spring + inner_w / 2 - gz0, DOOR_T * 0.6))
        lb((0, spring, 0.0), (inner_w, 0.025, DOOR_T * 0.6))
    leaf.build()
    glass.build()
    knobs = Body("Türknäufe", M["gold"], C["deco"], seed=85, vary=0.04)
    for s_ in (1, -1):
        knobs.lathe([(0.0, 0.0), (0.022, 0.0), (0.012, 0.03), (0.026, 0.05), (0.02, 0.07), (0.0, 0.072)],
                    (cx - 0.4, s_ * DOOR_T / 2, 1.0), segs=14, turn=(-90 * s_, 0))
    knobs.build()
    return C, ("shop", "windows", "deco")


# --- Blumenkästen (Rahmen canon, Oberkante hinten am Anker; Kasten ragt nach außen) ---

BOX_W, BOX_D, BOX_H = UP_W + 0.18, 0.2, 0.2


def build_box(kind):
    M, C = fresh("Blumenkasten %s" % kind)
    w, d, h = BOX_W, BOX_D, BOX_H
    base = Matrix.Translation((0, 0, -h))   # canon: Wand bei y = 0, außen -y
    fm = base @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # lokal x quer, y hoch, z nach außen
    if kind == "wood":
        SC.planter_box(M, C["pots"], "Kasten", fm, w, d, h, seed=81, gap=0.0, mat="green")
    else:
        mat = {"zinc": "zinc", "terracotta": "terracotta", "wicker": "wicker"}[kind]
        b = Body("Kasten", M[mat], C["pots"], seed=82, vary=0.06, bevel=0.006 if kind != "wicker" else 0.0)
        wall = 0.022
        if kind == "wicker":
            weave_box(b, fm, w, d, h)
        else:
            b.box((0, wall / 2, d / 2), (w, wall, d), step=0.25, dent=0.002, matrix=fm)
            for zz in (wall / 2, d - wall / 2):
                b.box((0, h / 2, zz), (w, h, wall), step=0.25, dent=0.003, matrix=fm)
            for side in (-1, 1):
                b.box((side * (w / 2 - wall / 2), h / 2, d / 2), (wall, h, d), step=0.25, dent=0.003, matrix=fm)
            if kind == "zinc":
                # gerollter Rand und zwei Sicken
                pts = [(-w / 2, h, 0.0), (w / 2, h, 0.0), (w / 2, h, d), (-w / 2, h, d), (-w / 2, h, 0.0)]
                b.tube([fm @ Vector(p) for p in pts], 0.012, segs=8)
                for yy in (h * 0.3, h * 0.65):
                    b.tube([fm @ Vector((-w / 2 + 0.01, yy, d + 0.002)), fm @ Vector((w / 2 - 0.01, yy, d + 0.002))], 0.005, segs=6)
            else:
                # Terrakotta: dicker Rand und Girlande aus kleinen Kugeln
                b.box((0, h - 0.015, d - 0.01), (w + 0.03, 0.03, 0.04), step=0.3, dent=0.002, matrix=fm)
                n = 9
                for k in range(n):
                    x = -w / 2 + 0.08 + (w - 0.16) * k / (n - 1)
                    y = h * 0.55 - 0.035 * math.sin(math.pi * (k % 3) / 2)
                    b.blob(fm @ Vector((x, y, d + 0.004)), 0.014, subdiv=1, lump=0.06, scale=(1, 1, 0.5))
        b.build()
        s = Body("Kasten Erde", M["soil"], C["pots"], seed=83)
        s.box((0, h - 0.045, d / 2), (w - 2 * wall - 0.004, 0.05, d - 2 * wall - 0.004), step=0.2, dent=0.006, matrix=fm)
        s.build()
        SC.plant_spot("box", fm @ Vector((0, h - 0.02, d / 2)), (w - 2 * wall, d - 2 * wall, 0.45), SC.facing_of(fm))
    # Zwei Konsolen aus Eisen unter dem Kasten
    kb = Body("Kasten Konsolen", M["lamp_iron"], C["deco"], seed=84, bevel=0.003)
    for sx in (-w / 2 + 0.08, w / 2 - 0.08):
        kb.tube([(sx, -0.02, -h - 0.25), (sx, -d * 0.9, -h - 0.01), (sx, -0.02, -h - 0.01)], 0.009, segs=6, round_ends=True)
    kb.build()
    return C, ("pots", "deco")


def weave_box(b, fm, w, d, h):
    """Weidengeflecht als Kasten: Staken und Ruten abwechselnd davor und dahinter (rundherum)."""
    path = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, d), (-w / 2, d)]
    per = 2 * (w + d)

    def at(s, off):
        s = s % per
        for (x0, z0), (x1, z1) in zip(path, path[1:] + path[:1]):
            seg_len = math.hypot(x1 - x0, z1 - z0)
            if s <= seg_len:
                t = s / seg_len
                nx, nz = (z1 - z0) / seg_len, -(x1 - x0) / seg_len
                return (x0 + (x1 - x0) * t + nx * off, z0 + (z1 - z0) * t + nz * off)
            s -= seg_len
        return path[0]
    staves = int(per / 0.045)
    for i in range(staves):
        x, z = at(per * i / staves, 0.0)
        b.tube([fm @ Vector((x, 0.0, z)), fm @ Vector((x, h, z))], 0.0035, segs=5)
    rows = 9
    for j in range(rows):
        y = h * (j + 0.5) / rows
        pts = []
        for i in range(staves * 2 + 1):
            off = 0.004 * (1 if (i + j) % 2 else -1)
            x, z = at(per * i / (staves * 2), off)
            pts.append(fm @ Vector((x, y, z)))
        b.tube(pts, 0.006, segs=5)
    b.box((0, 0.012, d / 2), (w - 0.01, 0.02, d - 0.01), step=0.3, dent=0.0, matrix=fm)
    b.tube([fm @ Vector((x, h, z)) for x, z in path + path[:1]], 0.01, segs=6)


# --- Ampeln (Rahmen canon, Anker oben an der Wand) ---

def build_basket(kind):
    M, C = fresh("Ampel %s" % kind)
    if kind == "bowl":
        T.hanging_basket(M, C, "Ampel", 0.0, 0.0, reach=0.5, drop=0.38, radius=0.16, mat="pot", seed=91)
    else:
        bracket(M, C)
        ring = Vector((0, -0.5, -0.05))
        r = 0.18
        base = ring + Vector((0, 0, -0.38 - r))
        if kind == "wicker":
            T.round_basket(M, C, "Ampel Korb", tuple(base), r * 0.7, r, r * 0.8, seed=92, coll="pots")
            top_z = base.z + r * 0.8
        else:
            # Drahtkorb mit Moos: Moosschale und Drahtbögen
            moss = Body("Ampel Moos", M["moss"], C["pots"], seed=93, vary=0.12, bevel=0.0)
            moss.lathe([(0.0, 0.0), (r * 0.5, 0.02), (r * 0.85, r * 0.35), (r, r * 0.75), (r * 0.94, r * 0.8), (r * 0.8, r * 0.42),
                        (r * 0.42, r * 0.1), (0.0, r * 0.08)], tuple(base), segs=20, dent=0.01)
            moss.build()
            wire = Body("Ampel Draht", M["lamp_iron"], C["deco"], seed=94, vary=0.02)
            for k in range(6):
                a = math.tau * k / 6
                pts = []
                for t in range(9):
                    phi = math.pi / 2 * t / 8
                    rr = r * 1.02 * math.sin(phi)
                    pts.append(base + Vector((math.cos(a) * rr, math.sin(a) * rr, r * 0.8 * (1 - math.cos(phi)))))
                wire.tube(pts, 0.004, segs=5)
            wire.build()
            top_z = base.z + r * 0.8
        soil = Body("Ampel Erde", M["soil"], C["pots"], seed=95)
        soil.lathe([(0.0, 0.0), (r * 0.88, 0.0), (r * 0.86, 0.03), (0.0, 0.035)], (base.x, base.y, top_z - 0.05), segs=16)
        soil.build()
        chains = Body("Ampel Ketten", M["lamp_iron"], C["deco"], seed=96)
        for k in range(3):
            a = math.radians(90 + 120 * k)
            p = Vector((base.x + math.cos(a) * r * 0.95, base.y + math.sin(a) * r * 0.95, top_z))
            chains.tube([ring, p], 0.0035, segs=5, round_ends=True)
        chains.build()
        SC.plant_spot("basket", (base.x, base.y, top_z - 0.02), (2 * r, 2 * r, 0.4))
    return C, ("pots", "deco")


def bracket(M, C):
    """Wandarm mit Schnecke (wie bei T.hanging_basket)."""
    import storybook_parts as SP
    ir = Body("Ampel Halter", M["lamp_iron"], C["deco"], seed=97, vary=0.03, bevel=0.004)
    ir.box((0, -0.012, -0.1), (0.07, 0.024, 0.3), step=1, dent=0.001)
    hook = Vector((0, -0.5, 0.02))
    ir.tube([(0, -0.02, 0), (0, -0.25, 0.035), hook], 0.013, segs=8, smooth=2, round_ends=True)
    ir.tube([(0, -0.02, -0.22), (0, -0.21, -0.08), (0, -0.4, 0.01)], 0.009, segs=8, smooth=2, round_ends=True)
    SP.scroll(ir, (0, -0.17, -0.06), 0.05, 0.0, turns=1.2, thick=0.006, start=0.8)
    ring = hook + Vector((0, 0, -0.07))
    ir.tube([hook, ring], 0.005, segs=6, round_ends=True)
    ir.build()


# --- Deko vor der Tür (seit Etappe 6c, Raumkoordinaten wie der Kern) ---

DECO_SETS = {"bench": ("bench", "bench_pots"), "steps": ("steps",), "sign": ("sign", "lantern"), "planters": ("planters",),
             "all": ("bench", "steps", "sign", "lantern", "planters")}


def library_chalkboard_image():
    """Startbild der Kreidetafel (assets/textures/signs/library_chalkboard.png) – nur, wenn es fehlt;
    danach ist es das Bild der Entwicklerin und wird nie überschrieben."""
    import style_lib as S
    import style_parts as P
    import build_houses as BH
    png = os.path.join(SC.ROOT, "assets", "textures", "signs", "library_chalkboard.png")
    if os.path.exists(png):
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = S.Builder("library_chalkboard")
    P.chalkboard_design(b, ["Heute:", "Vorlese-", "stunde"], 33)
    S.to_blender(b, {})
    BH._sign_lighting()
    S.render_ortho(png, P.CHALKBOARD_SIZE[0], P.CHALKBOARD_SIZE[1], 360)
    print("Startbild:", png)


def _collider(C, name, center, size):
    """Kasten nur für die Kollision im Spiel („…-colonly“), in Blender-Koordinaten."""
    b = Body(name + "-colonly", None, C["deco"], vary=0)
    b.box(center, size, step=10, dent=0)
    obj = b.build()
    obj.display_type = "WIRE"
    obj.hide_render = True


def _obstacle(C, matrix, radius):
    """Kreis, um den Passanten herumgehen (im Spiel ein StreetObstacle): leeres Objekt „Obstacle_<cm>“."""
    anchor(C, "Obstacle_%d" % round(radius * 100), matrix)


def build_deco(kind):
    import build_storybook_props as PR
    if kind in ("sign", "all"):
        library_chalkboard_image()
    M, C = fresh("Deko vor der Tür %s" % kind)
    parts = DECO_SETS[kind]
    dc = DIAG_LEN / 2
    # Treppe: Podest (Oberkante = Ladenboden 0) halb so breit wie die Wand minus die Seitenstufen
    podium_half = DIAG_LEN / 2 - 3 * 0.2

    def world(m, local):
        return m @ Vector(local)
    if "bench" in parts:
        # Parkbank an der Gassenwand (vor dem linken Fenster frei), mit Blick nach draußen
        m = T.canon(*LEFT, 0.98, GROUND, 0.3)
        T.placed(C["deco"], m, PR.street_bench, M, C["deco"])
        _collider(C, "Bank", world(m, (0.0, -0.02, 0.45)), (1.5, 0.5, 0.9))
        for x in (-0.45, 0.45):
            _obstacle(C, m @ Matrix.Translation((x, -0.05, 0.0)), 0.42)
    if "bench_pots" in parts:
        for k, (u, r, h) in enumerate(((0.12, 0.17, 0.36), (1.84, 0.14, 0.3))):
            if kind == "all" and k == 0:
                continue
            m = T.canon(*LEFT, u, GROUND, 0.32)
            SC.pot(M, C["pots"], "Bank Topf %d" % k, world(m, (0, 0, 0)), r, h, 900 + k, style="classic")
            _collider(C, "Bank Topf %d" % k, world(m, (0, 0, h / 2)), (r * 2, r * 2, h))
    if "steps" in parts:
        # Töpfe auf dem Podest (vorn an den Ecken) und an den Seiten der Stufen
        for k, (side, out, z, r, h) in enumerate(((-1, 0.48, 0.0, 0.15, 0.3), (1, 0.48, 0.0, 0.15, 0.3),
                                                  (-1, 0.62, -0.125, 0.085, 0.18), (1, 0.62, -0.125, 0.085, 0.18),
                                                  (-1, 0.9, -0.25, 0.08, 0.16), (1, 0.9, -0.25, 0.08, 0.16))):
            off = podium_half - 0.18 if k < 2 else podium_half + 0.1 if k < 4 else podium_half + 0.3
            m = T.canon(*DIAG, dc + side * off, z, out)
            SC.pot(M, C["pots"], "Treppe Topf %d" % k, world(m, (0, 0, 0)), r, h, 910 + k, style="bowl" if k >= 2 else "classic")
            _collider(C, "Treppe Topf %d" % k, world(m, (0, 0, h / 2)), (r * 2, r * 2, h))
    if "sign" in parts:
        # Aufsteller auf dem Gehweg vorn, nahe der Ecke zur Schräge, schräg zur Straße
        m = T.canon(*FRONT, 3.86, GROUND, 0.62)
        p = world(m, (0, 0, 0))
        before = set(bpy.data.objects)
        SC.chalkboard(M, C["deco"], (p.x, p.y), math.degrees(math.atan2(m[1][0], m[0][0])) + 20, SC.sign_material("library", "chalkboard"))
        for o in bpy.data.objects:
            if o not in before and o.parent is None:
                o.location.z += GROUND
        _collider(C, "Aufsteller", (p.x, p.y, GROUND + 0.45), (0.5, 0.5, 0.9))
        _obstacle(C, m, 0.38)
    if "lantern" in parts:
        # Laterne auf einem Pfosten am vorderen Rand des Podests (auf der Seite ohne Briefkasten)
        m = T.canon(*DIAG, dc - podium_half + 0.16, 0.0, 0.2)
        base = world(m, (0, 0, 0))
        post = Body("Laterne Pfosten", M["lamp_iron"], C["deco"], seed=930, vary=0.03, bevel=0.004)
        post.lathe([(0.0, 0.0), (0.09, 0.0), (0.09, 0.03), (0.05, 0.05), (0.03, 0.1), (0.0, 0.1)], base, segs=16)
        post.tube([base + Vector((0, 0, 0.08)), base + Vector((0, 0, 0.92))], 0.022, segs=10, round_ends=True)
        post.build()
        import storybook_parts as SP
        SP.lantern_head(M, C["deco"], "Laterne", base + Vector((0, 0, 0.92)), scale=0.62, seed=931)
        _collider(C, "Laterne", base + Vector((0, 0, 0.6)), (0.2, 0.2, 1.2))
    if "planters" in parts:
        # zwei große Kübel neben der Treppe (vorn und an der Gasse)
        for k, (seg, u) in enumerate(((FRONT, 3.62), (LEFT, 0.42 if kind != "all" else 1.95))):
            if kind == "all" and k == 1:
                continue
            m = T.canon(*seg, u, GROUND, 0.42)
            SC.pot(M, C["pots"], "Kübel %d" % k, world(m, (0, 0, 0)), 0.26, 0.5, 940 + k, mat="terracotta", style="tub", spot="tub")
            _collider(C, "Kübel %d" % k, world(m, (0, 0, 0.25)), (0.56, 0.56, 0.5))
            _obstacle(C, m, 0.4)
    return C, ("deco", "pots")


# --- Export ---

PARTS = {
    "core": build_core,
    **{"ground_" + v: (lambda v=v: build_ground(v)) for v in ("classic", "beadboard", "victorian")},
    **{"awning_" + v: (lambda v=v: build_awning(v)) for v in ("classic", "dome", "box")},
    **{"door_" + v: (lambda v=v: build_door(v)) for v in ("glazed", "panelled", "arched", "cottage")},
    **{"door_" + v: (lambda v=v: build_round_door(v)) for v in ("round_glazed", "round_cottage")},
    **{"box_" + v: (lambda v=v: build_box(v)) for v in ("wood", "zinc", "terracotta", "wicker")},
    **{"basket_" + v: (lambda v=v: build_basket(v)) for v in ("bowl", "wire", "wicker")},
    **{"deco_" + v: (lambda v=v: build_deco(v)) for v in DECO_SETS},
}


def export_part(name, C):
    """Teile je Material zusammenfassen, .glb mit externen Godot-Materialien, .blend als Quelle.
    Pflanzplätze heißen hier „FacadeSpot_…“ (die Fassade bepflanzt sie selbst, nicht Greenery) –
    außer im Kern (Kübel an der Gassenwand)."""
    objs = [o for c in C.values() for o in c.objects if o.type == "MESH"]
    extra = [o for c in C.values() for o in c.objects if o.type == "EMPTY"]
    extra += [o for o in bpy.data.objects if o.name.startswith("PlantSpot_") and o not in extra]
    if name != "core":
        for o in extra:
            if o.name.startswith("PlantSpot_"):
                o.name = "FacadeSpot_" + o.name.split("_")[1]
    if name == "core" or name.startswith("ground_"):
        # Wie die alte Fassade leicht „gesetzt“ – hängt nur von der Lage ab, darum passen die Teile
        # weiter genau aneinander
        SC.settle(objs, L.SETTLE, 3.2, E, E + L.RISE)
    bad = [(o.name, SB.non_manifold(o)) for o in objs if SB.non_manifold(o)]
    os.makedirs(MODEL_DIR, exist_ok=True)
    glb = os.path.join(MODEL_DIR, name + ".glb")
    tris, n = SC.export_objects(objs, [], glb, palette=False, extra=extra)
    mapping = SC.write_game_materials(only=set(SC.LAST_EXPORT_MATERIALS))
    SC.write_import_settings(mapping, glb)
    os.makedirs(SOURCE_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, name + ".blend"), compress=True)
    print("  %-20s %7d Dreiecke, %3d Netze%s" % (name, tris, n, ("  OFFENE KANTEN: %s" % bad) if bad else ""))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    wanted = [a for a in argv if not a.startswith("--")] or ([] if "--data" in argv else list(PARTS))
    for name in wanted:
        if name not in PARTS:
            print("Unbekanntes Teil:", name)
            continue
        C, _ = PARTS[name]()
        export_part(name, C)
    import facade_options
    facade_options.write_all()
    print("Fertig: %d Teile." % len(wanted))


if __name__ == "__main__":
    main()
