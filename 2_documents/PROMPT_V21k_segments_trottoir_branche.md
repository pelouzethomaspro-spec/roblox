# Demande pour la map V21k — segments de trottoir côté BRANCHE (entrée déplaçable)

Contexte (IA du jeu, Station Tycoon v51) : merci pour la V21j, les segments `Trottoir_PlotN_kk` du bord route du tour sont
intégrés (le jeu masque 2 segments, pose la traversée au ras de la chaussée et deux rampes de 6 studs aux bouts).

Depuis la v51, **l'ENTRÉE des clients n'est plus sur la route du tour : elle est sur le bord de la BRANCHE** (le grand côté
du plot, le long de la route qui vient du tunnel). Les voitures descendent la branche, font la queue dessus et tournent
dans le plot. Seule la **SORTIE** reste sur le bord de la route du tour (segments V21d existants). L'entrée est déplaçable
par le joueur le long de toute la branche, par pas de 15 studs (2 rangées = 30 studs d'ouverture).

## Ce qu'il faut

1. **Découper le trottoir du bord BRANCHE de chaque plot en 32 segments de 15 studs**, exactement comme ceux du bord
   route (V21d) :
   - noms : `Trottoir_PlotN_B_kk`, k = **00 à 31**, **en partant du coin de la route du tour** (k = 00 = le segment qui
     touche le coin du carrefour, k = 31 = celui qui touche la tête de tunnel), c'est-à-dire V = 480 − 15(k+1) … 480 − 15k
     dans le repère du plot (V mesuré depuis la bouche du tunnel) ;
   - chaque segment : 15 studs le long du bord, toute la largeur du trottoir (bordure + dalles, 15,9 studs), une texture par
     MeshPart (`…_B_kk`, `…_B_kk__Bordure`, `…_B_kk__DalleClaire`, `…_B_kk__DalleMoyenne`, `…_B_kk__Assise`) + sa Part de
     collision invisible nommée `Collision` ;
   - `InstallerMap` les range comme les autres : `Workspace.<map>.Voirie.TrottoirsPlots.PlotN.Trottoir_PlotN_B_kk` (un Model
     par segment, streaming Persistent) ;
   - extrémités ouvertes (coupe nette) comme pour le bord route : le jeu pose ses rampes contre les segments voisins ;
   - le **coin arrondi du carrefour** (jonction trottoir branche / trottoir route du tour) reste une pièce à part, non
     masquable (le jeu interdit l'entrée sur les 2 premières rangées et la sortie sur la colonne du coin) ;
   - le trottoir est **plein partout** (rien de creusé), la ligne de rive de la branche reste continue (le jeu la recouvre
     devant l'accès avec une plaque de bitume à Y = 0,58).

2. **Données** : dans `04_Donnees/plots_joueurs.json`, ajouter pour chaque plot `trottoir_segments_branche` sur le même
   modèle que `trottoir_segments` (nom, index, `v_studs` [v0, v1] depuis la bouche du tunnel, milieu du bord plot à Y = 1,27,
   milieu du bord chaussée à Y = 0,57, boîte X/Z). Garder `trottoir_segments` (bord route) tel quel.

3. **Collisions** : `DonneesCollisions.lua` : les collisions des nouveaux segments nommées `Trottoir_PlotN_B_kk` (rangées
   dans le Model du segment par InstallerMap, comme pour le bord route). Plus aucune entrée de plot figée.

4. Rien d'autre ne change : plots 270 × 480, repère, échelle (1 unité = 1 stud, Y en haut, centre (0,0,0)), noms de
   fichiers « V17 », PROMPT_TRANSFERT.md mis à jour (§ 4) et LISEZ_MOI.

## Pour vérifier de ton côté

- 8 plots × 32 segments = 256 Models `Trottoir_PlotN_B_kk` + les 8 × 18 du bord route ;
- Plot1 (type A, branche le long du bord X = 0 du plot) : `Trottoir_Plot1_B_00` touche le coin de la route du tour,
  `Trottoir_Plot1_B_31` touche la tête de tunnel ;
- le jeu masquera, pour une entrée aux rangées zE et zE+1 (zE ≥ 3), les segments k = zE − 1 et k = zE.
