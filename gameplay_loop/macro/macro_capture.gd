extends Node3D

## Macro-loop POC, milestone 11.1 (Docs/Plans/phase11_macro_poc.md): the last
## of the three loop POCs (LOOP_SPHERE_FRONT.md) after Micro (9) and Méso
## (10, mergé) — objective becomes "destroy the enemy base", challenge
## becomes combining Micro + Méso (kill units, breach the tower, push to the
## base), reward is a relayed offensive rather than an immediate end.
##
## A copy-and-extend of meso_siege.tscn/.gd (D6, same flat lane, no new wave
## tuning) with a second Tower/Base pair chained behind the first: PlayerBase
## faces TowerA -> EnemyBaseA -> TowerB -> EnemyBaseB. Capturing EnemyBaseA
## (D1: 0 HP, reuses Health/died, Base._capture()) does NOT end the run (D4,
## the point of this phase's plan revision) — it flips to the player's side,
## keeps fighting, and both it and PlayerBase are recabled to advance on
## EnemyBaseB/TowerB instead. TowerB gates EnemyBaseB exactly as before the
## relay (D3: no shortcut opened by a capture upstream). Victory is
## EnemyBaseB captured; defeat is PlayerBase captured — PlayerBase.capturable
## = true too, symmetric with the enemy side (sub-task 3).
##
## D5 (revised after the first playtest feedback): EnemyBaseB is a
## "backline" base and spawns nothing until EnemyBaseA is captured; it then
## starts its wave against PlayerBase/PlayerTower (already its targets).

@onready var _player_base: Base = $PlayerBase
@onready var _enemy_base_a: Base = $EnemyBaseA
@onready var _enemy_base_b: Base = $EnemyBaseB
@onready var _player_tower: Tower = $PlayerTower
@onready var _tower_a: Tower = $TowerA
@onready var _tower_b: Tower = $TowerB
@onready var _message: Label = $UI/MessageLabel

var _over: bool = false


func _ready() -> void:
	_player_base.advance_target = _enemy_base_a
	_player_base.advance_target_tower = _tower_a
	_enemy_base_a.advance_target = _player_base
	_enemy_base_a.advance_target_tower = _player_tower
	_enemy_base_b.advance_target = _player_base
	_enemy_base_b.advance_target_tower = _player_tower

	_player_base.captured.connect(_on_defeat)
	_enemy_base_a.captured.connect(_on_enemy_base_a_captured)
	_enemy_base_b.captured.connect(_on_victory)

	# D5 (revised): EnemyBaseB is a "backline" base — silent until A falls.
	# Bases' own _ready already started its timer (children before parent),
	# so put it back to sleep here.
	_enemy_base_b.stop_spawning()

	# Seeding the opening waves here means they advance toward targets
	# already assigned, instead of waiting a full wave_interval.
	_player_base.spawn_wave_now()
	_enemy_base_a.spawn_wave_now()


## D4: EnemyBaseA flipping is a relay, not an ending. It becomes the new
## front (advance_target -> EnemyBaseB/TowerB) and PlayerBase, now behind it,
## goes silent (backline: no more units). TowerB itself is untouched: it
## already gated EnemyBaseB before this capture and keeps doing so after.
func _on_enemy_base_a_captured(_new_faction: Faction.Kind) -> void:
	if _over:
		return
	_enemy_base_a.retarget(_enemy_base_b, _tower_b)
	# PlayerBase becomes the backline: EnemyBaseA is the player's front now,
	# so it stops fielding units (nothing to retarget — it stays silent).
	_player_base.stop_spawning()
	# The backline wakes up: EnemyBaseB now fields its wave against PlayerBase.
	_enemy_base_b.start_spawning()
	_enemy_base_b.spawn_wave_now()
	_message.text = "Front A capturé !\nL'assaut continue vers la base B."
	_message.visible = true
	# Transitoire (D4) — a relay, not a game-over overlay, so it clears itself
	# rather than sitting over the gameplay for the rest of the run.
	get_tree().create_timer(3.0).timeout.connect(_on_relay_message_timeout)


func _on_relay_message_timeout() -> void:
	if not _over:
		_message.visible = false


func _on_defeat(_new_faction: Faction.Kind) -> void:
	if _over:
		return
	_over = true
	_player_base.stop_spawning()
	_enemy_base_a.stop_spawning()
	_enemy_base_b.stop_spawning()
	_message.text = "Défaite\nVotre base est tombée."
	_message.visible = true


func _on_victory(_new_faction: Faction.Kind) -> void:
	if _over:
		return
	_over = true
	_player_base.stop_spawning()
	_enemy_base_a.stop_spawning()
	_enemy_base_b.stop_spawning()
	_message.text = "Victoire !\nLa chaîne de bases est tombée."
	_message.visible = true
