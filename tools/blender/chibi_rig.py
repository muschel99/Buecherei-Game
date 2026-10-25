"""Skelett und Gewichte der Chibi-Figuren (seit Etappe 5c, Neubau).

Skelett: Knochennamen wie Godots SkeletonProfileHumanoid. Die Gelenke liegen da, wo sich der Körper
wirklich biegt: Schultergelenk mitten im Oberarm-Ansatz, Schlüsselbein vom Halsansatz fast waagerecht
zur Schulter (keine hängenden Schultern), Ellbogen/Knie/Finger genau auf den Ringen des Netzes.

Gewichte (welcher Knochen welche Haut bewegt): Jede Ecke weiß aus dem Käfig, zu welchem Körperteil
sie gehört (Bereiche, beim Glätten weich verteilt). Danach bestimmt die Lage entlang des Arms, Beins
oder Fingers, wie stark die Knochen ziehen – mit breiten, weichen Übergängen an den Gelenken (früher
1,2 cm, an den Fingern 4 mm: Knicke und Ballons beim Bewegen). Zum Schluss werden die Gewichte über
das Netz geglättet. Reines numpy.
"""

import numpy as np

ARM_BONES = ("UpperArm", "LowerArm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little")
LEG_BONES = ("UpperLeg", "LowerLeg", "Foot", "Toes")
FINGER_NAMES = ("Thumb", "Index", "Middle", "Ring", "Little")
SIDES = (("Left", 1.0), ("Right", -1.0))

# Breite der weichen Übergänge (m, halbe Breite um das Gelenk)
SPINE_BLEND = 0.35       # Anteil der Wirbel-Abschnitte
SHOULDER_BLEND = (-0.036, 0.026)  # Rumpf → Oberarm, entlang des Arms ab dem Schultergelenk
ARM_RADIAL = (1.05, 1.7)  # … und quer dazu: bis so viele Oberarm-Radien von der Armachse
ELBOW_BLEND = 0.024
WRIST_BLEND = 0.015
KNEE_BLEND = 0.030
ANKLE_BLEND = 0.020
TOE_BLEND = 0.014
NECK_BLEND = 0.012
SMOOTH_ITERATIONS = 4    # Gewichte so oft über das Netz glätten
MAX_INFLUENCES = 4


def ss(a, b, x):
    """Weicher Übergang 0 → 1 zwischen a und b."""
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------------------------------
# Skelett
# ---------------------------------------------------------------------------------------------

def spine_heads(body):
    cr, T = body.crotch, body.T
    return {"Hips": cr + 0.17 * T, "Spine": cr + 0.33 * T, "Chest": cr + 0.55 * T, "UpperChest": cr + 0.74 * T,
            "Neck": body.neck_base - 0.01}


def clavicle_head(body, s):
    """Schlüsselbein-Ansatz am Halsansatz: fast auf Schulterhöhe, leicht vor der Wirbelsäule."""
    return np.array((s * 0.025, 0.004, body.shoulder_z + 0.012))


