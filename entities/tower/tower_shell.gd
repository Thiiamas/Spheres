extends "res://entities/base/mortar_shell.gd"
class_name TowerShell

## The Tower's AOE retaliation (phase 10.2, Docs/Plans/phase10_meso_poc.md):
## same lobbed-shell-with-radius-damage as MortarShell, aimed at a hostile
## player's position instead of wherever the player is aiming. Only
## _apply_damage() differs — RuneMage implements take_damage, not take_hit
## (the alias MortarShell calls through for FrontUnit/Tower/Enemy), so this
## override calls the other one. damage_mask is set by the caller
## (entities/shared/escort_gate.gd) to the player's physics layer instead of
## MortarShell's hardcoded enemy layer.


func _apply_damage(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
