# Scripts de Station_Tycoon_v55.rbxl (extraits tels quels)

Convention de fichiers : `.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript. Les dossiers reproduisent l'Explorer de Roblox Studio ; un script qui a des scripts enfants a un dossier du même nom à côté de lui (ex. `ReplicatedStorage/Catalogue.lua` et `ReplicatedStorage/Catalogue/Car.lua`).

Pour remettre un script dans Studio : ouvrir le script au même chemin dans l'Explorer, tout sélectionner, coller le contenu du fichier.

| Chemin dans l'Explorer | Type | Lignes | Fichier | Première ligne d'en-tête |
|---|---|---|---|---|
| `ReplicatedStorage/Catalogue` | ModuleScript | 17 | `ReplicatedStorage/Catalogue.lua` | local Catalogue = {} |
| `ReplicatedStorage/Catalogue/Car` | ModuleScript | 72 | `ReplicatedStorage/Catalogue/Car.lua` | Catalogue / Car — voitures clientes du tycoon, par rarete. |
| `ReplicatedStorage/Catalogue/Consommable` | ModuleScript | 80 | `ReplicatedStorage/Catalogue/Consommable.lua` | Catalogue / Consommable |
| `ReplicatedStorage/Catalogue/Extension` | ModuleScript | 41 | `ReplicatedStorage/Catalogue/Extension.lua` | local Extension = { |
| `ReplicatedStorage/Catalogue/Furniture` | ModuleScript | 232 | `ReplicatedStorage/Catalogue/Furniture.lua` | Catalogue / Furniture |
| `ReplicatedStorage/Catalogue/Mur` | ModuleScript | 181 | `ReplicatedStorage/Catalogue/Mur.lua` | Catalogue Mur : genere depuis le pack de constructions PACK_10_3 (1 case = 10 studs). |
| `ReplicatedStorage/Catalogue/Plafond` | ModuleScript | 19 | `ReplicatedStorage/Catalogue/Plafond.lua` | Catalogue Plafond : genere depuis le pack de constructions PACK_10_3 (1 case = 10 studs). |
| `ReplicatedStorage/Catalogue/Rank` | ModuleScript | 70 | `ReplicatedStorage/Catalogue/Rank.lua` | Catalogue / Rank — v55 : les 7 RANGS du joueur (Thomas : Bronze, Argent, Or, Platine, Diamant, Maitre, Legende). |
| `ReplicatedStorage/Catalogue/Sol` | ModuleScript | 34 | `ReplicatedStorage/Catalogue/Sol.lua` | Catalogue Sol : genere depuis le pack de constructions PACK_10_3 (1 case = 10 studs). |
| `ReplicatedStorage/Demi` | ModuleScript | 126 | `ReplicatedStorage/Demi.lua` | Demi (ModuleScript, ReplicatedStorage) — v54 : DEMI-GRILLE DE 7,5 STUDS pour les petits meubles et la deco. |
| `ReplicatedStorage/Foudre/Effet` | ModuleScript | 533 | `ReplicatedStorage/Foudre/Effet.lua` | Foudre / Effet   (ReplicatedStorage > Foudre > Effet) - calcule chez chaque joueur, rien sur le serveur |
| `ReplicatedStorage/Foudre/Reglages` | ModuleScript | 44 | `ReplicatedStorage/Foudre/Reglages.lua` | Foudre / Reglages   (ReplicatedStorage > Foudre > Reglages) |
| `ReplicatedStorage/Metal/Effet` | ModuleScript | 415 | `ReplicatedStorage/Metal/Effet.lua` | Metal / Effet   (ReplicatedStorage > Metal > Effet) - calcule chez chaque joueur, rien sur le serveur |
| `ReplicatedStorage/Metal/Reglages` | ModuleScript | 42 | `ReplicatedStorage/Metal/Reglages.lua` | Metal / Reglages   (ReplicatedStorage > Metal > Reglages) |
| `ReplicatedStorage/Stations/Categories` | ModuleScript | 40 | `ReplicatedStorage/Stations/Categories.lua` | StationsCommun / Categories |
| `ReplicatedStorage/Stations/Client` | ModuleScript | 331 | `ReplicatedStorage/Stations/Client.lua` | Stations / Client   (lance par le LocalScript StationsClient, chez chaque joueur) |
| `ReplicatedStorage/Stations/Comportements/Chaine` | ModuleScript | 430 | `ReplicatedStorage/Stations/Comportements/Chaine.lua` | Comportement Chaine (chaine de production de voitures, decor) |
| `ReplicatedStorage/Stations/Comportements/E4` | ModuleScript | 92 | `ReplicatedStorage/Stations/Comportements/E4.lua` | Comportement E4 (bornes) : lumieres du bras, flash et etincelles a chaque contact, sons |
| `ReplicatedStorage/Stations/Comportements/E5` | ModuleScript | 186 | `ReplicatedStorage/Stations/Comportements/E5.lua` | Comportement E5 (changement de roues) : roues tenues par les bras, roues neuves dans les racks, sons |
| `ReplicatedStorage/Stations/Comportements/E6` | ModuleScript | 197 | `ReplicatedStorage/Stations/Comportements/E6.lua` | Comportement E6 (cabine de peinture) : jet de peinture, taches de peinture fraiche, nouvelle couleur, sons |
| `ReplicatedStorage/Stations/Comportements/E7` | ModuleScript | 124 | `ReplicatedStorage/Stations/Comportements/E7.lua` | Comportement E7 (teinte des vitres) : lumieres, vapeur, teinte des vitres qui suit le portique, sons |
| `ReplicatedStorage/Stations/Comportements/L3` | ModuleScript | 94 | `ReplicatedStorage/Stations/Comportements/L3.lua` | Comportement L3 (karcher au plafond) : jet d'eau, eclaboussures, sons |
| `ReplicatedStorage/Stations/Comportements/L4` | ModuleScript | 99 | `ReplicatedStorage/Stations/Comportements/L4.lua` | Comportement L4 (rouleaux) : eau, mousse, sons des brosses et des rouleaux contre la voiture |
| `ReplicatedStorage/Stations/Comportements/Simple` | ModuleScript | 73 | `ReplicatedStorage/Stations/Comportements/Simple.lua` | Comportement "Simple" : stations sans robot (L1, L2, E1, E2, E3) |
| `ReplicatedStorage/Stations/Donnees/ChaineProduction` | ModuleScript | 183 | `ReplicatedStorage/Stations/Donnees/ChaineProduction.lua` | Stations / Donnees / ChaineProduction   (genere automatiquement, puis ramene a l'echelle de la chaine M4_9 : x 22/36, v55) |
| `ReplicatedStorage/Stations/Donnees/E1_Base` | ModuleScript | 32 | `ReplicatedStorage/Stations/Donnees/E1_Base.lua` | Stations / Donnees / E1_Base   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/E2_Barils` | ModuleScript | 33 | `ReplicatedStorage/Stations/Donnees/E2_Barils.lua` | Stations / Donnees / E2_Barils   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/E3_Pompes` | ModuleScript | 33 | `ReplicatedStorage/Stations/Donnees/E3_Pompes.lua` | Stations / Donnees / E3_Pompes   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/E4_Bornes` | ModuleScript | 67 | `ReplicatedStorage/Stations/Donnees/E4_Bornes.lua` | Stations / Donnees / E4_Bornes   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/E5_Pneus` | ModuleScript | 636 | `ReplicatedStorage/Stations/Donnees/E5_Pneus.lua` | Stations / Donnees / E5_Pneus   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/E6_Peinture` | ModuleScript | 1480 | `ReplicatedStorage/Stations/Donnees/E6_Peinture.lua` | Stations / Donnees / E6_Peinture   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/E7_Teinte` | ModuleScript | 87 | `ReplicatedStorage/Stations/Donnees/E7_Teinte.lua` | Stations / Donnees / E7_Teinte   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/L1_Vide` | ModuleScript | 34 | `ReplicatedStorage/Stations/Donnees/L1_Vide.lua` | Stations / Donnees / L1_Vide   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/L2_Seaux` | ModuleScript | 34 | `ReplicatedStorage/Stations/Donnees/L2_Seaux.lua` | Stations / Donnees / L2_Seaux   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/L3_Karcher` | ModuleScript | 108 | `ReplicatedStorage/Stations/Donnees/L3_Karcher.lua` | Stations / Donnees / L3_Karcher   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Donnees/L4_Rouleaux` | ModuleScript | 154 | `ReplicatedStorage/Stations/Donnees/L4_Rouleaux.lua` | Stations / Donnees / L4_Rouleaux   (genere automatiquement : ne pas modifier) |
| `ReplicatedStorage/Stations/Effets` | ModuleScript | 86 | `ReplicatedStorage/Stations/Effets.lua` | StationsCommun / Effets |
| `ReplicatedStorage/Stations/Montage` | ModuleScript | 342 | `ReplicatedStorage/Stations/Montage.lua` | Stations / Montage   (utilise UNE FOIS dans Studio, par la barre de commande : voir MonterStations_Studio) |
| `ReplicatedStorage/Stations/Outils` | ModuleScript | 86 | `ReplicatedStorage/Stations/Outils.lua` | Stations / Outils |
| `ReplicatedStorage/Stations/Reglages` | ModuleScript | 35 | `ReplicatedStorage/Stations/Reglages.lua` | Stations / Reglages   (le seul fichier a modifier) |
| `ReplicatedStorage/Stations/Sons` | ModuleScript | 132 | `ReplicatedStorage/Stations/Sons.lua` | StationsCommun / Sons |
| `ReplicatedStorage/Stations/Voiture` | ModuleScript | 286 | `ReplicatedStorage/Stations/Voiture.lua` | Stations / Voiture   (cote joueur) |
| `ServerScriptService/Acces` | ModuleScript | 428 | `ServerScriptService/Acces.lua` | --[[ Acces (ModuleScript, ServerScriptService) — v51 / v55 : ENTREE et SORTIE DEPLACABLES du plot (demande de Thomas). |
| `ServerScriptService/AdminCommands` | Script | 281 | `ServerScriptService/AdminCommands.server.lua` | AdminCommands   (Script, ServerScriptService) |
| `ServerScriptService/CarAmbiance` | Script | 276 | `ServerScriptService/CarAmbiance.server.lua` | CarAmbiance (Script, ServerScriptService) — voitures d'ambiance du centre de la map (trace rouge de Thomas). |
| `ServerScriptService/CarManager` | ModuleScript | 1494 | `ServerScriptService/CarManager.lua` | local CarManager = {} |
| `ServerScriptService/Circulation` | ModuleScript | 409 | `ServerScriptService/Circulation.lua` | Circulation (ModuleScript, ServerScriptService) — les voitures ROULENT SUR LE PLOT sans traverser les objets. |
| `ServerScriptService/DataManager` | Script | 198 | `ServerScriptService/DataManager.server.lua` | local Players = game:GetService("Players") |
| `ServerScriptService/Diagnostic` | ModuleScript | 268 | `ServerScriptService/Diagnostic.lua` | Diagnostic (ModuleScript, ServerScriptService) — v55 : analyse du plot pour les modes CIRCULATION et DECORATION |
| `ServerScriptService/Enchere` | ModuleScript | 270 | `ServerScriptService/Enchere.lua` | Enchere (ModuleScript, ServerScriptService) — v55 : ACHAT AUX ENCHERES des voitures du centre (CarAmbiance). |
| `ServerScriptService/FoudreServeur` | ModuleScript | 149 | `ServerScriptService/FoudreServeur.lua` | FoudreServeur   (ModuleScript, ServerScriptService > FoudreServeur) |
| `ServerScriptService/FunctionScript` | Script | 125 | `ServerScriptService/FunctionScript.server.lua` | local Players = game:GetService("Players") |
| `ServerScriptService/Lancement` | Script | 59 | `ServerScriptService/Lancement.server.lua` | -- Lancement : Script (ServerScriptService). A chaque "Jouer", installe la map si ce |
| `ServerScriptService/Livraison` | ModuleScript | 583 | `ServerScriptService/Livraison.lua` | Livraison (ModuleScript, ServerScriptService) — le CAMION DE LIVRAISON du Stock (v36 : le van a cartons). |
| `ServerScriptService/MapAlignement` | Script | 59 | `ServerScriptService/MapAlignement.server.lua` | MapAlignement (Script, ServerScriptService) — recale le jeu sur la map V17 importee. |
| `ServerScriptService/MetalServeur` | ModuleScript | 69 | `ServerScriptService/MetalServeur.lua` | MetalServeur   (ModuleScript, ServerScriptService > MetalServeur) |
| `ServerScriptService/Monetisation` | ModuleScript | 91 | `ServerScriptService/Monetisation.lua` | Monetisation (ModuleScript, ServerScriptService) — v55 : produits developpeur et Game Pass (Robux). |
| `ServerScriptService/Mutations` | Script | 124 | `ServerScriptService/Mutations.server.lua` | Mutations (Script, ServerScriptService) — TRES RAREMENT, une voiture en circulation "mute" : |
| `ServerScriptService/PlayerData` | ModuleScript | 576 | `ServerScriptService/PlayerData.lua` | local ReplicatedStorage = game:GetService("ReplicatedStorage") |
| `ServerScriptService/PlotManager` | ModuleScript | 1279 | `ServerScriptService/PlotManager.lua` | local ReplicatedStorage = game:GetService("ReplicatedStorage") |
| `ServerScriptService/PortesSas` | Script | 54 | `ServerScriptService/PortesSas.server.lua` | -- PortesSas : Script (ServerScriptService). V18 : portes coulissantes automatiques des sas d'entree |
| `ServerScriptService/ProfileService` | ModuleScript | 2417 | `ServerScriptService/ProfileService.lua` | -- local Madwork = _G.Madwork |
| `ServerScriptService/RobotStock` | Script | 123 | `ServerScriptService/RobotStock.server.lua` | -- RobotStock : Script (ServerScriptService). V21i : robot automatique de gestion du stock au plafond des |
| `ServerScriptService/StoreManager` | ModuleScript | 130 | `ServerScriptService/StoreManager.lua` | local ServerScriptService = game:GetService("ServerScriptService") |
| `ServerScriptService/Tutoriel` | ModuleScript | 376 | `ServerScriptService/Tutoriel.lua` | Tutoriel (v53) — ModuleScript ServerScriptService |
| `ServerScriptService/WorkerManager` | ModuleScript | 326 | `ServerScriptService/WorkerManager.lua` | local WorkerManager = {} |
| `ServerStorage/CamionCartons` | Script (désactivé) | 423 | `ServerStorage/CamionCartons.server.lua` | CamionCartons  v2   (Script serveur, a mettre DANS le modele du camion) |
| `ServerStorage/DonneesArbres` | ModuleScript | 693 | `ServerStorage/DonneesArbres.lua` | -- DonneesArbres : arbres (copies de la bibliotheque ARBRES_V9), copies des |
| `ServerStorage/DonneesCollisions` | ModuleScript | 3438 | `ServerStorage/DonneesCollisions.lua` | -- DonneesCollisions : Parts de collision invisibles (genere par export_v9.py). |
| `ServerStorage/InstallerChaines` | ModuleScript | 84 | `ServerStorage/InstallerChaines.lua` | InstallerChaines (ModuleScript, ServerStorage) — monte les 4 chaines de production animees de la map V17. |
| `ServerStorage/InstallerHerbe` | ModuleScript | 102 | `ServerStorage/InstallerHerbe.lua` | InstallerHerbe (ModuleScript, ServerStorage) — v49 (map V21) : herbe en relief (Terrain Grass, brins animes) dans les |
| `ServerStorage/InstallerMap` | ModuleScript | 762 | `ServerStorage/InstallerMap.lua` | InstallerMap -- installation optimisee de la map (V18), a lancer UNE FOIS dans Studio. |
| `ServerStorage/InstallerTout` | ModuleScript | 24 | `ServerStorage/InstallerTout.lua` | InstallerTout (ModuleScript, ServerStorage) — tout installer d'un coup, une fois les FBX importes dans Workspace : |
| `ServerStorage/InstallerVoirie` | ModuleScript | 111 | `ServerStorage/InstallerVoirie.lua` | InstallerVoirie (ModuleScript, ServerStorage) — remplace la voirie de la map par la version V17e AVEC les |
| `ServerStorage/Installer_Constructions` | ModuleScript | 477 | `ServerStorage/Installer_Constructions.lua` | Installer_Constructions — installe les vrais meshes du pack de constructions (PACK_10_3) dans la place. |
| `ServerStorage/RoutesAmbiance` | ModuleScript | 971 | `ServerStorage/RoutesAmbiance.lua` | RoutesAmbiance : trajets des voitures d'ambiance (genere depuis la map V21, gen_map_v21.py). |
| `StarterGui/Main/Root/MENUS/Build/Build` | LocalScript | 1 | `StarterGui/Main/Root/MENUS/Build/Build.client.lua` | -- Catalogue dans BuildData ; TemplateBouton cloné par UIController |
| `StarterGui/Main/Root/MENUS/Build/Build/BuildData` | ModuleScript | 1 | `StarterGui/Main/Root/MENUS/Build/Build/BuildData.lua` | return game:GetService("HttpService"):JSONDecode([==[{"sol": [{"id": "sol_parquets", "name": "Parquets", "labels": ["Parquet clair", "Chêne doré", "Chevron", "P |
| `StarterGui/Main/Root/MENUS/Staff/Staff` | LocalScript | 1 | `StarterGui/Main/Root/MENUS/Staff/Staff.client.lua` | -- Template des rangées du personnel (cloné par UIController) |
| `StarterGui/Menu/Choose/Hero/Car/DriveData` | ModuleScript | 1 | `StarterGui/Menu/Choose/Hero/Car/DriveData.lua` | return game:GetService("HttpService"):JSONDecode([==[{"sheets": ["rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxa |
| `StarterGui/UIController` | LocalScript | 1529 | `StarterGui/UIController.client.lua` | UIController v12 (LocalScript, StarterGui) — interface en images (rendues depuis le canvas) + zones cliquables. |
| `StarterGui/UIController/Sounds` | ModuleScript | 21 | `StarterGui/UIController/Sounds.lua` | -- Sons de l'interface (UIController/Sounds). Seuls les vrais clics et les ouvertures/fermetures de menu font un son : |
| `StarterPlayer/StarterPlayerScripts/ActionManager` | ModuleScript | 26 | `StarterPlayer/StarterPlayerScripts/ActionManager.lua` | local ActionManager = {} |
| `StarterPlayer/StarterPlayerScripts/ClientBuild` | ModuleScript | 705 | `StarterPlayer/StarterPlayerScripts/ClientBuild.lua` | ClientBuild = {} |
| `StarterPlayer/StarterPlayerScripts/ClientCamera` | ModuleScript | 137 | `StarterPlayer/StarterPlayerScripts/ClientCamera.lua` | ClientCamera   (ModuleScript, StarterPlayerScripts) — camera libre du mode construction |
| `StarterPlayer/StarterPlayerScripts/ClientCinematique` | LocalScript | 507 | `StarterPlayer/StarterPlayerScripts/ClientCinematique.client.lua` | ClientCinematique (LocalScript, StarterPlayerScripts) — v50 (v55 : ~8 s, plus nerveuse) : cinematiques de DECOUVERTE d'une voiture. |
| `StarterPlayer/StarterPlayerScripts/ClientData` | ModuleScript | 182 | `StarterPlayer/StarterPlayerScripts/ClientData.lua` | local ClientData = {} |
| `StarterPlayer/StarterPlayerScripts/ClientDiagnostic` | ModuleScript | 159 | `StarterPlayer/StarterPlayerScripts/ClientDiagnostic.lua` | ClientDiagnostic (ModuleScript, StarterPlayerScripts) — v55 : modes CIRCULATION et DECORATION de l'onglet Construction. |
| `StarterPlayer/StarterPlayerScripts/ClientLivraison` | LocalScript | 142 | `StarterPlayer/StarterPlayerScripts/ClientLivraison.client.lua` | ClientLivraison (LocalScript, StarterPlayerScripts) — la CAMERA CINEMATIQUE du van de livraison. |
| `StarterPlayer/StarterPlayerScripts/ClientRang` | LocalScript | 135 | `StarterPlayer/StarterPlayerScripts/ClientRang.client.lua` | ClientRang (LocalScript, StarterPlayerScripts) — v55 : |
| `StarterPlayer/StarterPlayerScripts/ClientService` | LocalScript | 64 | `StarterPlayer/StarterPlayerScripts/ClientService.client.lua` | ClientService (v53) — LocalScript StarterPlayer/StarterPlayerScripts |
| `StarterPlayer/StarterPlayerScripts/ClientStaff` | ModuleScript | 207 | `StarterPlayer/StarterPlayerScripts/ClientStaff.lua` | local ClientStaff = {} |
| `StarterPlayer/StarterPlayerScripts/ClientSupply` | ModuleScript | 105 | `StarterPlayer/StarterPlayerScripts/ClientSupply.lua` | ClientSupply = {} |
| `StarterPlayer/StarterPlayerScripts/ClientTutoriel` | LocalScript | 798 | `StarterPlayer/StarterPlayerScripts/ClientTutoriel.client.lua` | ClientTutoriel (v53) — LocalScript StarterPlayer/StarterPlayerScripts |
| `StarterPlayer/StarterPlayerScripts/Course` | LocalScript | 50 | `StarterPlayer/StarterPlayerScripts/Course.client.lua` | -- Course : LocalScript a mettre dans StarterPlayer > StarterPlayerScripts. |
| `StarterPlayer/StarterPlayerScripts/FoudreClient` | LocalScript | 5 | `StarterPlayer/StarterPlayerScripts/FoudreClient.client.lua` | FoudreClient   (LocalScript, StarterPlayer > StarterPlayerScripts) |
| `StarterPlayer/StarterPlayerScripts/MetalClient` | LocalScript | 5 | `StarterPlayer/StarterPlayerScripts/MetalClient.client.lua` | MetalClient   (LocalScript, StarterPlayer > StarterPlayerScripts) |
| `StarterPlayer/StarterPlayerScripts/StationsClient` | LocalScript | 12 | `StarterPlayer/StarterPlayerScripts/StationsClient.client.lua` | StationsClient   (LocalScript, StarterPlayer > StarterPlayerScripts) |
| `StarterPlayer/StarterPlayerScripts/TWEENController` | LocalScript | 471 | `StarterPlayer/StarterPlayerScripts/TWEENController.client.lua` | TWEENController (LocalScript, StarterPlayerScripts) |
