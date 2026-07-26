extends Node3D
class_name Base

## League-of-Legends-style wave spawner (Docs/phase7_front.md): every
## wave_interval seconds, spawns a full wave of wave_size FrontUnit instances,
## one every wave_unit_spacing seconds, lined up side by side, so a wave
## pushes down the lane as a group rather than trickling out continuously.
## Reports when an opposing-faction unit reaches its GoalZone via
## unit_reached_goal, but doesn't decide what that means (win, later: damage)
## — the level script does, keeping Base ignorant of win/loss state.

signal unit_reached_goal(unit: FrontUnit)

@export var faction: Faction.Kind = Faction.Kind.ALLY
@export var unit_scene: PackedScene
@export var advance_target: Node3D
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

@onready var _wave_timer: Timer = $WaveTimer
@onready var _goal_zone: Area3D = $GoalZone
@onready var _structure: MeshInstance3D = $Structure

var _spawning: bool = true


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
		add_child(unit)
		var t := 0.5 if to_spawn <= 1 else float(i) / float(to_spawn - 1)
		var offset := lerpf(-wave_spread, wave_spread, t)
		unit.global_position = global_position + Vector3(offset, 0.5, 0.0)
		if wave_unit_spacing > 0.0 and i < to_spawn - 1:
			await get_tree().create_timer(wave_unit_spacing).timeout


func _on_goal_zone_body_entered(body: Node3D) -> void:
	if body is FrontUnit and body.faction != faction:
		unit_reached_goal.emit(body)
