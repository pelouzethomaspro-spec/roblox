# Station tycoon — Échelle « M4 = 22 studs » : tout ce qu'il faut pour réajuster la map

*Dossier généré le 30/09/2026 (v41). Toutes les dimensions sont en studs Roblox, sauf mention « m ».*

## 1. La règle d'échelle (celle qui est codée dans le jeu)

- Référence choisie : **la BMW M4 (4,794 m réels) fait 22 studs**.
- Coefficient : **1 m = 4,59 studs** — **1 stud = 21,8 cm**.
- Chaque véhicule garde ses **proportions réelles** : longueur en studs = longueur réelle (m) × 4,59.
- Où c'est codé : `ReplicatedStorage > Catalogue > Car` (`Car.LONGUEUR_M4 = 22`, table `Car.LongueursM` en mètres, fonction `Car.Longueur(nom)`). Copie du script dans ce dossier (`Car.lua`). Pour changer l'échelle de TOUTES les voitures, il n'y a qu'un nombre à modifier : `LONGUEUR_M4`.
- Au démarrage du serveur, `CarManager` remet les 12 modèles de `ReplicatedStorage > VoituresModeles` à leur longueur ; les voitures clientes, les stations (qui mesurent la voiture qu'elles reçoivent) et la chaîne (échelle relative) suivent automatiquement.

### Le joueur dans cette échelle

- Ton personnage mesuré en jeu (Play, `GetBoundingBox` sans les cheveux) : **6,48 studs** de haut (avatar « grand », BodyTypeScale = 1). Un avatar Roblox classique fait ~5 studs.
- Dans l'échelle des voitures, 6,48 studs = **1,41 m** : les voitures paraissent ~24 % plus grandes que dans la réalité par rapport au joueur (une M4 « réaliste » pour ton perso ferait 17,8 studs). C'est le rendu que tu as validé sur les images (`renders/`).
- Conséquence pour la map : **tout ce qui est à l'échelle des voitures (routes, parkings, portes de garage) se calcule avec 4,59 studs/m ; tout ce qui est à l'échelle du joueur (portes piétons, marches, mains courantes) peut rester un peu plus petit.** Les valeurs actuelles de la map V17m sont déjà très proches de 4,59 studs/m (voir § 4).

## 2. Tailles des véhicules (fichier `tailles_vehicules.csv` / `.json`)

| Modèle (jeu) | Vrai véhicule | Réel L × l × h (m) | **En jeu L × l × h (studs)** | Avant |
|---|---|---|---|---|
| M4 | BMW M4 (G82) | 4,79 × 1,89 × 1,39 | **22,0 × 9,5 × 6,5** | 16 |
| Clio4 | Renault Clio IV | 4,06 × 1,73 × 1,45 | **18,6 × 8,5 × 6,9** | 16 |
| Golf2 | VW Golf II | 3,99 × 1,67 × 1,42 | **18,3 × 9,0 × 7,4** | 16 |
| Golf | VW Golf VIII | 4,28 × 1,79 × 1,46 | **19,7 × 9,1 × 6,6** | 16 |
| Volvo240 | Volvo 240 | 4,79 × 1,71 × 1,44 | **22,0 × 7,8 × 7,0** | 16 |
| Mercedes | Classe C (W205) | 4,69 × 1,81 × 1,44 | **21,5 × 9,0 × 5,8** | 16 |
| Dodge | Challenger | 5,02 × 1,92 × 1,45 | **23,0 × 11,2 × 7,2** | 16 |
| ClassG | Classe G (W463) | 4,82 × 1,93 × 1,97 | **22,1 × 8,9 × 9,0** | 16 |
| GT3 | Porsche 911 GT3 | 4,57 × 1,85 × 1,28 | **21,0 × 8,9 × 6,6** | 16 |
| Urus | Lamborghini Urus | 5,11 × 2,02 × 1,64 | **23,5 × 10,1 × 7,9** | 16 |
| F448 | Ferrari 488 | 4,53 × 1,95 × 1,21 | **20,8 × 9,0 × 5,6** | 16 |
| Follie | à confirmer | 4,70 × 1,90 × 1,30 | **21,6 × 11,2 × 5,9** | 16 |
| Fourgon (livraison) | Sprinter L2 | 5,93 × 2,02 × 2,70 | **27,2 × 9,3 × 12,4** | 20 |
| Voiture sur la chaîne de production | (M4 / Golf / Urus × 1,64) | — | **36 de long** (inchangé, gabarit des robots) | 36 |

Largeur et hauteur « en jeu » = celles des modèles 3D actuels remis à l'échelle (les modèles ne sont pas tous fidèles : le Challenger et la Follie sont larges de 11,2 studs, la Classe C est basse). Les deux modèles marqués ClassG et F448 sont calculés d'après les dimensions réelles.

**Gabarit à retenir pour la map** : la plus longue voiture cliente fait **23,5** (Urus), la plus large **11,2** (Challenger), la plus haute **9,0** (Classe G) ; le fourgon **27,2 × 9,3 × 12,4**.

## 3. Ce que ça change concrètement (déjà fait dans la v41)

- Espacement des voitures qui attendent sur la route du tour : 22 → **30 studs** (`CarManager.ESPACE_ATTENTE`).
- Longueur du fourgon : 20 → 27,2 (`Livraison`, via `Car.Longueur("Fourgon")`).
- Chaîne de production : `ECHELLE_VOITURE = 36 / 22` pour garder les voitures de la chaîne à 36 studs.
- Reste à faire côté jeu (v42) : file d'attente dans le tunnel (`ESPACE_FILE` 22 → 30 dans `gen_map`), et vérifier les 3 stations à animation quand une voiture large (Challenger) passe.

## 4. La map V17m relue avec 4,59 studs/m (fichier `conversion_reel_studs.csv`)

| Élément de la map | Studs | Équivalent réel | Verdict |
|---|---|---|---|
| Voie de circulation | 15 | 3,27 m | OK (réel 3–3,5 m) |
| Chaussée 2 voies | 30 | 6,5 m | OK |
| Trottoir V17m | 10,85 | 2,36 m | OK |
| Rond-point central (rayon ext.) | 172,9 | 37,7 m | OK, grand rond-point |
| Anneau des ronds-points | 30 | 6,5 m | OK |
| Map entière | 2 697 | 588 m de côté | — |
| Bouche de tunnel | à 1 200,5 du centre | 262 m | — |
| Plot | 350 × 550 | 76 × 120 m (0,9 ha) | — |
| Case du plot | 10 | 2,18 m | **étroit** : une voie de 10 studs pour des voitures de 8,5 à 11,2 de large |
| Route interne du plot (2 cases) | 20 | 4,36 m pour 2 sens | **serré** : réel 5,5–6 m |
| Station 3 × 3 | 30 | 6,5 m | OK : 3,2 studs de marge autour de l'Urus |
| Entrée / sortie du plot (3 cases) | 30 | 6,5 m | OK pour le fourgon |

**La voirie de la map est déjà à la bonne échelle** : avec 22 studs, les voitures tiennent dans les voies de 15 comme des vraies voitures sur une vraie route. Ce qui devient serré, c'est **l'intérieur des plots** (cases de 10).

## 5. Points à réajuster sur la map (par ordre d'importance)

1. **Routes internes des plots** : soit tu acceptes que deux voitures se frôlent (20 studs pour 2 sens, l'équivalent d'une ruelle), soit on passe la route du plot à **3 cases (30 studs)** ou on garde 2 cases mais **en sens unique** (une seule voie de 20 : très confortable). Décision à prendre ensemble : ça touche `Circulation` (couloirs de 2 cases) et le plan `plan_plot_echelle_22.png` montre les deux cas à l'échelle.
2. **Virages à 90° dans le plot** : une voiture de 23,5 pivote sur le centre des cases → elle déborde d'environ **7 studs** sur la case voisine (herbe / dalle) au moment du virage. Prévoir soit des cases « coin » sans décor, soit un arrondi (le code peut faire un arc de cercle : rayon 10 minimum).
3. **Tunnels (bouches de 148 studs de large)** : hauteur libre à vérifier ≥ **14 studs** pour le fourgon (12,4 de haut) + marge. Idem tout passage sous bâtiment / portique sur le trajet du fourgon (avenue, rond-point, branche).
4. **Portes de garage / stations avec bâtiment** : ouverture **≥ 12 de large × 10 de haut** pour les voitures (Classe G : 9,0 de haut, Challenger : 11,2 de large) ; **≥ 11 × 14** si le fourgon doit entrer.
5. **Places de parking dessinées (marquage)** : 2,5 × 5 m réels = **11,5 × 23 studs** ; prévoir **12 × 25** pour l'Urus.
6. **File d'attente devant le plot** (route du tour et branche) : 30 studs entre deux voitures ; pour 4 voitures en attente il faut **~120 studs** de route libre avant le carrefour (aujourd'hui `RECUL_ATTENTE = 65` puis file dans le tunnel).
7. **Chaîne de production** : ses voitures font 36 (7,8 m) = 1,64 × la même voiture en jeu. Si tu veux les accorder, la chaîne entière (robots, tapis, scanner) doit être réduite à **0,61** de sa taille (ou les voitures gardées à 36 comme « maquettes géantes », ce qui se voit peu de loin).
8. **Éléments piétons** (portes de bâtiments, marches, rambardes) : le joueur fait 6,5 studs → porte **≥ 9,5 de haut**, marche **≤ 0,8**, hauteur d'étage **13,8** (3 m) pour que les façades restent cohérentes avec les voitures.

