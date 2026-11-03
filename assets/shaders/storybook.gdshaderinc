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
// 8 Quader (große, runde Steinblöcke), 9 Bretter (waagerechte Holzverschalung, seit Etappe 6b)
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
// Stoffmuster (seit Etappe 6, Möbel): 0 keins, 1 Vichy-Karo, 2 Blümchen, 3 Schottenkaro.
// Karo: base_color = Karofarbe, third_color = heller Grund. Blümchen: base_color = Grund,
// second_color = Blüten, third_color = Blütenmitte. Schottenkaro: base_color = Grund,
// second_color und third_color = Streifen. Farbvarianten ändern base_color.
uniform int pattern = 0;
// Größe eines Musterfelds in m (ein Karo, eine Blume)
uniform float pattern_size = 0.04;
uniform vec4 third_color : source_color = vec4(0.95, 0.91, 0.82, 1.0);
// Verwitterung (seit Etappe 6c, alte Bücherei-Fassade): 0 = neu … 1 = alt. Mauerwerk: Reste von altem
// Putz in weather_color, abgeplatzte Stellen, Risse, einzelne fehlende Steine, Schmutzstreifen, ein Hauch
// Moos unten. Anstrich: abblätternde Farbe (darunter weather_color), ausgeblichen. Putz: Risse und Flecken.
uniform float weather = 0.0;
uniform vec4 weather_color : source_color = vec4(0.84, 0.78, 0.68, 1.0);

// Die Häuser bekommen von HouseFacade immer diese Werte – hier ohne Wirkung
#ifndef REST_POSITION
instance uniform vec4 wall_color : source_color = vec4(1.0);
instance uniform vec4 door_color : source_color = vec4(1.0);
instance uniform vec4 accent_color : source_color = vec4(1.0);
instance uniform int wall_layer = -1;
#endif

// Wind (Markisenstoff): so weit (m) schwingt der Stoff; wie stark jede Ecke mitgeht, steht im
// Alpha der Vertex-Farbe (1 = fest, z. B. am Kasten und an der Stange; 0 = frei, unten am Volant).
// Feste Teile haben Alpha 1 und bewegen sich nie.
uniform float wind_strength = 0.0;

varying vec3 model_pos;
varying vec3 model_normal;

#ifdef REST_POSITION
// Tiere (seit Etappe 6g, storybook_animal.gdshader): Muster aus der Ruhehaltung (UV = x, y; UV2.x = z – vom
// Bau-Script tools/blender/build_animals.py eingetragen), sonst rutscht das Fell beim Laufen unter den
// Flecken hindurch. Tigerstreifen (Katzen): tabby = Stärke (0 = keine), tabby_color = Farbe der Streifen
// (wird mit der Fellfarbe malgenommen), tabby_scale = Streifen je Meter.
uniform float tabby = 0.0;
uniform vec4 tabby_color : source_color = vec4(0.55, 0.4, 0.3, 1.0);
uniform float tabby_scale = 13.0;
// Farbmaske im Netz (UV2.y, seit Etappe 6h): > 0 = Brust/Kehle bzw. helles Fell (second_color), < 0 = Kappe/Hals
// (third_color); mask_from = ab welchem Maskenwert die Farbe beginnt, mask_soft = wie weich der Übergang ist.
// Mit mask_shimmer > 0 schillert die dritte Farbe je nach Blickwinkel nach shimmer_color (Taubenhals).
uniform float mask_from = 0.25;
uniform float mask_soft = 0.35;
uniform float mask_shimmer = 0.0;
uniform vec4 shimmer_color : source_color = vec4(0.45, 0.25, 0.55, 1.0);
varying float animal_mask;
#endif

