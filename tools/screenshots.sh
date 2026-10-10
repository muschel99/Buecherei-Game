#!/usr/bin/env bash
# Testbilder aus festen Blickwinkeln (seit Etappe 4f) – für Claude im Browser-Container.
# Startet Godot mit einem unsichtbaren Bildschirm (Xvfb) und Software-Vulkan (lavapipe) und
# speichert Bilder nach screenshots/ im Projekt (nicht in Git).
#
#   tools/screenshots.sh                     Gruppe "overview"
#   tools/screenshots.sh straight_end        eine Gruppe (Liste: tools/screenshots.sh --list)
#   tools/screenshots.sh turning_end --only=aerial,gate_close
#   tools/screenshots.sh --cam=0,1.1,-8:10,1.1,-8   freier Blickpunkt (Kamera : Ziel)
#
# Godot fehlt? Einmal tools/setup_godot.sh ausführen.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
ARGS=()
if [[ $# -gt 0 && "$1" != --* ]]; then
	ARGS+=("--set=$1")
	shift
fi
ARGS+=("$@")
mkdir -p "$ROOT/screenshots"
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path "$ROOT" --rendering-method forward_plus \
	--resolution 1600x900 --audio-driver Dummy res://scenes/tools/screenshot_tour.tscn -- "${ARGS[@]}" 2>&1 \
	| grep -v -E "^(Godot Engine|Vulkan|$)" || true
