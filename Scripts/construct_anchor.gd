class_name ConstructAnchor
extends ConstructNode

# Tracks all parts attached to this construct
var attached_parts: Array[ConstructPart] = []

# Tracks which part occupies which grid cell coordinate in the construct
# Key: Vector3i (local construct cell)
# Value: ConstructPart
var occupied_cells: Dictionary = {}

func _ready() -> void:
	super() # Ensure base ConstructNode ready logic runs (port generation)
	# Register ourselves as the anchor block
	occupied_cells[construct_grid_pos] = self

const DIRECTIONS: Array[Vector3i] = [
	Vector3i.UP, Vector3i.DOWN,
	Vector3i.LEFT, Vector3i.RIGHT,
	Vector3i.FORWARD, Vector3i.BACK,
]

# --- Grid <-> World (1 cell = 1 m, cell centers on integer local coordinates) ---

func world_to_cell(world_pos: Vector3) -> Vector3i:
	return Vector3i(to_local(world_pos).round())

func cell_to_world(cell: Vector3i) -> Vector3:
	return to_global(Vector3(cell))

# --- Attach / Detach ---

# True if the part could attach at this cell (cell free + at least one matching port pair)
func can_attach_at(part: ConstructPart, cell: Vector3i) -> bool:
	if occupied_cells.has(cell):
		return false
	return not _find_connections(part, cell).is_empty()

# Attaches a part at the given cell: reparents it under the anchor, snaps its
# transform to the grid, registers it, and connects every touching port pair.
func attach_part(part: ConstructPart, cell: Vector3i) -> bool:
	var connections := _find_connections(part, cell)
	if occupied_cells.has(cell) or connections.is_empty():
		return false
	if part.get_parent() != self:
		part.reparent(self)
	part.transform = Transform3D(Basis.IDENTITY, Vector3(cell))
	part.construct_grid_pos = cell
	register_part(part)
	for c in connections:
		part.connect_port(c[0], c[1], c[2])
	part.set_physics_enabled(false)
	return true

# Detaches a single part: disconnects all its ports, unregisters it, unfreezes
# its physics, and reparents it out of the construct so it moves independently.
# Does not cascade - use remove_part() for that.
func detach_part(part: ConstructPart) -> void:
	for port in part.ports:
		part.disconnect_port(port)
	unregister_part(part)
	part.set_physics_enabled(true)
	if part.get_parent() == self:
		part.reparent(get_tree().current_scene)

# Detaches a part and cascades: any other parts left without a chain of
# occupied ports back to the anchor (i.e. now "floating") are detached too,
# so nothing stays visually attached while structurally unsupported.
func remove_part(part: ConstructPart) -> void:
	detach_part(part)
	_prune_floating_parts()

# BFS over occupied ports starting at the anchor; any attached part not
# reached is disconnected from its peers and unpaired from the anchor.
func _prune_floating_parts() -> void:
	var reachable: Dictionary = {}
	var queue: Array[ConstructNode] = [self]
	while not queue.is_empty():
		var current: ConstructNode = queue.pop_back()
		for port in current.ports:
			if not port.is_occupied():
				continue
			var neighbor := port.connection
			if neighbor is ConstructPart and not reachable.has(neighbor):
				reachable[neighbor] = true
				queue.append(neighbor)

	for part in attached_parts.duplicate():
		if not reachable.has(part):
			detach_part(part)

# Returns [my_port, neighbor_node, neighbor_port] triples for every occupied
# neighbor cell where both facing ports exist and are free.
# Assumes an unrotated 1-cell part; sets part.construct_grid_pos as a side effect.
func _find_connections(part: ConstructPart, cell: Vector3i) -> Array:
	part.construct_grid_pos = cell
	var result := []
	for dir in DIRECTIONS:
		var neighbor_cell: Vector3i = cell + dir
		if not occupied_cells.has(neighbor_cell):
			continue
		var neighbor: ConstructNode = occupied_cells[neighbor_cell]
		var my_port := part.get_port_at(cell, dir)
		var other_port := neighbor.get_port_at(neighbor_cell, -dir)
		if my_port and other_port and not my_port.is_occupied() and not other_port.is_occupied():
			result.append([my_port, neighbor, other_port])
	return result

# Registers a new part and maps its occupied cells into the construct's grid
func register_part(part: ConstructPart) -> void:
	if not attached_parts.has(part):
		attached_parts.append(part)
		part.anchor = self
		
		# Map all cells this part occupies based on its dimensions and rotation
		for x in range(part.grid_width):
			for y in range(part.grid_height):
				for z in range(part.grid_depth):
					var local_cell := Vector3i(x, y, z)
					var rotated_offset := part.transform.basis * Vector3(local_cell)
					var cell_pos := part.construct_grid_pos + Vector3i(rotated_offset.round())
					occupied_cells[cell_pos] = part

# Unregisters a part and clears its mapped cells
func unregister_part(part: ConstructPart) -> void:
	attached_parts.erase(part)
	if part.anchor == self:
		part.anchor = null
		
	# Clean up matching cells in the dictionary
	# Note: safe iteration by duplicating keys to avoid size modification error
	for key in occupied_cells.keys().duplicate():
		if occupied_cells[key] == part:
			occupied_cells.erase(key)
