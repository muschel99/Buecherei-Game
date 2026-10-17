// Gezeichnetes Gesicht der Chibi-Figuren (seit Etappe 5c). Die Texturkoordinaten sind eine
// Abwicklung des Kopfes: fx = quer (m), fz = Höhe über dem Kinn (m). Augen, Iris, Augenbrauen
// und Mund kommen aus Bilder-Atlanten (je Feld ein Ausdruck, gezeichnet von
// tools/blender/chibi_face.py – die Maße hier müssen dazu passen). Gesteuert wird alles über
// Instanz-Werte, die das Script ChibiCharacter setzt (animierbar).
shader_type spatial;

// --- Lage im Gesicht (m), wie chibi_face.py ---
const float FACE_SIZE = 0.48;
const vec2 EYE = vec2(0.078, 0.160);
const float EYE_CELL = 0.085;
const float IRIS_CELL = 0.05;
const float EYE_SCALE = 1.62;
const vec2 BROW = vec2(0.080, 0.246);
const vec2 BROW_CELL = vec2(0.07, 0.035);
const float BROW_SCALE = 1.35;
const float MOUTH_Z = 0.081;
const float MOUTH_CELL = 0.06;
const float MOUTH_SCALE = 1.45;
const vec2 BLUSH = vec2(0.122, 0.112);
const vec2 BLUSH_R = vec2(0.030, 0.016);

uniform sampler2D eye_lines : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D eye_masks : filter_linear_mipmap, repeat_disable;
uniform sampler2D iris_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D brow_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D mouth_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 line_color : source_color = vec3(0.23, 0.14, 0.13);

instance uniform vec4 base_color : source_color = vec4(0.95, 0.80, 0.68, 1.0);
instance uniform vec4 iris_color : source_color = vec4(0.42, 0.28, 0.20, 1.0);
instance uniform vec4 brow_color : source_color = vec4(0.30, 0.22, 0.18, 1.0);
instance uniform int eye_frame = 0;      // 0..7 (Reihenfolge: EYE_FRAMES)
instance uniform int eye_set = 0;        // 0 = mit Schmuckwimpern (Frauen), 1 = ohne
instance uniform int iris_frame = 0;     // 0..3
instance uniform int brow_frame = 0;     // 0..7
instance uniform int mouth_frame = 0;    // 0..15
instance uniform vec2 look = vec2(0.0);  // Blickrichtung (-1..1)
instance uniform float iris_scale = 1.0;
instance uniform float blush = 0.4;

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
	float lod_eye = max(log2(m_px * 256.0 / (EYE_CELL * EYE_SCALE)), 0.0);
	float lod_iris = max(log2(m_px * 256.0 / (IRIS_CELL * EYE_SCALE * iris_scale)), 0.0);
	float lod_brow = max(log2(m_px * 256.0 / (BROW_CELL.x * BROW_SCALE)), 0.0);
	float lod_mouth = max(log2(m_px * 256.0 / (MOUTH_CELL * MOUTH_SCALE)), 0.0);
	vec3 col = base_color.rgb;
	// Wangenröte
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? 1.0 : -1.0;
		vec2 d = (f - vec2(s * BLUSH.x, BLUSH.y)) / BLUSH_R;
		float a = pow(clamp(1.0 - dot(d, d), 0.0, 1.0), 1.5) * 0.55 * blush;
		col = mix(col, vec3(0.96, 0.31, 0.31), a);
	}
	float eye_index = float(eye_set * 8 + eye_frame);
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? 1.0 : -1.0;
		// Linien gespiegelt (außen = außen), Iris nicht (Glanzlicht auf derselben Seite)
		vec2 l = vec2((f.x - s * EYE.x) * s, f.y - EYE.y) / EYE_SCALE;
		vec4 lines = cell(eye_lines, l, vec2(EYE_CELL), vec2(4.0), eye_index, lod_eye);
		vec4 mask = cell(eye_masks, l, vec2(EYE_CELL), vec2(4.0), eye_index, lod_eye);
		col = mix(col, vec3(0.98, 0.96, 0.94), mask.r);
		vec2 il = ((vec2(f.x - s * EYE.x, f.y - EYE.y) / EYE_SCALE) - vec2(look.x * 0.006, 0.0015 + look.y * 0.004)) / iris_scale;
		vec4 ir = cell(iris_tex, il, vec2(IRIS_CELL), vec2(2.0), float(iris_frame), lod_iris);
		vec3 base = iris_color.rgb;
		vec3 icol = mix(base * 0.18, base * 1.25, ir.r);
		icol = mix(icol, line_color, ir.b * 0.8);
		icol = mix(icol, vec3(1.0), ir.g);
		col = mix(col, icol, ir.a * mask.r);
		col *= 1.0 - mask.g * 0.45 * (1.0 - vec3(0.58, 0.55, 0.70));
		col = mix(col, lines.rgb, lines.a);
		vec2 bl = vec2((f.x - s * BROW.x) * s, f.y - BROW.y) / BROW_SCALE;
		vec4 br = cell(brow_tex, bl, BROW_CELL, vec2(4.0, 2.0), float(brow_frame), lod_brow);
		col = mix(col, brow_color.rgb, br.a);
	}
	vec4 m = cell(mouth_tex, vec2(f.x, f.y - MOUTH_Z) / MOUTH_SCALE, vec2(MOUTH_CELL), vec2(4.0), float(mouth_frame), lod_mouth);
	col = mix(col, m.rgb, m.a);
	ALBEDO = col * mix(1.0, UV2.x, ao_strength);
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
}
