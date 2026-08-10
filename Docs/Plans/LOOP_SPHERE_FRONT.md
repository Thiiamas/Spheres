# Boucle de gameplay — Sphere/Front

> Référence de la **boucle de gameplay visée** (Micro/Méso/Macro) et de son
> état d'avancement. Contrairement à `PLAN.md` (chronologie des phases déjà
> faites), ce doc répond à *"vers quoi on construit, et où est-ce qu'on en
> est par rapport à ça ?"* — c'est le doc à lire en premier pour savoir quoi
> faire ensuite. À tenir à jour à chaque changement de boucle ou de phase,
> comme `PLAN.md`.

---

## 🎯 Objectif actuel

**Phase 8 est terminée** (8.1 + 8.2, implémentées et playtestées
manuellement — cf. `phase8_foundations.md`). **Phase 9 (POC Micro) est
planifiée en détail** dans `phase9_micro_poc.md` — pas encore implémentée,
découpée en quatre jalons : **9.1 ✅** défense de Base (PV réels + Game Over,
ennemis en `FrontUnit` plutôt qu'`Enemy.tscn`) ; **9.2 ✅** progression
(débouché des ressources : `Upgrade` en `Resource` + autoload `Progression`,
portée globale, un seul portefeuille partagé) — les deux implémentées et
playtestées ; **9.3** possession d'une unité (variante RuneMage flaguée,
détails différés à l'implémentation ; Game Over généralisé à « toutes les
entités contrôlables mortes ») ; **9.4** relief/obstacles.

---

## La boucle en trois paliers

Chaque palier **contient** le précédent (Macro ⊃ Méso ⊃ Micro) plutôt que de
le remplacer — c'est une boucle de progression imbriquée, pas trois boucles
indépendantes.

### 🔵 Micro — combat individuel
| | |
|---|---|
| **Objectif** | Tuer un ennemi |
| **Challenge** | Les ennemis sont dangereux (pression, timing, positionnement) |
| **Récompense** | Ressources pour devenir plus puissant |

### 🟠 Méso — siège d'objectif
| | |
|---|---|
| **Objectif** | Détruire la tour |
| **Challenge** | Enchaîner plusieurs boucles Micro, monter en puissance grâce à leurs récompenses pour devenir capable de percer la tour |
| **Récompense** | Contrôle de la tour |

### 🔴 Macro — conquête du front
| | |
|---|---|
| **Objectif** | Détruire la base adverse |
| **Challenge** | Détruire les ennemis + la tour + pousser jusqu'à la base — combine les deux paliers précédents |
| **Récompense** | Contrôle du front entier, accès aux ressources près de la base conquise, ouverture du front suivant |

### Trous identifiés (non résolus par la phase en cours)
- **Micro → Méso** : ~~le lien "montée en puissance" du joueur n'existe
  pas~~ → **comblé côté Base par 9.2** (`phase9_micro_poc.md`) : système
  `Upgrade`/`Progression` générique, playtesté, où tuer des ennemis finance
  de vraies améliorations (cadence/dégâts du mortier, PV de base). Le
  playtest de 9.1 avait rendu le trou criant — les ressources
  s'accumulaient sans rien pouvoir acheter.
  **Reste à faire** : brancher le contrôlable lui-même dessus (9.3), pour
  que le joueur sente sa propre unité progresser et pas seulement sa
  structure. Le système est déjà prêt pour ça (achat géré dans
  `Controllable`, donc toute entité possédable en hérite).
- **Macro** n'a pas de fin de cycle définie ("ouverture du front suivant"
  est une progression linéaire, pas une boucle qui se referme) — pas
  bloquant pour l'instant, à trancher plus tard.

---

## Où en est l'implémentation

| Palier | État avant phase 8 | Ce que la phase 8 a apporté |
|---|---|---|
| Micro | ✅ Combat FrontUnit vs FrontUnit fonctionnel (phase 7) | Ajoute le **drop de ressources** à la mort d'un ennemi (8.1) |
| Méso | ✅ Tour + `Health`/`EscortGate` fonctionnels (phase 7) | Rien de nouveau directement — bénéficie indirectement de l'économie |
| Macro | ✅ Base vs Base, victoire par destruction de tour (phase 7) | La Base devient **jouable** (8.1) au lieu d'être un simple spawner IA |
| Possession (transversale, sert les 3 paliers) | ⚠️ Partielle — le joueur commence en RuneMage fixe, pas de switch vers/depuis un `FrontUnit` | **Terminée** par 8.2 : clic pour posséder un allié, swap `FrontUnit ↔ RuneMage`, retour possible sur la Base |

---

## Phase 8 — Prérequis (terminée)

> Détail complet : `phase8_foundations.md`. Cette phase ne construisait pas
> les 3 boucles elles-mêmes — elle posait les fondations dont elles
> dépendent (économie + possession complète).

### 8.1 — BaseController jouable
Le joueur démarre en contrôlant sa **Base** : tir longue distance (mortier)
visé souris, caméra RTS libre en edge-scroll (+ flèches en secours), gain de
ressources (`Economy`, autoload) au drop des ennemis morts, achat de slots
de vague (`wave_size`) via une touche debug (`B`).

**État : implémentée et validée en playtest manuel.**

