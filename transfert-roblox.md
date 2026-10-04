# Station Tycoon — document de transfert (état au 5 octobre 2026, build v55)

> Ce document permet à une nouvelle session Claude (Claude Code) **sans aucun contexte** de reprendre le projet.
> Il a été rédigé par la session « CODE » (conversation Cowork commencée le 26/09/2026), qui servait de passerelle
> centrale du jeu. Sources utilisées pour le rédiger : le résumé de la conversation (les échanges détaillés antérieurs au
> 4 octobre ne sont plus disponibles, seul leur résumé l'est), l'historique des 64 tâches de la session, les fichiers
> livrés, les en-têtes et commentaires des scripts, la place `Station_Tycoon_v55.rbxl` analysée objet par objet, et la liste
> du dossier Téléchargements du PC. **Quand une information n'est pas certaine, c'est écrit.**

Propriétaire : **Thomas** (compte Roblox **thamary4**, UserId **1558910815**, e-mail pelouze.thomas.pro@gmail.com).
PC : Windows, nom `desktop-4pokh4o`, dossier de travail partagé avec Claude : **`C:\Users\ADMIN\Downloads`**.
Fichier de jeu à jour : **`C:\Users\ADMIN\Downloads\Station_Tycoon_v55.rbxl`** (7 326 108 octets).
**Dossier de transfert complet : `C:\Users\ADMIN\Downloads\StationTycoon_transfert_CODE\`** — tous les scripts de la v55 en
fichiers `.lua` rangés comme dans l'Explorer (`1_scripts_v55\`), les documents (`2_documents\`) et le pipeline de build
(`3_pipeline\`). Commencer par `00_LISEZMOI.md` de ce dossier.

---

## Sommaire

1. Le jeu
2. Organisation du travail
3. État actuel (code, map, UI, modèles 3D)
4. Fichiers
5. Décisions et historique
6. Suite (tâche en cours, prochaines étapes, questions ouvertes)
7. Annexes (code et tables à recopier)

---

## 1. LE JEU

### 1.1 Concept et genre

**Station Tycoon** (nom de l'expérience Roblox : « Station tycoon », **privée**) est un **tycoon de station-service /
station de lavage / atelier automobile** en multijoueur (8 emplacements de joueurs sur une même map).

Résumé tiré de la carte du projet (artefact « Carte de Station Tycoon », https://claude.ai/artifact/1UNhDHfJeCwstwqEhbnYvr) :
« Tycoon Roblox de stations (lavage, atelier) : les clients arrivent en voiture par la branche, se font servir, payent à la
caisse et repartent par la route du tour. »

### 1.2 Boucle de gameplay (telle qu'elle est codée)

1. Le joueur choisit un **plot** (8 emplacements, type A ou B en miroir) depuis l'écran-titre.
2. Il **construit** sur une grille de cases de 15 studs : sols (le **goudron / route / béton** est roulable par les voitures),
   murs, toits, décor, **stations** (3×3 cases) et **caisses**. Il peut acheter des **extensions** de terrain et décorer une
   petite **annexe** en face.
3. Il achète des **consommables** (onglet Stock). Ils arrivent par un **fourgon de livraison** jusqu'au garage de son plot ;
   les cartons sont ramassés (touche E ou employé « logisticien ») et vont dans le **stockage** ; il **remplit** ensuite les
   stations (onglet Supply).
4. Il **embauche** des employés (Attendant 12 $/min, Caissier 7 $/min, Logisticien 10 $/min) et les affecte.
5. Des **voitures clientes** sortent du tunnel (rareté tirée selon le **rang** du joueur : Common → Divine), font la queue sur
   la branche, **entrent** dans le plot si un couloir de goudron de 2 cases mène à une station, se garent, sont **servies**
   (animation de la station), le client **descend et va payer à pied** à une caisse, revient, puis la voiture **ressort** par
   la sortie (route du tour). Depuis la v53, sans employé, le joueur peut **laver lui-même** (touche E).
6. Gains : `Buy + (Sell − Buy) × Mult rareté × Mult station × bonus mutation` ; XP = 50 × Mult rareté ; la voiture entre dans
   l'**Index** (collection). L'XP + le nombre de voitures servies par rareté font monter le **rang** (7 rangs), qui augmente
   la cadence des clients et les chances de voitures rares.
7. Événements : **mutations** rares (voiture en or ×3, argent ×2, électrique/foudre ×1,5), **cinématique de découverte**
   (GT3, hyperespace), **voitures du centre** (sorties des 4 usines) achetables **aux enchères** ou en Robux (v55).
8. Premier lancement : **tutoriel** guidé par le PNJ **ItsCirly** sur un plot pré-construit (v53).

### 1.3 Public visé

**Non précisé** dans les éléments dont je dispose (je n'ai pas retrouvé de cible d'âge ou de plateforme formulée par Thomas).
Constats : l'UI v24 prévoit PC / téléphone / tablette / console (tâche « rendre responsive » + audit « manette / téléphone »
jamais terminé) ; l'expérience est privée pour l'instant.

### 1.4 Direction artistique

- **Map** : ville moderne construite par script dans Blender par une autre IA (« IA map »), textures réalistes (bitume,
  bordures en granit, dalles de trottoir), herbe en relief (Terrain Grass), ~380 arbres, 4 grandes **usines** avec une
  **chaîne de production** robotisée (BMW M4 & co), garages/quais de livraison, hangars avec robot de stock, brume au bord
  de la map (Brume V2). Images de référence : `C:\Users\ADMIN\Downloads\MAP_V17_Transfert\03_Images\` (vues numérotées,
  version V21m de la map).
- **Échelle** : réaliste et fixe — **BMW M4 = 22 studs, 1 m = 4,59 studs** ; l'avatar fait 6,48 studs (avatar « grand »).
  Détail : `C:\Users\ADMIN\Downloads\Station_Tycoon_Echelle_22\LISEZMOI_Echelle_22_studs.md`.
- **UI** : interface **en images** rendue depuis la maquette d'un « designer » (autre IA) : bandeaux verts, cartes blanches
  arrondies, police **Nunito** (ExtraBold / SemiBold), accents dorés (Shop, rang), couleur par rareté
  (Common gris 170,170,175 · Uncommon vert 80,200,110 · Rare bleu 60,140,240 · Epic violet 165,85,225 · Legendary or 245,185,40
  · Mythic rouge 235,65,65 · Divine bleu très pâle 215,235,250). Maquette de référence :
  https://claude.ai/artifact/Dn2U5tfYXJ8cZzTq1Vocvb — captures dans `StationTycoon_transfert_v24.zip` → `4_apercus/`.
- **Superpositions de jeu** (modes Circulation / Décoration, tutoriel) : plaques **mates et pâles**, jamais de Neon
  (demande de Thomas) : vert 150,205,140 · bleu 140,175,225 · rouge 220,110,100, transparence 0,45.
- **Ambiance sonore** : musique de fond « firefly lullaby » (rbxassetid://124724787424208, volume 0,15), moteur, klaxon
  « poit poit » du fourgon, sons des stations.
- **Cinématiques** : caméra cinématique du fourgon à chaque livraison ; découverte de la GT3 « dans l'espace » avec saut en
  hyperespace (esprit « space edit » TikTok, selon la carte du projet).

### 1.5 Fonctionnalités prévues, par ordre de priorité

Ordre validé par Thomas pour le lot v55 (tout est **codé mais pas testé**, voir § 3) : 1 entrée/sortie déplaçables → 2 trajets
de voitures lisses → 3 modes Circulation / Décoration de la nouvelle UI → 4 rangs + panneau du tunnel → 5 enchères au centre →
6 panneaux publicitaires → 7 chaîne M4 réajustée → 8 cinématique GT3 plus courte.

Ensuite (backlog, ordre proposé, à faire valider par Thomas) :
1. Finir la v55 dans Studio : import des panneaux pub, import des 116 images + 2 sons de l'UI v24, tests, publication par Thomas.
2. Monétisation Robux : identifiants des produits (voitures par rareté, argent, Game Pass) à créer par Thomas.
3. Contenu débloqué par rang (`Rank[i].Debloque` est vide ; seul le champ `Rang` des panneaux pub est utilisé).
4. Onglet « Ma station » (note Propreté / Rapidité / Accueil / Décoration) + métier « Agent d'entretien » (bouton présent,
   non codé).
5. Anciennes tâches jamais terminées : conduite réaliste « voiture rare qui accélère si la voie est libre » ; audit sécurité
   des Remotes + UI manette/téléphone ; audit et optimisation de la map ; nouvelles idées de stations ; prix d'embauche
   (aujourd'hui gratuit).

---

## 2. ORGANISATION DU TRAVAIL

### 2.1 Le rôle de cette conversation (« passerelle »)

Thomas fait travailler **plusieurs IA séparées** ; cette session « CODE » était le **lead dev** qui intègre tout dans le jeu :

| Domaine | Qui produit | Ce qui arrive ici | Ce que la passerelle renvoie |
|---|---|---|---|
| **Map** | « IA map » (autre session Claude, Blender → FBX par script) | Paquets `MAP_V17_Transfert` en zips `MAP_V21x_PartieN_sur7_…zip` + `PROMPT_TRANSFERT.md` (versions V17 → V21l intégrées ; V21m présente sur le PC, non intégrée) | Prompts de demande (ex. `PROMPT_V21k_segments_trottoir_branche.md`, `Prompt_transfert_chaine_echelle_22.md`, dossier `Station_Tycoon_Echelle_22`) |
| **UI** | « designer » (autre session Claude, maquette HTML → images) | `StationTycoon_images_v21.zip`, `StationTycoon_import_v23.zip`, `StationTycoon_UI_complet.zip`, `StationTycoon_transfert_v24.zip` + `LISEZMOI.md` | Rien de formel ; on suit son guide d'intégration : https://claude.ai/code/artifact/1312b99a-a17b-40c7-ad35-5c38b6750f10 |
| **Stations & animations** | une autre session (ses fichiers `StationPneusE5*.lua`… datent des 25–26/09) | `jeux.rbxl` (système Stations côté client), `louiss.rbxl` (anciennes stations serveur), `Transfert_Animations.zip` | — |
| **Chaîne de production** | IA map (modèle `ChaineProduction_M4_9` dans le FBX de la map) | intégrée au FBX V21 | prompt de remise à l'échelle |
| **Effets** (foudre, or/argent) | une autre session (incertain) | `Foudre_1.zip`, `Foudre_2.zip`, `Transformation_Or_Argent.zip` | — |
| **Modèles 3D de Thomas** | Thomas | `camion.obj/.mtl`, `CamionA_Cartons_1.fbx` + `Camion_A_Cartons_1.rbxl`, `PACK_10_3_1.fbx` (constructions), `PANNEAUX_PUB_VIERGES_1.fbx` | — |
| **Code / intégration** | **cette session** | — | `Station_Tycoon_vNN.rbxl` dans Téléchargements |

Ordre habituel d'une itération :
1. Thomas envoie sa demande (souvent une longue liste) et/ou un paquet d'une autre IA.
2. Je pose les questions **en QCM, une par une** (AskUserQuestion) si nécessaire.
3. Je code **hors ligne** dans l'espace cloud de la session (pipeline ci-dessous) et je construis `Station_Tycoon_vNN.rbxl`.
4. Livraison : le fichier est envoyé dans la conversation et écrit dans `C:\Users\ADMIN\Downloads`.
5. **Seulement si Thomas l'autorise**, je prends le contrôle du PC (Roblox Studio) : ouvrir la place, importer les FBX /
   images (sous son compte), tester en Play, enregistrer une nouvelle base.
6. Thomas publie lui-même (Fichier → Publier sur Roblox sous… → Station tycoon → Remplacer).

### 2.2 Le pipeline de build (espace cloud de la session — **éphémère**)

Ce pipeline tournait dans le conteneur cloud (Linux) de cette session, qui disparaîtra avec elle. **Une copie complète est
sauvegardée dans `C:\Users\ADMIN\Downloads\StationTycoon_transfert_CODE\3_pipeline\`** (scripts, générateurs, sources Rust de
`merger` / `validator`, données de la map V21l nécessaires, fichiers générés, sources de travail `Integration_Stations\`,
binaires Linux de `luau-analyze`) ; mode d'emploi et chemins à adapter : `3_pipeline\LISEZMOI_PIPELINE.md`. Il faut Linux ou
WSL. On peut aussi se passer du pipeline et modifier les scripts directement dans Studio. Principe :

- **Base** : une place enregistrée par Thomas dans Studio, map importée et installée (meshes réels). Base actuelle :
  `place_base_v11.rbxl` = **`C:\Users\ADMIN\Downloads\Station_Tycoon_v54_base.rbxl`** (même MD5, 5 544 412 octets).
- `build_place2.sh` : lance les générateurs puis un outil maison en Rust (`merger`) qui **remplace la source** des scripts
  existants (`--source=Chemin/Dans/Explorer=fichier.lua`), **insère** des `.rbxmx` (`--insert=Service=fichier.rbxmx`),
  remplace `StarterGui` par l'arbre UI du designer (`v24_images.rbxlx`) et écrit `jeu_v2.rbxl` ; un `validator` vérifie.
  Commande utilisée pour la v55 : `MAPDIR=V21l SORTIE=jeu_v55.rbxl ./build_place2.sh`.
- Générateurs Python : `gen_foudre.py` (enveloppe les nouveaux scripts en `.rbxmx`), `map/gen_map_v21.py` (+ `map/routes.py`,
  `map/raster_fbx.py`) → `Workspace/PlotSpawns` et `ServerStorage/RoutesAmbiance`, `gen_constructions.py` (pack PACK_10_3 →
  catalogues Sol/Mur/Plafond), `gen_ui_v24.py` (branche les identifiants d'images dans l'UI).
- Contrôle syntaxique : `luau-analyze`. Tests hors ligne de la circulation : `tests/test_circulation.lua` (69 tests, verts en v40).

### 2.3 Outils, plugins, skills, connecteurs

- **Roblox Studio** (interface **en français**) sur le PC de Thomas. Plugin présent : **Texture Painter** (sa fenêtre se
  ré-ancre à chaque Play : la fermer). `InstallerStations_Plugin.rbxmx` (27/09) existe dans Téléchargements : je ne sais pas
  s'il est installé comme plugin.
- **Application Claude desktop (Cowork)** : pont « remote-devices » vers le PC : shell Linux sur le dossier connecté
  (`~/mnt/Downloads`), transfert de fichiers, **contrôle de l'écran** (captures + clics) pour piloter Studio.
- **Blender** : serveur MCP local « Blender » connecté sur le PC ; skill **`roblox-3d-creator`** (Blender → GLB optimisé
  Roblox : studs, ≤ 20 000 triangles, un seul matériau). Utilisé par les sessions « modèles 3D », pas par celle-ci.
- **Google Drive** (connecteur) : utilisé une fois pour lire un document Google de la map (tâche n° 5).
- Claude in Chrome : disponible, pas d'usage notable dans ce projet.
- **Pas de clé Open Cloud** (règle de Thomas) : tout upload d'asset passe par Studio, sous son compte.

### 2.4 Préférences et règles de Thomas

- **Langue française**, tutoiement. Réponses courtes quand il demande « t'en es où ? ».
- **Questions en QCM, une par une** (il a refusé un lot de questions d'un coup ; dans ce cas on avance avec les valeurs par défaut).
- **« stop » = arrêter immédiatement de toucher au PC.**
- Pour le lot en cours : **« Seulement quand tout sera prêt, tu pourras prendre contrôle de mon PC. »**
- Il ne veut pas de longues sessions de test (« je veux pas de test, pourquoi autant de temps ») et : « quand tout est mis,
  pas besoin de republier, dis-moi juste ».
- **Économie et sécurité côté serveur** (le client n'est jamais cru).
- **Seul son compte** importe les assets ; le jeu reste **privé** ; **c'est lui qui publie**.
- Règles du designer UI (à respecter) : ne renommer / déplacer / supprimer **aucun** objet de l'UI (le script y accède par
  chemin) ; **jamais de CanvasGroup** (fondus via `fadeFrame` / `setFaded`) ; **ne pas modifier les images** (tout changement
  visuel passe par la maquette) ; touche **M** = ouvrir / fermer l'interface.
- Règle de l'IA map : intégrer la map **sans la remodeler**. Thomas a dit (v55) que **les routes de la map ne changeront plus**.
- **Pas de messages au centre de l'écran** (toasts désactivés depuis v49).
- Conventions de nommage : builds `Station_Tycoon_vNN.rbxl`, bases `…_vNN_base.rbxl`, sauvegardes de scripts
  `Fichier.vNN.bak`, identifiants en français **sans accents** (`Acces`, `Demi`, `Tutoriel`, `Cinematiques`), notes de version
  « vNN : … » en tête et dans les commentaires des scripts ; catalogue : stations `L1_Vide…E7_Teinte`, sols `sol_*`, murs
  `mur_<famille>_<matiere>`, toits `toit_*`, panneaux `PUB_n_NOM`.

---

## 3. ÉTAT ACTUEL, DOMAINE PAR DOMAINE

### 3.1 CODE

#### 3.1.1 Architecture générale

- **Serveur** : `DataManager` (Script) charge le profil (ProfileService), appelle `PlayerData.Init`, gère le choix du plot
  (`ChoosePlotfunction`), construit le plot (`PlotManager.SpawnPlot`), démarre les voitures (`CarManager`), le tutoriel, et
  `require` les modules optionnels (`Diagnostic`, `Monetisation`). `FunctionScript` (Script) répond aux RemoteFunctions de
  construction. Les autres scripts serveur sont des **ModuleScripts** appelés par ceux-là.
- **Client** : `StarterGui/UIController` (LocalScript, ~1 530 lignes) pilote toute l'UI et `require` les modules client de
  `StarterPlayerScripts` (`ClientBuild`, `ClientData`, `ClientCamera`, `ClientStaff`, `ClientSupply`, `ActionManager`,
  `ClientDiagnostic`). Les animations de voitures/PNJ sont jouées par `TWEENController` à partir d'événements serveur.
- **Données partagées** : `ReplicatedStorage/Catalogue/*` (prix, masques, raretés, rangs), `ReplicatedStorage/Demi`
  (demi-grille), `ReplicatedStorage/Stations/*` (système des stations animées).
- Origine : la base du tycoon vient de `Thomas good luck 1.rbxl` (PlotManager, PlayerData, CarManager, ClientBuild…, auteur
  inconnu) ; le système de stations animées vient de `jeux.rbxl`. Tout a été très largement réécrit depuis.

#### 3.1.2 Liste des scripts de `Station_Tycoon_v55.rbxl`

**ServerScriptService**

| Script | Type | Rôle |
|---|---|---|
| `DataManager` | Script | Profils (ProfileService, magasin `TycoonData_Prod_V38`, clé `Player_<UserId>`), modèle de profil, choix du plot, lancement du tutoriel si `Tutoriel ~= true`, masque le nom Roblox au-dessus de la tête (v55), BindToClose |
| `FunctionScript` | Script | Placefunction (vérifie le prix, appelle `PlotManager.Place`, renvoie la raison du refus), Deplacerfunction (créée ici), Destroyfunction, etc. |
| `AdminCommands` | Script | Commandes chat réservées à l'UserId 1558910815 (liste en § 7.4) |
| `CarAmbiance` | Script | Voitures d'ambiance qui sortent des 4 usines (synchronisées sur la chaîne), 4 tours de l'anneau central, puis sortie de map ; **achat aux enchères** (v55, via `Enchere`) |
| `Lancement` | Script | Au démarrage : installe la map si besoin, refait l'herbe (`InstallerHerbe`) ; v55 : **remonte les 4 chaînes** si l'attribut `ChainesVersion` de la map ne correspond pas à l'échelle des données |
| `MapAlignement` | Script | Recale le jeu sur la map importée (attribut `Workspace.DecalageMap`, référence lue dans `DonneesArbres`) |
| `Mutations` | Script | Mutations rares (foudre / or / argent) toutes les 240–540 s ou par commande ; visuel côté client |
| `PortesSas` | Script | Portes coulissantes des sas des usines (fourni par l'IA map) |
| `RobotStock` | Script | Robots de stock au plafond des hangars (fourni par l'IA map, V21i) |
| `PlayerData` | ModuleScript | Données en mémoire du joueur : argent, XP, grille (`Grid`), annexe, demi-grilles, stations, caisses, inventaire, index, **rang** (`GetRank` → rang, probabilités), attributs du joueur (`MajAttributs`), file de récupération des voitures |
| `PlotManager` | ModuleScript | Grille du plot (cases de 15), pose / déplacement / suppression (grille 15 et demi-grille 7,5), annexe, extensions, terrain (herbe 3 états), bordures de goudron (clone de la bordure des trottoirs de la map), aperçu du plot pour l'écran-titre, contrôles v55 : rang requis, objet unique, orientation imposée, annexe seulement, sans sol |
| `CarManager` | ModuleScript | Cycle de vie des voitures clientes (CAR_QUEUE → FIND_STATION → WAITING_SERVICE → FIND_CAISSE → QUEUE_CAISSE → COMPLETED → WAIT_EXIT → EXIT, ou PASSE), PNJ piétons, paiement, XP, index, service manuel (touche E), cinématique de découverte, trajets continus `AnimationTrajetCar` (v55), **cadence par rang × pub × décoration** (v55) |
| `Circulation` | ModuleScript | Couloirs de goudron : la voiture est un bloc 2×2 cases, BFS sur les blocs, murs, plusieurs entrées / sorties, chemin piéton (1 case) vers la caisse, prise en compte de la demi-grille |
| `Acces` | ModuleScript | **Entrée (bord de la branche) et sortie (bord de la route du tour) déplaçables** : nœuds `Entree`, `QueueNodes`, `AchatNodes`, `ExitNodes`, `Passage`, tabliers, segments de trottoir masqués, rampes ; RemoteFunction `AccesFunction` ; mémorisé dans `data.Acces` |
| `Livraison` | ModuleScript | Fourgon de livraison (voie de gauche, coupe le rond-point, dérapages), garage du plot, déchargement des cartons (`CamionCartons`), cinématique client à chaque livraison |
| `WorkerManager` | ModuleScript | Embauche / affectation / licenciement ; uniformes ; salaires 12 / 7 / 10 $/min ; poste « Automatic » |
| `StoreManager` | ModuleScript | Achat de consommables (volume max 600 L + meubles de stockage), remplissage des stations |
| `Tutoriel` | ModuleScript | Tutoriel v53 : plot de départ pré-construit, PNJ ItsCirly, étapes accueil/plot/voiture/arrivee/laver/suivre/depart/vitrine/fin via `TutorielEvent` ; `/tutoriel` le rejoue |
| `Diagnostic` | ModuleScript | v55 : analyse des modes **Circulation** (vert / bleu / rouge barré) et **Décoration** (malus des stations et du stockage, bonus du décor) ; `DiagnosticFunction` ; multiplicateurs de cadence (pub, déco) |
| `Enchere` | ModuleScript | v55 : enchères des voitures du centre (E = acheter / surenchérir ×1,5, tours de 10 s, panneau « clash », étoiles + « Achetée par … » 3 s ; F = achat Robux) |
| `Monetisation` | ModuleScript | v55 : `ProcessReceipt` (produits voitures par rareté, argent), possession des Game Pass ; **identifiants tous à 0** |
| `FoudreServeur`, `MetalServeur` | ModuleScript | Désignent la voiture qui mute (le visuel est côté client) |
| `ProfileService` | ModuleScript | Bibliothèque ProfileService (Madwork), non modifiée |

**ServerStorage**

| Objet | Type | Rôle |
|---|---|---|
| `InstallerMap` | ModuleScript | Installe la map (collisions, arbres, copies, verre, eau, plots, herbe, véhicules, portes des sas) — fourni par l'IA map + « crochets » ajoutés par moi (`patch_installer.py`) |
| `DonneesCollisions`, `DonneesArbres` | ModuleScript | Données de la map V21l (IA map) |
| `InstallerHerbe` | ModuleScript | Herbe Terrain à chaque lancement (~0,3 s) |
| `InstallerChaines` | ModuleScript | Monte les 4 chaînes de production (Motor6D, animations) |
| `InstallerTout` | ModuleScript | Map + chaînes + constructions d'un coup |
| `InstallerVoirie` | ModuleScript | Ancien (V17e), conservé |
| `Installer_Constructions` | ModuleScript | Installe les vrais meshes du pack PACK_10_3 (sols, murs, toits, décor) |
| `RoutesAmbiance` | ModuleScript | Trajets générés (ambiance, achat → plot, livraison, garages) |
| `CamionCartons` | Script **désactivé** | Script de Thomas copié dans le fourgon par `Livraison` (normal qu'il soit désactivé ici) |
| `AnimationsStations`, `RBX_ANIMSAVES` | Folder | KeyframeSequences sources des animations (déjà publiées) |
| `ARBRES_V17`, `Camion`, `Van`, `TallVan`, `CamionCartons_Modeles` | Modèles | Bibliothèques de la map et du fourgon |

**ReplicatedStorage**

| Script | Type | Rôle |
|---|---|---|
| `Catalogue` + `Car`, `Consommable`, `Extension`, `Furniture`, `Rank`, `Sol`, `Mur`, `Plafond` | ModuleScripts | Données de jeu (voir § 7) |
| `Demi` | ModuleScript | Demi-grille 7,5 studs : `Cle`, `CaseDe`, `Centre`, `CaseMere`, `Cases`, `Ajuster` (réduit un modèle à 94 % de son masque) |
| `Stations/Client`, `Montage`, `Outils`, `Voiture`, `Reglages`, `Sons`, `Effets`, `Categories` | ModuleScripts | Système des stations animées ; `Reglages` contient les 14 identifiants d'animations publiées le 28/09 |
| `Stations/Comportements/Chaine, E4, E5, E6, E7, L3, L4, Simple` | ModuleScripts | Comportement visuel par station ; `Chaine` = chaîne de production (v55 : réduit les translations des animations ×22/36) |
| `Stations/Donnees/*` (12 modules) | ModuleScripts | Points et joints générés ; `ChaineProduction` remis à l'échelle de la chaîne M4_9 en v55 |
| `Foudre/Effet, Reglages` ; `Metal/Effet, Reglages` | ModuleScripts | Effets des mutations |

**StarterPlayer / StarterPlayerScripts**

| Script | Type | Rôle |
|---|---|---|
| `TWEENController` | LocalScript | Anime voitures et PNJ (Bézier) ; v55 : `jouerTrajet` (trajet continu, ralenti en virage, dérapage/roulis continus, roues détectées par géométrie) |
| `ClientCinematique` | LocalScript | Cinématique de découverte de la GT3 (v55 : ~8 s) |
| `ClientLivraison` | LocalScript | Caméra cinématique du fourgon |
| `ClientTutoriel` | LocalScript | Partie client du tutoriel (caméra, dialogues, plaques vertes / bleues) |
| `ClientService` | LocalScript | Touche E près d'une station → `ServiceManuelEvent` |
| `ClientRang` | LocalScript | v55 : badge « pseudo + rang en couleur » au-dessus des têtes ; panneau des taux de spawn au-dessus du tunnel (< 80 studs) |
| `StationsClient` | LocalScript | Lance `ReplicatedStorage/Stations/Client` |
| `FoudreClient`, `MetalClient` | LocalScript | Visuel des mutations |
| `Course` | LocalScript | Courir (Maj / L3 / bouton mobile) ×1,8 (fourni par l'IA map) |
| `ClientBuild` | ModuleScript | Fantôme de pose, pose en série au glisser, rotation R, déplacement, laser de suppression, grille et demi-grille, glisser de l'entrée/sortie, rafraîchit le diagnostic |
| `ClientCamera` | ModuleScript | Caméra libre du mode construction |
| `ClientData` | ModuleScript | Copie locale du profil (`InitialData`, `UpdateClientData`), `GetRank`, `CountTier` |
| `ClientDiagnostic` | ModuleScript | v55 : plaques des modes Circulation / Décoration |
| `ClientStaff`, `ClientSupply`, `ActionManager` | ModuleScript | Panneaux d'affectation, remplissage, mode courant |

**StarterGui** : `UIController` (LocalScript) + `UIController/Sounds` (ModuleScript) ; petits scripts du designer
`Main/Root/MENUS/Build/Build` (+ `BuildData`), `Main/Root/MENUS/Staff/Staff`, `Menu/Choose/Hero/Car/DriveData` (données).

#### 3.1.3 RemoteEvents / RemoteFunctions

Présents dans la place (`ReplicatedStorage`) : `Placefunction`, `Destroyfunction`, `Extensionfunction`, `Buyfunction`,
`FillStationfunction`, `Hirefunction`, `Firefunction`, `Assignfunction`, `UnAssignfunction`, `ChoosePlotfunction`,
`GetGridClient` (RemoteFunction) ; `InitialData` (profil envoyé à la connexion), `UpdateClientData` (mise à jour d'un champ),
`MoveCarEvent`, `MovePnjEvent`, `LivraisonEvent`, `Foudre/FoudreSol` (RemoteEvent) ;
`ServerStorage/CamionCartons/Declencher` et `Termine` (BindableEvent).

Créés à l'exécution par les scripts : `Deplacerfunction` (FunctionScript), `AccesFunction` (Acces), `DiagnosticFunction`
(Diagnostic), `TutorielEvent` (Tutoriel), `ServiceManuelEvent` et `CinematiqueEvent` (CarManager) ; côté client
`ClientData.OnDataChanged` et `ClientData.Ready` (BindableEvent).

#### 3.1.4 Sauvegarde des données

- ProfileService, magasin **`TycoonData_Prod_V38`**, clé `Player_<UserId>`.
- Champs du modèle : `Tutoriel`, `Money` (3 000 au départ), `Xp`, `Extensions` (droit1..3, haut1..3), `Inventory`,
  `Livraisons`, `Stations`, `Caisses`, `Garage`, `Workers`, `Index` (par rareté), `Grid`.
- Champs ajoutés à l'exécution : `Annexe`, `Demi`, `DemiAnnexe` (demi-grilles, clé `"hx_hz"`), `Acces` (`{entree, sortie}`),
  `Cinematiques`, `Cree` (date de création → attribut `Day`), `RecoveryQueue`.
- Attributs posés sur le joueur (lus par l'UI) : `Money`, `XP`, `Rank`, `RankIndex` (v55, 1..7), `XPNext`, `Day`, `Alerte`.
- **Point incertain** : la grille est passée de cases de 10 à 15 studs en v48 sans migration ni changement de nom de magasin ;
  je ne sais pas si les profils sauvegardés avant v48 ont été remis à zéro (la carte v51 listait « remise à zéro des
  sauvegardes (grille 10 → 15) » comme « à venir »).

#### 3.1.5 Ce qui marche (vérifié) et ce qui est buggé ou non testé

Vérifié en jeu (Studio) dans les versions précédentes :
- v53 : **tutoriel** complet testé avec Thomas (plots de type A et B) ; service manuel E.
- v54 : construite et ouverte dans Studio ; d'après l'historique des tâches, tests de l'accès par goudron, d'une caisse en
  demi-grille, du tutoriel et du camion. (Thomas a ensuite demandé d'arrêter les longs tests.)
- v40 : 69 tests hors ligne de `Circulation` verts ; v39 : menus de l'UI v23 OK ; v38 : chaînes animées, cinématique du
  fourgon, herbe ; ces points n'ont pas été re-testés après les changements suivants.

**Tout le lot v55 est codé, compile (`luau-analyze` sans erreur bloquante) et est construit, mais n'a JAMAIS été lancé en jeu** :
entrée/sortie déplaçables restaurées (version v53 + nœuds `Passage`), trajets continus, bordures de goudron clonées de la map,
comblement de l'herbe entre goudron et trottoir, modes Circulation / Décoration, rangs, panneau du tunnel, enchères, panneaux
pub, chaîne M4 réajustée, GT3 8 s, cadence par rang.

Bugs / limites connus :
- **Roues fantômes** restées dans la station après un lavage manuel (signalé, non corrigé).
- **Sons du tutoriel** absents (non fournis).
- **Toasts désactivés** (`TOASTS = false` dans UIController) : les raisons de refus (rang requis, « déjà posé »,
  « uniquement dans l'annexe »…) et les messages des modes Circulation / Décoration **ne s'affichent pas** ; seule la carte du
  menu Construction affiche « 🔒 dès le rang … » / « déjà posé ».
- **UI v24 sans ses nouvelles images** (voir § 3.3) : fenêtres Rangs, Shop et Ma station vides, voiture animée du menu
  invisible, pastilles d'onglet actif invisibles, art v23 sous les boutons v24.
- **Panneaux pub** : les modèles `PUB_*` ne sont **pas encore dans** `ReplicatedStorage/Furniture` → leurs cartes affichent
  « bientôt » tant que le FBX n'est pas importé.
- Fenêtre Rangs du designer : **8 rangs** (Bronze I … Diamant) alors que le jeu en a **7** (Bronze → Légende).
- Le commentaire d'en-tête de `Circulation` parle encore de cases de 10 studs (le code utilise 15).
- `ReplicatedFirst` contient un `ScreenGui` avec un `CanvasGroup` (origine non vérifiée ; la règle du designer interdit les
  CanvasGroup dans l'UI).
- Embauche gratuite (risque économique noté dans `ECONOMIE.md`, non tranché).
- Anciennes tâches ouvertes non revérifiées : affichage du stock (Stock/Supply), test complet des mutations.

### 3.2 MAP

- **Version intégrée dans le jeu : V21l** (IA map, 03/10). Fichier importé : `C:\Users\ADMIN\Downloads\MAP_V21l\MAP_MOTIFS_V17_AVEC_CHAINES.fbx`
  (le nom garde « V17 » pour ne rien casser) + `ARBRES_V17.fbx`. Paquet complet V21l : `C:\Users\ADMIN\Downloads\MAP_V21l_Partie1_sur7_…zip`
  à `…Partie7…zip`. Document de l'IA map pour la V21l (toutes les cotes) + `plots_joueurs.json` / `chaines_production.json` :
  copiés dans `StationTycoon_transfert_CODE\3_pipeline\map\V21l\MAP_V17_Transfert\`.
- **Attention : une version plus récente, V21m, existe sur le PC et n'a JAMAIS été intégrée** (elle n'a pas été envoyée à
  cette conversation ; je l'ai découverte en rédigeant ce document). Le dossier `C:\Users\ADMIN\Downloads\MAP_V17_Transfert\`
  contient désormais la **V21m**, et `C:\Users\ADMIN\Downloads\MAP_V17_Parties\` ses 7 zips. Nouveauté annoncée par l'IA map :
  « le quadrillage orange des plots remonte jusqu'au bout de la sortie prolongée : 42 colonnes au lieu de 27 (U jusqu'à 420
  studs), les cases au-delà de U = 270 étant limitées par le virage puis la diagonale de la route du tour » (plots de 42 × 48
  cases de 10 studs, 1 787 valides). À décider avec Thomas (voir § 6.3).
- **Échelle** : 1 unité = 1 stud, Y vers le haut, centre (0,0,0). **Map carrée de 2 369,4 studs** (demi-côté 1 184,7).
  Hauteurs : herbe Y = 0 ; chaussée Y = 0,57 ; trottoirs Y = 1,27.
- **Voirie** : chaussée 50 studs (2 × 25, une file par sens à 12,5 de l'axe), trottoirs 15,9 (bordure 2 + dalles) ; conduite à
  droite (le fourgon de livraison roule volontairement à gauche).
- **Structure** : rond-point central (chaussée rayon ext. 177,9) avec monument ; 4 usines + chaînes `ChaineProduction_M4_9`
  (275,6 × 83,2 studs) centrées à ±235,9 ; 4 avenues ; 4 ronds-points extérieurs centrés à ±516 ; **route du tour** d'axe ±516 ;
  4 **branches** à ±174,7 de l'axe des avenues jusqu'aux **tunnels** (bouche à 1 036,9 du centre) ; 8 cours de livraison avec
  quais (portes 13 × 13), hangars (racks, robot de stock) ; garages ; brume au bord.
- **8 plots** de **270 × 480 studs** (`Workspace/PlotSpawns/Plot1..8`, type A ou B en miroir). Grille du jeu : **18 colonnes ×
  32 rangées de cases de 15 studs** ; grille de départ **18 × 11** ; extensions `droit1..3` (+3 rangées chacune : 3 000 /
  8 000 / 25 000 $) et `haut1..3` (+4 rangées chacune, à partir de 30 000 $). Case (x, z) centrée en ((x−0,5)·15, (z−1)·15) dans
  le repère de `PlotCenter`. Cases interdites au coin du carrefour. **Annexe** 30 × 30 studs (2 × 2 cases, 4 × 4 demi-cases) de
  l'autre côté de la branche : sols, murs, décor, panneaux pub ; ni station ni caisse.
- **Entrée / sortie** : l'entrée est sur le bord **branche** (segments `Trottoir_PlotN_B_00..31`), la sortie sur le bord
  **route du tour** (segments `Trottoir_PlotN_00..33`, 18–33 au-delà du bout du plot) ; le jeu masque les segments choisis et
  pose traversée + rampes. Positions par défaut (`Acces.DEFAUT`) : type A {entrée 4, sortie 10}, type B {4, 8}.
- **Workspace** de la place v55 : `MAP_MOTIFS_V17_AVEC_CHAINES` (Model, ~8 200 objets, contient le dossier `Collisions`),
  `PlotSpawns` (Plot1..8 : PlotCenter, Annexe, PlayerSpawn, Camera, Tunnel, TypeA, AttenteAchat, ExitNodesFixe,
  CasesInterdites), `Plots` (plots des joueurs créés en jeu, « <Nom>'s plot »), `PortesSas`, `Vehicules` (24 véhicules + 56
  lumières de garage), `Brume`, `CielCreme`, `Depart` (SpawnLocation), `Terrain`, `TempStorage`.
- **Particularité de l'import Studio** : Studio agrandit le FBX de la map ×1,28 et le tourne de 180°. Correction (barre de
  commandes), sur le modèle importé `m` :
  ```lua
  m:ScaleTo(m:GetScale()/1.28); m:PivotTo(m:GetPivot()*CFrame.Angles(0,math.pi,0))
  ```
  puis translater le modèle pour que la pièce `Sol_Herbe_0_0` soit à `DonneesArbres.reference.position` (−888.53, 0, 888.53),
  puis `require(game.ServerStorage.InstallerMap)()`. Il faut d'abord supprimer l'ancienne map, et la bibliothèque
  `ARBRES_V17` doit être dans ServerStorage. La sortie d'InstallerMap ne défile pas toute seule dans Studio.
  (Le code exact de la translation n'a pas été conservé.)
- **Reste à faire côté map** : rien de demandé à l'IA map à ce jour ; anciennes tâches « audit visuel de la map » et
  « optimisation (identique visuellement) » jamais faites.

### 3.3 UI

Arbre UI = celui du designer **v24** (`StationTycoon_v24.rbxlx`), avec le `UIController` réécrit/câblé par moi
(ne pas utiliser celui du designer tel quel : il est en mode « maquette » sans serveur).

| Écran | Emplacement | État |
|---|---|---|
| Chargement | `StarterGui/Loading` | Branché ; pré-rendu de tous les panneaux derrière l'écran de chargement |
| Écran-titre « Ta partie » | `StarterGui/Menu/Choose` (Hero, Tiles, News, NewsDrop, Player, PlotView) | Branché (aperçu 3D du plot sauvegardé, Continuer) ; voiture animée du menu passée à 30 i/s mais **planches `Drive30_*` non importées → invisible** |
| Choix de l'emplacement | `StarterGui/Start/Choose` | Branché (caméra de chaque PlotSpawn, son « schling ») |
| Barre du bas + HUD | `Main/Root/HUD/HUD1` (BarArt, Low1 Money/Rank, Low2 Build/Stock/Supply/Staff/Station/Index/Shop) | Branché (argent, XP, rang en chiffres romains selon `RankIndex`) ; boutons Station et Shop actifs mais **dessinés seulement après import des images v24** |
| Construction | `Main/Root/MENUS/Build` (Left : Furniture/Utility/Deco/Floor/Wall/Roof ; Top : Move/Delete/Path/Deco/Rotate/Place/Cancel/Close) | Branché ; ouvre sur « Stations » ; **Path = mode Circulation, Deco = mode Décoration** (v55) ; verrou de rang sur les cartes |
| Stock | `MENUS/Stock` | Branché (familles, quantités, prix, livraison) |
| Rayons (Supply) | `MENUS/Supply` | Branché (remplissage des stations) |
| Personnel (Staff) | `MENUS/Staff` (CenterHire Attendant/Cashier/Logistics/Cleaner) | Branché pour 3 métiers ; **Cleaner (Agent d'entretien) non codé** |
| Index | `MENUS/Index` | Branché (12 voitures, filtres par rareté) |
| Ma station | `MENUS/Station` | Onglet ouvert/fermé, **image fixe, aucun système derrière** |
| Shop | `MENUS/Shop` (Tabs T0..T2, Hits GamePass/Money/Cars/Buy1..4/Close) | Branché sur MarketplaceService ; **table `SHOP` de UIController à 0** (« Article bientôt disponible ») |
| Rangs & Récompenses | `MENUS/Ranks` (Sel/S0..S7, Hits/Rank1..8, Close) | Branché (ouvre sur le rang du joueur) ; **images non importées** ; 8 entrées pour 7 rangs |
| Badge de rang | BillboardGui `BadgeRang` sur la tête (ClientRang) | Codé v55 |
| Panneau du tunnel | BillboardGui `TauxSpawn` sur `PlotSpawns/PlotN/Tunnel` (ClientRang) | Codé v55 |

**Images** : les images v23 (73 + 3 sons) sont en ligne sur le compte (liste nom → ID : `C:\Users\ADMIN\Downloads\Station_Tycoon_v23_IDs.txt`).
**Les 116 images + 2 sons v24** (`StationTycoon_transfert_v24.zip` → `2_a_importer/`) **ne sont pas encore importées**. En
attendant, la v55 réutilise l'image v23 du même nom (72 emplacements, ancien visuel) et laisse **42 emplacements à 0** :
`BuildMode_deco`, `BuildMode_path`, `Drive30_0..7`, `Rangs0..7_00/01`, `Shop0..2_00/01`, `Staff_01`, `Station_00`, `Supply_01`,
`TabActive_Build/Index/Staff/Station/Stock/Supply`, `TabInactive_Supply`. La table de correspondance est en § 7.1.

Sons (`StarterGui/UIController/Sounds`) : `engine` 103483259110286, `klaxon` 126229048818711, `schling` 91923071122458,
`musique` 124724787424208 ; **vides** : `hyper`, `moteurGT3`, `clac` (cinématique GT3) — à fournir par Thomas.

### 3.4 MODÈLES 3D

Contraintes techniques retenues : 1 unité FBX = 1 stud ; **une seule texture par MeshPart** (sinon l'import Roblox mélange
les textures : les pièces multi-matériaux sont découpées `Nom`, `Nom__Materiau2`…) ; maillages > 2048 studs → bug d'échelle ×1,28
à l'import ; pour les nouveaux modèles faits dans Blender, le skill `roblox-3d-creator` vise ≤ 20 000 triangles, un seul
matériau, export GLB. Les modèles du pack de constructions (10 studs) sont agrandis ×1,5 par le code (cases de 15).

| Modèle | Fichier source | Dans la place ? | Remarques |
|---|---|---|---|
| Map V21l (sol, voirie, bâtiments, usines + 4 chaînes M4_9) | `Downloads\MAP_V21l\MAP_MOTIFS_V17_AVEC_CHAINES.fbx` | Oui (base v11) | IA map |
| Arbres (27 modèles, ~380 copies) | `ARBRES_V17.fbx` | Oui (`ServerStorage/ARBRES_V17`) | IA map |
| Véhicules de garage `Van`, `TallVan`, `Camion` | `CAMIONS_V17.rbxm` (dans le paquet map) | Oui (ServerStorage + 24 copies ×1,25) | modèles de Thomas |
| Fourgon à cartons `CamionA` + script `CamionCartons` | `Downloads\CamionA_Cartons_1.fbx`, `Camion_A_Cartons_1.rbxl` | Oui (`ReplicatedStorage/CamionA`) | Thomas |
| Camion provisoire | `Downloads\Camion\camion.obj` | Oui (`ReplicatedStorage/Camion`) | Thomas |
| 11 stations (L1–L4, E1–E7) | `jeux.rbxl` | Oui (`ReplicatedStorage/Furniture`), agrandies ×1,5 (45 studs) | autre session |
| Caisses `1` (tapis), `2` (automatique), stockage `3` (pile de cartons), `4` (rayonnage) | base du tycoon | Oui | masques en demi-cases depuis v54 |
| Pack de constructions (28 sols, 175 murs, 13 toits, barrières, plantes, cartons, rayonnage) | `PACK_10_3_1.fbx` (upload du 27/09 ; sur le PC : `Downloads\PACK_10_3 (1).fbx`, même taille 17 033 260 octets) | Oui (`ReplicatedStorage/Sol`, `Mur`, `Plafond`, `Furniture`) via `Installer_Constructions` | |
| 12 voitures clientes (Clio4, Golf2, Golf, Volvo240, Mercedes, Dodge, M4, ClassG, Urus, GT3, F448, Follie) | dossier `VoituresModeles` copié de `jeux.rbxl` (créateur des modèles non retracé) | Oui (`ReplicatedStorage/VoituresModeles`) | remises à leur longueur réelle au démarrage (`Car.Longueur`) ; l'ancien dossier `ReplicatedStorage/Car/<rareté>` de la base existe encore |
| PNJ `PnjTemplateBoy/Girl`, employés `AttendantTemplate`, `CashierTemplate` | base | Oui | |
| Consommables `Products/1..9` | base | Oui | |
| **9 panneaux publicitaires** `PUB_1_PANCARTE` … `PUB_9_TOTEM` | **`Downloads\PANNEAUX_PUB_VIERGES_1.fbx`** | **Non** (à importer) | tailles 2,53 × 3,59 × 0,45 (Pancarte) à 19,62 × 20,48 × 2,82 (Totem) ; la texture `panneaux_vierges.png` référencée par le FBX **manque** (un fichier `Pub1pancarte1_diff.png` existe dans Téléchargements, rôle non confirmé) |
| Cartons / rayonnages extraits du pack | `Downloads\Stockage_Cartons_Rayonnages.fbx` / `.zip` (02/10) | — | extraits par moi du PACK_10_3 ; usage final non retracé |
| Voitures « packs » récents (AMG_GTR_Pack, Urus_Pack, M4_Pack, GT3RS_Pack, McLarenP1_Pack, Wrangler_Pack, Golf2_Pack…, `*_roues.blend`, `GEO13_voitures_claude.rbxm`, images Meshy AI) | Téléchargements, 02–04/10 | **Non** | faits par **une autre session**, hors de cette conversation : je n'ai aucune trace d'une demande d'intégration |

---

## 4. FICHIERS

### 4.1 Le jeu

- **Place à jour : `C:\Users\ADMIN\Downloads\Station_Tycoon_v55.rbxl`** (copie aussi dans `C:\Users\ADMIN\Downloads\Claude outputs\`).
- Base de construction (map V21l installée, sans le code v55) : `C:\Users\ADMIN\Downloads\Station_Tycoon_v54_base.rbxl`.
- **Jeu publié** : expérience Roblox « Station tycoon », **privée**, compte thamary4. Identifiant d'expérience / de place :
  **non retrouvé**. Dernière publication **certaine** : v38 (nuit du 29 au 30/09, en privé) ; je ne sais pas quelles versions
  Thomas a publiées ensuite. Une place « cloud » en Team Create existait (deux fenêtres bloquées sur « Application des
  modifications apportées au script » le 30/09).
- **Sources `.lua` à jour** : les 99 scripts de la place v55, extraits tels quels, sont dans
  `C:\Users\ADMIN\Downloads\StationTycoon_transfert_CODE\1_scripts_v55\` (index : `INDEX.md`). Les copies de travail
  (identiques pour les scripts du jeu, plus les sauvegardes `.vNN.bak` et quelques fichiers hors place) sont dans
  `…\3_pipeline\Integration_Stations\`. Les `.lua` du dossier `Claude outputs` sont des versions anciennes (sauf ceux datés du
  04/10 : `ClientDiagnostic`, `ClientRang`, `Diagnostic`, `Enchere`, `Monetisation`, `PlayerData`, `Rank`).

### 4.2 Fichiers livrés par cette conversation (tous dans `C:\Users\ADMIN\Downloads\`)

Les doublons `…_1`, `…_2` sont des téléchargements répétés du même fichier par l'application.

| Fichier(s) | Contenu |
|---|---|
| `Station_Tycoon_v4.rbxl` … `Station_Tycoon_v55.rbxl` | Builds successifs du jeu (v4 le 27/09 → v55 le 04/10) |
| `Station_Tycoon_v36_pre.rbxl`, `_v49_pre`, `_v52_pre`, `_v54_pre(.rbxl/_1)` | Builds intermédiaires |
| `Station_Tycoon_base_v5/v6/v7(_pre, _pre2).rbxl`, `Station_Tycoon_base_v7Station_Tycoon_base_v8.rbxl` (= base v8, nom concaténé par erreur), `Station_Tycoon_v49_base.rbxl`, `Station_Tycoon_v52_base.rbxl`, `Station_Tycoon_v54_base.rbxl` | Bases enregistrées dans Studio après import de la map |
| `Station_Tycoon_v54_preStation_Tycoon_v54_base.rbxl` | Erreur de « Enregistrer sous » (nom concaténé) = copie de la base v54 ; supprimable |
| `Station_Tycoon_map_corrigee.rbxl` | Première place recalée sur la map V17 (27/09) |
| `Jeu_integre_stations.rbxl` … `_21.rbxl` | Premières intégrations des stations (27/09) |
| `Patch_v40.rbxmx` … `Patch_v48.rbxmx` + `appliquer_patch.lua` | Patchs à insérer dans la place cloud puis appliquer par la barre de commandes (méthode abandonnée après v48) |
| `Recap_nuit_30-09.md` | Récapitulatif de la nuit du 29–30/09 (v38 publiée, v40 prête, bug Circulation) |
| `Station_Tycoon_v23_IDs.txt` | Noms → identifiants Roblox des 73 images + sons UI v23 |
| `Demo_Foudre*.rbxl`, `Demo_Effets*.rbxl` | Démos des effets foudre / or-argent (28–29/09) |
| `Foudre_medias\`, `Metal_medias\` | Textures et sons des effets (à importer / importés) |
| `Map_V17_4\` | Copie des FBX de la map V17_4 |
| `MAP_V21l\` | FBX de la map V21l importé dans Studio |
| `Station_Tycoon_Echelle_22\` | Dossier « échelle M4 = 22 studs » (LISEZMOI, tailles des véhicules, plans, rendus) envoyé à l'IA map |
| `PROMPT_V21k_segments_trottoir_branche.md` | Demande à l'IA map : segments de trottoir côté branche |
| `Entree_mobile\` | 2 images explicatives de l'entrée déplaçable |
| `Rendus\` | Rendus des algorithmes de circulation et des employés |
| `UI_v21\` | Images UI v21 |
| `Stockage_Cartons_Rayonnages.fbx/.zip` | Cartons et rayonnages extraits du pack |
| `Camion\camion.obj/.mtl` | Copie du camion de Thomas |
| `Claude outputs\` | Dossier géré par l'application Claude (mélange cette session et d'autres sessions) |

Fichiers reçus de Thomas / des autres IA (dans Téléchargements, pour mémoire) : `louiss.rbxl`, `Thomas good luck.rbxl`,
`jeux.rbxl`, `PACK_10_3_1.fbx`, `MAP_V17_*`, `MAP_V21j_*`, `MAP_V21l_Partie1..7_sur7_*.zip`, dossiers `MAP_V17_Parties*` et
`MAP_V17_Transfert*` (versions archivées `_ancien_Vxx`), `StationTycoon_*.zip`, `StationTycoon_v21.rbxlx`,
`StationTycoon_v23.rbxlx`, `LISEZMOI.md` (UI v24), `StationTycoon_transfert_v24.zip`, `PANNEAUX_PUB_VIERGES(_1).fbx`,
`CamionA_Cartons(_1).fbx`, `Camion_A_Cartons(_1).rbxl`, `firefly lullaby - counterfeit tycoon ost.mp3`.

### 4.3 Dossier de transfert `C:\Users\ADMIN\Downloads\StationTycoon_transfert_CODE\`

| Chemin | Contenu |
|---|---|
| `00_LISEZMOI.md` | Mode d'emploi du dossier |
| `transfert-roblox.md` | Copie de ce document |
| `1_scripts_v55\` | Les 99 scripts de `Station_Tycoon_v55.rbxl` (`.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript), rangés comme dans l'Explorer ; `INDEX.md` = chemin, type, nombre de lignes, en-tête |
| `2_documents\` | `GUIDE_INSTALLATION.md` (intégration des stations, 27/09), `ECONOMIE.md`, `Recap_nuit_30-09.md`, `Echelle_22\` (échelle M4 = 22 studs, tailles des véhicules), `PROMPT_V21k_segments_trottoir_branche.md`, `Prompt_transfert_chaine_echelle_22.md`, `Station_Tycoon_v23_IDs.txt/.json`, `Carte_Station_Tycoon_v51.html` (carte interactive du projet à l'état v51), `historique_des_taches.txt` (64 tâches de la session), `resume_conversation_avant_04-10.txt` (résumé automatique des échanges jusqu'au 04/10), `arbre_explorer_v55.txt` (arbre de la place), `remotes_dans_la_place_v55.txt`, `UIController_designer_v24_original.lua` (version « maquette » du designer, pour comparaison) |
| `3_pipeline\` | Pipeline de build : `build_place2.sh`, `gen_*.py`, `map\` (générateur des PlotSpawns et trajets + données V21l), `gen\` (fichiers générés), `merger\` et `validator\` (sources Rust), `tests\` (tests de Circulation), `outils_luau\` (luau-analyze Linux), `Integration_Stations\` (sources de travail + `.bak`, `Archive_Tempete\`, `Map\`, `Foudre\`, `Metal\`, `Camion\`, `Sons\`), `v24_images.rbxlx` ; mode d'emploi : `LISEZMOI_PIPELINE.md` |

Non copiés (déjà sur le PC ou inutiles) : la base `place_base_v11.rbxl` (= `Downloads\Station_Tycoon_v54_base.rbxl`), les
anciennes bases v3–v10, les builds, le zip de l'UI v24 et le FBX des panneaux (déjà dans Téléchargements), les patchs v40–v48,
les gros fichiers d'animations déjà présents dans la place.

---

## 5. DÉCISIONS ET HISTORIQUE

### 5.1 Chronologie résumée (d'après l'historique des tâches et les notes des scripts)

- **26–27/09** : analyse de `louiss.rbxl` / `Thomas good luck 1.rbxl` ; intégration des 11 stations animées de `jeux.rbxl`
  dans le tycoon ; pack de constructions PACK_10_3 ; première map (V17) ; trajets tunnel → plot → sortie et voitures
  d'ambiance ; annexe ; correction des pivots ; v4.
- **28/09** : v5 → v23 (corrections en série) ; 14 animations publiées (IDs dans `Stations/Reglages`) ; démos foudre / or-argent.
- **29/09** : mutations (v24/v25) ; module `Circulation` (v26) ; économie (argent de départ 3 000 $) ; map V17m (base v7) ;
  fourgon à cartons + cinématique (v36) ; v38 **publiée en privé**.
- **30/09** : UI v23 intégrée (v39/v40) ; correction du bug « aucune voiture n'entre » ; échelle **M4 = 22 studs** (v41) ;
  patchs v40–v48 ; UI fidèle à la maquette (v42–v45) ; terrain à 3 états (v47).
- **01/10** : **grille de 15 studs** (v48) ; map V21 (v49 : camion voie de gauche, carte goudron, toasts supprimés) ;
  cinématique GT3 (v50).
- **02/10** : entrée sur la branche + accès déplaçables + règles « étape par étape » (v51) ; v52 ; **tutoriel ItsCirly** (v53).
- **03/10** : map **V21l** (base v11) ; **demi-grille 7,5** ; accès « implicites » par le goudron ; animation du camion (v54).
- **04/10** : lot **v55** (voir § 1.5) ; build livré.

### 5.2 Décisions importantes et pourquoi

1. **Construire hors ligne puis livrer un `.rbxl`** plutôt qu'éditer dans Studio : reproductible et rapide ; Studio sert
   seulement aux imports d'assets (compte de Thomas) et aux tests.
2. **Échelle M4 = 22 studs (1 m = 4,59 studs)**, choisie par Thomas sur des rendus 16 / 20 / 22 / 24 : réaliste par rapport à la
   voirie de la map ; toutes les voitures gardent leurs proportions réelles (`Car.LONGUEUR_M4`, un seul nombre à changer).
3. **Grille de 15 studs** (v48) : avec des voitures de 22 studs, les cases de 10 étaient trop étroites ; le pack (10 studs) est
   agrandi ×1,5.
4. **Argent de départ 3 000 $** (`ECONOMIE.md`) : sol + station L1 + caisse tapis + stockage + produits ≈ 1 950 $ + marge.
5. **Entrée sur la branche, sortie sur la route du tour, toutes deux déplaçables** (v51). En v54 on a essayé des **accès
   implicites** (le goudron posé au bord ouvre le trottoir) ; **Thomas a préféré revenir en v55 aux objets Entrée/Sortie
   déplaçables** (glisser le long du bord, ouverture de 2 cases, trottoir refermé à l'ancienne place, bitume rempli).
6. **Règles de Thomas (v51)** : la voiture est bloquée étape par étape (rien n'est calculé d'avance) ; une station accueille dès
   qu'elle existe (v53 : même sans employé, lavage manuel E) ; sans stock la voiture attend ; sans caisse accessible le client
   attend (plus de départ sans payer) ; la voiture ne repart que s'il existe un couloir de 2 cases vers la sortie.
7. **Demi-grille 7,5 studs** pour les petits meubles et le décor (v54) ; caisse = 3 × 1 demi-cases ; stations 45 × 45 studs
   (masque 3 × 3 cases ; modèle 45 × 37,5).
8. **Pas de messages au centre de l'écran** (v49, non prévus dans la maquette).
9. **Herbe** : 3 états de terrain, bande rase de **5 studs** autour des sols (Thomas : 3 ne suffisait pas).
10. **Fourgon** : roule à gauche, coupe le rond-point à contresens, dérape ; **cinématique à chaque livraison**.
11. **Cinématique GT3** : dans l'espace, sans route (Thomas) ; v55 : même séquence en ~8 s au lieu de ~14, saut en hyperespace
    et flash conservés.
12. **Rangs** : 7 noms donnés par Thomas ; seuils, critères et probabilités **proposés par moi** (à valider).
13. **Enchères** ×1,5 par tour de 10 s, il faut être près de la voiture ; achat Robux par produit développeur par rareté.
14. **Panneaux pub** : annexe seulement, face à la sortie du tunnel, sans sol, tailles en demi-cases, déblocage par rang, effet
    = plus de clients (jusqu'à ×2 avec les 9).
15. **Chaîne de production** : d'abord voitures gardées à 36 studs (« maquettes géantes », `ECHELLE_VOITURE = 36/22`), puis
    la map V21 a apporté une chaîne réduite **M4_9** ; en v55 les données de la chaîne ont été ramenées ×22/36 (vérifié : les
    centres `CP_Tapis` et `CP_Usine` recalculés tombent exactement sur ceux du FBX M4_9) car les voitures traversaient les murs.

### 5.3 Essayé puis abandonné

- **Tempête / météo** (`Meteo`, `MeteoClient`, `FoudreHasard`) : archivée, remplacée par les **mutations** rares (raison exacte
  non conservée).
- **Patchs `.rbxmx` + script d'application** (v40–v48) pour la place cloud Team Create : plus utilisés ensuite.
- **Accès implicites par le goudron** (v54) : remplacés par les accès déplaçables (v55).
- **Messages « toast »** au centre de l'écran : supprimés (v49).
- **Bout de goudron surélevé avec flèche** à l'entrée des plots : supprimé.
- **UI v17 / v18 / v21** : remplacées successivement par v23 puis v24.
- Le code v51 qui exigeait un employé pour entrer : la voiture passait son chemin → remplacé par le service manuel (v53).

### 5.4 Problèmes rencontrés et solutions

| Problème | Solution |
|---|---|
| Tous les plots et trajets décalés de 3,48 studs | `MapAlignement` lisait la référence de l'ancienne map → lue dans `DonneesArbres` (v38) |
| « Les clients ne peuvent pas entrer » | `Circulation` comparait le nom du sol sans enlever le suffixe `#orientation` (v40) |
| Pivots des constructions décalés | `PivotOffset` sur la pièce principale (le PrimaryPart ignorait le WorldPivot) |
| Import FBX de la map ×1,28 et tourné de 180° | Correction en Lua (§ 3.2) |
| Animations des chaînes / stations absentes en v36 | Remontage Motor6D + animations dans la base |
| Publication bloquée (fenêtres Team Create figées) | Fermer toutes les fenêtres Studio (Gestionnaire des tâches si besoin) |
| Tutoriel : la voiture passait sans entrer | `StationUtilisable` exigeait un employé → renvoie vrai |
| Tutoriel : invite E invisible / à 124 studs | Pièce invisible `InviteService` au pivot du meuble + billboard + secours touche E côté client |
| Tutoriel : PNJ flottant, images blanches, caméra masquée par le toit | Hauteur du toit d'après les pièces visibles ; attendre 35 studs de déplacement ; vue 3/4 haute |
| « Enregistrer sous » : noms de fichiers concaténés | Fichiers renommés par copie (les mauvais noms restent dans Téléchargements) |
| Lancement.lua écrasé par celui de l'IA map | Restauré depuis la sauvegarde |
| Studio : les touches ZQSD simulées ne bougent pas le personnage | Téléportation par la barre de commandes |
| Plugin Texture Painter qui se ré-ancre à chaque Play | Fermer sa fenêtre |
| Déconnexions du PC | Attendre que Thomas dise « vas-y » |
| **Non résolu** : roues fantômes après lavage manuel ; sons du tutoriel ; texture des panneaux pub | — |

---

## 6. SUITE

### 6.1 Tâche en cours au moment de l'arrêt

Le lot v55 est **entièrement codé et construit** ; `Station_Tycoon_v55.rbxl` est livré dans Téléchargements. J'ai écrit à
Thomas que la prochaine étape était de **prendre le contrôle de son PC quand il dirait OK** pour (1) importer le FBX des panneaux
pub, (2) importer les 116 images + 2 sons de l'UI v24 et relever leurs identifiants, (3) ouvrir la place v55. Thomas n'a pas
encore répondu à cette proposition (il a demandé ce document de transfert à la place).

### 6.2 Prochaines étapes, dans l'ordre

1. Avec l'accord de Thomas : ouvrir `C:\Users\ADMIN\Downloads\Station_Tycoon_v55.rbxl` dans Studio.
2. **Panneaux pub** : Accueil → Importer 3D → `PANNEAUX_PUB_VIERGES_1.fbx` ; ranger les 9 modèles dans
   `ReplicatedStorage/Furniture` sous les noms exacts `PUB_1_PANCARTE`, `PUB_2_CHEVALET`, `PUB_3_MONUMENT`, `PUB_4_PORTIQUE`,
   `PUB_5_ENSEIGNE`, `PUB_6_BIPODE`, `PUB_7_TREILLIS`, `PUB_8_MAT`, `PUB_9_TOTEM` ; vérifier l'échelle (studs), le pivot (même
   convention que les autres meubles de la demi-grille, ex. `barriere_arceau`) et que la **face** regarde bien la sortie du
   tunnel avec `OrientationFixe = 0` (hypothèse : modèle face +Z ; sinon changer `OrientationFixe` dans `Catalogue/Furniture`).
   Obtenir de Thomas la texture des panneaux.
3. **UI v24** : Studio → Contenus → Importer → les 116 images de `2_a_importer/images/` et les 2 sons ; relever les
   identifiants ; les écrire dans les `StringValue Src` / `Sel` (correspondance § 7.1), dans `DriveData.sheets` (8 planches
   `Drive30_0..7`) et dans `Sounds` (`engine` = moteur.ogg, `schling` = schling.ogg si Thomas veut remplacer les actuels).
4. **Tests en Play** (courts) : entrée/sortie (glisser, segments masqués), voiture qui entre/sort, trajets lisses, bordures,
   modes Circulation / Décoration, badge de rang, panneau du tunnel, enchère à deux joueurs (Studio : Test → 2 joueurs),
   chaîne M4 (voitures dans le hall, plus à travers les murs), cinématique GT3 (`/cinematique GT3`), tutoriel (`/tutoriel`).
5. Corriger, enregistrer, prévenir Thomas (il publie lui-même).
6. Monétisation : dès que Thomas donne les identifiants, remplir `Monetisation.PRODUITS` / `GAMEPASS` (serveur) et la table
   `SHOP` de `UIController` (client).
7. Puis le backlog du § 1.5.

### 6.3 Questions ouvertes / en attente de Thomas

- Identifiants Robux : 7 produits « voiture » (un par rareté), produits « argent », 4 Game Pass ; prix.
- Texture des panneaux publicitaires (`panneaux_vierges.png`) ; prix, rang requis et bonus de clients des panneaux (valeurs
  proposées, § 7.3).
- Validation des **rangs** (seuils d'XP, critères par rareté, probabilités, cadences, § 7.2) et du **contenu débloqué** par rang.
- Fenêtre Rangs : faire ré-exporter par le designer une version à **7 rangs** (Bronze, Argent, Or, Platine, Diamant, Maître,
  Légende) ?
- Sons de la cinématique GT3 (`moteurGT3`, `clac`, `hyper`) et du tutoriel.
- Intégrer la **map V21m** (plots prolongés jusqu'au bout de la sortie, 42 colonnes) ? Elle est sur le PC mais n'a jamais
  été envoyée ici ; le jeu est calé sur la V21l (grille 18 × 32 cases de 15).
- Intégrer les nouvelles voitures des « packs » faits dans une autre session ? (aucune demande dans cette conversation)
- Système « Ma station » + Agent d'entretien : règles à définir.
- Embauche payante ou plafonnée ?
- Remise à zéro des sauvegardes (grille 10 → 15) : faite ou à faire ? (`TycoonData_Prod_V38`)
- Vidéo de référence de la chaîne M4 (proposée en option).

---

## 7. ANNEXES (à recopier tel quel)

### 7.1 Correspondance emplacements UI → images (v24)

Chemins sous `StarterGui`. Chaque `ImageLabel` a une `StringValue` enfant `Src` (et `Sel` pour l'état sélectionné) que
`UIController` applique au démarrage (`o.Image = src.Value` si différent de `rbxassetid://0`).

```python
SRC = {
    "Loading/Root/Title/T0": "LoadTitle_00", "Loading/Root/Title/T1": "LoadTitle_01",
    "Menu/Choose/Tiles/T0": "Menu_00", "Menu/Choose/Tiles/T2": "Menu_10",
    "Menu/Choose/NewsDrop/T0": "MenuNews_00",
    "Menu/Choose/Hero/Car": "Drive30_3",
    "Main/Root/HUD/HUD1/BarArt/Bar0": "HUD_00", "Main/Root/HUD/HUD1/BarArt/Bar1": "HUD_01",
    "Main/Root/HUD/HUD1/BarArt/Inactive_Supply": "TabInactive_Supply",
    "Main/Root/MENUS/Build/Art/Base/T0": "Build_00", "Main/Root/MENUS/Build/Art/Base/T1": "Build_01",
    "Main/Root/MENUS/Staff/Art/Base/T0": "Staff_00", "Main/Root/MENUS/Staff/Art/Base/T1": "Staff_01",
    "Main/Root/MENUS/Staff/Art/Assign/T0": "StaffAssign_00",
    "Main/Root/MENUS/Stock/Art/Base/T0": "Stock_00",
    "Main/Root/MENUS/Supply/Art/Base/T0": "Supply_00", "Main/Root/MENUS/Supply/Art/Base/T1": "Supply_01",
    "Main/Root/MENUS/Station/Art/Base/T0": "Station_00",
}
for t in ("Build", "Stock", "Supply", "Staff", "Index", "Station"):
    SRC[f"Main/Root/HUD/HUD1/BarArt/Active_{t}"] = f"TabActive_{t}"
for c in ("sol", "murs", "stations", "utilitaires", "deco", "toit"):
    SRC[f"Main/Root/MENUS/Build/Art/Variants/V_{c}/T0"] = f"BuildStrip_{c}_00"
for m in ("move", "del", "path", "deco"):
    SRC[f"Main/Root/MENUS/Build/Top/Active_{m}"] = f"BuildMode_{m}"
for i in range(1, 10):
    SRC[f"Main/Root/MENUS/Stock/Art/Variants/V{i}/T0"] = f"StockR{i}_00"
    SRC[f"Main/Root/MENUS/Stock/Art/Center/{i}"] = f"StockRow_{i}"
    SRC[f"Main/Root/MENUS/Supply/Art/Center/{i}"] = f"SupplyCard_{i}"
for k in range(3):
    SRC[f"Main/Root/MENUS/Stock/Fams/F{k}/T0"] = f"StockFam{k}_00"
    SRC[f"Main/Root/MENUS/Supply/Fams/F{k}/T0"] = f"SupplyFam{k}_00"
    SRC[f"Main/Root/MENUS/Shop/Tabs/T{k}/T0"] = f"Shop{k}_00"; SRC[f"Main/Root/MENUS/Shop/Tabs/T{k}/T1"] = f"Shop{k}_01"
for k in range(8):
    SRC[f"Main/Root/MENUS/Ranks/Sel/S{k}/T0"] = f"Rangs{k}_00"; SRC[f"Main/Root/MENUS/Ranks/Sel/S{k}/T1"] = f"Rangs{k}_01"
SEL = {f"Main/Root/MENUS/Stock/Art/Center/{i}": f"StockRowSel_{i}" for i in range(1, 10)}
SEL.update({f"Main/Root/MENUS/Supply/Art/Center/{i}": f"SupplyCardSel_{i}" for i in range(1, 10)})
# + DriveData (Menu/Choose/Hero/Car/DriveData) : "sheets" = 8 x "rbxassetid://<Drive30_0..7>"
```

Les images déjà en ligne avant la v24 (ex. `IndexCard_*`, `LoadScene_*`, `Menu_01`, `Menu_11`, `Sprite_*`) ont leur identifiant
dans `3_toutes_les_images/ids.txt` du zip v24.

### 7.2 Rangs (`ReplicatedStorage/Catalogue/Rank`, v55 — valeurs proposées)

| Rang | Couleur (RGB) | XP min | Voitures servies requises | Probabilités Common/Uncommon/Rare/Epic/Legendary/Mythic/Divine | Cadence (s) |
|---|---|---|---|---|---|
| Bronze | 205,127,50 | 0 | — | 0,70 / 0,25 / 0,045 / 0,005 / 0 / 0 / 0 | 19 |
| Argent | 192,192,200 | 5 000 | Common 25, Uncommon 10, Rare 2 | 0,55 / 0,30 / 0,12 / 0,028 / 0,002 / 0 / 0 | 16 |
| Or | 255,200,40 | 25 000 | C 100, U 50, R 20, Epic 3 | 0,42 / 0,32 / 0,19 / 0,06 / 0,009 / 0,001 / 0 | 13 |
| Platine | 120,210,230 | 100 000 | C 300, U 200, R 100, E 30, Legendary 2 | 0,30 / 0,31 / 0,26 / 0,105 / 0,022 / 0,003 / 0 | 10,5 |
| Diamant | 110,170,255 | 500 000 | C 800, U 600, R 400, E 150, L 15, Mythic 1 | 0,20 / 0,27 / 0,32 / 0,165 / 0,038 / 0,0068 / 0,0002 | 8,5 |
| Maître | 190,90,255 | 3 000 000 | R 1 500, E 800, L 80, M 8, Divine 1 | 0,13 / 0,22 / 0,34 / 0,23 / 0,07 / 0,0094 / 0,0006 | 7 |
| Légende | 255,80,80 | 20 000 000 | E 4 000, L 400, M 40, D 5 | 0,08 / 0,17 / 0,33 / 0,29 / 0,11 / 0,0185 / 0,0015 | 6 |

Cadence réelle entre deux clients = `Spawn × (0,8 … 1,3 au hasard) / (multiplicateur pub × multiplicateur déco)` avec
pub = 1 + somme des `Clients` des panneaux posés (1 à 2) et déco = `clamp(1 + score/300, 0,85, 1,5)` (score = somme des cases
vertes + ¼ des cases rouges du mode Décoration ; malus des stations/stockage −3/−2/−1 aux rayons 1/2/3, bonus du décor +2/+1
aux rayons 1/2).

### 7.3 Panneaux publicitaires (`Catalogue/Furniture`, v55 — valeurs proposées)

Champs communs : `Famille = "pubs", Pub = true, Demi = true, SansSol = true, Annexe = true, Unique = true, OrientationFixe = 0`.

| Nom | Prix | Masque (demi-cases) | Part de clients | Rang requis |
|---|---|---|---|---|
| PUB_1_PANCARTE | 500 | 1×1 | 0,04 | Bronze |
| PUB_2_CHEVALET | 900 | 1×1 | 0,05 | Bronze |
| PUB_3_MONUMENT | 1 500 | 1×1 | 0,06 | Argent |
| PUB_4_PORTIQUE | 2 500 | 2×1 | 0,08 | Argent |
| PUB_5_ENSEIGNE | 4 000 | 2×1 | 0,10 | Or |
| PUB_6_BIPODE | 6 000 | 2×1 | 0,12 | Or |
| PUB_7_TREILLIS | 9 000 | 2×1 | 0,14 | Platine |
| PUB_8_MAT | 14 000 | 2×1 | 0,17 | Diamant |
| PUB_9_TOTEM | 25 000 | 3×1 | 0,24 | Maître |

Les 9 occupent 16 demi-cases = toute l'annexe (4 × 4).

### 7.4 Commandes admin (chat, UserId 1558910815 uniquement)

```
/money <n>                 ajoute (ou retire si négatif) de l'argent
/unlock <extension>        droit1..3, haut1..3
/give <item> [qte]         consommable
/livrer [qte] [item]       livraison
/animation camion          lance tout de suite la livraison (animation du fourgon)
/cinematique GT3           rejoue la cinématique de découverte sur la prochaine voiture
/mutation foudre|or|argent|stop
/goudron x0 z0 x1 z1       (test) pose du goudron
/poser <meuble> x z [o]    (test) pose un meuble du catalogue
/stock [qte] [item]        (test) remplit les stations
/acces [entree|sortie n]   état / déplacement de l'entrée (rangée) ou de la sortie (colonne)
/tutoriel                  rejoue le tutoriel d'ItsCirly
/aide
```

### 7.5 Enchères et Robux (v55)

- `Enchere` : `DUREE_TOUR = 10`, `MULT = 1.5`, `DISTANCE = 30`, `DUREE_ETOILES = 3` ; prix de base = `150 × Mult` de la rareté
  (`CarAmbiance.PRIX_BASE`). Invite **E** « Acheter / Surenchérir », invite **F** « Acheter en Robux ». L'argent n'est débité
  qu'à la fin du tour (si le meneur n'a plus l'argent, on remonte aux enchérisseurs précédents). Si une enchère est en cours au
  dernier tour d'anneau, la voiture fait jusqu'à 3 tours de plus.
- `Monetisation.PRODUITS.Voiture = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0, Divine = 0 }`,
  `PRODUITS.Argent = { [idProduit] = montant }` (vide), `GAMEPASS` (vide). Côté client, `UIController` : table `SHOP`
  (`GamePass`, `Money`, `Cars`, 4 identifiants chacun, tous à 0).

### 7.6 Commandes utiles dans la barre de commandes de Studio

```lua
require(game.ServerStorage.InstallerMap)()        -- installe la map (après import du FBX)
require(game.ServerStorage.InstallerChaines)()    -- monte les 4 chaînes de production
require(game.ServerStorage.InstallerTout)()       -- map + chaînes + constructions
```
