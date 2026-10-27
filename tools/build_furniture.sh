#!/usr/bin/env bash
# Möbelkatalog bauen (Etappe 6): Blender baut die Modelle, danach importiert Godot sie.
#   tools/build_furniture.sh                       alle Objekte
#   tools/build_furniture.sh armchair_velvet       einzelne Objekte (ids)
#   tools/build_furniture.sh --style=country       ein Stil
# Weitere Angaben (--force, --adopt, --list) gehen an tools/blender/build_storybook_furniture.py.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
blender -b --factory-startup --python tools/blender/build_storybook_furniture.py -- "$@" 2>&1 \
	| grep -E "Dreiecke|bleibt|übersprungen|Fertig|Unbekannte|Error|Traceback|File \"|^\s+[A-Za-z_]+Error" | grep -v Draco || true
if [[ " $* " != *" --list "* ]]; then
	godot --headless --path "$ROOT" --import > /dev/null 2>&1 || true
	echo "Godot-Import fertig."
fi
