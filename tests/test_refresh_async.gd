extends GutTest


var _root: Node3D
var _sensor: LightSensor3D


func before_each():
	_root = TestSceneBuilder.build({
		"layer": 2,
		"add_omni_light": true,
		"light_energy": 0.25
	})
	add_child(_root)
	_sensor = TestSceneBuilder.get_sensor(_root)
	# Let rendering settle
	await get_tree().create_timer(0.2).timeout


func after_each():
	_root.queue_free()


func test_async_matches_sync():
	_sensor.refresh()
	var sync_color := _sensor.color
	_sensor.color = Color.BLACK
	await _sensor.refresh_async()
	assert_almost_eq(_sensor.color.r, sync_color.r, 0.01, "Red channel")
	assert_almost_eq(_sensor.color.g, sync_color.g, 0.01, "Green channel")
	assert_almost_eq(_sensor.color.b, sync_color.b, 0.01, "Blue channel")
	assert_gt(_sensor.light_level, 0.05, "Lit scene should read meaningful luminance")


func test_async_emits_signals():
	watch_signals(_sensor)
	await _sensor.refresh_async()
	assert_signal_emitted(_sensor, "color_updated")
	assert_signal_emitted(_sensor, "light_level_updated")


func test_async_does_not_update_before_data_arrives():
	if TestSceneBuilder.is_compatibility_renderer():
		pass_test("Skipped: Compatibility falls back to synchronous refresh")
		return
	_sensor.refresh_async()
	assert_eq(_sensor.color, Color.BLACK, "Reading should not land in the same frame")
	await _sensor.refresh_async()
	assert_ne(_sensor.color, Color.BLACK, "Reading should land after awaiting")


# Resetting color in the handler makes every reading emit, so the count equals readings taken.
func _count_readings() -> Dictionary:
	var readings := {"count": 0}
	_sensor.color_updated.connect(func(_c):
		readings["count"] += 1
		_sensor.color = Color.BLACK)
	return readings


func test_overlapping_calls_share_one_reading():
	if TestSceneBuilder.is_compatibility_renderer():
		pass_test("Skipped: Compatibility falls back to synchronous refresh")
		return
	var readings := _count_readings()
	_sensor.refresh_async()
	await _sensor.refresh_async()
	assert_eq(readings["count"], 1, "Overlapping calls should share one reading")


func test_sequential_calls_take_separate_readings():
	var readings := _count_readings()
	await _sensor.refresh_async()
	await _sensor.refresh_async()
	assert_eq(readings["count"], 2, "Sequential calls should each take a reading")


func test_each_reading_waits_for_the_gpu():
	if TestSceneBuilder.is_compatibility_renderer():
		pass_test("Skipped: Compatibility falls back to synchronous refresh")
		return
	var start := Engine.get_process_frames()
	for i in 5:
		await _sensor.refresh_async()
	assert_gte(Engine.get_process_frames() - start, 5,
		"Each reading should take at least one frame")


func test_handler_calling_refresh_does_not_crash():
	var calls := {"count": 0}
	_sensor.color_updated.connect(func(_c):
		calls["count"] += 1
		_sensor.refresh())
	await _sensor.refresh_async()
	assert_gt(calls["count"], 0, "Handler should run")


func test_async_with_resize_in_flight():
	# Compatibility refreshes synchronously, so there's no request in flight to test
	if not TestSceneBuilder.is_compatibility_renderer():
		_sensor.refresh_async()
		_sensor.environment_override = TestSceneBuilder.make_env()
		await _sensor.refresh_async()
		assert_gt(_sensor.light_level, 0.05, "Reading should survive a resize mid-flight")
	else:
		_sensor.environment_override = TestSceneBuilder.make_env()
	await get_tree().create_timer(0.2).timeout
	await _sensor.refresh_async()
	assert_gt(_sensor.light_level, 0.05, "32x32 viewport should read meaningful luminance")


func test_freeing_sensor_mid_flight_does_not_crash():
	_sensor.refresh_async()
	_root.free()
	_root = Node3D.new()
	add_child(_root)
	for i in 5:
		await get_tree().process_frame
	pass_test("No crash after freeing sensor with a pending readback")
