// Gemeinsamer Teil der Bilderbuch-Shader (storybook.gdshader, storybook_plant.gdshader).
// Bilderbuch-Stil (Modegeschäft "Zwirn und Zwirbel", tools/blender/build_storybook_shop.py):
// rechnet die Blender-Materialien im Spiel nach – ohne Bilddateien, alles aus der Lage im Modell.
//   Grundfarbe x Farbton je Teil (Vertex-Farbe "tint" aus Blender) x leichte Flecken,
//   dazu je nach Art (grain) Holzmaserung, Ziegel, Steinstruktur, Gewebe oder Putz als feines Relief.
// Ein Material je Blender-Material (assets/materials/storybook/*.tres, vom Bau-Script geschrieben).
// Lage im Modell: Godot-Koordinaten (x rechts, y oben, z nach vorn) – in Blender (x, -z, y).
uniform vec4 base_color : source_color = vec4(0.9, 0.85, 0.75, 1.0);
// Zweite Farbe: Streifen (Markise) bzw. Fugen der Ziegel
uniform vec4 second_color : source_color = vec4(0.75, 0.35, 0.27, 1.0);
// 0 Putz, 1 Stein, 2 Holz, 3 Ziegel, 4 Gewebe, 5 Blatt, 6 glatt, 7 Lack (gestrichenes Holz),
// 8 Quader (große, runde Steinblöcke)
uniform int grain = 0;
// Breite der Streifen in m (0 = keine)
uniform float stripe_width = 0.0;
// Flecken: Helligkeit wandert um +-vary, Größe über blot_scale
uniform float vary = 0.08;
uniform float blot_scale = 4.0;
uniform float bump_strength = 0.25;
uniform float rough = 0.85;
uniform float metal = 0.0;
uniform vec4 emission_color : source_color = vec4(1.0, 0.75, 0.45, 1.0);
uniform float emission_energy = 0.0;
// Innenräume leuchten leicht in ihrer eigenen Farbe (keine Lampen-Lichter im Spiel)
uniform float glow = 0.0;

// Die Häuser bekommen von HouseFacade immer diese Werte – hier ohne Wirkung
instance uniform vec4 wall_color : source_color = vec4(1.0);
instance uniform vec4 door_color : source_color = vec4(1.0);
instance uniform vec4 accent_color : source_color = vec4(1.0);
instance uniform int wall_layer = -1;

// Wind (Markisenstoff): so weit (m) schwingt der Stoff; wie stark jede Ecke mitgeht, steht im
// Alpha der Vertex-Farbe (1 = fest, z. B. am Kasten und an der Stange; 0 = frei, unten am Volant).
// Feste Teile haben Alpha 1 und bewegen sich nie.
uniform float wind_strength = 0.0;

varying vec3 model_pos;

void vertex() {
	model_pos = VERTEX;
	float sway = (1.0 - COLOR.a) * wind_strength;
	if (sway > 0.0) {
		// Beide Seiten des Stoffs bewegen sich gleich (fester Richtungsvektor, nicht die Normale).
		// Der Wind bläht den Stoff nur nach außen und oben auf (0..1), nie zurück zu Kasten und
		// Stange – so sticht nichts durch.
		float t = TIME;
		// Phase aus der Lage in der Welt (gebündelte Pflanzen schwingen nicht alle gleich)
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float wave = sin(t * 1.6 + wp.x * 1.4 + wp.z * 0.9) * 0.6
			+ sin(t * 2.9 + wp.x * 3.1 - wp.y * 1.7) * 0.3
			+ sin(t * 0.7 + wp.x * 0.5 + wp.z * 0.3) * 0.4;
		float puff = clamp(0.5 + 0.5 * wave / 1.3, 0.0, 1.0);
		VERTEX += vec3(0.0, 0.55, 0.85) * sway * puff;
	}
}

// 1 = Muster mit dieser Frequenz (Wiederholungen je Meter) gut sichtbar, 0 = feiner als ein paar
// Bildpunkte – dann ausblenden (sonst flimmert es und wirkt sandig)
float detail_fade(float px, float freq) {
	return 1.0 - smoothstep(0.1, 0.33, px * freq);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	for (int k = 0; k < octaves; k++) {
		sum += value_noise(p) * amp;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amp *= 0.5;
	}
	return sum;
}

// Abstand zur nächsten Kante einer Steinzelle (grobe Voronoi-Kanten)
float cell_edge(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash(i + g), hash(i + g + 11.3), hash(i + g + 23.7));
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return d2 - d1;
}

