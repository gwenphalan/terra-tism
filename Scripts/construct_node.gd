class_name ConstructNode
extends Node3D

# Emitted when a port's connection status changes (attached or detached)
signal connection_changed(port: Port)

# --- Inner Port Class ---
class Port:
	var local_pos: Vector3i      # Cell coordinate within the block (0-indexed)
	var local_dir: Vector3i      # Face direction relative to the block (e.g., Vector3i.UP)
	var connection: ConstructNode = null # The connected block
	var connected_port: Port = null # The specific mating port on the connected block

	func _init(pos: Vector3i, dir: Vector3i) -> void:
		local_pos = pos
		local_dir = dir

	func is_occupied() -> bool:
		return connection != null and connected_port != null

# --- Properties ---
@export_group("Block Dimensions")
@export var grid_width: int = 1
@export var grid_height: int = 1
@export var grid_depth: int = 1

@export_group("Attachment Ports")
@export var has_port_bottom: bool = true
@export var has_port_top: bool = true
@export var has_port_left: bool = true
@export var has_port_right: bool = true
@export var has_port_back: bool = true
@export var has_port_front: bool = true

# The block's origin position in the construct's local grid coordinates
var construct_grid_pos: Vector3i = Vector3i.ZERO

# Flat array storing all available ports on this block
var ports: Array[Port] = []

func _ready() -> void:
	_generate_ports()

# --- Port Generation ---
func _generate_ports() -> void:
	ports.clear()
	
	# Top (+Y) and Bottom (-Y)
	for x in range(grid_width):
		for z in range(grid_depth):
			if has_port_top:
				ports.append(Port.new(Vector3i(x, grid_height - 1, z), Vector3i.UP))
			if has_port_bottom:
				ports.append(Port.new(Vector3i(x, 0, z), Vector3i.DOWN))
				
	# Left (-X) and Right (+X)
	for y in range(grid_height):
		for z in range(grid_depth):
			if has_port_left:
				ports.append(Port.new(Vector3i(0, y, z), Vector3i.LEFT))
			if has_port_right:
				ports.append(Port.new(Vector3i(grid_width - 1, y, z), Vector3i.RIGHT))

	# Front (-Z) and Back (+Z)
	for x in range(grid_width):
		for y in range(grid_height):
			if has_port_front:
				ports.append(Port.new(Vector3i(x, y, 0), Vector3i.FORWARD))
			if has_port_back:
				ports.append(Port.new(Vector3i(x, y, grid_depth - 1), Vector3i.BACK))

# --- Rotation Math (Construct Local) ---

# Gets the direction of the port relative to the construct root (using local transform)
func get_construct_port_direction(port: Port) -> Vector3i:
	var construct_dir_float := transform.basis * Vector3(port.local_dir)
	return Vector3i(construct_dir_float.round())

# Gets the cell coordinate of the port relative to the construct root
func get_construct_port_position(port: Port) -> Vector3i:
	var rotated_offset := transform.basis * Vector3(port.local_pos)
	return construct_grid_pos + Vector3i(rotated_offset.round())

# Finds the port at a given construct-space cell and direction, or null
func get_port_at(construct_pos: Vector3i, construct_dir: Vector3i) -> Port:
	for port in ports:
		if get_construct_port_position(port) == construct_pos and get_construct_port_direction(port) == construct_dir:
			return port
	return null

# Enables/disables all collision shapes under this node (used while a part is held)
func set_collision_enabled(enabled: bool) -> void:
	for shape in find_children("*", "CollisionShape3D", true, false):
		shape.disabled = not enabled

# --- Connection Management ---

# Connects a local port to a port on another node (binds both sides)
func connect_port(my_port: Port, other_node: ConstructNode, other_port: Port) -> void:
	# Set our side
	my_port.connection = other_node
	my_port.connected_port = other_port
	
	# Set their side (avoiding infinite recursion)
	if other_port.connection != self or other_port.connected_port != my_port:
		other_port.connection = self
		other_port.connected_port = my_port
		other_node.connection_changed.emit(other_port)
		
	connection_changed.emit(my_port)

# Disconnects a local port (clears both sides)
func disconnect_port(my_port: Port) -> void:
	if not my_port.is_occupied():
		return
		
	var other_node := my_port.connection
	var other_port := my_port.connected_port
	
	# Clear our side
	my_port.connection = null
	my_port.connected_port = null
	
	# Clear their side (only if it still points to us, avoiding infinite loops)
	if other_port.connection == self and other_port.connected_port == my_port:
		other_port.connection = null
		other_port.connected_port = null
		other_node.connection_changed.emit(other_port)
		
	connection_changed.emit(my_port)

# --- Static Match Helper ---

# Checks if two ports can connect within the construct's local grid space
static func can_connect_ports(node_a: ConstructNode, port_a: Port, node_b: ConstructNode, port_b: Port) -> bool:
	var dir_a := node_a.get_construct_port_direction(port_a)
	var dir_b := node_b.get_construct_port_direction(port_b)
	
	# 1. Directions must be opposite
	if dir_a != -dir_b:
		return false
		
	var pos_a := node_a.get_construct_port_position(port_a)
	var pos_b := node_b.get_construct_port_position(port_b)
	
	# 2. They must align face-to-face in the grid
	return pos_a + dir_a == pos_b
