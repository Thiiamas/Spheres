extends Node3D
class_name EnemySpawner

## Spawns a ring of enemies around the arena centre at startup. Enemies are
## parented under this node to keep the scene tidy.

@export var enemy_scene: PackedScene
@export var enemy_count: int = 5
@export var spawn_radius: float = 12.0
@export var spawn_height: float = 0.5


func _ready() -> void:
	if enemy_scene == null:
		push_warning("EnemySpawner: enemy_scene not assigned; no enemies spawned.")
		return
	for i in enemy_count:
		var enemy := enemy_scene.instantiate()
		add_child(enemy)
		var angle := (TAU / enemy_count) * i
		enemy.global_position = Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius \
			+ Vector3.UP * spawn_height
