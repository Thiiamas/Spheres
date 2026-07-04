extends CharacterBody3D
class_name RuneMage

## MOBA-style caster unit (phase 6 — Ryze-inspired). Controlled entirely with
## the mouse: right-click ("move_click") walks toward the clicked ground point,
## LoL style, and the three spells (A/Z/E) are cast at / toward the cursor.
## Spells arrive in sub-phases 6.3-6.5; this script owns movement, HP and the
## cast plumbing (cooldown timers).
##
## Like the sphere, the mage never reads Input.*: the possession layer pushes
## a normalized InputContext through drive(ctx) each frame.

@export_group("Movement")
## Walk speed toward the clicked destination.
@export var move_speed: float = 6.0
## Distance at which the destination counts as reached.
@export var stop_distance: float = 0.15
## How fast the body turns to face its walk direction (rad/s factor).
@export var turn_speed: float = 12.0
@export var gravity: float = 18.0

@export_group("Health")
@export var max_hp: float = 100.0
## Optional floating health bar (HPBar3D) shown above the mage.
@export var hp_bar: Node3D

@export_group("Spell A - RuneBolt")
## Line projectile cast toward the cursor ("spell_a").
@export var bolt_scene: PackedScene
@export var bolt_damage: float = 25.0
@export var bolt_speed: float = 26.0
@export var bolt_cooldown: float = 1.2
## Damage multiplier against a RuneMark-carrying enemy (spell E synergy).
@export var bolt_mark_multiplier: float = 2.0

@export_group("Spell E - RuneFlux")
## Homing projectile cast on the enemy under the cursor ("spell_e").
@export var flux_scene: PackedScene
@export var flux_speed: float = 20.0
@export var flux_cooldown: float = 3.0
## How long the attached RuneMark orbits the enemy.
@export var flux_mark_duration: float = 4.0

@export_group("Spell Z - RuneCage")
## How long the caged enemy is pinned in place ("spell_z", point-and-click).
@export var cage_duration: float = 1.5
@export var cage_cooldown: float = 5.0

@export_group("Visual")
## Mesh whose emission signals possession (bright = inhabited, dim = idle).
@export var body_mesh: MeshInstance3D
@export var possessed_energy: float = 1.8
@export var idle_energy: float = 0.3

## Current hit points. Reaches 0 -> the mage is destroyed.
var hp: float = 100.0
## Driven by the possession contract (RuneMageControllable).
var is_controlled: bool = false
## The possession-contract child; set by RuneMageControllable in its _ready.
var controllable: Controllable = null

# Click-to-move destination (world space, XZ plane).
var _destination: Vector3 = Vector3.ZERO
var _has_destination: bool = false

# Latest InputContext pushed via drive(). Null while not possessed.
var _ctx: InputContext = null

# Spell cooldown timers (seconds remaining; <= 0 means ready).
var _bolt_timer: float = 0.0
var _flux_timer: float = 0.0
var _cage_timer: float = 0.0

# Per-instance copy of the body material so the glow is per-mage.
var _mat: StandardMaterial3D = null


func _ready() -> void:
	hp = max_hp
	_update_hp_bar()
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

	# LoL movement: right-click sets (and, held, keeps updating) the destination.
	if ctx.pressed(&"move_click"):
		_destination = ctx.world_cursor
		_has_destination = true

	if ctx.just_pressed(&"spell_a"):
		_cast_bolt(ctx)
	if ctx.just_pressed(&"spell_z"):
		_cast_cage(ctx)
	if ctx.just_pressed(&"spell_e"):
		_cast_flux(ctx)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	if is_controlled and _has_destination:
		var to := _destination - global_position
		to.y = 0.0
		if to.length() <= stop_distance:
			_has_destination = false
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var dir := to.normalized()
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
	_has_destination = false
	_ctx = null
	velocity = Vector3.ZERO
	_apply_visual()


## --- Health -----------------------------------------------------------------

func take_damage(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)
	_update_hp_bar()
	if hp <= 0.0:
		_die()


func _die() -> void:
	if controllable != null:
		Consciousness.unregister(controllable)
	queue_free()


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
	_has_destination = false
	rotation.y = atan2(dir.x, dir.z)

	var bolt := bolt_scene.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = global_position + dir * 0.7
	if bolt is RuneBolt:
		bolt.launch(dir, bolt_damage, bolt_speed, bolt_mark_multiplier)


## Spell E: point-and-click — needs an enemy under the cursor. The flux chases
## it and attaches the RuneMark (spell A then hits it for double damage).
func _cast_flux(ctx: InputContext) -> void:
	if flux_scene == null or _flux_timer > 0.0:
		return
	var target := ctx.hover_target
	if target == null:
		return # no enemy under the cursor: the cast simply doesn't go off
	_flux_timer = flux_cooldown
	_has_destination = false
	var to := target.global_position - global_position
	rotation.y = atan2(to.x, to.z)

	var flux := flux_scene.instantiate()
	get_tree().current_scene.add_child(flux)
	flux.global_position = global_position + Vector3.UP * 0.3
	if flux is RuneFlux:
		flux.launch(target, flux_speed, flux_mark_duration)


## Spell Z: point-and-click — pins the enemy under the cursor in place. The
## cage visual is built in code (RuneCage) and parented to the enemy.
func _cast_cage(ctx: InputContext) -> void:
	if _cage_timer > 0.0:
		return
	var target := ctx.hover_target
	if target == null or not target.has_method("root"):
		return # no rootable enemy under the cursor
	_cage_timer = cage_cooldown
	_has_destination = false
	var to := target.global_position - global_position
	rotation.y = atan2(to.x, to.z)

	target.root(cage_duration)
	var cage := RuneCage.new()
	cage.duration = cage_duration
	target.add_child(cage)


## Cooldown lines shown by the debug HUD (duck-typed — see HUD.gd).
func get_hud_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("Right-click: move")
	lines.append("A: bolt %s" % _cd_label(_bolt_timer))
	lines.append("Z: cage %s" % _cd_label(_cage_timer))
	lines.append("E: flux %s" % _cd_label(_flux_timer))
	return lines


static func _cd_label(timer: float) -> String:
	return "READY" if timer <= 0.0 else "%.1fs" % timer


## --- Internals ---------------------------------------------------------------

func _face_toward(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _update_hp_bar() -> void:
	if hp_bar and hp_bar.has_method("update_bar"):
		hp_bar.update_bar(hp, max_hp)


func _apply_visual() -> void:
	if _mat == null:
		return
	_mat.emission_enabled = true
	_mat.emission = _mat.albedo_color
	_mat.emission_energy_multiplier = possessed_energy if is_controlled else idle_energy
