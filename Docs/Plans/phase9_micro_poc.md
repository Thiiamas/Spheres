# Phase 9 — POC Micro : défense de Base

> **Objectif de cette phase.** Premier des trois POC de boucle annoncés par
> `LOOP_SPHERE_FRONT.md` : isoler le palier **Micro** (tuer un ennemi →
> ressources) pour en peaufiner le *feel*, avant d'empiler Méso (tour) puis
> Macro (capture de base) par-dessus dans les phases 10 et 11. Le joueur ne
> contrôle que sa **Base** (8.1) ; en face, uniquement des `FrontUnit` en
> mode ennemi — pas de vague alliée pour le joueur (ça viendra en Méso).
>
> Découpée en quatre jalons, chacun dépendant de **9.1** : **9.1** (boucle de
> défense sur terrain plat — la fondation jouable), **9.2** (progression —
> le débouché des ressources, sans quoi la récompense du palier Micro reste
> décorative), **9.3** (possession d'une unité — le palier Micro s'applique
> aussi au combat rapproché d'une entité possédée, pas seulement à la
> bombarde immobile de la Base), et **9.4** (relief/obstacles — le vrai test
> de robustesse du mouvement `FrontUnit`, identifié comme le point dur de ce
> POC).
>
> *(9.2 est un ajout postérieur au plan initial, d'où la renumérotation :
> l'ancien 9.2 devient 9.3, l'ancien 9.3 devient 9.4. Raison : le playtest de
> 9.1 a montré que tuer des ennemis rapportait des ressources qui ne
> pouvaient rien acheter — la boucle Micro ne se refermait pas.)*

---

## Organisation des scènes (`gameplay_loop/`)

Décision actée : chaque **palier de boucle** (Micro maintenant, Méso/Macro
plus tard) a son propre dossier de scènes, séparé de `levels/` (qui reste
pour les deux prototypes historiques, `main.tscn`/`level2_front.tscn`) —
`gameplay_loop/micro/`, puis `gameplay_loop/meso/`/`gameplay_loop/macro/`
en phases 10/11. Snake_case, cohérent avec le reste du projet
(`entities/`, `front_unit/`…).

À l'intérieur de `gameplay_loop/micro/`, **une scène par jalon** qui change
la composition du niveau, pas une seule scène qui évolue au fil des jalons :

- `micro_base_defense.tscn`/`.gd` (9.1)
- `micro_possession.tscn`/`.gd` (9.3)
- `micro_terrain.tscn`/`.gd` (9.4)

Chaque scène est **dupliquée et étendue** depuis celle du jalon précédent
plutôt que modifiée en place — décision explicite pour que chaque jalon
reste rejouable et testable **isolément** même une fois le jalon suivant
commencé, ce qui est précisément le test de découplage recherché. Coût
accepté : de la duplication entre les scènes (mêmes `PlayerBase`/
`EnemyBase`/décor recopiés) plutôt qu'un seul fichier partagé.

