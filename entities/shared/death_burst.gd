extends Node3D
class_name DeathBurst

## Purely cosmetic (phase 9.1 finitions, Docs/Plans/phase9_micro_poc.md): the
## dying entity bursts into a handful of small cubes that fly outward, tumble,
## fall under gravity and fade, then the whole thing frees itself.
##
## Built in code rather than authored as a GPUParticles3D so the debris keeps a
## cube shape — on-theme for the angular "cube tribe" (Docs/LORE.md) — without
## hand-writing a ParticleProcessMaterial. Same lifecycle contract as AoeBlast:
## instance it, add it to the scene, place it, optionally call play(), forget it.

@export var shard_count: int = 12
## Cube edge length (or, for spherical shards, twice their radius) — tuned up
## from an initial 0.22 that read as too faint against a ~1m unit.
@export var shard_size: float = 0.34
@export var duration: float = 0.7
@export var speed_min: float = 2.5
@export var speed_max: float = 7.0
@export var gravity: float = 14.0
@export var color: Color = Color(0.53, 0.53, 0.53)
## Sphere debris instead of cube debris. The project's whole visual language is
## sphere (ally) vs cube (enemy) — Docs/LORE.md — so an ally shattering into
## little cubes reads wrong. See death_burst_sphere.tscn.
@export var spherical_shards: bool = false

var _shards: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spins: Array[Vector3] = []
var _material: StandardMaterial3D = null
var _elapsed: float = 0.0


## Optional tint override, so one burst scene can serve differently-coloured
## units. Safe to call before or after _ready.
func play(shard_color: Color) -> void:
	color = shard_color
	if _material != null:
		_material.albedo_color = color


func _ready() -> void:
	# One material shared by every shard of this burst: they fade together, and
	# it's built here (not a scene resource) so nothing is shared across bursts.
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.roughness = 0.9
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# One mesh shared by every shard — they're identical, and only the
	# per-instance transforms differ.
	var mesh: Mesh
	if spherical_shards:
		var sphere := SphereMesh.new()
		sphere.radius = shard_size * 0.5
		sphere.height = shard_size
		mesh = sphere
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * shard_size
		mesh = box

	for _i in shard_count:
		var shard := MeshInstance3D.new()
		shard.mesh = mesh
		shard.material_override = _material
		add_child(shard)
		_shards.append(shard)
		# Outward around the ground plane plus an upward kick, so the burst
		# reads as a shatter rather than a flat expanding ring.
		var angle := randf() * TAU
		var dir := Vector3(cos(angle), randf_range(0.6, 1.4), sin(angle))
		_velocities.append(dir.normalized() * randf_range(speed_min, speed_max))
		_spins.append(Vector3(
			randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)))


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / duration
	if t >= 1.0:
		queue_free()
		return

	# Ballistic, no collision: shards may sink through the floor near the end of
	# their life, by which point they've faded out anyway.
	for i in _shards.size():
		_velocities[i].y -= gravity * delta
		_shards[i].position += _velocities[i] * delta
		_shards[i].rotation += _spins[i] * delta

	_material.albedo_color.a = 1.0 - t
