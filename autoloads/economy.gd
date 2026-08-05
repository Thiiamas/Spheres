extends Node

## Player resource pool (phase 8.1, Docs/Plans/phase8_foundations.md). A single
## global wallet, not per-base: the player has one economy regardless of which
## Base they're currently possessing — same "one player" premise as the
## singular Consciousness autoload.

signal resources_changed(new_amount: int)

var resources: int = 0


func add(amount: int) -> void:
	resources += amount
	resources_changed.emit(resources)


## Spends amount if affordable, returns whether it went through.
func try_spend(amount: int) -> bool:
	if resources < amount:
		return false
	resources -= amount
	resources_changed.emit(resources)
	return true
