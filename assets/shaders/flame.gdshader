// Flamme im Bilderbuch-Stil (seit Etappe 6d): stilisiert, nicht realistisch – heller Kern, warmer oranger Rand
// und Spitze. Bewegt sich wie Feuer: zittert, flackert in der Höhe und wiegt sich sanft hin und her; jede
// Flamme etwas anders (Takt aus ihrer Lage in der Welt). LightSource setzt dieses Material bei jeder Flamme
// (Material „flame“) automatisch ein und lässt das Licht passend mitflackern.
// Der Ursprung des Netzes liegt am Docht bzw. am Fuß der Flamme, +Y nach oben.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.93, 0.68, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.52, 0.16, 1.0);
// Helligkeit (dieselbe Wirkung wie im Bilderbuch-Material; LightSource blendet sie beim An- und Ausmachen)
uniform float emission_energy = 2.7;
// Höhe der Flamme im Modell (m) – dafür biegt sich vor allem die Spitze
uniform float height = 0.05;
// wie weit sich die Spitze zur Seite wiegt (Anteil der Höhe), wie stark die Höhe flackert, wie schnell
uniform float sway = 0.22;
uniform float flicker = 0.14;
uniform float speed = 1.0;

varying float rise;

float wave(float t, float p) {
	return sin(t * 2.1 + p) * 0.5 + sin(t * 4.7 + p * 1.9) * 0.3 + sin(t * 10.3 + p * 3.1) * 0.2;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = fract(sin(dot(origin, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 6.2831;
	float t = TIME * speed * (0.85 + 0.3 * fract(phase * 7.13));
	rise = clamp(VERTEX.y / max(height, 0.001), 0.0, 1.0);
	float stretch = 1.0 + flicker * wave(t * 1.7, phase + 1.3);
	VERTEX.y *= stretch;
	// beim Hochzucken etwas schmaler, beim Zusammensinken etwas breiter
	VERTEX.xz *= 1.0 - (stretch - 1.0) * 0.6 * rise;
	float bend = rise * rise * sway * height;
	VERTEX.x += wave(t, phase) * bend;
	VERTEX.z += wave(t * 0.8, phase + 2.4) * bend * 0.7;
}

void fragment() {
	float edge = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 c = mix(core_color.rgb, edge_color.rgb, clamp(edge * 1.3 + rise * 0.55, 0.0, 1.0));
	ALBEDO = c;
	EMISSION = c * emission_energy;
}
