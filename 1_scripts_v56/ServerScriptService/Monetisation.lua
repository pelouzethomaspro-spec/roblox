--[[ Monetisation (ModuleScript, ServerScriptService) — v55 : produits developpeur et Game Pass (Robux).

	A REMPLIR PAR THOMAS : les identifiants ci-dessous (0 = pas encore cree) viennent de Creations -> ton experience ->
	Monetisation (produits developpeur et passes). Les memes identifiants sont a recopier dans la table SHOP de
	StarterGui/UIController (onglets Argent et Voitures du Shop) ; les produits "Voiture" servent a l'achat immediat (F)
	d'une voiture du centre (Enchere).

	Securite : tout est verifie ici, cote serveur. ProcessReceipt est appele par Roblox apres paiement ; on rend
	PurchaseGranted seulement quand la recompense a bien ete donnee (sinon Roblox rappellera plus tard).
	Chaque recu n'est traite qu'une fois par serveur (table Recus) ; la memoire durable des recus (profil) est ajoutee
	si Thomas le souhaite.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local Monetisation = {}

Monetisation.PRODUITS = {
	-- achat immediat d'une voiture du centre, par rarete (identifiant du produit developpeur)
	Voiture = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0, Divine = 0 },
	-- argent (onglet Argent du Shop) : identifiant -> montant
	Argent = {
		-- [123456789] = 5000,     -- Petit sac
		-- [123456790] = 25000,    -- Coffre
		-- [123456791] = 100000,   -- Trésor
		-- [123456792] = 15000,    -- Pack démarrage
	},
}
Monetisation.GAMEPASS = {
	-- ArgentX2 = 0, VIP = 0, LivraisonExpress = 0, EmployesAuto = 0,
}

local Recus = {}

local function raretePourProduit(id)
	for tier, pid in pairs(Monetisation.PRODUITS.Voiture) do if pid == id and id ~= 0 then return tier end end
	return nil
end

MarketplaceService.ProcessReceipt = function(recu)
	local cle = recu.PurchaseId
	if Recus[cle] then return Enum.ProductPurchaseDecision.PurchaseGranted end
	local player = Players:GetPlayerByUserId(recu.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local id = recu.ProductId

	local tier = raretePourProduit(id)
	if tier then
		local okE, Enchere = pcall(function() return require(ServerScriptService:WaitForChild("Enchere", 5)) end)
		if not (okE and Enchere) then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local ok, res = pcall(Enchere.AchatRobux, player, tier)
		if ok and res then Recus[cle] = true; print(("[Monetisation] %s : voiture %s (Robux)"):format(player.Name, tier)); return Enum.ProductPurchaseDecision.PurchaseGranted end
		warn("[Monetisation] voiture Robux : " .. tostring(res))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local montant = Monetisation.PRODUITS.Argent[id]
	if montant then
		local ok = pcall(PlayerData.AddMoney, player, montant)
		if ok then Recus[cle] = true; print(("[Monetisation] %s : +%d $ (Robux)"):format(player.Name, montant)); return Enum.ProductPurchaseDecision.PurchaseGranted end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	warn("[Monetisation] produit inconnu : " .. tostring(id))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Game Pass : possession (cache par joueur), a interroger par les autres scripts (ex. Monetisation.Possede(player, "VIP"))
local cache = {}
function Monetisation.Possede(player, nom)
	local id = Monetisation.GAMEPASS[nom]
	if not id or id == 0 then return false end
	cache[player.UserId] = cache[player.UserId] or {}
	local c = cache[player.UserId]
	if c[nom] == nil then
		local ok, res = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
		c[nom] = ok and res or false
	end
	return c[nom]
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, achete)
	if achete then
		for nom, pid in pairs(Monetisation.GAMEPASS) do if pid == id then cache[player.UserId] = cache[player.UserId] or {}; cache[player.UserId][nom] = true end end
	end
end)
Players.PlayerRemoving:Connect(function(p) cache[p.UserId] = nil end)

return Monetisation
