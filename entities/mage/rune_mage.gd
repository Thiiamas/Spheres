extends CharacterBody3D
class_name RuneMage

## MOBA-style caster unit (phase 6 — Ryze-inspired). The three spells (A/Z/E)
## are cast at / toward the cursor. Movement was click-to-move (phase 6) but
## became direct ZQSD in phase 8.2 (Docs/Plans/phase8_foundations.md) once the
## mage started spawning mid-battle from a possessed FrontUnit — a MOBA-style
## destination click doesn't fit a unit you just swapped into on a live front
## line, and left-click was needed for "select" (swapping into another ally)
## instead. This script owns movement, HP and the cast plumbing (cooldown timers).
##
## Like the sphere, the mage never reads Input.*: the possession layer pushes
## a normalized InputContext through drive(ctx) each frame.

## The player's side — checked by EscortGate (entities/shared/escort_gate.gd)
## before retaliating, so an ally-faction tower never punishes its own
## player. Same Faction.Kind field FrontUnit/Tower/Base already carry.
@export var faction: Faction.Kind = Faction.Kind.ALLY

## Whether releasing this mage hands its body back to the front as an
## autonomous FrontUnit (PossessionSwap.release_to_front_unit, phase 8.2), or
## simply leaves it standing where it is. False for a fixed-roster body (D6/D7,
## Docs/Plans/phase9_micro_poc.md): those are pre-placed mages that go inert
## when you leave them, not units elevated from the line, so converting one on
## release would eat a body out of a roster that never refills.
@export var returns_to_front: bool = true

@export_group("Movement")
## Walk speed while a move key is held.
@export var move_speed: float = 6.0
## How fast the body turns to face its walk direction (rad/s factor).
@export var turn_speed: float = 12.0
@export var gravity: float = 18.0

@export_group("References")
## Supplies the view yaw so ZQSD is camera-relative, same convention as
## SphereController.camera — bound by CameraRig.bind_camera() on possession.
@export var camera: CameraRig

@export_group("Health")
## HP pool (entities/shared/health.gd) — take_damage forwards to it, same
## component FrontUnit and Tower use.
@export var health: Health

## Cooldowns note (9.3 playtest): all three baselines were cut by 25% from the
## phase 6 values (1.2 / 3.0 / 5.0 s). Phase 6 tuned them for a mage that only
## ever poked at a wave from a distance; the Micro loop puts the mage in contact
## with a line that walks into it, where the old rotation left long dead windows
## with nothing to do but take bites. The `spell_rate` upgrade still scales from
## whatever is authored here, so this shifts the whole curve, not just level 0.
@export_group("Spell A - RuneBolt")
## Whether this mage knows spell A at all (D5, Docs/Plans/phase9_micro_poc.md).
## One flag per spell rather than a single "minimal_mode": no spell is treated
## as the special case, and recomposing a kit later stays data instead of code.
## Read in drive() before the cast and in get_hud_lines() so the HUD never
## advertises a key that does nothing.
@export var enable_bolt: bool = true
## Line projectile cast toward the cursor ("spell_a").
@export var bolt_scene: PackedScene
@export var bolt_damage: float = 25.0
@export var bolt_speed: float = 26.0
@export var bolt_cooldown: float = 0.9
## Damage multiplier against a RuneMark-carrying enemy (spell E synergy).
@export var bolt_mark_multiplier: float = 2.0
## When the bolt hits a marked enemy, shards chain to every other marked enemy
## within this radius (and keep chaining from there).
@export var bolt_chain_radius: float = 6.0

@export_group("Spell E - RuneFlux")
## Whether this mage knows spell E (see enable_bolt).
@export var enable_flux: bool = true
## Homing projectile cast on the enemy under the cursor ("spell_e").
@export var flux_scene: PackedScene
@export var flux_speed: float = 20.0
@export var flux_cooldown: float = 2.25
## How long the attached RuneMark orbits the enemy.
@export var flux_mark_duration: float = 4.0
## Recast on an already marked enemy: the mark spreads to every enemy within
## this radius of the carrier (single ring, secondary fluxes don't re-spread).
@export var flux_spread_radius: float = 5.0

