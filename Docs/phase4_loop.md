# Phase 4 — Boucle de jeu complète (3D)

> **Note de synchro (docs ↔ code).** Cette phase est **implémentée**, mais
> l'**attaque diffère** de la proposition ci-dessous. Détail dans la section
> « Implémentation réelle » en fin de document. En bref :
> - l'attaque n'est **pas** une explosion de zone sur Espace : c'est un
>   **projectile** (`Projectile.tscn`) tiré sur l'action **`attack` = `A`**
>   (Espace reste `jump`), **visé là où pointe la souris** ;
> - « où pointe la souris » dépend de la caméra → résolu par un **patron
>   Strategy** (`AimStrategy` + `MouseCursorAim` pour RTS, `ScreenCenterAim`
>   pour FOLLOW) porté par `SphereCamera.get_aim_target()` ;
> - les HP/dégâts ennemis (`take_hit`) et la mort vivent sur `Enemy.gd` ;
>   les ennemis sont sur le **layer physique 2**, le projectile ne touche
>   qu'eux ;
> - `GameManager` (autoload) gère vagues/zones/Game Over ; `Main.gd` démarre la
>   1ʳᵉ vague une fois les sphères enregistrées ; la mort de la dernière sphère
>   (via `Consciousness.unregister`) déclenche le Game Over.

## Objectif
Le jeu a une boucle complète :
1. Vague d'ennemis arrive
2. Le joueur défend avec ses sphères
3. Tous les ennemis éliminés → zone suivante (plus difficile)
4. Toutes les sphères détruites → Game Over

Le joueur peut attaquer avec la sphère active (explosion de zone, Espace).

## Prérequis
Phase 3 validée et stable.

## Livrable
Une session jouable de bout en bout avec 2 zones et un écran de Game Over.

---

## Tâche

### 1. Capacité d'attaque dans `Sphere.gd`

Ajouter l'attaque de zone déclenchée par Espace :

```gdscript
const ATTACK_RADIUS = 5.0
const ATTACK_DAMAGE_TO_ENEMY = 35.0
const ATTACK_COOLDOWN = 3.0

var attack_cooldown_timer := 0.0

func _physics_process(delta: float) -> void:
    # ... code existant ...
    attack_cooldown_timer -= delta

func _input(event: InputEvent) -> void:
    if not is_controlled:
        return
    if event.is_action_pressed("attack") and attack_cooldown_timer <= 0.0:
        perform_attack()

func perform_attack() -> void:
    attack_cooldown_timer = ATTACK_COOLDOWN
    # Trouver tous les ennemis dans le rayon via PhysicsDirectSpaceState3D
    var space := get_world_3d().direct_space_state
    var query := PhysicsShapeQueryParameters3D.new()
    var shape := SphereShape3D.new()
    shape.radius = ATTACK_RADIUS
    query.shape = shape
    query.transform = Transform3D(Basis(), global_position)
    query.collision_mask = 2  # layer des ennemis
    var results := space.intersect_shape(query)
    for r in results:
        var body := r["collider"]
        if body.has_method("take_hit"):
            body.take_hit(ATTACK_DAMAGE_TO_ENEMY)
    # Flash visuel : pulsation de scale
    _flash_attack()

func _flash_attack() -> void:
    var mat := _make_material(Color(1.5, 1.5, 0.5))  # jaune vif
    $MeshInstance3D.material_override = mat
    await get_tree().create_timer(0.12).timeout
    set_active()  # restaure la couleur blanche
```

### 2. Ajouter `take_hit()` dans `Enemy.gd`

```gdscript
var hp := 40.0

func take_hit(damage: float) -> void:
    hp -= damage
    if hp <= 0.0:
        GameManager.on_enemy_died()
        queue_free()
```

### 3. Input Map

Ajouter dans `Project > Project Settings > Input Map` :
- Action `attack` → touche `Space`

### 4. Créer `GameManager.gd` — Autoload

Ajouter en Autoload avec le nom `GameManager`.

