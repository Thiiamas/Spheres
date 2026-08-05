extends Node3D

## Boots the front-line level (Docs/Plans/phase7_front.md): two Base spawners
## send out minion-style waves toward each other while the player starts
## possessing their own Base (phase 8.1). Shows a victory message and stops
## both bases the first time an ally unit reaches the enemy base's GoalZone —
## gated behind the enemy Tower's destruction (Docs/front/tower.md), so
## "reach the goal" alone isn't enough.
##
## No RuneMage is placed or spawned here (phase 8.2, Docs/Plans/
## phase8_foundations.md): the player gets one only by selecting an ally
## FrontUnit off the front (PossessionSwap), and losing it just hands control
## back to the Base (RuneMage._on_health_died) — nothing for the level script
## to manage.

@onready var _player_base: Base = $PlayerBase
@onready var _enemy_base: Base = $EnemyBase
@onready var _player_tower: Tower = $PlayerTower
@onready var _enemy_tower: Tower = $EnemyTower
@onready var _message: Label = $UI/MessageLabel

var _enemy_tower_destroyed: bool = false


func _ready() -> void:
	# Wired here rather than as an exported NodePath in the scene file: each
	# base only needs to know the other's position, and script assignment
	# avoids hand-authoring node_paths export metadata in the .tscn.
	_player_base.advance_target = _enemy_base
	_enemy_base.advance_target = _player_base
	_player_base.advance_target_tower = _enemy_tower
	_enemy_base.advance_target_tower = _player_tower
	_enemy_base.unit_reached_goal.connect(_on_enemy_base_reached)
	_enemy_tower.died.connect(_on_enemy_tower_died)

	# Base's own _ready runs before this one (children ready before parent),
	# so the opening wave is seeded here — after advance_target is wired —
	# rather than left to WaveTimer's first tick, wave_interval seconds in.
	_player_base.spawn_wave_now()
	_enemy_base.spawn_wave_now()


func _on_enemy_tower_died() -> void:
	_enemy_tower_destroyed = true


## Reaching the GoalZone only counts once the enemy Tower is down — "destroyed
## to access the rest of the map" (Docs/front/tower.md). Ignored otherwise; the next
## unit to reach the zone after the tower falls will trigger victory instead.
func _on_enemy_base_reached(_unit: FrontUnit) -> void:
	if not _enemy_tower_destroyed:
		return
	_player_base.stop_spawning()
	_enemy_base.stop_spawning()
	_message.text = "Victoire !\nLe front a percé la base ennemie."
	_message.visible = true
