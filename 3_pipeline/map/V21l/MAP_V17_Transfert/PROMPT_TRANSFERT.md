# PROMPT DE TRANSFERT — MAP V21 du jeu de Thomas

> À donner tel quel à l'IA qui développe le jeu. Tout ce dossier (`MAP_V17_Transfert`) l'accompagne.
> **V21l (03/10)** : comme la V21k, la **sortie peut être placée tout le long du trottoir de la route du tour, au-delà du bout du plot** : 16 segments de plus par plot (`Trottoir_PlotN_18` à `_33`, fin du virage puis diagonale), § 4. **V21k (03/10)** : comme la V21j, plus le **trottoir du bord BRANCHE découpé en 32 segments de 15 studs** par plot (`Trottoir_PlotN_B_00` à `_B_31`) pour l'**entrée déplaçable** du jeu v51 (§ 4) ; la sortie reste sur les segments du bord route (V21d). **V21j (02/10)** : comme la V21i, plus de panneaux bleus et blancs au-dessus des rangées ; le bras du robot de stock a un préhenseur à ventouses et fait un aller-retour simple zone A ↔ zone B en boucle. **V21i (02/10)** : comme la V21h, plus un **robot automatique de gestion du stock** au plafond de chaque hangar (§ 5 bis, Script `RobotStock`). **V21h (02/10)** : comme la V21g, hangar moins lumineux (murs et sol plus gris, plafond gris, dalles LED Neon atténuées, PointLights à 0,8). **V21g (02/10)** : comme la V21e, hangar retravaillé (§ 5 bis) : vraies fenêtres à l'étage qui donnent sur le hangar, charpente carrée avec dalles LED, poteaux et protections refaits, plus de chariot élévateur ni de transpalette, beaucoup de détails, bureau vitré façon chaîne M4 en vrai verre. **V21e (02/10)** : comme la V21d, plus le grand hangar de stockage intérieur derrière les quais (§ 5 bis). **V21d (01/10)** : comme la V21, plus le trottoir des bords de plots découpé en segments de 15 studs (entrée / sortie déplaçables, § 4). **V21** : les noms de fichiers restent en « V17 » pour ne rien casser, mais le contenu est la version **V21** (voir § 0).

---

