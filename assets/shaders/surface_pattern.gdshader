// Wände, Böden und Decken der Räume im Bilderbuch-Stil (seit Etappe 6j; vorher einfache Platzhalter-Muster).
// Die Muster richten sich nach der Position in der Welt, deshalb passen sie nahtlos über alle Wände und den
// ganzen Boden. Alles wirkt von Hand gemacht: Putz mit Kellenstrichen, Dielen mit Maserung und weichen Kanten,
// Fliesen mit kleinen Farbunterschieden. Feine Muster blenden aus, sobald sie kleiner als ein paar Bildpunkte
// werden (sonst flimmert es); das Relief wird nie über Bildschirm-Ableitungen gerechnet (gäbe Treppchen).
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
// Wie stark die Handarbeit zu sehen ist: Kellenstriche im Putz, Maserung im Holz, weiche Kanten (0 = glatt)
uniform float handmade : hint_range(0.0, 2.0) = 1.0;

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

float fbm(vec2 p) {
	return value_noise(p) * 0.55 + value_noise(p * 2.03 + 17.0) * 0.3 + value_noise(p * 4.1 + 43.0) * 0.15;
}

// Feines blendet aus, wenn eine Wiederholung (1/freq Meter) kleiner als etwa drei Bildpunkte wird
float detail_fade(float px, float freq) {
	return 1.0 - smoothstep(0.16, 0.45, px * freq);
}

// 1 direkt auf der Fuge, 0 abseits davon (nie schmaler als ein Bildpunkt – sonst flimmert die Fuge)
float joint_mask(float distance_to_edge, float px) {
	float w = max(joint_width, px * 1.2);
	return (1.0 - smoothstep(w * 0.5, w, distance_to_edge)) * min(1.0, joint_width / w * 1.6);
}

// Dielen: Abstand zur nächsten Fuge und Kennung des Bretts
float plank_edge(vec2 uv, out vec2 id, out float along_f) {
	float row = floor(uv.x / tile_size);
	// jedes Brett ist etwas anders lang
	float len = plank_length * (0.8 + 0.4 * hash(vec2(row, 3.0)));
	float along = uv.y / len + hash(vec2(row, 7.0));
	id = vec2(row, floor(along));
	along_f = fract(along) * len;
	float across = fract(uv.x / tile_size);
	float dx = min(across, 1.0 - across) * tile_size;
	float dy = min(fract(along), 1.0 - fract(along)) * len;
	return min(dx, dy);
}

float tile_edge(vec2 uv) {
	vec2 f = fract(uv / tile_size);
	vec2 d = min(f, 1.0 - f) * tile_size;
	return min(d.x, d.y);
}

// Höhe der Oberfläche in Metern (für das Relief): Kanten der Bretter und Fliesen sind weich abgerundet, Putz
// ist leicht wellig
float surface_height(vec2 uv, float px) {
	if (pattern == 1) {
		vec2 id;
		float along_f;
		float edge = plank_edge(uv, id, along_f);
		float bevel = 0.007;
		float h = smoothstep(0.0, bevel, edge) * 0.0016;
		// Bretter liegen nie ganz eben
		h += (hash(id + 11.0) - 0.5) * 0.0006;
		return h * detail_fade(px, 1.0 / bevel * 0.35);
	}
	if (pattern == 2) {
		float edge = tile_edge(uv);
		return smoothstep(0.0, 0.006, edge) * 0.0014 * detail_fade(px, 60.0);
	}
	if (pattern == 4) {
		float edge = tile_edge(uv);
		// vertieftes Feld mit schräger Kante
		return -smoothstep(frame_width, frame_width + 0.02, edge) * 0.006;
	}
	// Putz und Tapete: breite, flache Kellenstriche
	float h = fbm(uv * 3.0) * 0.0035;
	h += fbm(uv * vec2(14.0, 9.0) + 5.0) * 0.0009 * detail_fade(px, 14.0);
	return h;
}

