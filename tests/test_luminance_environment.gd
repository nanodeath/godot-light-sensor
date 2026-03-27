extends GutTest


func test_ssao_produces_valid_readings():
	if not TestSceneBuilder.supports_ssao():
		pass_test("Skipped: SSAO not available on %s renderer" % TestSceneBuilder.current_renderer())
		return

	var env := TestSceneBuilder.make_env(true, false)
	var root := TestSceneBuilder.build({
		"layer": 2,
		"environment_override": env,
		"add_omni_light": true,
		"light_energy": 0.5
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(1.0).timeout
	sensor.refresh()
	assert_between(sensor.light_level, 0.0, 1.0,
		"SSAO environment should produce valid luminance")
	root.queue_free()


func test_ssil_produces_valid_readings():
	if not TestSceneBuilder.supports_ssil():
		pass_test("Skipped: SSIL not available on %s renderer" % TestSceneBuilder.current_renderer())
		return

	var env := TestSceneBuilder.make_env(false, true)
	var root := TestSceneBuilder.build({
		"layer": 2,
		"environment_override": env,
		"add_omni_light": true,
		"light_energy": 0.5
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(1.0).timeout
	sensor.refresh()
	assert_between(sensor.light_level, 0.0, 1.0,
		"SSIL environment should produce valid luminance")
	root.queue_free()


func test_ssao_ssil_combined_produces_valid_readings():
	if not TestSceneBuilder.supports_ssao() or not TestSceneBuilder.supports_ssil():
		pass_test("Skipped: SSAO/SSIL not fully available on %s renderer" % TestSceneBuilder.current_renderer())
		return

	var env := TestSceneBuilder.make_env(true, true)
	var root := TestSceneBuilder.build({
		"layer": 2,
		"environment_override": env,
		"add_omni_light": true,
		"light_energy": 0.5
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(1.0).timeout
	sensor.refresh()
	assert_between(sensor.light_level, 0.0, 1.0,
		"SSAO+SSIL combined should produce valid luminance")
	root.queue_free()


func test_reference_camera_env_produces_valid_readings():
	var root := TestSceneBuilder.build({
		"layer": 2,
		"add_reference_camera": true,
		"add_omni_light": true,
		"light_energy": 0.5
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(1.0).timeout
	sensor.refresh()
	assert_between(sensor.light_level, 0.0, 1.0,
		"Reference camera environment should produce valid luminance")
	root.queue_free()


func test_reference_camera_with_ssao_produces_valid_readings():
	if not TestSceneBuilder.supports_ssao():
		pass_test("Skipped: SSAO not available on %s renderer" % TestSceneBuilder.current_renderer())
		return

	var root := TestSceneBuilder.build({
		"layer": 2,
		"add_reference_camera": true,
		"cam_ssao": true,
		"add_omni_light": true,
		"light_energy": 0.5
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(1.0).timeout
	sensor.refresh()
	assert_between(sensor.light_level, 0.0, 1.0,
		"Reference camera with SSAO should produce valid luminance")
	root.queue_free()
