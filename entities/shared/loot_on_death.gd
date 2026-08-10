extends Node
class_name LootOnDeath

## Sibling of Health (entities/shared/health.gd) — listens for its `died`
## signal and pays the player, without coupling the generic HP component to
## the game's economy (phase 8.1, Docs/Plans/phase8_foundations.md). Attach to
## enemy-side entities only; allies and structures don't drop anything.

@export var health: Health
@export var resource_amount: int = 5

## Optional floating "+N" label spawned above the entity on death, short and
## unanimated (H4 in the phase 8 plan — a flash, not a fully-fledged pickup).
@export var feedback_color: Color = Color(1.0, 0.85, 0.3)
@export var feedback_lifetime: float = 0.6
@export var feedback_rise: float = 1.0

## Optional cosmetic mote (entities/shared/resource_mote.tscn) that flies from
## the kill to the nearest ally Base — phase 9.1 finitions. The "+N" above
## stays as the immediate kill feedback; this is the "it reached your base"
## half. Purely visual: the pool is credited below either way.
@export var mote_scene: PackedScene


func _ready() -> void:
	if health != null:
		health.died.connect(_on_died)


func _on_died() -> void:
	Economy.add(resource_amount)
	_spawn_feedback()
	_spawn_mote()


func _spawn_feedback() -> void:
	var owner_node := get_parent() as Node3D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var label := Label3D.new()
	label.text = "+%d" % resource_amount
	label.modulate = feedback_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	# global_position needs the node inside the tree to resolve — add it first,
	# then place it (setting it beforehand errors: "!is_inside_tree()").
	var start_pos := owner_node.global_position + Vector3.UP * 1.5
	owner_node.get_tree().current_scene.add_child(label)
	label.global_position = start_pos

	var tween := label.create_tween()
	tween.tween_property(label, "global_position",
		start_pos + Vector3.UP * feedback_rise, feedback_lifetime)
	tween.parallel().tween_property(label, "modulate:a", 0.0, feedback_lifetime)
	tween.tween_callback(label.queue_free)


## Sends a mote toward the base that banked this kill. Silently does nothing
## when there's no ally Base in the scene (headless tests, or every base dead)
## — this is decoration, never a reason to fail.
func _spawn_mote() -> void:
	if mote_scene == null:
		return
	var owner_node := get_parent() as Node3D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var base := _nearest_ally_base(owner_node.global_position)
	if base == null:
		return

	var mote := mote_scene.instantiate()
	# Same order as the label above: into the tree, then placed, then set up
	# (ResourceMote.setup reads global_position as its launch origin).
	owner_node.get_tree().current_scene.add_child(mote)
	mote.global_position = owner_node.global_position + Vector3.UP
	if mote is ResourceMote:
		mote.setup(base)


## Nearest ALLY Base by distance. Scans Consciousness.entities — the same
## registry PossessionSwap.find_ally_base() uses — but nearest rather than
## first, since Méso/Macro will put more than one base on the field. Only ally
## bases ever register a Controllable (base_controllable.gd bails on enemies),
## so the faction check is belt-and-braces.
func _nearest_ally_base(from: Vector3) -> Base:
	var best: Base = null
	var best_dist := INF
	for c in Consciousness.entities:
		if not is_instance_valid(c):
			continue
		var base := c.entity as Base
		if base == null or not is_instance_valid(base):
			continue
		if base.faction != Faction.Kind.ALLY:
			continue
		var d := from.distance_squared_to(base.global_position)
		if d < best_dist:
			best_dist = d
			best = base
	return best
