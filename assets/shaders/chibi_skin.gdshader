// Haut der Chibi-Figuren (seit Etappe 5c): eine Farbe je Figur (Instanz-Wert), dazu die
// eingebaute Verschattung (UV2.x: Achseln, Bauchnabel, Finger) und die aufgemalte Unterwäsche:
// UV2.y = Abstand zum Rand von Bandeau/Hose (glTF dreht v um: 1 - UV2.y), negativ = Stoff.
// Unter Rock und Hose trägt die Unterhose deren Farbe (lower_cloth_color, wie ein Hosenrock); oben und
// unten trennt die Höhe in der Ruhelage (UV = Gesichts-Abwicklung: 1 - UV.y = Höhe über dem Kinn
// in 0,48-m-Einheiten, Hosenbund aller Figuren unter -0,75, Bandeau über -0,62).
shader_type spatial;

// Instanz-Werte mit festen Nummern – gleich wie in chibi_face.gdshader (beide Oberflächen
// des Körpers teilen sich die Werte über diese Nummern)
instance uniform vec4 base_color : source_color, instance_index(0) = vec4(0.95, 0.80, 0.68, 1.0);
instance uniform vec4 cloth_color : source_color, instance_index(1) = vec4(0.90, 0.89, 0.87, 1.0);
instance uniform vec4 lower_cloth_color : source_color, instance_index(14) = vec4(0.90, 0.89, 0.87, 1.0);
const float LOWER_SPLIT = -0.68;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	float ao = mix(1.0, UV2.x, ao_strength);
	float d = 1.0 - UV2.y;
	// scharfe, geglättete Kante (Breite = ein Bildpunkt)
	float w = max(fwidth(d), 0.0002);
	float cloth = clamp(0.5 - d / w, 0.0, 1.0);
	// feiner Saum am Rand der Wäsche
	float hem = cloth * (1.0 - smoothstep(0.0, 0.0025, -d)) * 0.12;
	vec3 fabric = (1.0 - UV.y) < LOWER_SPLIT ? lower_cloth_color.rgb : cloth_color.rgb;
	ALBEDO = mix(base_color.rgb, fabric * (1.0 - hem), cloth) * ao;
	ROUGHNESS = mix(roughness, 0.85, cloth);
	SPECULAR = 0.3;
}
