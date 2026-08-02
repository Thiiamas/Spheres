# Phase 7 — Le Front : base contre base

> **Note de synchro (docs ↔ code).** Rédigé et **implémenté** le 2026-07-20
> dans une scène séparée (`levels/level2_front.tscn`) qui ne modifie **aucun**
> fichier de la boucle de la phase 4 (`autoloads/game_manager.gd`,
> `entities/enemy/enemy.gd`, `levels/main.tscn`). Prototype v1, avec tour
> intermédiaire : **implémenté et playtesté manuellement** (2026-08-02, deux
> passes de correctifs, voir plus bas).
>
> Le détail technique **à jour** du mouvement/combat de `FrontUnit` (timers,
> priorité des branches, paramètres) vit dans `Docs/front/front_unit_ai.md`, tenu à
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
noms précis, pourquoi le layer 2) : `Docs/front/front_unit_ai.md`.

## Les cubes se bloquaient entre eux — deux passes

Playtesté le 2026-07-24. **Première passe** (insuffisante) : poussée
latérale locale entre unités proches, en pensant que le blocage venait d'un
manque d'évitement — aucun effet visible, les cubes restaient massés en bloc.
**Cause réelle** : chaque unité visait le point exact de sa cible, identique
pour toutes celles qui convergeaient dessus — un problème de convergence, pas
d'évitement. **Correctif** : chaque unité vise désormais un point sur un
cercle autour de la cible, propre à elle (dérivé de son `instance_id`),
l'évitement local ne faisant plus que le rattrapage résiduel. Mécanique
complète : `Docs/front/front_unit_ai.md`.

## Attaque de base à la League of Legends (immobile pendant le coup)

Ajouté le 2026-07-24 : une attaque était jusqu'ici instantanée sans
immobiliser l'unité. Un deuxième minuteur (`attack_duration`, indépendant du
cooldown) la plante désormais en place pendant le geste, comme un champion
LoL pendant l'animation de son auto-attaque. Chronologie, priorité des
branches et le knob de kiting : `Docs/front/front_unit_ai.md`.

## Objectif intermédiaire : la Tour (2026-08-02)

Ajouté pour donner un vrai enjeu au combat entre les deux bases : sans elle,
une vague alliée qui atteint la `GoalZone` ennemie gagnait immédiatement,
sans forcer le joueur à se battre pour le terrain. Demandé explicitement
comme **composant réutilisable** (« comme un composant Unity ») plutôt que
codé en dur sur un seul type d'ennemi.

- Une **`Tower`** (`entities/tower/tower.gd`) par base, immobile, ne peut être
  blessée par les sorts du RuneMage **que si une unité alliée est à portée**
  — forçant le joueur à pousser sa vague (tuer les `FrontUnit` ennemis,
  garder les siens en vie) avant que ses sorts ne fassent quoi que ce soit.
  Sans escorte, la tour **riposte** contre le joueur (dégâts lourds,
  périodiques) — un déterrent à la « plongée solo » façon tourelle MOBA.
- La victoire (`level2_front.gd`) est maintenant gardée derrière la
  destruction de la tour ennemie, pas seulement l'arrivée d'une unité en
  `GoalZone` — « détruite pour accéder au reste de la carte » devient
  littéral, sans blocage physique.
