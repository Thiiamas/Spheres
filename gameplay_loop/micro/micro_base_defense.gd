extends Node3D

## Micro-loop POC, milestone 9.1 (Docs/Plans/phase9_micro_poc.md): the player
## possesses their Base and nothing else, while the enemy Base sends waves of
## FrontUnit down a flat lane at it. Killing those units pays the Economy
## (LootOnDeath, phase 8.1); letting them reach the Base costs HP, and losing
## all of it ends the run.
##
## No Tower (that's the Meso tier, phase 10) and no allied wave — PlayerBase
## deliberately has no unit_scene, so Base's own spawner no-ops for it.
##
## Kept as its own scene rather than an edit of level2_front.tscn so both the
## phase 7 front prototype and each Micro milestone stay independently
## playable (see "Organisation des scènes" in the phase 9 plan).

@onready var _player_base: Base = $PlayerBase
@onready var _enemy_base: Base = $EnemyBase
@onready var _message: Label = $UI/MessageLabel


func _ready() -> void:
	# Wired here, not as a .tscn NodePath export: same reasoning as
	# level2_front.gd — the bases only need each other's position.
	_enemy_base.advance_target = _player_base
	_player_base.died.connect(_on_player_base_died)

	# Base's _ready runs before this one (children before parent), so seeding
	# the opening wave here means it advances toward a target that's already
	# assigned, instead of waiting a full wave_interval.
	_enemy_base.spawn_wave_now()


func _on_player_base_died() -> void:
	_enemy_base.stop_spawning()
	_message.text = "Défaite\nLa base est tombée."
	_message.visible = true
