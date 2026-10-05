# Station Tycoon — économie v56 (équilibrage de l'espérance de gain)

Rédigé le 05/10/2026 à partir d'une simulation (`3_pipeline/economie/simulation.py`, valeurs dans `valeurs_v56.json`).
Lancer `python3 simulation.py v55` puis `v56` pour comparer. Tout est réglable dans les catalogues : rien n'est codé en dur.

## 1. Le constat sur la v55

* **La cadence des clients est par plot, pas par station.** Au rang Bronze un client toutes les ~20 s = 3 voitures/min,
  quel que soit le nombre de stations. Toutes les stations rapportaient la même chose par voiture (`Mult` de station jamais
  défini → 1), donc acheter une Cabine de peinture à 8 000 $ ne changeait **rien** au revenu : la station la plus chère
  avait même le cycle le plus long (69 s).
* **Revenu de départ ~39 $/min net** : 1 h 30 de jeu pour le Karcher, 5 h 50 pour Platine, 20 h pour Diamant, **83 h pour
  Maître et 389 h pour Légende** (voir tableau). La voiture Divine exigée pour Maître (0,02 % de chances) pouvait bloquer
  un joueur des heures.
* Embauche gratuite : rien n'empêchait d'embaucher 20 employés et de se ruiner en salaires.
* L'onglet « Ma station » et l'agent d'entretien n'existaient pas : aucune raison de soigner sa station au-delà du décor.

## 2. Les règles v56 (ce qui est codé)

Gain d'une voiture = `Buy + (Sell − Buy) × Mult(rareté) × Mult(station) × pourboire(note) × bonus mutation (× 2 avec le
Game Pass ArgentX2)`. XP = 50 × Mult(rareté), inchangé.

Cadence entre deux clients = `Spawn(rang) × (0,8 … 1,3) ÷ [ pub (1 … 2) × déco (0,85 … 1,5) × attractivité × note ]`,
jamais moins de 4 s.

| Levier | Valeur v56 | Où |
|---|---|---|
| Mult des stations | L1 1,0 · L2 1,2 · L3 1,5 · L4 1,8 · E1 1,0 · E2 1,2 · E3 1,4 · E4 1,8 · E5 1,5 · E6 2,0 · E7 1,6 | `Catalogue/Furniture` (champ `Mult`) |
| Attractivité | +10 % de clients par station au-delà de la première, × 1,8 au plus (9 stations) | `CarManager.ATTRACTIVITE_*` |
| Produits 1 et 2 | Sell 25 → 30 (marge 20 $ par lavage de base) | `Catalogue/Consommable` |
| Notes de la station | pourboire × 0,85 … 1,30 et clients × 0,90 … 1,15 selon la note globale | `Notes.REGLAGES` |
| Embauche payante | Employé 300 $, Caissier 200 $, Logisticien 300 $, Agent d'entretien 250 $ ; salaires 12 / 7 / 10 / 8 $/min | `WorkerManager.PRIX_EMBAUCHE` |
| Extensions | 3 000 / 8 000 / 20 000 puis 40 000 / 90 000 / 180 000 $ | `Catalogue/Extension` |
| Rangs | XP 0 / 4 000 / 20 000 / 80 000 / 300 000 / 1,2 M / 5 M ; cadences 18 / 15 / 12,5 / 10 / 8,5 / 7 / 6 s ; critères adoucis, plus de Divine exigée avant Légende (2 Divines) | `Catalogue/Rank` |
| Verrou de rang | L3, E2 : Argent · L4, E3, E4, caisse automatique : Or · E5, E7 : Platine · E6 : Diamant · panneaux pub : Bronze → Maître | champ `Rang` de `Catalogue/Furniture`, listes `Debloque` de `Rank` |
| Panneaux pub | inchangés (500 → 25 000 $, +4 % → +24 % de clients, total × 2) | `Catalogue/Furniture` |

### Les quatre notes (onglet Ma station, module `Notes`)

| Note | Calcul | Comment la monter |
|---|---|---|
| Propreté | 100 au départ, −2,5 par voiture servie ; un agent d'entretien rend +0,6/s (2 agents max) ; sans agent, invite **E « Nettoyer la station »** sur une station dès 70 (+30 par nettoyage) | embaucher un agent (250 $ + 8 $/min) ou nettoyer soi-même |
| Rapidité | attente moyenne des 12 derniers clients (arrivée → début du service, trajet de ~25 s déduit) : 0 s = 100, 60 s = 0 | assez de stations, du stock, des employés |
| Accueil | 60 % part des stations avec employé (ou automatiques) + 40 % part des caisses avec employé ; 0 sans caisse | affecter les employés, caisses automatiques |
| Décoration | score du mode Décoration ramené à 0..100 (50 = neutre, +2/+1 par plante ou barrière proche, −3/−2/−1 autour des stations et du stockage) | plantes, barrières, panneaux entre les stations |

Note globale = moyenne. Elle est affichée en étoiles (une par tranche de 20) avec le pourboire et le multiplicateur de
clients résultants. Les valeurs sont posées en attributs du joueur (`NoteGlobale`, `NoteProprete`…) toutes les 5 s.

## 3. Ce que donne la simulation

Hypothèses : un joueur « raisonnable » achète la station suivante dès qu'il a le prix + 300 $ de réserve (ordre L1, L2, E1,
L3, E3, L4, E4, E7, E5, E6), un employé par station manuelle, un caissier pour 3 stations, aucun temps mort. Les verrous de
rang ne sont pas simulés (ils retardent un peu E3/L4/E4 et E5/E7, voir § 5).

### v55 (avant)
```
Rang      cadence  voit/min  Mult moy  $/voiture(L1,net)  XP/min(L1 sature)
Bronze      19.9s     3.01    1.155        17.3 $                174
Argent      16.8s     3.57    1.304        19.6 $                233
Or          13.7s     4.40    1.483        22.2 $                326
Platine     11.0s     5.44    1.709        25.6 $                465
Diamant      8.9s     6.72    1.976        29.6 $                664
Maitre       7.4s     8.16    2.267        34.0 $                925
Legende      6.3s     9.52    2.620        39.3 $               1248