**9.2 n'a pas de scène propre** : la progression modifie l'entité `Base`
elle-même (`base.tscn`) et un autoload, pas la composition du niveau — elle
se teste dans `micro_base_defense.tscn`. Corollaire assumé de la
convention : les changements au niveau des **entités** se propagent à toutes
les scènes, y compris celles des jalons déjà validés ; seule la composition
du niveau est figée par scène.

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
| H1 | Enjeu de la Base | La Base du joueur gagne des **PV réels** (composant `Health`, comme `Tower`/`FrontUnit`) ; à 0, **Game Over** (en 9.1, seule entité contrôlable du POC — 9.3 généralise cette règle à *toutes* les entités contrôlables du joueur). | Choix explicite : sans ça, le critère Micro *« les ennemis sont dangereux »* n'a pas de sens — il n'y aurait aucune conséquence à laisser une vague passer. |
| H2 | Type d'ennemi | **`FrontUnit` en mode `ENEMY`** (`enemy_unit.tscn`), pas `Enemy.tscn` (phase 3/4). | `Enemy.gd` cible exclusivement un `SphereController` via `Consciousness.entities` (`_nearest_sphere()`) — il ne peut pas du tout viser une `Base` sans réécriture. `FrontUnit`, lui, sait déjà avancer vers un `target_base: Node3D` générique (mécanique de la phase 7) : aucune modification de son ciblage/mouvement n'est nécessaire, seule son *attaque* doit apprendre à reconnaître une `Base` (H1). |
| H3 | Relief/obstacles | **9.1 sur couloir plat, 9.4 ajoute le relief** une fois la boucle de base validée en playtest — pas les deux d'un coup. | Isoler la variable : si le *feel* casse après l'ajout d'obstacles, on sait que c'est le relief et pas le spawn/l'équilibrage qui est en cause. |
| H4 | Économie (`buy_slot`/`wave_size`) | **Inerte en 9.1**, débouché ajouté en **9.2** (progression). | D'abord une décision explicite de l'utilisateur (ne rien inventer prématurément), puis **révisée après le playtest de 9.1** : la définition du palier Micro promet « des ressources pour devenir plus puissant », donc sans dépense la boucle ne se referme pas. `wave_size`/`buy_slot` restent hors sujet pour ce POC (pas de vague alliée) et sont absorbés par le nouveau système en 9.2. |
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
- `entities/front_unit/front_unit.gd`, `_try_attack()`. **Écart déclaré par
  rapport au plan initial** : le test `body is Base` proposé ici ne peut pas
  marcher — `Base` est un `Node3D`, jamais retourné par
  `Area3D.get_overlapping_bodies()` ; le corps présent dans la zone est son
  enfant `Hull`, qui n'a lui-même pas de `take_damage`. La boucle passe donc
  par un helper `_damageable(body)` qui traduit un corps en *victime réelle*
  (`body.get_parent() as Base` pour une Base) au lieu de tester le type sur
  place et d'appeler `body.take_damage` en aveugle.
- Aucune vérification de faction supplémentaire nécessaire — comme pour
  `Tower`, le filtrage se fait déjà par le masque de collision de
  `AttackZone` (`Faction.opposing_physics_layer(faction)`), qui ne peut de
  toute façon renvoyer que des corps de la faction adverse.
- Le **ciblage/mouvement** de `FrontUnit` n'a besoin d'aucune modification :
  `_current_target()` retombe déjà sur `target_base.global_position` quand
  ni tour ni hostile ne sont trouvés (aucune des deux n'existe dans ce
  POC) — les unités marchent donc déjà droit sur la Base adverse
  aujourd'hui, sans code supplémentaire.
- **Quirk découvert en écrivant le test** (pas un bug en jeu réel, mais un
  piège pour tout futur test ou spawn manuel) : un `FrontUnit` sans
  `target_base` *ni* `target_tower` ni hostile à portée fait un `return`
  dans `_physics_process` **avant** d'atteindre `_try_attack()` — il ne mord
  donc rien, même avec une cible valide dans sa `AttackZone`. `Base` assigne
  toujours `target_base` aux unités qu'elle spawne, donc le cas ne se
  produit pas en jeu ; il faut juste penser à l'assigner quand on instancie
  une unité à la main.

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
- `entities/front_unit/front_unit.gd` (modifié — helper `_damageable()`,
  la Base atteinte via son `Hull`)
- `gameplay_loop/micro/micro_base_defense.tscn`/`.gd` (nouveau)
- `tests/base_health_test.gd`/`.tscn` (nouveau — test headless, même
  convention que `base_possession_test`/`possession_swap_test`)

### Critères de validation

Vérifié **headless** (`tests/base_health_test.tscn`, code retour 0) :

- [x] Un `FrontUnit` ennemi arrivé à portée endommage la Base du montant
      exact de son `attack_damage` (150 → 142 PV)
- [x] La Base à 0 PV émet `died`, **reste dans l'arbre** (H5) et ignore
      silencieusement les entrées suivantes (pas de crash sur un `attack`
      envoyé après la défaite)
- [x] Une vague **autonome** (sans intervention du test) sort de `EnemyBase`,
      traverse le couloir et endommage la Base en ~11s — la boucle tourne
      d'elle-même, ce n'est pas qu'un dégât synthétique
- [x] Aucune régression : `base_possession_test`, `possession_swap_test`,
      `rune_chain_test`, `synthetic_drive_test` toujours au vert

Reste à confirmer **en playtest manuel** (pas vérifiable headless — pas de
rendu, pas de souris réelle) :

- [x] La partie démarre avec la Base possédée, caméra libre, tir mortier
      fonctionnel (hérité de 8.1, revérifié sans régression visuelle)
