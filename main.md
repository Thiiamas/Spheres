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
| `Docs/Plans/PLAN.md` | Plan d'implémentation phase par phase, structure du projet, état de chaque phase (✅/à faire), **« Questions ouvertes »** — la liste la plus utile avant une discussion game design |
| `Docs/Plans/phaseN_*.md` | Spec/prompt d'origine de chaque phase (1 à 7) — historique, pas la référence de comportement actuel |
| `Docs/front/front_unit_ai.md` | Référence technique **à jour** : mouvement/combat de `FrontUnit` (phase 7) |
| `Docs/front/tower.md` | Référence technique **à jour** : composants `Health`/`EscortGate`/`Tower` (objectif tour, phase 7) |
| `Docs/LORE.md` | Lore minimal et volontairement léger (sphère vs cube, « the Shore ») — direction artistique/tonale, pas une mécanique |
| `Docs/GAME_DEV_STEP_VISUALS_AND_LEVEL.md` | Guide de méthode générique écrit tôt dans le projet (ordre visuels → niveau → contenu) — process, pas une spec du jeu actuel |

Scènes utiles pour s'orienter dans l'éditeur : `levels/main.tscn` (boucle
principale), `levels/level2_front.tscn` (Le Front), `levels/test_scene.tscn`
(bac à sable parkour, sans rapport avec la boucle de jeu),
`tests/shader_gallery.tscn` / `shader_showcase.tscn` (revue des shaders
sphère/tribu, hors gameplay).

## Pour une discussion game design

Les questions qui n'ont **pas** de réponse dans le code aujourd'hui (détail
dans `Docs/Plans/PLAN.md`, « Questions ouvertes ») :

- Laquelle des deux boucles (défense de vagues vs Le Front) est le vrai
  prototype à pousser — ou les deux coexistent-elles délibérément ?
- Quel système de mouvement retenir pour la sphère active ?
- Comment le joueur obtient-il de nouvelles sphères/capacités en cours de
  run, et sont-elles choisies avant ou pendant la partie ?
- La conscience doit-elle pouvoir posséder autre chose que des sphères (déjà
  esquissé : balise, RuneMage) ?
- La caméra doit-elle montrer tout le champ de bataille ou rester proche de
  la sphère active ?
