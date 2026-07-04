# Phase 2 — Transfert de conscience (3D)

> **Note de synchro (docs ↔ code).** Cette phase est **implémentée**, mais
> **adaptée** au mouvement reactor-ball réel. Les extraits `CharacterBody3D`
> ci-dessous sont **illustratifs et périmés** ; l'implémentation effective est
> résumée dans la section « Implémentation réelle » en fin de document. En bref :
> - pas de `Sphere.gd` séparé : la logique `is_controlled` / `set_active()` /
>   `set_passive()` est greffée sur le **`SphereController` (`RigidBody3D`)** ;
> - une sphère passive est **`freeze`gée** (immobile, indéboulonnable) plutôt que
>   de remettre sa vélocité à zéro chaque frame ;
> - la sphère joueur est une scène réutilisable **`Sphere.tscn`** instanciée 3×
>   dans `Main.tscn` (fichiers toujours **à plat** sous `res://`) ;
> - la caméra et le HUD **se reciblent** sur la sphère active via le signal
>   `Consciousness.active_changed` (pas de `Main.gd` qui repositionne la caméra) ;
> - l'action de transfert est **`transfer`** (Tab / bouton X manette) ;
> - **depuis la phase 5** (`phase5_possession.md`) : `Consciousness` ne
>   manipule plus des `SphereController` mais des **`Controllable`** (contrat
>   de possession en nœud enfant — `SphereControllable` pour les sphères) ;
>   `set_active()`/`set_passive()` sont relayés par `on_possessed()`/
>   `on_released()`, le signal est `active_changed(controllable)`, et le pool
>   peut contenir des entités non-sphères (`ShoreBeacon`).

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

## Implémentation réelle (adaptée au reactor-ball)

| Élément | Réalisation |
|---------|-------------|
| Sphère joueur | `Sphere.tscn` (RigidBody3D + `SphereController` + mesh + collision + Reactor), instanciée 3× dans `Main.tscn` aux positions `(-5,1,0)`, `(0,1,0)`, `(5,1,0)`. |
| État actif/passif | `SphereController.set_active()` / `set_passive()`. Passif → `freeze = true` (statique, indéboulonnable), vélocités nulles, réacteur et particules coupés. Actif → `freeze = false`, réacteur réactivé, mode remis à `MOVEMENT`. |
| Couleur | Active = **couleur de mode** (bleu MOVEMENT / rouge ATTACK, lueur forte). Passive = **bleu glacé** `passive_color` (lueur faible). *(La doc parlait de « blanc » pour l'active ; on garde la teinte de mode de la phase 1, plus cohérente.)* |
| Autoload `Consciousness` | Registre des sphères (auto-enregistrement depuis `_ready`), index courant, `transfer_to_next()`, signal `active_changed(sphere)`. La 1ʳᵉ sphère devient active en **différé** (`call_deferred`) pour que caméra/HUD aient connecté le signal. |
| Caméra & HUD | Se connectent à `active_changed` et se reciblent sur la sphère active (la caméra lit son réacteur et lui transmet la référence caméra pour le roulement caméra-relatif). |
| Entrée | Action `transfer` = **Tab** (clavier) / bouton **X** manette (`button_index 2`). |

## Critères de validation

- [x] 3 sphères visibles au démarrage
- [x] Une seule sphère est active (teinte de mode), les autres sont bleu glacé
- [x] Tab transfère la conscience à la sphère suivante
- [x] La sphère quittée devient bleu glacé et s'immobilise instantanément (`freeze`)
- [x] La caméra se déplace vers la nouvelle sphère active
- [x] Pas d'erreur dans la console (vérifié en headless ; transfert testé 1→2→3→1)

---

## À ne PAS faire dans cette phase

- Pas d'ennemis
- Pas de HP
- Pas d'animation de transition caméra (lerp) — ça peut attendre

---

*Phase suivante : `phase3_combat.md`*
