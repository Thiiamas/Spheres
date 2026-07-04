extends SphereControlState
class_name AttackControlState

## ATTACK: the sphere holds position (no roll / jump / boost) and instead fires
## abilities — A = aimed projectile, Z = area blast (AOE). Reactor/mouse aiming
## stays live so projectiles can be aimed.


func enter() -> void:
	# Cancel any pending mobility so nothing fires when we lock movement.
	sphere.cancel_buffered_jumps()
	sphere.set_boost_emitting(false)


func handle_input(ctx: InputContext) -> void:
	if ctx.just_pressed(&"attack"):
		sphere.try_fire_projectile()
	if ctx.just_pressed(&"aoe"):
		sphere.try_cast_aoe()


func physics(physics_state: PhysicsDirectBodyState3D) -> void:
	# "Setting" stance: hard-brake the slide so the sphere anchors itself in place
	# to aim and launch, instead of coasting on its movement-mode momentum. Roll /
	# jump / boost stay locked; the body still simulates gravity and collisions.
	sphere.apply_attack_anchor(physics_state)


func tint() -> Color:
	return sphere.attack_color


func label() -> String:
	return "ATTACK"
