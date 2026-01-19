extends Node

# Global game settings that persist between scenes
# Add this as an autoload in Project Settings > Autoload

# Available car colors
var car_colors: Dictionary = {
	"red": Color(0.85, 0.15, 0.15),
	"blue": Color(0.15, 0.35, 0.85),
	"green": Color(0.15, 0.7, 0.25),
	"yellow": Color(0.95, 0.85, 0.1),
	"black": Color(0.1, 0.1, 0.1)
}

# Currently selected skin
var selected_skin: String = "red"

func get_selected_color() -> Color:
	return car_colors.get(selected_skin, Color.WHITE)

func apply_skin_to_car(car_body_node: Node3D) -> void:
	# Find the mesh instances in the car body and apply the color
	_apply_color_recursive(car_body_node, get_selected_color())

func _apply_color_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		# Apply color override to each surface
		for i in range(mesh_instance.get_surface_override_material_count()):
			var mat = mesh_instance.get_surface_override_material(i)
			if mat == null:
				# Get the active material and create an override
				var active_mat = mesh_instance.mesh.surface_get_material(i) if mesh_instance.mesh else null
				if active_mat and active_mat is StandardMaterial3D:
					mat = active_mat.duplicate()
					mesh_instance.set_surface_override_material(i, mat)
			if mat and mat is StandardMaterial3D:
				# Only apply to body-like materials (not glass, lights, etc.)
				var mat_name = mat.resource_name.to_lower() if mat.resource_name else ""
				if "glass" not in mat_name and "light" not in mat_name and "badge" not in mat_name:
					mat.albedo_color = color
		
		# Also try mesh materials if no overrides
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var override_mat = mesh_instance.get_surface_override_material(i)
				if override_mat == null:
					var surf_mat = mesh_instance.mesh.surface_get_material(i)
					if surf_mat and surf_mat is StandardMaterial3D:
						var new_mat = surf_mat.duplicate()
						var mat_name = new_mat.resource_name.to_lower() if new_mat.resource_name else ""
						if "glass" not in mat_name and "light" not in mat_name and "badge" not in mat_name:
							new_mat.albedo_color = color
							mesh_instance.set_surface_override_material(i, new_mat)
	
	# Recurse to children
	for child in node.get_children():
		_apply_color_recursive(child, color)
