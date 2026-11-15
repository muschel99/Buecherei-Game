shader_type sky;
// Himmel des Hauptmenüs (TitleBackdrop): weicher Abendhimmel wie gemalt – warmes Pfirsich am Horizont, oben Flieder bis
// Himmelblau, langsam ziehende, weiche Wolken, ein goldener Schein hinter der Baumkrone und um die Sonne. Unter dem Horizont
// ein weiches Wolkenmeer im warmen Dunst (die Rasen-Insel schwebt darüber). Farben und Wolken hier einstellen (oder in scenes/ui/title_backdrop.tscn).

uniform vec3 top_color : source_color = vec3(0.54, 0.63, 0.84);
uniform vec3 high_color : source_color = vec3(0.79, 0.7, 0.88);
uniform vec3 mid_color : source_color = vec3(0.99, 0.76, 0.67);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.86, 0.64);
uniform vec3 haze_color : source_color = vec3(0.97, 0.78, 0.68);
uniform vec3 deep_color : source_color = vec3(0.86, 0.64, 0.66);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.94, 0.86);
uniform vec3 cloud_shade : source_color = vec3(0.94, 0.7, 0.72);
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.75;
uniform float cloud_scale = 0.7;
uniform float cloud_speed = 0.006;
uniform float sun_glow : hint_range(0.0, 2.0) = 0.6;
// Wolkenmeer unter dem Horizont
uniform vec3 sea_color : source_color = vec3(1.0, 0.9, 0.84);
uniform float sea_scale = 1.6;
// goldener Schein hinter der Baumkrone (fest, unabhängig von der Sonne)
uniform vec3 glow_dir = vec3(0.45, 0.32, -1.0);
uniform vec3 glow_color : source_color = vec3(1.0, 0.84, 0.58);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.45;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.16, h));
	col = mix(col, high_color, smoothstep(0.12, 0.42, h));
	col = mix(col, top_color, smoothstep(0.35, 0.85, h));
	col = mix(col, haze_color, smoothstep(0.0, -0.12, h));
	col = mix(col, deep_color, smoothstep(-0.1, -0.55, h));
	// weiche Wolken: Rauschen auf einer gedachten Wolkendecke, zum Horizont hin flacher und dünner
	if (h > -0.02) {
		vec2 uv = d.xz / (h + 0.22) * cloud_scale + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.3);
		float n = fbm(uv);
		float c = smoothstep(0.62 - cloud_amount * 0.25, 0.86, n);
		c *= smoothstep(-0.02, 0.12, h) * (1.0 - smoothstep(0.55, 0.95, h));
		float shade = smoothstep(0.55, 0.9, fbm(uv + vec2(0.35, 0.2)));
		col = mix(col, mix(cloud_color, cloud_shade, shade * 0.7), c * 0.92);
	}
	// weiches Wolkenmeer unter dem Horizont (die Insel schwebt darüber): oben hell und flauschig, nach unten in den Dunst
	if (h < 0.02) {
		vec2 uv = d.xz / (0.18 - h) * sea_scale + vec2(TIME * cloud_speed * 0.5, 0.0);
		float n = fbm(uv);
		float puff = smoothstep(0.4, 0.75, n);
		float band = smoothstep(0.02, -0.03, h) * (1.0 - smoothstep(-0.12, -0.5, h));
		float shade = smoothstep(0.45, 0.85, fbm(uv * 1.7 + vec2(3.0, 1.0)));
		col = mix(col, mix(sea_color, cloud_shade, shade * 0.55), puff * band * 0.85);
	}
	float g = max(dot(d, normalize(glow_dir)), 0.0);
	col += glow_color * (pow(g, 3.0) * 0.35 + pow(g, 14.0) * 0.4) * glow_strength;
	// warmer Schein um die Sonne
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * (pow(s, 6.0) * 0.12 + pow(s, 40.0) * 0.35) * sun_glow;
	}
	COLOR = col;
}
