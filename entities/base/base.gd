extends Node3D
class_name Base

## League-of-Legends-style wave spawner (Docs/Plans/phase7_front.md): every
## wave_interval seconds, spawns a full wave of wave_size FrontUnit instances,
## one every wave_unit_spacing seconds, lined up side by side, so a wave
## pushes down the lane as a group rather than trickling out continuously.
## Reports when an opposing-faction unit reaches its GoalZone via
## unit_reached_goal, but doesn't decide what that means (win, later: damage)
## — the level script does, keeping Base ignorant of win/loss state.
##
## Also the player's entry point (phase 8.1, Docs/Plans/phase8_foundations.md):
## a sibling BaseControllable exposes this node to the possession layer, which
## drives it via drive() below — a ranged attack and wave-slot purchases.

signal unit_reached_goal(unit: FrontUnit)

@export var faction: Faction.Kind = Faction.Kind.ALLY
@export var unit_scene: PackedScene
@export var advance_target: Node3D
## The opposing Tower — units siege it while it's alive instead of trading
## blows with whatever minion happens to be nearby (Docs/front/tower.md).
@export var advance_target_tower: Node3D
## LoL waves spawn every 30s; shorter here so a prototype session sees several.
@export var wave_interval: float = 10.0
@export var wave_size: int = 3
## Seconds between each unit within a wave (0 = all at once).
@export var wave_unit_spacing: float = 0.75
## Half-width of the line the wave spawns across (perpendicular to the lane).
@export var wave_spread: float = 2.0
## Soft safety cap on how many of this faction's units may be alive at once —
## guards against unbounded pile-up if one side never loses units, not a
## League of Legends mechanic.
@export var max_alive: int = 40
## Structure tint — per-instance so the ally/enemy base read as different
## sides without needing two separate meshes/materials.
@export var tint: Color = Color(0.6, 0.6, 0.65)

@export_group("Attack")
## Lobbed at the mouse cursor with "attack" (A / left-click) while this Base
## is possessed (phase 8.1, MortarShell — Docs/Plans/phase8_foundations.md).
## A flat-flying Projectile (the sphere's) was tried first and sailed clean
## over every ground unit; a mortar arcs down onto the target point instead.
@export var mortar_scene: PackedScene
@export var mortar_blast_scene: PackedScene
@export var attack_cooldown: float = 0.9
@export var mortar_damage: float = 25.0
@export var mortar_radius: float = 2.5
@export var mortar_flight_time: float = 0.9

@export_group("Economy")
## Cost of the next wave-size slot: slot_cost_base + wave_size * slot_cost_step,
## so each purchase makes the next one pricier.
@export var slot_cost_base: int = 20
@export var slot_cost_step: int = 10

@onready var _wave_timer: Timer = $WaveTimer
@onready var _goal_zone: Area3D = $GoalZone
@onready var _structure: MeshInstance3D = $Structure

var _spawning: bool = true
var _attack_timer: float = 0.0


func _ready() -> void:
	_wave_timer.wait_time = wave_interval
	_wave_timer.timeout.connect(_on_wave_timer_timeout)
	_wave_timer.start()
	_goal_zone.collision_mask = Faction.opposing_physics_layer(faction)
	_goal_zone.body_entered.connect(_on_goal_zone_body_entered)
	var mat := _structure.get_active_material(0)
	if mat is StandardMaterial3D:
		mat = mat.duplicate()
		mat.albedo_color = tint
		_structure.material_override = mat


## Called once the level is won/over — stops future waves without touching
## units already on the field.
func stop_spawning() -> void:
	_spawning = false
	_wave_timer.stop()


## Spawns a wave immediately, outside the WaveTimer's schedule — used by the
## level script to seed an opening wave right away instead of waiting a full
## wave_interval for the first clash. Call only after advance_target is set
## (Base's own _ready runs before the level script's, so a wave spawned in
## _ready here would advance toward nothing).
func spawn_wave_now() -> void:
	_on_wave_timer_timeout()


func _on_wave_timer_timeout() -> void:
	if not _spawning or unit_scene == null:
		return
	var alive := get_tree().get_nodes_in_group(Faction.group_name(faction)).size()
	var to_spawn := mini(wave_size, max_alive - alive)
	for i in to_spawn:
		# Re-checked each step: stop_spawning() (level won) may fire mid-wave.
		if not _spawning:
			return
		var unit := unit_scene.instantiate() as FrontUnit
		unit.faction = faction
		unit.target_base = advance_target
		# advance_target_tower keeps pointing at the Tower's freed instance
		# after it dies (queue_free() doesn't null out other nodes' refs) —
		# assigning a freed reference to unit.target_tower directly would
		# throw, so guard the read instead of ever clearing the field itself.
		unit.target_tower = advance_target_tower if is_instance_valid(advance_target_tower) else null
		add_child(unit)
		var t := 0.5 if to_spawn <= 1 else float(i) / float(to_spawn - 1)
		var offset := lerpf(-wave_spread, wave_spread, t)
		unit.global_position = global_position + Vector3(offset, 0.5, 0.0)
		if wave_unit_spacing > 0.0 and i < to_spawn - 1:
			await get_tree().create_timer(wave_unit_spacing).timeout


func _on_goal_zone_body_entered(body: Node3D) -> void:
	if body is FrontUnit and body.faction != faction:
		unit_reached_goal.emit(body)


## Per-frame input while this Base is possessed (BaseControllable.handle_input).
## The Base doesn't move — firing at the cursor and buying wave slots is the
## entirety of its possession behaviour for this milestone.
func drive(ctx: InputContext) -> void:
	_attack_timer -= ctx.delta
	if ctx.just_pressed(&"attack"):
		_try_fire(ctx)
	if ctx.just_pressed(&"buy_slot"):
		_try_buy_slot()


func _try_fire(ctx: InputContext) -> void:
	if mortar_scene == null or _attack_timer > 0.0:
		return
	_attack_timer = attack_cooldown

	var shell := mortar_scene.instantiate()
	get_tree().current_scene.add_child(shell)
	shell.global_position = global_position + Vector3.UP * 1.5
	if shell is MortarShell:
		shell.setup(ctx.world_cursor, mortar_radius, mortar_damage,
			mortar_flight_time, mortar_blast_scene)


func _try_buy_slot() -> void:
	if Economy.try_spend(_next_slot_cost()):
		wave_size += 1


func _next_slot_cost() -> int:
	return slot_cost_base + wave_size * slot_cost_step


## Debug HUD block (duck-typed, see ui/hud.gd) shown while this Base is possessed.
func get_hud_lines() -> Array[String]:
	return [
		"Left-click/A: fire   B: buy wave slot",
		"Resources: %d   Slot: %d   Next: %d" % [Economy.resources, wave_size, _next_slot_cost()],
	]
