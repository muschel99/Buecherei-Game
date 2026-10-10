// Boden der Außenwelt im Stil (seit Etappe 4g): Straße, Gehwege, Bordsteine, Platz, Gassen.
// Nutzt dieselben Stil-Texturen wie die Häuser (Texture2DArray, Ebene "layer"), aufgetragen
// nach der Position in der Welt – so laufen Pflaster und Platten nahtlos über alle Flächen.
// Oben (Boden) mit Relief aus der Normal-Map, senkrechte Flächen (Bordsteinkanten) ohne.
shader_type spatial;

uniform sampler2DArray albedo_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_layers : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Welche Ebene (layers.json: 13 paving, 17 setts, 6 stone_trim …) und wie groß eine Kachel ist
uniform int layer = 13;
uniform float tile_size = 1.8;
// Farbe: färbt die ganze Fläche (1 = wie die Textur)
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
// Drehung des Musters um 90° (z. B. damit Pflasterreihen quer zur Fahrbahn liegen)
uniform bool rotate_90 = false;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv;
	bool top = abs(world_normal.y) > 0.5;
	if (top) {
		uv = rotate_90 ? world_pos.zx : world_pos.xz;
	} else if (abs(world_normal.x) > abs(world_normal.z)) {
		uv = vec2(world_pos.z, world_pos.y);
	} else {
		uv = vec2(world_pos.x, world_pos.y);
	}
	vec3 uvw = vec3(uv / tile_size, float(layer));
	ALBEDO = texture(albedo_layers, uvw).rgb * tint.rgb;
	ROUGHNESS = roughness_value;
	if (top) {
		// Normal-Map (Tangentenraum: x = u, y = v) in die Welt und dann in den Blickraum drehen
		vec3 n = texture(normal_layers, uvw).rgb * 2.0 - 1.0;
		n.xy *= normal_strength;
		vec3 wn = rotate_90 ? normalize(vec3(n.y, n.z, n.x)) : normalize(vec3(n.x, n.z, n.y));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}
