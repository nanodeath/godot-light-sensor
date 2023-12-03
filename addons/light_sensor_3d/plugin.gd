@tool
extends EditorPlugin

const GizmoPlugin = preload("res://addons/light_sensor_3d/light_sensor_3d_gizmo_plugin.gd")

var gizmo_plugin = GizmoPlugin.new()

func _enter_tree():
	add_node_3d_gizmo_plugin(gizmo_plugin)

func _exit_tree():
	remove_node_3d_gizmo_plugin(gizmo_plugin)
