extends Node3D

## Headless proof of phase 11.1 (Docs/Plans/phase11_macro_poc.md): the
## two-base capture chain. Boots macro_capture.tscn and asserts:
##
## - a non-capturable Base (every scene but this one) keeps exactly its old
##   H5 behaviour — explicit non-regression, since capturable branches inside
##   the same _on_health_died() that used to be unconditional;
## - EnemyBaseA at 0 HP flips faction, comes back to full HP, recomputes
##   unit_scene/layers/tint for its new side, emits `captured` (not `died`),
##   and resumes spawning (D1);
## - the level script relays the offensive on that signal: EnemyBaseA and
##   PlayerBase both retarget onto EnemyBaseB/TowerB (D4);
## - TowerB still gates EnemyBaseB exactly as before the relay — no shortcut
##   opened by capturing EnemyBaseA (D3), proven with real travel time rather
##   than asserted from the wiring alone;
## - driving a Base right after its own capture doesn't crash;
## - EnemyBaseB captured -> victory; PlayerBase captured -> defeat;
##   EnemyBaseA captured -> neither (just the relay message).
##
## Run with:
##
##   godot --headless res://tests/macro_capture_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

enum State {
	SPAWN_REGRESSION_BASE,
	REGRESSION_CHECK,
	SETTLE,
	KILL_BASE_A,
	CHECK_BASE_A_CAPTURED,
	DRIVE_BASE_A,
	AWAIT_TOWER_B_ENGAGED,
	FINISH_TOWER_B,
	AWAIT_BASE_B_DAMAGED,
	CHECK_VICTORY,
	SETUP_DEFEAT_INSTANCE,
	CHECK_DEFEAT,
	DONE,
}

const TOWER_B_ENGAGE_TIMEOUT := 30.0 # real travel, two full-length legs
const BASE_B_DAMAGE_TIMEOUT := 15.0

var _state: State = State.SPAWN_REGRESSION_BASE
var _frame := 0
var _elapsed := 0.0

var _plain_base: Base = null
var _plain_died_seen := false
var _plain_captured_seen := false

var _player_base: Base = null
var _enemy_base_a: Base = null
var _enemy_base_b: Base = null
var _player_tower: Tower = null
var _tower_a: Tower = null
var _tower_b: Tower = null
var _message: Label = null

var _base_a_captured := false
var _base_b_captured := false
var _player_base_captured := false
var _defeat_level: Node3D = null


