shader_type spatial;
// Buchrücken für viele Bücher auf einmal (MultiMesh: alle Bücher eines Regals in einem Rutsch).
// Jedes Buch ist ein Würfel der Größe 1, der auf seine Buchgröße gestreckt wird.
// Farbe je Buch: Instanzfarbe (COLOR).
// INSTANCE_CUSTOM.r = Verzierung auf dem Rücken: 0 = keine, 0.5 = helle Bänder, 1 = dunkle Bänder
// INSTANCE_CUSTOM.g = Titelschild: 0 = keins, 1 = helles Feld auf dem Rücken

uniform vec3 page_color : source_color = vec3(0.9, 0.86, 0.76);
uniform vec3 band_color : source_color = vec3(0.86, 0.72, 0.42);
uniform float roughness_value = 0.78;

varying vec3 local_pos;
varying vec4 custom;

void vertex() {
	local_pos = VERTEX;
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 col = base;
	// Oben: der helle Buchblock (Seiten), rundherum ein schmaler Rand vom Einband
	if (local_pos.y > 0.49 && local_pos.z < 0.42 && abs(local_pos.x) < 0.36) {
		col = page_color * 0.92;
	}
	// Vorn (+Z): der Buchrücken mit Bändern und Titelschild
	if (local_pos.z > 0.49) {
		float y = local_pos.y;
		if (custom.r > 0.25) {
			vec3 band = custom.r > 0.75 ? base * 0.45 : band_color;
			if (abs(y - 0.36) < 0.025 || abs(y + 0.38) < 0.025) {
				col = band;
			}
		}
		if (custom.g > 0.5 && abs(y - 0.08) < 0.11 && abs(local_pos.x) < 0.3) {
			col = mix(base, page_color, 0.75);
		}
	}
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