def bones(body):
    """[(Name, Kopf, Ende, Eltern)] – Namen wie Godots SkeletonProfileHumanoid."""
    h = spine_heads(body)
    out = [
        ("Hips", (0, 0.014, h["Hips"]), (0, 0.016, h["Spine"]), None),
        ("Spine", (0, 0.016, h["Spine"]), (0, 0.018, h["Chest"]), "Hips"),
        ("Chest", (0, 0.018, h["Chest"]), (0, 0.018, h["UpperChest"]), "Spine"),
        ("UpperChest", (0, 0.018, h["UpperChest"]), (0, 0.018, h["Neck"]), "Chest"),
        ("Neck", (0, 0.018, h["Neck"]), (0, 0.022, body.chin + 0.03), "UpperChest"),
        ("Head", (0, 0.022, body.chin + 0.03), (0, 0.022, body.chin + 0.33), "Neck"),
    ]
    for side, s in SIDES:
        a = body.joints_arm[side]
        hand = body.hands[side]["fingers"]
        out.append((side + "Shoulder", clavicle_head(body, s), a["shoulder"], "UpperChest"))
        out.append((side + "UpperArm", a["shoulder"], a["elbow"], side + "Shoulder"))
        out.append((side + "LowerArm", a["elbow"], a["wrist"], side + "UpperArm"))
        out.append((side + "Hand", a["wrist"], hand["Middle"]["pts"][0], side + "LowerArm"))
        for fname in FINGER_NAMES:
            pts = hand[fname]["pts"]
            names = ("Metacarpal", "Proximal", "Distal") if fname == "Thumb" else ("Proximal", "Intermediate", "Distal")
            parent = side + "Hand"
            for i, n in enumerate(names):
                out.append((f"{side}{fname}{n}", pts[i], pts[i + 1], parent))
                parent = f"{side}{fname}{n}"
        lg = body.joints_leg[side]
        out.append((side + "UpperLeg", lg["hip"], lg["knee"], "Hips"))
        out.append((side + "LowerLeg", lg["knee"], lg["ankle"], side + "UpperLeg"))
        out.append((side + "Foot", lg["ankle"], lg["ball"], side + "LowerLeg"))
        out.append((side + "Toes", lg["ball"], lg["toe"], side + "Foot"))
    return [(n, np.asarray(a, float), np.asarray(b, float), p) for n, a, b, p in out]


def limb_offsets(body, other):
    """Wie weit Arme und Beine in der Form other gegenüber body verschoben sind (je Seite)."""
    out = {}
    for side, s in SIDES:
        out[side + "UpperArm"] = other.joints_arm[side]["shoulder"] - body.joints_arm[side]["shoulder"]
        out[side + "UpperLeg"] = other.joints_leg[side]["hip"] - body.joints_leg[side]["hip"]
    return out


def chain_children(names, root):
    """Alle Knochen, die (über Eltern) an root hängen – nach den Namen (Seite + Teil)."""
    side = "Left" if root.startswith("Left") else "Right"
    group = ARM_BONES if "Arm" in root else LEG_BONES
    return [i for i, n in enumerate(names) if n.startswith(side) and any(b in n for b in group)]


# ---------------------------------------------------------------------------------------------
# Gewichte
# ---------------------------------------------------------------------------------------------

class Weights:
    """Sammelt Gewichte je Knochen für alle Ecken."""

    def __init__(self, n, names):
        self.names = names
        self.index = {b: i for i, b in enumerate(names)}
        self.w = np.zeros((n, len(names)))

    def add(self, mask, bone, value):
        self.w[mask, self.index[bone]] += value


def _torso(body, p):
    """Rumpf: Wirbel nach der Höhe, oben an den Schultern das Schlüsselbein. Liefert {Knochen: Anteil}."""
    h = spine_heads(body)
    z = p[:, 2]
    keys = ["Hips", "Spine", "Chest", "UpperChest", "Neck"]
    zs = [h[k] for k in keys]
    up = []   # weicher Übergang am Kopf von Spine, Chest, UpperChest
    for i in range(1, 4):
        b = SPINE_BLEND * min(zs[i] - zs[i - 1], zs[i + 1] - zs[i])
        up.append(ss(zs[i] - b, zs[i] + b, z))
    out = {"Hips": 1.0 - up[0], "Spine": up[0] * (1.0 - up[1]), "Chest": up[1] * (1.0 - up[2]), "UpperChest": up[2]}
    # Schlüsselbein: Schulterdach und Ansatz des Trapezes (nicht am Hals, nicht unter der Achsel)
    sz = body.shoulder_z
    rest = np.ones(len(p))
    shoulder = {}
    for side, s in SIDES:
        lateral = s * p[:, 0]
        w = 0.85 * ss(0.035, 0.105, lateral) * ss(sz - 0.035, sz + 0.015, z)
        shoulder[side + "Shoulder"] = w
        rest -= w
    out = {k: v * rest for k, v in out.items()}
    out.update(shoulder)
    return out


