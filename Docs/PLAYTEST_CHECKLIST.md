# Checklist de playtest manuel

Ce qui ne peut **pas** être vérifié en headless, et qui attend donc un passage
manuel. Tenue à jour au fil du développement : coche ce qui est validé, et
laisse une note quand quelque chose ne va pas.

Tout ce qui n'est pas dans cette liste est couvert par `tools/run_tests.sh`
(8 tests). Si un point ci-dessous devient automatisable, il doit **quitter cette
liste** et devenir une assertion.

Rappel : lancer la scène courante avec **F6**, pas F5 — `run/main_scene` pointe
sur `levels/main.tscn`, donc F5 lance toujours le niveau 1 (phases 1-6), qui n'a
ni économie ni palier Micro.

```sh
tools/godot.sh --path . res://gameplay_loop/micro/micro_terrain.tscn
```

---

## Pourquoi ces points restent manuels

Trois raisons, et une seule est technique :

- **Pas de curseur en headless** : la résolution du rayon sous la souris
  (`CameraRig.raycast_at_cursor`) ne peut pas être simulée. Tout ce qui est *en
  aval* du clic est testé.
- **Pas de rendu** : lueur, teintes, lisibilité d'un contournement.
- **Le *feel* n'est pas une assertion** : un équilibrage ne se prouve pas, il se
  juge. Ces points-là sont des questions, pas des cases à valider.

---

## Palier Micro — jalon 9.3 (possession)

Scène : `gameplay_loop/micro/micro_possession.tscn`

### Ce qui a besoin d'un curseur ou d'un œil

- [x] **Clic sur un corps du roster** en prend le contrôle. Les 3 corps sont à
      4 m devant la Base. Seule la résolution du rayon n'était pas couverte — le
      transfert lui-même, l'inertie du corps quitté et la sortie du pool le sont.
      **Validé** : le rayon résout bien le corps, donc `ALLY_LAYER` sur la
      variante minimale (bloqueur 1) est confirmé de bout en bout.
- [x] **`Tab`** fait tourner entre la Base et les 3 corps. **Validé** — ce qui
      confirme aussi que les 4 contrôlables sont dans le pool et que l'ordre des
      nœuds de la scène tient.
- [ ] **Lueur** : le corps quitté redevient faiblement lumineux, le nouveau
      s'allume (`idle_energy` 0.3 → `possessed_energy` 1.8). **Jugé en
      playtest** : pas nettement perceptible, mais **pas grave** — n'affecte
      pas la lisibilité du jeu, laissé tel quel.
- [x] **HUD du mage** : `Resources`, `A: bolt`, `E: flux`, et les 2 upgrades.
      **Aucune ligne `Z:`**. **Validé**.
- [x] **HUD de la Base** : plus que **3** upgrades (touches 1-3). Le slot de
      vague a disparu — il ne servait à rien ici. **Validé**.

### Questions d'équilibrage (à juger, pas à valider)

- [x] **Reset croisé A ↔ E** — alterner A, E, A, E n'attend plus *aucun*
      cooldown, et un cube marqué meurt d'un seul bolt. C'est un saut de
      puissance net, pas un ajustement. Trop fort ? Levier : `cross_spell_reset`
      dans l'inspecteur (A/B immédiat), ou un reset partiel. **Jugé OK en
      playtest**, gardé tel quel.
- [x] **Cooldowns −25 %** (bolt 0,9 s / flux 2,25 s / cage 3,75 s) — le rythme
      est-il bon, ou est-ce devenu trop permissif ? **Jugé OK en playtest**.
