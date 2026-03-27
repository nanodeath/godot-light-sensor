extends GutTest


var _root: Node3D
var _sensor: LightSensor3D


func before_each():
	_root = TestSceneBuilder.build({
		"layer": 2,
		"add_omni_light": true,
		"light_energy": 0.5
	})
	add_child(_root)
	_sensor = TestSceneBuilder.get_sensor(_root)
	# Let rendering settle
	await get_tree().create_timer(0.2).timeout


func after_each():
	_root.queue_free()


func test_color_updated_signal_emitted():
	watch_signals(_sensor)
	_sensor.refresh()
	assert_signal_emitted(_sensor, "color_updated")


func test_light_level_updated_signal_emitted():
	watch_signals(_sensor)
	_sensor.refresh()
	assert_signal_emitted(_sensor, "light_level_updated")


func test_no_signal_when_color_unchanged():
	# First refresh establishes color
	_sensor.refresh()
	# Second immediate refresh should see the same color
	watch_signals(_sensor)
	_sensor.refresh()
	assert_signal_not_emitted(_sensor, "color_updated")


func test_luminance_signal_value_in_range():
	var result := {"luminance": -1.0}
	_sensor.light_level_updated.connect(func(lum: float): result["luminance"] = lum)
	_sensor.refresh()
	assert_between(result["luminance"], 0.0, 1.0, "Luminance should be between 0 and 1")


func test_color_signal_not_black_with_light():
	var result := {"color": Color.BLACK}
	_sensor.color_updated.connect(func(c: Color): result["color"] = c)
	_sensor.refresh()
	assert_ne(result["color"], Color.BLACK, "Color should not be black with a light present")
