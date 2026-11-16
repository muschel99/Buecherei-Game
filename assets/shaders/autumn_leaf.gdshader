// Herbstblatt (seit der großen Überarbeitung, AutumnLeaves): ein Viereck, dessen Umriss der Shader als Blatt ausschneidet
// (Ahorn, Eiche oder Rundblatt – je Blatt zufällig), mit Mittelrippe, leicht gewölbt, beidseitig. Farbe aus COLOR (je Blatt
// aus der Herbst-Palette). Für fallende Blätter (tumble = 1) liefert der Partikel-Shader autumn_leaf_fall.gdshader in
// INSTANCE_CUSTOM: x = Alter (0–1), y = gelandet (0/1), z = Größe, w = Zufall; in der Luft schaukelt und dreht es sich.
// Laub am Boden (MultiMesh, tumble = 0): erscheint im Herbst Blatt für Blatt (season_autumn).
shader_type spatial;
render_mode cull_disabled;

uniform float tumble = 0.0;
// Wölbung entlang der Mittelrippe (Meter je Meter Blattbreite)
uniform float fold = 0.22;
global uniform float season_autumn;

varying vec3 leaf_color;
varying float leaf_kind;
varying float leaf_fade;

float h1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

mat3 rot_x(float a) {
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(a), sin(a)), vec3(0.0, -sin(a), cos(a)));
}

mat3 rot_z(float a) {
	return mat3(vec3(cos(a), sin(a), 0.0), vec3(-sin(a), cos(a), 0.0), vec3(0.0, 0.0, 1.0));
}

void vertex() {
	float r = h1(float(INSTANCE_ID) + 0.37);
	leaf_kind = h1(float(INSTANCE_ID) * 1.7 + 3.1);
	leaf_color = COLOR.rgb;
	leaf_fade = 1.0;
	// gewölbt: die Ränder liegen etwas höher als die Mittelrippe
	VERTEX.y += abs(UV.x - 0.5) * 2.0 * fold * 0.5;
	if (tumble > 0.5) {
		r = INSTANCE_CUSTOM.w;
		float landed = INSTANCE_CUSTOM.y;
		float t = TIME * (1.1 + r * 1.5) + r * 40.0;
		// in der Luft: schaukeln wie ein fallendes Blatt, langsam drehen
		mat3 tilt = rot_x(sin(t) * 0.9 * (1.0 - landed)) * rot_z(cos(t * 0.73) * 0.75 * (1.0 - landed));
		VERTEX = tilt * VERTEX;
		NORMAL = tilt * NORMAL;
		// am Ende des Lebens weich ausblenden (kleiner werden)
		leaf_fade = 1.0 - smoothstep(0.86, 1.0, INSTANCE_CUSTOM.x);
		VERTEX *= leaf_fade;
	} else {
		// Laub am Boden: Blatt für Blatt da, sobald Herbst ist
		leaf_fade = smoothstep(r - 0.05, r, season_autumn * 1.05);
		VERTEX *= leaf_fade;
	}
}

// Umriss eines Blatts in UV (0..1, Stiel unten bei v = 0): > 0 = innen
float leaf_shape(vec2 uv, float kind) {
	vec2 p = vec2(uv.x - 0.5, uv.y);
	float r;
	if (kind < 0.45) {
		// Ahorn: fünf spitze Lappen
		vec2 q = p - vec2(0.0, 0.42);
		float a = atan(q.x, q.y);
		float lobes = 0.33 + 0.13 * pow(abs(cos(a * 2.5)), 0.6) - 0.06 * smoothstep(1.9, 2.8, abs(a));
		return lobes - length(q * vec2(1.0, 1.08));
	} else if (kind < 0.75) {
		// Eiche: längliches Blatt mit runden Buchten
		float w = 0.27 * sin(clamp(p.y, 0.0, 1.0) * 3.14159) + 0.035 * sin(p.y * 31.0);
		r = w - abs(p.x);
		return min(r, min(p.y - 0.06, 0.96 - p.y));
	}
	// Linde/Birke: rund mit Spitze
	vec2 q = p - vec2(0.0, 0.45);
	float tip = smoothstep(0.1, 0.5, q.y) * abs(q.x) * 0.6;
	return 0.4 - length(q * vec2(1.15, 1.0)) - tip;
}

void fragment() {
	float d = leaf_shape(UV, leaf_kind);
	// Stiel
	float stem = step(abs(UV.x - 0.5), 0.012) * step(UV.y, 0.14);
	if (d < 0.0 && stem < 0.5) {
		discard;
	}
	vec3 col = leaf_color;
	// Mittelrippe und feine Adern etwas heller, Rand etwas dunkler
	float vein = 1.0 - smoothstep(0.0, 0.012, abs(UV.x - 0.5));
	float side_veins = 1.0 - smoothstep(0.0, 0.018, abs(fract((UV.y - abs(UV.x - 0.5) * 0.9) * 6.0) - 0.5) - 0.47);
	col = mix(col, col * 1.18 + vec3(0.03), vein * 0.6 + side_veins * 0.15 * step(0.02, d));
	col *= mix(0.8, 1.0, smoothstep(0.0, 0.06, d));
	col = mix(col, col * vec3(0.7, 0.55, 0.4), stem);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	SPECULAR = 0.25;
	// Rückseite etwas heller und matter (wie echte Blätter)
	if (!FRONT_FACING) {
		ALBEDO = mix(col, vec3(dot(col, vec3(0.33))), 0.2) * 1.08;
	}
	BACKLIGHT = col * 0.35;
}