```gdscript
extends Node

var current_zone := 1
var enemies_alive := 0
var enemy_scene: PackedScene

func _ready() -> void:
    enemy_scene = preload("res://scenes/Enemy.tscn")

func start_wave(count: int) -> void:
    enemies_alive = count
    var main := get_tree().current_scene
    const SPAWN_RADIUS := 14.0
    for i in count:
        var e := enemy_scene.instantiate()
        var angle := (TAU / count) * i + randf() * 0.3
        e.global_position = Vector3(cos(angle), 0.5, sin(angle)) * SPAWN_RADIUS
        main.add_child(e)

func on_enemy_died() -> void:
    enemies_alive -= 1
    if enemies_alive <= 0:
        zone_cleared()

func zone_cleared() -> void:
    current_zone += 1
    show_message("Zone dégagée ! Prochaine zone...")
    await get_tree().create_timer(2.0).timeout
    start_wave(4 + current_zone * 2)

func game_over() -> void:
    show_message("GAME OVER\n[Entrée] pour recommencer")

func show_message(text: String) -> void:
    var label := get_tree().current_scene.get_node_or_null("UI/MessageLabel")
    if label:
        label.text = text
        label.visible = true

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept") and Consciousness.spheres.is_empty():
        get_tree().reload_current_scene()
```

### 5. Modifier `Sphere.gd` — appeler game_over

Dans la fonction `die()` :

```gdscript
func die() -> void:
    Consciousness.spheres.erase(self)
    if Consciousness.spheres.size() > 0:
        Consciousness.current_index = Consciousness.current_index % Consciousness.spheres.size()
        Consciousness.spheres[Consciousness.current_index].set_active()
    else:
        GameManager.game_over()
    queue_free()
```

### 6. Créer `UI.tscn` et l'ajouter à `Main.tscn`

En 3D, l'UI 2D passe par un `CanvasLayer` (même principe qu'en 2D — l'UI est toujours en espace écran) :

```
CanvasLayer  (UI)
└── Label  (nom : MessageLabel)
      text : ""
      visible : false
      anchors_preset : 8  (CENTER)
      font_size : 32
      horizontal_alignment : CENTER
```

### 7. Modifier `Main.gd` — démarrer la première vague

```gdscript
func _ready() -> void:
    await get_tree().process_frame  # laisser les sphères s'enregistrer
    GameManager.start_wave(5)
```

---

## Implémentation réelle (adaptée au reactor-ball)

