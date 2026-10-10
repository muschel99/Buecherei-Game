// Gemeinsames Material für das Leben auf der Straße (seit Etappe 5a): Platzhalter-Passanten,
// Fahrräder, Autos und Lieferwagen. Alle teilen sich EIN Material – die Farbe jedes Teils
// kommt als "Instanz-Wert" (instance uniform "tint", kostet nichts extra) bzw. steht im Mesh.
// Im Mesh sagt der Alpha-Wert der Vertex-Farbe, wie ein Teil aussieht:
//   1.0  = feste Farbe, matt (rgb so, wie sie im Mesh steht)
//   0.75 = Farbe "tint" (rgb = Helligkeit), matt – z. B. Lack eines Autos, Jacke eines Passanten
//   0.5  = feste Farbe, glänzend (Scheiben, Chrom)
//   0.25 = feste Farbe, leuchtet leicht (Scheinwerfer)
shader_type spatial;
render_mode cull_back;

instance uniform vec4 tint : source_color = vec4(1.0);

varying vec3 base_color;
varying float gloss;
varying float glow;

void vertex() {
	float id = COLOR.a;
	base_color = id > 0.9 || id < 0.6 ? COLOR.rgb : tint.rgb * COLOR.rgb;
	gloss = id > 0.4 && id < 0.6 ? 1.0 : 0.0;
	glow = id > 0.1 && id < 0.4 ? 1.0 : 0.0;
}

void fragment() {
	ALBEDO = base_color;
	ROUGHNESS = mix(0.85, 0.2, gloss);
	SPECULAR = mix(0.4, 0.7, gloss);
	EMISSION = base_color * glow * 0.6;
}
