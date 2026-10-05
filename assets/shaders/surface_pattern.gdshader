// Einfache Muster für Wände und Böden (Platzhalter, bis eigene Texturen da sind).
// Die Muster richten sich nach der Position in der Welt, deshalb passen sie
// nahtlos über alle Wände und den ganzen Boden.
shader_type spatial;

// Grundfarbe und zweite Farbe des Musters
uniform vec4 base_color : source_color = vec4(0.8, 0.75, 0.65, 1.0);
uniform vec4 second_color : source_color = vec4(0.7, 0.62, 0.52, 1.0);
// Welches Muster?
uniform int pattern : hint_enum("Einfarbig", "Dielen", "Schachbrett", "Streifen", "Kassetten") = 0;
// Dielen: Brettbreite, Schachbrett: Feldgröße, Streifen: Streifenbreite (in Metern)
uniform float tile_size = 0.5;
// Anteil des zweiten Farbstreifens (nur Streifen; 0.5 = gleich breit, 0.2 = schmale Balken)
uniform float stripe_ratio : hint_range(0.05, 0.95) = 0.5;
// Breite des Rahmens um jede Kassette (nur Kassetten, in Metern)
uniform float frame_width = 0.06;
// Länge eines Bretts (nur Dielen)
uniform float plank_length = 1.6;
// Fugen zwischen Brettern bzw. Fliesen
uniform float joint_width = 0.006;
uniform vec4 joint_color : source_color = vec4(0.12, 0.08, 0.05, 1.0);
// Leichte Flecken für einen natürlicheren Eindruck (0 = aus)
uniform float mottling : hint_range(0.0, 1.0) = 0.0;
uniform float mottling_scale = 1.5;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x);
	return mix(a, b, u.y);
}

// 2D-Koordinaten je nach Ausrichtung der Fläche (Boden oder Wand)
vec2 surface_uv() {
	vec3 n = abs(world_normal);
	if (n.y > 0.5) {
		return world_pos.xz;
	}
	if (n.x > n.z) {
		return vec2(world_pos.z, world_pos.y);
	}
	return vec2(world_pos.x, world_pos.y);
}

// 1 direkt auf der Fuge, 0 abseits davon
float joint_mask(float distance_to_edge) {
	return 1.0 - smoothstep(joint_width * 0.5, joint_width, distance_to_edge);
}

void fragment() {
	vec2 uv = surface_uv();
	vec3 color = base_color.rgb;
	float joint = 0.0;

	if (pattern == 1) {
		// Dielen: Reihen nebeneinander, jede Reihe gegeneinander versetzt
		float row = floor(uv.x / tile_size);
		float along = uv.y / plank_length + hash(vec2(row, 7.0));
		float plank = floor(along);
		color = mix(base_color.rgb, second_color.rgb, hash(vec2(row, plank)));
		float across = fract(uv.x / tile_size);
		float dx = min(across, 1.0 - across) * tile_size;
		float dy = min(fract(along), 1.0 - fract(along)) * plank_length;
		joint = joint_mask(min(dx, dy));
	} else if (pattern == 2) {
		// Schachbrett mit Fugen
		vec2 cell = floor(uv / tile_size);
		color = mix(base_color.rgb, second_color.rgb, mod(cell.x + cell.y, 2.0));
		vec2 f = fract(uv / tile_size);
		vec2 d = min(f, 1.0 - f) * tile_size;
		joint = joint_mask(min(d.x, d.y));
	} else if (pattern == 3) {
		// Streifen (z. B. Tapete oder Holzbalken an der Decke)
		float stripe = 1.0 - step(stripe_ratio, fract(uv.x / (tile_size * 2.0)));
		color = mix(base_color.rgb, second_color.rgb, stripe);
	} else if (pattern == 4) {
		// Kassetten: helle Rahmen, vertiefte Felder mit leichtem Schatten am Rand
		vec2 f = fract(uv / tile_size);
		vec2 d = min(f, 1.0 - f) * tile_size;
		float edge = min(d.x, d.y);
		float frame = 1.0 - smoothstep(frame_width * 0.9, frame_width, edge);
		color = mix(second_color.rgb, base_color.rgb, frame);
		float shadow = smoothstep(frame_width, frame_width * 1.2, edge) * (1.0 - smoothstep(frame_width * 1.2, frame_width * 1.8, edge));
		color *= 1.0 - shadow * 0.3;
		joint = joint_mask(edge);
	}

	if (mottling > 0.0) {
		float n = value_noise(uv * mottling_scale) * 0.6 + value_noise(uv * mottling_scale * 4.0) * 0.4;
		color *= 1.0 + (n - 0.5) * mottling;
	}

	ALBEDO = mix(color, joint_color.rgb, joint * joint_color.a);
	ROUGHNESS = roughness_value;
}
