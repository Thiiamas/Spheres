extends Node3D
class_name AoeOrb

## A Lux-E-style area orb driven by a two-state machine:
##   MOVE — flies in the aimed direction at `travel_speed` for `move_time`
##          seconds, then auto-switches to HOLD. A recast switches to HOLD early
##          (park where it is) so the player can pick a closer spot.
##   HOLD — sits still. A recast DETONATES it. If left alone, the `lifetime` fuse
##          auto-detonates it wherever it is.
##
## The aim point only sets the *direction*; how far it reaches is move_time x
## travel_speed. Detonation damages every enemy within `radius` and spawns a
## blast visual. The damage query runs in _physics_process so it's physics-safe.

enum Phase { MOVE, HOLD }

var travel_speed: float = 18.0
var move_time: float = 0.8
var lifetime: float = 3.0
var radius: float = 5.0
var damage: float = 35.0
var blast_scene: PackedScene

## Ground height the radius ring sits on (arena floor top).
@export var ground_y: float = 0.0

@onready var _ring: MeshInstance3D = $RadiusRing

var _dir: Vector3 = Vector3.FORWARD
var _phase: Phase = Phase.MOVE
var _move_left: float = 0.8
var _life_left: float = 3.0
var _exploded: bool = false


## Configure the orb right after instancing (its global_position is the launch
## origin, already set by the caller). The aim point only sets the *direction*.
func setup(target: Vector3, p_radius: float, p_damage: float, p_move_time: float, p_lifetime: float, p_speed: float, p_blast: PackedScene) -> void:
	radius = p_radius
	damage = p_damage
	move_time = p_move_time
	lifetime = p_lifetime
	travel_speed = p_speed
	blast_scene = p_blast
	_move_left = p_move_time
	_life_left = p_lifetime

	var to := target - global_position
	to.y = 0.0 # travel horizontally; don't dip toward the ground aim point
	_dir = to.normalized() if to.length() > 0.001 else Vector3(0.0, 0.0, -1.0)

	# Ring mesh is unit radius; scale it to show the real blast footprint.
	if _ring:
		_ring.scale = Vector3(radius, 1.0, radius)


## The player recast the AOE: MOVE -> park into HOLD; HOLD -> detonate.
func recast() -> void:
	match _phase:
		Phase.MOVE:
			_phase = Phase.HOLD
		Phase.HOLD:
			_explode()


func _physics_process(delta: float) -> void:
	if _phase == Phase.MOVE:
		global_position += _dir * travel_speed * delta
		_move_left -= delta
		if _move_left <= 0.0:
			_phase = Phase.HOLD

	# Keep the radius ring flat on the ground beneath the orb.
	if _ring:
		_ring.global_position = Vector3(global_position.x, ground_y + 0.02, global_position.z)

	# Overall fuse: if never detonated by a recast, the orb goes off on its own.
	_life_left -= delta
	if _life_left <= 0.0:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 2 # enemies live on physics layer 2
	for hit in space.intersect_shape(query, 64):
		var body = hit.get("collider")
		if body and body.has_method("take_hit"):
			body.take_hit(damage)

	if blast_scene:
		var fx := blast_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = global_position
		if fx.has_method("play"):
			fx.play(radius)

	queue_free()
