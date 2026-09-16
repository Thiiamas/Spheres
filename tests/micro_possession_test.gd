extends Node3D

## Headless proof of milestone 9.3 (Docs/Plans/phase9_micro_poc.md): the fixed
## roster of possessable RuneMage bodies, the two blockers the plan found, the
## third one found while implementing, and the generalized defeat rule (D8).
##
## Like possession_swap_test, this drives the possession services directly
## instead of faking a mouse click — there is no cursor in headless mode, so
## "the raycast resolved the right body" stays a manual-playtest item and
## everything downstream of it is covered here.
##
## Run with:
##   Godot_..._console --headless --path . tests/micro_possession_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

enum State {
	SETTLE, CHECK_KIT, POSSESS, CHECK_POSSESS,
	SPELL_SETUP, CAST_BOLT, CHECK_BOLT, CAST_FLUX, CHECK_FLUX,
	CHECK_ROSTER_INTACT,
	BUY, CHECK_BUY, HURT, CHECK_DEATH_TO_BASE, KILL_BASE,
	CHECK_DEATH_TO_ROSTER, CHECK_DEFEAT,
}

const SETTLE_FRAMES := 5 # let possession's deferred initial activation land
const HURT_DEADLINE := 400 # generous: the cube has to walk over and bite

var _state: State = State.SETTLE
var _frame := 0
var _level: Node3D = null
var _base: Base = null
var _roster: Array[RuneMage] = []
var _mage: RuneMage = null
var _hp_before_hit := 0.0
var _max_hp_before_buy := 0.0
var _hurt_started := 0
var _dummy: FrontUnit = null


