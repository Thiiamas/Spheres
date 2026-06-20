# Phase 3 — Ennemis & Combat (3D)

> **Note de synchro (docs ↔ code).** Cette phase est **implémentée**, adaptée au
> contrôleur réel. Les extraits ci-dessous (HP/mort sur un `Sphere.gd`,
> `Main.gd` qui bouge la caméra) sont **illustratifs** ; le détail réel est dans
> la section « Implémentation réelle » en fin de document. En bref :
> - les HP (`hp`, `take_damage()`, mort) vivent sur **`SphereController`
>   (`RigidBody3D`)**, pas sur un `Sphere.gd` séparé ;
> - la mort passe par **`Consciousness.unregister()`** (retire la sphère, et
>   réassigne le contrôle si la sphère active meurt) au lieu de bidouiller
>   `Consciousness.spheres` directement ;
> - la caméra suit déjà la sphère active via le signal `active_changed` (phase
>   2) : **pas de `Main.gd`** qui repositionne la caméra ; le spawn d'ennemis est
>   isolé dans **`EnemySpawner.gd`** (nœud `Enemies` de `Main.tscn`) ;
> - l'ennemi **mord chaque frame** les corps présents dans sa zone
>   (`get_overlapping_bodies` + cooldown) plutôt que sur le seul signal
>   `body_entered`, pour des dégâts répétés au contact.

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

## Implémentation réelle (adaptée au reactor-ball)

| Élément | Réalisation |
|---------|-------------|
| Ennemi | `Enemy.tscn` (`CharacterBody3D` + cube gris + `AttackZone` Area3D r=1.2) piloté par `Enemy.gd`. Chasse `Consciousness.active_sphere()` sur XZ ; mord chaque frame les corps de la zone qui ont `take_damage` (cooldown `attack_cooldown`). Bloqué physiquement par les sphères passives (figées → statiques). |
| Spawn | `EnemySpawner.gd` sur le nœud `Enemies` de `Main.tscn` : anneau de `enemy_count` (5) ennemis au rayon `spawn_radius` (12). `enemy_scene` = `Enemy.tscn`. |
| HP | Sur `SphereController` : `max_hp` (100), `hp`, `take_damage()`. Passif → dégâts ÷ `passive_defense` (3). `hp ≤ 0` → `_die()`. |
| Mort | `_die()` → `Consciousness.unregister(self)` (réassigne le contrôle si la sphère active meurt) puis `queue_free()`. |
| Barre de vie | `HPBar3D.gd` : deux `BoxMesh` (fond rouge sombre + remplissage vert non éclairé), `top_level` pour ignorer la rotation de la bille, billboard en lacet vers la caméra. Le remplissage se vide depuis la droite. |
| Robustesse | Caméra et HUD ignorent une cible libérée (`is_instance_valid`) pour ne pas planter si toutes les sphères meurent (pas de game over en phase 3). |

> **Équilibrage.** Avec 5 ennemis ciblant tous la sphère active (~33 dégâts/s
> cumulés), l'active tombe en ~3 s si on ne bouge / ne switche pas — c'est la
> pression voulue. Ajuster via `attack_damage`, `attack_cooldown`, `speed`,
> `enemy_count` (tous exportés) si c'est trop brutal.

## Critères de validation

- [x] 5 ennemis (cubes) spawnent autour des sphères
- [x] Les ennemis marchent vers la sphère active sur le plan horizontal
- [x] Les barres de HP 3D diminuent quand les ennemis attaquent
- [x] Une sphère passive perd 3x moins de HP (vérifié : 30 dégâts → −10)
- [x] Quand une sphère tombe à 0 HP, elle disparaît (`queue_free`)
- [x] Si la sphère active est détruite, la conscience transfère automatiquement (vérifié)
- [x] Pas d'erreur dans la console (vérifié en headless)

---

## À ne PAS faire dans cette phase

- Pas de capacité d'attaque pour le joueur (Phase 4)
- Pas de condition de victoire / défaite
- Pas de NavigationAgent3D (trop complexe pour le prototype)

---

*Phase suivante : `phase4_loop.md`*
