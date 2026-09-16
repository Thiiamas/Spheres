# Phase 10 — POC Méso : front des deux côtés

> **Objectif de cette phase.** Deuxième des trois POC de boucle
> (`LOOP_SPHERE_FRONT.md`), après la Phase 9 (Micro, mergée dans `main`).
> Palier Méso : **objectif = détruire la tour**, **challenge = enchaîner
> plusieurs boucles Micro pour percer**, **récompense = contrôle de la
> tour**. Contrairement à Micro (le joueur ne subissait qu'une vague
> ennemie), les **deux camps spawnent** désormais — la Base du joueur reçoit
> enfin sa propre vague alliée (`unit_scene`, déjà câblé mais inerte depuis
> la 8.1/9.2 faute d'usage).
>
> Découpée en **deux jalons**, dépendants l'un de l'autre : **10.1** (front à
> deux camps, **sans** Tour — valider que le combat à deux vagues est déjà
> satisfaisant en soi : caméra, rythme de spawn, contact) puis **10.2**
> (ajout de la Tour comme **objectif de siège**, qui referme la définition
> officielle du palier et pose enfin une vraie victoire/défaite). Ce
> découpage résout explicitement le point laissé ouvert par
> `LOOP_SPHERE_FRONT.md` (« la Tour est-elle exclue de ce POC ou
> sous-entendue ? ») — voir D1 plus bas : ni l'un ni l'autre, elle est
> **ajoutée dans un second temps**, même logique d'isolement de variable que
> 9.1→9.4 (H3, `phase9_micro_poc.md`).

---

## Organisation des scènes (`gameplay_loop/meso/`)

Même convention que la Phase 9, demandée explicitement pour que **chaque
palier de boucle reste indépendamment rejouable et retravaillable** plus
tard : un nouveau dossier `gameplay_loop/meso/`, séparé de `gameplay_loop/
micro/` et de `levels/` (qui garde `level2_front.tscn`, le prototype
phase 7/8 — non touché par cette phase, voir « Ce qui existe déjà »
ci-dessous).

**Une scène par jalon**, dupliquée et étendue plutôt que modifiée en place :

- `meso_front.tscn`/`.gd` (10.1 — deux camps, pas de Tour)
- `meso_siege.tscn`/`.gd` (10.2 — copie de `meso_front.tscn` + Tour ×2, sa
  propre victoire/défaite)

Coût accepté : duplication du décor/`PlayerBase`/`EnemyBase` entre les deux
scènes, comme en Phase 9 — c'est précisément ce qui garantit que 10.1 reste
jouable et testable seule même une fois 10.2 commencé.

---

## Ce qui existe déjà (exploration du code avant de coder quoi que ce soit)

Contrairement à la Phase 9, où Base-attaquable/Progression/Possession-roster
étaient tous du travail neuf, **le palier Méso est déjà presque entièrement
construit** — par la Phase 7 (Tour + siège + victoire) et la Phase 8/9
(Base jouable, possession, progression, PV de Base, déflexion d'obstacles).
Ce que l'exploration a confirmé, morceau par morceau :

- **`Base._on_wave_timer_timeout()` spawne déjà pour n'importe quelle
  faction** dès que `unit_scene` est assigné — rien à écrire pour qu'une
  `PlayerBase` envoie sa propre vague, il suffit de l'assigner et de mettre
  `wave_size` à une valeur non nulle dans la scène.
- **`Tower`/`EscortGate` sont déjà complets et testés en playtest**
  (`Docs/front/tower.md`, phase 7) : vulnérable seulement escortée, riposte
  sinon, `FrontUnit._current_target()` priorise déjà une Tour en portée sur
  tout autre ennemi — une unité assiégeant ne se laisse pas distraire.
- **La Tour bloque physiquement le couloir**, pas seulement mécaniquement :
  `Tower` est un `StaticBody3D` sur la même convention de layer que
  `FrontUnit`/`Hull`, positionnée *dans* la voie entre le spawn et la Base
  adverse (`level2_front.tscn` : `PlayerTower` à z≈-10, entre `PlayerBase`
  z=-20 et le départ du RuneMage z=-16). Une vague ne peut donc pas
  physiquement dépasser une Tour vivante pour atteindre la Base derrière —
  c'est ce qui fait fonctionner D1 (voir plus bas) : retirer la Tour en 10.1
  n'est pas un simple habillage, ça change réellement ce qu'une vague peut
  atteindre.
- **La possession se fait déjà par clic sur une unité alliée du front**
  (`PossessionSwap.try_select_at_cursor`, phase 8.2) : détruit le
  `FrontUnit` ciblé, fait apparaître un `RuneMage` à sa place, HP reportés
  proportionnellement. **Pas** le patron du roster fixe de 9.3 (D6/D7,
  `phase9_micro_poc.md`) — ce patron-là supposait des corps pré-placés
  jamais remplacés, qui n'a de sens que quand il n'y a pas de vague alliée.
  Ici, avec des unités qui spawnent et meurent en continu, reposséder
  l'unité suivante venue du front est le bon patron, et il est déjà **entièrement
  générique et testé** (`possession_swap_test.gd`) — aucun code neuf attendu
  pour la possession dans cette phase (voir D3).
- **`PossessionSwap.find_fallback_controllable()` est déjà générique** :
  retombe sur la Base alliée si vivante, sinon scanne les `RuneMage` alliés
  vivants (aucun en Méso puisqu'il n'y a pas de roster), sinon `null` — le
  script de niveau n'a qu'à réagir à `null` pour déclarer la défaite. Rien à
  changer ici non plus.
- **`Base` a de vrais PV depuis la 9.1** (`Hull`/`Health`), et
  `FrontUnit._damageable()` reconnaît déjà une `Base` adverse comme cible
  mordable, **sans condition de faction spécifique** (le filtrage vient du
  masque de collision de `AttackZone`, cf. `phase9_micro_poc.md` sous-tâche
  9.1.2). Concrètement : **une vague alliée qui atteint la Base ennemie peut
  déjà l'endommager**, même sans Tour — c'est un effet de bord non prévu par
  la 9.1 (écrite pour un POC à sens unique) mais qui tombe juste ici : ça
  donne à 10.1 une vraie condition de victoire/défaite gratuite (D2 plus
  bas), sans écrire de mécanique neuve.
- **`Progression` (9.2) et la déflexion d'obstacles (9.4) sont déjà
  globales et génériques** — aucun changement de code requis pour qu'elles
  s'appliquent ici. `wave_slot` (jusqu'ici un puits à ressources sans effet
  dans les scènes Micro, faute de `unit_scene`) devient enfin un achat
  **utile** dans cette phase.
- **`level2_front.tscn` (phase 7/8) est de fait un brouillon de ce palier**
  — Tour ×2, `Base` des deux côtés, `PlayerBase.unit_scene` déjà assigné
  (mais `wave_size = 0` par défaut : vague alliée dormante, débloquée par
  achat de `wave_slot`). Ça confirme que la mécanique tient déjà en
  conditions réelles ; le travail de cette phase est de la **composer dans
  une scène dédiée** (`gameplay_loop/meso/`), pas de la réinventer. `level2_
  front.tscn` n'est **pas modifié** par cette phase (voir « Trous non
  couverts »).