func _process(delta: float) -> void:
	_frame += 1

	match _state:
		State.SETTLE:
			if _frame < SETTLE_FRAMES:
				return
			_level = get_node("MicroPossession")
			var c := Consciousness.active()
			_base = c.entity as Base if c != null else null
			if _base == null:
				_fail("the entity possessed at startup is not the player Base — check node order in the scene")
				return
			for child in _level.get_node("Roster").get_children():
				var mage := child as RuneMage
				if mage != null:
					_roster.append(mage)
			if _roster.size() != 3:
				_fail("expected a roster of 3 bodies, found %d" % _roster.size())
				return
			# Every body must have joined the possession pool on its own (D7) —
			# that is what makes Tab cycle the roster with no code at all.
			for mage in _roster:
				if mage.controllable == null or not (mage.controllable in Consciousness.entities):
					_fail("a roster body did not self-register with Consciousness")
					return
			if Consciousness.entities.size() != 4:
				_fail("expected 4 controllables (Base + 3 bodies), found %d"
					% Consciousness.entities.size())
				return
			print("[MicroPossessionTest] startup: PASS (Base possessed, 3 inert bodies in the pool)")

			# Autoloads outlive scenes, so start from a known slate.
			Progression.reset()
			Economy.resources = 0
			_stop_waves()
			_state = State.CHECK_KIT

		State.CHECK_KIT:
			# D5: the minimal variant keeps A and E only, and the HUD must not
			# advertise a key that does nothing.
			_mage = _roster[0]
			var hud := "\n".join(_mage.get_hud_lines())
			var kit_ok := _mage.enable_bolt and _mage.enable_flux and not _mage.enable_cage \
				and hud.contains("A: bolt") and hud.contains("E: flux") and not hud.contains("Z:")
			if not kit_ok:
				_fail("minimal kit wrong (bolt=%s flux=%s cage=%s) or Z still in the HUD"
					% [_mage.enable_bolt, _mage.enable_flux, _mage.enable_cage])
				return
			# Blocker 1: without ALLY_LAYER the select raycast passes straight
			# through the body, and no enemy AttackZone can see it either.
			if _mage.collision_layer & Faction.ALLY_LAYER == 0:
				_fail("roster body is not on ALLY_LAYER (layer=%d) — neither clickable nor attackable"
					% _mage.collision_layer)
				return
			print("[MicroPossessionTest] minimal kit A+E, body on ALLY_LAYER: PASS (layer %d)"
				% _mage.collision_layer)
			_state = State.POSSESS

		State.POSSESS:
			Consciousness.request_possession(_mage.controllable)
			_state = State.CHECK_POSSESS

		State.CHECK_POSSESS:
			var active := Consciousness.active()
			if active == null or active.entity != _mage or not _mage.is_controlled:
				_fail("request_possession did not hand control to the roster body")
				return
			# The bodies left behind must be inert, which is also what dims them.
			for other in _roster:
				if other != _mage and other.is_controlled:
					_fail("a reserve body is still marked controlled")
					return
			print("[MicroPossessionTest] possession transfer + reserve bodies inert: PASS")
			_state = State.SPELL_SETUP

		State.SPELL_SETUP:
			# A stationary punching bag: with no target_base and no hostile in
			# range, FrontUnit stands still and never reaches _try_attack, so it
			# can't chew on the mage while we probe the spell wiring.
			var scene: PackedScene = load("res://entities/front_unit/enemy_unit.tscn")
			_dummy = scene.instantiate()
			_dummy.faction = Faction.Kind.ENEMY
			get_tree().current_scene.add_child(_dummy)
			_dummy.global_position = _mage.global_position + Vector3(0, 0, 8)
			_state = State.CAST_BOLT

		State.CAST_BOLT:
			# A and Z pressed together: A must go off, Z must be a no-op.
			var ctx := InputContext.new()
			ctx.delta = delta
			ctx.world_cursor = _dummy.global_position
			ctx.hover_target = _dummy
			ctx.set_action(&"spell_a", true, true)
			ctx.set_action(&"spell_z", true, true)
			_mage.controllable.handle_input(ctx)
			_state = State.CHECK_BOLT

		State.CHECK_BOLT:
			# Z is gone for the roster body: no cage was parented to the target,
			# whatever the key press said.
			for child in _dummy.get_children():
				if child is RuneCage:
					_fail("spell Z still cages a target on the minimal variant")
					return
			var hud := _hud_lines()
			if hud.get("A: bolt", "") == "READY":
				_fail("bolt didn't go on cooldown — the cast never fired")
				return
			# Cross reset: launching A must clear E.
			if hud.get("E: flux", "") != "READY":
				_fail("launching A left flux on cooldown (%s) — cross reset not applied"
					% hud.get("E: flux", "<absent>"))
				return
			print("[MicroPossessionTest] Z inert + launching A resets flux: PASS (A %s, E %s)"
				% [hud.get("A: bolt"), hud.get("E: flux")])
			_state = State.CAST_FLUX

		State.CAST_FLUX:
			var ctx := InputContext.new()
			ctx.delta = delta
			ctx.world_cursor = _dummy.global_position
			ctx.hover_target = _dummy
			ctx.set_action(&"spell_e", true, true)
			_mage.controllable.handle_input(ctx)
			_state = State.CHECK_FLUX

		State.CHECK_FLUX:
			var hud := _hud_lines()
			if hud.get("E: flux", "") == "READY":
				_fail("flux didn't go on cooldown — the cast never fired")
				return
			# The other direction of the reset.
			if hud.get("A: bolt", "") != "READY":
				_fail("launching E left bolt on cooldown (%s) — cross reset not applied"
					% hud.get("A: bolt", "<absent>"))
				return
			print("[MicroPossessionTest] launching E resets bolt: PASS (E %s, A %s)"
				% [hud.get("E: flux"), hud.get("A: bolt")])
			_dummy.queue_free()
			_state = State.CHECK_ROSTER_INTACT

		State.CHECK_ROSTER_INTACT:
			# Third blocker: leaving a roster body must not consume it. Every
			# click-driven switch runs release_current_mage first, which for a
			# phase-8.2 mage converts the body into a FrontUnit — that would
			# permanently shrink a roster that never refills.
			PossessionSwap.release_current_mage(get_tree())
			if not is_instance_valid(_mage) or _mage.is_queued_for_deletion():
				_fail("leaving a roster body destroyed it — returns_to_front guard not honoured")
				return
			if not get_tree().get_nodes_in_group(&"front_ally").is_empty():
				_fail("leaving a roster body spawned an ally FrontUnit in its place")
				return
			print("[MicroPossessionTest] roster body survives being left: PASS")
			_state = State.BUY

		State.BUY:
			# The real genericity test for 9.2: the mage buys through the same
			# keys as the Base, with nothing written on the input side.
			Economy.add(50)
			_max_hp_before_buy = _mage.health.max_hp
			var ctx := InputContext.new()
			ctx.delta = delta
			ctx.set_action(&"upgrade_1", true, true)
			_mage.controllable.handle_input(ctx)
			_state = State.CHECK_BUY

		State.CHECK_BUY:
			var up: Upgrade = _mage.upgrades[0]
			if Progression.level_of(up.id) != 1:
				_fail("upgrade_1 did not buy the mage's first upgrade (level=%d)"
					% Progression.level_of(up.id))
				return
			if _mage.health.max_hp <= _max_hp_before_buy:
				_fail("upgrade bought but apply_progression left max_hp at %.0f"
					% _mage.health.max_hp)
				return
			print("[MicroPossessionTest] mage upgrade via the shared buy key: PASS (%s, hp ceiling %.0f -> %.0f)"
				% [up.id, _max_hp_before_buy, _mage.health.max_hp])
			_spawn_biter()
			_hp_before_hit = _mage.health.hp
			_hurt_started = _frame
			_state = State.HURT

		State.HURT:
			# Blocker 2: before this milestone nothing in a Tower-less scene
			# could damage the possessed player at all.
			if _mage.health.hp < _hp_before_hit:
				print("[MicroPossessionTest] enemy damages the possessed mage: PASS (%.0f -> %.0f hp)"
					% [_hp_before_hit, _mage.health.hp])
				_mage.take_damage(99999.0)
				_state = State.CHECK_DEATH_TO_BASE
				return
			if _frame - _hurt_started > HURT_DEADLINE:
				_fail("no damage taken in %d frames — the mage is still invulnerable" % HURT_DEADLINE)
			return

		State.CHECK_DEATH_TO_BASE:
			# D8, first rung: the Base is alive, so it inherits control and the
			# run continues.
			var active := Consciousness.active()
			if active == null or active.entity != _base:
				_fail("dying in possession did not hand control back to the live Base")
				return
			if _level.is_defeated():
				_fail("defeat declared while the Base and 2 bodies are still alive")
				return
			print("[MicroPossessionTest] death in possession -> live Base, run continues: PASS")
			_state = State.KILL_BASE

		State.KILL_BASE:
			_base.take_damage(99999.0)
			_state = State.CHECK_DEATH_TO_ROSTER

		State.CHECK_DEATH_TO_ROSTER:
			if _level.is_defeated():
				_fail("defeat declared with 2 roster bodies still standing")
				return
			# D8, second rung: with the Base gone, control must fall to a
			# surviving body rather than to the corpse of the Base.
			_mage = _roster[1]
			Consciousness.request_possession(_mage.controllable)
			_mage.take_damage(99999.0)
			var active := Consciousness.active()
			if active == null or active.entity != _roster[2]:
				_fail("with the Base dead, control did not fall to the surviving body (active=%s)"
					% [active.entity if active else "<none>"])
				return
			print("[MicroPossessionTest] Base dead -> control falls to a surviving body: PASS")
			_state = State.CHECK_DEFEAT

		State.CHECK_DEFEAT:
			# Last rung: nothing left to inhabit.
			_roster[2].take_damage(99999.0)
			if not _level.is_defeated():
				_fail("Base and whole roster dead but no defeat declared")
				return
			print("[MicroPossessionTest] defeat only once Base AND roster are gone: PASS")
			get_tree().quit(0)


