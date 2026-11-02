// Bilderbuch-Stil für Tiere mit Skelett (seit Etappe 6g): wie storybook.gdshader, aber die Muster
// (Flecken, Tigerstreifen) hängen an der Ruhehaltung (UV/UV2 aus tools/blender/build_animals.py) und
// laufen so mit dem Fell mit. Kein feines Relief (Tiere sind weich). Alles Weitere in storybook.gdshaderinc.
shader_type spatial;
render_mode cull_back;

#define REST_POSITION
#include "res://assets/shaders/storybook.gdshaderinc"