### 8.2 — Possession complète (`FrontUnit ↔ RuneMage`)
Clic sur une unité alliée (`select`, action liée au clic gauche, distincte
d'`attack`) → possession : le `FrontUnit` ciblé est remplacé par un
`RuneMage` à sa position (HP conservés proportionnellement). Relâcher la
possession fait l'inverse. Déplacement du RuneMage en **ZQSD**. Possession
accessible depuis n'importe quel mode caméra.

**État : implémentée et validée en playtest manuel (2026-08-10)** — clic
souris réel sur une unité du Front et sorts A/Z/E post-possession
confirmés, au-delà de la couverture headless.

### Décisions/hypothèses actées pour cette phase
- Edge-scroll souris pour le pan caméra libre (flèches en fallback)
- Ressources ajoutées instantanément au pool joueur à la mort d'un ennemi
  (pas de pickup physique), feedback visuel minimal
- Un slot de vague = +1 sur `wave_size`, rien de plus pour l'instant
- Mort du RuneMage en cours de possession → retour automatique sur la Base
  — confirmé en playtest, ne se sent pas brutal

---

## Prochaines étapes (après la phase 8)

> Implémenter les 3 boucles **une par une**, chacune comme un **POC** isolé,
> perfectionné avant de passer à la suivante — pas de contenu, mais un
> "feel" abouti à chaque palier. Ordre : Micro → Méso → Macro, cohérent avec
> le fait que Méso et Macro **contiennent** Micro (cf. tableau plus haut).

### Phase 9 — POC Micro : défense de Base *(planifiée, cf. `phase9_micro_poc.md` — pas encore implémentée)*
| | |
|---|---|
| **Le joueur contrôle** | Uniquement la **Base** (8.1) |
| **En jeu** | Base (joueur) + `FrontUnit` **ennemis** uniquement — **pas** de spawn de `FrontUnit` allié pour le joueur (ça vient en Méso) |
| **Objectif du POC** | Perfectionner le **spawn** et le **comportement** des unités ennemies — pas le contenu, le *feel* du combat Base-vs-vague |
| **Point dur identifié** | Ajouter **obstacles et relief** sur la route des ennemis, pour vérifier que leur comportement de déplacement (`direction_to()` + évitement local, phase 7) **tient** face à un terrain non-trivial, pas seulement un couloir plat. C'est le premier vrai test de robustesse du pathfinding simplifié — s'il casse, c'est ici qu'on le découvre, avant d'empiler Méso/Macro par-dessus. |

> *Note.* Ce POC est, de fait, très proche de la boucle "défense de vagues"
> originale (phases 1-6) — mais rejouée avec la Base (8.1) comme point de
> contrôle et les `FrontUnit` (phase 7) comme ennemis, pas les `Enemy.tscn`
> d'origine. À clarifier au moment de coder : **on réutilise `Enemy.tscn`**
> (déjà testé contre obstacles/terrain simple) **ou on fait spawner des
> `FrontUnit` en mode ennemi** (comportement de siège, pas conçu à l'origine
> pour naviguer un terrain accidenté) ? Tendance actuelle : `FrontUnit`
> ennemis, puisque c'est leur comportement qu'on veut précisément
> perfectionner pour la suite — mais ça vaut une décision explicite avant
> de commencer, pas une supposition silencieuse comme H1-H5.

### Phase 10 — POC Méso : front des deux côtés
| | |
|---|---|
| **En jeu** | Base + `FrontUnit` **alliés et ennemis** — les deux camps spawnent maintenant |
| **Objectif du POC** | Peu de contenu, mais **tout doit être agréable en soi** : caméra, façon dont les unités spawnent, leur comportement au contact |
| **Portée** | "C'est tout" — pas de Tour listée explicitement, alors qu'elle fait partie de la définition de la boucle Méso (*"Objectif : détruire la tour"*, cf. tableau plus haut). |

> **Point à trancher avant de coder** : la Tour est-elle volontairement
> **exclue** de ce POC (on isole d'abord juste "deux fronts d'unités qui se
> rencontrent", sans objectif de destruction, pour que le combat seul soit
> déjà satisfaisant), ou sous-entendue comme déjà acquise depuis la phase 7
> et donc pas rementionnée ? Les deux sont défendables, mais ça change le
> critère de "c'est fini" pour ce POC — à clarifier plutôt que de le
> deviner.

### Phase 11 — POC Macro : capture de base
| | |
|---|---|
| **Nouveauté** | La base ennemie devient **capturable** — une fois prise, elle **change de camp** (devient alliée) au lieu d'être simplement détruite |
| **Objectif du POC** | Valider que **Micro + Méso fonctionnent ensemble** en conditions réelles, avec une **vraie condition de victoire**, et une **ouverture** vers l'itération suivante de la boucle Macro (le "front suivant") |
| **Comble** | Le trou identifié plus haut — *"Macro n'a pas de fin de cycle"* — puisque cette phase définit enfin ce que "gagner" et "continuer" veulent dire concrètement |

> **Point à clarifier plus tard (pas bloquant maintenant)** : "capturer" une
> base — c'est quoi mécaniquement ? Détruire sa Tour puis un temps
> d'occupation par des unités alliées (façon `EscortGate`, déjà existant) ?
> Ou une nouvelle mécanique dédiée ? Pas besoin d'y répondre avant la phase
> 9, mais ça vaut d'être noté ici pour ne pas l'improviser au dernier moment
> en phase 11.

---

## Prochaine étape

**Implémenter la phase 9** (`phase9_micro_poc.md`), en commençant par 9.1
(terrain plat) avant 9.2 (relief).
