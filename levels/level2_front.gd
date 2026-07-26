extends Node3D

## Boots the front-line level (Docs/phase7_front.md): two Base spawners send
## out minion-style waves toward each other while the player starts
## possessing the RuneMage. Shows a victory message and stops both bases the
## first time an ally unit reaches the enemy base's GoalZone.

@onready var _player_base: Base = $PlayerBase
@onready var _enemy_base: Base = $EnemyBase
@onready var _message: Label = $UI/MessageLabel


func _ready() -> void:
	# Wired here rather than as an exported NodePath in the scene file: each
	# base only needs to know the other's position, and script assignment
	# avoids hand-authoring node_paths export metadata in the .tscn.
	_player_base.advance_target = _enemy_base
	_enemy_base.advance_target = _player_base
	_enemy_base.unit_reached_goal.connect(_on_enemy_base_reached)

	# Base's own _ready runs before this one (children ready before parent),
	# so the opening wave is seeded here — after advance_target is wired —
	# rather than left to WaveTimer's first tick, wave_interval seconds in.
	_player_base.spawn_wave_now()
	_enemy_base.spawn_wave_now()


func _on_enemy_base_reached(_unit: FrontUnit) -> void:
	_player_base.stop_spawning()
	_enemy_base.stop_spawning()
	_message.text = "Victoire !\nLe front a percé la base ennemie."
	_message.visible = true
