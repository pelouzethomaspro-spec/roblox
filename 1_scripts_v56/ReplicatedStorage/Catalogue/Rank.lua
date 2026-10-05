--[[ Catalogue / Rank — v55 : les 7 RANGS du joueur (Thomas : Bronze, Argent, Or, Platine, Diamant, Maitre, Legende).
	v56 : seuils d'XP, criteres et cadences re-equilibres d'apres la simulation (2_documents/ECONOMIE_v56.md : Argent ~20 min,
	Or ~1 h 15, Platine ~3 h, Diamant ~7 h, Maitre ~20 h, Legende ~55 h de jeu sans panneaux ni decoration) ; plus de voiture
	Divine exigee avant Legende (0,02 % de chances : on pouvait rester bloque des heures). Debloque rempli : ces objets portent
	le champ Rang correspondant dans Catalogue/Furniture (le menu Construction les grise en dessous du rang).
	Pour passer au rang suivant il faut l'XP ET les criteres : avoir lave au moins N voitures de chaque rarete indiquee
	(Index du profil, rempli par CarManager a chaque voiture servie). Les seuils ci-dessous sont une proposition : ajuste
	librement, rien dans le code n'en depend.
	Champs :
	  Nom       libelle affiche (HUD, au-dessus de la tete)
	  Couleur   couleur du rang (badge au-dessus de la tete, panneau du tunnel)
	  Xp        XP minimum
	  Requis    { rarete = nombre de voitures lavees }   (raretes : Common, Uncommon, Rare, Epic, Legendary, Mythic, Divine)
	  Probas    taux de spawn des 7 raretes a ce rang (somme = 1), affiches en % au-dessus du tunnel
	  Spawn     (secondes) temps moyen entre deux clients a ce rang (CarManager : x 0,8..1,3 au hasard, divise par le
	            multiplicateur des panneaux publicitaires (jusqu'a x2) et de la decoration (0,85..1,5))
	  Debloque  liste d'objets du catalogue debloques en atteignant ce rang (noms Furniture / Pub...) ; vide pour l'instant,
	            le menu Construction grise ce qui demande un rang superieur (champ `Rang` des objets du catalogue)
]]
local Rank = {
	{
		Nom = "Bronze", Couleur = Color3.fromRGB(205, 127, 50), Xp = 0, Spawn = 18.0,
		Requis = {},
		Probas = {0.700, 0.250, 0.0450, 0.0050, 0.0000, 0.00000, 0.00000},
		Debloque = {"L1_Vide", "L2_Seaux", "E1_Base", "PUB_1_PANCARTE", "PUB_2_CHEVALET"},
	},
	{
		Nom = "Argent", Couleur = Color3.fromRGB(192, 192, 200), Xp = 4000, Spawn = 15.0,
		Requis = { Common = 20, Uncommon = 8, Rare = 1 },
		Probas = {0.550, 0.300, 0.1200, 0.0280, 0.0020, 0.00000, 0.00000},
		Debloque = {"L3_Karcher", "E2_Barils", "PUB_3_MONUMENT", "PUB_4_PORTIQUE"},
	},
	{
		Nom = "Or", Couleur = Color3.fromRGB(255, 200, 40), Xp = 20000, Spawn = 12.5,
		Requis = { Common = 80, Uncommon = 40, Rare = 15, Epic = 2 },
		Probas = {0.420, 0.320, 0.1900, 0.0600, 0.0090, 0.00100, 0.00000},
		Debloque = {"L4_Rouleaux", "E3_Pompes", "E4_Bornes", "2", "PUB_5_ENSEIGNE", "PUB_6_BIPODE"},
	},
	{
		Nom = "Platine", Couleur = Color3.fromRGB(120, 210, 230), Xp = 80000, Spawn = 10.0,
		Requis = { Common = 250, Uncommon = 150, Rare = 80, Epic = 20, Legendary = 1 },
		Probas = {0.300, 0.310, 0.2600, 0.1050, 0.0220, 0.00300, 0.00000},
		Debloque = {"E5_Pneus", "E7_Teinte", "PUB_7_TREILLIS"},
	},
	{
		Nom = "Diamant", Couleur = Color3.fromRGB(110, 170, 255), Xp = 300000, Spawn = 8.5,
		Requis = { Common = 600, Uncommon = 450, Rare = 300, Epic = 100, Legendary = 10 },
		Probas = {0.200, 0.270, 0.3200, 0.1650, 0.0380, 0.00680, 0.00020},
		Debloque = {"E6_Peinture", "PUB_8_MAT"},
	},
	{
		Nom = "Maître", Couleur = Color3.fromRGB(190, 90, 255), Xp = 1200000, Spawn = 7.0,
		Requis = { Rare = 1000, Epic = 500, Legendary = 50, Mythic = 4 },
		Probas = {0.130, 0.220, 0.3400, 0.2300, 0.0700, 0.00940, 0.00060},
		Debloque = {"PUB_9_TOTEM"},
	},
	{
		Nom = "Légende", Couleur = Color3.fromRGB(255, 80, 80), Xp = 5000000, Spawn = 6.0,
		Requis = { Epic = 2500, Legendary = 250, Mythic = 20, Divine = 2 },
		Probas = {0.080, 0.170, 0.3300, 0.2900, 0.1100, 0.01850, 0.00150},
		Debloque = {},
	},
}

Rank.Ordre = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine"}
Rank.NomsRaretes = { Common = "Commune", Uncommon = "Peu commune", Rare = "Rare", Epic = "Épique", Legendary = "Légendaire", Mythic = "Mythique", Divine = "Divine" }

-- numero (1..7) d'un rang par son nom
function Rank.Numero(nom)
	for i, r in ipairs(Rank) do if r.Nom == nom then return i end end
	return nil                 -- v56 : rang inconnu -> nil (PlotManager refuse ; avant, 1 = achetable des Bronze)
end

return Rank
