#!/bin/bash
# Pipeline v2 : la base est la place enregistree par Thomas dans Studio (map V17 importee + installee, meshes des murs,
# chaines montees). On n'y remplace QUE les sources des scripts (aucun modele n'est reinsere : les vrais meshes restent).
# Usage : ./build_place2.sh [base.rbxl]   (defaut : place_base_v4_propre.rbxl = base v3 + scripts v4 + pivots corriges via copypivots)
set -e
cd "$(dirname "$0")"
BASE=${1:-place_base_v11.rbxl}
G=$PWD/gen
O=/mnt/user-data/outputs/Integration_Stations
# map : MAPDIR (V21 par defaut, V21j...) choisit les donnees (gen_map) ; MAPSRC le dossier des scripts de la map
# (InstallerMap avec crochets, DonneesCollisions, DonneesArbres, PortesSas, Course[, RobotStock])
export MAPDIR=${MAPDIR:-V21j}
MAPSRC=${MAPSRC:-$O/Map}
SORTIE=${SORTIE:-jeu_v2.rbxl}
python3 gen_installer.py >/dev/null
(cd map && python3 gen_map_v21.py > /dev/null)
MAPSRC=$MAPSRC python3 gen_foudre.py >/dev/null
EXTRA=()
if [ -f "$MAPSRC/RobotStock.lua" ]; then EXTRA+=("--insert=ServerScriptService=$G/RobotStock.rbxmx"); fi
python3 gen_ui_v24.py
./merger/target/release/merger "$BASE" v24_images.rbxlx "$SORTIE" \
  "--source=StarterGui/UIController=$O/UIController.lua" "--source=StarterGui/UIController/Sounds=$O/Sounds.lua" \
  "--source=ServerScriptService/PlotManager=$O/PlotManager.lua" \
  "--source=ServerScriptService/PlayerData=$O/PlayerData.lua" \
  "--source=ServerScriptService/CarManager=$O/CarManager.lua" \
  "--source=ServerScriptService/DataManager=$O/DataManager.lua" \
  "--source=ServerScriptService/AdminCommands=$O/AdminCommands.lua" \
  "--source=ServerScriptService/FunctionScript=$O/FunctionScript.lua" \
  "--source=ServerScriptService/WorkerManager=$O/WorkerManager.lua" \
  "--source=ServerScriptService/StoreManager=$O/StoreManager.lua" \
  "--source=ServerScriptService/MapAlignement=$O/MapAlignement.lua" \
  "--source=ServerScriptService/CarAmbiance=$O/CarAmbiance.lua" \
  "--source=ServerStorage/InstallerChaines=$O/InstallerChaines.lua" \
  "--source=ServerStorage/InstallerTout=$O/InstallerTout.lua" \
  "--source=ServerStorage/InstallerMap=$MAPSRC/InstallerMap.lua" "--source=ServerStorage/DonneesCollisions=$MAPSRC/DonneesCollisions.lua" \
  "--source=ServerStorage/DonneesArbres=$MAPSRC/DonneesArbres.lua" "--source=ServerScriptService/Lancement=$O/Map/Lancement.lua" \
  "${EXTRA[@]}" \
  "--source=ServerStorage/Installer_Constructions=$G/Installer_Constructions.lua" \
  "--source=ServerStorage/RoutesAmbiance=$G/RoutesAmbiance.lua" \
  "--source=ReplicatedStorage/Catalogue/Furniture=$O/Furniture.lua" \
  "--source=ReplicatedStorage/Catalogue/Car=$O/Car.lua" \
  "--source=ReplicatedStorage/Catalogue/Consommable=$O/Consommable.lua" \
  "--source=ReplicatedStorage/Catalogue/Extension=$O/Extension.lua" \
  "--source=ReplicatedStorage/Catalogue/Sol=$G/Catalogue_Sol.lua" \
  "--source=ReplicatedStorage/Catalogue/Mur=$G/Catalogue_Mur.lua" \
  "--source=ReplicatedStorage/Catalogue/Plafond=$G/Catalogue_Plafond.lua" \
  "--source=StarterPlayer/StarterPlayerScripts/ClientBuild=$O/ClientBuild.lua" \
  "--source=StarterPlayer/StarterPlayerScripts/ClientCamera=$O/ClientCamera.lua" \
  "--source=StarterPlayer/StarterPlayerScripts/ClientSupply=$O/ClientSupply.lua" \
  "--source=StarterPlayer/StarterPlayerScripts/ClientStaff=$O/ClientStaff.lua" \
  "--source=StarterPlayer/StarterPlayerScripts/TWEENController=$O/TWEENController.lua" \
  "--source=StarterPlayer/StarterPlayerScripts/ClientData=$O/ClientData.lua" \
  "--source=StarterPlayer/StarterPlayerScripts/StationsClient=$O/StationsClient.lua" \
  --vider=Workspace/PlotSpawns "--insert=Workspace/PlotSpawns=$G/PlotSpawns.rbxmx" \
  "--source=ReplicatedStorage/Stations/Client=$O/Client.lua" \
  "--source=ReplicatedStorage/Stations/Reglages=$O/Reglages.lua" \
  "--source=ReplicatedStorage/Stations/Outils=$O/Outils.lua" \
  --delete=ReplicatedStorage/AnimationsTest_ASupprimer \
  "--insert=ServerStorage=$G/InstallerVoirie.rbxmx" "--insert=ServerStorage=$G/InstallerHerbe.rbxmx" \
  "--insert=ServerScriptService=$G/PortesSas.rbxmx" --delete=ServerScriptService/PortesUsine --delete=StarterPlayer/StarterPlayerScripts/PortesClient --delete=ServerStorage/InstallerBrume \
  "--insert=ReplicatedStorage=$G/Foudre.rbxmx" "--insert=ServerScriptService=$G/FoudreServeur.rbxmx" \
  "--insert=ServerScriptService=$G/Mutations.rbxmx" "--insert=StarterPlayer/StarterPlayerScripts=$G/FoudreClient.rbxmx" \
  "--insert=ReplicatedStorage=$G/Metal.rbxmx" "--insert=ServerScriptService=$G/MetalServeur.rbxmx" "--insert=StarterPlayer/StarterPlayerScripts=$G/MetalClient.rbxmx" \
  "--insert=ServerScriptService=$G/Circulation.rbxmx" "--insert=ServerScriptService=$G/Livraison.rbxmx" "--insert=ReplicatedStorage=$G/LivraisonEvent.rbxmx" "--insert=ServerStorage=$G/CamionCartons.rbxmx" "--insert=StarterPlayer/StarterPlayerScripts=$G/ClientLivraison.rbxmx" "--insert=StarterPlayer/StarterPlayerScripts=$G/ClientCinematique.rbxmx" "--insert=ServerScriptService=$G/Acces.rbxmx" "--insert=ServerScriptService=$G/Tutoriel.rbxmx" "--insert=StarterPlayer/StarterPlayerScripts=$G/ClientTutoriel.rbxmx" "--insert=StarterPlayer/StarterPlayerScripts=$G/ClientService.rbxmx" "--insert=ReplicatedStorage=$G/Demi.rbxmx" \
  "--insert=ServerScriptService=$G/Diagnostic.rbxmx" "--insert=StarterPlayer/StarterPlayerScripts=$G/ClientDiagnostic.rbxmx" "--insert=StarterPlayer/StarterPlayerScripts=$G/ClientRang.rbxmx" "--insert=ServerScriptService=$G/Enchere.rbxmx" "--insert=ServerScriptService=$G/Monetisation.rbxmx" \
  "--source=ReplicatedStorage/Catalogue/Rank=$O/Rank.lua" \
  "--source=ReplicatedStorage/Stations/Voiture=$O/Voiture.lua" \
  "--source=ReplicatedStorage/Stations/Montage=$O/Montage.lua" \
  "--source=ReplicatedStorage/Stations/Comportements/Chaine=$O/Chaine.lua" \
  "--source=ReplicatedStorage/Stations/Donnees/ChaineProduction=$O/Donnees_ChaineProduction.lua" \
  2>&1 | grep -v "^ajoute StarterGui\|^supprime StarterGui\|^source\|^vide"
./validator/target/release/validator "$SORTIE" place_v3.rbxlx | tail -2
cp "$SORTIE" "$O/Jeu_integre_stations.rbxl"
ls -la "$O/Jeu_integre_stations.rbxl"
