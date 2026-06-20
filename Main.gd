extends Node3D

## Boots the game loop: once the spheres have registered with Consciousness,
## hand the enemy container and message label to GameManager and start wave 1.

@onready var _enemies: Node3D = $Enemies
@onready var _message: Label = $UI/MessageLabel


func _ready() -> void:
	# Let the spheres run their _ready (register + deferred initial activation).
	await get_tree().process_frame
	GameManager.begin(_enemies, _message)
