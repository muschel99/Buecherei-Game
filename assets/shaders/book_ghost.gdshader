shader_type spatial;
// Halbdurchsichtige Vorschau eines Buchs (Regal und frei abgelegt – zeigt, wo das Buch hinkäme).
// Wie book_spine.gdshader: ein Würfel der Größe 1, +Z = Buchrücken (Bild aus dem Atlas).
// Passt das Buch dort nicht hin, wird die Vorschau dezent rötlich eingefärbt (tint).
// Ruhig und gleichmäßig auf jeder Oberfläche:
// - unshaded: kein Licht und keine Schatten der Szene (sonst halb hell, halb dunkel oder
//   gestreift); eine eigene, sanfte Schattierung (oben hell, Seiten etwas dunkler) gibt Form.
// - Die Vorschau wird ein paar Millimeter zur Kamera hin gezeichnet, damit sie nie genau in
//   derselben Ebene liegt wie die Fläche darunter (sonst flackert sie: Z-Fighting).
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D spine_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 spine_rect = vec4(0.0);
uniform vec3 base_color : source_color = vec3(0.5, 0.4, 0.3);
uniform vec3 page_color : source_color = vec3(0.9, 0.86, 0.76);
// Färbung, wenn das Buch nicht passt (Farbe und Stärke 0 bis 1)
uniform vec3 tint_color : source_color = vec3(0.86, 0.4, 0.36);
uniform float tint = 0.0;
uniform float opacity = 0.6;
// So weit (in Metern) wird die Vorschau zur Kamera hin gezeichnet
uniform float lift = 0.003;

varying vec3 local_pos;
varying float shade;

void vertex() {
	local_pos = VERTEX;
	// Sanfte, feste Schattierung nach der Richtung der Fläche in der Welt (oben = hell)
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	shade = 0.78 + 0.22 * (world_normal.y * 0.5 + 0.5);
	// Ein paar Millimeter zur Kamera hin
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz += normalize(-view.xyz) * lift;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	vec3 col = base_color;
	if (local_pos.z > 0.499 && spine_rect.z > 0.0) {
		vec2 face_uv = vec2(local_pos.x + 0.5, 0.5 - local_pos.y);
		col = texture(spine_atlas, spine_rect.xy + clamp(face_uv, 0.002, 0.998) * spine_rect.zw).rgb;
	} else if (abs(local_pos.y) > 0.499 || local_pos.z < -0.499) {
		col = page_color * 0.94;
	}
	col = mix(col, tint_color, tint * 0.6);
	ALBEDO = col * shade * 0.9;
	ALPHA = opacity;
}