### Deux trous connus, exactement ceux que cette phase doit combler

Signalés mais explicitement différés par les phases précédentes — Méso est
« l'endroit » annoncé pour les traiter, pas un hasard :

1. **`Base.died` n'est écouté nulle part dans `level2_front.tscn`**
   (`phase9_micro_poc.md`, « Effet de bord sur level2_front.tscn — à traiter
   avec la défaite ») : une Base à 0 PV y devient silencieusement inerte,
   sans message ni fin de partie.
2. **`Tower.died` du joueur n'est pas écouté non plus**
   (`Docs/front/tower.md`, « Ce qui reste vrai » ; même trou noté dans
   `Docs/Plans/phase7_front.md`, « hors scope … à câbler avec la défaite
   plus généralement »).

Cette phase les résout — pour ses **propres** scènes (`gameplay_loop/meso/`
uniquement, voir « Trous non couverts » en fin de document pour
`level2_front.tscn`).

### Un troisième point trouvé en préparant cette phase

**Une Base « morte » continue de spawner ses vagues.**
`Base._on_health_died()` (9.1) met `_defeated = true` et coupe `drive()`
(tir mortier, achats), mais **n'appelle pas `stop_spawning()`** — rien ne
gardait cette garantie en Micro, où seule la Base *ennemie* spawnait et où
c'est le script de niveau qui coupait `enemy_base.stop_spawning()` sur la
mort du joueur. En Méso, les **deux** Bases spawnent : sans correctif, une
Base détruite continuerait indéfiniment à produire des unités, ce qui ne
tient pas thématiquement (une structure détruite ne construit plus rien) et
fausserait la lecture de la défaite. Corrigé une fois, dans `Base` elle-même
plutôt que dans chaque script de niveau (sous-tâche 10.1.1) — bénéfice
collatéral : `level2_front.tscn` et la future Macro en profitent aussi sans
rien recâbler.

