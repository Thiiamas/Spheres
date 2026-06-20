extends Node

## Autoload singleton (registered as "GameManager"). Owns the wave/zone loop:
## spawn a wave, count kills, clear the zone, spawn a bigger wave; show Game Over
## when every sphere is destroyed, and restart on confirm.
##
## The arena (enemy container + message label) is handed in by Main.gd once the
## scene is ready — autoloads exist before the scene, so they can't grab scene
## nodes at their own _ready.

const FIRST_WAVE := 5
const SPAWN_RADIUS := 14.0

var enemy_scene: PackedScene = preload("res://Enemy.tscn")
var current_zone: int = 1
var enemies_alive: int = 0

var _container: Node3D = null
var _message: Label = null


## Called by Main once the scene (and its spheres) are ready.
func begin(container: Node3D, message: Label) -> void:
	_container = container
	_message = message
	current_zone = 1
	enemies_alive = 0
	_hide_message()
	start_wave(FIRST_WAVE)


func start_wave(count: int) -> void:
	if _container == null:
		return
	_hide_message()
	enemies_alive = count
	for i in count:
		var enemy := enemy_scene.instantiate()
		_container.add_child(enemy)
		var angle := (TAU / count) * i + randf() * 0.3
		enemy.global_position = Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_RADIUS + Vector3.UP * 0.5


## An enemy reported its death (killed by a player projectile).
func on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0:
		_zone_cleared()


func game_over() -> void:
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
	if Consciousness.spheres.is_empty():
		return
	start_wave(4 + current_zone * 2)


func _hide_message() -> void:
	if _message:
		_message.visible = false


func _input(event: InputEvent) -> void:
	# Restart only from the Game Over state (no spheres left).
	if event.is_action_pressed("ui_accept") and Consciousness.spheres.is_empty():
		Consciousness.reset()
		get_tree().reload_current_scene()