## The mage's cooldown lines as {"A: bolt": "READY"|"0.9s", ...}. Reads the HUD
## rather than the private timers: what the player is told is the contract, and
## a spell whose cooldown moved without the HUD following would be a bug too.
func _hud_lines() -> Dictionary:
	var out := {}
	for line in _mage.get_hud_lines():
		var parts := line.split(" ", false)
		if parts.size() >= 3 and parts[0].length() == 2 and parts[0].ends_with(":"):
			out["%s %s" % [parts[0], parts[1]]] = parts[2]
	return out


## A single enemy walking past the possessed mage toward a point behind it.
## Deliberately not aimed *at* the mage: FrontUnit._current_target() only ever
## picks a Tower or a hostile FrontUnit, so a cube never hunts the mage — it
## bites it in passing, which is exactly the situation the Micro scene creates.
func _spawn_biter() -> void:
	var decoy := Node3D.new()
	add_child(decoy)
	decoy.global_position = _mage.global_position + Vector3(0, 0, -6)

	var scene: PackedScene = load("res://entities/front_unit/enemy_unit.tscn")
	var enemy: FrontUnit = scene.instantiate()
	enemy.faction = Faction.Kind.ENEMY
	enemy.target_base = decoy
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _mage.global_position + Vector3(0, 0, 2.0)


## No waves and no leftovers: a stray cube would pay the player mid-test or bite
## a body the test still expects to be alive.
func _stop_waves() -> void:
	for group in [&"front_ally", &"front_enemy"]:
		for unit in get_tree().get_nodes_in_group(group):
			unit.queue_free()
	_level.get_node("PlayerBase").stop_spawning()
	_level.get_node("EnemyBase").stop_spawning()


func _fail(reason: String) -> void:
	print("[MicroPossessionTest] FAIL: %s" % reason)
	get_tree().quit(1)
