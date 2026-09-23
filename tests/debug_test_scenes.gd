extends Node3D
## Finds all LightSensor3D nodes in children and sets up periodic refresh + reading display.

func _ready():
	for container in get_children():
		if container is Camera3D:
			continue
		if not (container is Node3D):
			continue

		var sensor: LightSensor3D = null
		var reading: Label3D = null
		for child in container.get_children():
			if child is LightSensor3D:
				sensor = child
			elif child is Label3D and child.name == "Reading":
				reading = child

		if sensor and reading:
			var timer := Timer.new()
			timer.wait_time = 0.5
			timer.autostart = true
			timer.timeout.connect(func():
				sensor.refresh()
				reading.text = "L: %.3f  C: (%.2f, %.2f, %.2f)" % [
					sensor.light_level,
					sensor.color.r, sensor.color.g, sensor.color.b
				]
			)
			container.add_child(timer)