#ifdef CAT_FACE
// Gemaltes Katzengesicht (storybook_cat.gdshader). Lage in der Ruhehaltung (Godot: x = links der Katze, y oben,
// z vorn), eingetragen vom Bau-Script: linkes Auge (das rechte ist gespiegelt), Achsen quer (nach außen) und hoch.
uniform vec3 eye_center = vec3(0.034, 0.198, 0.167);
uniform vec3 eye_right = vec3(0.86, 0.0, -0.5);
uniform vec3 eye_up = vec3(0.0, 1.0, 0.0);
uniform vec2 eye_size = vec2(0.0165, 0.0185);
uniform vec4 eye_color : source_color = vec4(0.7, 0.42, 0.16, 1.0);      // Iris (je Katze)
uniform vec4 pupil_color : source_color = vec4(0.07, 0.045, 0.035, 1.0);
uniform vec4 line_color : source_color = vec4(0.22, 0.12, 0.08, 1.0);    // Lidrand, Mund
// 0 = offen … 1 = zu: blink = Linie nach unten gebogen (schlafen, blinzeln), happy = Bogen nach oben (zufrieden)
uniform float eye_blink = 0.0;
uniform float eye_happy = 0.0;
uniform vec3 mouth_center = vec3(0.0, 0.174, 0.176);
uniform vec2 mouth_size = vec2(0.0085, 0.0035);
uniform vec4 blush_color : source_color = vec4(1.0, 0.62, 0.62, 1.0);
uniform float blush = 0.35;
// Linkes Ohr (rechtes gespiegelt): schräges Dreieck – Ecke innen unten (Ursprung), Achsen e1 (zur äußeren Ecke),
// e2 (zur Spitze), n (vorn); 2D-Lage der äußeren Ecke und der Spitze. Innenseite rosa gemalt.
uniform vec3 ear_origin = vec3(0.036, 0.262, 0.098);
uniform vec3 ear_e1 = vec3(0.73, -0.66, 0.23);
uniform vec3 ear_e2 = vec3(0.66, 0.75, 0.0);
uniform vec3 ear_n = vec3(0.0, 0.0, 1.0);
uniform vec2 ear_out = vec2(0.06, 0.0);
uniform vec2 ear_tip = vec2(0.045, 0.05);
uniform vec4 ear_color : source_color = vec4(0.96, 0.66, 0.66, 1.0);
// Streifen: Kopf (Mitte, Halbmesser), Schwanz ab z < tail_start, Beine unter y < leg_top
uniform vec3 head_center = vec3(0.0, 0.205, 0.112);
uniform float head_radius = 0.07;
uniform float tail_start = -0.124;
uniform float leg_top = 0.062;
#endif

void vertex() {
#ifdef REST_POSITION
	model_pos = vec3(UV.x, 1.0 - UV.y, UV2.x);
	animal_mask = 1.0 - UV2.y;
#else
	model_pos = VERTEX;
#endif
	model_normal = NORMAL;
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

// Mauerwerk im Läuferverband: Abstand zur nächsten Fuge (m) und Nummer des Steins (id); edges = Abstand
// zur nächsten senkrechten bzw. waagerechten Fuge einzeln (für die runde Kissenform der Steine)
float masonry_d(vec3 p, out vec2 id, out vec2 edges) {
	bool ashlar = grain == 8;
	float BW = ashlar ? 0.46 : 0.34;
	float BH = ashlar ? 0.27 : 0.115;
	float JOINT = ashlar ? 0.024 : 0.02;
	vec2 q = vec2(p.x - p.z, p.y);
	float row = floor(q.y / BH);
	q.x += ashlar ? hash(vec3(row, 1.7, 2.9)) * BW : mod(row, 2.0) * BW * 0.5;
	id = vec2(floor(q.x / BW), row);
	vec2 f = vec2(fract(q.x / BW) * BW, fract(q.y / BH) * BH);
	float dx = min(f.x, BW - f.x);
	if (ashlar && hash(vec3(id, 5.0)) < 0.35) {
		// geteilter Block: zweite Fuge etwa in der Mitte
		dx = min(dx, abs(f.x - BW * (0.4 + 0.2 * hash(vec3(id, 9.0)))));
	}
	// Kanten leicht unregelmäßig, wie von Hand gesetzt
	float jitter = (value_noise(p * 14.0) - 0.5) * (ashlar ? 0.014 : 0.008) - JOINT * 0.5;
	edges = vec2(dx, min(f.y, BH - f.y)) + jitter;
	return min(edges.x, edges.y);
}

// Holzverschalung: Höhe eines Bretts (m) und Lage im Brett (0 unten … 1 oben); id = Brett (Reihe, Stück)
const float BOARD_H = 0.15;
const float BOARD_L = 2.2;
float board_f(vec3 p, out vec2 id) {
	float row = floor(p.y / BOARD_H);
	float along = p.x - p.z + hash(vec3(row, 4.1, 8.3)) * BOARD_L;
	id = vec2(floor(along / BOARD_L), row);
	return fract(p.y / BOARD_H);
}

// Höhe des feinen Reliefs (0 … 1) an der Stelle p; px = Größe eines Bildpunkts (m)
// Musterfläche: die zwei Achsen quer zur Hauptrichtung der Fläche (wie aufgedruckt)
vec2 pattern_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) {
		return p.xz;
	}
	if (a.x >= a.z) {
		return p.zy;
	}
	return p.xy;
}

