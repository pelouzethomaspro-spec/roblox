--[[ Catalogue / Consommable
	Produits achetes au Stock (Buy), charges dans les stations (Supply), payes par les clients (Sell).
	Volume = place occupee dans l'inventaire du joueur (litres) et dans la station (Capacity de la station / Volume
	= nombre d'unites qu'elle contient). Type = famille, affichee dans le menu Supply.
	Un produit n'est utilisable que dans les stations dont "Accepted" (Catalogue > Furniture) contient sa cle.
	Le modele d'apercu 3D porte le meme nom dans ReplicatedStorage > Products.
]]
local Consommable = {

	-- ------------------------------------------------------------------ lavage (L1, L2, L3, L4, E1)
	["1"] = {
		Buy = 10,
		Sell = 25,
		Volume = 25,
		Name = "Nettoyant Carroserie",
		Type = "Lavage",
	},
	["2"] = {
		Buy = 10,
		Sell = 25,
		Volume = 3,
		Name = "Nettoyant Vitre",
		Type = "Lavage",
	},
	["3"] = {
		Buy = 65,
		Sell = 85,
		Volume = 3,
		Name = "Nettoyant Jante",
		Type = "Lavage",
	},

	-- ------------------------------------------------------------------ energie (E2, E3, E4, E1)
	["4"] = {
		Buy = 25,
		Sell = 50,
		Volume = 25,
		Name = "Bidon d'essence",
		Type = "Energie",
	},
	["5"] = {
		Buy = 30,
		Sell = 60,
		Volume = 80,
		Name = "Batterie Lithium",
		Type = "Energie",
	},
	["6"] = {
		Buy = 120,
		Sell = 150,
		Volume = 25,
		Name = "Bonbonne Hydrogène",
		Type = "Energie",
	},

	-- ------------------------------------------------------------------ ateliers (E5 pneus, E6 peinture, E7 vitres)
	["7"] = {
		Buy = 90,
		Sell = 190,
		Volume = 30,
		Name = "Jeu de pneus",
		Type = "Pneus",
	},
	["8"] = {
		Buy = 40,
		Sell = 95,
		Volume = 20,
		Name = "Pot de peinture",
		Type = "Peinture",
	},
	["9"] = {
		Buy = 35,
		Sell = 80,
		Volume = 10,
		Name = "Film teinté pour vitres",
		Type = "Vitres",
	},
}

return Consommable