- [x] La barre de vie de la Base est **visible et lisible** — première
      version jugée trop petite en playtest, élargie (mesh 1 → 2.5 unités de
      large), validée. A nécessité un correctif générique dans
      `ui/hp_bar_3d.gd` : l'ancrage à gauche du remplissage codait en dur une
      largeur de 1 unité (`(ratio - 1.0) * 0.5`), donc toute barre plus large
      se serait vidée depuis le mauvais côté ; la largeur est maintenant lue
      depuis le mesh (tour et unités inchangées visuellement, revérifiées)
- [x] Tuer un ennemi au mortier rapporte des ressources visibles au HUD
- [x] Le message de défaite s'affiche correctement à 0 PV
- [x] Cliquer sur la Base sélectionne toujours bien la Base malgré le
      nouveau `Hull` — confirmé en playtest : le raycast peut toucher `Hull`
      **ou** `SelectionArea`, les deux résolvent vers la `Base` via
      `hit.get_parent()` (c'est précisément pourquoi `Hull` est un nœud
      **enfant** et non la racine de `Base`)
- [x] Équilibrage du *feel* : `wave_interval = 6s`, `wave_size = 2`,
      `max_hp = 150` — jugés « ok pour l'instant » en playtest, gardés
      comme valeurs de travail (à réajuster quand 9.2 ajoutera la progression
      et 9.3 la possession, qui changent tous deux la pression ressentie)

### Finitions (après validation de la boucle, avant de passer à 9.2)

Le squelette de 9.1 validé, trois finitions demandées en playtest — du
*feel*, pas de la mécanique :

**1. Effet visuel à la mort — `DeathBurst`, sur les deux factions**
- `entities/shared/death_burst.gd`/`.tscn` : l'unité éclate en une poignée
  de débris qui partent vers l'extérieur, tournent, retombent (balistique
  simple, sans collision) et s'estompent, puis la scène se libère seule.
  Même contrat de cycle de vie qu'`AoeBlast`.
- Construit **en code** plutôt qu'en `GPUParticles3D` : contrôle direct de
  la forme des débris sans écrire un `ParticleProcessMaterial` à la main.
  Précédent déjà dans le projet : `LootOnDeath` fabrique son `Label3D` en
  code.
- Déclenché par un composant séparé, `entities/shared/death_effect.gd`
  (Node, écoute `Health.died`, sibling de `LootOnDeath`) — présentation et
  économie restent indépendantes : les unités **alliées** éclatent sans
  rien rapporter (pas de `LootOnDeath` chez elles), les ennemies font les
  deux.
- **Forme des débris par faction** : `spherical_shards` sur `DeathBurst`,
  d'où deux variantes de scène (`death_burst.tscn` cubique pour les
  ennemis, `death_burst_sphere.tscn` sphérique pour les alliés). Le langage
  visuel du projet est entièrement sphère (allié) contre cube (ennemi)
  — `Docs/LORE.md` — donc un allié qui explose en petits cubes se lit comme
  un bug. Teinte assortie au `base_color` de chaque unité.
- **Taille revue à la hausse** après premier playtest : débris 0.22 → 0.34,
  nombre 9 → 12, vitesses et durée montées d'autant — la première version
  était trop discrète face à une unité d'environ 1m.
- L'effet est parenté à la **scène courante**, pas à l'entité mourante :
  celle-ci se `queue_free()` dès que `died` est résolu
  (`FrontUnit._on_health_died`) et emporterait l'effet avec elle.

**2. Gain de ressource — `ResourceMote` vers la base la plus proche**
- `entities/shared/resource_mote.gd`/`.tscn` : une petite bille émissive
  qui décrit un arc depuis le kill jusqu'à la base qui encaisse (même
  parabole que `MortarShell`), rétrécit sur le dernier quart du trajet, puis
  se libère.
- `LootOnDeath` gagne `mote_scene` et un scan `_nearest_ally_base()` sur
  `Consciousness.entities` — la même source que
  `PossessionSwap.find_ally_base()`, mais **la plus proche** et non la
  première, puisque Méso/Macro mettront plusieurs bases sur le terrain.
- Le `+N` flottant existant est **conservé** au point de mort (retour
  immédiat du kill) ; le mote est la moitié « c'est arrivé à ta base ».
- **Le mote ne touche jamais `Economy`** : le pool est crédité à la mort
  (H4 de la phase 8), donc un mote perdu — ou une base détruite en cours de
  vol — ne peut rien coûter au joueur.

