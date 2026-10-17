// Haut und Wäsche der Chibi-Figuren (seit Etappe 5c): eine Farbe je Figur (Instanz-Wert),
// dazu die eingebaute Verschattung aus UV2.x (Achseln, Bauchnabel, Finger).
shader_type spatial;

instance uniform vec4 base_color : source_color = vec4(0.95, 0.80, 0.68, 1.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	float ao = mix(1.0, UV2.x, ao_strength);
	ALBEDO = base_color.rgb * ao;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}