void fragment() {
	// Flächen-Koordinaten: Boden und Decke nach x/z, Wände entlang der Wand (auch die schräge) und nach oben
	vec3 n_world = normalize(world_normal);
	vec3 tangent;
	vec3 bitangent;
	if (abs(n_world.y) > 0.5) {
		tangent = vec3(1.0, 0.0, 0.0);
		bitangent = vec3(0.0, 0.0, 1.0);
	} else {
		// Richtung entlang der Wand, immer mit demselben Vorzeichen (sonst spränge das Muster an Ecken)
		vec3 flat_n = normalize(vec3(n_world.x, 0.0, n_world.z));
		tangent = abs(flat_n.x) > abs(flat_n.z) ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		// schräge Wände: entlang der Wand messen statt verzerrt auf eine Achse zu legen
		if (abs(abs(flat_n.x) - abs(flat_n.z)) < 0.9) {
			tangent = normalize(cross(vec3(0.0, 1.0, 0.0), flat_n));
			if (tangent.x + tangent.z * 0.001 < 0.0) {
				tangent = -tangent;
			}
		}
		bitangent = vec3(0.0, 1.0, 0.0);
	}
	vec2 uv = vec2(dot(world_pos, tangent), dot(world_pos, bitangent));
	// Größe eines Bildpunkts auf der Fläche in Metern
	float px = max(0.0004, -VERTEX.z * 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y));

	vec3 color = base_color.rgb;
	float joint = 0.0;
	float rough = roughness_value;

	if (pattern == 1) {
		// Dielen: Reihen nebeneinander, jede Reihe gegeneinander versetzt, jedes Brett in eigenem Ton
		vec2 id;
		float along_f;
		float edge = plank_edge(uv, id, along_f);
		float tone = hash(id);
		color = mix(base_color.rgb, second_color.rgb, tone);
		color *= 0.94 + 0.12 * hash(id + 5.0);
		// Maserung: lange, leicht geschwungene Linien entlang des Bretts
		float warp = value_noise(vec2(uv.y * 1.3 + id.x * 3.1, id.y * 5.7)) * 0.05;
		float lines = value_noise(vec2((uv.x + warp) * 140.0 + id.y * 19.0, uv.y * 3.0 + id.x * 7.0));
		float broad = value_noise(vec2((uv.x + warp) * 38.0 + id.x * 13.0, uv.y * 1.1 + id.y * 3.0));
		float grain = (lines - 0.5) * 0.10 * detail_fade(px, 140.0) + (broad - 0.5) * 0.12 * detail_fade(px, 38.0);
		color *= 1.0 + grain * handmade;
		rough = clamp(rough + (broad - 0.5) * 0.12 * handmade, 0.0, 1.0);
		joint = joint_mask(edge, px);
	} else if (pattern == 2) {
		// Schachbrett mit Fugen, jede Fliese eine Spur anders
		vec2 cell = floor(uv / tile_size);
		color = mix(base_color.rgb, second_color.rgb, mod(cell.x + cell.y, 2.0));
		color *= 0.95 + 0.1 * hash(cell + 3.0) * handmade;
		float cloud = fbm(uv * 9.0 + cell * 2.7);
		color *= 1.0 + (cloud - 0.5) * 0.08 * handmade * detail_fade(px, 9.0);
		joint = joint_mask(tile_edge(uv), px);
	} else if (pattern == 3) {
		// Streifen (z. B. Tapete oder Holzbalken an der Decke): Kanten nie schärfer als ein Bildpunkt
		float f = fract(uv.x / (tile_size * 2.0));
		float w = clamp(px / (tile_size * 2.0), 0.0005, 0.2);
		float stripe = smoothstep(-w, w, stripe_ratio - f) * smoothstep(-w, w, f) + (1.0 - smoothstep(-w, w, 1.0 - f));
		stripe = clamp(stripe, 0.0, 1.0);
		color = mix(base_color.rgb, second_color.rgb, stripe);
	} else if (pattern == 4) {
		// Kassetten: helle Rahmen, vertiefte Felder mit leichtem Schatten am Rand
		float edge = tile_edge(uv);
		float frame = 1.0 - smoothstep(frame_width * 0.9, frame_width, edge);
		color = mix(second_color.rgb, base_color.rgb, frame);
		float shadow = smoothstep(frame_width, frame_width * 1.2, edge) * (1.0 - smoothstep(frame_width * 1.2, frame_width * 1.8, edge));
		color *= 1.0 - shadow * 0.3;
		joint = joint_mask(edge, px);
	}

	if (pattern != 1) {
		// Von Hand gestrichen: große, weiche Wolken und feine Striche (bei Putz, Tapete, Fliesen, Kassetten)
		float cloud = fbm(uv * 0.9 + 3.0);
		float strokes = fbm(uv * vec2(7.0, 4.0) + 9.0);
		float amount = (pattern == 0 || pattern == 3) ? 1.0 : 0.5;
		color *= 1.0 + ((cloud - 0.5) * 0.09 + (strokes - 0.5) * 0.05 * detail_fade(px, 7.0)) * handmade * amount;
	}

	if (mottling > 0.0) {
		float m = value_noise(uv * mottling_scale) * 0.6 + value_noise(uv * mottling_scale * 4.0) * 0.4 * detail_fade(px, mottling_scale * 4.0);
		color *= 1.0 + (m - 0.5) * mottling;
	}

	ALBEDO = mix(color, joint_color.rgb, joint * joint_color.a);
	ROUGHNESS = rough;

	// Relief: Höhe an drei Stellen im Abstand eines Bildpunkts (nie dFdx/dFdy – die arbeiten in 2x2-Blöcken)
	if (handmade > 0.0) {
		float e = max(px, 0.0015);
		float h0 = surface_height(uv, px);
		float hu = surface_height(uv + vec2(e, 0.0), px);
		float hv = surface_height(uv + vec2(0.0, e), px);
		vec2 slope = vec2(hu - h0, hv - h0) / e * handmade;
		// in der Ferne flacher (sonst rauscht das Licht)
		slope *= 1.0 - smoothstep(6.0, 18.0, -VERTEX.z);
		vec3 bumped = normalize(n_world - tangent * slope.x - bitangent * slope.y);
		NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
	}
}
