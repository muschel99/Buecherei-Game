"""Gezeichnete Chibi-Gesichter (seit Etappe 5c): Augen, Iris, Augenbrauen und Münder als Bilder-
Atlanten (je Feld ein Ausdruck). In Godot setzt der Shader chibi_face.gdshader das Gesicht aus
den Atlanten zusammen (Ausdruck, Blickrichtung, Blinzeln, Wangenröte als Instanz-Werte);
compose() macht hier dasselbe in numpy (Kontrollbilder in Blender, Standard-Gesicht im .glb).

Reines numpy. Längen in Metern im Gesicht: fx = Bogenlänge quer über das Gesicht (+ = linke
Gesichtshälfte der Figur, vom Betrachter aus rechts), fz = Höhe über dem Kinn.
Linien sind gespiegelt (außen = Augenwinkel außen), die Iris nicht (Glanzpunkte für beide Augen
auf derselben Seite).
"""

import math
import os
import struct
import zlib

import numpy as np

# --- Lage im Gesicht (m) – muss zu chibi_face.gdshader passen -------------------------------
FACE_SIZE = 0.48          # UV 0..1 entspricht 0,48 m
FACE_RADIUS = 0.21        # Radius der Zylinder-Abwicklung (Kopfmitte)
FACE_AXIS_Y = 0.0138      # Kopfachse (y) für die Abwicklung
EYE_X, EYE_Z = 0.078, 0.160
EYE_CELL = 0.085          # Größe eines Feldes im Atlas (Zeichnung in m)
IRIS_CELL = 0.05
EYE_SCALE = 1.62          # Augen im Gesicht so viel größer als gezeichnet
BROW_X, BROW_Z = 0.080, 0.246
BROW_CELL = (0.07, 0.035)
BROW_SCALE = 1.35
MOUTH_Z = 0.081
MOUTH_CELL = 0.06
MOUTH_SCALE = 1.45
BLUSH_X, BLUSH_Z = 0.122, 0.112
BLUSH_R = (0.030, 0.016)

CELL_PX = 256
LINE = (0.23, 0.14, 0.13)
LINE_SOFT = (0.42, 0.28, 0.26)

EYE_FRAMES = ["open", "half", "closed", "happy", "wide", "sad", "angry", "soft"]
IRIS_FRAMES = ["normal", "heart", "sparkle", "spiral"]
BROW_FRAMES = ["neutral", "raised", "worried", "angry", "sad", "flat", "focused", "relaxed"]
MOUTH_FRAMES = ["smile", "smile_wide", "open_smile", "laugh", "o", "O", "flat", "frown",
                "cat", "wavy", "sad_open", "smirk", "talk_a", "talk_e", "talk_o", "pout"]


# ---------------------------------------------------------------------------------------------
# Zeichnen mit Abstandsfeldern (weiche Kanten)
# ---------------------------------------------------------------------------------------------

class Layer:
    def __init__(self, w, h, size_x, size_y):
        self.w, self.h = w, h
        self.px = size_x / w
        xs = (np.arange(w) + 0.5) / w * size_x - size_x / 2
        ys = size_y / 2 - (np.arange(h) + 0.5) / h * size_y
        self.X, self.Y = np.meshgrid(xs, ys)
        self.rgb = np.zeros((h, w, 3))
        self.a = np.zeros((h, w))

    def cov(self, d, soft=1.0):
        return np.clip(0.5 - d / (self.px * soft), 0.0, 1.0)

    def paint(self, d, color, alpha=1.0, soft=1.0):
        c = self.cov(d, soft) * alpha
        self.rgb = self.rgb * (1 - c[..., None]) + np.array(color)[None, None, :] * c[..., None]
        self.a = self.a * (1 - c) + c

    def rgba(self):
        out = np.zeros((self.h, self.w, 4))
        out[..., :3] = self.rgb / np.maximum(self.a, 1e-6)[..., None]
        out[..., 3] = self.a
        return out


def sd_ellipse(X, Y, cx, cy, rx, ry, rot=0.0):
    dx, dy = X - cx, Y - cy
    if rot:
        c, s = math.cos(rot), math.sin(rot)
        dx, dy = c * dx + s * dy, -s * dx + c * dy
    k0 = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
    k1 = np.sqrt((dx / (rx * rx)) ** 2 + (dy / (ry * ry)) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_stroke(X, Y, pts, widths):
    """Linie durch pts mit Breite je Punkt (spitz zulaufend möglich), runde Enden."""
    pts = np.asarray(pts, float)
    widths = np.asarray(widths, float)
    best = np.full(X.shape, 1.0)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        l2 = max(float(ab @ ab), 1e-12)
        t = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / l2, 0.0, 1.0)
        dx = X - (a[0] + ab[0] * t)
        dy = Y - (a[1] + ab[1] * t)
        w = widths[i] + (widths[i + 1] - widths[i]) * t
        best = np.minimum(best, np.sqrt(dx * dx + dy * dy) - w * 0.5)
    return best


