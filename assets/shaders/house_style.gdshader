// Stil-Material der Außenwelt (seit Etappe 4g): EIN Material für alle Häuser aus Blender
// (assets/models/houses/*.glb, gebaut von tools/blender/build_houses.py).
// Die Texturen liegen als Liste (Texture2DArray) vor: Ziegel, Sandstein, Putz, Schiefer …
// (Tabelle: assets/textures/style/layers.json, erzeugt von scripts/tools/generate_style_textures.gd).
// Je Ecke steht im Modell:
//   UV      = Texturkoordinaten in Kacheln (Meter / Kachelgröße der Ebene)
//   UV2.x   = Nummer der Ebene, UV2.y = Rolle: 0 fest, 1 Wandfarbe, 2 Türfarbe, 3 Akzentfarbe
//   COLOR   = feste Farbe (bei Rolle 0), Alpha = 1 - Leuchten
// Einfärbbare Stellen (Alpha der Textur = 1) werden mit der Farbe multipliziert; die Farben je
// Haus kommen als Instanz-Werte vom Haus (HouseFacade: wall_color, door_color, accent_color).
shader_type spatial;
render_mode cull_back;

uniform sampler2DArray albedo_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_layers : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Rauheit und Metall je Ebene (Reihenfolge wie layers.json)
uniform float roughness_layers[20];
uniform float metallic_layers[20];
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
// Ausgleich der mittleren Texturhelligkeit (1 / linear(tint_mean) aus layers.json)
uniform float tint_gain = 1.656;
// Stärke des Leuchtens (z. B. beleuchtete Schaufenster)
uniform float glow_strength = 1.5;

instance uniform vec4 wall_color : source_color = vec4(0.55, 0.3, 0.24, 1.0);
instance uniform vec4 door_color : source_color = vec4(0.18, 0.28, 0.42, 1.0);
instance uniform vec4 accent_color : source_color = vec4(0.16, 0.3, 0.22, 1.0);

varying flat int layer;
varying vec3 tint;
varying float glow;

void vertex() {
	layer = int(round(UV2.x));
	int role = int(round(UV2.y));
	if (role == 1) {
		tint = wall_color.rgb;
	} else if (role == 2) {
		tint = door_color.rgb;
	} else if (role == 3) {
		tint = accent_color.rgb;
	} else {
		tint = COLOR.rgb;
	}
	glow = 1.0 - COLOR.a;
}

void fragment() {
	vec3 uvw = vec3(UV, float(layer));
	vec4 tex = texture(albedo_layers, uvw);
	vec3 color = mix(tex.rgb, tex.rgb * tint * tint_gain, tex.a);
	ALBEDO = color;
	ROUGHNESS = roughness_layers[layer];
	METALLIC = metallic_layers[layer];
	NORMAL_MAP = texture(normal_layers, uvw).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	EMISSION = color * glow * glow_strength;
}
