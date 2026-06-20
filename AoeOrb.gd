extends Node3D
class_name AoeOrb

## A Lux-E-style area orb. Launched toward an aim point, it travels there and
## then detonates — either on recast (the caster calls detonate()) or when its
## fuse expires. On detonation it damages every enemy within `radius` and spawns
## a blast visual.
##
## The damage query runs in _physics_process so it's always physics-safe; recast
## just shortens the fuse to detonate on the next physics step.

var travel_speed: float = 18.0
var fuse_time: float = 2.0
var radius: float = 5.0
var damage: float = 35.0
var blast_scene: PackedScene

var _target: Vector3
var _fuse_left: float = 2.0
var _exploded: bool = false


## Configure the orb right after instancing (before/just after add_child).
func setup(target: Vector3, p_radius: float, p_damage: float, p_fuse: float, p_speed: float, p_blast: PackedScene) -> void:
	_target = target
	radius = p_radius
	damage = p_damage
	fuse_time = p_fuse
	travel_speed = p_speed
	blast_scene = p_blast
	_fuse_left = p_fuse


## Request detonation now (recast). Defers to the next physics step.
func detonate() -> void:
	_fuse_left = 0.0


func _physics_process(delta: float) -> void:
	# Glide toward the aim point, stopping once we arrive.
	var to := _target - global_position
	var dist := to.length()
	if dist > 0.05:
		global_position += to / dist * minf(travel_speed * delta, dist)

	_fuse_left -= delta
	if _fuse_left <= 0.0:
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