Bonjour. Voici **la map définitive (V21)** de mon jeu Roblox. Elle a été construite entièrement par script (Blender → FBX) avec une autre IA. Ton rôle : l'intégrer dans le jeu (plots des joueurs, arrivée des voitures, chaînes de production…) **sans la remodeler**. Toutes les dimensions ci-dessous sont en **studs**, dans le repère Roblox, **centre de la map = (0, 0, 0)** tel qu'exporté (l'import Studio peut décaler la map : le script `InstallerMap` recale tout, voir § 6).

## 0. Nouveautés V21 : nouvelle chaîne `ChaineProduction_M4_9`, map resserrée, sorties des ronds-points vers les cours de livraison

La chaîne de production a été **réduite en largeur et en longueur** (`ChaineProduction_M4_9` : **275,6 × 83,2 studs**, ~62 de haut, contre 451 × 136 pour la M4_3). Décisions de Thomas :
- la map est **réduite en proportion** autour de la nouvelle chaîne ;
- les **bâtiments industriels autour des chaînes gardent leur taille** (largeur, profondeur, hauteur) : ils avancent simplement le long de la chaîne, plus près du centre ;
- le **rond-point central rétrécit** un peu (chaîne plus étroite) ; seul le centre change de forme, les ronds-points extérieurs, les tunnels, la voirie (2 × 25 studs) et les garages sont inchangés ;
- les **plots des joueurs rétrécissent** avec la map ;
- (dessin rouge / vert de Thomas) **les plates de livraison (cours des garages) ne bougent pas** : toute la partie extérieure de la map (ronds-points extérieurs, route du tour, plots, tunnels) **se rapproche** jusqu'à ce que le trottoir de chaque rond-point extérieur **touche les deux cours de livraison** voisines ;
- **une entrée sur chaque rond-point extérieur, de chaque côté de l'avenue, mène directement dans la plate de livraison** (8 entrées : trottoir de l'anneau coupé net à angle droit ; la plate de goudron est prolongée jusqu'au prolongement du pignon des bureaux et jusqu'au trottoir du rond-point ; le trottoir de l'avenue et son arrondi restent comme avant). Elle **remplace la bretelle en biais** qui partait de l'avenue (supprimée : le trottoir de l'avenue est de nouveau continu).

La map passe de 2 657,4 à **2 369,4 studs de côté** (−11 %).

| Donnée | V20 | **V21** |
|---|---|---|
| Chaîne | M4_3, 451 × 136 | **M4_9, 275,6 × 83,2** (échelle 1), portail 29,6 × 15,5, meneaux tous les 5,5 studs |
| Centre des chaînes (`CP_Hall`) | ±309,4 | **±235,9** (X et Z) |
| Map | 2 657,4 (demi 1 328,7) | **2 369,4** (demi **1 184,7**) |
| Rond-point central | chaussée rayon ext. 192,9, îlot 142,9 | **chaussée rayon ext. 177,9, îlot 127,9** (dont trottoir 15,9) |
| Monument | plateaux tournants de 56 studs | tour, bassin et jets inchangés, **plateaux tournants de 34 studs** (îlot plus petit) |
| Ronds-points extérieurs | centrés à 620 | **centrés à 516** (rayon 110,5 et îlot 60,5 inchangés), trottoir collé aux cours de livraison |
| Accès aux cours des garages | bretelle en biais depuis l'avenue | **entrée par le rond-point extérieur** : trottoir de l'anneau **coupé net** (bouts à angle droit, sans rampe) entre la fin de l'arrondi avenue / anneau (26°) et 45° de l'axe de l'avenue : ~37 studs le long de la bordure, ~42 au bord extérieur, au niveau de la chaussée (Y = 0,57) |
| Hangar (V21e) | — | **grand hangar de stockage blanc** derrière les quais (3 portes sur 4 ouvertes) : racks, charpente carrée + dalles LED, bureau vitré façon M4, vraies fenêtres à l'étage, entrée du personnel (§ 5 bis) |
| Quais (V21) | parking contre les bureaux | **4 quais de déchargement** : façade des bureaux reculée de 10 studs, quai ouvert à 5,5 studs, portes 13 × 13, auvent, camion et fourgon à quai (§ 5 bis) |
| Plate de livraison | jusqu'au trottoir de l'avenue | **prolongée** jusqu'au prolongement du pignon des bureaux et jusqu'au trottoir du rond-point (bordure haute le long du trottoir, sauf à l'entrée) ; herbe au-delà ; bout côté centre **carré** (perpendiculaire au trottoir) |
| Route du tour | ±620 | **±516** |
| Branches des tunnels | ±190 | **±174,7** de l'axe de chaque avenue |
| Bouche des tunnels | 1 180,9 | **1 036,9** du centre ; **tunnels ajustés au trottoir** : piédroits pile sur le bord extérieur des trottoirs, passage **81,2 studs** de large (= chaussée 50 + 2 trottoirs de 15,9) × ~65 de haut, têtes de 147,8 × ~128 × ~78 |
| Plots | 35 × 52 cases, 1 792 valides | **27 × 48 cases** de 10 studs, **1 262 valides** (34 exclues) |
| Entrée / sortie | i = 2–6 / 17–21 creusées | **déplaçables** : rien de creusé. **Sortie** (V21d / V21l) : trottoir du bord route découpé en **34 segments de 15 studs** par plot : `Trottoir_PlotN_00` à `_17` le long du plot, puis `_18` à `_33` au-delà du bout du plot (fin du virage et diagonale de la route du tour). **Entrée** (V21k, jeu v51) : trottoir du bord **branche** découpé en **32 segments de 15 studs** (`Trottoir_PlotN_B_00` au coin du carrefour à `_B_31` contre la tête de tunnel). Le jeu masque les segments choisis et pose la traversée + les rampes (§ 4) |
| Annexe 3 × 3 | j = 38–40 | **j = 35–37** |
| Sas des chaînes | portes 16,8 × 18,5 | **portes 10,3 × 18,5** (2 travées de 5,5 de la nouvelle façade), à ~24,8 studs de l'axe de la chaîne |
| Bâtiments, garages, voirie | — | **inchangés** (chaussée 2 × 25, trottoirs 15,9, fourgons ×1,25, portes 20 × 19, places 16 × 34) ; seul l'accès change (sortie du rond-point) |

**Toutes les positions changent** : reprendre `DonneesArbres.lua`, `DonneesCollisions.lua`, `plots_joueurs.json` et `chaines_production.json` de ce dossier, et **régénérer `RoutesAmbiance`** et les trajets de `map/routes.py` (§ 5 quater). Les fichiers `AnimationChaine` / `Joints_ChaineProduction` (animation de la chaîne) concernent le jeu, pas la map : la chaîne est posée à **échelle 1**, avec les mêmes noms de pièces que le modèle `ChaineProduction_M4_9`, préfixés `NE_`, `NO_`, `SO_`, `SE_`.

Rappel de la V20 (toujours valable) — échelle du jeu (**M4 = 22 studs, 1 m = 4,59 studs**) :

| Donnée | Valeur |
|---|---|
| Chaussée | **50 studs** = 2 sens de **25** ; **une seule ligne tiretée, sur l'axe** |
| Si tu fais 2 voies par sens | 2 × 12,5 : centres de voie à **6,25** et **18,75** studs de l'axe ; une seule file : **12,5** (recommandé) |
| Trottoir | **15,9 studs** (bordure 2 + dalles 13,9), dessus Y = 1,27 ; emprise d'une route **81,8 studs** |
| Garages | fourgons ×1,25 (21,8 → **27,2** = Sprinter L2), portes **20 × 19**, places **16 × 34**, sortie du rond-point de **30** |

Autres nouveautés depuis la V17m (déjà livrées en V18-V20) :
1. **Herbe Terrain seulement sur les espaces verts** (plus sur les routes ni dans les ronds-points), dessus sous le niveau des routes (§ 3).
2. **Brouillard du bord de la map refait** : un seul voile lisse et homogène (§ 3).
3. **Zone camions (8 garages)** : bordures continues autour de la cour, marquage en pointillés, rez-de-chaussée détaillés (§ 5 bis).
4. **Sas d'entrée des 4 chaînes** : 2 portes coulissantes l'une derrière l'autre de chaque côté du portail, Script **`PortesSas`** (§ 5 ter).
5. Coins de trottoir anneau / route du tour joints (dalle de coin), couture du rond-point ouest supprimée.

## 1. Contenu du dossier

| Dossier | Fichier | Rôle |
|---|---|---|
| `01_A_IMPORTER` | `MAP_MOTIFS_V17_AVEC_CHAINES.fbx` (21,4 Mo) | Toute la map : sol, routes, tunnels, rond-point central + monument, 4 chaînes de production (déjà placées, sas percés), façades, bâtiments d'angle (coin NE seulement, les 3 autres sont copiés par script) |
| | `ARBRES_V17.fbx` | Bibliothèque de 27 modèles d'arbres (les ~380 arbres de la map sont des copies posées par script) |
| | `CAMIONS_V17.rbxm` | Les 3 véhicules de Thomas (`Van`, `TallVan`, `Camion`) à insérer dans **ServerStorage** : `InstallerMap` en pose 24 copies ancrées **×1,25** (garages et parkings des 8 coins, fourgon = 27,2 studs) |
| | `MAP_V17.rbxlx` | Place Roblox prête : scripts + réglages (streaming, éclairage, course, portes des sas, point d’apparition) |
| `02_Scripts_Roblox` | `InstallerMap.lua` (ModuleScript, ServerStorage) | Installe la map (collisions, arbres, copies, verre, eau, jets, plots, herbe, véhicules, portes des sas…) |
| | `DonneesCollisions.lua` (ModuleScript, ServerStorage) | ~2 350 boîtes + ~410 cylindres de collision invisibles + plans inclinés (sorties des ronds-points vers les garages ; V21d : plus d'entrées de plots figées) ; collisions des segments de trottoir des plots nommées `Trottoir_PlotN_kk` (rangées dans le Model du segment) (sorties des ronds-points vers les garages) |
| | `DonneesArbres.lua` (ModuleScript, ServerStorage) | Arbres, copies des bâtiments, lumières, chaînes, **plots (avec entrée / sortie)**, bassin, jets d'eau, brume, **véhicules** (`vehicules`, `echelle_vehicules`), plafonniers (`garages`), **zones d'herbe** (`herbe`, `herbe_ilots`), **portes des sas** (`portes_sas`) |
| | `Lancement.lua` (Script, ServerScriptService) | Lance `InstallerMap` au démarrage si ce n'est pas déjà fait |
| | `PortesSas.lua` (Script, ServerScriptService) — **nouveau V18** | Ouvre / ferme les portes coulissantes des sas quand un joueur approche |
| | `RobotStock.lua` (Script, ServerScriptService) — **nouveau V21i** | Anime les 8 robots de stock du plafond des hangars (pont roulant qui déplace un carton) |
| | `Course.lua` (LocalScript, StarterPlayerScripts) | Courir (Maj / L3 / bouton mobile) ×1,8, FOV animé |
| `03_Images` | vues numérotées + `V18_Nouveautes/` (sas, garages, herbe, brouillard, coins de trottoir, route de 50 studs avec les voitures à l'échelle du jeu) | Plan annoté des plots, zoom d'un plot, vues du centre, façades, plots, tunnels |
| `04_Donnees` | `plots_joueurs.json`, `chaines_production.json` | **Géométrie exacte des 8 plots** (cases, annexe, entrée, sortie) et des 4 chaînes |
| `05_Map_complete_FBX_Textures` | `FBX/` (00 à 10), `Textures/`, `MAP_V17_complete.blend`, `LISEZ_MOI.txt` | **Toute la map en FBX** (tout-en-un + une partie par FBX), toutes les textures en PNG, fichier Blender complet. Même repère que le FBX principal |

## 2. Installation dans Studio

1. Ouvrir `MAP_V17.rbxlx` (ou une place existante : supprimer l'ancienne map importée, l'ancien dossier `Collisions`, `Vehicules`, `PortesSas`, `PlotZones`).
2. Accueil › **Importer 3D** › `MAP_MOTIFS_V17_AVEC_CHAINES.fbx` (réglages par défaut, dans Workspace), puis `ARBRES_V17.fbx`.
   Clic droit sur **ServerStorage** › *Insert from File…* › `CAMIONS_V17.rbxm` (ne pas tourner ni agrandir les modèles : l'installeur les copie ×1,25).
3. Mettre les 3 ModuleScripts (`InstallerMap`, `DonneesCollisions`, `DonneesArbres`) dans ServerStorage et les Scripts `Lancement`, `PortesSas`, `RobotStock` dans ServerScriptService (depuis la V19 : plus de `TailleJoueurs`, l'avatar garde sa taille de 6,5 studs) (déjà fait dans `MAP_V17.rbxlx`).
4. **Jouer** : `Lancement` appelle `InstallerMap` → la map est installée.
5. Pour figer l'installation dans la place : barre de commandes `require(game.ServerStorage.InstallerMap)()` puis **Sauvegarder**.

Chaque MeshPart n'a **qu'une seule texture** (obligatoire dans Roblox : sinon l'import mélange les textures). Les pièces multi-matériaux ont été découpées : `NomPiece`, `NomPiece__Materiau2`, …

## 3. Géométrie générale (voir `03_Images/01_plan_vue_de_haut_plots.png`)

- **Map carrée 2 369,4 × 2 369,4 studs** (demi-côté 1 184,7). Sol plat. Orientation du plan : haut de l'image = **−Z**, droite = **+X**.
- **Hauteurs du sol** : herbe **Y = 0** ; chaussée **Y = 0,57** ; trottoirs, parvis, esplanades **Y = 1,27** ; pelouse des îlots **Y = 1,08**.
- **Routes (V20-V21)** : **25 studs de bitume par sens** (**chaussée 50 studs**, ligne tiretée sur l'axe seulement), trottoirs de **15,9 studs** de chaque côté (bordure granit 2 studs + 2 rangs de dalles) → **emprise 81,8 studs**. À l'échelle du jeu (4,59 studs/m) : chaussée 10,9 m, trottoirs 3,5 m.
- **Rond-point central** : centre (0,0,0), rayon extérieur de chaussée **177,9** (V21), anneau de 50 studs, îlot (esplanade + monument) rayon 127,9 (dont trottoir de 15,9).
- **4 avenues** (axes ±X, ±Z) du centre vers **4 ronds-points extérieurs** centrés à **516 studs** (rayon extérieur 110,5, anneau de 50, îlot rayon 60,5 dont trottoir de 15,9).
- **Route du tour** : carré à ±516 studs (axe), qui tourne vers les 4 angles, puis **routes à 4 voies en diagonale** jusqu'aux angles de la map (terre-plein central). Coins anneau / route du tour à angle vif (dalle de coin).
- **8 branches vers des tunnels** : à **±174,7 studs** de l'axe de chaque avenue, du rond-point extérieur jusqu'au bord. **Bouche des tunnels à 1 036,9 studs** du centre ; têtes de tunnel de 147,8 studs (fin de map : les voitures arrivent / repartent par là), V21 : voûte à l'échelle ×1,143, **piédroits pile sur le bord extérieur des trottoirs** (plus d'herbe entre trottoir et tunnel) : passage 81,2 studs de large × ~65 de haut.
- Carrefours branche / route du tour : **angles droits** (pas d'arrondi).

- **Brouillard du bord de la map (V18, refait)** — « transition hyper smooth, pas de murs empilés, un mur homogène qui se fond dans le fond » :
  - **V21 — « le même brouillard que sur les rendus »** : `InstallerMap` (section « 6 quinquies », `BROUILLARD_RENDU = true`) **impose** l'Atmosphere des rendus (Density 0,45, Offset 0, Haze 2,5, Glare 0, Color 247,226,207, Decay 255,240,226 : couleurs mesurées sur les rendus) et pose une **coque de ciel crème** (`Workspace.CielCreme` : murs de Parts lisses à 5 200 studs du centre, 2 400 de haut, sans ombre ni collision, toujours chargés) que l'Atmosphere fond complètement → ciel crème au ras de l'horizon, comme sur les rendus, quelle que soit la Skybox. Si ton jeu règle lui-même `Lighting` / l'Atmosphere au lancement, il écrase ces valeurs : les reprendre ou mettre `BROUILLARD_RENDU = false` ;
  - `Lighting` de la place = celui de `Station_Tycoon_v13_1.rbxl` : ciel, 15 h 30, Bloom, SunRays, ColorCorrection, Atmosphere remplacée par celle des rendus (voir ci-dessus) ;
  - **16 rideaux lisses** (`Brume_Rideau_1…16_*`, groupe `Sol`, 15 visibles) : carrés concentriques de 100 studs avant la bouche des tunnels jusqu'à 10 studs au-delà du bord ; **couleur unie accordée à l'Atmosphere** (pied 236,214,198 → haut 246,228,214) ; **opacités calculées pour que la somme des rideaux suive une loi continue** (transmission T = exp(−3,2·t^1,7), de 3 % à 29 % par rideau, le dernier opaque) → aucune marche visible ; chaque rideau est plein jusqu'à 35 % de sa hauteur puis s'efface en douceur (smoothstep) ; hauteurs de 45 à 260 studs, toutes différentes → aucun bord visible. **Normales des rideaux vers le haut** : dans Roblox tous les rideaux reçoivent la même lumière quelle que soit leur orientation (sinon un côté est plus sombre) ;
  - 2 **nappes au sol** (2 et 7 studs de haut) en 4 bandes à dégradé continu ;
  - `InstallerMap` : Transparency 0,001 (l'alpha de la texture est respecté), sans ombre ni collision ;
  - **sol d'horizon** : l'herbe continue hors de la map jusqu'à 6 000 studs (`Horizon_Sol_*`, **Persistent**) ;
  - **bancs de brume** (`Workspace.Brume`, 56 émetteurs `smoke_main.dds`) et **poussière dorée** (20 émetteurs `sparkles_main.dds`) : réglages en haut de la section « 6 quinquies » d'`InstallerMap`.
- **Herbe réaliste de Roblox (V18-V21)** : `Terrain Grass` (brins animés, `Decoration = true`, `GrassLength = 0,7`, couleur **(111, 126, 62)**) **seulement sur les espaces verts**. Les zones sont **calculées à partir de la géométrie** (`herbe_zones.py`) : carré de la map − routes et trottoirs − îlots − tunnels − chaînes et bâtiments (+ dallages) − cours des garages − plots des joueurs et annexes − place centrale, **reculé de 4 studs de chaque bordure**, découpé en rectangles de la grille des voxels (4 studs) : `DonneesArbres.herbe` (1 614 rectangles `{x0, z0, x1, z1}`, dessus à **Y = 0,12**, sous la chaussée à 0,57 → **le vert ne cache plus les routes**) et `DonneesArbres.herbe_ilots` (36 rectangles : pelouse des 4 îlots des ronds-points extérieurs, dessus à 1,20). Au lancement, `InstallerMap` **vide d'abord le Terrain de la map** (Air), puis remplit ces rectangles. Le mesh d'herbe (`Sol_Herbe_*`) reste visible dessous (même teinte) et fait les bords. Image de contrôle : `03_Images/V18_Nouveautes/herbe_zones.png`.
- **Limites** : 4 murs invisibles (Parts `limite`, 300 studs de haut) sur le bord de la map.
- **Trottoirs** : 15,9 studs de large, dalles en pierre claire beige en damier, bordure en granit gris, flancs en béton.

## 4. LES 8 PLOTS DES JOUEURS (le plus important)

Données exactes : **`04_Donnees/plots_joueurs.json`** (et table `plots` dans `DonneesArbres.lua`). Images : `03_Images/01_…`, `02_zoom_plot6_cases_et_annexe.png`.

- 1 plot par branche de tunnel, **côté angle de la map**, numérotés **Plot1 à Plot8** (voir image).
- Chaque plot est un **quadrillage de cases de 10 × 10 studs** : **27 cases** en largeur (axe U, du trottoir de la branche vers l'angle de la map = 270 studs) × **48 cases** en longueur (axe V, de la bouche du tunnel vers le centre = 480 studs, jusqu'au trottoir de la route du tour).
- Le plot commence **au bord des trottoirs** (trottoir de la branche d'un côté, trottoir de la route du tour de l'autre), **à la sortie du tunnel**.
- Coin intérieur : le virage de la route du tour mord le plot → **34 cases exclues** (petit escalier) ; **1 262 cases valides** par plot. La liste exacte des cases exclues `(i, j)` est dans le JSON.
- Repère de chaque plot (JSON, studs Roblox) :
  - `origine_coin_tunnel_branche` = coin du plot côté tunnel / côté branche ;
  - `axe_U_vers_angle_de_la_map`, `axe_V_du_tunnel_vers_le_centre` (vecteurs unitaires horizontaux) ;
  - **centre de la case (i, j) = origine + U·(i+0,5)·10 + V·(j+0,5)·10**, avec i ∈ [0, 26], j ∈ [0, 47] ; i = 0 le long de la branche, j = 0 côté tunnel.
  - `bouche_du_tunnel` (point d'arrivée des voitures sur l'axe de la branche) et `direction_sortie_voitures` ;
  - `angle_droit_branche_route_du_tour`.
- Exemple Plot6 : origine (−1 036,9 ; 0 ; −215,6), U = (0, 0, −1), V = (+1, 0, 0), boîte englobante X ∈ [−1 036,9 ; −556,9], Z ∈ [−485,6 ; −215,6] ; bouche du tunnel (−1 036,9 ; 0 ; −174,7).
- **Annexe 3 × 3** (bleue sur les images) : pour chaque plot, un carré de **3 × 3 cases de 10 studs (30 × 30)** **de l'autre côté de la branche**, collé à son trottoir, aligné sur les cases **j = 35 à 37** du plot. Repère dans le JSON (`annexe_3x3` : origine, axes I et J).
- **Entrée et sortie de chaque plot — DÉPLAÇABLES (V21d, demandé par l'IA du jeu)** : plus aucun accès n'est creusé dans le trottoir, qui est **plein partout**. Le long du bord route de chaque plot (côté route du tour), du coin de la branche (U = 0) au bout du plot (U = 270 studs), le trottoir est **découpé en 18 segments de 15 studs** :
  - noms : `Trottoir_PlotN_kk`, avec k = 00 à 17 en partant de la branche du tunnel. Chaque segment fait 15 studs le long du bord, sur toute la largeur du trottoir (bordure + dalles, 15,9 studs) ;
  - **une texture par MeshPart** (contrainte Roblox) : chaque segment compte donc 5 MeshParts, `Trottoir_PlotN_kk`, `…__Bordure`, `…__DalleClaire`, `…__DalleMoyenne` et `…__Assise` ;
  - **`InstallerMap` les range** dans `Workspace.<map>.Voirie.TrottoirsPlots.PlotN.Trottoir_PlotN_kk`, un **Model par segment** qui contient ses 5 MeshParts et sa Part de collision invisible, renommée `Collision`. Les Models sont en streaming Persistent ;
  - pour **ouvrir une entrée / sortie** : masquer les Models choisis (par exemple 3 segments de 15 = 45 studs pour une double voie de 2 × 22,5, ou plus), meshes et collision ensemble, puis poser sa propre traversée (chaussée à plat, **Y = 0,57**) et ses rampes (dalles 1,27 → 0,57, bordure 1,43 → 0,57). La **ligne de rive** (trait blanc au bord de la chaussée) fait partie du mesh de la route et reste continue : la recouvrir devant l'accès (plaque de bitume à Y = 0,58) ;
  - les **derniers segments** (vers le bout du plot) suivent le début du virage de la route du tour : ils forment une bande légèrement oblique, et leur bord côté plot n'est plus exactement à V = 480 ;
  - **V21l — sortie prolongée au-delà du plot** : après `_17` (U = 270), le trottoir de la route du tour continue (fin du virage puis la diagonale) et il est **découpé à la suite en 16 segments de 15 studs** : `Trottoir_PlotN_18` à `_33`, **mesurés le long de la bordure et coupés perpendiculairement à elle** (`_18` est plus court : il raccorde la coupe U = 270 au virage), jusqu'au point indiqué par Thomas (~245 studs de bordure). Même structure (Model par segment, 5 MeshParts + `Collision`). Dans le JSON, ces segments ont `"au_dela_du_plot": true`, `le_long_de_la_bordure_studs`, `milieu_bord_chaussee`, `milieu_bord_plot`, `direction_vers_le_trottoir` et `direction_le_long` (pas de `u_studs`). **Entre ce trottoir et le plot il y a de la pelouse** : si la sortie est placée là, le jeu doit y poser son chemin du plot jusqu'au trottoir ;
  - données exactes : `trottoir_segments` de chaque plot dans `04_Donnees/plots_joueurs.json` (nom, index, U en studs, milieu du bord plot à Y = 1,27, milieu du bord chaussée à Y = 0,57, boîte X / Z) ;
  - les extrémités des segments sont ouvertes (coupe nette) : quand un segment est masqué, les rampes du jeu viennent contre les bouts des segments voisins ;
- **Entrée sur le bord BRANCHE — DÉPLAÇABLE (V21k, jeu v51)** : l'entrée des clients n'est plus sur la route du tour mais sur le **bord branche** (le grand côté U = 0 du plot, le long de la route qui vient du tunnel), déplaçable sur toute la longueur par pas de 15 studs. Seule la **sortie** reste sur le bord route du tour (segments V21d ci-dessus). Le trottoir du bord branche est lui aussi **plein partout** et **découpé en 32 segments de 15 studs** par plot :
  - noms : `Trottoir_PlotN_B_kk`, k = **00 à 31 en partant du coin de la route du tour** : `_B_00` touche le coin du carrefour, `_B_31` touche la tête de tunnel. Dans le repère du plot, le segment k couvre **V = 480 − 15 (k + 1) … 480 − 15 k** (U ≈ −15,9 … 0 : toute la largeur du trottoir, bordure + dalles) ;
  - même structure que les segments du bord route : **une texture par MeshPart** (`Trottoir_PlotN_B_kk`, `…__Bordure`, `…__DalleClaire`, `…__DalleMoyenne`, `…__Assise`) + **Part de collision invisible `Collision`**, extrémités ouvertes (coupe nette) ; `InstallerMap` les range dans `Workspace.<map>.Voirie.TrottoirsPlots.PlotN.Trottoir_PlotN_B_kk` (un Model par segment, streaming Persistent) ;
  - le **coin arrondi du carrefour** (jonction des deux trottoirs, V > 480) reste une pièce à part dans la voirie, **non masquable** ; le trottoir de la branche au-delà de V = 0 (tête de tunnel) aussi ;
  - **pour une entrée aux rangées zE et zE + 1** : masquer `_B_` k = zE − 1 et k = zE, puis poser la traversée (chaussée Y = 0,57) et les rampes comme pour la sortie ;
  - données : `trottoir_segments_branche` de chaque plot dans `04_Donnees/plots_joueurs.json` (même format que `trottoir_segments`, avec `v_studs` à la place de `u_studs`) ; collisions `Trottoir_PlotN_B_kk` dans `DonneesCollisions.lua` ;
  - vérification : 8 × 32 = **256 Models `_B_`** en plus des 8 × 34 = 272 du bord route (V21l).
  - circuit logique d'une voiture : sortie du tunnel → branche → **Entrée** (bord branche) → plot → **Sortie** (bord route du tour) → route du tour.
- Le sol des plots est de l'herbe mesh à Y = 0 (**pas de Terrain Grass dans les plots**, aucun arbre, aucune route dedans). Au Play, `InstallerMap` dessine chaque plot au sol en **orange translucide** (dossier `Workspace.PlotZones.PlotN`). Ces repères sont sans collision : à supprimer / remplacer par le vrai système de construction.
- Le jeu existant utilisait des plots avec `PlotCenter`, `PlayerSpawn`, `Camera`, `Tunnel`, `QueueNodes`, `ExitNodes` et une grille de 10 studs : **les recréer à partir du JSON**.

## 5. Le centre (voir images)

- **Monument** au centre de l'îlot : bassin hexagonal (vraie **eau Terrain Roblox**, 12 jets d'eau), socle, **tour vitrée** (~95 studs). **3 emplacements voitures** (plateaux tournants de 34 studs de diamètre en V21) à 30°, 150° et 270°.
- **4 chaînes de production** (`ChaineProduction_M4_9`, **échelle 1**, 275,6 × 83,2 × ~62 studs) sur les **4 diagonales**, **portail tourné vers le rond-point central**, façade arrondie collée au trottoir ; un tronçon de route relie l'anneau central au portail. Pièces nommées `NE_CP_…`, `NO_CP_…`, `SO_CP_…`, `SE_CP_…`. Positions : `04_Donnees/chaines_production.json` (centre de `CP_Hall`, rotation Y ; V21 : hall à ±235,9 studs en X et Z).
- Façade avant arrondie de chaque chaîne : `XX_Avancee` (ossature) + `XX_Avancee_Verre` (verre seul).
- De chaque côté de chaque chaîne : **rangée de 4 bâtiments industriels** (tête à grandes baies, atelier à sheds, bureaux, entrepôt + silos). Objets `Bloc_NE_…` dans le FBX ; les coins NO, SO, SE sont des **copies tournées** créées par `InstallerMap` (instancing).

### 5 bis. Zone camions / garages (V20 ; V21 : accès par le rond-point extérieur)

- 8 garages identiques (un par côté de chaque chaîne : coins `NE_a`, `NE_b`, `NO_a`, … `SE_b`).
- **Garage ouvert** (atelier à sheds, côté bureaux) : porte sectionnelle **20 × 19 studs** relevée ; garage intérieur **24 × 38 × 21,5 studs** (sol béton, marquage jaune, 2 rayonnages de 4 étagères, établi, 3 réglettes + une PointLight) avec un **fourgon** (Van ×1,25 = 27,2 studs, Sprinter L2 à l'échelle du jeu) garé face à la sortie. L'autre porte (fermée) et la porte de service ont chacune plaque numérotée, protections de tableau jaune / noir, extincteur, plan d'évacuation.
- **Entrée unique (V21) : une sortie simple du rond-point extérieur voisin**. La **grande cour en bitume** (Y = 0,57, de la façade jusqu'au trottoir de l'avenue) n'a pas bougé ; le rond-point extérieur est venu la toucher. Sur l'anneau, côté cour, le trottoir est **coupé net, bouts à angle droit** (sans rampe), entre la fin de l'arrondi avenue / anneau (26° de l'axe de l'avenue) et 45° : ~37 studs le long de la bordure, au niveau de la chaussée. La **plate de goudron** est prolongée jusqu'au **prolongement du pignon des bureaux** et jusqu'au trottoir du rond-point (bordure haute tout le long, sauf à l'entrée) ; au-delà du pignon, de l'herbe. Le trottoir de l'avenue et son arrondi sont **inchangés**. Exemple coin `NE_a` : la bordure coupée va de (48,4 ; 0,57 ; −416,7) à (78,1 ; 0,57 ; −437,9). Collisions : boîtes `entree_plot` (table `plans` de `DonneesCollisions`) le long de la coupe + bandes `cour`.
- **Bout de la cour côté centre (V21)** : carré (bord perpendiculaire au trottoir de l'avenue, au droit du coin de l'atelier) ; le petit triangle restant est dallé.
- **Bordures (V18)** : **anneau de bordure continu** autour de toute la cour (bordure granit, dessus 1,43), joint aux bâtiments et au trottoir, interrompu seulement à la bouche du col (sortie du rond-point) ; **rampe de 7 studs** devant chaque porte jusqu'au sol intérieur (Y = 1,27).
- **Marquage au sol (V18)** : **cases de manœuvre jaunes en pointillés** devant chaque porte, **guidage blanc en pointillés** de la sortie du rond-point jusqu'aux portes, lignes des places, ligne de bouche du parking.
- **Quais de déchargement (V21, bâtiment logistique)** : la façade des bureaux côté cour est **reculée de 10 studs**. Devant, un **quai ouvert** en béton à hauteur de plateau, **5,5 studs au-dessus de la cour (1,2 m à l'échelle du jeu)** et 10 studs de profondeur, avec cornière acier, ligne jaune, escalier avec garde-corps au bout et bornes jaunes. Au rez-de-chaussée, **4 portes sectionnelles de 13 × 13 studs** (2,83 m : camion 11,5 de large, fourgon 12,3 rétroviseurs compris), une par place. Chaque porte a son encadrement béton en relief, ses montants rayés anti-choc, son feu rouge / vert, sa lampe de quai, son numéro, et devant elle un niveleur rayé jaune / noir et des butoirs caoutchouc. Le tout est couvert par un **grand auvent** (consoles, tirants, hublots). **V21g : les 5 fenêtres de l'étage sont de vraies vitres** (`M_Blocs_Vitrage`, pièce `Bloc_…_9_hangar_Vitre`, transparente) **qui donnent sur le hangar** : on voit l'intérieur depuis la cour, et depuis le hangar on les voit en hauteur au-dessus des portes (cadre acier + tablette côté hangar). Les 3 fentes vitrées de la façade du stockage sont aussi de vraies vitres (on voit le bureau vitré derrière). **4 places de quai** de **16 × 34 studs** partent du bord du quai, avec des chasse-roues jaune / noir. Le **camion** et le **grand fourgon** (×1,25) sont **à quai en marche arrière** sur les quais 1 et 2 ; palettes filmées, cartons, transpalette et roll sont posés sur le quai. Collisions : bloc `quai` et marches `escalier` (tables de `DonneesCollisions`).
- **Hangar de stockage intérieur (V21e)** : le bâtiment des quais (bureaux) et le bâtiment voisin (stockage) forment **un seul grand hangar blanc** de ~120 × 105 studs, style entrepôt logistique :
  - **3 portes de quai sur 4 sont ouvertes** (quais 1 à 3) ; la 4e, près de l'escalier, reste fermée ;
  - **plancher au niveau du quai** (Y = 6,07, comme un vrai quai) ; murs blancs à plinthe grise ; **V21g : plafond à 38 studs** au-dessus du plancher (juste sous le toit des bureaux, pour que les fenêtres de l'étage donnent dans le hangar) ; **charpente carrée** inspirée de la verrière de la chaîne M4 : poutres maîtresses en I anthracite (2,4 studs de haut) tous les 16 studs, calées sur les limites des quais, pannes en I au même pas, goussets aux croisements, poutre de rive tout autour, **une dalle LED carrée par case** (pièce `Bloc_…_9_hangar_LED`, `InstallerMap` la passe en **Neon** gris clair atténué, couleur 176,174,162, pour ne pas éblouir), **poteaux muraux** en acier sur platine avec fourreau rayé jaune / noir, gaine de ventilation alu le long du mur du fond (suspentes, diffuseurs), réseau sprinkler rouge le long des pannes ; grande bannière bleue au fond avec pictos ;
  - **étagères = le modèle de Thomas** (`Stockage_Cartons_Rayonnages.fbx` : rayonnage plein / vide de 20 × 10,8 × 15,5 studs, texture `tex_rayonnage.png`, posé à l'échelle 1) : 4 rangées (2 simples contre les murs, 2 doubles dos à dos) de 3 rayonnages par côté, soit 18 rayonnages par hangar, perpendiculaires aux quais. Allées d'environ 17 studs avec lignes jaunes, allée piétonne verte transversale, piles de cartons du modèle dans les allées et devant les quais. Pièces `Bloc_…_9_hangar_racksN__M_Rayonnage` (la texture du modèle, une par MeshPart) ;
  - derrière chaque porte ouverte : zone hachurée jaune, palettes en attente, potelets jaunes, cadre acier et boîtier de commande ; **V21g : plus de chariot élévateur ni de transpalette** (demande de Thomas) ; un poste d'emballage (table, écran, bacs, petit convoyeur) ;
  - **bouts de rangées (V21g)** : vraies glissières de protection (potelets + 2 lisses jaunes, embouts noirs) et cornières rayées aux angles ;
  - **détails (V21g)** : armoires électriques, RIA et trousse de secours, horloge, poubelles de tri, extincteurs, 4 casiers de vestiaire + banc, pile de palettes vides près de la porte fermée, cornière d'angle, passage piéton zébré jusqu'à l'entrée du personnel ;
  - **bureau vitré façon chaîne M4 (V21g)** (28 × 24 studs, 12 de haut) près de l'**entrée du personnel** : mur-rideau à montants anthracite, socle anthracite, bande orange comme le hall de la chaîne, **toiture vitrée à grille carrée**, porte vitrée ouverte ; dedans moquette, 2 postes (plateau bois, 2 écrans, clavier, fauteuil), table de réunion et 4 fauteuils, armoire, plante, tableau blanc, plafonnier. Le verre est le vrai verre (`M_Blocs_Vitrage`) dans la pièce `Bloc_…_9_hangar_Vitre` : `InstallerMap` lui met Transparency 0,6 (on voit à travers) ;
  - **entrée du personnel** : sur la façade avant du bâtiment de stockage (porte entourée en bleu par Thomas), porte ouverte au niveau du plancher, palier, escalier de 6 marches avec garde-corps, et allée dallée depuis la plate de livraison ;
  - **robot de gestion du stock (V21i)** : pont roulant automatique accroché à la charpente. Deux chemins de roulement jaunes sous les poutres maîtresses extrêmes (≈ 96 studs d'écart), un **pont orange** (bandeaux bleus, gyrophares) qui roule le long des allées, un **chariot** qui roule sur le pont, une **colonne télescopique** au bout de laquelle est suspendu **un bras robot identique à ceux de la chaîne M4** (robot P1 de `chaine_m4.blend`, retourné tête en bas, même texture `TEX_Chaine`) ; sous son outil, un **préhenseur à ventouses** (tige, plateau orange à la taille du carton, 4 ventouses, comme un robot de palettisation) prend un **carton** et le repose ailleurs. Cycle (V21j) : **aller-retour en boucle entre la zone A** (carré hachuré orange près de la porte de quai fermée) **et la zone B** (carré hachuré orange dans l'allée transversale, ~31 studs plus loin) : descente, prise (0,8 s), remontée, déplacement, descente, dépose, remontée, puis retour ; ~9 studs/s à l'horizontale, 7 studs/s à la verticale. Pièces mobiles : `Bloc_<coin>_9_hangar_robot_pont`, `_chariot`, `_cable`, `_pince` (bride), `_bras` (bras M4, matériau `M_CP_Hall`), `_carton` (+ 3 repères minuscules `_robot_repO/repS/repL` qui donnent le repère du hangar, rendus invisibles). Le **Script `RobotStock`** (ServerScriptService, `02_Scripts_Roblox/RobotStock.lua`, ajouté dans `MAP_V17.rbxlx`) attend que les 8 coins soient installés puis anime les 8 robots avec TweenService (pièces ancrées, sans collision). Pour l'ajouter à une place existante : coller `RobotStock.lua` dans un Script de ServerScriptService ;
  - pièces : `Bloc_<coin>_9_hangar` (structure), `_charpente`, `_LED`, `_robot_*`, `_racks1` à `_racks3`, `_equip`, `_Vitre` (copiées dans les 8 coins comme les autres `Bloc_`) ;
  - collisions : plancher (`plancher_hangar`), rayonnages (`rack`, un bloc par rangée, 15,5 studs de haut), bureau vitré (`bureau_vitre`, porte libre, `bureau_toit`), palier et marches, mur côté atelier. Les façades sont percées aux portes ouvertes ;
  - éclairage : 6 PointLights par hangar à 30 studs du sol (V21h : Range 40, Brightness 0,8, sans ombre ; murs gris très clair, sol époxy gris, plafond gris moyen), ajoutées à la liste des plafonniers des garages (`DonneesArbres.garages`).
- **Rez-de-chaussée détaillés (V18)** : entrepôt (bandeau goutte d'eau, appliques, bornes lumineuses).
- `DonneesArbres.vehicules` : 24 entrées `{modele, coin, pos, avant}` (`pos` = milieu du dessous du véhicule, `avant` = direction du capot) ; `DonneesArbres.echelle_vehicules = 1.25` ; `DonneesArbres.garages` = plafonniers.
- Pose par `InstallerMap` (section « 6 sexies ») : il cherche `Van`, `TallVan`, `Camion` dans ServerStorage, les clone, les **agrandit ×1,25** (`Model:ScaleTo(GetScale()*1.25)` : Van 21,8 → 27,2 = ton « Fourgon »), recalcule leur boîte englobante puis les place avec `CFrame.lookAt(pos, pos + avant)` ; copies ancrées dans `Workspace.Vehicules`.
- Collisions : cour (bandes), bordures, façade percée, murs, sol et plafond du garage : on peut entrer dans le garage à pied. Les arbres ont été retirés des cours.

### 5 ter. Sas d'entrée des chaînes de production (V18, adaptés à la M4_9 en V21)

- Sur la **façade arrondie verte** de chaque chaîne, **de chaque côté du portail** (à ~24,8 studs de l'axe de la chaîne) : **porte 1** dans une facette droite de la façade arrondie, **porte 2** juste derrière dans la façade du hall (meneau du milieu et allège retirés sur 2 travées de 5,5 studs, sous l'imposte) → un **sas de ~6,5 studs** (sol de l'avancée) entre les deux. **8 sas, 16 portes**, passage **10,3 × 18,5 studs** (avatar de 6,5 studs : largement ≥ 9,5 de haut).
- Battants : **Parts ancrées** créées par `InstallerMap` (section « 6 septies ») dans `Workspace.PortesSas` : un Model `PorteSas_<chaine>_<a|b>_<1|2>` par porte, 2 battants vitrés (verre + montants + traverses), tagué **`PorteCoulissante`** (CollectionService), attribut `Centre` ; chaque pièce mobile porte les attributs `Ferme` / `Ouvert` (CFrame) et `Bloque` (la vitre fait la collision quand la porte est fermée). Enseigne verte **« ENTRÉE »** au-dessus de chaque porte 1.
- Script **`PortesSas`** (ServerScriptService) : toutes les 0,15 s, si un joueur est à moins de **16 studs** du milieu d'une porte, les battants glissent (TweenService 0,6 s) et la vitre ne bloque plus ; ils se referment (0,9 s) quand plus personne n'est proche. Réglages en haut du script.
- Données : `DonneesArbres.portes_sas` = `{chaine, cote, rang (1 = façade arrondie, 2 = hall), pos (milieu du seuil), axe (le long du mur), dedans (vers le sas), largeur, hauteur, decal}`.
- Collisions : sol du sas (Part `sol`), murs de l'avancée coupés au droit de la porte 1 (linteau gardé). **Meshes du hall** (`XX_CP_Hall`, `XX_CP_Hall_Verre`) : `InstallerMap` leur met `CollisionFidelity = PreciseConvexDecomposition` pour que le passage de la porte 2 reste libre (si Studio refuse ce réglage par script, le faire à la main dans les Propriétés).

### 5 quater. Voitures du trafic (V20-V21)

Rien à changer dans `Car` : la voirie (V20, inchangée en V21) est dimensionnée pour ta règle **M4 = 22 studs** (Urus 23,5 × 10,1, Challenger 11,2 de large, Classe G 9,0 de haut, fourgon 27,2 × 9,3 × 12,4) : **25 studs par sens** = une voiture de 11,2 de large avec ~7 studs de marge de chaque côté. Image à l'échelle : `03_Images/V18_Nouveautes/route_50_voitures_echelle_jeu.png`.

À refaire côté jeu (la géométrie a changé) :
- **`ServerStorage/RoutesAmbiance`** et `map/routes.py` : régénérer depuis la V21 (anneau central de rayon extérieur 177,9, ronds-points extérieurs de rayon 110,5 centrés à 516, route du tour à ±516, branches à ±174,7, chaussée de 50, chaînes à ±235,9, entrées de plots de 50, **8 sorties des ronds-points extérieurs vers les cours des garages**) ; voie des voitures = centre de chaussée ± 12,5 (une file par sens) ou ± 6,25 / ± 18,75 (2 voies de 12,5).
- **File d'attente** devant les plots (`ESPACE_ATTENTE` 30, `RECUL_ATTENTE`) : les plots ont 48 rangées (j = 0 à 47) ; les bouches de tunnel sont à 1 036,9.
- `gen_map.py` : `TROTTOIR = 15.9` ; entrées / sorties des plots : posées par le jeu sur les segments `Trottoir_PlotN_kk` (V21d), rampes de 11 conseillées.
- Collisions (`DonneesCollisions`) et herbe (`DonneesArbres.herbe`) : déjà régénérées dans ce dossier.

## 6. Réglages appliqués par `InstallerMap` (à conserver)

- Collisions des entrées / sorties de plots et des sorties des ronds-points vers les garages : `CFrame.fromMatrix` à partir de la table `plans` de `DonneesCollisions` (boîtes inclinées).
- Tout est **Anchored** ; meshes détaillés : CanCollide / CanTouch / CanQuery = false, CollisionFidelity = Box, RenderFidelity = Automatic ; **collisions = Parts invisibles simples** (dossier `Collisions`, ModelStreamingMode Persistent).
- **Verre** (toutes les pièces dont le nom contient « Verre » ou « Vitre », sauf `Bloc_`) : **Transparency 0,6, Reflectance 0,2**.
- Eau Terrain du bassin, jets d'eau, lumières (PointLights sans ombre), arbres copiés depuis `ARBRES_V17`, copies des bâtiments d'angle, véhicules ×1,25, portes des sas, herbe Terrain des espaces verts, point d'apparition `Depart` sur l'esplanade.
- Recalage : la pièce `Sol_Herbe_0_0` sert de référence (position attendue dans `DonneesArbres.reference`) ; tout est positionné avec `centre = CFrame.new(décalage d'import)`.
- Workspace : StreamingEnabled, rayon 768 / min 192 ; Lighting : ShadowMap.

## 7. Contraintes du projet (à respecter si on retouche)

- Cible **iPhone 11** : chaque MeshPart ≤ 20 000 triangles et ≤ 2 048 studs par axe ; FBX < 30 Mo ; **une texture par MeshPart**.
- Faces à sens unique (Roblox) : tout a été vérifié (**0 trou au sol, 0 face à l'envers**).
- Échelle du jeu (v41) : **1 m = 4,59 studs** (M4 = 22), avatar ≈ 6,5 studs : voies de 25 par sens, trottoirs 15,9, portes de garage 20 × 19, places 16 × 34, portes des sas 10,3 × 18,5, fourgons 27,2.