// weiche Streifen 0/1 mit Kantenglättung (w = Breite eines Bildpunkts im Muster)
float soft_band(float x, float w) {
	float f = abs(fract(x) - 0.5) * 2.0;
	return smoothstep(0.5 - w, 0.5 + w, f);
}

vec3 fabric_pattern(vec3 col, vec3 p, vec3 n, float px) {
	vec2 uv = pattern_uv(p, n) / pattern_size;
	float w = clamp(px / pattern_size * 1.5, 0.02, 0.5);
	float fade = detail_fade(px, 1.0 / pattern_size);
	if (pattern == 1) {
		float a = soft_band(uv.x, w);
		float b = soft_band(uv.y, w);
		vec3 light = third_color.rgb;
		vec3 c = mix(light, col, (a + b) * 0.5);
		return mix(mix(light, col, 0.5), c, fade);
	}
	if (pattern == 2) {
		vec2 cell = floor(uv);
		vec2 f = fract(uv) - 0.5;
		float h1 = hash(vec3(cell, 1.0));
		float h2 = hash(vec3(cell, 2.0));
		float h3 = hash(vec3(cell, 3.0));
		vec2 q = f - (vec2(h1, h2) - 0.5) * 0.35;
		float r = length(q);
		float ang = atan(q.y, q.x) + h3 * 6.2832;
		float petal = 0.2 + 0.07 * cos(ang * 5.0);
		float flower = 1.0 - smoothstep(petal - w, petal + w, r);
		float heart = 1.0 - smoothstep(0.06 - w, 0.06 + w, r);
		vec3 c = mix(col, second_color.rgb, flower);
		c = mix(c, third_color.rgb, heart);
		return mix(mix(col, second_color.rgb, 0.18), c, fade);
	}
	if (pattern == 3) {
		float a = soft_band(uv.x * 0.5, w);
		float b = soft_band(uv.y * 0.5, w);
		float thin_a = 1.0 - smoothstep(0.04, 0.04 + w, abs(fract(uv.x * 0.5 + 0.25) - 0.5));
		float thin_b = 1.0 - smoothstep(0.04, 0.04 + w, abs(fract(uv.y * 0.5 + 0.25) - 0.5));
		vec3 c = mix(col, second_color.rgb, (a + b) * 0.35);
		c = mix(c, third_color.rgb, max(thin_a, thin_b) * 0.85);
		return mix(mix(col, second_color.rgb, 0.3), c, fade);
	}
	return col;
}

