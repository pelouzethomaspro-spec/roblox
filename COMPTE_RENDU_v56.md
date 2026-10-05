# Station Tycoon — compte rendu de la nuit du 4 au 5 octobre 2026 (lot v56)

Tout est sur GitHub : dépôt `pelouzethomaspro-spec/roblox`, branche `claude/admiring-brown-0ue1dl`.
Rien n'a été touché sur ton PC ni dans Studio. Rien n'est publié.

## 1. Ce que tu dois faire dans Studio (dans l'ordre, ~20 min hors tests)

1. **Ouvre `Station_Tycoon_v56_pre.rbxl`** (celui que tu m'as envoyé : c'est la v55 + tes 9 panneaux pub importés, rien d'autre).
   Enregistre-le tout de suite **sous `Station_Tycoon_v56.rbxl`** (Fichier → Enregistrer sous) pour garder le `_pre` intact.
2. **Colle les 28 scripts du dossier `livraison_v56/`** : pour chaque fichier, ouvre le script au même chemin dans l'Explorer,
   Ctrl+A, colle. Les deux NOUVEAUX scripts à créer (clic droit sur le dossier → Insérer un objet → ModuleScript, puis
   renommer et coller) :
   * `ServerScriptService/Notes` (ModuleScript) — notes de la station, agent d'entretien.
   * `ReplicatedStorage/Catalogue/Boutique` (ModuleScript, enfant de `Catalogue`) — tous les identifiants Robux au même endroit.
   Les 26 autres existent déjà (liste en § 4). `.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript.
3. **Chaînes de production** : dans la barre de commandes, `require(game.ServerStorage.InstallerChaines)()` une fois, puis
   Ctrl+S. Désormais la map porte l'attribut `ChainesVersion` : les 4 chaînes ne sont plus remontées à chaque lancement
   (c'était ~120 000 instances recopiées à chaque Play, voir § 3).
4. **Images UI v24** (quand tu veux) : Contenus → Importer → les 116 images + 2 sons de `StationTycoon_transfert_v24.zip/2_a_importer/`.
   Puis ouvre `2_documents/outils_studio/Appliquer_IDs_v24.lua`, remplis la table `IDS` (nom d'image → identifiant), colle le
   tout dans la barre de commandes, Entrée, Ctrl+S. Il écrit les 35 emplacements encore vides (Rangs, Shop, modes
   Circulation/Décoration, pastilles d'onglets, Ma station, voiture animée du menu) et te dit ce qui manque.
5. **Tests courts en Play** (ce que je ne peux pas vérifier d'ici, par priorité) :
   * une voiture entre, se gare, le client paie, la voiture ressort **sans arrêt sec** à la sortie et **sans roues fantômes**
     après un lavage manuel (E) ;
   * plot de **type B** : une voiture qui passe (aucune station prête) part vers la route du tour sans faire demi-tour le long
     du plot ; plot de type A : elle ne coupe plus le coin du trottoir ;
   * la tête de file est 22 studs plus loin de l'entrée qu'avant (la voiture a de l'élan pour tourner) : vérifie que ça ne
     gêne pas visuellement ;
   * onglet **Ma station** : les notes bougent (5 étoiles, 4 barres) ; embauche d'un **Agent d'entretien** (250 $) qui se
     promène entre les stations ; sans agent, invite « Nettoyer la station » dès que la propreté passe sous 70 ;
   * **embauche payante** : 300 / 200 / 300 / 250 $ ; refus si pas assez d'argent ;
   * menu Construction : cartes grisées « dès le rang … » sur L3/E2 (Argent), L4/E3/E4/caisse auto (Or), E5/E7 (Platine),
     E6 (Diamant) ; supprimer un carton, une plante, une caisse ou un panneau pub posé **sur la moitié droite du plot ou au
     fond de l'annexe** (impossible en v55) ; un panneau pub posé une 2e fois affiche « déjà posé » ;
   * chaîne M4 : éloigne-toi à plus de 470 studs puis reviens : les voitures restent dans le hall ;
   * enchères à 2 joueurs (Test → 2 joueurs) : c'est bien le **dernier** enchérisseur qui gagne ;
   * `/tutoriel`, `/cinematique GT3`, `/acces` comme avant.
6. Si tout va : Ctrl+S, et dis-moi. C'est toi qui publies.

Un `print` en console `[Notes]`, `[Plot]`, `[Chaines]`, `[Ambiance]`, `[Enchere]` t'indique d'où vient un éventuel problème.

## 2. Ce que j'ai fait

### Relecture complète du lot v55 (jamais lancé en jeu) — 5 relecteurs, ~100 scripts lus
Aucune erreur de syntaxe ni de plantage au démarrage. **38 bugs corrigés**, les plus importants :

| Gravité | Bug | Fichier |
|---|---|---|
| grave | Suppression impossible des meubles de la demi-grille (cartons, plantes, caisses, **panneaux pub**) sur la moitié droite du plot et les 3/4 de l'annexe : X/Z en demi-cases testés comme des cases | `PlotManager` |
| grave | Anciens profils jamais réconciliés avec le modèle (`profile:Reconcile()` absent) → `GetRank` plantait sur une rareté absente de l'Index et **la boucle d'apparition des voitures s'arrêtait** | `DataManager`, `PlayerData` |
| grave | Grille client 20 colonnes au lieu de 18 : 2 colonnes dessinées sur le trottoir, poses refusées | `ClientData` |
| grave | **Roues fantômes** après lavage manuel : les roues sont ancrées côté client et seulement reposées pendant un trajet ; quand le serveur téléporte la voiture à la fin du cycle, elles restaient dans la station → reposées à chaque déplacement du châssis | `TWEENController` |
| grave | Chaîne M4 : la correction d'échelle ×22/36 était coupée quand le joueur s'éloignait et jamais rétablie → les voitures retraversaient les murs au retour | `Stations/Comportements/Chaine` |
| grave | Enchère : c'était le **premier** enchérisseur (prix de base) qui gagnait, pas le meneur | `Enchere` |
| grave | `Enchere` était une globale nil dans `CarAmbiance` : pas de tour supplémentaire pendant une enchère, enchère jamais arrêtée quand la voiture quitte l'anneau | `CarAmbiance` |
| grave | Les 4 chaînes remontées à **chaque** lancement (attribut jamais sauvegardé) avec recopie de ~120 000 instances d'animations | `InstallerChaines`, `Lancement` |
| moyen | Écran de chargement bloqué jusqu'à 60 s si `DiagnosticFunction` tarde | `ClientDiagnostic` |
| moyen | Bouton Annuler laissait les plaques Circulation/Décoration au sol et désynchronisait le bouton | `UIController` |
| moyen | Rang recalculé une voiture en retard (AddXp avant AddCar) | `CarManager`, `PlayerData` |
| moyen | Compteur de voitures par usine décrémenté deux fois → plus de voitures que le maximum | `CarAmbiance` |
| moyen | Type B : les voitures qui passent faisaient un crochet de ~100 studs en arrière ; type A : coupaient le coin du trottoir ; arrêt sec de 1 s à la sortie du plot | `Acces`, `CarManager` |
| moyen | PNJ nil (`SpawnPNJ`) → coroutine de la voiture morte, station bloquée « Taken » | `CarManager` |
| moyen | Panneaux pub agrandis ×1,5 comme les meshes du pack (ils sont déjà à l'échelle réelle) | `PlotManager` |
| moyen | Raisons de refus de pose invisibles (toasts coupés) → affichées sur l'étiquette du fantôme (pas au centre de l'écran) | `ClientBuild` |
| moyen | Attribut « Repos » des pièces mobiles périmé sur les stations agrandies ×1,5 (effets/sons des robots mal placés) → repris à la découverte de la station | `Stations/Client` |
| mineur | M n'ouvrait pas l'interface (règle du designer) ; vignette Supprimer qui restait ; son `hover` inexistant ; embauche toujours « réussie » ; `print` de debug (`appeled`, grille à chaque pose) ; connexions qui s'accumulaient (ClientRang) ; `Rank.Numero` acceptait un rang mal orthographié ; `SpendMoney` ne renvoyait rien ; déplacement de l'entrée ne rafraîchissait pas le mode Circulation ; objet unique posé → fantôme détruit et cartes repeintes ; sortie type B asymétrique ; cache des trottoirs figé si la map n'était pas prête ; fuite du limiteur Diagnostic ; remboursement si un achat Robux échoue après débit | divers |

### Nouveautés (backlog validé cette nuit)
* **Onglet Ma station** : 4 notes (Propreté, Rapidité, Accueil, Décoration) + note globale en étoiles, affichées par-dessus
  l'image de la maquette (aucun objet du designer renommé). Module serveur `Notes`.
* **Agent d'entretien** (4e carte Équipe) : 250 $ + 8 $/min, se promène entre les stations, nettoie en continu. Sans agent,
  le joueur nettoie lui-même (E sur une station).
* **Embauche payante** (300 / 200 / 300 / 250 $), vérifiée côté serveur.
* **Contenu débloqué par rang** : champ `Rang` sur les stations et la caisse automatique, listes `Debloque` dans `Rank`.
* **Monétisation prête** : un seul fichier à remplir, `ReplicatedStorage/Catalogue/Boutique` (4 passes, 4 produits argent,
  7 produits voiture) ; le Shop et `ProcessReceipt` le lisent ; le pass ArgentX2 double les gains.

### Équilibrage économique — lis `2_documents/ECONOMIE_v56.md`
Simulation de la progression (`3_pipeline/economie/simulation.py`). En v55 : 39 $/min au départ, Maître à 83 h, Légende à
389 h, et une station chère ne rapportait pas plus qu'une station de base. En v56 : Mult par station, +10 % de clients par
station, produit de base à 30 $, notes de station (pourboire ×0,85…1,30, clients ×0,90…1,15), seuils de rang revus. Résultat
simulé : Argent 20 min, Or 1 h 15, Platine 3 h, Diamant 7 h, Maître 19 h, Légende 56 h ; chaque station remboursée en 10 à 25 min.

## 3. Ce que j'ai tranché seul (dis-moi si tu veux autre chose)
* Valeurs des rangs, des panneaux et de l'embauche : celles du document d'économie.
* Les notes pèsent ±15 % sur les clients et −15 %/+30 % sur les gains.
* Tête de file reculée de 22 studs et nœud de carrefour ajouté (trajets plus naturels) : **à vérifier en jeu**, c'est de la
  géométrie que je ne peux pas voir d'ici.
* Fenêtre Rangs : toujours 8 planches pour 7 rangs (la 8e est vide) ; à faire ré-exporter par le designer.
* Les 42 identifiants d'images manquants restent à 0 tant que les images v24 ne sont pas importées (l'ancien visuel v23 est
  réutilisé là où il existe).

## 4. Fichiers
* `livraison_v56/` : les 28 scripts à coller (26 modifiés + `Notes` + `Boutique`), rangés comme dans l'Explorer.
* `1_scripts_v56/` : le jeu complet (99 + 2 scripts) tel qu'il doit être après collage.
* `2_documents/ECONOMIE_v56.md`, `2_documents/outils_studio/Appliquer_IDs_v24.lua`, `3_pipeline/economie/`.
* `places/Station_Tycoon_v56_pre.rbxl` : ton fichier, inchangé.

## 5. Pas fait, et pourquoi
* **Packs de voitures** (AMG GTR, P1, Wrangler…) : tu m'as autorisé à les intégrer mais les fichiers sont sur ton PC, pas
  dans la conversation. Envoie-les (`*_Pack`, `GEO13_voitures_claude.rbxm`) et je les ajoute au catalogue.
* **Map V21m** et **publication** : interdits, comme convenu.
* **Imports Studio et tests en jeu** : impossibles depuis cette session (pas d'accès au PC). Liste en § 1.
* Sons manquants (GT3 : `hyper`, `moteurGT3`, `clac` ; tutoriel) : à fournir.
* Game Pass VIP / Livraison express / Employés auto : identifiants prêts, effets non codés.
* Pièces mobiles des stations ×1,5 : un relecteur soupçonne que certaines translations (axe des roues, rack de pneus E5)
  ne sont pas multipliées par 1,5 (`Stations/Voiture`, `E5`). Je n'ai rien changé : à regarder en jeu, dis-moi si les roues
  des voitures dans les stations « orbitent ».
