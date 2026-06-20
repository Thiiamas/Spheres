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

## High-level player mode. MOVEMENT lets the ball roll/jump/boost; ATTACK locks
## movement (placeholder — attack behaviour is implemented later). Toggle with
## the "mode_toggle" action. The ball changes colour as a visual cue.
enum Mode { MOVEMENT, ATTACK }

@export_group("Rolling")
## Torque applied while grounded and giving directional input.
@export var roll_torque: float = 35.0
## Hard cap on spin so the ball doesn't accelerate forever.
@export var max_roll_speed: float = 22.0
## How hard the ball brakes when grounded with no input. Higher = settles sooner
## (less coasting); 0 disables braking and the ball coasts on momentum alone.
@export var brake_strength: float = 8.0

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

@export_group("Mode")
## Mesh whose material is recoloured to signal MOVEMENT vs ATTACK mode.
@export var ball_mesh: MeshInstance3D
## Albedo + glow colour while in MOVEMENT mode.
@export var movement_color: Color = Color(0.3, 0.55, 0.9)
## Albedo + glow colour while in ATTACK mode.
@export var attack_color: Color = Color(0.95, 0.3, 0.2)
## Albedo + glow colour while passive (crystallised — not the active sphere).
@export var passive_color: Color = Color(0.5, 0.75, 1.0)

@export_group("Health")
## Starting / maximum hit points.
@export var max_hp: float = 100.0
## Passive (crystallised) spheres take damage divided by this — they're tougher.
@export var passive_defense: float = 3.0
## Optional floating health bar (HPBar3D) shown above the sphere.
@export var hp_bar: Node3D

@export_group("Attack")
## Projectile fired on the "attack" action (A). Aimed at the mouse target.
@export var projectile_scene: PackedScene
## Minimum seconds between shots.
@export var attack_cooldown: float = 0.5
## Travel speed handed to the projectile.
@export var projectile_speed: float = 30.0
## Damage handed to the projectile (Enemy.take_hit).
@export var projectile_damage: float = 35.0

@export_group("References")
@export var reactor: Reactor
@export var camera: SphereCamera ## Provides the view yaw so roll matches the active camera mode.
@export var boost_particles: GPUParticles3D ## Optional; emits while FLYING.

var state: State = State.AIRBORNE
var mode: Mode = Mode.MOVEMENT

## Whether this sphere is the one the consciousness currently controls. Passive
## spheres are frozen (crystallised) and ignore all input. Driven by the
## Consciousness autoload via set_active() / set_passive().
var is_controlled: bool = false

## Current hit points. Reaches 0 -> the sphere is destroyed.
var hp: float = 100.0

var _attack_timer: float = 0.0

# Per-instance copy of the ball material so recolouring doesn't touch the shared resource.
var _mode_material: StandardMaterial3D = null

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

	# Own a private copy of the material so the mode tint is per-instance.
	if ball_mesh:
		var mat := ball_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			_mode_material = mat.duplicate()
			ball_mesh.material_override = _mode_material

	hp = max_hp
	_update_hp_bar()

	# Join the pool of transferable spheres. Consciousness decides which one
	# starts active; until then this sphere sits crystallised (set_passive).
	Consciousness.register(self)

	print("[Ball] reactor=", reactor, " camera=", camera, " boost_force=", boost_force)


func _process(delta: float) -> void:
	# Passive (crystallised) spheres ignore all input.
	if not is_controlled:
		return

	# Firing works in both movement modes (aiming is always available).
	_attack_timer -= delta
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0:
		_fire_projectile()
		_attack_timer = attack_cooldown

	if Input.is_action_just_pressed("mode_toggle"):
		_toggle_mode()

	# Movement input is ignored entirely in ATTACK mode.
	if mode != Mode.MOVEMENT:
		return

	# Buffer jump presses here for crisp edge detection; consume them in physics.
	if Input.is_action_just_pressed("jump"):
		if _is_grounded:
			_jump_queued = true
		elif _can_double_jump:
			_double_jump_queued = true
			_can_double_jump = false


