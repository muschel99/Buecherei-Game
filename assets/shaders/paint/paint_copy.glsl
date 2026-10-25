#[compute]
#version 450

// Malfilter, Schritt 1: das fertige Bild in eine Arbeitskopie schreiben (Schritt 2 liest daraus die
// Nachbarpunkte, während er das Bild neu malt). Gestartet von scripts/rendering/paint_filter_effect.gd.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D color_image;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D copy_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	if (uv.x >= int(params.raster_size.x) || uv.y >= int(params.raster_size.y)) {
		return;
	}
	imageStore(copy_image, uv, imageLoad(color_image, uv));
}
