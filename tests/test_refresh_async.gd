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


# GUT 9.5+ fails tests on unexpected errors, so expected ones must be asserted.
# Older GUT (used to test the 4.4 minimum) doesn't track errors or have these asserts.
func _expect_engine_errors(count: int) -> void:
	if has_method("assert_engine_error_count"):
		call("assert_engine_error_count", count)


func _expect_push_errors(count: int) -> void:
	if has_method("assert_push_error_count"):
		call("assert_push_error_count", count)


func _light() -> OmniLight3D:
	for child in _root.get_children():
		if child is OmniLight3D:
			return child
	return null


func test_call_before_ready_does_not_block_later_calls():
	var early := LightSensor3D.new()
	early.layer = 2
	# Errors, because the SubViewport doesn't exist until _ready
	early.refresh_async()
	_expect_engine_errors(1)

	_root.add_child(early)
	await get_tree().create_timer(0.2).timeout
	var done := {"value": false}
	var waiter := func():
		await early.refresh_async()
		done["value"] = true
	waiter.call()
	for i in 10:
		await get_tree().process_frame
	assert_true(done["value"], "A call after _ready should complete")


func test_await_in_handler_gets_its_own_reading():
	if TestSceneBuilder.is_compatibility_renderer():
		pass_test("Skipped: Compatibility falls back to synchronous refresh")
		return
	var result := {"frames": -1, "readings_after": 0}
	var readings := _count_readings()
	_sensor.color_updated.connect(func(_c):
		if result["frames"] != -1:
			return
		result["frames"] = 0
		var start := Engine.get_process_frames()
		var before: int = readings["count"]
		await _sensor.refresh_async()
		result["frames"] = Engine.get_process_frames() - start
		result["readings_after"] = readings["count"] - before)
	await _sensor.refresh_async()
	for i in 10:
		await get_tree().process_frame
	assert_gte(result["frames"], 1, "The handler's await should wait for a new reading")
	assert_eq(result["readings_after"], 1, "The handler's await should see exactly one new reading")


func test_reading_older_than_sync_refresh_is_dropped():
	if TestSceneBuilder.is_compatibility_renderer():
		pass_test("Skipped: Compatibility falls back to synchronous refresh")
		return
	var light := _light()
	light.light_energy = 1.0
	await get_tree().create_timer(0.2).timeout

	_sensor.refresh_async()
	light.light_energy = 0.0
	await get_tree().process_frame
	_sensor.refresh()
	var after_sync := _sensor.light_level
	for i in 6:
		await get_tree().process_frame
	assert_almost_eq(_sensor.light_level, after_sync, 0.01,
		"The older async reading should not replace the newer sync reading")


func test_low_processor_mode_falls_back_to_sync():
	OS.low_processor_usage_mode = true
	_sensor.refresh_async()
	var color_right_away := _sensor.color
	OS.low_processor_usage_mode = false
	assert_ne(color_right_away, Color.BLACK, "Low-processor mode should read synchronously")


func test_unexpected_texture_format_is_rejected():
	if TestSceneBuilder.is_compatibility_renderer():
		pass_test("Skipped: Compatibility falls back to synchronous refresh")
		return
	# HDR makes the texture RGBA16F instead of the RGBA8 the async path expects
	_sensor._sub_viewport.use_hdr_2d = true
	await get_tree().create_timer(0.2).timeout
	await _sensor.refresh_async()
	_expect_push_errors(1)
	assert_eq(_sensor.color, Color.BLACK, "A mismatched texture should not produce a reading")
