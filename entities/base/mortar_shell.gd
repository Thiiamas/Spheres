extends Node3D
class_name MortarShell

## The Base's ranged attack (phase 8.1) — a lobbed shell, not a flat-flying
## bolt: a straight-line Projectile at chest height sails clean over ground
## units (front_unit.gd's box is barely 1m tall), which is exactly the bug
## this replaces. A mortar arcs up and comes down ON the target point
## instead, so it always lands on whatever's standing there.
##
## Modeled after AoeOrb (entities/sphere/aoe_orb.gd): travels for a fixed
## flight_time, then detonates a radius query and an optional cosmetic blast
## (aoe_blast.tscn is generic enough to reuse as-is).
##
## Reused by the Tower's AOE retaliation (phase 10.2, entities/tower/
## tower_shell.gd, Docs/Plans/phase10_meso_poc.md) via subclassing rather
## than a new node type from scratch — damage_mask and _apply_damage() are
## the two seams that reuse needs: which layer the blast queries, and which
## method delivers the hit. Left as plain vars/an overridable method rather
## than setup() params so a subclass can change just one without repeating
## the whole call.

var damage: float = 25.0
var radius: float = 2.5
var flight_time: float = 0.9
var blast_scene: PackedScene
## Enemies live on physics layer 2 (Faction.ENEMY_LAYER) — the Base's own
## mortar only ever queries this layer. A subclass changes this directly
## (see TowerShell) rather than through setup(), which stays untouched.
var damage_mask: int = 2

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _start: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO
var _arc_height: float = 3.0
var _elapsed: float = 0.0
var _exploded: bool = false


## Configure the shell right after instancing (global_position is the launch
## origin, already set by the caller).
func setup(target: Vector3, p_radius: float, p_damage: float, p_flight_time: float,
		p_blast: PackedScene) -> void:
	_start = global_position
	_target = target
	radius = p_radius
	damage = p_damage
	flight_time = p_flight_time
	blast_scene = p_blast
	# Lob higher for a longer shot so the arc reads clearly at range.
	_arc_height = maxf(2.0, _start.distance_to(_target) * 0.25)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / flight_time, 0.0, 1.0)
	var pos := _start.lerp(_target, t)
	pos.y += _arc_height * 4.0 * t * (1.0 - t) # parabola, apex at t = 0.5
	global_position = pos

	if _mesh != null:
		_mesh.rotate_x(delta * 12.0) # tumble, purely cosmetic

	if t >= 1.0:
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
	query.collision_mask = damage_mask
	for hit in space.intersect_shape(query, 64):
		var body = hit.get("collider")
		if body:
			_apply_damage(body)

	if blast_scene:
		var fx := blast_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = global_position
		if fx.has_method("play"):
			fx.play(radius)

	queue_free()


## Same convention as FrontUnit/Tower/Enemy: take_hit is the alias other
## systems (RuneBolt's chain, this shell) call through. Overridden by
## TowerShell to call take_damage instead, for targets (RuneMage) that only
## implement that one — see the class doc above.
func _apply_damage(body: Node) -> void:
	if body.has_method("take_hit"):
		body.take_hit(damage)
