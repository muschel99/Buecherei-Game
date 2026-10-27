#!/usr/bin/env python3
"""Wandelt docs/ROADMAP.md in Notion-Markdown für die Notion-Seite „Roadmap (aus Claude Code)“ um.

Aufruf:  python3 tools/roadmap_to_notion.py [--part N --parts M] > /tmp/roadmap_notion.md

- Umbrochene Zeilen (Listenpunkte, Absätze) werden zu einer Zeile zusammengefügt.
- Fertige Etappen erscheinen als aufklappbare Überschriften (Toggle), offene und laufende als
  normale Überschriften – so bleibt die Seite übersichtlich.
- Die Etappen-Tabelle oben bekommt Farben je Status (fertig grün, in Arbeit gelb, offen grau).
- --part/--parts teilt das Ergebnis an Etappen-Grenzen (für mehrere Notion-Aufrufe).
"""

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE = os.path.join(ROOT, "docs", "ROADMAP.md")


def status_color(status):
    s = status.lower()
    if s.startswith("fertig"):
        return "green_bg"
    if "arbeit" in s:
        return "yellow_bg"
    return "gray_bg"


def escape(text):
    # Spitze Klammern wären sonst Notion-Tags
    return text.replace("<", "\\<")


def unwrap(lines):
    """Fügt Fortsetzungszeilen an ihren Listenpunkt bzw. Absatz an."""
    out = []
    for raw in lines:
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped:
            out.append("")
            continue
        starts_block = (stripped.startswith(("- ", "* ", "|", "#", ">"))
                        or re.match(r"^\d+\. ", stripped)
                        # Fettschrift beginnt nur nach einer Leerzeile einen neuen Absatz
                        or (stripped.startswith("**") and (not out or out[-1] == "")))
        continuation = out and out[-1] != "" and not starts_block and not out[-1].startswith(("|", "#"))
        if continuation:
            out[-1] = out[-1] + " " + stripped
        else:
            out.append(stripped)
    return out


def status_table(rows):
    parts = ['<table header-row="true">', "<colgroup>", '<col width="70" />', '<col width="520" />',
             '<col width="170" />', "</colgroup>",
             "<tr><th>Nr.</th><th>Etappe</th><th>Status</th></tr>"]
    for nr, name, status in rows:
        parts.append('<tr><td>%s</td><td>%s</td><td color="%s">%s</td></tr>'
                     % (escape(nr), escape(name), status_color(status), escape(status)))
    parts.append("</table>")
    return "\n".join(parts)


def main():
    text = open(SOURCE, encoding="utf-8").read()
    lines = text.split("\n")
    # Etappen-Tabelle und Status je Nummer
    rows = []
    status_of = {}
    i = 0
    while i < len(lines) and not lines[i].startswith("| Nr."):
        i += 1
    i += 2
    while i < len(lines) and lines[i].startswith("|"):
        cells = [c.strip() for c in lines[i].strip("|").split("|")]
        rows.append(cells[:3])
        status_of[cells[0]] = cells[2]
        i += 1
    rest = unwrap(lines[i:])

    blocks = []   # (Ebene, Titel, Zeilen) – Ebene 0 = vor der ersten Überschrift
    current = [0, "", []]
    for line in rest:
        m = re.match(r"^(#{2,3}) (.*)$", line)
        if m:
            blocks.append(current)
            current = [len(m.group(1)), m.group(2), []]
        else:
            current[2].append(line)
    blocks.append(current)

    out = []
    out.append('<callout icon="🗺️" color="blue_bg">\nAutomatisch aus **docs/ROADMAP.md** übertragen (Claude Code, '
               '`tools/roadmap_to_notion.py`). Wird bei jeder Änderung der ROADMAP auf denselben Stand gebracht – '
               'Änderungen bitte im Projekt, nicht hier.\n</callout>')
    out.append("<table-of-contents />")
    out.append("## Etappen auf einen Blick")
    out.append(status_table(rows))
    for level, title, body in blocks:
        content = "\n".join(escape(l) for l in body).strip("\n")
        content = re.sub(r"\n{3,}", "\n\n", content)
        if level == 0:
            if content.strip():
                out.append(content)
            continue
        m = re.match(r"^Etappe (\d+[a-z]?)\b", title)
        done = m and status_of.get(m.group(1), "").lower().startswith("fertig")
        heading = "h2" if level == 2 else "h3"
        if done and content:
            # Kinder eines Toggles: eine Leerzeile nach dem Titel, keine Leerzeilen am Rand
            out.append('<toggle heading="%s">\n%s\n\n%s\n</toggle>' % (heading, escape(title), content))
        else:
            out.append("%s %s" % ("##" if level == 2 else "###", escape(title)))
            if content:
                out.append(content)
    result = "\n\n".join(out) + "\n"

    if "--parts" in sys.argv:
        parts = int(sys.argv[sys.argv.index("--parts") + 1])
        part = int(sys.argv[sys.argv.index("--part") + 1])
        chunks = re.split(r"\n\n(?=## |<toggle heading=\"h2\")", result)
        size = sum(len(c) for c in chunks) / parts
        groups, acc, n = [[] for _ in range(parts)], 0, 0
        for c in chunks:
            if acc > size * (n + 1) and n < parts - 1:
                n += 1
            groups[n].append(c)
            acc += len(c)
        result = "\n\n".join(groups[part - 1]) + "\n"
    sys.stdout.write(result)


if __name__ == "__main__":
    main()
