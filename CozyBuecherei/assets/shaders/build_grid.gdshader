// Rasterlinien auf dem Boden im Gestaltungsmodus.
// Die Linien sind nur rund um die Möbel-Vorschau zu sehen und blenden nach außen weich aus.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float cell_size = 0.25;
uniform vec4 line_color : source_color = vec4(1.0, 0.95, 0.82, 0.45);
uniform float line_width = 0.012;
// Mittelpunkt und Radius des sichtbaren Bereichs (setzt der Gestaltungsmodus)
uniform vec3 focus_point = vec3(0.0);
uniform float focus_radius = 1.8;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = world_pos.xz / cell_size;
	vec2 distance_to_line = abs(fract(cell - 0.5) - 0.5) * cell_size;
	float line = 1.0 - smoothstep(line_width * 0.5, line_width, min(distance_to_line.x, distance_to_line.y));
	float fade = 1.0 - smoothstep(focus_radius * 0.35, focus_radius, distance(world_pos.xz, focus_point.xz));
	ALBEDO = line_color.rgb;
	ALPHA = line * line_color.a * fade;
}
