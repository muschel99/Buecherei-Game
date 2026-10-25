// Gezeichnetes Gesicht der Chibi-Figuren (seit Etappe 5c). Die Texturkoordinaten sind eine
// Abwicklung des Kopfes: fx = quer (m), fz = Höhe über dem Kinn (m). Augen, Iris, Augenbrauen
// und Mund kommen aus Bilder-Atlanten (je Feld ein Ausdruck, gezeichnet von
// tools/blender/chibi_face.py – die Maße hier müssen dazu passen). Gesteuert wird alles über
// Instanz-Werte, die das Script ChibiCharacter setzt (animierbar).
shader_type spatial;

// --- Lage im Gesicht (m), wie chibi_face.py ---
const float FACE_SIZE = 0.48;
const vec2 EYE = vec2(0.103, 0.170);
const float EYE_CELL = 0.085;
const float EYE_CELL_PX = 192.0;
const float IRIS_CELL = 0.05;
const float EYE_SCALE = 2.30;
const vec2 BROW = vec2(0.101, 0.264);
const vec2 BROW_CELL = vec2(0.07, 0.035);
const float BROW_SCALE = 1.5;
const float MOUTH_Z = 0.068;
const float MOUTH_CELL = 0.06;
const float MOUTH_SCALE = 2.6;
const vec2 BLUSH = vec2(0.127, 0.103);
const vec2 BLUSH_R = vec2(0.034, 0.019);
// Iris je Augen-Satz (Größe, Höhe): Frau süß/elegant/lebhaft, Mann sanft/cool/fröhlich
const vec2 SET_IRIS[6] = vec2[6](vec2(1.20, -0.003), vec2(1.05, -0.002), vec2(1.17, -0.001),
		vec2(1.06, -0.002), vec2(0.96, -0.004), vec2(1.10, -0.002));

uniform sampler2D eye_lines : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D eye_masks : filter_linear_mipmap, repeat_disable;
uniform sampler2D iris_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D brow_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D mouth_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 line_color : source_color = vec3(0.16, 0.10, 0.10);

// Instanz-Werte mit festen Nummern – 0 und 1 wie in chibi_skin.gdshader
instance uniform vec4 base_color : source_color, instance_index(0) = vec4(0.95, 0.80, 0.68, 1.0);
instance uniform vec4 iris_color : source_color, instance_index(2) = vec4(0.42, 0.28, 0.20, 1.0);
instance uniform vec4 brow_color : source_color, instance_index(3) = vec4(0.30, 0.22, 0.18, 1.0);
instance uniform int eye_set : instance_index(4) = 0;       // Geschlecht * 3 + Augenform (0..5)
instance uniform int eye_frame : instance_index(5) = 0;     // linkes Auge der Figur (EYE_FRAMES, 0..11)
instance uniform int eye_frame_r : instance_index(6) = 0;   // rechtes Auge (zum Zwinkern verschieden)
instance uniform int iris_frame : instance_index(7) = 0;    // 0..5 (Männer: eigene Zeilen mit dezentem Glanz)
instance uniform int brow_frame : instance_index(8) = 0;    // 0..7
instance uniform int mouth_frame : instance_index(9) = 0;   // 0..19
instance uniform vec2 look : instance_index(10) = vec2(0.0); // Blickrichtung (-1..1)
instance uniform float iris_scale : instance_index(11) = 1.0;
instance uniform float blush : instance_index(12) = 0.55;
instance uniform float blush_lines : instance_index(13) = 0.0; // Rotstriche auf den Wangen ("///")

// Feld index eines Atlas mit grid Spalten/Zeilen; local in Metern (Mitte = 0). Die Mipmap-Stufe
// wird vorher aus dem Bildschirmmaßstab berechnet (Godots eigene Wahl rauschte an den Feldern).
vec4 cell(sampler2D tex, vec2 local, vec2 cell_size, vec2 grid, float index, float lod) {
	vec2 uv = vec2(local.x / cell_size.x + 0.5, 0.5 - local.y / cell_size.y);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float col = mod(index, grid.x);
	float row = floor(index / grid.x);
	vec2 a = (vec2(col, row) + clamp(uv, vec2(0.004), vec2(0.996))) / grid;
	return textureLod(tex, a, lod) * inside;
}

