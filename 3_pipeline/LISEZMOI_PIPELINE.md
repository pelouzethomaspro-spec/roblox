# Pipeline de build de Station Tycoon (copie de l'espace cloud de la session « CODE »)

Ce pipeline construisait chaque `Station_Tycoon_vNN.rbxl` **hors de Studio** : il part d'une place de base enregistrée par
Thomas dans Studio (map importée, meshes réels), remplace la source des scripts, insère les nouveaux scripts/modèles, remplace
l'interface par celle du designer, puis écrit une nouvelle place. Il tournait sous **Linux** ; sous Windows, utiliser **WSL**.
Il est facultatif : on peut aussi modifier les scripts directement dans Studio (copies exactes dans `..\1_scripts_v55\`).

## Prérequis

- Python 3 avec `numpy`, `Pillow`, `lz4`, `zstandard` (`pip install numpy pillow lz4 zstandard`).
- Rust (`cargo`) pour compiler les deux outils maison :
  `cd merger && cargo build --release` puis `cd validator && cargo build --release`
  (dépendances `rbx_binary` / `rbx_xml`, voir `Cargo.toml`).
- Facultatif : `outils_luau/luau_linux_x64.zip` (luau, luau-analyze, luau-ast, luau-compile pour Linux x64) pour vérifier la
  syntaxe : `./luau-analyze fichier.lua`.

## Chemins codés en dur à adapter (ils pointaient vers l'espace cloud)

| Fichier | Ligne | Valeur d'origine | À remplacer par |
|---|---|---|---|
| `build_place2.sh` | `O=` | `/mnt/user-data/outputs/Integration_Stations` | `$PWD/Integration_Stations` |
| `build_place2.sh` | `BASE=${1:-place_base_v11.rbxl}` | base v11 | copier `C:\Users\ADMIN\Downloads\Station_Tycoon_v54_base.rbxl` ici sous le nom `place_base_v11.rbxl` (même fichier, MD5 2ddbabda401d715761f0040e7f1cb1ba) |
| `build_place2.sh` | dernière ligne `cp "$SORTIE" "$O/Jeu_integre_stations.rbxl"` | copie de la sortie | facultatif |
| `gen_foudre.py` | `O = "/mnt/user-data/outputs/Integration_Stations"` | | `Integration_Stations` (chemin relatif) |
| `gen_ui_v24.py` | `D = "ui_v24/StationTycoon_transfert_v24"` | dossier extrait du zip v24 | extraire `C:\Users\ADMIN\Downloads\StationTycoon_transfert_v24.zip` dans `ui_v24/` |
| `gen_ui_v24.py` | `/mnt/user-data/outputs/Station_Tycoon_v23_IDs.json` | IDs des images v23 | `../2_documents/Station_Tycoon_v23_IDs.json` |
| `gen_ui_v24.py` | `/mnt/user-data/outputs/Station_Tycoon_v24_IDs.json` | IDs des images v24 (à créer après import) | fichier JSON `{"NomImage.png": identifiant, ...}` |
| `map/patch_installer.py` | `O = '/mnt/user-data/outputs/Integration_Stations/Map'` | | `../Integration_Stations/Map` |
| `gen_constructions.py` | chemin de `PACK_10_3_1.fbx` | upload cloud | `C:\Users\ADMIN\Downloads\PACK_10_3 (1).fbx` (inutile de relancer : ses sorties sont dans `gen/`) |

## Lancer un build

```bash
MAPDIR=V21l SORTIE=Station_Tycoon_v56.rbxl ./build_place2.sh
```

Étapes faites par `build_place2.sh` :
1. `python3 gen_ui_v24.py` → `v24_images.rbxlx` (arbre StarterGui du designer + identifiants d'images ; la version déjà
   générée pour la v55 est fournie ; si le zip v24 n'est pas extrait, commenter cette ligne).
2. `python3 gen_installer.py` → `gen/Installer_Constructions.lua` (depuis `gen/constructions.json`).
3. `cd map && python3 gen_map_v21.py` → `gen/PlotSpawns.rbxmx` (8 PlotSpawns) et `gen/RoutesAmbiance.lua` (trajets), à partir
   de `map/V21l/` (`bitume57.png`, `trottoir127.png`, `MAP_V17_Transfert/04_Donnees/plots_joueurs.json`) ; image de contrôle
   `map/V21l/routes_verif.png`.
4. `python3 gen_foudre.py` → un `.rbxmx` par nouveau script (Acces, Circulation, Livraison, Tutoriel, Diagnostic, Enchere,
   Monetisation, ClientRang… — la liste exacte est dans le fichier) à partir de `Integration_Stations/`.
5. `merger <base.rbxl> v24_images.rbxlx <sortie.rbxl> [options]` avec :
   - `--source=Chemin/Dans/Explorer=fichier.lua` : remplace la source d'un script existant ;
   - `--insert=Parent=fichier.rbxmx` : ajoute (ou remplace par nom) les objets du fichier dans le parent ;
   - `--delete=Chemin`, `--delete-sans=Parent/Nom=Enfant`, `--vider=Chemin`, `--keep=…`.
6. `validator <sortie.rbxl> place_v3.rbxlx` : relit la place produite et l'écrit en XML (contrôle ; le XML fait ~280 Mo).

## Autres fichiers

- `map/patch_installer.py <dossier 02_Scripts_Roblox>` : ajoute les « crochets » Station Tycoon à l'`InstallerMap` livré par
  l'IA map (à refaire à chaque nouvelle version de la map) → `Integration_Stations/Map/InstallerMap.lua`.
- `map/routes.py` : suit le centre des chaussées sur le raster du bitume pour calculer les trajets.
- `rbxl_parse.py` : lit une place binaire `.rbxl` (arbre + propriétés simples) ; `rbxlx_inspect.py`, `rbxcodec.py` : outils
  voisins. Exemple : `python3 -c "import rbxl_parse as R; i=R.parse('Station_Tycoon_v55.rbxl'); R.dump(i,'sortie')"`.
- `fbxread.py`, `fbxscene.py`, `inv_fbx.py` : lecture de FBX binaires (inventaire des pièces, tailles).
- `gen_patch.py` + `appliquer_patch.lua` : ancienne méthode des patchs `.rbxmx` (v40–v48).
- `fusion.py` : fusion à 3 voies d'anciennes versions de l'UIController (historique).
- `extraire_stockage2.py` : extraction de pièces du pack avec Blender (`bpy`).
- `tests/` : `test_circulation.lua` + `stubs_roblox.lua` (69 tests de l'algorithme de circulation, à lancer avec `luau`).
- `gen/` : fichiers générés utilisés par le build (les patchs et les 2 gros fichiers d'animations, déjà dans la place, ne sont
  pas copiés).
- `Integration_Stations/` : sources de travail. Les sauvegardes `Fichier.vNN.bak` gardent l'état avant chaque lot ;
  `Archive_Tempete/` = ancien système de tempête abandonné ; `Map/` = scripts de la map (avec crochets) ;
  `Foudre/`, `Metal/` = effets des mutations ; `Camion/CamionCartons.lua` = script du fourgon de Thomas ; `Sons/klaxon.*`.
