"""Gemeinsame Werkzeuge der Bilderbuch-Häuser (Modegeschäft, Pub, Laternen …).

  - materials(): alle Materialien (Blender) + Werte fürs Spiel (GAME_MATERIALS)
  - sign_material(): Schild-Bild der Entwicklerin (assets/textures/signs/<typ>_<name>.png)
  - Töpfe, Kübel, Blumenkästen (ohne Pflanzen), Kreidetafel mit Bild
  - settle(): alles leicht verziehen wie über Jahrzehnte gesetzt
  - Export fürs Spiel (.glb je Material zusammengefasst, Godot-Materialien, Importeinstellungen)
  - Schutz für selbst bearbeitete .blend (Fingerabdruck), Kontrollbilder (Cycles)

Koordinaten wie in storybook_lib: Blender x rechts, y nach hinten, z oben; die Hausfront liegt
bei y = 0 und zeigt nach -y (im Spiel +Z).
"""

import bpy
import math
import numpy as np

# Blenders glTF-Export nutzt beim Export von Bildern (Schilder) noch np.bool – mit neuem numpy
# fehlt das (wie in character_lib)
if not hasattr(np, "bool"):
    np.bool = bool
import os
import random

from mathutils import Matrix, Vector, noise

import storybook_lib as SB
from storybook_lib import Body

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME_MAT_DIR = os.path.join(ROOT, "assets", "materials", "storybook")
SIGN_DIR = os.path.join(ROOT, "assets", "textures", "signs")
SHOTS = os.path.join(ROOT, "screenshots", "blender", "storybook")

GRAIN_ID = {"plaster": 0, "stone": 1, "wood": 2, "brick": 3, "fabric": 4, "leaf": 5, "smooth": 6, "paint": 7}
GAME_MATERIALS = {}   # Blender-Name -> Werte für das Godot-Material (siehe write_game_materials)


# --- Materialien ---

