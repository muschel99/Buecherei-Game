shader_type spatial;
// "Blaupause": die Vorschau beim Platzieren von Büchern und Möbeln (zeigt, wo etwas hinkäme).
// Überall gleich – egal ob Licht oder Schatten darauf fällt:
// - unshaded: Licht und Schatten der Szene zählen gar nicht.
// - Nur leicht durchsichtig (opacity), damit kaum Hell und Dunkel von dahinter durchscheint.
// - Die Form zeigt ein hellerer Rand (je nach Blickwinkel, nicht nach Licht); bei Büchern
//   (box_edges) zusätzlich feine helle Kanten wie auf einer Bauzeichnung.
// - Ein paar Millimeter zur Kamera hin gezeichnet: kein Flackern auf der Fläche darunter.
// tint 0 = passt (valid_color, ruhiges Blau), 1 = gesperrt (invalid_color, rot).
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled, fog_disabled;

uniform vec3 valid_color : source_color = vec3(0.45, 0.65, 0.95);
uniform vec3 invalid_color : source_color = vec3(0.95, 0.4, 0.35);
uniform float tint = 0.0;
uniform float opacity = 0.88;
// Stärke des helleren Rands
uniform float rim = 0.35;
// Feine Kanten für quaderförmige Vorschauen (Bücher: Würfel der Größe 1)
uniform bool box_edges = false;
// So weit (in Metern) wird die Vorschau zur Kamera hin gezeichnet
uniform float lift = 0.003;

varying vec3 local_pos;
varying vec3 local_scale;

void vertex() {
	local_pos = VERTEX;
	local_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz += normalize(-view.xyz) * lift;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	vec3 col = mix(valid_color, invalid_color, clamp(tint, 0.0, 1.0));
	// Hellerer Rand an den Umrissen (Blickwinkel, nicht Licht)
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	col = mix(col, vec3(1.0), (1.0 - facing) * rim);
	if (box_edges) {
		// Abstand zur nächsten Würfelkante in Metern (zwei Achsen nahe am Rand = Kante)
		vec3 d = (0.5 - abs(local_pos)) * local_scale;
		// Eine Kante liegt dort, wo zwei der drei Abstände klein sind (der mittlere zählt)
		float smallest = min(d.x, min(d.y, d.z));
		float middle = d.x + d.y + d.z - smallest - max(d.x, max(d.y, d.z));
		float near_edge = 1.0 - smoothstep(0.0015, 0.004, middle);
		col = mix(col, vec3(1.0), near_edge * 0.55);
	}
	ALBEDO = col;
	ALPHA = opacity;
}
