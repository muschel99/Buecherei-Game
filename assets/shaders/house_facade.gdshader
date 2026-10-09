// Farben der Platzhalter-Häuser (seit Etappe 4e).
// Alle Häuser eines Typs teilen sich EIN Mesh und dieses EINE Material – so kann Godot
// gleiche Häuser günstig mehrfach zeichnen. Die Farben jedes einzelnen Hauses kommen als
// "Instanz-Werte" (instance uniform) vom Haus selbst (HouseFacade: wall_color, door_color,
// accent_color).
// Im Mesh sagt der Alpha-Wert der Vertex-Farbe, welche Farbe ein Teil bekommt:
//   1.0  = feste Farbe (rgb so, wie sie im Mesh steht: Fensterrahmen, Glas, Dach …)
//   0.75 = Wandfarbe des Hauses  (rgb = Helligkeit, z. B. etwas dunkler für den Schornstein)
//   0.5  = Türfarbe des Hauses
//   0.25 = Akzentfarbe (Schild über der Ladenfront, Markise)
shader_type spatial;
render_mode cull_back;

instance uniform vec4 wall_color : source_color = vec4(0.55, 0.3, 0.24, 1.0);
instance uniform vec4 door_color : source_color = vec4(0.18, 0.28, 0.42, 1.0);
instance uniform vec4 accent_color : source_color = vec4(0.16, 0.3, 0.22, 1.0);

varying vec3 base_color;

void vertex() {
	vec3 shade = COLOR.rgb;
	float id = COLOR.a;
	if (id > 0.9) {
		base_color = shade;
	} else if (id > 0.6) {
		base_color = wall_color.rgb * shade;
	} else if (id > 0.4) {
		base_color = door_color.rgb * shade;
	} else {
		base_color = accent_color.rgb * shade;
	}
}

void fragment() {
	ALBEDO = base_color;
	ROUGHNESS = 0.92;
}
