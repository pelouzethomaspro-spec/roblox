--[[ Catalogue / Boutique — v56 : TOUS les identifiants Robux au meme endroit (a remplir par Thomas).
	Creations -> ton experience -> Monetisation : cree les Passes et les Produits developpeur, puis colle leurs identifiants
	ici (0 = pas encore cree : l'article affiche "bientot disponible" et rien n'est vendu).
	Lu par le serveur (ServerScriptService/Monetisation : ProcessReceipt, Game Pass) ET par le client (StarterGui/UIController :
	table SHOP du Shop). Un seul fichier a modifier.
]]
local Boutique = {}

-- Passes (Game Pass) : effet en jeu
Boutique.GAMEPASS = {
	ArgentX2 = 0,                 -- gains des voitures x2 (CarManager, verifie cote serveur)
	VIP = 0,                      -- badge VIP (ClientRang) ; autres avantages a definir
	LivraisonExpress = 0,         -- (a brancher dans Livraison : camion plus rapide)
	EmployesAuto = 0,             -- (a brancher : toutes les stations comptent comme pourvues d'un employe)
}

-- Produits developpeur "argent" : identifiant et montant donne
Boutique.ARGENT = {
	PetitSac = { Id = 0, Montant = 5000 },
	Coffre = { Id = 0, Montant = 25000 },
	Tresor = { Id = 0, Montant = 100000 },
	PackDemarrage = { Id = 0, Montant = 15000 },
}

-- Produits developpeur "voiture du centre" : achat immediat (touche F pres de la voiture, Enchere), par rarete
Boutique.VOITURE = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0, Divine = 0 }

-- Onglets du Shop (UI v24) : 4 articles par onglet, dans l'ordre des boutons Buy1..Buy4 de la maquette
Boutique.SHOP = {
	GamePass = { "ArgentX2", "VIP", "LivraisonExpress", "EmployesAuto" },
	Money = { "PetitSac", "Coffre", "Tresor", "PackDemarrage" },
	Cars = { "Legendary", "Mythic", "Divine", "Epic" },        -- F448 Legendaire, Follie Mythique, M4 Divine, Class G Epique
}

-- identifiants des 3 onglets, dans l'ordre des boutons (0 = indisponible)
function Boutique.IdsShop()
	local ids = { GamePass = {}, Money = {}, Cars = {} }
	for i, nom in ipairs(Boutique.SHOP.GamePass) do ids.GamePass[i] = Boutique.GAMEPASS[nom] or 0 end
	for i, nom in ipairs(Boutique.SHOP.Money) do ids.Money[i] = (Boutique.ARGENT[nom] and Boutique.ARGENT[nom].Id) or 0 end
	for i, tier in ipairs(Boutique.SHOP.Cars) do ids.Cars[i] = Boutique.VOITURE[tier] or 0 end
	return ids
end

-- montant d'argent d'un produit developpeur (nil si ce n'est pas un produit "argent")
function Boutique.MontantArgent(idProduit)
	if not idProduit or idProduit == 0 then return nil end
	for _, a in pairs(Boutique.ARGENT) do if a.Id == idProduit then return a.Montant end end
	return nil
end

return Boutique
