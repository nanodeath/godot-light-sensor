@icon("res://addons/light_sensor_3d/icon.png")
@tool
class_name LightSensor3D extends Node3D

## Emitted when the color the sensor observes has changed (after refresh()).
signal color_updated(color: Color)

## Emitted when the light level the sensor observes has changed (after refresh()).
## Ranges from 0 (pitch dark) to 1 (bright as the sun).
signal light_level_updated(luminance: float)

## Configure a layer for the sensor probe.
## Choose a layer visible to your lights but invisible to your camera.
@export_flags_3d_render var layer: int = 0:
	set(value):
		layer = value
		update_configuration_warnings()

@export_group("Advanced")
## Renders a square next to the sensor that shows what the subviewport is seeing.
@export var enable_subviewport_debug = false

## Prints out how long the sensor took every time it refreshes.
@export var print_timing_information = false

@export_group("Environment")
## Reference camera to inherit environment settings from. If not set, uses minimal environment.
## When set, the SubViewport is automatically sized to 32x32 (minimum for SSAO/SSIL).
## See: https://github.com/godotengine/godot/issues/86631
@export var reference_camera: Camera3D:
	set(value):
		reference_camera = value
		_update_environment()

## Optional environment override. If set, uses this instead of reference camera's environment.
## When set, the SubViewport is automatically sized to 32x32 (minimum for SSAO/SSIL).
@export var environment_override: Environment:
	set(value):
		environment_override = value
		_update_environment()

## How much to smooth readings between refreshes (0 = no smoothing, 0.95 = very smooth).
## Useful for reducing flickering from screen-space effects like SSAO/SSIL.
@export_range(0.0, 0.95) var smoothing: float = 0.0

## Color recorded by the probe during refresh().
## See also: light_level()
var color: Color = Color.BLACK

## Gets the luminance of the last color generated using refresh().
## Ranges from 0 (pitch dark) to 1 (bright as the sun).
## See also: color
var light_level: float:
	get:
		# This calculates and returns the luminance.
		# Color#luminance exists but sounds broken:
		# https://github.com/godotengine/godot/issues/57015
		return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b

var _scene: Node3D
var _sub_viewport: SubViewport
var _sensor_camera: Camera3D
var _fallback_environment: Environment

func _ready():
	if Engine.is_editor_hint():
		return

	_scene = preload("res://addons/light_sensor_3d/light_sensor_scene.tscn").instantiate() as Node3D
	add_child(_scene)
	
	_sub_viewport = _scene.get_node("SubViewport") as SubViewport
	_sensor_camera = _scene.get_node("SubViewport/Camera3D") as Camera3D
	var sensor_mesh := _scene.get_node("SubViewport/Camera3D/SensorMesh") as MeshInstance3D

	_fallback_environment = _sensor_camera.environment
	_sensor_camera.cull_mask = layer
	sensor_mesh.layers = layer
	
	var debug_sprite := _scene.get_node("DebugViewportSprite") as Sprite3D
	debug_sprite.visible = enable_subviewport_debug
	
	# Set up environment after everything is configured
	_update_environment()
	
	if print_timing_information:
		print_debug(get_path(), ": This LightSensor3D is configured to print out timing information.")

## Recalculates the light/color affecting this probe.
func refresh() -> void:
	var t_start = Time.get_ticks_usec()
	var texture := _sub_viewport.get_texture()
	var image := texture.get_image() # this one's a doozy

	var vp_size := _sub_viewport.size
	var sample_color: Color

	if vp_size.x <= 4 and vp_size.y <= 4:
		# Small viewport: read all pixels via bulk data (original fast path)
		var color_data := image.get_data()
		var average_color_array := [0, 0, 0]
		for i in color_data.size():
			average_color_array[i % 3] += color_data.decode_u8(i)
		var pixel_count := color_data.size() / 3.0
		sample_color = Color(
			average_color_array[0] / pixel_count / 255,
			average_color_array[1] / pixel_count / 255,
			average_color_array[2] / pixel_count / 255,
		)
	else:
		# Larger viewport: sample a 4x4 grid distributed across the surface
		var sample_grid_size := 4
		var step_size := vp_size / sample_grid_size
		var half_step := step_size / 2
		var average_color_array := [0.0, 0.0, 0.0]
		var pixel_count := 0
		for grid_y in range(sample_grid_size):
			for grid_x in range(sample_grid_size):
				var sample_x := grid_x * step_size.x + half_step.x
				var sample_y := grid_y * step_size.y + half_step.y
				var pixel_color := image.get_pixel(sample_x, sample_y)
				average_color_array[0] += pixel_color.r
				average_color_array[1] += pixel_color.g
				average_color_array[2] += pixel_color.b
				pixel_count += 1
		sample_color = Color(
			average_color_array[0] / pixel_count,
			average_color_array[1] / pixel_count,
			average_color_array[2] / pixel_count,
		)

	# Apply smoothing (exponential moving average)
	if smoothing > 0.0 and color != Color.BLACK:
		sample_color = color.lerp(sample_color, 1.0 - smoothing)

	var t_end := Time.get_ticks_usec()
	if print_timing_information:
		print(get_path(), " (a LightSensor3D) took %.2fms to refresh" % ((t_end - t_start) / 1000.0))

	# Trigger updates if the color changed
	if not color.is_equal_approx(sample_color):
		color = sample_color
		color_updated.emit(color)
		light_level_updated.emit(light_level)

func _get_configuration_warnings():
	if layer == 0:
		return ["LightSensor3D won't work without a layer configured"]
	return []

func _update_environment():
	if not _sensor_camera:
		return

	var target_environment: Environment

	# Priority: environment_override > reference_camera.environment > fallback
	if environment_override:
		target_environment = environment_override
	elif reference_camera and reference_camera.environment:
		target_environment = reference_camera.environment
	else:
		# Use the built-in environment from the scene, which shields the small
		# SubViewport from the WorldEnvironment's SSAO/SSIL (causes Vulkan errors at 4x4).
		target_environment = _fallback_environment

	_sensor_camera.environment = target_environment

	# SSAO/SSIL require minimum 32x32 viewport to avoid Vulkan errors.
	# Only bump when inheriting an external environment that may have them enabled.
	if _sub_viewport:
		var using_inherited_env := target_environment != null and target_environment != _fallback_environment
		if using_inherited_env:
			_sub_viewport.size = Vector2i(max(32, _sub_viewport.size.x), max(32, _sub_viewport.size.y))
		else:
			_sub_viewport.size = Vector2i(4, 4)