// Verwitterung an der Stelle p: x = alter Putz (1 = Putz liegt noch drauf), y = Riss (1 = mitten im Riss),
// z = fehlender Stein bzw. abgeblätterte Farbe (1 = weg), w = Schmutz (0 … 1)
vec4 weathering(vec3 p, vec2 brick_id, float px) {
	if (weather <= 0.0) {
		return vec4(0.0);
	}
	vec3 q = vec3(p.x - p.z, p.y, p.x + p.z);
	float fade = detail_fade(px, 30.0);
	// Putzreste: große, ausgefranste Flächen, an den Rändern kleine abgeplatzte Stücke
	float patch = fbm(q * vec3(0.55, 0.45, 0.55) + vec3(3.1, 7.7, 1.3), 4);
	float edge = fbm(q * 7.0 + vec3(1.9), 2) * 0.1;
	float plaster = smoothstep(0.575, 0.59, patch + edge + 0.02 * weather) * weather;
	// Risse: schmale, verzweigte Linien
	float rn = fbm(q * vec3(1.6, 1.1, 1.6) + vec3(8.3, 2.2, 5.1), 4);
	float crack = (1.0 - smoothstep(0.0, 0.006 + px * 0.5, abs(rn - 0.5))) * smoothstep(0.55, 0.62, fbm(q * 0.8 + vec3(4.4), 2));
	crack *= weather * fade;
	// fehlende Steine (Mauerwerk) bzw. abgeblätterte Farbe (Anstrich)
	float missing = 0.0;
	if (grain == 3 || grain == 8) {
		missing = step(hash(vec3(brick_id, 13.0)), 0.022 * weather) * (1.0 - plaster);
	} else if (grain == 7) {
		float flake = fbm(q * vec3(7.0, 4.5, 7.0) + vec3(2.7), 3) + fbm(q * 26.0, 2) * 0.1 * fade;
		missing = smoothstep(0.66, 0.672, flake + 0.03 * weather) * weather;
	}
	// Schmutz: senkrechte Streifen (Regen), unten etwas dunkler
	float streak = fbm(vec3(q.x * 5.0, q.y * 0.35, q.z * 5.0), 3);
	float dirt = (smoothstep(0.45, 0.8, streak) * 0.7 + smoothstep(0.6, -0.4, p.y) * 0.5) * weather;
	return vec4(plaster, crack, missing, dirt);
}

float surface_height(vec3 p, float px) {
	if (grain == 3 || grain == 8) {
		bool ashlar = grain == 8;
		float JOINT = ashlar ? 0.024 : 0.02;
		vec2 id;
		vec2 edges;
		masonry_d(p, id, edges);
		float far = smoothstep(0.4, 1.1, px / JOINT);
		// runde Steinkanten wie ein Kissen: Rundung zu jeder Fuge für sich, malgenommen – so sind auch die
		// Ecken rund (mit dem kleinsten Abstand allein liefen Knickkanten diagonal von den Ecken zur Mitte)
		float w = ashlar ? 0.05 : 0.026;
		float h = smoothstep(-0.004, w, edges.x) * smoothstep(-0.004, w, edges.y) * (1.0 - far);
		if (weather > 0.0) {
			vec4 wt = weathering(p, id, px);
			// Putzreste liegen über den Steinen, fehlende Steine sind tief, Risse kleine Kerben
			h = mix(h, 1.25 + fbm(p * 30.0, 2) * 0.15, wt.x);
			h *= 1.0 - wt.z * 0.9;
			h -= wt.y * 0.5;
		}
		return h;
	} else if (grain == 1) {
		return fbm(p * 9.0, 3) * 0.7 + fbm(p * 45.0, 2) * 0.3 * detail_fade(px, 45.0);
	} else if (grain == 0) {
		return fbm(p * 7.0, 3) * 0.65 + fbm(p * 40.0, 2) * 0.35 * detail_fade(px, 40.0);
	} else if (grain == 4) {
		return fbm(p * 90.0, 2) * detail_fade(px, 90.0);
	} else if (grain == 6) {
		return fbm(p * 25.0, 2) * detail_fade(px, 25.0);
	} else if (grain == 7) {
		float h7 = fbm(p * 6.0, 3) * 0.7 + fbm(p * 30.0, 2) * 0.3 * detail_fade(px, 30.0);
		if (weather > 0.0) {
			vec4 wt = weathering(p, vec2(0.0), px);
			h7 -= wt.z * 0.8 + wt.y * 0.4;
		}
		return h7;
	} else if (grain == 9) {
		// jedes Brett unten dicker (liegt über dem nächsten), die Kante weich gerundet
		vec2 id;
		float f = board_f(p, id);
		return (1.0 - f * 0.85) * smoothstep(0.0, 0.06, f) * detail_fade(px, 1.0 / BOARD_H);
	}
	return 0.0;
}

