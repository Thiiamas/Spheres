extends Node

## Autoload singleton (registered as "GameManager"). Owns the wave/zone loop:
## spawn a wave, count kills, clear the zone, spawn a bigger wave; show Game Over
## when every sphere is destroyed, and restart on confirm.
##
## The arena (enemy container + message label) is handed in by Main.gd once the
## scene is ready — autoloads exist before the scene, so they can't grab scene
## nodes at their own _ready.

const FIRST_WAVE := 5
## The Shore is a battle line, not a circle: cubes wash in along the cube-world
## edge (north, +Z) and advance south toward the sphere world. SHORE_SPAWN_Z is
## that edge; SHORE_SPAWN_HALF_WIDTH is how far the tide line spreads across X.
const SHORE_SPAWN_Z := 13.0
const SHORE_SPAWN_HALF_WIDTH := 12.0

var enemy_scene: PackedScene = preload("res://entities/enemy/enemy.tscn")
var current_zone: int = 1
var enemies_alive: int = 0

var _container: Node3D = null
var _message: Label = null
## True from game_over() until the next begin() — gates the restart input and
## the pending-wave coroutine, without the manager knowing entity types.
var _game_over: bool = false


## Called by Main once the scene (and its spheres) are ready.
func begin(container: Node3D, message: Label) -> void:
	_container = container
	_message = message
	current_zone = 1
	enemies_alive = 0
	_game_over = false
	_hide_message()
	start_wave(FIRST_WAVE)


func start_wave(count: int) -> void:
	if _container == null:
		return
	_hide_message()
	enemies_alive = count
	# A wave breaks across the whole frontier: spread the cubes evenly along the
	# cube-world edge (with a little jitter) rather than around a point. Enemy.gd
	# then walks each one toward the nearest sphere, so they advance as a tide.
	for i in count:
		var enemy := enemy_scene.instantiate()
		_container.add_child(enemy)
		var t := 0.5 if count <= 1 else float(i) / float(count - 1)
		var x := lerpf(-SHORE_SPAWN_HALF_WIDTH, SHORE_SPAWN_HALF_WIDTH, t) + randf_range(-0.5, 0.5)
		var z := SHORE_SPAWN_Z + randf_range(-0.6, 0.6)
		enemy.global_position = Vector3(x, 0.5, z)


## An enemy reported its death (killed by a player projectile).
func on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0:
		_zone_cleared()


func game_over() -> void:
	_game_over = true
	show_message("GAME OVER\n[Entrée] pour recommencer")


func show_message(text: String) -> void:
	if _message:
		_message.text = text
		_message.visible = true


func _zone_cleared() -> void:
	current_zone += 1
	show_message("Zone dégagée !\nProchaine zone…")
	await get_tree().create_timer(2.0).timeout
	# A wipe or restart may have happened during the pause.
	if _game_over:
		return
	start_wave(4 + current_zone * 2)


func _hide_message() -> void:
	if _message:
		_message.visible = false


func _input(event: InputEvent) -> void:
	# Restart only from the Game Over state (last sphere destroyed).
	if event.is_action_pressed("ui_accept") and _game_over:
		_game_over = false
		Consciousness.reset()
		get_tree().reload_current_scene()