## 6. Vitesses (pour caler les animations / la caméra)

| | studs/s | m/s | km/h |
|---|---|---|---|
| Route (`VITESSE_ROUTE`) | 32 | 7,0 | 25 |
| Approche du plot | 18 | 3,9 | 14 |
| Ligne droite dans le plot | 11 | 2,4 | 8,6 |
| Virage dans le plot | 6,5 | 1,4 | 5,1 |
| Marche du joueur (défaut Roblox) | 16 | 3,5 | 12,6 |

Une vraie limitation urbaine (50 km/h) ferait 64 studs/s : les voitures roulent volontairement « lentement » (25 km/h) pour la lisibilité.

## 7. Ta décision : chaussée à 30 studs par côté (60 au total) — impact côté jeu

Avec 30 studs par sens, chaque sens peut avoir **2 voies de 15** (3,27 m chacune) ou **1 voie large de 30** (6,5 m). Pour que je recale la circulation quand tu livres la nouvelle map, il me faut, comme pour la V17m :

- le **`plots_joueurs.json` régénéré** (origine, axes, bouche du tunnel, angle branche / route du tour, entrée / sortie) — ce sont ces points qui déplacent les plots et les trajets ;
- la **largeur exacte de la chaussée et du trottoir** et, si tu fais 2 voies par sens, **quelle voie les voitures clientes doivent prendre** (aujourd'hui : voie de gauche, centre de chaussée + 7,5 ; avec 60 de large ce sera + 7,5 ou + 22,5 selon la voie) ;
- la **position des axes** (rond-point central, avenues, ronds-points extérieurs à 620, route du tour, branches à ±190) s'ils bougent — sinon je garde ceux de la V17 ;
- si les tunnels s'élargissent aussi : largeur / hauteur de la bouche.

Côté code, ce qui dépend de la largeur de chaussée : `map/routes.py` (`VOIE = 7.5`, suivi du centre de chaussée sur l'image de bitume), `gen_map.py` (`TROTTOIR`, `u_bord`, tabliers d'accès de 20 de long), les collisions (`DonneesCollisions`) et l'herbe (`InstallerHerbe`). Rien à changer dans `Circulation` (intérieur du plot) ni dans `Car` (tailles) : la chaussée plus large ne change que les trajets sur la map.

Recommandation : avec 22 studs de voiture, **30 par sens = 2 voies de 15** est la version la plus réaliste (boulevard) ; garde les **trottoirs à 10,85** (2,4 m) et les **carrefours branche / route du tour à angle droit**, mon code s'y attend.

## 8. Contenu du dossier

- `LISEZMOI_Echelle_22_studs.md` / `.html` — ce document.
- `tailles_vehicules.csv` / `.json` — la table des 13 véhicules (réel + studs).
- `conversion_reel_studs.csv` — les conversions map ↔ réel et les gabarits recommandés.
- `plan_plot_echelle_22.png` — coin de plot vu de dessus, à l'échelle, avec les nouvelles voitures.
- `renders/` — les 5 rendus en jeu (M4 16 / 20 / 22 / 24 studs et les autres voitures à l'échelle réelle à côté de ton perso).
- `Car.lua` — le script qui porte la règle (copie de `ReplicatedStorage > Catalogue > Car`).
- `plots_joueurs.json` — rappel de la géométrie exacte des 8 plots (V17m, trottoirs 10,85).
