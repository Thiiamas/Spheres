# Phase 11 — POC Macro : capture de base

> **Objectif de cette phase.** Dernier des trois POC de boucle annoncés par
> `LOOP_SPHERE_FRONT.md`, après Micro (Phase 9) et Méso (Phase 10, terminée
> et validée). Palier Macro : **objectif = détruire la base adverse**,
> **challenge = combiner Micro + Méso** (tuer les ennemis, percer la tour,
> pousser jusqu'à la base), **récompense = contrôle du front, ouverture du
> front suivant**. La **nouveauté** posée par `LOOP_SPHERE_FRONT.md` pour ce
> palier : *« la base ennemie devient capturable — une fois prise, elle
> change de camp (devient alliée) au lieu d'être simplement détruite »* —
> ce n'est donc pas une décision ouverte, c'est déjà le point de départ du
> jalon, seule la mécanique concrète reste à définir (voir « Ce qui reste
> ouvert » plus bas, hérité de `phase9_micro_poc.md` et `Docs/front/
> tower.md`).
>
> Un seul jalon (11.1) est envisagé pour l'instant — contrairement à Micro
> (4 jalons) et Méso (2), presque toute l'infrastructure nécessaire existe
> déjà (voir « Ce qui existe déjà »). Si l'implémentation révèle plus de
> matière que prévu, ce document sera redécoupé, pas improvisé en cours de
> route.

---

## Organisation des scènes (`gameplay_loop/macro/`)

Même convention que Micro/Méso : nouveau dossier `gameplay_loop/macro/`,
séparé de `gameplay_loop/meso/`. **11.1** part d'une **copie** de
`meso_siege.tscn` (le jalon 10.2 a déjà tout : deux camps, Tour de chaque
côté, victoire/défaite propres) — `macro_capture.tscn`/`.gd`.

---

## Ce qui existe déjà (exploration du code avant de coder quoi que ce soit)

Comme pour Méso, la quasi-totalité de la mécanique est déjà en place :

- **La Base a de vrais PV et est déjà mordable** (9.1) : une fois la Tour
  adverse tombée (10.2, qui bloque physiquement et mécaniquement la
  progression tant qu'elle vit), une vague qui atteint la Base derrière
  l'endommage déjà, sans condition d'escorte (contrairement à `Tower.
  take_damage`, `Base.take_damage` est inconditionnel). **Rien à écrire
  pour que la Base devienne vulnérable au bon moment — c'est déjà vrai.**
- **Le spawn de vague est symétrique et automatique** (`Base._on_wave_timer_
  timeout`, phase 7) : n'importe quelle `Base`, quelle que soit sa faction,
  spawne son `unit_scene` toute seule. Il n'y a **aucune IA à écrire** pour
  qu'une base capturée se comporte correctement une fois retournée — elle
  spawnera pour son nouveau camp exactement comme elle le faisait pour
  l'ancien, à condition que `unit_scene`/`faction`/les layers soient
  cohérents après le retournement (voir sous-tâche 1).
- **`Progression.apply_progression()` a déjà un garde de faction** (trouvé
  en playtestant la 9.3, `phase9_micro_poc.md`) : *seul le joueur bénéficie
  de la progression du joueur*. Une Base qui devient `ALLY` en profitera
  donc **automatiquement** dès qu'`apply_progression()` est rappelée après
  le retournement — aucune nouvelle règle à écrire, juste un appel au bon
  moment.
- **`Base._on_health_died()` a déjà le bon point d'accroche** (D7, Phase
  10) : `stop_spawning()` y est déjà appelé sur soi-même à la mort. La
  capture n'est pas un mécanisme séparé à côté de la mort — c'est **une
  autre suite** donnée au même événement.

### Ce qui reste ouvert (hérité de `phase9_micro_poc.md` et `Docs/front/tower.md`)

Les deux docs notaient, sans trancher : *« capturer une base — c'est quoi
mécaniquement ? Détruire sa Tour puis un temps d'occupation par des unités
alliées (façon `EscortGate`) ? Ou une nouvelle mécanique dédiée ? »*

**Décidé ici (D1)** : **pas de nouvelle mécanique d'occupation.** La
capture se déclenche exactement comme la destruction se déclenchait déjà en
9.1/10.x — PV de la Base à 0, Tour adverse déjà tombée (gate déjà assurée
physiquement par la Tour, rien à garder en plus côté Base) — seule la
**suite** donnée à cet événement change : au lieu de rester inerte pour
toujours (H5, 9.1), la Base retourne de camp. Raison : `phase9_micro_poc.md`
anticipait déjà très précisément cette option — *« Phase 11 devra seulement
décider ce qui se passe après la destruction (capture vs. simple
élimination), pas réinventer le PV de Base lui-même »* — et le projet a
démontré à chaque phase précédente (9, 10) que réutiliser un mécanisme déjà
testé (`Health`/`died`) coûte presque rien comparé à en inventer un nouveau
(zone d'occupation, minuteur, UI de progression de capture).

**Conséquence sur H5 (9.1)** : *« la Base ne se `queue_free()` pas à 0 PV,
reste inerte »* était justifiée par *« pas de solution de repli dans ce
POC »* — Macro est précisément l'endroit où cette inertie devient un
**vrai** état de transition plutôt qu'une fin. `_defeated`/inerte-pour-
toujours reste le comportement **par défaut** (9.1, 10.x, `level2_front`
inchangés) ; la capture est un comportement **optionnel**, activé
explicitement par instance (D2 ci-dessous) — sans ça, changer le
comportement de mort de `Base` changerait aussi silencieusement celui de
toutes les scènes précédentes, qui reposent sur « détruite = reste cassée ».

---

## Décisions actées

| # | Sujet | Décision | Pourquoi |
|---|-------|----------|----------|
| D1 | Mécanique de capture | PV à 0 (réutilise `Health`/`died`), **pas** de zone d'occupation/minuteur séparé. Le retournement de camp remplace l'inertie permanente de H5, uniquement quand `capturable = true`. | Cohérent avec la note de la 9.1, coût quasi nul (voir « Ce qui existe déjà »). |
| D2 | Portée du changement | Nouveau champ `@export var capturable: bool = false` sur `Base`. `false` partout ailleurs (9.1, 10.x, `level2_front`) — comportement H5 inchangé ; `true` uniquement sur les deux `Base` de `macro_capture.tscn`. | `base.tscn` est partagé par **toutes** les scènes du jeu — changer le comportement par défaut de `_on_health_died()` casserait silencieusement « détruite = reste inerte » partout ailleurs, un contrat déjà attendu par 4 scènes existantes et leurs tests. |
| D3 | Victoire/défaite | Victoire = **Base ennemie capturée** (pas seulement sa Tour détruite — Méso l'avait déjà, Macro va plus loin). Défaite = **Base du joueur capturée**, symétrique. La Tour reste un **prérequis physique** (comme en 10.2) mais n'est plus elle-même la condition de fin. | Colle à la définition officielle du palier (« détruire [pousser jusqu'à] la base ») et à la nouveauté demandée (capture, pas simple élimination). |
| D4 | Ce qui se passe après la capture | Le camp qui capture **gagne immédiatement** — les deux spawns s'arrêtent au moment de la capture, comme en 10.2 avec la Tour. Pas de reprise de partie avec la base retournée activement défendue/attaquée par la suite. | `LOOP_SPHERE_FRONT.md` note déjà que « Macro n'a pas de fin de cycle » et que trancher « le front suivant » n'est **pas** requis par ce POC (« une ouverture », pas une boucle complète à refermer) — la validation demandée est « Micro + Méso fonctionnent ensemble avec une vraie condition de victoire », pas un mode infini. Le retournement de camp reste visible (D1) — le mérite du concept est montré — sans avoir à résoudre la suite. |
| D5 | Relief/portée | Réutilise `meso_siege.tscn` telle quelle (couloir plat, Tours à `z = ±10`, valeurs de vague déjà tunées en 10.2). Aucun réglage neuf par défaut. | Rien dans ce jalon ne teste le mouvement ou l'équilibrage de vague — seule la transition de capture est neuve. Réutiliser une base déjà validée isole la variable, même logique que H3/H6 des phases précédentes. |

---

## 11.1 — Capture de base

### Objectif

`gameplay_loop/macro/macro_capture.tscn` : copie de `meso_siege.tscn` où
les deux `Base` sont `capturable = true`. Percer la Tour adverse (10.2)
ouvre la voie à sa Base ; la détruire ne l'élimine plus, elle **change de
camp** — visuellement (teinte) et mécaniquement (spawn, PV, Progression) —
et la partie se termine immédiatement, victoire pour le camp qui capture.

### Prérequis

Phase 10 stable et mergée. `macro_capture.tscn` ne modifie ni
`meso_siege.tscn` ni `level2_front.tscn` (H5 par défaut inchangé partout
ailleurs, D2).

### Sous-tâches

**1. `Base` gagne un comportement de capture optionnel — `entities/base/base.gd`/`.tscn`**
- `@export var capturable: bool = false` (D2).
- `@export var captured_tint: Color` — la teinte affichée **après**
  retournement (l'auteur de la scène assigne la couleur du camp adverse :
  `EnemyBase.captured_tint` = bleu, `PlayerBase.captured_tint` = gris/rouge
  — chaque `Base` d'une paire ne retourne jamais que vers l'**unique** autre
  camp possible, pas besoin d'un champ par faction).
- `@export var ally_unit_scene: PackedScene` / `@export var enemy_unit_scene: PackedScene`
  — remplacent l'actuel `unit_scene` unique **uniquement pour les instances
  capturables** ; `unit_scene` reste piloté en interne, recalculé depuis la
  faction courante à chaque retournement (et à `_ready()`, pour ne rien
  changer aux scènes qui assignent encore `unit_scene` directement).
- Extraction d'un helper `_apply_faction_visuals_and_layers()` depuis les
  lignes déjà présentes dans `_ready()` (layers de `Hull`/`SelectionArea`,
  masque de `GoalZone`, teinte de `_structure`) — **appelé deux fois**:
  une fois normalement dans `_ready()`, une fois de plus après un
  retournement. Nécessaire : ces layers/masques ne sont aujourd'hui posés
  qu'une fois, jamais recalculés — sans ce refactor, une Base retournée
  garderait les couches physiques de son **ancien** camp (les unités de son
  nouveau camp la traiteraient comme hostile).
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
  `_capture()` (nouveau) : faction ← `Faction.opposite(faction)`,
  `health.set_hp(health.max_hp, true)` (reconstituée, pas laissée à 0 —
  visuellement, une base capturée n'a pas l'air à moitié détruite),
  `unit_scene` recalculé, `_apply_faction_visuals_and_layers()` rappelé,
  `tint` remplacé par `captured_tint`, `apply_progression()` rappelée (D3
  de la 9.2 : seul `ALLY` en profite, donc un retournement vers `ENEMY` n'a
  simplement plus d'effet, cohérent), **nouveau signal** `captured(new_
  faction: Faction.Kind)` émis (`died` n'est **pas** émis à la place — une
  base capturée n'est pas « morte », les scripts de niveau qui écoutent
  encore `died` sur une `Base` non-capturable ne sont pas concernés).
  `_defeated` n'est **jamais** mis à `true` pour une Base capturable —
  `drive()` continue de fonctionner normalement dessus après coup (utile
  si le joueur la possédait au moment du retournement... voir sous-tâche 3).

**2. Nouvelle scène `gameplay_loop/macro/macro_capture.tscn`/`.gd`**
- Copie de `meso_siege.tscn`. Sur `PlayerBase`/`EnemyBase` :
  `capturable = true`, `ally_unit_scene`/`enemy_unit_scene` assignés (les
  deux mêmes scènes déjà utilisées ailleurs), `captured_tint` réglé à la
  teinte de l'autre camp.
- `macro_capture.gd` : connecte `player_base.captured` → défaite (le joueur
  a perdu sa base), `enemy_base.captured` → victoire (D3/D4) — remplace les
  connexions à `died` de `meso_siege.gd` pour les deux `Base` (`Tower.died`
  n'a plus besoin d'être écouté séparément : la Tour reste un prérequis
  physique, plus une condition de fin en soi, D3).
- Message de victoire/défaite mentionne explicitement la capture (« Base
  ennemie capturée ! » / « Votre base a été capturée. ») plutôt que
  « détruite » — la distinction demandée par `LOOP_SPHERE_FRONT.md` doit
  se lire, pas seulement être vraie en interne.

**3. Cas à vérifier explicitement : la Base du joueur capturée pendant qu'il la possède**
- `_capture()` ne libère jamais la Base (comme H5) et ne met jamais
  `_defeated`. Si le joueur possède sa Base au moment où elle est
  capturée, il continue donc techniquement à la « conduire » — mais le
  script de niveau déclare la défaite au même instant (`captured` déjà
  connecté), donc la partie s'arrête avant que ça importe en pratique.
  À vérifier en test headless plutôt que supposé : driver une Base
  capturée juste après le retournement ne doit pas planter.

### Fichiers

- `entities/base/base.gd` (modifié — `capturable`, `captured_tint`,
  `ally_unit_scene`/`enemy_unit_scene`, `_apply_faction_visuals_and_layers()`,
  `_capture()`, signal `captured`)
- `gameplay_loop/macro/macro_capture.tscn`/`.gd` (nouveau)
- `tests/macro_capture_test.gd`/`.tscn` (nouveau — headless)

### Critères de validation

Vérifié **headless** :

- [ ] Une Base non-`capturable` (toutes les scènes existantes) garde
      exactement son comportement H5 — non-régression explicite, pas
      supposée
- [ ] Une Base `capturable` à 0 PV : `faction` inversée, PV remontés au
      max, `unit_scene` correspond au nouveau camp, `captured` émis (pas
      `died`)
- [ ] Après retournement, les couches physiques sont cohérentes : une unité
      du **nouveau** camp ne peut pas la mordre (elle est maintenant
      alliée), une unité de l'**ancien** camp le peut
- [ ] Une vague spawnée par la Base **après** son retournement porte bien
      le nouveau camp et progresse vers l'ancien
- [ ] `player_base.captured` déclenche la défaite ; `enemy_base.captured`
      déclenche la victoire
- [ ] Driver une Base capturable juste après son retournement ne plante pas
      (sous-tâche 3)
- [ ] Aucune régression : tous les tests headless précédents au vert

Confirmé **en playtest manuel** (`Docs/PLAYTEST_CHECKLIST.md`) :

- [ ] Le retournement se **voit** clairement (teinte, barre de vie
      remontée) — pas juste vrai en interne
- [ ] Le message de victoire/défaite se lit comme une capture, pas comme
      une destruction
- [ ] Le *feel* du siège (10.2) ne régresse pas jusqu'à la Base elle-même

### À ne PAS faire dans ce jalon

- Pas de « front suivant » — la capture met fin à la partie (D4)
- Pas de zone d'occupation/minuteur de capture (D1 — PV à 0 suffit)
- Pas de changement du comportement par défaut de `Base` en dehors de
  `capturable = true` (D2 — H5 doit rester intact partout ailleurs)
- Pas de nouveau relief/déséquilibrage de vague (D5)

---

## Point ouvert non traité par cette phase (à garder en tête)

`LOOP_SPHERE_FRONT.md` note que « Macro n'a pas de fin de cycle » — cette
phase montre qu'une base **peut** changer de camp, mais s'arrête là (D4) :
elle ne définit pas ce qui arriverait si la partie continuait après une
capture (un « front suivant », de nouvelles ressources, une seconde vague
d'objectifs). Resterait un chantier à part si le concept doit un jour
dépasser le stade du POC.
