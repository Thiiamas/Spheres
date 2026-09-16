extends Node3D

## Headless proof of phase 10.2 (Docs/Plans/phase10_meso_poc.md): boots
## meso_siege.tscn and asserts the Tower actually gates the lane rather than
## assuming the phase 7 behaviour (Docs/front/tower.md) still holds once
## composed into a fresh scene — a real allied wave must engage and damage
## the enemy Tower WITHOUT the enemy Base taking any damage while that Tower
## still stands, then, once the Tower falls, the same wave must go on to
## reach and damage the Base behind it. Also proves D4/D5: enemy Tower dead
## -> victory; the player's own Tower OR Base dying -> defeat, independently
## of each other. Run with:
##
##   godot --headless res://tests/meso_siege_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

enum State {
	SETTLE, AWAIT_TOWER_ENGAGED, FINISH_TOWER, AWAIT_BASE_DAMAGED,
	CHECK_VICTORY, KILL_PLAYER_TOWER, CHECK_LOST_TOWER, KILL_PLAYER_BASE,
	CHECK_LOST_BASE, DONE,
}

const SETTLE_FRAMES := 5
const TOWER_ENGAGE_TIMEOUT := 20.0 # real travel from PlayerBase (~24 units)
const BASE_DAMAGE_TIMEOUT := 15.0 # shorter hop, tower to base

var _state: State = State.SETTLE
var _frame := 0
var _elapsed := 0.0
var _player_base: Base = null
var _enemy_base: Base = null
var _player_tower: Tower = null
var _enemy_tower: Tower = null
var _player_won := false
var _lost_via_tower := false
var _lost_via_base := false


func _process(delta: float) -> void:
	_frame += 1
	_elapsed += delta

	match _state:
		State.SETTLE:
			if _frame < SETTLE_FRAMES:
				return
			_player_base = get_node("MesoSiege/PlayerBase") as Base
			_enemy_base = get_node("MesoSiege/EnemyBase") as Base
			_player_tower = get_node("MesoSiege/PlayerTower") as Tower
			_enemy_tower = get_node("MesoSiege/EnemyTower") as Tower
			if _player_base == null or _enemy_base == null \
					or _player_tower == null or _enemy_tower == null:
				_fail("PlayerBase/EnemyBase/PlayerTower/EnemyTower missing or wrong type")
				return
			_enemy_tower.died.connect(func() -> void: _player_won = true)
			_player_tower.died.connect(func() -> void: _lost_via_tower = true)
			_player_base.died.connect(func() -> void: _lost_via_base = true)

			# Isolate the direction under test: only the player's own wave
			# should be marching this run, so nothing on the enemy side can
			# damage the player's Tower/Base and contaminate the sequence below.
			_enemy_base.stop_spawning()
			for unit in get_tree().get_nodes_in_group(&"front_enemy"):
				unit.queue_free()
			_elapsed = 0.0
			_state = State.AWAIT_TOWER_ENGAGED

		State.AWAIT_TOWER_ENGAGED:
			if _enemy_base.health.hp < _enemy_base.health.max_hp:
				_fail("enemy Base took damage while its Tower is still alive — the Tower isn't gating the lane")
				return
			if _enemy_tower.health.hp < _enemy_tower.health.max_hp:
				print("[MesoSiegeTest] allied wave engaged the enemy Tower, Base untouched: PASS")
				_state = State.FINISH_TOWER
				return
			if _elapsed > TOWER_ENGAGE_TIMEOUT:
				_fail("no allied damage reached the enemy Tower within %.0fs" % TOWER_ENGAGE_TIMEOUT)
				return

		State.FINISH_TOWER:
			# Direct to Health, bypassing Tower.take_damage's escort gate — the
			# gate itself is phase 7 behaviour, not what this test is proving.
			# Skipped if the ongoing siege already finished it off.
			if is_instance_valid(_enemy_tower) and not _enemy_tower.health.is_dead():
				_enemy_tower.health.take_damage(9999.0)
			_elapsed = 0.0
			_state = State.AWAIT_BASE_DAMAGED

		State.AWAIT_BASE_DAMAGED:
			if _enemy_base.health.hp < _enemy_base.health.max_hp:
				print("[MesoSiegeTest] Tower down -> the same wave reached and damaged the Base: PASS")
				_state = State.CHECK_VICTORY
				return
			if _elapsed > BASE_DAMAGE_TIMEOUT:
				_fail("Tower destroyed, but no unit reached the enemy Base within %.0fs" % BASE_DAMAGE_TIMEOUT)
				return

		State.CHECK_VICTORY:
			if not _player_won:
				_fail("enemy Tower's death never emitted `died` (or the level never observed it)")
				return
			print("[MesoSiegeTest] enemy Tower destroyed -> victory (D4): PASS")
			_state = State.KILL_PLAYER_TOWER

		State.KILL_PLAYER_TOWER:
			_player_tower.health.take_damage(9999.0)
			_state = State.CHECK_LOST_TOWER

		State.CHECK_LOST_TOWER:
			if not _lost_via_tower:
				_fail("player Tower's death never emitted `died`")
				return
			if _lost_via_base:
				_fail("player Base reported dead just from killing the player Tower — the two defeat conditions aren't independent")
				return
			print("[MesoSiegeTest] player Tower destroyed -> defeat (D5), independently: PASS")
			_state = State.KILL_PLAYER_BASE

		State.KILL_PLAYER_BASE:
			_player_base.take_damage(9999.0)
			_state = State.CHECK_LOST_BASE

		State.CHECK_LOST_BASE:
			if not _lost_via_base:
				_fail("player Base's death never emitted `died`")
				return
			print("[MesoSiegeTest] player Base destroyed -> defeat (D5), independently: PASS")
			get_tree().quit(0)
			_state = State.DONE


func _fail(reason: String) -> void:
	print("[MesoSiegeTest] FAIL: %s" % reason)
	get_tree().quit(1)
