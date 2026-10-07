shader_type spatial;
// Ausgelegte Bücher (auf Tischen, der Theke, dem Boden …) – alle eines Raums in einem
// Rutsch (MultiMesh), wie book_spine.gdshader, aber mit echtem Cover auf dem vorderen
// Einband (aus dem Cover-Atlas von BookArt).
// Jedes Buch ist ein Würfel der Größe 1: +Z = Buchrücken, +X = vorderer Einband (Cover).
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

varying vec3 local_pos;
varying vec4 spine_rect;

void vertex() {
	local_pos = VERTEX;
	spine_rect = INSTANCE_CUSTOM;
}

void fragment() {
	// Nummer aus COLOR.a lesen (die Farbe je Buch kommt erst hier im Fragment sicher an)
	int code = int(round(COLOR.a * 255.0));
	int highlighted = code >= 128 ? 1 : 0;
	int cover_slot = (code % 128) - 1;
	vec3 base = COLOR.rgb;
	vec3 col = base;
	if (local_pos.z > 0.499) {
		// Buchrücken aus dem Atlas
		if (spine_rect.z > 0.0) {
			vec2 face_uv = vec2(local_pos.x + 0.5, 0.5 - local_pos.y);
			col = texture(spine_atlas, spine_rect.xy + clamp(face_uv, 0.002, 0.998) * spine_rect.zw).rgb;
		}
	} else if (local_pos.x > 0.499) {
		// Vorderer Einband: Cover aus dem Atlas oder Einbandfarbe mit feinem Rand
		if (cover_slot >= 0) {
			vec2 cell = vec2(float(cover_slot % int(cover_grid.x)), float(cover_slot / int(cover_grid.x)));
			vec2 face_uv = clamp(vec2(0.5 - local_pos.z, 0.5 - local_pos.y), 0.004, 0.996);
			col = texture(cover_atlas, (cell + face_uv) / cover_grid).rgb;
		} else if (abs(local_pos.y) > 0.46 || local_pos.z < -0.46) {
			col = base * 0.82;
		}
	} else if (local_pos.x < -0.499) {
		col = base * 0.92;
	} else if (abs(local_pos.y) > 0.499 || local_pos.z < -0.499) {
		// Seiten (Buchblock), rundherum ein schmaler Rand vom Einband
		bool inside = abs(local_pos.x) < 0.42 && local_pos.z < 0.46;
		col = inside ? page_color * 0.94 : base;
	}
	if (highlighted == 1) {
		col = mix(col, vec3(1.0, 0.96, 0.86), highlight_strength);
		EMISSION = col * 0.12;
	}
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
