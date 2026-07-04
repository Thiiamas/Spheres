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


## --- Spell plumbing (spells land in 6.3-6.5) --------------------------------

func _tick_cooldowns(_delta: float) -> void:
	pass


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
