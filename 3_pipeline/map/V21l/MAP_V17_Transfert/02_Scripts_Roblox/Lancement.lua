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
	warn("[Map] MAP_MOTIFS_V16_AVEC_CHAINES.fbx n'est pas encore importee dans Workspace "
		.. "(Accueil > Importer 3D). Importe aussi ARBRES_V16.fbx, puis relance Jouer.")
	return
end
if map:FindFirstChild("Collisions") then
	print("[Map] deja installee dans la place : rien a faire")
	return
end
local ok, err = pcall(function()
	require(SS:WaitForChild("InstallerMap"))()
end)
if not ok then warn("[Map] installation : " .. tostring(err)) end
