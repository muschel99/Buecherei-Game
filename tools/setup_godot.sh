#!/usr/bin/env bash
# Richtet Godot im Claude-Container ein (seit Etappe 4f): lädt Godot 4.6 (Standard, ohne .NET)
# nach /tmp/godot, verlinkt es als "godot", installiert Software-Vulkan (lavapipe) und
# importiert das Projekt einmal. Nur zum Testen – nichts davon kommt ins Projekt.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${GODOT_VERSION:-4.6-stable}"
DIR=/tmp/godot
if ! command -v godot >/dev/null; then
	mkdir -p "$DIR"
	curl -sSL -o "$DIR/godot.zip" \
		"https://github.com/godotengine/godot/releases/download/$VERSION/Godot_v${VERSION}_linux.x86_64.zip"
	unzip -oq "$DIR/godot.zip" -d "$DIR"
	ln -sf "$DIR/Godot_v${VERSION}_linux.x86_64" /usr/local/bin/godot
fi
if [[ ! -e /usr/share/vulkan/icd.d/lvp_icd.json ]]; then
	apt-get install -y mesa-vulkan-drivers >/dev/null 2>&1 \
		|| (apt-get update >/dev/null 2>&1 && apt-get install -y mesa-vulkan-drivers >/dev/null)
fi
command -v xvfb-run >/dev/null || apt-get install -y xvfb >/dev/null
godot --headless --path "$ROOT" --import >/dev/null 2>&1 || true
echo "Godot bereit: $(godot --version)"
