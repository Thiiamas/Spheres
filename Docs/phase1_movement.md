# Phase 1 — Sphère contrôlable (3D)

> **Système de mouvement "reactor-ball".** C'est le système **actuellement
> implémenté**, mais le mouvement est un axe **expérimental** : d'autres systèmes
> seront prototypés et comparés (voir `PLAN.md`). La logique de jeu des phases
> 2 à 4 se greffe par-dessus, indépendamment du système retenu.

## Objectif

Le joueur contrôle une sphère qui **roule** au sol et qui peut **sauter**,
**double-sauter** et **booster** en l'air. Le mouvement dépend de l'**état**
de la sphère (au sol / en l'air / en vol) et de la **direction de poussée du
réacteur**. Le contrôle se fait au plan horizontal (XZ), la hauteur (Y) étant
gérée par le saut et le boost.

## Livrable

Lancer le projet et voir une sphère qui roule au sol avec les touches de
déplacement, saute avec Espace, double-saute en l'air, et s'envole en
maintenant le boost — la poussée du boost suit la direction visée par le
réacteur.

---

## Architecture

La sphère est une **`RigidBody3D`** (et non un `CharacterBody3D`) : le rendu
"lourd" / inertie vient directement de la simulation physique. Toute la logique
de mouvement vit dans `_integrate_forces()` pour rester synchrone avec le
solveur physique.

Trois scripts coopèrent :

| Script | Rôle |
|--------|------|
| `SphereController.gd` (`RigidBody3D`) | Machine à états, roulement, saut, boost. |
| `Reactor.gd` (`Node3D`) | Tuyère orientable : produit une direction de poussée (yaw + pitch). |
| `SphereCamera.gd` (`Camera3D`) | Deux modes (FOLLOW / RTS) ; fournit le yaw de vue pour un déplacement relatif caméra. |

---

## Modes : Mouvement / Attaque (patron State)

Un niveau au-dessus de la machine à états locomotrice, la sphère a un **mode de
contrôle** global, basculé avec `mode_toggle` (touche **F** / bouton **Y**).
Il est implémenté avec un **patron State** : un objet `SphereControlState`
(léger, `RefCounted`) détenu par le contrôleur mappe l'entrée et choisit les
comportements physiques actifs. On **ne change pas le script** du nœud à chaud
(déconseillé par Godot) ; on échange l'objet d'état.

- **MOVEMENT** (`MovementControlState`) — roulement, saut, double-saut, boost.
  Seul cet état lit les entrées de **déplacement** (`move_*`, `jump`, `boost`).
- **ATTACK** (`AttackControlState`) — le déplacement est **verrouillé** (la bille
  tient sa position ; sauts bufferisés purgés) et la sphère **tire** : `A` =
  projectile visé souris, `Z` = explosion de zone (AOE). Seul cet état lit les
  actions d'**attaque** (`attack`, `aoe`).

> Comme chaque état lit des actions distinctes, `Z` peut servir à la fois de
> `move_forward` (en MOVEMENT) et d'`aoe` (en ATTACK) **sans conflit** : c'est
> l'état actif qui décide quelle action est consommée. (Détail attaque/AOE :
> `phase4_loop.md`.)

**Indice visuel :** la sphère **change de couleur** selon l'état — bleu
(`movement_color`) en MOVEMENT, rouge (`attack_color`) en ATTACK, bleu glacé
(`passive_color`) quand cristallisée (phase 2) — avec une émission (lueur). La
teinte est fournie par `state.tint()`. Le HUD affiche le mode et les touches
d'attaque. Le matériau est dupliqué au `_ready()` pour rester propre à l'instance.

> La visée du réacteur reste active dans les deux modes ; seul le **déplacement**
> est désactivé en ATTACK.

---

## Machine à états

La sphère est toujours dans un de ces trois états, recalculé chaque pas
physique :

```
GROUNDED  - au contact du sol. Les touches de déplacement font rouler la bille ;
            Espace fait sauter.
AIRBORNE  - en l'air. Espace permet UN double-saut ; maintenir Boost passe en vol.
FLYING    - en l'air ET boost maintenu. La poussée du réacteur est appliquée
            à chaque pas.
```

- **Détection du sol** : on inspecte les contacts du `RigidBody3D`
  (`contact_monitor = true`). Un contact compte comme "sol" si sa normale
  vérifie `normal · UP ≥ ground_normal_threshold` (0.6 par défaut).
- Atterrir réinitialise le double-saut.
- Le double-saut n'est disponible **qu'une fois** après avoir quitté le sol via
  un saut.

---

## 1. Roulement (état GROUNDED)

- Les touches de déplacement donnent un vecteur d'entrée via
  `Input.get_vector("move_left", "move_right", "move_forward", "move_back")`.
- L'entrée est mappée en direction monde **relative au yaw de la caméra**
  (`camera.get_view_yaw()`), donc "avant" = loin de la caméra dans les deux
  modes. Repli sur le yaw du réacteur si aucune caméra n'est assignée.
- On applique un **couple** (`apply_torque`) sur l'axe `UP × dir` pour faire
  rouler la bille vers `dir` — pas une vélocité linéaire directe, ce qui donne
  un roulement crédible.
- La vitesse de rotation est plafonnée à `max_roll_speed` pour éviter une
  accélération infinie.
