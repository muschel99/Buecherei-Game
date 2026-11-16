// Fallende Herbstblätter (seit der großen Überarbeitung, AutumnLeaves): Partikel-Shader. Blätter starten zufällig in
// einem Kasten über der Spielfigur (bzw. in einer Baumkrone), sinken langsam, treiben im Wind und flattern hin und her.
// Treffen sie den Boden (Kollision: Höhenfeld nur aus Straße und Gehwegen), bleiben sie liegen – flach, ausgerichtet
// an der Fläche – und verschwinden am Ende ihres Lebens weich (autumn_leaf.gdshader).
// CUSTOM: x = Alter (0–1), y = gelandet, z = Größe, w = Zufall (fürs Schaukeln).
shader_type particles;
render_mode disable_force;

uniform vec3 emission_box = vec3(18.0, 3.0, 18.0);
uniform vec3 wind = vec3(0.55, 0.0, 0.2);
uniform float fall_speed = 0.6;
uniform float flutter = 0.45;
uniform vec2 size_range = vec2(0.075, 0.125);
uniform vec4 color_a : source_color = vec4(0.9, 0.68, 0.2, 1.0);
uniform vec4 color_b : source_color = vec4(0.9, 0.42, 0.12, 1.0);
uniform vec4 color_c : source_color = vec4(0.7, 0.18, 0.1, 1.0);
uniform vec4 color_d : source_color = vec4(0.62, 0.48, 0.24, 1.0);

float rand(inout uint seed) {
	seed = seed * 747796405u + 2891336453u;
	uint w = ((seed >> ((seed >> 28u) + 4u)) ^ seed) * 277803737u;
	return float((w >> 22u) ^ w) / 4294967295.0;
}

mat3 yaw(float a) {
	return mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
}

void start() {
	uint seed = NUMBER * 1973u + RANDOM_SEED * 9277u + INDEX * 26699u;
	float size = mix(size_range.x, size_range.y, rand(seed));
	if (RESTART_POSITION) {
		vec3 p = (vec3(rand(seed), rand(seed), rand(seed)) * 2.0 - 1.0) * emission_box;
		TRANSFORM = EMISSION_TRANSFORM;
		TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(p, 1.0)).xyz;
	}
	if (RESTART_ROT_SCALE) {
		mat3 b = yaw(rand(seed) * 6.2832) * size;
		TRANSFORM[0].xyz = b[0];
		TRANSFORM[1].xyz = b[1];
		TRANSFORM[2].xyz = b[2];
	}
	if (RESTART_VELOCITY) {
		VELOCITY = vec3(0.0, -fall_speed, 0.0);
	}
	if (RESTART_COLOR) {
		float c = rand(seed);
		vec3 col = c < 0.3 ? color_a.rgb : (c < 0.6 ? color_b.rgb : (c < 0.82 ? color_c.rgb : color_d.rgb));
		COLOR = vec4(col * mix(0.82, 1.08, rand(seed)), 1.0);
	}
	if (RESTART_CUSTOM) {
		CUSTOM = vec4(0.0, 0.0, size, rand(seed));
	}
}

void process() {
	CUSTOM.x = clamp(CUSTOM.x + DELTA / max(LIFETIME, 0.01), 0.0, 1.0);
	if (CUSTOM.y > 0.5) {
		// liegt am Boden
		VELOCITY = vec3(0.0);
	} else {
		float t = TIME * (0.9 + CUSTOM.w * 0.8) + CUSTOM.w * 37.0;
		float gust = 0.65 + 0.35 * sin(TIME * 0.31 + CUSTOM.w * 3.0);
		vec3 drift = wind * gust + vec3(sin(t * 1.7), 0.0, cos(t * 1.3)) * flutter;
		VELOCITY = vec3(drift.x, -fall_speed * (0.75 + 0.35 * sin(t * 2.3)), drift.z);
		if (COLLIDED) {
			// gelandet: flach auf die Fläche legen (ausgerichtet an der Normalen), Drehung behalten
			CUSTOM.y = 1.0;
			VELOCITY = vec3(0.0);
			TRANSFORM[3].xyz += COLLISION_NORMAL * (COLLISION_DEPTH + 0.004);
			vec3 up = normalize(COLLISION_NORMAL);
			vec3 fwd = normalize(TRANSFORM[2].xyz - up * dot(TRANSFORM[2].xyz, up));
			vec3 right = cross(up, fwd);
			float s = CUSTOM.z;
			TRANSFORM[0].xyz = right * s;
			TRANSFORM[1].xyz = up * s;
			TRANSFORM[2].xyz = fwd * s;
		}
	}
}
