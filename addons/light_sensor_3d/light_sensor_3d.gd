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

## Size of the SubViewport used for light sampling (minimum 32x32 for SSAO/SSIL).
## SubViewports smaller than 32x32 cause Vulkan rendering errors when SSAO/SSIL effects
## are enabled in the inherited environment. See: https://github.com/godotengine/godot/issues/86631
@export var viewport_size: Vector2i = Vector2i(32, 32):
	set(value):
		viewport_size = Vector2i(max(32, value.x), max(32, value.y))
		if _sub_viewport:
			_sub_viewport.size = viewport_size

@export_group("Environment")
## Reference camera to inherit environment settings from. If not set, uses minimal environment.
@export var reference_camera: Camera3D:
	set(value):
		reference_camera = value
		_update_environment()

## Optional environment override. If set, uses this instead of reference camera's environment.
@export var environment_override: Environment:
	set(value):
		environment_override = value
		_update_environment()

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

func _ready():
	if Engine.is_editor_hint():
		return

	_scene = preload("res://addons/light_sensor_3d/light_sensor_scene.tscn").instantiate() as Node3D
	add_child(_scene)
	
	_sub_viewport = _scene.get_node("SubViewport") as SubViewport
	_sensor_camera = _scene.get_node("SubViewport/Camera3D") as Camera3D
	var sensor_mesh := _scene.get_node("SubViewport/Camera3D/SensorMesh") as MeshInstance3D

	_sub_viewport.size = viewport_size
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
	
	# Sample a 4x4 grid distributed across the entire viewport surface.
	# This maintains the original sampling behavior (entire sensor surface) efficiently.
	var sample_grid_size := 4
	var step_size := viewport_size / sample_grid_size
	var half_step := step_size / 2
	
	# Sum colors from grid samples across the entire viewport
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
	var average_color := Color(
		average_color_array[0] / pixel_count,
		average_color_array[1] / pixel_count,
		average_color_array[2] / pixel_count,
	)
	
	var t_end := Time.get_ticks_usec()
	if print_timing_information:
		print(get_path(), " (a LightSensor3D) took %.2fms to refresh" % ((t_end - t_start) / 1000.0))
	
	# Trigger updates if the color changed
	if not color.is_equal_approx(average_color):
		color = average_color
		color_updated.emit(color)
		light_level_updated.emit(light_level)

func _get_configuration_warnings():
	if layer == 0:
		return ["LightProbe won't work without a layer configured"]
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
		# Fallback to the built-in environment from the scene
		target_environment = null
	
	_sensor_camera.environment = target_environment