void fragment() {
	vec3 p = model_pos;
	vec3 col = base_color.rgb;
	float height = 0.0;
	// Größe eines Bildpunkts auf der Fläche (m): feine Muster blenden sich aus, bevor sie flimmern
	float px = length(fwidth(p)) + 1e-5;
	if (stripe_width > 0.0) {
		// Streifen entlang x, Kanten leicht unruhig wie gewebt
		float s = fract((p.x + 0.012 * value_noise(p * 3.0)) / (stripe_width * 2.0));
		col = s > 0.5 ? second_color.rgb : base_color.rgb;
	}
	bool masonry = grain == 3 || grain == 8;
	if (masonry) {
		// Mauerwerk im Läuferverband, waagerecht auf allen Seiten (Länge entlang x - z), runde
		// Kanten, jeder Stein in eigenem Ton, Fugen zurückgesetzt in gedämpftem Grau-Beige
		// (second_color, nicht eingefärbt). Ziegel: 34 x 11,5 cm, einzelne beige und dunkle Steine.
		// Quader: 46 x 27 cm, Breiten je Reihe verschoben, manche Blöcke geteilt.
		bool ashlar = grain == 8;
		float BW = ashlar ? 0.46 : 0.34;
		float BH = ashlar ? 0.27 : 0.115;
		float JOINT = ashlar ? 0.024 : 0.02;
		vec2 q = vec2(p.x - p.z, p.y);
		float row = floor(q.y / BH);
		q.x += ashlar ? hash(vec3(row, 1.7, 2.9)) * BW : mod(row, 2.0) * BW * 0.5;
		vec2 id = vec2(floor(q.x / BW), row);
		vec2 f = vec2(fract(q.x / BW) * BW, fract(q.y / BH) * BH);
		float dx = min(f.x, BW - f.x);
		if (ashlar && hash(vec3(id, 5.0)) < 0.35) {
			// geteilter Block: zweite Fuge etwa in der Mitte
			dx = min(dx, abs(f.x - BW * (0.4 + 0.2 * hash(vec3(id, 9.0)))));
		}
		// Abstand zur Fuge in m (Kanten leicht unregelmäßig, wie von Hand gesetzt)
		float d = min(dx, min(f.y, BH - f.y)) - JOINT * 0.5 + (value_noise(p * 14.0) - 0.5) * (ashlar ? 0.014 : 0.008);
		float stone = smoothstep(-px, px, d);
		float h1 = hash(vec3(id, 3.0));
		float h2 = hash(vec3(id, 7.0));
		vec3 base = base_color.rgb * COLOR.rgb;
		vec3 brick = base * (0.88 + 0.18 * h1);
		if (ashlar) {
			brick = mix(brick, base * vec3(1.06, 1.03, 0.96), smoothstep(0.6, 1.0, h2) * 0.8);
			brick *= 0.93 + 0.1 * fbm(p * 6.0, 2);
		} else {
			brick = mix(brick, vec3(0.8, 0.66, 0.5), smoothstep(0.7, 1.0, h2) * 0.6);
			brick = mix(brick, base * vec3(0.74, 0.7, 0.68), smoothstep(0.25, 0.0, h2) * 0.7);
		}
		// aus der Ferne: Steinfarben und Fugen gemittelt statt flimmernder Linien
		brick = mix(base * 0.97, brick, detail_fade(px, 1.0 / BH));
		float far = smoothstep(0.4, 1.1, px / JOINT);
		vec3 avg = mix(brick, second_color.rgb, JOINT * (BW + BH) / (BW * BH));
		col = mix(mix(second_color.rgb, brick, stone), avg, far);
		// runde Steinkanten: Höhe steigt zur Steinmitte weich an
		height = smoothstep(-0.004, ashlar ? 0.06 : 0.03, d) * (1.0 - far);
	}
	if (!masonry) {
		col *= COLOR.rgb;
	}
	float blot = fbm(p * blot_scale, 3);
	col *= mix(1.0 - vary, 1.0 + vary, smoothstep(0.3, 0.7, blot));
	if (grain == 2) {
		// Holz: feine, leicht geschwungene Maserungslinien (etwa alle 2,5 cm)
		float u = p.y * 38.0 + 2.5 * fbm(p * vec3(0.7, 2.5, 0.7), 3);
		float lines = smoothstep(0.72, 1.0, 0.5 + 0.5 * sin(u * 6.2832)) * detail_fade(px, 38.0);
		col *= 1.0 - 0.09 * lines;
		height = 1.0 - lines;
	} else if (grain == 1) {
		// Stein: weich unregelmäßig, leichte Farbwolken, keine Risslinien
		col *= mix(0.95, 1.04, fbm(p * 3.0 + vec3(5.0), 2));
		height = fbm(p * 9.0, 3) * 0.7 + fbm(p * 45.0, 2) * 0.3 * detail_fade(px, 45.0);
	} else if (grain == 0) {
		// Putz: sanfte Wellen der Kelle, feines Korn nur aus der Nähe
		height = fbm(p * 7.0, 3) * 0.65 + fbm(p * 40.0, 2) * 0.35 * detail_fade(px, 40.0);
	} else if (grain == 4) {
		height = fbm(p * 90.0, 2) * detail_fade(px, 90.0);
	} else if (grain == 5) {
		height = fbm(p * 90.0, 2) * detail_fade(px, 90.0);
	} else if (grain == 6) {
		height = fbm(p * 25.0, 2) * detail_fade(px, 25.0);
	} else if (grain == 7) {
		// Lack: matt, ganz leicht uneben gestrichen
		height = fbm(p * 6.0, 3) * 0.7 + fbm(p * 30.0, 2) * 0.3 * detail_fade(px, 30.0);
	}
	// Feines Relief aus der Höhe (Bump über Bildschirm-Ableitungen)
	if (bump_strength > 0.0) {
		vec3 dp1 = dFdx(VERTEX);
		vec3 dp2 = dFdy(VERTEX);
		float dh1 = dFdx(height);
		float dh2 = dFdy(height);
		vec3 r1 = cross(dp2, NORMAL);
		vec3 r2 = cross(NORMAL, dp1);
		float det = dot(dp1, r1);
		vec3 grad = sign(det) * (dh1 * r1 + dh2 * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad * bump_strength * 0.02);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
	EMISSION = emission_color.rgb * emission_energy + col * glow;
}