| Élément | Réalisation |
|---------|-------------|
| États de contrôle | Patron **State** : `SphereControlState` (base) + `MovementControlState` / `AttackControlState`, objet détenu par `SphereController` (pas de `set_script` à chaud). MOVEMENT lit `move_*`/`jump`/`boost` ; ATTACK lit `attack`/`aoe` → les touches partagées (ex. `Z`) ne se télescopent jamais. Bascule : `F`. **ATTACK = posture « setting » :** en entrant, la sphère se **freine durement** (`apply_attack_anchor`, `attack_anchor_brake`) et s'ancre sur place pour viser au lieu de glisser sur son élan. **Les cooldowns d'attaque tournent dans tous les modes** (`tick_attack_timers` appelé dans `_process`, plus seulement en ATTACK) — passer en ATTACK ne « gèle » plus un cooldown à moitié dépensé. |
| Attaque projectile | Action **`attack` = `A`** (et clic gauche), **en mode ATTACK**. `SphereController._fire_projectile()` instancie `Projectile.tscn`, le lance vers la cible souris, cooldown `attack_cooldown` (0.5 s). |
| Attaque AOE (orbe, façon Lux E — cast en **deux temps**) | Action **`aoe` = `Z`**, **en mode ATTACK**. 1ʳᵉ pression : `_launch_aoe_orb()` lance `AoeOrb.tscn`. La cible souris (même `AimStrategy` que le tir) ne donne que la **direction** ; l'orbe file dans cet axe, à plat à sa hauteur de lancement. **Machine à deux états (`Phase`) :** **MOVE** — vole pendant `aoe_move_time` (0,8 s ≈ vitesse × durée) puis passe en HOLD tout seul ; **HOLD** — immobile. **Recast (`recast()`) :** en MOVE → passe en **HOLD immédiatement** (park, pour choisir une distance plus courte) ; en HOLD → **détone**. Donc : lancer → (option) stopper tôt → détoner. Filet : si jamais recastée, `aoe_lifetime` (3 s, ≥ `aoe_move_time`) la fait **détoner d'elle-même**. À la détonation, l'orbe fait `intersect_shape` (rayon `aoe_radius`, masque layer 2) → `take_hit(aoe_damage)` sur chaque ennemi, et `AoeBlast.tscn` montre l'onde. Un **anneau au sol** (`RadiusRing` mis à l'échelle de `aoe_radius`) montre la zone d'impact. Cooldown de lancement `aoe_cooldown` (3 s) ; stopper/détoner est gratuit. |
| Visée souris | `SphereCamera.get_aim_target(origin)` délègue à une `AimStrategy` choisie selon le mode caméra : **RTS → `MouseCursorAim`** (curseur libre projeté), **FOLLOW → `ScreenCenterAim`** (souris capturée → centre écran). Raycast sur les ennemis, sinon plan du sol, sinon point lointain. |
| Projectile | `Projectile.tscn` (`Area3D`, masque layer 2) vole droit, appelle `Enemy.take_hit()` au contact puis se libère ; auto-destruction après `lifetime`. |
| Ennemi | `Enemy.gd` : `hp` (40), `take_hit()` → mort → `GameManager.on_enemy_died()`. Sur **layer 2** (le projectile ne touche que les ennemis ; pas les sphères ni les murs). |
| Boucle | `GameManager` (autoload) : `begin()` (appelé par `Main.gd`) → `start_wave(5)` ; `on_enemy_died()` décrémente ; à 0 → `_zone_cleared()` (zone++ , message, +2 s, `start_wave(4 + zone*2)`). **Spawn (niveau 01 « The Shore ») :** les cubes n'apparaissent plus en **cercle** autour du centre mais en **ligne de marée** le long du bord du monde-cube (`SHORE_SPAWN_Z`, +Z) étalée sur `SHORE_SPAWN_HALF_WIDTH` en X ; les sphères défendent depuis le côté monde-sphère (−Z). Cf. `LORE.md`. |
| Game Over | `SphereController._die()` → `Consciousness.unregister()` ; si plus aucune sphère → `GameManager.game_over()` (message). `ui_accept` recharge la scène (après `Consciousness.reset()`). |
| UI | `CanvasLayer UI/MessageLabel` centré dans `Main.tscn` (caché par défaut). |

> **Divergence assumée vs la doc d'origine.** Deux attaques, en **mode ATTACK** :
> `A` = projectile visé souris (remplace le flash zone sur Espace), `Z` =
> explosion de zone (reprend l'idée d'AoE de la doc, via `intersect_shape`). Le
> `take_hit` ennemi est déclenché par les deux. Le découpage MOVEMENT/ATTACK est
> un **patron State** (cf. `phase1_movement.md`).

## Critères de validation

- [x] 5 ennemis (cubes) spawnent au démarrage (`GameManager.start_wave(5)`)
- [x] La sphère active peut attaquer avec **`A`** → projectile visé souris *(remplace le flash zone)*
- [x] L'attaque a un cooldown (`attack_cooldown`, 0.5 s — projectile, pas l'AoE 3 s)
- [x] Tous les ennemis morts → message "Zone dégagée" → vague plus difficile (vérifié : zone 2 = 8 ennemis)
- [x] Toutes les sphères mortes → message "GAME OVER" (vérifié)
- [x] Entrée redémarre la partie depuis Game Over
- [x] La difficulté augmente à chaque zone (`4 + zone*2`)

---

## Après cette phase — v0.2

Le prototype est jouable. Les prochaines étapes sont dans `PLAN.md` (questions ouvertes).

Priorité suggérée pour v0.2 :
1. Système d'acquisition de sphères (gagner une sphère à chaque zone ?)
2. 2-3 capacités différentes sélectionnables
3. Transition de caméra fluide (lerp) lors du transfert de conscience
4. Ombres et post-processing léger (bloom) pour la 3D