#ifdef CAT_FACE
// Weiche Kante: 1 innen, 0 außen (aa = Breite des Übergangs)
float cat_inside(float d, float r, float aa) {
	return 1.0 - smoothstep(r - aa, r + aa, d);
}

// Abstand zu einem Dreieck in der Ebene (negativ = innen), nach Inigo Quilez
float cat_triangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
	vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
		vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
		vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

// Streifen-Band (0..1) aus einer Größe f (Streifen je Einheit), breit = Anteil des Streifens
float cat_band(float f, float wide) {
	return smoothstep(1.0 - wide - 0.12, 1.0 - wide + 0.05, 0.5 + 0.5 * cos(f * 6.2832));
}

// Tigerstreifen wie in den Vorlagen: auf dem Kopf oben längs (3 Streifen, nach unten schmaler), an den Wangen quer,
// am Rumpf quer um den Körper (oben kräftiger), an Beinen und Schwanz als Ringe.
float cat_stripes(vec3 p) {
	float n = value_noise(p * 55.0) - 0.5;
	vec3 dh = p - head_center;
	float head = 1.0 - smoothstep(head_radius * 1.02, head_radius * 1.25, length(dh * vec3(0.9, 1.0, 1.0)));
	float tail = smoothstep(tail_start + 0.008, tail_start - 0.008, p.z) * (1.0 - head);
	float leg = smoothstep(leg_top + 0.008, leg_top - 0.012, p.y) * (1.0 - head) * (1.0 - tail);
	float body = (1.0 - head) * (1.0 - tail) * (1.0 - leg);
	// Kopf oben: Streifen längs (Funktion von x), von hinten über die Stirn bis knapp über die Augen
	float top = smoothstep(0.018, 0.04, dh.y) * smoothstep(0.034, 0.022, abs(p.x));
	float fore = cat_band(p.x / 0.0135 + n * 0.25, 0.3 + 0.12 * smoothstep(0.02, 0.05, dh.y)) * top;
	// Wangen: zwei Streifen quer (Funktion von y), nur an den Seiten
	float side = smoothstep(0.04, 0.058, abs(p.x)) * smoothstep(0.03, 0.0, dh.z) * smoothstep(-0.04, -0.025, dh.y)
		* smoothstep(0.02, 0.008, dh.y);
	float cheek = cat_band(dh.y / 0.012 + n * 0.3, 0.3) * side;
	float h = max(fore, cheek);
	// Rumpf: quer um den Körper (Funktion von z, leicht gebogen), oben kräftiger
	float b = cat_band(p.z / 0.03 + 0.25 * abs(p.x) / 0.03 + n * 0.6, 0.32) * (0.45 + 0.55 * smoothstep(0.09, 0.15, p.y));
	float l = cat_band(p.y / 0.022 + n * 0.4, 0.3) * 0.85;
	float t = cat_band(p.z / 0.03 + n * 0.3, 0.4);
	return h * head + b * body + l * leg + t * tail;
}

