# Bruits de moteur par modèle (v56) — ce qu'il faut trouver et où le coller

Demande de Thomas : à partir de la rareté **Épique**, chaque modèle a son propre bruit de moteur, reconnaissable de la vraie
voiture. Deux sons par modèle : le **ralenti / régime constant** (en boucle, hauteur et volume suivent la vitesse) et une
**grosse accélération** (jouée une fois quand la voiture achetée au centre rugit et dérape dans le rond-point pour filer vers
ton plot). Les voitures Common → Rare gardent le son générique.

Je ne peux pas récupérer d'audio depuis ici : la boutique Roblox (Creator Store) se consulte dans Studio et tout import passe
par ton compte. Voici donc la liste exacte, les mots-clés à taper, et l'endroit où coller les identifiants.

## 1. La liste

| Modèle (catalogue) | Rareté | Vraie voiture / moteur | Caractère du son à chercher | Mots-clés Creator Store (onglet Audio) |
|---|---|---|---|---|
| `M4` | Épique | BMW M4 G82 — S58 3.0 L 6 cylindres en ligne biturbo | sifflement de turbo, grave rond, montée en régime propre | `inline 6 turbo engine idle`, `BMW M4 engine rev`, `turbo car acceleration` |
| `ClassG` | Épique | Mercedes-AMG G63 — M177 4.0 L V8 biturbo | grondement très grave, crépitements à la décélération | `V8 twin turbo idle`, `AMG V8 rev`, `muscle V8 acceleration` |
| `Urus` | Légendaire | Lamborghini Urus — 4.0 L V8 biturbo | V8 rauque, échappement sport, pops | `V8 twin turbo sport exhaust`, `Lamborghini Urus engine`, `SUV V8 acceleration` |
| `GT3` | Légendaire | Porsche 911 GT3 (992) — 4.0 L flat-6 atmosphérique, 9 000 tr/min | hurlement aigu, très haut dans les tours, pas de turbo | `flat six engine idle`, `Porsche GT3 rev 9000 rpm`, `naturally aspirated race car acceleration` |
| `F448` | Mythique | Ferrari 488 GTB — F154 3.9 L V8 biturbo | V8 italien tendu, turbo discret, aigu en haut | `Ferrari 488 engine idle`, `Ferrari V8 turbo rev`, `supercar acceleration` |
| `Follie` | Divine | **à confirmer** : hypercar V12 ? (LaFerrari 6.3 L V12, ou autre) | V12 strident, très haut en régime | `V12 engine idle`, `V12 supercar rev`, `hypercar acceleration` |
| `F150` (intro) | — | Ford F-150 — 5.0 L V8 Coyote | V8 américain grave, un peu rugueux | `pickup truck V8 idle`, `Ford V8 engine rev`, `truck burnout` |

Conseils pour que ça sonne « vrai » :
* **Ralenti** : un son de 5 à 15 s **en boucle propre** (sans clic au raccord), moteur à bas régime ou vitesse constante. Le jeu
  monte la hauteur jusqu'à ×1,45 avec la vitesse : prends un son plutôt grave.
* **Accélération** : 4 à 8 s, départ arrêté → plein régime, idéalement avec un passage de rapport. Pas de boucle.
* Dans le Creator Store, filtre « Son » (pas musique), trie par **Utilisation** ou **Note**, écoute avant de prendre. Les sons
  Roblox libres (fournisseurs APM, Pro Sound Effects) sont utilisables dans n'importe quelle expérience ; un son d'un autre
  joueur ne marchera **que** s'il est public (règle de confidentialité audio Roblox depuis 2022).
* Si tu importes tes propres fichiers (Contenus → Importer), formats .mp3 / .ogg, 7 minutes max, et tu dois en avoir les
  droits : les enregistrements YouTube de vraies voitures **ne passent pas** la modération.

## 2. Où coller

`ReplicatedStorage/Catalogue/Car` → table `Car.Sons` :

```lua
M4 = { Ralenti = 123456789, Acceleration = 987654321, Hauteur = 1.0, Volume = 0.7, Moteur = "..." },
```
* `Ralenti` / `Acceleration` : l'identifiant (nombre) ou la chaîne `rbxassetid://...`. `0` = pas encore (son générique).
* `Hauteur` : PlaybackSpeed de base du ralenti (0,85 grave … 1,1 aigu) ; `Volume` : volume du rugissement.

Rien d'autre à faire : `TWEENController` lit `Car.SonDe(nom du modèle)` pour chaque voiture (Common → Rare : générique),
et `CarAmbiance` pose l'attribut `Rugissement` pendant le trajet d'achat (sortie du rond-point en dérapage, étapes à 54 puis
42 studs/s) : le son d'accélération part à ce moment-là.

## 3. Test rapide dans Studio
1. Colle au moins les deux identifiants de la `M4`.
2. Play → chat : `/money 100000`, va au centre, attends une M4 sur l'anneau, **E** pour enchérir, laisse finir le tour :
   elle doit rugir et déraper en sortant du rond-point, puis rouler jusqu'à ton plot.
3. Les voitures M4 clientes qui descendent la branche ont désormais le ralenti S58 au lieu du kart.
