# Phase 6 — RuneMage : gameplay MOBA à la Ryze

> **Note de synchro (docs ↔ code).** Rédigé puis **implémenté** le 2026-07-04
> (branche `gameplay-ryze`, sous-phases 6.0 → 6.5 commitées séparément,
> validation headless à chaque étape). Les valeurs chiffrées sont des exports
> réglables. Voir « Implémentation réelle » en fin de document ; **playtest
> manuel effectué**, gameplay validé.

## Objectif

Un **deuxième gameplay complet** greffé sur l'architecture de possession de la
phase 5 : le **RuneMage**, une unité contrôlée à la souris façon League of
Legends (champion de référence : **Ryze**). C'est le premier vrai test de
charge du contrat `Controllable` : caméra, entrée et contrôle entièrement
différents de la sphère, **sans modification du cœur de possession**.

## Référence gameplay (spec)

- Caméra **au-dessus**, à la League of Legends.
- **Déplacement à la souris** (clic droit) à la League of Legends.
- Le **curseur cible les sorts** ; il **change de couleur** au-dessus d'un
  ennemi.
- **3 sorts** (clavier AZERTY) :

| Touche | Sort | Effet |
|--------|------|-------|
| **A** | **RuneBolt** (≈ Overload) | Projectile **en ligne** devant soi, vers le curseur. Touche le premier ennemi : X dégâts. Si l'ennemi porte la marque du **E** : **×2 dégâts**, puis le projectile **se sépare** : des éclats volent vers **tous les ennemis marqués alentour** et leur infligent **les mêmes dégâts** — chaque éclat qui touche un marqué **rechaîne** à son tour (propagation en chaîne, chaque ennemi touché une seule fois par lancer). |
| **Z** | **RuneCage** (≈ Rune Prison) | **Ciblé** sur l'entité sous la souris : **bloque ses déplacements** pendant X s (elle peut encore attaquer). Visuel : cage à barreaux. |
| **E** | **RuneFlux** (≈ Spell Flux) | Projectile **ciblé** sur l'entité sous la souris ; **s'attache** et **orbite** autour d'elle pendant X s (la « marque »). **Relancé sur un ennemi déjà marqué** : la marque se **propage aux ennemis alentour** (des flux secondaires partent du porteur vers ses voisins ; la propagation ne rebondit pas — un seul anneau par recast). |

Boucle type : E pour marquer → E sur le marqué pour **contaminer le pack** →
A pour **punir tout le groupe en chaîne** → Z pour immobiliser un fuyard.

## Prérequis

Phase 5 validée (contrats `Controllable` / `InputContext` / `CameraConfig`).

## Livrable

Le RuneMage instancié dans `Main.tscn`, dans le **cycle de possession Tab**
(sphères → balise → mage). Possédé : caméra LoL, déplacement clic droit,
curseur réactif, 3 sorts fonctionnels contre les cubes de la marée.

---

## Architecture (ce que la phase 5 donne gratuitement)

- **`RuneMageControllable`** (enfant `Controllable` de `RuneMage.tscn`) : le
  mage entre dans le pool de `Consciousness` sans que celui-ci change.
- **`mage_topdown.tres`** (`CameraConfig`) : pitch ≈ 56°, yaw 180° (le mage
  regarde la marée au nord), zoom 14 — le `CameraRig` l'applique tout seul.
- **`InputContext`** : les sorts lisent `ctx.just_pressed(&"spell_a")` etc.,
  le déplacement lit `ctx.pressed(&"move_click")` + `ctx.world_cursor`.

### Extension unique du tronc commun : la cible sous le curseur

Les sorts ciblés (Z, E) et le curseur réactif ont besoin de **l'entité sous la
souris**, pas seulement du point monde. `AimStrategy` raycast déjà les ennemis
en priorité — on expose ce résultat au lieu de le jeter :

