extends Node3D

# Track Builder - Place road tiles to build custom tracks
# Usage: Instance road tile scenes and snap them to grid

@export var tile_size: float = 10.0  # Adjust based on your road piece size
@export var grid_enabled: bool = true

# Dictionary to store placed tiles
var placed_tiles: Dictionary = {}

func _ready() -> void:
	print("Track Builder Ready - Tile size: ", tile_size)

# Snap position to grid
func snap_to_grid(pos: Vector3) -> Vector3:
	if not grid_enabled:
		return pos
	return Vector3(
		round(pos.x / tile_size) * tile_size,
		pos.y,
		round(pos.z / tile_size) * tile_size
	)

# Place a tile at grid position
func place_tile(tile_scene: PackedScene, grid_pos: Vector2i, rotation_y: float = 0.0) -> Node3D:
	var world_pos = Vector3(grid_pos.x * tile_size, 0, grid_pos.y * tile_size)
	
	# Check if tile already exists at this position
	if placed_tiles.has(grid_pos):
		remove_tile(grid_pos)
	
	var tile_instance = tile_scene.instantiate()
	tile_instance.position = world_pos
	tile_instance.rotation.y = deg_to_rad(rotation_y)
	add_child(tile_instance)
	
	placed_tiles[grid_pos] = tile_instance
	return tile_instance

# Remove tile at grid position
func remove_tile(grid_pos: Vector2i) -> void:
	if placed_tiles.has(grid_pos):
		placed_tiles[grid_pos].queue_free()
		placed_tiles.erase(grid_pos)

# Clear all tiles
func clear_all_tiles() -> void:
	for grid_pos in placed_tiles.keys():
		remove_tile(grid_pos)

# Get grid position from world position
func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / tile_size)),
		int(round(world_pos.z / tile_size))
	)
