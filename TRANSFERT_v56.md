# Station Tycoon — dossier de transfert v56 (session « CODE 2 », 4 → 7 octobre 2026)

> Pour une nouvelle session Claude **qui a la main sur le PC de Thomas** (Cowork ou Remote Control). Il reprend tout ce qui a
> été fait depuis le document `transfert-roblox.md` (état v55) : relecture et corrections, nouveaux systèmes, économie, intro du
> tutoriel en pick-up, sons de moteur, et le plan d'intégration de la **v57** (20 voitures + animations par script, préparées
> par un autre agent). Lis ce document en entier, puis `COMPTE_RENDU_v56.md` et `2_documents/ECONOMIE_v56.md`.
> Quand une information n'est pas certaine, c'est écrit.

Propriétaire : **Thomas** (compte Roblox **thamary4**, UserId 1558910815). Langue française, tutoiement, réponses courtes à
« t'en es où ». Règles conservées : économie et sécurité côté serveur, seul son compte importe les assets, le jeu reste privé,
**c'est lui qui publie**, « stop » = arrêter de toucher au PC, questions en QCM une par une, jamais de CanvasGroup ni de
renommage d'objets de l'UI du designer, pas de messages au centre de l'écran.

---

## 0. Où est tout

| Quoi | Où |
|---|---|
| **Dépôt GitHub** (tout le travail, 11 commits) | `pelouzethomaspro-spec/roblox`, branche `claude/admiring-brown-0ue1dl` |
| Jeu complet v56 (99 + 2 scripts, prêt à coller / injecter) | `1_scripts_v56/` (rangé comme l'Explorer ; `.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript) |
| Scripts v55 d'origine (référence pour les diffs) | `1_scripts_v55/` |
| **Les 31 scripts à coller** (29 modifiés + 2 nouveaux) | `livraison_v56/` |
| Compte rendu détaillé (bugs, décisions, checklist Studio) | `COMPTE_RENDU_v56.md` |
| Économie v56 (simulation, valeurs, raisons) | `2_documents/ECONOMIE_v56.md`, `3_pipeline/economie/simulation.py` + `valeurs_v56.json` |
| Sons de moteur (quoi chercher, où coller) | `2_documents/SONS_MOTEURS.md` |
| Script barre de commandes : identifiants des images UI v24 | `2_documents/outils_studio/Appliquer_IDs_v24.lua` |
| Prévisualisation 3D de l'intro F-150 (mêmes équations que le code) | `2_documents/apercus/intro_f150.html` (aussi https://claude.ai/artifact/Johrf627v8DU5UEzKtzNAw) |
| Place reçue de Thomas (= v55 + 9 panneaux pub importés, **rien d'autre**) | `places/Station_Tycoon_v56_pre.rbxl` ; son arbre : `2_documents/arbre_explorer_v56_pre.txt` |
| Pipeline de build hors Studio (merger Rust compile, testé le 06/10) | `3_pipeline/` (voir `LISEZMOI_PIPELINE.md`) |
| Sur le PC de Thomas, jamais reçus ici | `C:\Users\ADMIN\Desktop\voiture\` (20 voitures + `_Installation_animations_stations\`), `F150_5_peintures.rbxl` (reçu ici, pas dans la place), zips UI v24, packs de voitures, map V21m |

**État de la place de Thomas** : à ma connaissance il n'a **rien collé** des scripts v56 dans Studio (il voulait que je pilote le PC,
ce que cette session cloud ne pouvait pas faire). Donc son jeu = `Station_Tycoon_v56_pre.rbxl` = code v55. **Tout ce qui suit est
dans les fichiers, pas encore dans la place.** Première chose à vérifier : lui demander s'il a enregistré une version plus récente.

---

## 1. Autorisations données par Thomas (nuit du 4 au 5/10, à reconduire)

* Pousser sur GitHub ; modifier le code et livrer une v56 ; décider par défaut sur les questions ouvertes en listant les choix ;
  toucher aux scripts des autres IA (UIController, InstallerMap avec crochets, designer) sans renommer / déplacer les objets UI.
* Si un bug demande un changement de règle de jeu : corriger au plus simple et le noter.
* **Studio** (pour une session qui a la main) : ouvrir et enregistrer des places **sans jamais écraser un fichier existant**
  (enregistrer sous `Station_Tycoon_v57.rbxl` et une base `_v57_base.rbxl`), importer des assets sous son compte (FBX, images,
  sons ; aucune clé Open Cloud), tests en Play courts, fermer les fenêtres Studio bloquées (Texture Painter, gestionnaire des tâches).
* **Téléchargements / Bureau** : lire tout, écrire de nouveaux fichiers, supprimer les doublons mal nommés (liste avant), dézipper.
* **Interdits** : publier le jeu ; Open Cloud ; intégrer la map V21m. **Autorisé** : intégrer les packs de voitures.
* Il ne veut pas de longs tests (« je veux pas de test ») et « quand tout est mis, pas besoin de republier, dis-moi juste ».

---

## 2. Ce qui a été fait (v56) — résumé ; détail dans `COMPTE_RENDU_v56.md`

### 2.1 Relecture complète du lot v55 (jamais lancé en jeu) : 38 bugs corrigés
Cinq relecteurs ont lu les 99 scripts. Aucune erreur de syntaxe (luau-analyze sur tous les fichiers), aucun plantage au
démarrage. Les plus graves :

| Bug | Fichier(s) |
|---|---|
| Suppression impossible des meubles de la demi-grille (cartons, plantes, caisses, panneaux pub) sur la moitié droite du plot et les 3/4 de l'annexe (X/Z en demi-cases testés comme des cases) | `PlotManager` |
| Anciens profils jamais réconciliés (`profile:Reconcile()` absent) → `GetRank` plantait sur une rareté absente de l'Index et la boucle d'apparition des voitures s'arrêtait | `DataManager`, `PlayerData` |
| Grille client 20 colonnes au lieu de 18 | `ClientData` |
| Roues fantômes après lavage manuel : roues ancrées côté client, jamais reposées quand le serveur téléporte la voiture | `TWEENController` |
| Correction d'échelle ×22/36 de la chaîne M4 coupée quand le joueur s'éloigne et jamais rétablie | `Stations/Comportements/Chaine` |
| Enchère gagnée par le **premier** enchérisseur au lieu du meneur ; `Enchere` globale nil dans `CarAmbiance` ; compteur de voitures par usine décrémenté deux fois | `Enchere`, `CarAmbiance` |
| Les 4 chaînes remontées à chaque lancement (attribut `ChainesVersion` jamais sauvegardé) avec recopie de ~120 000 instances | `InstallerChaines`, `Lancement` |
| Écran de chargement bloqué jusqu'à 60 s si `DiagnosticFunction` tarde ; Annuler ne coupait pas le mode Circulation | `ClientDiagnostic`, `UIController` |
| Type B : voitures qui passent faisaient un crochet de 100 studs ; type A : coin du trottoir coupé ; arrêt sec à la sortie ; PNJ nil → station bloquée | `Acces`, `CarManager` |
| Panneaux pub agrandis ×1,5 comme le pack ; refus de pose invisibles → affichés sur l'étiquette du fantôme ; attribut « Repos » périmé sur les stations ×1,5 ; touche M n'ouvrait pas ; etc. | divers |

### 2.2 Roues « mal fixées » (vidéo de Thomas du 05/10 au soir) — corrigé
La carrosserie suivait le Root par soudure (déplacée par le moteur physique une image après), les roues étaient posées
directement par le script : décalage de 1 à 2 studs avant/arrière. Désormais `TWEENController` ancre et pose **toutes** les
pièces (carrosserie + roues) dans la même image ; l'axe de rotation de chaque roue passe par le centre du pneu (plus grande pièce).

### 2.3 Nouveaux systèmes
* **Notes de station** (`ServerScriptService/Notes.lua`, nouveau) : Propreté / Rapidité / Accueil / Décoration (0..100) + globale,
  attributs `NoteGlobale`, `NoteProprete`… posés sur le joueur toutes les 5 s ; affichées dans l'onglet **Ma station** (calque de
  TextLabels/barres créés par script par-dessus l'image du designer, positions à ajuster quand `Station_00` sera importée).
  Effets : pourboire × 0,85…1,30 sur le gain de chaque voiture, clients × 0,90…1,15.
* **Agent d'entretien** (`Cleaner`, 4e carte Équipe) : 250 $ + 8 $/min, se promène entre les stations, nettoie en continu ; sans
  agent, invite **E « Nettoyer la station »** dès que la propreté passe sous 70 (+30).
* **Embauche payante** 300 / 200 / 300 / 250 $ (`WorkerManager.PRIX_EMBAUCHE`), vérifiée serveur ; `Hirefunction` renvoie le résultat.
* **Contenu débloqué par rang** : champ `Rang` sur les stations (L3/E2 Argent ; L4/E3/E4/caisse auto Or ; E5/E7 Platine ; E6
  Diamant), listes `Debloque` dans `Catalogue/Rank`.
* **Monétisation prête** : `ReplicatedStorage/Catalogue/Boutique.lua` (nouveau) = **le seul fichier** où coller les identifiants
  Robux (4 passes, 4 produits argent, 7 produits voiture) ; lu par `Monetisation` (ProcessReceipt) et par le Shop de `UIController`.
  Le pass `ArgentX2` double les gains ; VIP / LivraisonExpress / EmployesAuto ont leur identifiant mais aucun effet.
* **Sons de moteur par modèle** à partir d'Épique : `Catalogue/Car.Sons` (Ralenti en boucle + Acceleration une fois, identifiants
  à remplir : tous à 0), `Car.SonDe(nom)` ; `TWEENController` joue le ralenti du modèle, et le **rugissement** quand la voiture
  achetée au centre file vers le plot (attribut `Rugissement` posé par `CarAmbiance`, qui fait maintenant ce trajet en une courbe
  continue avec dérapage à la sortie du rond-point : 54 puis 42 studs/s). Guide : `2_documents/SONS_MOTEURS.md`.
* **Intro du tutoriel en pick-up F-150** (`Tutoriel.lua` calcule le trajet, `ClientTutoriel` l'anime en local) : voir § 4.

### 2.4 Équilibrage économique (demande de Thomas : « une bonne espérance »)
Constat v55 : cadence des clients par plot (pas par station), toutes les stations rapportaient pareil (`Mult` jamais défini),
39 $/min au départ, Maître à 83 h et Légende à 389 h. v56 : `Mult` par station (L1 1,0 … E6 2,0), +10 % de clients par station
(×1,8 max), produit de base 25 → 30 $, notes de station, seuils de rang revus (0 / 4 000 / 20 000 / 80 000 / 300 000 / 1,2 M / 5 M),
extensions 3 000 / 8 000 / 20 000 / 40 000 / 90 000 / 180 000. Simulation : Argent 20 min, Or 1 h 15, Platine 3 h, Diamant 7 h,
Maître 19 h, Légende 56 h ; chaque station remboursée en 10–25 min. Tout est dans `ECONOMIE_v56.md` (§ 4 : choix par défaut à valider).

---

## 3. Ce qu'il faut faire dans Studio pour la v56 (si la v57 n'est pas faite dans la foulée)

Checklist complète au § 1 de `COMPTE_RENDU_v56.md`. En bref : ouvrir `Station_Tycoon_v56_pre.rbxl`, **enregistrer sous
`Station_Tycoon_v56.rbxl`**, coller les 31 scripts de `livraison_v56/` (créer `ServerScriptService/Notes` et
`ReplicatedStorage/Catalogue/Boutique`, ModuleScripts), `require(game.ServerStorage.InstallerChaines)()` une fois puis Ctrl+S,
copier le F-150 dans `ReplicatedStorage` (Folder `F150_Peintures` avec les 5 couleurs, ou Model `F150`), importer les 116 images +
2 sons UI v24 puis exécuter `Appliquer_IDs_v24.lua` (table `IDS` à remplir) dans la barre de commandes, supprimer les sources
d'animations (`game.ServerStorage.RBX_ANIMSAVES:Destroy()` et `game.ServerStorage.AnimationsStations:Destroy()` après export
`.rbxm` de sauvegarde : 149 000 instances = 92 % de la place), tests courts (liste dans le compte rendu), Ctrl+S, prévenir Thomas.

---

## 4. L'intro du tutoriel en F-150 (demande du 05/10, trois itérations avec Thomas)

* **Modèle** : `F150_5_peintures.rbxl` (5 Models `F150_*` : 12 MeshParts `Wheel_FL/FR/RL/RR_1..3` + `black, contour, gris, model,
  orange, phare, red, windo` ; dessiné à 50 studs, le code le ramène à 27,1 = `Car.Longueur("F150")`, avant = −Z). À copier dans
  `ReplicatedStorage` (Folder `F150_Peintures` → une couleur au hasard, ou Model `F150`). Sans modèle : ancienne intro (toit de la Clio).
* **Ce que Thomas veut** (ses mots) : ItsCirly assis décontracté à l'arrière de la benne ; le pick-up entre dans le plot, dérape, se
  retrouve **un petit peu** sur deux roues, **très léger, très rapide** ; ItsCirly **à moitié en train de tomber** de la benne, se
  rattrape, le pick-up retombe, il retombe dedans, le pick-up roule dans le plot. **Pas « d'un coup »** : un vrai système de
  gravité, accumulation de vitesse, freinage au virage, cohérent. **Caméra** : trois-quarts vue de haut où l'on voit ItsCirly dans la
  benne, puis zoom sur lui pendant qu'il parle, puis dézoom, et là le coup de virage où il faillit tomber.
* **Ce qui est codé** (`ClientTutoriel`, table `PICKUP`) : pilote qui accumule de la vitesse (36 studs/s), freine pour tenir
  0,67 g dans le virage (`aLatCible`), train arrière qui décroche (survirage ≤ 30°), à la sortie les pneus **accrochent d'un coup**
  (2,2 g pendant 0,20 s) : la caisse bascule autour des roues extérieures par inertie, la gravité la ramène avec un rebond (~10° pendant
  ~0,6 s) ; suspension (roulis, plongée). ItsCirly = masse qui glisse dans la benne (adhérence 0,45), part vers l'arrière et l'extérieur,
  déborde de la ridelle (2,4 studs max), se rattrape. Plans caméra tels que demandés + plan extérieur bas pendant le dérapage, puis
  face à la benne une fois garé (parking colonnes 3-4, rangée 8 ; `Tutoriel.lua` prend 9 nœuds de file, le trottoir marqué `virage`,
  l'entrée, 2 cases dans le plot, le parking). Dialogue pendant la descente (« Hey ! Moi c'est ItsCirly… », « Je t'emmène voir TON
  terrain. Tiens-toi bien… »), « WOOOOH !! » au décollage, « …Ouf. Ça va, ça va. Je gère. » à la retombée.
* **La prévisualisation 3D** (`2_documents/apercus/intro_f150.html`) rejoue exactement ces équations avec des curseurs (vitesse,
  adhérence, coup de roue, durée, adhérence d'ItsCirly). Thomas n'a **pas encore donné** ses valeurs préférées : lui demander, puis
  les reporter dans `PICKUP`. **À vérifier en Play** : sens du roulis et côté de la caméra (calculés d'après le sens du virage).

---

## 5. La v57 à intégrer (document de Thomas du 06/10 : `PROMPT_TRANSFERT_agent_code.md`, Google Doc)

Un autre agent a préparé, sur le PC (`C:\Users\ADMIN\Desktop\voiture\_Installation_animations_stations\`) :
`Stations_v57_Installation.rbxmx` (modules, **CarManager**, modèle R15, animations des 20 voitures), `Installer_v57_barre_de_commande.lua`,
`LISEZMOI_v57b.md`, `sources_lua_v57\`, `Demo_Stations_20_voitures_v3.rbxl`, `Test_installation_v57.rbxl` (copie du jeu + 20 voitures).
Principe : **plus aucune animation publiée pour les stations** : des ModuleScripts `AnimationsStations/<station>` par voiture (milliers
d'images clés), lus par `ReplicatedStorage.Stations.Lecteur` qui pose les `Motor6D.Transform` à chaque image ; employé R15 par cinématique
inverse (`Stations.Employe`, **ne pas changer les tables G et OFS**) ; peinture appliquée après la cabine E6 (`Stations.Peintures`).

**Les 20 voitures** (clé = début du nom des modèles, une clé = plusieurs peintures `Clé_Couleur`) :
Common : Clio2, Golf2, Peugeot206, Volvo240, F150 · Uncommon : Clio4, Raptor · Rare : Wrangler, Audi_A4, BMW_Serie1 ·
Epic : ClasseG, Challenger, M4, RS3 · Legendary : AudiR8, Urus, AMG_GTR · Mythic : Ferrari488, GT3RS, McLarenP1 · **Divine : aucune**.
Longueurs (M4 = 22) : Clio2 17,3 ; Golf2 18,3 ; 206 17,6 ; Volvo240 22,0 ; F150 27,0 ; Clio4 18,6 ; Raptor 27,0 ; Wrangler 22,0 ;
Audi_A4 21,9 ; BMW_Serie1 19,8 ; ClasseG 22,1 ; Challenger 23,0 ; M4 22,0 ; RS3 20,1 ; AudiR8 20,3 ; Urus 23,5 ; AMG_GTR 20,9 ;
Ferrari488 21,0 ; GT3RS 21,0 ; McLarenP1 21,1.

**Ce que Thomas demande** : intégrer les 20 voitures par rareté, leur attribuer les animations, et livrer une place **« Game Ready »
V1** avec tout le code et toutes les animations, qu'il puisse tout tester.

### 5.1 Plan d'intégration (ce que je comptais faire ; à faire par la session PC)
1. Partir de **`Test_installation_v57.rbxl`** (les 20 voitures y sont) ou copier les modèles des 20 `.rbxl` dans
   `ReplicatedStorage > VoituresModeles` en gardant les noms. Vérifier si cette copie est v55 ou v56_pre (panneaux pub présents ?).
2. Importer `Stations_v57_Installation.rbxmx`, exécuter `Installer_v57_barre_de_commande.lua`. **Attention** : il **remplace
   `CarManager` et `Catalogue/Car`** par ses versions (faites sur le v55). Il faut **fusionner** avec les v56 :
   * `CarManager` v56 : Cadence (attractivité, Notes), gain (Mult catalogue, pourboire, ArgentX2), hooks Notes, trajet PASSE, nœud
     Carrefour, `continue` en WAIT_EXIT, PNJ nil, `moduleOptionnel`. v57 : `dureeService(car, station)` via `Lecteur.donnees`
     (A.duree + 0,3 ou segments + arrêt), peinture après E6. Reprendre les deux.
   * `Catalogue/Car` v56 : `LongueursM.F150`, `Car.Sons`, `Car.SonDe`. v57 : longueurs des 20 voitures, recherche « clé la plus
     longue » (GT3RS ≠ GT3, Golf2 ≠ Golf). Reprendre les deux ; **reclasser** `Car.<rareté>.Models` sur les 20 clés.
   * Mes modifs v56 de `Stations/Client.lua` (warn Animator, rafraîchissement de `Repos`) et `Comportements/Chaine.lua` (connexion
     d'échelle rétablie au réveil) : v57 remplace peut-être ces modules (`Outils.repos` rend le `Repos` inutile). Garder la logique
     de `Chaine` (les chaînes ne sont pas dans v57).
3. Adapter ce qui dépend des noms de modèles : `CarManager.PickRandomCar` (tirer une clé puis une peinture au hasard parmi les
   modèles dont le nom commence par la clé ; attribut `Name` = la clé pour l'Index et les sons), `Enchere` (Models), `CarAmbiance`,
   `Catalogue/Car.Modele`, `Car.TierDe`, `Car.Sons` (clés : M4, ClasseG, Urus, GT3RS, Ferrari488, AMG_GTR, AudiR8, McLarenP1, RS3,
   Challenger, F150), **Index UI** (12 cartes `IndexCard_01..12` réparties 2/2/2/2/2/1/1 par rareté dans `UIController.CARTE_PAR_TIER` :
   avec 5/2/3/4/3/3/0 modèles il faut une autre répartition ou un défilement), `Rank` (**Légende exige 2 Divines** : à passer en
   Mythiques s'il n'y a pas de Divine ; `PickRandomCar` doit replier Divine → Mythic si le tier est vide), chaîne de production
   (`Stations/Reglages.VOITURES` et `ChaineProduction.VOITURES` = les 12 anciens noms : garder les anciens modèles pour la chaîne
   seulement, ou passer la liste aux nouvelles clés avec résolution clé → première peinture).
4. Puis le reste de la v56 : coller les 31 scripts (en tenant compte des fusions ci-dessus), F-150, images, sons, nettoyage des
   sources d'animations, `InstallerChaines` + Ctrl+S, tests, `Station_Tycoon_v57.rbxl`.

### 5.2 Questions posées à Thomas, sans réponse
* **Divine** : mettre la McLaren P1 en Divine, ou la rareté Divine disparaît pour l'instant ?
* **Anciennes 12 voitures** : garder pour la chaîne de production seulement (hors clients) ?
* **« Follie »** (ancienne Divine) : quelle voiture réelle ? (pour le son de moteur)
* Le fichier « avec le nom des voitures » de son bureau : jamais reçu (c'est sans doute le document v57 ci-dessus).
* Valeurs des curseurs de l'intro F-150 qui lui plaisent.
* Les identifiants Robux (`Catalogue/Boutique`), les sons (moteurs, GT3 `hyper/moteurGT3/clac`, tutoriel), la texture des panneaux.

---

## 6. Points à surveiller au premier lancement (non testés en jeu)
* Tête de file reculée de 22 studs et nœud `Carrefour` (`Acces`) : géométrie à regarder à l'œil.
* Panneaux pub : masques (1×1 / 2×1 / 3×1 demi-cases) vs tailles réelles importées (2,5 à 19,6 studs de large) — cohérents sur
  le papier ; `OrientationFixe = 0` suppose la face vers +Z ; vérifier qu'ils regardent la sortie du tunnel.
* Onglet Ma station : positions du calque à caler sur l'image `Station_00` une fois importée.
* `Rapidité` : si elle reste basse, monter `Notes.REGLAGES.ATTENTE_REF` (60 s) ou le trajet déduit (25 s).
* Pièces mobiles des stations ×1,5 : un relecteur soupçonne des translations non multipliées par 1,5 (`Stations/Voiture`, `E5`) ;
  v57 (`Outils.repos`, données `echelle`) règle peut-être le point. Rien changé.
* Fenêtre Rangs : 8 planches pour 7 rangs (demander une version à 7 au designer).

---

## 7. Décisions prises seul (à valider)
Valeurs de l'économie (§ 2.4), poids des notes (± 15 % clients, −15 / +30 % gains), agent d'entretien sans poste (téléporté toutes
les 20 s), seul pass branché = ArgentX2, prix des stations inchangés (c'est le `Mult` qui différencie), remboursement intégral
conservé, paramètres physiques de l'intro F-150 (§ 4), suppression des sources d'animations recommandée.
