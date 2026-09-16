# Tour de front — `Health` / `EscortGate` / `Tower` (référence à jour)

> **À tenir à jour.** Ce fichier décrit le comportement **actuel** de
> `entities/shared/health.gd`, `entities/shared/escort_gate.gd` et
> `entities/tower/tower.gd` — pas son historique. Toute modification de ces
> trois scripts doit mettre à jour ce document dans le **même changement**.
> Pour le pourquoi (demande initiale, alternatives écartées), voir la section
> correspondante de `Docs/Plans/phase7_front.md`.

## Vue d'ensemble

Objectif intermédiaire à la League of Legends : une tour, immobile, qui ne
peut être blessée par les sorts du RuneMage **que si une unité alliée est à
portée** — le joueur doit d'abord pousser sa vague (tuer les `FrontUnit`
ennemis, garder les siens en vie) avant que ses sorts ne fassent quoi que ce
soit à la tour. Sans escorte, la tour **riposte** contre le joueur.

Demandé explicitement comme **composant réutilisable** ("comme un composant
Unity") plutôt qu'un comportement codé en dur sur un seul type d'ennemi —
d'où la séparation en trois pièces indépendantes, chacune réutilisable seule :

- **`Health`** (`entities/shared/health.gd`) — une réserve de PV bête et
  générique. Aucune notion de faction, de portée, de garde. N'importe quelle
  entité pourrait s'en servir.
- **`EscortGate`** (`entities/shared/escort_gate.gd` + `.tscn`) — le
  comportement réutilisable "vulnérable seulement escorté, sinon riposte".
  Aucune notion de PV. C'est la pièce que le joueur pourra brancher plus tard
  sur une tour mobile, volante, ou une tourelle-projectile, en gardant le
  même comportement.
- **`Tower`** (`entities/tower/tower.gd` + `.tscn`) — l'entité concrète
  "tour classique" : possède un `Health` et un `EscortGate` en enfants, et
  est le **seul** endroit qui décide comment les deux interagissent. Un autre
  hôte composant les deux mêmes enfants pourrait câbler cette relation
  différemment.

## `Health` — réserve de PV générique

`Node` simple, sans dépendance à `Faction` ni à aucune zone. Entièrement
autonome dans son propre `_ready()` (pas de souci d'ordre parent/enfant —
`max_hp` est un export statique, jamais dérivé de l'hôte au runtime) :

| Membre | Rôle |
|---|---|
| `max_hp` (export, 100.0 par défaut) | PV de départ. |
| `hp_bar` (export, `Node3D`) | Barre de vie optionnelle, contrat duck-typé `has_method("update_bar")` (même contrat que `SphereController`/`RuneMage`/`FrontUnit`). |
| `hp` | PV courants. |
| `take_damage(amount)` | Soustrait `hp`, émet `hp_changed`, met à jour la barre, émet `died` à 0 (une seule fois, garde via `_dead`). |
| `take_hit(amount)` | Alias de `take_damage` — même convention que `FrontUnit`/`Enemy`, pour que les sorts du RuneMage qui testent `has_method("take_hit")` fonctionnent aussi contre un hôte de `Health`. |
| `is_dead()` | Utilitaire, pas utilisé en interne par `Tower` aujourd'hui. |
| `signal died` | Émis une fois, à 0 PV. `Tower` s'y connecte pour se libérer. |
| `signal hp_changed(current, max)` | Émis à chaque dégât — rien n'écoute aujourd'hui, gardé pour un futur HUD/debug. |

`entities/front_unit/front_unit.gd` **et** `entities/mage/rune_mage.gd` ont
été refactorés pour utiliser ce même composant (voir
`Docs/front/front_unit_ai.md`, section "PV et barre de vie") — la preuve que
`Health` est réellement générique, pas juste "la pièce que Tower utilise".
Au passage (2026-08-02), un bug préexistant sur `rune_mage.tscn` a été
corrigé : ses meshes `Background`/`Fill` n'avaient **aucun matériau assigné**
(oubli antérieur à la convention actuelle, déjà correcte sur
`sphere.tscn`/`ally_unit.tscn`) — la barre se voyait donc comme un bloc blanc
uniforme, sans contraste rouge/vert, même si `update_bar()` fonctionnait
correctement en interne.

## `EscortGate` — le comportement réutilisable

Scène autonome (`Node3D` racine + `DetectionZone` en `Area3D` +
`CollisionShape3D`), pensée pour être **instanciée en enfant** de n'importe
quel hôte — un vrai composant "à glisser", puisque sa seule dépendance
externe est un appel à `configure()`.

### Pourquoi `configure()` plutôt qu'un `@export var faction`

Godot prépare les **enfants avant les parents** (`_ready()` des enfants
d'abord). Ce projet a déjà buté deux fois sur ce piège (`Base`/
`level2_front.gd`, voir `Docs/Plans/phase7_front.md`) : un `@export var faction`
lu dans le `_ready()` du composant verrait encore sa valeur par défaut, pas
celle que l'hôte compte lui donner. `EscortGate` expose donc
`configure(faction: Faction.Kind) -> void`, appelée explicitement par l'hôte
dans **son propre** `_ready()` (qui, lui, tourne toujours après celui de
tous ses enfants) — le problème d'ordre disparaît au lieu d'être contourné
par un `call_deferred`.

`configure()` fait aussi le travail habituel de ce projet pour éviter le bug
de ressource partagée (`Base._structure`, `FrontUnit._attack_shader`) :
duplique le `SphereShape3D` de `DetectionZone/CollisionShape3D` avant de
changer son rayon, sinon deux tours instanciant la même scène partageraient
et redimensionneraient la forme de l'autre.

### `is_protected()`

```gdscript
func is_protected() -> bool:
	for body in _zone.get_overlapping_bodies():
		if body is FrontUnit and body.faction == Faction.opposite(_faction):
			return true
	return false
```

Vrai tant qu'un `FrontUnit` hostile (relatif à la faction de ce composant)
est dans `detection_radius` (6.0 par défaut, même valeur que
`FrontUnit.ENGAGE_RANGE`). C'est la **seule** condition qui pilote les deux
effets demandés : l'hôte doit la vérifier avant de transmettre des dégâts à
son `Health` (voir `Tower.take_damage`), et elle coupe aussi la riposte
ci-dessous — pousser sa vague active les dégâts **et** arrête la punition en
même temps.

### Riposte — contre le siège d'abord, contre un joueur non-escorté sinon

**Changement de la phase 10.2** (`Docs/Plans/phase10_meso_poc.md`) : avant
ça, une Tour assiégée par une vague de `FrontUnit` ne ripostait jamais contre
elle — seul un joueur non-escorté était une cible valide, et
`is_protected() == true` (justement, une vague en train d'assiéger)
désactivait la riposte entièrement. Résultat en playtest : une Tour sous
le feu d'une vague avait l'air totalement passive, sans aucune indication
qu'elle faisait quoi que ce soit. La riposte cible maintenant **soit** la
vague qui l'assiège, **soit** le joueur non-escorté — jamais les deux à la
fois, le second cas ne pouvant de toute façon survenir que quand le premier
ne s'applique pas :

```gdscript
func _physics_process(delta: float) -> void:
    if not _configured or not retaliation_enabled:
        return
    _retaliation_timer -= delta
    if _retaliation_timer > 0.0:
        return
    var target: Node = _find_hostile_front_unit() if is_protected() else _find_unescorted_attacker()
    if target != null:
        _fire_at(target)
        _retaliation_timer = retaliation_cooldown
```

- `is_protected() == true` signifie littéralement « un `FrontUnit` hostile
  est dans la zone de détection » — avant la 10.2 ça ne servait qu'à
  *supprimer* la branche joueur ci-dessous ; c'est maintenant aussi la
  condition qui *déclenche* la branche manquante. Les deux branches restent
  mutuellement exclusives par construction : pas besoin d'arbitrer entre les
  deux, la présence d'une unité hostile décide laquelle s'applique.
- `_find_hostile_front_unit()` : le premier `FrontUnit` de la zone dont la
  faction est l'opposée de celle de ce composant — même condition que
  `is_protected()`, qui retourne le corps au lieu d'un booléen.
- `_find_unescorted_attacker()` cherche, parmi les corps dans la zone, le
  premier qui a `take_damage`, **n'est pas** un `FrontUnit` — c'est-à-dire le
  joueur (`RuneMage`), jamais une unité — **et n'est pas du même camp** que ce
  composant.
- Détection du joueur via un layer physique dédié (`Faction.PLAYER_LAYER`,
  bit 8, additif — voir `core/faction.gd` et
  `entities/mage/rune_mage.gd::_ready()`) : "y a-t-il un joueur dans la
  zone ?" reste une question physique. Mais "ce joueur est-il hostile ?" est
  une question de camp, pas de collision — même séparation que `FrontUnit`/
  `Tower`/`Base` avec leur champ `faction` et `is_protected()` ci-dessus, pas
  un deuxième layer par camp de joueur (bogue corrigé le 2026-08-02 : la
  `PlayerTower` — camp `ALLY` — punissait son propre joueur, faute de ce
  second filtre). `RuneMage` porte donc désormais
  `@export var faction: Faction.Kind = ALLY`, comme `FrontUnit`/`Tower`/
  `Base` ; `_find_unescorted_attacker()` l'exclut via l'opérateur `in`
  (test de propriété, pas d'appel de méthode : `"faction" in body`), pour
  rester agnostique du type concret détecté — un corps sans champ `faction`
  n'est jamais exclu (fail-open).
- Répétée toutes les `retaliation_cooldown` secondes (1.5s par défaut) tant
  qu'une cible reste dans la zone — pas une punition unique. Mêmes
  `retaliation_damage`/`retaliation_cooldown`/`retaliation_projectile` pour
  les deux branches (35.0 dégâts, contre 100 PV max du RuneMage ou 40 PV max
  d'un `FrontUnit` — punitif dans les deux cas, quasi létal en deux coups
  contre une unité). Pas rééquilibré séparément pour l'instant : à ajuster
  en playtest si la riposte anti-siège s'avère trop forte ou trop faible
  telle quelle.
- `EscortGate` ne touche jamais aux PV ni ne s'auto-libère — c'est un pur
  comportement détection + riposte, libéré automatiquement avec l'hôte dont
  il est enfant.

### Projectile de riposte (2026-08-02)

Playtesté : la riposte initiale infligeait des dégâts instantanés, sans
aucun signal visuel — le joueur perdait des PV sans comprendre pourquoi.
`_fire_at(target)` instancie désormais `retaliation_projectile`
(`entities/tower/tower_bolt.tscn` par défaut sur `Tower`) au lieu d'appliquer
les dégâts directement :

```gdscript
func _fire_at(target: Node) -> void:
	if retaliation_projectile == null:
		target.take_damage(retaliation_damage)
		return
	var bolt := retaliation_projectile.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = global_position + Vector3.UP * muzzle_height
	if bolt.has_method("launch"):
		bolt.launch(target, retaliation_projectile_speed, retaliation_damage)
```

- `retaliation_projectile` est un `PackedScene` exporté, laissé `null` par
  défaut sur `EscortGate` lui-même (repli sur les dégâts instantanés) — c'est
  `tower.tscn` qui le renseigne (`ExtResource` vers `tower_bolt.tscn`) sur son
  instance d'`EscortGate`, pas `escort_gate.tscn` qui reste agnostique de tout
  projectile concret.
- `bolt.has_method("launch")` (duck-typé, pas `is TowerBolt`) : `EscortGate`
  (`entities/shared/`) ne référence jamais une classe concrète
  d'`entities/tower/` — la direction de dépendance reste "shared ne connaît
  pas tower", cohérente avec la séparation en trois pièces plus haut.
- `entities/tower/tower_bolt.gd` (`class_name TowerBolt`, `Node3D`) : même
  forme qu'`entities/mage/rune_flux.gd` — homing sur `_target`, `launch()`
  appelée une fois, dégâts appliqués à l'arrivée (`_hit()`), fusible
  `lifetime` si la cible devient inatteignable. Visuel : petite sphère
  émissive orange (`tower_bolt.tscn`).

## `Tower` — l'entité concrète

`StaticBody3D` qui compose un `Health` et un `EscortGate` enfants et décide
seule de leur interaction :

```gdscript
func take_damage(amount: float) -> void:
	if escort_gate.is_protected():
		health.take_damage(amount)
```

- `collision_layer = Faction.physics_layer(faction)` (2 pour `ENEMY`, comme
  `FrontUnit`/`Enemy`) et rejoint le groupe `"enemies"` si `ENEMY` — même
  condition que `FrontUnit` — pour que le raycast de visée du RuneMage
  (`core/aim_strategy.gd`, masque 2) et les scans de groupe de
  `rune_bolt.gd`/`rune_flux.gd` trouvent la tour sans aucun changement côté
  sorts. `RuneCage` ne peut naturellement pas la cibler
  (`has_method("root")` échoue) — normal, une tour ne s'enracine pas.
- `take_hit(amount)` alias `take_damage`, même convention que
  `FrontUnit`/`Enemy`.
- `signal died`, ré-émis depuis `health.died` (pas d'accès direct d'un
  système externe à `tower.health.died` — `Tower` garde son unique surface
  publique), puis `queue_free()`.
- Teinte (`tint`) appliquée à un `StandardMaterial3D` **dupliqué** avant
  modification — même pattern que `Base._structure`.

## Les minions assiègent la tour ennemie (2026-08-02)

Playtesté : les `FrontUnit` ignoraient complètement la `Tower` — seuls les
sorts du RuneMage pouvaient l'endommager, et une vague poussée se contentait
de trader des coups avec les minions ennemis juste à côté sans jamais
inquiéter la tour. Corrigé pour que la vague **assiège** la tour tant qu'elle
est en vie, exactement comme demandé.

- `FrontUnit.target_tower: Node3D` — assigné par `Base` en même temps que
  `target_base`, pointe vers la `Tower` adverse.
- `_current_target()` (nouveau) remplace l'appel direct à
  `_nearest_hostile()` dans `_physics_process` : si `target_tower` est valide
  et à `ENGAGE_RANGE` (6.0, même portée que pour un minion hostile), il **prime**
  sur n'importe quel minion hostile à proximité — une unité en train
  d'assiéger la tour ne se laisse pas distraire par une escarmouche voisine.
  Sinon, repli sur `_nearest_hostile()` comme avant.
  ```gdscript
  func _current_target() -> Node3D:
	  if target_tower != null and is_instance_valid(target_tower):
		  var to := target_tower.global_position - global_position
		  to.y = 0.0
		  if to.length_squared() <= ENGAGE_RANGE * ENGAGE_RANGE:
			  return target_tower
	  return _nearest_hostile()
  ```
  Aucun état mis en cache : réévalué chaque tick physique, donc dès que
  `Tower.queue_free()` rend `target_tower` invalide (mort), l'unité retombe
  immédiatement sur les minions ou l'avancée vers `target_base` — "tant
  qu'elle est en vie" au sens littéral.
- `_try_attack()` accepte désormais aussi `body is Tower` (en plus de
  `body is FrontUnit and body.faction != faction`) — le corps de la tour
  apparaît déjà dans `AttackZone.get_overlapping_bodies()` sans changement de
  layer/masque, puisque `Tower.collision_layer` réutilise la même convention
  `Faction.physics_layer(faction)` que `FrontUnit`.
- `_avoidance()` — signature élargie de `FrontUnit` à `Node3D` pour accepter
  `target_tower` comme paramètre `exclude` ; sans effet pratique puisque la
  boucle d'évitement ne scanne que des `FrontUnit`, donc exclure une `Tower`
  est un no-op silencieux (elle n'a jamais été un obstacle à éviter).
- Effet de bord utile : un minion qui assiège la tour est lui-même dans
  `EscortGate.detection_radius` (portée AttackZone ≪ portée détection), donc
  sa seule présence satisfait déjà `is_protected()` — pas besoin d'une
  escorte séparée en plus de l'assiégeant.
- Câblage : `Base.advance_target_tower` (nouvel export, même rôle
  qu'`advance_target` mais pour la tour) transmis à chaque unité spawnée
  (`unit.target_tower = advance_target_tower`) ; `level2_front.gd` câble
  `_player_base.advance_target_tower = _enemy_tower` et
  `_enemy_base.advance_target_tower = _player_tower`.

**Bug corrigé (2026-08-02)** : la destruction de la tour faisait planter le
spawn de vague suivant —
`Invalid assignment of property or key 'target_tower' with value of type
'previously freed'`. `Tower.queue_free()` ne fait rien pour les *autres*
références qui pointent encore vers elle : `Base.advance_target_tower` reste
une référence pendante vers l'instance libérée, indéfiniment (personne ne la
remet à `null`). Assigner cette référence pendante à une autre propriété
typée (`unit.target_tower = advance_target_tower`) déclenche l'exception —
la simple lire via `is_instance_valid()` ne pose aucun problème, c'est
l'**assignation** d'une référence pendante qui l'est. Corrigé par un garde à
la lecture, pas en réinitialisant le champ (`Base.gd`) :
```gdscript
unit.target_tower = advance_target_tower if is_instance_valid(advance_target_tower) else null
```

## Câblage niveau (`levels/level2_front.gd`)

- Deux instances : `PlayerTower` (faction `ALLY`, z≈-10, entre `PlayerBase`
  à z=-20 et le point de départ du RuneMage à z=-16) et `EnemyTower`
  (faction `ENEMY`, z≈+10, symétrique de `EnemyBase` à z=+20).
- **Porte de victoire** : `_enemy_tower_destroyed` (mis à `true` via
  `EnemyTower.died`) ; `_on_enemy_base_reached` ne déclenche la victoire que
  si ce flag est vrai — atteindre la `GoalZone` avant ne fait plus rien
  (l'unité suivante à atteindre la zone après la chute de la tour déclenche
  la victoire à sa place). Rend littéral le "détruite pour accéder au reste
  de la carte" même sans blocage physique.
- **Mort et respawn du joueur** : `RuneMage.died` (nouveau signal, émis dans
  `_die()` avant `queue_free()`) déclenche un message bref sur le
  `MessageLabel` existant, une pause `mage_respawn_delay` (3.0s par défaut,
  `get_tree().create_timer(...).timeout`), puis instancie un `RuneMage` neuf
  (`mage_scene`, même `rune_mage.tscn`) près de `PlayerBase`. Aucun câblage
  caméra/HUD supplémentaire : les deux sont déjà abonnés à
  `Consciousness.active_changed` (`core/camera_rig.gd`, `ui/hud.gd`), qui se
  redéclenche automatiquement dès que le nouveau `Controllable` s'auto-
  enregistre.
- **`PlayerTower` n'est plus à l'abri** depuis que les `FrontUnit` assiègent
  la tour adverse (section précédente) : une vague ennemie escortée
  l'endommage exactement comme une vague alliée endommage `EnemyTower` —
  confirmé au playtest (2026-08-02). Ce qui reste vrai : rien ne connecte
  `PlayerTower.died` (contrairement à `EnemyTower.died`, la porte de
  victoire) — sa destruction aujourd'hui ne fait que la faire disparaître
  silencieusement, sans condition de défaite. Voir `Docs/Plans/phase7_front.md`,
  « Hors scope ».

## Paramètres exportés

**`Health`**

| Export | Défaut | Rôle |
|---|---|---|
| `max_hp` | 100.0 (400.0 sur `Tower`, réglé par instance) | PV de départ. |
| `hp_bar` | — | Barre de vie optionnelle (duck-typée). |

**`EscortGate`**

| Export | Défaut | Rôle |
|---|---|---|
| `detection_radius` | 6.0 | Rayon de `DetectionZone` (aligné sur `FrontUnit.ENGAGE_RANGE`). |
| `retaliation_enabled` | true | Coupe complètement la riposte si besoin. |
| `retaliation_damage` | 35.0 | Dégâts par riposte contre le joueur non-escorté. |
| `retaliation_cooldown` | 1.5 | Délai minimum entre deux ripostes. |
| `retaliation_projectile` | `null` (`tower_bolt.tscn` sur `Tower`) | Scène du projectile de riposte ; `null` = dégâts instantanés sans visuel. |
| `retaliation_projectile_speed` | 14.0 | Vitesse de vol du projectile. |
| `muzzle_height` | 3.0 | Hauteur de tir au-dessus de l'origine de l'hôte. |

**`Tower`**

| Export | Défaut | Rôle |
|---|---|---|
| `faction` | `ENEMY` | Camp — dérive layer physique, groupe. |
| `health` | (NodePath `Health`) | Référence vers l'enfant `Health`. |
| `escort_gate` | (NodePath `EscortGate`) | Référence vers l'enfant `EscortGate`. |
| `tint` | rouge (0.6, 0.2, 0.2) | Couleur appliquée au matériau dupliqué du mesh. |

**`level2_front.gd`**

| Export | Défaut | Rôle |
|---|---|---|
| `mage_scene` | `rune_mage.tscn` | Scène instanciée au respawn. |
| `mage_respawn_delay` | 3.0 | Délai avant réapparition. |

Toutes ces valeurs sont des points de départ pour le playtest, pas des
constantes définitives.

## Fichiers concernés

- `entities/shared/health.gd` — réserve de PV générique.
- `entities/shared/escort_gate.gd`, `escort_gate.tscn` — comportement
  détection + riposte réutilisable.
- `entities/tower/tower.gd`, `tower.tscn` — entité "tour classique".
- `entities/tower/tower_bolt.gd`, `tower_bolt.tscn` — projectile visuel de
  riposte.
- `core/faction.gd` — `Faction.PLAYER_LAYER` (bit 8, nouveau).
- `entities/mage/rune_mage.gd`, `rune_mage.tscn` — layer additif, `signal
  died`, refactoré sur `Health` (détail dans `Docs/front/front_unit_ai.md`, même
  refactor que `FrontUnit`), matériaux de barre de vie corrigés.
- `entities/base/base.gd` — `advance_target_tower`, transmis à chaque unité
  spawnée.
- `levels/level2_front.gd`, `level2_front.tscn` — deux tours, porte de
  victoire, respawn, câblage `advance_target_tower`.
- `entities/front_unit/front_unit.gd`, `ally_unit.tscn`, `enemy_unit.tscn` —
  refactorés pour utiliser `Health` ; siège de la tour ennemie (détail dans
  `Docs/front/front_unit_ai.md`).
