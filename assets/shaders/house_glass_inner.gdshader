// Raues Glas, nur von einer Seite sichtbar (seit Etappe 4g): innen an Schaufenstern, damit man
// von drinnen nicht scharf auf das Straßenende schaut – von außen bleibt das Glas klar.
// Sonst wie house_glass.gdshader.
shader_type spatial;
render_mode cull_back;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Wie unscharf: Stufe im Bildschirm-Puffer (0 = klar) und Größe der Weichzeichnung
uniform float blur : hint_range(0.0, 6.0) = 2.5;
uniform float spread : hint_range(0.0, 0.03) = 0.008;
// Leicht milchig: so viel helles Grau kommt dazu
uniform vec4 milk : source_color = vec4(0.82, 0.84, 0.84, 1.0);
uniform float milkiness : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	vec2 aspect = vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0);
	vec3 sum = vec3(0.0);
	const int SAMPLES = 12;
	for (int i = 0; i < SAMPLES; i++) {
		float r = sqrt((float(i) + 0.5) / float(SAMPLES)) * spread;
		float a = float(i) * 2.39996;
		sum += textureLod(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * r * aspect, blur).rgb;
	}
	vec3 behind = sum / float(SAMPLES);
	ALBEDO = vec3(0.0);
	EMISSION = mix(behind, milk.rgb * 0.6, milkiness);
	ROUGHNESS = 0.25;
	SPECULAR = 0.4;
}
