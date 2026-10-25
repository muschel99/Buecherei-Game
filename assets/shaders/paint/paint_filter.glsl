#[compute]
#version 450

// Malfilter „Aquarell“, Schritt 2 (Gezeichnet-Look, Wunsch der Entwicklerin): malt das fertige 3D-Bild
// neu, bevor Godot Belichtung und Leuchten anwendet. Gestartet von scripts/rendering/paint_filter_effect.gd,
// alle Werte kommen aus GameConfig (Abschnitt „Malfilter“).
//   1. leichtes Zittern wie von Hand – nur bei den Tuschelinien (die Farben bleiben scharf)
//   2. Pinselflächen (wahlweise, Pinselgröße > 0): verallgemeinerter Kuwahara-Filter – macht das Bild weicher
//   3. Farbränder dunkler (Pigment sammelt sich am Rand wie bei Aquarell)
//   4. feine Tuschelinien an Kanten (aus Tiefe und Flächenrichtung), warmbraun, Strichdruck schwankt
//   5. Papier: ungleichmäßig aufgetragene Farbe, Körnung (in dunklen Stellen stärker), Fasern
//   6. warme, weiche Farbstimmung (Papierton in den Schatten, etwas weniger Sättigung)

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D source_tex;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;
layout(set = 0, binding = 3) uniform sampler2D normal_tex;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float z_near;
	float radius;          // Pinselgröße in Bildpunkten (bei 1080 Zeilen)
	float line_strength;   // Deckkraft der Tuschelinien (0 = keine)
	float line_width;      // Abstand für die Kantensuche in Bildpunkten
	float paper;           // Stärke der Papierstruktur
	float edge_dark;       // Farbränder dunkler
	float wobble;          // Zittern in Bildpunkten
	float warmth;          // warme Farbstimmung
	float saturation;      // Sättigung (1 = unverändert)
	float wash;            // Papierton in den Schatten
	vec3 line_color;       // Farbton der Tusche (linear)
	float line_fade;       // ab dieser Entfernung (m) verschwinden die Linien
	float line_dark;       // Helligkeit der Tusche im Verhältnis zur Fläche darunter (0,3 = ein Drittel)
	float pressure;        // wie stark der Strichdruck schwankt (0 = gleichmäßig)
	vec2 reserved;
} params;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(13.7, 7.1);
		a *= 0.5;
	}
	return v;
}