// Augen, Mund und Wangenröte aufs Fell malen; gloss = wie glänzend (Augen)
vec3 cat_face(vec3 p, vec3 col, float px, inout float gloss) {
	float side = p.x < 0.0 ? -1.0 : 1.0;
	vec3 q = vec3(abs(p.x), p.y, p.z);
	vec3 d = q - eye_center;
	vec3 nrm = normalize(cross(eye_right, eye_up));
	if (abs(dot(d, nrm)) < 0.02) {
		vec2 e = vec2(dot(d, normalize(eye_right)) / eye_size.x, dot(d, normalize(eye_up)) / eye_size.y);
		float r = length(e);
		if (r < 1.6) {
			float aa = clamp(length(fwidth(e)) * 0.75, 0.02, 0.6);
			// Lider: offen zwischen lower und upper; zu = beide auf der Linie c (blink ∪, happy ∩)
			float k = clamp(max(eye_blink, eye_happy), 0.0, 1.0);
			float hw = eye_happy / (eye_blink + eye_happy + 1e-4);
			float c = mix(-0.32 + 0.38 * e.x * e.x, 0.12 - 0.5 * e.x * e.x, hw);
			float upper = mix(1.25, c, k);
			float lower = mix(-1.25, c, k);
			float open = smoothstep(lower - aa, lower + aa, e.y) * (1.0 - smoothstep(upper - aa, upper + aa, e.y));
			float inside = cat_inside(r, 1.0, aa);
			// Iris (unten heller), große Pupille, dunkler Rand (oben breiter = Oberlid), Glanzpunkte
			vec3 iris = mix(eye_color.rgb * 0.5, eye_color.rgb * 1.12, smoothstep(0.35, -0.85, e.y));
			vec3 eye = mix(iris, pupil_color.rgb, cat_inside(length(e - vec2(0.0, 0.08)), 0.63, aa));
			eye = mix(eye, line_color.rgb, smoothstep(0.85 - aa, 0.85 + aa, r + 0.08 * smoothstep(0.0, 0.8, e.y)));
			vec2 ew = vec2(e.x * side, e.y);   // in der Welt: Glanz bei beiden Augen auf derselben Seite
			float g1 = cat_inside(length((ew - vec2(-0.3, 0.36)) * vec2(1.0, 1.15)), 0.27, aa);
			float g2 = cat_inside(length(ew - vec2(0.3, -0.38)), 0.12, aa);
			eye = mix(eye, vec3(0.98, 0.97, 0.95), max(g1, g2 * 0.85));
			float shown = inside * open;
			col = mix(col, eye, shown);
			gloss = max(gloss, shown);
			// Lidstrich an der Lidkante (beim Schließen), nur über dem Auge
			float lid = cat_inside(abs(e.y - upper), 0.13, aa) * cat_inside(abs(e.x), 0.98, aa)
				* smoothstep(0.03, 0.2, k) * step(r, 1.3);
			col = mix(col, line_color.rgb, lid);
		}
	}
	// Rosa Innenohr: das Ohr-Dreieck, nach innen versetzt und abgerundet, nur auf der Vorderseite (Mulde)
	{
		vec3 de = q - ear_origin;
		vec2 e = vec2(dot(de, ear_e1), dot(de, ear_e2));
		float w = dot(de, ear_n);
		if (abs(w) < 0.02 && e.y > -0.01 && e.y < ear_tip.y + 0.01) {
			float d = cat_triangle(e, vec2(0.0), ear_out, ear_tip);
			float h = e.y / ear_tip.y;
			float inner = cat_inside(d, -0.0052, max(px, 0.0007)) * smoothstep(0.04, 0.12, h) * smoothstep(-0.005, -0.001, w);
			vec3 pink = mix(ear_color.rgb, ear_color.rgb * vec3(0.9, 0.78, 0.8), cat_inside(d, -0.012, 0.004));
			col = mix(col, pink, inner);
		}
	}
	// Wangenröte: weich, schräg unter den Augen
	vec3 bc = eye_center + vec3(0.012, -0.022, -0.008);
	float bl = 1.0 - smoothstep(0.004, 0.014, length((q - bc) * vec3(1.0, 1.4, 1.0)));
	col = mix(col, col * blush_color.rgb, bl * blush);
	// Mund: „w“ (je Seite ein Bogen nach unten) und ein kurzer Strich hinauf zur Nase
	vec3 dm = p - mouth_center;
	if (abs(dm.x) < mouth_size.x * 1.4 && abs(dm.y) < 0.014 && dm.z > -0.012) {
		float X = abs(dm.x) / mouth_size.x;
		float arc = -mouth_size.y * (1.0 - pow((X - 0.5) / 0.5, 2.0));
		float w = 0.0008;
		float dist = abs(dm.y - arc) + max(0.0, abs(dm.x) - mouth_size.x);
		float line = cat_inside(dist, w, px) * clamp(w * 2.0 / px, 0.0, 1.0);
		float stem = cat_inside(abs(dm.x), w * 0.9, px) * step(0.0, dm.y) * cat_inside(dm.y, 0.006, px)
			* clamp(w * 2.0 / px, 0.0, 1.0);
		col = mix(col, line_color.rgb, max(line, stem));
	}
	return col;
}
#endif

