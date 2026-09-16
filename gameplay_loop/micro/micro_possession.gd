extends Node3D

## Micro-loop POC, milestone 9.3 (Docs/Plans/phase9_micro_poc.md): the 9.1/9.2
## base defense, plus a fixed roster of pre-placed RuneMage bodies the player
## can move into. A copy of micro_base_defense.tscn rather than an edit of it,
## so each milestone stays independently playable.
##
## The roster is finite and never refills (D6): each body lost is lost for good,
## which is what gives the generalized defeat rule (D8) its teeth — every death
## costs a permanent option rather than just some HP.
##
## Nothing here spawns or wires the bodies. A RuneMage dropped in the scene
## joins the possession pool by itself (RuneMageControllable._ready), goes inert
## and dims while unpossessed, and Tab already cycles through the whole roster.
## This script only owns the one rule that is genuinely the level's: when the
## run is lost.

@onready var _player_base: Base = $PlayerBase
@onready var _enemy_base: Base = $EnemyBase
@onready var _roster_root: Node3D = $Roster
@onready var _message: Label = $UI/MessageLabel

## The pre-placed bodies, captured once at load. Entries stay in the array after
## they die (they queue_free themselves) — is_instance_valid below filters them.
var _roster: Array[RuneMage] = []
## Set once the defeat rule below fires; see is_defeated().
var _defeated: bool = false


func _ready() -> void:
	# Wired here, not as a .tscn NodePath export: same reasoning as
	# micro_base_defense.gd — the bases only need each other's position.
	_enemy_base.advance_target = _player_base

	# D8: defeat is "the player has nothing left to inhabit", so every
	# controllable's death is the same event as far as this level is concerned.
	# 9.1's rule (Base.died = game over) is the special case where the roster
	# happens to be empty, not a separate mechanism.
	_player_base.died.connect(_on_controllable_lost)
	for child in _roster_root.get_children():
		var mage := child as RuneMage
		if mage == null:
			continue
		_roster.append(mage)
		mage.died.connect(_on_controllable_lost)

	# Base's _ready runs before this one (children before parent), so seeding
	# the opening wave here means it advances toward a target that's already
	# assigned, instead of waiting a full wave_interval.
	_enemy_base.spawn_wave_now()


func _on_controllable_lost() -> void:
	if not _all_controllables_lost():
		return
	_defeated = true
	_enemy_base.stop_spawning()
	_message.text = "Défaite\nPlus aucun corps à habiter."
	_message.visible = true


## Whether the run is over. Exposed so the headless test asserts on the level's
## own verdict rather than on whether a Label happens to be visible.
func is_defeated() -> bool:
	return _defeated


## True once the Base and every roster body are dead. Safe to call from inside a
## `died` handler: Health flips its own _dead flag before emitting, and the
## dying mage's queue_free() only takes effect at the end of the frame, so the
## entity that triggered this already reads as dead here.
func _all_controllables_lost() -> bool:
	if not _player_base.health.is_dead():
		return false
	for mage in _roster:
		if is_instance_valid(mage) and not mage.health.is_dead():
			return false
	return true
