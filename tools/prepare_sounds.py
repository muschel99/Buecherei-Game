"""Geräusche der Entwicklerin für das Spiel aufbereiten (seit Etappe 6e).

Liest die Originale aus „Game design/Sounds Cozy Bücherei/“ (werden nie verändert) und schreibt fertige
.ogg-Dateien nach assets/audio/<ordner>/<name>[_<n>].ogg:
- Sammeldateien („10x_…“ = zehn Klingeln hintereinander) an den stillen Stellen in einzelne Sounds schneiden
  – das Spiel nimmt dann jedes Mal zufällig eine Variante,
- kurze Stille am Anfang und Ende entfernen, sanft ein- und ausblenden (nichts knackt),
- Lautstärken angleichen (Ziel-Lautheit je Bereich, Spitzen begrenzt),
- Schleifen (Motoren, Tastatur) mit Überblendung nahtlos machen,
- räumliche Geräusche in Mono (im Spiel hört man sie aus der richtigen Richtung).

Aufruf (Terminal, im Projektordner; braucht ffmpeg):
    python3 tools/prepare_sounds.py            (alle)
    FFMPEG=/pfad/zu/ffmpeg python3 tools/prepare_sounds.py
Vorhandene Ziel-Dateien werden überschrieben (sie stammen ja aus diesem Script) – eigene, von Hand
abgelegte Dateien mit anderen Namen bleiben unberührt.
"""

import json
import math
import os
import shutil
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Game design", "Sounds Cozy Bücherei")
AUDIO = os.path.join(ROOT, "assets", "audio")
RATE = 44100
FFMPEG = os.environ.get("FFMPEG") or shutil.which("ffmpeg") or "ffmpeg"

# Ziel-Lautheit (RMS des hörbaren Teils in dBFS) je Art – leise und angenehm, nichts sticht heraus
LEVEL = {"ui": -27.0, "books": -25.0, "doors": -24.0, "bell": -25.0, "steps": -27.0, "vehicle": -24.0, "engine": -27.0,
         "birds": -25.0, "cats": -25.0, "voices": -27.0, "music": -25.0, "computer": -27.0}