---

## Décisions actées

| # | Sujet | Décision | Pourquoi |
|---|-------|----------|----------|
| D1 | Portée de la Tour | **Séquencée, pas tranchée d'un bloc** : 10.1 sans Tour (juste deux vagues + Bases qui peuvent déjà se blesser), 10.2 l'ajoute comme objectif de siège. | Résout le point ouvert de `LOOP_SPHERE_FRONT.md` sans deviner : la définition officielle du palier (« détruire la tour ») dit qu'elle doit y être, mais l'objectif du POC (« le combat doit déjà être agréable en soi ») dit de valider ce point d'abord, isolément — même raisonnement que H3 en Phase 9 (terrain plat avant relief). |
| D2 | Victoire/défaite en 10.1 | **Émergente, pas ajoutée** : Base ennemie détruite = victoire, Base du joueur détruite = défaite — conséquence directe du fait qu'une `Base` a de vrais PV (9.1) et est déjà mordable par un `FrontUnit` adverse, Tour ou pas. | Zéro mécanique neuve : juste écouter les deux `died` déjà émis et réagir (le trou n°1 ci-dessus, comblé par la même occasion). Donne à 10.1 un vrai critère de fin sans emprunter au palier Macro. |
| D3 | Possession | **Réutilise le clic-swap de la 8.2** (`PossessionSwap`), pas le roster fixe de 9.3. Aucun code neuf. | Le roster (D6/D7 en 9.3) supposait l'absence de vague alliée — faux ici. Le patron 8.2 gère déjà nativement des unités qui apparaissent et meurent en continu, et `find_fallback_controllable()` retombe déjà proprement sur la Base. |
| D4 | Victoire en 10.2 | **Tour ennemie détruite = victoire**, point final — pas de poussée jusqu'à la `GoalZone` de la Base adverse (contrairement à `level2_front.gd`). | Colle à la récompense officielle du palier (« contrôle de la tour »), pas à celle de Macro (« contrôle du front / base détruite »). Emprunter le patron `GoalZone` de `level2_front` mélangerait les deux paliers. |
| D5 | Défaite en 10.2 | **Tour du joueur détruite OU Base du joueur détruite** (les deux déclenchent la défaite, indépendamment). | Symétrique de D4 pour la Tour ; la règle de D2 (Base détruite = perte) reste vraie en 10.2, la Tour n'annule pas ce risque, elle ajoute juste un second front à défendre. |
| D6 | Relief/terrain | **Couloir plat, comme en 9.1** — pas de relief neuf dans cette phase. | Le point dur « le mouvement tient face à un terrain non-trivial » est déjà résolu génériquement par la déflexion d'obstacles (9.4, s'applique à tout `FrontUnit`). Le rejouer ici testerait la même chose deux fois ; l'objectif de cette phase est le *feel* du combat à deux camps, pas la robustesse du pathfinding. |
| D7 | Base morte arrête son propre spawn | Correctif dans `Base._on_health_died()` : `stop_spawning()` appelé sur soi-même, pas seulement décidé par le script de niveau. | Trouvé en préparant cette phase (voir plus haut) — sans ça, une Base détruite continuerait à produire des vagues indéfiniment. Un correctif générique profite aussi à `level2_front.tscn` et à la future Macro. |

