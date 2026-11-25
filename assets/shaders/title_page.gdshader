shader_type spatial;
// Buchseite im Hauptmenü (TitleBook, seit der Testrunde nach Etappe 8d): cremefarbenes Papier mit feiner Körnung und weichem
// Schatten zum Falz hin. Mit picture (rechte Seite) liegt darauf ein Bild wie eine gedruckte Abbildung: leicht entsättigt, mit
// dem Papier multipliziert und mit unregelmäßigem, weich auslaufendem Rand (wie ein Aquarell ohne Rahmen).
// UV: u von links nach rechts über die Seite, v von oben (0) nach unten (1) – aus build_title_book.py.

uniform vec4 paper_color : source_color = vec4(0.97, 0.94, 0.86, 1.0);
uniform vec4 fold_shade : source_color = vec4(0.72, 0.64, 0.55, 1.0);
// wo der Falz liegt: 0 = links (rechte Seite), 1 = rechts (linke Seite)
uniform float fold_at = 0.0;
uniform float fold_width = 0.16;
uniform float grain_strength = 0.05;
uniform bool has_picture = false;
uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_disable;
// Bildfläche auf der Seite (u0, v0, u1, v1) und wie breit der Rand ausläuft (Anteil der Seite)
uniform vec4 picture_rect = vec4(0.1, 0.07, 0.92, 0.88);
uniform float picture_soft = 0.035;
uniform float picture_fade = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	// Papier: feine Körnung und ein paar weiche Flecken
	float grain = value_noise(uv * vec2(420.0, 590.0)) * 0.6 + value_noise(uv * vec2(38.0, 53.0)) * 0.4;
	vec3 color = paper_color.rgb * (1.0 - grain_strength + grain * grain_strength * 2.0 * 0.5);
	if (has_picture) {
		vec2 size = picture_rect.zw - picture_rect.xy;
		vec2 local = (uv - picture_rect.xy) / size;
		// unregelmäßiger Rand: Abstand zum Rechteck, mit Rauschen verwackelt
		float edge = min(min(uv.x - picture_rect.x, picture_rect.z - uv.x), min(uv.y - picture_rect.y, picture_rect.w - uv.y));
		edge += (value_noise(uv * 26.0) - 0.5) * picture_soft * 1.6 + (value_noise(uv * 90.0) - 0.5) * picture_soft * 0.5;
		float mask = smoothstep(-picture_soft * 0.3, picture_fade * 0.25, edge);
		vec3 pic = texture(picture, clamp(local, 0.0, 1.0)).rgb;
		// gedruckt: etwas weniger bunt, mit dem Papier multipliziert, die hellsten Stellen bleiben Papier
		float luma = dot(pic, vec3(0.299, 0.587, 0.114));
		pic = mix(vec3(luma), pic, 0.93);
		vec3 printed = color * pic / max(paper_color.rgb, vec3(0.01));
		color = mix(color, printed, mask);
	}
	// weicher Schatten im Falz
	float to_fold = abs(uv.x - fold_at);
	float shade = 1.0 - smoothstep(0.0, fold_width, to_fold);
	color = mix(color, color * fold_shade.rgb, shade * shade * 0.85);
	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
