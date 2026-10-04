# Prompt de transfert — réajuster la chaîne de production à l'échelle des voitures du jeu

> À coller tel quel à l'IA qui a construit la chaîne de production (`ChaineProduction_M4_3`, Blender → FBX). Le fichier `tailles_vehicules.csv` (joint) contient la table complète.

---

Bonjour. Tu as construit la **chaîne de production de voitures** de mon jeu Roblox « Station tycoon » (modèle `ChaineProduction_M4_3`, 451 × 136 × 61 studs, échelle 1, tapis de 17 studs, étages d'environ 20 studs, posé sur les 4 diagonales de la map). Elle a été dimensionnée autour d'une **M4 de 36 studs de long** (36 × 15,6 × 10,5). Depuis, nous avons fixé **l'échelle définitive des voitures du jeu**, et elle est plus petite : il faut **réajuster la chaîne** (robots, tapis, portiques, scanner, ascenseur, portails, hauteur des étages) pour qu'elle soit cohérente avec ces voitures. **Ne touche pas au bâtiment qui l'entoure ni à sa position sur la map** : c'est l'intérieur (la chaîne elle-même et tout ce qui manipule la voiture) qui doit être remis à l'échelle.

## 1. La règle d'échelle du jeu (définitive)

- Référence : **la BMW M4 (4,794 m réels) mesure 22 studs de long** dans le jeu.
- Coefficient : **1 m = 4,59 studs** (1 stud = 21,8 cm).
- Toutes les voitures gardent leurs **proportions réelles** : longueur en studs = longueur réelle en mètres × 4,59. Chaque modèle a donc une taille différente (une Clio est plus courte qu'une Urus).
- Le joueur mesure 6,48 studs de haut (avatar Roblox « grand »).

## 2. Tailles exactes des voitures qui passent sur la chaîne

Longueur × largeur × hauteur, en studs, telles qu'elles sont dans le jeu :

| Modèle | Vrai véhicule | Réel (m) | **En jeu (studs)** |
|---|---|---|---|
| **M4** (référence) | BMW M4 G82 | 4,79 × 1,89 × 1,39 | **22,0 × 9,5 × 6,5** |
| **Golf** | VW Golf VIII | 4,28 × 1,79 × 1,46 | **19,7 × 9,1 × 6,6** |
| **Urus** | Lamborghini Urus | 5,11 × 2,02 × 1,64 | **23,5 × 10,1 × 7,9** |

Les autres voitures du jeu, au cas où tu veuilles un gabarit complet : Clio 4 18,6 × 8,5 × 6,9 ; Golf 2 18,3 × 9,0 × 7,4 ; Volvo 240 22,0 × 7,8 × 7,0 ; Mercedes Classe C 21,5 × 9,0 × 5,8 ; Challenger 23,0 × 11,2 × 7,2 ; Classe G 22,1 × 8,9 × 9,0 ; 911 GT3 21,0 × 8,9 × 6,6 ; Ferrari 488 20,8 × 9,0 × 5,6 ; Follie 21,6 × 11,2 × 5,9.

**Gabarit maximal à prévoir sur la chaîne : 23,5 de long × 11,2 de large × 9,0 de haut** (Urus / Challenger / Classe G), avec une marge de manœuvre de 2 studs de chaque côté pour les robots.

## 3. Ce que ça veut dire pour la chaîne

- Aujourd'hui la chaîne est calée sur une voiture de **36 studs** ; la voiture réelle du jeu fait **22**. Le rapport est **22 / 36 = 0,611**. Une remise à l'échelle uniforme de tout l'intérieur (robots, tapis, scanner, ascenseur, portails, pièces posées par les robots, points d'attache `Voiture_0..6`) par **× 0,61** donne directement le bon résultat ; les hauteurs d'étage et de portiques peuvent rester un peu plus généreuses (par ex. × 0,7) si tu préfères garder du volume visuel, tant que la voiture de 23,5 × 11,2 × 9,0 passe partout avec 2 studs de marge.
- **Largeur du tapis** : la voiture la plus large fait 11,2 studs → tapis ≥ 13 studs (aujourd'hui 17 pour une voiture de 15,6 : même logique).
- **Portails / ascenseur / scanner** : ouverture ≥ 13 de large × 11 de haut.
- **Robots** : leur portée doit atteindre le toit d'une voiture de 6,5 à 9 studs de haut et ses flancs à ± 5,6 studs de l'axe, pas plus loin : sinon les bras passent « à travers » ou restent trop hauts.
- **Espacement des postes** : la voiture avance d'un poste par cycle de 20 s ; les postes doivent être espacés d'au moins la longueur de la voiture + 6 studs (≈ 30 studs) pour que deux voitures ne se touchent pas.
- Les **pièces posées par les robots** (pare-chocs, vitres, phares, feux, roues) doivent être à l'échelle des voitures ci-dessus : une roue de M4 fait ≈ 3,1 studs de diamètre (0,68 m × 4,59).

## 4. Ce qui ne change pas

- Le **bâtiment** (hall, façade arrondie `Avancee`, bâtiments industriels des côtés) et la **position** des 4 chaînes sur la map (`chaines_production.json` : centre du hall, rotation Y, échelle 1) restent tels quels. Si la chaîne réduite « flotte » dans un hall devenu trop grand, préfère baisser le sol / ajouter des passerelles plutôt que de rétrécir le hall.
- Les **noms des pièces** (`CP_P1_Tourelle`, `CP_P1_BrasHaut`, `CP_P1_AvantBras`, `CP_P1_Rotule`, `CP_P1_Poignet`, `CP_P1_Outil`… pour les 6 robots, `CP_Tapis`, `CP_Usine`, `Voiture_0..6`, scanner, ascenseur, portails) et la **hiérarchie des articulations** doivent rester identiques : le jeu recrée les Motor6D et rejoue les animations à partir de ces noms. Seules les positions / tailles changent.
- Les **animations** (14 KeyframeSequences déjà publiées) devront être ré-exportées si les positions des articulations bougent : fournis-moi le nouveau fichier de données des joints (comme `Donnees_ChaineProduction.lua` : nom, parent, type, position, axe) pour que je régénère le montage.

## 5. Ce que j'attends en retour

1. Le FBX de la chaîne réajustée (même repère, même origine que `ChaineProduction_M4_3`, échelle 1, un seul matériau par pièce comme avant).
2. La liste des joints mise à jour (nom / parent / pivot / axe, en studs).
3. Une image de la nouvelle chaîne avec une M4 de 22 studs posée sur le tapis, pour vérifier les proportions à l'œil.
