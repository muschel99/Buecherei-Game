#!/usr/bin/env python3
"""Geräusche an der Theke (seit Etappe 7): erzeugt
  assets/audio/ui/counter_bell.wav – Tischklingel „Pling“ (heller Glockenton mit Obertönen, klingt aus),
  assets/audio/ui/stamp.wav        – Stempel auf Papier (kurzer, dumpfer Stoß mit etwas Holz),
  assets/audio/ui/scan.wav         – Scanner an der Theke (kurzes Piepen, seit Testrunde 7b),
  seit Etappe 8 (Theken-Ansicht, Gespräche):
  assets/audio/ui/card_insert.wav  – Ausweis gleitet in den Kartenleser (weiches Schaben, dann Klick),
  assets/audio/ui/card_beep.wav    – Kartenleser hat gelesen (ein sanfter, runder Piepton),
  assets/audio/ui/stamp_pop.wav    – Stempel ploppt auf dem Bildschirm auf (weiches „Plopp“),
  assets/audio/ui/slide.wav        – Bücher über die Theke schieben (sanftes Rutschen),
  assets/audio/ui/type.wav, type_1 … type_5.wav – leises, angenehmes Tastaturklackern beim Reden (Varianten).
Eigene Aufnahme? Einfach die Datei ersetzen (auch als .ogg mit gleichem Namen) – das Script schreibt nur, wenn die Datei
fehlt (--force: neu). Braucht nur Python (kein ffmpeg).

Aufruf (Terminal, im Projektordner):
    python3 tools/make_counter_sounds.py
"""
import math
import os
import random
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "ui")
RATE = 44100


def write(name, samples, peak=0.6):
    path = os.path.join(OUT_DIR, name)
    if os.path.exists(path) and "--force" not in sys.argv:
        print("vorhanden, bleibt:", path)
        return
    top = max(abs(s) for s in samples) or 1.0
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / top * peak * 32767)) for s in samples))
    print("geschrieben:", path)


def bell():
    """Tischklingel: Grundton ~2,1 kHz mit unharmonischen Obertönen, weicher Anschlag, langes Ausklingen."""
    seconds = 1.6
    partials = [(2093.0, 1.0, 1.1), (2093.0 * 2.76, 0.35, 0.5), (2093.0 * 5.4, 0.12, 0.25), (2093.0 * 0.5, 0.08, 0.9)]
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        attack = min(1.0, t / 0.002)
        s = 0.0
        for freq, amp, decay in partials:
            # leichtes Schweben (Schwebung) wie bei echtem Metall
            s += amp * math.exp(-t / decay) * math.sin(2 * math.pi * freq * t + 0.4 * math.sin(2 * math.pi * 3.0 * t))
        # kleines „Klick“ des Hämmerchens
        s += 0.25 * math.exp(-t / 0.003) * random.uniform(-1, 1)
        out.append(s * attack)
    return out


def stamp():
    """Stempel: dumpfer Stoß (tiefer Ton + gefiltertes Rauschen), danach ein kurzes Nachfedern."""
    seconds = 0.35
    out = []
    low = 0.0
    random.seed(7)
    for i in range(int(RATE * seconds)):
        t = i / RATE
        noise = random.uniform(-1, 1)
        low += (noise - low) * 0.08  # Tiefpass: Papier/Holz statt Zischen
        body = math.exp(-t / 0.035) * (0.9 * math.sin(2 * math.pi * 140.0 * t) + 1.6 * low)
        knock = math.exp(-max(0.0, t - 0.07) / 0.02) * (0.25 * low) if t > 0.07 else 0.0
        out.append(body + knock)
    return out


def scan():
    """Scanner an der Theke: kurzes, freundliches Piepen (zwei Töne knapp nacheinander)."""
    seconds = 0.16
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        freq = 1760.0 if t < 0.075 else 2349.0
        env = min(1.0, t / 0.004) * min(1.0, (seconds - t) / 0.02)
        out.append(env * (math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(4 * math.pi * freq * t)))
    return out


def card_insert():
    """Ausweis in den Leser: kurzes, gefiltertes Schaben (Karte gleitet), am Ende ein kleiner Klick."""
    seconds = 0.32
    out = []
    low = 0.0
    random.seed(11)
    for i in range(int(RATE * seconds)):
        t = i / RATE
        noise = random.uniform(-1, 1)
        low += (noise - low) * 0.25
        slide = 0.5 * low * min(1.0, t / 0.03) * max(0.0, 1.0 - t / 0.24)
        click = math.exp(-max(0.0, t - 0.25) / 0.006) * (0.9 * math.sin(2 * math.pi * 2400.0 * t) + noise * 0.5) if t > 0.25 else 0.0
        out.append(slide + click)
    return out


def card_beep():
    """Kartenleser: ein runder, sanfter Piepton (Sinus mit weichem Ein- und Ausblenden)."""
    seconds = 0.22
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        env = min(1.0, t / 0.01) * min(1.0, (seconds - t) / 0.06)
        out.append(env * math.sin(2 * math.pi * 1318.5 * t))
    return out


def stamp_pop():
    """Stempel auf dem Bildschirm: weiches „Plopp“ (Ton fällt schnell von hoch nach tief)."""
    seconds = 0.18
    out = []
    phase = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        freq = 380.0 + 900.0 * math.exp(-t / 0.025)
        phase += 2 * math.pi * freq / RATE
        out.append(math.exp(-t / 0.05) * min(1.0, t / 0.002) * math.sin(phase))
    return out


def slide():
    """Bücher schieben: sanftes, tiefes Rutschen (Rauschen, stark gefiltert, an- und abschwellend)."""
    seconds = 0.45
    out = []
    low = 0.0
    low2 = 0.0
    random.seed(19)
    for i in range(int(RATE * seconds)):
        t = i / RATE
        low += (random.uniform(-1, 1) - low) * 0.06
        low2 += (low - low2) * 0.2
        env = math.sin(math.pi * t / seconds) ** 1.5
        out.append(low2 * env)
    return out


def type_click(seed):
    """Eine Taste: kurzer, weicher Anschlag (gefiltertes Rauschen + kleiner Holzton), jede Variante etwas anders."""
    rnd = random.Random(seed)
    seconds = 0.07
    tone = rnd.uniform(500.0, 900.0)
    out = []
    low = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        low += (rnd.uniform(-1, 1) - low) * 0.35
        env = math.exp(-t / 0.012)
        out.append(env * (0.8 * low + 0.35 * math.sin(2 * math.pi * tone * t)) + math.exp(-max(0.0, t - 0.03) / 0.008) * 0.15 * low
                   * (t > 0.03))
    return out


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    random.seed(3)
    write("counter_bell.wav", bell(), 0.55)
    write("stamp.wav", stamp(), 0.7)
    write("scan.wav", scan(), 0.35)
    write("card_insert.wav", card_insert(), 0.45)
    write("card_beep.wav", card_beep(), 0.3)
    write("stamp_pop.wav", stamp_pop(), 0.5)
    write("slide.wav", slide(), 0.4)
    for n in range(6):
        write("type.wav" if n == 0 else "type_%d.wav" % n, type_click(100 + n), 0.22)
