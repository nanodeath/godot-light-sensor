class_name TestSceneBuilder


static func build(config: Dictionary = {}) -> Node3D:
	var root := Node3D.new()

	# Optional WorldEnvironment (for SSAO/SSIL tests)
	if config.get("ssao", false) or config.get("ssil", false):
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ssao_enabled = config.get("ssao", false)
		env.ssil_enabled = config.get("ssil", false)
		var world_env := WorldEnvironment.new()
		world_env.environment = env
		root.add_child(world_env)

	# LightSensor3D
	var sensor := LightSensor3D.new()
	sensor.layer = config.get("layer", 2)
	sensor.smoothing = config.get("smoothing", 0.0)

	if config.has("environment_override"):
		sensor.environment_override = config["environment_override"]

	root.add_child(sensor)

	# Optional spot light
	if config.get("add_spot_light", false):
		var light := SpotLight3D.new()
		# Point downward at the sensor mesh, matching example scene setup
		light.transform = Transform3D(
			Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)),
			Vector3(0, 0.5, 0))
		light.layers = config.get("layer", 2) | 1
		light.light_energy = config.get("light_energy", 1.0)
		light.spot_angle = 25.0
		light.shadow_enabled = true
		if config.has("light_color"):
			light.light_color = config["light_color"]
		root.add_child(light)

	# Optional OmniLight (simpler fallback if spot light geometry is tricky)
	if config.get("add_omni_light", false):
		var light := OmniLight3D.new()
		light.position = Vector3(0, 0.3, 0)
		light.layers = config.get("layer", 2) | 1
		light.light_energy = config.get("light_energy", 1.0)
		light.omni_range = 2.0
		if config.has("light_color"):
			light.light_color = config["light_color"]
		root.add_child(light)

	# Optional reference camera (for environment inheritance tests)
	if config.get("add_reference_camera", false):
		var cam := Camera3D.new()
		var cam_env := Environment.new()
		cam_env.background_mode = Environment.BG_COLOR
		cam_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		cam_env.ssao_enabled = config.get("cam_ssao", false)
		cam_env.ssil_enabled = config.get("cam_ssil", false)
		cam.environment = cam_env
		root.add_child(cam)
		sensor.reference_camera = cam

	return root


static func get_sensor(root: Node3D) -> LightSensor3D:
	for child in root.get_children():
		if child is LightSensor3D:
			return child
	return null


static func current_renderer() -> String:
	return RenderingServer.get_current_rendering_method()


static func is_compatibility_renderer() -> bool:
	return current_renderer() == "gl_compatibility"


static func supports_ssao() -> bool:
	# SSAO is available on Forward+ and Compatibility, not Mobile
	return current_renderer() != "mobile"


static func supports_ssil() -> bool:
	# SSIL is only available on Forward+
	return current_renderer() == "forward_plus"


static func make_env(ssao: bool = false, ssil: bool = false) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ssao_enabled = ssao
	env.ssil_enabled = ssil
	return env
