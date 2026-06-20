extends Node

## Autoload singleton (registered as "Consciousness"). Tracks every sphere on
## the field and which one the player's consciousness currently inhabits. Only
## one sphere is active at a time; the rest are crystallised (passive).
##
## Spheres self-register from their _ready(). The first registered sphere becomes
## active (deferred, so cameras/HUD have a frame to subscribe); the rest start
## passive. Pressing "transfer" (Tab) hands control to the next sphere in the
## list, emitting active_changed so the camera and HUD can retarget.

## Emitted whenever control moves to a different sphere (including the initial
## activation). Listeners receive the now-active SphereController.
signal active_changed(sphere: SphereController)

var spheres: Array[SphereController] = []
var current_index: int = 0


func register(sphere: SphereController) -> void:
	if sphere in spheres:
		return
	spheres.append(sphere)
	# Everyone starts crystallised; the first one is promoted to active once the
	# whole scene tree has finished _ready (so listeners are connected).
	sphere.set_passive()
	if spheres.size() == 1:
		current_index = 0
		call_deferred("_activate_initial")


## Remove a destroyed sphere from the pool. If it was the active one, control
## passes to the next surviving sphere; otherwise the active sphere is kept and
## the index is fixed up for the shrunken list.
func unregister(sphere: SphereController) -> void:
	var idx := spheres.find(sphere)
	if idx == -1:
		return
	var was_active := idx == current_index
	spheres.remove_at(idx)

	if spheres.is_empty():
		current_index = 0
		return

	if was_active:
		current_index = current_index % spheres.size()
		_activate(current_index)
	elif idx < current_index:
		current_index -= 1


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("transfer"):
		transfer_to_next()


## Move control to the next sphere in registration order, wrapping around.
func transfer_to_next() -> void:
	if spheres.size() < 2:
		return
	spheres[current_index].set_passive()
	current_index = (current_index + 1) % spheres.size()
	_activate(current_index)


func active_sphere() -> SphereController:
	if spheres.is_empty():
		return null
	return spheres[current_index]


func _activate_initial() -> void:
	if spheres.is_empty():
		return
	_activate(current_index)


func _activate(i: int) -> void:
	var sphere := spheres[i]
	sphere.set_active()
	active_changed.emit(sphere)
