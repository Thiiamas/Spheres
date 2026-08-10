# Phase 9 — POC Micro : défense de Base

> **Objectif de cette phase.** Premier des trois POC de boucle annoncés par
> `LOOP_SPHERE_FRONT.md` : isoler le palier **Micro** (tuer un ennemi →
> ressources) pour en peaufiner le *feel*, avant d'empiler Méso (tour) puis
> Macro (capture de base) par-dessus dans les phases 10 et 11. Le joueur ne
> contrôle que sa **Base** (8.1) ; en face, uniquement des `FrontUnit` en
> mode ennemi — pas de vague alliée pour le joueur (ça viendra en Méso).
>
> Découpée en trois jalons, chacun dépendant de **9.1** : **9.1** (boucle de
> défense sur terrain plat — la fondation jouable), **9.2** (possession
> d'une unité — le palier Micro s'applique aussi au combat rapproché d'une
> entité possédée, pas seulement à la bombarde immobile de la Base), et
> **9.3** (relief/obstacles — le vrai test de robustesse du mouvement
> `FrontUnit`, identifié comme le point dur de ce POC).

---

## Organisation des scènes (`gameplay_loop/`)

Décision actée : chaque **palier de boucle** (Micro maintenant, Méso/Macro
plus tard) a son propre dossier de scènes, séparé de `levels/` (qui reste
pour les deux prototypes historiques, `main.tscn`/`level2_front.tscn`) —
`gameplay_loop/micro/`, puis `gameplay_loop/meso/`/`gameplay_loop/macro/`
en phases 10/11. Snake_case, cohérent avec le reste du projet
(`entities/`, `front_unit/`…).

À l'intérieur de `gameplay_loop/micro/`, **une scène par jalon**, pas une
seule scène qui évolue au fil de 9.1→9.2→9.3 :

- `micro_base_defense.tscn`/`.gd` (9.1)
- `micro_possession.tscn`/`.gd` (9.2)
- `micro_terrain.tscn`/`.gd` (9.3)

Chaque scène est **dupliquée et étendue** depuis celle du jalon précédent
(9.2 part de 9.1 + possession, 9.3 part de 9.2 + relief) plutôt que
modifiée en place — décision explicite pour que chaque jalon reste
rejouable et testable **isolément** même une fois le jalon suivant
commencé, ce qui est précisément le test de découplage recherché. Coût
accepté : de la duplication entre les trois scènes (mêmes `PlayerBase`/
`EnemyBase`/décor recopiés) plutôt qu'un seul fichier partagé.

---

## Ce que l'exploration du code a montré (avant de coder quoi que ce soit)

Point important, pas dans `LOOP_SPHERE_FRONT.md` : **rien aujourd'hui ne
permet à un `FrontUnit` d'endommager une `Base`.**

- `FrontUnit._try_attack()` ne reconnaît que deux types de cible :
  `body is FrontUnit and body.faction != faction` ou `body is Tower`.
- `Base` n'a même pas de corps physique solide : `GoalZone` et
  `SelectionArea` sont des `Area3D` (jamais retournées par
  `Area3D.get_overlapping_bodies()`), et il n'y a pas de troisième nœud de
  collision.

Sans changement, une vague ennemie marcherait jusqu'à la position de la
Base et... ne se passerait rien. Ce point (Base attaquable) est donc du
travail réel de cette phase, pas juste du level design — détaillé en 9.1.

---

## Hypothèses/décisions actées pour cette phase

