// Pflanzen-Material der Außenwelt (seit Etappe 4g, Teil 4f): Blätter, Blüten, Rinde der
// Stil-Modelle aus Blender (tools/blender/style_plants.py). Ein Zeichenaufruf je Haus für alle
// Pflanzen.
// Die Texturen liegen als Liste (Texture2DArray) vor: Efeublatt, Laubblatt, Buchs-Zweig, Blüten …
// (Tabelle: assets/textures/plants/layers.json, erzeugt von scripts/tools/generate_plant_textures.gd).
// Je Ecke steht im Modell:
//   UV      = Lage im Blatt (0..1 über das ganze Feld), bei Rinde in Kacheln
//   UV2.x   = Nummer der Ebene
//   COLOR   = Farbe (linear; neutral = hellgrau 0,8 sRGB), Alpha = 1 - Leuchten
// Alpha der Textur = Deckung: Was darunter liegt, wird weggeschnitten (gezackte Ränder, Lappen).
// Blätter sind dünn: beide Seiten sichtbar, Licht scheint leicht hindurch.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2DArray albedo_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_layers : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Rauheit und Durchscheinen je Ebene (Reihenfolge wie layers.json)
uniform float roughness_layers[16];
uniform float translucency_layers[16];
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
// Ausgleich der neutralen Farbe (1 / linear(0,8))
uniform float tint_gain = 1.656;
uniform float glow_strength = 1.5;
// Ab welcher Deckung ein Pixel zum Blatt gehört
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
// Größe einer Ebene in Pixeln (für den Ausgleich in der Ferne)
uniform float layer_pixels = 512.0;

varying flat int layer;
varying float glow;

void vertex() {
	layer = int(round(UV2.x));
	glow = 1.0 - COLOR.a;
}

void fragment() {
	vec3 uvw = vec3(UV, float(layer));
	vec4 tex = texture(albedo_layers, uvw);
	// In der Ferne (kleinere Mipmap-Stufe) wird Alpha weicher und Blätter würden dünner:
	// je Stufe etwas mehr Deckung, damit Laub auch von weitem dicht bleibt
	vec2 px = UV * layer_pixels;
	float lod = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
	ALPHA = tex.a * (1.0 + lod * 0.25);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 color = tex.rgb * COLOR.rgb * tint_gain;
	ALBEDO = color;
	ROUGHNESS = roughness_layers[layer];
	NORMAL_MAP = texture(normal_layers, uvw).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	BACKLIGHT = color * translucency_layers[layer];
	EMISSION = color * glow * glow_strength;
}
