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

Réorganisé (2026-07-05) selon les recommandations Godot : **par fonctionnalité**
(chaque entité regroupe sa scène, ses scripts et ses ressources) et fichiers en
**snake_case**. Les `class_name` restent en PascalCase — les docs de phase
référencent les classes (`SphereController`, `CameraRig`…), qui n'ont pas changé.

```
res://
├── autoloads/
│   ├── consciousness.gd     (registre de Controllable, transfert au Tab, InputContext/frame)
│   ├── game_manager.gd      (boucle vagues/zones, Game Over, redémarrage)
│   └── economy.gd           (pool de ressources du joueur, phase 8.1)
├── core/                    ← contrats de possession + caméra (phase 5)
│   ├── controllable.gd      (Node — contrat de possession, composant enfant)
│   ├── input_context.gd     (RefCounted — entrée normalisée, seule classe à lire Input.*)
│   ├── camera_config.gd     (Resource — config caméra en données ; free_pan pour le
│   │                         mode topdown libre RTS, phase 8.1)
│   ├── camera_rig.gd        (Camera3D — applique les CameraConfig ; C cycle ; visée)
│   ├── aim_strategy.gd + mouse_cursor_aim.gd + screen_center_aim.gd (Strategy écran→monde)
│   └── faction.gd           (RefCounted — Faction.Kind ALLY/ENEMY, phase 7)
├── levels/
│   ├── main.tscn / main.gd  (scène principale : arène + 3 sphères + balise + mage + HUD)
│   ├── level2_front.tscn / level2_front.gd (phase 7 : deux Base + mage, scène séparée)
│   └── test_scene.tscn      (bac à sable parkour, Ball inline)
├── entities/
│   ├── sphere/              (sphere.tscn, sphere_controller.gd, sphere_controllable.gd,
│   │                         états MOVE/ATTACK, reactor.gd, projectile.*, aoe_orb.*,
│   │                         aoe_blast.*, sphere_follow.tres, sphere_rts.tres)
│   ├── mage/                (rune_mage.tscn/.gd, rune_mage_controllable.gd, sorts :
│   │                         rune_bolt.*, rune_flux.*, rune_mark.gd, rune_cage.gd,
│   │                         mage_topdown.tres ; déplacement ZQSD caméra-relatif
│   │                         depuis phase 8.2 — plus de click-to-move, chaque
│   │                         RuneMage naît d'une possession via possession_swap.gd)
│   ├── beacon/              (shore_beacon.tscn, beacon_controllable.gd, beacon_topdown.tres)
│   ├── enemy/               (enemy.tscn/.gd — cube, layer 2, groupe "enemies" ; phase 1-4)
│   ├── base/                (base.tscn/.gd — spawner phase 7, vagues type LoL + GoalZone ;
│   │                         base_controllable.gd + base_freepan.tres — Base possédable/
│   │                         jouable, tir à distance + achat de slot, phase 8.1)
│   ├── front_unit/          (front_unit.gd + ally_unit.tscn/enemy_unit.tscn — phase 7,
│   │                         unité autonome faction ALLY/ENEMY, indépendante de
│   │                         Consciousness/GameManager ; comportement détaillé et
│   │                         tenu à jour dans Docs/front/front_unit_ai.md ;
│   │                         possession_swap.gd — service statique FrontUnit ↔
│   │                         RuneMage (swap, pas contrat Controllable), phase 8.2)
│   ├── shared/              (health.gd, escort_gate.gd + .tscn — composants réutilisables
│   │                         PV générique / garde-de-portée-avec-riposte ; phase 7,
│   │                         détail à jour dans Docs/front/tower.md ; loot_on_death.gd —
│   │                         paie l'Economy à la mort d'un ennemi, phase 8.1)
│   └── tower/               (tower.gd + tower.tscn — objectif tour phase 7, compose
│                             Health + EscortGate ; détail à jour dans Docs/front/tower.md)
├── shaders/                 (8 sphere_*.gdshader tribu/état : active, crystallized,
│                             danger, destroyed, spectral, obscure, angular, pixelated ;
│                             + breathing_dent, cheese_holes — utilitaires de déformation)
├── ui/
│   ├── hud.gd               (Label de debug : entité possédée, cooldowns, caméra)
│   └── hp_bar_3d.gd         (barre de vie billboard)
├── tests/                   (synthetic_drive_test.*, rune_chain_test.*,
│                             base_possession_test.* (phase 8.1),
│                             possession_swap_test.* (phase 8.2) — headless, code retour ;
│                             shader_gallery.tscn — revue à plat des 8 shaders ;
│                             shader_showcase.tscn/.gd — scène deux zones (Sphérique/Angulaire) ;
│                             shader_lab.tscn — bac à sable shader-artist)
├── Docs/
│   ├── Plans/               (ce plan + les prompts de phase, PLAN.md inclus)
│   └── front/               (front_unit_ai.md, tower.md — référence technique à jour
│                             phase 7, tenue à jour à chaque changement de comportement)
├── icon.svg
└── project.godot
```

> Deux autoloads existent : `Consciousness` (phase 2) et `GameManager`
> (phase 4). Les uid Godot ont survécu au déplacement (sidecars `.uid`
> déplacés avec leurs scripts) ; tous les chemins `res://` ont été réécrits.

---

## Les phases