# (Quelle, Ziel ohne Endung, Art, Modus, Optionen)
#   Modus: "split" = an stillen Stellen schneiden (n = erwartete Anzahl, Ziele <ziel>_1 …),
#          "single" = ein Sound, "loop" = nahtlose Schleife, "music" = Musikstück (Stereo),
#          "pick" = schneiden und nur bestimmte Teile nehmen (parts = {Index: Ziel})
JOBS = [
    # Fahrzeuge
    ("10x_fahrradklingel_hell.mp3", "vehicles/bike_bell", "bell", "split", dict(n=10)),
    ("5x_farradklingel_dumpf.mp3", "vehicles/bike_bell", "bell", "split", dict(n=5, start=11)),
    ("2x_Auto_hupe_kurz.mp3", "vehicles/horn_car", "vehicle", "single", dict()),        # freundliches „mip mip“
    ("2x_auto_hupe_tief.mp3", "vehicles/horn_van", "vehicle", "single", dict()),
    ("automotor_soft.mp3", "vehicles/car_engine", "engine", "loop", dict()),
    # rauer Motor: weicher (Tiefpass) und leiser – für den Lieferwagen (Wunsch der Entwicklerin)
    ("automotor_trashy.mp3", "vehicles/van_engine", "engine", "loop", dict(lowpass=1400.0, gain=-4.0)),
    # Schritte: eigene Schritte drinnen (Holz) und draußen (Stein); Passanten auf dem Gehweg
    # (an den Anschlägen geschnitten: ein Laut = ein Schritt; Hintergrundrauschen hat keine stillen Stellen)
    ("7x_gehen_auf_holz.mp3", "footsteps/wood", "steps", "onset", dict(n=7)),
    ("11x_gehen_unisex_stein.mp3", "footsteps/stone", "steps", "onset", dict(n=11)),
    ("1x_generic footstep.mp3", "footsteps/stone", "steps", "onset", dict(n=1, start=12)),
    ("11x_gehen_unisex_stein.mp3", "footsteps/street", "steps", "onset", dict(n=11)),
    ("9X_mechanisch_gehen.mp3", "footsteps/street", "steps", "onset", dict(n=9, start=12)),
    ("8x_gehen_Female_stein_absatz.mp3", "footsteps/heels", "steps", "onset", dict(n=8)),
    # Tür: auf und zu; Glocke über der Tür (+ „door bell“ als weitere Variante, Wunsch der Entwicklerin)
    ("Tür_auf _zu.mp3", "doors/door", "doors", "times", dict(parts=[(0.36, 1.3, "doors/door_open"), (3.55, 4.3, "doors/door_close")])),
    ("4x_shopdoorbell.mp3", "doors/shop_bell", "bell", "split", dict(n=4)),
    ("door bell.mp3", "doors/shop_bell", "bell", "split", dict(n=1, start=5)),
    # Umgebung: Vögel (räumlich an Bäumen, Dächern, Pflanzen), Katzen
    ("6x-Vogel Zwitschern.mp3", "ambience/bird", "birds", "split", dict(n=6)),
    ("miau_kurz.mp3", "ambience/cat_meow", "cats", "split", dict(n=1)),
    ("miau_lang.mp3", "ambience/cat_meow", "cats", "split", dict(n=1, start=2)),
    ("cat_chatting.mp3", "ambience/cat_chatter", "cats", "split", dict(n=0)),
    ("cat_purr.mp3", "ambience/cat_purr", "cats", "loop", dict()),
    # Bücher: ins Regal stellen, frei ablegen, aufnehmen, im Stapel blättern
    ("buch_Schließen_u_platzieren.mp3", "books/shelve", "books", "times", dict(parts=[(0.07, 0.3, "books/shelve_1"),
                                                                                    (0.07, 0.3, "books/place_3")])),
    ("buch_platzieren.mp3", "books/place", "books", "times", dict(parts=[(0.42, 0.78, "books/place_1"), (0.85, 1.36, "books/place_2"),
                                                                     (0.42, 0.78, "books/shelve_2"), (0.85, 1.36, "books/shelve_3")])),
    ("umblättern2.mp3", "books/page", "books", "times", dict(parts=[(0.48, 1.9, "books/page_1")])),
    ("umblättern3.mp3", "books/page", "books", "times", dict(parts=[(0.48, 1.9, "books/page_2")])),
    # Aufnehmen: kurze, leise Papier-Geräusche aus dem schnellen Durchblättern
    ("schnelles durchblättern.mp3", "books/take", "books", "split", dict(n=0, max_len=0.35, limit=8, gain=-3.0)),
    # Oberfläche: Tablet öffnen, Plopp beim Antippen, Reiter wechseln
    ("menu open.mp3", "ui/tablet_open", "ui", "pick", dict(parts={0: "ui/tablet_open"})),
    ("plop_hoch.mp3", "ui/plop", "ui", "split", dict(n=1)),
    ("plop_tief.mp3", "ui/plop", "ui", "split", dict(n=1, start=2)),
    ("tablet tab.mp3", "ui/tab", "ui", "pick", dict(parts={0: "ui/tab"})),
    # Stimmen der Passanten (nur kurze Laute, keine Wörter)
    ("Female_haha_hell.mp3", "voices/laugh_female", "voices", "pick", dict(parts={"all": "voices/laugh_female_1"})),
    ("female_haha_tief.mp3", "voices/laugh_female", "voices", "pick", dict(parts={"all": "voices/laugh_female_2"})),
    ("female_kichern.mp3", "voices/giggle_female", "voices", "pick", dict(parts={"all": "voices/giggle_female"})),
    ("Male_hmm?_voice.mp3", "voices/hmm_male", "voices", "pick", dict(parts={"all": "voices/hmm_male"})),
    ("female_uh oh.mp3", "voices/oh_female", "voices", "pick", dict(parts={-1: "voices/oh_female"})),
    # Computer am Arbeitsplatz (vorbereitet für später)
    ("tastatur_tippen_leise.mp3", "computer/keyboard_soft", "computer", "loop", dict()),
    ("Tastatur_tippen_laut.mp3", "computer/keyboard_loud", "computer", "loop", dict(gain=-3.0)),
    ("mouse klick.mp3", "computer/mouse_click", "computer", "split", dict(n=0)),
    # Musik (ruhig im Hintergrund)
    ("background_calmmusic.mp3", "music/calm", "music", "music", dict()),
    ("background_lofi_music.mp3", "music/lofi", "music", "music", dict()),
    ("background_optimistic lofi.mp3", "music/optimistic_lofi", "music", "music", dict()),
]
# Bewusst nicht verwendet (Wunsch der Entwicklerin): Female_eww.mp3, female_urgh.mp3

STEREO = {"music"}