vec4 source_at(vec2 px) {
	return textureLod(source_tex, px / params.raster_size, 0.0);
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Helligkeit wie nach der Belichtung (für Vergleiche; das Bild ist hier noch HDR)
float tlum(vec3 c) {
	float l = lum(c);
	return l / (1.0 + l);
}

float raw_depth(vec2 px) {
	return textureLod(depth_tex, px / params.raster_size, 0.0).r;
}

vec3 normal_at(vec2 px) {
	return normalize(textureLod(normal_tex, px / params.raster_size, 0.0).xyz * 2.0 - 1.0);
}

void main() {
	ivec2 ip = ivec2(gl_GlobalInvocationID.xy);
	vec2 size = params.raster_size;
	if (ip.x >= int(size.x) || ip.y >= int(size.y)) {
		return;
	}
	float scale = size.y / 1080.0;
	vec2 px = vec2(ip) + 0.5;
	vec2 suv = px / size.y;

	// 1. Zittern wie von Hand (nur für die Linien; Farben werden genau am Bildpunkt gelesen – scharf)
	vec2 wob = (vec2(vnoise(suv * 9.0), vnoise(suv * 9.0 + 17.3)) - 0.5) * 2.0 * params.wobble * scale;
	vec2 p = px + wob;

	// 2. Pinselflächen (wahlweise): vier Viertel um den Punkt, das ruhigste (kleinste Streuung) zählt am meisten
	vec4 center = source_at(px);
	vec3 col = center.rgb;
	int r = int(round(params.radius * scale));
	if (r > 0) {
		vec3 m[4] = vec3[](vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));
		float sl[4] = float[](0.0, 0.0, 0.0, 0.0);
		float sl2[4] = float[](0.0, 0.0, 0.0, 0.0);
		float n[4] = float[](0.0, 0.0, 0.0, 0.0);
		for (int y = -r; y <= r; y++) {
			for (int x = -r; x <= r; x++) {
				vec3 c = source_at(px + vec2(float(x), float(y))).rgb;
				float l = tlum(c);
				for (int k = 0; k < 4; k++) {
					bool inx = (k % 2 == 0) ? x <= 0 : x >= 0;
					bool iny = (k < 2) ? y <= 0 : y >= 0;
					if (inx && iny) {
						m[k] += c;
						sl[k] += l;
						sl2[k] += l * l;
						n[k] += 1.0;
					}
				}
			}
		}
		vec3 acc = vec3(0.0);
		float wsum = 0.0;
		for (int k = 0; k < 4; k++) {
			float lm = sl[k] / n[k];
			float var = max(0.0, sl2[k] / n[k] - lm * lm);
			float w = 1.0 / (1.0 + pow(var * 600.0, 2.0));
			acc += m[k] / n[k] * w;
			wsum += w;
		}
		col = acc / wsum;
	}

	// Entfernung des Bildpunkts in m (umgekehrte Tiefe): in der Ferne werden Farbränder und Linien
	// ausgeblendet – dort sind die Formen kleiner als ein paar Bildpunkte und würden nur flimmern
	float r0 = raw_depth(px);
	float dist = params.z_near / max(r0, 1e-7);
	float near = 1.0 - smoothstep(params.line_fade * 0.3, params.line_fade, dist);

	// 3. Farbränder dunkler (wie getrocknete Aquarellfarbe am Rand einer Fläche) – nur an deutlichen
	// Farbgrenzen, nicht an feinen Mustern wie Pflaster oder Ziegeln
	float e = 2.0 * scale;
	float gx = tlum(source_at(px + vec2(e, 0.0)).rgb) - tlum(source_at(px - vec2(e, 0.0)).rgb);
	float gy = tlum(source_at(px + vec2(0.0, e)).rgb) - tlum(source_at(px - vec2(0.0, e)).rgb);
	col *= 1.0 - params.edge_dark * near * smoothstep(0.12, 0.4, length(vec2(gx, gy)));

	// 4. Tuschelinien: Sprünge in der Tiefe (Umrisse) und Knicke in der Flächenrichtung
	r0 = raw_depth(p);
	vec3 n0 = normal_at(p);
	float w = params.line_width * scale;
	float edge = 0.0;
	for (int k = 0; k < 2; k++) {
		vec2 o = (k == 0) ? vec2(w, 0.0) : vec2(0.0, w);
		float ra = raw_depth(p + o);
		float rb = raw_depth(p - o);
		// gerade Flächen haben eine gleichmäßige umgekehrte Tiefe – nur echte Kanten zählen
		float lap = abs(ra + rb - 2.0 * r0) / max(r0, 1e-7);
		edge = max(edge, smoothstep(0.04, 0.16, lap));
		float bend = max(1.0 - dot(n0, normal_at(p + o)), 1.0 - dot(n0, normal_at(p - o)));
		edge = max(edge, smoothstep(0.3, 0.6, bend));
	}
	// in der Ferne blasser und ab line_fade gar nicht mehr (auch nicht über dem Himmel)
	edge *= near;
	// Strichdruck schwankt leicht (gleichmäßig entlang der Bildfläche, keine Brüche in der Linie)
	edge *= 1.0 - params.pressure * vnoise(suv * 18.0);
	// Tusche: dunkles Braun, so hell wie ein Teil der Fläche darunter – auf hellen Wänden mittelbraun,
	// im Schatten dunkelbraun, nie schwarz
	vec3 hue = params.line_color / max(lum(params.line_color), 1e-4);
	vec3 ink = hue * max(lum(col) * params.line_dark, 0.02);
	ink = mix(ink, col * params.line_dark, 0.25);
	col = mix(col, ink, clamp(edge * params.line_strength, 0.0, 1.0));

	// 5. Papier
	float l = tlum(col);
	float clouds = fbm(suv * 3.2);                         // Farbe ungleichmäßig aufgetragen (große Wolken)
	float pools = fbm(suv * 14.0 + 3.7) - 0.5;              // kleine Pfützen und Flecken im Pigment
	float grain = vnoise(px / (4.0 * scale)) - 0.5;         // Papierkörnung (grob, kein Bildrauschen)
	float fibers = vnoise(suv * vec2(120.0, 35.0)) - 0.5;   // Papierfasern
	col *= mix(1.0, 0.87 + 0.26 * clouds, params.paper);
	col *= 1.0 - params.paper * (0.12 * pools + 0.07 * grain * (1.15 - l) + 0.04 * fibers);

	// 6. warme, weiche Farbstimmung
	col += params.wash * 0.03 * vec3(1.0, 0.9, 0.74) * (1.0 - l);
	float L = lum(col);
	col = mix(vec3(L), col, params.saturation);
	col *= vec3(1.0 + 0.05 * params.warmth, 1.0 + 0.01 * params.warmth, 1.0 - 0.08 * params.warmth);

	imageStore(color_image, ip, vec4(max(col, vec3(0.0)), center.a));
}