| Phase | Fichier prompt | Objectif | État |
|-------|---------------|----------|------|
| 1 | `phase1_movement.md` | Sphère contrôlable (mouvement) | ✅ Implémenté (système reactor-ball ; d'autres systèmes à venir) |
| 2 | `phase2_transfer.md` | Transfert de conscience | ✅ Implémenté (adapté au reactor-ball : sphères figées par `freeze`) |
| 3 | `phase3_combat.md` | Ennemis + combat + HP | ✅ Implémenté (adapté au reactor-ball ; HP greffés sur `SphereController`) |
| 4 | `phase4_loop.md` | Boucle complète (vagues, zones, game over) | ✅ Implémenté (attaque = projectile visé souris sur `A`) |
| 5 | `phase5_possession.md` | Possession multi-perspective (`Controllable` / `InputContext` / `CameraConfig`) | ✅ Implémenté et playtesté (branche `phase5-possession` ; balise non-sphère possédable + test IA) |
| 6 | `phase6_runemage.md` | RuneMage : gameplay MOBA à la Ryze (click-to-move, curseur ciblant, sorts A/Z/E) | ✅ Implémenté et playtesté manuellement (branche `gameplay-ryze`) |
| 7 | `phase7_front.md` (comportement `FrontUnit` : `Docs/front/front_unit_ai.md` ; tour objectif : `Docs/front/tower.md`) | Le Front : bases spawnant des unités autonomes qui s'affrontent entre les deux bases, tour intermédiaire à détruire pour gagner (scène séparée `level2_front.tscn`) | ✅ Implémenté et playtesté manuellement (sans PV de base ni condition de défaite) |
| 8 | `phase8_foundations.md` | Prérequis : Base jouable + économie (8.1), possession `FrontUnit ↔ RuneMage` complète (8.2) | ✅ 8.1 et 8.2 implémentées et playtestées manuellement (branche `phase8-foundations`) |
| 9 | `phase9_micro_poc.md` | POC Micro : défense de Base (9.1), possession d'unité (9.2), relief/obstacles (9.3) | 📝 Planifiée en détail, pas encore implémentée |

---

## Notes 3D

- Le jeu se joue sur un **plan horizontal** (XZ). Y est la hauteur (saut, boost,
  plateformes).
- La sphère active est actuellement une **`RigidBody3D`** simulée par **Jolt
  Physics** (`3d/physics_engine="Jolt Physics"`), pilotée dans
  `_integrate_forces()`. *(Un système antérieur du plan supposait
  `CharacterBody3D` + `move_and_slide()` ; ce n'est plus le cas.)*
- La **caméra n'est pas une vue isométrique fixe** : `CameraRig.gd` applique
  des **`CameraConfig` en données** exposées par l'entité possédée — pour la
  sphère : **follow** (chase-cam, `sphere_follow.tres`) et **topdown** (vue
  surélevée à la StarCraft/LoL, `sphere_rts.tres`), cyclées avec la touche **C**.
- Les ennemis (phase 3) seront des **cubes** (`BoxMesh`) gris se déplaçant sur
  le plan XZ (probablement `CharacterBody3D` + `move_and_slide()` ou
  `direction_to()`).

---

## Hors scope v0.1

- Bibliothèque de capacités (une seule capacité hardcodée en Phase 4)
- Système de méta-progression
- UI soignée
- NavigationAgent3D (pathfinding simple avec `direction_to()` suffit)

> La direction artistique / shaders / tribus n'est plus hors scope : 8 shaders
> `sphere_*` (états/tribus sphère vs cube) existent depuis le 2026-07-11
> (`tests/shader_gallery.tscn` + `tests/shader_showcase.tscn`), et sont en
> cours d'application aux entités de jeu réelles (RuneMage).

---

## Boucle de gameplay visée et prochaine phase

Voir `LOOP_SPHERE_FRONT.md` — la boucle Micro/Méso/Macro visée, l'état de
son implémentation par rapport à cette table de phases, et la prochaine
phase (9, POC Micro) à planifier en détail.

## Points à régler dans le jeu (dette identifiée, pas des questions de design)

- **Différenciation `select` / `attack` sur le clic gauche — à revoir.**
  Les deux actions sont mappées sur le même bouton et se départagent
  uniquement par **l'ordre de résolution** : `BaseControllable`/
  `RuneMageControllable` lisent `select` et font un `return` anticipé si le
  clic a touché une cible possédable, sinon le clic descend vers
  `drive()`/`attack` (mis en place phase 8.2, cf. H2 de
  `phase8_foundations.md` ; le `Hull` ajouté en 9.1 rend la résolution
  encore un peu plus subtile, deux nœuds différents pouvant désormais
  résoudre vers la même `Base`). Ça marche et c'est playtesté, mais c'est
  implicite : le comportement d'un clic dépend de ce qui se trouve sous le
  curseur, sans aucun retour visuel préalable au joueur, et toute nouvelle
  entité possédable doit penser à respecter cet ordre. À reprendre avec un
  mécanisme explicite (curseur contextuel, modificateur clavier, boutons
  distincts, ou un vrai routeur d'entrée) plutôt qu'à étendre l'ordre
  actuel indéfiniment.

## Questions ouvertes (pour v0.2)

- Quel(s) système(s) de mouvement retenir parmi ceux prototypés ?
- Comment le joueur obtient-il de nouvelles sphères en cours de run ?
- Les capacités sont-elles choisies avant ou pendant la partie ?
- La caméra doit-elle montrer tout le champ de bataille ou rester proche de la
  sphère active ? *(Le mode RTS adresse déjà partiellement cette question.)*
- Les ennemis ciblent-ils toujours la sphère active ou peuvent-ils ignorer la
  conscience ?
- La conscience doit-elle pouvoir posséder **autre chose que des sphères**
  (base RTS, véhicule, tourelle) ? *(Architecture détaillée dans
  `phase5_possession.md`.)*

---

*Commencer par : `phase1_movement.md`*
