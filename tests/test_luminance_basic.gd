extends GutTest


func test_dark_scene_reads_low():
	var root := TestSceneBuilder.build({"layer": 2})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.2).timeout
	sensor.refresh()
	# Compatibility (OpenGL) has higher ambient contribution (~0.25) than Vulkan (~0.0)
	var max_dark := 0.30 if TestSceneBuilder.is_compatibility_renderer() else 0.05
	assert_between(sensor.light_level, 0.0, max_dark,
		"Dark scene should read low luminance")
	root.queue_free()


func test_lit_scene_reads_nonzero():
	var root := TestSceneBuilder.build({
		"layer": 2,
		"add_omni_light": true,
		"light_energy": 1.0
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.2).timeout
	sensor.refresh()
	assert_gt(sensor.light_level, 0.1,
		"Lit scene should read meaningful luminance")
	root.queue_free()


func test_brighter_light_reads_higher():
	var root_dim := TestSceneBuilder.build({
		"layer": 2, "add_omni_light": true, "light_energy": 0.25
	})
	var root_bright := TestSceneBuilder.build({
		"layer": 4, "add_omni_light": true, "light_energy": 1.0
	})
	root_bright.position = Vector3(5, 0, 0)
	add_child(root_dim)
	add_child(root_bright)
	await get_tree().create_timer(0.2).timeout

	var sensor_dim := TestSceneBuilder.get_sensor(root_dim)
	var sensor_bright := TestSceneBuilder.get_sensor(root_bright)
	sensor_dim.refresh()
	sensor_bright.refresh()

	assert_gt(sensor_bright.light_level, sensor_dim.light_level,
		"Brighter light should produce higher luminance")
	root_dim.queue_free()
	root_bright.queue_free()


func test_luminance_formula_consistency():
	var root := TestSceneBuilder.build({
		"layer": 2, "add_omni_light": true, "light_energy": 0.5
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.2).timeout
	sensor.refresh()

	var expected := 0.299 * sensor.color.r + 0.587 * sensor.color.g + 0.114 * sensor.color.b
	assert_almost_eq(sensor.light_level, expected, 0.001,
		"light_level should match luminance formula")
	root.queue_free()


func test_colored_light_affects_color():
	var root := TestSceneBuilder.build({
		"layer": 2,
		"add_omni_light": true,
		"light_energy": 1.0,
		"light_color": Color.RED
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.2).timeout
	sensor.refresh()

	assert_gt(sensor.color.r, sensor.color.g,
		"Red light should produce more red than green")
	assert_gt(sensor.color.r, sensor.color.b,
		"Red light should produce more red than blue")
	root.queue_free()
