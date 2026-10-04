# Intégration des stations animées dans le tycoon

Résultat attendu : dans le menu Build, les 11 stations remplacent les cubes. Quand tu poses une station,
qu'elle a du stock et un employé (ou qu'elle est automatique), la voiture cliente qui arrive dessus déclenche
l'animation de la station (la voiture entre, se fait traiter, ressort), le PNJ va payer à la caisse pendant
ce temps, puis la voiture repart par les nœuds de sortie. Tous les joueurs voient la même chose.

Deux places Studio ouvertes en même temps : **`Thomas good luck 1.rbxl`** (le tycoon, place de destination)
et **`jeux.rbxl`** (les stations, place source). Le copier-coller fonctionne entre deux fenêtres Studio.

## 1. Copier depuis `jeux.rbxl` vers le tycoon (Ctrl+C dans l'une, Ctrl+V dans l'autre)

| Depuis `jeux.rbxl` | Coller dans le tycoon, sous | Remarque |
|---|---|---|
| `ReplicatedStorage > Stations` (dossier entier) | `ReplicatedStorage` | tous les modules du système |
| `ReplicatedStorage > AnimationsTest_ASupprimer` | `ReplicatedStorage` | 115 000 instances : lent, mais nécessaire pour voir les animations dans Studio tant qu'elles ne sont pas publiées |
| `ReplicatedStorage > VoituresModeles` | `ReplicatedStorage` | facultatif (ne sert qu'aux stations de décor en mode boucle) |
| `Workspace > Toutes_Stations_Alignees` | `Workspace` | les 11 stations montées ; le script d'installation les rangera |
| `StarterPlayer > StarterPlayerScripts > StationsClient` | `StarterPlayer > StarterPlayerScripts` | le LocalScript qui lance le système chez chaque joueur |

Attention : colle dans **Workspace** (pas dans le Terrain) et vérifie que `ReplicatedStorage.Stations.Donnees`
contient bien les 11 modules (E1_Base … L4_Rouleaux).

## 2. Lancer le script d'installation (une seule fois)

Dans le tycoon : Affichage > Barre de commande. Ouvre `Installer_Stations_BarreDeCommande.lua`, copie tout son
contenu dans la barre de commande, Entrée. La sortie doit afficher 11 lignes `Installer : <station> -> Furniture`
et aucune erreur. Il :

- supprime les cubes `5`, `6`, `7` (`8` n'existait pas) de `ReplicatedStorage > Furniture` ;
- donne à chaque station le même pivot que les cubes (coin de la case d'ancrage, hauteur du sol) ;
- déplace les 11 stations dans `ReplicatedStorage > Furniture`.

Si tu vois `Workspace.Stations_8 … peut être supprimé` : c'est l'ancienne copie non montée des stations qui traînait
dans le monde du tycoon ; tu peux la supprimer.

## 3. Remplacer / coller les scripts

Pour chaque fichier, ouvre le script dans Studio, sélectionne tout, colle le contenu du fichier.

| Fichier livré | Script dans le tycoon | Ce qui change |
|---|---|---|
| `Furniture.lua` | `ReplicatedStorage > Catalogue > Furniture` | les 11 stations remplacent 5/6/7/8 (prix, consommables acceptés, capacité : valeurs de départ à ajuster) |
| `CarManager.lua` | `ServerScriptService > CarManager` | déclenche et attend le cycle de la station, gare / ressort la voiture sur la voie de la station |
| `DataManager.lua` | `ServerScriptService > DataManager` | DataStore `V37` (données propres), libération mémoire au départ du joueur |
| `ClientBuild.lua` | `StarterPlayer > StarterPlayerScripts > ClientBuild` | le fantôme de placement n'est plus pris pour une station |
| `Client.lua` | `ReplicatedStorage > Stations > Client` | mode « commandé par le serveur » + garde anti-aperçu |
| `Voiture.lua` | `ReplicatedStorage > Stations > Voiture` | ignore la racine invisible des voitures clientes lors de la mesure |

Les autres modules de `Stations` (Comportements, Donnees, Sons, Effets, Outils, Montage, Reglages, Categories)
restent tels que copiés.

## 4. Tester dans Studio

1. Play. Choisis un plot, ouvre Build > Furniture : les stations apparaissent (leur aperçu 3D est mal cadré dans
   l'UI actuelle à cause d'une pièce invisible excentrée ; ta nouvelle UI réglera ça).
2. Pose du sol, une station (3×3), une caisse. Laisse libres les cases devant et derrière la station : la voiture
   entre par le côté −Z (orientation 0) et ressort par +Z, à ~24 studs au-delà de la dalle.
3. Achète le consommable accepté (Stock), remplis la station (Supply), embauche et affecte un employé si la
   station n'est pas automatique.
4. Une voiture arrive, se gare sur la voie : dès que stock + employé sont là, l'animation démarre. À la fin, la
   voiture réapparaît à la sortie de la station et rejoint les nœuds de sortie ; l'argent est encaissé.

Dans la sortie (Output), un `Stations : … : …` signale une erreur par station sans arrêter les autres.

## 5. Avant de publier le jeu

Les animations ne jouent dans Studio que grâce à `AnimationsTest_ASupprimer`. En jeu publié, il faut :

1. publier chaque `KeyframeSequence` de `ServerStorage > RBX_ANIMSAVES` (ou du dossier de test) comme
   Animation (clic droit > Save to Roblox, ou l'éditeur d'animation) ;
2. coller les IDs obtenus dans `ReplicatedStorage > Stations > Reglages > ANIMATIONS` ;
   `Voitures` est indispensable (c'est elle qui fait rouler la voiture dans E1, E2, E3, L1, L2) ;
3. supprimer `AnimationsTest_ASupprimer`.

Tant qu'un ID vaut `rbxassetid://0`, la station concernée reste immobile en jeu publié (un avertissement le dit).

## Sécurité : ce que cette étape change

Rien côté surface d'attaque : aucun nouveau remote, le client des stations ne renvoie rien au serveur. Le serveur
décide seul du début du service (stock + employé), de sa durée (`CYCLE` des données de la station), du stock
consommé et du paiement. L'animation n'est qu'un affichage local ; un client qui la trafique ne change ni son
argent ni celui des autres. Les failles listées précédemment (embauche gratuite, NaN, débit, admin par pseudo)
restent à corriger : c'est le chantier suivant.