def sd_poly(X, Y, pts):
    """Gefülltes Vieleck (gerade-ungerade Regel), negativ innen."""
    pts = np.asarray(pts, float)
    n = len(pts)
    dist = np.full(X.shape, 1.0)
    inside = np.zeros(X.shape, bool)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        ab = b - a
        l2 = max(float(ab @ ab), 1e-12)
        t = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / l2, 0.0, 1.0)
        dx = X - (a[0] + ab[0] * t)
        dy = Y - (a[1] + ab[1] * t)
        dist = np.minimum(dist, np.sqrt(dx * dx + dy * dy))
        cond = ((a[1] > Y) != (b[1] > Y)) & (X < (b[0] - a[0]) * (Y - a[1]) / np.where(b[1] - a[1] == 0, 1e-12, b[1] - a[1]) + a[0])
        inside ^= cond
    return np.where(inside, -dist, dist)


def bezier(p0, p1, p2, p3, n=24):
    t = np.linspace(0.0, 1.0, n)[:, None]
    p0, p1, p2, p3 = (np.asarray(p, float) for p in (p0, p1, p2, p3))
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3


def taper(n, w0, w1, w2=None, mid=0.5):
    """Breiten entlang einer Linie: w0 am Anfang, w1 in der Mitte (bzw. am Ende), w2 am Ende."""
    t = np.linspace(0.0, 1.0, n)
    if w2 is None:
        return w0 + (w1 - w0) * t
    return np.where(t < mid, w0 + (w1 - w0) * (t / mid), w1 + (w2 - w1) * ((t - mid) / (1 - mid)))


# ---------------------------------------------------------------------------------------------
# Augen (Linien + Maske), Koordinaten: x nach außen, y nach oben, Mitte des Auges = 0
# ---------------------------------------------------------------------------------------------

EYE_RX, EYE_RY = 0.0205, 0.0275


def _eye_shape(frame):
    """(rx, ry, Oberlid(x) oder None, Unterlid(x) oder None, Linienstärke)"""
    rx, ry = EYE_RX, EYE_RY
    if frame == "wide":
        return rx * 1.1, ry * 1.08, None, None, 0.85
    if frame == "half":
        return rx, ry, (lambda x: 0.0015 + 0.0025 * x / rx), None, 1.0
    if frame == "sad":
        return rx, ry, (lambda x: ry * (0.55 - 0.45 * x / rx)), None, 1.0
    if frame == "angry":
        return rx, ry, (lambda x: ry * (0.45 + 0.4 * x / rx)), None, 1.0
    if frame == "soft":
        return rx, ry, None, (lambda x: -ry * 0.42 + 0.006 * (1 - (x / rx) ** 2)), 1.0
    return rx, ry, None, None, 1.0


def _upper_boundary(rx, ry, top, n=48):
    th = np.linspace(math.radians(174), math.radians(6), n)
    x = rx * np.cos(th)
    y = ry * np.sin(th)
    if top is not None:
        y = np.minimum(y, top(x))
        # nur der Teil, der noch im Auge liegt
        keep = y > -ry * np.sin(np.arccos(np.clip(x / rx, -1, 1))) + 1e-4
        x, y = x[keep], y[keep]
    return np.stack([x, y], axis=1)


