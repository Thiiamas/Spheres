# Phase 3 — Ennemis & Combat (3D)

> **Note de synchro (docs ↔ code).** Pas encore implémentée. Comme en phase 2,
> les ajouts HP / `take_damage` / barre de vie doivent se greffer sur le
> contrôleur réel de la sphère (`SphereController`, `RigidBody3D`), pas sur un
> `CharacterBody3D`. Fichiers à plat sous `res://` (ex. `res://Enemy.tscn`).
> L'autoload `Consciousness` provient de la phase 2.

## Objectif
Des ennemis angulaires (cubes gris) marchent vers les sphères et leur infligent des dégâts.
Les sphères passives cristallisées encaissent 3x moins de dégâts et bloquent physiquement les ennemis.
Si une sphère tombe à 0 HP, elle est détruite.

## Prérequis
Phase 2 validée et stable.

## Livrable
5 ennemis spawnent et attaquent les sphères. Le joueur doit switcher pour défendre les positions menacées.

---

## Tâche

### 1. Créer `Enemy.tscn`

Structure de nœuds :
```
CharacterBody3D  (Enemy)
├── CollisionShape3D  (BoxShape3D, taille 1×1×1)
├── MeshInstance3D    (BoxMesh, taille 1×1×1, couleur gris #888888)
└── Area3D  (AttackZone)
    └── CollisionShape3D  (SphereShape3D, radius = 1.2)
```

### 2. Créer `Enemy.gd`

```gdscript
extends CharacterBody3D

const SPEED = 3.5
const ATTACK_DAMAGE = 8.0
const ATTACK_COOLDOWN = 1.2

var target = null
var attack_timer := 0.0

func _ready() -> void:
    $AttackZone.body_entered.connect(_on_attack_zone_body_entered)

func _physics_process(delta: float) -> void:
    attack_timer -= delta
    find_target()

    if target == null:
        return

    # Déplacement sur le plan XZ uniquement
    var dir := (target.global_position - global_position)
    dir.y = 0.0
    dir = dir.normalized()

    velocity.x = dir.x * SPEED
    velocity.z = dir.z * SPEED
    if not is_on_floor():
        velocity.y -= 9.8 * delta

    move_and_slide()

func find_target() -> void:
    if Consciousness.spheres.size() > 0:
        target = Consciousness.spheres[Consciousness.current_index]

func _on_attack_zone_body_entered(body) -> void:
    if body.has_method("take_damage") and attack_timer <= 0.0:
        body.take_damage(ATTACK_DAMAGE)
        attack_timer = ATTACK_COOLDOWN
```

### 3. Modifier `Sphere.gd` — ajout HP

Ajouter ces variables et fonctions au script existant :

```gdscript
var hp := 100.0
const MAX_HP = 100.0
const PASSIVE_DEFENSE = 3.0

func take_damage(amount: float) -> void:
    var actual := amount / PASSIVE_DEFENSE if not is_controlled else amount
    hp -= actual
    hp = max(hp, 0.0)
    update_hp_bar()
    if hp <= 0.0:
        die()

func die() -> void:
    Consciousness.spheres.erase(self)
    if Consciousness.spheres.size() > 0:
        Consciousness.current_index = Consciousness.current_index % Consciousness.spheres.size()
        Consciousness.spheres[Consciousness.current_index].set_active()
    queue_free()

func update_hp_bar() -> void:
    if has_node("HPBar3D"):
        $HPBar3D.update_bar(hp, MAX_HP)
```

### 4. Ajouter une barre de HP 3D à `Sphere.tscn`

En 3D, une ProgressBar classique ne s'affiche pas dans l'espace monde. Utiliser un **billboard** via un `SubViewport` ou une approche simplifiée avec deux `MeshInstance3D` superposés :

```
Node3D  (nom : HPBar3D, position : (0, 1.2, 0))
├── MeshInstance3D  (fond — BoxMesh 1×0.1×0.05, couleur rouge sombre #550000)
└── MeshInstance3D  (nom : Fill — BoxMesh 1×0.1×0.05, couleur vert #00cc44)
```

Script `HPBar3D.gd` attaché au nœud `HPBar3D` :

```gdscript
extends Node3D

@onready var fill: MeshInstance3D = $Fill

func _process(_delta: float) -> void:
    # Toujours face à la caméra (billboard)
    if get_viewport().get_camera_3d():
        look_at(get_viewport().get_camera_3d().global_position, Vector3.UP)

func update_bar(current: float, maximum: float) -> void:
    var ratio := current / maximum
    fill.scale.x = ratio
    # Décaler pour que la barre se vide depuis la droite
    fill.position.x = (ratio - 1.0) * 0.5
```

### 5. Spawner les ennemis dans `Main.tscn`

Ajouter / remplacer `Main.gd` :

```gdscript
extends Node3D

@onready var camera: Camera3D = $Camera3D

@export var enemy_scene: PackedScene
const ENEMY_COUNT = 5
const SPAWN_RADIUS = 12.0

const CAM_OFFSET := Vector3(0, 18, 14)

func _ready() -> void:
    spawn_enemies()

func _process(_delta: float) -> void:
    if Consciousness.spheres.is_empty():
        return
    var active = Consciousness.spheres[Consciousness.current_index]
    camera.global_position = active.global_position + CAM_OFFSET
    camera.look_at(active.global_position, Vector3.UP)

func spawn_enemies() -> void:
    for i in ENEMY_COUNT:
        var e = enemy_scene.instantiate()
        var angle := (TAU / ENEMY_COUNT) * i
        e.global_position = Vector3(cos(angle), 0.5, sin(angle)) * SPAWN_RADIUS
        add_child(e)
```

Assigner `Enemy.tscn` à la variable `enemy_scene` dans l'inspecteur.

---

## Critères de validation

- [ ] 5 ennemis (cubes) spawnent autour des sphères
- [ ] Les ennemis marchent vers la sphère active sur le plan horizontal
- [ ] Les barres de HP 3D diminuent quand les ennemis attaquent
- [ ] Une sphère passive perd 3x moins de HP
- [ ] Quand une sphère tombe à 0 HP, elle disparaît
- [ ] Si la sphère active est détruite, la conscience transfère automatiquement
- [ ] Pas d'erreur dans la console

---

## À ne PAS faire dans cette phase

- Pas de capacité d'attaque pour le joueur (Phase 4)
- Pas de condition de victoire / défaite
- Pas de NavigationAgent3D (trop complexe pour le prototype)

---

*Phase suivante : `phase4_loop.md`*