def _arm(body, p, side, s):
    """Arm: Rumpf → Oberarm am Schultergelenk, Oberarm → Unterarm → Hand. Am Ansatz zieht der
    Oberarm nur Haut nah an seiner Achse mit – Rücken und Brust daneben bleiben beim Rumpf (sonst
    beult sich der Rücken aus, wenn die Arme nach vorn gehen)."""
    a = body.joints_arm[side]
    t = s * (p[:, 0] - a["shoulder"][0])
    rho = np.hypot(p[:, 1] - a["shoulder"][1], p[:, 2] - a["shoulder"][2])
    r_up = body.r_arm[0]
    e, w = body.upper_arm, body.upper_arm + body.fore_arm
    near = np.maximum(1.0 - ss(ARM_RADIAL[0] * r_up, ARM_RADIAL[1] * r_up, rho), ss(0.02, 0.07, t))
    into = ss(SHOULDER_BLEND[0], SHOULDER_BLEND[1], t) * near
    elbow = ss(e - ELBOW_BLEND, e + ELBOW_BLEND, t)
    wrist = ss(w - WRIST_BLEND, w + WRIST_BLEND, t)
    out = {k: v * (1.0 - into) for k, v in _torso(body, p).items()}
    out[side + "UpperArm"] = into * (1.0 - elbow)
    out[side + "LowerArm"] = into * elbow * (1.0 - wrist)
    out[side + "Hand"] = into * wrist
    return out


def _chain_param(p, pts):
    """Lage entlang einer Gliederkette (Bogenlänge; vor dem ersten Punkt negativ) und Abstand."""
    best_d = np.full(len(p), np.inf)
    best_s = np.zeros(len(p))
    start = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        L = float(np.linalg.norm(ab))
        t = ((p - a) @ ab) / (L * L)
        tc = np.clip(t, 0.0 if i > 0 else -np.inf, 1.0 if i < len(pts) - 2 else np.inf)
        q = a + tc[:, None] * ab
        d = np.linalg.norm(p - q, axis=1)
        better = d < best_d
        best_d = np.where(better, d, best_d)
        best_s = np.where(better, start + tc * L, best_s)
        start += L
    return best_s, best_d


def _finger(body, p, side, name):
    """Finger: Hand → Grundglied am Knöchel, dann Mittel- und Endglied (Daumen: Mittelhand, Grund-, Endglied)."""
    f = body.hands[side]["fingers"][name]
    pts = f["pts"]
    s_arc, _ = _chain_param(p, pts)
    lens = [float(np.linalg.norm(pts[i + 1] - pts[i])) for i in range(3)]
    b = 0.55 * f["radii"][0]
    j1, j2 = lens[0], lens[0] + lens[1]
    names = ("Metacarpal", "Proximal", "Distal") if name == "Thumb" else ("Proximal", "Intermediate", "Distal")
    into = ss(-b, b, s_arc) if name != "Thumb" else ss(-0.004, 0.012, s_arc)
    w1 = ss(j1 - b, j1 + b, s_arc)
    w2 = ss(j2 - b, j2 + b, s_arc)
    return {side + "Hand": 1.0 - into, f"{side}{name}{names[0]}": into * (1.0 - w1),
            f"{side}{name}{names[1]}": into * w1 * (1.0 - w2), f"{side}{name}{names[2]}": into * w2}


def _leg(body, p, side, membership):
    """Bein: Hüfte → Oberschenkel (nach dem Bereich), Knie, Knöchel (nach der Höhe), Zehen (nach vorn)."""
    j = body.joints_leg[side]
    z, y = p[:, 2], p[:, 1]
    into = ss(0.05, 0.75, membership)
    knee = ss(j["knee"][2] - KNEE_BLEND, j["knee"][2] + KNEE_BLEND, z)
    ankle = ss(j["ankle"][2] - ANKLE_BLEND, j["ankle"][2] + ANKLE_BLEND, z)
    toes = 1.0 - ss(j["ball"][1] - TOE_BLEND, j["ball"][1] + TOE_BLEND, y)
    out = {k: v * (1.0 - into) for k, v in _torso(body, p).items()}
    out[side + "UpperLeg"] = into * knee
    out[side + "LowerLeg"] = into * (1.0 - knee) * ankle
    out[side + "Foot"] = into * (1.0 - knee) * (1.0 - ankle) * (1.0 - toes)
    out[side + "Toes"] = into * (1.0 - knee) * (1.0 - ankle) * toes
    return out