- Implémentation en trois pièces indépendantes plutôt qu'un composant
  unique fourre-tout : `Health` (réserve de PV générique, sans notion de
  faction ni de portée), `EscortGate` (le comportement « vulnérable
  seulement escorté, sinon riposte », sans notion de PV), et `Tower`
  (l'entité concrète qui compose les deux et décide de leur interaction).
  Détail technique complet, à jour, dans `Docs/front/tower.md` — ce fichier-ci ne
  garde que le pourquoi.
- `FrontUnit` a été refactoré pour utiliser ce même `Health` (au lieu de sa
  propre implémentation dupliquée de `hp`/`max_hp`/`take_damage`) — la
  première preuve que le composant est réellement générique. Voir
  `Docs/front/front_unit_ai.md`.
- La riposte de la tour rend la mort du RuneMage possible pour la première
  fois (`RuneMage` avait déjà `hp`/`take_damage`/`_die()` depuis la phase 6,
  mais rien ne l'utilisait en combat jusqu'ici). `_die()` gagne un signal
  `died` ; `level2_front.gd` y réagit avec un respawn minimal (message bref,
  pause, nouvelle instance près de `PlayerBase`) plutôt qu'un vrai écran de
  défaite — toujours hors scope, voir plus bas.

### Premier playtest : trois correctifs (2026-08-02)

- **Riposte silencieuse** : la tour infligeait ses dégâts instantanément,
  sans aucun signal visuel — le joueur mourait sans comprendre pourquoi.
  `EscortGate` tire désormais un projectile visible (`TowerBolt`, homing,
  même forme que `RuneFlux`) qui applique les dégâts à l'arrivée plutôt
  qu'au moment de la décision. Détail : `Docs/front/tower.md`.
- **Minions indifférents à la tour** : une vague poussée ignorait
  complètement la `Tower` et se contentait d'affronter les minions ennemis à
  côté. `FrontUnit` cible maintenant la tour adverse en priorité (tant
  qu'elle est en vie et à portée) au lieu du minion hostile le plus proche —
  la vague assiège vraiment l'objectif. Détail : `Docs/front/tower.md`,
  `Docs/front/front_unit_ai.md`.
- **Barre de vie du joueur cassée** : `rune_mage.tscn` avait un bug
  préexistant (matériaux manquants sur les meshes de la barre — bloc blanc
  sans contraste) en plus d'une implémentation PV encore indépendante.
  `RuneMage` est refactoré sur le même composant `Health` que `FrontUnit`, et
  les matériaux sont corrigés. Détail : `Docs/front/tower.md`.

### Deuxième playtest : deux correctifs (2026-08-02)

- **`PlayerTower` punissait son propre joueur** : la riposte ne vérifiait que
  « y a-t-il un joueur dans la zone », pas de quel camp il est — la tour
  alliée ripostait donc contre le RuneMage exactement comme la tour ennemie.
  Corrigé en séparant détection physique (layer) et camp (donnée de jeu) :
  `RuneMage` porte désormais `faction` comme `FrontUnit`/`Tower`/`Base`, et
  `EscortGate` exclut un assaillant du même camp qu'elle avant de riposter.
  Détail (et alternative écartée : un layer par camp de joueur, jugée
  sur-dimensionnée pour un seul joueur toujours allié) : `Docs/front/tower.md`.
- **Crash à la mort de la tour ennemie** : `Base` spawnait la vague suivante
  en assignant une référence déjà libérée (`Tower.queue_free()` ne nettoie
  pas les références des *autres* nœuds) à `target_tower` — exception
  Godot sur l'assignation, pas sur la lecture. Corrigé par un garde
  `is_instance_valid()` à l'assignation. Détail : `Docs/front/tower.md`.

Playtesté ensuite : les deux tours encaissent maintenant correctement les
dégâts des `FrontUnit` de la faction escortante (alliés contre `EnemyTower`,
ennemis contre `PlayerTower`) — confirmé fonctionnel dans les deux sens.

## Hors scope (noté pour la suite)

- Pas de PV de **base** (seule la `Tower` en a), pas de condition de
  défaite, pas de possession d'une `FrontUnit` par le joueur — tout ça est
  prévu plus tard (voir `Docs/Plans/PLAN.md`, « Questions ouvertes »).
- **`PlayerTower` n'est plus à l'abri** (correction 2026-08-02 : l'ancienne
  note ici, « ne risque rien », était fausse dès l'ajout du siège de tour par
  les `FrontUnit` — une vague ennemie qui atteint `PlayerTower` avec plusieurs
  unités l'endommage tout autant qu'une vague alliée endommage `EnemyTower`).
  Ce qui reste hors scope : **rien n'écoute `PlayerTower.died`** —
  contrairement à `EnemyTower.died` (porte de victoire), la destruction de
  `PlayerTower` aujourd'hui ne fait que la faire disparaître silencieusement,
  sans condition de défaite ni message. À câbler en même temps que la
  défaite plus généralement.

## Fichiers

- `core/faction.gd`
- `entities/base/base.gd`, `entities/base/base.tscn`
- `entities/front_unit/front_unit.gd`, `ally_unit.tscn`, `enemy_unit.tscn` —
  comportement détaillé dans `Docs/front/front_unit_ai.md`
- `entities/shared/health.gd`, `entities/shared/escort_gate.gd` +
  `escort_gate.tscn`, `entities/tower/tower.gd` + `tower.tscn`,
  `entities/tower/tower_bolt.gd` + `tower_bolt.tscn` — comportement détaillé
  dans `Docs/front/tower.md`
- `entities/mage/rune_mage.gd`, `rune_mage.tscn` — refactoré sur `Health`,
  matériaux de barre de vie corrigés
- `levels/level2_front.tscn`, `levels/level2_front.gd`
