# Station Tycoon — économie de départ (v24)

## Ce que coûte un démarrage jouable

| Poste | Prix | Remarque |
|---|---|---|
| Sol (goudron / béton, ~20 à 30 cases) | 100 – 150 $ | 5 $ la case |
| Station « Lavage : place libre » (L1) | 600 $ | capacité 50 L, cycle 19 s |
| Caisse tapis | 800 $ | obligatoire pour encaisser |
| Pile de cartons (stockage +50 L) | 200 $ | sans elle, 50 L de base seulement |
| ~20 produits de lavage (produit 2 : 10 $, 3 L) | 200 $ | livrés par le camion (top toutes les minutes) |
| **Total** | **≈ 1 950 $** | |

Les employés sont gratuits à l'embauche mais coûtent en salaire : 12 $/min (station) + 7 $/min (caisse) = **19 $/min**.

## Ce que rapporte le début
Un client commun paie `Buy + (Sell − Buy) × Mult(rareté)` : produit 2 → 10 + 15 × 1 = **25 $** (Uncommon ×1,4 = 31 $, Rare ×2 = 40 $).
Cadence des clients : un toutes les 14 à 24 s → environ **75 $/min brut**, soit **≈ 55 $/min net** après salaires.
Première amélioration (Lavage aux seaux, 900 $) atteinte en ~15 min ; Karcher (2 500 $) vers 45 min ; les extensions
(3 000 / 8 000 / 25 000 $ puis 30 000 / 80 000 / 250 000 $) et les stations d'entretien (800 → 8 000 $) donnent la
progression longue. Les mutations (or ×3, argent ×2, électrique ×1,5) sont des bonus rares.

## Décision : argent de départ = 3 000 $
1 950 $ d'indispensable + ~1 000 $ de marge : de quoi payer les salaires des 10 premières minutes même si le joueur
tâtonne, refaire un plein de produits et éventuellement une deuxième pile de cartons, sans pouvoir sauter directement
à la station suivante (la progression garde son sens). Réglé dans `DataManager.lua` (`ProfileTemplate.Money`). Les
profils existants gardent leur solde.

## Points à surveiller (non modifiés)
* Le produit 1 (25 L) n'entre qu'à 2 exemplaires dans les 50 L de base : le produit 2 (3 L) est le bon produit de départ,
  l'UI Stock devrait le mettre en avant.
* L'embauche est gratuite : un joueur peut embaucher sans limite et se ruiner en salaires ; envisager un prix d'embauche
  (ex. 300 $) ou un plafond selon le rang.
