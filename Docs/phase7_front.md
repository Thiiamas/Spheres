# Phase 7 — Le Front : base contre base

> **Note de synchro (docs ↔ code).** Rédigé et **implémenté** le 2026-07-20
> dans une scène séparée (`levels/level2_front.tscn`) qui ne modifie **aucun**
> fichier de la boucle de la phase 4 (`autoloads/game_manager.gd`,
> `entities/enemy/enemy.gd`, `levels/main.tscn`). Prototype v1 : à playtester.
>
> Le détail technique **à jour** du mouvement/combat de `FrontUnit` (timers,
> priorité des branches, paramètres) vit dans `Docs/front_unit_ai.md`, tenu à
> jour à chaque changement de comportement. Ce fichier-ci garde l'historique
> (pourquoi, essais ratés, dates) — pas la référence.

## Objectif

Tester une **forme de jeu différente** de la défense de vagues : un **front
actif**. Deux **bases** font entrer en jeu des unités qui **avancent l'une
vers l'autre** et se battent **entre les deux bases** — c'est ce combat
mobile, pas une ligne de défense statique, qui constitue « le front ».

- Chaque **`Base`** (`entities/base/base.gd`) fait apparaître, **par vagues à
  intervalle régulier** (`wave_interval`), des instances de `FrontUnit` de sa
  propre faction — modèle League of Legends (minions), pas un flux continu :
  chaque camp pousse par à-coups, pas en continu. *(Première itération : flux
  continu goutte-à-goutte ; changé le 2026-07-24, le comportement ne lisait
  pas comme un vrai front.)* Dans une vague, les `wave_size` unités sortent
  **l'une après l'autre** (`wave_unit_spacing` secondes d'écart, 0.75s par
  défaut) plutôt que toutes en même temps — lisible comme une file qui sort de
  la base — et se répartissent le long d'une ligne de `wave_spread` de
  large, perpendiculaire au couloir. La toute première vague de chaque base
  est déclenchée explicitement par `levels/level2_front.gd`
  (`Base.spawn_wave_now()`) juste après avoir câblé `advance_target`, pour que
  le combat démarre dès le lancement plutôt que d'attendre `wave_interval`.
- Chaque **`FrontUnit`** (`entities/front_unit/front_unit.gd`) avance vers la
  base adverse (`target_base`) ; si une unité hostile entre dans sa portée
  d'engagement, elle s'arrête sur elle et mord — deux lignes qui avancent
  finissent par se rencontrer et se battre au milieu.
- La victoire est déclarée dès qu'une unité **alliée** entre dans la
  `GoalZone` de la base **ennemie** (`Base.unit_reached_goal`) — pas de PV de
  base ni d'attaque de structure en v1.
- Pas de condition de défaite en v1 (prototype de la boucle
  spawn → poussée → combat → victoire, hors scope pour l'instant).

## Ce qui est réutilisé tel quel

- Le joueur commence en possession du **RuneMage** (phase 6), instancié comme
  dans `levels/main.tscn` avec son `CameraRig` et son `HUD` — la caméra et le
  HUD sont *duck-typés* sur le contrat `Controllable` (`core/controllable.gd`,
  `core/camera_rig.gd`, `ui/hud.gd`), donc rien à modifier côté framework.
- Le décor d'arène (`WorldEnvironment`, `DirectionalLight3D`, sol, murs) est
  copié/adapté de `levels/main.tscn`, étiré en Z pour laisser de la place au
  couloir de front.

## Ce qui est nouveau et pourquoi

- `core/faction.gd` (`Faction.Kind { ALLY, ENEMY }`) : contrat minuscule
  partagé par `Base` et `FrontUnit` pour qu'ils s'accordent sur les camps,
  et pour dériver le nom de groupe (`front_ally` / `front_enemy`) utilisé
  pour le ciblage — pas de requête physique, comme
  `entities/enemy/enemy.gd` scanne aujourd'hui `Consciousness.entities`.
- `FrontUnit` est une **entité neuve, autonome**, pas une `SphereController`
  allégée : la sphère du joueur (réacteur, saut, boost) reste un système de
  mouvement possédé, pas une IA. `FrontUnit` ne dépend ni de `Consciousness`
  ni de `GameManager` : sa mort émet un signal `died` (zéro couplage avec la
  boucle de la phase 4). `Base` ne compte plus les unités vivantes via ce
  signal — elle interroge directement la taille du groupe de faction au
  moment de spawner une vague (`max_alive` en garde-fou anti-accumulation).
- Deux scènes fines (`ally_unit.tscn` / `enemy_unit.tscn`) partagent le même
  script, distinguées par `faction` + apparence : la sphère alliée reprend
  `shaders/sphere_active.gdshader` (déjà utilisé pour le glow de possession
  du RuneMage) pour se lire comme « tribu sphère » ; le cube ennemi reprend
  le matériau gris plat de `entities/enemy/enemy.tscn` pour la continuité
  visuelle avec le lore sphère-contre-cube.

## Le RuneMage peut cibler les cubes du front

Playtesté le 2026-07-24 : le joueur ne pouvait ni endommager ni cibler les
cubes ennemis avec ses sorts. Corrigé en réutilisant les mêmes interfaces que
`entities/enemy/enemy.gd` (`take_hit`, `root`, groupe `"enemies"`, layer
physique 2), sans toucher au code des sorts. Détail complet (pourquoi ces
noms précis, pourquoi le layer 2) : `Docs/front_unit_ai.md`.

## Les cubes se bloquaient entre eux — deux passes

Playtesté le 2026-07-24. **Première passe** (insuffisante) : poussée
latérale locale entre unités proches, en pensant que le blocage venait d'un
manque d'évitement — aucun effet visible, les cubes restaient massés en bloc.
**Cause réelle** : chaque unité visait le point exact de sa cible, identique
pour toutes celles qui convergeaient dessus — un problème de convergence, pas
d'évitement. **Correctif** : chaque unité vise désormais un point sur un
cercle autour de la cible, propre à elle (dérivé de son `instance_id`),
l'évitement local ne faisant plus que le rattrapage résiduel. Mécanique
complète : `Docs/front_unit_ai.md`.

## Attaque de base à la League of Legends (immobile pendant le coup)

Ajouté le 2026-07-24 : une attaque était jusqu'ici instantanée sans
immobiliser l'unité. Un deuxième minuteur (`attack_duration`, indépendant du
cooldown) la plante désormais en place pendant le geste, comme un champion
LoL pendant l'animation de son auto-attaque. Chronologie, priorité des
branches et le knob de kiting : `Docs/front_unit_ai.md`.

## Hors scope (noté pour la suite)

- Pas de PV de base, pas de condition de défaite, pas de possession d'une
  `FrontUnit` par le joueur — tout ça est prévu plus tard (voir
  `Docs/PLAN.md`, « Questions ouvertes »).

## Fichiers

- `core/faction.gd`
- `entities/base/base.gd`, `entities/base/base.tscn`
- `entities/front_unit/front_unit.gd`, `ally_unit.tscn`, `enemy_unit.tscn` —
  comportement détaillé dans `Docs/front_unit_ai.md`
- `levels/level2_front.tscn`, `levels/level2_front.gd`