def draw_eye(frame, gender):
    lay = Layer(CELL_PX, CELL_PX, EYE_CELL, EYE_CELL)
    mask = np.zeros((CELL_PX, CELL_PX, 4))
    X, Y = lay.X, lay.Y
    fem = gender == "female"
    lw = 1.0
    if frame in ("closed", "happy"):
        if frame == "closed":
            pts = bezier((-EYE_RX * 0.95, 0.001), (-EYE_RX * 0.4, -0.009), (EYE_RX * 0.5, -0.009), (EYE_RX * 1.15, 0.0))
            lash_dir = -1
        else:
            pts = bezier((-EYE_RX * 0.98, -0.007), (-EYE_RX * 0.5, 0.009), (EYE_RX * 0.55, 0.009), (EYE_RX * 1.1, -0.006))
            lash_dir = 1
        lay.paint(sd_stroke(X, Y, pts, taper(len(pts), 0.0012, 0.0036 * lw, 0.0044 * lw, 0.6)), LINE)
        if fem:
            # geschwungene Wimpern am äußeren Teil des geschlossenen Lids
            for i, (ang, ln) in enumerate(((10.0, 0.0062), (-15.0, 0.0068), (-40.0, 0.0062), (-62.0, 0.0050))):
                base = pts[-1 - i * 3]
                a = math.radians(ang * lash_dir)
                tip = base + np.array((math.cos(a), math.sin(a))) * ln
                ctrl = base + (tip - base) * 0.45 + np.array((0.0, lash_dir * 0.0016))
                lp = bezier(base, ctrl, ctrl, tip, 10)
                lay.paint(sd_stroke(X, Y, lp, taper(len(lp), 0.0017, 0.0)), LINE)
        return lay.rgba(), mask
    rx, ry, top, bottom, thick = _eye_shape(frame)
    # Öffnung (Weiß + Iris) als Maske
    d_open = sd_ellipse(X, Y, 0.0, 0.0, rx, ry)
    if top is not None:
        d_open = np.maximum(d_open, Y - top(X))
    if bottom is not None:
        d_open = np.maximum(d_open, bottom(X) - Y)
    mask[..., 0] = lay.cov(d_open)
    # Schatten unter dem Oberlid
    ell_top = ry * np.sqrt(np.clip(1 - (X / rx) ** 2, 0.0, 1.0))
    up = ell_top if top is None else np.minimum(ell_top, top(X))
    mask[..., 1] = np.clip(1.0 - (up - Y) / 0.009, 0.0, 1.0) * mask[..., 0]
    mask[..., 3] = 1.0
    # Oberlid-Linie entlang der oberen Grenze, außen dicker, mit Schwung nach außen
    ub = _upper_boundary(rx, ry, top)
    ub = ub + np.array((0.0, 0.0006))
    tail_end = ub[-1] + np.array((0.0075, -0.0005 if top is None else 0.0))
    tail = bezier(ub[-1], ub[-1] + np.array((0.003, 0.0)), tail_end - np.array((0.002, 0.0)), tail_end, 8)[1:]
    path = np.concatenate([ub, tail])
    n = len(path)
    w = np.concatenate([taper(len(ub), 0.0012 * thick, 0.0034 * lw * thick, 0.0048 * lw * thick, 0.45),
                        taper(len(tail), 0.0046 * lw * thick, 0.0004)])
    lay.paint(sd_stroke(X, Y, path, w), LINE)
    if fem:
        # fünf geschwungene Wimpern am äußeren Lid, nach außen länger
        for i, (ang, ln, w0) in enumerate(((78.0, 0.0050, 0.0013), (62.0, 0.0062, 0.0015), (44.0, 0.0074, 0.0017),
                                           (24.0, 0.0084, 0.0019), (4.0, 0.0072, 0.0018))):
            k = int(len(ub) - 1 - (4 - i) * 4)
            base = ub[max(k, 0)] + np.array((0.0, -0.0004))
            a = math.radians(ang)
            tip = base + np.array((math.cos(a), math.sin(a))) * ln
            # Schwung: erst nach oben, dann nach außen gebogen
            ctrl1 = base + np.array((math.cos(a + 0.5), math.sin(a + 0.5))) * ln * 0.45
            ctrl2 = tip - np.array((math.cos(a - 0.35), math.sin(a - 0.35))) * ln * 0.3
            lp = bezier(base, ctrl1, ctrl2, tip, 12)
            lay.paint(sd_stroke(X, Y, lp, taper(len(lp), w0, 0.0)), LINE)
        if bottom is None:
            # zwei feine Wimpern unten außen
            for ang_pos, ang, ln in ((-22.0, -35.0, 0.0034), (-42.0, -62.0, 0.0028)):
                t = math.radians(ang_pos)
                base = np.array((rx * math.cos(t), ry * math.sin(t))) * 1.02
                a = math.radians(ang)
                tip = base + np.array((math.cos(a), math.sin(a))) * ln
                lp = bezier(base, base + (tip - base) * 0.4 + np.array((0.0004, 0.0)), tip, tip, 8)
                lay.paint(sd_stroke(X, Y, lp, taper(len(lp), 0.0011, 0.0)), LINE_SOFT)
        # Lidfalte
        th = np.linspace(math.radians(118), math.radians(35), 20)
        crease = np.stack([rx * 1.08 * np.cos(th) + 0.001, ry * 1.08 * np.sin(th) + 0.0055], axis=1)
        if top is not None:
            crease[:, 1] = np.minimum(crease[:, 1], top(crease[:, 0]) + 0.006)
        lay.paint(sd_stroke(X, Y, crease, taper(len(crease), 0.0002, 0.0008, 0.0003)), LINE_SOFT, 0.55)
    # Unterlid: feine Linie außen
    if bottom is None:
        th = np.linspace(math.radians(-12), math.radians(-105), 24)
        low = np.stack([rx * np.cos(th) * 1.02, ry * np.sin(th) * 1.02], axis=1)
    else:
        xs = np.linspace(rx * 0.95, -rx * 0.6, 24)
        low = np.stack([xs, bottom(xs) - 0.0004], axis=1)
    lay.paint(sd_stroke(X, Y, low, taper(len(low), 0.0014 * lw, 0.0)), LINE_SOFT if bottom is None else LINE, 0.9)
    return lay.rgba(), mask


