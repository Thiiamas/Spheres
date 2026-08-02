# FrontUnit — mouvement et combat (référence à jour)

> **À tenir à jour.** Ce fichier décrit le comportement **actuel** de
> `entities/front_unit/front_unit.gd` — pas son historique. Toute modification
> du mouvement ou du combat de `FrontUnit` doit mettre à jour ce document dans
> le **même changement** (pas après coup). Pour le pourquoi de chaque choix et
> les essais qui n'ont pas marché, voir les sections correspondantes de
> `Docs/Plans/phase7_front.md` — ce fichier-ci ne garde que ce qui est vrai
> aujourd'hui.

## Vue d'ensemble

`FrontUnit` (`CharacterBody3D`) n'a ni pathfinding ni machine à états
complexe : à chaque frame physique, il recalcule sa direction à partir de
quelques vecteurs simples (seek + décalage d'essaimage + évitement), et gère
son attaque avec trois compteurs à rebours indépendants. Pas de
`NavigationAgent3D` — choix déjà acté (`Docs/Plans/PLAN.md`, « Hors scope v0.1 »).

## Les trois minuteurs

| Variable | Remis à | Rôle |
|---|---|---|
| `_root_timer` | `root(duration)` (RuneCage) | Immobilisation externe. Prioritaire sur tout : unité figée même hors combat. |
| `_attacking_timer` | `attack_duration` à chaque coup porté | Immobilisation auto-imposée pendant le coup. |
| `_attack_timer` | `attack_cooldown` à chaque coup porté | Délai avant qu'un **nouveau** coup soit tenté. |

Les trois décrémentent de `delta` à chaque `_physics_process`, quelle que
soit la branche empruntée ensuite.

## Priorité des branches (`_physics_process`)

1. **`_root_timer > 0`** — vitesse X/Z à zéro, gravité appliquée, tente quand
   même une attaque si `_attack_timer` le permet (un ennemi enraciné mord
   toujours ce qui traîne dans son `AttackZone`).
2. **`_attacking_timer > 0`** (sinon) — même immobilisation, mais **aucune**
   tentative d'attaque : le coup qui a armé ce minuteur vient d'atterrir, pas
   de nouvelle tentative avant la fin du geste.
3. **Libre** (ni l'un ni l'autre) — mouvement normal (voir plus bas), puis
   tentative d'attaque si `_attack_timer` le permet.

## Mouvement en branche libre

1. **Cible** : `_current_target()` (2026-08-02) — priorité à la `Tower`
   adverse (`target_tower`, assignée par `Base` comme `target_base`) si elle
   est vivante et dans `ENGAGE_RANGE` (6.0) ; sinon repli sur
   `_nearest_hostile()` — l'unité `FrontUnit` adverse la plus proche dans le
   groupe `front_ally`/`front_enemy`, à la même portée. Aucun test de ligne
   de vue : la distance seule compte, même si un allié bloque le chemin.
   Réévalué chaque tick (rien n'est mis en cache), donc une tour détruite
   entre deux frames relâche l'unité vers un minion ou la base l'instant
   d'après — voir `Docs/front/tower.md`, section « Les minions assiègent la tour ».
2. **Point visé** : si une cible (tour ou hostile) est trouvée → sa
   position ; sinon → la `Base` adverse (`target_base`) ; sinon (rien à
   faire) → vitesse nulle.
3. **Décalage d'essaimage** (`_surround_offset()`) : le point visé est
   décalé sur un cercle de rayon `surround_radius` autour de la cible, à un
   angle dérivé de manière stable de `get_instance_id()`. Sans ça, toutes les
   unités convergeant sur la même cible viseraient le **même point exact** et
   feraient la queue derrière la première arrivée — c'est ça, pas un manque
   d'évitement, qui causait l'empilement observé le 2026-07-24.
4. **Évitement local** (`_avoidance()`) : poussée loin de chaque autre
   `FrontUnit` (des deux factions) à moins de `avoidance_radius`, pondérée
   par `avoidance_weight`, sauf la cible hostile courante (qu'on veut
   justement atteindre). Corrige les cas résiduels que le décalage
   d'essaimage ne couvre pas (deux créneaux de cercle trop proches).
5. Direction finale = normalisation de (seek + évitement × poids) ; si le
   résultat est quasi nul (forces qui s'annulent), on retombe sur le seek pur
   plutôt que de rester figé.

## Le combat (`_try_attack`)

Appelé uniquement quand `_attack_timer <= 0`. Parcourt les corps qui
chevauchent `AttackZone` (`Area3D`, rayon ~1.2) et prend le **premier**
`FrontUnit` de faction adverse **ou** `Tower` adverse trouvé (depuis
2026-08-02 — la tour apparaît sans changement de layer/masque, elle réutilise
`Faction.physics_layer(faction)` comme `FrontUnit`) — **aucune priorité de
ciblage** au-delà de ça (pas de plus-faible-PV, pas de plus-proche, juste
l'ordre renvoyé par `get_overlapping_bodies()`). Sur ce premier corps trouvé :

```gdscript
body.take_damage(attack_damage)      # dégâts instantanés, pas de temps de trajet
_attack_timer = attack_cooldown      # prochain coup possible seulement après ce délai
_attacking_timer = attack_duration   # immobilisé jusqu'à la fin du geste
```

**Chronologie type** (défauts : `attack_cooldown = attack_duration = 1.2s`) :

```
t=0.0s    en portée, cooldown prêt → coup porté, les deux minuteurs à 1.2
t=0.0–1.2s   _attacking_timer > 0 → figé sur place, aucune nouvelle tentative
t=1.2s    les deux minuteurs tombent à 0 → reprise du mouvement libre,
          nouvelle cible/tentative immédiate si toujours en portée
```

Avec des valeurs égales (le défaut), l'unité reste plantée pour tout le
cycle de combat — c'est le comportement « immobile pendant l'attaque »
demandé. Réduire `attack_duration` sous `attack_cooldown` libère une fenêtre
de déplacement avant que le prochain coup ne soit disponible — l'équivalent
simplifié du « attack move » (kiting) de League of Legends. Rien ne
l'exploite aujourd'hui, c'est juste réglable par type d'unité si besoin.

**Limite connue** : comme `_try_attack()` prend le premier corps trouvé, une
unité qui termine son geste et retrouve **plusieurs** hostiles dans son
`AttackZone` peut « changer » de cible d'un coup à l'autre sans qu'il y ait
de mémoire de la cible précédente. Pas un bug, juste un manque de collant de
cible à garder en tête si ça se voit en jeu.

## Interface visuelle : `is_attacking` / `attack_started`

Ajouté le 2026-07-24 pour que des scripts externes (mise à jour de shader,
VFX) réagissent à l'attaque sans dupliquer la logique de timer :

- `is_attacking: bool` — propriété calculée (`_attacking_timer > 0.0`), pas
  de champ propre. À **sonder chaque frame** pour un effet continu (glow,
  teinte) pendant tout le geste.
- `signal attack_started` — émis une seule fois, au moment exact où
  `_try_attack()` porte un coup (juste avant de retourner). Pour un effet
  **ponctuel** (flash, à-coup d'échelle) qui ne doit pas se redéclencher à
  chaque frame tant que `is_attacking` reste vrai.

Aucun des deux ne prescrit *comment* l'effet est réalisé (shader, Tween,
particules…) — c'est volontairement laissé à qui consomme l'état.

## Shader de combat (`shaders/front_unit_attack.gdshader`)

Branché le 2026-07-24 sur `ally_unit.tscn` et `enemy_unit.tscn` : glow de
contour fresnel, terne à l'arrêt, qui bascule vers une couleur chaude et se
met à pulser tant que `attack_amount` est proche de 1 (uniforme du shader,
0.0–1.0). Un seul shader pour les deux factions — seuls les paramètres
diffèrent par instance (`base_color`, `attack_color`, `surface_roughness`…),
réglés directement dans chaque `.tscn`.

- `FrontUnit._ready()` récupère le matériau actif de `$MeshInstance3D`
  (`get_active_material(0)`) ; si c'est un `ShaderMaterial`, il est **dupliqué**
  et posé en `material_override` avant d'être gardé dans `_attack_shader`.
  Sans cette duplication, comme `Sphere_ally`/`Box_enemy` sont des ressources
  de mesh **partagées** entre toutes les instances de la scène, modifier le
  paramètre sur une unité l'aurait fait changer sur **toutes** les unités du
  même type (même bug de fond que `Base._structure`, voir
  `entities/base/base.gd`).
- `FrontUnit._process(_delta)` — nouveau, seule fonction de la classe qui
  touche au rendu plutôt qu'au gameplay — pousse
  `_attack_shader.set_shader_parameter("attack_amount", 1.0 if is_attacking else 0.0)`
  à chaque frame rendue. Binaire pour l'instant (pas de fondu basé sur le
  temps restant de `_attacking_timer`) ; envisageable plus tard si le flash
  net actuel est trop abrupt.
- Si le mesh d'une future scène `FrontUnit` n'utilise pas de `ShaderMaterial`,
  `_attack_shader` reste `null` et `_process` ne fait rien — sans erreur.

## PV et barre de vie : composant `Health`

Depuis l'ajout de la tour (`Docs/front/tower.md`), `FrontUnit` ne porte plus ses
PV en interne — il délègue à un enfant `entities/shared/health.gd`
(`class_name Health`), le même composant générique réutilisé par `Tower`.
Avant ce changement, `hp`/`max_hp`/`hp_bar` vivaient directement sur
`FrontUnit` (dupliqué depuis `entities/enemy/enemy.gd`) ; c'est maintenant la
première fois que ce bloc PV devient un vrai composant partagé plutôt qu'une
quatrième copie.

- `@export var health: Health` — référence typée vers l'enfant `Health`,
  câblée en `NodePath` dans `ally_unit.tscn`/`enemy_unit.tscn` (même
  convention que `SphereController.reactor` sur `sphere.tscn`).
- `Health` porte lui-même `max_hp`, l'accumulateur `hp`, le signal `died`, et
  la barre de vie (`hp_bar`, même contrat duck-typé
  `hp_bar.has_method("update_bar")` qu'avant, juste déplacé sur `Health`).
- `FrontUnit._ready()` connecte `health.died` à `_on_health_died()`, qui
  reproduit l'ancien ordre : `died.emit(self)` (signal propre à `FrontUnit`,
  toujours utile à un futur `Base` qui voudrait réagir à une mort) puis
  `queue_free()`.

## `take_damage` vs `take_hit`

- `take_damage(amount)` : transmet directement à `health.take_damage(amount)`
  — toute la logique PV (soustraction, `died`, barre de vie) vit maintenant
  dans `Health`, pas ici.
- `take_hit(damage)` : simple alias, présent uniquement pour que les sorts du
  RuneMage (qui vérifient `has_method("take_hit")`, comme sur `Enemy`)
  puissent toucher les `FrontUnit` de faction `ENEMY`. Voir
  `Docs/Plans/phase7_front.md` pour le détail des layers physiques qui rendent ça
  possible sans tir ami.

## Paramètres exportés

| Export | Défaut | Rôle |
|---|---|---|
| `faction` | `ALLY` | Camp — dérive groupe, layer physique, cible adverse. |
| `speed` | 3.5 | Vitesse de déplacement en branche libre. |
| `attack_damage` | 8.0 | Dégâts par coup porté. |
| `attack_cooldown` | 1.2 | Délai avant qu'un nouveau coup soit tenté. |
| `attack_duration` | 1.2 | Durée d'immobilisation après un coup porté. |
| `gravity` | 18.0 | Chute quand pas au sol (toutes branches). |
| `surround_radius` | 1.4 | Rayon du cercle d'essaimage autour d'une cible/base. |
| `avoidance_radius` | 1.6 | Portée de la poussée d'évitement local. |
| `avoidance_weight` | 2.2 | Poids de l'évitement face au seek dans le mélange final. |
| `health` | (NodePath `Health`) | Référence vers l'enfant `Health` ; `max_hp` (40.0 par défaut) se règle sur ce nœud, pas ici. |

## Fichiers concernés

- `entities/front_unit/front_unit.gd` — toute la logique ci-dessus.
- `entities/shared/health.gd` — composant PV générique (`class_name Health`),
  détail complet dans `Docs/front/tower.md`.
- `shaders/front_unit_attack.gdshader` — le glow de combat, décrit plus haut.
- `entities/front_unit/ally_unit.tscn`, `enemy_unit.tscn` — chacun applique le
  shader ci-dessus avec ses propres paramètres, et câble un enfant `Health`
  (qui porte lui-même la référence vers `HPBar3D`).
- `ui/hp_bar_3d.gd` — composant de barre de vie réutilisé tel quel (déjà
  utilisé par `SphereController` et `RuneMage`), non modifié.
- `entities/base/base.gd` — assigne `target_base`, `target_tower` et
  `faction` à chaque unité spawnée (voir `Docs/Plans/phase7_front.md` pour le
  spawn par vagues).
- `entities/tower/tower.gd` — cible de siège prioritaire ; détail complet
  (composition `Health`/`EscortGate`) dans `Docs/front/tower.md`.
- `core/faction.gd` — `Faction.Kind`, groupes, layers physiques.