- `AimStrategy.resolve_info(camera, origin)` → `{ position: Vector3,
  target: Node3D|null }` (l'ancien `resolve()` délègue et reste compatible) ;
- `CameraRig.get_aim_info(origin)` le relaie ;
- `InputContext` gagne **`hover_target: Node3D`** (null hors ennemi), rempli
  par `Consciousness` à côté de `world_cursor`.

Nouvelles actions d'entrée : `move_click` (clic droit), `spell_a` (A),
`spell_z` (Z), `spell_e` (E). Les chevauchements de touches avec la sphère
(`attack`=A, `aoe`=Z) sont **sans effet** : chaque entité ne consomme que ses
propres actions.

---

## Fichiers

### À créer

| Fichier | Rôle |
|---------|------|
| `RuneMage.gd` / `RuneMage.tscn` | `CharacterBody3D` : click-to-move, HP, cast des 3 sorts (exports : vitesse, dégâts, cooldowns, durées) |
| `RuneMageControllable.gd` | Contrat de possession + curseur custom (couleur selon `hover_target`) |
| `RuneBolt.gd` / `RuneBolt.tscn` | Sort A : projectile ligne ; ×2 dégâts si `RuneMark` présent sur la cible |
| `RuneFlux.gd` / `RuneFlux.tscn` | Sort E : projectile autoguidé vers la cible, pose la marque à l'impact |
| `RuneMark.gd` | La marque : orbe qui orbite l'ennemi, expire après `duration`, nœud nommé `RuneMark` (détection par le bolt) |
| `RuneCage.gd` / `RuneCage.tscn` | Sort Z : visuel cage à barreaux auto-détruit après la durée du root |
| `mage_topdown.tres` | `CameraConfig` LoL |

### À modifier

| Fichier | Changement |
|---------|-----------|
| `project.godot` | Actions `move_click`, `spell_a`, `spell_z`, `spell_e` |
| `InputContext.gd` | `hover_target` + les 4 actions dans `TRACKED_ACTIONS` |
| `AimStrategy.gd` | `resolve_info()` (point **et** collider) |
| `CameraRig.gd` | `get_aim_info()` |
| `Consciousness.gd` | Remplit `ctx.hover_target` |
| `Enemy.gd` | `root(duration)` : `_root_timer` fige le déplacement (l'attaque reste active) |
| `Main.tscn` | Instance du RuneMage |
| `HUD.gd` | Lignes d'entité génériques (duck-typing `get_hud_lines()`) pour afficher les cooldowns du mage |

---

## Valeurs de départ (exports)

| Paramètre | Valeur | Note |
|-----------|--------|------|
| Vitesse de déplacement | 6.0 m/s | |
| RuneBolt dégâts | 25 | cube = 40 HP → 2 bolts, ou **1 bolt marqué (50)** |
| RuneBolt cooldown | 1.2 s | vitesse 26 m/s |
| RuneFlux durée de marque | 4.0 s | cooldown 3 s ; re-marquer rafraîchit |
| RuneFlux rayon de propagation | 5.0 m | recast sur un marqué : contamine les voisins (1 anneau, pas de rebond) |
| RuneBolt rayon de chaîne | 6.0 m | éclats vers les marqués voisins ; chaque ennemi touché 1× par lancer |
| RuneCage durée de root | 1.5 s | cooldown 5 s |

## Sous-phases

1. **6.0** — doc + actions d'entrée + `hover_target` (aucun changement visible)
2. **6.1** — entité + click-to-move + caméra (possédable, se déplace)
3. **6.2** — curseur réactif au survol
4. **6.3** — sort A (dégâts de base)
5. **6.4** — sort E (marque orbitale) + synergie A ×2
6. **6.5** — sort Z (cage root)
7. **6.6** — synchro docs

## Implémentation réelle (2026-07-04)

| Élément | Réalisation |
|---------|-------------|
| Entité | `RuneMage.gd` (`CharacterBody3D`) : click-to-move (clic droit maintenu = suivi du curseur), rotation lissée vers la marche, HP 100 + `HPBar3D`, lueur d'émission possédé/idle. Caster : le cast **plante** le mage (LoL) et snappe son orientation. |
| Contrat | `RuneMageControllable.gd` — relais standard + **curseur-réticule dessiné à la volée** (anneau + point, aucun asset image) : cyan au sol, **rouge sur `hover_target`** ; restauré au relâchement. |
| Caméra | `mage_topdown.tres` (pitch 56°, yaw 180° face à la marée, zoom 14) — appliquée par le `CameraRig` de la phase 5 sans modification du rig. |
| Sort A | `RuneBolt.gd/.tscn` (`Area3D`, masque layer 2) : ligne droite, 25 dégâts, ×2 si l'ennemi porte un enfant nommé `RuneMark`. **Chaîne** : à l'impact sur un marqué, des **éclats autoguidés** (mode SHARD, collision d'aire coupée) partent vers chaque marqué dans `bolt_chain_radius` et rechaînent à leur tour ; une liste `visited` **partagée par référence** sur toute la chaîne garantit ≤ 1 touche par ennemi et par lancer (les cibles sont réservées à l'avance, pas de course entre éclats). |
| Sort E | `RuneFlux.gd/.tscn` : autoguidé sur `ctx.hover_target` (refus de cast sans cible) ; à l'impact pose/rafraîchit `RuneMark` — orbe émissif **construit en code** qui orbite le porteur 4 s. **Propagation** : recast sur un porteur → des flux secondaires (`can_spread=false`) partent du porteur vers chaque ennemi dans `flux_spread_radius` et les marquent — un seul anneau, pas de ping-pong. |
| Sort Z | `Enemy.root(duration)` : `_root_timer` fige le déplacement (gravité + morsures conservées, sémantique root LoL) ; visuel `RuneCage.gd` — 8 barreaux + anneau **construits en code**, parentés à l'ennemi, auto-détruits. |
| HUD | Bloc générique duck-typé `get_hud_lines()` : le mage affiche ses 3 cooldowns (READY / x.x s). |
| Écart au doc | `RuneMark` et `RuneCage` n'ont **pas de .tscn** (visuels 100 % code, plus simple) ; `RuneCage` n'est pas un projectile mais un effet instantané ciblé. |
| Groupe `enemies` | `Enemy._ready()` s'ajoute au groupe `"enemies"` : chaîne et propagation trouvent les voisins via `get_nodes_in_group` (pas de requête physique). |
| Test de régression | `Tests/RuneChainTest.tscn` (headless) : 1 bolt sur 3 cubes marqués alignés → les 3 meurent, un badaud non marqué est intact ; recast E sur un porteur → le voisin est contaminé. |

Boucle vérifiée par conception : cube 40 HP → 2 bolts, ou **E + A = 50 = one-shot**.

## Critères de validation

- [x] Tab inclut le RuneMage ; caméra LoL appliquée à la possession *(headless OK, confirmé en jeu)*
- [x] Clic droit : le mage marche vers le point cliqué (maintien = suivi du curseur) — *confirmé en jeu*
- [x] Le curseur change de couleur au-dessus d'un cube — *confirmé en jeu*
- [x] A : bolt en ligne, 25 dégâts, cooldown 1,2 s
- [x] E : flux ciblé, orbe qui orbite l'ennemi 4 s
- [x] A sur ennemi marqué : 50 dégâts (cube one-shot)
- [x] Z : l'ennemi ciblé est figé 1,5 s (cage visible), mais mord encore
- [x] E recast sur un marqué : la marque se propage aux ennemis dans le rayon (flux secondaires visibles ; pas de rebond en cascade)
- [x] A sur un marqué entouré d'autres marqués : éclats en chaîne, mêmes dégâts sur chaque marqué, chacun touché une seule fois
- [x] Le gameplay sphère est **inchangé** (cœur possession : seuls `hover_target` / `resolve_info` ajoutés, additifs)
- [x] Aucune erreur console (headless, Main + TestScene + SyntheticDriveTest)
- [x] **Playtest manuel complet** (feel du click-to-move, lisibilité des sorts, boucle E→E→A→Z)

## À ne PAS faire dans cette phase

- Pas d'auto-attaque, pas de mana, pas d'ulti (R) — 3 sorts, point.
- Pas de pathfinding (arène plate, `move_and_slide` glisse le long des piliers).
- Pas d'équilibrage fin — les valeurs sont des exports de départ.

---

*Phase précédente : `phase5_possession.md` — Concept global : `PLAN.md`*
