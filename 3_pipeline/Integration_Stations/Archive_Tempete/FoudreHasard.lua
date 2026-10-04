--[[ FoudreHasard (Script, ServerScriptService) — TRES RAREMENT, un eclair frappe une voiture au hasard.
	La voiture touchee devient electrique (arcs violets, etincelles, halo, crepitement : effet du pack "Foudre" joue chez
	chaque joueur par StarterPlayerScripts/FoudreClient) pendant DUREE secondes, puis redevient normale.
	Ca tourne en permanence, sans orage ni changement de ciel : juste un coup de foudre de temps en temps.

	Le serveur ne fait que designer la voiture (etiquette "Electrifiee" + attribut "FoudreT", voir FoudreServeur) :
	cout serveur quasi nul, tout le visuel est calcule cote joueur.

	Voitures du jeu : les Models dont le PrimaryPart s'appelle "Root" (voitures clientes dans Workspace/Cars_<UserId> et
	voitures d'ambiance dans Workspace/Cars_Ambiance). Le pack cherchait des VehicleSeat par defaut : on lui donne
	notre propre liste.

	Commandes admin (AdminCommands) : /foudre = frappe la voiture la plus proche de toi (pour tester),
	/foudre stop = eteint toutes les voitures.
]]
local ACTIF = true
local INTERVALLE = {240, 540}     -- secondes entre deux coups de foudre (au hasard entre 4 et 9 minutes)
local DUREE = 45                  -- secondes pendant lesquelles la voiture reste electrique
local PROXIMITE_JOUEUR = 500      -- on prefere une voiture a moins de cette distance d'un joueur (pour que quelqu'un le voie)

local Players = game:GetService("Players")
local Foudre = require(script.Parent:WaitForChild("FoudreServeur"))

local function estVoiture(m)
	return m:IsA("Model") and m.PrimaryPart ~= nil and m.PrimaryPart.Name == "Root"
end

-- toutes les voitures en circulation : les clientes de chaque joueur (Workspace/Cars_<UserId>, dossier de CarManager)
-- et les voitures d'ambiance (Workspace/Cars_Ambiance). Pas les camions de livraison (Livraisons_<UserId>).
local function voitures()
	local liste = {}
	for _, dossier in ipairs(workspace:GetChildren()) do
		if dossier:IsA("Folder") and dossier.Name:sub(1, 5) == "Cars_" then
			for _, d in ipairs(dossier:GetChildren()) do
				if estVoiture(d) then table.insert(liste, d) end
			end
		end
	end
	return liste
end

-- les voitures proches d'un joueur d'abord ; s'il n'y en a aucune, toutes
local function voituresVisibles()
	local toutes = voitures()
	local proches = {}
	local racines = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp then table.insert(racines, hrp.Position) end
	end
	for _, v in ipairs(toutes) do
		local pos = v.PrimaryPart.Position
		for _, r in ipairs(racines) do
			if (pos - r).Magnitude < PROXIMITE_JOUEUR then table.insert(proches, v) break end
		end
	end
	return #proches > 0 and proches or toutes
end

-- partage avec AdminCommands (/foudre) : la meme definition des voitures
Foudre.voituresJeu = voitures
Foudre.DUREE_HASARD = DUREE

if ACTIF then
	Foudre.hasard({ intervalle = INTERVALLE, duree = DUREE, voitures = voituresVisibles })
	print(("[Foudre] coup de foudre au hasard toutes les %d a %d s, voiture electrique %d s"):format(INTERVALLE[1], INTERVALLE[2], DUREE))
end