- **Sans entrée au sol**, un **freinage** amortit la rotation et la vitesse
  horizontale (décroissance exponentielle indépendante du framerate) pour que la
  bille **s'arrête vite** au lieu de continuer à glisser. Réglé par
  `brake_strength` (0 = pas de freinage, glisse à l'inertie pure). La vélocité
  verticale n'est pas touchée (gravité / atterrissage préservés).

```gdscript
func _apply_roll(physics_state: PhysicsDirectBodyState3D) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if input == Vector2.ZERO:
        return

    var view_yaw := camera.get_view_yaw() if camera else (reactor.yaw if reactor else 0.0)
    var yaw_basis := Basis(Vector3.UP, deg_to_rad(view_yaw))
    var dir := (yaw_basis * Vector3(input.x, 0.0, input.y)).normalized()

    physics_state.apply_torque(Vector3.UP.cross(dir) * roll_torque)

    var spin := physics_state.angular_velocity
    if spin.length() > max_roll_speed:
        physics_state.angular_velocity = spin.normalized() * max_roll_speed
```

---

## 2. Saut & double-saut

- Les pressions de saut sont **bufferisées** dans `_process()` (détection de
  front nette) puis consommées dans `_integrate_forces()`.
- Le saut écrit directement `linear_velocity.y = jump_force`, indépendamment de
  la vitesse de chute en cours → hauteur de saut constante.
- Au sol → saut (`jump_force`), ce qui **arme** un double-saut.
- En l'air, si le double-saut est armé → double-saut (`double_jump_force`), puis
  désarmé.

---

## 3. Boost / vol (état FLYING)

- Maintenir `boost` en l'air passe en `FLYING`.
- Le réacteur (`Reactor.gd`) pointe sa tuyère "vers le bas" (par défaut
  `Vector3.DOWN`), orientable en yaw (autour de UP) et en pitch (clampé à
  `[-80°, +80°]` pour que la poussée reste toujours **vers le haut**).
- La poussée est l'**opposée** de la direction de la tuyère :
  `thrust = -reactor.get_reactor_dir() * boost_force`, intégrée directement
  dans la vélocité (`linear_velocity += thrust * step`).
- Les particules d'échappement (`boost_particles`) n'émettent que pendant
  `FLYING`.

```gdscript
func _apply_boost(physics_state: PhysicsDirectBodyState3D) -> void:
    if reactor == null:
        return
    var thrust := -reactor.get_reactor_dir() * boost_force
    physics_state.linear_velocity += thrust * physics_state.step
```

---

## 4. Paramètres exportés (réglage)

| Paramètre | Défaut | Effet |
|-----------|--------|-------|
| `roll_torque` | 35.0 | Couple de roulement au sol. |
| `max_roll_speed` | 22.0 | Plafond de vitesse de rotation. |
| `brake_strength` | 8.0 | Freinage au sol sans entrée (plus haut = s'arrête plus vite ; 0 = glisse). |
| `jump_force` | 8.0 | Vélocité verticale du saut au sol. |
| `double_jump_force` | 7.0 | Vélocité verticale du double-saut. |
| `boost_force` | 28.0 | Poussée continue du boost (m/s²). |
| `ground_normal_threshold` | 0.6 | Seuil de normale pour compter un contact comme sol. |

---

## 5. Input Map (Project Settings)

> Le clavier est en disposition **AZERTY** (ZQSD).

| Action | Touche / contrôle |
|--------|-------------------|
| `move_forward` | Z |
| `move_back` | S |
| `move_left` | Q |
| `move_right` | D |
| `jump` | Espace / bouton A manette |
| `boost` | Shift gauche / gâchette droite (R2) |
| `mode_toggle` | F / bouton Y manette (bascule Mouvement ↔ Attaque) |
| `attack` | A / clic gauche (tir projectile — **en mode ATTACK**) |
| `aoe` | Z (explosion de zone — **en mode ATTACK** ; partage la touche de `move_forward`) |
| `transfer` | Tab / bouton X manette (transfert de conscience — phase 2) |
| `aim_left/right/up/down` | Stick droit (visée réacteur) |
| `camera_toggle` | C / bouton Select |
| `cam_pan_left/right/up/down` | Flèches (pan caméra RTS) |

La visée du réacteur en mode FOLLOW se fait aussi à la **souris** (capturée ;
Échap libère/recapture le curseur).

---

## Critères de validation

- [ ] La sphère roule au sol avec ZQSD (déplacement relatif à la caméra)
- [ ] L'inertie est clairement perceptible (la bille glisse avant de s'arrêter)
- [ ] Espace fait sauter au sol ; un seul double-saut est possible en l'air
- [ ] Maintenir Boost en l'air fait s'envoler la sphère dans la direction visée
- [ ] La poussée du boost reste toujours orientée vers le haut (pitch clampé)
- [ ] F bascule entre mode Mouvement et Attaque
- [ ] En mode Attaque, la sphère ne peut plus se déplacer (ni rouler, sauter, booster)
- [ ] La sphère change de couleur selon le mode (bleu = Mouvement, rouge = Attaque)
- [ ] La caméra (FOLLOW / RTS, bascule avec C) suit la sphère
- [ ] La sphère ne traverse pas le sol
- [ ] 60fps stable, aucune erreur dans la console Godot

---

## À ne PAS faire dans cette phase

- Pas d'ennemis
- Pas d'autres sphères (transfert de conscience → phase 2)
- Pas de combat
- Pas d'UI élaborée

---

_Phase suivante : `phase2_transfer.md`_
