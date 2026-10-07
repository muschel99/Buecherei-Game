// Dezente Hervorhebung eines Regalfachs (Regal-Menü): ein unsichtbarer Kasten in der Größe
// des Fachs, der alles darin leicht aufhellt und seine Kanten mit einer feinen, weißen
// Linie nachzeichnet – wie die Hervorhebung im Gestaltungsmodus.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

// Halbe Größe des Kastens (in Metern)
uniform vec3 half_size = vec3(0.5, 0.2, 0.15);
// Aufhellung der Fläche und Helligkeit der Kanten (0 = gar nicht)
uniform float fill = 0.07;
uniform float edge = 0.5;
// Breite der Kantenlinie in Metern
uniform float edge_width = 0.006;
// Zum sanften Ein- und Ausblenden (0 bis 1)
uniform float strength = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Abstand zu den drei Seitenpaaren; auf einer Fläche ist einer davon fast 0,
	// der nächstgrößere ist dann der Abstand zur nächsten Kante
	vec3 d = half_size - abs(local_pos);
	float middle = max(min(d.x, d.y), min(max(d.x, d.y), d.z));
	float line = 1.0 - smoothstep(edge_width * 0.5, edge_width, middle);
	ALBEDO = vec3(1.0) * (fill + line * edge) * strength;
}