def decode(path, channels, lowpass=0.0):
    cmd = [FFMPEG, "-v", "error", "-i", path]
    if lowpass > 0:
        # weicher Tiefpass (zweimal = sanfter Abfall), z. B. für den rauen Motor
        cmd += ["-af", "lowpass=f=%d,lowpass=f=%d" % (lowpass, lowpass)]
    cmd += ["-f", "f32le", "-acodec", "pcm_f32le", "-ac", str(channels), "-ar", str(RATE), "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    data = np.frombuffer(raw, dtype=np.float32)
    return data.reshape(-1, channels).copy()


def encode(data, path, quality=5):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ch = data.shape[1]
    cmd = [FFMPEG, "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", str(ch), "-i", "-", "-c:a", "libvorbis",
           "-q:a", str(quality), path]
    subprocess.run(cmd, input=np.ascontiguousarray(data, dtype=np.float32).tobytes(), check=True)


def envelope(data, win=0.02, hop=0.005):
    mono = data.mean(axis=1)
    w, h = int(win * RATE), int(hop * RATE)
    n = max(1, (len(mono) - w) // h + 1)
    env = np.array([math.sqrt(float(np.mean(mono[i * h:i * h + w] ** 2)) + 1e-12) for i in range(n)])
    return env, h, w


def segments(data, thr_db, min_gap=0.1, min_len=0.05):
    """Hörbare Abschnitte (Start, Ende in Samples): Hüllkurve über thr_db unter dem Maximum."""
    env, h, w = envelope(data)
    peak = env.max()
    if peak <= 0:
        return []
    on = env > peak * 10 ** (thr_db / 20.0)
    segs = []
    i = 0
    while i < len(on):
        if on[i]:
            j = i
            while j < len(on) and on[j]:
                j += 1
            segs.append([i * h, j * h + w])
            i = j
        else:
            i += 1
    merged = []
    for s in segs:
        if merged and s[0] - merged[-1][1] < min_gap * RATE:
            merged[-1][1] = s[1]
        else:
            merged.append(s)
    return [s for s in merged if s[1] - s[0] >= min_len * RATE]


def onsets(data, n, min_dist=0.28):
    """Anschläge (Schritte): die n deutlichsten Spitzen der Hüllkurve, mindestens min_dist auseinander;
    jeder Abschnitt beginnt kurz davor und endet, wenn es leise wird (spätestens vor dem nächsten)."""
    env, h, w = envelope(data, win=0.012, hop=0.004)
    dist = int(min_dist * RATE / h)
    cand = [i for i in range(1, len(env) - 1) if env[i] >= env[max(0, i - dist):i + dist + 1].max()]
    cand.sort(key=lambda i: -env[i])
    picked = sorted(cand[:n])
    segs = []
    for k, i in enumerate(picked):
        start = max(0, i - int(0.035 * RATE / h))
        limit = picked[k + 1] - int(0.03 * RATE / h) if k + 1 < len(picked) else len(env) - 1
        end = i
        while end < limit and env[end] > env[i] * 0.06 and (end - i) * h < 0.4 * RATE:
            end += 1
        segs.append([start * h, min(len(data), end * h + w)])
    return segs


def split(data, n):
    """Schneidet in n Teile (n = 0: so viele, wie deutlich getrennt sind). Sucht die passende Schwelle."""
    best = None
    for thr in (-30, -26, -34, -22, -38, -18, -42, -15):
        for gap in (0.08, 0.15, 0.05, 0.25):
            segs = segments(data, thr, gap)
            if n == 0:
                if segs and (best is None or len(segs) > len(best)) and thr <= -26:
                    best = segs
                continue
            if len(segs) == n:
                return segs
            if best is None or abs(len(segs) - n) < abs(len(best) - n):
                best = segs
    return best or [[0, len(data)]]


def finish(data, kind, seg=None, gain=0.0, fade_in=0.008, fade_out=None):
    """Ausschnitt mit etwas Luft, sanfte Blenden, Lautstärke angleichen, Spitzen begrenzen."""
    if seg is not None:
        a = max(0, seg[0] - int(0.012 * RATE))
        b = min(len(data), seg[1] + int(0.03 * RATE))
        data = data[a:b].copy()
    length = len(data) / RATE
    fo = fade_out if fade_out is not None else min(0.06, length * 0.15)
    fi = int(min(fade_in, length * 0.1) * RATE)
    fo = int(fo * RATE)
    if fi > 1:
        data[:fi] *= np.linspace(0.0, 1.0, fi)[:, None]
    if fo > 1:
        data[-fo:] *= np.linspace(1.0, 0.0, fo)[:, None]
    env, h, w = envelope(data)
    loud = env[env > env.max() * 0.1] if env.max() > 0 else env
    rms = float(np.sqrt(np.mean(loud ** 2))) if len(loud) else 1e-6
    target = 10 ** ((LEVEL[kind] + gain) / 20.0)
    data = data * (target / max(rms, 1e-6))
    peak = float(np.abs(data).max())
    if peak > 0.89:
        data *= 0.89 / peak
    return data


def loopable(data, cross=0.35):
    """Nahtlose Schleife: das Ende wird über den Anfang geblendet (Ende passt wieder an den Anfang)."""
    d = int(min(cross, len(data) / RATE * 0.25) * RATE)
    head, tail = data[:d], data[-d:]
    t = np.linspace(0.0, 1.0, d)[:, None]
    mixed = tail * (1.0 - t) + head * t
    return np.concatenate([mixed, data[d:-d]])


def out_path(name):
    return os.path.join(AUDIO, name + ".ogg")


def main():
    report = []
    for src, dest, kind, mode, opt in JOBS:
        path = os.path.join(SOURCE, src)
        if not os.path.exists(path):
            print("FEHLT:", src)
            continue
        channels = 2 if kind in STEREO else 1
        data = decode(path, channels, opt.get("lowpass", 0.0))
        made = []
        if mode == "music":
            # Stille am Rand weg, 2 s ein- und 4 s ausblenden (sanfte Übergänge zwischen den Stücken)
            segs = segments(data, -45, 1.0)
            if segs:
                data = data[max(0, segs[0][0] - RATE // 10):min(len(data), segs[-1][1] + RATE // 2)]
            data = finish(data, kind, fade_in=2.0, fade_out=4.0)
            encode(data, out_path(dest), quality=4)
            made.append((dest, len(data) / RATE))
        elif mode == "loop":
            segs = segments(data, -40, 0.5)
            if segs:
                data = data[segs[0][0]:segs[-1][1]]
            data = loopable(finish(data, kind, gain=opt.get("gain", 0.0), fade_in=0.0, fade_out=0.0))
            encode(data, out_path(dest))
            made.append((dest, len(data) / RATE))
        elif mode == "single":
            segs = segments(data, -40, 0.4)
            seg = [segs[0][0], segs[-1][1]] if segs else None
            data = finish(data, kind, seg, gain=opt.get("gain", 0.0))
            encode(data, out_path(dest))
            made.append((dest, len(data) / RATE))
        elif mode == "onset":
            start = opt.get("start", 1)
            for k, seg in enumerate(onsets(data, opt["n"])):
                name = "%s_%d" % (dest, start + k)
                piece = finish(data, kind, seg, gain=opt.get("gain", 0.0), fade_out=0.04)
                encode(piece, out_path(name))
                made.append((name, len(piece) / RATE))
        elif mode == "times":
            for a, b, name in opt["parts"]:
                piece = finish(data, kind, [int(a * RATE), int(b * RATE)], gain=opt.get("gain", 0.0))
                encode(piece, out_path(name))
                made.append((name, len(piece) / RATE))
        elif mode in ("split", "pick"):
            if mode == "pick" and "all" in opt["parts"]:
                segs = segments(data, -40, 0.4)
                pieces = {opt["parts"]["all"]: [segs[0][0], segs[-1][1]] if segs else [0, len(data)]}
            else:
                segs = split(data, opt.get("n", 0) if mode == "split" else 0)
                if opt.get("max_len"):
                    # lange Abschnitte (schnelles Blättern) in kurze Stücke teilen
                    cut = []
                    for a, b in segs:
                        step = int(opt["max_len"] * RATE)
                        cut += [[x, min(b, x + step)] for x in range(a, b, step) if min(b, x + step) - x > step // 2]
                    segs = cut
                if opt.get("limit"):
                    segs = segs[:opt["limit"]]
                if mode == "pick":
                    pieces = {name: segs[idx] for idx, name in opt["parts"].items() if segs}
                else:
                    start = opt.get("start", 1)
                    pieces = {"%s_%d" % (dest, start + k): s for k, s in enumerate(segs)}
            for name, seg in pieces.items():
                piece = finish(data, kind, seg, gain=opt.get("gain", 0.0))
                encode(piece, out_path(name))
                made.append((name, len(piece) / RATE))
        expected = opt.get("n")
        note = "" if not expected or mode != "split" or len(made) == expected else "  (erwartet %d, gefunden %d)" % (expected, len(made))
        report.append({"quelle": src, "ziel": [m[0] for m in made], "laengen": [round(m[1], 2) for m in made]})
        print("%-34s -> %2d Datei(en) %s%s" % (src, len(made), ", ".join("%s (%.2f s)" % m for m in made[:3]) + (" …" if len(made) > 3 else ""), note))
    with open(os.path.join(AUDIO, "sounds_report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
