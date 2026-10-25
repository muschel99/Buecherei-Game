// Boden der Außenwelt im Bilderbuch-Stil (Stil-Umbau der Welt, Etappe 4h): Straße, Gehwege,
// Bordsteine, Platz, Gassen und Eingangstreppe. Alles aus der Lage in der Welt berechnet (keine
// Bilder): runde, unregelmäßige Steine in warmen Tönen, weiche Fugen, jeder Stein leicht gewölbt.
// Aus der Ferne werden Fugen und Wölbung weich ausgeblendet (sonst flimmert es). Die Wölbung (Relief)
// wird an jedem Bildpunkt genau aus der Steinform berechnet – nicht über Bildschirm-Ableitungen, die in
// 2x2-Blöcken arbeiten und Treppchen und Pixel an den Fugen machten.
//   pattern 0 = Kopfsteinpflaster (rund, unregelmäßig – Fahrbahn)
//   pattern 1 = Platten (verschieden breite Reihen – Gehwege, Platz, Gasse)
//   pattern 2 = Bordstein-Quader (lange Steine)
//   pattern 3 = Kleinpflaster (kleine runde Steine in Reihen – Gassen)
//   pattern 4 = ruhiger Sandstein ohne Fugen, nach der Lage im Modell (Eingangstreppe: jede Stufe
//               ein ganzer Stein, Muster dreht sich mit der Treppe)
shader_type spatial;

uniform int pattern = 0;
// Größe eines Steins in m (Kopfstein: Abstand der Steine; Platten: Reihenhöhe)
uniform float stone_size = 0.17;
// Farben der Steine (je Stein gemischt) und der Fuge
uniform vec4 color_a : source_color = vec4(0.62, 0.5, 0.42, 1.0);
uniform vec4 color_b : source_color = vec4(0.72, 0.6, 0.48, 1.0);
uniform vec4 color_c : source_color = vec4(0.55, 0.47, 0.44, 1.0);
uniform vec4 color_accent : source_color = vec4(0.78, 0.55, 0.42, 1.0);
uniform vec4 joint_color : source_color = vec4(0.34, 0.28, 0.23, 1.0);
// Fugenbreite als Anteil des Steins (Kopfstein) bzw. in m (Platten, Bordstein)
uniform float joint = 0.12;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float bump_strength = 1.0;
// Muster um 90° drehen (Reihen quer statt längs)
uniform bool rotate_90 = false;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_pos = VERTEX;
	local_normal = NORMAL;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

// Ableitung von smoothstep(a, b, x) nach x
float smoothstep_slope(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return 6.0 * t * (1.0 - t) / (b - a);
}

// Farbe eines Steins aus seiner Nummer: Mischung aus drei warmen Tönen, selten ein Akzentstein
vec3 stone_color(vec2 id) {
	float h = hash12(id * 1.37 + 4.1);
	float h2 = hash12(id * 2.11 + 9.7);
	vec3 c = h < 0.4 ? mix(color_a.rgb, color_b.rgb, h / 0.4) : mix(color_b.rgb, color_c.rgb, (h - 0.4) / 0.6);
	c = mix(c, color_accent.rgb, step(0.9, h2) * 0.8);
	return c * (0.88 + 0.22 * hash12(id + 17.3));
}

