extends SphereControlState
class_name AttackControlState

## ATTACK: the sphere holds position (no roll / jump / boost) and instead fires
## abilities — A = aimed projectile, Z = area blast (AOE). Reactor/mouse aiming
## stays live so projectiles can be aimed.


func enter() -> void:
	# Cancel any pending mobility so nothing fires when we lock movement.
	sphere.cancel_buffered_jumps()
	sphere.set_boost_emitting(false)


func handle_input(delta: float) -> void:
	sphere.tick_attack_timers(delta)
	if Input.is_action_just_pressed("attack"):
		sphere.try_fire_projectile()
	if Input.is_action_just_pressed("aoe"):
		sphere.try_cast_aoe()


func physics(_physics_state: PhysicsDirectBodyState3D) -> void:
	# Movement is locked. The body still simulates (gravity, collisions); the
	# player simply applies no roll / jump / boost while attacking.
	pass


func tint() -> Color:
	return sphere.attack_color


func label() -> String:
	return "ATTACK"