func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	# Passive spheres are frozen, so _integrate_forces shouldn't even run — but
	# guard anyway so a stray call can never move a crystallised sphere.
	if not is_controlled:
		return

	_update_grounded(physics_state)
	_update_state()

	var can_move := mode == Mode.MOVEMENT

	# Exhaust particles fire only while actively boosting in MOVEMENT mode.
	if boost_particles:
		boost_particles.emitting = can_move and state == State.FLYING

	# ATTACK mode locks all movement. Drop any buffered jumps so they don't
	# fire when switching back.
	if not can_move:
		_jump_queued = false
		_double_jump_queued = false
		return

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


func _toggle_mode() -> void:
	mode = Mode.ATTACK if mode == Mode.MOVEMENT else Mode.MOVEMENT
	_apply_visual()


## --- Consciousness transfer (Phase 2) -------------------------------------

## Take control of this sphere: thaw the physics, re-enable its reactor, and
## reset to MOVEMENT mode. Called by the Consciousness autoload.
func set_active() -> void:
	is_controlled = true
	mode = Mode.MOVEMENT
	freeze = false
	if reactor:
		reactor.set_process(true)
		reactor.set_process_input(true)
	_apply_visual()


## Crystallise this sphere: stop dead, freeze the body so it becomes an immovable
## obstacle, and silence its reactor. Called by the Consciousness autoload.
func set_passive() -> void:
	is_controlled = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	_jump_queued = false
	_double_jump_queued = false
	if reactor:
		reactor.set_process(false)
		reactor.set_process_input(false)
	if boost_particles:
		boost_particles.emitting = false
	_apply_visual()


## Let the shared camera point this controller at the right view yaw.
func bind_camera(cam: SphereCamera) -> void:
	camera = cam


func get_reactor() -> Reactor:
	return reactor


## --- Health / combat (Phase 3) --------------------------------------------

## Take a hit. Passive (crystallised) spheres divide the damage by
## passive_defense, so they're far tougher than the active one.
func take_damage(amount: float) -> void:
	var dmg := amount if is_controlled else amount / passive_defense
	hp = maxf(hp - dmg, 0.0)
	_update_hp_bar()
	if hp <= 0.0:
		_die()


## Fire a projectile toward where the mouse is aiming. The camera resolves the
## world-space aim point via its current AimStrategy, so this code doesn't care
## whether we're in FOLLOW or RTS mode.
func _fire_projectile() -> void:
	if projectile_scene == null or camera == null:
		return
	var origin := global_position
	var target := camera.get_aim_target(origin)
	var dir := target - origin
	if dir.length() < 0.001:
		dir = -global_basis.z # fallback: straight ahead
	dir = dir.normalized()

	var proj := projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = origin + dir * 0.8
	if proj.has_method("launch"):
		proj.launch(dir, projectile_damage, projectile_speed)


## Leave the consciousness pool (which reassigns control if this was the active
## sphere) and remove this sphere from the world. If it was the last one, the
## run is over.
func _die() -> void:
	Consciousness.unregister(self)
	if Consciousness.spheres.is_empty():
		GameManager.game_over()
	queue_free()


func _update_hp_bar() -> void:
	if hp_bar and hp_bar.has_method("update_bar"):
		hp_bar.update_bar(hp, max_hp)


## Recolour the ball so its mode (when active) or crystallised state (passive)
## is readable at a glance.
func _apply_visual() -> void:
	if _mode_material == null:
		return
	var col: Color
	var energy: float
	if not is_controlled:
		col = passive_color
		energy = 0.35 # faint, icy glow
	else:
		col = movement_color if mode == Mode.MOVEMENT else attack_color
		energy = 1.6
	_mode_material.albedo_color = col
	_mode_material.emission_enabled = true
	_mode_material.emission = col
	_mode_material.emission_energy_multiplier = energy


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
		_apply_ground_brake(physics_state)
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


## With no input on the ground, bleed off spin and horizontal drift so the ball
## settles quickly instead of coasting. Exponential decay keeps it frame-rate
## independent; vertical velocity is left alone so gravity/landing still work.
func _apply_ground_brake(physics_state: PhysicsDirectBodyState3D) -> void:
	if brake_strength <= 0.0:
		return
	var decay := exp(-brake_strength * physics_state.step)
	physics_state.angular_velocity *= decay
	var v := physics_state.linear_velocity
	v.x *= decay
	v.z *= decay
	physics_state.linear_velocity = v


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
