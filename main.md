# Spheres — vue d'ensemble du projet

> Point d'entrée uniquement : ce fichier ne duplique aucun détail déjà tenu à
> jour ailleurs, il dit ce que le projet **est** en gros et **où** trouver le
> reste. Si un fait précis change (mécanique, fichier, état d'une phase),
> corrigez-le dans le doc qui en est la source, pas ici.

## Le jeu, en une phrase

Le joueur incarne une **conscience** qui saute de sphère en sphère sur un
champ de bataille **sphère (rond, allié) contre cube (anguleux, ennemi)** ;
une seule sphère est active/contrôlée à la fois, les autres sont passives.
Nom de projet : **Spheres** (`config/name` dans `project.godot`) — *"The
Shore"* était un titre de travail antérieur, encore visible dans certains
noms de fichiers/lore.

## Deux boucles de jeu prototypées en parallèle — rien n'est encore tranché

C'est le point le plus important pour une discussion game design : le projet
n'a **pas convergé** vers une seule direction, deux formes de jeu coexistent
comme prototypes indépendants et jouables :

1. **Défense de vagues classique** (`levels/main.tscn`, phases 1-6) : le
   joueur défend un point fixe contre des vagues de cubes qui arrivent en
   ligne depuis le bord "monde-cube".
2. **Le Front** (`levels/level2_front.tscn`, phase 7) : deux bases qui
   s'affrontent, unités autonomes qui poussent l'une vers l'autre, une tour
   intermédiaire à assiéger — plus proche d'un mini-MOBA que d'une défense de
   vagues statique.

Les deux sont "implémentées et playtestées manuellement", aucune n'a été
choisie comme direction finale du prototype. Le système de **mouvement** de
la sphère active est lui-même explicitement décrit comme "expérimental,
swappable" (actuellement : reactor-ball `RigidBody3D`) — encore un axe
ouvert, pas un choix figé.

## Où trouver quoi

| Doc | Contenu |
|---|---|
| `Docs/Plans/LOOP_SPHERE_FRONT.md` | **Doc « objectif courant »** : la boucle de gameplay visée (Micro/Méso/Macro), où en est son implémentation, et la prochaine phase à faire — à lire en premier pour savoir quoi faire ensuite |
| `Docs/Plans/PLAN.md` | Plan d'implémentation phase par phase, structure du projet, état de chaque phase (✅/à faire), **« Questions ouvertes »** — la liste la plus utile avant une discussion game design |
| `Docs/Plans/phaseN_*.md` | Spec/prompt d'origine de chaque phase (1 à 7) — historique, pas la référence de comportement actuel |
| `Docs/front/front_unit_ai.md` | Référence technique **à jour** : mouvement/combat de `FrontUnit` (phase 7) |
| `Docs/front/tower.md` | Référence technique **à jour** : composants `Health`/`EscortGate`/`Tower` (objectif tour, phase 7) |
| `Docs/PLAYTEST_CHECKLIST.md` | **Ce qui reste à vérifier à la main** : les points qu'aucun test headless ne peut couvrir (pas de curseur, pas de rendu, et le *feel* qui se juge au lieu de se prouver), plus les non-régressions à repasser. À ouvrir avant un playtest |
| `Docs/LORE.md` | Lore minimal et volontairement léger (sphère vs cube, « the Shore ») — direction artistique/tonale, pas une mécanique |
| `Docs/GAME_DEV_STEP_VISUALS_AND_LEVEL.md` | Guide de méthode générique écrit tôt dans le projet (ordre visuels → niveau → contenu) — process, pas une spec du jeu actuel |

Scènes utiles pour s'orienter dans l'éditeur : `levels/main.tscn` (boucle
principale), `levels/level2_front.tscn` (Le Front),
`gameplay_loop/micro/micro_base_defense.tscn`, `micro_possession.tscn` et
`micro_terrain.tscn` (POC du palier Micro, phase 9 — une scène par jalon,
chacune copie de la précédente, donc `micro_terrain` est la plus avancée),
`levels/test_scene.tscn` (bac à sable parkour, sans rapport avec la boucle de
jeu),
`tests/shader_gallery.tscn` / `shader_showcase.tscn` (revue des shaders
sphère/tribu, hors gameplay).

## Lancer Godot et les tests

Le projet cible **Godot 4.7** (`config/features` dans `project.godot`), en
build standard — aucun `.cs`, donc pas besoin de la variante mono. L'install
se fait par winget (`winget install GodotEngine.GodotEngine`), qui place le
binaire dans un dossier dont le nom contient la version ; `tools/godot.sh`
résout la plus récente pour éviter un chemin en dur qui casserait au prochain
`winget upgrade` :

```sh
tools/godot.sh --version              # 4.7.2.stable.official
tools/godot.sh --path . --import      # réimporter après un changement d'engine
tools/run_tests.sh                    # toute la suite headless
tools/run_tests.sh rune_chain         # un seul test (filtre sur le nom)
```

> **`project.godot` ne garde pas les commentaires.** Godot réécrit le fichier à
> chaque lancement et supprime les lignes `;` au passage — inutile d'y documenter
> quoi que ce soit, l'explication doit vivre ici. Ce qui y a été perdu :
> `window/size/mode=2` (fenêtre maximisée) existe parce que sans lui le jeu
> tournait au 1152x648 par défaut de Godot — il n'y avait aucune section
> `[display]` — ce qui donnait une petite boîte sur un grand écran. Même piège
> pour les `.tscn` réenregistrées depuis l'éditeur.

Les scènes de `tests/` sont des tests de régression headless : chacune se
termine elle-même avec le code 0 (PASS) ou 1 (FAIL), et `run_tests.sh` en
fait le résumé. Les scènes `shader_*` sont des scènes de revue visuelle, pas
des tests — le runner les ignore.