void fragment() {
	vec2 f = vec2((UV.x - 0.5) * FACE_SIZE, (1.0 - UV.y) * FACE_SIZE);
	// Meter je Bildpunkt auf dem Bildschirm -> Mipmap-Stufe je Atlas (Bildpunkte je Meter im Atlas)
	float m_px = max(length(dFdx(f)), length(dFdy(f)));
	vec2 iris_set = SET_IRIS[clamp(eye_set, 0, 5)];
	float lod_eye = max(log2(m_px * EYE_CELL_PX / (EYE_CELL * EYE_SCALE)), 0.0);
	float lod_iris = max(log2(m_px * 256.0 / (IRIS_CELL * EYE_SCALE * iris_scale * iris_set.x)), 0.0);
	float lod_brow = max(log2(m_px * 256.0 / (BROW_CELL.x * BROW_SCALE)), 0.0);
	float lod_mouth = max(log2(m_px * 256.0 / (MOUTH_CELL * MOUTH_SCALE)), 0.0);
	vec3 col = base_color.rgb;
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? 1.0 : -1.0;
		vec2 b = (f - vec2(s * BLUSH.x, BLUSH.y)) / BLUSH_R;
		float a = pow(clamp(1.0 - dot(b, b), 0.0, 1.0), 1.2) * 0.75 * blush;
		col = mix(col, vec3(0.93, 0.21, 0.24), a);
		// drei kurze schräge Striche
		float st = abs(fract((b.x * s * 0.9 + b.y * 1.6) * 1.5 + 0.5) - 0.5);
		float la = step(st, 0.11) * step(abs(b.x), 0.62) * step(abs(b.y), 0.55) * 0.75 * blush_lines;
		col = mix(col, vec3(0.70, 0.11, 0.12), la);
	}
	int gender = eye_set / 3;
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? 1.0 : -1.0;
		float eye_index = float(eye_set * 12 + (i == 0 ? eye_frame : eye_frame_r));
		// Linien gespiegelt (außen = außen), Iris nicht (Glanzlicht auf derselben Seite)
		vec2 l = vec2((f.x - s * EYE.x) * s, f.y - EYE.y) / EYE_SCALE;
		vec4 lines = cell(eye_lines, l, vec2(EYE_CELL), vec2(12.0, 6.0), eye_index, lod_eye);
		vec4 mask = cell(eye_masks, l, vec2(EYE_CELL), vec2(12.0, 6.0), eye_index, lod_eye);
		col = mix(col, vec3(0.98, 0.96, 0.94), mask.r);
		float sc = iris_scale * iris_set.x;
		vec2 il = ((vec2(f.x - s * EYE.x, f.y - EYE.y) / EYE_SCALE) - vec2(look.x * 0.006, iris_set.y + look.y * 0.004)) / sc;
		vec4 ir = cell(iris_tex, il, vec2(IRIS_CELL), vec2(3.0, 4.0), float(gender * 6 + iris_frame), lod_iris);
		vec3 base = iris_color.rgb;
		vec3 icol = mix(base * 0.08, base * 1.3, ir.r);
		icol = mix(icol, line_color, ir.b * 0.85);
		icol = mix(icol, vec3(1.0), ir.g);
		col = mix(col, icol, ir.a * mask.r);
		col *= 1.0 - mask.g * 0.5 * (1.0 - vec3(0.48, 0.45, 0.62));
		col = mix(col, lines.rgb, lines.a);
		vec2 bl = vec2((f.x - s * BROW.x) * s, f.y - BROW.y) / BROW_SCALE;
		vec4 br = cell(brow_tex, bl, BROW_CELL, vec2(4.0, 4.0), float(gender * 8 + brow_frame), lod_brow);
		col = mix(col, brow_color.rgb, br.a);
	}
	vec4 m = cell(mouth_tex, vec2(f.x, f.y - MOUTH_Z) / MOUTH_SCALE, vec2(MOUTH_CELL), vec2(5.0, 4.0), float(mouth_frame), lod_mouth);
	col = mix(col, m.rgb, m.a);
	ALBEDO = col * mix(1.0, UV2.x, ao_strength);
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
}