func _process(delta: float) -> void:
	_frame += 1
	_elapsed += delta

	match _state:
		State.SPAWN_REGRESSION_BASE:
			# Standalone instance, outside the macro scene entirely: default
			# capturable = false must still behave exactly like H5 (phase 9.1)
			# — dies for good, `died` emitted, never `captured`. Needs a couple
			# of frames after add_child() for its own _ready() (which connects
			# health.died) to actually run before we can rely on it.
			if _frame == 1:
				var base_scene: PackedScene = load("res://entities/base/base.tscn")
				_plain_base = base_scene.instantiate() as Base
				add_child(_plain_base)
				_plain_base.died.connect(func() -> void: _plain_died_seen = true)
				_plain_base.captured.connect(func(_f: Faction.Kind) -> void: _plain_captured_seen = true)
				return
			if _frame < 4:
				return
			_state = State.REGRESSION_CHECK

		State.REGRESSION_CHECK:
			_plain_base.health.take_damage(9999.0)
			if not _plain_died_seen:
				_fail("non-capturable Base: `died` never emitted at 0 HP (H5 regression)")
				return
			if _plain_captured_seen:
				_fail("non-capturable Base emitted `captured` — capturable=false must be a no-op")
				return
			# _defeated (private) is what gates further drive() input — proxy it
			# through the public contract instead of reaching into the field:
			# a defeated non-capturable Base must ignore damage from here on.
			var hp_before := _plain_base.health.hp
			_plain_base.take_damage(10.0)
			if _plain_base.health.hp != hp_before:
				_fail("non-capturable Base kept taking damage after death (H5 regression, _defeated not gating take_damage)")
				return
			print("[MacroCaptureTest] non-capturable Base keeps H5 behaviour: PASS")
			_plain_base.queue_free()
			_frame = 0
			_state = State.SETTLE

		State.SETTLE:
			if _frame < 5:
				return
			_player_base = get_node("MacroCapture/PlayerBase") as Base
			_enemy_base_a = get_node("MacroCapture/EnemyBaseA") as Base
			_enemy_base_b = get_node("MacroCapture/EnemyBaseB") as Base
			_player_tower = get_node("MacroCapture/PlayerTower") as Tower
			_tower_a = get_node("MacroCapture/TowerA") as Tower
			_tower_b = get_node("MacroCapture/TowerB") as Tower
			_message = get_node("MacroCapture/UI/MessageLabel") as Label
			if _player_base == null or _enemy_base_a == null or _enemy_base_b == null \
					or _player_tower == null or _tower_a == null or _tower_b == null:
				_fail("PlayerBase/EnemyBaseA/EnemyBaseB/PlayerTower/TowerA/TowerB missing or wrong type")
				return
			_enemy_base_a.captured.connect(func(_f: Faction.Kind) -> void: _base_a_captured = true)
			_enemy_base_b.captured.connect(func(_f: Faction.Kind) -> void: _base_b_captured = true)
			_player_base.captured.connect(func(_f: Faction.Kind) -> void: _player_base_captured = true)

			# D5 (revised): the backline base must be silent until A falls.
			if not (_enemy_base_b.get_node("WaveTimer") as Timer).is_stopped():
				_fail("EnemyBaseB's wave timer is running at start — backline base must not spawn")
				return
			if not get_tree().get_nodes_in_group(Faction.group_name(Faction.Kind.ENEMY)).all(
					func(u: Node) -> bool: return _enemy_base_b.global_position.distance_to((u as Node3D).global_position) > 5.0):
				_fail("a unit spawned at EnemyBaseB before EnemyBaseA fell")
				return
			_elapsed = 0.0
			_state = State.KILL_BASE_A

		State.KILL_BASE_A:
			# Direct to Health, same shortcut meso_siege_test uses — TowerA gating
			# EnemyBaseA until it falls is already proven generically by that
			# test; what's new here is what happens AFTER the capture, not
			# before it. TowerA is felled too (not just EnemyBaseA): in real
			# play a Base isn't mordable until its Tower falls (Docs/front/
			# tower.md), so leaving TowerA standing would physically jam the
			# lane for the relayed wave heading past it toward TowerB/EnemyBaseB.
			if not _tower_a.health.is_dead():
				_tower_a.health.take_damage(9999.0)
			_enemy_base_a.health.take_damage(9999.0)
			_state = State.CHECK_BASE_A_CAPTURED

		State.CHECK_BASE_A_CAPTURED:
			if not _base_a_captured:
				_fail("EnemyBaseA's death never emitted `captured`")
				return
			if _enemy_base_a.faction != Faction.Kind.ALLY:
				_fail("EnemyBaseA didn't flip to ALLY on capture")
				return
			if _enemy_base_a.health.hp != _enemy_base_a.health.max_hp:
				_fail("EnemyBaseA's HP wasn't restored to max on capture")
				return
			if _enemy_base_a.unit_scene != _enemy_base_a.ally_unit_scene:
				_fail("EnemyBaseA's unit_scene doesn't match its new (ALLY) faction")
				return
			var hull := _enemy_base_a.get_node("Hull") as StaticBody3D
			if hull.collision_layer != Faction.physics_layer(Faction.Kind.ALLY):
				_fail("EnemyBaseA's Hull layer wasn't recomputed for its new faction")
				return
			var goal_zone := _enemy_base_a.get_node("GoalZone") as Area3D
			if goal_zone.collision_mask != Faction.opposing_physics_layer(Faction.Kind.ALLY):
				_fail("EnemyBaseA's GoalZone mask wasn't recomputed for its new faction")
				return
			var wave_timer := _enemy_base_a.get_node("WaveTimer") as Timer
			if wave_timer.is_stopped():
				_fail("EnemyBaseA's spawning didn't resume after capture")
				return
			if _enemy_base_a.advance_target != _enemy_base_b or _enemy_base_a.advance_target_tower != _tower_b:
				_fail("EnemyBaseA wasn't recabled onto EnemyBaseB/TowerB after its own capture (D4 relay)")
				return
			if not (_player_base.get_node("WaveTimer") as Timer).is_stopped():
				_fail("PlayerBase kept spawning once EnemyBaseA became the player's front (must be backline)")
				return
			if not _message.text.begins_with("Front A capturé"):
				_fail("level script didn't show the relay message on EnemyBaseA's capture")
				return
			if _base_b_captured or _player_base_captured:
				_fail("EnemyBaseA's capture also fired the victory/defeat path — the relay must be silent")
				return
			if (_enemy_base_b.get_node("WaveTimer") as Timer).is_stopped():
				_fail("EnemyBaseB didn't wake up after EnemyBaseA's capture")
				return
			# Its own wave is orthogonal to what follows (TowerB's gate) — mute it
			# again so the run stays deterministic.
			_enemy_base_b.stop_spawning()
			print("[MacroCaptureTest] EnemyBaseA capture: faction/HP/layers/unit_scene/spawn/retarget: PASS")
			_state = State.DRIVE_BASE_A

		State.DRIVE_BASE_A:
			# Sub-task 3: driving a Base right after its own capture must not crash.
			var ctx := InputContext.new()
			ctx.delta = 0.016
			_enemy_base_a.drive(ctx)
			print("[MacroCaptureTest] driving a just-captured Base doesn't crash: PASS")
			_elapsed = 0.0
			_state = State.AWAIT_TOWER_B_ENGAGED

		State.AWAIT_TOWER_B_ENGAGED:
			if _enemy_base_b.health.hp < _enemy_base_b.health.max_hp:
				_fail("EnemyBaseB took damage while TowerB is still alive — capturing EnemyBaseA opened a shortcut (D3)")
				return
			if _tower_b.health.hp < _tower_b.health.max_hp:
				print("[MacroCaptureTest] the relayed offensive engaged TowerB, EnemyBaseB untouched: PASS")
				_state = State.FINISH_TOWER_B
				return
			if _elapsed > TOWER_B_ENGAGE_TIMEOUT:
				_fail("no damage reached TowerB within %.0fs of EnemyBaseA's capture" % TOWER_B_ENGAGE_TIMEOUT)
				return

		State.FINISH_TOWER_B:
			if is_instance_valid(_tower_b) and not _tower_b.health.is_dead():
				_tower_b.health.take_damage(9999.0)
			# Same reasoning as meso_siege_test's fresh_biter: the ongoing siege
			# may not have survived TowerB's own retaliation, so plant a fresh
			# ally directly on EnemyBaseB rather than depending on it.
			var ally_scene: PackedScene = load("res://entities/front_unit/ally_unit.tscn")
			var fresh_biter := ally_scene.instantiate()
			fresh_biter.target_base = _enemy_base_b
			get_tree().current_scene.add_child(fresh_biter)
			fresh_biter.global_position = _enemy_base_b.global_position + Vector3(0, 0.5, -2.2)
			_elapsed = 0.0
			_state = State.AWAIT_BASE_B_DAMAGED

		State.AWAIT_BASE_B_DAMAGED:
			if _enemy_base_b.health.hp < _enemy_base_b.health.max_hp:
				print("[MacroCaptureTest] TowerB down -> an allied unit reached and damaged EnemyBaseB: PASS")
				_state = State.CHECK_VICTORY
				return
			if _elapsed > BASE_B_DAMAGE_TIMEOUT:
				_fail("TowerB destroyed, but no unit reached EnemyBaseB within %.0fs" % BASE_B_DAMAGE_TIMEOUT)
				return

		State.CHECK_VICTORY:
			_enemy_base_b.health.take_damage(9999.0)
			if not _base_b_captured:
				_fail("EnemyBaseB's death never emitted `captured`")
				return
			if not _message.text.begins_with("Victoire"):
				_fail("level script didn't declare victory on EnemyBaseB's capture (D4, last of the chain)")
				return
			print("[MacroCaptureTest] EnemyBaseB captured -> victory (D3/D4): PASS")
			_frame = 0
			_state = State.SETUP_DEFEAT_INSTANCE

		State.SETUP_DEFEAT_INSTANCE:
			# Fresh instance, isolated from the finished run above — proves the
			# defeat path independently rather than reusing a scene the level
			# script may already consider over. Needs a couple of settle frames
			# (same reason as the regression Base above) before its children's
			# _ready() can be relied on.
			if _frame == 1:
				var level_scene: PackedScene = load("res://gameplay_loop/macro/macro_capture.tscn")
				_defeat_level = level_scene.instantiate()
				add_child(_defeat_level)
				return
			if _frame < 4:
				return
			var fresh_player_base := _defeat_level.get_node("PlayerBase") as Base
			_message = _defeat_level.get_node("UI/MessageLabel") as Label
			fresh_player_base.captured.connect(func(_f: Faction.Kind) -> void: _player_base_captured = true)
			_player_base_captured = false
			fresh_player_base.health.take_damage(9999.0)
			_state = State.CHECK_DEFEAT

		State.CHECK_DEFEAT:
			if not _player_base_captured:
				_fail("PlayerBase's death never emitted `captured`")
				return
			if not _message.text.begins_with("Défaite"):
				_fail("level script didn't declare defeat on PlayerBase's capture (D3, symmetric with the enemy side)")
				return
			print("[MacroCaptureTest] PlayerBase captured -> defeat (D3), independently: PASS")
			get_tree().quit(0)
			_state = State.DONE


func _fail(reason: String) -> void:
	print("[MacroCaptureTest] FAIL: %s" % reason)
	get_tree().quit(1)
