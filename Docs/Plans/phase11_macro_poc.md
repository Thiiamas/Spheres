# Phase 11 — POC Macro : capture de base

> **Objectif de cette phase.** Dernier des trois POC de boucle annoncés par
> `LOOP_SPHERE_FRONT.md`, après Micro (Phase 9) et Méso (Phase 10, terminée
> et mergée). Palier Macro : **objectif = détruire la base adverse**,
> **challenge = combiner Micro + Méso** (tuer les ennemis, percer la tour,
> pousser jusqu'à la base), **récompense = contrôle du front, ouverture du
> front suivant**.
>
> **Révision (2026-09-17)** : la première version de ce plan traitait la
> capture comme un aller simple 1v1 qui termine la partie — rejetée par
> l'utilisateur. Le jeu final visera des scènes **beaucoup plus grandes**,
> avec **plusieurs bases à capturer pour avancer** ; ce POC doit donc
> valider le **mécanisme de chaîne**, pas juste « une base peut changer de
> camp ». Portée retenue pour 11.1 : **deux** bases ennemies, l'une à la
> suite de l'autre — la première capturée devient le **front actif** du
> joueur, celui d'où partent désormais ses propres unités, avant de pousser
> vers la seconde. Deux plutôt qu'un plus grand nombre : assez pour prouver
> que le relais fonctionne (une base capturée transmet l'offensive à la
> suivante), sans construire tout de suite la scène « beaucoup plus grande »
> visée par le jeu final — ça viendrait allonger la chaîne, pas changer le
> mécanisme.

---

## Organisation des scènes (`gameplay_loop/macro/`)

Même convention que Micro/Méso : nouveau dossier `gameplay_loop/macro/`.
**11.1** part d'une **copie** de `meso_siege.tscn`, étendue avec une
deuxième paire Tour/Base ennemie plutôt qu'une simple duplication 1v1 —
`macro_capture.tscn`/`.gd`.

---

## Ce qui existe déjà (exploration du code avant de coder quoi que ce soit)

Reste vrai, hérité de la Phase 10 :

- **La Base a de vrais PV et est déjà mordable** (9.1) une fois sa Tour
  tombée (10.2, qui bloque physiquement/mécaniquement la progression tant
  qu'elle vit) — rien à écrire pour que chaque Base de la chaîne devienne
  vulnérable au bon moment.
- **Le spawn de vague est symétrique et automatique**, quelle que soit la
  faction (`Base._on_wave_timer_timeout`, phase 7) — une base capturée
  spawnera pour son nouveau camp sans IA à écrire, à condition que
  `unit_scene`/faction/layers/**cible** soient recalculés (sous-tâche 1).
- **`Progression.apply_progression()` a déjà un garde de faction** (9.3) :
  une base qui devient `ALLY` profite automatiquement des achats du joueur
  dès qu'`apply_progression()` est rappelée après le retournement.
- **Les unités d'un même camp ne se bloquent pas mutuellement** —
  `_current_target()`/`_try_attack()` ne réagissent qu'à la faction
  opposée ; la Tour B (toujours ennemie) n'est qu'un obstacle physique
  ordinaire pour les unités ennemies de la Base A qui passeraient à
  proximité, pas une cible ni un allié à coordonner. C'est ce qui rend la
  chaîne possible **sans code de coordination neuf** : chaque Base ne
  connaît que sa propre cible (`advance_target`/`advance_target_tower`),
  câblée/recâblée par le script de niveau — jamais de logique de chaîne
  dans `Base`/`FrontUnit` eux-mêmes.

### La question laissée ouverte par la Phase 9/`Docs/front/tower.md`

*« Capturer une base — c'est quoi mécaniquement ? »* reste tranchée comme
dans la première version de ce plan (D1 ci-dessous, inchangé) : PV à 0,
`Health`/`died` déjà testés, pas de zone d'occupation/minuteur séparé. Ce
qui change avec cette révision, c'est **la suite** donnée à l'événement
(D4) — plus une fin de partie immédiate, mais un relais.

---

## Décisions actées

| # | Sujet | Décision | Pourquoi |
|---|-------|----------|----------|
| D1 | Mécanique de capture | Inchangé : PV à 0 (réutilise `Health`/`died`), pas de zone d'occupation/minuteur séparé. | Voir version précédente — coût quasi nul, déjà quasi entièrement supporté par l'existant. |
| D2 | Portée du changement | Inchangé : `@export var capturable: bool = false` sur `Base`, activé uniquement sur les instances de `macro_capture.tscn`. | `base.tscn` est partagé par toutes les scènes du jeu — H5 (Base détruite = reste inerte) doit rester le comportement par défaut ailleurs. |
| D3 | Portée du POC | **Deux** bases ennemies en chaîne (`EnemyBaseA` → `EnemyBaseB`), une seule base joueur. Pas symétrique : l'ennemi n'a pas sa propre chaîne de bases à faire tomber en retour dans ce POC. | Valide le relais (capturer A transmet l'offensive vers B) sans construire la carte « beaucoup plus grande » du jeu final — ça allongerait la chaîne, ça ne changerait pas le mécanisme testé ici. |
| D4 | Ce qui se passe après une capture | **Capturer `EnemyBaseA` ne termine PAS la partie.** Elle retourne de camp, redevient active, et son `advance_target`/`advance_target_tower` sont recâblés vers `EnemyBaseB`/`EnemyTowerB` — elle devient le nouveau front d'où partent les unités du joueur. **Révisé (retour utilisateur)** : `PlayerBase`, désormais derrière le nouveau front, devient « backline » — le niveau appelle `stop_spawning()` dessus, elle ne produit plus d'unités (pas de recâblage). Victoire = **`EnemyBaseB` capturée** (la dernière de la chaîne), pas avant. | C'est tout le point de la révision : la capture doit *relayer* l'offensive, pas clore la boucle au premier succès. Remplace D4 de la version précédente (qui faisait de la première capture une fin de partie). |
| D5 | Pression ennemie | **Révisé (retour utilisateur)** : `EnemyBaseB` est une base « backline » — elle **ne spawn rien** tant que `EnemyBaseA` n'est pas capturée ; à la capture, le niveau la réveille (`Base.start_spawning()` + vague immédiate), déjà câblée vers `PlayerBase`/`PlayerTower`. Remplace la version « pas de dormance ». | La double pression day-one n'était pas voulue : une base en arrière-ligne ne produit pas d'unités tant que le front devant elle tient. |
| D6 | Relief/portée | Réutilise le couloir plat de `meso_siege.tscn`, allongé pour loger la deuxième paire Tour/Base. Aucun réglage de vague neuf par défaut (10.2 a déjà tuné `wave_interval`/`wave_size`/dégâts de Tour). | Isoler la variable : ce jalon teste le relais de capture, pas l'équilibrage ni le terrain. |

---

## 11.1 — Chaîne de capture (deux bases ennemies)

### Objectif

`gameplay_loop/macro/macro_capture.tscn` : `PlayerBase`/`PlayerTower` face à
**deux** paires Tour/Base ennemies alignées (`TowerA`/`EnemyBaseA` puis
`TowerB`/`EnemyBaseB`, plus loin). Percer `TowerA` ouvre la voie à
`EnemyBaseA` ; la capturer (D1) la retourne côté joueur **et** la
transforme en nouveau point de départ offensif vers `TowerB`/`EnemyBaseB`
(D4). Capturer `EnemyBaseB` clôt la partie — victoire.

### Prérequis

Phase 10 stable et mergée (fait). `macro_capture.tscn` ne modifie ni
`meso_siege.tscn` ni `level2_front.tscn` (H5 par défaut inchangé partout
ailleurs, D2).

### Sous-tâches

**1. `Base` gagne un comportement de capture optionnel — `entities/base/base.gd`/`.tscn`**
- `@export var capturable: bool = false` (D2), `@export var captured_tint: Color`
  (teinte affichée après retournement — chaque instance ne retourne jamais
  que vers l'unique autre camp possible, pas besoin d'un champ par
  faction), `@export var ally_unit_scene`/`@export var enemy_unit_scene`
  (remplacent `unit_scene`, recalculé depuis la faction courante).
- Extraction d'un helper `_apply_faction_visuals_and_layers()` depuis les
  lignes déjà présentes dans `_ready()` (layers `Hull`/`SelectionArea`,
  masque `GoalZone`, teinte `_structure`) — rappelé après un retournement,
  sinon la Base garderait les couches physiques de son **ancien** camp.
- `_on_health_died()` :
  ```gdscript
  func _on_health_died() -> void:
      stop_spawning()
      if capturable:
          _capture()
          return
      _defeated = true
      died.emit()
  ```
  `_capture()` : faction ← `Faction.opposite(faction)`, PV remontés au max
  (`health.set_hp(health.max_hp, true)`), `unit_scene` recalculé,
  `_apply_faction_visuals_and_layers()` rappelée, `tint` ← `captured_tint`,
  `apply_progression()` rappelée, **relance le spawn** (`_spawning = true`,
  redémarre `_wave_timer` — contrairement à la version précédente de ce
  plan, la Base capturée **continue** de jouer), signal **`captured(new_
  faction: Faction.Kind)`** émis (pas `died` — une base capturée n'est pas
  « morte »). `_defeated` n'est jamais mis à `true` pour une Base
  capturable.
- **Nouveau, propre à cette révision** : `Base` expose une méthode
  `retarget(new_base: Node3D, new_tower: Node3D) -> void` (`advance_target
  = new_base; advance_target_tower = new_tower`) — utilisée par le script
  de niveau pour recâbler la cible d'une Base déjà en jeu (D4). Une simple
  fonction plutôt que de laisser le niveau écrire directement dans les
  champs : documente l'intention (« cette Base change d'objectif ») au même
  endroit que le reste du contrat de `Base`.

**2. Nouvelle scène `gameplay_loop/macro/macro_capture.tscn`/`.gd`**
- Couloir allongé (copie/étendue de `meso_siege.tscn`) : `PlayerBase` →
  `PlayerTower` → `EnemyBaseA` (`capturable = true`,
  `ally_unit_scene`/`enemy_unit_scene` assignés, `captured_tint` = teinte
  alliée) → `TowerB` → `EnemyBaseB` (mêmes réglages, `captured_tint`
  également alliée puisqu'elle ne peut retourner que vers le joueur).
  `TowerA` entre `PlayerBase` et `EnemyBaseA` (bloque l'approche initiale) ;
  `TowerB` entre `EnemyBaseA` et `EnemyBaseB` (bloque l'accès à la cible
  finale, avant **et** après la capture de `EnemyBaseA` — rien ne change
  pour elle).
- Câblage initial (D5) : `PlayerBase.advance_target = EnemyBaseA` /
  `advance_target_tower = TowerA`. `EnemyBaseA.advance_target = PlayerBase`
  / `advance_target_tower = PlayerTower`. `EnemyBaseB.advance_target =
  PlayerBase` / `advance_target_tower = PlayerTower` **aussi** — les deux
  bases ennemies visent le joueur dès le départ (D5), leurs unités se
  croisent sans se gêner (factions identiques, pas de friction).
- `macro_capture.gd` :
  - `enemy_base_a.captured.connect(_on_enemy_base_a_captured)` → appelle
    `enemy_base_a.retarget(enemy_base_b, tower_b)` (elle devient le
    nouveau front, D4) **et** `player_base.stop_spawning()` (`PlayerBase` devient backline :
    le front du joueur est désormais `EnemyBaseA`, elle ne produit plus
    d'unités) ; `enemy_base_b.start_spawning()` réveille la base backline
    ennemie (D5).
  - `enemy_base_b.captured.connect(_on_victory)` — dernière de la chaîne,
    fin de partie (D3/D4).
  - `player_base.captured.connect(_on_defeat)` (`PlayerBase.capturable =
    true` aussi — symétrique, le joueur peut perdre sa base de la même
    façon qu'il capture celle de l'adversaire).
  - Vague initiale des trois bases au démarrage (`spawn_wave_now()`).
- Messages distincts : « Front A capturé ! » (transitoire, pas un message
  de fin — juste une confirmation lisible que le relais a eu lieu) puis
  « Victoire ! » à la capture de B, ou « Défaite » si `PlayerBase` tombe.

**3. Cas à vérifier explicitement**
- **Base capturée pendant qu'elle est possédée par le joueur** : comme
  dans la version précédente de ce plan — `_capture()` ne libère jamais la
  Base et ne met jamais `_defeated`, `drive()` continue de fonctionner
  après coup. Pertinent uniquement pour `PlayerBase` dans ce POC (le joueur
  ne possède jamais une Base ennemie avant sa capture).
- **Un `FrontUnit` déjà en vol vers une cible qui devient alliée entre
  temps** : une unité spawnée par `PlayerBase` *avant* la capture de
  `EnemyBaseA`, encore en approche au moment où elle bascule, continue de
  marcher vers sa position (son `target_base` n'est pas réévalué en vol) —
  elle arrive, trouve une base alliée, n'attaque rien, reste plantée là.
  Accepté comme limite connue de ce POC (cosmétique, pas de crash, pas de
  perte de ressources) plutôt que corrigé : corriger demanderait de faire
  réévaluer `target_base` à chaque `FrontUnit` en vol, hors du périmètre
  d'un mécanisme de *capture*, pas de *pathing*.

### Fichiers

- `entities/base/base.gd` (modifié — `capturable`, `captured_tint`,
  `ally_unit_scene`/`enemy_unit_scene`, `_apply_faction_visuals_and_layers()`,
  `_capture()`, `retarget()`, signal `captured`)
- `gameplay_loop/macro/macro_capture.tscn`/`.gd` (nouveau)
- `tests/macro_capture_test.gd`/`.tscn` (nouveau — headless)

### Critères de validation

Vérifié **headless** (`tests/macro_capture_test.gd`) :

- [x] Une Base non-`capturable` (toutes les scènes existantes) garde
      exactement son comportement H5 — non-régression explicite
- [x] `EnemyBaseA` à 0 PV : faction inversée, PV remontés, `unit_scene`
      correspond au nouveau camp, layers cohérents (mordable par l'ancien
      camp, pas par le nouveau), `captured` émis (pas `died`), le spawn
      **reprend** sous le nouveau camp
- [x] Après capture de `EnemyBaseA`, elle vise bien `EnemyBaseB`/`TowerB`
      (et non plus `PlayerBase`) ; `PlayerBase` devient backline (ne spawn plus)
- [x] `EnemyBaseB` reste protégée par `TowerB` exactement comme avant la
      capture de `EnemyBaseA` (aucun raccourci ouvert par le relais) —
      vérifié avec un vrai trajet minuté, pas seulement le câblage
- [x] `player_base.captured` déclenche la défaite ; `enemy_base_b.captured`
      déclenche la victoire ; `enemy_base_a.captured` ne déclenche **ni
      l'une ni l'autre** (juste le relais)
- [x] Driver une Base capturable juste après son retournement ne plante pas
- [x] Aucune régression : les 12 tests headless du projet au vert

Confirmé **en playtest manuel** (`Docs/PLAYTEST_CHECKLIST.md`) :

- [ ] Le retournement de `EnemyBaseA` se voit clairement (teinte, barre de
      vie remontée, nouvelle vague qui en sort peu après)
- [ ] Le relais se sent juste : une fois `EnemyBaseA` prise, l'assaut vers
      `EnemyBaseB` démarre sans que le joueur ait à tout relancer
      manuellement depuis `PlayerBase`
- [ ] Le réveil de `EnemyBaseB` après la capture de `EnemyBaseA` (D5
      révisé) crée-t-il un nouveau pic de pression lisible ?
- [ ] Le message « Front capturé » puis « Victoire » se lit bien comme deux
      étapes distinctes, pas comme une fin prématurée

### À ne PAS faire dans ce jalon

- Pas de chaîne symétrique côté ennemi (l'ennemi n'a pas à capturer les
  bases du joueur en cascade dans ce POC, D3)
- Pas de mécanisme de dormance générique dans `Base` : le niveau endort/réveille la base backline via `stop_spawning()`/`start_spawning()` (D5)
- Pas de nouveau relief/déséquilibrage de vague au-delà de ce qu'impose la
  chaîne (D6)
- Pas de correctif sur le pathing des unités déjà en vol au moment d'une
  capture (limite connue, sous-tâche 3)
- Pas de carte « taille finale » avec de nombreuses bases — deux suffisent
  à valider le mécanisme (D3)

---

## Bugs connus trouvés en playtest (à traiter, pas encore corrigés)

Constatés par l'utilisateur sur `macro_capture.tscn` après la capture de
`EnemyBaseA` — **non corrigés**, à reprendre dans une session dédiée :

- **Une Base capturée ne devient pas possédable.** `PlayerBase` s'arrête
  bien de spawner (backline, voulu), mais le joueur ne peut pas basculer
  sur `EnemyBaseA`, devenue son nouveau front. Cause probable : le
  `Controllable` d'une Base est posé une seule fois dans son `_ready`
  (`base_controllable.gd`) selon sa faction **d'origine** (null pour une Base
  ennemie) ; rien ne le (re)crée ni ne l'enregistre dans le pool de
  possession au retournement (`_capture()`).
- **Crash en alternant entre une `FrontUnit` possédée et la première Base.**
  Aller-retour unité ↔ `PlayerBase` (swap de possession, phase 8.2) plante.
  À reproduire et diagnostiquer ; piste : `PlayerBase` a été mise en
  sommeil (`stop_spawning()`) / la Base garde l'état de possession
  (`controllable`, `_defeated`, `drive()`) qui suppose une Base toujours
  jouable côté joueur.
- **Chantier à prévoir : mieux gérer la façon dont une Base devient
  contrôlable** — le rendre dépendant de la faction *courante* (activation/
  désactivation au retournement, enregistrement/retrait du pool, retour de
  contrôle si la Base possédée est capturée) plutôt que d'un état figé à
  `_ready`. À planifier avant de passer à des chaînes de plus de deux bases.

---

## Point ouvert non traité par cette phase (à garder en tête)

Le jeu final visera des scènes bien plus grandes avec plusieurs bases à
enchaîner — ce jalon valide le **relais à deux maillons**, pas la mise à
l'échelle (N bases, plusieurs lignes de front en parallèle, symétrie
complète des deux côtés). `LOOP_SPHERE_FRONT.md` note aussi que « Macro n'a
pas de fin de cycle » — ce POC clôt bien la partie à la capture finale
(D4), mais ne définit toujours pas ce qui suivrait un « front suivant » au
sens d'une campagne continue. Restent des chantiers à part.
