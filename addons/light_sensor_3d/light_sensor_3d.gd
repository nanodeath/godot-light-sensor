@icon("res://addons/light-sensor/icon.png")
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

func _ready():
	_scene = preload("res://addons/light_sensor_3d/light_sensor_scene.tscn").instantiate() as Node3D
	add_child(_scene)
	
	_sub_viewport = _scene.get_node("SubViewport") as SubViewport
	var camera := _scene.get_node("SubViewport/Camera3D") as Camera3D
	var sensor_mesh := _scene.get_node("SubViewport/Camera3D/SensorMesh") as MeshInstance3D

	camera.cull_mask = layer
	sensor_mesh.layers = layer

## Recalculates the light/color affecting this probe.
func refresh() -> void:
	var texture := _sub_viewport.get_texture()
	var image := texture.get_image() # this one's a doozy
	var col := image.get_pixel(0, 0)
	if col != color:
		color = col
		color_updated.emit(color)
		light_level_updated.emit(light_level)

func _get_configuration_warnings():
	if layer == 0:
		return ["LightProbe won't work without a layer configured"]
	return []
