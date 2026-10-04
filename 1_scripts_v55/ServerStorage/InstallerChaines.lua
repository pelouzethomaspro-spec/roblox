--[[ InstallerChaines (ModuleScript, ServerStorage) — monte les 4 chaines de production animees de la map V17.
	Barre de commande (Affichage > Barre de commande), la map importee :  require(game.ServerStorage.InstallerChaines)()
	(ou, pour tout faire d'un coup : require(game.ServerStorage.InstallerTout)() )

	Dans le FBX de la map, les 4 chaines sont deja placees et leurs pieces portent un prefixe : NE_CP_Tapis, NO_CP_Hall...
	Le systeme Stations (module Montage, donnees Donnees/ChaineProduction, animations) connait les pieces sans prefixe
	(CP_Tapis...). Pour chaque coin, ce script :
	  1) regroupe les pieces XX_CP_* dans un Model "ChaineProduction_XX" (range dans le modele de la map) et retire le prefixe ;
	  2) lance le montage du systeme Stations sur ce modele : 80 articulations Motor6D, pieces figees, Socle,
	     AnimationController, voitures invisibles Voiture_0..6, etiquette "Station" ;
	  3) marque la chaine "Boucle" (decor : elle tourne en continu chez tous les joueurs).
	Puis il range les 7 animations (ServerStorage/AnimationsStations -> RBX_ANIMSAVES + copies de test dans
	ReplicatedStorage/AnimationsTest_ASupprimer tant que les ID publies manquent dans Stations/Reglages).
	Relancable sans risque (le montage refait les articulations). InstallerMap doit avoir ete lance avant (il l'est
	automatiquement ici si ce n'est pas le cas).
]]
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local COINS = {"NE", "NO", "SE", "SO"}

local function trouverMap()
	for _, enfant in ipairs(workspace:GetChildren()) do
		if enfant:IsA("Model") or enfant:IsA("Folder") then
			for _, d in ipairs(enfant:GetDescendants()) do
				if d:IsA("BasePart") and string.find(d.Name, "Sol_Herbe_0_0", 1, true) then return enfant end
			end
		end
	end
end

return function()
	local map = trouverMap()
	assert(map, "Map V17 introuvable dans Workspace : Accueil > Importer 3D > MAP_MOTIFS_V17_AVEC_CHAINES.fbx")
	if not map:FindFirstChild("Collisions") then
		print("[Chaines] la map n'est pas encore installee : lancement d'InstallerMap d'abord…")
		require(SS:WaitForChild("InstallerMap"))()
	end

	local Montage = require(RS:WaitForChild("Stations"):WaitForChild("Montage"))
	local D = require(RS.Stations.Donnees:WaitForChild("ChaineProduction"))
	local montees = {}
	local total = 0

	for _, coin in ipairs(COINS) do
		local nomModele = "ChaineProduction_" .. coin
		local modele = map:FindFirstChild(nomModele) or workspace:FindFirstChild(nomModele)
		-- 1) regroupement des pieces prefixees (import brut) dans le modele du coin
		local prefixe = coin .. "_CP_"
		local pieces = {}
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") and string.sub(d.Name, 1, #prefixe) == prefixe then table.insert(pieces, d) end
		end
		if #pieces == 0 and not modele then
			warn("[Chaines] coin " .. coin .. " : aucune piece " .. prefixe .. "* dans Workspace (FBX AVEC_CHAINES importe ?)")
			continue
		end
		if not modele then
			modele = Instance.new("Model"); modele.Name = nomModele; modele.Parent = map
		end
		for _, p in ipairs(pieces) do
			p.Name = string.sub(p.Name, #coin + 2)          -- "NE_CP_Tapis" -> "CP_Tapis"
			p.Parent = modele
		end
		-- 2) montage du systeme Stations sur ce modele precis
		local ok, r = pcall(Montage.station, D, modele)
		if not ok then
			warn("[Chaines] coin " .. coin .. " : " .. tostring(r))
		elseif r then
			r:SetAttribute("Boucle", true)                  -- decor : cycle continu, pas de commande serveur
			r:SetAttribute("Coin", coin)
			montees[r] = D
			total += 1
		end
	end

	-- 3) animations : RBX_ANIMSAVES + copies de test (Studio) pour celles sans ID publie
	if next(montees) then
		local ok, err = pcall(Montage.animations, montees)
		if not ok then warn("[Chaines] animations : " .. tostring(err)) end
	end
	print(("[Chaines] %d chaine(s) montee(s). Etape suivante : publier les 7 animations Chaine* (ServerStorage > AnimationsStations, clic droit > Enregistrer sur Roblox) et coller les ID dans ReplicatedStorage > Stations > Reglages."):format(total))
	return total
end