--- Progression (sans pub, deco neutre, note moyenne) ---
     29.0 min (  0.5 h)  RANG Argent
     33.0 min (  0.6 h)  ACHAT E1_Base (reste 317 $, 39 $/min net)
     92.0 min (  1.5 h)  ACHAT L3_Karcher (reste 317 $, 42 $/min net)
    115.0 min (  1.9 h)  RANG Or
    133.5 min (  2.2 h)  ACHAT E3_Pompes (reste 300 $, 66 $/min net)
    189.5 min (  3.2 h)  ACHAT L4_Rouleaux (reste 311 $, 72 $/min net)
    241.0 min (  4.0 h)  ACHAT E4_Bornes (reste 308 $, 68 $/min net)
    332.0 min (  5.5 h)  ACHAT E7_Teinte (reste 329 $, 66 $/min net)
    345.0 min (  5.8 h)  RANG Platine
    372.0 min (  6.2 h)  ACHAT E5_Pneus (reste 361 $, 147 $/min net)
    413.5 min (  6.9 h)  ACHAT E6_Peinture (reste 352 $, 193 $/min net)
   1205.5 min ( 20.1 h)  RANG Diamant
   4969.5 min ( 82.8 h)  RANG Maitre
  23342.0 min (389.0 h)  RANG Legende
  Passages de rang (heures de jeu) : {'Argent': 0.5, 'Or': 1.9, 'Platine': 5.8, 'Diamant': 20.1, 'Maitre': 82.8, 'Legende': 389.0}

--- Progression (pub max, deco max, note parfaite) ---
     10.0 min (  0.2 h)  ACHAT E1_Base (reste 334 $, 78 $/min net)
     13.0 min (  0.2 h)  RANG Argent
     24.5 min (  0.4 h)  ACHAT L3_Karcher (reste 388 $, 183 $/min net)
     34.5 min (  0.6 h)  ACHAT E3_Pompes (reste 377 $, 199 $/min net)
     43.0 min (  0.7 h)  RANG Or
     49.0 min (  0.8 h)  ACHAT L4_Rouleaux (reste 318 $, 339 $/min net)
     60.0 min (  1.0 h)  ACHAT E4_Bornes (reste 423 $, 328 $/min net)
     77.5 min (  1.3 h)  ACHAT E7_Teinte (reste 312 $, 337 $/min net)
     90.5 min (  1.5 h)  ACHAT E5_Pneus (reste 312 $, 385 $/min net)
    107.5 min (  1.8 h)  ACHAT E6_Peinture (reste 489 $, 481 $/min net)
    119.5 min (  2.0 h)  RANG Platine
    432.0 min (  7.2 h)  RANG Diamant
   2119.0 min ( 35.3 h)  RANG Maitre
  12117.5 min (202.0 h)  RANG Legende
  Passages de rang (heures de jeu) : {'Argent': 0.2, 'Or': 0.7, 'Platine': 2.0, 'Diamant': 7.2, 'Maitre': 35.3, 'Legende': 202.0}
```

### v56 (après)
```
Rang      cadence  voit/min  Mult moy  $/voiture(L1,net)  XP/min(L1 sature)
Bronze      18.4s     3.25    1.155        18.6 $                188
Argent      15.4s     3.90    1.304        21.0 $                255
Or          12.8s     4.69    1.483        23.9 $                347
Platine     10.2s     5.86    1.709        27.6 $                500
Diamant      8.7s     6.89    1.976        31.9 $                681
Maitre       7.2s     8.37    2.267        36.6 $                948
Legende      6.1s     9.76    2.620        42.3 $               1279