# ---------------------------------------------------------------------------------------------
# Iris: R = Helligkeit (oben dunkel), G = Glanzlicht, B = dunkle Linien/Pupille, A = Iris
# ---------------------------------------------------------------------------------------------

IRIS_RX, IRIS_RY = 0.0158, 0.0212


def _heart(X, Y, cx, cy, s):
    """Herz (Abstandsfeld nach Inigo Quilez), Spitze unten, Größe s (Höhe ≈ 1,1 s)."""
    x = np.abs(X - cx) / s
    y = (Y - cy) / s + 0.55
    upper = np.sqrt((x - 0.25) ** 2 + (y - 0.75) ** 2) - math.sqrt(2) / 4
    m = np.maximum(x + y, 0.0) * 0.5
    lower = np.sqrt(np.minimum(x * x + (y - 1.0) ** 2, (x - m) ** 2 + (y - m) ** 2)) * np.sign(x - y)
    return np.where(y + x > 1.0, upper, lower) * s


def _star(X, Y, cx, cy, r, thin=0.18):
    """Vierzackiger Glitzerstern."""
    dx, dy = np.abs(X - cx), np.abs(Y - cy)
    k = (dx / r) ** 0.5 + (dy / r) ** 0.5
    return (k - 1.0) * r * thin * 2


def draw_iris(frame):
    lay = Layer(CELL_PX, CELL_PX, IRIS_CELL, IRIS_CELL)
    X, Y = lay.X, lay.Y
    out = np.zeros((CELL_PX, CELL_PX, 4))
    d = sd_ellipse(X, Y, 0, 0, IRIS_RX, IRIS_RY)
    cov = lay.cov(d)
    k0 = np.sqrt((X / IRIS_RX) ** 2 + (Y / IRIS_RY) ** 2)
    shade = 0.28 + 0.72 * np.clip((IRIS_RY * 0.35 - Y) / (IRIS_RY * 1.2), 0.0, 1.0) ** 0.8
    shade *= 1.0 - 0.45 * np.clip((k0 - 0.72) / 0.28, 0.0, 1.0)
    # heller Bogen unten
    shade += 0.25 * np.clip(1 - np.abs(k0 - 0.68) / 0.12, 0, 1) * np.clip(-Y / IRIS_RY, 0, 1)
    out[..., 0] = np.clip(shade, 0.0, 1.0)
    dark = lay.cov(np.abs(d + 0.0006) - 0.0006) * 0.9            # Rand der Iris
    ang = np.arctan2(Y, X)
    streak = (0.5 + 0.5 * np.cos(ang * 22.0)) * np.clip((k0 - 0.45) / 0.4, 0, 1) * np.clip((0.95 - k0) / 0.2, 0, 1)
    dark = np.maximum(dark, 0.18 * streak * (Y < IRIS_RY * 0.2))
    hi = np.zeros_like(X)
    if frame == "heart":
        dark = np.maximum(dark, lay.cov(_heart(X, Y, 0.0, -0.001, 0.0135)) * 0.95)
        hi = np.maximum(hi, lay.cov(_heart(X, Y, -0.0062, 0.0085, 0.0062)))
        hi = np.maximum(hi, lay.cov(sd_ellipse(X, Y, 0.0068, -0.0095, 0.0018, 0.0018)))
    elif frame == "spiral":
        r = np.sqrt(X * X + Y * Y)
        sp = np.abs(((r / 0.0042 - ang / (2 * math.pi)) % 1.0) - 0.5) * 0.0042 - 0.0007
        dark = np.maximum(dark, lay.cov(sp) * (r < IRIS_RX * 0.95))
    else:
        dark = np.maximum(dark, lay.cov(sd_ellipse(X, Y, 0.0, -0.0008, 0.0066, 0.0094)) * 0.95)
        hi = np.maximum(hi, lay.cov(sd_ellipse(X, Y, -0.0060, 0.0085, 0.0054, 0.0062, rot=0.35)))
        hi = np.maximum(hi, lay.cov(sd_ellipse(X, Y, 0.0068, -0.0092, 0.0021, 0.0021)))
        hi = np.maximum(hi, 0.8 * lay.cov(sd_ellipse(X, Y, 0.0030, 0.0098, 0.0011, 0.0011)))
        if frame == "sparkle":
            hi = np.maximum(hi, lay.cov(_star(X, Y, 0.0055, 0.0035, 0.0055)))
            hi = np.maximum(hi, lay.cov(_star(X, Y, -0.0048, -0.0072, 0.0035)))
    out[..., 1] = hi * cov
    out[..., 2] = dark * cov
    out[..., 3] = cov
    return out


