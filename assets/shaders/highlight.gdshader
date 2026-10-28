// Dezente Hervorhebung: hellt ein Objekt leicht auf und betont seine Ränder mit
// einem feinen, weißen Schimmer. Wird als zusätzliche Schicht über das Objekt gelegt,
// das Objekt selbst bleibt gut sichtbar.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

// Wie stark das ganze Objekt aufgehellt wird (0 = gar nicht)
uniform float brightness = 0.06;
// Wie hell der Rand schimmert (0 = kein Rand)
uniform float rim_strength = 0.45;
// Wie schmal der Rand ist (größer = schmaler)
uniform float rim_sharpness = 3.0;
// Farbe des Schimmers (Weiß; im Gestaltungsmodus warm)
uniform vec3 tint = vec3(1.0);
// Die Schicht liegt ein winziges Stück außen auf dem Objekt (Meter) – genau auf der Oberfläche
// würden sich beide Schichten an manchen Bildpunkten abwechseln (Sprenkel)
uniform float inflate = 0.0015;

void vertex() {
	VERTEX += NORMAL * inflate;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_sharpness);
	ALBEDO = tint * (brightness + rim * rim_strength);
}
