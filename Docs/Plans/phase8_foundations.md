# Phase 8 — Prérequis : Base jouable + Possession complète

> **Objectif de cette phase.** Poser les deux briques manquantes identifiées
> pour que les 3 boucles Micro/Méso/Macro (`LOOP_SPHERE_FRONT.md` — ou son
> équivalent) soient réalisables : (a) un point d'entrée "Base" jouable avec
> économie de ressources, (b) la possession `FrontUnit ↔ RuneMage` terminée.
> Cette phase ne construit **pas** encore les 3 boucles elles-mêmes — elle
> construit les fondations dont elles dépendent (cf. discussion précédente :
> sans progression, le palier Méso n'a pas de sens ; sans possession finie,
> le cœur du jeu reste un mensonge).
>
> Découpée en **8.1** (Base) et **8.2** (Possession) — chacune livrable et
> jouable séparément, 8.2 dépendant de 8.1 pour le test de bout en bout
> (Base → possession → retour Base).

---

## Hypothèses retenues (à valider avant de coder)

Ces points n'ont pas été tranchés explicitement dans la conversation ; je
propose une valeur par défaut cohérente avec les patrons existants plutôt
que de bloquer sur une question de plus. **À corriger si faux.**

| # | Sujet | Hypothèse retenue | Pourquoi |
|---|-------|-------------------|----------|
| H1 | Pan caméra RTS libre | **Edge-scroll souris** : la caméra se déplace quand le curseur approche du bord de l'écran, vitesse proportionnelle à la proximité du bord. Les flèches (`cam_pan_left/right/up/down`, déjà mappées) restent disponibles comme méthode alternative/de secours, sans coût d'implémentation supplémentaire. | Plus naturel pour une caméra RTS libre que le clavier seul ; simple à greffer sur `CameraRig` (lecture de la position souris à l'écran, pas de nouvelle action Input Map). |
| H2 | Clic gauche partagé entre `attack` et `select` | Nouvelle action **`select`** (clic gauche), distincte d'`attack` (clic gauche aussi). Chaque `InputContext`/état actif ne lit que l'action qui le concerne — même trick que `Z` = `move_forward` en MOVEMENT / `aoe` en ATTACK (phase 1). | Évite de casser le tir de la sphère active en réassignant le clic gauche globalement. |
| H3 | Mort du RuneMage **pendant** qu'il est possédé (combat, pas relâché volontairement) | Retour automatique de la possession sur la **Base**, pas de respawn RuneMage/FrontUnit. | Il n'y a plus de "RuneMage permanent" en phase 8 (contrairement à la phase 7) — chaque RuneMage naît d'une possession et n'a pas vocation à survivre seul seul. À revalider en playtest : ça peut se sentir brutal. |
| H4 | Drop de ressource à la mort d'un ennemi | Ajout **instantané** au pool du joueur (pas de pickup physique), avec un feedback visuel court (flash + texte flottant "+N"), pas d'animation élaborée. | Conforme à ta réponse — "seulement une animation rapide et efficace pour l'instant". |
| H5 | Slot de vague = `wave_size` uniquement | Un achat = +1 sur `Base.wave_size` de la Base **possédée** (pas de variété d'unité pour l'instant). | Conforme à ta réponse. |

---

## 8.1 — BaseController jouable

### Objectif

Le joueur démarre la partie en contrôlant sa **Base**. Il peut : viser et
tirer à distance, faire défiler la caméra RTS librement, gagner des
ressources en tuant des ennemis (indirectement, via ses unités autonomes
existantes — la Base ne tue pas elle-même pour l'instant sauf via son
attaque), et acheter des slots de vague avec ces ressources.

### Prérequis

Phase 7 stable (`level2_front.tscn` jouable). Aucune dépendance sur 8.2.

### Livrable

Lancer `level2_front.tscn` (ou une variante), le joueur contrôle la Base dès
le départ (pas le RuneMage). Caméra libre pilotée aux flèches. Un tir à
distance sur clic. Un label debug affiche ressources courantes + coût du
prochain slot + slot actuel. Une touche achète un slot si assez de
ressources.

### Sous-tâches

**1. `BaseControllable` (nouveau composant, contrat `Controllable`)**
- Nœud enfant de la scène `Base` existante (`entities/base/base.tscn`),
  comme `SphereControllable` l'est pour `Sphere.tscn` (phase 5).
- `on_possessed()` / `on_released()` : pas grand-chose à faire (la Base ne
  change pas d'apparence visible en étant possédée — pas de couleur/mode à
  basculer, contrairement à la sphère).
- Expose un `CameraConfig` en mode **libre** (voir 8.1.2) plutôt que
  follow/topdown.
- Référence le `Base` sibling (le spawner existant) pour lire/écrire
  `wave_size` lors de l'achat de slot.

**2. Pan caméra RTS libre — réutilisation du mode `topdown` existant**
- `CameraRig` implémente déjà le pan libre (`_apply_pan`, edge-scroll +
  fallback clavier `cam_pan_*`) derrière deux flags **au niveau du rig**
  (`follow_target`, `edge_scroll`), actuellement statiques par scène plutôt
  que pilotés par la config active. Plutôt que d'ajouter un mode
  `FREE_PAN` dupliquant cette logique (proposition initiale), on ajoute un
  champ `free_pan: bool` à `CameraConfig` (groupe Topdown) et on fait
  suivre ces deux flags du rig depuis `apply_config()` quand
  `cfg.mode == &"topdown"`. Résultat identique à H1, sans dupliquer
  `_apply_pan`/edge-scroll/fallback clavier.
- Nouvelle ressource `entities/base/base_freepan.tres` : `mode = &"topdown"`,
  `free_pan = true`.
- Pas de bornes de carte pour ce jalon (le critère de validation est
  "rien ne casse", pas "la caméra est contenue" — à raffiner si le niveau
  grandit, comme le note déjà `_apply_pan`).
- **Retour playtest : l'edge-scroll était saccadé.** `_apply_pan` déclenchait
  le pan en tout-ou-rien (vitesse pleine dès que le curseur franchit
  `edge_margin`) sans lissage. Corrigé : vitesse graduée selon la proximité
  au bord (0 à `edge_margin`, 1 au bord de l'écran — l'intention initiale de
  H1) + lissage exponentiel du vecteur de pan appliqué (`_pan_velocity`,
  nouvelle état sur `CameraRig`), pour que le déplacement démarre/s'arrête en
  douceur plutôt que par à-coups. S'applique aussi au fallback clavier
  (`cam_pan_*`), qui bénéficie du même lissage.

**3. Attaque longue distance de la Base — mortier, pas `Projectile`**
- Première implémentation avec `Projectile.tscn` (phase 4, tir plat) :
  **rejetée en playtest** — un tir à hauteur de canon passe au-dessus des
  `FrontUnit` (boîte d'~1m de haut), il ne touche jamais rien au sol.
- Remplacé par `MortarShell` (nouveau, `entities/base/mortar_shell.gd/.tscn`) :
  trajectoire en arc (parabole) qui **atterrit sur le point visé** plutôt
  que de voler en ligne droite, puis dégâts de zone à l'impact (requête
  physique + explosion cosmétique, même patron que `AoeOrb`/`AoeBlast`
  phase 4 — réutilise `aoe_blast.tscn` tel quel).
- Visée : `MouseCursorAim` existant (phase 4/5), via `AimStrategy` —
  indépendant du mode caméra, aucune adaptation nécessaire.
- Déclenchement : action `attack` existante (clic gauche + touche A).
- Régression couverte par `tests/base_possession_test.tscn` : un ennemi
  placé exactement au point visé perd `mortar_damage` (et pas zéro).

**4. Autoload `Economy` (nouveau)**
```
autoloads/economy.gd
- var resources: int = 0
- signal resources_changed(new_amount)
- func add(amount: int) -> void
- func try_spend(amount: int) -> bool   # false si insuffisant
```

**5. Drop de ressource à la mort d'un ennemi**
- Composant séparé, `entities/shared/loot_on_death.gd` (Node, sibling de
  `Health`), écoutant `Health.died` — **sans modifier `Health`**, pour ne
  pas coupler un composant générique à l'économie du jeu.
- Ajouté sur `enemy.tscn` (phase 3/4) et `enemy_unit.tscn` (phase 7) — pas
  sur les unités alliées ni les tours.
- Feedback : flash + texte flottant "+N" court (pas d'animation élaborée).

**6. Achat de slot + HUD debug**
- Nouvelle action Input Map : `buy_slot` (touche `B`).
- Sur `buy_slot`, si `Economy.try_spend(cost)` réussit → `base.wave_size += 1`,
  coût suivant `cost = 20 + wave_size * 10`.
- Réutilise le HUD debug existant (`ui/hud.gd` lit déjà
  `entity.get_hud_lines()` de façon duck-typée pour toute entité possédée
  sans sphère/mage) plutôt que d'écrire un nouveau label dédié — `Base`
  expose `get_hud_lines()` : `Ressources: {n} | Slot: {wave_size} |
  Prochain: {cost}`.

### Fichiers

- `entities/base/base_controllable.gd` (nouveau)
- `core/camera_config.gd` (modifié — champ `free_pan`)
- `core/camera_rig.gd` (modifié — `apply_config` fait suivre
  `follow_target`/`edge_scroll` depuis `cfg.free_pan` ; `_apply_pan` avec
  vitesse graduée + lissage exponentiel, cf. retour playtest ci-dessus)
- `entities/base/base_freepan.tres` (nouveau)
- `entities/base/mortar_shell.gd`/`.tscn` (nouveau — arc + dégâts de zone à
  l'impact, remplace le `Projectile` plat rejeté en playtest)
- `autoloads/economy.gd` (nouveau, ajouté en Autoload)
- `entities/shared/loot_on_death.gd` (nouveau)
- `entities/base/base.gd` (modifié — `wave_size`/coût, `get_hud_lines()`)
- `entities/front_unit/enemy_unit.tscn` (modifié — ajout `LootOnDeath`).
  *(`entities/enemy/enemy.tscn`, phase 3/4, n'a pas de composant `Health` —
  hors scope de cette phase, qui ne cible que `level2_front.tscn`.)*
- `levels/level2_front.tscn` (modifié — `PlayerBase` reçoit `projectile_scene`
  et son nœud est réordonné avant `RuneMage` dans l'arbre, pour que sa
  `BaseControllable` s'enregistre en premier auprès de `Consciousness` et
  devienne l'entité possédée au démarrage — aucun changement de script
  nécessaire côté `level2_front.gd`)
- `tests/base_possession_test.gd`/`.tscn` (nouveau — test headless, même
  convention que `synthetic_drive_test`/`rune_chain_test`)
- Input Map : nouvelle action `buy_slot` ; `core/input_context.gd` (ajout de
  `buy_slot` à `TRACKED_ACTIONS`)

### Critères de validation

Tous vérifiés headless **et** en playtest manuel (édition, souris/clavier réels) :

- [x] La partie démarre avec la Base possédée (pas le RuneMage)
- [x] Les flèches/edge-scroll déplacent la caméra librement, sans à-coups —
      edge-scroll retravaillé deux fois en playtest (vitesse graduée + lissage,
      puis `edge_margin` 18px → 90px, cf. section caméra ci-dessus)
- [x] Clic gauche / A tire un mortier visé souris depuis la Base, qui atterrit
      sur la cible (le `Projectile` plat initial, rejeté en playtest, ne
      touchait rien — remplacé par `MortarShell`, cf. section attaque ci-dessus)
- [x] Les ennemis tués (par la Base ou par les FrontUnit alliés) ajoutent des
      ressources visibles au HUD (`LootOnDeath` + flash "+N" + `get_hud_lines()`)
- [x] `B` achète un slot si assez de ressources, augmente `wave_size`, le coût
      affiché grimpe
- [x] Aucune régression sur le comportement Front existant (bases IA, tours,
      FrontUnit)

**8.1 est complète et validée.**

### À ne PAS faire dans cette phase

- Pas de possession de FrontUnit (→ 8.2)
- Pas de variété d'unité par slot (juste `wave_size`)
- Pas de vraie UI (boutons, icônes) — label debug uniquement
- Pas de limite/plafond de ressources ou de coût progressif complexe

---

## 8.2 — Possession complète (`FrontUnit` ↔ `RuneMage`)

### Objectif

Le joueur peut, à tout moment (Base ou possession en cours), cliquer sur une
unité alliée pour la posséder en RuneMage ; en quitter la possession, elle
redevient un `FrontUnit` autonome. Le déplacement du RuneMage passe en ZQSD
(clic gauche libéré pour la sélection).

### Prérequis

8.1 stable (pour tester le cycle complet Base → possession → Base).

### Livrable

Depuis la Base, clic sur une unité alliée du Front → bascule en RuneMage à
sa position, HP conservés proportionnellement. Déplacement ZQSD. Clic sur
une autre unité alliée (ou sur la Base) → relâche la possession courante
(l'unité relâchée redevient FrontUnit autonome), possède la nouvelle cible.

### Sous-tâches

**1. Extension de `Consciousness` — possession directe (pas seulement cyclique)**
- Nouvelle API `request_possession(controllable)` en plus de
  `transfer_to_next()` (Tab) : bascule directement sur une entité précise
  au clic.
- Cas particulier : la cible peut ne **pas encore exister** dans le pool
  (le RuneMage est spawné à la volée) — géré par le swap (sous-tâche 3),
  pas par `request_possession` elle-même.

**2. `FrontUnitControllable` (nouveau, contrat `Controllable` sur `ally_unit.tscn`)**
- Point d'entrée cliquable qui délègue à un remplacement d'entité (sous-tâche 3),
  pas une possession classique sur place.
- Cliquable via raycast de sélection (sous-tâche 4), uniquement si
  `faction == ALLY`.

**3. Le swap `FrontUnit` → `RuneMage` et retour**
- Nouveau service `entities/front_unit/possession_swap.gd` : détruit le
  `FrontUnit`, fait apparaître un `RuneMage` à sa position avec HP
  proportionnels (et inversement au relâchement).
- Point d'attention (comme les bugs de référence périmée en phase 7) : le
  `FrontUnit` relâché doit retrouver sa cible (`target_tower`/`target_base`)
  correctement.

**4. Sélection au clic — nouvelle action `select`**
- Nouvelle action Input Map `select` (clic gauche — coexiste avec `attack`
  sur la même touche, H2).
- Raycast souris → monde ; si la collision porte un allié
  (`FrontUnitControllable`/`BaseControllable`) → `request_possession`.
  Sinon aucun effet (pas de move-to-click).
- Actif dans tous les modes caméra.

**5. Rework du déplacement RuneMage — ZQSD au lieu du click-to-move**
- Retire le click-to-move Ryze-style ; déplacement direct relatif caméra
  via `Input.get_vector` sur les actions `move_*` déjà existantes (ZQSD).
- Les sorts A/Z/E ne changent pas.

### Fichiers

- `autoloads/consciousness.gd` (modifié — `request_possession()`)
- `entities/front_unit/front_unit_controllable.gd` (nouveau)
- `entities/front_unit/possession_swap.gd` (nouveau)
- `entities/mage/rune_mage.gd` (modifié — déplacement ZQSD)
- `core/input_context.gd` (modifié — nouvelle action `select`)
- Input Map : nouvelle action `select`

### Critères de validation

- [ ] Clic sur un `FrontUnit` allié depuis la vue Base → possession en
      RuneMage, à la bonne position, HP cohérents
- [ ] ZQSD déplace le RuneMage possédé (plus de click-to-move)
- [ ] Les sorts A/Z/E fonctionnent toujours normalement
- [ ] Clic sur une autre unité alliée (ou retour sur la Base) relâche la
      possession courante → l'ancienne unité redevient un FrontUnit
      autonome qui reprend son comportement sans crash
- [ ] Mourir en étant possédé (RuneMage tué) renvoie la possession sur la
      Base sans crash (H3 — à confirmer en playtest)
- [ ] Aucune régression sur le comportement Front autonome existant

### À ne PAS faire dans cette phase

- Pas de possession d'unités **ennemies**
- Pas d'amélioration du RuneMage possédé lui-même (le lien Micro→Méso reste
  hors scope ici ; cf. note finale)
- Pas de transition caméra fluide (lerp) sur le switch

---

## Point ouvert non traité par cette phase (à garder en tête)

Le plan des 3 boucles notait un trou : *"Micro → Méso, le lien montée en
puissance n'existe pas encore"*. Cette phase 8 donne une **économie** (via
la Base) mais ne donne toujours pas de moyen, pour l'**unité possédée**
elle-même (le RuneMage), de devenir plus forte au fil d'une run — seule la
Base peut acheter des slots. Si l'intention est que le joueur sente sa
propre unité progresser (pas seulement son armée), ce sera une phase 9
distincte plutôt qu'un ajout tardif ici — mieux vaut le nommer maintenant
que le découvrir en playtest.
