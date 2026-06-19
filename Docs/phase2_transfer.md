# Phase 2 — Transfert de conscience (3D)

> **Note de synchro (docs ↔ code).** Cette phase n'est **pas encore
> implémentée**. Les extraits ci-dessous supposent un `Sphere.gd` de type
> `CharacterBody3D` simple ; or la sphère active est aujourd'hui le
> **`SphereController` (`RigidBody3D`)** avec mouvement reactor-ball (voir
> `phase1_movement.md`). À l'implémentation :
> - greffer la logique `is_controlled` / `set_active` / `set_passive` sur le
>   contrôleur réel plutôt que de recopier le `_physics_process` ci-dessous ;
> - les fichiers sont **à plat** sous `res://` (pas de dossier `scenes/`) ;
> - les actions de déplacement réelles sont `move_left/right/forward/back`
>   (et non `ui_left/...`).

## Objectif
Le joueur peut transférer sa conscience entre plusieurs sphères.
La sphère quittée se "cristallise" : immobile, très résistante, visuellement distincte.
La sphère rejointe reprend vie et devient contrôlable.

## Prérequis
Phase 1 validée et stable.

## Livrable
3 sphères sur l'écran. Tab pour switcher. La sphère active est blanche, les passives sont bleu glacé.

---

## Tâche

### 1. Modifier `Sphere.gd`

Remplacer le script existant par :

```gdscript
extends CharacterBody3D

const SPEED = 8.0
const FRICTION = 0.85

var is_controlled := false

func _physics_process(delta: float) -> void:
    if not is_controlled:
        velocity = Vector3.ZERO
        move_and_slide()
        return

    var input_dir := Vector2(
        Input.get_axis("ui_left", "ui_right"),
        Input.get_axis("ui_up", "ui_down")
    )
    var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()

    velocity.x += move_dir.x * SPEED
    velocity.z += move_dir.z * SPEED
    velocity.x *= FRICTION
    velocity.z *= FRICTION
    if not is_on_floor():
        velocity.y -= 9.8 * delta

    move_and_slide()

func set_active() -> void:
    is_controlled = true
    # Couleur blanche — sphère vivante
    $MeshInstance3D.material_override = _make_material(Color.WHITE)

func set_passive() -> void:
    is_controlled = false
    velocity = Vector3.ZERO
    # Bleu glacé — cristallisée
    $MeshInstance3D.material_override = _make_material(Color(0.5, 0.75, 1.0))

func _make_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color * 0.3  # légère lueur
    return mat
```

### 2. Créer `ConsciousnessController.gd`

Créer ce script et l'ajouter en **Autoload** (`Project > Project Settings > Autoload`, nom : `Consciousness`).

```gdscript
extends Node

var spheres: Array = []
var current_index := 0

func _ready() -> void:
    pass

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("transfer"):
        transfer_to_next()

func register(sphere) -> void:
    spheres.append(sphere)
    if spheres.size() == 1:
        sphere.set_active()
    else:
        sphere.set_passive()

func transfer_to_next() -> void:
    if spheres.size() < 2:
        return
    spheres[current_index].set_passive()
    current_index = (current_index + 1) % spheres.size()
    spheres[current_index].set_active()
```

### 3. Modifier `Sphere.gd` — ajout du register

Dans la fonction `_ready()` de `Sphere.gd`, ajouter :

```gdscript
func _ready() -> void:
    Consciousness.register(self)
```

### 4. Modifier `Main.tscn`

- Supprimer l'instance unique de `Sphere.tscn`
- Ajouter **3 instances** de `Sphere.tscn` à des positions différentes sur le plan XZ :
  - Sphère 1 : `(-4, 0.5, 0)`
  - Sphère 2 : `(0, 0.5, 0)`
  - Sphère 3 : `(4, 0.5, 0)`

### 5. Modifier `Main.gd` — suivi de la sphère active

```gdscript
extends Node3D

@onready var camera: Camera3D = $Camera3D

const CAM_OFFSET := Vector3(0, 18, 14)

func _process(_delta: float) -> void:
    if Consciousness.spheres.is_empty():
        return
    var active = Consciousness.spheres[Consciousness.current_index]
    camera.global_position = active.global_position + CAM_OFFSET
    camera.look_at(active.global_position, Vector3.UP)
```

### 6. Input Map

Ajouter l'action `transfer` dans `Project > Project Settings > Input Map` :
- Touche : `Tab`

---

## Critères de validation

- [ ] 3 sphères visibles au démarrage
- [ ] Une seule sphère est blanche (active), les autres sont bleu glacé
- [ ] Tab transfère la conscience à la sphère suivante
- [ ] La sphère quittée devient bleu glacé et s'immobilise instantanément
- [ ] La caméra se déplace vers la nouvelle sphère active
- [ ] Pas d'erreur dans la console

---

## À ne PAS faire dans cette phase

- Pas d'ennemis
- Pas de HP
- Pas d'animation de transition caméra (lerp) — ça peut attendre

---

*Phase suivante : `phase3_combat.md`*
