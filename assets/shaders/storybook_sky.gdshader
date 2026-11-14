// Himmel im Bilderbuch-Stil (seit Etappe 7): Farbverlauf, weiche Sonnenscheibe, Mond mit sanftem Schein, Sterne und gemalte
// Wolken, die langsam ziehen. Alle Farben und Lagen setzt DayCycle (scripts/world/day_cycle.gd) je nach Uhrzeit.
// Später (Wetter): cloud_cover = Bedeckung 0–1, cloud_darkness = Regenwolken.
shader_type sky;
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.30, 0.52, 0.84);
uniform vec3 horizon_color : source_color = vec3(0.96, 0.84, 0.68);
uniform vec3 ground_color : source_color = vec3(0.32, 0.29, 0.26);
uniform float curve = 0.12;
// Sonne: Richtung zur Sonne (Welt), Farbe, Größe der Scheibe (Kosinus), Schein drumherum
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_visible = 1.0;
uniform float sun_size = 0.9994;
uniform float sun_glow = 0.35;
// Mond
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float moon_visible = 0.0;
uniform float moon_size = 0.99955;
uniform vec3 moon_color : source_color = vec3(0.95, 0.94, 0.86);
// Sterne (0 = keine)
uniform float stars = 0.0;
// Sterne warm und gedämpft (seit Testrunde 7b), Sternschnuppen: alle shooting_period Sekunden mit shooting_chance eine
uniform vec3 star_color : source_color = vec3(1.0, 0.86, 0.66);
uniform float star_brightness = 0.6;
uniform float shooting_period = 23.0;
uniform float shooting_chance = 0.35;
// Wolken: Bedeckung, Versatz (wandert mit dem Wind), Farbe von unten/oben, Schatten, wie stark Sonne/Mond sie anstrahlen
uniform float cloud_cover = 0.42;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 cloud_shade : source_color = vec3(0.70, 0.74, 0.84);
uniform float cloud_darkness = 0.0;
uniform float cloud_opacity = 0.92;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise2(p);
		p = p * 2.03 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	// Farbverlauf: Horizont → oben; unter dem Horizont zum Boden
	vec3 col;
	if (up >= 0.0) {
		float t = pow(clamp(up, 0.0, 1.0), curve * 3.0);
		col = mix(horizon_color, top_color, smoothstep(0.0, 1.0, t));
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.25, -up));
	}
	// Schein um die Sonne (auch durch die Wolken leicht sichtbar)
	float sun_cos = dot(dir, normalize(sun_dir));
	float glow = pow(max(sun_cos, 0.0), 8.0) * sun_glow + pow(max(sun_cos, 0.0), 64.0) * sun_glow;
	col += sun_color * glow * sun_visible;
	if (!AT_CUBEMAP_PASS && up > -0.02) {
		// Sterne: feste Punkte auf der Himmelskugel, leicht funkelnd
		if (stars > 0.0) {
			vec3 p = dir * 180.0;
			vec3 cell = floor(p);
			float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
			if (h > 0.985) {
				vec3 center = cell + 0.5 + (vec3(fract(h * 13.1), fract(h * 71.7), fract(h * 37.3)) - 0.5) * 0.6;
				float d = length(p - center);
				float twinkle = 0.75 + 0.25 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
				float star = smoothstep(0.35, 0.0, d) * twinkle * (0.5 + 0.5 * fract(h * 97.0));
				col += star_color * star * stars * star_brightness * smoothstep(-0.02, 0.15, up);
			}
			// Sternschnuppe: ein kurzer Strich, der schräg nach unten zieht (ab und zu, nur bei klarer Nacht)
			float slot = floor(TIME / shooting_period);
			if (stars > 0.3 && hash2(vec2(slot, 7.3)) < shooting_chance) {
				float t = (TIME - slot * shooting_period) / 0.9;
				if (t < 1.0) {
					float az = hash2(vec2(slot, 1.7)) * 6.2832;
					float el = mix(0.5, 1.05, hash2(vec2(slot, 3.1)));
					vec3 a = vec3(cos(el) * cos(az), sin(el), cos(el) * sin(az));
					vec3 east = normalize(cross(vec3(0.0, 1.0, 0.0), a));
					float side = hash2(vec2(slot, 5.9)) < 0.5 ? -1.0 : 1.0;
					vec3 b = normalize(a + east * side * 0.32 - vec3(0.0, 0.16, 0.0));
					vec3 head = normalize(mix(a, b, t));
					vec3 tail = normalize(mix(a, b, max(t - 0.3, 0.0)));
					vec3 seg = head - tail;
					float k = clamp(dot(dir - tail, seg) / max(dot(seg, seg), 1e-6), 0.0, 1.0);
					float d = length(dir - (tail + seg * k));
					float streak = smoothstep(0.0022, 0.0, d) * k * sin(3.14159 * t);
					col += star_color * 1.6 * streak * stars;
				}
			}
		}
		// Sonnenscheibe (weich)
		float disc = smoothstep(sun_size - 0.00025, sun_size + 0.00015, sun_cos);
		col = mix(col, sun_color * 1.6, disc * sun_visible);
		// Mond: Scheibe mit sanftem Schein und ein paar weichen Flecken
		vec3 md = normalize(moon_dir);
		float moon_cos = dot(dir, md);
		col += moon_color * pow(max(moon_cos, 0.0), 300.0) * 0.25 * moon_visible;
		float mdisc = smoothstep(moon_size - 0.00012, moon_size + 0.00008, moon_cos);
		if (mdisc > 0.0) {
			vec3 side = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
			vec3 upv = cross(side, md);
			vec2 mp = vec2(dot(dir, side), dot(dir, upv)) * 1800.0;
			float spots = noise2(mp * 0.12 + 3.0) * 0.6 + noise2(mp * 0.3) * 0.4;
			col = mix(col, moon_color * (0.85 + 0.25 * smoothstep(0.35, 0.75, spots)) * 1.3, mdisc * moon_visible);
		}
	}
	// Gemalte Wolken: auf eine Ebene über der Stadt projiziert, weiche Ränder, unten etwas dunkler
	if (up > 0.0 && cloud_cover > 0.0) {
		vec2 plane = dir.xz / (up + 0.12) * 1.6 + cloud_offset;
		float shape = fbm2(plane * 0.55);
		float detail = AT_CUBEMAP_PASS ? 0.5 : fbm2(plane * 1.9 + 4.0);
		float density = shape * 0.8 + detail * 0.2;
		float edge = 1.0 - cloud_cover;
		float c = smoothstep(edge, edge + 0.16, density);
		// Licht von der Sonnenseite: oben/zur Sonne hin heller
		float lit = clamp(0.55 + 0.45 * (density - edge) * 4.0, 0.0, 1.0);
		vec3 ccol = mix(cloud_shade, cloud_lit, lit);
		ccol = mix(ccol, cloud_shade * 0.55, cloud_darkness);
		// am Horizont ausblenden (sonst Streifen)
		c *= smoothstep(0.0, 0.18, up) * cloud_opacity;
		col = mix(col, ccol, c);
	}
	COLOR = col;
}
