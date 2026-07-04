extends Controllable
class_name SphereControllable

## Adapter: exposes the reactor-ball SphereController to the possession
## contract without rewriting any of its physics. Sits as a child node of
## Sphere.tscn; Consciousness talks to this contract, and this class relays to
## the sphere's existing set_active/set_passive/drive API.

var controller: SphereController = null


func _ready() -> void:
	controller = get_parent() as SphereController
	if controller != null:
		controller.controllable = self
	# Resolve entity and register with Consciousness (which immediately calls
	# on_released — the sphere starts crystallised until possessed).
	super()


func handle_input(ctx: InputContext) -> void:
	if controller != null:
		controller.drive(ctx)


func on_possessed() -> void:
	super()
	if controller != null:
		controller.set_active()


func on_released() -> void:
	super()
	if controller != null:
		controller.set_passive()
