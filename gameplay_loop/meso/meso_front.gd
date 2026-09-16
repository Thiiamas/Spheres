extends Node3D

## Meso-loop POC, milestone 10.1 (Docs/Plans/phase10_meso_poc.md): both Bases
## now field their own wave (PlayerBase gets unit_scene for the first time
## outside level2_front) and can already damage each other through a pushed
## wave — FrontUnit._damageable() has recognised a Base as a valid attack
## target since 9.1, faction-agnostic, so nothing new was needed for that
## part. Victory/defeat both fall out of listening to the two Base.died
## signals that Micro never had to connect both ways.
##
## No Tower here (that's 10.2, meso_siege.tscn) — this milestone exists to
## validate that two waves colliding is already good on its own, in
## isolation, before stacking a siege objective on top (same reasoning as
## 9.1's flat terrain before 9.4's relief).
##
## Kept as its own scene rather than an edit of level2_front.tscn so each
## loop tier stays independently playable (see "Organisation des scènes" in
## the phase 10 plan).

@onready var _player_base: Base = $PlayerBase
@onready var _enemy_base: Base = $EnemyBase
@onready var _message: Label = $UI/MessageLabel


func _ready() -> void:
	# Wired here, not as .tscn NodePath exports: same reasoning as
	# micro_base_defense.gd — each Base only needs the other's position.
	_player_base.advance_target = _enemy_base
	_enemy_base.advance_target = _player_base
	_player_base.died.connect(_on_player_base_died)
	_enemy_base.died.connect(_on_enemy_base_died)

	# Base's own _ready runs before this one (children before parent), so
	# seeding both opening waves here means they advance toward a target
	# that's already assigned, instead of waiting a full wave_interval.
	_player_base.spawn_wave_now()
	_enemy_base.spawn_wave_now()


func _on_player_base_died() -> void:
	# Base._on_health_died() (D7) already stops the dying Base's own spawner;
	# stopping the other side here is what actually ends the run.
	_enemy_base.stop_spawning()
	_message.text = "Défaite\nVotre base est tombée."
	_message.visible = true


func _on_enemy_base_died() -> void:
	_player_base.stop_spawning()
	_message.text = "Victoire !\nLa base ennemie est détruite."
	_message.visible = true
