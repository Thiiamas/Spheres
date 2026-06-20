# Spheres — Plan d'implémentation Godot 4 (3D)

> **Projet Godot :** `Spheres` (`config/name="Spheres"`, scène principale
> `res://Main.tscn`). `res://TestScene.tscn` reste un bac à sable (parkour de
> test). *"The Shore"* était un titre de travail antérieur.
>
> **Règle d'or :** chaque phase produit quelque chose de jouable.
> Ne pas passer à la suivante avant que la précédente soit stable et fun.

---

## Concept core

Le joueur incarne une **conscience** capable de prendre possession de sphères
alliées sur le champ de bataille. Le jeu est un **wave defense** (défense de
vagues).

- **Une seule sphère active à la fois** — contrôlée par le joueur
- **Les autres sphères sont passives** — cristallisées, immobiles, très
  résistantes, elles bloquent les ennemis
- **Les ennemis sont angulaires** (cubes/rectangles) et attaquent les sphères
- **Boucle** : repousser une vague → avancer vers la zone suivante

---

## Le mouvement est un système expérimental (swappable)

> ⚠️ **Important pour la synchro docs/code.** Le **mouvement de la sphère active
> n'est pas figé** : plusieurs systèmes de déplacement sont prototypés et
> comparés. Le concept du jeu (wave defense / transfert de conscience) ne dépend
> pas du système de mouvement choisi.

- **Système de mouvement actuellement implémenté : "reactor-ball platformer".**
  La sphère active est une `RigidBody3D` qui **roule** au sol, **saute**,
  **double-saute** et **booste** en l'air via la direction d'un réacteur
  orientable. Détail complet dans `phase1_movement.md`.
- Les phases 2 à 4 ci-dessous décrivent la **logique de jeu** (transfert,
  combat, boucle) qui se greffe **par-dessus** le mouvement, quel qu'il soit.
  Leurs extraits de code qui supposent un `CharacterBody3D` simple sont
  **illustratifs** et doivent être adaptés au contrôleur actif.

---

## Structure du projet (état actuel)

Les fichiers sont actuellement **à plat** à la racine `res://` (pas encore de
dossiers `scenes/` / `scripts/`) :

```
res://
├── Main.tscn             ← scène principale (arène bornée + 3× Sphere.tscn + caméra + HUD + UI)
├── TestScene.tscn        ← bac à sable (sol + niveau parkour + Ball inline + caméra + HUD)
├── Sphere.tscn           ← sphère joueur réutilisable (RigidBody + mesh + collision + Reactor + HPBar + projectile)
├── Enemy.tscn            ← cube ennemi (CharacterBody3D + AttackZone ; layer 2)
├── Projectile.tscn       ← tir du joueur (Area3D ; masque layer 2 = ennemis)
├── Main.gd               (Node3D — bootstrap : démarre la 1ʳᵉ vague via GameManager)
├── SphereController.gd    (RigidBody3D — mouvement reactor-ball ; actif/passif ; HP ; attaque projectile)
├── Reactor.gd             (Node3D — tuyère orientable, produit la direction de poussée)
├── SphereCamera.gd        (Camera3D — FOLLOW / RTS ; suit l'active ; fournit la cible de visée)
├── AimStrategy.gd         (RefCounted — Strategy : écran→monde ; + MouseCursorAim / ScreenCenterAim)
├── HUD.gd                 (Label de debug : sphère active, état, angles réacteur, vitesse, caméra)
├── HPBar3D.gd             (Node3D — barre de vie billboard flottant au-dessus de la sphère)
├── Enemy.gd               (CharacterBody3D — IA : marche vers la sphère la plus proche ; HP, take_hit)
├── Consciousness.gd       (Autoload — registre des sphères, transfert au Tab, mort/réassignation)
├── GameManager.gd         (Autoload — boucle vagues/zones, Game Over, redémarrage)
└── Docs/                  (ce plan + les prompts de phase)
```

> Réorganiser en `scenes/` / `scripts/` est une tâche de nettoyage future, non
> bloquante. Deux autoloads existent : `Consciousness` (phase 2) et
> `GameManager` (phase 4).

---

## Les 4 phases

| Phase | Fichier prompt | Objectif | État |
|-------|---------------|----------|------|
| 1 | `phase1_movement.md` | Sphère contrôlable (mouvement) | ✅ Implémenté (système reactor-ball ; d'autres systèmes à venir) |
| 2 | `phase2_transfer.md` | Transfert de conscience | ✅ Implémenté (adapté au reactor-ball : sphères figées par `freeze`) |
| 3 | `phase3_combat.md` | Ennemis + combat + HP | ✅ Implémenté (adapté au reactor-ball ; HP greffés sur `SphereController`) |
| 4 | `phase4_loop.md` | Boucle complète (vagues, zones, game over) | ✅ Implémenté (attaque = projectile visé souris sur `A`) |

---

## Notes 3D

- Le jeu se joue sur un **plan horizontal** (XZ). Y est la hauteur (saut, boost,
  plateformes).
- La sphère active est actuellement une **`RigidBody3D`** simulée par **Jolt
  Physics** (`3d/physics_engine="Jolt Physics"`), pilotée dans
  `_integrate_forces()`. *(Un système antérieur du plan supposait
  `CharacterBody3D` + `move_and_slide()` ; ce n'est plus le cas.)*
- La **caméra n'est pas une vue isométrique fixe** : `SphereCamera.gd` propose
  deux modes — **FOLLOW** (chase-cam derrière la balle) et **RTS** (vue
  surélevée à la StarCraft/LoL), basculés avec la touche **C**.
- Les ennemis (phase 3) seront des **cubes** (`BoxMesh`) gris se déplaçant sur
  le plan XZ (probablement `CharacterBody3D` + `move_and_slide()` ou
  `direction_to()`).

---

## Hors scope v0.1

- Bibliothèque de capacités (une seule capacité hardcodée en Phase 4)
- Direction artistique / shaders / tribus
- Système de méta-progression
- UI soignée
- NavigationAgent3D (pathfinding simple avec `direction_to()` suffit)

---

## Questions ouvertes (pour v0.2)

- Quel(s) système(s) de mouvement retenir parmi ceux prototypés ?
- Comment le joueur obtient-il de nouvelles sphères en cours de run ?
- Les capacités sont-elles choisies avant ou pendant la partie ?
- La caméra doit-elle montrer tout le champ de bataille ou rester proche de la
  sphère active ? *(Le mode RTS adresse déjà partiellement cette question.)*
- Les ennemis ciblent-ils toujours la sphère active ou peuvent-ils ignorer la
  conscience ?

---

*Commencer par : `phase1_movement.md`*
