extends Area3D
class_name RuneBolt

## Spell A (phase 6, Ryze Overload-style). Two modes:
##
##   LINE  - the cast: straight projectile toward the cursor, damages the first
##           enemy it touches.
##   SHARD - the chain: when a bolt hits a RuneMark-carrying enemy, it deals
##           amplified damage, then SPLITS — homing shards fly to every other
##           marked enemy in chain_radius and deal the same damage. Each shard
##           that lands on a marked enemy chains again. A shared visited list
##           guarantees every enemy is hit at most once per cast.

## Seconds before a line bolt fizzles if it hits nothing.
@export var lifetime: float = 2.0

var _dir: Vector3 = Vector3.ZERO
var _speed: float = 26.0
var _damage: float = 25.0
var _mark_multiplier: float = 2.0
var _chain_radius: float = 6.0
var _time: float = 0.0

# The scene used to spawn chain shards (handed in by the caster — avoids a
# script<->scene preload cycle).
var _scene: PackedScene = null

# SHARD mode: locked target (null = LINE mode, flies straight + collides).
var _homing_target: Node3D = null
# Enemies already hit or already targeted by a shard of this cast. SHARED by
# reference across the whole chain.
var _visited: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Arm a LINE bolt (the initial cast). Called by RuneMage.
func launch(dir: Vector3, damage: float, speed: float, mark_multiplier: float,
		chain_radius: float, scene: PackedScene) -> void:
	_dir = dir.normalized()
	_damage = damage
	_speed = speed
	_mark_multiplier = mark_multiplier
	_chain_radius = chain_radius
	_scene = scene


## Arm a SHARD (chain segment): homes onto a specific marked enemy instead of
## flying straight; the Area collision is disabled so it can't clip bystanders.
func launch_chain(target: Node3D, damage: float, speed: float,
		mark_multiplier: float, chain_radius: float, scene: PackedScene,
		visited: Array) -> void:
	_homing_target = target
	_damage = damage
	_speed = speed
	_mark_multiplier = mark_multiplier
	_chain_radius = chain_radius
	_scene = scene
	_visited = visited
	monitoring = false # shards only hit their locked target, on arrival


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= lifetime:
		queue_free()
		return

	if _homing_target != null:
		# SHARD: chase the locked enemy; it may die to another shard first.
		if not is_instance_valid(_homing_target):
			queue_free()
			return
		var to := _homing_target.global_position + Vector3.UP * 0.5 - global_position
		var step := _speed * delta
		if to.length() <= step + 0.3:
			_hit(_homing_target)
			return
		global_position += to.normalized() * step
	else:
		# LINE: straight flight, first body wins (via _on_body_entered).
		global_position += _dir * _speed * delta


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("take_hit"):
		return
	_hit(body)


## Resolve the impact: amplified damage on a marked enemy, then chain.
func _hit(body: Node3D) -> void:
	var marked := body.get_node_or_null("RuneMark") != null
	var dmg := _damage * (_mark_multiplier if marked else 1.0)
	var origin := body.global_position
	body.take_hit(dmg)
	if marked:
		_split_toward_marked(origin, body)
	queue_free()


## The split: spawn a homing shard toward every marked enemy near the impact
## that this cast hasn't reached yet. Targets are reserved in _visited up
## front so two shards never race for the same enemy.
func _split_toward_marked(origin: Vector3, hit_body: Node3D) -> void:
	if _scene == null:
		return
	if not hit_body in _visited:
		_visited.append(hit_body)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _visited or not is_instance_valid(enemy):
			continue
		if enemy.get_node_or_null("RuneMark") == null:
			continue
		if (enemy.global_position - origin).length() > _chain_radius:
			continue
		_visited.append(enemy)

		var shard := _scene.instantiate()
		get_tree().current_scene.add_child(shard)
		shard.global_position = origin + Vector3.UP * 0.5
		if shard is RuneBolt:
			shard.launch_chain(enemy, _damage, _speed, _mark_multiplier,
				_chain_radius, _scene, _visited)
