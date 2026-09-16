extends Node3D

## Meso-loop POC, milestone 10.2 (Docs/Plans/phase10_meso_poc.md): adds a
## Tower in front of each Base, positioned inside the lane so it physically
## and mechanically gates a wave's path to the Base behind it (Docs/front/
## tower.md, phase 7 — reused verbatim, nothing new to write there).
##
## Not a copy of meso_front.gd (unlike 9.4's micro_terrain.tscn reusing
## micro_possession.gd): the win/lose rule genuinely changes here (D4/D5),
## it isn't a superset of 10.1's, so it gets its own script.
##
## Victory (D4): the enemy Tower falling is the whole reward for this tier
## ("contrôle de la tour") — no further push to the enemy Base's GoalZone
## like level2_front.gd does; that belongs to Macro.
## Defeat (D5): either the player's own Tower or their own Base falling ends
## the run — the Tower adds a second front to defend, it doesn't remove the
## risk to the Base that 10.1 already established.

@onready var _player_base: Base = $PlayerBase
@onready var _enemy_base: Base = $EnemyBase
@onready var _player_tower: Tower = $PlayerTower
@onready var _enemy_tower: Tower = $EnemyTower
@onready var _message: Label = $UI/MessageLabel

var _over: bool = false


func _ready() -> void:
	_player_base.advance_target = _enemy_base
	_enemy_base.advance_target = _player_base
	_player_base.advance_target_tower = _enemy_tower
	_enemy_base.advance_target_tower = _player_tower
	_player_base.died.connect(_on_defeat)
	_player_tower.died.connect(_on_defeat)
	_enemy_tower.died.connect(_on_victory)

	# Bases' own _ready runs before this one (children before parent), so
	# seeding both opening waves here means they advance toward targets
	# already assigned, instead of waiting a full wave_interval.
	_player_base.spawn_wave_now()
	_enemy_base.spawn_wave_now()


func _on_defeat() -> void:
	if _over:
		return
	_over = true
	_player_base.stop_spawning()
	_enemy_base.stop_spawning()
	_message.text = "Défaite\nVotre front est tombé."
	_message.visible = true


func _on_victory() -> void:
	if _over:
		return
	_over = true
	_player_base.stop_spawning()
	_enemy_base.stop_spawning()
	_message.text = "Victoire !\nLa tour ennemie est détruite."
	_message.visible = true
