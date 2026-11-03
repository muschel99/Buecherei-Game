// Bilderbuch-Stil für die Katze (seit Etappe 6h, Form nach den Vorlagen der Entwicklerin): wie
// storybook_animal.gdshader (Muster aus der Ruhehaltung), dazu GEMALT wie bei den Chibi-Passanten: große Augen mit
// Glanzpunkten (blinzeln/zufrieden über eye_blink/eye_happy), Mund („w“), Wangenröte und Tigerstreifen an Stirn,
// Wangen, Rücken, Beinen und Schwanz. Lage vom Bau-Script (tools/blender/animal_cat.py, face_params).
shader_type spatial;
render_mode cull_back;

#define REST_POSITION
#define CAT_FACE
#include "res://assets/shaders/storybook.gdshaderinc"
