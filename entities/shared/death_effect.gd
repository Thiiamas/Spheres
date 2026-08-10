extends Node
class_name DeathEffect

## Sibling of Health (entities/shared/health.gd) — spawns a cosmetic effect
## where the entity died, then lets it manage its own lifetime.
##
## Kept separate from LootOnDeath, which reacts to the same `died` signal:
## presentation and economy stay independent, so an ally unit can burst without
## dropping resources (and an enemy could pay out without a burst).

@export var health: Health
@export var effect_scene: PackedScene
## Forwarded to a DeathBurst's play(), so one burst scene can serve
## differently-coloured units without a scene per faction.
@export var tint: Color = Color(0.53, 0.53, 0.53)
@export var offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	if health != null:
		health.died.connect(_on_died)


func _on_died() -> void:
	if effect_scene == null:
		return
	var host := get_parent() as Node3D
	if host == null or not is_instance_valid(host):
		return

	var fx := effect_scene.instantiate()
	# Parented to the current scene rather than the dying host: the host frees
	# itself as soon as `died` finishes resolving (FrontUnit._on_health_died),
	# which would take the effect down with it before it played a single frame.
	host.get_tree().current_scene.add_child(fx)
	if fx is Node3D:
		fx.global_position = host.global_position + offset
	# Typed rather than has_method("play"): AoeBlast also exposes play(), but
	# takes a radius float — a duck-typed call would break the moment someone
	# assigned aoe_blast.tscn here.
	if fx is DeathBurst:
		fx.play(tint)
