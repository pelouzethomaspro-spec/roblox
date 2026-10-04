--[[ Meteo (Script, ServerScriptService) — evenement TEMPETE : le ciel se couvre, pluie, vent, orage violet, et la foudre
	frappe le sol et les voitures.

	Le serveur DECIDE (debut/fin de la tempete, ou et quand tombe chaque eclair, quelle voiture est foudroyee) et l'annonce
	a tous les joueurs par le RemoteEvent "MeteoEvent" ; tout le visuel et le son sont joues chez chaque joueur (MeteoClient).
	Rien ne vient du client.

	Commandes (chat, admins seulement, voir AdminCommands) :
	  /tempete [secondes]   lance la tempete (180 s par defaut)   |   /tempete stop   l'arrete
	  /eclair               un eclair pres de toi                 |   /foudre         foudroie la voiture la plus proche de toi

	VOITURE FOUDROYEE : elle recoit l'attribut "Electrique" = true (retire apres ELECTRIQUE_DUREE secondes) et le
	BindableEvent ServerScriptService/Meteo/VoitureFoudroyee est declenche avec (voiture, position). C'est le point
	d'accroche pour l'animation "la voiture devient electrique" : cote client, MeteoClient joue deja un effet simple
	(halo violet, etincelles, zap) que l'animation de Thomas pourra remplacer ou completer.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DUREE_DEFAUT = 180             -- secondes
local ECLAIR_MIN, ECLAIR_MAX = 1.5, 5 -- secondes entre deux eclairs (tempete intense)
local PROBA_VOITURE = 0.35           -- part des eclairs qui visent une voiture
local RAYON_JOUEUR = 260             -- les autres eclairs tombent dans ce rayon autour d'un joueur (pour qu'on les voie)
local ELECTRIQUE_DUREE = 25          -- secondes pendant lesquelles la voiture reste "Electrique"

local MeteoEvent = ReplicatedStorage:FindFirstChild("MeteoEvent")
if not MeteoEvent then MeteoEvent = Instance.new("RemoteEvent"); MeteoEvent.Name = "MeteoEvent"; MeteoEvent.Parent = ReplicatedStorage end

local Commande = Instance.new("BindableEvent"); Commande.Name = "MeteoCommande"; Commande.Parent = script
local Foudroyee = Instance.new("BindableEvent"); Foudroyee.Name = "VoitureFoudroyee"; Foudroyee.Parent = script

local enCours = false
local finA = 0

-- toutes les voitures en circulation (clients des plots + ambiance)
local function voitures()
	local liste = {}
	local plots = workspace:FindFirstChild("Plots")
	if plots then
		for _, d in ipairs(plots:GetDescendants()) do
			if d:IsA("Model") and d.PrimaryPart and d.PrimaryPart.Name == "Root" and (d:GetAttribute("Tier") or d:GetAttribute("Ambiance")) then
				table.insert(liste, d)
			end
		end
	end
	local amb = workspace:FindFirstChild("Cars_Ambiance")
	if amb then
		for _, d in ipairs(amb:GetChildren()) do if d:IsA("Model") and d.PrimaryPart then table.insert(liste, d) end end
	end
	return liste
end

local function foudroyer(voiture, position)
	voiture:SetAttribute("Electrique", true)
	voiture:SetAttribute("FoudroyeeA", workspace:GetServerTimeNow())
	Foudroyee:Fire(voiture, position)
	task.delay(ELECTRIQUE_DUREE, function()
		if voiture.Parent then voiture:SetAttribute("Electrique", nil) end
	end)
end

-- un eclair : sur une voiture (cible) ou au sol a une position
local function eclair(position, cible, puissance)
	MeteoEvent:FireAllClients("eclair", position, cible, puissance or 1)
	if cible then foudroyer(cible, position) end
end

local function eclairAleatoire()
	local liste = voitures()
	if #liste > 0 and math.random() < PROBA_VOITURE then
		local v = liste[math.random(1, #liste)]
		eclair(v:GetPivot().Position, v, 1)
		return
	end
	local joueurs = Players:GetPlayers()
	local centre = Vector3.zero
	if #joueurs > 0 then
		local p = joueurs[math.random(1, #joueurs)]
		local perso = p.Character
		local racine = perso and perso:FindFirstChild("HumanoidRootPart")
		if racine then centre = racine.Position end
	end
	local a, r = math.random() * 2 * math.pi, 40 + math.random() * RAYON_JOUEUR
	local pos = Vector3.new(centre.X + math.cos(a) * r, 0, centre.Z + math.sin(a) * r)
	local ray = workspace:Raycast(pos + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0))
	if ray then pos = ray.Position end
	eclair(pos, nil, 0.6 + math.random() * 0.6)
end

local function arreter()
	if not enCours then return end
	enCours = false
	workspace:SetAttribute("Tempete", false)
	MeteoEvent:FireAllClients("tempete", false)
	print("[Meteo] fin de la tempete")
end

local function lancer(duree)
	duree = duree or DUREE_DEFAUT
	finA = os.clock() + duree
	if enCours then print(("[Meteo] tempete prolongee : %d s"):format(duree)) return end
	enCours = true
	workspace:SetAttribute("Tempete", true)
	MeteoEvent:FireAllClients("tempete", true, duree)
	print(("[Meteo] TEMPETE pendant %d s"):format(duree))
	task.spawn(function()
		task.wait(6)                                             -- le ciel se couvre d'abord
		while enCours and os.clock() < finA do
			eclairAleatoire()
			task.wait(ECLAIR_MIN + math.random() * (ECLAIR_MAX - ECLAIR_MIN))
		end
		arreter()
	end)
end

Commande.Event:Connect(function(action, arg, joueur)
	if action == "start" then lancer(arg)
	elseif action == "stop" then arreter()
	elseif action == "eclair" then
		local racine = joueur and joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		local centre = racine and racine.Position or Vector3.zero
		local a = math.random() * 2 * math.pi
		local pos = centre + Vector3.new(math.cos(a) * 40, 0, math.sin(a) * 40)
		local ray = workspace:Raycast(pos + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0))
		eclair(ray and ray.Position or pos, nil, 1)
	elseif action == "foudre" then
		local racine = joueur and joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		local centre = racine and racine.Position or Vector3.zero
		local best, bd = nil, math.huge
		for _, v in ipairs(voitures()) do
			local d = (v:GetPivot().Position - centre).Magnitude
			if d < bd then best, bd = v, d end
		end
		if best then eclair(best:GetPivot().Position, best, 1) end
	end
end)

-- un joueur qui arrive pendant la tempete la recoit
Players.PlayerAdded:Connect(function(p)
	if enCours then task.delay(3, function() MeteoEvent:FireClient(p, "tempete", true, math.max(5, finA - os.clock())) end) end
end)
workspace:SetAttribute("Tempete", false)
