extends StaticBody3D
class_name Tower

## Intermediary front objective (Docs/Plans/phase7_front.md, Docs/front/tower.md): an
## immobile structure that composes a Health + an EscortGate, and is the only
## place that decides how the two interact — a different host (a moving,
## flying, or projectile tower) would compose the same two children but could
## wire the relationship differently.

@export var faction: Faction.Kind = Faction.Kind.ENEMY
@export var health: Health
@export var escort_gate: EscortGate
@export var tint: Color = Color(0.6, 0.2, 0.2, 1)

@onready var _mesh: MeshInstance3D = $Mesh

## Forwards Health's died — external systems (the level script's victory
## gate) depend on Tower's own signal, not on reaching into a child directly.
signal died


func _ready() -> void:
	collision_layer = Faction.physics_layer(faction)
	collision_mask = 0
	if faction == Faction.Kind.ENEMY:
		# Same reason FrontUnit does: lets RuneBolt/RuneFlux's group scans and
		# core/aim_strategy.gd's hover raycast (layer 2) find the tower too.
		add_to_group("enemies")

	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat = mat.duplicate()
		mat.albedo_color = tint
		_mesh.material_override = mat

	escort_gate.configure(faction)
	health.died.connect(_on_health_died)


## Spell damage only lands while an allied FrontUnit is escorting the push —
## the gate check lives here, not inside Health or EscortGate, since Tower is
## the one entity that knows its incoming damage should be conditional.
func take_damage(amount: float) -> void:
	if escort_gate.is_protected():
		health.take_damage(amount)


## Same interface as FrontUnit/Enemy, checked via has_method("take_hit") by
## RuneBolt's chain/hit logic.
func take_hit(amount: float) -> void:
	take_damage(amount)


func _on_health_died() -> void:
	died.emit()
	queue_free()