**3. Rotation de la caméra (façon RuneScape) — bien plus simple que prévu**
- Doute levé en lisant le code : `_zoom` établissait **déjà** exactement le
  patron nécessaire (« état du rig, pas de la config, initialisé depuis la
  première `CameraConfig` topdown puis possédé par le joueur »). La
  rotation est le même refactor appliqué à `yaw` : `CameraConfig.yaw`
  devient l'angle de **départ** au lieu d'une constante.
- `core/camera_rig.gd` : nouvel état `_yaw` (sentinelle `INF` = jamais
  initialisé) + `_current_yaw()`, et les **trois** sites qui lisaient
  `config.yaw` le lisent maintenant : placement de la caméra
  (`_update_topdown`), direction du pan (`_apply_pan`, pour que « gauche »
  reste la gauche de l'écran après rotation) et `get_view_yaw()`.
- Entrée : **glisser au bouton du milieu**, lu directement en
  `InputEventMouseButton`/`MouseMotion` — aucune action Input Map ajoutée,
  comme le zoom molette qui n'en a pas non plus. Choix délibéré : les
  flèches sont prises (`cam_pan_*`) et le clic gauche est déjà surchargé
  (`select`/`attack`, cf. la dette notée dans `PLAN.md`).
- Glissement **horizontal seulement** : le `pitch` reste une valeur
  d'auteur par config, la vue ne peut pas être basculée dans un angle
  illisible en pleine vague.
- Conséquence à surveiller en playtest, pas un bug : `get_view_yaw()`
  alimente le déplacement caméra-relatif du RuneMage (ZQSD) et le roulement
  de la sphère. Tourner la caméra **change donc « l'avant »** — c'est le
  comportement attendu (LoL/RuneScape font pareil), mais tourner en pleine
  course dévie la trajectoire.

### À ne PAS faire dans ce jalon

- Pas de Tour, pas de siège d'objectif (Méso, phase 10)
- Pas de vague alliée pour le joueur
- Pas de dépense de l'économie (`buy_slot` reste inerte — H4, traité en 9.2)
- Pas de relief/obstacles (9.4)
- Pas de possession d'unité (9.3)

---

## 9.2 — Progression : le débouché des ressources

### Objectif

Fermer la boucle Micro. Sa définition (`LOOP_SPHERE_FRONT.md`) promet
« **Récompense : ressources pour devenir plus puissant** » ; à la fin de 9.1
les ressources s'accumulent et n'achètent **rien** (`buy_slot` est inerte,
H4 — pas de vague alliée dans ce POC). Deux tiers de la boucle existent,
la récompense est décorative.

Ce jalon pose un **système** de progression générique, appliqué d'abord à la
Base, et prévu pour que le contrôlable de 9.3 s'y branche sans réécriture.

### Prérequis

9.1 stable. `Economy` (8.1) fournit déjà le portefeuille.

### La contrainte qui décide de l'architecture

`PossessionSwap.possess_front_unit()` fait `queue_free()` sur le `FrontUnit`
puis `instantiate()` un mage : **posséder une unité la détruit et en crée une
autre**. Toute progression stockée *sur l'instance* est donc perdue au
prochain swap — c'est-à-dire en permanence, dès 9.3.

Le projet a déjà résolu ce problème une fois, sur la caméra : `_zoom` et
`_yaw` sont de l'**état du rig, pas de la config**, précisément pour survivre
au cycle des configs et aux transferts de possession. La progression suit la
même règle : c'est de l'état **joueur**, pas de l'état entité. Ça tombe juste
avec le lore — c'est la *conscience* qui monte en puissance, les corps sont
jetables.

### Décisions actées

| # | Sujet | Décision | Pourquoi |
|---|-------|----------|----------|
| D1 | Pool de ressources | **Un seul portefeuille partagé** (l'`Economy` existant) entre Base et unité possédée. | Améliorer la Base ou son unité devient un choix concurrent — une vraie tension de décision. Cohérent avec le commentaire d'`Economy` : « un seul joueur, un seul portefeuille ». |
| D2 | Portée des upgrades | **Globale** : les niveaux sont stockés par upgrade, pas par unité, donc toute entité possédée bénéficie de tout ce qui est acheté. **Mais l'API doit garder la place** pour des upgrades *par unité* plus tard, sans réécrire les appelants. | Simple, colle au lore, et gratuit avec le pattern ci-dessous. Concrètement : `Progression.level_of(id, scope := &"global")` — le paramètre `scope` existe dès maintenant avec une valeur par défaut, le stockage est clé composite, et le jour où on veut du par-unité on passe un scope sans toucher au code appelant. |
| D3 | Achat | **Une touche par upgrade** (`1`/`2`/`3`/`4`), pas de panneau UI. | Cohérent avec le « pas de vraie UI » des jalons précédents. Ne passe pas l'échelle au-delà de ~4 upgrades — c'est assumé pour un POC. |
| D4 | Montée de `max_hp` | Augmenter les PV max **soigne aussi du delta** immédiatement. | Sinon l'upgrade ne fait rien de perceptible quand on l'achète en pleine vague (le plafond monte, les PV courants non). Fait aussi office de mécanique de retour en jeu, notée comme manquante au playtest de 9.1. |

### Le pattern : `Resource` (données) + store autoload + application idempotente

Trois pièces, chacune calquée sur un patron déjà en place dans le projet.

**1. `core/upgrade.gd` — `Upgrade extends Resource`**

Les données vivent en `.tres`, comme `CameraConfig` (phase 5) :

```gdscript
@export var id: StringName        # &"mortar_rate"
@export var display_name: String
@export var max_level: int = 5
@export var cost_base: int = 20
@export var cost_step: int = 10
## Ce qu'un niveau vaut — interprété par l'entité, pas par l'upgrade.
@export var per_level: float = 0.08
func cost_at(level: int) -> int   # cost_base + level * cost_step
```

**2. `autoloads/progression.gd` — le store**

À côté d'`Economy`, et pour la même raison (état joueur, pas état entité) :

```gdscript
signal changed
func level_of(id: StringName, scope := &"global") -> int
func try_buy(up: Upgrade, scope := &"global") -> bool  # Economy.try_spend + niveau + changed
func bonus(up: Upgrade, scope := &"global") -> float   # level * up.per_level
```

**3. L'application, côté entité — duck-typée**

`apply_progression()`, appelée en `_ready()` **et** sur `Progression.changed`
(même patron duck-typé que `get_hud_lines`/`bind_camera`/`update_bar`) :

```gdscript
func apply_progression() -> void:
    attack_cooldown = _base_cooldown * (1.0 - Progression.bonus(mortar_rate_up))
    mortar_damage   = _base_damage + Progression.bonus(mortar_damage_up)
```

C'est là que la contrainte plus haut se dissout : une entité fraîchement
créée par un swap lit le store dans son `_ready()` et arrive **déjà** au
niveau acheté. Aucun code de transfert, aucune sérialisation.

> **Piège à ne pas manquer : l'application doit être idempotente.** Garder la
> valeur d'auteur (`_base_cooldown`, capturée en `_ready()` avant toute
> application) et **toujours recalculer depuis elle**. Muter la stat en place
> (`attack_cooldown *= 0.92`) compose à chaque réapplication et la valeur
> dérive à l'infini — `Progression.changed` étant émis à chaque achat, ça
> arriverait dès le deuxième.

### Sous-tâches

**1. `Upgrade` + `Progression`** (les deux fichiers ci-dessus, `Progression`
ajouté aux autoloads de `project.godot` après `Economy`).

**2. Absorber l'achat en dur existant.** `Base._try_buy_slot()`/
`_next_slot_cost()` sont un mécanisme d'achat parallèle, à retirer au profit
du système générique — sinon deux façons d'acheter coexistent. Impacts
identifiés :
- `core/input_context.gd:19` — `&"buy_slot"` retiré de `TRACKED_ACTIONS`,
  remplacé par `&"upgrade_1"`…`&"upgrade_4"`
- `entities/base/base.gd` — `drive()` boucle sur la liste d'upgrades au lieu
  du cas spécial `buy_slot` ; `slot_cost_base`/`slot_cost_step` migrent dans
  un `.tres`
- Input Map — `buy_slot` (B) retiré, `upgrade_1..4` sur les touches `1`-`4`
- `tests/base_possession_test.gd:93` — utilise `set_action(&"buy_slot", …)`,
  à mettre à jour (sinon le test vérifie une action qui n'existe plus)

**3. Les upgrades de la Base** (`entities/base/upgrades/*.tres`) :
`mortar_rate` (touche `1`), `mortar_damage` (`2`), `base_hp` (`3`),
`wave_slot` (`4`, l'ancien `buy_slot` — gardé pour ne rien perdre, même s'il
est sans effet dans ce POC faute de vague alliée).
`Base.apply_progression()` les applique, avec les baselines capturées.

Le catalogue est assigné dans **`base.tscn`** (donc partagé par toutes les
`Base`, y compris ennemies) plutôt que par niveau : une Base ennemie n'est
jamais possédée, ne reçoit donc jamais `drive()` et ne peut rien acheter — et
`_bonus()` renvoie 0 pour un id absent, donc ses stats restent celles de son
auteur. Bénéfice : les scènes de niveau et de test n'ont rien à recâbler.

**4. HUD.** `Base.get_hud_lines()` liste les upgrades avec touche, niveau et
coût du prochain — le HUD debug existant suffit (D3).

**5. Test headless** `tests/progression_test.gd`/`.tscn` : achat refusé sans
ressources, accepté avec, `max_level` respecté, **idempotence** (appliquer
deux fois de suite donne la même valeur), et le point qui compte le plus —
une entité créée **après** l'achat arrive déjà améliorée.

### Fichiers

- `core/upgrade.gd` (nouveau)
- `autoloads/progression.gd` (nouveau, + autoload dans `project.godot`)
- `entities/base/upgrades/*.tres` (nouveaux)
- `entities/base/base.gd` (modifié — `apply_progression`, baselines, `drive`
  générique, retrait de `_try_buy_slot`/`_next_slot_cost`)
- `core/input_context.gd` (modifié — `TRACKED_ACTIONS`)
- `project.godot` (modifié — Input Map, autoload)
- `tests/progression_test.gd`/`.tscn` (nouveau)
- `tests/base_possession_test.gd` (modifié — action renommée)

### Critères de validation

Vérifié **headless** (`tests/progression_test.tscn`) :

- [x] Un achat refusé faute de ressources ne débite rien, ne monte pas le
      niveau et ne touche pas la stat
- [x] Un achat au coût exact passe et débite la totalité (0 restant)
- [x] La stat de l'entité vivante suit l'achat (25 → 33 de dégâts mortier)
- [x] **Idempotence** : réappliquer deux fois de suite ne fait pas dériver la
      valeur — le test échouerait si la stat était mutée en place au lieu
      d'être recalculée depuis sa baseline
- [x] **Une entité créée *après* l'achat arrive déjà améliorée** (33.0) —
      le critère qui justifie toute l'architecture, et ce qui fera que le
      détruire/recréer de `PossessionSwap` sera un non-problème en 9.3
- [x] `max_level` bloque les achats au-delà, sans rien dépenser
- [x] Aucune régression : les cinq tests headless précédents au vert (six
      avec celui-ci)

Reste à confirmer **en playtest manuel** :

- [ ] Le HUD affiche correctement touche, niveau et coût de chaque upgrade,
      et le coût grimpe visiblement après un achat
- [ ] L'effet est **perceptible en jeu** : cadence de tir, dégâts, PV max
- [ ] Les touches `1`-`4` achètent bien, et n'entrent pas en conflit avec le
      reste des entrées (l'ancien `B` a disparu)
- [ ] D4 se sent juste : acheter des PV max en pleine vague soigne
      immédiatement du delta

### Ajustements faits en préparation de 9.3

Trois points relevés en vérifiant que le système convenait au
`RuneMageMinimal` de 9.3 (upgrades PV + cooldown). Confirmation d'abord :
`RuneMage` a déjà un composant `Health` (donc `set_max_hp` marche tel quel)
et ses cooldowns sont de simples `float` exportés (`bolt_cooldown`,
`flux_cooldown`, `cage_cooldown`), donc le patron de baseline s'applique sans
adaptation. Détail utile : `_tick_cooldowns` réarme les timers depuis ces
exports **au moment du cast**, donc changer la valeur n'a aucun effet
étrange sur un cooldown en cours.

**1. `UPGRADE_ACTIONS` déplacé de `Base` vers `InputContext`.** Le mage aurait
dû écrire `Base.UPGRADE_ACTIONS` pour lire ses propres touches d'achat. Sa
place est à côté de `TRACKED_ACTIONS`, qui doit de toute façon rester
synchronisé avec elle (une action absente de `TRACKED_ACTIONS` n'est jamais
échantillonnée : la touche serait silencieusement inerte).

**2. La boucle d'achat est montée dans `Controllable`.** Elle était dans
`Base.drive()` et il aurait fallu la dupliquer dans chaque entité. Acheter un
upgrade est une préoccupation de la **couche possession** (c'est du méta, ça
dépense le portefeuille partagé du joueur), exactement comme `select` — même
raisonnement, même endroit. `Controllable._handle_upgrade_keys()` lit
`entity.upgrades` en duck-typing via `get()`, donc :
- toute entité possédable exposant un tableau `upgrades` peut acheter, sans
  plomberie — le mage de 9.3 y compris ;
- les entités sans upgrades (sphère, balise) renvoient `null` et sont ignorées ;
- `Base` ne fait plus que **déclarer** ce qu'elle propose.
Les quatre sous-classes appellent désormais `super(ctx)` dans
`handle_input`. Couvert par `base_possession_test`, qui achète via le chemin
des touches réel (`set_action` → `handle_input`).

**3. Bug préexistant corrigé : la barre de vie après un swap de possession.**
`PossessionSwap` assignait `health.hp` directement, ce qui ne rafraîchit
rien — seuls `take_damage`, `set_max_hp` et `_ready` le font. Une entité
possédée à 50% de PV **affichait donc une barre pleine** jusqu'à son premier
coup encaissé. Datait de la phase 8.2 ; 9.3 l'aurait rendu systématique,
puisque chaque possession passe par ce chemin. Corrigé par
`Health.set_hp()` (symétrique de `set_max_hp`), utilisé aux deux endroits du
swap. Régression pincée dans `possession_swap_test` : vérifié en remettant
l'ancienne ligne, le test échoue bien avec « bar shows 100% after a 50%
swap ».

> Effet de bord vérifié et voulu : le `set_hp` du swap tourne **après**
> `add_child`, donc après l'`apply_progression()` du `_ready` de la nouvelle
> entité. Le ratio de PV se reporte sur le plafond **déjà amélioré**, ce qui
> est le comportement souhaité.

### À ne PAS faire dans ce jalon

- Pas de pile de modificateurs / buffs temporaires — le pattern
  Decorator devient le bon choix quand il y aura du temporaire ou du
  multiplicatif ; surdimensionné pour des upgrades permanents et additifs, et
  migrable plus tard puisque le store centralise déjà « ce qui est acheté »
- Pas d'upgrades **par unité** (D2 : la place est réservée dans l'API, rien
  de plus)
- Pas de panneau UI (D3), pas de sauvegarde entre parties
- Pas d'upgrades du contrôlable — il n'existe qu'en 9.3

---

## 9.3 — Gameplay : possession d'unité (variante RuneMage)

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

9.2 aussi : le contrôlable introduit ici doit se brancher sur le système de
progression (`apply_progression()` + une liste d'upgrades qui lui sont
propres), ce qui est le vrai test de généricité de ce système — et le point
où D2 (portée globale) se vérifie concrètement, puisqu'un mage né d'une
possession doit arriver déjà amélioré.

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

## 9.4 — Relief et obstacles (test de robustesse du mouvement)

### Prérequis

9.3 stable. `gameplay_loop/micro/micro_terrain.tscn` part d'une **copie**
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
- Pas de `NavigationAgent3D` par défaut — seulement si ce jalon démontre que
  c'est nécessaire (voir sous-tâche 2b)

---

## Effet de bord sur `level2_front.tscn` (phase 7) — à traiter avec la défaite

`base.tscn` est partagé par les deux niveaux : donner des PV à `Base` (9.1)
en donne donc **aussi** aux deux bases de `level2_front.tscn`, et les
`FrontUnit` peuvent désormais y mordre. Rien n'y écoute `Base.died` — une
base tombée y devient donc silencieusement inerte, sans message ni fin de
partie. **Exactement le même trou que `PlayerTower.died`** déjà noté dans
`Docs/Plans/phase7_front.md` (« hors scope … à câbler en même temps que la
défaite plus généralement ») — à traiter avec lui, pas séparément.

---

## Point ouvert non traité par cette phase (à garder en tête)

Donner des PV à la `Base` (H1) est un prérequis technique pour la capture
de base (Phase 11, Macro) — détruire une base au lieu de simplement
atteindre sa `GoalZone` a maintenant un mécanisme concret. Phase 11 devra
seulement décider ce qui se passe **après** la destruction (capture vs.
simple élimination), pas réinventer le PV de Base lui-même.
