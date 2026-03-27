extends GutTest


func _get_viewport_size(sensor: LightSensor3D) -> Vector2i:
	return sensor.get_child(0).get_node("SubViewport").size


func test_no_env_stays_4x4():
	var root := TestSceneBuilder.build({"layer": 2})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.3).timeout
	assert_eq(_get_viewport_size(sensor), Vector2i(4, 4))
	root.queue_free()


func test_env_override_bumps_to_32x32():
	var env := TestSceneBuilder.make_env()
	var root := TestSceneBuilder.build({"layer": 2, "environment_override": env})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.3).timeout
	assert_eq(_get_viewport_size(sensor), Vector2i(32, 32))
	root.queue_free()


func test_reference_camera_bumps_to_32x32():
	var root := TestSceneBuilder.build({"layer": 2, "add_reference_camera": true})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.3).timeout
	assert_eq(_get_viewport_size(sensor), Vector2i(32, 32))
	root.queue_free()


func test_clearing_env_override_reverts_to_4x4():
	var env := TestSceneBuilder.make_env()
	var root := TestSceneBuilder.build({"layer": 2, "environment_override": env})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.3).timeout
	assert_eq(_get_viewport_size(sensor), Vector2i(32, 32))

	sensor.environment_override = null
	assert_eq(_get_viewport_size(sensor), Vector2i(4, 4))
	root.queue_free()


func test_clearing_reference_camera_reverts_to_4x4():
	var root := TestSceneBuilder.build({"layer": 2, "add_reference_camera": true})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.3).timeout
	assert_eq(_get_viewport_size(sensor), Vector2i(32, 32))

	sensor.reference_camera = null
	assert_eq(_get_viewport_size(sensor), Vector2i(4, 4))
	root.queue_free()


func test_ssao_env_uses_32x32():
	if not TestSceneBuilder.supports_ssao():
		pass_test("Skipped: SSAO not available on %s renderer" % TestSceneBuilder.current_renderer())
		return
	var env := TestSceneBuilder.make_env(true, false)
	var root := TestSceneBuilder.build({"layer": 2, "environment_override": env})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.3).timeout
	assert_eq(_get_viewport_size(sensor), Vector2i(32, 32))
	root.queue_free()


func test_ssil_env_uses_32x32():
	if not TestSceneBuilder.supports_ssil():
		pass_test("Skipped: SSIL not available on %s renderer" % TestSceneBuilder.current_renderer())
		return
	var env := TestSceneBuilder.make_env(false, true)
	var root := TestSceneBuilder.build({"layer": 2, "environment_override": env})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.3).timeout
	assert_eq(_get_viewport_size(sensor), Vector2i(32, 32))
	root.queue_free()