| # | Sujet | Décision | Pourquoi |
|---|-------|----------|----------|
| H1 | Enjeu de la Base | La Base du joueur gagne des **PV réels** (composant `Health`, comme `Tower`/`FrontUnit`) ; à 0, **Game Over** (en 9.1, seule entité contrôlable du POC — 9.2 généralise cette règle à *toutes* les entités contrôlables du joueur). | Choix explicite : sans ça, le critère Micro *« les ennemis sont dangereux »* n'a pas de sens — il n'y aurait aucune conséquence à laisser une vague passer. |
| H2 | Type d'ennemi | **`FrontUnit` en mode `ENEMY`** (`enemy_unit.tscn`), pas `Enemy.tscn` (phase 3/4). | `Enemy.gd` cible exclusivement un `SphereController` via `Consciousness.entities` (`_nearest_sphere()`) — il ne peut pas du tout viser une `Base` sans réécriture. `FrontUnit`, lui, sait déjà avancer vers un `target_base: Node3D` générique (mécanique de la phase 7) : aucune modification de son ciblage/mouvement n'est nécessaire, seule son *attaque* doit apprendre à reconnaître une `Base` (H1). |
| H3 | Relief/obstacles | **9.1 sur couloir plat, 9.3 ajoute le relief** une fois la boucle de base validée en playtest — pas les deux d'un coup. | Isoler la variable : si le *feel* casse après l'ajout d'obstacles, on sait que c'est le relief et pas le spawn/l'équilibrage qui est en cause. |
| H4 | Économie (`buy_slot`/`wave_size`) | **Laissée inerte** dans ce POC — les ressources s'accumulent (`LootOnDeath` fonctionne déjà) mais rien ne les dépense ici. | Décision explicite de l'utilisateur : cette économie sert le palier Méso (vagues alliées), pas Micro. Pas de mécanique de dépense inventée prématurément. |
| H5 | La Base ne se `queue_free()` pas à 0 PV | Contrairement à `Tower`/`FrontUnit` (qui se libèrent à la mort), la Base **reste dans l'arbre**, juste inerte (`drive()` ignore les entrées suivantes) ; c'est le script de niveau qui affiche Game Over et arrête le spawn ennemi. | La Base du joueur est l'entité **possédée** activement au moment de sa mort (contrairement à `Tower`/`FrontUnit`, jamais possédées) — la libérer créerait une possession orpheline sans entité de repli (pas de RuneMage/Base de secours dans ce POC, contrairement au H3 de la phase 8 qui pouvait renvoyer sur la Base). |

---

## 9.1 — Défense de Base (terrain plat)

### Objectif

Nouvelle scène où le joueur possède sa Base dès le départ (comme en 8.1),
face à des vagues de `FrontUnit` ennemis qui avancent sur un couloir plat et
attaquent la Base à leur arrivée. Perdre toute sa vie affiche un Game Over.
Pas de Tour, pas de vague alliée — uniquement Base (joueur) vs `FrontUnit`
ennemis.

### Prérequis

Phase 8 stable (`BaseControllable`, `MortarShell`, `Economy`,
`LootOnDeath`) — tout est réutilisé tel quel.

### Sous-tâches