def materials():
    def M(name, color, glow=0.0, plant=False, **kw):
        """Material in Blender anlegen und die Werte für Godot merken (glow = Leuchten im Spiel,
        z. B. Innenräume, die in Blender von Lampen beleuchtet werden; plant = Blätter/Blüten, im
        Spiel beidseitig sichtbar)."""
        GAME_MATERIALS[name] = dict(kw, color=color, glow=glow, plant=plant)
        mat = SB.material(name, color, **{k: v for k, v in kw.items() if k != "wind"})
        mat["spiel_pflanze"] = plant   # export_storybook.py vereinfacht diese Teile fürs Spiel
        return mat
    return {
        "plaster": M("Putz Creme", (0.9, 0.83, 0.7), rough=0.93, vary=0.09, scale=1.4, bump=0.35),
        "plaster_side": M("Putz Sand Seitenwand", (0.84, 0.75, 0.6), rough=0.93, vary=0.1, scale=1.2),
        "stone": M("Sandstein", (0.85, 0.77, 0.62), grain="stone", rough=0.9, vary=0.1, bump=0.3),
        "trim": M("Stuck Gebrochenweiß", (0.93, 0.89, 0.8), rough=0.88, vary=0.05, scale=3.0),
        "blue": M("Lack Taubenblau", (0.24, 0.33, 0.44), grain="paint", rough=0.72, vary=0.06, bump=0.12),
        "blue_dark": M("Lack Taubenblau dunkel", (0.18, 0.25, 0.34), grain="paint", rough=0.72, vary=0.05, bump=0.12),
        "sign": M("Holz Schild Nussbraun", (0.33, 0.21, 0.13), grain="wood", rough=0.8, vary=0.08, bump=0.25),
        "gold": M("Ocker-Gold matt", (0.84, 0.64, 0.3), grain="smooth", rough=0.5, metal=0.35, vary=0.05),
        "roof": M("Dachziegel Schiefer-Braun", (0.42, 0.34, 0.3), grain="stone", rough=0.92, vary=0.08, bump=0.2),
        "terra": M("Terrakotta", (0.74, 0.39, 0.25), rough=0.9, vary=0.08, scale=3.0),
        # Ziegel: warmes Braun (einzelne Steine beige oder dunkler, im Shader), color2 = Fuge
        "brick": M("Backstein", (0.6, 0.38, 0.27), grain="brick", rough=0.92, vary=0.06, color2=(0.57, 0.5, 0.42)),
        "frame": M("Fensterrahmen Creme", (0.91, 0.86, 0.76), grain="paint", rough=0.8, vary=0.04, bump=0.08),
        "glass": M("Glas", (0.92, 0.95, 0.93), grain="smooth", rough=0.03, glass=True, vary=0.0, bump=0.0),
        "curtain": M("Vorhang Leinen", (0.9, 0.8, 0.64), grain="fabric", rough=0.95, vary=0.05, emit=0.35,
                     emit_color=(0.95, 0.72, 0.45)),
        "awning": M("Markisenstoff", (0.93, 0.88, 0.78), grain="fabric", rough=0.95, vary=0.04, stripes=0.13,
                    color2=(0.76, 0.35, 0.27), wind=0.035),
        "iron": M("Schmiedeeisen", (0.21, 0.2, 0.19), grain="smooth", rough=0.7, metal=0.4, vary=0.04),
        "lamp_iron": M("Laterne Eisen dunkelbraun", (0.13, 0.11, 0.095), grain="smooth", rough=0.6, metal=0.3, vary=0.04),
        "bronze": M("Dachrinne Bronze", (0.36, 0.28, 0.2), grain="smooth", rough=0.65, metal=0.4),
        "lamp": M("Laternenglas leuchtend", (1.0, 0.86, 0.62), grain="smooth", rough=0.4, emit=7.0,
                  emit_color=(1.0, 0.74, 0.42), vary=0.0, bump=0.0),
        "bulb": M("Lampenschirm leuchtend", (1.0, 0.9, 0.72), grain="smooth", rough=0.6, emit=4.0,
                  emit_color=(1.0, 0.76, 0.48), vary=0.0, bump=0.0),
        "box": M("Holz Blumenkasten", (0.5, 0.32, 0.21), grain="wood", rough=0.85, vary=0.08),
        "soil": M("Erde", (0.25, 0.18, 0.12), rough=1.0, vary=0.1, scale=8),
        "ivy": M("Blatt Efeu", (0.2, 0.34, 0.13), grain="leaf", rough=0.7, vary=0.1, plant=True),
        "ivy_young": M("Blatt Efeu jung", (0.36, 0.5, 0.2), grain="leaf", rough=0.7, vary=0.1, plant=True),
        "leaf": M("Blatt Geranie", (0.28, 0.44, 0.17), grain="leaf", rough=0.75, vary=0.1, plant=True),
        "box_leaf": M("Blatt Buchs", (0.22, 0.38, 0.14), grain="leaf", rough=0.72, vary=0.16, plant=True),
        "box_core": M("Buchs Inneres", (0.08, 0.15, 0.06), grain="leaf", rough=0.9, vary=0.1),
        "olive_leaf": M("Blatt Olive", (0.5, 0.56, 0.4), grain="leaf", rough=0.8, vary=0.1, plant=True),
        "stem": M("Stiel", (0.34, 0.38, 0.2), rough=0.8, vary=0.08),
        "bark": M("Rinde", (0.42, 0.34, 0.26), grain="wood", rough=0.95, vary=0.1),
        "red": M("Blüte Geranienrot", (0.86, 0.2, 0.22), grain="fabric", rough=0.7, vary=0.1, plant=True),
        "pink": M("Blüte Rosa", (0.93, 0.46, 0.6), grain="fabric", rough=0.7, vary=0.12, plant=True),
        "rose": M("Blüte Himbeer", (0.85, 0.3, 0.43), grain="fabric", rough=0.7, vary=0.1, plant=True),
        "coral": M("Blüte Koralle", (0.96, 0.56, 0.45), grain="fabric", rough=0.7, vary=0.1, plant=True),
        "cream_flower": M("Blüte Creme", (0.96, 0.93, 0.85), grain="fabric", rough=0.7, vary=0.05, plant=True),
        "blush_flower": M("Blüte Zartrosa", (0.97, 0.75, 0.78), grain="fabric", rough=0.7, vary=0.08, plant=True),
        "lilac": M("Blüte Flieder", (0.68, 0.58, 0.86), grain="fabric", rough=0.7, vary=0.12, plant=True),
        "blue_flower": M("Blüte Blau", (0.48, 0.55, 0.86), grain="fabric", rough=0.7, vary=0.1, plant=True),
        "zinc": M("Zink", (0.62, 0.63, 0.6), grain="smooth", rough=0.6, metal=0.3, vary=0.06),
        "pot": M("Terrakotta Topf", (0.72, 0.42, 0.28), rough=0.92, vary=0.08, scale=6),
        "chalkboard": M("Tafel", (0.17, 0.21, 0.19), rough=0.95, vary=0.06),
        "chalk": M("Kreide", (0.93, 0.91, 0.85), rough=1.0, vary=0.03),
        "wood": M("Holz Eiche", (0.62, 0.44, 0.28), grain="wood", rough=0.8, vary=0.08),
        "wood_in": M("Holz Eiche innen", (0.62, 0.44, 0.28), grain="wood", rough=0.8, vary=0.08, glow=0.22),
        "in_wall": M("Innenwand Salbei", (0.66, 0.68, 0.54), rough=0.9, vary=0.05, glow=0.26),
        "in_paper": M("Tapete Creme", (0.9, 0.82, 0.68), rough=0.9, vary=0.05, glow=0.26),
        "in_dark": M("Zimmer warm", (0.66, 0.54, 0.4), rough=0.95, vary=0.05, glow=0.3),
        "linen": M("Schneiderpuppe Leinen", (0.86, 0.79, 0.66), grain="fabric", rough=0.9, vary=0.04, glow=0.2),
        "mustard": M("Stoff Senf", (0.82, 0.62, 0.24), grain="fabric", rough=0.92, vary=0.06, glow=0.2),
        "sage": M("Stoff Salbeigrün", (0.33, 0.46, 0.33), grain="fabric", rough=0.92, vary=0.06, glow=0.2),
        "rust": M("Stoff Rostrot", (0.68, 0.31, 0.22), grain="fabric", rough=0.92, vary=0.06, glow=0.2),
        "blush": M("Stoff Altrosa", (0.88, 0.62, 0.62), grain="fabric", rough=0.92, vary=0.06, glow=0.2),
        "slab": M("Gehwegplatten", (0.7, 0.64, 0.55), grain="stone", rough=0.95, vary=0.08, bump=0.2),
        "curb": M("Bordstein", (0.62, 0.59, 0.54), grain="stone", rough=0.95, vary=0.06),
        "cobble": M("Kopfsteinpflaster", (0.58, 0.42, 0.33), grain="stone", rough=0.95, vary=0.06),
        "earth": M("Fugen", (0.36, 0.3, 0.25), rough=1.0),
        "grass": M("Gras", (0.36, 0.5, 0.2), grain="leaf", rough=0.8, vary=0.15, plant=True),
        # Pub "The Ink & Ivy"
        "pub_brick": M("Backstein Ziegelrot", (0.66, 0.4, 0.28), grain="brick", rough=0.92, vary=0.07, color2=(0.6, 0.52, 0.43)),
        "pub_arch": M("Backstein Bogen hell", (0.78, 0.55, 0.4), grain="brick", rough=0.92, vary=0.06, color2=(0.62, 0.55, 0.46)),
        "pub_side": M("Backstein Seitenwand", (0.58, 0.38, 0.28), grain="brick", rough=0.92, vary=0.07, color2=(0.56, 0.49, 0.41)),
        "bottle": M("Lack Flaschengrün", (0.2, 0.3, 0.22), grain="paint", rough=0.72, vary=0.06, bump=0.12),
        "bottle_dark": M("Lack Flaschengrün dunkel", (0.14, 0.22, 0.16), grain="paint", rough=0.72, vary=0.05, bump=0.12),
        "slate": M("Schiefer Blaugrau", (0.36, 0.38, 0.42), grain="stone", rough=0.9, vary=0.08, bump=0.2),
        "pub_wall_in": M("Gaststube Wand Rot", (0.62, 0.22, 0.17), grain="fabric", rough=0.9, vary=0.06, glow=0.24),
        "pub_wood_in": M("Gaststube Holz dunkel", (0.36, 0.22, 0.14), grain="wood", rough=0.75, vary=0.08, glow=0.2),
        "pub_ceiling": M("Gaststube Decke", (0.86, 0.74, 0.56), rough=0.9, vary=0.05, glow=0.3),
        "leather": M("Leder Grün", (0.22, 0.34, 0.25), grain="fabric", rough=0.65, vary=0.08, glow=0.18),
        "brass_in": M("Messing innen", (0.86, 0.66, 0.32), grain="smooth", rough=0.45, metal=0.4, vary=0.04, glow=0.2),
        "bottle_amber": M("Flaschen Bernstein", (0.85, 0.5, 0.16), grain="smooth", rough=0.3, vary=0.1, glow=0.55),
        "bottle_green": M("Flaschen Grün", (0.3, 0.6, 0.3), grain="smooth", rough=0.3, vary=0.1, glow=0.55),
        "bottle_blue": M("Flaschen Blau", (0.3, 0.45, 0.75), grain="smooth", rough=0.3, vary=0.1, glow=0.55),
        "bottle_red": M("Flaschen Rot", (0.75, 0.22, 0.25), grain="smooth", rough=0.3, vary=0.1, glow=0.55),
        "bottle_cream": M("Flaschen Creme", (0.92, 0.86, 0.7), grain="smooth", rough=0.3, vary=0.1, glow=0.55),
        "picture": M("Bild warm", (0.85, 0.72, 0.5), rough=0.8, vary=0.1, glow=0.35),
        "candle": M("Kerze leuchtend", (1.0, 0.85, 0.6), grain="smooth", rough=0.6, emit=3.0, emit_color=(1.0, 0.72, 0.4),
                    vary=0.0, bump=0.0),
        "table_top": M("Holz Tischplatte", (0.45, 0.3, 0.19), grain="wood", rough=0.75, vary=0.08),
        "chair": M("Holz Stuhl", (0.4, 0.26, 0.16), grain="wood", rough=0.78, vary=0.08),
        "pot_light": M("Terrakotta Topf hell", (0.8, 0.5, 0.33), rough=0.92, vary=0.08, scale=6),
        "pot_dark": M("Terrakotta Topf dunkel", (0.62, 0.34, 0.22), rough=0.92, vary=0.08, scale=6),
        # Teeladen, Wolleladen, Blumenladen, Bäckerei, Torhaus (storybook_town.py)
        "awning_red": M("Markisenstoff Rot", (0.94, 0.89, 0.8), grain="fabric", rough=0.95, vary=0.04, stripes=0.15,
                        color2=(0.72, 0.16, 0.15), wind=0.035),
        "tea_black": M("Lack Schwarzbraun", (0.1, 0.09, 0.085), grain="paint", rough=0.7, vary=0.05, bump=0.12),
        "shutter": M("Fensterladen Schiefergrau", (0.24, 0.26, 0.28), grain="paint", rough=0.78, vary=0.06, bump=0.15),
        "tea_wall_in": M("Teestube Wand Altrosa", (0.86, 0.68, 0.64), rough=0.9, vary=0.05, glow=0.26),
        "fern": M("Lack Farngrün", (0.42, 0.53, 0.42), grain="paint", rough=0.72, vary=0.06, bump=0.12),
        "fern_dark": M("Lack Farngrün dunkel", (0.3, 0.4, 0.31), grain="paint", rough=0.72, vary=0.05, bump=0.12),
        "petrol": M("Lack Tannengrün", (0.11, 0.25, 0.2), grain="paint", rough=0.72, vary=0.06, bump=0.12),
        "petrol_dark": M("Lack Tannengrün dunkel", (0.08, 0.18, 0.15), grain="paint", rough=0.72, vary=0.05, bump=0.12),
        "box_red": M("Lack Blumenkasten Rot", (0.7, 0.2, 0.17), grain="paint", rough=0.75, vary=0.06),
        "box_green": M("Lack Blumenkasten Grün", (0.3, 0.42, 0.3), grain="paint", rough=0.75, vary=0.06),
        "bread": M("Brot goldbraun", (0.8, 0.52, 0.25), rough=0.85, vary=0.12, scale=8, glow=0.3),
        "bread_dark": M("Brot dunkel", (0.56, 0.32, 0.16), rough=0.85, vary=0.12, scale=8, glow=0.3),
        "wicker": M("Weidenkorb", (0.68, 0.5, 0.3), grain="fabric", rough=0.9, vary=0.1, bump=0.4),
        "wicker_in": M("Weidenkorb innen", (0.68, 0.5, 0.3), grain="fabric", rough=0.9, vary=0.1, bump=0.4, glow=0.25),
        "bike": M("Lack Fahrrad Salbei", (0.52, 0.64, 0.48), grain="smooth", rough=0.45, metal=0.15, vary=0.04),
        "rubber": M("Gummi", (0.12, 0.11, 0.1), grain="smooth", rough=0.8, vary=0.03),
        "chrome": M("Chrom matt", (0.72, 0.71, 0.68), grain="smooth", rough=0.35, metal=0.6, vary=0.03),
        "saddle": M("Leder Sattel", (0.42, 0.25, 0.15), grain="fabric", rough=0.6, vary=0.06),
        "oak_dark": M("Fachwerk Eiche dunkel", (0.3, 0.19, 0.12), grain="wood", rough=0.85, vary=0.08, bump=0.3),
        "infill": M("Gefach Terrakotta", (0.78, 0.47, 0.34), rough=0.93, vary=0.08, scale=1.6, bump=0.3),
        "clay": M("Dachziegel Ton", (0.72, 0.4, 0.27), grain="stone", rough=0.9, vary=0.1, bump=0.2),
        "clay_dark": M("Dachziegel Ton dunkel", (0.6, 0.32, 0.22), grain="stone", rough=0.9, vary=0.1, bump=0.2),
        "vault": M("Gewölbe Sandstein", (0.8, 0.72, 0.58), grain="stone", rough=0.92, vary=0.1, bump=0.3),
        "wool_wall_in": M("Wolleladen Wand Creme", (0.93, 0.88, 0.8), rough=0.9, vary=0.04, glow=0.28),
        "flower_wall_in": M("Blumenladen Wand Hellgrün", (0.8, 0.84, 0.72), rough=0.9, vary=0.05, glow=0.28),
        "bakery_wall_in": M("Bäckerei Wand Honig", (0.93, 0.8, 0.6), rough=0.9, vary=0.05, glow=0.3),
        "yarn_blue": M("Wolle Blau", (0.42, 0.55, 0.78), grain="fabric", rough=0.95, vary=0.08, glow=0.22),
        "yarn_lilac": M("Wolle Flieder", (0.7, 0.6, 0.82), grain="fabric", rough=0.95, vary=0.08, glow=0.22),
        "yarn_mint": M("Wolle Mint", (0.62, 0.8, 0.7), grain="fabric", rough=0.95, vary=0.08, glow=0.22),
        "tin_red": M("Teedose Rot", (0.66, 0.2, 0.18), grain="smooth", rough=0.45, metal=0.2, vary=0.06, glow=0.3),
        "tin_green": M("Teedose Grün", (0.24, 0.42, 0.3), grain="smooth", rough=0.45, metal=0.2, vary=0.06, glow=0.3),
        "tin_cream": M("Teedose Creme", (0.9, 0.84, 0.7), grain="smooth", rough=0.45, metal=0.2, vary=0.06, glow=0.3),
        "tin_blue": M("Teedose Blau", (0.24, 0.32, 0.5), grain="smooth", rough=0.45, metal=0.2, vary=0.06, glow=0.3),
        "china": M("Porzellan", (0.95, 0.93, 0.88), grain="smooth", rough=0.3, vary=0.03, glow=0.3),
    }




