shader_type spatial;
// Bücher – viele auf einmal (MultiMesh: alle Bücher eines Regals in einem Rutsch).
// Jedes Buch ist ein Würfel der Größe 1, der auf seine Buchgröße gestreckt wird.
// Seiten des Würfels: +Z = Buchrücken (zeigt im Regal nach vorn), +X = vorderer Einband
// (Cover), -X = hinterer Einband, oben/unten/hinten = Seiten (Papier).
// Je Buch (Instanz):
//   COLOR.rgb       Farbe des Einbands
//   COLOR.a         1 = normal, kleiner = hervorgehoben (z. B. angeschaut)
//   INSTANCE_CUSTOM Lage des Buchrückens im Atlas: x, y = Ecke, z, w = Breite, Höhe (0 bis 1)

uniform sampler2D spine_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Nur für ein einzelnes Buch (z. B. in der Hand): Bild des Covers auf dem vorderen Einband
uniform sampler2D cover_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_cover = false;
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
	vec3 base = COLOR.rgb;
	vec3 col = base;
	if (local_pos.z > 0.499) {
		// Buchrücken aus dem Atlas
		if (spine_rect.z > 0.0) {
			vec2 face_uv = vec2(local_pos.x + 0.5, 0.5 - local_pos.y);
			col = texture(spine_atlas, spine_rect.xy + clamp(face_uv, 0.002, 0.998) * spine_rect.zw).rgb;
		}
	} else if (local_pos.x > 0.499) {
		// Vorderer Einband: Cover-Bild oder Einbandfarbe mit feinem Rand
		if (use_cover) {
			col = texture(cover_texture, vec2(0.5 - local_pos.z, 0.5 - local_pos.y)).rgb;
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
	if (COLOR.a < 0.99) {
		col = mix(col, vec3(1.0, 0.96, 0.86), highlight_strength);
		EMISSION = col * 0.12;
	}
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