@export_group("Spell Z - RuneCage")
## Whether this mage knows spell Z (see enable_bolt). The minimal roster
## variant (rune_mage_minimal.tscn) is the one that turns this off.
@export var enable_cage: bool = true
## How long the caged enemy is pinned in place ("spell_z", point-and-click).
@export var cage_duration: float = 1.5
@export var cage_cooldown: float = 3.75

@export_group("Spell interplay")
## Launching one of A / E clears the OTHER's cooldown (9.3 playtest). Mutual and
## total: mark-then-bolt is the mage's whole damage identity, and waiting on the
## slower of the two made the pair feel like two unrelated buttons instead of a
## combo. Cage is deliberately out of it — it's crowd control, not part of the
## damage rotation, and it's disabled on the roster variant anyway.
##
## Consequence to keep in mind: alternating A, E, A, E never waits on a cooldown
## at all, so the pair is rate-limited only by having a valid E target. An export
## rather than a hardcoded reset so turning it off is a one-click A/B in the
## inspector if it proves too strong.
@export var cross_spell_reset: bool = true

@export_group("Progression")
## Upgrades this mage offers (phase 9.3), in buy-key order: index 0 is bought
## with "upgrade_1", index 1 with "upgrade_2"… Nothing else is needed to make
## buying work — Controllable._handle_upgrade_keys() already spends on any
## possessed entity that exposes this array, which is precisely what 9.2 was
## built to allow.
##
## Same contract as Base's: order here only decides which key buys what,
## apply_progression() below matches on Upgrade.id.
@export var upgrades: Array[Upgrade] = []

@export_group("Visual")
## Mesh whose emission signals possession (bright = inhabited, dim = idle).
@export var body_mesh: MeshInstance3D
@export var possessed_energy: float = 1.8
@export var idle_energy: float = 0.3

## Fired the instant hp reaches 0, before this node frees itself — lets the
## level script (e.g. levels/level2_front.gd) react (respawn, game over...).
signal died

## Driven by the possession contract (RuneMageControllable).
var is_controlled: bool = false
## The possession-contract child; set by RuneMageControllable in its _ready.
var controllable: Controllable = null

# Latest InputContext pushed via drive(). Null while not possessed.
var _ctx: InputContext = null

# Spell cooldown timers (seconds remaining; <= 0 means ready).
var _bolt_timer: float = 0.0
var _flux_timer: float = 0.0
var _cage_timer: float = 0.0

# Per-instance copy of the body material so the glow is per-mage.
var _mat: StandardMaterial3D = null

# Authored values, captured once before the first apply_progression(). Every
# apply recomputes from these rather than mutating the live stats: Progression
# re-emits `changed` on every purchase, so scaling in place would compound and
# drift from the second purchase on. Same reasoning as Base's _base_* fields.
var _base_max_hp: float = 0.0
var _base_bolt_cooldown: float = 0.0
var _base_flux_cooldown: float = 0.0
var _base_cage_cooldown: float = 0.0


func _ready() -> void:
	health.died.connect(_on_health_died)
	# Additive: keeps the default floor-collision bit, just makes the mage
	# also detectable as "the player" by an EscortGate's detection zone
	# (entities/shared/escort_gate.gd), without type-checking RuneMage there.
	collision_layer |= Faction.PLAYER_LAYER

	# Captured after Health's own _ready (children first, so max_hp is still the
	# authored value here) and before the first apply below — same order Base
	# uses. A mage instantiated mid-run therefore inherits every upgrade already
	# bought, which is what PossessionSwap.possess_front_unit relies on when it
	# scales the carried-over HP against max_hp.
	_base_max_hp = health.max_hp
	_base_bolt_cooldown = bolt_cooldown
	_base_flux_cooldown = flux_cooldown
	_base_cage_cooldown = cage_cooldown
	Progression.changed.connect(apply_progression)
	apply_progression()

	if body_mesh != null:
		var mat := body_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			_mat = mat.duplicate()
			body_mesh.material_override = _mat
	_apply_visual()


