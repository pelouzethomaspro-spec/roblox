# Dossier de transfert — Station Tycoon (session « CODE », build v55, 05/10/2026)

À lire dans cet ordre :

1. **`transfert-roblox.md`** — le document de transfert complet (le jeu, l'organisation, l'état du code / de la map / de
   l'UI / des modèles 3D, les fichiers, l'historique, la suite). Même fichier que `C:\Users\ADMIN\Downloads\transfert-roblox.md`.
2. **`1_scripts_v55\INDEX.md`** — la liste des 99 scripts du jeu, avec leur chemin dans l'Explorer de Roblox Studio.
3. **`3_pipeline\LISEZMOI_PIPELINE.md`** — seulement si tu veux reconstruire les `.rbxl` hors de Studio comme le faisait la
   session « CODE ».

## Contenu

| Dossier | Ce qu'il contient |
|---|---|
| `1_scripts_v55\` | Le code exact de `Station_Tycoon_v55.rbxl`, extrait script par script. `.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript. Les dossiers reproduisent l'Explorer (`ServerScriptService\CarManager.lua`, `StarterGui\UIController.client.lua`…). |
| `2_documents\` | Guides, récapitulatifs, échelle des véhicules, prompts envoyés à l'IA map, identifiants des images UI v23, carte interactive du projet (v51), historique des tâches, résumé de la conversation, arbre complet de la place v55. |
| `3_pipeline\` | Les outils de build (Python + Rust) et les sources de travail (`Integration_Stations\`, avec les sauvegardes `.vNN.bak`). |

## Fichiers importants qui sont ailleurs dans Téléchargements (non recopiés ici)

| Fichier | Rôle |
|---|---|
| `C:\Users\ADMIN\Downloads\Station_Tycoon_v55.rbxl` | **La place à jour** (à ouvrir dans Studio) |
| `C:\Users\ADMIN\Downloads\Station_Tycoon_v54_base.rbxl` | Base de build (map V21l installée), = `place_base_v11.rbxl` du pipeline |
| `C:\Users\ADMIN\Downloads\PANNEAUX_PUB_VIERGES_1.fbx` | 9 panneaux publicitaires à importer dans Studio (`ReplicatedStorage/Furniture`) |
| `C:\Users\ADMIN\Downloads\StationTycoon_transfert_v24.zip` + `LISEZMOI.md` | Nouvelle UI v24 du designer (116 images + 2 sons à importer) |
| `C:\Users\ADMIN\Downloads\MAP_V21l\MAP_MOTIFS_V17_AVEC_CHAINES.fbx` | FBX de la map intégrée (V21l) |
| `C:\Users\ADMIN\Downloads\MAP_V21l_Partie1_sur7_…zip` … `Partie7` | Paquet complet de la map V21l |
| `C:\Users\ADMIN\Downloads\MAP_V17_Transfert\` et `MAP_V17_Parties\` | **Map V21m** (plus récente, jamais intégrée) |
| `C:\Users\ADMIN\Downloads\PACK_10_3 (1).fbx` | Pack de constructions (sols, murs, toits, décor) |
| `C:\Users\ADMIN\Downloads\Station_Tycoon_Echelle_22\` | Dossier « échelle M4 = 22 studs » (aussi copié dans `2_documents\Echelle_22\`) |

## Remettre un script dans Studio

Ouvrir `Station_Tycoon_v55.rbxl`, retrouver le script au même chemin dans l'Explorer, l'ouvrir, tout sélectionner, coller le
contenu du fichier `.lua`. Les scripts créés à l'exécution (RemoteFunctions `AccesFunction`, `DiagnosticFunction`, etc.) n'ont
pas besoin d'être ajoutés à la main.