**1. Rendre `Base` attaquable — `entities/base/base.gd`/`.tscn`**
- Nouveau nœud enfant **`Hull`** (`StaticBody3D` + `CollisionShape3D`,
  cylindre reprenant les dimensions de `Structure`), **pas** un changement
  du type racine de `Base` (qui reste `Node3D`). Point d'attention vérifié
  avant de coder : `PossessionSwap.try_select_at_cursor()` résout un clic
  sur la Base via `hit.get_parent() as Base` — ça suppose que `hit` est un
  **enfant** de `Base` (aujourd'hui `SelectionArea`). Si `Base` devenait
  elle-même le `StaticBody3D`, un clic qui toucherait ce corps au lieu de
  `SelectionArea` casserait cette résolution (`hit.get_parent()` renverrait
  la scène, pas la Base). Avec `Hull` en enfant, `hit.get_parent() as Base`
  reste correct que le raycast touche `SelectionArea` ou `Hull`.
- `Hull.collision_layer = Faction.physics_layer(faction)` (même valeur que
  `FrontUnit`/`Tower` de la même faction), `collision_mask = 0` (la Base ne
  détecte rien elle-même). Assigné dans `Base._ready()`, comme les autres
  couches déjà réglées là.
- Effet de bord attendu, cohérent avec `Tower` : comme le masque de
  mouvement de `FrontUnit` inclut déjà `ALLY_LAYER | ENEMY_LAYER`, les
  unités **butent physiquement** sur `Hull` en plus d'être arrêtées par la
  portée d'engagement — pas de changement nécessaire côté `FrontUnit` pour
  ça.
- Nouveau enfant **`Health`** (`entities/shared/health.gd`, même composant
  que `Tower`/`FrontUnit`) + **`HPBar3D`** (`ui/hp_bar_3d.gd`, même patron
  visuel que `Tower`) — la Base affiche sa vie comme n'importe quelle autre
  entité dotée de PV.
- `Base` expose `@export var health: Health` (NodePath), un signal
  `died` (forwardé depuis `health.died`, même patron que `Tower`), et :
  ```gdscript
  func take_damage(amount: float) -> void:
      if _defeated:
          return
      health.take_damage(amount)
  ```
  **Pas** de `take_hit()` — décision délibérée : `MortarShell._explode()`
  ne cible que les corps avec `has_method("take_hit")` sur le layer ennemi
  (2). Sans `take_hit`, le mortier du joueur ne peut **pas** endommager la
  Base ennemie (spawner adverse) — ce POC porte sur tuer des unités, pas
  détruire des structures (ça viendra avec la capture de base, phase 11).
  `FrontUnit._try_attack()` appelle `take_damage` directement (typage
  explicite, voir sous-tâche 2), donc `take_hit` n'est nécessaire pour
  aucun chemin de dégâts utile ici.
- `_on_health_died()` : `_defeated = true; died.emit()` — **ne libère pas**
  la Base (H5). `drive()` gagne une garde `if _defeated: return` en
  première ligne, pour que la Base détruite ignore silencieusement tir et
  achat de slot plutôt que de crasher sur une entité à moitié morte.

**2. `FrontUnit` reconnaît la `Base` comme cible d'attaque**
- `entities/front_unit/front_unit.gd`, `_try_attack()` :
  ```gdscript
  if (body is FrontUnit and body.faction != faction) or body is Tower or body is Base:
  ```
  Aucune vérification de faction supplémentaire nécessaire — comme pour
  `Tower`, le filtrage se fait déjà par le masque de collision de
  `AttackZone` (`Faction.opposing_physics_layer(faction)`), qui ne peut de
  toute façon renvoyer que des corps de la faction adverse.
- Le **ciblage/mouvement** de `FrontUnit` n'a besoin d'aucune modification :
  `_current_target()` retombe déjà sur `target_base.global_position` quand
  ni tour ni hostile ne sont trouvés (aucune des deux n'existe dans ce
  POC) — les unités marchent donc déjà droit sur la Base adverse
  aujourd'hui, sans code supplémentaire.

**3. Nouvelle scène `gameplay_loop/micro/micro_base_defense.tscn` / `.gd`**
- Décor copié/adapté de `level2_front.tscn` (sol, murs, lumière,
  `WorldEnvironment`) — couloir plat pour 9.1, relief ajouté en 9.3.
- **`PlayerBase`** (`Base.tscn`) : `faction = ALLY`, `mortar_scene`/
  `mortar_blast_scene` assignés (comme 8.1), **`unit_scene` non assigné**
  (pas de vague alliée — `Base._on_wave_timer_timeout()` s'arrête déjà tôt
  quand `unit_scene == null`, aucun changement de code requis), `health`
  câblé au nouveau nœud `Health`.
- **`EnemyBase`** (`Base.tscn`) : `faction = ENEMY`, `unit_scene =
  enemy_unit.tscn`, `advance_target = PlayerBase`, pas de `mortar_scene`
  (ne tire pas), pas de possession (comme `EnemyBase` dans
  `level2_front.tscn`). Pas de `advance_target_tower` — inutilisé, reste
  `null`.
- Pas de `Tower` dans cette scène (le siège d'objectif est le palier
  Méso, phase 10).
- `micro_base_defense.gd` : câble `enemy_base.advance_target = player_base`,
  déclenche `enemy_base.spawn_wave_now()` au démarrage (même patron que
  `level2_front.gd`, pour ne pas attendre `wave_interval` avant le premier
  contact), connecte `player_base.died` → affichage d'un message Game Over
  (réutilise le patron `MessageLabel` de `level2_front.gd`) et
  `enemy_base.stop_spawning()`.
- HUD debug réutilisé tel quel (`Base.get_hud_lines()` déjà écrit en 8.1) ;
  la ligne `B: buy wave slot` reste affichée bien qu'inerte (H4) — pas de
  changement pour la cacher, à revoir si ça gêne en playtest.

**4. Réglage initial des paramètres de vague ennemie**
- Valeurs de départ pour le premier playtest (à ajuster, comme toujours) :
  `wave_interval` plus court que le défaut de phase 7 (10s) pour un rythme
  Micro plus serré, `wave_size` petit au début (1-2) pour valider la
  boucle avant de monter la pression.
- `EnemyBase.max_alive` : garde-fou déjà existant (phase 7), pas de
  nouveau réglage nécessaire à ce stade.

### Fichiers

- `entities/base/base.gd` (modifié — `Hull`, `Health`, `died`,
  `take_damage`, garde `_defeated` sur `drive()`)
- `entities/base/base.tscn` (modifié — nœuds `Hull`, `Health`, `HPBar3D`)
- `entities/front_unit/front_unit.gd` (modifié — `_try_attack()` reconnaît
  `Base`)
- `gameplay_loop/micro/micro_base_defense.tscn`/`.gd` (nouveau)

### Critères de validation

- [ ] La partie démarre avec la Base du joueur possédée, caméra libre,
      tir mortier fonctionnel (hérité de 8.1, à revérifier sans régression)
- [ ] Des vagues de `FrontUnit` ennemis spawnent depuis `EnemyBase` et
      avancent en ligne droite vers `PlayerBase`
- [ ] Un `FrontUnit` ennemi arrivé à portée **endommage** la Base (barre de
      vie visible qui baisse)
- [ ] Tuer un ennemi (mortier ou, à défaut, corps-à-corps s'il y avait une
      unité alliée — hors scope ici) rapporte des ressources visibles au HUD
- [ ] La Base à 0 PV affiche un message Game Over, arrête le spawn ennemi,
      et ignore silencieusement tir/achat de slot ensuite (pas de crash)
- [ ] Cliquer sur la Base ennemie ou une zone quelconque ne casse pas la
      sélection de la Base du joueur (`SelectionArea` toujours résolue
      correctement malgré le nouveau `Hull`)

### À ne PAS faire dans ce jalon

- Pas de Tour, pas de siège d'objectif (Méso, phase 10)
- Pas de vague alliée pour le joueur
- Pas de dépense de l'économie (`buy_slot` reste inerte, H4)
- Pas de relief/obstacles (9.3)
- Pas de possession d'unité (9.2)

---

## 9.2 — Gameplay : possession d'unité (variante RuneMage)

### Objectif

Le palier Micro ne se limite pas à la bombarde immobile de la Base : le
combat individuel rapproché (« les ennemis sont dangereux — pression,
timing, positionnement », `LOOP_SPHERE_FRONT.md`) s'incarne surtout dans
une unité **possédée** qui se déplace au contact, comme en phase 8.2. Ce
jalon ajoute cette possibilité au POC et généralise la condition de
défaite en conséquence : **Game Over seulement quand *toutes* les entités
contrôlables du joueur sont mortes** (la Base **et** toute unité possédée),
pas la Base seule comme en 9.1 — mourir en tant qu'unité possédée ne doit
pas terminer la partie si la Base tient encore, et inversement.

### Prérequis

9.1 stable (Base attaquable, scène, vagues ennemies, Game Over de base —
la règle de défaite de 9.1 devient un cas particulier de celle-ci, pas un
mécanisme à refaire). `gameplay_loop/micro/micro_possession.tscn` part
d'une **copie** de `micro_base_defense.tscn` (voir « Organisation des
scènes » plus haut) — pas une modification du fichier de 9.1.

