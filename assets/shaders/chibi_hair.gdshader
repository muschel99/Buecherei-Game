// Haare der Chibi-Figuren (seit Etappe 5c): eine Farbe je Frisur (Instanz-Wert), eingebaute
// Verschattung (UV2.x: dunkler am Ansatz und unter dem Pony) und ein weicher Glanz.
shader_type spatial;

instance uniform vec4 base_color : source_color = vec4(0.36, 0.24, 0.16, 1.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	float ao = mix(1.0, UV2.x, ao_strength);
	ALBEDO = base_color.rgb * ao;
	ROUGHNESS = roughness;
	SPECULAR = 0.45;
}
