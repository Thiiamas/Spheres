extends SphereControlState
class_name MovementControlState

## MOVEMENT: roll on the ground, jump / double-jump, and boost-fly. No attacks.
## Movement input (move_*, jump, boost) is read only here, so it never collides
## with the attack abilities bound to the same keys in AttackControlState.


func handle_input(_delta: float) -> void:
	sphere.buffer_jump_input()


func physics(physics_state: PhysicsDirectBodyState3D) -> void:
	if sphere.is_grounded():
		sphere.apply_roll(physics_state)
	sphere.consume_jumps(physics_state)

	var flying := sphere.movement_phase == SphereController.State.FLYING
	sphere.set_boost_emitting(flying)
	if flying:
		sphere.apply_boost(physics_state)


func tint() -> Color:
	return sphere.movement_color


func label() -> String:
	return "MOVE"
