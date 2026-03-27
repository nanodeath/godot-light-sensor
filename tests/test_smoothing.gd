extends GutTest


func test_no_smoothing_consecutive_reads_equal():
	var root := TestSceneBuilder.build({
		"layer": 2, "add_omni_light": true, "light_energy": 0.5, "smoothing": 0.0
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.2).timeout

	sensor.refresh()
	var first_level := sensor.light_level
	sensor.refresh()
	var second_level := sensor.light_level

	assert_almost_eq(first_level, second_level, 0.01,
		"Without smoothing, consecutive reads should be nearly identical")
	root.queue_free()


func test_high_smoothing_dampens_change():
	var root := TestSceneBuilder.build({
		"layer": 2, "add_omni_light": true, "light_energy": 0.8, "smoothing": 0.95
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.2).timeout

	# First refresh sets the baseline
	sensor.refresh()
	var first_level := sensor.light_level

	# With smoothing=0.95, only 5% of the new sample mixes in
	sensor.refresh()
	var diff: float = abs(sensor.light_level - first_level)
	assert_lt(diff, 0.05,
		"High smoothing should produce minimal change between same-scene reads")
	root.queue_free()


func test_smoothing_converges_over_multiple_refreshes():
	var root := TestSceneBuilder.build({
		"layer": 2, "add_omni_light": true, "light_energy": 0.6, "smoothing": 0.5
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.2).timeout

	var readings: Array[float] = []
	for i in 10:
		sensor.refresh()
		readings.append(sensor.light_level)
		await get_tree().create_timer(0.1).timeout

	# Later readings should be closer together than early ones
	var early_range: float = abs(readings[1] - readings[0])
	var late_range: float = abs(readings[9] - readings[8])
	assert_true(late_range <= early_range + 0.01,
		"Smoothed readings should converge over time")
	root.queue_free()


func test_smoothing_skipped_on_first_read():
	# Smoothing uses lerp from current color, but first read starts from BLACK.
	# The code checks `color != Color.BLACK` before applying smoothing,
	# so the first read should be unsmoothed.
	var root := TestSceneBuilder.build({
		"layer": 2, "add_omni_light": true, "light_energy": 0.5, "smoothing": 0.95
	})
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)
	await get_tree().create_timer(0.2).timeout

	# Also create an unsmoothed sensor for comparison
	var root_raw := TestSceneBuilder.build({
		"layer": 4, "add_omni_light": true, "light_energy": 0.5, "smoothing": 0.0
	})
	root_raw.position = Vector3(10, 0, 0)
	add_child(root_raw)
	var sensor_raw := TestSceneBuilder.get_sensor(root_raw)
	await get_tree().create_timer(0.2).timeout

	sensor.refresh()
	sensor_raw.refresh()

	# First reads should be similar since smoothing is skipped when color is BLACK
	assert_almost_eq(sensor.light_level, sensor_raw.light_level, 0.05,
		"First read should be unsmoothed regardless of smoothing setting")
	root.queue_free()
	root_raw.queue_free()
