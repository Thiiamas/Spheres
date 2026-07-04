extends Controllable
class_name RuneMageControllable

## Possession contract of the RuneMage (phase 6). Relays possession and the
## per-frame InputContext to the mage; also owns the hover-reactive cursor
## (arrives in 6.2) since the cursor is a property of *this* gameplay, not of
## the possession layer.

var mage: RuneMage = null


func _ready() -> void:
	mage = get_parent() as RuneMage
	if mage != null:
		mage.controllable = self
	super()


func handle_input(ctx: InputContext) -> void:
	if mage != null:
		mage.drive(ctx)


func on_possessed() -> void:
	super()
	if mage != null:
		mage.set_active()


func on_released() -> void:
	super()
	if mage != null:
		mage.set_passive()
