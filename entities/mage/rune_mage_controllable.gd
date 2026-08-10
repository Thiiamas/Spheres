extends Controllable
class_name RuneMageControllable

## Possession contract of the RuneMage (phase 6). Relays possession and the
## per-frame InputContext to the mage; also owns the hover-reactive cursor —
## the targeting reticle is a property of *this* gameplay, not of the
## possession layer, so it appears on possession and vanishes on release.

## Reticle colour over open ground.
@export var cursor_color: Color = Color(0.7, 0.9, 1.0)
## Reticle colour while an enemy is under the cursor (spell target available).
@export var cursor_hover_color: Color = Color(1.0, 0.35, 0.25)

var mage: RuneMage = null

var _cursor_normal: ImageTexture = null
var _cursor_hover: ImageTexture = null
var _hovering: bool = false


func _ready() -> void:
	mage = get_parent() as RuneMage
	if mage != null:
		mage.controllable = self
	_cursor_normal = _make_cursor(cursor_color)
	_cursor_hover = _make_cursor(cursor_hover_color)
	super()


func handle_input(ctx: InputContext) -> void:
	super(ctx) # upgrade buy keys — see Controllable._handle_upgrade_keys
	# "select" (phase 8.2) switches to another ally under the cursor — a
	# possession-layer concern resolved here, before the mage's own input,
	# so RuneMage stays ignorant of possession swapping (mirrors
	# BaseControllable.handle_input).
	if ctx.just_pressed(&"select") and PossessionSwap.try_select_at_cursor(get_tree()):
		return

	if mage != null:
		mage.drive(ctx)

	# Swap the reticle when the cursor enters / leaves an enemy.
	var hovering := ctx.hover_target != null
	if hovering != _hovering:
		_hovering = hovering
		_apply_cursor()


func on_possessed() -> void:
	super()
	if mage != null:
		mage.set_active()
	_hovering = false
	_apply_cursor()


func on_released() -> void:
	super()
	if mage != null:
		mage.set_passive()
	# Hand the OS cursor back untouched for the next entity.
	Input.set_custom_mouse_cursor(null)


func _apply_cursor() -> void:
	Input.set_custom_mouse_cursor(
		_cursor_hover if _hovering else _cursor_normal,
		Input.CURSOR_ARROW,
		Vector2(16, 16) # hotspot: reticle centre
	)


## Draw a targeting reticle (outer ring + centre dot) into a texture at
## runtime — no image assets needed.
static func _make_cursor(color: Color) -> ImageTexture:
	const SIZE := 32
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var centre := Vector2(SIZE / 2.0 - 0.5, SIZE / 2.0 - 0.5)
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x, y).distance_to(centre)
			var alpha := 0.0
			if d <= 2.5:
				alpha = 1.0 # centre dot
			elif d >= 9.0 and d <= 12.0:
				alpha = 1.0 # targeting ring
			elif d > 12.0 and d <= 13.0:
				alpha = 0.35 # soft outer edge
			if alpha > 0.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(img)
