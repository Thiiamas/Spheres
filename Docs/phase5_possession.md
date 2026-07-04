# Phase 5 — Possession multi-perspective (architecture)

> **Note de synchro (docs ↔ code).** Cette phase est **implémentée**
> (2026-07-04, branche `phase5-possession`, sous-phases 5.0 → 5.4 commitées
> séparément). Les extraits `gdscript` du corps du document sont les contrats
> **planifiés** ; l'implémentation effective — très proche — est résumée dans
> la section « Implémentation réelle » en fin de document, avec les quelques
> écarts assumés. **Reste à valider manuellement** : le game feel (5.1) et les
> bascules Tab / C en jeu (voir critères).

## Objectif
Découpler le **contrôleur joueur** (l'« âme » persistante) de **l'entité
contrôlée**, pour que la conscience puisse posséder plusieurs **types**
d'entités — sphère, base RTS, unité MOBA, véhicule… — chacune définissant sa
propre caméra, son entrée et son contrôle. La sphère devient *un* possédable
parmi d'autres, sans rien perdre de son game feel actuel.

## Prérequis
Phases 1 à 4 validées et stables (reactor-ball, transfert, combat, boucle de
vagues). Aucune régression du gameplay n'est acceptable : ce refactor doit
être **invisible** tant qu'on ne possède que des sphères.

## Livrable
Le jeu actuel, inchangé en apparence, mais dont la possession passe par trois
contrats génériques (`Controllable` / `InputContext` / `CameraConfig`) — plus
une **deuxième entité non-sphère possédable** qui prouve l'abstraction.

---

## Analyse d'écart : ~60 % existe déjà

Point crucial avant d'écrire du code : **l'autoload `Consciousness` EST le
`PlayerController` du brief.** Âme persistante (autoload, survit aux entités),
registre d'entités, cycle de contrôle au Tab, signal `active_changed` qui
recible caméra et HUD — tout y est. La phase 5 est une **évolution** de
l'existant, pas un système parallèle.

| Concept du brief | Déjà présent | Écart à combler |
|------------------|--------------|-----------------|
| **PlayerController** (âme persistante) | ✅ `Consciousness.gd` : autoload, registre, `transfer_to_next()`, signal `active_changed` | Typé `Array[SphereController]` → doit piloter des `Controllable` génériques |
| **Controllable** (contrat d'entité) | ⚠️ `SphereControlState.gd` abstrait déjà les modes MOVEMENT/ATTACK **d'une** sphère (patron State) | Rien n'abstrait **entre types d'entités** : conscience, caméra et HUD connaissent le type concret |
| **CameraRig + CameraConfig** | ⚠️ `SphereCamera.gd` : deux modes FOLLOW/RTS complets et fonctionnels | Modes en `enum` **en dur** dans le script, pas pilotés par données ; la caméra suppose une sphère (réacteur, `bind_camera`) |
| **InputContext** (entrée normalisée) | ❌ | Les entités lisent `Input.*` en direct (`apply_roll`, `buffer_jump_input`, `_update_phase`, états ATTACK, toggle de mode) |
| **Machine à états de possession** | ✅ Cycle de `Consciousness` + patron State `Mode` par sphère | Aucun — les deux niveaux existent déjà et se composent bien |

---

## Décision Godot clé : `Controllable` en nœud-composant enfant

Le contrat `Controllable` est un **nœud enfant** de l'entité, **pas une classe
de base**. Raison : l'héritage GDScript est simple. `SphereController extends
RigidBody3D` ; un futur `Vehicle` serait lui aussi un corps physique, mais une
`RTSBase` serait un simple `Node3D` statique. Une classe de base `Controllable`
devrait choisir de quoi elle hérite (`RigidBody3D` ?) et exclurait de fait la
RTS. Le brief tranche dans le même sens : *« la logique de contrôle vit dans un
nœud enfant »*.

Conséquence pratique : on **enveloppe** le `SphereController` existant avec un
enfant `SphereControllable` qui l'adapte au contrat, **sans réécrire sa
physique**. `Consciousness` ne manipule que des `Controllable`, jamais des
types concrets.

```
                    ┌──────────────────────┐
                    │ Consciousness (auto) │  ← l'âme : registre, Tab,
                    │  Array[Controllable] │    construit l'InputContext/frame
                    └─────┬───────────┬────┘
        handle_input(ctx) │           │ active_changed(controllable)
                          ▼           ▼
              ┌────────────────┐   ┌──────────────────────┐
              │   CameraRig    │◄──│ CameraConfig (.tres) │
              │ (ex-SphereCam) │   │ follow / topdown / … │
              └────────────────┘   └──────────────────────┘
                          ▲ get_camera_config()
                          │
        ┌─────────────────┼──────────────────────┐
        ▼                 ▼                      ▼
┌───────────────┐  ┌───────────────┐  ┌────────────────┐
│ Sphere.tscn   │  │ RTSBase.tscn  │  │ Vehicle.tscn   │
│ RigidBody3D   │  │ Node3D        │  │ RigidBody3D    │  ← types concrets libres
│ └ Sphere-     │  │ └ RTSBase-    │  │ └ Vehicle-     │
│   Controllable│  │   Controllable│  │   Controllable │  ← nœud enfant = contrat
└───────────────┘  └───────────────┘  └────────────────┘
```

---

## Contrats (extraits indicatifs)

### `Controllable.gd` — le contrat de possession

```gdscript
extends Node
class_name Controllable

## Nœud-composant enfant : adapte n'importe quelle entité au contrat de
## possession. Consciousness ne parle qu'à cette interface.

var entity: Node            # l'entité adaptée (le parent, en pratique)
var input_enabled: bool = false

func get_camera_config() -> CameraConfig:
    return null

## Appelé chaque frame par Consciousness avec l'entrée normalisée.
func handle_input(_ctx: InputContext) -> void:
    pass

func on_possessed() -> void:
    pass

func on_released() -> void:
    pass
```

### `InputContext.gd` — l'entrée normalisée

```gdscript
extends RefCounted
class_name InputContext

## Instantané d'entrée d'une frame, construit UNE fois par Consciousness puis
## passé à controllable.handle_input(ctx). Aucune entité ne relit Input.*.

var move_vector: Vector2 = Vector2.ZERO   # move_left/right/forward/back
var look_vector: Vector2 = Vector2.ZERO   # souris / stick droit
var world_cursor: Vector3 = Vector3.ZERO  # curseur projeté au sol (via CameraRig)
var actions: Dictionary = {}              # nom → {pressed, just_pressed}

func just_pressed(action: StringName) -> bool:
    return actions.get(action, {}).get("just_pressed", false)
```

> **Bonus gratuit :** piloter une entité par IA = **synthétiser un
> `InputContext`** et appeler `handle_input()`. Aucune branche « joueur vs IA »
> dans les entités.

### `CameraConfig.gd` — la caméra en données

```gdscript
extends Resource
class_name CameraConfig

@export var mode: StringName = &"follow"  # &"follow" / &"topdown" / &"fixed"
@export var follow_distance: float = 6.0
@export var height: float = 3.0
@export var pitch: float = 55.0
@export var yaw: float = 45.0
@export var fov: float = 75.0
@export var zoom_min: float = 8.0
@export var zoom_max: float = 45.0
```

Chaque entité rend sa config via `get_camera_config()` ; le `CameraRig`
(l'actuel `SphereCamera` refactoré) l'applique au moment de la possession. Les
deux modes actuels deviennent deux ressources : `sphere_follow.tres` et
`sphere_rts.tres`.

---

## Fichiers

### À créer

| Fichier | Rôle |
|---------|------|
| `Controllable.gd` | Contrat de possession (nœud-composant enfant) |
| `InputContext.gd` | Instantané d'entrée par frame (`RefCounted`) |
| `CameraConfig.gd` | Ressource de configuration caméra |
| `SphereControllable.gd` | Adaptateur : enveloppe le `SphereController` existant dans le contrat |
| `sphere_follow.tres` / `sphere_rts.tres` | Les deux modes caméra actuels, en données |

### À modifier

| Fichier | Changement |
|---------|-----------|
| `Consciousness.gd` | `Array[Controllable]` au lieu d'`Array[SphereController]` ; `active_changed(controllable)` ; construit l'`InputContext` chaque frame et le passe à l'actif |
| `SphereController.gd` | Lit l'`InputContext` (plus aucun `Input.*`) ; `set_active()`/`set_passive()` appelés par **son** `SphereControllable` |
| `MovementControlState.gd` / `AttackControlState.gd` | `handle_input(ctx: InputContext)` au lieu de lire `Input.*` |
| `SphereCamera.gd` | Devient `CameraRig` piloté par `CameraConfig` (plus d'enum de mode en dur) |
| `Sphere.tscn` | Ajout du nœud enfant `SphereControllable` |
| `HUD.gd` | Type-agnostique : affiche ce que le `Controllable` actif expose, plus de `SphereController` typé en dur |

---

## Sous-phases ordonnées (anti-régression)

Règle : **le build tourne et se joue à l'identique après chaque sous-phase.**

### 5.0 — Ajouts purs
Créer `CameraConfig.gd`, `InputContext.gd`, `Controllable.gd`. Code mort à ce
stade : rien ne les référence, le jeu est strictement identique. Zéro risque.

### 5.1 — Normaliser l'entrée *(le plus invasif — branche dédiée)*
`Consciousness` construit un `InputContext` par frame. Migrer **site par site**
tous les accès `Input.*` du chemin sphère :

- `SphereController.apply_roll` — `Input.get_vector("move_*")` → `ctx.move_vector`
- `SphereController.buffer_jump_input` — `jump`
- `SphereController._update_phase` — `boost` maintenu
- `AttackControlState.handle_input` → `try_fire_projectile` (`attack`) et
  `try_cast_aoe` (`aoe`)
- le toggle `mode_toggle` dans `SphereController._process`

Après migration : **vérifier que le feel est identique** (roulement
caméra-relatif, buffer de saut, double saut, boost maintenu, recast AOE).
C'est ici que le game feel peut se casser.

### 5.2 — Contrat `Controllable` sur la sphère
Ajouter `SphereControllable` dans `Sphere.tscn` : il relaie
`on_possessed()`/`on_released()` vers `set_active()`/`set_passive()` et
`handle_input(ctx)` vers le contrôleur et ses états. `Consciousness` passe en
`Array[Controllable]` ; `SphereCamera._on_active_changed(controllable)`
récupère l'entité via `controllable.entity`.

### 5.3 — Caméra pilotée par données
`SphereCamera` → `CameraRig` : lit un `CameraConfig` au lieu de son enum
FOLLOW/RTS. Les deux modes actuels deviennent `sphere_follow.tres` et
`sphere_rts.tres` ; la touche **C** bascule entre les configs exposées par le
`Controllable` actif. Option : `SpringArm3D` pour l'occlusion (facultatif).

### 5.4 — Prouver l'abstraction
Créer une **deuxième entité non-sphère** possédable (ex. une base statique vue
top-down : un `Node3D` + son `Controllable` + son `CameraConfig`). Critère
dur : **aucune modification** des fichiers de 5.0–5.3 pour l'intégrer. S'il
faut y retoucher, l'abstraction fuit.

### 5.5 — Docs
Mettre à jour ce document (section « Implémentation réelle »), `PLAN.md` et
les notes de synchro des phases 2–4 impactées.

---

## Risques

| Risque | Parade |
|--------|--------|
| Créer un `PlayerController` **parallèle** à `Consciousness` | Interdit : on fait **évoluer** `Consciousness`. Deux âmes = deux sources de vérité, bugs de possession garantis |
| Réimplémenter le gating d'entrée du brief (`set_process_input(false)`) | Déjà couvert : `set_passive()` freeze la sphère, coupe son réacteur et détruit son état de contrôle. Le `Controllable` ne fait que **relayer** vers l'existant |
| 5.1 altère le game feel (buffer de saut, boost maintenu, edge detection des `just_pressed`) | Branche dédiée + playtest comparatif avant merge ; migrer site par site, pas en bloc |

---

## Implémentation réelle (2026-07-04)

| Élément | Réalisation |
|---------|-------------|
| Contrats | `Controllable.gd`, `InputContext.gd`, `CameraConfig.gd` — conformes au plan. Deux ajouts pragmatiques : `InputContext.delta` (évite un second paramètre à `handle_input`) et `Controllable.camera_configs: Array[CameraConfig]` + `cycle_camera_config()` (la touche C cycle les configs **de l'entité**, `get_camera_config()` rend la courante). |
| Fraîcheur de l'entrée | `InputContext.capture()` échantillonne à la frame ; `refresh_held()` ré-échantillonne l'état **maintenu** (move_vector, `pressed`) à chaque tick physique depuis `Consciousness._physics_process`, pour que roll/boost lisent l'entrée aussi fraîche qu'avant (les fronts `just_pressed` gardent leur timing frame). |
| `Consciousness` | Registre `entities: Array[Controllable]`, signal `active_changed(controllable)`, `active()`. Construit l'`InputContext` par frame (`world_cursor` résolu par `camera_rig.get_aim_target`, la caméra s'enregistre via `Consciousness.camera_rig`) et le pousse à l'actif. Expose `last_context` pour le HUD. |
| Adaptateur sphère | `SphereControllable.gd`, enfant `Controllable` de `Sphere.tscn` **et** de la balle inline de `TestScene.tscn`. Relaie `on_possessed/on_released` → `set_active/set_passive`, `handle_input(ctx)` → `drive(ctx)` (qui remplace `SphereController._process`). L'enregistrement quitte `SphereController._ready` (l'enfant étant ready avant le parent, `_apply_visual()` est rejoué en fin de `_ready` du parent pour la teinte passive). |
| Caméra | `SphereCamera.gd` → **`CameraRig.gd`** (uid conservé via le sidecar `.uid`). `apply_config(cfg)` aiguille sur `mode` (`&"follow"` / `&"topdown"` / `&"fixed"`) ; FOLLOW/RTS → `sphere_follow.tres` / `sphere_rts.tres`. Le zoom molette reste un **état du rig** (semé par la 1ʳᵉ config topdown puis borné) pour survivre aux bascules et transferts, comme l'ancien export. `SpringArm3D` non retenu (reporté). |
| Périphériques | `Enemy._nearest_sphere()` filtre les sphères du pool hétérogène ; `GameManager` remplace ses lectures `spheres.is_empty()` par un flag `_game_over` ; `SphereController._die()` déclenche le game over quand plus aucune **sphère** ne reste (la balise ne compte pas) ; HUD type-agnostique (`Possessing: <nom>` pour une non-sphère). |
| Preuve 5.4 | `ShoreBeacon.tscn` + `BeaconControllable.gd` + `beacon_topdown.tres` : pylône de cristal statique au sud (`(0, 0, -13)`), vue top-down, cristal qui s'illumine à la possession. Intégré **sans toucher** aux fichiers 5.0–5.3. |
| Preuve IA | `Tests/SyntheticDriveTest.tscn` : un `InputContext` fabriqué à la main (move_vector avant) poussé via `controllable.handle_input()` fait rouler la sphère de **3,1 m** en headless, sortie 0 = PASS. |
| Hors périmètre (assumé) | La visée du `Reactor` (souris/stick) garde sa propre lecture d'entrée — sa migration vers `look_vector` est notée pour plus tard. `look_vector` est réservé mais non alimenté. |

---

## Critères de validation

- [x] 5.0 : les trois contrats existent, le jeu est inchangé, aucune erreur console *(vérifié headless, 120 frames)*
- [x] 5.1 : plus aucun `Input.*` dans `SphereController` ni dans les états de contrôle *(grep : seuls `InputContext`, `Reactor` — visée, hors périmètre — et `CameraRig` lisent `Input`)* — **feel à confirmer en playtest manuel** (préservé par conception : `refresh_held()` ré-échantillonne l'état maintenu à la cadence physique)
- [x] 5.2 : `Consciousness` ne référence plus `SphereController` ; l'activation initiale passe par les `Controllable` *(headless OK ; Tab à confirmer en jeu)*
- [x] 5.3 : FOLLOW et RTS fonctionnent depuis `sphere_follow.tres` / `sphere_rts.tres` *(la touche C cycle les configs du `Controllable` actif — à confirmer en jeu)*
- [x] 5.4 : la `ShoreBeacon` (non-sphère, top-down) est possédable **sans avoir touché** aux fichiers de 5.0–5.3 (uniquement des fichiers nouveaux + une instance dans `Main.tscn`)
- [x] Un `InputContext` synthétique fait rouler une sphère de 3,1 m sans clavier — `Tests/SyntheticDriveTest.tscn`, PASS en headless (preuve du chemin IA)
- [ ] Pas d'erreur console sur un run complet (transfert, combat, vague, game over) — *headless propre sur 300 frames avec vague 1 active ; le cycle complet jusqu'au game over reste à jouer*

### Reste à valider manuellement (playtest)

1. Game feel 5.1 : roulement caméra-relatif, buffer de saut, double saut,
   boost maintenu, tir visé, recast AOE.
2. Tab : cycle sphère 1 → 2 → 3 → balise → 1, recolorations comprises.
3. C : bascule follow ↔ topdown sur une sphère ; zoom molette conservé.
4. Run complet jusqu'au game over + restart Entrée.

---

## À ne PAS faire dans cette phase

- Pas de nouvelle capacité ni de nouvelle arme (la sphère garde tir + AOE, point)
- Pas de réorganisation `scenes/` / `scripts/` (nettoyage séparé, non bloquant)
- Pas de vraie IA — l'`InputContext` synthétique de validation suffit à prouver le chemin

---

*Phase précédente : phase4_loop.md — Concept global : PLAN.md*
