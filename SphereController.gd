extends RigidBody3D
class_name SphereController

## Player ball. A RigidBody3D sphere that rolls on the ground, jumps / double
## jumps, and boosts through the air using the Reactor's thrust direction.
##
## State machine:
##   GROUNDED - touching the ground. WASD rolls the ball; Space jumps.
##   AIRBORNE - in the air. Space double-jumps (once); Shift starts boosting.
##   FLYING   - airborne AND holding boost. Reactor thrust is applied each step.

enum State { GROUNDED, AIRBORNE, FLYING }

@export_group("Rolling")
## Torque applied while grounded and giving directional input.
@export var roll_torque: float = 35.0
## Hard cap on spin so the ball doesn't accelerate forever.
@export var max_roll_speed: float = 22.0

@export_group("Jumping")
## Upward velocity set on a ground jump.
@export var jump_force: float = 8.0
## Upward velocity set on the mid-air double jump.
@export var double_jump_force: float = 7.0

@export_group("Boost")
## Continuous thrust force applied along -reactorDir while boosting.
@export var boost_force: float = 28.0

@export_group("Ground Check")
## A contact counts as "ground" when its normal·UP is at least this value.
@export var ground_normal_threshold: float = 0.6

@export_group("References")
@export var reactor: Reactor
@export var camera: SphereCamera ## Provides the view yaw so roll matches the active camera mode.
@export var boost_particles: GPUParticles3D ## Optional; emits while FLYING.

var state: State = State.AIRBORNE

var _is_grounded: bool = false
var _can_double_jump: bool = false
var _jump_queued: bool = false
var _double_jump_queued: bool = false


func _ready() -> void:
	# Needed so _integrate_forces can inspect contacts for ground detection.
	contact_monitor = true
	max_contacts_reported = 8
	# Keep simulating so boost/roll feel responsive even at rest.
	can_sleep = false
	print("[Ball] reactor=", reactor, " camera=", camera, " boost_force=", boost_force)


func _process(_delta: float) -> void:
	# Buffer jump presses here for crisp edge detection; consume them in physics.
	if Input.is_action_just_pressed("jump"):
		if _is_grounded:
			_jump_queued = true
		elif _can_double_jump:
			_double_jump_queued = true
			_can_double_jump = false


func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	_update_grounded(physics_state)
	_update_state()

	# Exhaust particles fire only while actively boosting.
	if boost_particles:
		boost_particles.emitting = state == State.FLYING

	if _is_grounded:
		_apply_roll(physics_state)

	if _jump_queued:
		_do_jump(physics_state, jump_force)
		_jump_queued = false
		_can_double_jump = true # one double jump becomes available after leaving ground

	if _double_jump_queued:
		_do_jump(physics_state, double_jump_force)
		_double_jump_queued = false

	if state == State.FLYING:
		_apply_boost(physics_state)


func _update_grounded(physics_state: PhysicsDirectBodyState3D) -> void:
	_is_grounded = false
	for i in physics_state.get_contact_count():
		var normal := physics_state.get_contact_local_normal(i)
		if normal.dot(Vector3.UP) >= ground_normal_threshold:
			_is_grounded = true
			return


func _update_state() -> void:
	if _is_grounded:
		state = State.GROUNDED
		_can_double_jump = false # refreshed on next ground jump
	elif Input.is_action_pressed("boost"):
		state = State.FLYING
	else:
		state = State.AIRBORNE


func _apply_roll(physics_state: PhysicsDirectBodyState3D) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		return

	# Map input to a horizontal world direction relative to the active camera's
	# view yaw, so "forward" is always away-from-camera in BOTH follow and RTS
	# modes. Falls back to the reactor yaw if no camera is assigned.
	var view_yaw := camera.get_view_yaw() if camera else (reactor.yaw if reactor else 0.0)
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(view_yaw))
	var dir := (yaw_basis * Vector3(input.x, 0.0, input.y)).normalized()

	# To roll the ball toward `dir`, spin it about the horizontal axis UP x dir.
	physics_state.apply_torque(Vector3.UP.cross(dir) * roll_torque)

	# Clamp spin magnitude.
	var spin := physics_state.angular_velocity
	if spin.length() > max_roll_speed:
		physics_state.angular_velocity = spin.normalized() * max_roll_speed


func _do_jump(physics_state: PhysicsDirectBodyState3D, force: float) -> void:
	# Set vertical velocity directly for consistent jump height regardless of
	# current fall speed.
	var v := physics_state.linear_velocity
	v.y = force
	physics_state.linear_velocity = v


func _apply_boost(physics_state: PhysicsDirectBodyState3D) -> void:
	if reactor == null:
		return
	# Thrust is opposite the nozzle direction: nozzle points down -> push up.
	# Integrate it into velocity directly (boost_force is treated as an
	# acceleration in m/s^2). We do this rather than apply_central_force because
	# direct velocity writes reliably take effect inside _integrate_forces here,
	# matching how the jump works.
	var thrust := -reactor.get_reactor_dir() * boost_force
	physics_state.linear_velocity += thrust * physics_state.step
