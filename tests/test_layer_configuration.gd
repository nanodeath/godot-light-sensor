extends GutTest


func test_layer_zero_produces_warning():
	var sensor := LightSensor3D.new()
	sensor.layer = 0
	var warnings = sensor._get_configuration_warnings()
	assert_eq(warnings.size(), 1, "Layer 0 should produce one warning")
	assert_string_contains(warnings[0], "layer")
	sensor.free()


func test_nonzero_layer_no_warning():
	var sensor := LightSensor3D.new()
	sensor.layer = 2
	var warnings = sensor._get_configuration_warnings()
	assert_eq(warnings.size(), 0, "Nonzero layer should produce no warnings")
	sensor.free()


func test_layer_bitmask_propagates():
	var root := TestSceneBuilder.build({"layer": 8})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var cam := sensor.get_child(0).get_node("SubViewport/Camera3D")
	var mesh := sensor.get_child(0).get_node("SubViewport/Camera3D/SensorMesh")
	assert_eq(cam.cull_mask, 8, "Camera cull_mask should match layer 8")
	assert_eq(mesh.layers, 8, "Mesh layers should match layer 8")
	root.queue_free()


func test_different_layer_values():
	for layer_val in [1, 4, 16, 32]:
		var root := TestSceneBuilder.build({"layer": layer_val})
		add_child(root)
		var sensor := TestSceneBuilder.get_sensor(root)
		await get_tree().process_frame
		await get_tree().process_frame

		var cam := sensor.get_child(0).get_node("SubViewport/Camera3D")
		assert_eq(cam.cull_mask, layer_val, "Camera cull_mask should match layer %d" % layer_val)
		root.queue_free()
		await get_tree().process_frame