void fragment() {
	bool top = abs(world_normal.y) > 0.5;
	vec2 uv;
	// Richtungen von u und v in der Welt (für das Relief)
	vec3 axis_u;
	vec3 axis_v;
	if (top) {
		uv = rotate_90 ? world_pos.zx : world_pos.xz;
		axis_u = rotate_90 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		axis_v = rotate_90 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0);
	} else if (abs(world_normal.x) > abs(world_normal.z)) {
		uv = vec2(world_pos.z, world_pos.y);
		axis_u = vec3(0.0, 0.0, 1.0);
		axis_v = vec3(0.0, 1.0, 0.0);
	} else {
		uv = vec2(world_pos.x, world_pos.y);
		axis_u = vec3(1.0, 0.0, 0.0);
		axis_v = vec3(0.0, 1.0, 0.0);
	}
	// Steigung des Reliefs (Höhe je m entlang u und v)
	vec2 slope = vec2(0.0);
	// Größe eines Bildpunkts auf dem Boden (m)
	float px = length(fwidth(world_pos)) + 1e-5;
	vec3 col;
	float height;
	float edge_m;
	vec2 id;
	if (pattern == 0 || pattern == 3) {
		// runde Steine: Voronoi-Zellen (leicht in Reihen), Abstand zur nächsten Zellgrenze
		float s = stone_size;
		vec2 q = uv / s;
		if (pattern == 3) {
			q.x += mod(floor(q.y), 2.0) * 0.5;
		}
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float d1 = 8.0;
		float d2 = 8.0;
		vec2 best = vec2(0.0);
		vec2 r1 = vec2(1.0, 0.0);
		vec2 r2 = vec2(-1.0, 0.0);
		float ky = pattern == 3 ? 1.0 : 1.15;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 g = vec2(float(x), float(y));
				vec2 o = pattern == 3 ? vec2(0.5) + (hash22(cell + g) - 0.5) * 0.35 : 0.15 + 0.7 * hash22(cell + g);
				vec2 r = g + o - f;
				r.y *= ky;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					r2 = r1;
					d1 = d;
					r1 = r;
					best = cell + g;
				} else if (d < d2) {
					d2 = d;
					r2 = r;
				}
			}
		}
		id = best;
		edge_m = (sqrt(d2) - sqrt(d1)) * 0.5 * s;
		float j = joint * s;
		float stone = smoothstep(j * 0.5 - px, j * 0.5 + px, edge_m);
		// Wölbung: zur Steinmitte hin weich ansteigend
		// gewölbt nur am Rand, oben flach (sonst laufen Knickkanten von den Ecken zur Steinmitte)
		float rim = j * 0.5 + s * 0.13;
		height = smoothstep(j * 0.3, rim, edge_m);
		// Steigung des Randabstands: zeigt von der Fuge weg zur Steinmitte
		vec2 ge = 0.5 * (vec2(r1.x, r1.y * ky) / max(length(r1), 1e-4) - vec2(r2.x, r2.y * ky) / max(length(r2), 1e-4));
		slope = ge * smoothstep_slope(j * 0.3, rim, edge_m);
		col = mix(joint_color.rgb, stone_color(id), stone);
	} else if (pattern == 1) {
		// Platten in Reihen, jede Reihe mit eigener Breite und Versatz
		float rh = stone_size;
		float row = floor(uv.y / rh);
		float w = rh * (0.9 + 0.7 * hash12(vec2(row, 3.7)));
		float xr = uv.x + hash12(vec2(row, 8.1)) * w;
		float colm = floor(xr / w);
		id = vec2(colm, row);
		float fx = fract(xr / w) * w;
		float fy = fract(uv.y / rh) * rh;
		// Ränder leicht unregelmäßig
		float wob = (vnoise(uv * 9.0) - 0.5) * 0.012;
		edge_m = min(min(fx, w - fx), min(fy, rh - fy)) + wob;
		float stone = smoothstep(joint * 0.5 - px, joint * 0.5 + px, edge_m);
		// Kissenform: Rundung zu den Längs- und Querfugen einzeln, malgenommen – runde Ecken ohne Knickkanten
		float ex = min(fx, w - fx) + wob;
		float ey = min(fy, rh - fy) + wob;
		float a0 = joint * 0.3;
		float a1 = joint * 0.5 + 0.05;
		float hx = smoothstep(a0, a1, ex);
		float hy = smoothstep(a0, a1, ey);
		height = hx * hy;
		slope = vec2((fx < w - fx ? 1.0 : -1.0) * smoothstep_slope(a0, a1, ex) * hy,
			(fy < rh - fy ? 1.0 : -1.0) * smoothstep_slope(a0, a1, ey) * hx);
		col = mix(joint_color.rgb, stone_color(id), stone);
		// Flecken und leichte Abnutzung auf jeder Platte
		col *= 0.93 + 0.12 * vnoise(uv * 2.3 + id * 3.1);
	} else if (pattern == 4) {
		// ruhiger Sandstein: weiche Wolken in zwei Tönen, ein paar helle Sprenkel, keine Fugen
		vec3 lp = local_pos;
		vec2 luv = abs(local_normal.y) > 0.5 ? lp.xz : (abs(local_normal.x) > abs(local_normal.z) ? lp.zy : lp.xy);
		uv = luv;
		id = vec2(0.0);
		float cloud = vnoise(luv * 1.6 + 3.1) * 0.6 + vnoise(luv * 4.3) * 0.4;
		col = mix(color_a.rgb, color_b.rgb, smoothstep(0.25, 0.75, cloud));
		col = mix(col, color_c.rgb, smoothstep(0.62, 0.8, vnoise(luv * 7.0 + 11.0)) * 0.5);
		height = 0.0;
		edge_m = 1.0;
	} else {
		// Bordstein: lange Quader entlang u
		float L = stone_size;
		float k = floor(uv.x / L);
		float fx = fract(uv.x / L) * L;
		id = vec2(k, 0.0);
		edge_m = min(fx, L - fx) + (vnoise(uv * 8.0) - 0.5) * 0.008;
		float stone = smoothstep(joint * 0.5 - px, joint * 0.5 + px, edge_m);
		height = smoothstep(joint * 0.3, joint * 0.5 + 0.04, edge_m);
		slope = vec2(fx < L - fx ? 1.0 : -1.0, 0.0) * smoothstep_slope(joint * 0.3, joint * 0.5 + 0.04, edge_m);
		col = mix(joint_color.rgb, stone_color(id), stone);
	}
	// feine Körnung, aus der Ferne ausgeblendet
	float grain = vnoise(uv * 40.0) * (1.0 - smoothstep(0.004, 0.012, px));
	col *= 0.96 + 0.08 * grain;
	// aus der Ferne: Fugen und Wölbung weich verschwinden lassen
	float far = pattern == 4 ? 0.0 : smoothstep(stone_size * 0.06, stone_size * 0.22, px);
	col = mix(col, mix(stone_color(id), joint_color.rgb, 0.15), far * 0.6);
	height *= 1.0 - far;
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	if (bump_strength > 0.0) {
		// Relief aus der Steigung (in der Welt), geglättet auf die Größe eines Bildpunkts: ist die Rundung
		// der Steinkante schmaler als ein paar Bildpunkte, wird sie sanft flacher (sonst flimmert es)
		float soft = 1.0 - smoothstep(0.012, 0.04, px);
		vec3 grad = (slope.x * axis_u + slope.y * axis_v) * (1.0 - far) * soft;
		vec3 g = (VIEW_MATRIX * vec4(grad, 0.0)).xyz;
		NORMAL = normalize(NORMAL - g * bump_strength * 0.035);
	}
	SPECULAR = 0.3;
}
