extends EditorNode3DGizmoPlugin

const sensor_distance := 0.1
const sensor_distance_half := sensor_distance / 2.0
const sensor_distance_quarter := sensor_distance / 4.0
const sensor_half_size := 0.1 / 2.0

const arrow_color := Color.WHITE
const sensor_color := Color.ORANGE

func _get_gizmo_name():
	return "LightSensor3D"

func _has_gizmo(node):
	return node is LightSensor3D

func _init():
	create_material("main", Color(1, 1, 1))
	create_material("secondary", sensor_color)
	create_handle_material("handles")
	

func _redraw(gizmo):
	gizmo.clear()

	var node3d = gizmo.get_node_3d() as LightSensor3D

	var lines := PackedVector3Array()

	lines.push_back(Vector3(0, sensor_distance, 0))
	lines.push_back(Vector3.ZERO)
	
	lines.push_back(Vector3(sensor_distance_quarter, sensor_distance_half, 0))
	lines.push_back(Vector3.ZERO)
	
	lines.push_back(Vector3(-sensor_distance_quarter, sensor_distance_half, 0))
	lines.push_back(Vector3.ZERO)
	
	lines.push_back(Vector3(0, sensor_distance_half, sensor_distance_quarter))
	lines.push_back(Vector3.ZERO)
	
	lines.push_back(Vector3(0, sensor_distance_half, -sensor_distance_quarter))
	lines.push_back(Vector3.ZERO)
	
	var lines2 = PackedVector3Array()
	
	lines2.push_back(Vector3(sensor_half_size, 0, sensor_half_size)) # tr
	lines2.push_back(Vector3(sensor_half_size, 0, -sensor_half_size)) # br
	
	lines2.push_back(Vector3(sensor_half_size, 0, -sensor_half_size)) # br
	lines2.push_back(Vector3(-sensor_half_size, 0, -sensor_half_size)) # bl
	
	lines2.push_back(Vector3(-sensor_half_size, 0, -sensor_half_size)) # bl
	lines2.push_back(Vector3(-sensor_half_size, 0, sensor_half_size)) # tl
	
	lines2.push_back(Vector3(-sensor_half_size, 0, sensor_half_size)) # tl
	lines2.push_back(Vector3(sensor_half_size, 0, sensor_half_size)) # tr

	gizmo.add_lines(lines, get_material("main", gizmo))
	gizmo.add_lines(lines2, get_material("secondary", gizmo))
