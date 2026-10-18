// Gemeinsamer Teil der Bilderbuch-Shader (storybook.gdshader, storybook_plant.gdshader).
// Bilderbuch-Stil (Modegeschäft "Zwirn und Zwirbel", tools/blender/build_storybook_shop.py):
// rechnet die Blender-Materialien im Spiel nach – ohne Bilddateien, alles aus der Lage im Modell.
//   Grundfarbe x Farbton je Teil (Vertex-Farbe "tint" aus Blender) x leichte Flecken,
//   dazu je nach Art (grain) Holzmaserung, Ziegel, Steinstruktur, Gewebe oder Putz als feines Relief.
// Ein Material je Blender-Material (assets/materials/storybook/*.tres, vom Bau-Script geschrieben).
// Lage im Modell: Godot-Koordinaten (x rechts, y oben, z nach vorn) – in Blender (x, -z, y).
uniform vec4 base_color : source_color = vec4(0.9, 0.85, 0.75, 1.0);
// Zweite Farbe: Streifen (Markise) bzw. dunkle Ziegel
uniform vec4 second_color : source_color = vec4(0.75, 0.35, 0.27, 1.0);
// 0 Putz, 1 Stein, 2 Holz, 3 Ziegel, 4 Gewebe, 5 Blatt, 6 glatt
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

varying vec3 model_pos;

void vertex() {
	model_pos = VERTEX;
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
	if (stripe_width > 0.0) {
		// Streifen entlang x, Kanten leicht unruhig wie gewebt
		float s = fract((p.x + 0.012 * value_noise(p * 3.0)) / (stripe_width * 2.0));
		col = s > 0.5 ? second_color.rgb : base_color.rgb;
	}
	if (grain == 3) {
		// Ziegel im Läuferverband, waagerecht auf allen Seiten (Länge entlang x - z)
		vec2 b = vec2(p.x - p.z, p.y) / vec2(0.225, 0.075);
		float row = floor(b.y);
		b.x += mod(row, 2.0) * 0.5;
		vec2 cell = fract(b);
		vec2 id = vec2(floor(b.x), row);
		float mortar = step(cell.x, 0.045) + step(cell.y, 0.13);
		float shade = 0.82 + 0.18 * hash(vec3(id, 3.0));
		col = mix(base_color.rgb * shade, vec3(0.78, 0.72, 0.62), clamp(mortar, 0.0, 1.0));
		height = 1.0 - clamp(mortar, 0.0, 1.0);
	}
	col *= COLOR.rgb;
	float blot = fbm(p * blot_scale, 3);
	col *= mix(1.0 - vary, 1.0 + vary, smoothstep(0.3, 0.7, blot));
	if (grain == 2) {
		// Holzmaserung: verzogene Bänder
		float bands = 0.5 + 0.5 * sin((p.y * 9.0 + 7.0 * fbm(p * vec3(1.5, 0.4, 1.5), 3)) * 6.2832);
		col *= mix(0.88, 1.0, bands);
		height = bands;
	} else if (grain == 1) {
		height = smoothstep(0.0, 0.12, cell_edge(p * 7.0));
	} else if (grain == 0) {
		height = fbm(p * 60.0, 3);
	} else if (grain == 4) {
		height = fbm(p * 160.0, 2);
	} else if (grain == 5) {
		height = fbm(p * 90.0, 2);
	} else if (grain == 6) {
		height = fbm(p * 25.0, 2);
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
