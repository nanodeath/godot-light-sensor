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

	# Optional spot light — SpotLight3D emits along -Z, so rotate -90 on X to point down
	if config.get("add_spot_light", false):
		var light := SpotLight3D.new()
		light.position = Vector3(0, 0.5, 0)
		light.rotation_degrees = Vector3(-90, 0, 0)
		light.layers = config.get("layer", 2) | 1
		light.light_energy = config.get("light_energy", 1.0)
		light.spot_angle = 25.0
		light.shadow_enabled = true
		if config.has("light_color"):
			light.light_color = config["light_color"]
		root.add_child(light)

	# Optional bounce spot light — aims at the back wall, not the sensor.
	# Only reaches the sensor via indirect light bounce (tests SSIL).
	if config.get("add_bounce_spot_light", false):
		var light := SpotLight3D.new()
		light.position = Vector3(0, 0.3, 0.5)
		# Default -Z forward already aims at the back wall
		light.layers = config.get("layer", 2) | 1
		light.light_energy = config.get("light_energy", 1.0)
		light.spot_angle = 20.0
		light.shadow_enabled = true
		if config.has("light_color"):
			light.light_color = config["light_color"]
		root.add_child(light)

	# Optional OmniLight
	if config.get("add_omni_light", false):
		var light := OmniLight3D.new()
		light.position = Vector3(0, 0.3, 0)
		light.layers = config.get("layer", 2) | 1
		light.light_energy = config.get("light_energy", 1.0)
		light.omni_range = 2.0
		if config.has("light_color"):
			light.light_color = config["light_color"]
		root.add_child(light)

	# Optional corner geometry: floor + two walls forming an L-shape
	# Provides surfaces for light bounce (SSIL) and depth variation (SSAO)
	if config.get("add_geometry", false):
		var layer_val: int = config.get("layer", 2)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.8, 0.8)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		# Floor
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.mesh = PlaneMesh.new()
		floor_mesh.mesh.size = Vector2(2, 2)
		floor_mesh.material_override = mat
		floor_mesh.layers = layer_val
		floor_mesh.position = Vector3(0, -0.2, 0)
		root.add_child(floor_mesh)

		# Back wall
		var back_wall := MeshInstance3D.new()
		back_wall.mesh = PlaneMesh.new()
		back_wall.mesh.size = Vector2(2, 1)
		back_wall.material_override = mat
		back_wall.layers = layer_val
		back_wall.position = Vector3(0, 0.3, -1)
		back_wall.rotation_degrees = Vector3(90, 0, 0)
		root.add_child(back_wall)

		# Side wall
		var side_wall := MeshInstance3D.new()
		side_wall.mesh = PlaneMesh.new()
		side_wall.mesh.size = Vector2(1, 2)
		side_wall.material_override = mat
		side_wall.layers = layer_val
		side_wall.position = Vector3(-1, 0.3, 0)
		side_wall.rotation_degrees = Vector3(0, 0, -90)
		root.add_child(side_wall)

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
	# Use call() for compatibility with Godot < 4.5 where this method doesn't exist
	if RenderingServer.has_method("get_current_rendering_method"):
		return RenderingServer.call("get_current_rendering_method")
	return ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")


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