void fragment() {
	vec3 p = model_pos;
	vec3 col = base_color.rgb;
	// Größe eines Bildpunkts auf der Fläche (m): feine Muster blenden sich aus, bevor sie flimmern
	float px = length(fwidth(p)) + 1e-5;
	if (stripe_width > 0.0) {
		// Streifen entlang x, Kanten leicht unruhig wie gewebt
		float s = fract((p.x + 0.012 * value_noise(p * 3.0)) / (stripe_width * 2.0));
		col = s > 0.5 ? second_color.rgb : base_color.rgb;
	}
#ifdef REST_POSITION
	float light_fur = 0.0;
	float gloss = 0.0;
	{
		// Glatter Übergang zwischen den Farben (Brust, Kappe; Taubenhals schillernd)
		float m = animal_mask;
		float w2 = smoothstep(mask_from, mask_from + mask_soft, m);
		light_fur = w2;
		float w3 = smoothstep(mask_from, mask_from + mask_soft, -m);
		vec3 third = third_color.rgb;
		if (mask_shimmer > 0.0) {
			float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
			third = mix(third, shimmer_color.rgb, mask_shimmer * (1.0 - facing));
		}
		col = mix(col, second_color.rgb, w2);
		col = mix(col, third, w3);
	}
	if (tabby > 0.0) {
#ifdef CAT_FACE
		// Katze: Streifen wie in den Vorlagen, nie auf dem hellen Fell (Latz, Schnauze, Pfoten)
		float st = clamp(cat_stripes(p), 0.0, 1.0) * (1.0 - light_fur);
		col = mix(col, col * tabby_color.rgb, st * tabby * detail_fade(px, tabby_scale));
#else
		// Streifen quer zum Körper (Rumpf: entlang z, Beine und Schwanz: entlang y), unruhig wie gemalt,
		// zum Bauch hin blasser
		float f = p.z * tabby_scale + p.y * tabby_scale * 0.45 + 0.9 * value_noise(p * 7.0) + 0.35 * abs(p.x) * tabby_scale;
		float band = smoothstep(0.62, 0.8, 0.5 + 0.5 * sin(f * 6.2832));
		float back = smoothstep(0.1, 0.24, p.y) * 0.7 + 0.3;
		col = mix(col, col * tabby_color.rgb, band * tabby * back * detail_fade(px, tabby_scale));
#endif
	}
#ifdef CAT_FACE
	col = cat_face(p, col, px, gloss);
#endif
#endif
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
		vec2 id;
		vec2 edges;
		float d = masonry_d(p, id, edges);
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
	}
	if (pattern > 0) {
		col = fabric_pattern(col, p, normalize(model_normal), px);
	}
	if (!masonry) {
		col *= COLOR.rgb;
	}
	if (weather > 0.0) {
		vec2 wid = vec2(0.0);
		vec2 wedges;
		if (masonry) {
			masonry_d(p, wid, wedges);
		}
		vec4 wt = weathering(p, wid, px);
		// ausgeblichen und leicht grau
		col = mix(col, vec3(dot(col, vec3(0.33))) * 1.05, 0.18 * weather);
		if (masonry) {
			vec3 plaster_col = weather_color.rgb * (0.9 + 0.14 * fbm(p * 5.0, 2));
			col = mix(col, plaster_col, wt.x);
			// Schattenkante, wo der alte Putz abgebrochen ist
			col *= 1.0 - 0.28 * (1.0 - abs(wt.x * 2.0 - 1.0)) * step(0.02, wt.x);
			col = mix(col, col * 0.35 + vec3(0.06, 0.05, 0.04), wt.z);
		} else if (grain == 7) {
			col = mix(col, weather_color.rgb * (0.85 + 0.2 * fbm(p * 9.0, 2)), wt.z);
		}
		col *= 1.0 - wt.y * 0.55;
		col *= 1.0 - wt.w * 0.22;
		// ein Hauch Moos ganz unten
		float moss = smoothstep(0.2, -0.45, p.y) * smoothstep(0.45, 0.7, fbm(p * 3.0 + vec3(9.0), 3)) * weather;
		col = mix(col, vec3(0.32, 0.38, 0.2), moss * 0.45);
	}
	float blot = fbm(p * blot_scale, 3);
	col *= mix(1.0 - vary, 1.0 + vary, smoothstep(0.3, 0.7, blot));
	if (grain == 2) {
		// Holz im Bilderbuch-Stil: ruhige, weiche Maserung – breite, sanft geschwungene Streifen in
		// leicht verschiedenen Brauntönen, ohne harte Linien, Astlöcher oder Fugen. Bewusst
		// niedrige Frequenz und kein Relief (feine Muster ergaben Treppchen-Pixel).
		float warp = fbm(p * vec3(1.2, 0.35, 1.2), 3);
		float streak = 0.5 + 0.5 * sin((p.x * 7.0 - p.z * 7.0 + warp * 3.0) * 6.2832 * 0.5);
		float soft = fbm(vec3((p.x - p.z) * 9.0, p.y * 1.2, 0.0), 2);
		float tone = mix(streak, soft, 0.5);
		col *= mix(0.92, 1.05, smoothstep(0.2, 0.8, tone));
	} else if (grain == 9) {
		// Bretter: jedes in eigenem Ton, unter jeder Kante ein weicher Schatten; ruhige Maserung längs
		vec2 id;
		float f = board_f(p, id);
		float fade = detail_fade(px, 1.0 / BOARD_H);
		float tone = mix(0.9, 1.06, hash(vec3(id, 2.0)));
		float shade = mix(0.68, 1.0, smoothstep(0.0, 0.22, f));
		float streak = fbm(vec3((p.x - p.z) * 1.5, p.y * 22.0, id.x * 3.1), 2);
		col *= mix(0.97, tone * shade * mix(0.94, 1.05, streak), fade);
	} else if (grain == 1) {
		// Stein: weich unregelmäßig, leichte Farbwolken, keine Risslinien
		col *= mix(0.95, 1.04, fbm(p * 3.0 + vec3(5.0), 2));
	}
	// Feines Relief (Putz, Stein, Steinkanten, Gewebe): Höhe an drei Stellen der Fläche, Abstand etwa ein
	// Bildpunkt – so ist das Relief an jedem Bildpunkt genau und weich (die frühere Rechnung über
	// Bildschirm-Ableitungen arbeitete in 2x2-Blöcken und machte Treppchen und Pixel an Fugen und Kanten).
	// Holz (Maserung nur in der Farbe) und Blätter (glatt) ohne Relief.
#ifdef REST_POSITION
	if (false) {
#else
	if (bump_strength > 0.0 && grain != 2 && grain != 5) {
#endif
		vec3 n = normalize(model_normal);
		vec3 t = normalize(cross(abs(n.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0), n));
		vec3 b = cross(n, t);
		float e = max(px, 0.0015);
		float h0 = surface_height(p, px);
		vec3 grad = ((surface_height(p + t * e, px) - h0) * t + (surface_height(p + b * e, px) - h0) * b) / e;
		vec3 g = (VIEW_MATRIX * (MODEL_MATRIX * vec4(grad, 0.0))).xyz;
		NORMAL = normalize(NORMAL - g * bump_strength * 0.02);
	}
	ALBEDO = col;
#ifdef REST_POSITION
	ROUGHNESS = mix(rough, 0.18, gloss);
#else
	ROUGHNESS = rough;
#endif
	METALLIC = metal;
	SPECULAR = 0.3;
	EMISSION = emission_color.rgb * emission_energy + col * glow;
}
