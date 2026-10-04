# Station tycoon — récap de la nuit du 29/30 septembre

## Publié (en privé) : v38
- Quadrillage recalé sur les trottoirs V17m (10,85 studs) : les plots utilisent les nouvelles données `plots_joueurs.json`.
- **Bug majeur corrigé** : `MapAlignement` gardait la référence de l'ancienne map (-1011,22) → tous les plots et tous les trajets
  de voitures étaient décalés de 3,48 studs en diagonale. La référence est maintenant lue dans `DonneesArbres`.
- Bout de goudron surélevé + flèche supprimés à l'entrée des parcelles (le trottoir V17m continue à plat).
- Goudron des parcelles (`sol_goudron`) et tabliers d'accès : même texture que les routes (`rbxassetid://92104598075721`).
- Herbe en relief partout (les plots compris) ; sol plat seulement sous les dalles posées (case par case, `PlotManager`) et
  sous les tabliers d'accès. Le terrain est refait à chaque démarrage du serveur (`InstallerHerbe`, ~0,3 s) : plus rien à
  « cuire » dans Studio.
- Cinématique du fourgon à **chaque** livraison (testée : plan fixe, travelling, poursuite, rond-point, chute des cartons).
- Chaînes de production remontées (Motor6D + animations) dans la base v8 → elles s'animent.
- Base Studio : `Station_Tycoon_base_v7Station_Tycoon_base_v8.rbxl` (= base v8, nom à renommer).

## Prêt mais PAS publié : v40 (`Station_Tycoon_v40.rbxl` dans Téléchargements)
- **UI v23** intégrée : arbre du designer + 73 images + 3 sons branchés, fusion de son UIController v23 avec mon câblage
  (panneau joueur, « Ta partie » avec aperçu 3D du garage, Newsletter, HUD argent/XP/rang, familles Stock/Supply,
  cadran « prochaine livraison », boutons Déplacer/Supprimer). Testée en Studio (v39) : menus OK.
- **Bug majeur corrigé** : `Circulation` comparait le nom du sol sans enlever le suffixe « #orientation » → aucun sol n'était
  roulable, **aucune voiture ne pouvait entrer sur le plot** (c'est l'origine de « Les clients ne peuvent pas entrer »).
- Circulation plus tolérante : la route de 2 cases peut être à gauche ou à droite de l'accès (3 cases) et de la station.
- Chemin piéton déplacé dans `Circulation.CheminPieton` ; 69 tests hors ligne (`tests/test_circulation.lua`, tous verts).
- Publication bloquée cette nuit : deux fenêtres Studio du lieu cloud (Team Create) restées ouvertes (dialogue « Application
  des modifications apportées au script » qui ne se termine jamais) ; l'accès à ton PC a expiré ensuite.

## À faire au réveil (5 minutes)
1. Fermer TOUTES les fenêtres Roblox Studio (Gestionnaire des tâches → Fin de tâche RobloxStudioBeta si le dialogue bloque)
   et fermer le Gestionnaire des tâches que j'ai ouvert par erreur.
2. Ouvrir `Station_Tycoon_v40.rbxl`, Fichier → Publier sur Roblox comme → Station tycoon → Écrire par-dessus.
   (Alternative sans fermer les fenêtres : dans le lieu cloud, Explorateur → Workspace → Insérer `Patch_v40.rbxmx`, puis coller
   `appliquer_patch.lua` dans la barre de commande, puis Alt+P.)

## Non fait (manque de temps / accès PC perdu)
- Conduite réaliste (accélération / freinage / boost des voitures rares), diagnostic manette-téléphone, audit visuel de la
  map, tuto cinématique 40 s avec parcelle pré-construite, propositions de stations.
