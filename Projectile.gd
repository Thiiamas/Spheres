extends Area3D
class_name Projectile

## A straight-flying shot fired by the active sphere. Travels along a fixed
## direction, damages the first enemy it touches (via take_hit), then frees
## itself. Self-destructs after `lifetime` so strays don't accumulate.

@export var lifetime: float = 2.5

var _dir: Vector3 = Vector3.FORWARD
var _speed: float = 30.0
var _damage: float = 35.0
var _life: float = 0.0


## Configure the shot before/after adding it to the tree.
func launch(dir: Vector3, damage: float, speed: float) -> void:
	_dir = dir.normalized()
	_damage = damage
	_speed = speed


func _ready() -> void:
	_life = lifetime
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_hit"):
		body.take_hit(_damage)
		queue_free()