# ---------------------------------------------------------------------------------------------
# Augenbrauen (A = Deckkraft; Farbe kommt aus dem Shader), x nach außen
# ---------------------------------------------------------------------------------------------

def draw_brow(frame):
    w, h = BROW_CELL
    lay = Layer(CELL_PX, CELL_PX // 2, w, h)
    inner_y, mid_y, outer_y, lift = {
        "neutral": (0.0, 0.0035, -0.0015, 0.0),
        "raised": (0.0015, 0.0055, 0.0, 0.003),
        "worried": (0.0055, 0.002, -0.0035, 0.0),
        "angry": (-0.0050, 0.0005, 0.0035, 0.0),
        "sad": (0.0040, 0.0025, -0.0045, 0.0),
        "flat": (0.0, 0.001, 0.0, 0.0),
        "focused": (-0.0025, 0.0015, 0.001, 0.0),
        "relaxed": (-0.0005, 0.0025, -0.0025, -0.001),
    }[frame]
    p0 = (-0.019, inner_y + lift)
    p3 = (0.021, outer_y + lift)
    p1 = (-0.007, mid_y + 0.0015 + lift)
    p2 = (0.010, mid_y + 0.0012 + lift)
    pts = bezier(p0, p1, p2, p3, 28)
    lay.paint(sd_stroke(lay.X, lay.Y, pts, taper(len(pts), 0.0036, 0.0031, 0.0009, 0.35)), (1, 1, 1))
    return lay.rgba()


# ---------------------------------------------------------------------------------------------
# Münder (farbig), Mitte = 0
# ---------------------------------------------------------------------------------------------

MOUTH_INSIDE = (0.50, 0.17, 0.19)
TONGUE = (0.93, 0.52, 0.52)
TEETH = (0.99, 0.97, 0.93)


def _open_mouth(lay, top_pts, bottom_pts, tongue=True, teeth=False, line=0.0016):
    X, Y = lay.X, lay.Y
    poly = np.concatenate([top_pts, bottom_pts[::-1]])
    d = sd_poly(X, Y, poly)
    lay.paint(d, MOUTH_INSIDE)
    if tongue:
        lo = bottom_pts[:, 1].min()
        cx = bottom_pts[:, 0].mean()
        width = (bottom_pts[:, 0].max() - bottom_pts[:, 0].min()) * 0.32
        t = sd_ellipse(X, Y, cx, lo + 0.0005, width, (top_pts[:, 1].max() - lo) * 0.42)
        lay.paint(np.maximum(t, d), TONGUE)
    if teeth:
        hi = top_pts[:, 1].max()
        lay.paint(np.maximum(d, -(Y - (hi - 0.0028))), TEETH)
    lay.paint(np.abs(d) - line * 0.5, LINE)


def draw_mouth(frame):
    lay = Layer(CELL_PX, CELL_PX, MOUTH_CELL, MOUTH_CELL)
    X, Y = lay.X, lay.Y
    lw = 0.0017

    def line(pts, w0=0.0010, w1=lw, w2=0.0010):
        lay.paint(sd_stroke(X, Y, pts, taper(len(pts), w0, w1, w2, 0.5)), LINE)

    if frame == "smile":
        line(bezier((-0.0085, 0.0018), (-0.004, -0.0028), (0.004, -0.0028), (0.0085, 0.0018)))
    elif frame == "smile_wide":
        line(bezier((-0.0135, 0.003), (-0.006, -0.0042), (0.006, -0.0042), (0.0135, 0.003)))
    elif frame == "open_smile":
        top = bezier((-0.010, 0.002), (-0.004, 0.0005), (0.004, 0.0005), (0.010, 0.002), 16)
        bot = bezier((-0.010, 0.002), (-0.007, -0.010), (0.007, -0.010), (0.010, 0.002), 16)
        _open_mouth(lay, top, bot)
    elif frame == "laugh":
        top = bezier((-0.0145, 0.0035), (-0.006, 0.0015), (0.006, 0.0015), (0.0145, 0.0035), 16)
        bot = bezier((-0.0145, 0.0035), (-0.011, -0.016), (0.011, -0.016), (0.0145, 0.0035), 16)
        _open_mouth(lay, top, bot, teeth=True)
    elif frame == "o":
        d = sd_ellipse(X, Y, 0, -0.001, 0.0045, 0.0058)
        lay.paint(d, MOUTH_INSIDE)
        lay.paint(np.abs(d) - 0.0008, LINE)
    elif frame == "O":
        d = sd_ellipse(X, Y, 0, -0.002, 0.0078, 0.0105)
        lay.paint(d, MOUTH_INSIDE)
        lay.paint(np.maximum(sd_ellipse(X, Y, 0, -0.0095, 0.0045, 0.0035), d), TONGUE)
        lay.paint(np.abs(d) - 0.0008, LINE)
    elif frame == "flat":
        line(np.array([(-0.0075, 0.0), (0.0075, 0.0)]))
    elif frame == "frown":
        line(bezier((-0.008, -0.0025), (-0.004, 0.0018), (0.004, 0.0018), (0.008, -0.0025)))
    elif frame == "cat":
        a = bezier((0.0, 0.001), (-0.001, -0.004), (-0.007, -0.004), (-0.0085, 0.0015), 14)
        b = a * np.array((-1, 1))
        line(a, 0.0014, lw, 0.0008)
        line(b, 0.0014, lw, 0.0008)
    elif frame == "wavy":
        xs = np.linspace(-0.0105, 0.0105, 40)
        line(np.stack([xs, 0.0016 * np.sin(xs / 0.0105 * 2.5 * math.pi)], axis=1))
    elif frame == "sad_open":
        top = bezier((-0.0085, -0.004), (-0.004, 0.0045), (0.004, 0.0045), (0.0085, -0.004), 16)
        bot = bezier((-0.0085, -0.004), (-0.004, -0.0025), (0.004, -0.0025), (0.0085, -0.004), 16)
        _open_mouth(lay, top, bot, tongue=False)
    elif frame == "smirk":
        line(bezier((-0.0075, -0.0005), (-0.002, -0.002), (0.004, -0.0015), (0.0095, 0.003)))
    elif frame == "talk_a":
        top = bezier((-0.0075, 0.0015), (-0.003, 0.0025), (0.003, 0.0025), (0.0075, 0.0015), 16)
        bot = bezier((-0.0075, 0.0015), (-0.0055, -0.0085), (0.0055, -0.0085), (0.0075, 0.0015), 16)
        _open_mouth(lay, top, bot)
    elif frame == "talk_e":
        top = bezier((-0.0095, 0.001), (-0.004, 0.0018), (0.004, 0.0018), (0.0095, 0.001), 16)
        bot = bezier((-0.0095, 0.001), (-0.006, -0.0045), (0.006, -0.0045), (0.0095, 0.001), 16)
        _open_mouth(lay, top, bot, tongue=False, teeth=True)
    elif frame == "talk_o":
        d = sd_ellipse(X, Y, 0, -0.0015, 0.0058, 0.0072)
        lay.paint(d, MOUTH_INSIDE)
        lay.paint(np.abs(d) - 0.0008, LINE)
    elif frame == "pout":
        a = bezier((-0.0035, 0.004), (0.0015, 0.004), (0.0015, 0.0), (-0.0015, 0.0), 12)
        b = bezier((-0.0015, 0.0), (0.0015, 0.0), (0.0015, -0.004), (-0.0035, -0.004), 12)
        line(np.concatenate([a, b[1:]]), 0.0012, 0.0016, 0.0012)
    return lay.rgba()


# ---------------------------------------------------------------------------------------------
# Atlanten
# ---------------------------------------------------------------------------------------------

def build_atlases():
    """Liefert dict Name -> Bild (H, W, 4) in 0..1."""
    eyes = np.zeros((4 * CELL_PX, 4 * CELL_PX, 4))
    masks = np.zeros_like(eyes)
    for gi, gender in enumerate(("female", "male")):
        for i, f in enumerate(EYE_FRAMES):
            r, c = gi * 2 + i // 4, i % 4
            lines, mask = draw_eye(f, gender)
            eyes[r * CELL_PX:(r + 1) * CELL_PX, c * CELL_PX:(c + 1) * CELL_PX] = lines
            masks[r * CELL_PX:(r + 1) * CELL_PX, c * CELL_PX:(c + 1) * CELL_PX] = mask
    iris = np.zeros((2 * CELL_PX, 2 * CELL_PX, 4))
    for i, f in enumerate(IRIS_FRAMES):
        r, c = i // 2, i % 2
        iris[r * CELL_PX:(r + 1) * CELL_PX, c * CELL_PX:(c + 1) * CELL_PX] = draw_iris(f)
    brows = np.zeros((2 * CELL_PX // 2, 4 * CELL_PX, 4))
    for i, f in enumerate(BROW_FRAMES):
        r, c = i // 4, i % 4
        brows[r * CELL_PX // 2:(r + 1) * CELL_PX // 2, c * CELL_PX:(c + 1) * CELL_PX] = draw_brow(f)
    mouths = np.zeros((4 * CELL_PX, 4 * CELL_PX, 4))
    for i, f in enumerate(MOUTH_FRAMES):
        r, c = i // 4, i % 4
        mouths[r * CELL_PX:(r + 1) * CELL_PX, c * CELL_PX:(c + 1) * CELL_PX] = draw_mouth(f)
    return {"face_eyes": eyes, "face_eye_masks": masks, "face_iris": iris, "face_brows": brows,
            "face_mouths": mouths}


def write_png(path, img):
    """img (H, W, 4) in 0..1 -> 8-bit RGBA PNG (ohne Zusatzbibliotheken)."""
    a = (np.clip(img, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    h, w = a.shape[:2]
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


# ---------------------------------------------------------------------------------------------
# Ausdrücke und Zusammensetzen (wie der Shader)
# ---------------------------------------------------------------------------------------------

# Ausdruck = Augen, Iris, Augenbrauen, Mund, Wangenröte, Irisgröße
EXPRESSIONS = {
    "neutral": ("open", "normal", "neutral", "smile", 0.4, 1.0),
    "happy": ("soft", "normal", "relaxed", "open_smile", 0.55, 1.0),
    "laugh": ("happy", "normal", "raised", "laugh", 0.7, 1.0),
    "surprised": ("wide", "normal", "raised", "O", 0.2, 0.78),
    "sad": ("sad", "normal", "worried", "frown", 0.1, 1.0),
    "angry": ("angry", "normal", "angry", "flat", 0.35, 0.95),
    "sleepy": ("half", "normal", "relaxed", "o", 0.2, 1.0),
    "love": ("open", "heart", "raised", "cat", 0.9, 1.05),
    "excited": ("open", "sparkle", "raised", "open_smile", 0.6, 1.05),
    "blink": ("closed", "normal", "neutral", "smile", 0.25, 1.0),
    "worried": ("open", "normal", "worried", "wavy", 0.3, 0.9),
    "dizzy": ("open", "spiral", "worried", "wavy", 0.2, 1.0),
}


def _sample(img, u, v):
    """Bilinear (u, v in Pixeln, außerhalb = durchsichtig)."""
    h, w = img.shape[:2]
    x0 = np.floor(u - 0.5).astype(int)
    y0 = np.floor(v - 0.5).astype(int)
    fx = (u - 0.5) - x0
    fy = (v - 0.5) - y0
    out = 0.0
    for dy, wy in ((0, 1 - fy), (1, fy)):
        for dx, wx in ((0, 1 - fx), (1, fx)):
            xx = np.clip(x0 + dx, 0, w - 1)
            yy = np.clip(y0 + dy, 0, h - 1)
            ok = ((x0 + dx >= 0) & (x0 + dx < w) & (y0 + dy >= 0) & (y0 + dy < h)).astype(float)
            out = out + img[yy, xx] * (wx * wy * ok)[..., None]
    return out


def _cell(img, local_x, local_y, cell_w, cell_h, col, row, cw_px, ch_px):
    u = (local_x / cell_w + 0.5)
    v = (0.5 - local_y / cell_h)
    inside = (u >= 0) & (u <= 1) & (v >= 0) & (v <= 1)
    s = _sample(img, col * cw_px + np.clip(u, 0, 1) * cw_px, row * ch_px + np.clip(v, 0, 1) * ch_px)
    return s * inside[..., None]


def srgb_to_linear(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def compose(atlases, expression="neutral", gender="female", size=1024, skin=(0.95, 0.80, 0.68),
            iris_color=(0.42, 0.28, 0.20), brow_color=(0.30, 0.22, 0.18), look=(0.0, 0.0)):
    """Ganzes Gesicht (sRGB, 0..1) im UV-Bereich 0..1 – Gegenstück zu chibi_face.gdshader."""
    eye_f, iris_f, brow_f, mouth_f, blush, iris_scale = EXPRESSIONS[expression]
    n = size
    u = (np.arange(n) + 0.5) / n
    U, V = np.meshgrid(u, u)
    fx = (U - 0.5) * FACE_SIZE
    fz = (1.0 - V) * FACE_SIZE
    col = np.ones((n, n, 3)) * np.array(skin)
    # Wangenröte
    for s in (1, -1):
        e = ((fx - s * BLUSH_X) / BLUSH_R[0]) ** 2 + ((fz - BLUSH_Z) / BLUSH_R[1]) ** 2
        a = np.clip(1.0 - e, 0.0, 1.0) ** 1.5 * 0.55 * blush
        col = col * (1 - a[..., None]) + np.array((0.98, 0.55, 0.55)) * a[..., None]
    gi = 0 if gender == "female" else 1
    ei = EYE_FRAMES.index(eye_f)
    erow, ecol = gi * 2 + ei // 4, ei % 4
    ii = IRIS_FRAMES.index(iris_f)
    for s in (1, -1):
        lx = (fx - s * EYE_X) * s / EYE_SCALE
        ly = (fz - EYE_Z) / EYE_SCALE
        lines = _cell(atlases["face_eyes"], lx, ly, EYE_CELL, EYE_CELL, ecol, erow, CELL_PX, CELL_PX)
        mask = _cell(atlases["face_eye_masks"], lx, ly, EYE_CELL, EYE_CELL, ecol, erow, CELL_PX, CELL_PX)
        white = mask[..., 0]
        shadow = mask[..., 1]
        eye_col = np.array((0.99, 0.98, 0.97))
        col = col * (1 - white[..., None]) + eye_col * white[..., None]
        ix = ((fx - s * EYE_X) / EYE_SCALE - look[0] * 0.006) / iris_scale
        iy = ((fz - EYE_Z) / EYE_SCALE - 0.0015 - look[1] * 0.004) / iris_scale
        ir = _cell(atlases["face_iris"], ix, iy, IRIS_CELL, IRIS_CELL, ii % 2, ii // 2, CELL_PX, CELL_PX)
        ia = ir[..., 3] * white
        base = np.array(iris_color)
        icol = base * 0.35 + (base * 1.15 - base * 0.35) * np.clip(ir[..., 0:1], 0, 1)
        icol = icol * (1 - ir[..., 2:3]) + np.array(LINE) * ir[..., 2:3] * 0.8
        icol = icol * (1 - ir[..., 1:2]) + 1.0 * ir[..., 1:2]
        col = col * (1 - ia[..., None]) + np.clip(icol, 0, 1) * ia[..., None]
        sh = shadow * 0.45
        col = col * (1 - sh[..., None] * (1 - np.array((0.78, 0.76, 0.86))))
        la = lines[..., 3:4]
        col = col * (1 - la) + lines[..., :3] * la
        bi = BROW_FRAMES.index(brow_f)
        bx = (fx - s * BROW_X) * s / BROW_SCALE
        br = _cell(atlases["face_brows"], bx, (fz - BROW_Z) / BROW_SCALE, BROW_CELL[0], BROW_CELL[1], bi % 4, bi // 4,
                   CELL_PX, CELL_PX // 2)
        ba = br[..., 3:4]
        col = col * (1 - ba) + np.array(brow_color) * ba
    mi = MOUTH_FRAMES.index(mouth_f)
    m = _cell(atlases["face_mouths"], fx / MOUTH_SCALE, (fz - MOUTH_Z) / MOUTH_SCALE, MOUTH_CELL, MOUTH_CELL, mi % 4, mi // 4, CELL_PX, CELL_PX)
    ma = m[..., 3:4]
    col = col * (1 - ma) + m[..., :3] * ma
    out = np.ones((n, n, 4))
    out[..., :3] = np.clip(col, 0, 1)
    return out
