-- Lancement : Script (ServerScriptService). A chaque "Jouer", installe la map si ce
-- n'est pas deja fait dans la place (collisions invisibles, arbres, lumieres,
-- point d'apparition). Pour l'enregistrer une fois pour toutes dans la place :
-- barre de commandes -> require(game.ServerStorage.InstallerMap)()  puis sauvegarder.
local SS = game:GetService("ServerStorage")

local function mapImportee()
	for _, enfant in ipairs(workspace:GetChildren()) do
		if enfant:IsA("Model") or enfant:IsA("Folder") then
			for _, d in ipairs(enfant:GetDescendants()) do
				if d:IsA("BasePart") and string.find(d.Name, "Sol_Herbe_0_0", 1, true) then
					return enfant
				end
			end
		end
	end
end

local map = mapImportee()
if not map then
	warn("[Map] MAP_MOTIFS_V17_AVEC_CHAINES.fbx n'est pas encore importee dans Workspace "
		.. "(Accueil > Importer 3D). Importe aussi ARBRES_V17.fbx, puis relance Jouer.")
	return
end
-- Brume V2 (nappes graduelles au bord de la map) : si la place sauvegardee ne l'a pas encore, on la pose au lancement
-- (44 Parts, instantane) ; pour la garder dans la place : require(game.ServerStorage.InstallerBrume)() puis sauvegarder
local brume = workspace:FindFirstChild("Brume")
if not (brume and brume:FindFirstChild("Nappes")) and SS:FindFirstChild("InstallerBrume") then
	local okB, errB = pcall(function() require(SS.InstallerBrume)() end)
	if not okB then warn("[Map] brume : " .. tostring(errB)) end
end
-- v55 : les donnees de la chaine de production (Stations/Donnees/ChaineProduction) sont a l'echelle de la chaine M4_9 de
-- la map (x 22/36). Si la place a ete montee avec d'autres donnees (attribut ChainesVersion de la map), on remonte les
-- 4 chaines au lancement (articulations, voitures invisibles) : ~1 s, sinon les voitures traversent les murs du hall.
local function remonterChaines()
	local okC, errC = pcall(function()
		local D = require(game:GetService("ReplicatedStorage"):WaitForChild("Stations"):WaitForChild("Donnees"):WaitForChild("ChaineProduction"))
		local version = "echelle=" .. tostring(D.ECHELLE_ANIM or 1)
		if map:GetAttribute("ChainesVersion") ~= version then
			require(SS:WaitForChild("InstallerChaines"))()
			map:SetAttribute("ChainesVersion", version)
			print("[Map] chaines remontees (" .. version .. ")")
		end
	end)
	if not okC then warn("[Map] chaines : " .. tostring(errC)) end
end
if map:FindFirstChild("Collisions") then
	-- map deja installee : on refait seulement le terrain (herbe realiste, sol plat sous le bati, eau), ~1 s
	local okH, errH = pcall(function() require(SS:WaitForChild("InstallerHerbe"))() end)
	if not okH then warn("[Map] herbe : " .. tostring(errH)) end
	remonterChaines()
	print("[Map] deja installee dans la place : terrain refait")
	return
end
local ok, err = pcall(function()
	require(SS:WaitForChild("InstallerMap"))()
end)
if not ok then warn("[Map] installation : " .. tostring(err)) end
remonterChaines()
