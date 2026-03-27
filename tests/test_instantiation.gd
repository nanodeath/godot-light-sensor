extends GutTest


var _root: Node3D
var _sensor: LightSensor3D


func before_each():
	_root = TestSceneBuilder.build({"layer": 2})
	add_child(_root)
	_sensor = TestSceneBuilder.get_sensor(_root)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each():
	_root.queue_free()


func test_sensor_is_in_tree():
	assert_true(_sensor.is_inside_tree(), "Sensor should be in scene tree")


func test_internal_scene_instantiated():
	assert_gt(_sensor.get_child_count(), 0, "Sensor should have instantiated its internal scene")


func test_subviewport_exists():
	var scene_child := _sensor.get_child(0)
	var sub_vp := scene_child.get_node("SubViewport")
	assert_not_null(sub_vp, "SubViewport should exist")


func test_camera_exists():
	var scene_child := _sensor.get_child(0)
	var cam := scene_child.get_node("SubViewport/Camera3D")
	assert_not_null(cam, "Camera3D should exist in SubViewport")


func test_sensor_mesh_exists():
	var scene_child := _sensor.get_child(0)
	var mesh := scene_child.get_node("SubViewport/Camera3D/SensorMesh")
	assert_not_null(mesh, "SensorMesh should exist under Camera3D")


func test_initial_color_is_black():
	assert_eq(_sensor.color, Color.BLACK, "Initial color should be black")


func test_initial_light_level_is_zero():
	assert_eq(_sensor.light_level, 0.0, "Initial light level should be 0")


func test_camera_cull_mask_matches_layer():
	var cam := _sensor.get_child(0).get_node("SubViewport/Camera3D")
	assert_eq(cam.cull_mask, 2, "Camera cull_mask should match sensor layer")


func test_mesh_layers_match_sensor_layer():
	var mesh := _sensor.get_child(0).get_node("SubViewport/Camera3D/SensorMesh")
	assert_eq(mesh.layers, 2, "Mesh layers should match sensor layer")
