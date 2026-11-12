// Kleidung der Chibi-Figuren (seit Etappe 5c): eine Farbe je Kleidungsstück (Instanz-Wert),
// dazu die eingebaute Verschattung (UV2.x) und bei Schuhen eine helle Sohle: UV2.y = Höhe über
// dem Boden in m (glTF dreht v um: 1 - UV2.y).
// Saum (seit Etappe 6j): UV.x = Abstand zur Schnittlinie des Kleidungsstücks in m – was jenseits liegt (negativ), wird
// verworfen. So ist jeder Saum eine glatte Linie statt einer zackigen Kante; beide Seiten des Stoffs werden gezeichnet
// (man schaut am Saum auf die Innenseite).
shader_type spatial;
render_mode cull_disabled;

instance uniform vec4 base_color : source_color = vec4(0.8, 0.75, 0.6, 1.0);
instance uniform vec4 sole_color : source_color = vec4(0.86, 0.82, 0.74, 1.0);
// Sohle bis zu dieser Höhe (0 = keine Sohle, z. B. bei Hemd und Hose)
instance uniform float sole_height = 0.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	if (UV.x < -0.00002) {
		discard;
	}
	float ao = mix(1.0, UV2.x, ao_strength);
	float height = 1.0 - UV2.y;
	float w = max(fwidth(height), 0.0002);
	float sole = clamp(0.5 - (height - sole_height) / w, 0.0, 1.0) * step(0.0001, sole_height);
	ALBEDO = mix(base_color.rgb, sole_color.rgb, sole) * ao;
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
}
