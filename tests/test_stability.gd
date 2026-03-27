extends GutTest

const SETTLE_TIME := 0.5
const MEASURE_TIME := 1.5
const SAMPLE_INTERVAL := 0.1
const MAX_DEVIATION := 0.05


func _run_stability_test(config: Dictionary) -> void:
	var root := TestSceneBuilder.build(config)
	add_child(root)
	var sensor := TestSceneBuilder.get_sensor(root)

	await get_tree().create_timer(SETTLE_TIME).timeout

	var samples: Array[float] = []
	var elapsed := 0.0
	while elapsed < MEASURE_TIME:
		sensor.refresh()
		samples.append(sensor.light_level)
		await get_tree().create_timer(SAMPLE_INTERVAL).timeout
		elapsed += SAMPLE_INTERVAL

	var sum := 0.0
	for s in samples:
		sum += s
	var mean := sum / samples.size()

	var max_dev := 0.0
	for s in samples:
		max_dev = max(max_dev, abs(s - mean))

	gut.p("  Samples: %d, Mean: %.4f, Max deviation: %.4f" % [samples.size(), mean, max_dev])
	assert_lt(max_dev, MAX_DEVIATION,
		"Readings should be stable (max deviation %.4f < %.4f)" % [max_dev, MAX_DEVIATION])

	root.queue_free()


func test_stability_no_env():
	await _run_stability_test({
		"layer": 2, "add_omni_light": true, "light_energy": 0.5
	})


func test_stability_with_ssao():
	if not TestSceneBuilder.supports_ssao():
		pass_test("Skipped: SSAO not available on %s renderer" % TestSceneBuilder.current_renderer())
		return
	await _run_stability_test({
		"layer": 2, "add_omni_light": true, "light_energy": 0.5,
		"environment_override": TestSceneBuilder.make_env(true, false)
	})


func test_stability_with_ssil():
	if not TestSceneBuilder.supports_ssil():
		pass_test("Skipped: SSIL not available on %s renderer" % TestSceneBuilder.current_renderer())
		return
	await _run_stability_test({
		"layer": 2, "add_omni_light": true, "light_energy": 0.5,
		"environment_override": TestSceneBuilder.make_env(false, true)
	})


func test_stability_with_ssao_ssil():
	if not TestSceneBuilder.supports_ssao() or not TestSceneBuilder.supports_ssil():
		pass_test("Skipped: SSAO/SSIL not fully available on %s renderer" % TestSceneBuilder.current_renderer())
		return
	await _run_stability_test({
		"layer": 2, "add_omni_light": true, "light_energy": 0.5,
		"environment_override": TestSceneBuilder.make_env(true, true)
	})


func test_stability_with_smoothing():
	await _run_stability_test({
		"layer": 2, "add_omni_light": true, "light_energy": 0.5,
		"smoothing": 0.5,
	})


func test_stability_dark_scene():
	await _run_stability_test({
		"layer": 2
	})