---

## 10.1 — Front à deux camps (sans Tour)

### Objectif

Nouvelle scène où le joueur possède sa Base dès le départ (comme en 9.1),
mais où **les deux camps spawnent** des `FrontUnit` qui se rencontrent au
milieu du couloir. Le joueur peut posséder n'importe quelle unité alliée du
front pour combattre au contact (réutilise 8.2), ou rester à la Base pour
tirer au mortier et acheter des upgrades (réutilise 8.1/9.2). Victoire si la
Base ennemie tombe, défaite si la sienne tombe (D2) — sans Tour, sans siège,
juste le combat à deux vagues.

### Prérequis

Phase 9 stable (mergée dans `main`). Rien de neuf à écrire côté `Base`,
`FrontUnit`, `Progression` ou `PossessionSwap` — cette phase compose de
l'existant (voir « Ce qui existe déjà »), à l'exception du correctif D7.

### Sous-tâches

**1. Correctif D7 — `entities/base/base.gd`**
```gdscript
func _on_health_died() -> void:
    _defeated = true
    stop_spawning()
    died.emit()
```
Un seul appel ajouté. Aucune régression attendue : `stop_spawning()` est
déjà idempotent (`_spawning = false; _wave_timer.stop()`), déjà appelé
ailleurs par les scripts de niveau sur l'*autre* Base.

**2. Nouvelle scène `gameplay_loop/meso/meso_front.tscn`/`.gd`**
- Décor copié/adapté de `micro_base_defense.tscn` (couloir plat, D6) —
  **sans** Tour.