def _neck_head(body, p, head_share):
    """Hals und Kopf: Rumpf → Hals am Halsansatz, Hals → Kopf unter dem Kinn; der Kopf selbst ist starr."""
    z = p[:, 2]
    nb, chin = body.neck_base, body.chin
    neck = ss(nb - NECK_BLEND, nb + NECK_BLEND, z)
    head = np.maximum(ss(chin + 0.004, chin + 0.03, z), head_share)
    out = {k: v * (1.0 - neck) * (1.0 - head) for k, v in _torso(body, p).items()}
    out["Neck"] = neck * (1.0 - head)
    out["Head"] = head
    return out


def skin_weights(body, p, regions, neighbors, names):
    """Gewichte aller Ecken p (mittlere Form). regions = {Bereich: Anteil je Ecke} aus dem geglätteten
    Käfig, neighbors = Nachbarecken je Ecke, names = Knochennamen. Liefert (N × Knochen)."""
    n = len(p)
    W = Weights(n, names)

    def m(name):
        return regions.get(name, np.zeros(n))

    assigned = np.zeros(n, bool)
    # Finger: wo ein Finger-Bereich anteilig ist und die Ecke vor dem Knöchel liegt
    for side, s in SIDES:
        best = np.zeros(n)
        pick = np.full(n, -1)
        for i, f in enumerate(FINGER_NAMES):
            v = m(f"finger_{side}_{f}")
            better = v > best
            best = np.where(better, v, best)
            pick = np.where(better, i, pick)
        for i, f in enumerate(FINGER_NAMES):
            mask = (pick == i) & (best > 0.01)
            if not mask.any():
                continue
            for bone, w in _finger(body, p[mask], side, f).items():
                W.add(mask, bone, w)
            assigned |= mask
    # Arme mit Händen
    for side, s in SIDES:
        arm = m("arm_" + side) + m("hand_" + side)
        mask = (arm > 0.01) & ~assigned
        for bone, w in _arm(body, p[mask], side, s).items():
            W.add(mask, bone, w)
        assigned |= mask
    # Beine mit Füßen
    for side, s in SIDES:
        leg = m("leg_" + side) + m("foot_" + side)
        mask = (leg > 0.01) & ~assigned
        for bone, w in _leg(body, p[mask], side, leg[mask]).items():
            W.add(mask, bone, w)
        assigned |= mask
    # Hals und Kopf
    nh = m("neck") + m("head")
    mask = (nh > 0.01) & ~assigned
    for bone, w in _neck_head(body, p[mask], ss(0.4, 0.95, m("head")[mask])).items():
        W.add(mask, bone, w)
    assigned |= mask
    # der Rest ist Rumpf
    mask = ~assigned
    for bone, w in _torso(body, p[mask]).items():
        W.add(mask, bone, w)
    w = W.w
    w /= np.maximum(w.sum(axis=1, keepdims=True), 1e-9)
    w = smooth(w, neighbors, SMOOTH_ITERATIONS)
    return prune(w)


def smooth(w, neighbors, iterations, factor=0.5):
    """Gewichte über das Netz glätten (jede Ecke ein Stück zum Mittel ihrer Nachbarn)."""
    for _ in range(iterations):
        avg = np.array([w[nb].mean(axis=0) for nb in neighbors])
        w = (1.0 - factor) * w + factor * avg
    return w


def prune(w, keep=MAX_INFLUENCES):
    """Nur die stärksten Knochen je Ecke behalten (Godot/glTF: 4), winzige Anteile weg."""
    order = np.argsort(-w, axis=1)[:, :keep]
    mask = np.zeros_like(w, bool)
    np.put_along_axis(mask, order, True, axis=1)
    w = np.where(mask & (w > 0.01), w, 0.0)
    return w / np.maximum(w.sum(axis=1, keepdims=True), 1e-9)