def sign_material(type_id, sign):
    """Material für ein Schild-Bild der Entwicklerin: assets/textures/signs/<typ>_<schild>.png.
    Das Bild wird nie verändert; im Spiel zeigt ein eigenes Material genau dieses Bild."""
    path = os.path.join(SIGN_DIR, "%s_%s.png" % (type_id, sign))
    name = "Schild %s %s" % (type_id, sign)
    GAME_MATERIALS[name] = {"image": path}
    return SB.image_material(name, path)


def projecting_sign(M, coll, name, wall, image, width, height, outline=None, reach=0.72, seed=170):
    """Ausleger-Schild: Wandplatte, geschwungener Arm aus Schmiedeeisen nach vorn, daran an zwei
    Stangen das Schild (Bild der Entwicklerin auf beiden Seiten). wall = Befestigungspunkt an der
    Wand (Blender, Front bei y = 0 zeigt nach -y); das Schild hängt quer zur Wand."""
    import storybook_parts as SP
    x, y, z = wall
    ir = Body(name + " Arm", M["lamp_iron"], coll, seed=seed, vary=0.03, bevel=0.005)
    ir.box((x, y - 0.015, z - 0.08), (0.1, 0.03, 0.34), step=1, dent=0.001)
    ir.tube([Vector((x, y - 0.03, z + 0.05)), Vector((x, y - reach * 0.5, z + 0.09)), Vector((x, y - reach, z + 0.05))], 0.016,
            segs=8, smooth=2, round_ends=True)
    ir.tube([Vector((x, y - 0.03, z - 0.2)), Vector((x, y - 0.25, z - 0.05)), Vector((x, y - 0.42, z + 0.05))], 0.011, segs=8,
            smooth=2, round_ends=True)
    SP.scroll(ir, (x, y - 0.18, z - 0.06), 0.06, x, turns=1.3, thick=0.007, start=0.8)
    ir.blob((x, y - reach - 0.03, z + 0.05), 0.022, subdiv=2, lump=0.0)
    cy = y - 0.1 - (reach - 0.1) / 2
    top = z + 0.0
    for dy in (-width * 0.3, width * 0.3):
        ir.tube([Vector((x, cy + dy, z + 0.07)), Vector((x, cy + dy, top - 0.03))], 0.005, segs=6, round_ends=True)
    ir.build()
    pic = Body(name + " Bild", image, coll, seed=seed + 1, vary=0.0)
    cz = top - 0.025 - height / 2
    for side in (-1, 1):
        # Platte quer zur Wand, Bild zeigt zur Seite (+x bzw. -x), beide Seiten lesbar
        m = Matrix.Translation((x + side * 0.0008, cy, cz)) @ Matrix(((0, 0, side, 0), (side, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        pic.panel(m, width, height, 0.018, outline=outline)
    pic.build()


# --- Töpfe, Kübel, Blumenkästen (Deko; Pflanzen kommen später) ---

def pot(M, coll, name, base, radius, height, seed, mat="pot", style="classic", soil=True):
    """Blumentopf als Körper: Wand mit Dicke, Rand (Wulst), innen Erde. style: classic (unten
    schmaler, dicker Rand), bowl (bauchig), tall (hoch und schlank), tub (Kübel mit zwei Ringen)."""
    rnd = random.Random(seed)
    r, h = radius, height
    if style == "bowl":
        prof = [(r * 0.55, 0.0), (r * 0.9, h * 0.35), (r * 1.0, h * 0.75), (r * 0.98, h * 0.92)]
    elif style == "tall":
        prof = [(r * 0.7, 0.0), (r * 0.82, h * 0.5), (r * 0.94, h * 0.9)]
    elif style == "tub":
        prof = [(r * 0.86, 0.0), (r * 0.95, h * 0.5), (r * 1.0, h * 0.93)]
    else:
        prof = [(r * 0.72, 0.0), (r * 0.9, h * 0.8), (r * 0.9, h * 0.84)]
    rim_r = r * (1.06 if style != "tub" else 1.03)
    wall = max(0.012, r * 0.08)
    outside = [(0.0, 0.0)] + [(x, z) for x, z in prof] + [(rim_r, h * 0.86), (rim_r + 0.006, h * 0.93), (rim_r, h),
                                                          (rim_r - wall * 0.6, h + 0.004)]
    inside = [(rim_r - wall * 1.4, h - 0.006), (prof[-1][0] - wall, h * 0.8), (prof[0][0] - wall, wall), (0.0, wall)]
    b = Body(name, M[mat], coll, seed=seed, vary=0.05, bevel=0.004)
    b.lathe(outside + inside, base, segs=32, dent=0.003 * rnd.uniform(0.6, 1.4))
    if style == "tub":
        for zz in (h * 0.22, h * 0.7):
            rr = r * (0.88 + 0.1 * zz / h)
            b.lathe([(0.0, 0.0), (rr + 0.004, 0.0), (rr + 0.009, 0.008), (rr + 0.004, 0.016), (0.0, 0.016)],
                    Vector(base) + Vector((0, 0, zz)), segs=32)
    b.build()
    if soil:
        e = Body(name + " Erde", M["soil"], coll, seed=seed + 1)
        sr = rim_r - wall * 1.5
        e.lathe([(0.0, 0.0), (sr, 0.0), (sr * 0.97, 0.025), (sr * 0.5, 0.04), (0.0, 0.045)],
                Vector(base) + Vector((0, 0, h * 0.84)), segs=24, dent=0.006)
        e.build()


def zinc_tub(M, coll, name, base, seed):
    """Zinkeimer mit Henkeln und zwei Ringen, innen Erde."""
    x, y, z = base
    tub = Body(name, M["zinc"], coll, seed=seed, vary=0.04, bevel=0.004)
    tub.lathe([(0.0, 0.0), (0.17, 0.0), (0.22, 0.32), (0.235, 0.33), (0.235, 0.35), (0.21, 0.35), (0.165, 0.04), (0.0, 0.04)],
              (x, y, z), segs=32, dent=0.004)
    for side in (-1, 1):
        tub.tube([(x + side * 0.22, y, z + 0.28), (x + side * 0.27, y, z + 0.3), (x + side * 0.27, y, z + 0.22), (x + side * 0.215, y, z + 0.2)],
                 0.008, segs=8, smooth=2, round_ends=True)
    for zz in (0.08, 0.24):
        r = 0.17 + 0.05 * zz / 0.32
        tub.lathe([(0.0, 0.0), (r + 0.006, 0.0), (r + 0.008, 0.008), (r + 0.006, 0.016), (0.0, 0.017)], (x, y, z + zz), segs=32)
    tub.build()
    soil = Body(name + " Erde", M["soil"], coll, seed=seed + 1)
    soil.lathe([(0.0, 0.0), (0.205, 0.0), (0.2, 0.03), (0.0, 0.04)], (x, y, z + 0.29), segs=24, dent=0.008)
    soil.build()


def planter_box(M, coll, name, fm, width, depth, height, seed, gap=0.06, mat="box", rail=True):
    """Blumenkasten (offen, mit Erde) auf einer Fensterbank. fm = Ebene des Fensters (lokal x
    quer, y hoch, z zur Straße; y = 0 Unterkante des Kastens)."""
    b = Body(name, M[mat], coll, seed=seed, vary=0.06, bevel=0.008)
    g = gap
    wall = 0.022
    b.box((0, wall / 2, g + depth / 2), (width, wall, depth), step=0.25, dent=0.002, matrix=fm)
    b.box((0, height / 2, g + depth - wall / 2), (width + 0.02, height, wall), step=0.25, dent=0.003, matrix=fm)
    b.box((0, height / 2, g + wall / 2), (width, height, wall), step=0.25, dent=0.003, matrix=fm)
    for side in (-1, 1):
        b.box((side * (width / 2 - wall / 2), height / 2, g + depth / 2), (wall, height, depth), step=0.25, dent=0.003, matrix=fm)
    if rail:
        b.box((0, height + 0.01, g + depth - wall / 2 + 0.005), (width + 0.05, 0.02, wall + 0.02), step=0.25, dent=0.002, matrix=fm)
    b.build()
    s = Body(name + " Erde", M["soil"], coll, seed=seed + 1)
    s.box((0, height - 0.045, g + depth / 2), (width - 2 * wall - 0.004, 0.05, depth - 2 * wall - 0.004), step=0.2, dent=0.006, matrix=fm)
    s.build()


def chalkboard(M, coll, pos, yaw, image, name="Kreidetafel", seed=140):
    """Aufsteller (Kreidetafel) mit dem Bild der Entwicklerin auf beiden Seiten: oben am
    Scharnier zusammen, unten gespreizt, beide Füße auf dem Boden. image = sign_material(...)."""
    x, y = pos
    m = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    a = math.radians(12)
    hinge = 0.84
    drop = hinge * (1 - math.cos(a))

    def leaf_matrix(side):
        return m @ Matrix.Translation((0, 0, hinge - drop)) @ Matrix.Rotation(-side * a, 4, "X") @ Matrix.Translation((0, 0, -hinge))
    w = Body(name + " Rahmen", M["wood"], coll, seed=seed, vary=0.05, bevel=0.008)
    pic = Body(name + " Bild", image, coll, seed=seed + 1, vary=0.0, bevel=0.0)
    bw, bh = 0.42, 0.7
    for side in (-1, 1):
        fm = leaf_matrix(side)
        for c, sz in (((-bw / 2 - 0.02, side * -0.02, 0.43), (0.04, 0.03, 0.86)), ((bw / 2 + 0.02, side * -0.02, 0.43), (0.04, 0.03, 0.86)),
                      ((0, side * -0.02, 0.43 + bh / 2 + 0.02), (bw + 0.08, 0.03, 0.04)), ((0, side * -0.02, 0.43 - bh / 2 - 0.02), (bw + 0.08, 0.03, 0.04))):
            w.box(c, sz, step=0.3, dent=0.002, matrix=fm)
        # Bild zeigt nach außen (vorn bei side = 1 nach -y, hinten nach +y)
        pm = fm @ Matrix.Translation((0, side * -0.02, 0.43)) @ Matrix.Rotation(math.radians(90 if side > 0 else -90), 4, "X")
        if side < 0:
            pm = pm @ Matrix.Rotation(math.pi, 4, "Z")
        pic.panel(pm @ Matrix.Translation((0, 0, -0.006)), bw, bh, 0.012)
    w.build()
    pic.build()


# --- Hilfen ---

def front_matrix(x, z, y=0.0, turn=0.0):
    """Ebene der Fassade: lokal x = Welt x, lokal y = Welt z (oben), lokal z = Welt -y (zur
    Straße); turn = Drehung in der Wand (Grad)."""
    m = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    return Matrix.Translation((x, y, z)) @ m @ Matrix.Rotation(math.radians(turn), 4, "Z")


def add_bevel(obj, width):
    mod = obj.modifiers.new("Weiche Kanten", "BEVEL")
    mod.width = width * SB.BEVEL_SCALE
    mod.segments = 3
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(40)


def add_light(name, pos, kelvin, watt, coll, kind="POINT", radius=0.05, size=1.0):
    data = bpy.data.lights.new(name, kind)
    data.energy = watt
    data.color = kelvin_rgb(kelvin)
    if kind == "POINT":
        data.shadow_soft_size = radius
    elif kind == "AREA":
        data.size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = pos
    # Lampe selbst unsichtbar (auch durch Glas und in Spiegelungen), nur ihr Licht wirkt
    obj.visible_camera = False
    obj.visible_transmission = False
    obj.visible_glossy = False
    if kind == "AREA":
        obj.rotation_euler = (0, 0, 0)
    coll.objects.link(obj)
    return obj


def kelvin_rgb(k):
    """Grobe Farbe einer Glühlampe (linear) – 2700 K sehr warm, 3500 K warm."""
    table = {2700: (1.0, 0.52, 0.2), 3000: (1.0, 0.6, 0.28), 3500: (1.0, 0.69, 0.4), 4000: (1.0, 0.76, 0.52)}
    return table.get(k, (1.0, 0.69, 0.4))


def pavement(M, C, seed=300, half=4.2):
    """Gehweg, Bordstein und Kopfsteinpflaster vor dem Haus – nur für die Vorschaubilder."""
    rnd = random.Random(seed)
    s = Body("Gehwegplatten", M["slab"], C["env"], seed=seed, vary=0.1, bevel=0.012)
    y = 0.02
    while y > -2.35:
        depth = rnd.uniform(0.5, 0.7)
        x = -4.2 + rnd.uniform(0, 0.4)
        while x < 4.2:
            wdt = rnd.uniform(0.5, 0.95)
            s.box((x + wdt / 2, y - depth / 2, -0.04 + rnd.uniform(-0.004, 0.004)), (wdt - 0.014, depth - 0.014, 0.08), step=0.4,
                  dent=0.004, turn=(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(-1, 1)))
            x += wdt
        y -= depth
    s.build()
    cb = Body("Bordstein", M["curb"], C["env"], seed=seed + 1, vary=0.06, bevel=0.015)
    x = -4.2
    while x < 4.2:
        L = rnd.uniform(0.6, 1.0)
        cb.box((x + L / 2, -2.48, -0.09), (L - 0.012, 0.2, 0.2), step=0.3, dent=0.004, turn=(0, 0, rnd.uniform(-0.8, 0.8)))
        x += L
    cb.build()
    co = Body("Kopfsteinpflaster", M["cobble"], C["env"], seed=seed + 2, vary=0.16, bevel=0.018)
    y = -2.62
    row = 0
    while y > -6.0:
        h = rnd.uniform(0.09, 0.13)
        x = -4.2 + (0.06 if row % 2 else 0) + rnd.uniform(-0.03, 0.03)
        while x < 4.2:
            wdt = rnd.uniform(0.1, 0.17)
            co.box((x + wdt / 2, y - h / 2, -0.17 + rnd.uniform(-0.008, 0.01)), (wdt - 0.016, h - 0.016, 0.08), step=1,
                   dent=0.01, dent_scale=12, turn=(rnd.uniform(-3, 3), rnd.uniform(-3, 3), rnd.uniform(-6, 6)))
            x += wdt
        y -= h
        row += 1
    co.build()
    e = Body("Untergrund", M["earth"], C["env"], seed=seed + 3)
    e.box((0, -3.0, -0.28), (8.6, 6.4, 0.3), step=2, dent=0)
    e.build()


def settle(objects, p, half, eaves, ridge):
    """Alles gemeinsam leicht verziehen (Wellen, Neigung, Durchhang von Traufe und Dach), wie über
    Jahrzehnte gesetzt. half = halbe Hausbreite, eaves/ridge = Traufe/First (m). An den Brandwänden
    wandert nichts zur Seite, unten steht das Haus fest."""
    HW, E, RIDGE = half, eaves, ridge
    seed = Vector((3.1, 7.7, 1.3))
    for obj in objects:
        if obj.type != "MESH":
            continue
        mw = obj.matrix_world
        inv = mw.inverted()
        for v in obj.data.vertices:
            wp = mw @ v.co
            d = noise.noise_vector(wp / p["wavelength"] + seed) * p["wave"]
            d.x *= SB.smooth((HW - abs(wp.x)) / 0.6)
            d.z *= SB.smooth(wp.z / 0.8)
            d.y -= p["lean"] * max(wp.z, 0.0)
            across = max(0.0, 1 - (wp.x / HW) ** 2)
            if wp.z > E - 1.2:
                d.z -= p["eaves_sag"] * across * SB.smooth((wp.z - (E - 1.2)) / 1.2)
            if wp.z > E:
                r = SB.smooth((wp.z - E) / (RIDGE - E))
                d.z += (-p["roof_sag"] * across + p["ridge_tilt"] * wp.x / HW) * r
            v.co = inv @ (wp + d)
    for obj in objects:
        if obj.type == "LIGHT":
            wp = obj.location
            obj.location = wp + Vector((0, -p["lean"] * max(wp.z, 0.0), 0))


def colliders(C, obstacles):
    """Kästen für die Kollision im Spiel (in Blender nur als Drahtgitter sichtbar)."""
    out = []
    for name, entry in obstacles.items():
        # ((x, y), (Breite, Tiefe), Höhe[, Drehung in Grad um die Hochachse])
        (x, y), (sx, sy), h = entry[:3]
        yaw = entry[3] if len(entry) > 3 else 0.0
        b = Body(name + "-colonly", None, C["collision"], vary=0)
        b.box((x, y, h / 2), (sx, sy, h), step=10, dent=0, turn=(0, 0, yaw))
        obj = b.build()
        obj.display_type = "WIRE"
        obj.hide_render = True
        out.append(obj)
    return out


def slug(name):
    table = {"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss"}
    out = "".join(table.get(ch, ch) for ch in name.lower())
    return "".join(ch if ch.isalnum() else "_" for ch in out).strip("_")


def write_game_materials():
    """Je Blender-Material ein Godot-Material (Shader storybook.gdshader, Glas eigenes Material).
    Liefert {Blender-Name: res-Pfad}."""
    os.makedirs(GAME_MAT_DIR, exist_ok=True)
    out = {}
    for name, v in GAME_MATERIALS.items():
        path = os.path.join(GAME_MAT_DIR, slug(name) + ".tres")
        res = "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")
        out[name] = res
        if v.get("image"):
            png = "res://" + os.path.relpath(v["image"], ROOT).replace(os.sep, "/")
            text = ('[gd_resource type="StandardMaterial3D" load_steps=2 format=3]\n\n'
                    '; Schild-Bild der Entwicklerin – Bild austauschen: %s\n\n'
                    '[ext_resource type="Texture2D" path="%s" id="1_image"]\n\n'
                    '[resource]\nresource_name = "%s"\nalbedo_texture = ExtResource("1_image")\nroughness = 0.7\n'
                    'metallic_specular = 0.25\ntexture_filter = 5\n' % (png, png, name))
            with open(path, "w") as f:
                f.write(text)
            continue
        c = v["color"]
        head = "; Erzeugt von den Bilderbuch-Bau-Scripts (tools/blender/build_storybook_*.py, Blender-Material \"%s\") – wird beim Neubau\n; überschrieben. Werte gern ausprobieren, dauerhaft aber im Bau-Script ändern.\n" % name
        if v.get("glass"):
            text = ('[gd_resource type="StandardMaterial3D" format=3]\n\n%s\n[resource]\nresource_name = "%s"\n'
                    'transparency = 1\nalbedo_color = Color(%.3f, %.3f, %.3f, 0.06)\nmetallic_specular = 0.12\nroughness = 0.15\n'
                    % (head, name, c[0], c[1], c[2]))
        else:
            c2 = v.get("color2") or c
            ec = v.get("emit_color") or c
            emit = v.get("emit", 0.0)
            text = ('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n%s\n'
                    '[ext_resource type="Shader" path="res://assets/shaders/%s.gdshader" id="1_shader"]\n\n'
                    '[resource]\nresource_name = "%s"\nrender_priority = 0\nshader = ExtResource("1_shader")\n'
                    'shader_parameter/base_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/second_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/grain = %d\nshader_parameter/stripe_width = %.3f\nshader_parameter/vary = %.3f\n'
                    'shader_parameter/blot_scale = %.3f\nshader_parameter/bump_strength = %.3f\nshader_parameter/rough = %.3f\n'
                    'shader_parameter/metal = %.3f\nshader_parameter/emission_color = Color(%.3f, %.3f, %.3f, 1)\n'
                    'shader_parameter/emission_energy = %.3f\nshader_parameter/glow = %.3f\n'
                    'shader_parameter/wind_strength = %.3f\n'
                    % (head, "storybook_plant" if v["plant"] else "storybook", name, c[0], c[1], c[2], c2[0], c2[1], c2[2], GRAIN_ID[v.get("grain", "plaster")], v.get("stripes") or 0.0,
                       v.get("vary", 0.08), v.get("scale", 4.0), v.get("bump", 0.25), v.get("rough", 0.85), v.get("metal", 0.0),
                       ec[0], ec[1], ec[2], emit * 0.45, v["glow"], v.get("wind", 0.0)))
        with open(path, "w") as f:
            f.write(text)
    return out


def leaf_tops(me):
    """Von jedem Blatt (Insel aus Ober-, Unterseite und Rand) nur die größte Fläche behalten –
    im Spiel sind Blätter von beiden Seiten sichtbar (storybook_plant.gdshader)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    seen = set()
    drop = []
    for f in bm.faces:
        if f.index in seen:
            continue
        island, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        # Nur flache Inseln (Blätter, Blütenblätter) – Stiele u. Ä. haben keine große Fläche
        if len(island) > 3:
            keep = max(island, key=lambda g: g.calc_area())
            if keep.calc_area() > 0.3 * sum(g.calc_area() for g in island):
                drop += [g for g in island if g is not keep]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(me)
    bm.free()


def export_objects(objs, cols, path, simplify=None):
    """Alle Teile mit gleichem Material zu einem Netz zusammenfassen (wenige Zeichenaufrufe),
    Modifikatoren anwenden und als .glb speichern. simplify(material) = True: nur die Oberseiten
    der Blätter (leaf_tops). Die Einzelteile bleiben unverändert."""
    tmp = SB.collection("_export")
    groups = {}
    for obj in objs:
        if obj.type == "MESH" and obj.data.materials and obj.data.materials[0] is not None:
            groups.setdefault(obj.data.materials[0].name, []).append(obj)
    dg = bpy.context.evaluated_depsgraph_get()
    merged = []
    for name, objs in groups.items():
        copies = []
        for o in objs:
            me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
            c = bpy.data.objects.new(name, me)
            c.matrix_world = o.matrix_world
            tmp.objects.link(c)
            copies.append(c)
        if simplify and simplify(objs[0].data.materials[0]):
            for c in copies:
                leaf_tops(c.data)
        with bpy.context.temp_override(active_object=copies[0], object=copies[0], selected_objects=copies,
                                       selected_editable_objects=copies):
            bpy.ops.object.join()
        obj = copies[0]
        obj.name = name
        ca = obj.data.color_attributes.get("tint")
        if ca:
            obj.data.color_attributes.active_color = ca
            obj.data.color_attributes.render_color_index = list(obj.data.color_attributes).index(ca)
        merged.append(obj)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in merged + cols:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Bilder (Schilder) nicht in die .glb packen – Godot nimmt die eigenen Materialien
    # (assets/materials/storybook/), die auf assets/textures/signs/*.png zeigen
    extra = {"export_image_format": "NONE"} if "NONE" in [i.identifier for i in
             bpy.ops.export_scene.gltf.get_rna_type().properties["export_image_format"].enum_items] else {}
    bpy.ops.export_scene.gltf(filepath=path, **extra, export_format="GLB", use_selection=True, export_apply=True, export_colors=True,
                              export_lights=False, export_cameras=False, export_texcoords=True, export_normals=True,
                              export_yup=True, export_materials="EXPORT")
    tris = sum(len(p.vertices) - 2 for o in merged for p in o.data.polygons)
    for o in merged:
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    bpy.data.collections.remove(tmp)
    return tris, len(merged)


def write_import_settings(mapping, path):
    """Godot-Importeinstellungen: Materialien der .glb -> assets/materials/storybook/*.tres;
    Detailstufen (LOD) an, damit das Haus aus der Ferne günstiger wird."""
    entries = ",\n".join('"%s": {\n"use_external/enabled": true,\n"use_external/path": "%s"\n}' % (k, v)
                          for k, v in sorted(mapping.items()))
    res = "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")
    text = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="%s"

[params]

meshes/generate_lods=true
_subresources={
"materials": {
%s
}
}
""" % (res, entries)
    with open(path + ".import", "w") as f:
        f.write(text)


def blend_fingerprint(BLEND):
    import hashlib
    with open(BLEND, "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()


def edited_by_hand(BLEND, STAMP):
    """Wurde die .blend nach dem letzten Bau in Blender geändert? (Fingerabdruck stimmt nicht.)"""
    if not os.path.exists(BLEND) or not os.path.exists(STAMP):
        return False
    return open(STAMP).read().strip() != blend_fingerprint(BLEND)


def setup_render(quick):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48 if quick else 320
    sc.cycles.max_bounces = 8
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.02
    sc.cycles.sample_clamp_indirect = 3.0
    sc.cycles.blur_glossy = 1.0
    sc.cycles.caustics_refractive = False
    sc.cycles.caustics_reflective = False
    try:
        sc.cycles.use_denoising = True
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        sc.cycles.use_denoising = False
    sc.view_settings.view_transform = "Filmic"
    sc.view_settings.look = "Medium Contrast"
    sc.view_settings.exposure = 0.15
    world = bpy.data.worlds.new("Himmel")
    sc.world = world
    world.use_nodes = True
    N, L = world.node_tree.nodes, world.node_tree.links
    bg = N["Background"]
    sky = N.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    sky.sun_elevation = math.radians(24)
    sky.sun_rotation = math.radians(215)
    sky.sun_intensity = 0.0
    warm = N.new("ShaderNodeMixRGB")
    warm.blend_type = "MULTIPLY"
    warm.inputs[0].default_value = 1.0
    warm.inputs[2].default_value = (1.0, 0.86, 0.7, 1)
    L.new(sky.outputs[0], warm.inputs[1])
    L.new(warm.outputs[0], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.42
    sun = bpy.data.lights.new("Sonne 3500 K", "SUN")
    sun.energy = 3.6
    sun.color = kelvin_rgb(3500)
    sun.angle = math.radians(9)
    so = bpy.data.objects.new("Sonne 3500 K", sun)
    so.rotation_euler = (math.radians(58), 0, math.radians(-38))
    sc.collection.objects.link(so)
    # mildes, warmes Leuchten um Lichter (Bloom)
    sc.use_nodes = True
    tree = sc.node_tree
    rl = tree.nodes["Render Layers"]
    comp = tree.nodes["Composite"]
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"
    glare.quality = "HIGH"
    glare.threshold = 0.85
    glare.size = 8
    glare.mix = -0.72
    tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], comp.inputs["Image"])


def render(name, cam, target, lens, res, focus=None, fstop=6.0):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.dof.use_dof = True
    data.dof.aperture_fstop = fstop
    obj = bpy.data.objects.new("Kamera " + name, data)
    sc.collection.objects.link(obj)
    obj.location = cam
    obj.rotation_euler = (Vector(target) - Vector(cam)).to_track_quat("-Z", "Y").to_euler()
    data.dof.focus_distance = focus or (Vector(target) - Vector(cam)).length
    sc.camera = obj
    os.makedirs(SHOTS, exist_ok=True)
    sc.render.filepath = os.path.join(SHOTS, name + ".png")
    bpy.ops.render.render(write_still=True)


