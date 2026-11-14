shader_type spatial;
// Ausgelegte Bücher (auf Tischen, der Theke, dem Boden …) – alle eines Raums in einem
// Rutsch (MultiMesh), wie book_spine.gdshader, aber mit echtem Cover auf dem vorderen
// Einband (aus dem Cover-Atlas von BookArt).
// Jedes Buch ist die weiche Buchform aus BookLook: +Z = Buchrücken, +X = vorderer Einband (Cover); Teil = UV2.x
// (0 Rücken, 1 vorn, 2 hinten, 3 Kanten, 4 Seiten), Lage auf der Fläche = UV.
// Je Buch (Instanz):
//   COLOR.rgb       Farbe des Einbands
//   COLOR.a         Nummer: 0 = kein Cover; 1–127 = Cover im Atlasfeld (Nummer − 1);
//                   +128 = hervorgehoben (angeschaut). Gespeichert als Nummer / 255.
//   INSTANCE_CUSTOM Lage des Buchrückens im Rücken-Atlas (x, y = Ecke, z, w = Breite, Höhe)

uniform sampler2D spine_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D cover_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Felder im Cover-Atlas (Spalten, Zeilen) – siehe BookArt.COVER_ATLAS_GRID
uniform vec2 cover_grid = vec2(16.0, 7.0);
uniform vec3 page_color : source_color = vec3(0.9, 0.86, 0.76);
uniform float roughness_value = 0.78;
uniform float highlight_strength = 0.18;

varying float part;
varying vec2 face_uv;
varying vec4 spine_rect;

void vertex() {
	part = UV2.x;
	face_uv = UV;
	spine_rect = INSTANCE_CUSTOM;
}

void fragment() {
	// Nummer aus COLOR.a lesen (die Farbe je Buch kommt erst hier im Fragment sicher an)
	int code = int(round(COLOR.a * 255.0));
	int highlighted = code >= 128 ? 1 : 0;
	int cover_slot = (code % 128) - 1;
	vec3 base = COLOR.rgb;
	vec3 col = base;
	if (part < 0.5) {
		if (spine_rect.z > 0.0) {
			col = texture(spine_atlas, spine_rect.xy + clamp(face_uv, 0.002, 0.998) * spine_rect.zw).rgb;
		}
	} else if (part < 1.5) {
		if (cover_slot >= 0) {
			vec2 cell = vec2(float(cover_slot % int(cover_grid.x)), float(cover_slot / int(cover_grid.x)));
			col = texture(cover_atlas, (cell + clamp(face_uv, 0.004, 0.996)) / cover_grid).rgb;
		} else {
			float edge = min(min(face_uv.y, 1.0 - face_uv.y), 1.0 - face_uv.x);
			col = base * mix(0.86, 1.0, smoothstep(0.02, 0.06, edge));
		}
	} else if (part < 2.5) {
		col = base * 0.93;
	} else if (part < 3.5) {
		col = base * 0.82;
	} else {
		col = page_color * (0.95 + 0.03 * sin(face_uv.x * 220.0));
	}
	if (highlighted == 1) {
		col = mix(col, vec3(1.0, 0.96, 0.86), highlight_strength);
		EMISSION = col * 0.12;
	}
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