- **`PlayerBase`** : `faction = ALLY`, `mortar_scene`/`mortar_blast_scene`
  assignés (8.1), **`unit_scene = ally_unit.tscn`** (nouveau par rapport aux
  scènes Micro — c'est tout le point de cette phase), `wave_size` non nul
  dès le départ (pas de gating derrière un achat, contrairement à
  `level2_front`'s `wave_size = 0` — voir D2 : la vague alliée doit être
  visible dès la première seconde, c'est ce palier qui la teste).
- **`EnemyBase`** : `faction = ENEMY`, `unit_scene = enemy_unit.tscn`,
  `advance_target = PlayerBase`.
- `meso_front.gd` : câble `player_base.advance_target = enemy_base` et
  vice-versa (comme `micro_base_defense.gd`), déclenche
  `spawn_wave_now()` des **deux** côtés au démarrage, connecte
  `player_base.died` → message de défaite + `enemy_base.stop_spawning()`
  (D7 rend cet appel redondant mais explicite — cohérent avec le patron
  Micro), et `enemy_base.died` → message de victoire + symétrique.
- HUD debug réutilisé tel quel (`Base.get_hud_lines()`), maintenant avec
  `wave_slot` **effectif** puisque `PlayerBase.unit_scene != null`
  (`_is_applicable` en 9.2 le garde donc dans l'offre).

**3. Réglage initial des paramètres de vague**
- Valeurs de départ (à ajuster en playtest, comme toujours) :
  `wave_interval`/`wave_size` **identiques des deux côtés** pour commencer
  — un déséquilibre volontaire n'a de sens qu'une fois le combat symétrique
  validé comme agréable.
- `max_alive` par camp : garde-fou existant (phase 7), pas de nouveau
  réglage nécessaire.

### Fichiers

- `entities/base/base.gd` (modifié — D7)
- `gameplay_loop/meso/meso_front.tscn`/`.gd` (nouveau)
- `tests/meso_front_test.gd`/`.tscn` (nouveau — headless)

### Critères de validation

Vérifié **headless** (`tests/meso_front_test.tscn`) :

- [x] Une vague alliée spawne réellement dès le départ (pas besoin d'acheter
      `wave_slot` pour la voir apparaître)
- [x] Un `FrontUnit` allié qui atteint la Base ennemie l'endommage —
      confirme l'effet de bord de la 9.1 dans le sens que ce milestone
      n'avait jamais exercé (le sens ennemi → joueur était déjà couvert par
      `base_health_test`)
- [x] Une Base détruite arrête son propre spawn (D7) — vérifié en attendant
      8s (> `wave_interval` 6s) après la mort des deux Bases : aucune unité
      supplémentaire
- [x] `player_base.died` déclenche la défaite ; `enemy_base.died` déclenche
      la victoire
- [x] Aucune régression : les 9 tests headless du projet au vert

Confirmé **en playtest manuel** (`Docs/PLAYTEST_CHECKLIST.md`) :

- [x] Le *feel* du combat à deux vagues est bon **avant même d'ajouter la
      Tour** — c'est le critère central de ce jalon (caméra, rythme de
      spawn, lisibilité du contact entre les deux lignes)
- [x] Posséder une unité alliée du front (pas un corps de roster) fonctionne
      comme en 8.2 — clic, swap, combat, retour à la Base à la mort si elle
      vit encore
- [x] Victoire/défaite s'affichent correctement et arrêtent bien les deux
      spawns
- [x] `wave_slot` a un effet visible (plus d'unités alliées par vague)

**10.1 est complète et validée.**

### À ne PAS faire dans ce jalon

- Pas de Tour, pas de siège (10.2)
- Pas de relief (D6 — hors scope de toute la phase)
- Pas de nouveau patron de possession (D3 — réutilisation pure)
- Pas de déséquilibrage volontaire allié/ennemi avant d'avoir validé le
  combat symétrique

---

## 10.2 — La Tour comme objectif de siège

### Objectif

Referme la définition officielle du palier Méso : ajoute une Tour de chaque
côté, positionnée **dans** le couloir entre le spawn et la Base adverse (comme
`level2_front.tscn`), qui bloque physiquement et mécaniquement la progression
d'une vague tant qu'elle est vivante. Victoire = Tour ennemie détruite (D4).
Défaite = Tour **ou** Base du joueur détruite (D5).

### Prérequis

10.1 stable et validé en playtest — le combat à deux vagues doit déjà être
bon *avant* d'ajouter l'objectif par-dessus (sinon impossible de savoir si un
problème de *feel* vient du combat ou de la Tour). `gameplay_loop/meso/
meso_siege.tscn` part d'une **copie** de `meso_front.tscn`.

### Sous-tâches

**1. Nouvelle scène `gameplay_loop/meso/meso_siege.tscn`/`.gd`**
- Copie de `meso_front.tscn` + **`PlayerTower`**/**`EnemyTower`**
  (`tower.tscn`, phase 7), positionnées dans le couloir entre chaque Base et
  le point de rencontre des deux vagues (mêmes proportions que
  `level2_front.tscn` : Tour à mi-chemin entre spawn et Base adverse, pas au
  contact immédiat du spawn).
- `Base.advance_target_tower` câblé pour les deux camps (`unit.target_tower`
  déjà transmis par `Base._on_wave_timer_timeout`, rien à changer côté
  `FrontUnit`/`Base`).
- `meso_siege.gd` (nouveau script, ne réutilise **pas** `meso_front.gd` —
  contrairement à 9.4/`micro_terrain.tscn` qui partageait le script du
  jalon précédent : ici la règle de victoire/défaite change réellement,
  D4/D5 ne sont pas un sur-ensemble de D2, donc dupliquer le script plutôt
  que le brancher conditionnellement) :
  - `player_tower.died` / `player_base.died` → défaite (D5, l'un ou
    l'autre suffit)
  - `enemy_tower.died` → victoire (D4) — **pas** de porte `GoalZone` façon
    `level2_front.gd`, la Tour est la fin, pas une porte vers autre chose
  - Vague initiale des deux côtés comme en 10.1

**2. Vérification du blocage physique**
- Confirmer que la Tour, placée dans le couloir, bloque effectivement
  `move_and_slide()` (comme documenté dans `tower.md`) — pas de changement
  de code attendu, juste un test headless qui l'affirme explicitement
  plutôt que de le supposer hérité de la phase 7.

### Fichiers

- `gameplay_loop/meso/meso_siege.tscn`/`.gd` (nouveau)
- `tests/meso_siege_test.gd`/`.tscn` (nouveau — headless)

### Critères de validation

Vérifié **headless** (`tests/meso_siege_test.tscn`) :

- [x] Une vague ne peut pas endommager la Base adverse tant que sa Tour est
      vivante (bloquée/redirigée vers la Tour en premier — `_current_target()`
      déjà écrit pour ça, ce test le confirme en conditions Méso réelles,
      avec une vraie vague qui parcourt réellement le couloir)
- [x] La Tour détruite, la même vague reprend sa route et endommage la Base
      derrière
- [x] `enemy_tower.died` déclenche la victoire ; `player_tower.died` **et**
      `player_base.died` déclenchent chacun la défaite indépendamment (l'un
      ne déclenche pas l'autre)
- [x] Aucune régression : les 10 tests headless du projet au vert
      (y compris ceux de 10.1)

Confirmé **en playtest manuel** :

- [ ] La Tour se sent comme un vrai palier à franchir (pas un simple délai)
      — le siège (pousser sa vague, l'escorter) doit se sentir différent du
      pur combat de 10.1
- [ ] La riposte de la Tour contre un joueur non-escorté (`EscortGate`,
      phase 7) reste lisible et pas trop punitive dans ce contexte à deux
      vagues actives
- [ ] Victoire/défaite s'affichent correctement dans les trois cas (Tour
      adverse tombée, sa propre Tour tombée, sa propre Base tombée)

### À ne PAS faire dans ce jalon

- Pas de capture de la Tour/Base ennemie (Macro, phase 11)
- Pas de poussée jusqu'à la Base adverse comme condition de victoire
  supplémentaire (D4 — la Tour suffit, garder Macro pour la suite)
- Pas de relief (D6, toute la phase)

---

## Trous non couverts par cette phase (à garder en tête)

`level2_front.tscn` (phase 7/8) **n'est pas modifié** par cette phase — les
deux trous qu'elle comble (`Base.died`/`Tower.died` non écoutés) y restent
ouverts. Il partage `base.tscn`/`tower.tscn`/`front_unit.gd` avec
`gameplay_loop/meso/`, donc toutes les mécaniques (PV de Base, déflexion
d'obstacles, D7) s'y appliquent déjà silencieusement, comme noté pour
`level2_front` dans `phase9_micro_poc.md` — mais rien n'y réagit encore.
Décision explicite : ne pas toucher `level2_front.tscn` dans cette phase (il
reste le prototype historique phases 1-8, pas un jalon de boucle à
retravailler) ; si le trou doit être comblé un jour, ce sera une tâche à
part, pas un sous-produit de la Phase 10.

Le point « Macro n'a pas de fin de cycle » (`LOOP_SPHERE_FRONT.md`) reste
entier — cette phase ne le traite pas, Phase 11 le fera.
