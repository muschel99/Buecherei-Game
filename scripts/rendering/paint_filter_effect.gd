@tool
class_name PaintFilterEffect
extends CompositorEffect
## Malfilter „Aquarell“ (Gezeichnet-Look, Wunsch der Entwicklerin): malt das fertige 3D-Bild neu – weiche
## Pinselflächen, dunklere Farbränder, feine Tuschelinien, Papierstruktur, warme Farbstimmung.
##
## Läuft nach allen festen und durchsichtigen Dingen (Glas, Bauvorschau …), vor Belichtung und Leuchten;
## die Oberfläche (HUD, Menüs) bleibt scharf. Zwei Rechenschritte auf der Grafikkarte:
## assets/shaders/paint/paint_copy.glsl (Arbeitskopie) und paint_filter.glsl (das eigentliche Malen).
## Ein- und ausschalten: Einstellung „Malstil“ (main.gd setzt enabled); Werte: GameConfig, Abschnitt
## „Malfilter“. Ohne Grafikkarten-Zugriff (z. B. headless) tut der Filter nichts.

const COPY_SHADER := preload("res://assets/shaders/paint/paint_copy.glsl")
const PAINT_SHADER := preload("res://assets/shaders/paint/paint_filter.glsl")
const CONTEXT := &"paint_filter"
const SOURCE := &"source"

## Pinselgröße in Bildpunkten (bei 1080 Bildzeilen, wächst mit der Auflösung); 0 = keine Pinselflächen.
@export var brush_radius := 0.0
@export var line_strength := 0.55
@export var line_width := 1.0
@export var line_color := Color(0.4, 0.24, 0.13)
@export var line_darkness := 0.3
@export var line_pressure := 0.15
@export var line_fade_distance := 24.0
@export var paper_strength := 0.5
@export var edge_darkening := 0.35
@export var wobble := 1.2
@export var warmth := 0.5
@export var saturation := 0.92
@export var wash := 0.3

var _rd: RenderingDevice
var _copy_shader := RID()
var _copy_pipeline := RID()
var _paint_shader := RID()
var _paint_pipeline := RID()
var _linear_sampler := RID()
var _nearest_sampler := RID()


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	needs_normal_roughness = true
	RenderingServer.call_on_render_thread(_initialize)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		# Shader zuerst: die Pipelines gehören zu ihnen und werden mit ihnen freigegeben
		for rid: RID in [_copy_shader, _paint_shader, _linear_sampler, _nearest_sampler]:
			if rid.is_valid():
				_rd.free_rid(rid)


## Übernimmt die Werte aus GameConfig und der Grafikstufe (Hauptthread; das Malen liest sie im Render-Thread).
func apply_config(preset: Dictionary) -> void:
	brush_radius = float(preset.get("paint_radius", GameConfig.paint_brush_radius))
	line_strength = GameConfig.paint_line_strength
	line_width = GameConfig.paint_line_width
	line_color = GameConfig.paint_line_color
	line_darkness = GameConfig.paint_line_darkness
	line_pressure = GameConfig.paint_line_pressure
	line_fade_distance = GameConfig.paint_line_fade_distance
	paper_strength = GameConfig.paint_paper_strength
	edge_darkening = GameConfig.paint_edge_darkening
	wobble = GameConfig.paint_wobble
	warmth = GameConfig.paint_warmth
	saturation = GameConfig.paint_saturation
	wash = GameConfig.paint_wash


func _initialize() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	_copy_shader = _rd.shader_create_from_spirv(COPY_SHADER.get_spirv())
	_copy_pipeline = _rd.compute_pipeline_create(_copy_shader)
	_paint_shader = _rd.shader_create_from_spirv(PAINT_SHADER.get_spirv())
	_paint_pipeline = _rd.compute_pipeline_create(_paint_shader)
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_linear_sampler = _rd.sampler_create(state)
	state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_nearest_sampler = _rd.sampler_create(state)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if _rd == null or not _paint_pipeline.is_valid() or callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene_data := render_data.get_render_scene_data()
	if buffers == null or scene_data == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0 or not buffers.has_texture(&"forward_clustered", &"normal_roughness"):
		return
	# Arbeitskopie in derselben Größe wie das Bild (bei neuer Größe neu anlegen)
	if buffers.has_texture(CONTEXT, SOURCE):
		var format := _rd.texture_get_format(buffers.get_texture(CONTEXT, SOURCE))
		if format.width != size.x or format.height != size.y:
			buffers.clear_context(CONTEXT)
	if not buffers.has_texture(CONTEXT, SOURCE):
		var usage := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		buffers.create_texture(CONTEXT, SOURCE, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage,
			RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true, false)
	var source := buffers.get_texture(CONTEXT, SOURCE)
	var normal := buffers.get_texture(&"forward_clustered", &"normal_roughness")
	var groups := Vector3i(ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	var z_near := scene_data.get_cam_projection().get_z_near()
	var copy_params := PackedFloat32Array([size.x, size.y, 0.0, 0.0]).to_byte_array()
	var c := line_color.srgb_to_linear()
	var paint_params := PackedFloat32Array([
		size.x, size.y, z_near, brush_radius,
		line_strength, line_width, paper_strength, edge_darkening,
		wobble, warmth, saturation, wash,
		c.r, c.g, c.b, line_fade_distance,
		line_darkness, line_pressure, 0.0, 0.0,
	]).to_byte_array()
	for view in buffers.get_view_count():
		var color := buffers.get_color_layer(view)
		var depth := buffers.get_depth_layer(view)
		# Schritt 1: Kopie
		var copy_set := UniformSetCacheRD.get_cache(_copy_shader, 0, [_image(0, color), _image(1, source)])
		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _copy_pipeline)
		_rd.compute_list_bind_uniform_set(list, copy_set, 0)
		_rd.compute_list_set_push_constant(list, copy_params, copy_params.size())
		_rd.compute_list_dispatch(list, groups.x, groups.y, groups.z)
		_rd.compute_list_end()
		# Schritt 2: malen
		var paint_set := UniformSetCacheRD.get_cache(_paint_shader, 0, [_image(0, color), _sampled(1, _linear_sampler, source),
			_sampled(2, _nearest_sampler, depth), _sampled(3, _nearest_sampler, normal)])
		list = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _paint_pipeline)
		_rd.compute_list_bind_uniform_set(list, paint_set, 0)
		_rd.compute_list_set_push_constant(list, paint_params, paint_params.size())
		_rd.compute_list_dispatch(list, groups.x, groups.y, groups.z)
		_rd.compute_list_end()


func _image(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture)
	return uniform


func _sampled(binding: int, sampler: RID, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler)
	uniform.add_id(texture)
	return uniform
