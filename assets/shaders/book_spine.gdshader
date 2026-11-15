shader_type spatial;
// Bücher – viele auf einmal (MultiMesh: alle Bücher eines Regals in einem Rutsch).
// Jedes Buch ist die weiche Buchform aus BookLook (im Würfel der Größe 1), auf seine Buchgröße gestreckt.
// +Z = Buchrücken (gewölbt, zeigt im Regal nach vorn), +X = vorderer Einband (Cover), -X = hinterer Einband.
// Welcher Teil: UV2.x (BookLook.Part: 0 Rücken, 1 vorn, 2 hinten, 3 Kanten, 4 Seiten), Lage auf der Fläche: UV.
// Je Buch (Instanz):
//   COLOR.rgb       Farbe des Einbands
//   COLOR.a         1 = normal, kleiner = hervorgehoben (z. B. angeschaut)
//   INSTANCE_CUSTOM Lage des Buchrückens im Atlas: x, y = Ecke, z, w = Breite, Höhe (0 bis 1)

uniform sampler2D spine_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Nur für ein einzelnes Buch (z. B. in der Hand): Bild des Covers auf dem vorderen Einband
uniform sampler2D cover_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_cover = false;
// Einzelnes Buch ohne MultiMesh und ohne Cover-Bild (Bücherkisten, Requisiten der Besucher): Farbe und Rücken aus den Werten
uniform bool use_single = false;
// Für ein einzelnes Buch (ohne MultiMesh): Einbandfarbe und Lage des Rückens im Atlas
uniform vec3 single_color : source_color = vec3(0.5, 0.4, 0.3);
uniform vec4 single_spine_rect = vec4(0.0);
uniform vec3 page_color : source_color = vec3(0.9, 0.86, 0.76);
// Farbschnitt: so viel Einbandfarbe kommt in den Buchblock (GameConfig.book_page_tint)
uniform float page_tint = 0.42;
uniform float roughness_value = 0.78;
uniform float highlight_strength = 0.18;

varying float part;
varying vec2 face_uv;
varying vec4 spine_rect;

void vertex() {
	part = UV2.x;
	face_uv = UV;
	spine_rect = (use_cover || use_single) ? single_spine_rect : INSTANCE_CUSTOM;
}

void fragment() {
	vec3 base = (use_cover || use_single) ? single_color : COLOR.rgb;
	vec3 col = base;
	if (part < 0.5) {
		// Buchrücken aus dem Atlas
		if (spine_rect.z > 0.0) {
			col = texture(spine_atlas, spine_rect.xy + clamp(face_uv, 0.002, 0.998) * spine_rect.zw).rgb;
		}
	} else if (part < 1.5) {
		// Vorderer Einband: Cover-Bild oder Einbandfarbe mit weichem, etwas dunklerem Rand
		if (use_cover) {
			col = texture(cover_texture, clamp(face_uv, 0.004, 0.996)).rgb;
		} else {
			float edge = min(min(face_uv.y, 1.0 - face_uv.y), 1.0 - face_uv.x);
			col = base * mix(0.86, 1.0, smoothstep(0.02, 0.06, edge));
		}
	} else if (part < 2.5) {
		col = base * 0.93;
	} else if (part < 3.5) {
		col = base * 0.82;
	} else {
		// Buchblock: Papier in der Einbandfarbe getönt (Farbschnitt) mit ganz feinen Blattlinien
		col = mix(page_color, base, page_tint) * (0.95 + 0.03 * sin(face_uv.x * 220.0));
	}
	if (!use_cover && COLOR.a < 0.99) {
		col = mix(col, vec3(1.0, 0.96, 0.86), highlight_strength);
		EMISSION = col * 0.12;
	}
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
