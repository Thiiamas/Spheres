extends Node3D

## Boots the front-line level (Docs/Plans/phase7_front.md): two Base spawners send
## out minion-style waves toward each other while the player starts
## possessing the RuneMage. Shows a victory message and stops both bases the
## first time an ally unit reaches the enemy base's GoalZone — gated behind
## the enemy Tower's destruction (Docs/front/tower.md), so "reach the goal" alone
## isn't enough. Also handles the RuneMage's death: EnemyTower's EscortGate
## can now retaliate against an unescorted push, so respawn is wired here.

@export var mage_scene: PackedScene
@export var mage_respawn_delay: float = 3.0

@onready var _player_base: Base = $PlayerBase
@onready var _enemy_base: Base = $EnemyBase
@onready var _player_tower: Tower = $PlayerTower
@onready var _enemy_tower: Tower = $EnemyTower
@onready var _message: Label = $UI/MessageLabel

var _rune_mage: RuneMage
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

	_rune_mage = $RuneMage
	_rune_mage.died.connect(_on_mage_died)


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


## EnemyTower's EscortGate can now kill an unescorted RuneMage. No game-over
## screen (out of scope, Docs/Plans/phase7_front.md) — just a short delay, then a
## fresh mage at the player's base, re-adopted by the existing possession
## system (Consciousness.active_changed) with no extra wiring needed.
func _on_mage_died() -> void:
	_message.text = "Vous êtes tombé...\nRespawn dans %.0fs" % mage_respawn_delay
	_message.visible = true
	await get_tree().create_timer(mage_respawn_delay).timeout
	_message.visible = false
	_spawn_mage()


func _spawn_mage() -> void:
	var mage := mage_scene.instantiate() as RuneMage
	add_child(mage)
	mage.global_position = _player_base.global_position + Vector3(3, 0.55, 4)
	mage.died.connect(_on_mage_died)
	_rune_mage = mage
