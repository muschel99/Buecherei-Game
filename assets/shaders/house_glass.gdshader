// Fensterglas der Stil-Häuser (seit Etappe 4g): leicht verschwommen, wie altes Glas.
// Statt einfach durchsichtig zu sein, zeichnet das Glas das Bild dahinter weichgezeichnet
// (aus dem Bildschirm-Puffer, je größer "blur", desto verschwommener) und ein wenig gewellt.
// Darüber spiegelt es den Himmel wie echtes Glas.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Wie verschwommen (Stufe im Bildschirm-Puffer, 0 = klar)
uniform float blur : hint_range(0.0, 6.0) = 2.2;
// Leichte Wellen im Glas (Stärke) und ein Hauch Farbe
uniform float wobble : hint_range(0.0, 0.02) = 0.004;
uniform vec4 tint : source_color = vec4(0.84, 0.88, 0.9, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 wave = vec2(sin(UV.y * 31.0 + UV.x * 5.0), cos(UV.x * 27.0 + UV.y * 3.0)) * wobble;
	vec3 behind = textureLod(screen_tex, SCREEN_UV + wave, blur).rgb;
	ALBEDO = vec3(0.0);
	EMISSION = mix(behind, behind * tint.rgb, tint_strength);
	ROUGHNESS = 0.06;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