### Ce qui reste délibérément non tranché ici

> Décidé ensemble : les détails d'implémentation de ce jalon seront
> discutés **au moment de l'attaquer**, pas anticipés maintenant. Cette
> section note seulement ce qui est déjà acté, pour ne pas le redécider
> par erreur plus tard.

- **Nature de la « variante RuneMage »** : une version à part du RuneMage
  existant (phases 6-8), distinguée par un **flag**, pensée pour rester
  dans l'esprit léger du POC plutôt que de réutiliser tous les sorts/l'UI
  du RuneMage complet — quels sorts/mouvements gardés ou simplifiés reste
  à discuter à l'implémentation.
- **Origine des unités possédables** dans ce POC (roster fixe pré-placé ?
  conversion d'un `FrontUnit` existant comme en 8.2 ? autre chose ?) — non
  tranché.
- **Une possession à la fois ou plusieurs unités en réserve** — non
  tranché.

### Sous-tâches (esquisse — à affiner en attaquant ce jalon, pas figée)

1. Introduire la variante RuneMage flaguée (détails ci-dessus, à discuter
   avant de coder ce point précis).
2. Généraliser la condition de défaite : suivre l'ensemble des entités
   contrôlables du joueur (Base + unité(s) possédée(s)/possédable(s)) et ne
   déclencher Game Over que lorsque plus aucune n'est en vie — probablement
   dans `micro_possession.gd`, plutôt que dans `Base` elle-même (`Base.died`
   seule ne suffit plus : elle ne doit plus, à elle seule, terminer la
   partie).
3. Réutiliser `PossessionSwap` (phase 8.2) tel quel si compatible avec la
   variante flaguée ; noter explicitement tout écart si ce n'est pas le cas.

### Fichiers (provisoire — à confirmer à l'implémentation de ce jalon)

- Nouveau : `gameplay_loop/micro/micro_possession.tscn`/`.gd` (copie de
  `micro_base_defense.tscn`, cf. « Organisation des scènes »)
- Nouveau : variante RuneMage (nom de fichier à définir au moment de coder)
- Modifié, potentiellement : `entities/base/base.gd` (`died` ne déclenche
  plus directement Game Over à lui seul, cf. sous-tâche 2)

### Critères de validation

- [ ] Le joueur peut posséder une unité alliée pendant la défense de Base
      (comme en 8.2), depuis cette scène POC
- [ ] Mourir en tant qu'unité possédée ne termine PAS la partie si la Base
      (ou une autre entité contrôlable) est encore en vie
- [ ] Game Over seulement quand la Base **et** toute unité possédée/
      possédable sont mortes
- [ ] Le combat rapproché possédé se sent dangereux/positionnel (feel
      Micro), pas juste une formalité à côté de la bombarde de Base

### À ne PAS faire dans ce jalon

- Ne pas figer maintenant les détails de la variante RuneMage (flag) —
  décision différée à l'attaque de ce jalon, pas à anticiper en amont
- Pas de vague alliée spawnée automatiquement, sauf décision contraire
  prise à ce moment-là

---

## 9.3 — Relief et obstacles (test de robustesse du mouvement)

### Prérequis

9.2 stable. `gameplay_loop/micro/micro_terrain.tscn` part d'une **copie**
de `micro_possession.tscn` (voir « Organisation des scènes ») — relief
ajouté par-dessus la boucle base + possession déjà validée.

### Objectif

Vérifier que le mouvement `FrontUnit` (seek + décalage d'essaimage +
évitement local entre unités, **aucun évitement d'obstacle statique
aujourd'hui** — voir constat ci-dessous) tient face à un couloir non-trivial,
pas seulement un sol plat. C'est le point dur identifié par
`LOOP_SPHERE_FRONT.md` : si ça casse, on le découvre ici, avant d'empiler
Méso/Macro par-dessus un mouvement fragile.

### Constat technique (à lire avant de placer le premier obstacle)

`FrontUnit._avoidance()` ne pousse qu'à l'écart **des autres `FrontUnit`**
(alliés et ennemis confondus) — rien ne pousse à l'écart d'un obstacle
statique. Le seul mécanisme qui empêchera une unité de traverser un rocher
est la réponse de collision physique de `move_and_slide()` lui-même
(glissement le long des surfaces), qui **route** un `CharacterBody3D` autour
d'un obstacle convexe isolé, mais peut le bloquer net contre un coin
concave ou un goulot d'étranglement — il n'y a **aucun vrai pathfinding**
(`NavigationAgent3D` explicitement hors scope v0.1, `PLAN.md`).

### Sous-tâches

**1. Ajouter un relief simple au couloir**
- Quelques obstacles convexes isolés (rochers/piliers `StaticBody3D` sur
  `Faction.FLOOR_LAYER`, hors du chemin direct base-à-base au départ) —
  pas un labyrinthe. Objectif : un test progressif, pas un piège.
- Playtester après **chaque** obstacle ajouté plutôt que tous d'un coup —
  un blocage sera plus facile à isoler.

**2. Décision à prendre en playtest, pas avant : que faire si ça casse ?**
- **Si le glissement de `move_and_slide()` suffit** (unités contournent les
  rochers sans se coincer) : rien à faire, le mouvement actuel tient, 9.3
  se limite à valider et documenter la limite (obstacles convexes/isolés
  uniquement, pas de garantie sur du relief complexe).
- **Si des unités se coincent visiblement** (contre un coin, dans un
  goulot) : deux options à trancher *alors*, pas maintenant par supposition
  silencieuse — (a) ajouter un terme de répulsion obstacles à
  `_avoidance()` (correctif léger, cohérent avec l'existant), ou (b)
  introduire `NavigationAgent3D` pour `FrontUnit` (renverse la décision
  "hors scope v0.1" de `PLAN.md` — plus lourd, mais la bonne réponse si le
  relief prévu pour Méso/Macro est plus complexe qu'un couloir avec
  quelques rochers).

### Fichiers

- `gameplay_loop/micro/micro_terrain.tscn`/`.gd` (nouveau — copie de
  `micro_possession.tscn` + obstacles)
- `entities/front_unit/front_unit.gd` (modifié **seulement si** le
  playtest montre un blocage — voir sous-tâche 2)

### Critères de validation

- [ ] Une vague ennemie traverse le couloir avec relief sans qu'aucune unité
      ne reste bloquée indéfiniment (quelques secondes de contournement
      sont acceptables, un blocage permanent ne l'est pas)
- [ ] Le *feel* validé en 9.1 (rythme des vagues, danger perçu, tir mortier)
      ne régresse pas avec le relief en place
- [ ] Décision documentée ici (mise à jour de ce doc) si un correctif de
      mouvement (2a ou 2b) a été nécessaire, avec le pourquoi

### À ne PAS faire dans ce jalon

- Pas de relief complexe/labyrinthique — l'objectif est un test de
  robustesse graduel, pas un niveau fini
- Pas de `NavigationAgent3D` par défaut — seulement si 9.3 démontre que
  c'est nécessaire (voir sous-tâche 2b)

---

## Point ouvert non traité par cette phase (à garder en tête)

Donner des PV à la `Base` (H1) est un prérequis technique pour la capture
de base (Phase 11, Macro) — détruire une base au lieu de simplement
atteindre sa `GoalZone` a maintenant un mécanisme concret. Phase 11 devra
seulement décider ce qui se passe **après** la destruction (capture vs.
simple élimination), pas réinventer le PV de Base lui-même.
