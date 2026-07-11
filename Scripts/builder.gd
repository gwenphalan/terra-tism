class_name Builder
extends Node

# Mouse-driven pick/place controller.
# Left click a loose or attached part to pick it up; while holding, the part
# snaps to any valid cell on the construct (click to attach) or can be
# clicked onto the ground to drop it loose.

@export var camera: Camera3D
@export var anchor: ConstructAnchor

const RAY_LENGTH := 200.0
const HOLD_DISTANCE := 6.0

var held_part: ConstructPart = null
var hover_cell := Vector3i.ZERO
var hover_valid := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if held_part:
			_try_place()
		else:
			_try_pick()

func _physics_process(_delta: float) -> void:
	if held_part:
		_update_held()

func _try_pick() -> void:
	var hit := _raycast()
	if hit.is_empty():
		return
	var node := _find_construct_node(hit.collider)
	if node is not ConstructPart:
		return # the anchor (cab) and non-construct bodies are not pickable
	var part := node as ConstructPart
	if part.anchor:
		part.anchor.remove_part(part) # cascades: strands any now-unsupported peers too
	part.set_collision_enabled(false)
	part.set_physics_enabled(false) # frozen while dragged so gravity doesn't fight the hand
	held_part = part

func _try_place() -> void:
	if hover_valid and anchor.attach_part(held_part, hover_cell):
		_release()
		return
	var hit := _raycast()
	if not hit.is_empty() and _find_construct_node(hit.collider) == null:
		# Clicked a non-construct surface (the ground): drop the part loose
		held_part.global_position = hit.position + Vector3.UP * 0.5
		held_part.global_rotation = Vector3.ZERO
		held_part.set_physics_enabled(true)
		_release()

func _release() -> void:
	held_part.set_collision_enabled(true)
	held_part = null
	hover_valid = false

# While held: snap to the hovered cell when attachable, otherwise float on the ray
func _update_held() -> void:
	var hit := _raycast()
	hover_valid = false
	if not hit.is_empty():
		hover_cell = anchor.world_to_cell(hit.position + hit.normal * 0.5)
		hover_valid = anchor.can_attach_at(held_part, hover_cell)
	if hover_valid:
		held_part.global_transform = Transform3D(anchor.global_basis, anchor.cell_to_world(hover_cell))
	else:
		var mouse := get_viewport().get_mouse_position()
		held_part.global_position = camera.project_ray_origin(mouse) \
				+ camera.project_ray_normal(mouse) * HOLD_DISTANCE

func _raycast() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

# Walks up from a hit collider to the owning ConstructNode, if any
func _find_construct_node(collider: Object) -> ConstructNode:
	var node := collider as Node
	while node:
		if node is ConstructNode:
			return node
		node = node.get_parent()
	return null