- [x] **Les corps en réserve sont mordables** — une vague peut décimer ton roster
      pendant que tu es à la Base. Tension voulue, mais potentiellement punitive.
      Porte de sortie déjà documentée : réduire les dégâts subis hors possession
      (le concept d'origine décrit ces corps comme « très résistants »). **Jugé
      OK en playtest**, la tension est acceptée telle quelle.
- [x] **Revenu du mage** — en mage, ton revenu ce sont *tes* kills, rien d'autre
      ne tue de cubes. La rotation E→A (un tir par cube) est-elle nécessaire à
      connaître, ou trop punitive si on l'ignore ? **Jugé OK en playtest**.

---

## Palier Micro — jalon 9.4 (relief)

Scène : `gameplay_loop/micro/micro_terrain.tscn`

Le blocage d'unité **est** mesuré (`micro_terrain_test` : 6 cubes traversent
piliers, portail, rocher et rampe ; 5/6 restaient plantés sans la correction).
Il ne reste donc que le visuel et le feel.

- [x] **Lisibilité du contournement** — une unité qui longe un obstacle le fait
      de façon crédible, sans tremblement ni demi-tour absurde. Le choix du côté
      est figé au premier contact, donc elle ne doit pas hésiter. **Validé**.
- [x] **La rampe** — sa boîte de collision est volontairement à moitié enterrée
      pour ne pas présenter de marche verticale. Vérifier que le rendu ne fait
      pas « bloc qui sort du sol » de façon moche, et que les cubes la montent
      et en redescendent proprement. **Validé**.
- [x] **Le feel de 9.1 ne régresse pas** avec le relief : rythme des vagues,
      danger perçu, tir de mortier. **Validé**.
- [x] **Le mortier** par-dessus le relief — les obstacles sont sur la couche 1 et
      le mortier ne masque que la couche 2, donc il *devrait* tirer par-dessus.
      À confirmer à l'œil : un obus qui traverse un pilier serait laid. **Validé**.
- [x] **Passage latéral du portail** — les blocs laissent 2,25 m de chaque côté.
      Est-ce que ça se lit comme un choix tactique, ou comme une erreur de
      level design ? **Validé, lu comme un choix tactique**.

---

## Non-régression ailleurs (la déflexion touche *tout* `FrontUnit`)

`obstacle_deflect_weight` s'applique à toute unité du jeu, pas seulement dans la
scène de relief. Les scènes plates ne devraient rien voir (les unités ne touchent
pas les murs), mais ça se vérifie.

- [ ] **`levels/level2_front.tscn`** — les unités poussent toujours vers la base
      adverse, assiègent la Tour, et ne longent pas ses murs au lieu de la
      frapper. (La Tour et les Bases sont explicitement exclues de la déflexion,
      mais c'est le point le plus à risque.)
- [ ] **`level2_front`, possession 8.2** — clic sur une unité alliée → elle
      devient un mage ; les **trois** sorts répondent (A, Z, E — c'est ici que Z
      doit encore marcher) ; quitter le mage le rend au front en `FrontUnit`.
- [ ] **`gameplay_loop/micro/micro_base_defense.tscn`** (9.1/9.2) — inchangé.
- [ ] **`levels/main.tscn`** (niveau 1) — inchangé. Rappel : pas d'économie dans
      cette scène, ses ennemis n'ont pas de `LootOnDeath`.

---

## Déjà validé manuellement

- [x] Jalon 9.1 — boucle de défense de Base, Game Over (playtest utilisateur)
- [x] Jalon 9.2 — achat et application des upgrades, D4 (playtest utilisateur)
- [x] Jalon 9.3 — possession du roster et sorts A/E confirmés en jeu
      (« ok pas mal ça marche »)

---

## Points ouverts connus (pas des bugs à vérifier)

- **Aucune escalade de difficulté** dans le palier Micro : la pression est
  constante, 2 cubes toutes les 6 s, plafonnée par `max_alive = 40`. Rien
  n'augmente avec le temps. L'escalade existante (`GameManager`, `4 + zone * 2`)
  ne pilote que `levels/main.tscn`. C'est le chantier suivant si la partie doit
  monter en tension — il n'est dans aucun jalon de la phase 9.
- **La déflexion d'obstacle est locale, pas du pathfinding.** Elle réagit au
  contact, sans anticiper. Une poche concave (cul-de-sac) peut encore piéger une
  unité : c'est le minimum local classique, et `NavigationAgent3D` reste hors
  scope (`PLAN.md`). Le relief de 9.4 évite volontairement ce cas.
