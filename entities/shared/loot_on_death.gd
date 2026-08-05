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


func _ready() -> void:
	if health != null:
		health.died.connect(_on_died)


func _on_died() -> void:
	Economy.add(resource_amount)
	_spawn_feedback()


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
