extends SceneTree
## Compares refresh() and refresh_async() cost.
##
## Run (not headless; needs a real renderer):
##   godot --path . --rendering-method forward_plus -s res://tests/benchmarks/benchmark_refresh.gd
##
## Keep the window visible. A covered window is throttled to 1 fps.
##
## Each scenario refreshes every sensor every REFRESH_INTERVAL frames. An async
## reading takes about 2 frames, so some async calls find a reading still in
## flight and share it. The "readings" column shows how many each mode took, and
## "per_reading" divides by it so the modes compare fairly.
## "call" is main-thread time spent inside the refresh calls, per frame.
## "frame" is wall time between frames, so it also catches GPU stalls and
## async work that runs outside the refresh calls.
## "per_reading" is (frame_avg - NONE frame_avg) * frames / readings: the total
## frame time each reading adds, wherever it lands.

const SENSOR_COUNTS := [1, 8, 32]
const WARMUP_FRAMES := 60
const MEASURE_FRAMES := 300
const LATENCY_SAMPLES := 60
const REFRESH_INTERVAL := 2

enum Mode { NONE, SYNC, ASYNC }


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_run.call_deferred()


func _run() -> void:
	print("BENCH godot=%s renderer=%s frames=%d" % [
		Engine.get_version_info().string,
		RenderingServer.get_current_rendering_method(),
		MEASURE_FRAMES,
	])
	print("BENCH %-6s %-5s %-6s %8s %10s %10s %10s %10s %12s" % [
		"vp", "count", "mode", "readings", "call_avg", "frame_med", "frame_p95", "frame_avg", "per_reading"])

	for large_viewport in [false, true]:
		for count in SENSOR_COUNTS:
			var baseline_us := 0.0
			for mode in [Mode.NONE, Mode.SYNC, Mode.ASYNC]:
				var avg_us: float = await _scenario(count, mode, large_viewport, baseline_us)
				if mode == Mode.NONE:
					baseline_us = avg_us

	print("BENCH")
	print("BENCH latency: refresh_async() call until the reading lands (frame_queue_size=%d)" %
		ProjectSettings.get_setting("rendering/rendering_device/vsync/frame_queue_size"))
	print("BENCH %-6s %-5s %8s %10s %10s %10s" % ["fps", "count", "frames", "ms_med", "ms_p95", "ms_max"])
	for max_fps in [0, 60]:
		for count in [1, 32]:
			await _latency(count, max_fps)
	quit()


func _build_sensors(count: int, large_viewport: bool) -> Array:
	var root := Node3D.new()
	var sensors: Array[LightSensor3D] = []
	for i in count:
		var cell := TestSceneBuilder.build({
			"layer": 2,
			"add_omni_light": true,
			"light_energy": 0.25,
		})
		cell.position = Vector3(i * 5, 0, 0)
		root.add_child(cell)
		var sensor := TestSceneBuilder.get_sensor(cell)
		if large_viewport:
			sensor.environment_override = TestSceneBuilder.make_env()
		sensors.append(sensor)
	get_root().add_child(root)
	return [root, sensors]


func _latency(count: int, max_fps: int) -> void:
	Engine.max_fps = max_fps
	var built := _build_sensors(count, false)
	var root: Node3D = built[0]
	var sensors: Array[LightSensor3D] = built[1]
	for i in WARMUP_FRAMES:
		await process_frame

	var samples_us: Array[int] = []
	var frames: Array[int] = []
	for i in LATENCY_SAMPLES:
		var t0 := Time.get_ticks_usec()
		var f0 := Engine.get_process_frames()
		for s in sensors:
			s.refresh_async()
		# Readbacks complete in request order, so the last sensor finishes last
		await sensors[-1].refresh_async()
		samples_us.append(Time.get_ticks_usec() - t0)
		frames.append(Engine.get_process_frames() - f0)
		await process_frame

	root.queue_free()
	await process_frame
	Engine.max_fps = 0

	samples_us.sort()
	frames.sort()
	print("BENCH %-6s %-5d %8d %8.3fms %8.3fms %8.3fms" % [
		"uncap" if max_fps == 0 else str(max_fps),
		count,
		frames[frames.size() / 2],
		samples_us[samples_us.size() / 2] / 1000.0,
		samples_us[int(samples_us.size() * 0.95)] / 1000.0,
		samples_us[-1] / 1000.0,
	])


# Returns the average frame time in microseconds.
func _scenario(count: int, mode: Mode, large_viewport: bool, baseline_us: float) -> float:
	var built := _build_sensors(count, large_viewport)
	var root: Node3D = built[0]
	var sensors: Array[LightSensor3D] = built[1]
	var readings := {"count": 0}
	for s in sensors:
		s._async_refresh_finished.connect(func(): readings["count"] += 1)

	for i in WARMUP_FRAMES:
		await process_frame

	var call_total_us := 0
	var frame_us: Array[int] = []
	var last := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		var t0 := Time.get_ticks_usec()
		if i % REFRESH_INTERVAL == 0:
			match mode:
				Mode.SYNC:
					for s in sensors:
						s.refresh()
					readings["count"] += sensors.size()
				Mode.ASYNC:
					for s in sensors:
						s.refresh_async()
		call_total_us += Time.get_ticks_usec() - t0

		await process_frame
		var now := Time.get_ticks_usec()
		frame_us.append(now - last)
		last = now

	# Only readings that landed inside the measured window count
	var reading_count: int = readings["count"]

	# Let pending readbacks land before freeing
	for i in 5:
		await process_frame
	root.queue_free()
	await process_frame

	frame_us.sort()
	var frame_sum := 0
	for f in frame_us:
		frame_sum += f
	var avg_us := float(frame_sum) / MEASURE_FRAMES
	var per_reading := "-"
	if mode != Mode.NONE:
		per_reading = "%.4fms" % ((avg_us - baseline_us) * MEASURE_FRAMES / reading_count / 1000.0)
	print("BENCH %-6s %-5d %-6s %8d %8.3fms %8.3fms %8.3fms %8.3fms %12s" % [
		"32x32" if large_viewport else "4x4",
		count,
		Mode.keys()[mode],
		reading_count,
		call_total_us / 1000.0 / MEASURE_FRAMES,
		frame_us[frame_us.size() / 2] / 1000.0,
		frame_us[int(frame_us.size() * 0.95)] / 1000.0,
		avg_us / 1000.0,
		per_reading,
	])
	return avg_us