--- Progression (sans pub, deco neutre, note moyenne) ---
      4.5 min (  0.1 h)  ACHAT L2_Seaux (reste 17 $, 59 $/min net)
     20.0 min (  0.3 h)  RANG Argent
     20.5 min (  0.3 h)  ACHAT E1_Base (reste 3 $, 101 $/min net)
     46.5 min (  0.8 h)  ACHAT L3_Karcher (reste 313 $, 108 $/min net)
     63.0 min (  1.1 h)  ACHAT E3_Pompes (reste 15 $, 121 $/min net)
     70.0 min (  1.2 h)  RANG Or
     84.0 min (  1.4 h)  ACHAT L4_Rouleaux (reste 319 $, 231 $/min net)
     97.5 min (  1.6 h)  ACHAT E4_Bornes (reste 345 $, 261 $/min net)
    117.5 min (  2.0 h)  ACHAT E7_Teinte (reste 343 $, 300 $/min net)
    131.0 min (  2.2 h)  ACHAT E5_Pneus (reste 418 $, 376 $/min net)
    147.0 min (  2.5 h)  ACHAT E6_Peinture (reste 437 $, 501 $/min net)
    174.5 min (  2.9 h)  RANG Platine
    418.5 min (  7.0 h)  RANG Diamant
   1153.0 min ( 19.2 h)  RANG Maitre
   3388.0 min ( 56.5 h)  RANG Legende
  Passages de rang (heures de jeu) : {'Argent': 0.3, 'Or': 1.2, 'Platine': 2.9, 'Diamant': 7.0, 'Maitre': 19.2, 'Legende': 56.5}

--- Progression (pub max, deco max, note parfaite) ---
      3.5 min (  0.1 h)  ACHAT L2_Seaux (reste 15 $, 76 $/min net)
     10.0 min (  0.2 h)  ACHAT E1_Base (reste 70 $, 178 $/min net)
     12.0 min (  0.2 h)  RANG Argent
     19.0 min (  0.3 h)  ACHAT L3_Karcher (reste 422 $, 326 $/min net)
     24.0 min (  0.4 h)  ACHAT E3_Pompes (reste 159 $, 407 $/min net)
     31.0 min (  0.5 h)  ACHAT L4_Rouleaux (reste 500 $, 620 $/min net)
     32.5 min (  0.5 h)  RANG Or
     35.5 min (  0.6 h)  ACHAT E4_Bornes (reste 324 $, 772 $/min net)
     43.0 min (  0.7 h)  ACHAT E7_Teinte (reste 500 $, 823 $/min net)
     48.5 min (  0.8 h)  ACHAT E5_Pneus (reste 693 $, 944 $/min net)
     55.5 min (  0.9 h)  ACHAT E6_Peinture (reste 795 $, 1157 $/min net)
     86.5 min (  1.4 h)  RANG Platine
    258.5 min (  4.3 h)  RANG Diamant
    865.5 min ( 14.4 h)  RANG Maitre
   3100.5 min ( 51.7 h)  RANG Legende
  Passages de rang (heures de jeu) : {'Argent': 0.2, 'Or': 0.5, 'Platine': 1.4, 'Diamant': 4.3, 'Maitre': 14.4, 'Legende': 51.7}
```

Lecture : en v56 un joueur normal (sans panneau ni déco) finit ses 11 stations en ~2 h 30 et touche ~500 $/min, Platine à
~3 h, Diamant à ~7 h, Maître à ~19 h, Légende à ~56 h ; avec panneaux, décoration et note parfaite, tout va ~1,5 à 2 fois
plus vite. Chaque station se rembourse en 10 à 25 minutes de jeu. La cadence plancher (4 s) et la capacité des stations
(1 voiture par cycle) bornent le revenu : impossible d'exploser l'économie avec les seuls multiplicateurs.

## 4. Choix faits par défaut (à valider)

1. Les notes pèsent **± 15 % sur la cadence et −15 % / +30 % sur le gain** : assez pour compter, pas assez pour punir un
   débutant (note neutre ≈ 55 → pourboire × 1,10).
2. L'agent d'entretien n'a pas de poste : il se promène de station en station (téléporté toutes les 20 s) ; pas d'animation
   de nettoyage pour l'instant.
3. Le Game Pass **ArgentX2** est le seul pass branché (× 2 sur les gains) ; VIP, Livraison express et Employés auto ont
   leur identifiant dans `Catalogue/Boutique` mais aucun effet encore.
4. Les prix des stations ne changent pas ; c'est le `Mult` qui les différencie.
5. Le remboursement d'une station à la destruction reste intégral (comme avant).

## 5. À surveiller en jeu

* Si la montée Bronze → Argent paraît lente, baisser `Rank[2].Xp` (4 000) ou monter `Sell` du produit 2.
* Les verrous de rang : E3 (Or) arrive en simulation vers 1 h 05 alors que le rang Or tombe vers 1 h 10 ; E5/E7 (Platine)
  vers 2 h 10 pour un rang à 2 h 55. Le joueur attend donc quelques minutes avec de l'argent en poche : voulu (le rang a un
  sens), mais si c'est frustrant, descendre E3 à Argent et E5/E7 à Or.
* Si la Rapidité reste basse même avec une bonne station, augmenter `Notes.REGLAGES.ATTENTE_REF` (60 s) ou le trajet déduit (25 s).
* Les cadences aux hauts rangs (6–7 s divisés par jusqu'à × 4) atteignent le plancher de 4 s : la file de la branche a
  autant de places que de nœuds `QueueNodes` ; si elle déborde, remonter `CarManager.CADENCE_PLANCHER`.
