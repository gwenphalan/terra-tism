class_name ConstructPart
extends ConstructNode

# Reference to the anchor node of the construct this part belongs to
var anchor: ConstructAnchor = null

func _ready() -> void:
	super() # Ensure base ConstructNode ready logic runs (port generation)

# Freezes/unfreezes physics simulation on this part (it's a RigidBody3D).
# Attached parts are frozen static so the construct stays rigid; loose parts
# simulate normally (gravity, collisions).
func set_physics_enabled(enabled: bool) -> void:
	# Routed through an untyped Node ref: the static analyzer only knows
	# `self` as ConstructPart (extends Node3D) and rejects a direct cast to
	# the sibling branch RigidBody3D, even though that's the node's real type.
	var node: Node = self
	if node is RigidBody3D:
		var body: RigidBody3D = node
		body.freeze = not enabled
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		if enabled:
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