## Per-frame input, pushed by the possession layer while this mage is possessed.
func drive(ctx: InputContext) -> void:
	if not is_controlled:
		return
	_ctx = ctx
	_tick_cooldowns(ctx.delta)

	if enable_bolt and ctx.just_pressed(&"spell_a"):
		_cast_bolt(ctx)
	if enable_cage and ctx.just_pressed(&"spell_z"):
		_cast_cage(ctx)
	if enable_flux and ctx.just_pressed(&"spell_e"):
		_cast_flux(ctx)


## Let the shared camera point this mage at the right view yaw — mirrors
## SphereController.bind_camera, called by CameraRig on possession.
func bind_camera(cam: CameraRig) -> void:
	camera = cam


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	# _ctx.move_vector is re-sampled at physics rate by the possession layer
	# (InputContext.refresh_held, called from Consciousness._physics_process
	# right before this), same as SphereController.apply_roll.
	if is_controlled and _ctx != null and _ctx.move_vector != Vector2.ZERO:
		var view_yaw := camera.get_view_yaw() if camera else 0.0
		var yaw_basis := Basis(Vector3.UP, deg_to_rad(view_yaw))
		var dir := (yaw_basis * Vector3(_ctx.move_vector.x, 0.0, _ctx.move_vector.y)).normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_face_toward(dir, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


## --- Possession (driven by RuneMageControllable) ---------------------------

func set_active() -> void:
	is_controlled = true
	_apply_visual()


func set_passive() -> void:
	is_controlled = false
	_ctx = null
	velocity = Vector3.ZERO
	_apply_visual()


## --- Health -----------------------------------------------------------------

func take_damage(amount: float) -> void:
	health.take_damage(amount)


## Death mid-possession. There's no permanent mage to respawn (H3,
## Docs/Plans/phase8_foundations.md) — the body is simply gone, and no unit is
## spawned in its place. What control falls back to is a priority list (D8,
## Docs/Plans/phase9_micro_poc.md): the ally Base while it stands, then any
## surviving roster body, then nothing at all. Phase 8.2's behaviour (always
## back to the Base) is just the first rung of that list, so level2_front is
## unaffected.
##
## Deliberately does not declare defeat when the list comes up empty: "every
## controllable is dead" is a rule about the level, not about this mage, so it
## stays in the level script (D8) — this only reports its own death via `died`.
func _on_health_died() -> void:
	if controllable != null:
		Consciousness.unregister(controllable)
	var fallback := PossessionSwap.find_fallback_controllable()
	if fallback != null:
		Consciousness.request_possession(fallback)
	died.emit()
	queue_free()


## --- Progression --------------------------------------------------------------

## Recompute the upgradable stats from the authored baselines (phase 9.3).
## Called on _ready and on every Progression.changed.
##
## The mage is the second entity to implement this after Base, and deliberately
## interprets its levels its own way: `spell_rate` is one purchase that shortens
## *every* cooldown, because a caster's power is its rotation, not one spell.
## That's the point of Upgrade.per_level being a bare number — the entity, not
## the upgrade, decides what a level is worth.
##
## Must stay idempotent: recompute from _base_*, never mutate the live value.
func apply_progression() -> void:
	# ALLY-only, same reason as Base.apply_progression: the player's purchases
	# must not leak onto a hostile copy of the same scene. No enemy mage exists
	# today; this is here so adding one can't reintroduce the bug.
	if faction != Faction.Kind.ALLY:
		return
	var rate := _bonus(&"spell_rate")
	bolt_cooldown = maxf(0.05, _base_bolt_cooldown * (1.0 - rate))
	flux_cooldown = maxf(0.05, _base_flux_cooldown * (1.0 - rate))
	cage_cooldown = maxf(0.05, _base_cage_cooldown * (1.0 - rate))
	# grant_delta: raising the ceiling also heals the difference (D4), so buying
	# HP while a cube is chewing on you is felt immediately.
	health.set_max_hp(_base_max_hp + _bonus(&"mage_hp"), true)


func _bonus(id: StringName) -> float:
	return Progression.bonus_of(upgrades, id)


## --- Spells ------------------------------------------------------------------

func _tick_cooldowns(delta: float) -> void:
	_bolt_timer -= delta
	_flux_timer -= delta
	_cage_timer -= delta


## Spell A: line bolt toward the cursor. Casting stops the walk (LoL style:
## you plant to cast) and snaps the facing to the cast direction.
func _cast_bolt(ctx: InputContext) -> void:
	if bolt_scene == null or _bolt_timer > 0.0:
		return
	var dir := ctx.world_cursor - global_position
	dir.y = 0.0
	if dir.length() < 0.001:
		dir = Vector3(sin(rotation.y), 0.0, cos(rotation.y)) # fallback: facing
	dir = dir.normalized()

	_bolt_timer = bolt_cooldown
	if cross_spell_reset:
		_flux_timer = 0.0
	rotation.y = atan2(dir.x, dir.z)

	var bolt := bolt_scene.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = global_position + dir * 0.7
	if bolt is RuneBolt:
		bolt.launch(dir, bolt_damage, bolt_speed, bolt_mark_multiplier,
			bolt_chain_radius, bolt_scene)


## Spell E: point-and-click — needs an enemy under the cursor. The flux chases
## it and attaches the RuneMark (spell A then hits it for double damage).
func _cast_flux(ctx: InputContext) -> void:
	if flux_scene == null or _flux_timer > 0.0:
		return
	var target := ctx.hover_target
	if target == null:
		return # no enemy under the cursor: the cast simply doesn't go off
	_flux_timer = flux_cooldown
	if cross_spell_reset:
		_bolt_timer = 0.0
	var to := target.global_position - global_position
	rotation.y = atan2(to.x, to.z)

	var flux := flux_scene.instantiate()
	get_tree().current_scene.add_child(flux)
	flux.global_position = global_position + Vector3.UP * 0.3
	if flux is RuneFlux:
		flux.launch(target, flux_speed, flux_mark_duration,
			flux_spread_radius, true, flux_scene)


## Spell Z: point-and-click — pins the enemy under the cursor in place. The
## cage visual is built in code (RuneCage) and parented to the enemy.
func _cast_cage(ctx: InputContext) -> void:
	if _cage_timer > 0.0:
		return
	var target := ctx.hover_target
	if target == null or not target.has_method("root"):
		return # no rootable enemy under the cursor
	_cage_timer = cage_cooldown
	var to := target.global_position - global_position
	rotation.y = atan2(to.x, to.z)

	target.root(cage_duration)
	var cage := RuneCage.new()
	cage.duration = cage_duration
	target.add_child(cage)


## Cooldown lines shown by the debug HUD (duck-typed — see HUD.gd).
func get_hud_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("ZQSD: move   Left-click: switch to another ally")
	lines.append("Resources: %d" % Economy.resources)
	if enable_bolt:
		lines.append("A: bolt %s" % _cd_label(_bolt_timer))
	if enable_cage:
		lines.append("Z: cage %s" % _cd_label(_cage_timer))
	if enable_flux:
		lines.append("E: flux %s" % _cd_label(_flux_timer))
	lines.append_array(Progression.hud_lines(upgrades))
	return lines


static func _cd_label(timer: float) -> String:
	return "READY" if timer <= 0.0 else "%.1fs" % timer


## --- Internals ---------------------------------------------------------------

func _face_toward(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _apply_visual() -> void:
	if _mat == null:
		return
	_mat.emission_enabled = true
	_mat.emission = _mat.albedo_color
	_mat.emission_energy_multiplier = possessed_energy if is_controlled else idle_energy
