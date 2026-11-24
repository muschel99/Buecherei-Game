shader_type spatial;
// Bachwasser im Garten (seit der Testrunde nach Etappe 8d): kleine Wellen, die in Fließrichtung wandern, glänzend, mit dem Himmel
// darin. Wellen als Höhenfeld aus zwei Rausch-Schichten, die Neigung wird aus Nachbarwerten des Rauschens gerechnet (nicht über
// Bildschirm-Ableitungen – die gäben Treppchen); in der Ferne werden die Wellen ruhiger (kein Flimmern).

uniform vec4 deep_color : source_color = vec4(0.17, 0.29, 0.3, 1.0);
uniform vec4 light_color : source_color = vec4(0.36, 0.5, 0.47, 1.0);
// Fließrichtung (x/z in der Welt) und Geschwindigkeit (m/s)
uniform vec2 flow = vec2(-0.8, 0.6);
uniform float speed = 0.35;
uniform float ripple_scale = 2.2;
uniform float ripple_strength = 0.55;
uniform float fade_distance = 18.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.05;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float waves(vec2 p, float t) {
	vec2 dir = normalize(flow);
	float a = value_noise(p * ripple_scale - dir * t * speed * ripple_scale);
	float b = value_noise(p * ripple_scale * 2.3 + vec2(dir.y, -dir.x) * t * 0.12 - dir * t * speed * 1.6 * ripple_scale);
	return a * 0.65 + b * 0.35;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME;
	float e = 0.04;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	float dist = length(CAMERA_POSITION_WORLD - world_pos);
	float strength = ripple_strength * (1.0 - smoothstep(fade_distance * 0.4, fade_distance, dist));
	vec3 n = normalize(vec3(-(hx - h) / e * strength * 0.1, 1.0, -(hz - h) / e * strength * 0.1));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = mix(deep_color.rgb, light_color.rgb, smoothstep(0.35, 0.8, h));
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
